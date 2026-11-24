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
 # A historical refusal must retain the actual archived cycle context. These
 # native reads use the real signed POLL/offer and accepted HTTPS/core result.
 # The copied cycle here is a disposable path fixture, not a committed archive.
 if($case -ceq 'ref_rollback'){
  $rfArchive=Join-Path $rfLife 'history-archives\000001\cycles'
  [IO.Directory]::CreateDirectory($rfArchive)|Out-Null
  $rfSource=Join-Path $rfLife '000001';$rfCopy=Join-Path $rfArchive '000001'
  Copy-Item -LiteralPath $rfSource -Destination $rfCopy -Recurse
  $rfHold=Join-Path $flowDirectory ('held-refusal-cycle-'+[guid]::NewGuid().ToString('N'))
  [IO.Directory]::Move($rfSource,$rfHold)
  try{
   $rfArchivedState=Read-AuthWireLifecyclePoll $rfArchive '000001' $b $rsa
   $rfArchived=Read-AuthWireWriteRefusalOutbox $journal $rfArchive $rfArchivedState $b $rsa $true
   Check ($rfArchived.body_sha256 -ceq $rfHash) 'archived refusal retains exact original body after active cycle is absent'
   $rfCompletion=Read-AuthWireLifecycleCompletion $journal $rfArchive $rfArchivedState $b $rsa
   Check ($rfCompletion.outcome -ceq 'refused_before_authorization' -and $rfCompletion.result_body_sha256 -ceq $rfHash) 'archived completion follows the original accepted ACK through the supplied cycle context'
   Reject {Read-AuthWireWriteRefusalOutbox $journal $rfArchive $rfArchivedState $b $rsa} 'archived read requires explicit historical mode'
   Reject {New-AuthWireWriteRefusalOutbox $journal $rfArchive $rfArchivedState $b $rsa} 'archived context cannot create a refusal'
   Reject {Send-AuthWireWriteRefusal $journal $rfArchive $rfArchivedState $b $rsa $url} 'archived context cannot send a refusal or create a proof'
   foreach($badPath in @((Join-Path $rfLife 'history-archives\000002\cycles'),(Join-Path $rfLife 'history-archives\000001\cycles\..\cycles'),(Join-Path $flowDirectory 'history-archives\000001\cycles'))){
    Reject {Read-AuthWireWriteRefusalOutbox $journal $badPath $rfArchivedState $b $rsa $true} 'foreign noncanonical or out-of-segment archive path is refused'
   }
   $rfCompletePath=Join-Path $rfCopy 'completion.json';$rfCompleteBytes=[IO.File]::ReadAllBytes($rfCompletePath)
   try{[IO.File]::Delete($rfCompletePath);Reject {Read-AuthWireWriteRefusalOutbox $journal $rfArchive $rfArchivedState $b $rsa $true} 'missing archived completion cannot become historical acceptance'}finally{[IO.File]::WriteAllBytes($rfCompletePath,$rfCompleteBytes)}
   $rfForeign=Join-Path $rfJob 'rollback-claim-started.json'
   try{[IO.File]::WriteAllText($rfForeign,'uncertain');Reject {Read-AuthWireWriteRefusalOutbox $journal $rfArchive $rfArchivedState $b $rsa $true} 'historical reads preserve the strict no-CLAIM barrier'}finally{[IO.File]::Delete($rfForeign)}
  }finally{[IO.Directory]::Move($rfHold,$rfSource);Remove-Item (Join-Path $rfLife 'history-archives') -Recurse -Force}
 }
 Check ((Get-AuthWireSysvolInventory $gpo).Sha256 -ceq $rfBefore) 'refusal or lost-claim recovery never writes or deletes SMB data'
 Check (Test-Path -LiteralPath (Join-Path $journal ('gpo-'+$t.gpo_id+'.json'))) 'original durable GPO lock is retained'
 Write-Host ('WRITE_REFUSAL_CASE_OK case='+$case+' job='+$rfId+' customer_changed=false')
}finally{
 ${function:Invoke-AuthWireStagingWritePreflight}=$rfStage;${function:Invoke-AuthWireRollbackPreflight}=$rfRollback
 ${function:Write-AuthWireStagingJournal}=$script:RefusalJournalWriter
 if($case -ceq 'ref_rollback'){[IO.File]::Delete($rfMode)}
}

