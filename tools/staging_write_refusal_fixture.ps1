# Only in disposable hosted fixture. AD/preflight failure is an explicit stub;
# production POLL, decision/outbox, CNG proof, HTTPS and SQLite core remain real.
$rfStage=${function:Invoke-AuthWireStagingWritePreflight};$rfRollback=${function:Invoke-AuthWireRollbackPreflight}
$script:RefusalJournalWriter=${function:Write-AuthWireStagingJournal}
$rfLife=Get-AuthWireWriteLifecyclePath $journal $b;$rfId=$id;$rfMode=Join-Path $flowDirectory 'rollback-mode.json'
$rfBefore=(Get-AuthWireSysvolInventory $gpo).Sha256
try{
 if($case -ceq 'ref_rollback'){
  $rfId=[guid]::NewGuid().ToString('D')
  [IO.File]::WriteAllText($rfMode,(@{stage_job_id=$id;job_id=$rfId;actor=[guid]::NewGuid().ToString('D');case=$case}|ConvertTo-Json -Compress))
  Wait-AuthWireFixtureCore
  function Invoke-AuthWireRollbackPreflight {throw 'ROLLBACK_PREFLIGHT_FAILED'}
 }elseif($case -cne 'ref_claim'){
  function Invoke-AuthWireStagingWritePreflight {throw 'WRITE_PREFLIGHT_FAILED'}
 }
 if($case -ceq 'ref_disk'){
  function Write-AuthWireStagingJournal([string]$Path,$Value){
   if([IO.Path]::GetFileName($Path) -ceq 'refusal-outbox.json'){throw 'FIXTURE_DISK_ERROR'}
   & $script:RefusalJournalWriter $Path $Value
  }
 }
 $rfFirst=Invoke-AuthWireStagingWriteLifecycleStep $journal $b $release $rsa $url
 $rfJob=Join-Path $journal $rfId;$rfBox=Join-Path $rfJob 'refusal-outbox.json'
 if($case -cin @('ref_claim','ref_disk')){
  Check ($rfFirst.Phase -ceq 'local_reconciliation_required') 'uncertain claim or failed freeze remains reconciliation'
  Check (-not (Test-Path -LiteralPath $rfBox)) 'uncertain or unpersisted decision cannot claim no filesystem effects'
  . (Join-Path $package 'StagingWriteLifecycle.ps1')
  Check ((Invoke-AuthWireStagingWriteLifecycleStep $journal $b $release $rsa $url).Phase -ceq 'local_reconciliation_required') 'restart does not invent a late refusal or replay CLAIM'
  Check ($null -eq (Get-AuthWireWriteReconciliationReview $journal $b $rsa).StageLockReleaseEvidence) 'ambiguous history does not produce lock release evidence'
 }else{
  if($case -cin @('ref_lost_ack','ref_ack_limit')){
   Check ($rfFirst.Phase -ceq 'refusal_result_pending' -and -not $rfFirst.ResultRecorded) 'lost or wrong ACK leaves immutable refusal pending'
   Check ($null -eq (Get-AuthWireWriteReconciliationReview $journal $b $rsa).StageLockReleaseEvidence) 'missing ACK does not produce lock release evidence'
  }else{Check ($rfFirst.Phase -ceq 'refused_before_authorization' -and $rfFirst.ResultRecorded) 'preflight rejection reaches typed core result without CLAIM'}
  $rfState=Read-AuthWireLifecyclePoll $rfLife '000001' $b $rsa
  $rfBody=Read-AuthWireWriteRefusalOutbox $journal $rfLife $rfState $b $rsa
  Check ($rfBody.body.authorization_id -ceq '' -and $rfBody.body.filesystem_effects -ceq 'none' -and $rfBody.body.reason -ceq 'PREFLIGHT_FAILED') 'refusal body has no authority or successful staging assertion'
  $rfHash=$rfBody.body_sha256
  . (Join-Path $package 'StagingWriteLifecycle.ps1')
  $rfSecond=Invoke-AuthWireStagingWriteLifecycleStep $journal $b $release $rsa $url
  if($case -ceq 'ref_ack_limit'){
   $rfThird=Invoke-AuthWireStagingWriteLifecycleStep $journal $b $release $rsa $url
   $rfFourth=Invoke-AuthWireStagingWriteLifecycleStep $journal $b $release $rsa $url
   Check ($rfThird.Phase -ceq 'refusal_attempt_limit_requires_review' -and $rfFourth.Phase -ceq 'refusal_attempt_limit_requires_review') 'three durable refusal attempts exhaust without a fourth POST'
  }else{
   Check ($rfSecond.Phase -ceq 'refused_before_authorization' -and $rfSecond.ResultRecorded) 'reload only reports frozen body or verifies already accepted result'
  }
  Check ((Read-AuthWireWriteRefusalOutbox $journal $rfLife $rfState $b $rsa).body_sha256 -ceq $rfHash) 'recovery preserves original timestamp and body'
  Check ((Get-AuthWireLifecycleSlots $rfLife).Count -eq 1) 'refusal remains a no-new-POLL barrier'
  # Claim helper guards are exercised before any preflight access or proof.
  if($case -ceq 'ref_rollback'){
   Check ($null -eq (Get-AuthWireWriteReconciliationReview $journal $b $rsa).StageLockReleaseEvidence) 'rollback refusal does not produce stage lock release evidence'
   Reject {New-AuthWireRollbackClaim $journal $rfId $b $release $rsa} 'refusal blocks separate rollback CLAIM'
   Reject {Invoke-AuthWireRollbackClaimTransport $journal $rfId $b $release $rsa $url} 'refusal blocks rollback transport'
  }else{
   Reject {New-AuthWireStagingWriteClaim $journal $rfId $b $release $rsa} 'refusal blocks stage CLAIM'
   Reject {Invoke-AuthWireStagingWriteClaimTransport $journal $rfId $b $release $rsa $url} 'refusal blocks stage claim transport'
  }
  if($case -ceq 'ref_stage'){
   $rfLock=Join-Path $journal ('gpo-'+$t.gpo_id+'.json')
   $rfCompletion=Join-Path (Join-Path $rfLife '000001') 'completion.json'
   $rfLockBytes=[IO.File]::ReadAllBytes($rfLock)
   $rfCompletionBytes=[IO.File]::ReadAllBytes($rfCompletion)
   $rfDone=Read-AuthWireStagingJournal $rfCompletion
   $rfReview=Get-AuthWireWriteReconciliationReview $journal $b $rsa
   $rfEvidence=$rfReview.StageLockReleaseEvidence
   Check ($rfEvidence -and $rfEvidence.format -ceq 'AuthWireRefusedStageLockEvidenceV1' -and $rfEvidence.slot -ceq '000001' -and
    $rfEvidence.gpo_id -ceq $t.gpo_id -and $rfEvidence.job_id -ceq $rfId -and $rfEvidence.scope_sha256 -ceq $rfState.Offer.scope_sha256 -and
    $rfEvidence.intent_sha256 -ceq $rfState.Offer.intent_sha256 -and $rfEvidence.result_body_sha256 -ceq $rfHash -and
    $rfEvidence.accepted_ack_sha256 -ceq $rfDone.ack_sha256 -and $rfEvidence.completion_sha256 -ceq (Get-AuthWireWriteHash $rfDone) -and
    $rfEvidence.lock_sha256 -ceq (Get-AuthWireWriteHash (Read-AuthWireStagingJournal $rfLock))) 'verified refusal projects the original GPO lock and matching completion evidence'
   Check ([Convert]::ToBase64String([IO.File]::ReadAllBytes($rfLock)) -ceq [Convert]::ToBase64String($rfLockBytes) -and
    [Convert]::ToBase64String([IO.File]::ReadAllBytes($rfCompletion)) -ceq [Convert]::ToBase64String($rfCompletionBytes)) 'review preserves lock and completion bytes'
   $rfProjection=@{evidence=$rfReview.Evidence;stage_lock_evidence=$rfEvidence;stage_lock_evidence_sha256=(Get-AuthWireWriteHash $rfEvidence)}
   [IO.File]::WriteAllText((Join-Path $flowDirectory 'stage-lock-evidence.json'),($rfProjection|ConvertTo-Json -Depth 6 -Compress))
   $null=[IO.Directory]::CreateDirectory((Join-Path $flowDirectory 'stage-lock-review'))
   $rfReplyFile=Join-Path $flowDirectory 'stage-lock-verification.json'
   $rfFailed=Join-Path $flowDirectory 'stage-lock-verification-failed'
   $rfTimer=[Diagnostics.Stopwatch]::StartNew()
   while(-not [IO.File]::Exists($rfReplyFile) -and -not [IO.Directory]::Exists($rfFailed) -and $rfTimer.ElapsedMilliseconds -lt 15000){Start-Sleep -Milliseconds 25}
   Check ([IO.File]::Exists($rfReplyFile)) 'server rechecks the exact recorded approval'
   $rfReply=Read-AuthWireStagingJournal $rfReplyFile
   $rfReceipt=Read-AuthWireStagingJournal (Join-Path $flowDirectory 'stage-lock-receipt.json')
   $rfMatch=Test-AuthWireStageLockApprovalEvidence $journal $b $rsa $rfReply $rfReceipt.revision
   Check ($rfMatch.LocalEvidenceMatches -and $rfMatch.JobId -ceq $rfId -and -not $rfMatch.CanApplyGpo) 'Windows matches the server response to current local evidence'
   Reject {Test-AuthWireStageLockApprovalEvidence $journal $b $rsa $rfReply ($rfReceipt.revision+1)} 'Windows rejects a different approval revision'
   $rfReply.can_apply_gpo=$true
   Reject {Test-AuthWireStageLockApprovalEvidence $journal $b $rsa $rfReply $rfReceipt.revision} 'Windows rejects unexpected permission to apply GPO'
   $rfReply.can_apply_gpo=$false
   try{
    $rfChanged=Read-AuthWireStagingJournal $rfLock;$rfChanged.intent_sha256='0'*64
    [IO.File]::WriteAllText($rfLock,($rfChanged|ConvertTo-Json -Compress))
    $rfInvalid=Get-AuthWireWriteReconciliationReview $journal $b $rsa
    Check ($rfInvalid.Phase -ceq 'evidence_invalid_or_unavailable' -and $null -eq $rfInvalid.StageLockReleaseEvidence) 'mismatched lock never produces release evidence'
    Reject {Test-AuthWireStageLockApprovalEvidence $journal $b $rsa $rfReply $rfReceipt.revision} 'Windows refuses a previously verified response after local lock drift'
   }finally{[IO.File]::WriteAllBytes($rfLock,$rfLockBytes)}
   try{
    [IO.File]::Delete($rfCompletion)
    $rfPartial=Get-AuthWireWriteReconciliationReview $journal $b $rsa
    Check ($rfPartial.Phase -ceq 'accepted_ack_completion_missing' -and $null -eq $rfPartial.StageLockReleaseEvidence) 'a valid ACK alone does not produce lock release evidence'
    Reject {Test-AuthWireStageLockApprovalEvidence $journal $b $rsa $rfReply $rfReceipt.revision} 'Windows refuses a previously verified response without its local completion'
   }finally{[IO.File]::WriteAllBytes($rfCompletion,$rfCompletionBytes)}
  }
  $rfBytes=[IO.File]::ReadAllBytes($rfBox)
  try{
   $rfBad=Read-AuthWireStagingJournal $rfBox;$rfBad.body.reason='CONTENT_REJECTED';$rfBad.body_sha256=Get-AuthWireWriteHash $rfBad.body
   [IO.File]::WriteAllText($rfBox,($rfBad|ConvertTo-Json -Depth 10 -Compress))
   Reject {Read-AuthWireWriteRefusalOutbox $journal $rfLife $rfState $b $rsa} 'rehashed unsupported reason cannot replace observed preflight failure'
  }finally{[IO.File]::WriteAllBytes($rfBox,$rfBytes)}
  $rfForeign=Join-Path $rfJob 'claim-started.json'
  try{
   [IO.File]::WriteAllText($rfForeign,'uncertain CLAIM evidence')
   Reject {Read-AuthWireWriteRefusalOutbox $journal $rfLife $rfState $b $rsa} 'even a CLAIM start marker blocks no-effect report'
  }finally{[IO.File]::Delete($rfForeign)}
 }
 Check ((Get-AuthWireSysvolInventory $gpo).Sha256 -ceq $rfBefore) 'refusal or lost-claim recovery never writes or deletes SMB data'
 Check (Test-Path -LiteralPath (Join-Path $journal ('gpo-'+$t.gpo_id+'.json'))) 'original durable GPO lock is retained'
 Write-Host ('WRITE_REFUSAL_CASE_OK case='+$case+' job='+$rfId+' customer_changed=false')
}finally{
 ${function:Invoke-AuthWireStagingWritePreflight}=$rfStage;${function:Invoke-AuthWireRollbackPreflight}=$rfRollback
 ${function:Write-AuthWireStagingJournal}=$script:RefusalJournalWriter
 if($case -ceq 'ref_rollback'){[IO.File]::Delete($rfMode)}
}
