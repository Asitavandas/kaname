# Source-only durable POLL proof validator. Never signs or transmits.
# Same nine-field channel identity, CNG policy and wire envelope contract as CLAIM.
Set-StrictMode -Version 2
function Assert-AuthWireStoredWritePollAt($Proof,[hashtable]$Binding,[string]$Release,[Security.Cryptography.RSACng]$Key,[long]$RecordedAt,[long]$ObservedAt){
 Assert-AuthWireCandidateFields $Proof @('frame','signature','payload');Assert-AuthWireCandidateGuid $Release
 if(-not (Test-AuthWireWriteInteger $RecordedAt) -or -not (Test-AuthWireWriteInteger $ObservedAt) -or $RecordedAt -gt $ObservedAt -or $ObservedAt-$RecordedAt -gt 5 -or $ObservedAt -gt [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()){throw 'LIFECYCLE_POLL_TIME_REJECTED'}
 $names=@('instance_id','connector_id','generation','host_guid','host_fqdn','service_sid','appliance_fqdn','appliance_tls_sha256','channel_key_sha256')
 if($Binding.Count -ne 9 -or @($names|Where-Object{-not $Binding.ContainsKey($_)}).Count){throw 'LIFECYCLE_POLL_RECORD_REJECTED'}
 foreach($n in @('instance_id','connector_id','host_guid')){Assert-AuthWireCandidateGuid $Binding[$n]}
 if(($Binding.generation -isnot [int] -and $Binding.generation -isnot [long]) -or $Binding.generation -lt 1 -or $Binding.generation -gt 2147483647){throw 'LIFECYCLE_POLL_RECORD_REJECTED'}
 foreach($n in @('host_fqdn','appliance_fqdn')){
  $v=$Binding[$n]
  if($v -isnot [string] -or $v.Length -gt 253 -or $v -cne $v.ToLowerInvariant() -or $v.Split('.').Count -lt 2){throw 'LIFECYCLE_POLL_RECORD_REJECTED'}
  foreach($label in $v.Split('.')){if($label -cnotmatch '\A[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\z'){throw 'LIFECYCLE_POLL_RECORD_REJECTED'}}
 }
 if($Binding.service_sid -isnot [string] -or $Binding.service_sid -cnotmatch '\AS-1-5-21-(?:[1-9][0-9]{0,9}-){3}[1-9][0-9]{0,9}\z'){throw 'LIFECYCLE_POLL_RECORD_REJECTED'}
 foreach($part in $Binding.service_sid.Split('-')[4..7]){if([long]$part -gt 4294967295){throw 'LIFECYCLE_POLL_RECORD_REJECTED'}}
 foreach($n in @('appliance_tls_sha256','channel_key_sha256')){if(-not (Test-AuthWireWriteHash $Binding[$n])){throw 'LIFECYCLE_POLL_RECORD_REJECTED'}}
 $identity=[Security.Principal.WindowsIdentity]::GetCurrent()
 try{$sid=$identity.User.Value}finally{$identity.Dispose()}
 $keyPolicy=$Key.Key
 if($sid -cne $Binding.service_sid -or [Environment]::MachineName.ToLowerInvariant() -cne $Binding.host_fqdn.Split('.')[0] -or
    -not $keyPolicy.IsMachineKey -or $keyPolicy.IsEphemeral -or [int]$keyPolicy.ExportPolicy -ne 0 -or [int]$keyPolicy.KeyUsage -ne 2 -or
    $keyPolicy.Provider.Provider -cne 'Microsoft Software Key Storage Provider' -or (Get-AuthWireChannelPublicKeyId $Key) -cne $Binding.channel_key_sha256){throw 'LIFECYCLE_POLL_KEY_REJECTED'}
 $raw=ConvertFrom-AuthWireWriteBase64 $Proof.frame 2048
 foreach($c in $raw){if($c -ne 10 -and ($c -lt 32 -or $c -gt 126)){throw 'LIFECYCLE_POLL_RECORD_REJECTED'}}
 $f=[Text.Encoding]::ASCII.GetString($raw).Split([char]10)
 if($f.Count -ne 18 -or $f[0] -cne 'AUTHWIRE-STAGING-WRITE-JOB-POLL-V1' -or $f[15] -cne 'POST' -or $f[16] -cne '/api/connector/v1/staging-write/poll' -or $f[17] -cne ''){throw 'LIFECYCLE_POLL_RECORD_REJECTED'}
 for($i=0;$i -lt 9;$i++){if($f[$i+1] -cne [string]$Binding[$names[$i]]){throw 'LIFECYCLE_POLL_RECORD_REJECTED'}}
 foreach($i in @(10,11,14)){if(-not (Test-AuthWireWriteHash $f[$i])){throw 'LIFECYCLE_POLL_RECORD_REJECTED'}}
 foreach($i in @(12,13)){if($f[$i] -cnotmatch '\A[1-9][0-9]{0,10}\z'){throw 'LIFECYCLE_POLL_RECORD_REJECTED'}}
 $issued=[long]$f[12];$expires=[long]$f[13]
 if($expires-$issued -ne 60 -or $issued -lt $RecordedAt -or $issued -gt $RecordedAt+2 -or $issued -gt $ObservedAt -or $ObservedAt -ge $expires){throw 'LIFECYCLE_POLL_RECORD_STALE'}
 $payload=ConvertFrom-AuthWireWriteBase64 $Proof.payload 1024
 $signature=ConvertFrom-AuthWireWriteBase64 $Proof.signature 512
 if((Get-AuthWireJobHash $payload) -cne $f[14] -or -not $Key.VerifyData($raw,$signature,[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1)){throw 'LIFECYCLE_POLL_RECORD_REJECTED'}
 $body=ConvertFrom-AuthWireCandidateJson $payload
 Assert-AuthWireCandidateFields $body @('capability','release_id')
 foreach($n in @('capability','release_id')){if($body.$n -isnot [string]){throw 'LIFECYCLE_POLL_RECORD_REJECTED'}}
 if($body.capability -cne 'combined.filesystem.write.v1' -or $body.release_id -cne $Release){throw 'LIFECYCLE_POLL_PROOF_REJECTED'}
 return $f[10]
}
