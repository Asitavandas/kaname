# Fixed read-only content verification. No AD/GPO executor or private signer key.
Set-StrictMode -Version 2

function Get-AuthWireCombinedTargetHash($Target){
 $ordered=[ordered]@{}
 foreach($n in @('approval_sha256','candidate_id','dependency_sha256','domain','draft_sha256','gpo_id','group_sid','machine_profile_id','machine_profile_version','manifest_sha256','network_candidate_id','network_manifest_sha256','plan_id','plan_version','publisher_thumbprint','root_thumbprint')){$ordered[$n]=$Target.$n}
 return (Get-AuthWireJobHash ([Text.UTF8Encoding]::new($false,$true).GetBytes(($ordered|ConvertTo-Json -Compress))))
}
function Get-AuthWireCombinedJobIntent([string]$Scope,[string]$Id,[string]$TargetHash){
 return (Get-AuthWireJobHash ([Text.Encoding]::ASCII.GetBytes("AuthWireCombinedVerifyIntentV1`n"+$Scope+"`n"+$Id+"`n"+$TargetHash+"`n")))
}
function New-AuthWireCombinedJobProof {
 param([hashtable]$Binding,[Security.Cryptography.RSACng]$ChannelKey,
       [ValidateSet('POLL','RESULT')][string]$Kind,[hashtable]$Payload)
 $health=New-AuthWireConnectorPollProof -Binding $Binding -ChannelKey $ChannelKey
 $fields=[Text.Encoding]::ASCII.GetString([Convert]::FromBase64String($health.frame)).Split([char]10)
 if($Kind -ceq 'POLL'){
  if($Payload.Count -ne 2 -or $Payload.capability -cne 'combined.verify.v1' -or -not (Test-AuthWireJobGuid $Payload.release_id)){throw 'COMBINED_JOB_INPUT_REJECTED'}
  $path='/api/connector/v1/combined/poll'
 }else{
  $names=@('job_id','lease_id','intent_sha256','outcome','release_id','target_sha256')
  if($Payload.Count -ne $names.Count -or @($names|Where-Object{-not $Payload.ContainsKey($_)}).Count){throw 'COMBINED_JOB_INPUT_REJECTED'}
  foreach($n in @('job_id','release_id')){if(-not (Test-AuthWireJobGuid $Payload[$n])){throw 'COMBINED_JOB_INPUT_REJECTED'}}
  foreach($n in @('lease_id','intent_sha256','target_sha256')){if($Payload[$n] -isnot [string] -or $Payload[$n] -cnotmatch '\A[0-9a-f]{64}\z'){throw 'COMBINED_JOB_INPUT_REJECTED'}}
  if($Payload.outcome -cnotin @('combined_content_verified','combined_content_rejected') -or $Payload.intent_sha256 -cne (Get-AuthWireCombinedJobIntent (Get-AuthWireJobScope $Binding) $Payload.job_id $Payload.target_sha256)){throw 'COMBINED_JOB_INPUT_REJECTED'}
  $path='/api/connector/v1/combined/result'
 }
 $bytes=[Text.UTF8Encoding]::new($false,$true).GetBytes(($Payload|ConvertTo-Json -Compress))
 if($bytes.Length -gt 1024){throw 'COMBINED_JOB_INPUT_REJECTED'}
 $raw=[Text.Encoding]::ASCII.GetBytes(((@('AUTHWIRE-COMBINED-JOB-'+$Kind+'-V1')+@($fields[1..13])+@((Get-AuthWireJobHash $bytes),'POST',$path)) -join "`n")+"`n")
 $sig=$ChannelKey.SignData($raw,[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1)
 return @{frame=[Convert]::ToBase64String($raw);signature=[Convert]::ToBase64String($sig);payload=[Convert]::ToBase64String($bytes)}
}
function Assert-AuthWireCombinedJobTarget($Target){
 Assert-AuthWireCandidateFields $Target @('candidate_id','network_candidate_id','plan_id','plan_version','gpo_id','approval_sha256','network_manifest_sha256','manifest_sha256','draft_sha256','dependency_sha256','publisher_thumbprint','machine_profile_id','machine_profile_version','domain','root_thumbprint','group_sid')
 foreach($n in @('candidate_id','network_candidate_id','plan_id','gpo_id','machine_profile_id')){Assert-AuthWireCandidateGuid $Target.$n}
 foreach($n in @('approval_sha256','network_manifest_sha256','manifest_sha256','draft_sha256','dependency_sha256')){
  if($Target.$n -isnot [string] -or $Target.$n -cnotmatch '\A[0-9a-f]{64}\z'){throw 'COMBINED_JOB_TARGET_REJECTED'}
 }
 foreach($n in @('plan_version','machine_profile_version')){if($Target.$n -isnot [int] -or $Target.$n -lt 1){throw 'COMBINED_JOB_TARGET_REJECTED'}}
 if($Target.publisher_thumbprint -isnot [string] -or $Target.publisher_thumbprint -cnotmatch '\A[0-9A-F]{40}\z' -or
    $Target.root_thumbprint -isnot [string] -or $Target.root_thumbprint -cnotmatch '\A[0-9a-f]{40}\z' -or
    $Target.group_sid -isnot [string] -or $Target.group_sid -cnotmatch '\AS-1-5-21-(?:[0-9]{1,10}-){3}[0-9]{1,10}\z' -or
    $Target.domain -isnot [string] -or $Target.domain.Length -gt 253 -or $Target.domain.Split('.').Count -lt 2){throw 'COMBINED_JOB_TARGET_REJECTED'}
 foreach($label in $Target.domain.Split('.')){if($label -cnotmatch '\A[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\z'){throw 'COMBINED_JOB_TARGET_REJECTED'}}
}
function Get-AuthWireCombinedJobNetworkApproval($Target,[hashtable]$Binding){
 $root=Join-Path ([Environment]::GetFolderPath('CommonApplicationData')) ('AuthWire-DeploymentCandidates-'+([guid]$Binding.connector_id).ToString('N'))
 Assert-AuthWireCandidateAcl $root $Binding.service_sid -Directory
 $items=@(Get-ChildItem -LiteralPath $root -Force);if($items.Count -gt 32){throw 'COMBINED_JOB_DIRECTORY_LIMIT'}
 $prefix=([guid]$Target.plan_id).ToString('N')+'-v'+$Target.plan_version+'-'
 $selected=@()
 foreach($item in $items){
  if($item.Name -cnotmatch ('\A'+[regex]::Escape($prefix)+'[0-9a-f]{64}\z')){continue}
  if(-not $item.PSIsContainer){throw 'COMBINED_JOB_DIRECTORY_REJECTED'}
  Assert-AuthWireCandidateAcl $item.FullName $Binding.service_sid -Directory
  $path=Join-Path $item.FullName 'approval.json';Assert-AuthWireCandidateAcl $path $Binding.service_sid
  if((Get-AuthWireCandidateHash (Read-AuthWireCandidateBytes $path 8192)) -cne $Target.approval_sha256){continue}
  $a=(Read-AuthWireCandidateApproval $path $Target.approval_sha256).Value
  if($item.Name -cne ($prefix+$a.preview_hash)){throw 'COMBINED_JOB_NETWORK_PATH_REJECTED'}
  $selected+=,$a
 }
 if($selected.Count -ne 1){throw 'COMBINED_JOB_EXACT_NETWORK_REQUIRED'}
 return $selected[0]
}
function Assert-AuthWireCombinedJobAssets($Target,[hashtable]$Binding,[string]$BaseUrl,$Approval,$Draft){
 foreach($pair in @(@('machine_profile_id',$Target.machine_profile_id),@('domain',$Target.domain),@('group_sid',$Target.group_sid),@('root_thumbprint',$Target.root_thumbprint.ToUpperInvariant()),@('publisher_thumbprint',$Target.publisher_thumbprint))){
  if($Approval.($pair[0]) -cne $pair[1]){throw 'COMBINED_JOB_NETWORK_DEPENDENCY_CHANGED'}
 }
 if($Approval.machine_profile_version -ne $Target.machine_profile_version -or
    $Draft.Manifest.machine_profile_id -cne $Target.machine_profile_id -or
    $Draft.Manifest.machine_profile_version -ne $Target.machine_profile_version -or
    $Draft.Manifest.network_zip_sha256 -cne $Approval.zip_sha256){throw 'COMBINED_JOB_PROFILE_OR_NETWORK_CHANGED'}
 $cfg=ConvertFrom-AuthWireCandidateJson $Draft.Files['enrollment/config.json']
 Assert-AuthWireCandidateFields $cfg @('url','spn','domain','profile_id','tls_sha256')
 if($cfg.url -cne $BaseUrl.TrimEnd('/') -or $cfg.spn -cne ('HTTP/'+$Binding.appliance_fqdn) -or
    $cfg.domain -cne $Target.domain -or $cfg.profile_id -cne $Target.machine_profile_id -or
    $cfg.tls_sha256 -cne $Binding.appliance_tls_sha256){throw 'COMBINED_JOB_ENROLLMENT_BINDING_CHANGED'}
 foreach($n in @('root-ca.pem','issuer-ca.pem')){
  if((Get-AuthWireCandidateHash $Draft.Files['enrollment/'+$n]) -cne (Get-AuthWireCandidateHash $Draft.Files['network/'+$n])){throw 'COMBINED_JOB_ENROLLMENT_CA_CHANGED'}
 }
 $pem=[Text.Encoding]::ASCII.GetString($Draft.Files['enrollment/https-trust.pem'])
 $match=[regex]::Match($pem,'\A-----BEGIN CERTIFICATE-----\s+([A-Za-z0-9+/=\r\n]+)-----END CERTIFICATE-----\s*\z')
 if(-not $match.Success){throw 'COMBINED_JOB_WEB_TRUST_CHANGED'}
 if((Get-AuthWireCandidateHash ([Convert]::FromBase64String($match.Groups[1].Value))) -cne $Binding.appliance_tls_sha256){throw 'COMBINED_JOB_WEB_TRUST_CHANGED'}
}
function Test-AuthWireJobCombinedContent($Target,[hashtable]$Binding,[string]$PublisherThumbprint,[string]$BaseUrl){
 Assert-AuthWireCombinedJobTarget $Target
 if($Target.publisher_thumbprint -cne $PublisherThumbprint){throw 'COMBINED_JOB_PUBLISHER_MISMATCH'}
 $network=@{candidate_id=$Target.network_candidate_id;plan_id=$Target.plan_id;plan_version=$Target.plan_version;gpo_id=$Target.gpo_id;approval_sha256=$Target.approval_sha256;manifest_sha256=$Target.network_manifest_sha256;dependency_sha256=$Target.dependency_sha256}
 $networkObject=[pscustomobject]$network
 # The original network verifier enforces the exact non-admin service identity,
 # public signer, signed comment manifest, profile/CA/XML and fixed path/ACLs.
 if(-not (Test-AuthWireJobCandidateContent $networkObject $Binding $PublisherThumbprint)){throw 'COMBINED_JOB_NETWORK_VERIFICATION_FAILED'}
 $a=Get-AuthWireCombinedJobNetworkApproval $Target $Binding
 $pins=@{ConnectorId=$Binding.connector_id;PlanId=$Target.plan_id;PlanVersion=$Target.plan_version;
         DraftSha256=$Target.draft_sha256;ManifestSha256=$Target.manifest_sha256;
         PublisherThumbprint=$PublisherThumbprint;ServiceSid=$Binding.service_sid}
 $result=Test-AuthWireServiceCombinedContent @pins
 if($result.ContentVerified -isnot [bool] -or -not $result.ContentVerified -or
    $result.ServiceIdentityVerified -isnot [bool] -or -not $result.ServiceIdentityVerified -or
    $result.RuntimeSid -cne $Binding.service_sid -or $result.SignaturesVerified -ne 3 -or
    $result.ManifestSha256 -cne $Target.manifest_sha256 -or $result.DraftSha256 -cne $Target.draft_sha256 -or
    $result.PrivateKeyOpened -isnot [bool] -or $result.PrivateKeyOpened -or
    $result.ArtifactExecuted -isnot [bool] -or $result.ArtifactExecuted -or
    $result.CanApplyGpo -isnot [bool] -or $result.CanApplyGpo){throw 'COMBINED_JOB_CONTENT_REJECTED'}
 $templateHash=Get-AuthWireCandidateHash (Get-AuthWireCombinedReadonlyTemplate)
 $root=Join-Path ([Environment]::GetFolderPath('CommonApplicationData')) ('AuthWire-CombinedCandidates-'+([guid]$Binding.connector_id).ToString('N'))
 $path=Join-Path $root ($Target.plan_id+'-v'+$Target.plan_version+'-'+$Target.draft_sha256+'-'+$templateHash.Substring(0,16))
 Assert-AuthWireCandidateAcl $root $Binding.service_sid -Directory
 Assert-AuthWireCandidateAcl $path $Binding.service_sid -Directory
 $draftPath=Join-Path $path 'original-draft.zip';Assert-AuthWireCandidateAcl $draftPath $Binding.service_sid
 $draft=Read-AuthWireCombinedDraft $draftPath $Target.draft_sha256
 Assert-AuthWireCombinedJobAssets $Target $Binding $BaseUrl $a $draft
 # Recheck content after the extra dependency validation as well.
 $again=Test-AuthWireServiceCombinedContent @pins
 if($again.ManifestSha256 -cne $Target.manifest_sha256 -or -not $again.ContentVerified){throw 'COMBINED_JOB_CONTENT_CHANGED'}
 return $true
}
function Invoke-AuthWireCombinedJob {
 param([string]$BaseUrl,[hashtable]$Binding,[Security.Cryptography.RSACng]$ChannelKey,
       [string]$PackageReleaseId,[string]$PublisherThumbprint)
 if(-not (Test-AuthWireJobGuid $PackageReleaseId)){throw 'COMBINED_JOB_RELEASE_REJECTED'}
 $poll=New-AuthWireCombinedJobProof $Binding $ChannelKey POLL @{capability='combined.verify.v1';release_id=$PackageReleaseId}
 $request=[Text.Encoding]::ASCII.GetString([Convert]::FromBase64String($poll.frame)).Split([char]10)[10]
 $raw=[AuthWire.Connector.ChannelTypesV1]::Post($BaseUrl,$Binding.appliance_fqdn,$Binding.appliance_tls_sha256,'/api/connector/v1/combined/poll',($poll|ConvertTo-Json -Compress))
 $offer=ConvertFrom-AuthWireCandidateJson ([Text.Encoding]::UTF8.GetBytes($raw))
 Assert-AuthWireCandidateFields $offer @('format','request_id','scope_sha256','job_id','operation','lease_id','intent_sha256','expires_at','target','read_only','can_apply')
 $scope=Get-AuthWireJobScope $Binding
 if($offer.format -isnot [int] -or $offer.format -ne 1 -or $offer.request_id -cne $request -or $offer.scope_sha256 -cne $scope -or $offer.read_only -isnot [bool] -or -not $offer.read_only -or $offer.can_apply -isnot [bool] -or $offer.can_apply){throw 'COMBINED_JOB_REPLY_REJECTED'}
 if($offer.job_id -ceq ''){
  if($offer.operation -cne '' -or $offer.lease_id -cne '' -or $offer.intent_sha256 -cne '' -or $offer.expires_at -isnot [int] -or $offer.expires_at -ne 0 -or $null -ne $offer.target){throw 'COMBINED_JOB_REPLY_REJECTED'}
  return [pscustomobject]@{ChannelVerified=$true;JobCompleted=$false;JobId=''}
 }
 Assert-AuthWireCombinedJobTarget $offer.target
 $targetHash=Get-AuthWireCombinedTargetHash $offer.target;$now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
 if(-not (Test-AuthWireJobGuid $offer.job_id) -or $offer.operation -cne 'combined.verify.v1' -or $offer.lease_id -isnot [string] -or $offer.lease_id -cnotmatch '\A[0-9a-f]{64}\z' -or $offer.intent_sha256 -cne (Get-AuthWireCombinedJobIntent $scope $offer.job_id $targetHash) -or ($offer.expires_at -isnot [int] -and $offer.expires_at -isnot [long]) -or $now -ge $offer.expires_at -or $offer.expires_at -gt $now+95){throw 'COMBINED_JOB_REPLY_REJECTED'}
 $outcome='combined_content_rejected'
 try{if(Test-AuthWireJobCombinedContent $offer.target $Binding $PublisherThumbprint $BaseUrl){$outcome='combined_content_verified'}}catch{$outcome='combined_content_rejected'}
 $proof=New-AuthWireCombinedJobProof $Binding $ChannelKey RESULT @{job_id=$offer.job_id;lease_id=$offer.lease_id;intent_sha256=$offer.intent_sha256;outcome=$outcome;release_id=$PackageReleaseId;target_sha256=$targetHash}
 $request=[Text.Encoding]::ASCII.GetString([Convert]::FromBase64String($proof.frame)).Split([char]10)[10]
 $raw=[AuthWire.Connector.ChannelTypesV1]::Post($BaseUrl,$Binding.appliance_fqdn,$Binding.appliance_tls_sha256,'/api/connector/v1/combined/result',($proof|ConvertTo-Json -Compress))
 if(-not [AuthWire.Connector.ChannelTypesV1]::JobReceipt($raw)){throw 'COMBINED_JOB_RECEIPT_REJECTED'}
 $r=$raw|ConvertFrom-Json
 if($r.format -isnot [int] -or $r.format -ne 1 -or $r.request_id -cne $request -or $r.job_id -cne $offer.job_id -or $r.result_recorded -isnot [bool] -or -not $r.result_recorded -or $r.read_only -isnot [bool] -or -not $r.read_only -or $r.can_apply -isnot [bool] -or $r.can_apply){throw 'COMBINED_JOB_RECEIPT_REJECTED'}
 return [pscustomobject]@{ChannelVerified=$true;JobCompleted=$true;JobId=$offer.job_id}
}
