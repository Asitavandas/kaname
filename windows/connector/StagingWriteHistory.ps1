# Source-only governed local history archiving. No peer, scheduler or service API.
# Completed cycles are copied, verified and sealed before local originals retire.
# Partial maintenance is a durable stop; this module never repairs or unlocks it.
Set-StrictMode -Version 2

function Get-AuthWireHistoryCycleRows($Lease){
 $rows=@()
 foreach($r in $Lease.Rows){
  if($r.Kind -ceq 'directory' -and $r.Path -ceq ''){continue}
  if($r.Kind -cne 'file' -or $r.Path -cmatch '[/\\:]' -or $r.Size -lt 1 -or $r.Size -gt 65536){throw 'HISTORY_CYCLE_RECORD_REJECTED'}
  $rows+=,[pscustomobject]@{path=$r.Path;size=[long]$r.Size;sha256=$r.Sha256}
 }
 if($rows.Count -lt 1 -or $rows.Count -gt 7){throw 'HISTORY_CYCLE_RECORD_REJECTED'}
 return ,$rows
}
function Get-AuthWireHistoryArchiveFrame($Body){
 return [Text.Encoding]::ASCII.GetBytes(("AUTHWIRE-WRITE-HISTORY-ARCHIVE-V1`n"+(ConvertTo-AuthWireWriteJson $Body)+"`n"))
}
function Read-AuthWireHistoryArchives([string]$Root,[string]$Life,$Baseline,[hashtable]$Binding,[Security.Cryptography.RSACng]$Key){
 $area=Join-Path $Life 'history-archives';$states=@();$through=0;$head='';$count=0
 if(-not (Test-Path -LiteralPath $area)){return [pscustomobject]@{States=$states;Through=$through;Head=$head;Count=$count}}
 $p=[AuthWire.Staging.TreeLeaseV1]::new();$leases=[Collections.Generic.List[IDisposable]]::new()
 try{
  $p.PinAncestors($area);$p.PinDirectory($area);Assert-AuthWireStagingJournalRoot $area
  $items=@(Get-ChildItem -LiteralPath $area -Force|Sort-Object Name)
  if($items.Count -lt 1 -or $items.Count -gt 8){throw 'HISTORY_ARCHIVE_QUOTA_REQUIRES_MAINTENANCE'}
  foreach($item in $items){
   $count++;$index=$count.ToString('D6')
   if(-not $item.PSIsContainer -or $item.Name -cne $index){throw 'HISTORY_ARCHIVE_SEQUENCE_REJECTED'}
   $dir=$item.FullName;$p.PinAncestors($dir);$p.PinDirectory($dir)
   $entries=@(Get-ChildItem -LiteralPath $dir -Force)
   if($entries.Count -ne 4){throw 'HISTORY_RETENTION_RECONCILIATION_REQUIRED'}
   foreach($i in $entries){
    if($i.Name -ceq 'cycles' -and $i.PSIsContainer){$p.PinAncestors($i.FullName);$p.PinDirectory($i.FullName);continue}
    if($i.PSIsContainer -or $i.Name -cnotin @('intent.json','archive.json','committed.json')){throw 'HISTORY_UNKNOWN_ARCHIVE_RECORD'}
    $p.PinFile($i.FullName)
   }
   foreach($n in @('intent.json','archive.json','committed.json','cycles')){if(-not (Test-Path -LiteralPath (Join-Path $dir $n))){throw 'HISTORY_RETENTION_RECONCILIATION_REQUIRED'}}
   $intent=Read-AuthWireStagingJournal (Join-Path $dir 'intent.json')
   Assert-AuthWireCandidateFields $intent @('format','binding_scope','archive_index','baseline_sha256','previous_archive_sha256','review_sha256','first_slot','last_slot','started_at')
   $v=Read-AuthWireStagingJournal (Join-Path $dir 'archive.json');Assert-AuthWireCandidateFields $v @('body','signature')
   $a=$v.body
   Assert-AuthWireCandidateFields $a @('format','policy','binding_scope','baseline_sha256','previous_archive_sha256','archive_index','first_slot','last_slot','cycle_count','record_count','total_bytes','cycle_manifest_sha256','protected_manifest_sha256','review_sha256','review_checked_at','review_expires_at','intent_sha256','created_at','cycles')
   Assert-AuthWireStageStrings $a @('format','policy','binding_scope','baseline_sha256','previous_archive_sha256','first_slot','last_slot','cycle_manifest_sha256','protected_manifest_sha256','review_sha256','intent_sha256')
   $scope=Get-AuthWireJobScope $Binding;$baselineHash=Get-AuthWireWriteHash $Baseline
   if($a.format -cne 'AuthWireWriteHistoryArchiveV1' -or $a.policy -cne 'retain_observed_cycles_v1' -or $a.binding_scope -cne $scope -or $a.baseline_sha256 -cne $baselineHash -or $a.previous_archive_sha256 -cne $head -or
      $a.archive_index -isnot [int] -or $a.archive_index -ne $count -or $a.first_slot -cne ($through+1).ToString('D6') -or $a.last_slot -cne ($through+64).ToString('D6') -or
      $a.cycle_count -isnot [int] -or $a.cycle_count -ne 64 -or $a.cycles -isnot [array] -or $a.cycles.Count -ne 64 -or
      -not (Test-AuthWireWriteInteger $a.record_count) -or $a.record_count -gt 448 -or -not (Test-AuthWireWriteInteger $a.total_bytes) -or $a.total_bytes -gt 16777216 -or
      -not (Test-AuthWireWriteInteger $a.created_at) -or $a.created_at -gt [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() -or
      -not (Test-AuthWireWriteInteger $a.review_checked_at) -or -not (Test-AuthWireWriteInteger $a.review_expires_at) -or $a.review_expires_at-$a.review_checked_at -ne 60 -or $a.created_at -lt $a.review_checked_at -or $a.created_at -ge $a.review_expires_at){throw 'HISTORY_ARCHIVE_REJECTED'}
   foreach($n in @('cycle_manifest_sha256','protected_manifest_sha256','review_sha256','intent_sha256')){if(-not (Test-AuthWireWriteHash $a.$n)){throw 'HISTORY_ARCHIVE_REJECTED'}}
   if($a.cycle_manifest_sha256 -cne (Get-AuthWireWriteHash @($a.cycles))){throw 'HISTORY_ARCHIVE_REJECTED'}
   $sig=ConvertFrom-AuthWireWriteBase64 $v.signature 512
   if($sig.Length -ne $Key.KeySize/8 -or -not $Key.VerifyData((Get-AuthWireHistoryArchiveFrame $a),$sig,[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1)){throw 'HISTORY_ARCHIVE_SIGNATURE_REJECTED'}
   if($intent.format -cne 'AuthWireWriteHistoryIntentV1' -or $intent.binding_scope -cne $scope -or $intent.archive_index -isnot [int] -or $intent.archive_index -ne $count -or
      $intent.baseline_sha256 -cne $baselineHash -or $intent.previous_archive_sha256 -cne $head -or $intent.review_sha256 -cne $a.review_sha256 -or $intent.first_slot -cne $a.first_slot -or $intent.last_slot -cne $a.last_slot -or
      $intent.started_at -ne $a.created_at -or $a.intent_sha256 -cne (Get-AuthWireWriteHash $intent)){throw 'HISTORY_ARCHIVE_INTENT_REJECTED'}
   $committed=Read-AuthWireStagingJournal (Join-Path $dir 'committed.json')
   Assert-AuthWireCandidateFields $committed @('format','binding_scope','archive_index','archive_sha256','completed_at')
   $archiveHash=Get-AuthWireWriteHash $v
   if($committed.format -cne 'AuthWireWriteHistoryCommittedV1' -or $committed.binding_scope -cne $scope -or $committed.archive_index -isnot [int] -or $committed.archive_index -ne $count -or $committed.archive_sha256 -cne $archiveHash -or
      -not (Test-AuthWireWriteInteger $committed.completed_at) -or $committed.completed_at -lt $a.created_at -or $committed.completed_at -ge $a.review_expires_at -or $committed.completed_at -gt [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()){throw 'HISTORY_ARCHIVE_COMMIT_REJECTED'}
   $cycles=Join-Path $dir 'cycles';$dirs=@(Get-ChildItem -LiteralPath $cycles -Force|Sort-Object Name)
   if($dirs.Count -ne 64){throw 'HISTORY_ARCHIVE_CYCLES_REJECTED'}
   $bytes=[long]0;$records=0
   for($j=0;$j -lt 64;$j++){
    $slot=($through+$j+1).ToString('D6');$row=$a.cycles[$j];Assert-AuthWireCandidateFields $row @('slot','records_sha256')
    if(-not $dirs[$j].PSIsContainer -or $dirs[$j].Name -cne $slot -or $row.slot -cne $slot -or -not (Test-AuthWireWriteHash $row.records_sha256)){throw 'HISTORY_ARCHIVE_CYCLES_REJECTED'}
    $lease=[AuthWire.Staging.TreeLeaseV1]::Tree($dirs[$j].FullName,$false);$leases.Add($lease)
    $rows=Get-AuthWireHistoryCycleRows $lease
    if((Get-AuthWireWriteHash $rows) -cne $row.records_sha256){throw 'HISTORY_ARCHIVE_BYTES_CHANGED'}
    foreach($r in $rows){$bytes+=$r.size;$records++}
    $s=Read-AuthWireLifecyclePoll $cycles $slot $Binding $Key
    if($s.Phase -cne 'reply_saved'){throw 'HISTORY_ARCHIVE_INCOMPLETE_CYCLE'}
    $done=Read-AuthWireLifecycleCompletion $Root $cycles $s $Binding $Key
    if($done.outcome -cnotin @('no_job','staged','rolled_back') -or $done.completed_at -gt $a.created_at){throw 'HISTORY_ARCHIVE_INCOMPLETE_CYCLE'}
    $states+=,$s
   }
   if($bytes -ne $a.total_bytes -or $records -ne $a.record_count){throw 'HISTORY_ARCHIVE_TOTALS_REJECTED'}
   $through+=64;$head=$archiveHash
  }
  return [pscustomobject]@{States=$states;Through=$through;Head=$head;Count=$count}
 }finally{foreach($lease in $leases){$lease.Dispose()};$p.Dispose()}
}

function Read-AuthWireLifecycleHistory([string]$Root,[hashtable]$Binding,[Security.Cryptography.RSACng]$Key){
 $life=Get-AuthWireWriteLifecyclePath $Root $Binding;$baseline=Read-AuthWireLifecycleBaseline $Root $Binding $Key
 $archives=Read-AuthWireHistoryArchives $Root $life $baseline $Binding $Key
 $slots=Get-AuthWireLifecycleSlots $life $archives.Through;$active=@()
 foreach($slot in $slots){$active+=,(Read-AuthWireLifecyclePoll $life $slot $Binding $Key)}
 $all=@($archives.States)+@($active);$requests=@{};$jobs=@{}
 if($null -ne $baseline.legacy){$legacy=Read-AuthWireStagingJournal (Join-Path $Root 'cycle-poll.json');$requests[$legacy.request_id]=$true;$jobs[$baseline.legacy.job_id]=$true}
 foreach($s in $all){if($null -ne $s.Offer){
  if($requests.ContainsKey($s.Offer.request_id)){throw 'LIFECYCLE_DUPLICATE_POLL_HISTORY'};$requests[$s.Offer.request_id]=$true
  if($s.Offer.job_id -cne ''){if($jobs.ContainsKey($s.Offer.job_id)){throw 'LIFECYCLE_DUPLICATE_JOB_HISTORY'};$jobs[$s.Offer.job_id]=$true}
 }}
 Assert-AuthWireLifecycleRootEntries $Root $baseline $all $Binding $Key
 return [pscustomobject]@{Life=$life;Baseline=$baseline;Slots=$slots;States=$all;ActiveStates=$active;ArchivedThrough=$archives.Through;ArchiveHead=$archives.Head;ArchiveCount=$archives.Count}
}

function Get-AuthWireHistoryProtectedHash([string]$Root,$Pins){
 $hash=Get-AuthWireJobHash ([Text.Encoding]::ASCII.GetBytes("AUTHWIRE-WRITE-HISTORY-PROTECTED-V1`n"));$count=0;$bytes=[long]0
 $files=@(Get-ChildItem -LiteralPath $Root -Force|Where-Object {$_.Name -cne 'write-lifecycle'}|ForEach-Object {if($_.PSIsContainer){$Pins.PinAncestors($_.FullName);Get-ChildItem -LiteralPath $_.FullName -Force}else{$_}})
 foreach($file in @($files|Sort-Object FullName)){
  if($file.PSIsContainer){throw 'HISTORY_PROTECTED_TREE_REJECTED'}
  $Pins.PinFile($file.FullName);$raw=Read-AuthWireCandidateBytes $file.FullName 65536
  $count++;$bytes+=$raw.Length;if($count -gt 2048 -or $bytes -gt 33554432){throw 'HISTORY_PROTECTED_LIMIT'}
  $relative=$file.FullName.Substring($Root.Length+1).Replace('\','/')
  $row=[pscustomobject]@{path=$relative;size=$raw.Length;sha256=(Get-AuthWireJobHash $raw)}
  $hash=Get-AuthWireJobHash ([Text.Encoding]::ASCII.GetBytes(($hash+"`n"+(ConvertTo-AuthWireWriteJson $row)+"`n")))
 }
 return $hash
}
function New-AuthWireHistoryReviewState([string]$Root,[hashtable]$Binding,[Security.Cryptography.RSACng]$Key){
 Assert-AuthWireStagingWriteJournalLocation $Root $Binding;Initialize-AuthWireStagingFilesystemTypes
 $pins=[AuthWire.Staging.TreeLeaseV1]::new();$leases=[Collections.Generic.List[IDisposable]]::new()
 try{
  $pins.PinAncestors($Root);$h=Read-AuthWireLifecycleHistory $Root $Binding $Key
  $pins.PinAncestors($h.Life);$pins.PinFile((Join-Path $h.Life 'baseline.json'))
  $protected=Get-AuthWireHistoryProtectedHash $Root $pins
  $cycleRows=@();$details=@();$total=[long]0;$records=0
  foreach($slot in $h.Slots){
   $lease=[AuthWire.Staging.TreeLeaseV1]::Tree((Join-Path $h.Life $slot),$false);$leases.Add($lease)
   $rows=Get-AuthWireHistoryCycleRows $lease
   $cycleRows+=,[pscustomobject]@{slot=$slot;records_sha256=(Get-AuthWireWriteHash $rows)}
   $details+=,[pscustomobject]@{Slot=$slot;Rows=$rows}
   foreach($r in $rows){$total+=$r.size;$records++}
  }
  # Revalidate semantics while all active bytes and protected originals are held.
  $h=Read-AuthWireLifecycleHistory $Root $Binding $Key
  if((Get-AuthWireHistoryProtectedHash $Root $pins) -cne $protected){throw 'HISTORY_PROTECTED_CHANGED'}
  $reason='active_history_not_full';$eligible=$h.Slots.Count -eq 64
  for($j=0;$j -lt $h.ActiveStates.Count;$j++){
   $s=$h.ActiveStates[$j]
   if($s.Phase -cne 'reply_saved' -or -not (Test-Path -LiteralPath (Join-Path (Join-Path $h.Life $s.Slot) 'completion.json'))){$eligible=$false;$reason='pending_cycle';if($j -ne $h.ActiveStates.Count-1){throw 'LIFECYCLE_PENDING_HISTORY_GAP'};continue}
   $done=Read-AuthWireLifecycleCompletion $Root $h.Life $s $Binding $Key
   if($done.outcome -cnotin @('no_job','staged','rolled_back')){$eligible=$false;$reason='review_barrier';if($j -ne $h.ActiveStates.Count-1){throw 'LIFECYCLE_PENDING_HISTORY_GAP'}}
  }
  if($h.ArchiveCount -ge 8){$eligible=$false;$reason='archive_quota'}
  if($total -gt 16777216){$eligible=$false;$reason='archive_byte_limit'}
  if($eligible){$reason='observed_complete_history'}
  $now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds();$first=($h.ArchivedThrough+1).ToString('D6');$last=($h.ArchivedThrough+$h.Slots.Count).ToString('D6')
  $body=[pscustomobject]@{format='AuthWireWriteHistoryReviewV1';policy='retain_observed_cycles_v1';binding_scope=(Get-AuthWireJobScope $Binding);baseline_sha256=(Get-AuthWireWriteHash $h.Baseline);previous_archive_sha256=$h.ArchiveHead;archive_index=($h.ArchiveCount+1);archived_through=$h.ArchivedThrough;first_slot=$first;last_slot=$last;cycle_count=$h.Slots.Count;record_count=$records;total_bytes=$total;cycle_manifest_sha256=(Get-AuthWireWriteHash $cycleRows);protected_manifest_sha256=$protected;checked_at=$now;expires_at=($now+60);can_archive=[bool]$eligible;reason=$reason}
  return [pscustomobject]@{Review=$body;ReviewSha256=(Get-AuthWireWriteHash $body);History=$h;Cycles=$cycleRows;Details=$details;Pins=$pins;Leases=$leases}
 }catch{foreach($lease in $leases){$lease.Dispose()};$pins.Dispose();throw}
}
function Get-AuthWireWriteHistoryReview([string]$Root,[hashtable]$Binding,[Security.Cryptography.RSACng]$Key){
 $lock=Enter-AuthWireWriteCycleLock $Binding;$state=$null
 try{
  $state=New-AuthWireHistoryReviewState $Root $Binding $Key
  return [pscustomobject]@{Review=$state.Review;ReviewSha256=$state.ReviewSha256}
 }finally{if($state){foreach($lease in $state.Leases){$lease.Dispose()};$state.Pins.Dispose()};$lock.ReleaseMutex();$lock.Dispose()}
}

function Get-AuthWireWriteReconciliationReview([string]$Root,[hashtable]$Binding,[Security.Cryptography.RSACng]$Key){
 # This is a local evidence read. Even a valid ACK is not fresh approval.
 Assert-AuthWireStagingWriteJournalLocation $Root $Binding
 Initialize-AuthWireStagingFilesystemTypes
 $lock=Enter-AuthWireWriteCycleLock $Binding;$pins=[AuthWire.Staging.TreeLeaseV1]::new()
 $review=[pscustomobject]@{Phase='no_active_cycles';Slot='';JobId='';RecordedOutcome='';AcceptedAck=$false;Evidence=$null;StageLockReleaseEvidence=$null}
 try{
  $pins.PinAncestors($Root)
  if(-not (Get-ChildItem -LiteralPath $Root -Force -ErrorAction Stop|Select-Object -First 1)){return $review}
  $h=Read-AuthWireLifecycleHistory $Root $Binding $Key
  for($i=0;$i -lt $h.ActiveStates.Count;$i++){
   $state=$h.ActiveStates[$i];$dir=Join-Path $h.Life $state.Slot
   $pins.PinAncestors($dir)
   $review.Slot=$state.Slot;$review.JobId='';$review.RecordedOutcome='';$review.AcceptedAck=$false;$review.Evidence=$null
   if($state.Phase -cne 'reply_saved'){
    if($i -ne $h.ActiveStates.Count-1 -or (Test-Path -LiteralPath (Join-Path $dir 'completion.json'))){throw 'LIFECYCLE_PENDING_HISTORY_GAP'}
    $review.Phase=$state.Phase
    return $review
   }
   $review.JobId=$state.Offer.job_id
   if($review.JobId -cne ''){
    $review.Evidence=[pscustomobject]@{job_id=$review.JobId;scope_sha256=$state.Offer.scope_sha256;intent_sha256=$state.Offer.intent_sha256;result_body_sha256='';accepted_ack=$false}
   }
   if(Test-Path -LiteralPath (Join-Path $dir 'completion.json')){
    $completionPath=Join-Path $dir 'completion.json';$pins.PinFile($completionPath)
    $stageLock=$null
    if($state.Offer.operation -ceq 'combined.filesystem.stage.v1'){
     $stageLock=Join-Path $Root ('gpo-'+$state.Offer.target.scope_target.gpo_id+'.json')
     $pins.PinFile($stageLock)
    }
    $done=Read-AuthWireLifecycleCompletion $Root $h.Life $state $Binding $Key
    $review.Phase='completion_verified';$review.RecordedOutcome=$done.outcome;$review.AcceptedAck=$review.JobId -cne ''
    if($review.Evidence){$review.Evidence.result_body_sha256=$done.result_body_sha256;$review.Evidence.accepted_ack=$true}
    if($done.outcome -cin @('requires_review','refused_before_authorization') -and $i -ne $h.ActiveStates.Count-1){throw 'LIFECYCLE_PENDING_HISTORY_GAP'}
    if($stageLock -and $done.outcome -ceq 'refused_before_authorization'){
     $review.StageLockReleaseEvidence=[pscustomobject]@{
      format='AuthWireRefusedStageLockEvidenceV1';slot=$state.Slot;gpo_id=$state.Offer.target.scope_target.gpo_id
      job_id=$review.JobId;scope_sha256=$review.Evidence.scope_sha256;intent_sha256=$review.Evidence.intent_sha256
      result_body_sha256=$done.result_body_sha256;accepted_ack_sha256=$done.ack_sha256
      completion_sha256=(Get-AuthWireWriteHash $done);lock_sha256=(Get-AuthWireWriteHash (Read-AuthWireStagingJournal $stageLock))
     }
    }
    continue
   }
   if($i -ne $h.ActiveStates.Count-1){throw 'LIFECYCLE_PENDING_HISTORY_GAP'}
   if($review.JobId -ceq ''){$review.Phase='idle_completion_missing';return $review}
   if(-not (Test-Path -LiteralPath (Join-Path $dir 'dispatch-started.json'))){$review.Phase='dispatch_record_missing';return $review}
   Assert-AuthWireLifecycleDispatch $h.Life $state
   $job=Join-Path $Root $review.JobId;$release=$state.Started.release_id
   $rollback=$state.Offer.operation -ceq 'combined.filesystem.rollback.v1'
   $prefix=if($rollback){'rollback-'}else{''}
   $refusal=(Test-Path -LiteralPath (Join-Path $job 'refusal-outbox.json')) -or (Test-Path -LiteralPath (Join-Path $job 'refusal-accepted.json'))
   $resultPresent=(Test-Path -LiteralPath (Join-Path $job ($prefix+'result-outbox.json'))) -or (Test-Path -LiteralPath (Join-Path $job ($prefix+'result-accepted.json')))
   if($refusal -and $resultPresent){throw 'LIFECYCLE_OUTCOME_REJECTED'}
   $ackFile=if($refusal){'refusal-accepted.json'}else{$prefix+'result-accepted.json'}
   if(Test-Path -LiteralPath (Join-Path $job $ackFile)){
    $e=Get-AuthWireLifecycleOutcomeEvidence $Root $state $Binding $Key
    $review.Phase='accepted_ack_completion_missing';$review.RecordedOutcome=$e.Outcome;$review.AcceptedAck=$true
    $review.Evidence.result_body_sha256=$e.BodySha256;$review.Evidence.accepted_ack=$true
   }elseif($refusal -or $resultPresent){
    if($refusal){$box=Read-AuthWireWriteRefusalOutbox $Root $h.Life $state $Binding $Key}
    elseif($rollback){$box=Read-AuthWireRollbackResultOutbox $Root $review.JobId $Binding $release $Key}
    else{$box=Read-AuthWireWriteResultOutbox $Root $review.JobId $Binding $release $Key}
    $review.Evidence.result_body_sha256=$box.body_sha256
    $review.Phase='outbox_without_accepted_ack'
   }elseif(Test-Path -LiteralPath (Join-Path $job ($prefix+'authorization.json'))){
    if($rollback){$null=Read-AuthWireRollbackAuthorizationEvidence $Root $review.JobId $Binding $release $Key}
    else{$null=Read-AuthWireWriteAuthorizationEvidence $Root $review.JobId $Binding $release $Key}
    $review.Phase='authorization_without_frozen_outcome'
   }elseif(Test-Path -LiteralPath (Join-Path $job ($prefix+'claim-sent.json'))){
    $review.Phase='claim_outcome_unknown'
   }else{$review.Phase='authorization_evidence_missing'}
   return $review
  }
  return $review
 }catch{
  return [pscustomobject]@{Phase='evidence_invalid_or_unavailable';Slot='';JobId='';RecordedOutcome='';AcceptedAck=$false;Evidence=$null;StageLockReleaseEvidence=$null}
 }finally{$pins.Dispose();$lock.ReleaseMutex();$lock.Dispose()}
}

function Test-AuthWireStageLockApprovalEvidence {
 param([string]$Root,[hashtable]$Binding,[Security.Cryptography.RSACng]$Key,
       $VerificationResponse,[long]$ExpectedApprovalRevision)
 # Compare a response obtained by the operator over the authenticated API.
 # This local comparison is not an execution grant.
 $reply=$VerificationResponse
 $fields=@('job_id','gpo_id','decision','approval_revision','approval_verified',
  'stage_lock_evidence_sha256','review_only','approval_enabled','write_authorization_enabled',
  'execution_adapter_available','can_apply_gpo')
 Assert-AuthWireCandidateFields $reply $fields
 if(($reply.approval_revision -isnot [int] -and $reply.approval_revision -isnot [long]) -or
    $ExpectedApprovalRevision -lt 1 -or $ExpectedApprovalRevision -ge 9007199254740992L -or
    $reply.approval_revision -ne $ExpectedApprovalRevision -or
    $reply.decision -isnot [string] -or $reply.decision -cne 'approve_refused_stage_lock_release' -or
    -not (Test-AuthWireWriteHash $reply.stage_lock_evidence_sha256)){
  throw 'WRITE_LOCK_APPROVAL_RESPONSE_REJECTED'
 }
 foreach($name in @('approval_verified','review_only')){
  if($reply.$name -isnot [bool] -or -not $reply.$name){throw 'WRITE_LOCK_APPROVAL_RESPONSE_REJECTED'}
 }
 foreach($name in @('approval_enabled','write_authorization_enabled','execution_adapter_available','can_apply_gpo')){
  if($reply.$name -isnot [bool] -or $reply.$name){throw 'WRITE_LOCK_APPROVAL_RESPONSE_REJECTED'}
 }
 Assert-AuthWireCandidateGuid $reply.job_id
 Assert-AuthWireCandidateGuid $reply.gpo_id
 $review=Get-AuthWireWriteReconciliationReview $Root $Binding $Key
 $local=$review.StageLockReleaseEvidence
 if($null -eq $local -or $local.job_id -cne $reply.job_id -or $local.gpo_id -cne $reply.gpo_id -or
    (Get-AuthWireWriteHash $local) -cne $reply.stage_lock_evidence_sha256){throw 'WRITE_LOCK_APPROVAL_LOCAL_EVIDENCE_CHANGED'}
 return [pscustomobject]@{JobId=$local.job_id;GpoId=$local.gpo_id;ApprovalRevision=$ExpectedApprovalRevision;
  LocalEvidenceMatches=$true;CanApplyGpo=$false}
}

function Write-AuthWireHistoryBytes([string]$Path,[byte[]]$Bytes){
 $s=[IO.File]::Open($Path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
 try{$s.Write($Bytes,0,$Bytes.Length);$s.Flush($true)}finally{$s.Dispose()}
}
function Invoke-AuthWireWriteHistoryArchive([string]$Root,[hashtable]$Binding,[Security.Cryptography.RSACng]$Key,$Reviewed,[string]$Acknowledge){
 # Trusted local SDK only. Review hashes constrain consent; they are not a
 # network credential, a new write grant or an independent service identity.
 if($Acknowledge -cne 'archive_observed_history_preserve_all_evidence'){throw 'HISTORY_ARCHIVE_ACK_REQUIRED'}
 Assert-AuthWireCandidateFields $Reviewed @('Review','ReviewSha256')
 if(-not (Test-AuthWireWriteHash $Reviewed.ReviewSha256) -or (Get-AuthWireWriteHash $Reviewed.Review) -cne $Reviewed.ReviewSha256){throw 'HISTORY_REVIEW_CHANGED'}
 $approved=$Reviewed.Review
 if(-not (Test-AuthWireWriteInteger $approved.checked_at) -or -not (Test-AuthWireWriteInteger $approved.expires_at) -or $approved.expires_at-$approved.checked_at -ne 60 -or $approved.checked_at -gt [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() -or $approved.expires_at -le [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()){throw 'HISTORY_REVIEW_EXPIRED'}
 $lock=Enter-AuthWireWriteCycleLock $Binding;$state=$null;$owned=[Collections.Generic.List[IDisposable]]::new();$copies=[Collections.Generic.List[IDisposable]]::new()
 try{
  $state=New-AuthWireHistoryReviewState $Root $Binding $Key
  $fresh=$state.Review;$fresh.checked_at=$approved.checked_at;$fresh.expires_at=$approved.expires_at
  if((Get-AuthWireWriteHash $fresh) -cne $Reviewed.ReviewSha256){throw 'HISTORY_REVIEW_CHANGED'}
  if(-not $fresh.can_archive -or $fresh.cycle_count -ne 64 -or $fresh.archive_index -gt 8){throw 'HISTORY_ARCHIVE_NOT_ELIGIBLE'}
  foreach($lease in $state.Leases){$lease.Dispose()};$state.Leases.Clear()
  # Protected job/origin/lock records remain pinned. Bind delete-capable local
  # cycle leases to the exact reviewed bytes before publishing an intent.
  foreach($detail in $state.Details){
   $lease=[AuthWire.Staging.TreeLeaseV1]::Tree((Join-Path $state.History.Life $detail.Slot),$true);$owned.Add($lease)
   if((Get-AuthWireWriteHash (Get-AuthWireHistoryCycleRows $lease)) -cne (Get-AuthWireWriteHash $detail.Rows)){throw 'HISTORY_REVIEW_CHANGED'}
  }
  if((Get-AuthWireHistoryProtectedHash $Root $state.Pins) -cne $fresh.protected_manifest_sha256){throw 'HISTORY_PROTECTED_CHANGED'}
  if([DateTimeOffset]::UtcNow.ToUnixTimeSeconds() -ge $fresh.expires_at){throw 'HISTORY_REVIEW_EXPIRED'}
  $life=$state.History.Life;$area=Join-Path $life 'history-archives'
  if(-not (Test-Path -LiteralPath $area)){
   [AuthWire.Staging.TreeLeaseV1]::CreateNewDirectory($area)
   $identity=[Security.Principal.WindowsIdentity]::GetCurrent();try{$sid=$identity.User.Value}finally{$identity.Dispose()}
   $acl=Get-Acl -LiteralPath $area
   $acl.SetSecurityDescriptorSddlForm(('D:P(A;OICI;FA;;;'+ $sid +')(A;OICI;FA;;;SY)(A;OICI;FA;;;BA)'),[Security.AccessControl.AccessControlSections]::Access)
   Set-Acl -LiteralPath $area -AclObject $acl -ErrorAction Stop
  }
  $state.Pins.PinAncestors($area);$state.Pins.PinDirectory($area);Assert-AuthWireStagingJournalRoot $area
  $dir=Join-Path $area $fresh.archive_index.ToString('D6');[AuthWire.Staging.TreeLeaseV1]::CreateNewDirectory($dir);$state.Pins.PinAncestors($dir)
  $started=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
  $intent=[pscustomobject]@{format='AuthWireWriteHistoryIntentV1';binding_scope=$fresh.binding_scope;archive_index=$fresh.archive_index;baseline_sha256=$fresh.baseline_sha256;previous_archive_sha256=$fresh.previous_archive_sha256;review_sha256=$Reviewed.ReviewSha256;first_slot=$fresh.first_slot;last_slot=$fresh.last_slot;started_at=$started}
  Write-AuthWireStagingJournal (Join-Path $dir 'intent.json') $intent
  $target=Join-Path $dir 'cycles';[AuthWire.Staging.TreeLeaseV1]::CreateNewDirectory($target);$state.Pins.PinAncestors($target)
  for($j=0;$j -lt 64;$j++){
   $detail=$state.Details[$j];$destination=Join-Path $target $detail.Slot;[AuthWire.Staging.TreeLeaseV1]::CreateNewDirectory($destination)
   foreach($row in $detail.Rows){Write-AuthWireHistoryBytes (Join-Path $destination $row.path) ($owned[$j].ReadOwnedBytes($row.path))}
   $copy=[AuthWire.Staging.TreeLeaseV1]::Tree($destination,$false);$copies.Add($copy)
   if((Get-AuthWireWriteHash (Get-AuthWireHistoryCycleRows $copy)) -cne (Get-AuthWireWriteHash $detail.Rows)){throw 'HISTORY_ARCHIVE_BYTES_CHANGED'}
  }
  $body=[pscustomobject]@{format='AuthWireWriteHistoryArchiveV1';policy=$fresh.policy;binding_scope=$fresh.binding_scope;baseline_sha256=$fresh.baseline_sha256;previous_archive_sha256=$fresh.previous_archive_sha256;archive_index=$fresh.archive_index;first_slot=$fresh.first_slot;last_slot=$fresh.last_slot;cycle_count=64;record_count=$fresh.record_count;total_bytes=$fresh.total_bytes;cycle_manifest_sha256=$fresh.cycle_manifest_sha256;protected_manifest_sha256=$fresh.protected_manifest_sha256;review_sha256=$Reviewed.ReviewSha256;review_checked_at=$fresh.checked_at;review_expires_at=$fresh.expires_at;intent_sha256=(Get-AuthWireWriteHash $intent);created_at=$started;cycles=$state.Cycles}
  $signature=$Key.SignData((Get-AuthWireHistoryArchiveFrame $body),[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1)
  $archive=[pscustomobject]@{body=$body;signature=[Convert]::ToBase64String($signature)}
  Write-AuthWireStagingJournal (Join-Path $dir 'archive.json') $archive;$state.Pins.PinFile((Join-Path $dir 'archive.json'))
  if([DateTimeOffset]::UtcNow.ToUnixTimeSeconds() -ge $fresh.expires_at){throw 'HISTORY_REVIEW_EXPIRED'}
  # Local maintenance has its own <=30-second retirement budget inside the
  # original 60-second review. No server CLAIM/grant/deadline is generated.
  $at=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds();$deadline=[Math]::Min($at+30,[long]$fresh.expires_at);$ticks=[Diagnostics.Stopwatch]::GetTimestamp()
  foreach($lease in $owned){$lease.DeleteOwnedTreeBefore($deadline,$at,$ticks)}
  if((Get-AuthWireHistoryProtectedHash $Root $state.Pins) -cne $fresh.protected_manifest_sha256){throw 'HISTORY_PROTECTED_CHANGED'}
  [AuthWire.Staging.TreeLeaseV1]::AssertRollbackDeadline($deadline,$at,$ticks)
  Write-AuthWireStagingJournal (Join-Path $dir 'committed.json') ([pscustomobject]@{format='AuthWireWriteHistoryCommittedV1';binding_scope=$fresh.binding_scope;archive_index=$fresh.archive_index;archive_sha256=(Get-AuthWireWriteHash $archive);completed_at=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()})
  return [pscustomobject]@{Phase='history_archived';ArchivedThrough=[int]$fresh.last_slot;ArchivedCycles=64;ArchiveCount=$fresh.archive_index;ArchiveSha256=(Get-AuthWireWriteHash $archive);ProtectedRecordsPreserved=$true;CanApplyGpo=$false;NetworkSent=$false}
 }finally{foreach($lease in $copies){$lease.Dispose()};foreach($lease in $owned){$lease.Dispose()};if($state){foreach($lease in $state.Leases){$lease.Dispose()};$state.Pins.Dispose()};$lock.ReleaseMutex();$lock.Dispose()}
}
