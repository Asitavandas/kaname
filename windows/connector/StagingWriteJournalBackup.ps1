# Evidence copy only. The restored tree is quarantined and is never a live journal.
Set-StrictMode -Version 2

function Get-AuthWireJournalBackupInventory([string]$Path,$Pins){
 $rows=[Collections.Generic.List[object]]::new()
 $pending=[Collections.Generic.Queue[object]]::new()
 $pending.Enqueue([pscustomobject]@{Path=$Path;Relative='';Depth=0})
 $total=[long]0;$files=0
 $hash=Get-AuthWireJobHash ([Text.Encoding]::ASCII.GetBytes("AUTHWIRE-WRITE-JOURNAL-BACKUP-V1`n"))
 while($pending.Count){
  $parent=$pending.Dequeue();$Pins.PinDirectory($parent.Path)
  $names=[string[]]@(Get-ChildItem -LiteralPath $parent.Path -Force -ErrorAction Stop|Select-Object -First 8193|ForEach-Object Name)
  [Array]::Sort($names,[StringComparer]::Ordinal)
  foreach($name in $names){
   if($name -cnotmatch '\A[a-z0-9][a-z0-9._-]{0,100}\z' -or $name.EndsWith('.') -or $parent.Depth -ge 6 -or $rows.Count -ge 8192){throw 'JOURNAL_BACKUP_ENTRY_REJECTED'}
   $relative=if($parent.Relative){$parent.Relative+'/'+$name}else{$name}
   $itemPath=Join-Path $parent.Path $name
   $item=Get-Item -LiteralPath $itemPath -Force -ErrorAction Stop
   $size=0;$digest='';$kind='directory'
   if($item.PSIsContainer){
    $Pins.PinDirectory($itemPath)
    $pending.Enqueue([pscustomobject]@{Path=$itemPath;Relative=$relative;Depth=$parent.Depth+1})
   }else{
    $Pins.PinFile($itemPath)
    $bytes=Read-AuthWireCandidateBytes $itemPath 65536
    $size=$bytes.Length;$total+=$size;$files++;$kind='file';$digest=Get-AuthWireJobHash $bytes
    if($size -eq 0 -or $total -gt 167772160){throw 'JOURNAL_BACKUP_SIZE_LIMIT'}
   }
   $rows.Add([pscustomobject]@{Path=$relative;Kind=$kind;Sha256=$digest})
   $line=$hash+"`n"+$kind+"`n"+$relative+"`n"+$size.ToString([Globalization.CultureInfo]::InvariantCulture)+"`n"+$digest+"`n"
   $hash=Get-AuthWireJobHash ([Text.Encoding]::ASCII.GetBytes($line))
  }
 }
 return [pscustomobject]@{Rows=$rows;TreeSha256=$hash;Files=$files;Bytes=$total}
}

