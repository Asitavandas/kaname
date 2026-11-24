# Test only: a real separate rollback grant was just produced. The production
# parent performs one-use consumption and execution with continuous input pins.
$rxReceipt=Read-AuthWireStagingJournal (Join-Path $rbJob 'rollback-authorization.json')
$fixture.rollback_expires_at=$rxReceipt.grant.expires_at
[IO.File]::WriteAllText((Join-Path $package 'fixture.json'),($fixture|ConvertTo-Json -Depth 12 -Compress))
# Count only this parent's full authority traversals. The independently signed
# child loads its own original module, so this cannot stub its validation.
$rxOriginalAuthorityReader=${function:Read-AuthWireRollbackAuthorizationEvidence}
$rxOriginalProcessInit=${function:Initialize-AuthWireStageProcess}
$script:RollbackParentAuthorityReads=0;$script:RollbackHandoffPinsHeld=$false
function Read-AuthWireRollbackAuthorizationEvidence([string]$Root,[string]$JobId,[hashtable]$Binding,[string]$Release,[Security.Cryptography.RSACng]$Key){
 $script:RollbackParentAuthorityReads++
 if($script:RollbackParentAuthorityReads -gt 1){throw 'FIXTURE_DUPLICATE_PARENT_AUTHORITY_TRAVERSAL'}
 return (& $rxOriginalAuthorityReader @PSBoundParameters)
}
function Initialize-AuthWireStageProcess {
 $stream=$null
 try{$stream=[IO.File]::Open((Join-Path $rbJob 'rollback-grant-consumed.json'),[IO.FileMode]::Open,[IO.FileAccess]::Write,[IO.FileShare]::ReadWrite)}
 catch [IO.IOException]{$script:RollbackHandoffPinsHeld=$true}
 finally{if($stream){$stream.Dispose()}}
 if(-not $script:RollbackHandoffPinsHeld){throw 'FIXTURE_HANDOFF_INPUTS_NOT_PINNED'}
 # This case changes AD only AFTER consumption has obtained its fresh witness.
 # Otherwise it tests consumption rejection, never the independent child check.
 if($case -ceq 'rb_execute_drift'){
  $fixture.rollback_drift=$true
  [IO.File]::WriteAllText((Join-Path $package 'fixture.json'),($fixture|ConvertTo-Json -Depth 12 -Compress))
 }
 & $rxOriginalProcessInit
}
$rxWatch=[Diagnostics.Stopwatch]::StartNew();$rxError='';$rxResult=$null
try{$rxResult=Invoke-AuthWireAuthorizedFilesystemRollback $rbRoot $rbId $b $release $rsa -ConsumeFirst}catch{$rxError=$_.Exception.Message}
finally{
 Set-Item function:Read-AuthWireRollbackAuthorizationEvidence -Value $rxOriginalAuthorityReader
 Set-Item function:Initialize-AuthWireStageProcess -Value $rxOriginalProcessInit
};$rxWatch.Stop()
Check ($script:RollbackParentAuthorityReads -eq 1) 'real parent validates original authority once while retaining its original native inputs'
Check $script:RollbackHandoffPinsHeld 'consumption inputs remain write-locked across immediate execution handoff'
$rxReleased=[IO.File]::Open((Join-Path $rbJob 'rollback-grant-consumed.json'),[IO.FileMode]::Open,[IO.FileAccess]::Write,[IO.FileShare]::ReadWrite)
$rxReleased.Dispose()
Check $true 'native handoff pins are released after both success and execution failure without changing bytes'
$rxSuccess=$case -cin @('rb_execute_success','rb_execute_lost_ack')
$rxObserved=Join-Path $rbJob 'rollback-execution-observed.json'
if($rxSuccess){
 if($rxError){Write-Host ('ROLLBACK_EXECUTION_ENTRY_FAILURE '+$rxError)}
 if($rxError -and (Test-Path -LiteralPath (Join-Path $rbJob 'rollback-execution-requires-review.json'))){$rxReview=Read-AuthWireStagingJournal (Join-Path $rbJob 'rollback-execution-requires-review.json');Write-Host ('ROLLBACK_EXECUTION_DIAGNOSTIC '+($rxReview.diagnostic|ConvertTo-Json -Compress))}
 Check ($rxError -ceq '' -and $rxResult.RollbackExecuted -and $rxResult.BaselineRestored -and -not $rxResult.CanApplyGpo -and -not $rxResult.ArtifactExecuted) 'separate authenticated child and parent verify actual owned-directory deletion'
 Check (Test-Path -LiteralPath $rxObserved) 'parent recorded independent baseline observation'
 Check ((Get-AuthWireSysvolInventory $gpo).Sha256 -ceq $before.Sha256) 'real rollback restores exact original full GPO baseline'
 $rxEngineStart=Read-AuthWireStagingJournal (Join-Path $rbEngine 'rollback-started.json')
 Check ($rxEngineStart.expires_at -eq $rxReceipt.grant.expires_at) 'native engine receives unchanged original grant deadline'
}else{
 Check ($rxError -cne '' -and -not (Test-Path -LiteralPath $rxObserved)) 'uncertain child or parent result never reported as observed success'
 if($case -cne 'rb_execute_launch_disk'){
  $rxReview=Read-AuthWireStagingJournal (Join-Path $rbJob 'rollback-execution-requires-review.json')
  Check ($rxReview.format -ceq 'AuthWireRollbackReviewV1' -and ($rxReview.diagnostic|ConvertTo-Json -Compress).Length -lt 512) 'bounded safe review diagnostic retained'
  if($case -ceq 'rb_execute_timeout'){Check ($rxReview.diagnostic.timed_out -and $rxWatch.Elapsed.TotalSeconds -lt 23) 'kill-on-close child writer obeys original bounded process budget'}
  if($case -ceq 'rb_execute_drift'){Check ($rxReview.diagnostic.child_phase -ceq 'context') 'fresh PDC drift refused before rollback engine'}
  if($case -ceq 'rb_execute_parent_drift'){Check ($rxReview.diagnostic.parent_phase -ceq 'completion') 'parent independently refuses foreign post-child baseline change'}
 }
 if($case -cin @('rb_execute_drift','rb_execute_launch_disk','rb_execute_identity','rb_execute_timeout')){
  Check ((Get-AuthWireSysvolInventory $gpo).Sha256 -ceq $rbBefore) 'predelete failure leaves original staged SMB bytes and ACL intact'
  Check (-not (Test-Path -LiteralPath (Join-Path $rbEngine 'rollback-started.json'))) 'predelete failure cannot enter native engine'
 }
 if($case -ceq 'rb_execute_completion_disk'){
  Check ((Test-Path -LiteralPath (Join-Path $rbEngine 'rollback-started.json')) -and -not (Test-Path -LiteralPath (Join-Path $rbEngine 'rolled-back.json'))) 'missing native completion remains uncertain with start marker retained'
  Check ((Get-AuthWireSysvolInventory $gpo).Sha256 -ceq $before.Sha256) 'even actual deletion without completion is not promoted to success'
 }
 if($case -ceq 'rb_execute_parent_drift'){Check (Test-Path -LiteralPath (Join-Path $gpo 'User\foreign-after-child.txt')) 'foreign post-child data is preserved for review'}
}
Check (Test-Path -LiteralPath (Join-Path $rbJob 'rollback-launch.json')) 'one-launch gate retained after every rollback outcome'
$rxHash=(Get-AuthWireSysvolInventory $gpo).Sha256;$rxReadPath=Join-Path $package ('rollback-reads-'+$rbId+'.txt');$rxReads=[IO.File]::ReadAllText($rxReadPath)
Reject {Invoke-AuthWireAuthorizedFilesystemRollback $rbRoot $rbId $b $release $rsa} 'parent replay refused before history or fresh observation'
Reject {Invoke-AuthWireAuthorizedFilesystemRollback $rbRoot $rbId $b $release $rsa -ConsumeFirst} 'combined consumption/execution replay refused before any fresh observation'
$rxIntentHash=Get-AuthWireWriteHash (Read-AuthWireStagingJournal (Join-Path $rbJob 'rollback-filesystem-intent.json'))
$rxExe=Join-Path ([Environment]::GetFolderPath('Windows')) 'System32\WindowsPowerShell\v1.0\powershell.exe'
$rxArgs='-NoLogo -NoProfile -NonInteractive -ExecutionPolicy AllSigned -File "'+(Join-Path $package 'Invoke-AuthWireRollbackChild.ps1')+'" -JournalRoot "'+$rbRoot+'" -JobId '+$rbId+' -IntentSha256 '+$rxIntentHash
$rxReplayWatch=[Diagnostics.Stopwatch]::StartNew()
$rxReplay=[AuthWire.Connector.ScopeProcessV1]::Run($rxExe,$rxArgs,8000);$rxReplayWatch.Stop()
if($rxReplay.TimedOut -or $rxReplay.ExitCode -ne 20){
 # Fixed fixture case and bounded numeric/boolean metadata only. Never print
 # child stdout/stderr, paths, proof material or credentials.
 Write-Host ('ROLLBACK_REPLAY_SAFE_DIAGNOSTIC '+(@{case=$case;timed_out=[bool]$rxReplay.TimedOut;exit_code=[int]$rxReplay.ExitCode;elapsed_ms=$rxReplayWatch.ElapsedMilliseconds;expected_exit_code=20}|ConvertTo-Json -Compress))
}
Check (-not $rxReplay.TimedOut -and $rxReplay.ExitCode -eq 20) 'new direct signed child cannot reuse closed original gate or expired grant'
$rxReplayBody=ConvertFrom-AuthWireCandidateJson ([Text.UTF8Encoding]::new($false,$true).GetBytes($rxReplay.Output))
Assert-AuthWireCandidateFields $rxReplayBody @('error','phase','exception_kind')
Check ($rxReplayBody.error -ceq 'ROLLBACK_EXECUTION_REQUIRES_REVIEW' -and $rxReplayBody.phase -ceq 'identity') 'new process replay is rejected at the entry identity filter before key or AD modules'
Check ([IO.File]::ReadAllText($rxReadPath) -ceq $rxReads -and (Get-AuthWireSysvolInventory $gpo).Sha256 -ceq $rxHash) 'replay creates no AD observation or SMB effect'
$rxBox=New-AuthWireRollbackResultOutbox $rbRoot $rbId $b $release $rsa
if($rxSuccess){Check ($rxBox.body.outcome -ceq 'rolled_back' -and $rxBox.body.journal_sha256 -ceq $rxResult.RollbackJournalSha256 -and $rxBox.body.tree_sha256 -ceq $rbOffer.target.stage_receipt.staged_tree_sha256) 'success RESULT binds actual rollback journal and ORIGINAL removed tree'}
else{Check ($rxBox.body.outcome -ceq 'requires_review' -and $rxBox.body.filesystem_effects -ceq 'unconfirmed' -and $rxBox.body.journal_sha256 -ceq '') 'partial unobserved or parent-rejected deletion freezes only review evidence'}
$rxBodyHash=$rxBox.body_sha256;$rxSendError='';$rxSent=$null
$rxBoxPath=Join-Path $rbJob 'rollback-result-outbox.json';$rxBoxBytes=[IO.File]::ReadAllBytes($rxBoxPath)
if($case -cin @('rb_execute_success','rb_execute_bad_result')){
 try{
  $rxForged=Clone $rxBox;$rxForged.body.outcome='rolled_back';$rxForged.body.reason='OK';$rxForged.body.filesystem_effects='removed_owned_directory'
  $rxForged.body.checked_at=$rxReceipt.received_at;$rxForged.body.journal_sha256='0'*64;$rxForged.body.tree_sha256=$rbOffer.target.stage_receipt.staged_tree_sha256
  $rxForged.body_sha256=Get-AuthWireWriteHash $rxForged.body
  [IO.File]::WriteAllText($rxBoxPath,($rxForged|ConvertTo-Json -Depth 12 -Compress))
  Reject {Read-AuthWireRollbackResultOutbox $rbRoot $rbId $b $release $rsa} 'rehashing a changed or promoted outbox cannot replace exact parent observation'
 }finally{[IO.File]::WriteAllBytes($rxBoxPath,$rxBoxBytes)}
}
try{$rxSent=Send-AuthWireRollbackResult $rbRoot $rbId $b $release $rsa $url}catch{$rxSendError=$_.Exception.Message}
if($case -ceq 'rb_execute_lost_ack'){
 Check ($rxSendError -cne '' -and -not (Test-Path -LiteralPath (Join-Path $rbJob 'rollback-result-accepted.json'))) 'lost accepted RESULT reply preserves pending immutable outbox'
}else{Check ($rxSendError -ceq '' -and $rxSent.ResultRecorded) 'real core accepts exact rollback success or review RESULT'}
. (Join-Path $package 'StagingRollbackResult.ps1')
Check ((Send-AuthWireRollbackResult $rbRoot $rbId $b $release $rsa $url).ResultRecorded) 'result-only recovery after reload reaches same core acknowledgment'
Check ((Read-AuthWireRollbackResultOutbox $rbRoot $rbId $b $release $rsa).body_sha256 -ceq $rxBodyHash) 'result recovery never changes outcome or completion time'
Check ([IO.File]::ReadAllText($rxReadPath) -ceq $rxReads -and (Get-AuthWireSysvolInventory $gpo).Sha256 -ceq $rxHash) 'result recovery performs no current AD check or deletion'
Reject {Read-AuthWireWriteResultOutbox $rbRoot $rbId $b $release $rsa} 'rollback outbox cannot be reinterpreted as stage result'
Write-Host ('ROLLBACK_EXECUTION_CASE_OK case='+$case+' child_parent_ms='+$rxWatch.ElapsedMilliseconds+' success='+$rxSuccess+' result_recovered=true customer_changed=false')


