& {
    $ErrorActionPreference = 'Stop'
    $awProbe = Join-Path $env:TEMP 'AuthWire-Service-Logon-Probe-v1.ps1'
    scp 'segmentiq@10.35.50.246:/home/segmentiq/authwire-service-logon-probe-v1-20261025.ps1' $awProbe
    if ($LASTEXITCODE -ne 0) { throw 'Dosya aktarilamadi.' }
    if ((Get-FileHash -LiteralPath $awProbe -Algorithm SHA256).Hash -ine 'ac34825ef7263f920563b7980c1afbc701b77df5516b95599e3538c781bbeac0') {
        throw 'Dosya ozeti uyusmuyor; calistirilmadi.'
    }
    $awPublisher = '6E74B513F766E01730719684A41B2664380CA68A'
    $awCert = Get-Item -LiteralPath ("Cert:\CurrentUser\My\" + $awPublisher)
    if (-not $awCert.HasPrivateKey) { throw 'Kurumsal imzalama anahtari bulunamadi.' }
    $awSigned = Set-AuthenticodeSignature -FilePath $awProbe -Certificate $awCert -HashAlgorithm SHA256
    if ($awSigned.Status.ToString() -ne 'Valid' -or $awSigned.SignerCertificate.Thumbprint -ine $awPublisher) {
        throw 'Kurumsal imza dogrulanamadi.'
    }
    & $awProbe -Mode RunProbe -ExpectedComputer 'DC01' `
        -ExpectedDomain 'vizyonveri.local' -InstanceId '4c23eebe-0715-46d1-88ee-a2e96ad7ee46' `
        -AccountName 'aw-deploy' -AccountSid 'S-1-5-21-34256453-3348971241-2809240126-1648' `
        -BootstrapPath (Join-Path $env:TEMP 'AuthWire-Windows-Bootstrap-v1-r4.ps1') `
        -RightsToolPath (Join-Path $env:TEMP 'AuthWire-Service-Right-Prepare-v1.ps1') `
        -PublisherThumbprint $awPublisher
}
