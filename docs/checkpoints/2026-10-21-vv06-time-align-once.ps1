& {
    $ErrorActionPreference = 'Stop'
    if ($env:COMPUTERNAME -ine 'VV06') {
        throw 'Bu islem yalniz VV06 icindir.'
    }

    $awConfig = 'HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Config'
    $awParams = 'HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\Parameters'
    $awPolicy = 'HKLM:\SOFTWARE\Policies\Microsoft\W32Time\Config'
    $awOriginal = (Get-ItemProperty $awConfig).MaxAllowedPhaseOffset

    if ($awOriginal -ne 300 -or (Get-ItemProperty $awParams).Type -ne 'NT5DS') {
        throw 'Beklenen 300/NT5DS ayarlari degismis; islem uygulanmadi.'
    }
    if ($null -ne (Get-ItemProperty $awPolicy -Name MaxAllowedPhaseOffset -ErrorAction SilentlyContinue)) {
        throw 'Esik GPO ile yonetiliyor; islem uygulanmadi.'
    }

    $awBackup = Join-Path $env:ProgramData (
        'AuthWire-Time-Align-' + (Get-Date -Format 'yyyyMMdd-HHmmss')
    )
    New-Item -ItemType Directory -Path $awBackup | Out-Null
    reg.exe export 'HKLM\SYSTEM\CurrentControlSet\Services\W32Time' "$awBackup\W32Time.reg" /y
    if ($LASTEXITCODE -ne 0) { throw 'Yedek alinamadi; degisiklik uygulanmadi.' }
    "Yedek: $awBackup"

    try {
        Set-ItemProperty $awConfig -Name MaxAllowedPhaseOffset -Value 1
        Restart-Service W32Time
        Start-Sleep -Seconds 3
        w32tm /resync /rediscover
        if ($LASTEXITCODE -ne 0) { throw 'Resync basarisiz; ciktiyi paylas.' }
        Start-Sleep -Seconds 3
    }
    finally {
        Set-ItemProperty $awConfig -Name MaxAllowedPhaseOffset -Value $awOriginal
        w32tm /config /update
        if ($LASTEXITCODE -ne 0) {
            throw 'Ozgun registry esigi geri yazildi; W32Time yeniden yukleme basarisiz. Ciktiyi paylas.'
        }
        if ((Get-ItemProperty $awConfig).MaxAllowedPhaseOffset -ne $awOriginal) {
            throw 'Ozgun esik geri yukleme dogrulanamadi.'
        }
        "Ozgun esik geri yuklendi: $awOriginal"
    }

    w32tm /query /configuration | Select-String 'MaxAllowedPhaseOffset:|Type:'
    w32tm /query /status /verbose
    w32tm /stripchart /computer:dc01.vizyonveri.local /dataonly /samples:5
}
