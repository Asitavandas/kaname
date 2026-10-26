# Sign with enterprise Authenticode. Deploy once as computer startup via GPO.
param([switch]$RunClient, [switch]$RetryCheck)
$ErrorActionPreference = 'Stop'
if ([Security.Principal.WindowsIdentity]::GetCurrent().User.Value -ne 'S-1-5-18') { throw 'AuthWire installation requires SYSTEM.' }
$publisher = $null
foreach($name in @('Install-AuthWire.ps1','AuthWire-Client.ps1')) {
    $signature = Get-AuthenticodeSignature (Join-Path $PSScriptRoot $name)
    if($signature.Status -ne 'Valid') { throw 'AuthWire requires valid enterprise Authenticode signatures.' }
    if(!$publisher) { $publisher = $signature.SignerCertificate.Thumbprint }
    if($signature.SignerCertificate.Thumbprint -ne $publisher) { throw 'AuthWire scripts must use the same trusted publisher.' }
}
# Package generation embeds these hashes BEFORE the operator signs this file.
# Thus the Authenticode signature covers the config and public trust assets too.
$expectedAssets = @'
__AUTHWIRE_ASSET_HASHES__
'@ | ConvertFrom-Json
$verifiedAssets = @{}
foreach($asset in $expectedAssets.PSObject.Properties) {
    if($asset.Name -notin @('config.json','root-ca.pem','issuer-ca.pem','https-trust.pem')) { throw 'Unexpected AuthWire asset.' }
    $assetFile = Join-Path $PSScriptRoot $asset.Name
    if((Get-Item $assetFile).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'AuthWire asset reparse point refused.' }
    $bytes = [IO.File]::ReadAllBytes($assetFile)
    $hash = [Security.Cryptography.SHA256]::Create()
    try { $actual = [BitConverter]::ToString($hash.ComputeHash($bytes)).Replace('-','') } finally { $hash.Dispose() }
    if($actual -ine $asset.Value) { throw 'AuthWire config/trust asset was modified after signing.' }
    $verifiedAssets[$asset.Name] = $bytes
}
$target = Join-Path $env:ProgramData 'AuthWire'
function Read-AuthWireRetryDeadline([string]$Directory) {
    $path = Join-Path $Directory 'retry.json'
    if(!(Test-Path -LiteralPath $path)) { return $null }
    if((Get-Item -LiteralPath $path).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'AuthWire retry reparse point refused.' }
    $retry = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
    $deadline = [DateTimeOffset]::Parse([string]$retry.next_attempt)
    if($deadline -gt [DateTimeOffset]::UtcNow.AddHours(13)) { throw 'AuthWire retry deadline outside bounded backoff.' }
    return $deadline
}
function Set-AuthWireRetryTask([string]$Directory, [string]$TaskName, [DateTimeOffset]$When) {
    $scriptFile = Join-Path $Directory 'Install-AuthWire.ps1'
    $retryAction = New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -Argument ('-NoProfile -NonInteractive -ExecutionPolicy AllSigned -File "'+$scriptFile+'" -RetryCheck')
    $retrySettings = New-ScheduledTaskSettingsSet -StartWhenAvailable -RunOnlyIfNetworkAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 2)
    $retryPrincipal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
    $description = 'AuthWire managed enrollment retry deadline'
    $existingRetry = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if($existingRetry -and ($existingRetry.Description -ne $description -or $existingRetry.Principal.UserId -notin @('SYSTEM','NT AUTHORITY\SYSTEM','S-1-5-18'))) { throw 'Unexpected existing AuthWire retry task.' }
    # StartBoundary uses whole-second precision. Do not truncate a fractional
    # deadline into an early run or re-register an already elapsed trigger.
    # https://learn.microsoft.com/en-us/windows/win32/taskschd/trigger-startboundary
    $earliest = [DateTimeOffset]::UtcNow.AddSeconds(5)
    $scheduled = if($When -gt $earliest) { $When.UtcDateTime } else { $earliest.UtcDateTime }
    $fraction = $scheduled.Ticks % [TimeSpan]::TicksPerSecond
    if($fraction -ne 0) { $scheduled = $scheduled.AddTicks([TimeSpan]::TicksPerSecond - $fraction) }
    $retryTrigger = New-ScheduledTaskTrigger -Once -At $scheduled.ToLocalTime()
    $null = Register-ScheduledTask -TaskName $TaskName -Action $retryAction -Trigger $retryTrigger -Settings $retrySettings -Principal $retryPrincipal -Description $description -Force
    # Restrict the task definition itself, as well as the private signed files.
    $scheduler = New-Object -ComObject 'Schedule.Service'
    $scheduler.Connect()
    $registered = $scheduler.GetFolder('\').GetTask($TaskName)
    $registered.SetSecurityDescriptor('D:P(A;;GA;;;SY)(A;;GA;;;BA)',0)
}
function Invoke-AuthWireRetryCheck([string]$Directory, [string]$MainTaskName, [string]$RetryTaskName) {
    $deadline = Read-AuthWireRetryDeadline $Directory
    if(!$deadline) { return 'nothing_pending' }
    if([DateTimeOffset]::UtcNow -lt $deadline) {
        Set-AuthWireRetryTask $Directory $RetryTaskName $deadline
        return 'deadline_rearmed'
    }
    $main = Get-ScheduledTask -TaskName $MainTaskName -ErrorAction Stop
    if($main.State -in @('Running','Queued')) { return 'already_pending' }
    Start-ScheduledTask -TaskName $MainTaskName -ErrorAction Stop
    return 'retry_requested'
}
function Complete-AuthWireRecoveryStatus([string]$Directory) {
    if(Test-Path -LiteralPath (Join-Path $Directory 'retry.json')) { return }
    $statusFile = Join-Path $Directory 'status.json'
    $installedFile = Join-Path $Directory 'installed.json'
    if(!(Test-Path -LiteralPath $statusFile) -or !(Test-Path -LiteralPath $installedFile)) { return }
    foreach($path in @($statusFile,$installedFile)) {
        if((Get-Item -LiteralPath $path).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'AuthWire state reparse point refused.' }
    }
    $oldStatus = Get-Content -LiteralPath $statusFile -Raw | ConvertFrom-Json
    if($oldStatus.state -ne 'retry_pending') { return }
    $installedState = Get-Content -LiteralPath $installedFile -Raw | ConvertFrom-Json
    if($installedState.thumbprint -notmatch '^[A-Fa-f0-9]{40}$' -or $installedState.serial -notmatch '^[A-Fa-f0-9]+$') { throw 'Invalid AuthWire installed identity.' }
    $leaf = Get-Item ('Cert:\LocalMachine\My\'+$installedState.thumbprint) -ErrorAction Stop
    if(!$leaf.HasPrivateKey -or $leaf.NotBefore -gt (Get-Date) -or $leaf.NotAfter -le (Get-Date)) { throw 'AuthWire current certificate unavailable.' }
    # This is a successful receipt check, not a new certificate issuance date.
    $recovered = @{state='installed';serial=$installedState.serial;checked_at=[DateTimeOffset]::UtcNow.ToString('o');last_verified=[DateTimeOffset]::UtcNow.ToString('o');operation='renewal_check'}
    if($oldStatus.last_success) { $recovered['last_success'] = $oldStatus.last_success }
    $temporary = $statusFile+'.tmp'
    if((Test-Path -LiteralPath $temporary) -and ((Get-Item -LiteralPath $temporary).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'AuthWire temporary state reparse point refused.' }
    [IO.File]::WriteAllText($temporary,($recovered|ConvertTo-Json -Depth 5),(New-Object Text.UTF8Encoding($false)))
    [IO.File]::Replace($temporary,$statusFile,[NullString]::Value)
}
function Invoke-AuthWireEnrollmentClient([string]$Directory, [string]$RetryTaskName) {
    $launcherMutex = New-Object Threading.Mutex($false,'Global\AuthWire-Certificate-Launcher')
    $locked = $false
    try {
        try { $locked = $launcherMutex.WaitOne(0) }
        catch [Threading.AbandonedMutexException] { $locked = $true }
        if(!$locked) { return 0 }
        $deadline = Read-AuthWireRetryDeadline $Directory
        if($deadline -and [DateTimeOffset]::UtcNow -lt $deadline) {
            Set-AuthWireRetryTask $Directory $RetryTaskName $deadline
            return 0
        }
        $arguments = '-NoProfile -NonInteractive -ExecutionPolicy AllSigned -File "'+(Join-Path $Directory 'AuthWire-Client.ps1')+'"'
        $child = Start-Process -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList $arguments -WindowStyle Hidden -Wait -PassThru
        $child.Refresh()
        $result = [int]$child.ExitCode
        $deadline = Read-AuthWireRetryDeadline $Directory
        if($deadline) {
            if($deadline -le [DateTimeOffset]::UtcNow) { throw 'AuthWire client did not advance its retry deadline.' }
            Set-AuthWireRetryTask $Directory $RetryTaskName $deadline
        } elseif($result -eq 0) {
            Complete-AuthWireRecoveryStatus $Directory
        }
        return $result
    } finally {
        if($locked) { $launcherMutex.ReleaseMutex() }
        $launcherMutex.Dispose()
    }
}
if($RunClient -or $RetryCheck) {
    if($RunClient -and $RetryCheck) { throw 'Conflicting AuthWire launcher modes.' }
    if([IO.Path]::GetFullPath($PSScriptRoot).TrimEnd('\') -ine [IO.Path]::GetFullPath($target).TrimEnd('\')) { throw 'AuthWire launcher requires the private installed directory.' }
    if((Get-Item -LiteralPath $target).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'AuthWire private directory reparse point refused.' }
    if($RetryCheck) {
        Write-Output ('AuthWire retry: '+(Invoke-AuthWireRetryCheck $target 'AuthWire Certificate Enrollment' 'AuthWire Certificate Enrollment Retry'))
        exit 0
    }
    exit (Invoke-AuthWireEnrollmentClient $target 'AuthWire Certificate Enrollment Retry')
}
if(Test-Path $target) {
    if((Get-Item $target).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'AuthWire reparse point refused.' }
} else { $null = New-Item $target -ItemType Directory }
# Private client state/config and pending CNG requests are not user-writable.
$acl = New-Object Security.AccessControl.DirectorySecurity
$acl.SetAccessRuleProtection($true,$false)
$acl.SetOwner((New-Object Security.Principal.SecurityIdentifier('S-1-5-32-544')))
foreach($sid in @('S-1-5-18','S-1-5-32-544')) {
    $rule = New-Object Security.AccessControl.FileSystemAccessRule((New-Object Security.Principal.SecurityIdentifier($sid)), 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
    $acl.AddAccessRule($rule)
}
Set-Acl $target $acl
foreach($name in @('AuthWire-Client.ps1','Install-AuthWire.ps1') + @($verifiedAssets.Keys)) {
    $destination = Join-Path $target $name
    if((Test-Path $destination) -and ((Get-Item $destination).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'AuthWire file reparse point refused.' }
    if($name -in @('AuthWire-Client.ps1','Install-AuthWire.ps1')) {
        Copy-Item (Join-Path $PSScriptRoot $name) $destination -Force
        $copiedSignature = Get-AuthenticodeSignature $destination
        if($copiedSignature.Status -ne 'Valid' -or $copiedSignature.SignerCertificate.Thumbprint -ne $publisher) { throw 'Copied AuthWire script signature invalid.' }
    } else { [IO.File]::WriteAllBytes($destination, [byte[]]$verifiedAssets[$name]) }
    $fileAcl = New-Object Security.AccessControl.FileSecurity
    $fileAcl.SetAccessRuleProtection($true,$false)
    $fileAcl.SetOwner((New-Object Security.Principal.SecurityIdentifier('S-1-5-32-544')))
    foreach($sid in @('S-1-5-18','S-1-5-32-544')) {
        $fileAcl.AddAccessRule((New-Object Security.AccessControl.FileSystemAccessRule((New-Object Security.Principal.SecurityIdentifier($sid)), 'FullControl', 'Allow')))
    }
    Set-Acl $destination $fileAcl
}
foreach($entry in @(@('root-ca.pem','Root'),@('issuer-ca.pem','CA'),@('https-trust.pem','Root'))) {
    $file = Join-Path $target $entry[0]
    if(Test-Path $file) {
        $certificate = New-Object Security.Cryptography.X509Certificates.X509Certificate2($file)
        $store = New-Object Security.Cryptography.X509Certificates.X509Store($entry[1],'LocalMachine')
        try { $store.Open('ReadWrite'); $store.Add($certificate) } finally { $store.Close(); $certificate.Dispose() }
    }
}
$action = New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -Argument ('-NoProfile -NonInteractive -ExecutionPolicy AllSigned -File "'+(Join-Path $target 'Install-AuthWire.ps1')+'" -RunClient')
$daily = New-ScheduledTaskTrigger -Daily -At '09:00'; $evening = New-ScheduledTaskTrigger -Daily -At '21:00'
$startup = New-ScheduledTaskTrigger -AtStartup
# Startup plus StartWhenAvailable/RunOnlyIfNetworkAvailable defers enrollment
# until networking is usable. Avoid raw MSFT_TaskEventTrigger CIM instances:
# Register-ScheduledTask rejects their PSTypeName on supported Windows clients.
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -RunOnlyIfNetworkAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 10)
$null = Register-ScheduledTask -TaskName 'AuthWire Certificate Enrollment' -Action $action -Trigger @($daily,$evening,$startup) -Principal $principal -Settings $settings -Force
# Reapplication also repairs a pending deadline created by the older client.
$pendingRetry = Read-AuthWireRetryDeadline $target
if($pendingRetry) {
    $retryAt = if($pendingRetry -gt [DateTimeOffset]::UtcNow) { $pendingRetry } else { [DateTimeOffset]::UtcNow.AddMinutes(1) }
    Set-AuthWireRetryTask $target 'AuthWire Certificate Enrollment Retry' $retryAt
}
# GPO can register/update an existing task after the boot event was missed.
# Task existence does not prove that its boot trigger actually ran.
function Start-AuthWireEnrollmentForBoot([string]$TaskName) {
    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction Stop
    $info = Get-ScheduledTaskInfo -TaskName $TaskName -ErrorAction Stop
    $boot = (Get-CimInstance Win32_OperatingSystem -ErrorAction Stop).LastBootUpTime
    if (!$boot -or !$info.LastRunTime) { throw 'AuthWire boot state unavailable.' }
    if ($task.State -in @('Running','Queued')) { return 'already_pending' }
    if ($info.LastRunTime -ge $boot) { return 'already_ran_this_boot' }
    Start-ScheduledTask -TaskName $TaskName -ErrorAction Stop
    return 'boot_run_requested'
}
$bootRun = Start-AuthWireEnrollmentForBoot 'AuthWire Certificate Enrollment'
Write-Output ('AuthWire enrollment startup: ' + $bootRun)
# No supplicant policy, port control or RADIUS changes in this package.
