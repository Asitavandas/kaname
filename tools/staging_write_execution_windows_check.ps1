# Hosted Windows only: signed real child + actual CNG/SMB/NTFS.
# AD/content observations and the SYSVOL namespace resolver are fixture shims.
# Receipts are seeded locally; the separate transport fixture tests real TLS/core grants.
$ErrorActionPreference='Stop';Set-StrictMode -Version 2
if($env:RUNNER_ENVIRONMENT -ne 'github-hosted'){throw 'Hosted fixture only'}
$lib=Join-Path $PSScriptRoot '..\windows\connector'
$root=[IO.Path]::GetFullPath((Join-Path $env:TEMP ('aw-stage-execution-'+[guid]::NewGuid().ToString('N'))))
$package=Join-Path $root 'signed-package';$share=$null;$startedServer=$false;$key=$null;$rsa=$null;$signer=$null;$public=$null
$journal=$null;$candidateBase=$null;$oldModulePath=$env:PSModulePath;$script:checks=0
function Check($v,[string]$name){if(-not $v){throw ('EXECUTION_FIXTURE:'+ $name)};$script:checks++}
function Reject([scriptblock]$fn,[string]$name){$failed=$false;try{& $fn|Out-Null}catch{$failed=$true};Check $failed $name}
function Clone($v){return ($v|ConvertTo-Json -Depth 15 -Compress|ConvertFrom-Json)}
function PrivateRoot([string]$path){$null=New-Item -ItemType Directory -Path $path;$acl=[Security.AccessControl.DirectorySecurity]::new();$acl.SetSecurityDescriptorSddlForm('O:BAG:BAD:P(A;OICI;FA;;;SY)(A;OICI;FA;;;BA)');Set-Acl -LiteralPath $path -AclObject $acl}
try{
 PrivateRoot $root;PrivateRoot $package
 $signer=New-SelfSignedCertificate -Type CodeSigningCert -Subject ('CN=AuthWire-Stage-Fixture-'+[guid]::NewGuid().ToString('N')) -CertStoreLocation Cert:\LocalMachine\My -KeyAlgorithm RSA -KeyLength 3072 -KeyExportPolicy NonExportable -NotAfter (Get-Date).AddDays(1)
 $public=[Security.Cryptography.X509Certificates.X509Certificate2]::new($signer.Export([Security.Cryptography.X509Certificates.X509ContentType]::Cert))
 foreach($name in @('Root','TrustedPublisher')){$s=[Security.Cryptography.X509Certificates.X509Store]::new($name,'LocalMachine');try{$s.Open('ReadWrite');$s.Add($public)}finally{$s.Close()}}
 $files=@('Test-AuthWireDeploymentCandidate.ps1','Compare-AuthWireSigningKeyAcl.ps1','New-AuthWireConnectorHealthProof.ps1','Invoke-AuthWireConnectorProbeJob.ps1','Invoke-AuthWireCandidateJob.ps1','DeploymentScope.ps1','Invoke-AuthWireScopeJob.ps1','CombinedCandidateContent.ps1','Invoke-AuthWireCombinedJob.ps1','CombinedDeploymentScope.ps1','Invoke-AuthWireCombinedScopeJob.ps1','SysvolInventory.ps1','CombinedStagingPreview.ps1','StagingFilesystem.ps1','StagingWritePreclaim.ps1','StagingWriteTransport.ps1','StagingWriteConsumption.ps1','StagingWriteExecution.ps1','Read-AuthWireStagingWritePreflight.ps1','Invoke-AuthWireStagingWriteChild.ps1')
 foreach($name in $files){[IO.File]::WriteAllBytes((Join-Path $package $name),[IO.File]::ReadAllBytes((Join-Path $lib $name)))}
 # Test production namespace derivation BEFORE replacing only its environment.
 . (Join-Path $package 'Test-AuthWireDeploymentCandidate.ps1') -LibraryOnly
 . (Join-Path $package 'StagingWritePreclaim.ps1')
 $pathTarget=[pscustomobject]@{gpo_id=[guid]::NewGuid().ToString('D');domain='lab.example'}
 Check ((Get-AuthWireWriteGpoPath 'dc01.lab.example' $pathTarget) -ceq ('\\dc01.lab.example\SYSVOL\lab.example\Policies\{'+$pathTarget.gpo_id+'}')) 'production SYSVOL path derived exactly'
 foreach($bad in @('evil.example','dc01.lab.example\outside','DC01.lab.example','dc01.lab.example:445','dc01..lab.example')){Reject {Get-AuthWireWriteGpoPath $bad $pathTarget} 'production namespace refuses other hosts or path injection'}
 $preclaimShim=@'

# Fixture-only signed namespace/AD/content observations. No production hook.
function Get-AuthWireWriteGpoPath([string]$Pdc,$Target){
 $fixture=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'fixture.json') -Raw|ConvertFrom-Json
 if($Target.gpo_id -cne $fixture.gpo_id){throw 'FIXTURE_WRONG_GPO'}
 return $fixture.gpo_root
}
function Get-AuthWireWriteStageLiveContext($Offer,[hashtable]$Binding,[string]$Publisher,[string]$BaseUrl){
 $fixture=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'fixture.json') -Raw|ConvertFrom-Json
 $v=$fixture.live;$v.checked_at=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
 if($fixture.case -ceq 'drift'){$v.pdc='dc02.lab.example'}
 return $v
}
'@
 [IO.File]::AppendAllText((Join-Path $package 'StagingWritePreclaim.ps1'),$preclaimShim)
 $engineShim=@'

