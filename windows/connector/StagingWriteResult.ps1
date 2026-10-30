# Source-only immutable result outbox. Never executes, reclaims, deletes or unlocks.
Set-StrictMode -Version 2
function Assert-AuthWireNoActiveStage([string]$JournalRoot,[string]$JobId){
 $job=Join-Path $JournalRoot $JobId;$p=[AuthWire.Staging.TreeLeaseV1]::new()
 try{
  $path=Join-Path $job 'stage-launch.json'
  if(Test-Path -LiteralPath $path){
   $p.PinFile($path);$v=Read-AuthWireStagingJournal $path
   if($v.gate_name -isnot [string] -or $v.gate_name -cnotmatch ('\ALocal\\AuthWireStage-'+([guid]$JobId).ToString('N')+'-[0-9a-f]{32}\z')){throw 'WRITE_RESULT_LAUNCH_REJECTED'}
   $g=$null
   try{$g=[Threading.EventWaitHandle]::OpenExisting($v.gate_name,[Security.AccessControl.EventWaitHandleRights]::Synchronize)}catch [Threading.WaitHandleCannotBeOpenedException]{}
   if($g){$g.Dispose();throw 'WRITE_RESULT_STAGE_STILL_ACTIVE'}
  }
  $path=Join-Path $job 'stage-child.json'
  if(Test-Path -LiteralPath $path){
   $p.PinFile($path);$v=Read-AuthWireStagingJournal $path
   if(-not (Test-AuthWireWriteInteger $v.process_id) -or $v.process_started_ticks -isnot [string] -or $v.process_started_ticks -cnotmatch '\A[1-9][0-9]{16,18}\z'){throw 'WRITE_RESULT_CHILD_REJECTED'}
   $process=$null;try{$process=[Diagnostics.Process]::GetProcessById([int]$v.process_id)}catch [ArgumentException]{}
   if($process){try{if(-not $process.HasExited -and $process.StartTime.ToUniversalTime().Ticks.ToString([Globalization.CultureInfo]::InvariantCulture) -ceq $v.process_started_ticks){throw 'WRITE_RESULT_STAGE_STILL_ACTIVE'}}finally{$process.Dispose()}}
  }
 }finally{$p.Dispose()}
}
function Assert-AuthWireFrozenWriteResult($Body,$Authorization){
 Assert-AuthWireCandidateFields $Body @('job_id','lease_id','intent_sha256','target_sha256','release_id','authorization_id','checked_at','outcome','reason','journal_sha256','tree_sha256','filesystem_effects')
 Assert-AuthWireStageStrings $Body @('job_id','lease_id','intent_sha256','target_sha256','release_id','authorization_id','outcome','reason','journal_sha256','tree_sha256','filesystem_effects')
 $a=$Authorization;$o=$a.Offer;$now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
 if($Body.job_id -cne $o.job_id -or $Body.lease_id -cne $o.lease_id -or $Body.intent_sha256 -cne $o.intent_sha256 -or $Body.target_sha256 -cne (Get-AuthWireWriteHash $o.target) -or $Body.release_id -cne $a.Receipt.release_id -or $Body.authorization_id -cne $a.Receipt.grant.authorization_id -or
    -not (Test-AuthWireWriteInteger $Body.checked_at) -or $Body.checked_at -lt $a.Receipt.received_at -or $Body.checked_at -gt $now){throw 'WRITE_RESULT_BODY_REJECTED'}
 if($Body.outcome -ceq 'staged'){
  if($Body.checked_at -ge $a.Receipt.grant.expires_at -or $Body.reason -cne 'OK' -or $Body.filesystem_effects -cne 'created_owned_directory' -or -not (Test-AuthWireWriteHash $Body.journal_sha256) -or -not (Test-AuthWireWriteHash $Body.tree_sha256)){throw 'WRITE_RESULT_BODY_REJECTED'}
 }elseif($Body.outcome -ceq 'requires_review'){
  if($Body.reason -cne 'OUTCOME_UNKNOWN' -or $Body.filesystem_effects -cne 'unconfirmed' -or $Body.journal_sha256 -cne '' -or $Body.tree_sha256 -cne '' -or $Body.checked_at -gt $o.expires_at+300){throw 'WRITE_RESULT_BODY_REJECTED'}
 }else{throw 'WRITE_RESULT_BODY_REJECTED'}
}
function Read-AuthWireWriteResultOutbox([string]$JournalRoot,[string]$JobId,[hashtable]$Binding,[string]$Release,[Security.Cryptography.RSACng]$Key){
 $a=Read-AuthWireWriteAuthorizationEvidence $JournalRoot $JobId $Binding $Release $Key
 $p=[AuthWire.Staging.TreeLeaseV1]::new()
 try{
  $p.PinAncestors($JournalRoot);$p.PinAncestors((Join-Path $JournalRoot $JobId));$file=Join-Path (Join-Path $JournalRoot $JobId) 'result-outbox.json';$p.PinFile($file)
  $v=Read-AuthWireStagingJournal $file
  Assert-AuthWireCandidateFields $v @('format','binding_scope','release_id','job_id','authorization_sha256','body_sha256','body')
  Assert-AuthWireStageStrings $v @('format','binding_scope','release_id','job_id','authorization_sha256','body_sha256')
  if($v.format -cne 'AuthWireWriteResultOutboxV1' -or $v.binding_scope -cne (Get-AuthWireJobScope $Binding) -or $v.release_id -cne $Release -or $v.job_id -cne $JobId -or $v.authorization_sha256 -cne $a.AuthorizationSha256 -or $v.body_sha256 -cne (Get-AuthWireWriteHash $v.body)){throw 'WRITE_RESULT_OUTBOX_REJECTED'}
  Assert-AuthWireFrozenWriteResult $v.body $a
  return $v
 }finally{$p.Dispose()}
}
function Read-AuthWireObservedStageBody([string]$JournalRoot,[string]$JobId,[hashtable]$Binding,[string]$Release,[Security.Cryptography.RSACng]$Key){
 # Same historical observation/completion checks as New-AuthWireWriteResultOutbox,
 # without outbox creation, promotion, fresh timestamps or report-window renewal.
 $a=Read-AuthWireWriteAuthorizationEvidence $JournalRoot $JobId $Binding $Release $Key
 $p=[AuthWire.Staging.TreeLeaseV1]::new()
 try{
  $job=Join-Path $JournalRoot $JobId;$p.PinAncestors($JournalRoot);$p.PinAncestors($job)
  $o=$a.Offer;$now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
  $body=[pscustomobject][ordered]@{job_id=$JobId;lease_id=$o.lease_id;intent_sha256=$o.intent_sha256;target_sha256=(Get-AuthWireWriteHash $o.target);release_id=$Release;authorization_id=$a.Receipt.grant.authorization_id;checked_at=$now;outcome='requires_review';reason='OUTCOME_UNKNOWN';journal_sha256='';tree_sha256='';filesystem_effects='unconfirmed'}
  $observed=Join-Path $job 'execution-observed.json'
  if(Test-Path -LiteralPath $observed){
   $s=Read-AuthWireAuthorizedStageIntentEvidence $JournalRoot $JobId $Binding $Release $Key
   $inputPins=New-AuthWireStageInputPins $JournalRoot $JobId $s.Authorization.Offer
   try{
    $launch=Read-AuthWireStageLaunch $JournalRoot $JobId $s;$complete=Get-AuthWireStageCompletion $JournalRoot $JobId $s $launch $Binding
    $p.PinFile($observed);$p.PinFile((Join-Path $job 'execution-complete.json'))
    $ob=Read-AuthWireStagingJournal $observed;$done=Read-AuthWireStagingJournal (Join-Path $job 'execution-complete.json')
    Assert-AuthWireCandidateFields $ob @('format','job_id','result_sha256','complete_sha256','observed_at')
    Assert-AuthWireStageStrings $ob @('format','job_id','result_sha256','complete_sha256')
    Assert-AuthWireCandidateFields $done @('format','job_id','filesystem_operation_id','execution_intent_sha256','authorization_sha256','launch_sha256','child_identity_sha256','stage_preflight_sha256','complete_sha256','tree_sha256','checked_at','file_count','staged','can_apply_gpo')
    Assert-AuthWireStageStrings $done @('format','job_id','filesystem_operation_id','execution_intent_sha256','authorization_sha256','launch_sha256','child_identity_sha256','stage_preflight_sha256','complete_sha256','tree_sha256')
    $identity=Read-AuthWireStageChildIdentity $JournalRoot $JobId $launch
    if($ob.format -cne 'AuthWireStageObservedV1' -or $ob.job_id -cne $JobId -or $ob.result_sha256 -cne (Get-AuthWireWriteHash $done) -or $ob.complete_sha256 -cne $complete.CompleteSha256 -or
       -not (Test-AuthWireWriteInteger $ob.observed_at) -or $ob.observed_at -gt $now -or $done.format -cne 'AuthWireAuthorizedStageResultV1' -or $done.job_id -cne $JobId -or $done.filesystem_operation_id -cne $s.Intent.filesystem_operation_id -or
       $done.execution_intent_sha256 -cne $s.IntentSha256 -or $done.authorization_sha256 -cne $a.AuthorizationSha256 -or $done.launch_sha256 -cne (Get-AuthWireWriteHash $launch) -or $done.child_identity_sha256 -cne (Get-AuthWireWriteHash $identity) -or
       $done.stage_preflight_sha256 -cne $complete.StagePreflightSha256 -or $done.complete_sha256 -cne $complete.CompleteSha256 -or $done.tree_sha256 -cne $complete.TreeSha256 -or
       -not (Test-AuthWireWriteInteger $done.checked_at) -or $done.checked_at -lt $launch.started_at -or $done.checked_at -gt $ob.observed_at -or $done.checked_at -ge $a.Receipt.grant.expires_at -or
       $done.file_count -isnot [int] -or $done.file_count -ne 20 -or $done.staged -isnot [bool] -or -not $done.staged -or $done.can_apply_gpo -isnot [bool] -or $done.can_apply_gpo){throw 'WRITE_RESULT_COMPLETION_REJECTED'}
    $body.checked_at=$done.checked_at;$body.outcome='staged';$body.reason='OK';$body.journal_sha256=$complete.CompleteSha256;$body.tree_sha256=$complete.TreeSha256;$body.filesystem_effects='created_owned_directory'
   }finally{$inputPins.Dispose()}
  }
  if($body.outcome -cne 'staged'){throw 'WRITE_STAGE_OBSERVATION_REQUIRED'}
  Assert-AuthWireFrozenWriteResult $body $a
  return $body
 }finally{$p.Dispose()}
}

