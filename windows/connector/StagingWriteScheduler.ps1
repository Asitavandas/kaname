# Source scheduler for the existing write lifecycle. A service host owns its stop event.
Set-StrictMode -Version 2

function Invoke-AuthWireStagingWriteScheduler {
 [CmdletBinding()]
 param(
  [Parameter(Mandatory=$true)][string]$Root,
  [Parameter(Mandatory=$true)][hashtable]$Binding,
  [Parameter(Mandatory=$true)][string]$Release,
  [Parameter(Mandatory=$true)][Security.Cryptography.RSACng]$Key,
  [Parameter(Mandatory=$true)][string]$BaseUrl,
  [Parameter(Mandatory=$true)][Threading.WaitHandle]$StopSignal,
  [Parameter(Mandatory=$true)][Diagnostics.Process]$HostProcess,
  [ValidateRange(1,300)][int]$IntervalSeconds=30
 )
 Assert-AuthWireCandidateGuid $Binding.connector_id
 Assert-AuthWireCandidateGuid $Release
 $mutex=[Threading.Mutex]::new($false,('Global\AuthWireWriteScheduler-'+([guid]$Binding.connector_id).ToString('N')))
 $held=$false
 $summary=[pscustomobject]@{StopReason='';Steps=[long]0;LastPhase=''}
 try{
  try{$held=$mutex.WaitOne(0)}catch [Threading.AbandonedMutexException]{
   $held=$true;$summary.StopReason='scheduler_abandoned_requires_review';return $summary
  }
  if(-not $held){$summary.StopReason='scheduler_busy';return $summary}
  $clock=[Diagnostics.Stopwatch]::StartNew();$next=[long]0
  while($true){
   if($StopSignal.WaitOne(0)){$summary.StopReason='stop_requested';return $summary}
   if($HostProcess.HasExited){$summary.StopReason='host_exited';return $summary}
   $wait=$next-$clock.ElapsedMilliseconds
   if($wait -gt 0){$null=$StopSignal.WaitOne([int][Math]::Min(250,$wait));continue}
   $summary.Steps++
   try{
    $step=Invoke-AuthWireStagingWriteLifecycleStep $Root $Binding $Release $Key $BaseUrl
    if($step -isnot [pscustomobject] -or $step.Phase -isnot [string] -or
       $step.ResultRecorded -isnot [bool] -or $step.CanApplyGpo -isnot [bool] -or
       $step.CanApplyGpo -or $step.ArtifactExecuted -isnot [bool] -or $step.ArtifactExecuted){
     $summary.StopReason='invalid_lifecycle_result';return $summary
    }
    $phase=$step.Phase
    if($phase -cin @('no_job','result_recorded','requires_review','local_reconciliation_required',
      'result_pending','refusal_result_pending','refused_before_authorization','result_attempt_limit_requires_review',
      'refusal_attempt_limit_requires_review','history_limit_requires_maintenance')){$summary.LastPhase=$phase}
    else{$summary.StopReason='invalid_lifecycle_result';return $summary}
    $idle=$phase -ceq 'no_job' -and -not $step.ResultRecorded -and $step.JobId -ceq '' -and $step.Outcome -ceq ''
    $accepted=$phase -ceq 'result_recorded' -and $step.ResultRecorded -and $step.Outcome -cin @('staged','rolled_back')
    if($accepted){Assert-AuthWireCandidateGuid $step.JobId}
    if(-not ($idle -or $accepted)){$summary.StopReason='lifecycle_requires_attention';return $summary}
   }catch [Management.Automation.PipelineStoppedException]{throw}catch{
    $summary.StopReason='lifecycle_failed';return $summary
   }
   $next=$clock.ElapsedMilliseconds+1000L*$IntervalSeconds
  }
 }finally{if($held){$mutex.ReleaseMutex()};$mutex.Dispose()}
}
