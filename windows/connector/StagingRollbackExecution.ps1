# Source-only authenticated bounded rollback adapter. No active worker/peer route.
# Existing false-flag consumption intent is evidence, not standalone delete authority.
Set-StrictMode -Version 2

function New-AuthWireRollbackExecutionInputPins([string]$Root,[string]$JobId,[hashtable]$Binding,[string]$Release){
 Assert-AuthWireStagingWriteJournalLocation $Root $Binding;Assert-AuthWireCandidateGuid $JobId;Initialize-AuthWireStagingFilesystemTypes
 $p=[AuthWire.Staging.TreeLeaseV1]::new();$originPins=$null
 try{
  $p.PinAncestors($Root);$job=Join-Path $Root $JobId;$p.PinAncestors($job)
  foreach($n in @('rollback-offer.json','rollback-preflight.json','rollback-claim-started.json','rollback-claim-proof.json','rollback-claim-sent.json','rollback-authorization.json','rollback-grant-consumed.json','rollback-consumption-preflight.json','rollback-filesystem-intent.json')){$p.PinFile((Join-Path $job $n))}
  $sent=Read-AuthWireStagingJournal (Join-Path $job 'rollback-claim-sent.json')
  if(-not (Test-AuthWireWriteInteger $sent.sent_at)){throw 'ROLLBACK_EXECUTION_INPUT_REJECTED'}
  $saved=Read-AuthWireRollbackOfferAt $Root $JobId $Binding $Release $sent.sent_at
  $p.PinFile((Get-AuthWireRollbackReservationPath $Root $saved.Reservation.stage_job_id))
  $p.PinFile((Join-Path $Root ('gpo-'+$saved.Offer.target.scope_target.gpo_id+'.json')))
  $originPins=New-AuthWireRollbackOriginInputPins $Root $saved.Offer
  return [pscustomobject]@{Inputs=$p;Origin=$originPins}
 }catch{if($originPins){$originPins.Dispose()};$p.Dispose();throw}
}
function Close-AuthWireRollbackExecutionInputPins($Pins){if($Pins){$Pins.Origin.Dispose();$Pins.Inputs.Dispose()}}
function Read-AuthWireAuthorizedRollbackIntentEvidence([string]$Root,[string]$JobId,[hashtable]$Binding,[string]$Release,[Security.Cryptography.RSACng]$Key){
 $pins=New-AuthWireRollbackExecutionInputPins $Root $JobId $Binding $Release
 try{
  $a=Read-AuthWireRollbackAuthorizationEvidence $Root $JobId $Binding $Release $Key
  $job=Join-Path $Root $JobId;$c=Read-AuthWireStagingJournal (Join-Path $job 'rollback-grant-consumed.json')
  Assert-AuthWireCandidateFields $c @('format','binding_scope','release_id','job_id','stage_job_id','stage_operation_id','authorization_sha256','origin_chain_sha256','consumed_at','expires_at')
  Assert-AuthWireStageStrings $c @('format','binding_scope','release_id','job_id','stage_job_id','stage_operation_id','authorization_sha256','origin_chain_sha256')
  $now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds();$r=$a.Reservation
  if($c.format -cne 'AuthWireRollbackGrantConsumedV1' -or $c.binding_scope -cne $a.Receipt.binding_scope -or $c.release_id -cne $Release -or $c.job_id -cne $JobId -or
     $c.stage_job_id -cne $r.stage_job_id -or $c.stage_operation_id -cne $r.stage_operation_id -or $c.authorization_sha256 -cne $a.AuthorizationSha256 -or $c.origin_chain_sha256 -cne $r.origin_chain_sha256 -or
     -not (Test-AuthWireWriteInteger $c.consumed_at) -or $c.consumed_at -lt $a.Receipt.received_at -or $c.consumed_at -gt $now -or $c.consumed_at -ge $a.Receipt.grant.expires_at -or
     -not (Test-AuthWireWriteInteger $c.expires_at) -or $c.expires_at -ne $a.Receipt.grant.expires_at){throw 'ROLLBACK_CONSUMPTION_REJECTED'}
  $v=Read-AuthWireStagingJournal (Join-Path $job 'rollback-consumption-preflight.json')
  Assert-AuthWireRollbackPreflightAt $v $a $Binding $Release $v.checked_at
  if($v.checked_at -lt $c.consumed_at -or $v.checked_at -gt $now -or $v.checked_at -ge $c.expires_at -or $v.directory_sha256 -cne $a.Preflight.directory_sha256){throw 'ROLLBACK_CONSUMPTION_REJECTED'}
  $i=Read-AuthWireStagingJournal (Join-Path $job 'rollback-filesystem-intent.json')
  Assert-AuthWireCandidateFields $i @('format','job_id','binding_scope','release_id','stage_job_id','stage_operation_id','authorization_sha256','consumption_sha256','offer_sha256','target_sha256','origin_chain_sha256','live_preflight_sha256','expires_at','can_delete','can_apply_gpo')
  Assert-AuthWireStageStrings $i @('format','job_id','binding_scope','release_id','stage_job_id','stage_operation_id','authorization_sha256','consumption_sha256','offer_sha256','target_sha256','origin_chain_sha256','live_preflight_sha256')
  if($i.format -cne 'AuthWireRollbackFilesystemIntentV1' -or $i.job_id -cne $JobId -or $i.binding_scope -cne $c.binding_scope -or $i.release_id -cne $Release -or
     $i.stage_job_id -cne $c.stage_job_id -or $i.stage_operation_id -cne $c.stage_operation_id -or $i.authorization_sha256 -cne $a.AuthorizationSha256 -or $i.consumption_sha256 -cne (Get-AuthWireWriteHash $c) -or
     $i.offer_sha256 -cne $a.Receipt.offer_sha256 -or $i.target_sha256 -cne (Get-AuthWireWriteHash $a.Offer.target) -or $i.origin_chain_sha256 -cne $r.origin_chain_sha256 -or $i.live_preflight_sha256 -cne (Get-AuthWireWriteHash $v) -or
     -not (Test-AuthWireWriteInteger $i.expires_at) -or $i.expires_at -ne $c.expires_at -or $i.can_delete -isnot [bool] -or $i.can_delete -or $i.can_apply_gpo -isnot [bool] -or $i.can_apply_gpo){throw 'ROLLBACK_INTENT_REJECTED'}
  return [pscustomobject]@{Authorization=$a;Consumed=$c;Intent=$i;IntentSha256=(Get-AuthWireWriteHash $i);ConsumptionPreflight=$v}
 }finally{Close-AuthWireRollbackExecutionInputPins $pins}
}
function Read-AuthWireAuthorizedRollbackIntent([string]$Root,[string]$JobId,[hashtable]$Binding,[string]$Release,[Security.Cryptography.RSACng]$Key){
 $s=Read-AuthWireAuthorizedRollbackIntentEvidence $Root $JobId $Binding $Release $Key
 if([DateTimeOffset]::UtcNow.ToUnixTimeSeconds() -ge $s.Intent.expires_at){throw 'ROLLBACK_AUTHORIZATION_EXPIRED'}
 return $s
}
function Read-AuthWireRollbackLaunch([string]$Root,[string]$JobId,$State){
 $p=[AuthWire.Staging.TreeLeaseV1]::new()
 try{
  $file=Join-Path (Join-Path $Root $JobId) 'rollback-launch.json';$p.PinFile($file);$v=Read-AuthWireStagingJournal $file
  Assert-AuthWireCandidateFields $v @('format','job_id','stage_operation_id','execution_intent_sha256','authorization_sha256','gate_name','started_at','expires_at','work_budget_ms')
  Assert-AuthWireStageStrings $v @('format','job_id','stage_operation_id','execution_intent_sha256','authorization_sha256','gate_name')
  $now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
  if($v.format -cne 'AuthWireRollbackLaunchV1' -or $v.job_id -cne $JobId -or $v.stage_operation_id -cne $State.Intent.stage_operation_id -or $v.execution_intent_sha256 -cne $State.IntentSha256 -or
     $v.authorization_sha256 -cne $State.Authorization.AuthorizationSha256 -or $v.gate_name -cnotmatch ('\ALocal\\AuthWireRollback-'+([guid]$JobId).ToString('N')+'-[0-9a-f]{32}\z') -or
     -not (Test-AuthWireWriteInteger $v.started_at) -or $v.started_at -lt $State.Consumed.consumed_at -or $v.started_at -gt $now -or -not (Test-AuthWireWriteInteger $v.expires_at) -or $v.expires_at -ne $State.Intent.expires_at -or
     -not (Test-AuthWireWriteInteger $v.work_budget_ms) -or $v.work_budget_ms -lt 100 -or $v.work_budget_ms -gt 15000 -or $v.work_budget_ms -gt ($v.expires_at-$v.started_at-2)*1000){throw 'ROLLBACK_LAUNCH_REJECTED'}
  return $v
 }finally{$p.Dispose()}
}
function Read-AuthWireRollbackChildIdentity([string]$Root,[string]$JobId,$Launch){
 $p=[AuthWire.Staging.TreeLeaseV1]::new()
 try{
  $file=Join-Path (Join-Path $Root $JobId) 'rollback-child.json';$p.PinFile($file);$v=Read-AuthWireStagingJournal $file
  Assert-AuthWireCandidateFields $v @('format','job_id','launch_sha256','process_id','process_started_ticks')
  Assert-AuthWireStageStrings $v @('format','job_id','launch_sha256','process_started_ticks')
  if($v.format -cne 'AuthWireRollbackChildIdentityV1' -or $v.job_id -cne $JobId -or $v.launch_sha256 -cne (Get-AuthWireWriteHash $Launch) -or -not (Test-AuthWireWriteInteger $v.process_id) -or $v.process_started_ticks -cnotmatch '\A[1-9][0-9]{16,18}\z'){throw 'ROLLBACK_CHILD_IDENTITY_REJECTED'}
  return $v
 }finally{$p.Dispose()}
}
function Get-AuthWireRollbackCompletion([string]$Root,[string]$JobId,$State,$Launch,[hashtable]$Binding,[bool]$ObserveBaseline=$false){
 $p=[AuthWire.Staging.TreeLeaseV1]::new()
 try{
  $a=$State.Authorization;$engine=Join-Path $Root $State.Intent.stage_operation_id;$job=Join-Path $Root $JobId
  $p.PinAncestors($Root);$p.PinAncestors($engine);$p.PinAncestors($job)
  foreach($n in @('intent.json','complete.json','rollback-started.json','rolled-back.json')){$p.PinFile((Join-Path $engine $n))}
  $p.PinFile((Join-Path $job 'rollback-execution-preflight.json'))
  $start=Read-AuthWireStagingJournal (Join-Path $engine 'rollback-started.json');$done=Read-AuthWireStagingJournal (Join-Path $engine 'rolled-back.json')
  Assert-AuthWireCandidateFields $start @('format','operation_id','complete_sha256','started_at','expires_at')
  Assert-AuthWireStageStrings $start @('format','operation_id','complete_sha256')
  Assert-AuthWireCandidateFields $done @('format','operation_id','complete_sha256','baseline_restored')
  Assert-AuthWireStageStrings $done @('format','operation_id','complete_sha256')
  $complete=Read-AuthWireStagingJournal (Join-Path $engine 'complete.json');$oldIntent=Read-AuthWireStagingJournal (Join-Path $engine 'intent.json')
  if((Get-AuthWireWriteHash $oldIntent) -cne (Get-AuthWireWriteHash $a.Origin.Intent) -or (Get-AuthWireScopeDataHash $complete) -cne $a.Offer.target.stage_receipt.complete_journal_sha256 -or
     $start.format -cne 'AuthWireFilesystemRollbackIntentV2' -or $start.operation_id -cne $State.Intent.stage_operation_id -or $start.complete_sha256 -cne $a.Offer.target.stage_receipt.complete_journal_sha256 -or
     -not (Test-AuthWireWriteInteger $start.started_at) -or $start.started_at -lt $Launch.started_at -or $start.started_at -ge $State.Intent.expires_at -or -not (Test-AuthWireWriteInteger $start.expires_at) -or $start.expires_at -ne $State.Intent.expires_at -or
     $done.format -cne 'AuthWireFilesystemRollbackV1' -or $done.operation_id -cne $State.Intent.stage_operation_id -or $done.complete_sha256 -cne $start.complete_sha256 -or $done.baseline_restored -isnot [bool] -or -not $done.baseline_restored){throw 'ROLLBACK_COMPLETION_REJECTED'}
  $live=Read-AuthWireStagingJournal (Join-Path $job 'rollback-execution-preflight.json')
  Assert-AuthWireRollbackPreflightAt $live $a $Binding $a.Receipt.release_id $live.checked_at
  if($live.checked_at -lt $Launch.started_at -or $live.checked_at -gt $start.started_at -or $live.directory_sha256 -cne $State.ConsumptionPreflight.directory_sha256){throw 'ROLLBACK_COMPLETION_REJECTED'}
  if($ObserveBaseline){
   # Independent parent observation at the ORIGINAL verified PDC/path. No
   # deletion or directory data is inferred from a child stdout success flag.
   $gpo=Get-AuthWireWriteGpoPath $a.Origin.StageLive.pdc $a.Offer.target.scope_target
   if($gpo -cne $a.Origin.Intent.gpo_root -or (Get-AuthWireSysvolInventory $gpo).Sha256 -cne $a.Origin.Intent.baseline_sha256){throw 'ROLLBACK_PARENT_BASELINE_REJECTED'}
  }
  return [pscustomobject]@{RollbackJournalSha256=(Get-AuthWireWriteHash $done);RollbackStartSha256=(Get-AuthWireWriteHash $start);ExecutionPreflightSha256=(Get-AuthWireWriteHash $live);OriginalCompleteSha256=$start.complete_sha256;TreeSha256=$a.Offer.target.stage_receipt.staged_tree_sha256;BaselineSha256=$a.Origin.Intent.baseline_sha256}
 }finally{$p.Dispose()}
}
function Invoke-AuthWireAuthorizedRollbackChild([string]$Root,[string]$JobId,[string]$ExpectedIntentSha256,[hashtable]$Binding,[string]$Release,[Security.Cryptography.RSACng]$Key,[string]$Publisher,[string]$BaseUrl){
 $script:AuthWireRollbackChildPhase='intent';$pins=New-AuthWireRollbackExecutionInputPins $Root $JobId $Binding $Release
 try{
  $s=Read-AuthWireAuthorizedRollbackIntent $Root $JobId $Binding $Release $Key
  if(-not (Test-AuthWireWriteHash $ExpectedIntentSha256) -or $s.IntentSha256 -cne $ExpectedIntentSha256){throw 'ROLLBACK_INTENT_REJECTED'}
  $launch=Read-AuthWireRollbackLaunch $Root $JobId $s;$job=Join-Path $Root $JobId
  $script:AuthWireRollbackChildPhase='gate';$g=[Threading.EventWaitHandle]::OpenExisting($launch.gate_name,[Security.AccessControl.EventWaitHandleRights]::Synchronize)
  try{if(-not $g.WaitOne(2000)){throw 'ROLLBACK_GATE_UNAVAILABLE'}}finally{$g.Dispose()}
  $script:AuthWireRollbackChildPhase='identity';$identity=Read-AuthWireRollbackChildIdentity $Root $JobId $launch;$process=[Diagnostics.Process]::GetCurrentProcess()
  try{if($identity.process_id -ne $PID -or $identity.process_started_ticks -cne $process.StartTime.ToUniversalTime().Ticks.ToString([Globalization.CultureInfo]::InvariantCulture)){throw 'ROLLBACK_CHILD_IDENTITY_REJECTED'}}finally{$process.Dispose()}
  $start=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds();$clock=[Diagnostics.Stopwatch]::StartNew()
  Write-AuthWireStagingJournal (Join-Path $job 'rollback-entered.json') ([pscustomobject]@{format='AuthWireRollbackEnteredV1';job_id=$JobId;launch_sha256=(Get-AuthWireWriteHash $launch);child_identity_sha256=(Get-AuthWireWriteHash $identity);entered_at=$start})
  $script:AuthWireRollbackChildPhase='context'
  $live=Get-AuthWireRollbackPreflight $s.Authorization.Offer $Binding $Release $Key $Publisher $BaseUrl
  Assert-AuthWireRollbackPreflightAt $live $s.Authorization $Binding $Release ([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())
  if($live.checked_at -lt $start -or $live.directory_sha256 -cne $s.ConsumptionPreflight.directory_sha256){throw 'ROLLBACK_EXECUTION_SCOPE_CHANGED'}
  Write-AuthWireStagingJournal (Join-Path $job 'rollback-execution-preflight.json') $live
  Assert-AuthWireStagingWriteDeadline $s.Intent.expires_at $start $clock
  $script:AuthWireRollbackChildPhase='engine';$origin=$s.Authorization.Origin
  $r=Invoke-AuthWireStagingFilesystemRollback -GpoRoot $origin.Intent.gpo_root -JournalRoot $Root -OperationId $s.Intent.stage_operation_id -ApprovedCompleteSha256 $s.Authorization.Offer.target.stage_receipt.complete_journal_sha256 -NotAfter $s.Intent.expires_at
  $script:AuthWireRollbackChildPhase='postcheck'
  if($r.Phase -isnot [string] -or $r.Phase -cne 'rolled_back' -or $r.OperationId -isnot [string] -or $r.OperationId -cne $s.Intent.stage_operation_id -or $r.BaselineRestored -isnot [bool] -or -not $r.BaselineRestored -or $r.CanApplyGpo -isnot [bool] -or $r.CanApplyGpo){throw 'ROLLBACK_ENGINE_RESULT_REJECTED'}
  $complete=Get-AuthWireRollbackCompletion $Root $JobId $s $launch $Binding
  Assert-AuthWireStagingWriteDeadline $s.Intent.expires_at $start $clock
  $result=[pscustomobject]@{format='AuthWireAuthorizedRollbackResultV1';job_id=$JobId;stage_job_id=$s.Intent.stage_job_id;stage_operation_id=$s.Intent.stage_operation_id;execution_intent_sha256=$s.IntentSha256;authorization_sha256=$s.Authorization.AuthorizationSha256;launch_sha256=(Get-AuthWireWriteHash $launch);child_identity_sha256=(Get-AuthWireWriteHash $identity);execution_preflight_sha256=$complete.ExecutionPreflightSha256;rollback_start_sha256=$complete.RollbackStartSha256;rollback_journal_sha256=$complete.RollbackJournalSha256;original_complete_sha256=$complete.OriginalCompleteSha256;tree_sha256=$complete.TreeSha256;checked_at=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds();rolled_back=$true;can_apply_gpo=$false}
  $script:AuthWireRollbackChildPhase='result_flush';Write-AuthWireStagingJournal (Join-Path $job 'rollback-execution-complete.json') $result
  Assert-AuthWireStagingWriteDeadline $s.Intent.expires_at $start $clock
  return $result
 }finally{Close-AuthWireRollbackExecutionInputPins $pins}
}

function Assert-AuthWireRollbackChildResult($Value,$State,$Launch,$Identity,$Complete,[long]$ObservedAt){
 $v=$Value;$s=$State;$c=$Complete
 Assert-AuthWireCandidateFields $v @('format','job_id','stage_job_id','stage_operation_id','execution_intent_sha256','authorization_sha256','launch_sha256','child_identity_sha256','execution_preflight_sha256','rollback_start_sha256','rollback_journal_sha256','original_complete_sha256','tree_sha256','checked_at','rolled_back','can_apply_gpo')
 Assert-AuthWireStageStrings $v @('format','job_id','stage_job_id','stage_operation_id','execution_intent_sha256','authorization_sha256','launch_sha256','child_identity_sha256','execution_preflight_sha256','rollback_start_sha256','rollback_journal_sha256','original_complete_sha256','tree_sha256')
 if($v.format -cne 'AuthWireAuthorizedRollbackResultV1' -or $v.job_id -cne $s.Intent.job_id -or $v.stage_job_id -cne $s.Intent.stage_job_id -or $v.stage_operation_id -cne $s.Intent.stage_operation_id -or
    $v.execution_intent_sha256 -cne $s.IntentSha256 -or $v.authorization_sha256 -cne $s.Authorization.AuthorizationSha256 -or $v.launch_sha256 -cne (Get-AuthWireWriteHash $Launch) -or
    $v.child_identity_sha256 -cne (Get-AuthWireWriteHash $Identity) -or $v.execution_preflight_sha256 -cne $c.ExecutionPreflightSha256 -or $v.rollback_start_sha256 -cne $c.RollbackStartSha256 -or
    $v.rollback_journal_sha256 -cne $c.RollbackJournalSha256 -or $v.original_complete_sha256 -cne $c.OriginalCompleteSha256 -or $v.tree_sha256 -cne $c.TreeSha256 -or
    -not (Test-AuthWireWriteInteger $v.checked_at) -or $v.checked_at -lt $Launch.started_at -or $v.checked_at -gt $ObservedAt -or $v.checked_at -ge $s.Intent.expires_at -or
    $v.rolled_back -isnot [bool] -or -not $v.rolled_back -or $v.can_apply_gpo -isnot [bool] -or $v.can_apply_gpo){throw 'ROLLBACK_CHILD_RESULT_REJECTED'}
}
function Invoke-AuthWireAuthorizedFilesystemRollback([string]$Root,[string]$JobId,[hashtable]$Binding,[string]$Release,[Security.Cryptography.RSACng]$Key){
 Assert-AuthWireStagingWriteJournalLocation $Root $Binding;Assert-AuthWireCandidateGuid $JobId
 $decision=Enter-AuthWireWriteOutcomeLock $JobId;$pins=$null;$gate=$null
 try{
  $job=Join-Path $Root $JobId
  if(Test-Path -LiteralPath (Join-Path $job 'rollback-result-outbox.json')){throw 'ROLLBACK_RESULT_ALREADY_FROZEN'}
  if(Test-Path -LiteralPath (Join-Path $job 'rollback-launch.json')){throw 'ROLLBACK_ALREADY_LAUNCHED_REQUIRES_REVIEW'}
  $pins=New-AuthWireRollbackExecutionInputPins $Root $JobId $Binding $Release
  $s=Read-AuthWireAuthorizedRollbackIntent $Root $JobId $Binding $Release $Key
  $now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds();$clock=[Diagnostics.Stopwatch]::StartNew();$budget=[int][Math]::Min(15000,($s.Intent.expires_at-$now-2)*1000)
  if($budget -lt 100){throw 'ROLLBACK_AUTHORIZATION_EXPIRED'}
  $name='Local\AuthWireRollback-'+([guid]$JobId).ToString('N')+'-'+[guid]::NewGuid().ToString('N');$acl=[Security.AccessControl.EventWaitHandleSecurity]::new()
  foreach($sid in @($Binding.service_sid,'S-1-5-18','S-1-5-32-544')){$acl.AddAccessRule([Security.AccessControl.EventWaitHandleAccessRule]::new([Security.Principal.SecurityIdentifier]::new($sid),[Security.AccessControl.EventWaitHandleRights]::FullControl,[Security.AccessControl.AccessControlType]::Allow))}
  $created=$false;$gate=[Threading.EventWaitHandle]::new($false,[Threading.EventResetMode]::AutoReset,$name,[ref]$created,$acl)
  if(-not $created){throw 'ROLLBACK_GATE_ALREADY_EXISTS'}
  $launch=[pscustomobject]@{format='AuthWireRollbackLaunchV1';job_id=$JobId;stage_operation_id=$s.Intent.stage_operation_id;execution_intent_sha256=$s.IntentSha256;authorization_sha256=$s.Authorization.AuthorizationSha256;gate_name=$name;started_at=$now;expires_at=$s.Intent.expires_at;work_budget_ms=$budget}
  Write-AuthWireStagingJournal (Join-Path $job 'rollback-launch.json') $launch
  $phase='process_start';$r=$null
  try{
   Initialize-AuthWireStageProcess
   $exe=Join-Path ([Environment]::GetFolderPath('Windows')) 'System32\WindowsPowerShell\v1.0\powershell.exe';$file=Join-Path $PSScriptRoot 'Invoke-AuthWireRollbackChild.ps1'
   if($Root.Length -gt 1800 -or $Root.Contains('"')){throw 'WRITE_JOURNAL_PATH_REJECTED'}
   $arguments='-NoLogo -NoProfile -NonInteractive -ExecutionPolicy AllSigned -File "'+$file+'" -JournalRoot "'+$Root.TrimEnd('\')+'" -JobId '+$JobId+' -IntentSha256 '+$s.IntentSha256
   $remaining=$budget-[int]$clock.ElapsedMilliseconds
   Assert-AuthWireStagingWriteDeadline $s.Intent.expires_at $now $clock
   if($remaining -lt 100){throw 'ROLLBACK_AUTHORIZATION_EXPIRED'}
   $beforeRelease=[Action[int,long]]{param($childPid,$ticks)
    Write-AuthWireStagingJournal (Join-Path $job 'rollback-child.json') ([pscustomobject]@{format='AuthWireRollbackChildIdentityV1';job_id=$JobId;launch_sha256=(Get-AuthWireWriteHash $launch);process_id=$childPid;process_started_ticks=$ticks.ToString([Globalization.CultureInfo]::InvariantCulture)})
   }
   $r=[AuthWire.Connector.StageProcessV1]::Run($exe,$arguments,$remaining,$gate,$beforeRelease)
   $phase='child_exit';if($r.TimedOut -or $r.Truncated -or $r.ExitCode -ne 0){throw 'ROLLBACK_CHILD_REQUIRES_REVIEW'}
   $phase='result';$v=ConvertFrom-AuthWireCandidateJson ([Text.UTF8Encoding]::new($false,$true).GetBytes($r.Output))
   $phase='child_identity';$identity=Read-AuthWireRollbackChildIdentity $Root $JobId $launch
   if($identity.process_id -ne $r.ProcessId -or $identity.process_started_ticks -cne $r.ProcessStartedTicks.ToString([Globalization.CultureInfo]::InvariantCulture)){throw 'ROLLBACK_CHILD_IDENTITY_REJECTED'}
   $phase='completion';$complete=Get-AuthWireRollbackCompletion $Root $JobId $s $launch $Binding $true
   Assert-AuthWireRollbackChildResult $v $s $launch $identity $complete ([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())
   $resultFile=Join-Path $job 'rollback-execution-complete.json';$p=[AuthWire.Staging.TreeLeaseV1]::new()
   try{
    $p.PinFile($resultFile)
    if((Get-AuthWireWriteHash (Read-AuthWireStagingJournal $resultFile)) -cne (Get-AuthWireWriteHash $v)){throw 'ROLLBACK_CHILD_RESULT_REJECTED'}
    $phase='observation';Write-AuthWireStagingJournal (Join-Path $job 'rollback-execution-observed.json') ([pscustomobject]@{format='AuthWireRollbackObservedV1';job_id=$JobId;result_sha256=(Get-AuthWireWriteHash $v);rollback_journal_sha256=$complete.RollbackJournalSha256;baseline_sha256=$complete.BaselineSha256;observed_at=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()})
   }finally{$p.Dispose()}
   return [pscustomobject]@{JobId=$JobId;Phase='rolled_back';RollbackJournalSha256=$complete.RollbackJournalSha256;TreeSha256=$complete.TreeSha256;BaselineRestored=$true;RollbackExecuted=$true;PeerResultSubmitted=$false;CanApplyGpo=$false;ArtifactExecuted=$false}
  }catch{
   $diagnostic=[pscustomobject]@{format='AuthWireRollbackDiagnosticV1';parent_phase=$phase;child_phase='unknown';timed_out=$false;truncated=$false;exit_code=$null;elapsed_ms=$clock.ElapsedMilliseconds;work_budget_ms=$budget}
   if($r){
    $diagnostic.timed_out=[bool]$r.TimedOut;$diagnostic.truncated=[bool]$r.Truncated;$diagnostic.exit_code=[int]$r.ExitCode
    if(-not $r.Truncated -and $r.Output -is [string] -and $r.Output.Length -le 512){try{
     $failure=ConvertFrom-AuthWireCandidateJson ([Text.UTF8Encoding]::new($false,$true).GetBytes($r.Output));Assert-AuthWireCandidateFields $failure @('error','phase','exception_kind')
     if($failure.error -ceq 'ROLLBACK_EXECUTION_REQUIRES_REVIEW' -and $failure.phase -is [string] -and $failure.phase -cin @('load','config','key','intent','modules','gate','identity','context','engine','postcheck','result_flush')){$diagnostic.child_phase=$failure.phase}
    }catch{}}
   }
   try{Write-AuthWireStagingJournal (Join-Path $job 'rollback-execution-requires-review.json') ([pscustomobject]@{format='AuthWireRollbackReviewV1';job_id=$JobId;execution_intent_sha256=$s.IntentSha256;reason='OUTCOME_REQUIRES_REVIEW';checked_at=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds();diagnostic=$diagnostic})}catch{}
   throw 'ROLLBACK_EXECUTION_REQUIRES_REVIEW'
  }
 }finally{if($gate){$gate.Dispose()};Close-AuthWireRollbackExecutionInputPins $pins;$decision.ReleaseMutex();$decision.Dispose()}
}
