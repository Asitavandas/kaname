#Requires -Version 5.1
# Isolated native SMB/NTFS boundary test. No AD, real SYSVOL, grants or service.
$ErrorActionPreference='Stop';Set-StrictMode -Version 2
. (Join-Path $PSScriptRoot '..\windows\connector\StagingFilesystem.ps1')
Initialize-AuthWireStagingFilesystemTypes
$script:checks=0
function Check($value,[string]$name){if(-not $value){throw ('SYSVOL_FIXTURE:'+ $name)};$script:checks++}
function Denied([scriptblock]$Action,[string]$name){$blocked=$false;try{& $Action}catch{$blocked=$true};Check $blocked $name}
$root=[IO.Path]::GetFullPath((Join-Path $env:TEMP ('aw-sysvol-'+[guid]::NewGuid().ToString('N'))))
$share='awj'+[guid]::NewGuid().ToString('N').Substring(0,12)
$pins=$null;$owned=$null
try{
 $physical=Join-Path $root 'physical';$target=Join-Path $physical 'domain';$export=Join-Path $root 'export';$wrong=Join-Path $root 'wrong'
 $id=[guid]::NewGuid().ToString('D');$gpo=Join-Path $target ('Policies\{'+$id+'}');$machine=Join-Path $gpo 'Machine'
 foreach($d in @($machine,$export,$wrong)){[IO.Directory]::CreateDirectory($d)|Out-Null}
 [IO.File]::WriteAllText((Join-Path $gpo 'outside.txt'),'existing protected data')
 $link=Join-Path $export 'domain';New-Item -ItemType Junction -Path $link -Target $target | Out-Null
 $account=[Security.Principal.WindowsIdentity]::GetCurrent().Name
 New-SmbShare -Name $share -Path $export -FullAccess $account -CachingMode None | Out-Null
 $anchor='\\'+$env:COMPUTERNAME+'\'+$share+'\domain';$unc=$anchor+'\Policies\{'+$id+'}';$uncMachine=$unc+'\Machine'
 Write-Output ('SYSVOL_FIXTURE_CANONICAL '+(@{path=([IO.Path]::GetFullPath($uncMachine) -ceq $uncMachine);anchor=([IO.Path]::GetFullPath($anchor) -ceq $anchor);target=([IO.Path]::GetFullPath($target) -ceq $target);target_root_length=[IO.Path]::GetPathRoot($target).Length}|ConvertTo-Json -Compress))
 Check ([IO.File]::ReadAllText($unc+'\outside.txt') -ceq 'existing protected data') 'real SMB read'
 $pins=[AuthWire.Staging.TreeLeaseV1]::new()
 Denied {$pins.PinAncestors($unc)} 'generic traversal still rejects junction';$pins.Dispose();$pins=$null
 $pins=[AuthWire.Staging.TreeLeaseV1]::new()
 $pins.PinLocalSysvolAncestors($uncMachine,$anchor,$link,$target)
 Check $true 'fixed junction tag target and physical file identity accepted through SMB'
 Denied {Rename-Item -LiteralPath $link -NewName 'moved' -ErrorAction Stop} 'held junction cannot be renamed'
 Denied {Rename-Item -LiteralPath $target -NewName 'moved' -ErrorAction Stop} 'held physical target cannot be renamed'
 # Own new version only. Ancestors are pinned by the same path used by stage
 # and rollback. Delete leases are compared before the fixed owned-tree delete.
 $version=$uncMachine+'\AuthWire-fixture';[AuthWire.Staging.TreeLeaseV1]::CreateNewDirectory($version)
 $pins.PinLocalSysvolAncestors($version,$anchor,$link,$target)
 for($i=0;$i -lt 20;$i++){[IO.File]::WriteAllText(($version+'\f'+$i+'.txt'),('fixture '+$i))}
 $owned=[AuthWire.Staging.TreeLeaseV1]::Tree($version,$true)
 Check ($owned.Rows.Count -eq 21) 'exact owned 20-file tree observed'
 # The separate path pin is not a delete lease. Release it before deletion,
 # then reacquire only GPO/Machine ancestors as the rollback engine does.
 $owned.Dispose();$owned=$null;$pins.Dispose();$pins=[AuthWire.Staging.TreeLeaseV1]::new()
 $pins.PinLocalSysvolAncestors($uncMachine,$anchor,$link,$target)
 $owned=[AuthWire.Staging.TreeLeaseV1]::Tree($version,$true)
 $start=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds();$ticks=[Diagnostics.Stopwatch]::GetTimestamp()
 $owned.DeleteOwnedTreeBefore(($start+20),$start,$ticks);$owned.Dispose();$owned=$null
 Check (-not [IO.Directory]::Exists($version)) 'owned tree removed through pinned junction'
 Check ([IO.File]::ReadAllText($unc+'\outside.txt') -ceq 'existing protected data') 'outside content preserved'
 $pins.Dispose();$pins=$null
 foreach($case in @('wrong-target','target-unc','outside-prefix','dot-path')){
  $pins=[AuthWire.Staging.TreeLeaseV1]::new()
  switch($case){
   'wrong-target'{Denied {$pins.PinLocalSysvolAncestors($unc,$anchor,$link,$wrong)} $case}
   'target-unc'{Denied {$pins.PinLocalSysvolAncestors($unc,$anchor,$link,$anchor)} $case}
   'outside-prefix'{Denied {$pins.PinLocalSysvolAncestors(($anchor+'-other'),$anchor,$link,$target)} $case}
   'dot-path'{Denied {$pins.PinLocalSysvolAncestors(($anchor+'\Policies\..\Policies\{'+$id+'}'),$anchor,$link,$target)} $case}
  };$pins.Dispose();$pins=$null
 }
 $escape=Join-Path $machine 'escape';New-Item -ItemType Junction -Path $escape -Target $wrong | Out-Null
 $pins=[AuthWire.Staging.TreeLeaseV1]::new()
 Denied {$pins.PinLocalSysvolAncestors(($uncMachine+'\escape'),$anchor,$link,$target)} 'descendant junction remains rejected'
 $pins.Dispose();$pins=$null;[IO.Directory]::Delete($escape)
 $alias=Join-Path $root 'alias';New-Item -ItemType Junction -Path $alias -Target $physical | Out-Null
 $pins=[AuthWire.Staging.TreeLeaseV1]::new()
 Denied {$pins.PinLocalSysvolAncestors($unc,$anchor,$link,(Join-Path $alias 'domain'))} 'local physical target ancestors cannot redirect'
 $pins.Dispose();$pins=$null;[IO.Directory]::Delete($alias)
 $symbolic=Join-Path $export 'symbolic';New-Item -ItemType SymbolicLink -Path $symbolic -Target $target | Out-Null
 $pins=[AuthWire.Staging.TreeLeaseV1]::new()
 Denied {$pins.PinLocalSysvolAncestors(('\\'+$env:COMPUTERNAME+'\'+$share+'\symbolic\Policies\{'+$id+'}'),('\\'+$env:COMPUTERNAME+'\'+$share+'\symbolic'),$symbolic,$target)} 'symbolic link tag is not a mount-point junction'
 $pins.Dispose();$pins=$null;[IO.Directory]::Delete($symbolic)
 # Public engine adapter has no request-supplied target/exception switch.
 $pins=[AuthWire.Staging.TreeLeaseV1]::new()
 Denied {Add-AuthWireStagingGpoPins $pins $unc $unc} 'non SYSVOL adapter path retains generic rejection'
 $pins.Dispose();$pins=$null
 [IO.Directory]::Delete($link)
 Check ([IO.File]::ReadAllText((Join-Path $gpo 'outside.txt')) -ceq 'existing protected data') 'junction removal leaves physical data'
 Write-Output ('AUTHWIRE_SYSVOL_JUNCTION_OK checks='+$script:checks+' real_smb=true ad_simulated=false real_ad_exercised=false')
}finally{
 if($owned){$owned.Dispose()};if($pins){$pins.Dispose()}
 if(Get-SmbShare -Name $share -ErrorAction SilentlyContinue){Remove-SmbShare -Name $share -Force -Confirm:$false}
 # Remove links themselves, never traverse them during recursive fixture cleanup.
 foreach($p in @((Join-Path $root 'export\domain'),(Join-Path $root 'export\symbolic'),(Join-Path $root 'alias'),(Join-Path $root ('physical\domain\Policies\{'+$id+'}\Machine\escape')))){
  if(Test-Path -LiteralPath $p){$item=Get-Item -LiteralPath $p -Force;if($item.Attributes -band [IO.FileAttributes]::ReparsePoint){[IO.Directory]::Delete($p)}}
 }
 if(Test-Path -LiteralPath (Join-Path $root 'export\moved')){[IO.Directory]::Delete((Join-Path $root 'export\moved'))}
 if(Test-Path -LiteralPath $root){Remove-Item -LiteralPath $root -Recurse -Force}
}
