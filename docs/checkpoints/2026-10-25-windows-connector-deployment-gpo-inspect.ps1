& {
    $ErrorActionPreference = 'Stop'
    $awTool = Join-Path $env:TEMP 'AuthWire-Deployment-GPO-Bootstrap-v1.ps1'
    scp 'segmentiq@10.35.50.246:/home/segmentiq/authwire-deployment-gpo-bootstrap-v1-20261025.ps1' $awTool
    if ($LASTEXITCODE -ne 0) { throw 'Dosya aktarilamadi.' }
    if ((Get-FileHash -LiteralPath $awTool -Algorithm SHA256).Hash -ine '48170996a41fef8bb50dc656d56e46b500541b46ad1184d1659252d2de0f827e') {
        throw 'Dosya ozeti uyusmuyor; calistirilmadi.'
    }
    $awPublisher = '6E74B513F766E01730719684A41B2664380CA68A'
    $awCert = Get-Item -LiteralPath ("Cert:\CurrentUser\My\" + $awPublisher)
    if (-not $awCert.HasPrivateKey) { throw 'Kurumsal imzalama anahtari bulunamadi.' }
    $awSigned = Set-AuthenticodeSignature -FilePath $awTool -Certificate $awCert -HashAlgorithm SHA256
    if ($awSigned.Status.ToString() -ne 'Valid' -or $awSigned.SignerCertificate.Thumbprint -ine $awPublisher) {
        throw 'Kurumsal imza dogrulanamadi.'
    }
    & $awTool -Mode Inspect -ExpectedComputer 'DC01' -ExpectedDomain 'vizyonveri.local' `
        -InstanceId '4c23eebe-0715-46d1-88ee-a2e96ad7ee46' -AccountName 'aw-deploy' `
        -AccountSid 'S-1-5-21-34256453-3348971241-2809240126-1648' `
        -ScopeGroupSid 'S-1-5-21-34256453-3348971241-2809240126-1647' `
        -ScopeGroupName 'AuthWire-Pilot-Computers' `
        -ProtectedGpoId 'e5a9ab39-3709-49cb-837a-0208d2eb3b12' `
        -BootstrapPath (Join-Path $env:TEMP 'AuthWire-Windows-Bootstrap-v1-r4.ps1') `
        -PublisherThumbprint $awPublisher
}
