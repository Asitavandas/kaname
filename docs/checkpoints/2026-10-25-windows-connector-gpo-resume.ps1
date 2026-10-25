& {
    $ErrorActionPreference = 'Stop'
    if ($env:COMPUTERNAME -ine 'DC01') { throw 'Bu komut DC01 uzerinde calistirilmali.' }

    $awTool = Join-Path $env:TEMP 'AuthWire-Deployment-GPO-Bootstrap-v1-r2.ps1'
    scp segmentiq@10.35.50.246:/home/segmentiq/authwire-deployment-gpo-bootstrap-v1-r2-20261025.ps1 $awTool
    if ($LASTEXITCODE -ne 0) { throw 'Dosya indirilemedi.' }

    $awHash = (Get-FileHash -LiteralPath $awTool -Algorithm SHA256).Hash
    if ($awHash -ine '25794286c163f4fecf83ae8736b80cdbb25ba5c6d1bd5eefa236a7859c5b67d5') {
        throw 'Dosya dogrulanamadi.'
    }

    $awPublisher = '6E74B513F766E01730719684A41B2664380CA68A'
    $awCert = Get-Item -LiteralPath ('Cert:\CurrentUser\My\' + $awPublisher)
    if (-not $awCert.HasPrivateKey) { throw 'Imzalama anahtarina erisilemiyor.' }
    $awSignature = Set-AuthenticodeSignature -FilePath $awTool -Certificate $awCert -HashAlgorithm SHA256
    if ($awSignature.Status.ToString() -ne 'Valid' -or
        $awSignature.SignerCertificate.Thumbprint -ine $awPublisher) {
        throw 'Dosyanin imzasi dogrulanamadi.'
    }

    & $awTool -Mode ResumeGpo `
        -PreparationReceiptPath 'C:\ProgramData\AuthWire-GpoPreparation-6394ceadf50a4dc29f13787be5822806\gpo-preparation.json' `
        -ExpectedGpoId '8c6808fd-a382-4bf2-9c9c-d9e1d46082a3' `
        -ExpectedComputer 'DC01' -ExpectedDomain 'vizyonveri.local' `
        -InstanceId '4c23eebe-0715-46d1-88ee-a2e96ad7ee46' `
        -AccountName 'aw-deploy' `
        -AccountSid 'S-1-5-21-34256453-3348971241-2809240126-1648' `
        -ScopeGroupSid 'S-1-5-21-34256453-3348971241-2809240126-1647' `
        -ScopeGroupName 'AuthWire-Pilot-Computers' `
        -ProtectedGpoId 'e5a9ab39-3709-49cb-837a-0208d2eb3b12' `
        -BootstrapPath (Join-Path $env:TEMP 'AuthWire-Windows-Bootstrap-v1-r4.ps1') `
        -PublisherThumbprint $awPublisher
}
