param([Parameter(Mandatory=$true)][ValidateSet('Export','Restore')][string]$Mode,
      [Alias('ManifestSha256')][string]$ExpectedManifestSha256,[string]$ScopeSha256,[string]$TreeSha256,[string]$TarSha256)
$ErrorActionPreference='Stop'
if($env:RUNNER_ENVIRONMENT -cne 'github-hosted' -or $env:GITHUB_ACTIONS -cne 'true'){throw 'Hosted Windows fixture required'}
$lib=Join-Path (Split-Path $PSScriptRoot) 'windows\connector'
. (Join-Path $lib 'Test-AuthWireDeploymentCandidate.ps1') -LibraryOnly
foreach($name in @('Invoke-AuthWireConnectorProbeJob','StagingFilesystem','StagingWriteCycle','StagingWriteConsumption','StagingWriteHistory','StagingWriteJournalBackup')){. (Join-Path $lib ($name+'.ps1'))}

function Set-FixturePrivateDirectoryAcl([string]$Path,[string]$ServiceSid){
 $serviceAce=if($ServiceSid){'(A;OICI;0x1301bf;;;'+$ServiceSid+')'}else{''}
 $acl=[Security.AccessControl.DirectorySecurity]::new()
 $acl.SetSecurityDescriptorSddlForm('O:BAG:BAD:P(A;OICI;FA;;;SY)(A;OICI;FA;;;BA)'+$serviceAce)
 Set-Acl -LiteralPath $Path -AclObject $acl
}
function New-FixturePrivateDirectory([string]$Path){
 $null=New-Item -Path $Path -ItemType Directory
 Set-FixturePrivateDirectoryAcl $Path
}
function Assert-FixtureRejection([scriptblock]$Action,[string]$Expected){
 try{& $Action|Out-Null}catch{if($_.Exception.Message -ceq $Expected){return};throw}
 throw ('Expected failure: '+$Expected)
}

