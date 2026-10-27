# Bounded read-only inventory. Never traverses a reparse point or executes content.
Set-StrictMode -Version 2
function Get-AuthWireSysvolInventory {
 param([Parameter(Mandatory=$true)][string]$Root)
 $rootItem=Get-Item -LiteralPath $Root -Force -ErrorAction Stop
 if(-not $rootItem.PSIsContainer -or ($rootItem.Attributes -band [IO.FileAttributes]::ReparsePoint)){throw 'SYSVOL_ROOT_REJECTED'}
 $queue=New-Object 'System.Collections.Generic.Queue[object]'
 $queue.Enqueue([pscustomobject]@{Path=$rootItem.FullName;Relative='';Depth=0})
 $rows=New-Object 'System.Collections.Generic.List[object]';$bytes=0L
 while($queue.Count){
  $dir=$queue.Dequeue()
  if($dir.Depth -gt 16){throw 'SYSVOL_DEPTH_LIMIT'}
  $current=Get-Item -LiteralPath $dir.Path -Force -ErrorAction Stop
  if(-not $current.PSIsContainer -or ($current.Attributes -band [IO.FileAttributes]::ReparsePoint)){throw 'SYSVOL_REPARSE_REJECTED'}
  $acl=Get-Acl -LiteralPath $dir.Path -ErrorAction Stop
  $rows.Add([pscustomobject][ordered]@{Path=$dir.Relative;Kind='directory';Size=0L;Sha256='';Sddl=$acl.Sddl})
  if($rows.Count -gt 1024){throw 'SYSVOL_ENTRY_LIMIT'}
  # Stream directory entries instead of materializing an unbounded recursive tree.
  foreach($path in [IO.Directory]::EnumerateFileSystemEntries($dir.Path)){
   if($rows.Count+$queue.Count -ge 1024){throw 'SYSVOL_ENTRY_LIMIT'}
   $item=Get-Item -LiteralPath $path -Force -ErrorAction Stop
   if($item.Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'SYSVOL_REPARSE_REJECTED'}
   $relative=if($dir.Relative){$dir.Relative+'/'+$item.Name}else{$item.Name}
   if($relative.Length -gt 1024 -or $item.Name.Contains(':')){throw 'SYSVOL_PATH_REJECTED'}
   if($item.PSIsContainer){$queue.Enqueue([pscustomobject]@{Path=$item.FullName;Relative=$relative;Depth=$dir.Depth+1});continue}
   $length=[long]$item.Length;$bytes+=$length
   if($length -gt 16777216 -or $bytes -gt 33554432){throw 'SYSVOL_BYTE_LIMIT'}
   $sddl=(Get-Acl -LiteralPath $item.FullName -ErrorAction Stop).Sddl
   $stream=[IO.File]::Open($item.FullName,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read)
   $sha=[Security.Cryptography.SHA256]::Create()
   try{
    if($stream.Length -ne $length){throw 'SYSVOL_FILE_CHANGED'}
    $hash=([BitConverter]::ToString($sha.ComputeHash($stream))).Replace('-','').ToLowerInvariant()
    if($stream.Length -ne $length){throw 'SYSVOL_FILE_CHANGED'}
   }finally{$sha.Dispose();$stream.Dispose()}
   $after=Get-Item -LiteralPath $item.FullName -Force -ErrorAction Stop
   if(($after.Attributes -band [IO.FileAttributes]::ReparsePoint) -or $after.Length -ne $length -or (Get-Acl -LiteralPath $item.FullName -ErrorAction Stop).Sddl -cne $sddl){throw 'SYSVOL_FILE_CHANGED'}
   $rows.Add([pscustomobject][ordered]@{Path=$relative;Kind='file';Size=$length;Sha256=$hash;Sddl=$sddl})
  }
 }
 $names=[string[]]@($rows|ForEach-Object {$_.Path});[Array]::Sort($names,[StringComparer]::Ordinal)
 $map=@{};foreach($r in $rows){if($map.ContainsKey($r.Path)){throw 'SYSVOL_DUPLICATE_PATH'};$map[$r.Path]=$r}
 $ordered=@(foreach($n in $names){$map[$n]})
 $data=[Text.UTF8Encoding]::new($false,$true).GetBytes(($ordered|ConvertTo-Json -Depth 5 -Compress))
 $sha=[Security.Cryptography.SHA256]::Create()
 try{$digest=([BitConverter]::ToString($sha.ComputeHash($data))).Replace('-','').ToLowerInvariant()}finally{$sha.Dispose()}
 return [pscustomobject]@{Entries=$ordered;FileBytes=$bytes;Sha256=$digest}
}
function Test-AuthWireSysvolEmptyDeployment($Inventory){
 $root=@($Inventory.Entries|Where-Object {$_.Path -ceq '' -and $_.Kind -ceq 'directory'})
 $machine=@($Inventory.Entries|Where-Object {$_.Path -ceq 'Machine' -and $_.Kind -ceq 'directory'})
 $user=@($Inventory.Entries|Where-Object {$_.Path -ceq 'User' -and $_.Kind -ceq 'directory'})
 if($root.Count -ne 1 -or $machine.Count -ne 1 -or $user.Count -ne 1){return $false}
 foreach($r in $Inventory.Entries){
  if($r.Path -ceq ''){continue}
  if($r.Path -cin @('GPO.cmt','GPT.INI')){if($r.Kind -cne 'file' -or $r.Size -gt 4096){return $false};continue}
  if($r.Kind -cne 'directory' -or $r.Path -cnotmatch '\A(?:Machine|User)(?:/[^/]+)*\z'){return $false}
 }
 return (@($Inventory.Entries|Where-Object {$_.Path -ceq 'GPO.cmt'}).Count -eq 1 -and @($Inventory.Entries|Where-Object {$_.Path -ceq 'GPT.INI'}).Count -eq 1)
}
