#Requires -Version 5.1
$ErrorActionPreference='Stop';Set-StrictMode -Version 2
$root=$PSScriptRoot;$out=Join-Path $root 'diagnostic-output';$rsa=$null;$key=$null;$session=$null;$csrf=$null
try{
 $active='C:\Program Files\AuthWire-Connector-4c23eebe071546d188eea2e96ad7ee46'
 $c=Get-Content -LiteralPath (Join-Path $active 'service.json') -Raw|ConvertFrom-Json
 if($c.ReleaseId -cne 'd539aa00-4acf-4b22-a952-4b24d57e0cde'){throw 'RECOVERY_RELEASE_CHANGED'}
 . (Join-Path $active 'Test-AuthWireDeploymentCandidate.ps1') -LibraryOnly
 foreach($file in @('Compare-AuthWireSigningKeyAcl.ps1','ConnectorChannelTypes.ps1','ConnectorChannelKey.ps1','New-AuthWireConnectorHealthProof.ps1','Invoke-AuthWireConnectorProbeJob.ps1','Invoke-AuthWireCandidateJob.ps1','DeploymentScope.ps1','Invoke-AuthWireScopeJob.ps1','CombinedCandidateContent.ps1','Invoke-AuthWireCombinedJob.ps1','CombinedDeploymentScope.ps1','Invoke-AuthWireCombinedScopeJob.ps1','SysvolInventory.ps1','CombinedStagingPreview.ps1','StagingFilesystem.ps1','StagingWritePreclaim.ps1','StagingWriteTransport.ps1','StagingWriteConsumption.ps1','StagingWriteProcess.ps1','StagingWriteExecution.ps1','StagingWriteResult.ps1','StagingWriteCycle.ps1','StagingRollbackEvidence.ps1','StagingRollbackAuthorization.ps1','StagingRollbackExecution.ps1','StagingRollbackResult.ps1','StagingWritePollRecord.ps1','StagingWriteLifecycle.ps1','StagingRollbackEvidence.ps1','StagingRollbackAuthorization.ps1')){. (Join-Path $active $file)}
 Assert-AuthWireWriteServiceConfigFields $c
 $b=@{};foreach($p in $c.Binding.PSObject.Properties){$b[$p.Name]=$p.Value}
 $identity=[Security.Principal.WindowsIdentity]::GetCurrent();try{if($identity.User.Value -cne $b.service_sid){throw 'RECOVERY_IDENTITY_CHANGED'}}finally{$identity.Dispose()}
 $key=[Security.Cryptography.CngKey]::Open($c.KeyName,[Security.Cryptography.CngProvider]::MicrosoftSoftwareKeyStorageProvider,[Security.Cryptography.CngKeyOpenOptions]::MachineKey)
 $rsa=[Security.Cryptography.RSACng]::new($key)
 $keyPath=Join-Path (Join-Path $env:ProgramData 'Microsoft\Crypto\Keys') $key.UniqueName
 if(-not (Compare-AuthWireSigningKeyAcl $c.ExpectedKeySddl (Get-Acl -LiteralPath $keyPath).Sddl).AclEquivalent){throw 'RECOVERY_KEY_ACL_CHANGED'}
 Initialize-AuthWireStagingFilesystemTypes
 $journal=Get-AuthWireStagingWriteJournalRoot $b


 $j=Join-Path $journal '68dfc2b5-ea6a-483a-876e-c33bfabf765b'
 $state=Read-AuthWireStagingJournal (Join-Path $journal 'write-lifecycle\000133\poll-response.json')
 $saved=Read-AuthWireRollbackOfferAt $journal '68dfc2b5-ea6a-483a-876e-c33bfabf765b' $b $c.ReleaseId $state.received_at
 $origin=Read-AuthWireRollbackOriginEvidenceAt $saved.Offer $b $c.ReleaseId $rsa $state.received_at
 $clock=[Diagnostics.Stopwatch]::StartNew()
 $directory=Get-AuthWireRollbackDirectoryObservation $saved.Offer $b $c.PublisherThumbprint $c.BaseUrl
 $oneMs=$clock.ElapsedMilliseconds
 $generic=[AuthWire.Staging.TreeLeaseV1]::new();$genericCode=''
 try{$generic.PinAncestors($directory.gpo_root)}catch{$genericCode=$_.Exception.GetBaseException().Message}finally{$generic.Dispose()}
 $pins=[AuthWire.Staging.TreeLeaseV1]::new();$tree=$null
 try{
  Add-AuthWireStagingGpoPins $pins $directory.gpo_root $directory.gpo_root
  Add-AuthWireStagingGpoPins $pins ([IO.Path]::Combine($directory.gpo_root,'Machine')) $directory.gpo_root
  $dest=[IO.Path]::Combine($directory.gpo_root,$origin.Intent.relative_destination.Replace('/','\'))
  $tree=[AuthWire.Staging.TreeLeaseV1]::Tree($dest,$false)
  $rows=Get-AuthWireStagingFilesystemRows $tree
  if((Get-AuthWireStagingFilesystemDigest $rows) -cne $origin.Complete.tree_sha256){throw 'DIAGNOSTIC_STAGED_TREE_DRIFT'}
  $inventory=Get-AuthWireSysvolInventory $directory.gpo_root;$relative=$origin.Intent.relative_destination
  $outside=@($inventory.Entries|Where-Object {$_.Path -cne $relative -and -not $_.Path.StartsWith($relative+'/',[StringComparison]::Ordinal)})
  if((Get-AuthWireScopeDataHash $outside) -cne $origin.Intent.baseline_sha256){throw 'DIAGNOSTIC_OUTSIDE_DRIFT'}
  $again=Get-AuthWireRollbackDirectoryObservation $saved.Offer $b $c.PublisherThumbprint $c.BaseUrl
  if((Get-AuthWireWriteHash $again) -cne (Get-AuthWireWriteHash $directory)){throw 'DIAGNOSTIC_DIRECTORY_DRIFT'}
  $body=[pscustomobject]@{status='read_only_verified';stage_id='e195a1c3-ce02-46bc-869a-6063bba14f9f';rollback_id='68dfc2b5-ea6a-483a-876e-c33bfabf765b';original_offer_observed_at=$state.received_at;generic_pin_error=$genericCode;first_directory_ms=$oneMs;both_directory_and_tree_ms=$clock.ElapsedMilliseconds;staged_file_count=@($rows|Where-Object Kind -ceq 'file').Count;tree_sha256=$origin.Complete.tree_sha256;baseline_sha256=$origin.Intent.baseline_sha256;outside_unchanged=$true;can_delete=$false;at=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()}
  Write-AuthWireStagingJournal (Join-Path $out 'rollback-readonly-result.json') $body
 }finally{if($tree){$tree.Dispose()};$pins.Dispose()}
}catch{
 [IO.File]::WriteAllText((Join-Path $out 'rollback-readonly-failure.json'),(@{code=$_.Exception.GetBaseException().Message;stack=$_.ScriptStackTrace}|ConvertTo-Json -Compress),[Text.UTF8Encoding]::new($false));exit 1
}finally{if($rsa){$rsa.Dispose()};if($key){$key.Dispose()}}
