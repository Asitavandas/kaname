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
    $safe=$done.outcome -cin @('no_job','staged','rolled_back')
    if(-not $safe -and $done.outcome -ceq 'requires_review'){$safe=Test-AuthWireConsumedStageClosed $Root $cycles $s $Binding $Key}
    if(-not $safe -or $done.completed_at -gt $a.created_at){throw 'HISTORY_ARCHIVE_INCOMPLETE_CYCLE'}
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
   $safe=$done.outcome -cin @('no_job','staged','rolled_back')
   if(-not $safe -and $done.outcome -ceq 'requires_review'){$safe=Test-AuthWireConsumedStageClosed $Root $h.Life $s $Binding $Key}
   if(-not $safe){$eligible=$false;$reason='review_barrier';if($j -ne $h.ActiveStates.Count-1){throw 'LIFECYCLE_PENDING_HISTORY_GAP'}}
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

function Get-AuthWireStageConsumptionReview([string]$Root,[string]$SlotPath,$State,[hashtable]$Binding,[Security.Cryptography.RSACng]$Key){
 # Evidence classification only. Missing markers never authorize a retry or unlock.
 if($State.Offer.operation -cne 'combined.filesystem.stage.v1'){return}
 $jobId=$State.Offer.job_id;$release=$State.Started.release_id
 $job=Join-Path $Root $jobId;$failure=Join-Path $SlotPath 'dispatch-failed.json'
 $consumed=Join-Path $job 'grant-consumed.json'
 if(-not (Test-Path -LiteralPath $failure) -or -not (Test-Path -LiteralPath $consumed)){return}
 $p=[AuthWire.Staging.TreeLeaseV1]::new()
 try{
  $p.PinAncestors($SlotPath);$p.PinAncestors($job);$p.PinFile($failure);$p.PinFile($consumed)
  $f=Read-AuthWireStagingJournal $failure
  if($f.phase -cne 'consume'){return}
  foreach($name in @('filesystem-intent.json','stage-launch.json','stage-child.json','stage-entered.json','stage-preflight.json','execution-complete.json','execution-observed.json','execution-requires-review.json')){
   if(Test-Path -LiteralPath (Join-Path $job $name)){return}
  }
  $auth=Read-AuthWireWriteAuthorizationEvidence $Root $jobId $Binding $release $Key
  $op=Get-AuthWireFilesystemOperationId $auth
  if((Get-AuthWireWriteHash $auth.Offer) -cne (Get-AuthWireWriteHash $State.Offer) -or
     (Test-Path -LiteralPath (Join-Path $Root $op))){return}
  $record=Read-AuthWireStagingJournal $consumed
  Assert-AuthWireCandidateFields $record @('format','binding_scope','release_id','job_id','authorization_sha256','filesystem_operation_id','consumed_at','expires_at')
  if($record.format -cne 'AuthWireWriteGrantConsumedV1' -or $record.binding_scope -cne (Get-AuthWireJobScope $Binding) -or
     $record.release_id -cne $release -or $record.job_id -cne $jobId -or $record.authorization_sha256 -cne $auth.AuthorizationSha256 -or
     $record.filesystem_operation_id -cne $op -or -not (Test-AuthWireWriteInteger $record.consumed_at) -or
     -not (Test-AuthWireWriteInteger $record.expires_at) -or $record.expires_at -ne $auth.Receipt.grant.expires_at -or
     $record.consumed_at -lt $auth.Receipt.received_at -or $record.consumed_at -ge $record.expires_at -or
     $record.consumed_at -gt $f.checked_at){throw 'WRITE_CONSUMPTION_REVIEW_REJECTED'}
  $diagnostic=if($f.format -ceq 'AuthWireLifecycleDispatchFailedV2'){$f.diagnostic_code}else{'unavailable'}
  return [pscustomobject]@{Phase='consumed_without_filesystem_intent';DiagnosticCode=$diagnostic;GrantConsumedSha256=(Get-AuthWireWriteHash $record);GrantExpiresAt=$record.expires_at}
 }finally{$p.Dispose()}
}

