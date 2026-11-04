# Hosted, test-owned native metadata only. Synthesized idle records below have
# real independent CNG signatures, but are NOT server requests or write grants.
function Add-HistoryFixtureIdle([int]$First,[int]$Last){
 foreach($n in $First..$Last){
  $slot=$n.ToString('D6');$dir=Join-Path $lcLife $slot;[AuthWire.Staging.TreeLeaseV1]::CreateNewDirectory($dir)
  $at=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds();$proof=New-AuthWireStagingWriteProof $b $rsa POLL @{capability='combined.filesystem.write.v1';release_id=$release}
  $sentAt=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds();$request=[Text.Encoding]::ASCII.GetString([Convert]::FromBase64String($proof.frame)).Split([char]10)[10]
  $sent=[pscustomobject]@{format='AuthWireLifecyclePollSentV1';request_id=$request;proof_sha256=(Get-AuthWireWriteHash $proof);sent_at=$sentAt}
  Write-AuthWireStagingJournal (Join-Path $dir 'poll-started.json') ([pscustomobject]@{format='AuthWireLifecyclePollStartedV1';binding_scope=(Get-AuthWireJobScope $b);release_id=$release;slot=$slot;started_at=$at})
  Write-AuthWireStagingJournal (Join-Path $dir 'poll-proof.json') ([pscustomobject]@{format='AuthWireLifecyclePollProofV1';proof=$proof})
  Write-AuthWireStagingJournal (Join-Path $dir 'poll-sent.json') $sent
  $reply=[pscustomobject]@{format=1;request_id=$request;scope_sha256=(Get-AuthWireJobScope $b);job_id='';operation='';lease_id='';intent_sha256='';expires_at=0;target=$null;write_authorized=$false;can_apply_gpo=$false}
  Write-AuthWireStagingJournal (Join-Path $dir 'poll-response.json') ([pscustomobject]@{format='AuthWireLifecyclePollResponseV1';poll_sha256=(Get-AuthWireWriteHash $sent);received_at=$sentAt;reply=$reply})
  $s=Read-AuthWireLifecyclePoll $lcLife $slot $b $rsa;$null=Complete-AuthWireLifecycleCycle $lcRoot $lcLife $s $b $rsa
 }
}
$historyAck='archive_observed_history_preserve_all_evidence'
$historyArea=Join-Path $lcLife 'history-archives';$historyBefore=(Get-AuthWireSysvolInventory $gpo).Sha256
$historyReview=Get-AuthWireWriteHistoryReview $lcRoot $b $rsa
if($case -cin @('lc_lost_poll','lc_saved_grant')){
 Check (-not $historyReview.Review.can_archive -and $historyReview.Review.reason -cin @('pending_cycle','review_barrier')) 'unknown POLL and accepted review are explicit archive barriers'
 Reject {Invoke-AuthWireWriteHistoryArchive $lcRoot $b $rsa $historyReview $historyAck} 'partial or uncertain history cannot retire any cycle'
 Check (-not (Test-Path -LiteralPath $historyArea) -and (Get-AuthWireLifecycleSlots $lcLife).Count -eq 1) 'blocked history review writes no maintenance record or new cycle'
}else{
 if($case -ceq 'lc_stage'){
  Check (-not $historyReview.Review.can_archive -and $historyReview.Review.cycle_count -eq 1) 'underfilled actual stage history is not eligible for archiving'
  Reject {Invoke-AuthWireWriteHistoryArchive $lcRoot $b $rsa $historyReview $historyAck} 'underfilled review cannot reset history'
  Add-HistoryFixtureIdle 2 64
 }
 $historyReview=Get-AuthWireWriteHistoryReview $lcRoot $b $rsa
 Check ($historyReview.Review.can_archive -and $historyReview.Review.cycle_count -eq 64 -and $historyReview.Review.first_slot -ceq '000001' -and $historyReview.Review.last_slot -ceq '000064') 'complete 64-cycle review binds exact original boundary'
 Reject {Invoke-AuthWireWriteHistoryArchive $lcRoot $b $rsa $historyReview 'wrong'} 'explicit local archival acknowledgement is required'
 $bad=Clone $historyReview;$bad.Review.protected_manifest_sha256='0'*64;$bad.ReviewSha256=Get-AuthWireWriteHash $bad.Review
 Reject {Invoke-AuthWireWriteHistoryArchive $lcRoot $b $rsa $bad $historyAck} 'rehashed different protected state is not the reviewed state'
 $bad=Clone $historyReview;$bad.Review.checked_at-=61;$bad.Review.expires_at-=61;$bad.ReviewSha256=Get-AuthWireWriteHash $bad.Review
 Reject {Invoke-AuthWireWriteHistoryArchive $lcRoot $b $rsa $bad $historyAck} 'expired local review never authorizes archival'
 $changed=Join-Path (Join-Path $lcLife '000064') 'completion.json';$saved=[IO.File]::ReadAllBytes($changed)
 try{
  [IO.File]::WriteAllBytes($changed,($saved+[Text.Encoding]::ASCII.GetBytes(' ')))
  Reject {Invoke-AuthWireWriteHistoryArchive $lcRoot $b $rsa $historyReview $historyAck} 'semantically equivalent changed original bytes require a fresh review'
 }finally{[IO.File]::WriteAllBytes($changed,$saved)}
 Check (-not (Test-Path -LiteralPath $historyArea)) 'rejected proposals leave the full original history unchanged'
 $historyReview=Get-AuthWireWriteHistoryReview $lcRoot $b $rsa
 $historyProtected=$historyReview.Review.protected_manifest_sha256;$historyBaseline=Get-AuthWireJobHash ([IO.File]::ReadAllBytes((Join-Path $lcLife 'baseline.json')))
 $watch=[Diagnostics.Stopwatch]::StartNew();$archived=Invoke-AuthWireWriteHistoryArchive $lcRoot $b $rsa $historyReview $historyAck;$watch.Stop()
 Write-Host ('HISTORY_FIXTURE_ARCHIVE_READY case='+$case+' elapsed_ms='+$watch.ElapsedMilliseconds)
 Check ($archived.Phase -ceq 'history_archived' -and $archived.ArchivedThrough -eq 64 -and -not $archived.NetworkSent -and -not $archived.CanApplyGpo) 'archive seals and retires only reviewed local cycle originals without network or GPO action'
 $after=Get-AuthWireWriteHistoryReview $lcRoot $b $rsa
 Check ($after.Review.archived_through -eq 64 -and $after.Review.cycle_count -eq 0 -and $after.Review.protected_manifest_sha256 -ceq $historyProtected) 'original stage job engine and GPO-lock records survive archive unchanged'
 Check ((Get-AuthWireJobHash ([IO.File]::ReadAllBytes((Join-Path $lcLife 'baseline.json')))) -ceq $historyBaseline) 'archive never replaces the immutable baseline'
 Reject {Invoke-AuthWireWriteHistoryArchive $lcRoot $b $rsa $historyReview $historyAck} 'completed maintenance review cannot be consumed again'
 $next=Invoke-AuthWireStagingWriteLifecycleStep $lcRoot $b $release $rsa $url
 Check ($next.Phase -ceq 'no_job' -and (Get-AuthWireLifecycleSlots $lcLife 64).Count -eq 1 -and (Test-Path -LiteralPath (Join-Path $lcLife '000065'))) 'verified archive allows one later real POLL with monotonic slot 65'
 $archiveDir=Join-Path $historyArea '000001';$cycles=Join-Path $archiveDir 'cycles';$archiveFile=Join-Path $archiveDir 'archive.json'
 $savedArchive=[IO.File]::ReadAllBytes($archiveFile)
 try{
  $tampered=Read-AuthWireStagingJournal $archiveFile;$tampered.body.protected_manifest_sha256='0'*64
  [IO.File]::WriteAllText($archiveFile,($tampered|ConvertTo-Json -Depth 12 -Compress))
  Reject {Invoke-AuthWireStagingWriteLifecycleStep $lcRoot $b $release $rsa $url} 'changed archive body fails its actual CNG signature before POLL'
 }finally{[IO.File]::WriteAllBytes($archiveFile,$savedArchive)}
 $copied=Join-Path (Join-Path $cycles '000064') 'completion.json';$savedCopy=[IO.File]::ReadAllBytes($copied)
 try{
  [IO.File]::WriteAllBytes($copied,($savedCopy+[Text.Encoding]::ASCII.GetBytes(' ')))
  Reject {Get-AuthWireWriteHistoryReview $lcRoot $b $rsa} 'even semantically equivalent archive byte drift is detected'
 }finally{[IO.File]::WriteAllBytes($copied,$savedCopy)}
 $commit=Join-Path $archiveDir 'committed.json';$savedCommit=[IO.File]::ReadAllBytes($commit)
 try{
  [IO.File]::Delete($commit)
  Reject {Invoke-AuthWireStagingWriteLifecycleStep $lcRoot $b $release $rsa $url} 'lost maintenance completion is a no-new-POLL reconciliation stop'
  Check (-not (Test-Path -LiteralPath $commit)) 'reader never reconstructs or automatically unlocks a maintenance commit'
 }finally{[IO.File]::WriteAllBytes($commit,$savedCommit)}
 $foreign=Join-Path $archiveDir 'foreign.json'
 try{
  [IO.File]::WriteAllText($foreign,'fixture retain unknown archive data')
  Reject {Get-AuthWireWriteHistoryReview $lcRoot $b $rsa} 'unknown archive metadata is not pruned or adopted'
  Check (Test-Path -LiteralPath $foreign) 'unknown archive metadata remains available for review'
 }finally{[IO.File]::Delete($foreign)}
 # A copied, relabelled old signed request cannot become an active new cycle.
 $active=Join-Path $lcLife '000065';$backup=@{}
 foreach($f in Get-ChildItem -LiteralPath $active -File){$backup[$f.Name]=[IO.File]::ReadAllBytes($f.FullName);[IO.File]::Delete($f.FullName)}
 try{
  foreach($f in Get-ChildItem -LiteralPath (Join-Path $cycles '000001') -File){[IO.File]::WriteAllBytes((Join-Path $active $f.Name),[IO.File]::ReadAllBytes($f.FullName))}
  foreach($name in @('poll-started.json','completion.json')){$file=Join-Path $active $name;$v=Read-AuthWireStagingJournal $file;$v.slot='000065';[IO.File]::WriteAllText($file,($v|ConvertTo-Json -Depth 12 -Compress))}
  Reject {Invoke-AuthWireStagingWriteLifecycleStep $lcRoot $b $release $rsa $url} 'duplicate request/job history is rejected across archived and active cycles'
 }finally{
  foreach($f in Get-ChildItem -LiteralPath $active -File){[IO.File]::Delete($f.FullName)}
  foreach($name in $backup.Keys){[IO.File]::WriteAllBytes((Join-Path $active $name),$backup[$name])}
 }
 $wrong=@{};foreach($n in $b.Keys){$wrong[$n]=$b[$n]};$wrong.generation++
 Reject {Get-AuthWireWriteHistoryReview $lcRoot $wrong $rsa} 'binding generation cannot adopt old archive history'
 try{
  foreach($n in 2..9){[AuthWire.Staging.TreeLeaseV1]::CreateNewDirectory((Join-Path $historyArea $n.ToString('D6')))}
  Reject {Invoke-AuthWireStagingWriteLifecycleStep $lcRoot $b $release $rsa $url} 'ninth physical archive entry fails closed at bounded storage quota'
  Check (@(Get-ChildItem -LiteralPath $historyArea -Directory).Count -eq 9) 'quota reader does not delete excess or incomplete entries'
 }finally{foreach($n in 2..9){[IO.Directory]::Delete((Join-Path $historyArea $n.ToString('D6')))}}
 Check ((Get-AuthWireSysvolInventory $gpo).Sha256 -ceq $historyBefore) 'history archival and every rejection leave SMB target content unchanged'
 if($case -cin @('lc_stage','lc_idle')){
  # Real fault at an owned copy boundary, before any cycle-original deletion.
  Add-HistoryFixtureIdle 66 128
  $review=Get-AuthWireWriteHistoryReview $lcRoot $b $rsa
  Check ($review.Review.can_archive -and $review.Review.first_slot -ceq '000065' -and $review.Review.last_slot -ceq '000128') 'second segment review continues the original sequence'
  $writer=${function:Write-AuthWireHistoryBytes};$script:historyFixtureCopies=0
  $foreignDuringRetire=Join-Path (Join-Path $lcLife '000065') 'foreign.txt'
  try{
   function Write-AuthWireHistoryBytes([string]$Path,[byte[]]$Bytes){
    $script:historyFixtureCopies++
    if($script:historyFixtureCopies -eq 4){if($case -ceq 'lc_idle'){throw 'FIXTURE_HISTORY_COPY_DISK_FAILURE'}else{[IO.File]::WriteAllText($foreignDuringRetire,'fixture foreign data must survive native retirement')}}
    & $writer $Path $Bytes
   }
   Reject {Invoke-AuthWireWriteHistoryArchive $lcRoot $b $rsa $review $historyAck} 'real copy failure or foreign child during native retirement cannot become success'
  }finally{${function:Write-AuthWireHistoryBytes}=$writer}
  Check ((Get-AuthWireLifecycleSlots $lcLife 64).Count -eq 64) 'copy interruption or foreign-child stop preserves all active directory boundaries'
  if($case -ceq 'lc_stage'){
   Check (Test-Path -LiteralPath $foreignDuringRetire) 'native retirement never removes an unreviewed foreign child'
   Check (Test-Path -LiteralPath (Join-Path (Join-Path (Join-Path (Join-Path $historyArea '000002') 'cycles') '000065') 'completion.json')) 'original bytes remain in verified archive after partial native retirement'
  }else{
   Check (Test-Path -LiteralPath (Join-Path (Join-Path $lcLife '000065') 'completion.json')) 'copy failure before retirement preserves original record files'
  }
  Reject {Invoke-AuthWireStagingWriteLifecycleStep $lcRoot $b $release $rsa $url} 'incomplete second archive prevents any new POLL or execution'
  Check (-not (Test-Path -LiteralPath (Join-Path (Join-Path $historyArea '000002') 'committed.json'))) 'interrupted maintenance stays unconfirmed for governed reconciliation'
 }
}
Write-Host ('WRITE_HISTORY_CASE_OK case='+$case+' archive_local_only=true actual_machine_reboot=false customer_changed=false')