function Copy-AuthWireJournalBackupTree([string]$Source,[string]$Destination,$Inventory,$Pins){
 foreach($row in $Inventory.Rows){
  $relative=$row.Path.Replace('/','\');$target=Join-Path $Destination $relative
  if($row.Kind -ceq 'directory'){
   [AuthWire.Staging.TreeLeaseV1]::CreateNewDirectory($target)
   $Pins.PinDirectory($target)
  }else{
   $bytes=Read-AuthWireCandidateBytes (Join-Path $Source $relative) 65536
   if((Get-AuthWireJobHash $bytes) -cne $row.Sha256){throw 'JOURNAL_BACKUP_SOURCE_CHANGED'}
   Write-AuthWireHistoryBytes $target $bytes
   $Pins.PinFile($target)
  }
 }
}

function Assert-AuthWireJournalBackupSeparate([string]$First,[string]$Second){
 $a=[IO.Path]::GetFullPath($First).TrimEnd('\')+'\'
 $b=[IO.Path]::GetFullPath($Second).TrimEnd('\')+'\'
 if($a.StartsWith($b,[StringComparison]::OrdinalIgnoreCase) -or $b.StartsWith($a,[StringComparison]::OrdinalIgnoreCase)){throw 'JOURNAL_BACKUP_PATH_OVERLAP'}
}

function Assert-AuthWireEmptyJournalBackupDirectory([string]$Path,$Pins){
 if([IO.Path]::GetFullPath($Path) -match '(?:^|\\)AuthWire-WriteJournal-[0-9a-f]{32}(?:\\|$)'){throw 'JOURNAL_BACKUP_ACTIVE_PATH_REJECTED'}
 $Pins.PinAncestors($Path);Assert-AuthWireStagingJournalRoot $Path
 if(Get-ChildItem -LiteralPath $Path -Force -ErrorAction Stop|Select-Object -First 1){throw 'JOURNAL_BACKUP_DESTINATION_NOT_EMPTY'}
}

function Export-AuthWireWriteJournalBackup([string]$Root,[hashtable]$Binding,[string]$Backup){
 Assert-AuthWireStagingWriteJournalLocation $Root $Binding
 Assert-AuthWireJournalBackupSeparate $Root $Backup
 Initialize-AuthWireStagingFilesystemTypes
 $lock=Enter-AuthWireWriteCycleLock $Binding;$source=[AuthWire.Staging.TreeLeaseV1]::new();$target=[AuthWire.Staging.TreeLeaseV1]::new()
 try{
  $source.PinAncestors($Root);Assert-AuthWireEmptyJournalBackupDirectory $Backup $target
  $inventory=Get-AuthWireJournalBackupInventory $Root $source
  if($inventory.Files -eq 0){throw 'JOURNAL_BACKUP_EMPTY_SOURCE'}
  $data=Join-Path $Backup 'data';[AuthWire.Staging.TreeLeaseV1]::CreateNewDirectory($data);$target.PinDirectory($data)
  Copy-AuthWireJournalBackupTree $Root $data $inventory $target
  $copied=Get-AuthWireJournalBackupInventory $data $target
  $current=Get-AuthWireJournalBackupInventory $Root $source
  if($copied.TreeSha256 -cne $inventory.TreeSha256 -or $current.TreeSha256 -cne $inventory.TreeSha256){throw 'JOURNAL_BACKUP_TREE_CHANGED'}
  $manifest=[pscustomobject][ordered]@{format='AuthWireWriteJournalBackupV1';scope_sha256=(Get-AuthWireJobScope $Binding);tree_sha256=$inventory.TreeSha256;files=$inventory.Files;bytes=$inventory.Bytes}
  $bytes=[Text.UTF8Encoding]::new($false,$true).GetBytes(($manifest|ConvertTo-Json -Compress))
  Write-AuthWireHistoryBytes (Join-Path $Backup 'manifest.json') $bytes
  return [pscustomobject]@{ManifestSha256=(Get-AuthWireJobHash $bytes);TreeSha256=$inventory.TreeSha256;Files=$inventory.Files}
 }finally{$target.Dispose();$source.Dispose();$lock.ReleaseMutex();$lock.Dispose()}
}

function Restore-AuthWireWriteJournalEvidence([string]$Backup,[string]$Destination,[string]$ManifestSha256,[string]$ScopeSha256){
 if($ManifestSha256 -cnotmatch '\A[0-9a-f]{64}\z' -or $ScopeSha256 -cnotmatch '\A[0-9a-f]{64}\z' -or
    [IO.Path]::GetFileName($Destination) -cnotmatch '\AAuthWire-JournalRestore-[0-9a-f]{32}\z'){throw 'JOURNAL_RESTORE_INPUT_REJECTED'}
 Assert-AuthWireJournalBackupSeparate $Backup $Destination
 Initialize-AuthWireStagingFilesystemTypes
 $source=[AuthWire.Staging.TreeLeaseV1]::new();$target=[AuthWire.Staging.TreeLeaseV1]::new()
 try{
  $source.PinAncestors($Backup);Assert-AuthWireStagingJournalRoot $Backup
  Assert-AuthWireEmptyJournalBackupDirectory $Destination $target
  $items=@(Get-ChildItem -LiteralPath $Backup -Force -ErrorAction Stop|ForEach-Object Name)
  if($items.Count -ne 2 -or 'data' -cnotin $items -or 'manifest.json' -cnotin $items){throw 'JOURNAL_BACKUP_ENVELOPE_REJECTED'}
  $file=Join-Path $Backup 'manifest.json';$source.PinFile($file)
  $bytes=Read-AuthWireCandidateBytes $file 4096
  if((Get-AuthWireJobHash $bytes) -cne $ManifestSha256){throw 'JOURNAL_BACKUP_MANIFEST_CHANGED'}
  $manifest=ConvertFrom-AuthWireCandidateJson $bytes
  Assert-AuthWireCandidateFields $manifest @('format','scope_sha256','tree_sha256','files','bytes')
  if($manifest.format -cne 'AuthWireWriteJournalBackupV1' -or $manifest.scope_sha256 -cne $ScopeSha256){throw 'JOURNAL_BACKUP_SCOPE_REJECTED'}
  $data=Join-Path $Backup 'data';$source.PinAncestors($data)
  $inventory=Get-AuthWireJournalBackupInventory $data $source
  if($inventory.Files -eq 0 -or $inventory.TreeSha256 -cne $manifest.tree_sha256 -or $inventory.Files -ne $manifest.files -or $inventory.Bytes -ne $manifest.bytes){throw 'JOURNAL_BACKUP_TREE_CHANGED'}
  Copy-AuthWireJournalBackupTree $data $Destination $inventory $target
  $restored=Get-AuthWireJournalBackupInventory $Destination $target
  if($restored.TreeSha256 -cne $inventory.TreeSha256){throw 'JOURNAL_RESTORE_TREE_CHANGED'}
  return [pscustomobject]@{ManifestSha256=$ManifestSha256;TreeSha256=$restored.TreeSha256;Files=$restored.Files;Quarantined=$true}
 }finally{$target.Dispose();$source.Dispose()}
}