function New-AuthWireConsumedStageRecoveryBody($State,$Completion,$Consumption,$Fresh,[long]$Now){
 $offer=$State.Offer;$approved=$offer.target.preview_record;$seen=$Fresh.Preview
 if($Completion.outcome -cne 'requires_review' -or $Consumption.Phase -cne 'consumed_without_filesystem_intent' -or
    -not (Test-AuthWireWriteInteger $Consumption.GrantExpiresAt) -or -not (Test-AuthWireWriteInteger $seen.checked_at) -or
    $seen.checked_at -lt $Consumption.GrantExpiresAt -or $seen.checked_at -gt $Now -or $Now -ge $seen.checked_at+60){
  throw 'WRITE_RECOVERY_EVIDENCE_NOT_CURRENT'
 }
 if((Get-AuthWireWritePreviewHash $seen) -cne $Fresh.PreviewSha256){throw 'WRITE_RECOVERY_PREVIEW_REJECTED'}
 # Compare all approved observations, excluding the fresh timestamps only.
 $normalized=ConvertTo-AuthWireWriteOrderedPreview $seen
 $normalized.checked_at=$approved.Preview.checked_at
 $normalized.expires_at=$approved.Preview.expires_at
 if((Get-AuthWireWritePreviewHash $normalized) -cne $approved.PreviewSha256){throw 'WRITE_RECOVERY_OBSERVATIONS_CHANGED'}
 $lock=[pscustomobject]@{format='AuthWireWriteGpoLockV1';job_id=$offer.job_id;intent_sha256=$offer.intent_sha256}
 return [pscustomobject][ordered]@{
  format='AuthWireConsumedStageRecoveryEvidenceV1'
  job_id=$offer.job_id
  gpo_id=$offer.target.scope_target.gpo_id
  scope_sha256=$offer.scope_sha256
  intent_sha256=$offer.intent_sha256
  result_body_sha256=$Completion.result_body_sha256
  accepted_ack_sha256=$Completion.ack_sha256
  completion_sha256=(Get-AuthWireWriteHash $Completion)
  grant_consumed_sha256=$Consumption.GrantConsumedSha256
  lock_sha256=(Get-AuthWireWriteHash $lock)
  approved_preview_sha256=$approved.PreviewSha256
  observed_preview_sha256=$Fresh.PreviewSha256
  baseline_inventory_sha256=$seen.baseline_inventory_sha256
  grant_expires_at=$Consumption.GrantExpiresAt
  observed_at=$seen.checked_at
  expires_at=($seen.checked_at+60)
 }
}

function Get-AuthWireConsumedStageRecoveryFrame($Body){
 return ,([Text.Encoding]::ASCII.GetBytes("AUTHWIRE-CONSUMED-STAGE-RECOVERY-EVIDENCE-V1`n"+(Get-AuthWireWriteHash $Body)+"`n"))
}

