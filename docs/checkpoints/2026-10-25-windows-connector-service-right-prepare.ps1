& {
    $ErrorActionPreference = 'Stop'
    $awTool = Join-Path $env:TEMP 'AuthWire-Service-Right-Prepare-v1.ps1'
    scp 'segmentiq@10.35.50.246:/home/segmentiq/authwire-service-right-prepare-v1-20261025.ps1' $awTool
    if ($LASTEXITCODE -ne 0) { throw 'Dosya aktarilamadi.' }
    if ((Get-FileHash -LiteralPath $awTool -Algorithm SHA256).Hash -ine 'b795a3a153af632a8cd2cfd821c3d2172633b0925da9aa4c2bb22031be4204f4') {
        throw 'Dosya ozeti uyusmuyor; calistirilmadi.'
    }
    $awPublisher = '6E74B513F766E01730719684A41B2664380CA68A'
    $awCert = Get-Item -LiteralPath ("Cert:\CurrentUser\My\" + $awPublisher)
    if (-not $awCert.HasPrivateKey) { throw 'Kurumsal imzalama anahtari bulunamadi.' }
    $awSigned = Set-AuthenticodeSignature -FilePath $awTool -Certificate $awCert -HashAlgorithm SHA256
    if ($awSigned.Status.ToString() -ne 'Valid' -or $awSigned.SignerCertificate.Thumbprint -ine $awPublisher) {
        throw 'Kurumsal imza dogrulanamadi.'
    }
    & $awTool -Mode PrepareServiceRight -ExpectedComputer 'DC01' `
        -ExpectedDomain 'vizyonveri.local' -InstanceId '4c23eebe-0715-46d1-88ee-a2e96ad7ee46' `
        -AccountName 'aw-deploy' -AccountSid 'S-1-5-21-34256453-3348971241-2809240126-1648' `
        -BootstrapPath (Join-Path $env:TEMP 'AuthWire-Windows-Bootstrap-v1-r4.ps1') `
        -PublisherThumbprint $awPublisher
}
