# DC01 operator: one real startup/signature/cleanup acceptance after completed computer policy refresh; no new permissions or GPO edits.
$ErrorActionPreference = 'Stop'
$awTool = Join-Path $env:TEMP 'AuthWire-Service-Authenticode-Probe-v1.ps1'
$awSignature = Get-AuthenticodeSignature -FilePath $awTool
if ($awSignature.Status.ToString() -ne 'Valid' -or $awSignature.SignerCertificate.Thumbprint -ne '6E74B513F766E01730719684A41B2664380CA68A') {
    throw 'Test aracinin imzasi dogrulanamadi'
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
    PublisherThumbprint = '6E74B513F766E01730719684A41B2664380CA68A'
}
& $awTool @awParameters
