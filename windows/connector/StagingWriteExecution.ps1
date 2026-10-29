# Source-only bounded stage adapter. Not in the live package/runtime or peer API.
# Internal trusted caller only. A saved hash/operation ID is not authorization.
Set-StrictMode -Version 2

function Assert-AuthWireStageStrings($Value,[string[]]$Names){
 foreach($n in $Names){if($Value.$n -isnot [string]){throw 'WRITE_EXECUTION_RECORD_REJECTED'}}
}
function New-AuthWireStageInputPins([string]$JournalRoot,[string]$JobId,$Offer){
 $p=[AuthWire.Staging.TreeLeaseV1]::new()
 try{
  $p.PinAncestors($JournalRoot);$job=Join-Path $JournalRoot $JobId;$p.PinAncestors($job)
  foreach($n in @('offer.json','preflight.json','claim-started.json','claim-proof.json','claim-sent.json','authorization.json','grant-consumed.json','filesystem-intent.json')){$p.PinFile((Join-Path $job $n))}
  $p.PinFile((Join-Path $JournalRoot ('gpo-'+$Offer.target.scope_target.gpo_id+'.json')))
  return $p
 }catch{$p.Dispose();throw}
}
function Read-AuthWireAuthorizedStageIntent([string]$JournalRoot,[string]$JobId,[hashtable]$Binding,[string]$Release,[Security.Cryptography.RSACng]$Key){
 $a=Read-AuthWireWriteAuthorization $JournalRoot $JobId $Binding $Release $Key
 $p=New-AuthWireStageInputPins $JournalRoot $JobId $a.Offer
 try{
  $again=Read-AuthWireWriteAuthorization $JournalRoot $JobId $Binding $Release $Key
  if($again.AuthorizationSha256 -cne $a.AuthorizationSha256){throw 'WRITE_LOCAL_RECORD_CHANGED'}
  $job=Join-Path $JournalRoot $JobId
  $c=Read-AuthWireStagingJournal (Join-Path $job 'grant-consumed.json')
  Assert-AuthWireCandidateFields $c @('format','binding_scope','release_id','job_id','authorization_sha256','filesystem_operation_id','consumed_at','expires_at')
  Assert-AuthWireStageStrings $c @('format','binding_scope','release_id','job_id','authorization_sha256','filesystem_operation_id')
  $now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds();$op=Get-AuthWireFilesystemOperationId $a
  Assert-AuthWireCandidateGuid $op
  if($c.format -cne 'AuthWireWriteGrantConsumedV1' -or $c.binding_scope -cne $a.Receipt.binding_scope -or $c.release_id -cne $Release -or $c.job_id -cne $JobId -or
     $c.authorization_sha256 -cne $a.AuthorizationSha256 -or $c.filesystem_operation_id -cne $op -or -not (Test-AuthWireWriteInteger $c.consumed_at) -or
     $c.consumed_at -lt $a.Receipt.received_at -or $c.consumed_at -gt $now -or -not (Test-AuthWireWriteInteger $c.expires_at) -or $c.expires_at -ne $a.Receipt.grant.expires_at){throw 'WRITE_EXECUTION_RECORD_REJECTED'}
  $i=Read-AuthWireStagingJournal (Join-Path $job 'filesystem-intent.json')
  Assert-AuthWireCandidateFields $i @('format','job_id','filesystem_operation_id','binding_scope','release_id','authorization_sha256','consumption_sha256','offer_sha256','target_sha256','preview_sha256','live_context','expires_at','filesystem_write_enabled','can_apply_gpo')
  Assert-AuthWireStageStrings $i @('format','job_id','filesystem_operation_id','binding_scope','release_id','authorization_sha256','consumption_sha256','offer_sha256','target_sha256','preview_sha256')
  if($i.format -cne 'AuthWireAuthorizedFilesystemIntentV1' -or $i.job_id -cne $JobId -or $i.filesystem_operation_id -cne $op -or $i.binding_scope -cne $c.binding_scope -or $i.release_id -cne $Release -or
     $i.authorization_sha256 -cne $a.AuthorizationSha256 -or $i.consumption_sha256 -cne (Get-AuthWireWriteHash $c) -or $i.offer_sha256 -cne $a.Receipt.offer_sha256 -or
     $i.target_sha256 -cne (Get-AuthWireWriteHash $a.Offer.target) -or $i.preview_sha256 -cne $a.Offer.target.preview_record.PreviewSha256 -or
     -not (Test-AuthWireWriteInteger $i.expires_at) -or $i.expires_at -ne $c.expires_at -or $i.filesystem_write_enabled -isnot [bool] -or $i.filesystem_write_enabled -or $i.can_apply_gpo -isnot [bool] -or $i.can_apply_gpo){throw 'WRITE_EXECUTION_RECORD_REJECTED'}
  $live=$i.live_context
  if(-not (Test-AuthWireWriteInteger $live.checked_at) -or $live.checked_at -lt $c.consumed_at -or $live.checked_at -gt $now){throw 'WRITE_EXECUTION_RECORD_REJECTED'}
  Assert-AuthWireWriteLiveContextAt $live $a.Offer $Binding $live.checked_at
  foreach($n in @('source_root','gpo_root','protected_gpo_id','pdc')){if($live.$n -cne $a.Preflight.$n){throw 'WRITE_EXECUTION_SCOPE_CHANGED'}}
  return [pscustomobject]@{Authorization=$a;Consumed=$c;Intent=$i;IntentSha256=(Get-AuthWireWriteHash $i)}
 }finally{$p.Dispose()}
}
function Read-AuthWireStageLaunch([string]$JournalRoot,[string]$JobId,$State){
 $file=Join-Path (Join-Path $JournalRoot $JobId) 'stage-launch.json'
 $p=[AuthWire.Staging.TreeLeaseV1]::new()
 try{
  $p.PinFile($file);$v=Read-AuthWireStagingJournal $file
  Assert-AuthWireCandidateFields $v @('format','job_id','filesystem_operation_id','execution_intent_sha256','authorization_sha256','gate_name','started_at','expires_at','work_budget_ms')
  Assert-AuthWireStageStrings $v @('format','job_id','filesystem_operation_id','execution_intent_sha256','authorization_sha256','gate_name')
  $now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
  if($v.format -cne 'AuthWireStageLaunchV1' -or $v.job_id -cne $JobId -or $v.filesystem_operation_id -cne $State.Intent.filesystem_operation_id -or
     $v.execution_intent_sha256 -cne $State.IntentSha256 -or $v.authorization_sha256 -cne $State.Authorization.AuthorizationSha256 -or $v.gate_name -cnotmatch ('\ALocal\\AuthWireStage-'+([guid]$JobId).ToString('N')+'-[0-9a-f]{32}\z') -or
     -not (Test-AuthWireWriteInteger $v.started_at) -or $v.started_at -lt $State.Intent.live_context.checked_at -or $v.started_at -gt $now -or
     -not (Test-AuthWireWriteInteger $v.expires_at) -or $v.expires_at -ne $State.Intent.expires_at -or
     -not (Test-AuthWireWriteInteger $v.work_budget_ms) -or $v.work_budget_ms -lt 100 -or $v.work_budget_ms -gt 15000 -or $v.work_budget_ms -gt ($v.expires_at-$v.started_at-2)*1000){throw 'WRITE_EXECUTION_LAUNCH_REJECTED'}
  return $v
 }finally{$p.Dispose()}
}
function Read-AuthWireStageChildIdentity([string]$JournalRoot,[string]$JobId,$Launch){
 $p=[AuthWire.Staging.TreeLeaseV1]::new()
 try{
  $file=Join-Path (Join-Path $JournalRoot $JobId) 'stage-child.json';$p.PinFile($file);$v=Read-AuthWireStagingJournal $file
  Assert-AuthWireCandidateFields $v @('format','job_id','launch_sha256','process_id','process_started_ticks')
  Assert-AuthWireStageStrings $v @('format','job_id','launch_sha256','process_started_ticks')
  if($v.format -cne 'AuthWireStageChildIdentityV1' -or $v.job_id -cne $JobId -or $v.launch_sha256 -cne (Get-AuthWireWriteHash $Launch) -or -not (Test-AuthWireWriteInteger $v.process_id) -or $v.process_started_ticks -cnotmatch '\A[1-9][0-9]{16,18}\z'){throw 'WRITE_EXECUTION_CHILD_IDENTITY_REJECTED'}
  return $v
 }finally{$p.Dispose()}
}
function Get-AuthWireStageCompletion([string]$JournalRoot,[string]$JobId,$State,$Launch,[hashtable]$Binding){
 $op=$State.Intent.filesystem_operation_id;$job=Join-Path $JournalRoot $JobId;$directory=Join-Path $JournalRoot $op
 $p=[AuthWire.Staging.TreeLeaseV1]::new()
 try{
  $p.PinAncestors($JournalRoot);$p.PinAncestors($job);$p.PinAncestors($directory)
  foreach($n in @('intent.json','complete.json')){$p.PinFile((Join-Path $directory $n))}
  $p.PinFile((Join-Path $job 'stage-preflight.json'))
  $actual=Read-AuthWireStagingJournal (Join-Path $directory 'intent.json')
  $done=Read-AuthWireStagingJournal (Join-Path $directory 'complete.json')
  $live=Read-AuthWireStagingJournal (Join-Path $job 'stage-preflight.json')
  Assert-AuthWireCandidateFields $actual @('format','operation_id','preview_sha256','target_sha256','gpo_root','relative_destination','baseline_sha256','protected_gpo_id')
  Assert-AuthWireStageStrings $actual @('format','operation_id','preview_sha256','target_sha256','gpo_root','relative_destination','baseline_sha256','protected_gpo_id')
  Assert-AuthWireCandidateFields $done @('format','operation_id','intent_sha256','tree_sha256','tree','baseline')
  Assert-AuthWireStageStrings $done @('format','operation_id','intent_sha256','tree_sha256')
  $o=$State.Authorization.Offer;$t=$o.target.scope_target
  if(-not (Test-AuthWireWriteInteger $live.checked_at) -or $live.checked_at -lt $Launch.started_at -or $live.checked_at -ge $Launch.expires_at){throw 'WRITE_EXECUTION_COMPLETION_REJECTED'}
  Assert-AuthWireWriteLiveContextAt $live $o $Binding $live.checked_at
  foreach($n in @('source_root','gpo_root','protected_gpo_id','pdc')){if($live.$n -cne $State.Intent.live_context.$n){throw 'WRITE_EXECUTION_SCOPE_CHANGED'}}
  if($actual.format -cne 'AuthWireFilesystemIntentV1' -or $actual.operation_id -cne $op -or $actual.preview_sha256 -cne $State.Intent.preview_sha256 -or $actual.target_sha256 -cne (Get-AuthWireCombinedScopeTargetHash $t) -or
     $actual.gpo_root -cne $live.gpo_root -or $actual.relative_destination -cne $o.target.preview_record.Preview.relative_destination -or $actual.baseline_sha256 -cne $o.target.preview_record.Preview.baseline_inventory_sha256 -or
     $actual.protected_gpo_id -cne $live.protected_gpo_id -or $done.format -cne 'AuthWireFilesystemCompleteV1' -or $done.operation_id -cne $op -or $done.intent_sha256 -cne (Get-AuthWireScopeDataHash $actual) -or
     -not (Test-AuthWireWriteHash $done.tree_sha256) -or $done.tree -isnot [array] -or $done.tree.Count -ne 23 -or (Get-AuthWireStagingFilesystemDigest $done.tree) -cne $done.tree_sha256 -or
     (Get-AuthWireScopeDataHash @($done.baseline)) -cne $actual.baseline_sha256){throw 'WRITE_EXECUTION_COMPLETION_REJECTED'}
  return [pscustomobject]@{CompleteSha256=(Get-AuthWireScopeDataHash $done);TreeSha256=$done.tree_sha256;StagePreflightSha256=(Get-AuthWireWriteHash $live)}
 }finally{$p.Dispose()}
}
function Invoke-AuthWireAuthorizedStageChild([string]$JournalRoot,[string]$JobId,[string]$ExpectedIntentSha256,[hashtable]$Binding,[string]$Release,[Security.Cryptography.RSACng]$Key,[string]$Publisher,[string]$BaseUrl){
 $s=Read-AuthWireAuthorizedStageIntent $JournalRoot $JobId $Binding $Release $Key
 if(-not (Test-AuthWireWriteHash $ExpectedIntentSha256) -or $s.IntentSha256 -cne $ExpectedIntentSha256){throw 'WRITE_EXECUTION_INTENT_REJECTED'}
 $p=New-AuthWireStageInputPins $JournalRoot $JobId $s.Authorization.Offer
 try{
  $again=Read-AuthWireAuthorizedStageIntent $JournalRoot $JobId $Binding $Release $Key
  if($again.IntentSha256 -cne $s.IntentSha256){throw 'WRITE_LOCAL_RECORD_CHANGED'}
  $launch=Read-AuthWireStageLaunch $JournalRoot $JobId $s
  $job=Join-Path $JournalRoot $JobId;$op=$s.Intent.filesystem_operation_id
  if(Test-Path -LiteralPath (Join-Path $JournalRoot $op)){throw 'WRITE_EXECUTION_JOURNAL_EXISTS_REQUIRES_REVIEW'}
  $entryGate=[Threading.EventWaitHandle]::OpenExisting($launch.gate_name,[Security.AccessControl.EventWaitHandleRights]::Synchronize)
  try{if(-not $entryGate.WaitOne(2000)){throw 'WRITE_EXECUTION_GATE_NOT_AVAILABLE'}}finally{$entryGate.Dispose()}
  $childIdentity=Read-AuthWireStageChildIdentity $JournalRoot $JobId $launch
  $process=[Diagnostics.Process]::GetCurrentProcess()
  try{if($childIdentity.process_id -ne $PID -or $childIdentity.process_started_ticks -cne $process.StartTime.ToUniversalTime().Ticks.ToString([Globalization.CultureInfo]::InvariantCulture)){throw 'WRITE_EXECUTION_CHILD_IDENTITY_REJECTED'}}finally{$process.Dispose()}
  $start=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds();$clock=[Diagnostics.Stopwatch]::StartNew()
  Write-AuthWireStagingJournal (Join-Path $job 'stage-entered.json') ([pscustomobject]@{format='AuthWireStageEnteredV1';job_id=$JobId;launch_sha256=(Get-AuthWireWriteHash $launch);child_identity_sha256=(Get-AuthWireWriteHash $childIdentity);entered_at=$start})
  $live=Get-AuthWireWriteStageLiveContext $s.Authorization.Offer $Binding $Publisher $BaseUrl
  Assert-AuthWireWriteLiveContext $live $s.Authorization.Offer $Binding
  if($live.checked_at -lt $start){throw 'WRITE_EXECUTION_PREFLIGHT_STALE'}
  foreach($n in @('source_root','gpo_root','protected_gpo_id','pdc')){if($live.$n -cne $s.Intent.live_context.$n){throw 'WRITE_EXECUTION_SCOPE_CHANGED'}}
  Write-AuthWireStagingJournal (Join-Path $job 'stage-preflight.json') $live
  Assert-AuthWireStagingWriteDeadline $launch.expires_at $start $clock
  $offer=$s.Authorization.Offer
  $preview=[pscustomobject]@{Preview=(ConvertTo-AuthWireWriteOrderedPreview $offer.target.preview_record.Preview);PreviewSha256=$s.Intent.preview_sha256}
  $r=Invoke-AuthWireStagingFilesystemStage -Target $offer.target.scope_target -PreviewRecord $preview -ApprovedPreviewSha256 $preview.PreviewSha256 -SourceRoot $live.source_root -GpoRoot $live.gpo_root -JournalRoot $JournalRoot -OperationId $op -ProtectedGpoId $live.protected_gpo_id -NotAfter $launch.expires_at
  if($r.Phase -isnot [string] -or $r.Phase -cne 'staged' -or $r.OperationId -isnot [string] -or $r.OperationId -cne $op -or $r.FileCount -isnot [int] -or $r.FileCount -ne 20 -or $r.CanApplyGpo -isnot [bool] -or $r.CanApplyGpo){throw 'WRITE_EXECUTION_ENGINE_RESULT_REJECTED'}
  $complete=Get-AuthWireStageCompletion $JournalRoot $JobId $s $launch $Binding
  Assert-AuthWireStagingWriteDeadline $launch.expires_at $start $clock
  $result=[pscustomobject][ordered]@{format='AuthWireAuthorizedStageResultV1';job_id=$JobId;filesystem_operation_id=$op;execution_intent_sha256=$s.IntentSha256;authorization_sha256=$s.Authorization.AuthorizationSha256;launch_sha256=(Get-AuthWireWriteHash $launch);child_identity_sha256=(Get-AuthWireWriteHash $childIdentity);stage_preflight_sha256=$complete.StagePreflightSha256;complete_sha256=$complete.CompleteSha256;tree_sha256=$complete.TreeSha256;checked_at=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds();file_count=20;staged=$true;can_apply_gpo=$false}
  Write-AuthWireStagingJournal (Join-Path $job 'execution-complete.json') $result
  Assert-AuthWireStagingWriteDeadline $launch.expires_at $start $clock
  return $result
 }finally{$p.Dispose()}
}
function Invoke-AuthWireAuthorizedFilesystemStage([string]$JournalRoot,[string]$JobId,[hashtable]$Binding,[string]$Release,[Security.Cryptography.RSACng]$Key){
 $s=Read-AuthWireAuthorizedStageIntent $JournalRoot $JobId $Binding $Release $Key
 $p=New-AuthWireStageInputPins $JournalRoot $JobId $s.Authorization.Offer
 $gate=$null
 try{
  $again=Read-AuthWireAuthorizedStageIntent $JournalRoot $JobId $Binding $Release $Key
  if($again.IntentSha256 -cne $s.IntentSha256){throw 'WRITE_LOCAL_RECORD_CHANGED'}
  $job=Join-Path $JournalRoot $JobId
  if(Test-Path -LiteralPath (Join-Path $job 'stage-launch.json')){throw 'WRITE_EXECUTION_ALREADY_LAUNCHED_REQUIRES_REVIEW'}
  Assert-AuthWireWriteLiveContext $s.Intent.live_context $s.Authorization.Offer $Binding
  $now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds();$clock=[Diagnostics.Stopwatch]::StartNew()
  $budget=[int][Math]::Min(15000,($s.Intent.expires_at-$now-2)*1000)
  if($budget -lt 100){throw 'WRITE_AUTHORIZATION_EXPIRED'}
  $gateName='Local\AuthWireStage-'+([guid]$JobId).ToString('N')+'-'+[guid]::NewGuid().ToString('N')
  $gateAcl=[Security.AccessControl.EventWaitHandleSecurity]::new()
  foreach($sid in @($Binding.service_sid,'S-1-5-18','S-1-5-32-544')){$gateAcl.AddAccessRule([Security.AccessControl.EventWaitHandleAccessRule]::new([Security.Principal.SecurityIdentifier]::new($sid),[Security.AccessControl.EventWaitHandleRights]::FullControl,[Security.AccessControl.AccessControlType]::Allow))}
  $created=$false;$gate=[Threading.EventWaitHandle]::new($false,[Threading.EventResetMode]::AutoReset,$gateName,[ref]$created,$gateAcl)
  if(-not $created){throw 'WRITE_EXECUTION_GATE_ALREADY_EXISTS'}
  $launch=[pscustomobject][ordered]@{format='AuthWireStageLaunchV1';job_id=$JobId;filesystem_operation_id=$s.Intent.filesystem_operation_id;execution_intent_sha256=$s.IntentSha256;authorization_sha256=$s.Authorization.AuthorizationSha256;gate_name=$gateName;started_at=$now;expires_at=$s.Intent.expires_at;work_budget_ms=$budget}
  Write-AuthWireStagingJournal (Join-Path $job 'stage-launch.json') $launch
  try{
   Initialize-AuthWireStageProcess
   $exe=Join-Path ([Environment]::GetFolderPath('Windows')) 'System32\WindowsPowerShell\v1.0\powershell.exe'
   $file=Join-Path $PSScriptRoot 'Invoke-AuthWireStagingWriteChild.ps1'
   if($JournalRoot.Length -gt 1800 -or $JournalRoot.Contains('"')){throw 'WRITE_JOURNAL_PATH_REJECTED'}
   $arguments='-NoLogo -NoProfile -NonInteractive -ExecutionPolicy AllSigned -File "'+$file+'" -JournalRoot "'+$JournalRoot.TrimEnd('\')+'" -JobId '+$JobId+' -IntentSha256 '+$s.IntentSha256
   $remaining=$budget-[int]$clock.ElapsedMilliseconds
   Assert-AuthWireStagingWriteDeadline $s.Intent.expires_at $now $clock
   if($remaining -lt 100){throw 'WRITE_AUTHORIZATION_EXPIRED'}
   $beforeRelease=[Action[int,long]]{param($childPid,$ticks)
    Write-AuthWireStagingJournal (Join-Path $job 'stage-child.json') ([pscustomobject]@{format='AuthWireStageChildIdentityV1';job_id=$JobId;launch_sha256=(Get-AuthWireWriteHash $launch);process_id=$childPid;process_started_ticks=$ticks.ToString([Globalization.CultureInfo]::InvariantCulture)})
   }
   $r=[AuthWire.Connector.StageProcessV1]::Run($exe,$arguments,$remaining,$gate,$beforeRelease)
   if($r.TimedOut -or $r.Truncated -or $r.ExitCode -ne 0){throw 'WRITE_EXECUTION_CHILD_REQUIRES_REVIEW'}
   $v=ConvertFrom-AuthWireCandidateJson ([Text.UTF8Encoding]::new($false,$true).GetBytes($r.Output))
   Assert-AuthWireCandidateFields $v @('format','job_id','filesystem_operation_id','execution_intent_sha256','authorization_sha256','launch_sha256','child_identity_sha256','stage_preflight_sha256','complete_sha256','tree_sha256','checked_at','file_count','staged','can_apply_gpo')
   Assert-AuthWireStageStrings $v @('format','job_id','filesystem_operation_id','execution_intent_sha256','authorization_sha256','launch_sha256','child_identity_sha256','stage_preflight_sha256','complete_sha256','tree_sha256')
   $childIdentity=Read-AuthWireStageChildIdentity $JournalRoot $JobId $launch
   if($childIdentity.process_id -ne $r.ProcessId -or $childIdentity.process_started_ticks -cne $r.ProcessStartedTicks.ToString([Globalization.CultureInfo]::InvariantCulture)){throw 'WRITE_EXECUTION_CHILD_IDENTITY_REJECTED'}
   $complete=Get-AuthWireStageCompletion $JournalRoot $JobId $s $launch $Binding
   if($v.format -cne 'AuthWireAuthorizedStageResultV1' -or $v.job_id -cne $JobId -or $v.filesystem_operation_id -cne $s.Intent.filesystem_operation_id -or $v.execution_intent_sha256 -cne $s.IntentSha256 -or
      $v.authorization_sha256 -cne $s.Authorization.AuthorizationSha256 -or $v.launch_sha256 -cne (Get-AuthWireWriteHash $launch) -or $v.child_identity_sha256 -cne (Get-AuthWireWriteHash $childIdentity) -or $v.stage_preflight_sha256 -cne $complete.StagePreflightSha256 -or
      $v.complete_sha256 -cne $complete.CompleteSha256 -or $v.tree_sha256 -cne $complete.TreeSha256 -or -not (Test-AuthWireWriteInteger $v.checked_at) -or $v.checked_at -lt $now -or $v.checked_at -gt [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() -or
      $v.checked_at -ge $s.Intent.expires_at -or $v.file_count -isnot [int] -or $v.file_count -ne 20 -or $v.staged -isnot [bool] -or -not $v.staged -or $v.can_apply_gpo -isnot [bool] -or $v.can_apply_gpo){throw 'WRITE_EXECUTION_RESULT_REJECTED'}
   $resultFile=Join-Path $job 'execution-complete.json';$p.PinFile($resultFile)
   if((Get-AuthWireWriteHash (Read-AuthWireStagingJournal $resultFile)) -cne (Get-AuthWireWriteHash $v)){throw 'WRITE_EXECUTION_RESULT_REJECTED'}
   Write-AuthWireStagingJournal (Join-Path $job 'execution-observed.json') ([pscustomobject]@{format='AuthWireStageObservedV1';job_id=$JobId;result_sha256=(Get-AuthWireWriteHash $v);complete_sha256=$complete.CompleteSha256;observed_at=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()})
   return [pscustomobject]@{JobId=$JobId;Phase='staged';FilesystemOperationId=$s.Intent.filesystem_operation_id;CompleteSha256=$complete.CompleteSha256;TreeSha256=$complete.TreeSha256;FilesystemStaged=$true;PeerResultSubmitted=$false;CanApplyGpo=$false;ArtifactExecuted=$false}
  }catch{
   # The child may have written some/all files even if its result was lost.
   # Preserve every journal/lock and never infer that timeout means no effects.
   try{Write-AuthWireStagingJournal (Join-Path $job 'execution-requires-review.json') ([pscustomobject]@{format='AuthWireStageReviewV1';job_id=$JobId;execution_intent_sha256=$s.IntentSha256;reason='OUTCOME_REQUIRES_REVIEW';checked_at=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()})}catch{}
   throw 'WRITE_EXECUTION_REQUIRES_REVIEW'
  }
 }finally{if($gate){$gate.Dispose()};$p.Dispose()}
}
