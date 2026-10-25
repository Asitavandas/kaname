# Operator on elevated DC01 Windows PowerShell. Creates and removes only an owned temporary service; actual gMSA signing output is still pending.
$ErrorActionPreference = 'Stop'
$awTool = Join-Path $env:TEMP 'AuthWire-Service-Signing-Probe-v1.ps1'
$awPublisher = '6E74B513F766E01730719684A41B2664380CA68A'

scp 'segmentiq@10.35.50.246:/home/segmentiq/authwire-service-signing-probe-v1-20261025.ps1' $awTool
if ($LASTEXITCODE -ne 0) { throw 'Dosya aktarilamadi' }
if ((Get-FileHash -LiteralPath $awTool -Algorithm SHA256).Hash -ne '85a21def1fcbcd542d599c7d7d71acb74ab3f2cc6f2704dbcd3e4c027b2d0152') {
    throw 'Dosya dogrulamasi basarisiz'
}
$awCertificate = Get-Item ('Cert:\CurrentUser\My\' + $awPublisher)
$awSignature = Set-AuthenticodeSignature -FilePath $awTool -Certificate $awCertificate -HashAlgorithm SHA256
if ($awSignature.Status.ToString() -ne 'Valid' -or $awSignature.SignerCertificate.Thumbprint -ne $awPublisher) {
    throw 'Imza dogrulamasi basarisiz'
}
$awParameters = @{
    Mode = 'RunProbe'
    ExpectedComputer = 'DC01'
    ExpectedDomain = 'vizyonveri.local'
    InstanceId = '4c23eebe-0715-46d1-88ee-a2e96ad7ee46'
    AccountName = 'aw-deploy'
    AccountSid = 'S-1-5-21-34256453-3348971241-2809240126-1648'
    BootstrapPath = Join-Path $env:TEMP 'AuthWire-Windows-Bootstrap-v1-r4.ps1'
    RightsToolPath = Join-Path $env:TEMP 'AuthWire-Service-Right-Prepare-v1.ps1'
    SignerThumbprint = 'FFC134BC305757457163F99C7479B4168E397129'
    KeyAccessReceiptPath = 'C:\ProgramData\AuthWire-SigningTemplate-b05c01482d03415897d290ccde085a37\machine-signing-v2-key-access-verified.json'
    PublisherThumbprint = $awPublisher
}
& $awTool @awParameters