# Fixture-only fault injection; production adapter and child remain unchanged.
$script:FixtureEngineBody=${function:Invoke-AuthWireStagingFilesystemStage}
$script:FixtureWriterBody=${function:Write-AuthWireStagingJournal}
function Write-AuthWireStagingJournal([string]$Path,$Value){
 $fixture=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'fixture.json') -Raw|ConvertFrom-Json
 $name=[IO.Path]::GetFileName($Path)
 if($fixture.case -ceq 'partial' -and $name -ceq 'complete.json'){throw 'FIXTURE_COMPLETION_DISK_FAILURE'}
 if($fixture.case -ceq 'launch_disk' -and $name -ceq 'stage-launch.json'){& $script:FixtureWriterBody $Path $Value;throw 'FIXTURE_LAUNCH_DISK_FAILURE'}
 & $script:FixtureWriterBody $Path $Value
}
function Invoke-AuthWireStagingFilesystemStage {
 param($Target,$PreviewRecord,[string]$ApprovedPreviewSha256,[string]$SourceRoot,[string]$GpoRoot,[string]$JournalRoot,[string]$OperationId,[string]$ProtectedGpoId,[long]$NotAfter=0)
 $fixture=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'fixture.json') -Raw|ConvertFrom-Json
 if($NotAfter -ne $fixture.expires_at){throw 'FIXTURE_GRANT_EXPIRY_NOT_FORWARDED'}
 if($fixture.case -ceq 'timeout'){Start-Sleep -Seconds 25}
 $r=& $script:FixtureEngineBody @PSBoundParameters
 if($fixture.case -ceq 'bad_result'){$r.Phase='wrong'}
 return $r
}
'@
 [IO.File]::AppendAllText((Join-Path $package 'StagingFilesystem.ps1'),$engineShim)
 $modules=Join-Path $package 'fixture-modules';$null=New-Item -ItemType Directory -Path $modules
 foreach($name in @('ActiveDirectory','GroupPolicy')){
  $directory=Join-Path $modules $name;$null=New-Item -ItemType Directory -Path $directory
  $file=Join-Path $directory ($name+'.psm1');[IO.File]::WriteAllText($file,'# Fixture only: no AD forest or production commands.')
  Check ((Set-AuthenticodeSignature -FilePath $file -Certificate $signer -HashAlgorithm SHA256).Status -eq 'Valid') 'signed fixture module'
 }
 $env:PSModulePath=$modules+';'+$oldModulePath
 foreach($name in $files){Check ((Set-AuthenticodeSignature -FilePath (Join-Path $package $name) -Certificate $signer -HashAlgorithm SHA256).Status -eq 'Valid') ('signed dependency '+$name)}
 . (Join-Path $package 'Test-AuthWireDeploymentCandidate.ps1') -LibraryOnly
 foreach($name in $files|Where-Object {$_ -cnotin @('Test-AuthWireDeploymentCandidate.ps1','Read-AuthWireStagingWritePreflight.ps1','Invoke-AuthWireStagingWriteChild.ps1')}){. (Join-Path $package $name)}
 Initialize-AuthWireStagingFilesystemTypes;Initialize-AuthWireScopeProcess
 $sid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value;$domainSid=$sid.Substring(0,$sid.LastIndexOf('-'))
 $connector=[guid]::NewGuid().ToString('D');$release=[guid]::NewGuid().ToString('D')
 $parameters=[Security.Cryptography.CngKeyCreationParameters]::new();$parameters.Provider=[Security.Cryptography.CngProvider]::MicrosoftSoftwareKeyStorageProvider
 $parameters.KeyCreationOptions=[Security.Cryptography.CngKeyCreationOptions]::MachineKey;$parameters.ExportPolicy=[Security.Cryptography.CngExportPolicies]::None;$parameters.KeyUsage=[Security.Cryptography.CngKeyUsages]::Signing
 $parameters.Parameters.Add([Security.Cryptography.CngProperty]::new('Length',[BitConverter]::GetBytes(3072),[Security.Cryptography.CngPropertyOptions]::None))
 $keyName='AuthWire-Channel-'+([guid]$connector).ToString('N')+'-'+[guid]::NewGuid().ToString('N')
 $key=[Security.Cryptography.CngKey]::Create([Security.Cryptography.CngAlgorithm]::Rsa,$keyName,$parameters);$rsa=[Security.Cryptography.RSACng]::new($key)
 $b=@{instance_id=[guid]::NewGuid().ToString('D');connector_id=$connector;generation=1;host_guid=[guid]::NewGuid().ToString('D');host_fqdn=([Environment]::MachineName.ToLowerInvariant()+'.lab.example');service_sid=$sid;appliance_fqdn='kaname.lab.example';appliance_tls_sha256=('a'*64);channel_key_sha256=(Get-AuthWireChannelPublicKeyId $rsa)}
 $journal=Get-AuthWireStagingWriteJournalRoot $b;if(Test-Path -LiteralPath $journal){throw 'Unexpected fixture journal'};PrivateRoot $journal
 $candidateBase=Join-Path $env:ProgramData ('AuthWire-CombinedCandidates-'+([guid]$connector).ToString('N'));if(Test-Path -LiteralPath $candidateBase){throw 'Unexpected fixture candidates'};PrivateRoot $candidateBase
 $keyPath=Join-Path (Join-Path $env:ProgramData 'Microsoft\Crypto\Keys') $key.UniqueName;$keyAcl=(Get-Acl -LiteralPath $keyPath).Sddl
 $config=@{Version=1;ReleaseId=$release;ServiceName=('AuthWireConnector-'+([guid]$connector).ToString('N'));AccountName=[Security.Principal.WindowsIdentity]::GetCurrent().Name;PublisherThumbprint=$signer.Thumbprint;BaseUrl='https://kaname.lab.example/';Binding=$b;KeyName=$keyName;ExpectedKeySddl=$keyAcl;RootPath=$package}
 [IO.File]::WriteAllText((Join-Path $package 'service.json'),($config|ConvertTo-Json -Depth 8 -Compress))
 $shareDirectory=Join-Path $root 'share';PrivateRoot $shareDirectory
 if((Get-Service LanmanServer).Status -ne 'Running'){Start-Service LanmanServer;$startedServer=$true}
 $share='aw-stage-execution-'+[guid]::NewGuid().ToString('N');$null=New-SmbShare -Name $share -Path $shareDirectory -FullAccess ([Security.Principal.WindowsIdentity]::GetCurrent().Name)
 $outcomes=@()
 foreach($case in @('success','drift','partial','bad_result','launch_disk','timeout')){
  $t=[pscustomobject][ordered]@{candidate_id=[guid]::NewGuid().ToString('D');network_candidate_id=[guid]::NewGuid().ToString('D');plan_id=[guid]::NewGuid().ToString('D');plan_version=1;gpo_id=[guid]::NewGuid().ToString('D');approval_sha256=('a'*64);network_manifest_sha256=('b'*64);manifest_sha256=('c'*64);draft_sha256=('d'*64);dependency_sha256=('e'*64);publisher_thumbprint=$signer.Thumbprint;machine_profile_id=[guid]::NewGuid().ToString('D');machine_profile_version=3;domain='lab.example';root_thumbprint=('f'*40);group_sid=($domainSid+'-1647');content_result_sha256=('2'*64);target_sids_sha256=('3'*64);target_count=1}
  $draft=[Text.Encoding]::ASCII.GetBytes('fixture never execute '+$case);$t.draft_sha256=Get-AuthWireCandidateHash $draft
  $source=Join-Path $candidateBase ($t.plan_id+'-v1-'+$t.draft_sha256+'-ab1a11c683810061');PrivateRoot $source
  foreach($name in @('enrollment','network')){$null=New-Item -ItemType Directory -Path (Join-Path $source $name)}
  foreach($name in Get-AuthWireCombinedStagingNames){$bytes=[Text.Encoding]::ASCII.GetBytes(('throw ''FIXTURE_ARTIFACT_MUST_NOT_EXECUTE'' # '+$name+' '+$case));if($name -ceq 'original-draft.zip'){$bytes=$draft};[IO.File]::WriteAllBytes((Join-Path $source $name),$bytes)}
  foreach($file in Get-ChildItem -LiteralPath $source -Recurse -File){$acl=[Security.AccessControl.FileSecurity]::new();$acl.SetSecurityDescriptorSddlForm('O:BAG:BAD:P(A;;FA;;;SY)(A;;FA;;;BA)(A;;0x120089;;;'+$sid+')');Set-Acl -LiteralPath $file.FullName -AclObject $acl}
  $t.manifest_sha256=Get-AuthWireCandidateHash ([IO.File]::ReadAllBytes((Join-Path $source 'signed-manifest.json')))
  $gpoLocal=Join-Path $shareDirectory ('{'+$t.gpo_id+'}');PrivateRoot $gpoLocal
  foreach($name in @('Machine','User')){$null=New-Item -ItemType Directory -Path (Join-Path $gpoLocal $name)}
  [IO.File]::WriteAllText((Join-Path $gpoLocal 'GPT.INI'),"[General]`r`nVersion=0`r`n");[IO.File]::WriteAllText((Join-Path $gpoLocal 'GPO.cmt'),'fixture marker')
  $gpo='\\localhost\'+$share+'\{'+$t.gpo_id+'}'
  $before=Get-AuthWireSysvolInventory $gpo
  $files=@(foreach($name in Get-AuthWireCombinedStagingNames){$file=Join-Path $source $name;[pscustomobject][ordered]@{Path=$name;Size=[long](Get-Item -LiteralPath $file).Length;Sha256=(Get-AuthWireCandidateHash ([IO.File]::ReadAllBytes($file)));Sddl=(Get-Acl -LiteralPath $file).Sddl}})
  $preview=New-AuthWireCombinedStagingPlanCore $t $files $before ('4'*64) ([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())
  $target=[pscustomobject]@{scope_target=$t;preview_record=$preview;preview_job_id=[guid]::NewGuid().ToString('D');preview_result_sha256=('5'*64);writer_release_id=$release;stage_receipt=$null}
  $id=[guid]::NewGuid().ToString('D');$request='1'*64;$scope=Get-AuthWireJobScope $b
  $intentFrame='AuthWireStagingWriteIntentV1'+"`n"+$scope+"`n"+$id+"`ncombined.filesystem.stage.v1`n"+(Get-AuthWireWriteHash $target)+"`n"
  $offer=[pscustomobject]@{format=1;request_id=$request;scope_sha256=$scope;job_id=$id;operation='combined.filesystem.stage.v1';lease_id=('6'*64);intent_sha256=(Get-AuthWireJobHash ([Text.Encoding]::ASCII.GetBytes($intentFrame)));expires_at=$preview.Preview.expires_at;target=$target;write_authorized=$false;can_apply_gpo=$false}
  $live=[pscustomobject]@{format='AuthWireWriteLiveContextV1';job_id=$id;intent_sha256=$offer.intent_sha256;target_sha256=(Get-AuthWireWriteHash $target);source_root=$source;gpo_root=$gpo;protected_gpo_id=[guid]::NewGuid().ToString('D');pdc='dc01.lab.example';checked_at=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds();can_apply_gpo=$false}
  $fixture=[pscustomobject]@{case='prepare';gpo_id=$t.gpo_id;gpo_root=$gpo;live=$live;expires_at=0}
  [IO.File]::WriteAllText((Join-Path $package 'fixture.json'),($fixture|ConvertTo-Json -Depth 12 -Compress))
  $null=Save-AuthWireStagingWriteOffer $offer $b $release $request $journal
  $job=Join-Path $journal $id;Write-AuthWireStagingJournal (Join-Path $job 'preflight.json') $live
  $proof=New-AuthWireStagingWriteClaim $journal $id $b $release $rsa
  $requestId=[Text.Encoding]::ASCII.GetString([Convert]::FromBase64String($proof.frame)).Split([char]10)[10]
  $sent=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds();$expiry=$sent+30
  $grant=[pscustomobject]@{format=1;request_id=$requestId;job_id=$id;operation=$offer.operation;intent_sha256=$offer.intent_sha256;target_sha256=(Get-AuthWireWriteHash $target);authorization_id=([guid]::NewGuid().ToString('N')+[guid]::NewGuid().ToString('N'));expires_at=$expiry;write_authorized=$true;can_apply_gpo=$false}
  $proofJson=Clone $proof;$proofHash=Get-AuthWireWriteHash $proofJson
  Write-AuthWireStagingJournal (Join-Path $job 'claim-sent.json') ([pscustomobject]@{format='AuthWireWriteClaimSentV1';job_id=$id;request_id=$requestId;proof_sha256=$proofHash;sent_at=$sent})
  Write-AuthWireStagingJournal (Join-Path $job 'authorization.json') ([pscustomobject]@{format='AuthWireWriteAuthorizationReceiptV1';binding_scope=$scope;release_id=$release;offer_sha256=(Get-AuthWireWriteHash $offer);preflight_sha256=(Get-AuthWireWriteHash $live);claim_proof_sha256=$proofHash;sent_at=$sent;received_at=$sent;grant=$grant})
  $fixture.expires_at=$expiry;[IO.File]::WriteAllText((Join-Path $package 'fixture.json'),($fixture|ConvertTo-Json -Depth 12 -Compress))
  $reserved=New-AuthWireAuthorizedFilesystemIntent $journal $id $b $release $rsa
  Check ($reserved.GrantConsumed -and -not $reserved.FilesystemWriteEnabled) 'real signed readonly intent child succeeded'
  $fixture.case=$case;[IO.File]::WriteAllText((Join-Path $package 'fixture.json'),($fixture|ConvertTo-Json -Depth 12 -Compress))
  $watch=[Diagnostics.Stopwatch]::StartNew();$failure='';$result=$null
  try{$result=Invoke-AuthWireAuthorizedFilesystemStage $journal $id $b $release $rsa}catch{$failure=$_.Exception.Message};$watch.Stop()
  $destination=Join-Path $gpo $preview.Preview.relative_destination.Replace('/','\')
  if($case -ceq 'success'){
   Check ($failure -ceq '' -and $result.FilesystemStaged -and -not $result.PeerResultSubmitted -and -not $result.CanApplyGpo -and -not $result.ArtifactExecuted) 'actual signed child stages without activation or artifact execution'
   Check (@(Get-ChildItem -LiteralPath $destination -Recurse -File).Count -eq 20) 'actual SMB contains twenty exact payload files'
   Check ((Get-AuthWireScopeDataHash (Read-AuthWireStagingJournal (Join-Path (Join-Path $journal $result.FilesystemOperationId) 'complete.json'))) -ceq $result.CompleteSha256) 'parent result binds actual completed engine journal'
   Check (Test-Path -LiteralPath (Join-Path $job 'execution-observed.json')) 'parent durable completion observation'
  }else{
   Check ($failure -ne '') ('failed stage surfaced '+$case)
   Check (-not (Test-Path -LiteralPath (Join-Path $job 'execution-observed.json'))) 'failed child never reported observed completion'
   if($case -cne 'launch_disk'){Check (Test-Path -LiteralPath (Join-Path $job 'execution-requires-review.json')) 'uncertain outcome recorded for review'}
   if($case -cin @('drift','launch_disk','timeout')){Check ((Get-AuthWireSysvolInventory $gpo).Sha256 -ceq $before.Sha256) 'refused or prewrite timeout preserves entire SMB baseline'}
   if($case -ceq 'partial'){
    Check (Test-Path -LiteralPath $destination) 'partial outcome never recursively cleaned'
    Check (Test-Path -LiteralPath (Join-Path (Join-Path $journal $reserved.FilesystemOperationId) 'intent.json')) 'actual engine intent retained on completion failure'
    Check (-not (Test-Path -LiteralPath (Join-Path (Join-Path $journal $reserved.FilesystemOperationId) 'complete.json'))) 'missing engine completion not fabricated'
   }
   if($case -ceq 'timeout'){Check ($watch.Elapsed.TotalSeconds -lt 23) 'signed writer hard deadline plus bounded cleanup'}
  }
  Check (Test-Path -LiteralPath (Join-Path $job 'stage-launch.json')) 'durable one-launch gate retained'
  Check (Test-Path -LiteralPath (Join-Path $journal ('gpo-'+$t.gpo_id+'.json'))) 'GPO lock retained after every result'
  $treeHash=(Get-AuthWireSysvolInventory $gpo).Sha256
  . (Join-Path $package 'StagingWriteExecution.ps1')
  Reject {Invoke-AuthWireAuthorizedFilesystemStage $journal $id $b $release $rsa} 'module reload cannot relaunch stage'
  Check ((Get-AuthWireSysvolInventory $gpo).Sha256 -ceq $treeHash) 'replay changes no SMB bytes or permissions'
  $outcomes+=,[pscustomobject]@{case=$case;seconds=[Math]::Round($watch.Elapsed.TotalSeconds,2);staged=($case -ceq 'success')}
 }
 foreach($name in @('ConnectorServicePackage.ps1','ConnectorServiceRuntime.ps1')){Check (-not ([IO.File]::ReadAllText((Join-Path $lib $name))).Contains('StagingWriteExecution')) 'execution adapter absent from active package/runtime'}
 Check ((Get-Acl -LiteralPath $keyPath).Sddl -ceq $keyAcl) 'dedicated native key ACL preserved'
 $timer=[Diagnostics.Stopwatch]::StartNew();Reject {Assert-AuthWireStagingWriteDeadline ([DateTimeOffset]::UtcNow.ToUnixTimeSeconds()-1) ([DateTimeOffset]::UtcNow.ToUnixTimeSeconds()) $timer} 'engine refuses expired authorization';Reject {Assert-AuthWireStagingWriteDeadline ([DateTimeOffset]::UtcNow.ToUnixTimeSeconds()+30) ([DateTimeOffset]::UtcNow.ToUnixTimeSeconds()+1) $timer} 'engine refuses clock rollback'
 Write-Host ('AUTHWIRE_AUTHORIZED_STAGE_WINDOWS_OK checks='+$checks+' outcomes='+($outcomes|ConvertTo-Json -Compress)+' actual_smb=true seeded_grants=true namespace_ad_content_simulated=true customer_changed=false')
}catch{Write-Host ('EXECUTION_FIXTURE_FAILURE checks='+$checks+' stack='+$_.ScriptStackTrace);throw}
finally{
 $env:PSModulePath=$oldModulePath
 if($share){Remove-SmbShare -Name $share -Force -ErrorAction SilentlyContinue}
 if($startedServer){Stop-Service LanmanServer}
 if($rsa){$rsa.Dispose()};if($key){$key.Delete();$key.Dispose()}
 if($signer){foreach($name in @('Root','TrustedPublisher','My')){$path='Cert:\LocalMachine\'+$name+'\'+$signer.Thumbprint;if(Test-Path -LiteralPath $path){if($name -ceq 'My'){Remove-Item -LiteralPath $path -DeleteKey -Force}else{Remove-Item -LiteralPath $path -Force}}}}
 if($public){$public.Dispose()}
 foreach($path in @($journal,$candidateBase)){if($path -and (Test-Path -LiteralPath $path)){Remove-Item -LiteralPath $path -Recurse -Force}}
 if(Test-Path -LiteralPath $root){Remove-Item -LiteralPath $root -Recurse -Force}
}
