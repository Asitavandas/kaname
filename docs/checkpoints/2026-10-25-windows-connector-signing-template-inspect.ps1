# Operator command: run in elevated Windows PowerShell 5.1 on DC01.
# Transfers public tool, pins bytes, signs with existing corporate publisher, then readonly Inspect.
$ErrorActionPreference = 'Stop'
$awTool = Join-Path $env:TEMP 'AuthWire-Signing-Template-Prepare-v1.ps1'
$awPublisher = '6E74B513F766E01730719684A41B2664380CA68A'

scp 'segmentiq@10.35.50.246:/home/segmentiq/authwire-signing-template-prepare-v1-20261025.ps1' $awTool
if ($LASTEXITCODE -ne 0) { throw 'Dosya aktarilamadi' }
if ((Get-FileHash -LiteralPath $awTool -Algorithm SHA256).Hash -ne '4aa6373aa7ec4fd4c6f8a1bbd9be42a419bacf7c231a46d186cae20dcbe0d953') {
    throw 'Dosya dogrulamasi basarisiz'
}
$awCert = Get-Item ('Cert:\CurrentUser\My\' + $awPublisher)
$awSignature = Set-AuthenticodeSignature -FilePath $awTool -Certificate $awCert -HashAlgorithm SHA256
if ($awSignature.Status.ToString() -ne 'Valid' -or $awSignature.SignerCertificate.Thumbprint -ne $awPublisher) {
    throw 'Imza dogrulamasi basarisiz'
}
$awParameters = @{
    Mode                = 'Inspect'
    ExpectedComputer    = 'DC01'
    ExpectedDomain      = 'vizyonveri.local'
    InstanceId          = '4c23eebe-0715-46d1-88ee-a2e96ad7ee46'
    AccountName         = 'aw-deploy'
    AccountSid          = 'S-1-5-21-34256453-3348971241-2809240126-1648'
    SourceTemplateName  = 'AuthWireGPOCodeSigning'
    ExpectedCaName      = 'vizyonveri-DC01-CA'
    BootstrapPath       = Join-Path $env:TEMP 'AuthWire-Windows-Bootstrap-v1-r4.ps1'
    ReadinessToolPath   = Join-Path $env:TEMP 'AuthWire-Signing-Readiness-v1-r2.ps1'
    PublisherThumbprint = $awPublisher
}
& $awTool @awParameters
