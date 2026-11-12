param([switch]$StageOnly)
# Test-owned record-boundary reconstruction, not an actual VM reboot.
$lcRoot=Get-AuthWireStagingWriteJournalRoot $b;$lcLife=Get-AuthWireWriteLifecyclePath $lcRoot $b
$lcBefore=(Get-AuthWireSysvolInventory $gpo).Sha256;$lcMode=Join-Path $flowDirectory 'rollback-mode.json';$lcId=[guid]::NewGuid().ToString('D')
$lcJob='';$lcBody='';$lcReadFile='';$lcReads=''
try{
 if($StageOnly){
  $lcJob=$id;$lcBodyFile=Join-Path (Join-Path $lcRoot $id) 'result-outbox.json';$lcBody=(Read-AuthWireStagingJournal $lcBodyFile).body_sha256
  $lcReadFile=Join-Path $package ('reads-'+$id+'.txt');$lcReads=[IO.File]::ReadAllText($lcReadFile)
  # Loss after accepted RESULT but before completion flush: only reconstruct
  # the owned bookkeeping boundary. No product reset/delete API is exercised.
  [IO.File]::Delete((Join-Path (Join-Path $lcLife '000001') 'completion.json'))
  $lcReview=Get-AuthWireWriteReconciliationReview $lcRoot $b $rsa
  Check ($lcReview.Phase -ceq 'accepted_ack_completion_missing' -and $lcReview.AcceptedAck -and $lcReview.RecordedOutcome -ceq 'staged') 'read-only review verifies the saved stage ACK without creating completion'
  Check (-not (Test-Path -LiteralPath (Join-Path (Join-Path $lcLife '000001') 'completion.json'))) 'review leaves missing completion untouched'
  [IO.File]::WriteAllText((Join-Path $flowDirectory 'reconcile-stage.json'),(ConvertTo-AuthWireWriteJson $lcReview.Evidence))
  . (Join-Path $package 'StagingWriteLifecycle.ps1')
  $lcRecovered=Invoke-AuthWireStagingWriteLifecycleStep $lcRoot $b $release $rsa $url
  Check ($lcRecovered.Phase -ceq 'result_recorded' -and $lcRecovered.Outcome -ceq 'staged') 'accepted stage recovery completes only immutable result bookkeeping'
  Check ((Read-AuthWireStagingJournal $lcBodyFile).body_sha256 -ceq $lcBody -and [IO.File]::ReadAllText($lcReadFile) -ceq $lcReads) 'stage recovery does not renew completion time or observe AD again'
  Check ((Get-AuthWireSysvolInventory $gpo).Sha256 -ceq $lcBefore) 'stage result recovery performs no second SMB write'
 }else{
  [IO.File]::WriteAllText($lcMode,(@{stage_job_id=$id;job_id=$lcId;actor=[guid]::NewGuid().ToString('D');case=$case}|ConvertTo-Json -Compress))
  Wait-AuthWireFixtureCore
  if($case -ceq 'lc_saved_grant'){
   # Shared production helpers build the actual poll/dispatch and actual core
   # CLAIM receipt. Stopping at this boundary simulates controller loss;
   # consumption/child execution were never invoked by the fixture.
   $lcLock=Enter-AuthWireWriteCycleLock $b
   try{
    Initialize-AuthWireWriteLifecycle $lcRoot $b $rsa
    $lcState=New-AuthWireLifecyclePoll $lcLife '000001' $b $release $rsa $url
    New-AuthWireLifecycleDispatch $lcLife $lcState
    $lcOffer=$lcState.Offer
    $null=Save-AuthWireRollbackOffer $lcOffer $b $release $rsa $lcOffer.request_id
    $null=Invoke-AuthWireRollbackPreflight $lcRoot $lcId $b $release
    $null=New-AuthWireRollbackClaim $lcRoot $lcId $b $release $rsa
    $null=Invoke-AuthWireRollbackClaimTransport $lcRoot $lcId $b $release $rsa $url
   }finally{$lcLock.ReleaseMutex();$lcLock.Dispose()}
   Check (-not (Test-Path -LiteralPath (Join-Path (Join-Path $lcRoot $lcId) 'rollback-grant-consumed.json'))) 'saved real grant boundary contains no consumption'
   $lcReview=Get-AuthWireWriteReconciliationReview $lcRoot $b $rsa
   Check ($lcReview.Phase -ceq 'authorization_without_frozen_outcome' -and -not $lcReview.AcceptedAck -and $lcReview.RecordedOutcome -ceq '') 'authorization alone does not establish filesystem outcome'
  }
  $lcFirst=Invoke-AuthWireStagingWriteLifecycleStep $lcRoot $b $release $rsa $url
  if($case -cin @('lc_success','lc_lost_ack')){
   if($case -ceq 'lc_success'){Check ($lcFirst.Phase -ceq 'result_recorded' -and $lcFirst.Outcome -ceq 'rolled_back') 'one durable cycle dispatches separate real rollback to accepted core result'}
   else{Check ($lcFirst.Phase -ceq 'result_pending' -and -not $lcFirst.ResultRecorded) 'lost accepted ACK remains pending without closing cycle'}
   $lcJob=$lcId;$lcBodyFile=Join-Path (Join-Path $lcRoot $lcId) 'rollback-result-outbox.json';$lcBody=(Read-AuthWireStagingJournal $lcBodyFile).body_sha256
   $lcReadFile=Join-Path $package ('rollback-reads-'+$lcId+'.txt');$lcReads=[IO.File]::ReadAllText($lcReadFile)
   if($case -ceq 'lc_success'){[IO.File]::Delete((Join-Path (Join-Path $lcLife '000001') 'completion.json'))}
   $lcReview=Get-AuthWireWriteReconciliationReview $lcRoot $b $rsa
   if($case -ceq 'lc_lost_ack'){
    Check ($lcReview.Phase -ceq 'outbox_without_accepted_ack' -and -not $lcReview.AcceptedAck -and $lcReview.RecordedOutcome -ceq '') 'lost ACK remains unknown even with a valid frozen rollback result'
    [IO.File]::WriteAllText((Join-Path $flowDirectory 'reconcile-lost-ack.json'),(ConvertTo-AuthWireWriteJson $lcReview.Evidence))
   }else{
    Check ($lcReview.Phase -ceq 'accepted_ack_completion_missing' -and $lcReview.AcceptedAck -and $lcReview.RecordedOutcome -ceq 'rolled_back') 'read-only review verifies the saved rollback ACK'
   }
   Check (-not (Test-Path -LiteralPath (Join-Path (Join-Path $lcLife '000001') 'completion.json'))) 'review neither resends RESULT nor restores completion'
   . (Join-Path $package 'StagingWriteLifecycle.ps1')
   $lcRecovered=Invoke-AuthWireStagingWriteLifecycleStep $lcRoot $b $release $rsa $url
   Check ($lcRecovered.Phase -ceq 'result_recorded' -and $lcRecovered.Outcome -ceq 'rolled_back') 'restart step resumes only frozen rollback RESULT or accepted bookkeeping'
   Check ((Read-AuthWireStagingJournal $lcBodyFile).body_sha256 -ceq $lcBody -and [IO.File]::ReadAllText($lcReadFile) -ceq $lcReads) 'rollback result recovery preserves body and performs no new live observation'
   Check ((Get-AuthWireSysvolInventory $gpo).Sha256 -ceq $before.Sha256) 'durable rollback restores exact original GPO baseline'
  }elseif($case -ceq 'lc_idle'){
   Check ($lcFirst.Phase -ceq 'no_job') 'strict no-job response closes a durable idle cycle'
   . (Join-Path $package 'StagingWriteLifecycle.ps1')
   $lcSecond=Invoke-AuthWireStagingWriteLifecycleStep $lcRoot $b $release $rsa $url
   Check ($lcSecond.Phase -ceq 'no_job' -and (Get-AuthWireLifecycleSlots $lcLife).Count -eq 2) 'new idle poll advances only after verified previous completion'
   # Duplicate signed POLL history is refused even with locally rehashed links.
   $lcClone=Join-Path $lcLife '000003';[AuthWire.Staging.TreeLeaseV1]::CreateNewDirectory($lcClone)
   try{
    foreach($lcFile in Get-ChildItem -LiteralPath (Join-Path $lcLife '000002') -File){[IO.File]::WriteAllBytes((Join-Path $lcClone $lcFile.Name),[IO.File]::ReadAllBytes($lcFile.FullName))}
    $lcStart=Read-AuthWireStagingJournal (Join-Path $lcClone 'poll-started.json');$lcStart.slot='000003';[IO.File]::WriteAllText((Join-Path $lcClone 'poll-started.json'),($lcStart|ConvertTo-Json -Compress))
    $lcDuplicate='';try{Invoke-AuthWireStagingWriteLifecycleStep $lcRoot $b $release $rsa $url|Out-Null}catch{$lcDuplicate=$_.Exception.Message}
    Check ($lcDuplicate -ceq 'LIFECYCLE_DUPLICATE_POLL_HISTORY') 'duplicate request nonce cannot become a new history cycle'
   }finally{Remove-Item -LiteralPath $lcClone -Recurse -Force}
   # Capacity fixture only: synthesize independently signed no-job metadata,
   # not server requests, for slots3..64. No write grant is synthesized.
   foreach($lcN in 3..64){
    $lcSlot=$lcN.ToString('D6');$lcDir=Join-Path $lcLife $lcSlot;[AuthWire.Staging.TreeLeaseV1]::CreateNewDirectory($lcDir)
    $lcAt=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds();$lcProof=New-AuthWireStagingWriteProof $b $rsa POLL @{capability='combined.filesystem.write.v1';release_id=$release}
    $lcSentAt=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    $lcRequest=[Text.Encoding]::ASCII.GetString([Convert]::FromBase64String($lcProof.frame)).Split([char]10)[10]
    $lcSent=[pscustomobject]@{format='AuthWireLifecyclePollSentV1';request_id=$lcRequest;proof_sha256=(Get-AuthWireWriteHash $lcProof);sent_at=$lcSentAt}
    Write-AuthWireStagingJournal (Join-Path $lcDir 'poll-started.json') ([pscustomobject]@{format='AuthWireLifecyclePollStartedV1';binding_scope=(Get-AuthWireJobScope $b);release_id=$release;slot=$lcSlot;started_at=$lcAt})
    Write-AuthWireStagingJournal (Join-Path $lcDir 'poll-proof.json') ([pscustomobject]@{format='AuthWireLifecyclePollProofV1';proof=$lcProof})
    Write-AuthWireStagingJournal (Join-Path $lcDir 'poll-sent.json') $lcSent
    $lcReply=[pscustomobject]@{format=1;request_id=$lcRequest;scope_sha256=(Get-AuthWireJobScope $b);job_id='';operation='';lease_id='';intent_sha256='';expires_at=0;target=$null;write_authorized=$false;can_apply_gpo=$false}
    Write-AuthWireStagingJournal (Join-Path $lcDir 'poll-response.json') ([pscustomobject]@{format='AuthWireLifecyclePollResponseV1';poll_sha256=(Get-AuthWireWriteHash $lcSent);received_at=$lcSentAt;reply=$lcReply})
    $lcState=Read-AuthWireLifecyclePoll $lcLife $lcSlot $b $rsa;$null=Complete-AuthWireLifecycleCycle $lcRoot $lcLife $lcState $b $rsa
   }
   $lcFull=Invoke-AuthWireStagingWriteLifecycleStep $lcRoot $b $release $rsa $url
   Check ($lcFull.Phase -ceq 'history_limit_requires_maintenance' -and (Get-AuthWireLifecycleSlots $lcLife).Count -eq 64) 'bounded history stops without new POLL or automatic retention deletion'
   Check ((Get-AuthWireSysvolInventory $gpo).Sha256 -ceq $lcBefore) 'idle and capacity classification never change staged SMB content'
  }elseif($case -ceq 'lc_saved_grant'){
   Check ($lcFirst.Phase -ceq 'requires_review' -and $lcFirst.ResultRecorded) 'saved grant after controller-loss boundary reports only unconfirmed review'
   . (Join-Path $package 'StagingWriteLifecycle.ps1')
   Check ((Invoke-AuthWireStagingWriteLifecycleStep $lcRoot $b $release $rsa $url).Phase -ceq 'requires_review') 'acknowledged review is a durable no-new-poll barrier'
   Check (-not (Test-Path -LiteralPath (Join-Path (Join-Path $lcRoot $lcId) 'rollback-grant-consumed.json'))) 'recovery never consumes or executes a saved grant'
   Check ((Get-AuthWireSysvolInventory $gpo).Sha256 -ceq $lcBefore) 'saved-grant recovery leaves original staged data unchanged'
  }else{
   Check ($lcFirst.Phase -ceq 'local_reconciliation_required') 'lost CLAIM or uncertain POLL cannot be retried automatically'
   $lcReview=Get-AuthWireWriteReconciliationReview $lcRoot $b $rsa
   $lcExpected=if($case -ceq 'lc_lost_claim'){'claim_outcome_unknown'}else{'poll_outcome_unknown'}
   Check ($lcReview.Phase -ceq $lcExpected -and -not $lcReview.AcceptedAck -and $lcReview.RecordedOutcome -ceq '') 'uncertain transport gets no accepted outcome'
   if($case -ceq 'lc_lost_claim'){[IO.File]::WriteAllText((Join-Path $flowDirectory 'reconcile-lost-claim.json'),(ConvertTo-AuthWireWriteJson $lcReview.Evidence))}
   . (Join-Path $package 'StagingWriteLifecycle.ps1')
   Check ((Invoke-AuthWireStagingWriteLifecycleStep $lcRoot $b $release $rsa $url).Phase -ceq 'local_reconciliation_required') 'restart preserves uncertain request instead of sending another request'
   Check ((Get-AuthWireLifecycleSlots $lcLife).Count -eq 1) 'uncertain request never opens a new cycle slot'
   if($case -ceq 'lc_lost_claim'){Check (-not (Test-Path -LiteralPath (Join-Path (Join-Path $lcRoot $lcId) 'rollback-grant-consumed.json'))) 'lost grant cannot trigger consumption on restart'}
   Check ((Get-AuthWireSysvolInventory $gpo).Sha256 -ceq $lcBefore) 'uncertain-request recovery changes no SMB data'
  }
 }
 $lcWrong=@{};foreach($lcName in $b.Keys){$lcWrong[$lcName]=$b[$lcName]};$lcWrong.generation++
 Reject {Invoke-AuthWireStagingWriteLifecycleStep $lcRoot $lcWrong $release $rsa $url} 'binding generation change cannot adopt existing lifecycle history'
 $lcForeign=Join-Path $lcRoot 'foreign-root-record.txt'
 try{
  [IO.File]::WriteAllText($lcForeign,'fixture unknown data must not be deleted')
  $lcReview=Get-AuthWireWriteReconciliationReview $lcRoot $b $rsa
  Check ($lcReview.Phase -ceq 'evidence_invalid_or_unavailable' -and -not $lcReview.AcceptedAck) 'unreferenced record cannot become verified evidence'
  Reject {Invoke-AuthWireStagingWriteLifecycleStep $lcRoot $b $release $rsa $url} 'unreferenced root record prevents poll and action'
  Check (Test-Path -LiteralPath $lcForeign) 'unknown history is preserved for explicit review'
 }finally{[IO.File]::Delete($lcForeign)}
 Check (Test-Path -LiteralPath (Join-Path $lcLife 'baseline.json')) 'durable header remains in original fixed private root'
 if($env:AUTHWIRE_WRITE_HISTORY_CHECK -eq '1'){. (Join-Path $PSScriptRoot 'staging_write_history_fixture.ps1')}
 Write-Host ('WRITE_LIFECYCLE_CASE_OK case='+$case+' reload_record_boundary_simulated=true actual_machine_reboot=false customer_changed=false')
}finally{if(-not $StageOnly){[IO.File]::Delete($lcMode)}}
