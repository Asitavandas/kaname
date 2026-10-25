& {
    $ErrorActionPreference = 'Stop'
    $awSetup = Join-Path $env:TEMP 'AuthWire-Windows-Bootstrap-v1-r3.ps1'
    scp 'segmentiq@10.35.50.246:/home/segmentiq/authwire-windows-bootstrap-v1-r3-20261025.ps1' $awSetup
    if ($LASTEXITCODE -ne 0) { throw 'Dosya aktarilamadi.' }
    $awExpectedHash = '696733d09ee6c4f5bea29df1b1d4fb60da47cac0e9b7d81d40f0f002c3a90361'
    if ((Get-FileHash -LiteralPath $awSetup -Algorithm SHA256).Hash -ine $awExpectedHash) {
        throw 'Dosya ozeti uyusmuyor; calistirilmadi.'
    }
    $awPublisher = '6E74B513F766E01730719684A41B2664380CA68A'
    $awCert = Get-Item -LiteralPath ("Cert:\CurrentUser\My\" + $awPublisher)
    if (-not $awCert.HasPrivateKey) { throw 'Kurumsal imzalama anahtari bulunamadi.' }
    $awSigned = Set-AuthenticodeSignature -FilePath $awSetup -Certificate $awCert -HashAlgorithm SHA256
    if ($awSigned.Status.ToString() -ne 'Valid' -or
        $awSigned.SignerCertificate.Thumbprint -ine $awPublisher) {
        throw 'Kurumsal imza dogrulanamadi.'
    }
    & $awSetup -Mode Inspect -ExpectedDomain 'vizyonveri.local' `
        -ConnectorComputer 'DC01' -InstanceId '4c23eebe-0715-46d1-88ee-a2e96ad7ee46' `
        -AccountName 'aw-deploy' -GpoId 'e5a9ab39-3709-49cb-837a-0208d2eb3b12' `
        -PublisherThumbprint $awPublisher
}
