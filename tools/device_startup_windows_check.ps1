# Disposable hosted Windows only; real SYSTEM tasks, no enrollment/AD requests.
$ErrorActionPreference = 'Stop'
if ($env:RUNNER_ENVIRONMENT -ne 'github-hosted') { throw 'Hosted fixture only.' }
$source = Join-Path $PSScriptRoot '..\kaname\device_client\Install-AuthWire.ps1'
$tokens = $null; $parseErrors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile($source,[ref]$tokens,[ref]$parseErrors)
if ($parseErrors.Count) { throw 'Installer syntax failed.' }
$functions = @($ast.FindAll({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Start-AuthWireEnrollmentForBoot'},$true))
if ($functions.Count -ne 1) { throw 'Expected one production startup function.' }
. ([scriptblock]::Create($functions[0].Extent.Text))
$settingsAst = @($ast.FindAll({param($n) $n -is [Management.Automation.Language.AssignmentStatementAst] -and $n.Left.Extent.Text -eq '$settings'},$true))
if ($settingsAst.Count -ne 1) { throw 'Expected production task settings.' }
$settings = & ([scriptblock]::Create($settingsAst[0].Right.Extent.Text))
if ($settings.DisallowStartIfOnBatteries -or $settings.StopIfGoingOnBatteries -or !$settings.RunOnlyIfNetworkAvailable) { throw 'Production conditions changed unexpectedly.' }
$folder = Join-Path $env:RUNNER_TEMP ('authwire-startup-' + [guid]::NewGuid().ToString('N'))
$null = New-Item $folder -ItemType Directory
$marker = Join-Path $folder 'runs.txt'
$taskName = 'AuthWire-CI-Startup-' + [guid]::NewGuid().ToString('N')
$created = $false
function RunCount { if (Test-Path $marker) { return @(Get-Content $marker).Count }; return 0 }
function WaitCompleted([datetime]$After) {
    $deadline = (Get-Date).AddSeconds(35)
    do {
        Start-Sleep -Milliseconds 300
        $info = Get-ScheduledTaskInfo -TaskName $taskName
        $task = Get-ScheduledTask -TaskName $taskName
        if ($info.LastRunTime -ge $After -and $task.State -eq 'Ready') {
            if ($info.LastTaskResult -ne 0) { throw 'Fixture action failed.' }
            return
        }
    } while ((Get-Date) -lt $deadline)
    throw ('Fixture never completed: ' + $task.State)
}
try {
    $safeMarker = $marker.Replace("'","''")
    $body = "[IO.File]::AppendAllText('$safeMarker',([Security.Principal.WindowsIdentity]::GetCurrent().User.Value+[Environment]::NewLine));Start-Sleep -Seconds 6"
    $encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($body))
    $action = New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -Argument "-NoProfile -NonInteractive -ExecutionPolicy AllSigned -EncodedCommand $encoded"
    $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
    $trigger = New-ScheduledTaskTrigger -AtStartup
    $definition = New-ScheduledTask -Action $action -Principal $principal -Settings $settings -Trigger $trigger
    $null = Register-ScheduledTask -TaskName $taskName -InputObject $definition
    $created = $true
    $started = (Get-Date).AddSeconds(-1)
    if ((Start-AuthWireEnrollmentForBoot $taskName) -ne 'boot_run_requested') { throw 'Fresh task was not requested.' }
    $deadline = (Get-Date).AddSeconds(15)
    do { Start-Sleep -Milliseconds 200 } while ((Get-ScheduledTask -TaskName $taskName).State -ne 'Running' -and (Get-Date) -lt $deadline)
    if ((Get-ScheduledTask -TaskName $taskName).State -ne 'Running') { throw 'Fixture task did not enter Running.' }
    if ((Start-AuthWireEnrollmentForBoot $taskName) -ne 'already_pending') { throw 'Running task duplicate was not suppressed.' }
    WaitCompleted $started
    if ((RunCount) -ne 1 -or (Get-Content $marker) -ne 'S-1-5-18') { throw 'Expected exactly one real SYSTEM action.' }
    if ((Start-AuthWireEnrollmentForBoot $taskName) -ne 'already_ran_this_boot' -or (RunCount) -ne 1) { throw 'Completed boot task was restarted.' }

    # Keep the Task Scheduler native; simulate only a new OS boot boundary.
    # An actual runner reboot is intentionally not claimed by this fixture.
    $script:FixtureBoot = Get-Date
    Start-Sleep -Seconds 1
    function Get-CimInstance { param([string]$ClassName) if ($ClassName -ne 'Win32_OperatingSystem') { throw 'Unexpected query.' }; [pscustomobject]@{LastBootUpTime=$script:FixtureBoot} }
    $null = Register-ScheduledTask -TaskName $taskName -InputObject $definition -Force
    if ((Get-ScheduledTaskInfo -TaskName $taskName).LastRunTime -ge $script:FixtureBoot) { throw 'Expected predecessor run preserved by task update.' }
    if ((Start-AuthWireEnrollmentForBoot $taskName) -ne 'boot_run_requested') { throw 'Re-registered missed boot was not recovered.' }
    WaitCompleted $script:FixtureBoot
    if ((RunCount) -ne 2) { throw 'Expected one recovery action.' }
    if ((Start-AuthWireEnrollmentForBoot $taskName) -ne 'already_ran_this_boot' -or (RunCount) -ne 2) { throw 'Recovery was not idempotent.' }

    # A queued task already has a pending run; exercise the no-extra-request guard.
    function Get-ScheduledTask { param([string]$TaskName) [pscustomobject]@{State='Queued'} }
    if ((Start-AuthWireEnrollmentForBoot $taskName) -ne 'already_pending') { throw 'Queued guard failed.' }
    Remove-Item Function:\Get-ScheduledTask
    Remove-Item Function:\Get-CimInstance
    Write-Output ('AUTHWIRE_STARTUP_FIXTURE_OK ' + (@{real_task_scheduler=$true;real_system_actions=2;fresh_install=$true;running_not_duplicated=$true;already_ran_not_duplicated=$true;missed_boot_recovered_after_registration=$true;boot_boundary_simulated=$true;real_reboot_tested=$false;queued_guard_mocked=$true;customer_state_used=$false;enrollment_network_calls=0}|ConvertTo-Json -Compress))
} finally {
    Remove-Item Function:\Get-ScheduledTask -ErrorAction SilentlyContinue
    Remove-Item Function:\Get-CimInstance -ErrorAction SilentlyContinue
    if ($created) {
        Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
    }
    Remove-Item $folder -Recurse -Force -ErrorAction SilentlyContinue
}
