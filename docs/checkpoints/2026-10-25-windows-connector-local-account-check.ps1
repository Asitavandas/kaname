& {
    $ErrorActionPreference = 'Stop'
    if ($env:COMPUTERNAME -ine 'DC01') { throw 'Bu adim DC01 uzerinde calistirilmali.' }

    $awSetup = Join-Path $env:TEMP 'AuthWire-Windows-Bootstrap-v1-r4.ps1'
    $awPublisher = '6E74B513F766E01730719684A41B2664380CA68A'
    $awSignature = Get-AuthenticodeSignature -FilePath $awSetup
    if ($awSignature.Status.ToString() -ne 'Valid' -or
        $awSignature.SignerCertificate.Thumbprint -ine $awPublisher) {
        throw 'Hazirlik betiginin kurumsal imzasi dogrulanamadi.'
    }

    $awInspect = & $awSetup -Mode Inspect -ExpectedDomain 'vizyonveri.local' `
        -ConnectorComputer 'DC01' -InstanceId '4c23eebe-0715-46d1-88ee-a2e96ad7ee46' `
        -AccountName 'aw-deploy' -GpoId 'e5a9ab39-3709-49cb-837a-0208d2eb3b12' `
        -PublisherThumbprint $awPublisher | ConvertFrom-Json

    $awSid = 'S-1-5-21-34256453-3348971241-2809240126-1648'
    if ($awInspect.BootstrapVersion -ne '1.0.3' -or
        -not $awInspect.ReadyForAccountPreparation -or
        @($awInspect.Blockers).Count -ne 0 -or
        -not $awInspect.Account.Exists -or $awInspect.Account.Sid -ne $awSid) {
        throw 'Hesap kontrolu gecemedi; yerel kurulum yapilmadi.'
    }

    Import-Module ActiveDirectory
    $awBefore = @(Test-ADServiceAccount -Identity $awSid -ErrorAction Stop)
    if ($awBefore.Count -ne 1 -or $awBefore[0] -isnot [bool]) {
        throw 'Yerel test beklenmeyen sonuc dondurdu.'
    }
    $awInstalledNow = $false
    if (-not $awBefore[0]) {
        Install-ADServiceAccount -Identity $awSid -ErrorAction Stop
        $awInstalledNow = $true
    }
    $awAfter = @(Test-ADServiceAccount -Identity $awSid -ErrorAction Stop)
    $awReady = ($awAfter.Count -eq 1 -and $awAfter[0] -is [bool] -and $awAfter[0])

    [pscustomobject]@{
        Event = 'WINDOWS_CONNECTOR_LOCAL_ACCOUNT_CHECK'
        Computer = $env:COMPUTERNAME
        Account = 'aw-deploy$'
        Sid = $awSid
        InstalledNow = $awInstalledNow
        LocalInstallationVerified = $awReady
        AccountReadyForUse = $awReady
        ServiceLogonVerified = $false
        ConnectorInstalled = $false
        CanApplyGpo = $false
    } | ConvertTo-Json
}
