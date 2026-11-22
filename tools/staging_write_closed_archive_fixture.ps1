# Hosted fixture: one real closed stage plus 62 independently signed synthetic
# no-job metadata records. The latter are not server requests or field evidence.
$life=Get-AuthWireWriteLifecyclePath $journal $b
foreach($n in 3..64){
 $slot=$n.ToString('D6');$dir=Join-Path $life $slot
 [AuthWire.Staging.TreeLeaseV1]::CreateNewDirectory($dir)
 $at=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
 $poll=New-AuthWireStagingWriteProof $b $rsa POLL @{capability='combined.filesystem.write.v1';release_id=$release}
 $sentAt=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
 $requestId=[Text.Encoding]::ASCII.GetString([Convert]::FromBase64String($poll.frame)).Split([char]10)[10]
 $sent=[pscustomobject]@{format='AuthWireLifecyclePollSentV1';request_id=$requestId;proof_sha256=(Get-AuthWireWriteHash $poll);sent_at=$sentAt}
 Write-AuthWireStagingJournal (Join-Path $dir 'poll-started.json') ([pscustomobject]@{format='AuthWireLifecyclePollStartedV1';binding_scope=(Get-AuthWireJobScope $b);release_id=$release;slot=$slot;started_at=$at})
 Write-AuthWireStagingJournal (Join-Path $dir 'poll-proof.json') ([pscustomobject]@{format='AuthWireLifecyclePollProofV1';proof=$poll})
 Write-AuthWireStagingJournal (Join-Path $dir 'poll-sent.json') $sent
 $reply=[pscustomobject]@{format=1;request_id=$requestId;scope_sha256=(Get-AuthWireJobScope $b);job_id='';operation='';lease_id='';intent_sha256='';expires_at=0;target=$null;write_authorized=$false;can_apply_gpo=$false}
 Write-AuthWireStagingJournal (Join-Path $dir 'poll-response.json') ([pscustomobject]@{format='AuthWireLifecyclePollResponseV1';poll_sha256=(Get-AuthWireWriteHash $sent);received_at=$sentAt;reply=$reply})
 $state=Read-AuthWireLifecyclePoll $life $slot $b $rsa
 $null=Complete-AuthWireLifecycleCycle $journal $life $state $b $rsa
}
[IO.File]::Move($closedPath,$partialPath)
try{Reject {Get-AuthWireWriteHistoryReview $journal $b $rsa} 'unclosed uncertain stage cannot be hidden inside a full archive'}
finally{[IO.File]::Move($partialPath,$closedPath)}
$review=Get-AuthWireWriteHistoryReview $journal $b $rsa
Check ($review.Review.can_archive -and $review.Review.cycle_count -eq 64) 'valid signed closure permits governed archiving of the complete history'
$archived=Invoke-AuthWireWriteHistoryArchive $journal $b $rsa $review 'archive_observed_history_preserve_all_evidence'
Check ($archived.Phase -ceq 'history_archived' -and $archived.ArchivedThrough -eq 64 -and $archived.ProtectedRecordsPreserved) 'closed uncertain result is archived without deleting protected job records'
$history=Read-AuthWireLifecycleHistory $journal $b $rsa
Check ($history.ArchiveCount -eq 1 -and $history.ArchivedThrough -eq 64 -and $history.ActiveStates.Count -eq 0 -and $history.States.Count -eq 64) 'archive signature and all 64 retained cycles validate on reload'
$cycles=Join-Path $life 'history-archives\000001\cycles'
Check (Test-AuthWireConsumedStageClosed $journal $cycles $history.States[0] $b $rsa) 'closed stage remains independently verifiable from its archived cycle'
$tampered=Clone $closed;$tampered.Body.lock_sha256='0'*64
[IO.File]::WriteAllText($closedPath,(ConvertTo-AuthWireWriteJson $tampered),[Text.UTF8Encoding]::new($false))
try{Reject {Read-AuthWireLifecycleHistory $journal $b $rsa} 'an archived closure with a broken signature still blocks continuation'}
finally{[IO.File]::WriteAllBytes($closedPath,$savedClosed)}
$continued=Invoke-AuthWireStagingWriteLifecycleStep $journal $b $release $rsa $url
Check ($continued.Phase -ceq 'no_job' -and (Test-Path -LiteralPath (Join-Path $life '000065\completion.json'))) 'post-archive continuation opens slot65 with a fresh real HTTPS poll'
Check ((Get-FileHash -LiteralPath (Join-Path $job 'grant-consumed.json')).Hash -ceq $grantHash -and (Get-FileHash -LiteralPath (Join-Path $job 'result-outbox.json')).Hash -ceq $resultHash) 'archive preserves the original consumed grant and uncertain result bytes'