function New-AuthWireWriteResultOutbox([string]$JournalRoot,[string]$JobId,[hashtable]$Binding,[string]$Release,[Security.Cryptography.RSACng]$Key){
 $a=Read-AuthWireWriteAuthorizationEvidence $JournalRoot $JobId $Binding $Release $Key
 $lock=Enter-AuthWireWriteOutcomeLock $JobId;$p=[AuthWire.Staging.TreeLeaseV1]::new()
 try{
  $p.PinAncestors($JournalRoot);$job=Join-Path $JournalRoot $JobId;$p.PinAncestors($job)
  Assert-AuthWireNoActiveStage $JournalRoot $JobId
  if(Test-Path -LiteralPath (Join-Path $job 'result-outbox.json')){return (Read-AuthWireWriteResultOutbox $JournalRoot $JobId $Binding $Release $Key)}
  $o=$a.Offer;$now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
  $body=[pscustomobject][ordered]@{job_id=$JobId;lease_id=$o.lease_id;intent_sha256=$o.intent_sha256;target_sha256=(Get-AuthWireWriteHash $o.target);release_id=$Release;authorization_id=$a.Receipt.grant.authorization_id;checked_at=$now;outcome='requires_review';reason='OUTCOME_UNKNOWN';journal_sha256='';tree_sha256='';filesystem_effects='unconfirmed'}
  $observed=Join-Path $job 'execution-observed.json'
  if(Test-Path -LiteralPath $observed){$body=Read-AuthWireObservedStageBody $JournalRoot $JobId $Binding $Release $Key}
  Assert-AuthWireFrozenWriteResult $body $a
  if($now-$body.checked_at -gt 300 -or $now -gt $o.expires_at+300){throw 'WRITE_RESULT_REPORT_WINDOW_EXPIRED'}
  $v=[pscustomobject]@{format='AuthWireWriteResultOutboxV1';binding_scope=(Get-AuthWireJobScope $Binding);release_id=$Release;job_id=$JobId;authorization_sha256=$a.AuthorizationSha256;body_sha256=(Get-AuthWireWriteHash $body);body=$body}
  Write-AuthWireStagingJournal (Join-Path $job 'result-outbox.json') $v
  return $v
 }finally{$p.Dispose();$lock.ReleaseMutex();$lock.Dispose()}
}
function Assert-AuthWireWriteResultAck($Value,[string]$RequestId,[string]$JobId){
 Assert-AuthWireCandidateFields $Value @('format','request_id','job_id','result_recorded','can_apply_gpo')
 if($Value.format -isnot [int] -or $Value.format -ne 1 -or $Value.request_id -isnot [string] -or $Value.request_id -cne $RequestId -or $Value.job_id -isnot [string] -or $Value.job_id -cne $JobId -or $Value.result_recorded -isnot [bool] -or -not $Value.result_recorded -or $Value.can_apply_gpo -isnot [bool] -or $Value.can_apply_gpo){throw 'WRITE_RESULT_ACK_REJECTED'}
}
function Send-AuthWireWriteResult([string]$JournalRoot,[string]$JobId,[hashtable]$Binding,[string]$Release,[Security.Cryptography.RSACng]$Key,[string]$BaseUrl){
 $outbox=New-AuthWireWriteResultOutbox $JournalRoot $JobId $Binding $Release $Key
 $lock=Enter-AuthWireWriteOutcomeLock $JobId;$p=[AuthWire.Staging.TreeLeaseV1]::new()
 try{
  $job=Join-Path $JournalRoot $JobId;$p.PinAncestors($JournalRoot);$p.PinAncestors($job);$p.PinFile((Join-Path $job 'result-outbox.json'))
  Assert-AuthWireNoActiveStage $JournalRoot $JobId
  $outbox=Read-AuthWireWriteResultOutbox $JournalRoot $JobId $Binding $Release $Key
  $accepted=Join-Path $job 'result-accepted.json'
  if(Test-Path -LiteralPath $accepted){
   $p.PinFile($accepted);$v=Read-AuthWireStagingJournal $accepted
   Assert-AuthWireCandidateFields $v @('format','job_id','body_sha256','request_id','ack')
   Assert-AuthWireStageStrings $v @('format','job_id','body_sha256','request_id')
   if($v.format -cne 'AuthWireWriteResultAcceptedV1' -or $v.job_id -cne $JobId -or $v.body_sha256 -cne $outbox.body_sha256 -or -not (Test-AuthWireWriteHash $v.request_id)){throw 'WRITE_RESULT_ACK_REJECTED'}
   Assert-AuthWireWriteResultAck $v.ack $v.request_id $JobId
   return [pscustomobject]@{JobId=$JobId;ResultRecorded=$true;AlreadyRecorded=$true;CanApplyGpo=$false}
  }
  $attempt=0
  foreach($n in 1..3){$file=Join-Path $job ('result-attempt-'+$n+'.json');if(Test-Path -LiteralPath $file){if($attempt -ne 0){throw 'WRITE_RESULT_ATTEMPT_GAP_REQUIRES_REVIEW'};$p.PinFile($file);$v=Read-AuthWireStagingJournal $file;Assert-AuthWireCandidateFields $v @('format','job_id','body_sha256','attempt');Assert-AuthWireStageStrings $v @('format','job_id','body_sha256');if($v.format -cne 'AuthWireWriteResultAttemptV1' -or $v.job_id -cne $JobId -or $v.body_sha256 -cne $outbox.body_sha256 -or $v.attempt -isnot [int] -or $v.attempt -ne $n){throw 'WRITE_RESULT_ATTEMPT_REJECTED'}}elseif($attempt -eq 0){$attempt=$n}}
  if($attempt -eq 0){throw 'WRITE_RESULT_ATTEMPT_LIMIT_REQUIRES_REVIEW'}
  Write-AuthWireStagingJournal (Join-Path $job ('result-attempt-'+$attempt+'.json')) ([pscustomobject]@{format='AuthWireWriteResultAttemptV1';job_id=$JobId;body_sha256=$outbox.body_sha256;attempt=$attempt})
  $body=@{};foreach($field in $outbox.body.PSObject.Properties){$body[$field.Name]=$field.Value}
  $proof=New-AuthWireStagingWriteProof $Binding $Key RESULT $body
  $request=[Text.Encoding]::ASCII.GetString([Convert]::FromBase64String($proof.frame)).Split([char]10)[10]
  Write-AuthWireStagingJournal (Join-Path $job ('result-proof-'+$attempt+'.json')) ([pscustomobject]@{format='AuthWireWriteResultProofV1';job_id=$JobId;body_sha256=$outbox.body_sha256;proof=$proof})
  Initialize-AuthWireWriteTransportTypes
  $raw=[AuthWire.Connector.WriteTransportV1]::Post($BaseUrl,$Binding.appliance_fqdn,$Binding.appliance_tls_sha256,'/api/connector/v1/staging-write/result',(ConvertTo-AuthWireWriteJson $proof))
  $ack=ConvertFrom-AuthWireCandidateJson ([Text.UTF8Encoding]::new($false,$true).GetBytes($raw));Assert-AuthWireWriteResultAck $ack $request $JobId
  Write-AuthWireStagingJournal $accepted ([pscustomobject]@{format='AuthWireWriteResultAcceptedV1';job_id=$JobId;body_sha256=$outbox.body_sha256;request_id=$request;ack=$ack})
  return [pscustomobject]@{JobId=$JobId;ResultRecorded=$true;AlreadyRecorded=$false;CanApplyGpo=$false}
 }finally{$p.Dispose();$lock.ReleaseMutex();$lock.Dispose()}
}
