if ($env:COMPUTERNAME -ne 'VV06') { throw 'Bu kontrol VV06 uzerinde calistirilmali.' }
$ErrorActionPreference = 'Stop'
$awName = 'AuthWire-KeyCheck-' + [guid]::NewGuid().ToString('N')
$awResult = Join-Path $env:ProgramData ('AuthWire\' + $awName + '.json')
$awCreated = $false
$awProbe = @'
$ErrorActionPreference = 'Stop'
$r = @{Checked=$false; RunAsSystem=([Security.Principal.WindowsIdentity]::GetCurrent().User.Value -eq 'S-1-5-18')}
try {
    if (!$r.RunAsSystem) { throw 'SYSTEM required' }
    $s = Get-Content 'C:\ProgramData\AuthWire\installed.json' -Raw | ConvertFrom-Json
    if ($s.thumbprint -ne '4CFD8321AE08D6074B99AF5C194151AD5F99F454') { throw 'Current certificate changed' }
    $old = @($s.previous | Where-Object {$_.thumbprint -eq '68B32BBD470847950BAE5629B853739F819150B5'})
    if ($old.Count -ne 1 -or !$old[0].container -or !$s.container) { throw 'Tracking information missing' }
    $provider = [Security.Cryptography.CngProvider]::MicrosoftSoftwareKeyStorageProvider
    $options = [Security.Cryptography.CngKeyOpenOptions]::MachineKey
    $r.CurrentKeyPresent = [Security.Cryptography.CngKey]::Exists($s.container,$provider,$options)
    if (!$r.CurrentKeyPresent) { throw 'Positive control failed' }
    $r.OldCertificatePresent = Test-Path 'Cert:\LocalMachine\My\68B32BBD470847950BAE5629B853739F819150B5'
    $r.OldKeyPresent = [Security.Cryptography.CngKey]::Exists($old[0].container,$provider,$options)
    $r.Checked = $true
} catch {
    $r.Error = 'KEY_INSPECTION_NOT_VERIFIED'
}
$r | ConvertTo-Json | Set-Content '__AW_RESULT__' -Encoding UTF8
'@
$awProbe = $awProbe.Replace('__AW_RESULT__', $awResult)
$awEncoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($awProbe))
try {
    $awAction = New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -Argument "-NoProfile -NonInteractive -ExecutionPolicy AllSigned -EncodedCommand $awEncoded"
    $awPrincipal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
    $awSettings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 1)
    Register-ScheduledTask -TaskName $awName -InputObject (New-ScheduledTask -Action $awAction -Principal $awPrincipal -Settings $awSettings) | Out-Null
    $awCreated = $true
    Start-ScheduledTask -TaskName $awName
    $awDeadline = (Get-Date).AddSeconds(30)
    do {
        Start-Sleep -Seconds 1
        $awState = (Get-ScheduledTask -TaskName $awName).State
    } while (($awState -ne 'Ready' -or !(Test-Path $awResult)) -and (Get-Date) -lt $awDeadline)
    if ($awState -ne 'Ready' -or !(Test-Path $awResult)) { throw 'Kontrol tamamlanmadi; temizlik basarili sayilmadi.' }
    Get-Content $awResult -Raw
} finally {
    if ($awCreated) {
        Stop-ScheduledTask -TaskName $awName -ErrorAction SilentlyContinue
        Unregister-ScheduledTask -TaskName $awName -Confirm:$false -ErrorAction SilentlyContinue
    }
    Remove-Item $awResult -ErrorAction SilentlyContinue
}
