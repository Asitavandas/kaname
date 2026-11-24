# Dedicated empty-directory recovery tests. The exited real child's timeout
# diagnostic and partial engine/destination are synthesized only in this fixture.
$job=Join-Path $journal $id;$ir=Read-AuthWireStagingJournal (Join-Path $job 'filesystem-intent.json')
$engine=Join-Path $journal $ir.filesystem_operation_id;$dest=Join-Path $gpo $preview.Preview.relative_destination.Replace('/','\')
$reviewFile=Join-Path $job 'execution-requires-review.json';$review=Read-AuthWireStagingJournal $reviewFile
$review.diagnostic.timed_out=$true;$review.diagnostic.elapsed_ms=$review.diagnostic.work_budget_ms+1
[IO.File]::WriteAllText($reviewFile,(ConvertTo-AuthWireWriteJson $review),[Text.UTF8Encoding]::new($false))
[AuthWire.Staging.TreeLeaseV1]::CreateNewDirectory($engine)
$ei=[pscustomobject]@{format='AuthWireFilesystemIntentV1';operation_id=$ir.filesystem_operation_id;preview_sha256=$preview.PreviewSha256;target_sha256=$preview.Preview.scope_target_sha256;gpo_root=$gpo;relative_destination=$preview.Preview.relative_destination;baseline_sha256=$before.Sha256;protected_gpo_id=$live.protected_gpo_id}
Write-AuthWireStagingJournal (Join-Path $engine 'intent.json') $ei
[AuthWire.Staging.TreeLeaseV1]::CreateNewDirectory($dest)
$acl=Get-Acl $dest;$acl.SetOwner([Security.Principal.SecurityIdentifier]::new($b.service_sid));Set-Acl $dest $acl
function Get-AuthWireEmptyStageCleanupPreview($Target,$Binding,$Publisher,$BaseUrl,$Original){
 if($BaseUrl -cne $script:RecoveryExpectedEnrollmentBase){throw 'FIXTURE_ENROLLMENT_PORT_CHANGED'}
 return (New-AuthWireCombinedStagingPlanCore $Target $files (Get-AuthWireEmptyStageInventory $gpo $Original.Relative $Original.Baseline) $preview.Preview.scope_observations_sha256 ([DateTimeOffset]::UtcNow.ToUnixTimeSeconds()))
}
Reject {Get-AuthWireConsumedStageRecoveryEvidence $journal $id $b $rsa $signer.Thumbprint $url} 'old no-engine protocol still refuses the timed-out partial stage'
$foreign=Join-Path $dest 'foreign.txt';[IO.File]::WriteAllText($foreign,'preserve')
try{Reject {Get-AuthWireEmptyStageCleanupReview $journal $id $b $rsa $signer.Thumbprint $url} 'foreign file blocks empty cleanup';Check (Test-Path $foreign) 'foreign file retained'}finally{[IO.File]::Delete($foreign)}
$sub=Join-Path $dest 'foreign';[IO.Directory]::CreateDirectory($sub)|Out-Null
try{Reject {Get-AuthWireEmptyStageCleanupReview $journal $id $b $rsa $signer.Thumbprint $url} 'any subdirectory blocks empty cleanup'}finally{[IO.Directory]::Delete($sub)}
$outside=Join-Path $gpo 'User\outside.txt';[IO.File]::WriteAllText($outside,'preserve')
try{Reject {Get-AuthWireEmptyStageCleanupReview $journal $id $b $rsa $signer.Thumbprint $url} 'outside GPO drift blocks cleanup'}finally{[IO.File]::Delete($outside)}
$engineForeign=Join-Path $engine 'foreign.json';[IO.File]::WriteAllText($engineForeign,'{}')
try{Reject {Get-AuthWireEmptyStageCleanupReview $journal $id $b $rsa $signer.Thumbprint $url} 'extra engine record blocks cleanup'}finally{[IO.File]::Delete($engineForeign)}
$engineComplete=Join-Path $engine 'complete.json';[IO.File]::WriteAllText($engineComplete,'{}')
try{Reject {Get-AuthWireEmptyStageCleanupReview $journal $id $b $rsa $signer.Thumbprint $url} 'completed engine cannot use empty cleanup'}finally{[IO.File]::Delete($engineComplete)}
$pre=Join-Path $job 'stage-preflight.json';$held=Join-Path $root 'held-preflight.json';[IO.File]::Move($pre,$held)
try{Reject {Get-AuthWireEmptyStageCleanupReview $journal $id $b $rsa $signer.Thumbprint $url} 'missing original evidence blocks cleanup'}finally{[IO.File]::Move($held,$pre)}
$childFile=Join-Path $job 'stage-child.json';$enteredFile=Join-Path $job 'stage-entered.json'
$cb=[IO.File]::ReadAllBytes($childFile);$eb=[IO.File]::ReadAllBytes($enteredFile)
try{
 $child=Read-AuthWireStagingJournal $childFile;$entered=Read-AuthWireStagingJournal $enteredFile
 $child.process_id=$PID;$child.process_started_ticks=[Diagnostics.Process]::GetCurrentProcess().StartTime.ToUniversalTime().Ticks.ToString([Globalization.CultureInfo]::InvariantCulture)
 $entered.child_identity_sha256=Get-AuthWireWriteHash $child
 [IO.File]::WriteAllText($childFile,(ConvertTo-AuthWireWriteJson $child));[IO.File]::WriteAllText($enteredFile,(ConvertTo-AuthWireWriteJson $entered))
 Reject {Get-AuthWireEmptyStageCleanupReview $journal $id $b $rsa $signer.Thumbprint $url} 'live original child blocks cleanup'
}finally{[IO.File]::WriteAllBytes($childFile,$cb);[IO.File]::WriteAllBytes($enteredFile,$eb)}
$proof=Get-AuthWireEmptyStageCleanupReview $journal $id $b $rsa $signer.Thumbprint $url;$hash=Get-AuthWireWriteHash $proof
Check ($proof.Body.delete_only_empty_directory -and -not $proof.Body.release_gpo_lock) 'separate signed review never grants lock release'
$wrong=Clone $proof;$wrong.Body.destination_row_sha256='0'*64
Reject {Complete-AuthWireEmptyStageCleanup $journal $id $b $rsa $signer.Thumbprint $url $wrong (Get-AuthWireWriteHash $wrong) 'remove_exact_empty_owned_stage_directory'} 'tampered signed review rejected'
Reject {Complete-AuthWireEmptyStageCleanup $journal $id $b $rsa $signer.Thumbprint $url $proof ('0'*64) 'remove_exact_empty_owned_stage_directory'} 'different expected review rejected'
Reject {Complete-AuthWireEmptyStageCleanup $journal $id $b $rsa $signer.Thumbprint $url $proof $hash 'wrong'} 'explicit maintenance acknowledgement required'
$oldGrant=(Get-FileHash (Join-Path $job 'grant-consumed.json')).Hash;$oldResult=(Get-FileHash (Join-Path $job 'result-outbox.json')).Hash
$receipt=Complete-AuthWireEmptyStageCleanup $journal $id $b $rsa $signer.Thumbprint $url $proof $hash 'remove_exact_empty_owned_stage_directory'
Check (-not (Test-Path $dest) -and $receipt.Body.restored_inventory_sha256 -ceq $before.Sha256) 'exact empty directory removed and full original baseline restored'
Check ((Test-Path (Join-Path $engine 'intent.json')) -and (Test-Path (Join-Path $journal ('gpo-'+$t.gpo_id+'.json')))) 'engine intent and GPO lock retained for separate closure'
Check ((Get-FileHash (Join-Path $job 'grant-consumed.json')).Hash -ceq $oldGrant -and (Get-FileHash (Join-Path $job 'result-outbox.json')).Hash -ceq $oldResult) 'original grant/result byte hashes unchanged'
Reject {Complete-AuthWireEmptyStageCleanup $journal $id $b $rsa $signer.Thumbprint $url $proof $hash 'remove_exact_empty_owned_stage_directory'} 'cleanup intent prevents any second deletion'
$h=Read-AuthWireLifecycleHistory $journal $b $rsa;$state=$h.ActiveStates[-1]
$class=Get-AuthWireRecoveredEmptyStageReview $journal $state $b $rsa
Check ($class.Phase -ceq 'recovered_empty_stage_destination') 'signed receipt enables only distinct recovered classification'
$receiptFile=Join-Path $job 'empty-stage-cleanup-complete.json';$rb=[IO.File]::ReadAllBytes($receiptFile);$bad=Clone $receipt;$bad.Body.destination_row_sha256='0'*64
[IO.File]::WriteAllText($receiptFile,(ConvertTo-AuthWireWriteJson $bad))
try{Reject {Get-AuthWireRecoveredEmptyStageReview $journal $state $b $rsa} 'tampered cleanup receipt cannot enable closure'}finally{[IO.File]::WriteAllBytes($receiptFile,$rb)}
# Native race: only the held directory is considered for deletion; a child
# added after enumeration must survive and makes the directory delete fail.
$race=Join-Path $root 'native-empty-race';[IO.Directory]::CreateDirectory($race)|Out-Null
$lease=[AuthWire.Staging.TreeLeaseV1]::Tree($race,$true)
try{
 $f=Join-Path $race 'later-foreign.txt';[IO.File]::WriteAllText($f,'preserve')
 $at=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds();$ticks=[Diagnostics.Stopwatch]::GetTimestamp()
 Reject {$lease.DeleteOwnedTreeBefore($at+10,$at,$ticks)} 'foreign child arriving after lease prevents directory deletion'
 Check (Test-Path $f) 'foreign race file is never traversed or deleted'
}finally{$lease.Dispose();Remove-Item $race -Recurse -Force}
