# Read-only probe jobs only. No AD, GPO, process creation or arbitrary signing.
Set-StrictMode -Version 2

function Get-AuthWireJobHash([byte[]]$Bytes){
 $sha=[Security.Cryptography.SHA256]::Create()
 try{return ([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-','').ToLowerInvariant()}finally{$sha.Dispose()}
}
function Get-AuthWireJobScope([hashtable]$Binding){
 $names=@('instance_id','connector_id','generation','host_guid','host_fqdn','service_sid','appliance_fqdn','appliance_tls_sha256','channel_key_sha256')
 $parts=@($names|ForEach-Object{[string]$Binding[$_]})
 return (Get-AuthWireJobHash ([Text.Encoding]::ASCII.GetBytes("AuthWireConnectorJobBindingV1`n"+($parts -join "`n")+"`n")))
}
function Get-AuthWireProbeIntent([string]$Scope,[string]$JobId){
 return (Get-AuthWireJobHash ([Text.Encoding]::ASCII.GetBytes("AuthWireConnectorProbeIntentV1`n"+$Scope+"`n"+$JobId+"`nconnector.probe`n")))
}
function Test-AuthWireJobGuid($Value){
 $g=[guid]::Empty
 return ($Value -is [string] -and [guid]::TryParseExact($Value,'D',[ref]$g) -and $g -ne [guid]::Empty -and $g.ToString('D') -ceq $Value)
}
function New-AuthWireProbeJobProof {
 param([hashtable]$Binding,[Security.Cryptography.RSACng]$ChannelKey,
       [ValidateSet('POLL','RESULT')][string]$Kind='POLL',[hashtable]$Result)
 # Reuse the reviewed runtime SID/host/non-exportable machine-key/binding checks.
 $health=New-AuthWireConnectorPollProof -Binding $Binding -ChannelKey $ChannelKey
 $fields=[Text.Encoding]::ASCII.GetString([Convert]::FromBase64String($health.frame)).Split([char]10)
 if($Kind -eq 'POLL'){
  if($null -ne $Result){throw 'CONNECTOR_JOB_INPUT_REJECTED'}
  $payload=[Text.Encoding]::ASCII.GetBytes('{}');$path='/api/connector/v1/jobs/poll'
 }else{
  $names=@('job_id','lease_id','intent_sha256','outcome','release_id')
  if($null -eq $Result -or $Result.Count -ne 5 -or @($names|Where-Object{-not $Result.ContainsKey($_)}).Count){throw 'CONNECTOR_JOB_INPUT_REJECTED'}
  if(-not (Test-AuthWireJobGuid $Result.job_id) -or -not (Test-AuthWireJobGuid $Result.release_id) -or $Result.outcome -cne 'probe_completed'){throw 'CONNECTOR_JOB_INPUT_REJECTED'}
  foreach($n in @('lease_id','intent_sha256')){if($Result[$n] -isnot [string] -or $Result[$n] -cnotmatch '\A[0-9a-f]{64}\z'){throw 'CONNECTOR_JOB_INPUT_REJECTED'}}
  if($Result.intent_sha256 -cne (Get-AuthWireProbeIntent (Get-AuthWireJobScope $Binding) $Result.job_id)){throw 'CONNECTOR_JOB_INPUT_REJECTED'}
  $payload=[Text.UTF8Encoding]::new($false,$true).GetBytes(($Result|ConvertTo-Json -Compress))
  $path='/api/connector/v1/jobs/result'
 }
 $parts=@('AUTHWIRE-CONNECTOR-JOB-'+$Kind+'-V1')+@($fields[1..13])+@((Get-AuthWireJobHash $payload),'POST',$path)
 $raw=[Text.Encoding]::ASCII.GetBytes(($parts -join "`n")+"`n")
 $signature=$ChannelKey.SignData($raw,[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1)
 [pscustomobject]@{frame=[Convert]::ToBase64String($raw);signature=[Convert]::ToBase64String($signature);payload=[Convert]::ToBase64String($payload)}
}

function Invoke-AuthWireConnectorProbeJob {
 param([string]$BaseUrl,[hashtable]$Binding,[Security.Cryptography.RSACng]$ChannelKey,[string]$PackageReleaseId)
 if(-not (Test-AuthWireJobGuid $PackageReleaseId)){throw 'CONNECTOR_JOB_RELEASE_REJECTED'}
 Initialize-AuthWireChannelTypes
 $poll=New-AuthWireProbeJobProof -Binding $Binding -ChannelKey $ChannelKey
 $request=[Text.Encoding]::ASCII.GetString([Convert]::FromBase64String($poll.frame)).Split([char]10)[10]
 $raw=[AuthWire.Connector.ChannelTypesV1]::Post($BaseUrl,$Binding.appliance_fqdn,$Binding.appliance_tls_sha256,'/api/connector/v1/jobs/poll',($poll|ConvertTo-Json -Compress))
 if(-not [AuthWire.Connector.ChannelTypesV1]::JobOffer($raw)){throw 'CONNECTOR_JOB_REPLY_REJECTED'}
 $offer=$raw|ConvertFrom-Json;$scope=Get-AuthWireJobScope $Binding
 if($offer.format -isnot [int] -or $offer.format -ne 1 -or $offer.request_id -cne $request -or $offer.scope_sha256 -cne $scope -or $offer.read_only -isnot [bool] -or -not $offer.read_only -or $offer.can_apply -isnot [bool] -or $offer.can_apply -or $offer.job_id -isnot [string]){throw 'CONNECTOR_JOB_REPLY_REJECTED'}
 if($offer.job_id -ceq ''){
  if($offer.operation -cne '' -or $offer.lease_id -cne '' -or $offer.intent_sha256 -cne '' -or $offer.expires_at -isnot [int] -or $offer.expires_at -ne 0){throw 'CONNECTOR_JOB_REPLY_REJECTED'}
  return [pscustomobject]@{ProbeChannelVerified=$true;JobCompleted=$false;JobId='';CanApply=$false;AdChanged=$false;GpoChanged=$false}
 }
 $now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
 if(-not (Test-AuthWireJobGuid $offer.job_id) -or $offer.operation -cne 'connector.probe' -or $offer.lease_id -isnot [string] -or $offer.lease_id -cnotmatch '\A[0-9a-f]{64}\z' -or $offer.intent_sha256 -cne (Get-AuthWireProbeIntent $scope $offer.job_id) -or ($offer.expires_at -isnot [int] -and $offer.expires_at -isnot [long]) -or $now -ge $offer.expires_at -or $offer.expires_at -gt $now+95){throw 'CONNECTOR_JOB_REPLY_REJECTED'}
 # The only supported operation reports this verified package's fixed identity.
 # No request can supply an executable, PowerShell, GPO, path, AD filter or URL.
 $result=@{job_id=$offer.job_id;lease_id=$offer.lease_id;intent_sha256=$offer.intent_sha256;outcome='probe_completed';release_id=$PackageReleaseId}
 $proof=New-AuthWireProbeJobProof -Binding $Binding -ChannelKey $ChannelKey -Kind RESULT -Result $result
 $request=[Text.Encoding]::ASCII.GetString([Convert]::FromBase64String($proof.frame)).Split([char]10)[10]
 $raw=[AuthWire.Connector.ChannelTypesV1]::Post($BaseUrl,$Binding.appliance_fqdn,$Binding.appliance_tls_sha256,'/api/connector/v1/jobs/result',($proof|ConvertTo-Json -Compress))
 if(-not [AuthWire.Connector.ChannelTypesV1]::JobReceipt($raw)){throw 'CONNECTOR_JOB_REPLY_REJECTED'}
 $receipt=$raw|ConvertFrom-Json
 if($receipt.format -isnot [int] -or $receipt.format -ne 1 -or $receipt.request_id -cne $request -or $receipt.job_id -cne $offer.job_id -or $receipt.result_recorded -isnot [bool] -or -not $receipt.result_recorded -or $receipt.read_only -isnot [bool] -or -not $receipt.read_only -or $receipt.can_apply -isnot [bool] -or $receipt.can_apply){throw 'CONNECTOR_JOB_REPLY_REJECTED'}
 [pscustomobject]@{ProbeChannelVerified=$true;JobCompleted=$true;JobId=$offer.job_id;CanApply=$false;AdChanged=$false;GpoChanged=$false}
}
