# Fixed read-only content verification. No AD/GPO executor or private signer key.
Set-StrictMode -Version 2

function Get-AuthWireCandidateTargetHash($Target){
 $ordered=[ordered]@{}
 foreach($n in @('approval_sha256','candidate_id','dependency_sha256','gpo_id','manifest_sha256','plan_id','plan_version')){$ordered[$n]=$Target.$n}
 return (Get-AuthWireJobHash ([Text.UTF8Encoding]::new($false,$true).GetBytes(($ordered|ConvertTo-Json -Compress))))
}
function Get-AuthWireCandidateJobIntent([string]$Scope,[string]$Id,[string]$TargetHash){
 return (Get-AuthWireJobHash ([Text.Encoding]::ASCII.GetBytes("AuthWireCandidateVerifyIntentV1`n"+$Scope+"`n"+$Id+"`n"+$TargetHash+"`n")))
}
function New-AuthWireCandidateJobProof {
 param([hashtable]$Binding,[Security.Cryptography.RSACng]$ChannelKey,
       [ValidateSet('POLL','RESULT')][string]$Kind,[hashtable]$Payload)
 $health=New-AuthWireConnectorPollProof -Binding $Binding -ChannelKey $ChannelKey
 $fields=[Text.Encoding]::ASCII.GetString([Convert]::FromBase64String($health.frame)).Split([char]10)
 if($Kind -ceq 'POLL'){
  if($Payload.Count -ne 2 -or $Payload.capability -cne 'candidate.verify.v1' -or -not (Test-AuthWireJobGuid $Payload.release_id)){throw 'CANDIDATE_JOB_INPUT_REJECTED'}
  $path='/api/connector/v1/candidates/poll'
 }else{
  $names=@('job_id','lease_id','intent_sha256','outcome','release_id','target_sha256')
  if($Payload.Count -ne $names.Count -or @($names|Where-Object{-not $Payload.ContainsKey($_)}).Count){throw 'CANDIDATE_JOB_INPUT_REJECTED'}
  foreach($n in @('job_id','release_id')){if(-not (Test-AuthWireJobGuid $Payload[$n])){throw 'CANDIDATE_JOB_INPUT_REJECTED'}}
  foreach($n in @('lease_id','intent_sha256','target_sha256')){if($Payload[$n] -isnot [string] -or $Payload[$n] -cnotmatch '\A[0-9a-f]{64}\z'){throw 'CANDIDATE_JOB_INPUT_REJECTED'}}
  if($Payload.outcome -cnotin @('content_verified','content_rejected') -or $Payload.intent_sha256 -cne (Get-AuthWireCandidateJobIntent (Get-AuthWireJobScope $Binding) $Payload.job_id $Payload.target_sha256)){throw 'CANDIDATE_JOB_INPUT_REJECTED'}
  $path='/api/connector/v1/candidates/result'
 }
 $bytes=[Text.UTF8Encoding]::new($false,$true).GetBytes(($Payload|ConvertTo-Json -Compress))
 if($bytes.Length -gt 1024){throw 'CANDIDATE_JOB_INPUT_REJECTED'}
 $raw=[Text.Encoding]::ASCII.GetBytes(((@('AUTHWIRE-CANDIDATE-JOB-'+$Kind+'-V1')+@($fields[1..13])+@((Get-AuthWireJobHash $bytes),'POST',$path)) -join "`n")+"`n")
 $sig=$ChannelKey.SignData($raw,[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1)
 return @{frame=[Convert]::ToBase64String($raw);signature=[Convert]::ToBase64String($sig);payload=[Convert]::ToBase64String($bytes)}
}
function Assert-AuthWireCandidateJobTarget($Target){
 Assert-AuthWireCandidateFields $Target @('candidate_id','plan_id','plan_version','gpo_id','approval_sha256','manifest_sha256','dependency_sha256')
 foreach($n in @('candidate_id','plan_id','gpo_id')){Assert-AuthWireCandidateGuid $Target.$n}
 foreach($n in @('approval_sha256','manifest_sha256','dependency_sha256')){if($Target.$n -isnot [string] -or $Target.$n -cnotmatch '\A[0-9a-f]{64}\z'){throw 'CANDIDATE_JOB_TARGET_REJECTED'}}
 if($Target.plan_version -isnot [int] -or $Target.plan_version -lt 1){throw 'CANDIDATE_JOB_TARGET_REJECTED'}
}
function Test-AuthWireJobCandidateContent($Target,[hashtable]$Binding,[string]$PublisherThumbprint){
 Assert-AuthWireCandidateJobTarget $Target
 if($PublisherThumbprint -cnotmatch '\A[0-9A-F]{40}\z'){throw 'CANDIDATE_JOB_PUBLISHER_REQUIRED'}
 # Discover only the bounded, fixed candidate root; never accept a request path.
 $root=Join-Path ([Environment]::GetFolderPath('CommonApplicationData')) ('AuthWire-DeploymentCandidates-'+([guid]$Binding.connector_id).ToString('N'))
 Assert-AuthWireCandidateAcl $root $Binding.service_sid -Directory
 $items=@(Get-ChildItem -LiteralPath $root -Force);if($items.Count -gt 32){throw 'CANDIDATE_JOB_DIRECTORY_LIMIT'}
 $prefix=([guid]$Target.plan_id).ToString('N')+'-v'+$Target.plan_version+'-'
 $selectedApprovals=@()
 foreach($item in $items){
  if($item.Name -cnotmatch ('\A'+[regex]::Escape($prefix)+'[0-9a-f]{64}\z')){continue}
  if(-not $item.PSIsContainer){throw 'CANDIDATE_JOB_DIRECTORY_REJECTED'}
  Assert-AuthWireCandidateAcl $item.FullName $Binding.service_sid -Directory
  $path=Join-Path $item.FullName 'approval.json';Assert-AuthWireCandidateAcl $path $Binding.service_sid
  $bytes=Read-AuthWireCandidateBytes $path 8192
  if((Get-AuthWireCandidateHash $bytes) -cne $Target.approval_sha256){continue}
  $approval=Read-AuthWireCandidateApproval $path $Target.approval_sha256
  if($item.Name -cne ($prefix+$approval.Value.preview_hash)){throw 'CANDIDATE_JOB_PATH_BINDING_REJECTED'}
  $selectedApprovals+=,$approval.Value
 }
 if($selectedApprovals.Count -ne 1){throw 'CANDIDATE_JOB_EXACT_CANDIDATE_REQUIRED'}
 $a=$selectedApprovals[0]
 if($a.publisher_thumbprint -cne $PublisherThumbprint){throw 'CANDIDATE_JOB_PUBLISHER_MISMATCH'}
 # Approval bytes are pinned; publisher is additionally pinned by service config.
 $pins=@{ConnectorId=$Binding.connector_id;PlanId=$Target.plan_id;PlanVersion=$Target.plan_version;
  PreviewHash=$a.preview_hash;GpoId=$Target.gpo_id;ProtectedGpoId=$a.protected_gpo_id;
  ServiceSid=$Binding.service_sid;PublisherThumbprint=$PublisherThumbprint;
  ApprovalSha256=$Target.approval_sha256;ManifestSha256=$Target.manifest_sha256}
 $result=Test-AuthWireServiceCandidate @pins
 if($result.CandidateVerified -isnot [bool] -or -not $result.CandidateVerified -or $result.SignatureVerified -isnot [bool] -or -not $result.SignatureVerified -or $result.NetworkContentVerified -isnot [bool] -or -not $result.NetworkContentVerified -or $result.RuntimeSid -cne $Binding.service_sid -or $result.ManifestSha256 -cne $Target.manifest_sha256){throw 'CANDIDATE_JOB_VERIFICATION_REJECTED'}
 return $true
}
function Invoke-AuthWireCandidateJob {
 param([string]$BaseUrl,[hashtable]$Binding,[Security.Cryptography.RSACng]$ChannelKey,
       [string]$PackageReleaseId,[string]$PublisherThumbprint)
 if(-not (Test-AuthWireJobGuid $PackageReleaseId)){throw 'CANDIDATE_JOB_RELEASE_REJECTED'}
 $poll=New-AuthWireCandidateJobProof $Binding $ChannelKey POLL @{capability='candidate.verify.v1';release_id=$PackageReleaseId}
 $request=[Text.Encoding]::ASCII.GetString([Convert]::FromBase64String($poll.frame)).Split([char]10)[10]
 $raw=[AuthWire.Connector.ChannelTypesV1]::Post($BaseUrl,$Binding.appliance_fqdn,$Binding.appliance_tls_sha256,'/api/connector/v1/candidates/poll',($poll|ConvertTo-Json -Compress))
 $offer=ConvertFrom-AuthWireCandidateJson ([Text.Encoding]::UTF8.GetBytes($raw))
 Assert-AuthWireCandidateFields $offer @('format','request_id','scope_sha256','job_id','operation','lease_id','intent_sha256','expires_at','target','read_only','can_apply')
 $scope=Get-AuthWireJobScope $Binding
 if($offer.format -isnot [int] -or $offer.format -ne 1 -or $offer.request_id -cne $request -or $offer.scope_sha256 -cne $scope -or $offer.read_only -isnot [bool] -or -not $offer.read_only -or $offer.can_apply -isnot [bool] -or $offer.can_apply){throw 'CANDIDATE_JOB_REPLY_REJECTED'}
 if($offer.job_id -ceq ''){
  if($offer.operation -cne '' -or $offer.lease_id -cne '' -or $offer.intent_sha256 -cne '' -or $offer.expires_at -isnot [int] -or $offer.expires_at -ne 0 -or $null -ne $offer.target){throw 'CANDIDATE_JOB_REPLY_REJECTED'}
  return [pscustomobject]@{ChannelVerified=$true;JobCompleted=$false;JobId=''}
 }
 Assert-AuthWireCandidateJobTarget $offer.target
 $targetHash=Get-AuthWireCandidateTargetHash $offer.target;$now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
 if(-not (Test-AuthWireJobGuid $offer.job_id) -or $offer.operation -cne 'candidate.verify.v1' -or $offer.lease_id -isnot [string] -or $offer.lease_id -cnotmatch '\A[0-9a-f]{64}\z' -or $offer.intent_sha256 -cne (Get-AuthWireCandidateJobIntent $scope $offer.job_id $targetHash) -or ($offer.expires_at -isnot [int] -and $offer.expires_at -isnot [long]) -or $now -ge $offer.expires_at -or $offer.expires_at -gt $now+95){throw 'CANDIDATE_JOB_REPLY_REJECTED'}
 $outcome='content_rejected'
 try{if(Test-AuthWireJobCandidateContent $offer.target $Binding $PublisherThumbprint){$outcome='content_verified'}}catch{$outcome='content_rejected'}
 $proof=New-AuthWireCandidateJobProof $Binding $ChannelKey RESULT @{job_id=$offer.job_id;lease_id=$offer.lease_id;intent_sha256=$offer.intent_sha256;outcome=$outcome;release_id=$PackageReleaseId;target_sha256=$targetHash}
 $request=[Text.Encoding]::ASCII.GetString([Convert]::FromBase64String($proof.frame)).Split([char]10)[10]
 $raw=[AuthWire.Connector.ChannelTypesV1]::Post($BaseUrl,$Binding.appliance_fqdn,$Binding.appliance_tls_sha256,'/api/connector/v1/candidates/result',($proof|ConvertTo-Json -Compress))
 if(-not [AuthWire.Connector.ChannelTypesV1]::JobReceipt($raw)){throw 'CANDIDATE_JOB_RECEIPT_REJECTED'}
 $r=$raw|ConvertFrom-Json
 if($r.format -isnot [int] -or $r.format -ne 1 -or $r.request_id -cne $request -or $r.job_id -cne $offer.job_id -or $r.result_recorded -isnot [bool] -or -not $r.result_recorded -or $r.read_only -isnot [bool] -or -not $r.read_only -or $r.can_apply -isnot [bool] -or $r.can_apply){throw 'CANDIDATE_JOB_RECEIPT_REJECTED'}
 return [pscustomobject]@{ChannelVerified=$true;JobCompleted=$true;JobId=$offer.job_id}
}
