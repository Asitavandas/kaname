#Requires -Version 5.1
$ErrorActionPreference='Stop';Set-StrictMode -Version 2
$step='load';$root=$PSScriptRoot;$out=Join-Path $root 'output-junction-20261122';$rsa=$null;$key=$null;$session=$null;$csrf=$null;$cred=$null
try{
 $active='C:\Program Files\AuthWire-Connector-4c23eebe071546d188eea2e96ad7ee46'
 $c=Get-Content -LiteralPath (Join-Path $active 'service.json') -Raw|ConvertFrom-Json
 if($c.ReleaseId -cne '21d54b36-75e0-4834-93d3-886d675bec79'){throw 'RECOVERY_RELEASE_CHANGED'}
 . (Join-Path $active 'Test-AuthWireDeploymentCandidate.ps1') -LibraryOnly
 foreach($file in @('Compare-AuthWireSigningKeyAcl.ps1','ConnectorChannelTypes.ps1','ConnectorChannelKey.ps1','New-AuthWireConnectorHealthProof.ps1','Invoke-AuthWireConnectorProbeJob.ps1','Invoke-AuthWireCandidateJob.ps1','DeploymentScope.ps1','Invoke-AuthWireScopeJob.ps1','CombinedCandidateContent.ps1','Invoke-AuthWireCombinedJob.ps1','CombinedDeploymentScope.ps1','Invoke-AuthWireCombinedScopeJob.ps1','SysvolInventory.ps1','CombinedStagingPreview.ps1','Invoke-AuthWireStagingPreviewJob.ps1','StagingFilesystem.ps1','StagingWritePreclaim.ps1','StagingWriteTransport.ps1','StagingWriteConsumption.ps1','StagingWriteProcess.ps1','StagingWriteExecution.ps1','StagingWriteResult.ps1','StagingWriteCycle.ps1','StagingRollbackEvidence.ps1','StagingRollbackAuthorization.ps1','StagingRollbackExecution.ps1','StagingRollbackResult.ps1','StagingWritePollRecord.ps1','StagingWriteLifecycle.ps1')){. (Join-Path $active $file)}

 $module=Join-Path $root 'StagingFilesystem-Junction.ps1'
 $sig=Get-AuthenticodeSignature -LiteralPath $module
 if($sig.Status -ne 'Valid' -or $sig.SignerCertificate.Thumbprint -cne $c.PublisherThumbprint){throw 'JUNCTION_SOURCE_SIGNATURE_REJECTED'}
 $body=([IO.File]::ReadAllText($module) -split '(?m)^# SIG # Begin signature block')[0].Replace("`r`n","`n").TrimEnd([char]13,[char]10)+"`n"
 if((Get-AuthWireCandidateHash ([Text.UTF8Encoding]::new($false).GetBytes($body))) -cne 'af98b69852ae3a733cbf77759d40d60b8d39b2dbec230a446b5b7e80c0dde0c8'){throw 'JUNCTION_SOURCE_PIN_REJECTED'}
 . $module
 Assert-AuthWireWriteServiceConfigFields $c
 $b=@{};foreach($p in $c.Binding.PSObject.Properties){$b[$p.Name]=$p.Value}
 $identity=[Security.Principal.WindowsIdentity]::GetCurrent();try{if($identity.User.Value -cne $b.service_sid){throw 'RECOVERY_IDENTITY_CHANGED'}}finally{$identity.Dispose()}
 $key=[Security.Cryptography.CngKey]::Open($c.KeyName,[Security.Cryptography.CngProvider]::MicrosoftSoftwareKeyStorageProvider,[Security.Cryptography.CngKeyOpenOptions]::MachineKey)
 $rsa=[Security.Cryptography.RSACng]::new($key)
 $keyPath=Join-Path (Join-Path $env:ProgramData 'Microsoft\Crypto\Keys') $key.UniqueName
 if(-not (Compare-AuthWireSigningKeyAcl $c.ExpectedKeySddl (Get-Acl -LiteralPath $keyPath).Sddl).AclEquivalent){throw 'RECOVERY_KEY_ACL_CHANGED'}
 Initialize-AuthWireStagingFilesystemTypes
 Initialize-AuthWireChannelTypes
 Initialize-AuthWireWriteTransportTypes
 $journal=Get-AuthWireStagingWriteJournalRoot $b


 $job='733fc751-202d-448a-af68-0bea09c2aeb4'
 $resultPath=Join-Path $out 'observation.json'
 if(Test-Path -LiteralPath $resultPath){throw 'READ_EXISTING_JUNCTION_OBSERVATION'}
 $validated=Read-AuthWireAuthorizedStageIntentEvidence $journal $job $b $c.ReleaseId $rsa
 $offer=$validated.Authorization.Offer;$intent=$validated.Intent;$target=$offer.target.scope_target
 $sourceRoot=$intent.live_context.source_root;$gpoRoot=$intent.live_context.gpo_root
 $pins=[AuthWire.Staging.TreeLeaseV1]::new();$source=$null
 try {
  $step='pin-gpo';Add-AuthWireStagingGpoPins $pins $gpoRoot $gpoRoot;Add-AuthWireStagingGpoPins $pins ([IO.Path]::Combine($gpoRoot,'Machine')) $gpoRoot
  $step='pin-source';$pins.PinAncestors($sourceRoot);$pins.PinAncestors($journal)
  $source=[AuthWire.Staging.TreeLeaseV1]::Tree($sourceRoot,$false)
  $rows=Get-AuthWireStagingFilesystemRows $source
  $files=@(foreach($r in $rows|Where-Object Kind -eq 'file'){[pscustomobject][ordered]@{Path=$r.Path;Size=[long]$r.Size;Sha256=$r.Sha256;Sddl=$r.Sddl}})
  $inventory=Get-AuthWireSysvolInventory $gpoRoot
  $preview=$offer.target.preview_record
  $plan=New-AuthWireCombinedStagingPlanCore $target $files $inventory $preview.Preview.scope_observations_sha256 $preview.Preview.checked_at
  if($plan.PreviewSha256 -cne $preview.PreviewSha256){throw 'PINNED_PREVIEW_CHANGED'}
  $step='fresh-ad'
  Import-Module ActiveDirectory -ErrorAction Stop;Import-Module GroupPolicy -ErrorAction Stop
  $domain=Get-ADDomain -Identity $target.domain -Server $target.domain -ErrorAction Stop
  if([string]$domain.PDCEmulator -cne $intent.live_context.pdc -or $domain.DNSRoot -cne $target.domain){throw 'PDC_CHANGED'}
  $fresh=Get-AuthWireCombinedStagingPreview $target $b $c.PublisherThumbprint $c.BaseUrl
  $fresh.Preview.checked_at=$preview.Preview.checked_at;$fresh.Preview.expires_at=$preview.Preview.expires_at
  if((Get-AuthWireWritePreviewHash $fresh.Preview) -cne $preview.PreviewSha256){throw 'FRESH_BUSINESS_OBSERVATIONS_CHANGED'}
  $op=Join-Path $journal $intent.filesystem_operation_id
  $destination=Join-Path $gpoRoot $preview.Preview.relative_destination.Replace('/','\')
  if(Test-Path -LiteralPath $op){throw 'ENGINE_JOURNAL_PRESENT_KEEP_UNDER_REVIEW'}
  if(Test-Path -LiteralPath $destination){throw 'DESTINATION_PRESENT_KEEP_UNDER_REVIEW'}
  if(-not (Test-Path -LiteralPath (Join-Path $journal ('gpo-'+$target.gpo_id+'.json')))){throw 'REVIEW_LOCK_MISSING'}
  $observed=[pscustomobject][ordered]@{format='AuthWireLocalSysvolJunctionObservationV1';job_id=$job;gpo_id=$target.gpo_id;scope=(Get-AuthWireJobScope $b);release_id=$c.ReleaseId;module_source_sha256='af98b69852ae3a733cbf77759d40d60b8d39b2dbec230a446b5b7e80c0dde0c8';runtime_sid=$b.service_sid;baseline_inventory_sha256=$inventory.Sha256;approved_preview_sha256=$preview.PreviewSha256;pinned_preview_sha256=$plan.PreviewSha256;source_file_count=$files.Count;fresh_business_observations_match=$true;filesystem_intent_present=$true;engine_operation_directory_absent=$true;staged_destination_absent=$true;gpo_lock_preserved=$true;can_apply_gpo=$false;read_only=$true;observed_at=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()}
  $frame=[Text.Encoding]::ASCII.GetBytes("AUTHWIRE-LOCAL-SYSVOL-JUNCTION-OBSERVATION-V1`n"+(Get-AuthWireScopeDataHash $observed)+"`n")
  $signature=[Convert]::ToBase64String($rsa.SignData($frame,[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1))
  if(-not $rsa.VerifyData($frame,[Convert]::FromBase64String($signature),[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1)){throw 'OBSERVATION_SIGNATURE_FAILED'}
  Write-AuthWireStagingJournal $resultPath ([pscustomobject]@{Body=$observed;Signature=$signature})
 }finally{if($source){$source.Dispose()};$pins.Dispose()}
}catch{
 [IO.File]::WriteAllText((Join-Path $out 'failure.json'),(@{status='requires_review';step=$step;message=$_.Exception.GetBaseException().Message;line=$_.InvocationInfo.ScriptLineNumber;at=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()}|ConvertTo-Json -Compress),[Text.UTF8Encoding]::new($false));exit 1
}finally{if($rsa){$rsa.Dispose()};if($key){$key.Dispose()}}
