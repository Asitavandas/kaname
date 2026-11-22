#Requires -Version 5.1
# Administrator-reviewed diagnostic. No grant, engine, claim or transport call.
$ErrorActionPreference='Stop';$ProgressPreference='SilentlyContinue';Set-StrictMode -Version 2
$out='C:\ProgramData\AuthWire-G01-ColdRead-20261122\output\profile-original.json'
if(Test-Path -LiteralPath $out){throw 'DIAGNOSTIC_ALREADY_RECORDED'}
$root='C:\Program Files\AuthWire-Connector-4c23eebe071546d188eea2e96ad7ee46'
$journal='C:\ProgramData\AuthWire-WriteJournal-4c23eebe071546d188eea2e96ad7ee46'
$job=Join-Path $journal 'c292e179-5dc7-4f24-afcd-61df41d8346c'
$script:timings=New-Object 'System.Collections.Generic.List[object]'
$clock=[Diagnostics.Stopwatch]::StartNew();$rsa=$null;$key=$null
try{
 $t=$clock.ElapsedMilliseconds
 . (Join-Path $root 'Test-AuthWireDeploymentCandidate.ps1') -LibraryOnly
 foreach($f in @('Compare-AuthWireSigningKeyAcl.ps1','New-AuthWireConnectorHealthProof.ps1','Invoke-AuthWireConnectorProbeJob.ps1','Invoke-AuthWireCandidateJob.ps1','DeploymentScope.ps1','Invoke-AuthWireScopeJob.ps1','CombinedCandidateContent.ps1','Invoke-AuthWireCombinedJob.ps1','CombinedDeploymentScope.ps1','Invoke-AuthWireCombinedScopeJob.ps1','SysvolInventory.ps1','CombinedStagingPreview.ps1','StagingFilesystem.ps1','StagingWritePreclaim.ps1','StagingWriteTransport.ps1','StagingWriteConsumption.ps1','StagingWriteExecution.ps1')){. (Join-Path $root $f)}
 $script:timings.Add([pscustomobject]@{name='signed_source_load';ms=$clock.ElapsedMilliseconds-$t})
 $t=$clock.ElapsedMilliseconds;Initialize-AuthWireStagingFilesystemTypes;Initialize-AuthWireCandidateTypes
 $script:timings.Add([pscustomobject]@{name='native_types';ms=$clock.ElapsedMilliseconds-$t})
 $c=ConvertFrom-AuthWireCandidateJson (Read-AuthWireCandidateBytes (Join-Path $root 'service.json') 16384)
 if($c.ReleaseId -cne 'b9e84cf9-b560-4c4f-b729-921bdf03afe6' -or $c.RootPath -cne $root){throw 'DIAGNOSTIC_PACKAGE_CHANGED'}
 $binding=@{};foreach($p in $c.Binding.PSObject.Properties){$binding[$p.Name]=$p.Value}
 $identity=[Security.Principal.WindowsIdentity]::GetCurrent();try{if($identity.User.Value -cne $binding.service_sid -or ([Security.Principal.WindowsPrincipal]::new($identity)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){throw 'DIAGNOSTIC_IDENTITY'}}finally{$identity.Dispose()}
 $original=@{};foreach($n in @('grant-consumed.json','filesystem-intent.json','result-outbox.json')){$original[$n]=(Get-FileHash -LiteralPath (Join-Path $job $n) -Algorithm SHA256).Hash}
 $offer=(Read-AuthWireStagingJournal (Join-Path $job 'offer.json')).offer
 $live=Read-AuthWireStagingJournal (Join-Path $job 'stage-preflight.json')
 $inventoryBefore=(Get-AuthWireSysvolInventory $live.gpo_root).Sha256
 if($inventoryBefore -cne 'b694d3170907045f688ddb7490933815f29eeff21b4e682b795487233ffebec6'){throw 'DIAGNOSTIC_BASELINE_CHANGED'}
 $t=$clock.ElapsedMilliseconds
 $key=[Security.Cryptography.CngKey]::Open($c.KeyName,[Security.Cryptography.CngProvider]::MicrosoftSoftwareKeyStorageProvider,[Security.Cryptography.CngKeyOpenOptions]::MachineKey);$rsa=[Security.Cryptography.RSACng]::new($key)
 $keyPath=Join-Path (Join-Path ([Environment]::GetFolderPath('CommonApplicationData')) 'Microsoft\Crypto\Keys') $key.UniqueName
 if(-not (Compare-AuthWireSigningKeyAcl $c.ExpectedKeySddl (Get-Acl -LiteralPath $keyPath).Sddl).AclEquivalent){throw 'DIAGNOSTIC_KEY_ACL'}
 $script:timings.Add([pscustomobject]@{name='key_open_acl';ms=$clock.ElapsedMilliseconds-$t})
 $t=$clock.ElapsedMilliseconds;Import-Module ActiveDirectory -ErrorAction Stop;Import-Module GroupPolicy -ErrorAction Stop
 $script:timings.Add([pscustomobject]@{name='directory_module_import';ms=$clock.ElapsedMilliseconds-$t})
 $script:profileBodies=@{}
 foreach($name in @('Get-AuthWireCandidatePublicSigner','Test-AuthWireJobCandidateContent','Test-AuthWireJobCombinedContent','Get-AuthWireScopeContext','Get-AuthWireCombinedScopeContext','Get-AuthWireCombinedStagingLedger','Get-AuthWireScopeData','Get-AuthWireSysvolInventory','Get-AuthWireCombinedStagingPreview')){
  $script:profileBodies[$name]=(Get-Command $name -CommandType Function).ScriptBlock
  $wrapper='param() $w=[Diagnostics.Stopwatch]::StartNew();try{& $script:profileBodies['''+$name+'''] @args}finally{$script:timings.Add([pscustomobject]@{name='''+$name+''';ms=$w.ElapsedMilliseconds})}'
  Set-Item -LiteralPath ('Function:\'+$name) -Value ([scriptblock]::Create($wrapper))
 }
 # Reconstruct only read operations. Original expired preview is never renewed.
 # The final normal expiry rejection is expected; no stage adapter is invoked.
 $t=$clock.ElapsedMilliseconds;$expiryRejected=$false
 try{$null=Get-AuthWireWriteStageLiveContext $offer $binding $c.PublisherThumbprint $c.BaseUrl;throw 'DIAGNOSTIC_EXPECTED_EXPIRY_REJECTION'}catch{if($_.Exception.Message -cne 'STAGING_PREVIEW_EXPIRED'){throw};$expiryRejected=$true}
 $contextMs=$clock.ElapsedMilliseconds-$t
 $inventoryAfter=(Get-AuthWireSysvolInventory $live.gpo_root).Sha256
 foreach($n in $original.Keys){if((Get-FileHash -LiteralPath (Join-Path $job $n) -Algorithm SHA256).Hash -cne $original[$n]){throw 'DIAGNOSTIC_ORIGINAL_RECORD_CHANGED'}}
 if($inventoryAfter -cne $inventoryBefore){throw 'DIAGNOSTIC_SYSVOL_CHANGED'}
 $result=[ordered]@{format='AuthWireColdReadDiagnosticV1';status='observed';release=$c.ReleaseId;checked_at=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds();identity=$binding.service_sid;context_ms=$contextMs;total_ms=$clock.ElapsedMilliseconds;timings=@($script:timings.ToArray());expired_preview_rejected=$expiryRejected;original_records_unchanged=$true;inventory_sha256=$inventoryAfter;new_job_created=$false;engine_invoked=$false;authorization_extended=$false}
 [IO.File]::WriteAllText($out,($result|ConvertTo-Json -Depth 6),[Text.UTF8Encoding]::new($false))
}catch{
 [IO.File]::WriteAllText($out,([ordered]@{status='diagnostic_failed';error=$_.Exception.Message;line=$_.InvocationInfo.ScriptLineNumber;timings=@($script:timings.ToArray())}|ConvertTo-Json -Depth 6),[Text.UTF8Encoding]::new($false));exit 20
}finally{if($rsa){$rsa.Dispose()};if($key){$key.Dispose()}}
