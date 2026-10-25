& {
    $ErrorActionPreference = 'Stop'
    if ($env:COMPUTERNAME -ine 'DC01') { throw 'Bu komut DC01 uzerinde calistirilmali.' }

    $awTool = Join-Path $env:TEMP 'AuthWire-Signing-Readiness-v1.ps1'
    scp segmentiq@10.35.50.246:/home/segmentiq/authwire-signing-readiness-v1-20261025.ps1 $awTool
    if ($LASTEXITCODE -ne 0) { throw 'Dosya indirilemedi.' }

    if ((Get-FileHash -LiteralPath $awTool -Algorithm SHA256).Hash -ine '00d2399c2c527bf176384f43917be4b7226624204ab2c82bdbaf73ea0a1f782d') {
        throw 'Dosya dogrulanamadi.'
    }

    $awPublisher = '6E74B513F766E01730719684A41B2664380CA68A'
    $awCert = Get-Item -LiteralPath ('Cert:\CurrentUser\My\' + $awPublisher)
    if (-not $awCert.HasPrivateKey) { throw 'Imzalama anahtarina erisilemiyor.' }
    $awSignature = Set-AuthenticodeSignature -FilePath $awTool -Certificate $awCert -HashAlgorithm SHA256
    if ($awSignature.Status.ToString() -ne 'Valid' -or
        $awSignature.SignerCertificate.Thumbprint -ine $awPublisher) {
        throw 'Imza dogrulanamadi.'
    }

    $awParams = @{
        ExpectedComputer    = 'DC01'
        ExpectedDomain      = 'vizyonveri.local'
        InstanceId          = '4c23eebe-0715-46d1-88ee-a2e96ad7ee46'
        AccountName         = 'aw-deploy'
        AccountSid          = 'S-1-5-21-34256453-3348971241-2809240126-1648'
        BootstrapPath       = Join-Path $env:TEMP 'AuthWire-Windows-Bootstrap-v1-r4.ps1'
        PublisherThumbprint = $awPublisher
    }

    & $awTool -Mode Inspect @awParams
}
