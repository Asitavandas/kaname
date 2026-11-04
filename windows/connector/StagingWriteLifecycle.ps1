# Source-only durable stage/rollback dispatcher and result-only restart step.
# Not registered with the permanent worker or production peer routes.
# No unknown-state retry, cleanup, retention deletion, grant renewal or unlock.
Set-StrictMode -Version 2

function Get-AuthWireWriteLifecyclePath([string]$Root,[hashtable]$Binding){
 Assert-AuthWireStagingWriteJournalLocation $Root $Binding
 return (Join-Path $Root 'write-lifecycle')
}
function Read-AuthWireLifecycleLegacyStage([string]$Root,[hashtable]$Binding,[Security.Cryptography.RSACng]$Key){
 # Only a fully observed and accepted legacy stage may anchor an existing root.
 # Other existing history is not discarded or treated as a new empty store.
 $p=[AuthWire.Staging.TreeLeaseV1]::new()
 try{
  $p.PinAncestors($Root);$file=Join-Path $Root 'cycle-offer.json';$p.PinFile($file);$v=Read-AuthWireStagingJournal $file
  Assert-AuthWireCandidateGuid $v.release_id;$release=$v.release_id
  $v=Read-AuthWireWriteCycleOffer $Root $Binding $release
  $pollFile=Join-Path $Root 'cycle-poll.json';$p.PinFile($pollFile);$poll=Read-AuthWireStagingJournal $pollFile
  Assert-AuthWireCandidateFields $poll @('format','binding_scope','release_id','request_id','sent_at','proof')
  if($poll.format -cne 'AuthWireWriteCyclePollV1' -or $poll.binding_scope -cne (Get-AuthWireJobScope $Binding) -or $poll.release_id -cne $release -or -not (Test-AuthWireWriteInteger $poll.sent_at)){throw 'LIFECYCLE_LEGACY_REVIEW_REQUIRED'}
  $raw=ConvertFrom-AuthWireWriteBase64 $poll.proof.frame 2048;$frame=[Text.Encoding]::ASCII.GetString($raw).Split([char]10)
  if($frame.Count -ne 18 -or $frame[12] -cnotmatch '\A[1-9][0-9]{0,10}\z'){throw 'LIFECYCLE_LEGACY_REVIEW_REQUIRED'}
  # Legacy records have a send time, not a before-signing marker. The signed
  # original issue time is verified against that send time, never renewed.
  $request=Assert-AuthWireStoredWritePollAt $poll.proof $Binding $release $Key ([long]$frame[12]) $poll.sent_at
  if($request -cne $poll.request_id){throw 'LIFECYCLE_LEGACY_REVIEW_REQUIRED'}
  $s=Read-AuthWireAuthorizedStageIntentEvidence $Root $v.job_id $Binding $release $Key
  $body=Read-AuthWireObservedStageBody $Root $v.job_id $Binding $release $Key
  $box=Read-AuthWireWriteResultOutbox $Root $v.job_id $Binding $release $Key
  $file=Join-Path (Join-Path $Root $v.job_id) 'result-accepted.json';$p.PinFile($file);$ack=Read-AuthWireStagingJournal $file
  Assert-AuthWireCandidateFields $ack @('format','job_id','body_sha256','request_id','ack')
  Assert-AuthWireStageStrings $ack @('format','job_id','body_sha256','request_id')
  if($ack.format -cne 'AuthWireWriteResultAcceptedV1' -or $ack.job_id -cne $v.job_id -or $ack.body_sha256 -cne $box.body_sha256 -or (Get-AuthWireWriteHash $body) -cne $box.body_sha256 -or -not (Test-AuthWireWriteHash $ack.request_id)){throw 'LIFECYCLE_LEGACY_REVIEW_REQUIRED'}
  Assert-AuthWireWriteResultAck $ack.ack $ack.request_id $v.job_id
  Assert-AuthWireNoActiveStage $Root $v.job_id
  if(Test-Path -LiteralPath (Join-Path (Join-Path $Root $v.job_id) 'execution-requires-review.json')){throw 'LIFECYCLE_LEGACY_REVIEW_REQUIRED'}
  return [pscustomobject]@{job_id=$v.job_id;release_id=$release;operation_id=$s.Intent.filesystem_operation_id;gpo_id=$s.Authorization.Offer.target.scope_target.gpo_id;body_sha256=$box.body_sha256;ack_sha256=(Get-AuthWireWriteHash $ack)}
 }finally{$p.Dispose()}
}
function Initialize-AuthWireWriteLifecycle([string]$Root,[hashtable]$Binding,[Security.Cryptography.RSACng]$Key){
 $life=Get-AuthWireWriteLifecyclePath $Root $Binding
 if(Test-Path -LiteralPath $life){return}
 $items=@(Get-ChildItem -LiteralPath $Root -Force);$legacy=$null
 if($items.Count){
  $legacy=Read-AuthWireLifecycleLegacyStage $Root $Binding $Key
  foreach($n in @('rollback-started.json','rolled-back.json')){if(Test-Path -LiteralPath (Join-Path (Join-Path $Root $legacy.operation_id) $n)){throw 'LIFECYCLE_LEGACY_REVIEW_REQUIRED'}}
  $names=@('cycle-poll.json','cycle-offer.json',$legacy.job_id,$legacy.operation_id,('gpo-'+$legacy.gpo_id+'.json'))
  if($items.Count -ne 5 -or @($items|Where-Object {$_.Name -cnotin $names}).Count){throw 'LIFECYCLE_EXISTING_ROOT_REQUIRES_REVIEW'}
 }
 $p=[AuthWire.Staging.TreeLeaseV1]::new()
 try{
  $p.PinAncestors($Root);[AuthWire.Staging.TreeLeaseV1]::CreateNewDirectory($life);$p.PinAncestors($life)
  # A partial directory/header stays partial after a crash. Never reinitialize.
  Write-AuthWireStagingJournal (Join-Path $life 'baseline.json') ([pscustomobject]@{format='AuthWireWriteLifecycleRootV1';binding_scope=(Get-AuthWireJobScope $Binding);created_at=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds();legacy=$legacy})
 }finally{$p.Dispose()}
}
function Read-AuthWireLifecycleBaseline([string]$Root,[hashtable]$Binding,[Security.Cryptography.RSACng]$Key){
 $life=Get-AuthWireWriteLifecyclePath $Root $Binding;$p=[AuthWire.Staging.TreeLeaseV1]::new()
 try{
  $p.PinAncestors($Root);$p.PinAncestors($life);$file=Join-Path $life 'baseline.json';$p.PinFile($file);$v=Read-AuthWireStagingJournal $file
  Assert-AuthWireCandidateFields $v @('format','binding_scope','created_at','legacy')
  if($v.format -cne 'AuthWireWriteLifecycleRootV1' -or $v.binding_scope -cne (Get-AuthWireJobScope $Binding) -or -not (Test-AuthWireWriteInteger $v.created_at) -or $v.created_at -gt [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()){throw 'LIFECYCLE_BASELINE_REJECTED'}
  if($null -ne $v.legacy){
   Assert-AuthWireCandidateFields $v.legacy @('job_id','release_id','operation_id','gpo_id','body_sha256','ack_sha256')
   $actual=Read-AuthWireLifecycleLegacyStage $Root $Binding $Key
   if((Get-AuthWireWriteHash $actual) -cne (Get-AuthWireWriteHash $v.legacy)){throw 'LIFECYCLE_LEGACY_CHANGED'}
  }
  return $v
 }finally{$p.Dispose()}
}
function Assert-AuthWireLifecyclePollReplyAt($Value,[hashtable]$Binding,[string]$Release,[string]$Request,[long]$At){
 Assert-AuthWireCandidateFields $Value @('format','request_id','scope_sha256','job_id','operation','lease_id','intent_sha256','expires_at','target','write_authorized','can_apply_gpo')
 Assert-AuthWireStageStrings $Value @('request_id','scope_sha256','job_id','operation','lease_id','intent_sha256')
 if($Value.format -isnot [int] -or $Value.format -ne 1 -or $Value.request_id -cne $Request -or $Value.scope_sha256 -cne (Get-AuthWireJobScope $Binding) -or $Value.write_authorized -isnot [bool] -or $Value.write_authorized -or $Value.can_apply_gpo -isnot [bool] -or $Value.can_apply_gpo){throw 'LIFECYCLE_REPLY_REJECTED'}
 if($Value.job_id -ceq ''){
  if($Value.operation -cne '' -or $Value.lease_id -cne '' -or $Value.intent_sha256 -cne '' -or $null -ne $Value.target -or $Value.expires_at -isnot [int] -or $Value.expires_at -ne 0){throw 'LIFECYCLE_IDLE_REJECTED'}
 }else{Assert-AuthWireWriteOfferAt $Value $Binding $Release $Request $At}
}
function Get-AuthWireLifecycleSlots([string]$Life){
 $slots=@();$items=@(Get-ChildItem -LiteralPath $Life -Force)
 foreach($i in $items){
  if($i.Name -ceq 'baseline.json' -and -not $i.PSIsContainer){continue}
  if(-not $i.PSIsContainer -or $i.Name -cnotmatch '\A[0-9]{6}\z'){throw 'LIFECYCLE_UNKNOWN_HISTORY'}
  $slots+=,$i.Name
 }
 if($slots.Count -gt 64){throw 'LIFECYCLE_HISTORY_LIMIT'}
 [Array]::Sort($slots,[StringComparer]::Ordinal)
 for($i=0;$i -lt $slots.Count;$i++){if($slots[$i] -cne ($i+1).ToString('D6')){throw 'LIFECYCLE_HISTORY_GAP'}}
 return ,$slots
}
function Read-AuthWireLifecyclePoll([string]$Life,[string]$Slot,[hashtable]$Binding,[Security.Cryptography.RSACng]$Key){
 if($Slot -cnotmatch '\A[0-9]{6}\z'){throw 'LIFECYCLE_SLOT_REJECTED'}
 $dir=Join-Path $Life $Slot;$p=[AuthWire.Staging.TreeLeaseV1]::new()
 try{
  $p.PinAncestors($Life);$p.PinAncestors($dir)
  $allowed=@('poll-started.json','poll-proof.json','poll-sent.json','poll-response.json','dispatch-started.json','dispatch-failed.json','completion.json')
  foreach($i in Get-ChildItem -LiteralPath $dir -Force){if($i.PSIsContainer -or $i.Name -cnotin $allowed){throw 'LIFECYCLE_UNKNOWN_HISTORY'};$p.PinFile($i.FullName)}
  $file=Join-Path $dir 'poll-started.json'
  if(-not (Test-Path -LiteralPath $file)){return [pscustomobject]@{Slot=$Slot;Phase='partial_poll';Offer=$null;Started=$null;Response=$null}}
  $s=Read-AuthWireStagingJournal $file;Assert-AuthWireCandidateFields $s @('format','binding_scope','release_id','slot','started_at')
  Assert-AuthWireCandidateGuid $s.release_id
  if($s.format -cne 'AuthWireLifecyclePollStartedV1' -or $s.binding_scope -cne (Get-AuthWireJobScope $Binding) -or $s.slot -cne $Slot -or -not (Test-AuthWireWriteInteger $s.started_at) -or $s.started_at -gt [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()){throw 'LIFECYCLE_POLL_RECORD_REJECTED'}
  $file=Join-Path $dir 'poll-sent.json'
  if(-not (Test-Path -LiteralPath $file)){return [pscustomobject]@{Slot=$Slot;Phase='poll_not_sent';Offer=$null;Started=$s;Response=$null}}
  $sent=Read-AuthWireStagingJournal $file;Assert-AuthWireCandidateFields $sent @('format','request_id','proof_sha256','sent_at')
  if($sent.format -cne 'AuthWireLifecyclePollSentV1' -or -not (Test-AuthWireWriteInteger $sent.sent_at)){throw 'LIFECYCLE_POLL_RECORD_REJECTED'}
  $pr=Read-AuthWireStagingJournal (Join-Path $dir 'poll-proof.json');Assert-AuthWireCandidateFields $pr @('format','proof')
  if($pr.format -cne 'AuthWireLifecyclePollProofV1' -or $sent.proof_sha256 -cne (Get-AuthWireWriteHash $pr.proof)){throw 'LIFECYCLE_POLL_RECORD_REJECTED'}
  $request=Assert-AuthWireStoredWritePollAt $pr.proof $Binding $s.release_id $Key $s.started_at $sent.sent_at
  if($sent.request_id -cne $request){throw 'LIFECYCLE_POLL_RECORD_REJECTED'}
  $file=Join-Path $dir 'poll-response.json'
  if(-not (Test-Path -LiteralPath $file)){return [pscustomobject]@{Slot=$Slot;Phase='poll_outcome_unknown';Offer=$null;Started=$s;Response=$null}}
  $r=Read-AuthWireStagingJournal $file;Assert-AuthWireCandidateFields $r @('format','poll_sha256','received_at','reply')
  if($r.format -cne 'AuthWireLifecyclePollResponseV1' -or $r.poll_sha256 -cne (Get-AuthWireWriteHash $sent) -or -not (Test-AuthWireWriteInteger $r.received_at) -or $r.received_at -lt $sent.sent_at -or $r.received_at -gt $sent.sent_at+5 -or $r.received_at -gt [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()){throw 'LIFECYCLE_POLL_RECORD_REJECTED'}
  Assert-AuthWireLifecyclePollReplyAt $r.reply $Binding $s.release_id $request $r.received_at
  if($r.reply.job_id -ceq '' -and ((Test-Path -LiteralPath (Join-Path $dir 'dispatch-started.json')) -or (Test-Path -LiteralPath (Join-Path $dir 'dispatch-failed.json')))){throw 'LIFECYCLE_IDLE_REJECTED'}
  $failed=Join-Path $dir 'dispatch-failed.json'
  if(Test-Path -LiteralPath $failed){
   $f=Read-AuthWireStagingJournal $failed;Assert-AuthWireCandidateFields $f @('format','phase','reason','checked_at')
   if($f.format -cne 'AuthWireLifecycleDispatchFailedV1' -or $f.phase -isnot [string] -or $f.phase -cnotin @('offer','preflight','claim','consume','execute') -or $f.reason -cne 'OUTCOME_REQUIRES_REVIEW' -or -not (Test-AuthWireWriteInteger $f.checked_at) -or $f.checked_at -lt $r.received_at -or $f.checked_at -gt [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()){throw 'LIFECYCLE_DISPATCH_REJECTED'}
  }
  return [pscustomobject]@{Slot=$Slot;Phase='reply_saved';Offer=$r.reply;Started=$s;Response=$r}
 }finally{$p.Dispose()}
}
function New-AuthWireLifecyclePoll([string]$Life,[string]$Slot,[hashtable]$Binding,[string]$Release,[Security.Cryptography.RSACng]$Key,[string]$BaseUrl){
 Assert-AuthWireCandidateGuid $Release
 if($Slot -cnotmatch '\A[0-9]{6}\z' -or [int]$Slot -lt 1 -or [int]$Slot -gt 64){throw 'LIFECYCLE_SLOT_REJECTED'}
 $dir=Join-Path $Life $Slot;$p=[AuthWire.Staging.TreeLeaseV1]::new()
 try{
  $p.PinAncestors($Life);[AuthWire.Staging.TreeLeaseV1]::CreateNewDirectory($dir);$p.PinAncestors($dir)
  $started=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
  Write-AuthWireStagingJournal (Join-Path $dir 'poll-started.json') ([pscustomobject]@{format='AuthWireLifecyclePollStartedV1';binding_scope=(Get-AuthWireJobScope $Binding);release_id=$Release;slot=$Slot;started_at=$started})
  $proof=New-AuthWireStagingWriteProof $Binding $Key POLL @{capability='combined.filesystem.write.v1';release_id=$Release}
  Write-AuthWireStagingJournal (Join-Path $dir 'poll-proof.json') ([pscustomobject]@{format='AuthWireLifecyclePollProofV1';proof=$proof})
  # Validate the flushed representation, using the same strict object parser
  # as restart recovery; the signing helper returns an in-memory hashtable.
  $proof=(Read-AuthWireStagingJournal (Join-Path $dir 'poll-proof.json')).proof
  $sentAt=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds();$request=Assert-AuthWireStoredWritePollAt $proof $Binding $Release $Key $started $sentAt
  $sent=[pscustomobject]@{format='AuthWireLifecyclePollSentV1';request_id=$request;proof_sha256=(Get-AuthWireWriteHash $proof);sent_at=$sentAt}
  # Flush before HTTP. Missing response after a crash NEVER creates a new POLL.
  Write-AuthWireStagingJournal (Join-Path $dir 'poll-sent.json') $sent
  Initialize-AuthWireWriteTransportTypes
  $raw=[AuthWire.Connector.WriteTransportV1]::Post($BaseUrl,$Binding.appliance_fqdn,$Binding.appliance_tls_sha256,'/api/connector/v1/staging-write/poll',(ConvertTo-AuthWireWriteJson $proof))
  $received=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds();$offer=ConvertFrom-AuthWireCandidateJson ([Text.UTF8Encoding]::new($false,$true).GetBytes($raw))
  Assert-AuthWireLifecyclePollReplyAt $offer $Binding $Release $request $received
  if($received -lt $sentAt -or $received -gt $sentAt+5){throw 'LIFECYCLE_POLL_TIME_REJECTED'}
  Write-AuthWireStagingJournal (Join-Path $dir 'poll-response.json') ([pscustomobject]@{format='AuthWireLifecyclePollResponseV1';poll_sha256=(Get-AuthWireWriteHash $sent);received_at=$received;reply=$offer})
  return (Read-AuthWireLifecyclePoll $Life $Slot $Binding $Key)
 }finally{$p.Dispose()}
}

function Assert-AuthWireLifecycleRootEntries([string]$Root,$Baseline,[object[]]$States,[hashtable]$Binding,[Security.Cryptography.RSACng]$Key){
 $names=@{'write-lifecycle'='directory'};$jobs=@{};$engines=@{};$stageOps=@{};$rollbackEngines=@{}
 if($null -ne $Baseline.legacy){
  $l=$Baseline.legacy;$names['cycle-poll.json']='file';$names['cycle-offer.json']='file'
  $names[$l.job_id]='directory';$jobs[$l.job_id]=$true;$names[$l.operation_id]='directory';$engines[$l.operation_id]=$true;$names['gpo-'+$l.gpo_id+'.json']='file'
  $stageOps[$l.job_id]=$l.operation_id
 }
 foreach($s in $States){
  if($null -eq $s.Offer -or $s.Offer.job_id -ceq ''){continue}
  $o=$s.Offer;$names[$o.job_id]='directory';$jobs[$o.job_id]=$true;$names['gpo-'+$o.target.scope_target.gpo_id+'.json']='file'
  if($o.operation -ceq 'combined.filesystem.rollback.v1'){
   $names['rollback-stage-'+$o.target.stage_receipt.stage_job_id+'.json']='file'
   if(-not $stageOps.ContainsKey($o.target.stage_receipt.stage_job_id)){throw 'LIFECYCLE_UNREFERENCED_STAGE_ORIGIN'}
   $rollbackEngines[$stageOps[$o.target.stage_receipt.stage_job_id]]=$true
  }
  elseif(Test-Path -LiteralPath (Join-Path (Join-Path $Root $o.job_id) 'filesystem-intent.json')){
   $a=Read-AuthWireAuthorizedStageIntentEvidence $Root $o.job_id $Binding $s.Started.release_id $Key
   $op=$a.Intent.filesystem_operation_id;$names[$op]='directory';$engines[$op]=$true
   $stageOps[$o.job_id]=$op
  }
 }
 $p=[AuthWire.Staging.TreeLeaseV1]::new()
 try{
  $p.PinAncestors($Root)
  foreach($i in Get-ChildItem -LiteralPath $Root -Force){
   if(-not $names.ContainsKey($i.Name) -or ($i.PSIsContainer -and $names[$i.Name] -cne 'directory') -or (-not $i.PSIsContainer -and $names[$i.Name] -cne 'file')){throw 'LIFECYCLE_UNREFERENCED_ROOT_HISTORY'}
   if($i.PSIsContainer){$p.PinAncestors($i.FullName)}else{$p.PinFile($i.FullName)}
  }
  $jobNames=@('offer.json','preflight.json','claim-started.json','claim-proof.json','claim-sent.json','authorization.json','grant-consumed.json','filesystem-intent.json','stage-launch.json','stage-child.json','stage-entered.json','stage-preflight.json','execution-complete.json','execution-observed.json','execution-requires-review.json','cycle-review.json','result-outbox.json','result-accepted.json',
   'rollback-offer.json','rollback-preflight.json','rollback-claim-started.json','rollback-claim-proof.json','rollback-claim-sent.json','rollback-authorization.json','rollback-grant-consumed.json','rollback-filesystem-intent.json','rollback-consumption-preflight.json','rollback-launch.json','rollback-child.json','rollback-entered.json','rollback-execution-preflight.json','rollback-execution-complete.json','rollback-execution-observed.json','rollback-execution-requires-review.json','rollback-result-outbox.json','rollback-result-accepted.json')
  foreach($n in 1..3){foreach($prefix in @('','rollback-')){foreach($kind in @('attempt','proof')){$jobNames+=,($prefix+'result-'+$kind+'-'+$n+'.json')}}}
  foreach($id in $jobs.Keys){$dir=Join-Path $Root $id;if(-not (Test-Path -LiteralPath $dir)){continue};foreach($i in Get-ChildItem -LiteralPath $dir -Force){if($i.PSIsContainer -or $i.Name -cnotin $jobNames){throw 'LIFECYCLE_UNKNOWN_JOB_RECORD'};$p.PinFile($i.FullName)}}
  foreach($id in $engines.Keys){$dir=Join-Path $Root $id;if(-not (Test-Path -LiteralPath $dir)){continue};foreach($i in Get-ChildItem -LiteralPath $dir -Force){if($i.PSIsContainer -or $i.Name -cnotin @('intent.json','complete.json','rollback-started.json','rolled-back.json') -or ($i.Name -cin @('rollback-started.json','rolled-back.json') -and -not $rollbackEngines.ContainsKey($id))){throw 'LIFECYCLE_UNKNOWN_ENGINE_RECORD'};$p.PinFile($i.FullName)}}
 }finally{$p.Dispose()}
}
function Get-AuthWireLifecycleOutcomeEvidence([string]$Root,$State,[hashtable]$Binding,[Security.Cryptography.RSACng]$Key){
 $o=$State.Offer;$release=$State.Started.release_id;$rollback=$o.operation -ceq 'combined.filesystem.rollback.v1'
 if($rollback){$box=Read-AuthWireRollbackResultOutbox $Root $o.job_id $Binding $release $Key;$prefix='rollback-';$format='AuthWireRollbackResultAcceptedV1'}
 else{
  $box=Read-AuthWireWriteResultOutbox $Root $o.job_id $Binding $release $Key;$prefix='';$format='AuthWireWriteResultAcceptedV1'
  if($box.body.outcome -ceq 'staged'){$observed=Read-AuthWireObservedStageBody $Root $o.job_id $Binding $release $Key;if((Get-AuthWireWriteHash $observed) -cne $box.body_sha256){throw 'LIFECYCLE_OUTCOME_REJECTED'}}
 }
 $file=Join-Path (Join-Path $Root $o.job_id) ($prefix+'result-accepted.json');$p=[AuthWire.Staging.TreeLeaseV1]::new()
 try{
  $p.PinFile($file);$v=Read-AuthWireStagingJournal $file;Assert-AuthWireCandidateFields $v @('format','job_id','body_sha256','request_id','ack');Assert-AuthWireStageStrings $v @('format','job_id','body_sha256','request_id')
  if($v.format -cne $format -or $v.job_id -cne $o.job_id -or $v.body_sha256 -cne $box.body_sha256 -or -not (Test-AuthWireWriteHash $v.request_id)){throw 'LIFECYCLE_OUTCOME_REJECTED'}
  Assert-AuthWireWriteResultAck $v.ack $v.request_id $o.job_id
  return [pscustomobject]@{Outcome=$box.body.outcome;BodySha256=$box.body_sha256;AckSha256=(Get-AuthWireWriteHash $v)}
 }finally{$p.Dispose()}
}
function Complete-AuthWireLifecycleCycle([string]$Root,[string]$Life,$State,[hashtable]$Binding,[Security.Cryptography.RSACng]$Key){
 $o=$State.Offer;$body='';$ack='';$outcome='no_job'
 if($o.job_id -cne ''){$e=Get-AuthWireLifecycleOutcomeEvidence $Root $State $Binding $Key;$outcome=$e.Outcome;$body=$e.BodySha256;$ack=$e.AckSha256}
 $v=[pscustomobject]@{format='AuthWireLifecycleCompletionV1';slot=$State.Slot;operation=$o.operation;job_id=$o.job_id;offer_sha256=(Get-AuthWireWriteHash $o);response_sha256=(Get-AuthWireWriteHash $State.Response);outcome=$outcome;result_body_sha256=$body;ack_sha256=$ack;completed_at=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()}
 Write-AuthWireStagingJournal (Join-Path (Join-Path $Life $State.Slot) 'completion.json') $v
 return $v
}
function Read-AuthWireLifecycleCompletion([string]$Root,[string]$Life,$State,[hashtable]$Binding,[Security.Cryptography.RSACng]$Key){
 $p=[AuthWire.Staging.TreeLeaseV1]::new()
 try{
  $file=Join-Path (Join-Path $Life $State.Slot) 'completion.json';$p.PinFile($file);$v=Read-AuthWireStagingJournal $file
  Assert-AuthWireCandidateFields $v @('format','slot','operation','job_id','offer_sha256','response_sha256','outcome','result_body_sha256','ack_sha256','completed_at')
  Assert-AuthWireStageStrings $v @('format','slot','operation','job_id','offer_sha256','response_sha256','outcome','result_body_sha256','ack_sha256')
  $o=$State.Offer
  if($v.format -cne 'AuthWireLifecycleCompletionV1' -or $v.slot -cne $State.Slot -or $v.operation -cne $o.operation -or $v.job_id -cne $o.job_id -or $v.offer_sha256 -cne (Get-AuthWireWriteHash $o) -or $v.response_sha256 -cne (Get-AuthWireWriteHash $State.Response) -or
     -not (Test-AuthWireWriteInteger $v.completed_at) -or $v.completed_at -lt $State.Response.received_at -or $v.completed_at -gt [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()){throw 'LIFECYCLE_COMPLETION_REJECTED'}
  if($o.job_id -ceq ''){if($v.outcome -cne 'no_job' -or $v.result_body_sha256 -cne '' -or $v.ack_sha256 -cne ''){throw 'LIFECYCLE_COMPLETION_REJECTED'}}
  else{$e=Get-AuthWireLifecycleOutcomeEvidence $Root $State $Binding $Key;if($v.outcome -cne $e.Outcome -or $v.result_body_sha256 -cne $e.BodySha256 -or $v.ack_sha256 -cne $e.AckSha256){throw 'LIFECYCLE_COMPLETION_REJECTED'}}
  if($o.job_id -cne ''){Assert-AuthWireLifecycleDispatch $Life $State}
  return $v
 }finally{$p.Dispose()}
}
function New-AuthWireLifecycleDispatch([string]$Life,$State){
 if($State.Offer.job_id -ceq ''){throw 'LIFECYCLE_JOB_REQUIRED'}
 Write-AuthWireStagingJournal (Join-Path (Join-Path $Life $State.Slot) 'dispatch-started.json') ([pscustomobject]@{format='AuthWireLifecycleDispatchV1';job_id=$State.Offer.job_id;operation=$State.Offer.operation;response_sha256=(Get-AuthWireWriteHash $State.Response);started_at=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()})
}
function Assert-AuthWireLifecycleDispatch([string]$Life,$State){
 $file=Join-Path (Join-Path $Life $State.Slot) 'dispatch-started.json';$p=[AuthWire.Staging.TreeLeaseV1]::new()
 try{
  $p.PinFile($file);$v=Read-AuthWireStagingJournal $file;Assert-AuthWireCandidateFields $v @('format','job_id','operation','response_sha256','started_at')
  if($v.format -cne 'AuthWireLifecycleDispatchV1' -or $v.job_id -cne $State.Offer.job_id -or $v.operation -cne $State.Offer.operation -or $v.response_sha256 -cne (Get-AuthWireWriteHash $State.Response) -or -not (Test-AuthWireWriteInteger $v.started_at) -or $v.started_at -lt $State.Response.received_at -or $v.started_at -ge $State.Offer.expires_at -or $v.started_at -gt [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()){throw 'LIFECYCLE_DISPATCH_REJECTED'}
 }finally{$p.Dispose()}
}
function Get-AuthWireLifecycleResult([string]$Phase,[string]$JobId='', [string]$Outcome='', [bool]$Recorded=$false,[string]$Reason=''){
 return [pscustomobject]@{Phase=$Phase;JobId=$JobId;Outcome=$Outcome;ResultRecorded=$Recorded;CanApplyGpo=$false;ArtifactExecuted=$false;Reason=$Reason}
}
function Resume-AuthWireLifecycleResult([string]$Root,[string]$Life,$State,[hashtable]$Binding,[Security.Cryptography.RSACng]$Key,[string]$BaseUrl){
 # No POLL, CLAIM, consumption, context reader or executor in this function.
 Assert-AuthWireLifecycleDispatch $Life $State
 $o=$State.Offer;$job=Join-Path $Root $o.job_id;$release=$State.Started.release_id;$rollback=$o.operation -ceq 'combined.filesystem.rollback.v1';$prefix=if($rollback){'rollback-'}else{''}
 if(-not (Test-Path -LiteralPath (Join-Path $job ($prefix+'authorization.json')))){return (Get-AuthWireLifecycleResult 'local_reconciliation_required' $o.job_id)}
 if((Test-Path -LiteralPath (Join-Path $job ($prefix+'result-attempt-3.json'))) -and -not (Test-Path -LiteralPath (Join-Path $job ($prefix+'result-accepted.json')))){return (Get-AuthWireLifecycleResult 'result_attempt_limit_requires_review' $o.job_id)}
 try{
  if($rollback){$sent=Send-AuthWireRollbackResult $Root $o.job_id $Binding $release $Key $BaseUrl}
  else{$sent=Send-AuthWireWriteResult $Root $o.job_id $Binding $release $Key $BaseUrl}
  if(-not $sent.ResultRecorded){return (Get-AuthWireLifecycleResult 'result_pending' $o.job_id)}
  $c=Complete-AuthWireLifecycleCycle $Root $Life $State $Binding $Key
  return (Get-AuthWireLifecycleResult $(if($c.outcome -ceq 'requires_review'){'requires_review'}else{'result_recorded'}) $o.job_id $c.outcome $true)
 }catch{
  return (Get-AuthWireLifecycleResult $(if(Test-Path -LiteralPath (Join-Path $job ($prefix+'result-outbox.json'))){'result_pending'}else{'local_reconciliation_required'}) $o.job_id)
 }
}
function Invoke-AuthWireStagingWriteLifecycleStep([string]$Root,[hashtable]$Binding,[string]$Release,[Security.Cryptography.RSACng]$Key,[string]$BaseUrl){
 Assert-AuthWireStagingWriteJournalLocation $Root $Binding;Assert-AuthWireCandidateGuid $Release;Initialize-AuthWireStagingFilesystemTypes
 $lock=Enter-AuthWireWriteCycleLock $Binding;$p=[AuthWire.Staging.TreeLeaseV1]::new()
 try{
  $p.PinAncestors($Root);Initialize-AuthWireWriteLifecycle $Root $Binding $Key
  $life=Get-AuthWireWriteLifecyclePath $Root $Binding;$baseline=Read-AuthWireLifecycleBaseline $Root $Binding $Key;$slots=Get-AuthWireLifecycleSlots $life;$states=@()
  foreach($slot in $slots){$states+=,(Read-AuthWireLifecyclePoll $life $slot $Binding $Key)}
  $requests=@{};$jobs=@{}
  foreach($s in $states){if($null -ne $s.Offer){
   if($requests.ContainsKey($s.Offer.request_id)){throw 'LIFECYCLE_DUPLICATE_POLL_HISTORY'};$requests[$s.Offer.request_id]=$true
   if($s.Offer.job_id -cne ''){if($jobs.ContainsKey($s.Offer.job_id)){throw 'LIFECYCLE_DUPLICATE_JOB_HISTORY'};$jobs[$s.Offer.job_id]=$true}
  }}
  Assert-AuthWireLifecycleRootEntries $Root $baseline $states $Binding $Key
  for($i=0;$i -lt $states.Count;$i++){
   $s=$states[$i];$dir=Join-Path $life $s.Slot
   if($s.Phase -cne 'reply_saved'){
    if($i -ne $states.Count-1){throw 'LIFECYCLE_PENDING_HISTORY_GAP'}
    return (Get-AuthWireLifecycleResult 'local_reconciliation_required')
   }
   if(Test-Path -LiteralPath (Join-Path $dir 'completion.json')){
    $done=Read-AuthWireLifecycleCompletion $Root $life $s $Binding $Key
    if($done.outcome -ceq 'requires_review'){if($i -ne $states.Count-1){throw 'LIFECYCLE_PENDING_HISTORY_GAP'};return (Get-AuthWireLifecycleResult 'requires_review' $s.Offer.job_id $done.outcome $true)}
    continue
   }
   if($i -ne $states.Count-1){throw 'LIFECYCLE_PENDING_HISTORY_GAP'}
   if($s.Offer.job_id -ceq ''){$null=Complete-AuthWireLifecycleCycle $Root $life $s $Binding $Key;return (Get-AuthWireLifecycleResult 'no_job')}
   if(-not (Test-Path -LiteralPath (Join-Path $dir 'dispatch-started.json'))){return (Get-AuthWireLifecycleResult 'local_reconciliation_required' $s.Offer.job_id)}
   return (Resume-AuthWireLifecycleResult $Root $life $s $Binding $Key $BaseUrl)
  }
  # Bounded immutable history. Maintenance is explicit, never automatic deletion
  # of poll/job/origin/GPO-lock records. Active worker delivery still gated on it.
  if($slots.Count -ge 64){return (Get-AuthWireLifecycleResult 'history_limit_requires_maintenance')}
  $next=($slots.Count+1).ToString('D6')
  try{$s=New-AuthWireLifecyclePoll $life $next $Binding $Release $Key $BaseUrl}catch{
   $reason=if($_.Exception.Message -cmatch '\ALIFECYCLE_[A-Z_]{1,64}\z'){$_.Exception.Message}else{'POLL_OR_RECORD_ERROR'}
   return (Get-AuthWireLifecycleResult 'local_reconciliation_required' '' '' $false $reason)
  }
  if($s.Offer.job_id -ceq ''){$null=Complete-AuthWireLifecycleCycle $Root $life $s $Binding $Key;return (Get-AuthWireLifecycleResult 'no_job')}
  $o=$s.Offer;Assert-AuthWireWriteOffer $o $Binding $Release $o.request_id
  New-AuthWireLifecycleDispatch $life $s
  $phase='offer'
  try{
   if($o.operation -ceq 'combined.filesystem.stage.v1'){
    $null=Save-AuthWireStagingWriteOffer $o $Binding $Release $o.request_id $Root
    $phase='preflight';$null=Invoke-AuthWireStagingWritePreflight $Root $o.job_id $Binding $Release
    $phase='claim';$null=New-AuthWireStagingWriteClaim $Root $o.job_id $Binding $Release $Key;$null=Invoke-AuthWireStagingWriteClaimTransport $Root $o.job_id $Binding $Release $Key $BaseUrl
    $phase='consume';$null=New-AuthWireAuthorizedFilesystemIntent $Root $o.job_id $Binding $Release $Key
    $phase='execute';$null=Invoke-AuthWireAuthorizedFilesystemStage $Root $o.job_id $Binding $Release $Key
   }else{
    $null=Save-AuthWireRollbackOffer $o $Binding $Release $Key $o.request_id
    $phase='preflight';$null=Invoke-AuthWireRollbackPreflight $Root $o.job_id $Binding $Release
    $phase='claim';$null=New-AuthWireRollbackClaim $Root $o.job_id $Binding $Release $Key;$null=Invoke-AuthWireRollbackClaimTransport $Root $o.job_id $Binding $Release $Key $BaseUrl
    $phase='consume';$null=New-AuthWireRollbackFilesystemIntent $Root $o.job_id $Binding $Release $Key
    $phase='execute';$null=Invoke-AuthWireAuthorizedFilesystemRollback $Root $o.job_id $Binding $Release $Key
   }
  }catch [Management.Automation.PipelineStoppedException]{throw}catch{
   try{Write-AuthWireStagingJournal (Join-Path (Join-Path $life $next) 'dispatch-failed.json') ([pscustomobject]@{format='AuthWireLifecycleDispatchFailedV1';phase=$phase;reason='OUTCOME_REQUIRES_REVIEW';checked_at=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()})}catch{}
  }
  return (Resume-AuthWireLifecycleResult $Root $life $s $Binding $Key $BaseUrl)
 }finally{$p.Dispose();$lock.ReleaseMutex();$lock.Dispose()}
}
