# Run on DC01 as the authorized administrator. AD operation is Inspect only.
& {
    $ErrorActionPreference = 'Stop'
    $awSetup = Join-Path $env:TEMP 'AuthWire-Windows-Bootstrap-v1.ps1'
    scp segmentiq@10.35.50.246:/home/segmentiq/authwire-windows-bootstrap-v1-20261024.ps1 $awSetup
    if ($LASTEXITCODE -ne 0) { throw 'Dosya alinamadi; islem durduruldu.' }
    $awExpected = '75b8e21e21796dcf2a3023f45dd8d87c9cc6c2f7d8176bf7096fe4b2afe1dfc1'
    if ((Get-FileHash -LiteralPath $awSetup -Algorithm SHA256).Hash -ine $awExpected) {
        throw 'Dosya hash dogrulamasi basarisiz.'
    }
    $awPublisher = '6E74B513F766E01730719684A41B2664380CA68A'
    $awSigner = Get-Item -LiteralPath ('Cert:\CurrentUser\My\' + $awPublisher)
    if (-not $awSigner.HasPrivateKey) { throw 'Kurumsal imzalama anahtari bulunamadi.' }
    $awSignature = Set-AuthenticodeSignature -FilePath $awSetup -Certificate $awSigner -HashAlgorithm SHA256
    if ($awSignature.Status.ToString() -ne 'Valid' -or $awSignature.SignerCertificate.Thumbprint -ine $awPublisher) {
        throw 'Kurumsal imza dogrulanamadi.'
    }
    & $awSetup -Mode Inspect -ExpectedDomain 'vizyonveri.local' -ConnectorComputer 'DC01' -InstanceId '4c23eebe-0715-46d1-88ee-a2e96ad7ee46' -GpoId 'e5a9ab39-3709-49cb-837a-0208d2eb3b12' -PublisherThumbprint $awPublisher
}
