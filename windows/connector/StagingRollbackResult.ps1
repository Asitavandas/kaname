# Source-only immutable rollback RESULT; reporting never reclaims or executes.
Set-StrictMode -Version 2

function Assert-AuthWireNoActiveRollback([string]$Root,[string]$JobId){
 $job=Join-Path $Root $JobId;$p=[AuthWire.Staging.TreeLeaseV1]::new()
 try{
  $file=Join-Path $job 'rollback-launch.json'
  if(Test-Path -LiteralPath $file){
   $p.PinFile($file);$v=Read-AuthWireStagingJournal $file
   if($v.gate_name -isnot [string] -or $v.gate_name -cnotmatch ('\ALocal\\AuthWireRollback-'+([guid]$JobId).ToString('N')+'-[0-9a-f]{32}\z')){throw 'ROLLBACK_RESULT_LAUNCH_REJECTED'}
   $g=$null;try{$g=[Threading.EventWaitHandle]::OpenExisting($v.gate_name,[Security.AccessControl.EventWaitHandleRights]::Synchronize)}catch [Threading.WaitHandleCannotBeOpenedException]{}
   if($g){$g.Dispose();throw 'ROLLBACK_RESULT_CHILD_ACTIVE'}
  }
  $file=Join-Path $job 'rollback-child.json'
  if(Test-Path -LiteralPath $file){
   $p.PinFile($file);$v=Read-AuthWireStagingJournal $file
   if(-not (Test-AuthWireWriteInteger $v.process_id) -or $v.process_started_ticks -isnot [string] -or $v.process_started_ticks -cnotmatch '\A[1-9][0-9]{16,18}\z'){throw 'ROLLBACK_CHILD_IDENTITY_REJECTED'}
   $process=$null;try{$process=[Diagnostics.Process]::GetProcessById([int]$v.process_id)}catch [ArgumentException]{}
   if($process){try{if(-not $process.HasExited -and $process.StartTime.ToUniversalTime().Ticks.ToString([Globalization.CultureInfo]::InvariantCulture) -ceq $v.process_started_ticks){throw 'ROLLBACK_RESULT_CHILD_ACTIVE'}}finally{$process.Dispose()}}
  }
 }finally{$p.Dispose()}
}
function Assert-AuthWireFrozenRollbackResult($Body,$Authorization){
 Assert-AuthWireCandidateFields $Body @('job_id','lease_id','intent_sha256','target_sha256','release_id','authorization_id','checked_at','outcome','reason','journal_sha256','tree_sha256','filesystem_effects')
 Assert-AuthWireStageStrings $Body @('job_id','lease_id','intent_sha256','target_sha256','release_id','authorization_id','outcome','reason','journal_sha256','tree_sha256','filesystem_effects')
 $a=$Authorization;$o=$a.Offer;$now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
 if($o.operation -cne 'combined.filesystem.rollback.v1' -or $Body.job_id -cne $o.job_id -or $Body.lease_id -cne $o.lease_id -or $Body.intent_sha256 -cne $o.intent_sha256 -or $Body.target_sha256 -cne (Get-AuthWireWriteHash $o.target) -or
    $Body.release_id -cne $a.Receipt.release_id -or $Body.authorization_id -cne $a.Receipt.grant.authorization_id -or -not (Test-AuthWireWriteInteger $Body.checked_at) -or $Body.checked_at -lt $a.Receipt.received_at -or $Body.checked_at -gt $now){throw 'ROLLBACK_RESULT_BODY_REJECTED'}
 if($Body.outcome -ceq 'rolled_back'){
  if($Body.checked_at -ge $a.Receipt.grant.expires_at -or $Body.reason -cne 'OK' -or $Body.filesystem_effects -cne 'removed_owned_directory' -or -not (Test-AuthWireWriteHash $Body.journal_sha256) -or $Body.tree_sha256 -cne $o.target.stage_receipt.staged_tree_sha256){throw 'ROLLBACK_RESULT_BODY_REJECTED'}
 }elseif($Body.outcome -ceq 'requires_review'){
  if($Body.reason -cne 'OUTCOME_UNKNOWN' -or $Body.filesystem_effects -cne 'unconfirmed' -or $Body.journal_sha256 -cne '' -or $Body.tree_sha256 -cne '' -or $Body.checked_at -gt $o.expires_at+300){throw 'ROLLBACK_RESULT_BODY_REJECTED'}
 }else{throw 'ROLLBACK_RESULT_BODY_REJECTED'}
}
function Read-AuthWireObservedRollbackBody([string]$Root,[string]$JobId,[hashtable]$Binding,[string]$Release,[Security.Cryptography.RSACng]$Key){
 $pins=New-AuthWireRollbackExecutionInputPins $Root $JobId $Binding $Release;$p=[AuthWire.Staging.TreeLeaseV1]::new()
 try{
  $s=Read-AuthWireAuthorizedRollbackIntentEvidence $Root $JobId $Binding $Release $Key;$a=$s.Authorization;$job=Join-Path $Root $JobId
  if(Test-Path -LiteralPath (Join-Path $job 'rollback-execution-requires-review.json')){throw 'ROLLBACK_REVIEW_NOT_SUCCESS'}
  foreach($n in @('rollback-launch.json','rollback-child.json','rollback-execution-preflight.json','rollback-execution-complete.json','rollback-execution-observed.json')){$p.PinFile((Join-Path $job $n))}
  $launch=Read-AuthWireRollbackLaunch $Root $JobId $s;$identity=Read-AuthWireRollbackChildIdentity $Root $JobId $launch;$c=Get-AuthWireRollbackCompletion $Root $JobId $s $launch $Binding
  $done=Read-AuthWireStagingJournal (Join-Path $job 'rollback-execution-complete.json');$ob=Read-AuthWireStagingJournal (Join-Path $job 'rollback-execution-observed.json')
  Assert-AuthWireCandidateFields $ob @('format','job_id','result_sha256','rollback_journal_sha256','baseline_sha256','observed_at')
  Assert-AuthWireStageStrings $ob @('format','job_id','result_sha256','rollback_journal_sha256','baseline_sha256')
  if($ob.format -cne 'AuthWireRollbackObservedV1' -or $ob.job_id -cne $JobId -or $ob.result_sha256 -cne (Get-AuthWireWriteHash $done) -or $ob.rollback_journal_sha256 -cne $c.RollbackJournalSha256 -or $ob.baseline_sha256 -cne $c.BaselineSha256 -or
     -not (Test-AuthWireWriteInteger $ob.observed_at) -or $ob.observed_at -gt [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()){throw 'ROLLBACK_OBSERVATION_REJECTED'}
  Assert-AuthWireRollbackChildResult $done $s $launch $identity $c $ob.observed_at
  $body=[pscustomobject]@{job_id=$JobId;lease_id=$a.Offer.lease_id;intent_sha256=$a.Offer.intent_sha256;target_sha256=(Get-AuthWireWriteHash $a.Offer.target);release_id=$Release;authorization_id=$a.Receipt.grant.authorization_id;checked_at=$done.checked_at;outcome='rolled_back';reason='OK';journal_sha256=$c.RollbackJournalSha256;tree_sha256=$c.TreeSha256;filesystem_effects='removed_owned_directory'}
  Assert-AuthWireFrozenRollbackResult $body $a
  return $body
 }finally{$p.Dispose();Close-AuthWireRollbackExecutionInputPins $pins}
}
function Read-AuthWireRollbackResultOutbox([string]$Root,[string]$JobId,[hashtable]$Binding,[string]$Release,[Security.Cryptography.RSACng]$Key){
 $a=Read-AuthWireRollbackAuthorizationEvidence $Root $JobId $Binding $Release $Key;$p=[AuthWire.Staging.TreeLeaseV1]::new()
 try{
  $file=Join-Path (Join-Path $Root $JobId) 'rollback-result-outbox.json';$p.PinFile($file);$v=Read-AuthWireStagingJournal $file
  Assert-AuthWireCandidateFields $v @('format','binding_scope','release_id','job_id','authorization_sha256','body_sha256','body')
  Assert-AuthWireStageStrings $v @('format','binding_scope','release_id','job_id','authorization_sha256','body_sha256')
  if($v.format -cne 'AuthWireRollbackResultOutboxV1' -or $v.binding_scope -cne (Get-AuthWireJobScope $Binding) -or $v.release_id -cne $Release -or $v.job_id -cne $JobId -or $v.authorization_sha256 -cne $a.AuthorizationSha256 -or $v.body_sha256 -cne (Get-AuthWireWriteHash $v.body)){throw 'ROLLBACK_OUTBOX_REJECTED'}
  Assert-AuthWireFrozenRollbackResult $v.body $a
  if($v.body.outcome -ceq 'rolled_back'){
   $observed=Read-AuthWireObservedRollbackBody $Root $JobId $Binding $Release $Key
   if((Get-AuthWireWriteHash $observed) -cne $v.body_sha256){throw 'ROLLBACK_OUTBOX_OBSERVATION_REJECTED'}
  }
  return $v
 }finally{$p.Dispose()}
}
function New-AuthWireRollbackResultOutbox([string]$Root,[string]$JobId,[hashtable]$Binding,[string]$Release,[Security.Cryptography.RSACng]$Key){
 $lock=Enter-AuthWireWriteOutcomeLock $JobId;$p=[AuthWire.Staging.TreeLeaseV1]::new()
 try{
  $a=Read-AuthWireRollbackAuthorizationEvidence $Root $JobId $Binding $Release $Key;$job=Join-Path $Root $JobId;$p.PinAncestors($Root);$p.PinAncestors($job)
  Assert-AuthWireNoActiveRollback $Root $JobId
  if(Test-Path -LiteralPath (Join-Path $job 'rollback-result-outbox.json')){return (Read-AuthWireRollbackResultOutbox $Root $JobId $Binding $Release $Key)}
  $now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds();$o=$a.Offer
  $body=[pscustomobject]@{job_id=$JobId;lease_id=$o.lease_id;intent_sha256=$o.intent_sha256;target_sha256=(Get-AuthWireWriteHash $o.target);release_id=$Release;authorization_id=$a.Receipt.grant.authorization_id;checked_at=$now;outcome='requires_review';reason='OUTCOME_UNKNOWN';journal_sha256='';tree_sha256='';filesystem_effects='unconfirmed'}
  if((Test-Path -LiteralPath (Join-Path $job 'rollback-execution-observed.json')) -and -not (Test-Path -LiteralPath (Join-Path $job 'rollback-execution-requires-review.json'))){$body=Read-AuthWireObservedRollbackBody $Root $JobId $Binding $Release $Key}
  Assert-AuthWireFrozenRollbackResult $body $a
  if($now-$body.checked_at -gt 300 -or $now -gt $o.expires_at+300){throw 'ROLLBACK_RESULT_WINDOW_EXPIRED'}
  $v=[pscustomobject]@{format='AuthWireRollbackResultOutboxV1';binding_scope=(Get-AuthWireJobScope $Binding);release_id=$Release;job_id=$JobId;authorization_sha256=$a.AuthorizationSha256;body_sha256=(Get-AuthWireWriteHash $body);body=$body}
  Write-AuthWireStagingJournal (Join-Path $job 'rollback-result-outbox.json') $v
  return $v
 }finally{$p.Dispose();$lock.ReleaseMutex();$lock.Dispose()}
}

function Send-AuthWireRollbackResult([string]$JournalRoot,[string]$JobId,[hashtable]$Binding,[string]$Release,[Security.Cryptography.RSACng]$Key,[string]$BaseUrl){
 $outbox=New-AuthWireRollbackResultOutbox $JournalRoot $JobId $Binding $Release $Key
 $lock=Enter-AuthWireWriteOutcomeLock $JobId;$p=[AuthWire.Staging.TreeLeaseV1]::new()
 try{
  $job=Join-Path $JournalRoot $JobId;$p.PinAncestors($JournalRoot);$p.PinAncestors($job);$p.PinFile((Join-Path $job 'rollback-result-outbox.json'))
  Assert-AuthWireNoActiveRollback $JournalRoot $JobId
  $outbox=Read-AuthWireRollbackResultOutbox $JournalRoot $JobId $Binding $Release $Key
  $accepted=Join-Path $job 'rollback-result-accepted.json'
  if(Test-Path -LiteralPath $accepted){
   $p.PinFile($accepted);$v=Read-AuthWireStagingJournal $accepted
   Assert-AuthWireCandidateFields $v @('format','job_id','body_sha256','request_id','ack')
   Assert-AuthWireStageStrings $v @('format','job_id','body_sha256','request_id')
   if($v.format -cne 'AuthWireRollbackResultAcceptedV1' -or $v.job_id -cne $JobId -or $v.body_sha256 -cne $outbox.body_sha256 -or -not (Test-AuthWireWriteHash $v.request_id)){throw 'WRITE_RESULT_ACK_REJECTED'}
   Assert-AuthWireWriteResultAck $v.ack $v.request_id $JobId
   return [pscustomobject]@{JobId=$JobId;ResultRecorded=$true;AlreadyRecorded=$true;CanApplyGpo=$false}
  }
  $attempt=0
  foreach($n in 1..3){$file=Join-Path $job ('rollback-result-attempt-'+$n+'.json');if(Test-Path -LiteralPath $file){if($attempt -ne 0){throw 'WRITE_RESULT_ATTEMPT_GAP_REQUIRES_REVIEW'};$p.PinFile($file);$v=Read-AuthWireStagingJournal $file;Assert-AuthWireCandidateFields $v @('format','job_id','body_sha256','attempt');Assert-AuthWireStageStrings $v @('format','job_id','body_sha256');if($v.format -cne 'AuthWireRollbackResultAttemptV1' -or $v.job_id -cne $JobId -or $v.body_sha256 -cne $outbox.body_sha256 -or $v.attempt -isnot [int] -or $v.attempt -ne $n){throw 'WRITE_RESULT_ATTEMPT_REJECTED'}}elseif($attempt -eq 0){$attempt=$n}}
  if($attempt -eq 0){throw 'WRITE_RESULT_ATTEMPT_LIMIT_REQUIRES_REVIEW'}
  Write-AuthWireStagingJournal (Join-Path $job ('rollback-result-attempt-'+$attempt+'.json')) ([pscustomobject]@{format='AuthWireRollbackResultAttemptV1';job_id=$JobId;body_sha256=$outbox.body_sha256;attempt=$attempt})
  $body=@{};foreach($field in $outbox.body.PSObject.Properties){$body[$field.Name]=$field.Value}
  $proof=New-AuthWireStagingWriteProof $Binding $Key RESULT $body
  $request=[Text.Encoding]::ASCII.GetString([Convert]::FromBase64String($proof.frame)).Split([char]10)[10]
  Write-AuthWireStagingJournal (Join-Path $job ('rollback-result-proof-'+$attempt+'.json')) ([pscustomobject]@{format='AuthWireRollbackResultProofV1';job_id=$JobId;body_sha256=$outbox.body_sha256;proof=$proof})
  Initialize-AuthWireWriteTransportTypes
  $raw=[AuthWire.Connector.WriteTransportV1]::Post($BaseUrl,$Binding.appliance_fqdn,$Binding.appliance_tls_sha256,'/api/connector/v1/staging-write/result',(ConvertTo-AuthWireWriteJson $proof))
  $ack=ConvertFrom-AuthWireCandidateJson ([Text.UTF8Encoding]::new($false,$true).GetBytes($raw));Assert-AuthWireWriteResultAck $ack $request $JobId
  Write-AuthWireStagingJournal $accepted ([pscustomobject]@{format='AuthWireRollbackResultAcceptedV1';job_id=$JobId;body_sha256=$outbox.body_sha256;request_id=$request;ack=$ack})
  return [pscustomobject]@{JobId=$JobId;ResultRecorded=$true;AlreadyRecorded=$false;CanApplyGpo=$false}
 }finally{$p.Dispose();$lock.ReleaseMutex();$lock.Dispose()}
}
