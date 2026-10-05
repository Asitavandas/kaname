# Disposable CI machine only. No AD/DC/network requests or customer state.
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '..\kaname\device_client\AuthWire-Client.ps1') -ValidateOnly
# Both scripts must parse in Windows PowerShell 5.1; SSPI P/Invoke must compile.
foreach($name in @('AuthWire-Client.ps1','Install-AuthWire.ps1')) {
    $tokens=$null;$errors=$null
    $null=[Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot ('..\kaname\device_client\'+$name)),[ref]$tokens,[ref]$errors)
    if($errors.Count) { throw ($errors | Out-String) }
}
$temp=Join-Path $env:TEMP ('authwire-ci-'+[Guid]::NewGuid())
$null=New-Item $temp -ItemType Directory
$null=New-Item (Join-Path $temp 'CI_FIXTURE_ONLY') -ItemType File
$container='AuthWire-CI-'+[Guid]::NewGuid();$key=$null;$private=$null;$leaf=$null
try {
    # Identical native CertReq settings to the unattended client.
    $inf=@"
[Version]
Signature="`$Windows NT`$"
[NewRequest]
Subject="CN=AuthWire computer request"
KeyAlgorithm=RSA
KeyLength=2048
HashAlgorithm=sha256
Exportable=FALSE
MachineKeySet=TRUE
ProviderName="Microsoft Software Key Storage Provider"
KeyContainer="$container"
RequestType=PKCS10
SuppressDefaults=TRUE
"@
    $infFile=Join-Path $temp 'request.inf';$csrFile=Join-Path $temp 'request.pem'
    [IO.File]::WriteAllText($infFile,$inf,[Text.Encoding]::ASCII)
    & "$env:SystemRoot\System32\certreq.exe" -new -machine -q -f $infFile $csrFile | Out-Null
    if($LASTEXITCODE -ne 0) { throw 'CNG CSR creation failed' }
    $csr=(Get-Content $csrFile -Raw).Replace('BEGIN NEW CERTIFICATE REQUEST','BEGIN CERTIFICATE REQUEST').Replace('END NEW CERTIFICATE REQUEST','END CERTIFICATE REQUEST')
    [IO.File]::WriteAllText($csrFile,$csr,[Text.Encoding]::ASCII)
    $key=[Security.Cryptography.CngKey]::Open($container,[Security.Cryptography.CngProvider]::MicrosoftSoftwareKeyStorageProvider,[Security.Cryptography.CngKeyOpenOptions]::MachineKey)
    if($key.ExportPolicy -ne [Security.Cryptography.CngExportPolicies]::None) { throw 'Private key export permitted' }
    $private=New-Object Security.Cryptography.RSACng($key)
    $exported=$false
    try { $null=$private.ExportParameters($true);$exported=$true } catch [Security.Cryptography.CryptographicException] {}
    if($exported) { throw 'Private key unexpectedly exported' }
    python -m tools.device_fixture --root $temp --step challenge
    if($LASTEXITCODE -ne 0) { throw 'Strict server CSR parser rejected native CNG request' }
    $challenge=Get-Content (Join-Path $temp 'challenge.json') -Raw | ConvertFrom-Json
    $proof=$private.SignData([Convert]::FromBase64String($challenge.payload),[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1)
    [IO.File]::WriteAllText((Join-Path $temp 'proof.txt'),[Convert]::ToBase64String($proof),[Text.Encoding]::ASCII)
    python -m tools.device_fixture --root $temp --step issue
    if($LASTEXITCODE -ne 0) { throw 'Native key challenge proof rejected' }
    & "$env:SystemRoot\System32\certreq.exe" -accept -machine -q (Join-Path $temp 'issued.pem') | Out-Null
    if($LASTEXITCODE -ne 0) { throw 'Native machine certificate installation failed' }
    $leaf=New-Object Security.Cryptography.X509Certificates.X509Certificate2((Join-Path $temp 'issued.pem'))
    $installed=Get-Item ('Cert:\LocalMachine\My\'+$leaf.Thumbprint)
    if(!$installed.HasPrivateKey) { throw 'Installed leaf lacks the CNG private key' }
    $issued=Get-Content (Join-Path $temp 'issued.json') -Raw | ConvertFrom-Json
    $installedPrivate=[Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($installed)
    try { $proof=$installedPrivate.SignData([Convert]::FromBase64String($issued.receipt_payload),[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1) } finally { $installedPrivate.Dispose() }
    [IO.File]::WriteAllText((Join-Path $temp 'receipt-proof.txt'),[Convert]::ToBase64String($proof),[Text.Encoding]::ASCII)
    python -m tools.device_fixture --root $temp --step receipt
    if($LASTEXITCODE -ne 0) { throw 'Installed private-key receipt rejected' }
    Write-Output 'Native Windows CSR, nonexportable CNG key, proof and machine-store receipt passed. Domain SSPI pilot remains required.'
} finally {
    if($leaf) { Remove-Item ('Cert:\LocalMachine\My\'+$leaf.Thumbprint) -ErrorAction SilentlyContinue;$leaf.Dispose() }
    if($private) { $private.Dispose() }
    if($key) { $key.Delete();$key.Dispose() }
    Remove-Item $temp -Recurse -Force
}
