& {
    $ErrorActionPreference = 'Stop'
    if ($env:COMPUTERNAME -ine 'DC01') { throw 'Bu kontrol DC01 uzerinde calistirilmali.' }

    $awPrefix = Join-Path $env:TEMP ('AuthWire-Service-Rights-' + [guid]::NewGuid().ToString('N'))
    $awInf = $awPrefix + '.inf'
    $awLog = $awPrefix + '.log'
    try {
        & "$env:WINDIR\System32\secedit.exe" /export /mergedpolicy `
            /cfg $awInf /areas USER_RIGHTS /log $awLog /quiet
        if ($LASTEXITCODE -ne 0) { throw 'Hizmet oturumu izinleri okunamadi.' }

        $awEntries = @(Get-Content -LiteralPath $awInf |
            Where-Object { $_ -match '^\s*Se(Deny)?ServiceLogonRight\s*=' })

        [pscustomobject]@{
            Event = 'WINDOWS_CONNECTOR_SERVICE_RIGHTS_READONLY'
            Computer = $env:COMPUTERNAME
            Account = 'aw-deploy$'
            Sid = 'S-1-5-21-34256453-3348971241-2809240126-1648'
            ExportedAssignments = $awEntries
            PolicyChanged = $false
            ServiceLogonVerified = $false
        } | ConvertTo-Json -Depth 4
    } finally {
        Remove-Item -LiteralPath $awInf,$awLog -Force -ErrorAction SilentlyContinue
    }
}
