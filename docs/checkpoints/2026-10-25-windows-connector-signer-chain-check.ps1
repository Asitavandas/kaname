# DC01 elevated operator readonly certificate verification with public-input thumbprint pin and retained log. No automatic trust import or package rollout.
$ErrorActionPreference = 'Stop'
$awFolder = 'C:\ProgramData\AuthWire-SigningTemplate-b05c01482d03415897d290ccde085a37'
$awCer = Join-Path $awFolder 'machine-signing-v2.cer'
$awLog = Join-Path $awFolder 'machine-signing-v2-chain-verify.log'
$awCertificate = [Security.Cryptography.X509Certificates.X509Certificate2]::new($awCer)
try {
    if ($awCertificate.Thumbprint -ne 'FFC134BC305757457163F99C7479B4168E397129') {
        throw 'Beklenen imzalama sertifikasi eslesmedi'
    }
} finally {
    $awCertificate.Dispose()
}

& "$env:SystemRoot\System32\certutil.exe" -verify -urlfetch $awCer |
    Tee-Object -FilePath $awLog
$awVerifyExit = $LASTEXITCODE

[pscustomobject]@{
    Event = 'WINDOWS_CONNECTOR_SIGNER_CHAIN_CHECK_RETURNED'
    CertutilExitCode = $awVerifyExit
    LogFile = $awLog
    KeyAclChanged = $false
    TrustStoreChanged = $false
} | ConvertTo-Json
