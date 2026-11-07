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
 }else{
  if($case -cin @('ref_lost_ack','ref_ack_limit')){
   Check ($rfFirst.Phase -ceq 'refusal_result_pending' -and -not $rfFirst.ResultRecorded) 'lost or wrong ACK leaves immutable refusal pending'
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
   Reject {New-AuthWireRollbackClaim $journal $rfId $b $release $rsa} 'refusal blocks separate rollback CLAIM'
   Reject {Invoke-AuthWireRollbackClaimTransport $journal $rfId $b $release $rsa $url} 'refusal blocks rollback transport'
  }else{
   Reject {New-AuthWireStagingWriteClaim $journal $rfId $b $release $rsa} 'refusal blocks stage CLAIM'
   Reject {Invoke-AuthWireStagingWriteClaimTransport $journal $rfId $b $release $rsa $url} 'refusal blocks stage claim transport'
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