$temp=Join-Path $env:RUNNER_TEMP ('authwire-journal-fixture-'+[guid]::NewGuid().ToString('N'))
New-FixturePrivateDirectory $temp
$backup=Join-Path $temp 'backup';New-FixturePrivateDirectory $backup
$tar=Join-Path $env:RUNNER_TEMP 'authwire-journal-fixture.tar'
$source=$null
try{
 if($Mode -ceq 'Export'){
  $binding=@{connector_id=[guid]::NewGuid().ToString('D');instance_id=[guid]::NewGuid().ToString('D');generation=1;
   host_guid=[guid]::NewGuid().ToString('D');host_fqdn='source.example';service_sid='S-1-5-21-1-2-3-1001';
   appliance_fqdn='authwire.example';appliance_tls_sha256=('a'*64);channel_key_sha256=('b'*64)}
  $source=Get-AuthWireStagingWriteJournalRoot $binding
  New-FixturePrivateDirectory $source
  $job=[guid]::NewGuid().ToString('D');$gpo=[guid]::NewGuid().ToString('D')
  foreach($name in @($job,'write-lifecycle\000001','write-lifecycle\history-archives\000001\cycles\000001','write-lifecycle\000002')){
   $null=[IO.Directory]::CreateDirectory((Join-Path $source $name))
  }
  Write-AuthWireStagingJournal (Join-Path $source ('gpo-'+$gpo+'.json')) ([pscustomobject]@{fixture='lock';job_id=$job})
  Write-AuthWireStagingJournal (Join-Path $source ($job+'\refusal-outbox.json')) ([pscustomobject]@{fixture='outbox';outcome='refused_before_authorization'})
  Write-AuthWireStagingJournal (Join-Path $source ($job+'\refusal-accepted.json')) ([pscustomobject]@{fixture='ack';accepted=$true})
  Write-AuthWireStagingJournal (Join-Path $source 'write-lifecycle\000001\poll-sent.json') ([pscustomobject]@{fixture='pending'})
  Write-AuthWireStagingJournal (Join-Path $source 'write-lifecycle\history-archives\000001\cycles\000001\completion.json') ([pscustomobject]@{fixture='archive'})
  Assert-FixtureRejection {Export-AuthWireWriteJournalBackup $source $binding $source} 'JOURNAL_BACKUP_PATH_OVERLAP'
  Set-FixturePrivateDirectoryAcl $source 'S-1-5-21-1-2-3-1002'
  Assert-FixtureRejection {Export-AuthWireWriteJournalBackup $source $binding $backup} 'STAGING_JOURNAL_ACL_REJECTED'
  Set-FixturePrivateDirectoryAcl $source $binding.service_sid
  Assert-FixtureRejection {Assert-AuthWireStagingWriteJournalLocation $source $binding} 'STAGING_JOURNAL_ACL_REJECTED'
  Set-FixturePrivateDirectoryAcl $backup $binding.service_sid
  Assert-FixtureRejection {Export-AuthWireWriteJournalBackup $source $binding $backup} 'STAGING_JOURNAL_ACL_REJECTED'
  if(Get-ChildItem -LiteralPath $backup -Force){throw 'Rejected ACL wrote a backup file'}
  Set-FixturePrivateDirectoryAcl $backup
  $export=Export-AuthWireWriteJournalBackup $source $binding $backup
  if($export.Files -ne 5 -or $export.ScopeSha256 -cne (Get-AuthWireJobScope $binding)){throw 'Unexpected export receipt'}
  Assert-FixtureRejection {Export-AuthWireWriteJournalBackup $source $binding $backup} 'JOURNAL_BACKUP_DESTINATION_NOT_EMPTY'
  & tar.exe -cf $tar -C $backup .
  if($LASTEXITCODE -ne 0){throw 'Fixture archive creation failed'}
  @('manifest_sha256='+$export.ManifestSha256; 'scope_sha256='+$export.ScopeSha256;
    'tree_sha256='+$export.TreeSha256; 'tar_sha256='+(Get-FileHash -LiteralPath $tar).Hash.ToLowerInvariant();
    'artifact_name=authwire-synthetic-journal-'+$env:GITHUB_RUN_ID+'-'+$env:GITHUB_RUN_ATTEMPT) | Add-Content -LiteralPath $env:GITHUB_OUTPUT
  Write-Output 'AUTHWIRE_JOURNAL_BACKUP_EXPORT_OK synthetic=true'
 }else{
  if((Get-FileHash -LiteralPath $tar).Hash.ToLowerInvariant() -cne $TarSha256){throw 'Fixture transport archive changed'}
  & tar.exe -xf $tar -C $backup
  if($LASTEXITCODE -ne 0){throw 'Fixture archive extraction failed'}
  $dest=Join-Path $temp ('AuthWire-JournalRestore-'+[guid]::NewGuid().ToString('N'));New-FixturePrivateDirectory $dest
  Assert-FixtureRejection {Restore-AuthWireWriteJournalEvidence $backup $dest ('0'*64) $ScopeSha256} 'JOURNAL_BACKUP_MANIFEST_CHANGED'
  Assert-FixtureRejection {Restore-AuthWireWriteJournalEvidence $backup $dest $ExpectedManifestSha256 ('0'*64)} 'JOURNAL_BACKUP_SCOPE_REJECTED'
  $record=Join-Path $backup 'data\write-lifecycle\000001\poll-sent.json';$old=[IO.File]::ReadAllBytes($record)
  try{
   [IO.File]::AppendAllText($record,' ')
   Assert-FixtureRejection {Restore-AuthWireWriteJournalEvidence $backup $dest $ExpectedManifestSha256 $ScopeSha256} 'JOURNAL_BACKUP_TREE_CHANGED'
  }finally{[IO.File]::WriteAllBytes($record,$old)}
  if(Get-ChildItem -LiteralPath $dest -Force){throw 'Invalid evidence wrote a destination file'}
  $result=Restore-AuthWireWriteJournalEvidence $backup $dest $ExpectedManifestSha256 $ScopeSha256
  if(-not $result.Quarantined -or $result.TreeSha256 -cne $TreeSha256 -or $result.Files -ne 5 -or
     -not (Test-Path -LiteralPath (Join-Path $dest 'write-lifecycle\000002') -PathType Container)){throw 'Restored evidence does not match the source'}
  Assert-FixtureRejection {Restore-AuthWireWriteJournalEvidence $backup $dest $ExpectedManifestSha256 $ScopeSha256} 'JOURNAL_BACKUP_DESTINATION_NOT_EMPTY'
  Write-Output 'AUTHWIRE_JOURNAL_BACKUP_RESTORE_OK synthetic=true quarantined=true files=5'
 }
}finally{
 if($source -and (Test-Path -LiteralPath $source)){Remove-Item -LiteralPath $source -Recurse -Force}
 Remove-Item -LiteralPath $temp -Recurse -Force
}
