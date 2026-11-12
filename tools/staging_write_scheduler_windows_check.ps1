$ErrorActionPreference='Stop'
if($env:RUNNER_ENVIRONMENT -cne 'github-hosted' -or $env:GITHUB_ACTIONS -cne 'true'){throw 'Hosted Windows fixture required'}
$lib=Join-Path (Split-Path $PSScriptRoot) 'windows\connector'
. (Join-Path $lib 'Test-AuthWireDeploymentCandidate.ps1') -LibraryOnly
. (Join-Path $lib 'StagingWriteLifecycle.ps1')
. (Join-Path $lib 'StagingWriteScheduler.ps1')

Add-Type -TypeDefinition @'
using System;
using System.Threading;
public sealed class AuthWireSchedulerFixtureLock : IDisposable {
    readonly ManualResetEvent ready = new ManualResetEvent(false);
    readonly ManualResetEvent release = new ManualResetEvent(false);
    readonly Thread owner;
    public AuthWireSchedulerFixtureLock(string name) {
        owner = new Thread(() => {
            using (var mutex = new Mutex(false, name)) {
                if (!mutex.WaitOne(3000)) return;
                ready.Set();
                try { release.WaitOne(10000); } finally { mutex.ReleaseMutex(); }
            }
        });
        owner.IsBackground = true;
        owner.Start();
        if (!ready.WaitOne(4000)) throw new InvalidOperationException("Fixture mutex unavailable.");
    }
    public void Dispose() { release.Set(); owner.Join(5000); release.Dispose(); ready.Dispose(); }
    public static Timer SignalLater(EventWaitHandle signal) {
        return new Timer(state => signal.Set(), null, 200, Timeout.Infinite);
    }
}
'@

function Check([bool]$Condition,[string]$Message){if(-not $Condition){throw $Message}}
function Invoke-AuthWireStagingWriteLifecycleStep {
 $script:observed.Add($script:watch.ElapsedMilliseconds)
 if($script:throwStep){throw 'fixture transport failure'}
 if($script:signalDuringWait){$script:timer=[AuthWireSchedulerFixtureLock]::SignalLater($stop)}
 if($script:observed.Count -eq $script:stopAfter){$null=$stop.Set()}
 return $script:results.Dequeue()
}
function Reset-Fixture {
 $null=$stop.Reset();$script:observed.Clear();$script:results.Clear()
 $script:watch.Restart();$script:stopAfter=0;$script:throwStep=$false;$script:signalDuringWait=$false
}

$stop=[Threading.ManualResetEvent]::new($false)
$key=[Security.Cryptography.RSACng]::new(2048)
$parent=[Diagnostics.Process]::GetCurrentProcess()
$binding=@{connector_id=[guid]::NewGuid().ToString('D')}
$release=[guid]::NewGuid().ToString('D');$job=[guid]::NewGuid().ToString('D')
$params=@{Root='fixture';Binding=$binding;Release=$release;Key=$key;BaseUrl='https://unused.invalid';
          StopSignal=$stop;HostProcess=$parent;IntervalSeconds=1}
$script:watch=[Diagnostics.Stopwatch]::new()
$script:observed=[Collections.Generic.List[long]]::new()
$script:results=[Collections.Generic.Queue[object]]::new()
$script:timer=$null
try{
 Reset-Fixture
 $script:results.Enqueue((Get-AuthWireLifecycleResult 'no_job'))
 $script:results.Enqueue((Get-AuthWireLifecycleResult 'result_recorded' $job 'staged' $true))
 $script:results.Enqueue((Get-AuthWireLifecycleResult 'result_recorded' $job 'rolled_back' $true))
 $script:stopAfter=3
 $summary=Invoke-AuthWireStagingWriteScheduler @params
 Check ($summary.StopReason -ceq 'stop_requested' -and $summary.Steps -eq 3) 'Idle and accepted outcomes did not continue as expected.'
 Check ($script:observed[1]-$script:observed[0] -ge 1000 -and $script:observed[2]-$script:observed[1] -ge 1000) 'Scheduler started another step before its monotonic interval.'

 foreach($phase in @('requires_review','local_reconciliation_required','result_pending','refusal_result_pending',
     'refused_before_authorization','result_attempt_limit_requires_review','refusal_attempt_limit_requires_review','history_limit_requires_maintenance')){
  Reset-Fixture
  $script:results.Enqueue((Get-AuthWireLifecycleResult $phase $job))
  $summary=Invoke-AuthWireStagingWriteScheduler @params
  Check ($summary.StopReason -ceq 'lifecycle_requires_attention' -and $summary.LastPhase -ceq $phase -and $summary.Steps -eq 1) ('Unsafe continuation after '+$phase)
 }
 Reset-Fixture
 $bad=Get-AuthWireLifecycleResult 'no_job';$bad.CanApplyGpo=$true;$script:results.Enqueue($bad)
 Check ((Invoke-AuthWireStagingWriteScheduler @params).StopReason -ceq 'invalid_lifecycle_result') 'Unexpected authorization flag was accepted.'
 Reset-Fixture
 $script:throwStep=$true
 $summary=Invoke-AuthWireStagingWriteScheduler @params
 Check ($summary.StopReason -ceq 'lifecycle_failed' -and $summary.Steps -eq 1) 'A failed lifecycle step was retried automatically.'

 Reset-Fixture
 $script:signalDuringWait=$true;$script:results.Enqueue((Get-AuthWireLifecycleResult 'no_job'))
 $params.IntervalSeconds=30
 $summary=Invoke-AuthWireStagingWriteScheduler @params
 Check ($summary.StopReason -ceq 'stop_requested' -and $summary.Steps -eq 1 -and $script:watch.ElapsedMilliseconds -lt 10000) 'Stop event did not interrupt the idle interval.'
 $summary=Invoke-AuthWireStagingWriteScheduler @params
 Check ($summary.StopReason -ceq 'stop_requested' -and $summary.Steps -eq 0) 'A pre-signaled stop allowed a lifecycle step.'

 Reset-Fixture
 $child=Start-Process -FilePath "$env:SystemRoot\System32\cmd.exe" -ArgumentList '/c exit 0' -NoNewWindow -PassThru -Wait
 try{
  $params.HostProcess=$child
  $summary=Invoke-AuthWireStagingWriteScheduler @params
  Check ($summary.StopReason -ceq 'host_exited' -and $summary.Steps -eq 0) 'An exited host allowed a lifecycle step.'
 }finally{$child.Dispose();$params.HostProcess=$parent}

 $held=[AuthWireSchedulerFixtureLock]::new(('Global\AuthWireWriteScheduler-'+([guid]$binding.connector_id).ToString('N')))
 try{
  $summary=Invoke-AuthWireStagingWriteScheduler @params
  Check ($summary.StopReason -ceq 'scheduler_busy' -and $summary.Steps -eq 0) 'A concurrent scheduler started a lifecycle step.'
 }finally{$held.Dispose()}
 Write-Output 'AUTHWIRE_WRITE_SCHEDULER_WINDOWS_OK synthetic_lifecycle=true native_wait_and_mutex=true scm_registered=false'
}finally{
 if($script:timer){$script:timer.Dispose()}
 $parent.Dispose();$key.Dispose();$stop.Dispose()
}
