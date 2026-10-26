# Disposable hosted Windows only. Real SYSTEM tasks and signed fixture files.
$ErrorActionPreference='Stop'
if($env:RUNNER_ENVIRONMENT -ne 'github-hosted') {throw 'Hosted fixture only.'}
$source=Join-Path $PSScriptRoot '..\kaname\device_client\Install-AuthWire.ps1'
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile($source,[ref]$tokens,[ref]$errors)
if($errors.Count) {throw 'Installer parse failed.'}
$names=@('Read-AuthWireRetryDeadline','Set-AuthWireRetryTask','Invoke-AuthWireRetryCheck','Complete-AuthWireRecoveryStatus','Invoke-AuthWireEnrollmentClient')
$functions=@($ast.FindAll({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -in $names},$true))
if($functions.Count -ne $names.Count) {throw 'Expected all production launcher functions.'}
$definitions=($functions|ForEach-Object {$_.Extent.Text})-join [Environment]::NewLine
. ([scriptblock]::Create($definitions))
$folder=Join-Path $env:RUNNER_TEMP ('authwire-retry-'+[guid]::NewGuid().ToString('N'))
$null=New-Item $folder -ItemType Directory
$mainName='AuthWire-CI-Main-'+[guid]::NewGuid().ToString('N')
$retryName='AuthWire-CI-Retry-'+[guid]::NewGuid().ToString('N')
$signer=$null;$leaf=$null
function ChildCount {
    $file=Join-Path $folder 'count.txt'
    if(Test-Path $file) {return [int](Get-Content $file -Raw)}
    return 0
}
function Write-RetryFixtureDiagnostic {
    # Only bounded task/timing facts from this UUID fixture; never script bodies,
    # credentials, full state documents, certificate keys, or customer tasks.
    $facts=[ordered]@{checked_utc=[DateTimeOffset]::UtcNow.ToString('o');child_count=(ChildCount)}
    foreach($entry in @(@('main',$mainName),@('retry',$retryName))) {
        $task=Get-ScheduledTask -TaskName $entry[1] -ErrorAction SilentlyContinue
        if(!$task) {$facts[$entry[0]]=@{found=$false};continue}
        $info=Get-ScheduledTaskInfo -TaskName $entry[1]
        $facts[$entry[0]]=@{found=$true;state=[string]$task.State;last_result=$info.LastTaskResult;last_run=$(if($info.LastRunTime){$info.LastRunTime.ToString('o')}else{$null});next_run=$(if($info.NextRunTime){$info.NextRunTime.ToString('o')}else{$null})}
    }
    $facts['network_profiles']=@(Get-NetConnectionProfile -ErrorAction SilentlyContinue|ForEach-Object {@{category=[string]$_.NetworkCategory;ipv4=[string]$_.IPv4Connectivity;ipv6=[string]$_.IPv6Connectivity}})
    foreach($name in @('retry.json','status.json','launcher-result.json')) {
        $path=Join-Path $folder $name
        if(!(Test-Path -LiteralPath $path)) {continue}
        try {
            $value=Get-Content -LiteralPath $path -Raw|ConvertFrom-Json
            $selected=[ordered]@{}
            foreach($field in @('attempts','next_attempt','state','stage','mode','result','error_type','error_id','hresult')) {
                if($null -ne $value.$field) {$selected[$field]=$value.$field}
            }
            $facts[$name]=$selected
        } catch {$facts[$name]=@{read_failed=$true}}
    }
    Write-Output ('AUTHWIRE_RETRY_FIXTURE_DIAGNOSTIC '+($facts|ConvertTo-Json -Depth 5 -Compress))
}
function Wait-TaskResult([string]$Name,[datetime]$After,[int]$Expected) {
    $limit=(Get-Date).AddSeconds(50)
    do {
        Start-Sleep -Milliseconds 250
        $task=Get-ScheduledTask -TaskName $Name
        $info=Get-ScheduledTaskInfo -TaskName $Name
        if($info.LastRunTime -ge $After -and $task.State -eq 'Ready') {
            if($info.LastTaskResult -ne $Expected) {throw ('Unexpected fixture exit: '+$info.LastTaskResult)}
            return
        }
    } while((Get-Date) -lt $limit)
    throw ('Task did not finish: '+$Name)
}
try {
    $acl=New-Object Security.AccessControl.DirectorySecurity
    $acl.SetAccessRuleProtection($true,$false)
    $acl.SetOwner((New-Object Security.Principal.SecurityIdentifier('S-1-5-32-544')))
    foreach($sid in @('S-1-5-18','S-1-5-32-544')) {$acl.AddAccessRule((New-Object Security.AccessControl.FileSystemAccessRule((New-Object Security.Principal.SecurityIdentifier($sid)),'FullControl','ContainerInherit,ObjectInherit','None','Allow')))}
    Set-Acl $folder $acl
    $signer=New-SelfSignedCertificate -Type CodeSigningCert -Subject ('CN=AuthWire Retry Signer '+[guid]::NewGuid()) -CertStoreLocation Cert:\CurrentUser\My
    foreach($storeName in @('Root','TrustedPublisher')) {
        $store=New-Object Security.Cryptography.X509Certificates.X509Store($storeName,'LocalMachine')
        try {$store.Open('ReadWrite');$store.Add((New-Object Security.Cryptography.X509Certificates.X509Certificate2(,$signer.RawData)))} finally {$store.Close()}
    }
    $leaf=New-SelfSignedCertificate -Type Custom -Subject ('CN=AuthWire Retry Leaf '+[guid]::NewGuid()) -CertStoreLocation Cert:\LocalMachine\My -KeyExportPolicy NonExportable
    $installed=Join-Path $folder 'installed.json'
    [IO.File]::WriteAllText($installed,(@{serial=$leaf.SerialNumber;thumbprint=$leaf.Thumbprint;container='fixture-no-export';renew_at=[DateTimeOffset]::UtcNow.AddDays(30).ToString('o')}|ConvertTo-Json))
    $installedHash=(Get-FileHash $installed).Hash
    foreach($name in @('config.json','root-ca.pem','issuer-ca.pem')) {[IO.File]::WriteAllText((Join-Path $folder $name),'fixture-public-asset')}
    $assetHashes=[ordered]@{}
    foreach($name in @('config.json','root-ca.pem','issuer-ca.pem')) {$assetHashes[$name]=(Get-FileHash (Join-Path $folder $name)).Hash}
    $map=$assetHashes|ConvertTo-Json -Compress

    $stub=@'
$ErrorActionPreference='Stop'
if([Security.Principal.WindowsIdentity]::GetCurrent().User.Value -ne 'S-1-5-18') {throw 'Expected SYSTEM child.'}
$countFile=Join-Path $PSScriptRoot 'count.txt'
$count=if(Test-Path $countFile) {[int](Get-Content $countFile -Raw)+1} else {1}
[IO.File]::WriteAllText($countFile,[string]$count)
$mode=Get-Content (Join-Path $PSScriptRoot 'mode.txt') -Raw
if($mode -eq 'fail-twice' -and $count -le 2) {
    [IO.File]::WriteAllText((Join-Path $PSScriptRoot 'retry.json'),(@{attempts=$count;stage='session';next_attempt=[DateTimeOffset]::UtcNow.AddSeconds(25).ToOffset([TimeSpan]::FromHours(3)).ToString('o')}|ConvertTo-Json))
    [IO.File]::WriteAllText((Join-Path $PSScriptRoot 'status.json'),(@{state='retry_pending';error='ENROLLMENT_OR_INSTALL_FAILED';stage='session';checked_at=[DateTimeOffset]::UtcNow.ToString('o')}|ConvertTo-Json))
    exit 1
}
if($mode -eq 'hold') {Start-Sleep -Seconds 15}
Remove-Item (Join-Path $PSScriptRoot 'retry.json') -Force -ErrorAction SilentlyContinue
exit 0
'@
    $client=Join-Path $folder 'AuthWire-Client.ps1'
    [IO.File]::WriteAllText($client,$stub,(New-Object Text.UTF8Encoding($true)))
    if((Set-AuthenticodeSignature $client $signer -HashAlgorithm SHA256).Status -ne 'Valid') {throw 'Fixture client signing failed.'}
    $clientHash=(Get-FileHash $client).Hash
    $text=[IO.File]::ReadAllText($source)
    # Use the exact production signature/asset checks and exact function bodies.
    # Only private test-directory binding and UUID task names differ from entrypoint.
    $prefix=$text.Substring(0,$text.IndexOf('$target = Join-Path'))
    $footer=@'
try {
    if($RetryCheck) {
        $outcome=Invoke-AuthWireRetryCheck $PSScriptRoot '__MAIN__' '__RETRY__'
        [IO.File]::WriteAllText((Join-Path $PSScriptRoot 'launcher-result.json'),(@{mode='retry';result=[string]$outcome}|ConvertTo-Json -Compress))
        exit 0
    }
    if($RunClient) {exit (Invoke-AuthWireEnrollmentClient $PSScriptRoot '__RETRY__')}
    throw 'Fixture launcher requires an explicit mode.'
} catch {
    [IO.File]::WriteAllText((Join-Path $PSScriptRoot 'launcher-result.json'),(@{mode=$(if($RetryCheck){'retry'}else{'main'});error_type=$_.Exception.GetType().Name;error_id=$_.FullyQualifiedErrorId;hresult=$_.Exception.HResult}|ConvertTo-Json -Compress))
    throw
}
'@
    $footer=$footer.Replace('__MAIN__',$mainName).Replace('__RETRY__',$retryName)
    $shim=$prefix+$definitions+[Environment]::NewLine+$footer
    $shim=$shim.Replace('__AUTHWIRE_ASSET_HASHES__',$map)
    $installer=Join-Path $folder 'Install-AuthWire.ps1'
    [IO.File]::WriteAllText($installer,$shim,(New-Object Text.UTF8Encoding($true)))
    if((Set-AuthenticodeSignature $installer $signer -HashAlgorithm SHA256).Status -ne 'Valid') {throw 'Fixture launcher signing failed.'}
    [IO.File]::WriteAllText((Join-Path $folder 'mode.txt'),'fail-twice')
    $action=New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -Argument ('-NoProfile -NonInteractive -ExecutionPolicy AllSigned -File "'+$installer+'" -RunClient')
    $principal=New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
    $settings=New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 5)
    $null=Register-ScheduledTask -TaskName $mainName -Action $action -Principal $principal -Settings $settings

    # Actual scheduler serialization must not round a fractional backoff down.
    $precise=[DateTimeOffset]::UtcNow.AddSeconds(15)
    Set-AuthWireRetryTask $folder $retryName $precise
    $boundary=[DateTimeOffset]::Parse((Get-ScheduledTask -TaskName $retryName).Triggers[0].StartBoundary)
    if($boundary -lt $precise -or $boundary.UtcDateTime.Ticks % [TimeSpan]::TicksPerSecond -ne 0) {throw 'Fractional retry deadline was rounded down.'}
    $checked=[DateTimeOffset]::UtcNow
    Set-AuthWireRetryTask $folder $retryName $checked.AddSeconds(-1)
    $boundary=[DateTimeOffset]::Parse((Get-ScheduledTask -TaskName $retryName).Triggers[0].StartBoundary)
    if($boundary -lt $checked.AddSeconds(5)) {throw 'Elapsed retry registration was not moved safely into the future.'}
    Unregister-ScheduledTask -TaskName $retryName -Confirm:$false
    Write-Output 'RETRY_NATIVE_FRACTIONAL_DEADLINE_ROUNDUP_AND_FUTURE_GUARD_OK'

    $began=(Get-Date).AddSeconds(-1)
    Start-ScheduledTask -TaskName $mainName
    Wait-TaskResult $mainName $began 1
    if((ChildCount) -ne 1) {throw 'Expected first failed attempt.'}
    $retry=Get-ScheduledTask -TaskName $retryName
    if($retry.Principal.UserId -notin @('SYSTEM','NT AUTHORITY\SYSTEM','S-1-5-18') -or $retry.Actions[0].Arguments -notmatch 'AllSigned.*-RetryCheck' -or $retry.Triggers.Count -ne 1 -or $retry.Triggers[0].CimClass.CimClassName -ne 'MSFT_TaskTimeTrigger') {throw 'Retry task contract incorrect.'}
    if(!$retry.Settings.RunOnlyIfNetworkAvailable -or !$retry.Settings.StartWhenAvailable -or $retry.Settings.DisallowStartIfOnBatteries -or $retry.Settings.StopIfGoingOnBatteries) {throw 'Retry conditions incorrect.'}
    $schedule=New-Object -ComObject Schedule.Service;$schedule.Connect()
    $sddl=$schedule.GetFolder('\').GetTask($retryName).GetSecurityDescriptor(4)
    $security=New-Object Security.AccessControl.RawSecurityDescriptor($sddl)
    foreach($ace in $security.DiscretionaryAcl) {
        if($ace.SecurityIdentifier.Value -notin @('S-1-5-18','S-1-5-32-544')) {throw 'Unexpected retry task permission.'}
    }
    # An early invocation rearms the same one-time task instead of claiming recovery.
    $early=(Get-Date).AddSeconds(-1)
    Start-ScheduledTask -TaskName $retryName
    Wait-TaskResult $retryName $early 0
    if((ChildCount) -ne 1) {throw 'Retry ran before backoff deadline.'}
    Write-Output 'RETRY_NATIVE_EARLY_REARM_AND_TASK_ACL_OK'

    # No Start-ScheduledTask from here: both subsequent main runs must be automatic.
    $limit=(Get-Date).AddSeconds(180)
    do {
        Start-Sleep -Milliseconds 500
        $main=Get-ScheduledTask -TaskName $mainName
        $info=Get-ScheduledTaskInfo -TaskName $mainName
        if((ChildCount) -eq 3 -and $main.State -eq 'Ready' -and $info.LastTaskResult -eq 0) {break}
    } while((Get-Date) -lt $limit)
    if((ChildCount) -ne 3 -or $info.LastTaskResult -ne 0) {Write-RetryFixtureDiagnostic;throw 'Native automatic failure/rearm/recovery did not finish.'}
    if(Test-Path (Join-Path $folder 'retry.json')) {throw 'Retry state survived successful recovery.'}
    $status=Get-Content (Join-Path $folder 'status.json') -Raw|ConvertFrom-Json
    if($status.state -ne 'installed' -or $status.serial -ne $leaf.SerialNumber -or !$status.last_verified -or $status.error -or $status.stage -or $status.last_success) {throw 'Recovered status stale or invented issuance date.'}
    if((Get-FileHash $installed).Hash -ne $installedHash -or (Get-FileHash $client).Hash -ne $clientHash -or !(Get-Item ('Cert:\LocalMachine\My\'+$leaf.Thumbprint)).HasPrivateKey) {throw 'Recovery altered installed identity or client.'}
    foreach($name in $assetHashes.Keys) {if((Get-FileHash (Join-Path $folder $name)).Hash -ne $assetHashes[$name]) {throw 'Protected fixture asset changed.'}}
    if((Invoke-AuthWireRetryCheck $folder $mainName $retryName) -ne 'nothing_pending') {throw 'Expected no-op without retry.'}
    Write-Output 'RETRY_NATIVE_TWO_AUTOMATIC_ATTEMPTS_RECOVERED_AND_IDENTITY_PRESERVED'

    # Real running-main guard; no duplicate process may be requested.
    [IO.File]::WriteAllText((Join-Path $folder 'mode.txt'),'hold')
    $began=(Get-Date).AddSeconds(-1)
    Start-ScheduledTask -TaskName $mainName
    $limit=(Get-Date).AddSeconds(20)
    do {Start-Sleep -Milliseconds 200} while((ChildCount) -lt 4 -and (Get-Date) -lt $limit)
    if((ChildCount) -ne 4) {throw 'Holding child did not start.'}
    [IO.File]::WriteAllText((Join-Path $folder 'retry.json'),(@{next_attempt=[DateTimeOffset]::UtcNow.AddSeconds(-1).ToString('o')}|ConvertTo-Json))
    if((Invoke-AuthWireRetryCheck $folder $mainName $retryName) -ne 'already_pending') {throw 'Running main was not suppressed.'}
    Wait-TaskResult $mainName $began 0
    if((ChildCount) -ne 4) {throw 'Duplicate main child executed.'}
    Write-Output 'RETRY_RUNNING_MAIN_NOT_DUPLICATED'

    [IO.File]::WriteAllText((Join-Path $folder 'retry.json'),'{"next_attempt":"invalid"}')
    $rejected=$false
    try {$null=Invoke-AuthWireRetryCheck $folder $mainName $retryName} catch {$rejected=$true}
    if(!$rejected -or (ChildCount) -ne 4) {throw 'Invalid deadline accepted.'}
    Remove-Item (Join-Path $folder 'retry.json')
    [IO.File]::AppendAllText($client,'# signature tamper')
    $began=(Get-Date).AddSeconds(-1)
    Start-ScheduledTask -TaskName $mainName
    $limit=(Get-Date).AddSeconds(30)
    do {Start-Sleep -Milliseconds 250;$state=Get-ScheduledTask $mainName;$info=Get-ScheduledTaskInfo $mainName} while(($info.LastRunTime -lt $began -or $state.State -ne 'Ready') -and (Get-Date) -lt $limit)
    if($info.LastTaskResult -eq 0 -or (ChildCount) -ne 4) {throw 'Unsigned/tampered child ran.'}
    Write-Output 'AUTHWIRE_RETRY_FIXTURE_OK real_system=true real_time_triggers=true no_ad_or_enrollment_network=true customer_state=false real_offline_network_tested=false'
} finally {
    foreach($name in @($mainName,$retryName)) {
        Stop-ScheduledTask -TaskName $name -ErrorAction SilentlyContinue
        Unregister-ScheduledTask -TaskName $name -Confirm:$false -ErrorAction SilentlyContinue
    }
    if($leaf) {Remove-Item ('Cert:\LocalMachine\My\'+$leaf.Thumbprint) -DeleteKey -Force -ErrorAction SilentlyContinue}
    if($signer) {
        foreach($storeName in @('Root','TrustedPublisher')) {Remove-Item ('Cert:\LocalMachine\'+$storeName+'\'+$signer.Thumbprint) -Force -ErrorAction SilentlyContinue}
        Remove-Item ('Cert:\CurrentUser\My\'+$signer.Thumbprint) -DeleteKey -Force -ErrorAction SilentlyContinue
    }
    Remove-Item $folder -Recurse -Force -ErrorAction SilentlyContinue
}
