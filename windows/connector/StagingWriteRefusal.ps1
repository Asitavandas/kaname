# Source-only lifecycle refusal outbox. No CLAIM, writer, unlock or AD reader.
# Only the current dispatch can freeze a preflight refusal. Restart only sends
# an already frozen body; missing/partial evidence requires reconciliation.
Set-StrictMode -Version 2

function New-AuthWireWriteRefusalInputPins([string]$Root,[string]$Life,$State,[hashtable]$Binding,[Security.Cryptography.RSACng]$Key){
 Assert-AuthWireStagingWriteJournalLocation $Root $Binding
 if($Life -cne (Get-AuthWireWriteLifecyclePath $Root $Binding)){throw 'WRITE_REFUSAL_ROOT_REJECTED'}
 $p=[AuthWire.Staging.TreeLeaseV1]::new()
 try{
  $p.PinAncestors($Root);$dir=Join-Path $Life $State.Slot;$p.PinAncestors($dir)
  foreach($n in @('poll-started.json','poll-proof.json','poll-sent.json','poll-response.json','dispatch-started.json','dispatch-failed.json')){$p.PinFile((Join-Path $dir $n))}
  $actual=Read-AuthWireLifecyclePoll $Life $State.Slot $Binding $Key
  if($actual.Phase -cne 'reply_saved' -or $null -eq $actual.Offer -or $actual.Offer.job_id -ceq '' -or (Get-AuthWireWriteHash $actual) -cne (Get-AuthWireWriteHash $State)){throw 'WRITE_REFUSAL_POLL_REJECTED'}
  Assert-AuthWireLifecycleDispatch $Life $State
  $o=$State.Offer;$release=$State.Started.release_id;$job=Join-Path $Root $o.job_id;$p.PinAncestors($job)
  # Strict allow-list: even a CLAIM signing-start marker or unknown file makes
  # "none" unsafe. Pin every existing file, rejecting hardlinks/ADS/reparse.
  $allowed=@('refusal-outbox.json','refusal-accepted.json')
  foreach($i in 1..3){foreach($kind in @('attempt','proof')){$allowed+=,('refusal-'+$kind+'-'+$i+'.json')}}
  if($o.operation -ceq 'combined.filesystem.stage.v1'){$allowed+=@('offer.json','preflight.json')}
  else{$allowed+=@('rollback-offer.json','rollback-preflight.json')}
  foreach($i in Get-ChildItem -LiteralPath $job -Force){if($i.PSIsContainer -or $i.Name -cnotin $allowed){throw 'WRITE_REFUSAL_CLAIM_OR_UNKNOWN_HISTORY'};$p.PinFile($i.FullName)}
  # Validate the original offer at receipt time, not by renewing its lease.
  if($o.operation -ceq 'combined.filesystem.stage.v1'){
   $saved=Read-AuthWireStagingWriteOfferAt $Root $o.job_id $Binding $release $State.Response.received_at
  }else{
   $saved=(Read-AuthWireRollbackOfferAt $Root $o.job_id $Binding $release $State.Response.received_at).Offer
   $p.PinFile((Get-AuthWireRollbackReservationPath $Root $o.target.stage_receipt.stage_job_id))
  }
  $p.PinFile((Join-Path $Root ('gpo-'+$o.target.scope_target.gpo_id+'.json')))
  if((Get-AuthWireWriteHash $saved) -cne (Get-AuthWireWriteHash $o)){throw 'WRITE_REFUSAL_OFFER_REJECTED'}
  $failure=Read-AuthWireStagingJournal (Join-Path $dir 'dispatch-failed.json')
  if($failure.phase -cne 'preflight' -or $failure.checked_at -ge $o.expires_at){throw 'WRITE_REFUSAL_FAILURE_REJECTED'}
  return $p
 }catch{$p.Dispose();throw}
}
function Read-AuthWireWriteRefusalOutbox([string]$Root,[string]$Life,$State,[hashtable]$Binding,[Security.Cryptography.RSACng]$Key){
 $p=New-AuthWireWriteRefusalInputPins $Root $Life $State $Binding $Key
 try{
  $o=$State.Offer;$dir=Join-Path $Life $State.Slot;$file=Join-Path (Join-Path $Root $o.job_id) 'refusal-outbox.json';$p.PinFile($file)
  $v=Read-AuthWireStagingJournal $file;$f=Read-AuthWireStagingJournal (Join-Path $dir 'dispatch-failed.json')
  Assert-AuthWireCandidateFields $v @('format','binding_scope','release_id','slot','response_sha256','failure_sha256','body_sha256','body')
  Assert-AuthWireStageStrings $v @('format','binding_scope','release_id','slot','response_sha256','failure_sha256','body_sha256')
  $b=$v.body
  Assert-AuthWireCandidateFields $b @('job_id','lease_id','intent_sha256','target_sha256','release_id','authorization_id','checked_at','outcome','reason','journal_sha256','tree_sha256','filesystem_effects')
  Assert-AuthWireStageStrings $b @('job_id','lease_id','intent_sha256','target_sha256','release_id','authorization_id','outcome','reason','journal_sha256','tree_sha256','filesystem_effects')
  if($v.format -cne 'AuthWireWriteRefusalOutboxV1' -or $v.binding_scope -cne (Get-AuthWireJobScope $Binding) -or $v.release_id -cne $State.Started.release_id -or $v.slot -cne $State.Slot -or
     $v.response_sha256 -cne (Get-AuthWireWriteHash $State.Response) -or $v.failure_sha256 -cne (Get-AuthWireWriteHash $f) -or $v.body_sha256 -cne (Get-AuthWireWriteHash $b) -or
     $b.job_id -cne $o.job_id -or $b.lease_id -cne $o.lease_id -or $b.intent_sha256 -cne $o.intent_sha256 -or $b.target_sha256 -cne (Get-AuthWireWriteHash $o.target) -or $b.release_id -cne $State.Started.release_id -or
     $b.authorization_id -cne '' -or -not (Test-AuthWireWriteInteger $b.checked_at) -or $b.checked_at -ne $f.checked_at -or $b.outcome -cne 'refused_before_authorization' -or
     $b.reason -cne 'PREFLIGHT_FAILED' -or $b.journal_sha256 -cne '' -or $b.tree_sha256 -cne '' -or $b.filesystem_effects -cne 'none'){throw 'WRITE_REFUSAL_OUTBOX_REJECTED'}
  return $v
 }finally{$p.Dispose()}
}
function New-AuthWireWriteRefusalOutbox([string]$Root,[string]$Life,$State,[hashtable]$Binding,[Security.Cryptography.RSACng]$Key){
 $decision=Enter-AuthWireWritePreauthorizationLock $State.Offer.job_id;$p=$null
 try{
  $p=New-AuthWireWriteRefusalInputPins $Root $Life $State $Binding $Key
  $o=$State.Offer;$file=Join-Path (Join-Path $Root $o.job_id) 'refusal-outbox.json'
  if(Test-Path -LiteralPath $file){return (Read-AuthWireWriteRefusalOutbox $Root $Life $State $Binding $Key)}
  $now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
  $f=Read-AuthWireStagingJournal (Join-Path (Join-Path $Life $State.Slot) 'dispatch-failed.json')
  # Freeze only during the original dispatch/lease. Recovery never calls this.
  if($now -ge $o.expires_at -or $now-$f.checked_at -gt 5){throw 'WRITE_REFUSAL_WINDOW_EXPIRED'}
  $body=[pscustomobject][ordered]@{job_id=$o.job_id;lease_id=$o.lease_id;intent_sha256=$o.intent_sha256;target_sha256=(Get-AuthWireWriteHash $o.target);release_id=$State.Started.release_id;authorization_id='';checked_at=$f.checked_at;outcome='refused_before_authorization';reason='PREFLIGHT_FAILED';journal_sha256='';tree_sha256='';filesystem_effects='none'}
  $v=[pscustomobject]@{format='AuthWireWriteRefusalOutboxV1';binding_scope=(Get-AuthWireJobScope $Binding);release_id=$State.Started.release_id;slot=$State.Slot;response_sha256=(Get-AuthWireWriteHash $State.Response);failure_sha256=(Get-AuthWireWriteHash $f);body_sha256=(Get-AuthWireWriteHash $body);body=$body}
  # CreateNew + Flush(true) reserves the no-CLAIM decision, including partial IO.
  Write-AuthWireStagingJournal $file $v
  return (Read-AuthWireWriteRefusalOutbox $Root $Life $State $Binding $Key)
 }finally{if($p){$p.Dispose()};$decision.ReleaseMutex();$decision.Dispose()}
}
function Read-AuthWireWriteRefusalAccepted([string]$Root,$State,$Outbox){
 $file=Join-Path (Join-Path $Root $State.Offer.job_id) 'refusal-accepted.json';$p=[AuthWire.Staging.TreeLeaseV1]::new()
 try{
  $p.PinFile($file);$v=Read-AuthWireStagingJournal $file
  Assert-AuthWireCandidateFields $v @('format','job_id','body_sha256','request_id','ack')
  Assert-AuthWireStageStrings $v @('format','job_id','body_sha256','request_id')
  if($v.format -cne 'AuthWireWriteRefusalAcceptedV1' -or $v.job_id -cne $State.Offer.job_id -or $v.body_sha256 -cne $Outbox.body_sha256 -or -not (Test-AuthWireWriteHash $v.request_id)){throw 'WRITE_REFUSAL_ACK_REJECTED'}
  Assert-AuthWireWriteResultAck $v.ack $v.request_id $v.job_id
  return $v
 }finally{$p.Dispose()}
}
function Send-AuthWireWriteRefusal([string]$Root,[string]$Life,$State,[hashtable]$Binding,[Security.Cryptography.RSACng]$Key,[string]$BaseUrl){
 $decision=Enter-AuthWireWritePreauthorizationLock $State.Offer.job_id;$p=$null
 try{
  $p=New-AuthWireWriteRefusalInputPins $Root $Life $State $Binding $Key
  $box=Read-AuthWireWriteRefusalOutbox $Root $Life $State $Binding $Key;$job=Join-Path $Root $State.Offer.job_id
  if(Test-Path -LiteralPath (Join-Path $job 'refusal-accepted.json')){$null=Read-AuthWireWriteRefusalAccepted $Root $State $box;return}
  $attempt=0
  foreach($n in 1..3){
   $file=Join-Path $job ('refusal-attempt-'+$n+'.json')
   if(Test-Path -LiteralPath $file){
    if($attempt -ne 0){throw 'WRITE_REFUSAL_ATTEMPT_GAP'}
    $v=Read-AuthWireStagingJournal $file;Assert-AuthWireCandidateFields $v @('format','job_id','body_sha256','attempt')
    if($v.format -cne 'AuthWireWriteRefusalAttemptV1' -or $v.job_id -cne $State.Offer.job_id -or $v.body_sha256 -cne $box.body_sha256 -or $v.attempt -isnot [int] -or $v.attempt -ne $n){throw 'WRITE_REFUSAL_ATTEMPT_REJECTED'}
   }elseif($attempt -eq 0){$attempt=$n}
  }
  if($attempt -eq 0){throw 'WRITE_REFUSAL_ATTEMPT_LIMIT'}
  Write-AuthWireStagingJournal (Join-Path $job ('refusal-attempt-'+$attempt+'.json')) ([pscustomobject]@{format='AuthWireWriteRefusalAttemptV1';job_id=$State.Offer.job_id;body_sha256=$box.body_sha256;attempt=$attempt})
  $body=@{};foreach($field in $box.body.PSObject.Properties){$body[$field.Name]=$field.Value}
  $proof=New-AuthWireStagingWriteProof $Binding $Key RESULT $body
  $request=[Text.Encoding]::ASCII.GetString([Convert]::FromBase64String($proof.frame)).Split([char]10)[10]
  Write-AuthWireStagingJournal (Join-Path $job ('refusal-proof-'+$attempt+'.json')) ([pscustomobject]@{format='AuthWireWriteRefusalProofV1';job_id=$State.Offer.job_id;body_sha256=$box.body_sha256;proof=$proof})
  Initialize-AuthWireWriteTransportTypes
  $raw=[AuthWire.Connector.WriteTransportV1]::Post($BaseUrl,$Binding.appliance_fqdn,$Binding.appliance_tls_sha256,'/api/connector/v1/staging-write/result',(ConvertTo-AuthWireWriteJson $proof))
  $ack=ConvertFrom-AuthWireCandidateJson ([Text.UTF8Encoding]::new($false,$true).GetBytes($raw));Assert-AuthWireWriteResultAck $ack $request $State.Offer.job_id
  Write-AuthWireStagingJournal (Join-Path $job 'refusal-accepted.json') ([pscustomobject]@{format='AuthWireWriteRefusalAcceptedV1';job_id=$State.Offer.job_id;body_sha256=$box.body_sha256;request_id=$request;ack=$ack})
 }finally{if($p){$p.Dispose()};$decision.ReleaseMutex();$decision.Dispose()}
}
