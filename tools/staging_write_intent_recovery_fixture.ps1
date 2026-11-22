# Runs only in the isolated native CNG/TLS/SQLite fixture before its new proof.
# Every mutation is a deliberate fixture fault, restored before the next check.
$job=Join-Path $journal $id
$intentRecord=Read-AuthWireStagingJournal (Join-Path $job 'filesystem-intent.json')
$engine=Join-Path $journal $intentRecord.filesystem_operation_id
$destination=Join-Path $gpo $preview.Preview.relative_destination.Replace('/','\')
Check (-not (Test-Path $engine) -and -not (Test-Path $destination)) 'no engine journal or destination exists after exited child'
[AuthWire.Staging.TreeLeaseV1]::CreateNewDirectory($engine)
try{Reject {Get-AuthWireConsumedStageRecoveryEvidence $journal $id $b $rsa $signer.Thumbprint $url} 'even empty engine journal prevents intent recovery'}finally{[IO.Directory]::Delete($engine)}
[AuthWire.Staging.TreeLeaseV1]::CreateNewDirectory($destination)
try{Reject {Get-AuthWireConsumedStageRecoveryEvidence $journal $id $b $rsa $signer.Thumbprint $url} 'any staged destination prevents intent recovery'}finally{[IO.Directory]::Delete($destination)}
$childPath=Join-Path $job 'stage-child.json';$enteredPath=Join-Path $job 'stage-entered.json'
$childBytes=[IO.File]::ReadAllBytes($childPath);$enteredBytes=[IO.File]::ReadAllBytes($enteredPath)
try{
 $child=Read-AuthWireStagingJournal $childPath;$entered=Read-AuthWireStagingJournal $enteredPath
 $process=[Diagnostics.Process]::GetCurrentProcess()
 try{$child.process_id=$PID;$child.process_started_ticks=$process.StartTime.ToUniversalTime().Ticks.ToString([Globalization.CultureInfo]::InvariantCulture)}finally{$process.Dispose()}
 $entered.child_identity_sha256=Get-AuthWireWriteHash $child
 [IO.File]::WriteAllText($childPath,(ConvertTo-AuthWireWriteJson $child),[Text.UTF8Encoding]::new($false))
 [IO.File]::WriteAllText($enteredPath,(ConvertTo-AuthWireWriteJson $entered),[Text.UTF8Encoding]::new($false))
 Reject {Get-AuthWireConsumedStageRecoveryEvidence $journal $id $b $rsa $signer.Thumbprint $url} 'a live original child identity prevents recovery'
}finally{[IO.File]::WriteAllBytes($childPath,$childBytes);[IO.File]::WriteAllBytes($enteredPath,$enteredBytes)}
$reviewPath=Join-Path $job 'execution-requires-review.json';$reviewBytes=[IO.File]::ReadAllBytes($reviewPath)
try{
 $review=Read-AuthWireStagingJournal $reviewPath;$review.diagnostic.timed_out=$true
 [IO.File]::WriteAllText($reviewPath,(ConvertTo-AuthWireWriteJson $review),[Text.UTF8Encoding]::new($false))
 Reject {Get-AuthWireConsumedStageRecoveryEvidence $journal $id $b $rsa $signer.Thumbprint $url} 'timed out or unobserved execution cannot use no-engine recovery'
}finally{[IO.File]::WriteAllBytes($reviewPath,$reviewBytes)}
$preflightPath=Join-Path $job 'stage-preflight.json';$missing=Join-Path $root 'held-preflight.json'
[IO.File]::Move($preflightPath,$missing)
try{Reject {Get-AuthWireConsumedStageRecoveryEvidence $journal $id $b $rsa $signer.Thumbprint $url} 'missing original child preflight prevents recovery'}finally{[IO.File]::Move($missing,$preflightPath)}
$foreign=Join-Path $gpo 'User\foreign-recovery-fixture.txt';[IO.File]::WriteAllText($foreign,'fixture drift')
try{Reject {Get-AuthWireConsumedStageRecoveryEvidence $journal $id $b $rsa $signer.Thumbprint $url} 'changed SYSVOL baseline prevents intent recovery'}finally{[IO.File]::Delete($foreign)}
