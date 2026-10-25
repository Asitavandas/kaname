& {
    $ErrorActionPreference = 'Stop'
    $awProbe = Join-Path $env:TEMP 'AuthWire-Service-Rights-Readonly-v1.ps1'
    scp 'segmentiq@10.35.50.246:/home/segmentiq/authwire-service-rights-readonly-v1-20261025.ps1' $awProbe
    if ($LASTEXITCODE -ne 0) { throw 'Dosya aktarilamadi.' }
    if ((Get-FileHash -LiteralPath $awProbe -Algorithm SHA256).Hash -ine '8084e949dd954833464d26224606e8a4ee41989ac17ed79f918c165ac9a2ef07') {
        throw 'Dosya ozeti uyusmuyor; calistirilmadi.'
    }
    $awPublisher = '6E74B513F766E01730719684A41B2664380CA68A'
    $awCert = Get-Item -LiteralPath ("Cert:\CurrentUser\My\" + $awPublisher)
    if (-not $awCert.HasPrivateKey) { throw 'Kurumsal imzalama anahtari bulunamadi.' }
    $awSigned = Set-AuthenticodeSignature -FilePath $awProbe -Certificate $awCert -HashAlgorithm SHA256
    if ($awSigned.Status.ToString() -ne 'Valid' -or $awSigned.SignerCertificate.Thumbprint -ine $awPublisher) {
        throw 'Kurumsal imza dogrulanamadi.'
    }
    & $awProbe -ExpectedComputer 'DC01' `
        -AccountSid 'S-1-5-21-34256453-3348971241-2809240126-1648'
}