function New-AuthWireConsumedStageRecoveryProof($State,$Completion,$Consumption,$Fresh,[Security.Cryptography.RSACng]$Key,[long]$Now){
 # Domain-separated evidence for an operator review. It is never a write grant.
 $body=New-AuthWireConsumedStageRecoveryBody $State $Completion $Consumption $Fresh $Now
 $signature=$Key.SignData((Get-AuthWireConsumedStageRecoveryFrame $body),[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1)
 return [pscustomobject]@{Body=$body;Signature=[Convert]::ToBase64String($signature)}
}

function Read-AuthWireConsumedStageRecoveryState([string]$Root,[string]$JobId,[hashtable]$Binding,[Security.Cryptography.RSACng]$Key,$Pins,[bool]$PinLock=$true){
  # The caller holds the Connector cycle mutex and owns the file pins.
  $pins.PinAncestors($Root)
  $history=Read-AuthWireLifecycleHistory $Root $Binding $Key
  if(-not $history.ActiveStates.Count){throw 'WRITE_RECOVERY_STAGE_NOT_FOUND'}
  $state=$history.ActiveStates[-1]
  if($state.Phase -cne 'reply_saved' -or $state.Offer.job_id -cne $JobId -or $state.Offer.operation -cne 'combined.filesystem.stage.v1'){
   throw 'WRITE_RECOVERY_STAGE_NOT_FOUND'
  }
  $slot=Join-Path $history.Life $state.Slot
  $target=$state.Offer.target.scope_target
  $pins.PinAncestors($slot)
  $pins.PinFile((Join-Path $slot 'completion.json'))
  if($PinLock){$pins.PinFile((Join-Path $Root ('gpo-'+$target.gpo_id+'.json')))}
  $done=Read-AuthWireLifecycleCompletion $Root $history.Life $state $Binding $Key
  $consumed=Get-AuthWireStageConsumptionReview $Root $slot $state $Binding $Key
  if($done.outcome -cne 'requires_review' -or $null -eq $consumed -or
     [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() -lt $consumed.GrantExpiresAt){throw 'WRITE_RECOVERY_STAGE_NOT_ELIGIBLE'}
  return [pscustomobject]@{State=$state;Slot=$slot;Completion=$done;Consumption=$consumed}
}

function Get-AuthWireConsumedStageRecoveryEvidence([string]$Root,[string]$JobId,[hashtable]$Binding,[Security.Cryptography.RSACng]$Key,[string]$PublisherThumbprint,[string]$BaseUrl){
 Assert-AuthWireStagingWriteJournalLocation $Root $Binding
 Assert-AuthWireCandidateGuid $JobId
 Initialize-AuthWireStagingFilesystemTypes
 $lock=Enter-AuthWireWriteCycleLock $Binding;$pins=[AuthWire.Staging.TreeLeaseV1]::new()
 try{
  $current=Read-AuthWireConsumedStageRecoveryState $Root $JobId $Binding $Key $pins
  $fresh=Get-AuthWireCombinedStagingPreview $current.State.Offer.target.scope_target $Binding $PublisherThumbprint $BaseUrl
  $again=Get-AuthWireStageConsumptionReview $Root $current.Slot $current.State $Binding $Key
  if($null -eq $again -or $again.GrantConsumedSha256 -cne $current.Consumption.GrantConsumedSha256){throw 'WRITE_RECOVERY_STAGE_CHANGED'}
  return (New-AuthWireConsumedStageRecoveryProof $current.State $current.Completion $again $fresh $Key ([DateTimeOffset]::UtcNow.ToUnixTimeSeconds()))
 }finally{$pins.Dispose();$lock.ReleaseMutex();$lock.Dispose()}
}

function Assert-AuthWireConsumedStageRecoveryReceipt($Request,$Reply,[long]$Now){
 $approval=$Request.approval;$proof=$approval.consumed_stage_proof;$body=$proof.Body
 Assert-AuthWireCandidateFields $Reply @('job_id','gpo_id','decision','approval_revision','approval_verified','approval_request_sha256','consumed_stage_proof_sha256','evidence_expires_at','review_only','source_only','approval_enabled','write_authorization_enabled','execution_adapter_available','can_apply_gpo')
 if($Reply.job_id -cne $body.job_id -or $Reply.gpo_id -cne $body.gpo_id -or
    $Reply.decision -cne 'approve_consumed_stage_lock_release' -or
    -not (Test-AuthWireWriteInteger $Reply.approval_revision) -or $Reply.approval_revision -ne $Request.approval_revision -or
    $Reply.approval_request_sha256 -cne (Get-AuthWireWriteHash $approval) -or
    $Reply.consumed_stage_proof_sha256 -cne (Get-AuthWireWriteHash $proof) -or
    -not (Test-AuthWireWriteInteger $Reply.evidence_expires_at) -or $Reply.evidence_expires_at -ne $body.expires_at -or
    $Now -lt $body.observed_at -or $Now -ge $body.expires_at){throw 'WRITE_RECOVERY_RECEIPT_REJECTED'}
 foreach($field in @('approval_verified','review_only','approval_enabled','write_authorization_enabled','execution_adapter_available')){
  if($Reply.$field -isnot [bool] -or -not $Reply.$field){throw 'WRITE_RECOVERY_RECEIPT_REJECTED'}
 }
 foreach($field in @('source_only','can_apply_gpo')){
  if($Reply.$field -isnot [bool] -or $Reply.$field){throw 'WRITE_RECOVERY_RECEIPT_REJECTED'}
 }
}

function Confirm-AuthWireConsumedStageRecoveryApproval([string]$Root,[string]$JobId,[hashtable]$Binding,[Security.Cryptography.RSACng]$Key,[string]$BaseUrl,$Request,[securestring]$Session,[securestring]$Csrf){
 Assert-AuthWireStagingWriteJournalLocation $Root $Binding
 Assert-AuthWireCandidateGuid $JobId
 Assert-AuthWireCandidateFields $Request @('approval','approval_revision')
 $approval=$Request.approval
 Assert-AuthWireCandidateFields $approval @('expected_revision','evidence','decision','review_hash','acknowledge','reconciliation_receipt','consumed_stage_proof')
 $proof=$approval.consumed_stage_proof
 Assert-AuthWireCandidateFields $proof @('Body','Signature')
 $body=$proof.Body
 if($body.job_id -cne $JobId -or $approval.decision -cne 'approve_consumed_stage_lock_release' -or
    -not (Test-AuthWireWriteInteger $body.observed_at) -or
    -not (Test-AuthWireWriteInteger $approval.expected_revision) -or
    -not (Test-AuthWireWriteInteger $Request.approval_revision) -or $Request.approval_revision -ne ($approval.expected_revision+1)){
  throw 'WRITE_RECOVERY_APPROVAL_REJECTED'
 }
 Initialize-AuthWireStagingFilesystemTypes
 Initialize-AuthWireWriteTransportTypes
 $lock=Enter-AuthWireWriteCycleLock $Binding;$pins=[AuthWire.Staging.TreeLeaseV1]::new()
 try{
  $current=Read-AuthWireConsumedStageRecoveryState $Root $JobId $Binding $Key $pins
  # Rebuild the attested body from the pinned local journals and approved preview
  # at the original observation time. The existing proof must still be fresh.
  $preview=ConvertTo-AuthWireWriteOrderedPreview $current.State.Offer.target.preview_record.Preview
  $preview.checked_at=$body.observed_at;$preview.expires_at=$body.observed_at+90
  $fresh=[pscustomobject]@{Preview=$preview;PreviewSha256=(Get-AuthWireWritePreviewHash $preview)}
  $expected=New-AuthWireConsumedStageRecoveryBody $current.State $current.Completion $current.Consumption $fresh ([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())
  $signature=ConvertFrom-AuthWireWriteBase64 $proof.Signature 512
  if((Get-AuthWireWriteHash $expected) -cne (Get-AuthWireWriteHash $body) -or $signature.Length -ne $Key.KeySize/8 -or
     -not $Key.VerifyData((Get-AuthWireConsumedStageRecoveryFrame $expected),$signature,[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1)){
   throw 'WRITE_RECOVERY_APPROVAL_REJECTED'
  }
  $reply=[AuthWire.Connector.WriteTransportV1]::VerifyStageRecovery($BaseUrl,$Binding.appliance_fqdn,$Binding.appliance_tls_sha256,(ConvertTo-AuthWireWriteJson $Request),[Net.NetworkCredential]::new('',$Session).Password,[Net.NetworkCredential]::new('',$Csrf).Password)
  $receipt=ConvertFrom-AuthWireCandidateJson ([Text.UTF8Encoding]::new($false,$true).GetBytes($reply))
  Assert-AuthWireConsumedStageRecoveryReceipt $Request $receipt ([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())
  return $receipt
 }finally{$pins.Dispose();$lock.ReleaseMutex();$lock.Dispose()}
}


function Get-AuthWireConsumedStageClosureFrame($Body){
 return ,([Text.Encoding]::ASCII.GetBytes("AUTHWIRE-CONSUMED-STAGE-CLOSURE-V1`n"+(Get-AuthWireWriteHash $Body)+"`n"))
}
function New-AuthWireConsumedStageClosureBody($Request,[long]$At){
 $approval=$Request.approval;$b=$approval.consumed_stage_proof.Body
 return [pscustomobject][ordered]@{
  format='AuthWireConsumedStageClosureV1';job_id=$b.job_id;gpo_id=$b.gpo_id
  scope_sha256=$b.scope_sha256;intent_sha256=$b.intent_sha256;result_body_sha256=$b.result_body_sha256
  completion_sha256=$b.completion_sha256;lock_sha256=$b.lock_sha256
  consumed_stage_proof_sha256=(Get-AuthWireWriteHash $approval.consumed_stage_proof)
  approval_request_sha256=(Get-AuthWireWriteHash $approval);approval_revision=$Request.approval_revision
  closed_at=$At;evidence_expires_at=$b.expires_at;lock_released=$true
 }
}
function Test-AuthWireConsumedStageClosed([string]$Root,[string]$Life,$State,[hashtable]$Binding,[Security.Cryptography.RSACng]$Key){
 $job=Join-Path $Root $State.Offer.job_id;$file=Join-Path $job 'consumed-stage-closed.json'
 if(-not (Test-Path -LiteralPath $file)){return $false}
 $p=[AuthWire.Staging.TreeLeaseV1]::new()
 try{
  $p.PinAncestors($Root);$p.PinAncestors($job);$p.PinFile($file)
  $releaseFile=Join-Path $job 'consumed-stage-release.json';$p.PinFile($releaseFile)
  $savedLock=Join-Path $job 'released-gpo-lock.json';$p.PinFile($savedLock)
  $release=Read-AuthWireStagingJournal $releaseFile
  Assert-AuthWireCandidateFields $release @('format','request','receipt')
  if($release.format -cne 'AuthWireConsumedStageReleaseV1'){throw 'WRITE_RECOVERY_CLOSURE_REJECTED'}
  $request=$release.request;$body=$request.approval.consumed_stage_proof.Body
  Assert-AuthWireCandidateFields $request @('approval','approval_revision')
  $closed=Read-AuthWireStagingJournal $file
  Assert-AuthWireCandidateFields $closed @('Body','Signature')
  if(-not (Test-AuthWireWriteInteger $closed.Body.closed_at) -or $closed.Body.closed_at -gt [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()){throw 'WRITE_RECOVERY_CLOSURE_REJECTED'}
  Assert-AuthWireConsumedStageRecoveryReceipt $request $release.receipt $closed.Body.closed_at
  $expected=New-AuthWireConsumedStageClosureBody $request $closed.Body.closed_at
  if((Get-AuthWireWriteHash $expected) -cne (Get-AuthWireWriteHash $closed.Body) -or
     -not $Key.VerifyData((Get-AuthWireConsumedStageClosureFrame $expected),(ConvertFrom-AuthWireWriteBase64 $closed.Signature 512),[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1)){throw 'WRITE_RECOVERY_CLOSURE_REJECTED'}
  $done=Read-AuthWireLifecycleCompletion $Root $Life $State $Binding $Key
  $consumed=Get-AuthWireStageConsumptionReview $Root (Join-Path $Life $State.Slot) $State $Binding $Key
  $preview=ConvertTo-AuthWireWriteOrderedPreview $State.Offer.target.preview_record.Preview
  $preview.checked_at=$body.observed_at;$preview.expires_at=$body.observed_at+90
  $fresh=[pscustomobject]@{Preview=$preview;PreviewSha256=(Get-AuthWireWritePreviewHash $preview)}
  $attested=New-AuthWireConsumedStageRecoveryBody $State $done $consumed $fresh $closed.Body.closed_at
  if((Get-AuthWireWriteHash $body) -cne (Get-AuthWireWriteHash $attested) -or
     -not $Key.VerifyData((Get-AuthWireConsumedStageRecoveryFrame $attested),(ConvertFrom-AuthWireWriteBase64 $request.approval.consumed_stage_proof.Signature 512),[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1) -or
     (Get-AuthWireWriteHash (Read-AuthWireStagingJournal $savedLock)) -cne $body.lock_sha256){throw 'WRITE_RECOVERY_CLOSURE_REJECTED'}
  # A later job may own a new lock for the same GPO. It must never be mistaken
  # for this retired job or removed by recovery of the old job.
  $active=Join-Path $Root ('gpo-'+$body.gpo_id+'.json')
  if(Test-Path -LiteralPath $active){
   $p.PinFile($active);$l=Read-AuthWireStagingJournal $active
   if($l.job_id -ceq $State.Offer.job_id){throw 'WRITE_RECOVERY_LOCK_STILL_PRESENT'}
  }
  return $true
 }finally{$p.Dispose()}
}
function Complete-AuthWireConsumedStageLocalClosure([string]$Root,[string]$JobId,[hashtable]$Binding,[Security.Cryptography.RSACng]$Key,[string]$PublisherThumbprint,[string]$BaseUrl,$Request,[securestring]$Session,[securestring]$Csrf,[string]$EnrollmentBaseUrl=''){
 Assert-AuthWireStagingWriteJournalLocation $Root $Binding;Assert-AuthWireCandidateGuid $JobId
 # The isolated write HTTPS port is transport only. Signed enrollment content
 # remains bound to the canonical appliance URL in the protected service config.
 if($EnrollmentBaseUrl -ceq ''){$EnrollmentBaseUrl=$BaseUrl}
 $enrollment=$null
 if(-not [uri]::TryCreate($EnrollmentBaseUrl,[UriKind]::Absolute,[ref]$enrollment) -or
    $enrollment.Scheme -cne 'https' -or $enrollment.Host -cne $Binding.appliance_fqdn -or
    $enrollment.UserInfo -or $enrollment.Query -or $enrollment.Fragment -or $enrollment.AbsolutePath -cne '/'){
  throw 'WRITE_RECOVERY_ENROLLMENT_URL_REJECTED'
 }
 Initialize-AuthWireStagingFilesystemTypes
 $mutex=Enter-AuthWireWriteCycleLock $Binding;$p=[AuthWire.Staging.TreeLeaseV1]::new();$owned=$null
 try{
  $p.PinAncestors($Root)
  $current=Read-AuthWireConsumedStageRecoveryState $Root $JobId $Binding $Key $p $false
  $job=Join-Path $Root $JobId;$p.PinAncestors($job)
  foreach($name in @('consumed-stage-release.json','released-gpo-lock.json','consumed-stage-closed.json')){
   if(Test-Path -LiteralPath (Join-Path $job $name)){throw 'WRITE_RECOVERY_PARTIAL_REQUIRES_REVIEW'}
  }
  foreach($file in Get-ChildItem -LiteralPath $job -Force){
   if($file.PSIsContainer){throw 'WRITE_RECOVERY_CLOSURE_REJECTED'};$p.PinFile($file.FullName)
  }
  $receipt=Confirm-AuthWireConsumedStageRecoveryApproval $Root $JobId $Binding $Key $BaseUrl $Request $Session $Csrf
  # A second real observation immediately precedes retirement. Normalize only
  # timestamps; any AD, source, ACL or SYSVOL drift keeps the lock closed.
  $fresh=Get-AuthWireCombinedStagingPreview $current.State.Offer.target.scope_target $Binding $PublisherThumbprint $EnrollmentBaseUrl
  $null=New-AuthWireConsumedStageRecoveryBody $current.State $current.Completion $current.Consumption $fresh ([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())
  $now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
  Assert-AuthWireConsumedStageRecoveryReceipt $Request $receipt $now
  $lockPath=Join-Path $Root ('gpo-'+$Request.approval.consumed_stage_proof.Body.gpo_id+'.json')
  $owned=[AuthWire.Staging.TreeLeaseV1]::OwnedLockFile($lockPath)
  $lockRecord=ConvertFrom-AuthWireCandidateJson ($owned.ReadOwnedBytes('lock'))
  if((Get-AuthWireWriteHash $lockRecord) -cne $Request.approval.consumed_stage_proof.Body.lock_sha256){throw 'WRITE_RECOVERY_LOCK_CHANGED'}
  Write-AuthWireStagingJournal (Join-Path $job 'consumed-stage-release.json') ([pscustomobject]@{format='AuthWireConsumedStageReleaseV1';request=$Request;receipt=$receipt})
  Write-AuthWireStagingJournal (Join-Path $job 'released-gpo-lock.json') $lockRecord
  # The only deletion is the exact held local lock, after immutable evidence
  # and its historical copy are flushed. No SYSVOL, AD, job or grant is deleted.
  $start=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds();$ticks=[Diagnostics.Stopwatch]::GetTimestamp()
  $until=[long][Math]::Min($start+30,$Request.approval.consumed_stage_proof.Body.expires_at)
  $owned.DeleteOwnedTreeBefore($until,$start,$ticks);$owned.Dispose();$owned=$null
  $at=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
  Assert-AuthWireConsumedStageRecoveryReceipt $Request $receipt $at
  $body=New-AuthWireConsumedStageClosureBody $Request $at
  $sig=$Key.SignData((Get-AuthWireConsumedStageClosureFrame $body),[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1)
  $closed=[pscustomobject]@{Body=$body;Signature=[Convert]::ToBase64String($sig)}
  Write-AuthWireStagingJournal (Join-Path $job 'consumed-stage-closed.json') $closed
  if(-not (Test-AuthWireConsumedStageClosed $Root (Get-AuthWireWriteLifecyclePath $Root $Binding) $current.State $Binding $Key)){throw 'WRITE_RECOVERY_CLOSURE_REJECTED'}
  return $closed
 }finally{if($owned){$owned.Dispose()};$p.Dispose();$mutex.ReleaseMutex();$mutex.Dispose()}
}
function Send-AuthWireConsumedStageClosure([hashtable]$Binding,[string]$BaseUrl,$Request,$Closure,[securestring]$Session,[securestring]$Csrf){
 Initialize-AuthWireWriteTransportTypes
 $value=[pscustomobject]@{approval=$Request.approval;approval_revision=$Request.approval_revision;closure=$Closure}
 $raw=[AuthWire.Connector.WriteTransportV1]::CloseStageRecovery($BaseUrl,$Binding.appliance_fqdn,$Binding.appliance_tls_sha256,(ConvertTo-AuthWireWriteJson $value),[Net.NetworkCredential]::new('',$Session).Password,[Net.NetworkCredential]::new('',$Csrf).Password)
 $reply=ConvertFrom-AuthWireCandidateJson ([Text.UTF8Encoding]::new($false,$true).GetBytes($raw))
 Assert-AuthWireCandidateFields $reply @('job_id','gpo_id','closed','closure_revision','closure_sha256','source_only','approval_enabled','write_authorization_enabled','execution_adapter_available','can_apply_gpo')
 if($reply.job_id -cne $Closure.Body.job_id -or $reply.gpo_id -cne $Closure.Body.gpo_id -or
    $reply.closed -isnot [bool] -or -not $reply.closed -or $reply.can_apply_gpo -isnot [bool] -or $reply.can_apply_gpo -or
    -not (Test-AuthWireWriteInteger $reply.closure_revision) -or $reply.closure_sha256 -cne (Get-AuthWireWriteHash $Closure)){throw 'WRITE_RECOVERY_CLOSURE_RECEIPT_REJECTED'}
 return $reply
}

function Get-AuthWireWriteReconciliationReview([string]$Root,[hashtable]$Binding,[Security.Cryptography.RSACng]$Key){
 # This is a local evidence read. Even a valid ACK is not fresh approval.
 Assert-AuthWireStagingWriteJournalLocation $Root $Binding
 Initialize-AuthWireStagingFilesystemTypes
 $lock=Enter-AuthWireWriteCycleLock $Binding;$pins=[AuthWire.Staging.TreeLeaseV1]::new()
 $review=[pscustomobject]@{Phase='no_active_cycles';Slot='';JobId='';RecordedOutcome='';AcceptedAck=$false;Evidence=$null;StageConsumption=$null}
 try{
  $pins.PinAncestors($Root)
  if(-not (Get-ChildItem -LiteralPath $Root -Force -ErrorAction Stop|Select-Object -First 1)){return $review}
  $h=Read-AuthWireLifecycleHistory $Root $Binding $Key
  for($i=0;$i -lt $h.ActiveStates.Count;$i++){
   $state=$h.ActiveStates[$i];$dir=Join-Path $h.Life $state.Slot
   $pins.PinAncestors($dir)
   $review.Slot=$state.Slot;$review.JobId='';$review.RecordedOutcome='';$review.AcceptedAck=$false;$review.Evidence=$null;$review.StageConsumption=$null
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
    $done=Read-AuthWireLifecycleCompletion $Root $h.Life $state $Binding $Key
    $review.Phase='completion_verified';$review.RecordedOutcome=$done.outcome;$review.AcceptedAck=$review.JobId -cne ''
    if($review.Evidence){$review.Evidence.result_body_sha256=$done.result_body_sha256;$review.Evidence.accepted_ack=$true}
    if($done.outcome -ceq 'requires_review' -and (Test-AuthWireConsumedStageClosed $Root $h.Life $state $Binding $Key)){$review.Phase='closed_without_filesystem_intent';continue}
    if($done.outcome -ceq 'requires_review'){$review.StageConsumption=Get-AuthWireStageConsumptionReview $Root $dir $state $Binding $Key}
    if($done.outcome -cin @('requires_review','refused_before_authorization') -and $i -ne $h.ActiveStates.Count-1){throw 'LIFECYCLE_PENDING_HISTORY_GAP'}
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
    if($e.Outcome -ceq 'requires_review'){$review.StageConsumption=Get-AuthWireStageConsumptionReview $Root $dir $state $Binding $Key}
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
  return [pscustomobject]@{Phase='evidence_invalid_or_unavailable';Slot='';JobId='';RecordedOutcome='';AcceptedAck=$false;Evidence=$null;StageConsumption=$null}
 }finally{$pins.Dispose();$lock.ReleaseMutex();$lock.Dispose()}
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
