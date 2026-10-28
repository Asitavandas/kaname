# Separate combined scope protocol; existing bounded AllSigned process runner.
Set-StrictMode -Version 2
function Get-AuthWireStagingPreviewTargetHash($Target){
 Assert-AuthWireCombinedScopeTarget $Target
 $v=[ordered]@{};foreach($n in @('approval_sha256', 'candidate_id', 'content_result_sha256', 'dependency_sha256', 'domain', 'draft_sha256', 'gpo_id', 'group_sid', 'machine_profile_id', 'machine_profile_version', 'manifest_sha256', 'network_candidate_id', 'network_manifest_sha256', 'plan_id', 'plan_version', 'publisher_thumbprint', 'root_thumbprint', 'target_count', 'target_sids_sha256')){$v[$n]=$Target.$n}
 return (Get-AuthWireJobHash ([Text.UTF8Encoding]::new($false,$true).GetBytes(($v|ConvertTo-Json -Compress))))
}
function Get-AuthWireStagingPreviewIntent([string]$Scope,[string]$Id,[string]$Hash){
 return (Get-AuthWireJobHash ([Text.Encoding]::ASCII.GetBytes("AuthWireStagingPreviewIntentV1`n"+$Scope+"`n"+$Id+"`n"+$Hash+"`n")))
}
function New-AuthWireStagingPreviewProof([hashtable]$Binding,[Security.Cryptography.RSACng]$Key,[ValidateSet('POLL','RESULT')][string]$Kind,[hashtable]$Payload){
 $h=New-AuthWireConnectorPollProof -Binding $Binding -ChannelKey $Key
 $f=[Text.Encoding]::ASCII.GetString([Convert]::FromBase64String($h.frame)).Split([char]10)
 $path=if($Kind -ceq 'POLL'){'/api/connector/v1/staging-preview/poll'}else{'/api/connector/v1/staging-preview/result'}
 $bytes=[Text.UTF8Encoding]::new($false,$true).GetBytes(($Payload|ConvertTo-Json -Depth 10 -Compress))
 if($bytes.Length -gt $(if($Kind -ceq 'RESULT'){16384}else{1024})){throw 'SCOPE_PAYLOAD_REJECTED'}
 $raw=[Text.Encoding]::ASCII.GetBytes(((@('AUTHWIRE-STAGING-PREVIEW-JOB-'+$Kind+'-V1')+@($f[1..13])+@((Get-AuthWireJobHash $bytes),'POST',$path)) -join "`n")+"`n")
 $sig=$Key.SignData($raw,[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1)
 return @{frame=[Convert]::ToBase64String($raw);signature=[Convert]::ToBase64String($sig);payload=[Convert]::ToBase64String($bytes)}
}
function Invoke-AuthWireStagingPreviewReader($Target,[int]$BudgetMs){
 Initialize-AuthWireScopeProcess
 $path=Join-Path $PSScriptRoot 'Read-AuthWireCombinedStagingPreview.ps1'
 $exe=Join-Path ([Environment]::GetFolderPath('Windows')) 'System32\WindowsPowerShell\v1.0\powershell.exe'
 $payload=[Convert]::ToBase64String([Text.UTF8Encoding]::new($false,$true).GetBytes(($Target|ConvertTo-Json -Compress)))
 return [AuthWire.Connector.ScopeProcessV1]::RunPreview($exe,('-NoLogo -NoProfile -NonInteractive -ExecutionPolicy AllSigned -File "'+$path+'" -RequestBase64 '+$payload),$BudgetMs)
}
function Invoke-AuthWireStagingPreviewJob {
 param([string]$BaseUrl,[hashtable]$Binding,[Security.Cryptography.RSACng]$ChannelKey,[string]$PackageReleaseId)
 if(-not (Test-AuthWireJobGuid $PackageReleaseId)){throw 'SCOPE_RELEASE_REJECTED'}
 $p=New-AuthWireStagingPreviewProof $Binding $ChannelKey POLL @{capability='combined.staging.preview.v1';release_id=$PackageReleaseId}
 $request=[Text.Encoding]::ASCII.GetString([Convert]::FromBase64String($p.frame)).Split([char]10)[10]
 $raw=[AuthWire.Connector.ChannelTypesV1]::PostStagingPreview($BaseUrl,$Binding.appliance_fqdn,$Binding.appliance_tls_sha256,'/api/connector/v1/staging-preview/poll',($p|ConvertTo-Json -Compress))
 $offer=ConvertFrom-AuthWireCandidateJson ([Text.Encoding]::UTF8.GetBytes($raw))
 Assert-AuthWireCandidateFields $offer @('format','request_id','scope_sha256','job_id','operation','lease_id','intent_sha256','expires_at','target','read_only','can_apply')
 $scope=Get-AuthWireJobScope $Binding
 if($offer.format -isnot [int] -or $offer.format -ne 1 -or $offer.request_id -cne $request -or $offer.scope_sha256 -cne $scope -or $offer.read_only -isnot [bool] -or -not $offer.read_only -or $offer.can_apply -isnot [bool] -or $offer.can_apply){throw 'SCOPE_REPLY_REJECTED'}
 if($offer.job_id -ceq ''){
  if($offer.operation -cne '' -or $offer.lease_id -cne '' -or $offer.intent_sha256 -cne '' -or $offer.expires_at -isnot [int] -or $offer.expires_at -ne 0 -or $null -ne $offer.target){throw 'SCOPE_REPLY_REJECTED'}
  return [pscustomobject]@{ChannelVerified=$true;JobCompleted=$false;JobId='';Reason=''}
 }
 Assert-AuthWireCombinedScopeTarget $offer.target
 $hash=Get-AuthWireStagingPreviewTargetHash $offer.target;$now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
 if(-not (Test-AuthWireJobGuid $offer.job_id) -or $offer.operation -cne 'combined.staging.preview.v1' -or $offer.lease_id -isnot [string] -or $offer.lease_id -cnotmatch '\A[0-9a-f]{64}\z' -or $offer.intent_sha256 -cne (Get-AuthWireStagingPreviewIntent $scope $offer.job_id $hash) -or ($offer.expires_at -isnot [int] -and $offer.expires_at -isnot [long]) -or $offer.expires_at -le $now+5 -or $offer.expires_at -gt $now+95){throw 'SCOPE_REPLY_REJECTED'}
 $checkedAt=$now;$reason='READ_FAILED';$preview=$null;$previewHash=''
 try{
  $r=Invoke-AuthWireStagingPreviewReader $offer.target ([int][Math]::Min(30000,($offer.expires_at-$now-5)*1000))
  if($r.TimedOut){$reason='READ_TIMEOUT'}
  elseif(-not $r.Truncated -and $r.ExitCode -eq 0){
   $v=ConvertFrom-AuthWireCandidateJson ([Text.UTF8Encoding]::new($false,$true).GetBytes($r.Output))
   Assert-AuthWireCandidateFields $v @('format','checked_at','reason','preview','preview_sha256')
   if($v.format -isnot [int] -or $v.format -ne 1 -or ($v.checked_at -isnot [int] -and $v.checked_at -isnot [long]) -or $v.checked_at -lt $now -or $v.checked_at -gt [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() -or $v.reason -cnotin @('OK','CONTENT_REJECTED','DIRECTORY_SCOPE_CHANGED','GPO_SCOPE_CHANGED','READ_FAILED','OBSERVATIONS_CHANGED')){throw 'STAGING_READ_RESULT_REJECTED'}
   if($v.reason -ceq 'OK'){
    if($null -eq $v.preview -or $v.preview.checked_at -ne $v.checked_at -or $v.preview.read_only -isnot [bool] -or -not $v.preview.read_only -or $v.preview.can_stage -isnot [bool] -or $v.preview.can_stage -or $v.preview.can_apply_gpo -isnot [bool] -or $v.preview.can_apply_gpo -or $v.preview.writer_available -isnot [bool] -or $v.preview.writer_available -or $v.preview_sha256 -cne (Get-AuthWireScopeDataHash $v.preview)){throw 'STAGING_READ_RESULT_REJECTED'}
    $preview=$v.preview;$previewHash=$v.preview_sha256
   }elseif($null -ne $v.preview -or $v.preview_sha256 -cne ''){throw 'STAGING_READ_RESULT_REJECTED'}
   $checkedAt=$v.checked_at;$reason=$v.reason
  }
 }catch{$reason='READ_FAILED';$preview=$null;$previewHash=''}
 $now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds();if($now -ge $offer.expires_at){throw 'STAGING_LEASE_EXPIRED'}
 if($reason -cne 'OK'){$checkedAt=$now;$preview=$null;$previewHash=''}
 $outcome=if($reason -ceq 'OK'){'staging_preview_verified'}else{'staging_preview_rejected'}
 $p=New-AuthWireStagingPreviewProof $Binding $ChannelKey RESULT @{job_id=$offer.job_id;lease_id=$offer.lease_id;intent_sha256=$offer.intent_sha256;outcome=$outcome;release_id=$PackageReleaseId;target_sha256=$hash;checked_at=$checkedAt;reason=$reason;preview=$preview;preview_sha256=$previewHash}
 $request=[Text.Encoding]::ASCII.GetString([Convert]::FromBase64String($p.frame)).Split([char]10)[10]
 $raw=[AuthWire.Connector.ChannelTypesV1]::PostStagingPreview($BaseUrl,$Binding.appliance_fqdn,$Binding.appliance_tls_sha256,'/api/connector/v1/staging-preview/result',($p|ConvertTo-Json -Compress))
 if(-not [AuthWire.Connector.ChannelTypesV1]::JobReceipt($raw)){throw 'SCOPE_RECEIPT_REJECTED'}
 $r=$raw|ConvertFrom-Json
 if($r.format -isnot [int] -or $r.format -ne 1 -or $r.request_id -cne $request -or $r.job_id -cne $offer.job_id -or $r.result_recorded -isnot [bool] -or -not $r.result_recorded -or $r.read_only -isnot [bool] -or -not $r.read_only -or $r.can_apply -isnot [bool] -or $r.can_apply){throw 'SCOPE_RECEIPT_REJECTED'}
 return [pscustomobject]@{ChannelVerified=$true;JobCompleted=$true;JobId=$offer.job_id;Reason=$reason}
}
