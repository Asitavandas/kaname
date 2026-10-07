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
# Regression: production state files already exist on renewal, so replacement
# must overwrite them atomically on Windows PowerShell 5.1.
$stateFile=Join-Path $temp 'state.json';$stateTemp=$stateFile+'.tmp'
[IO.File]::WriteAllText($stateTemp,'{"value":1}',[Text.Encoding]::UTF8)
[AuthWireTls]::AtomicReplace($stateTemp,$stateFile)
[IO.File]::WriteAllText($stateTemp,'{"value":2}',[Text.Encoding]::UTF8)
[AuthWireTls]::AtomicReplace($stateTemp,$stateFile)
if((Get-Content $stateFile -Raw) -ne '{"value":2}') { throw 'Atomic state overwrite failed' }
$container='AuthWire-CI-'+[Guid]::NewGuid();$key=$null;$private=$null;$leaf=$null;$renewKey=$null;$renewPrivate=$null;$renewLeaf=$null
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
    # Match the GPO installer: trust this disposable fixture CA before accept.
    $fixtureTrust = @()
    foreach($entry in @(@('root-ca.pem','Root'),@('issuer-ca.pem','CA'))) {
        $ca = New-Object Security.Cryptography.X509Certificates.X509Certificate2((Join-Path $temp $entry[0]))
        $caStore = New-Object Security.Cryptography.X509Certificates.X509Store($entry[1],'LocalMachine')
        try { $caStore.Open('ReadWrite');$caStore.Add($ca) } finally { $caStore.Close() }
        $fixtureTrust += @{store=$entry[1];thumbprint=$ca.Thumbprint};$ca.Dispose()
    }
    & "$env:SystemRoot\System32\certreq.exe" -accept -machine -q (Join-Path $temp 'issued.pem')
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

    # Force the same server-side renewal condition as the panel's "Renew now".
    python -m tools.device_fixture --root $temp --step renew
    if($LASTEXITCODE -ne 0) { throw 'Server renewal request fixture failed' }

    # Release the predecessor signing handle before replacement-key creation,
    # matching the unattended renewal client.
    if($private) { $private.Dispose(); $private=$null }

    $renewContainer='AuthWire-CI-Renew-'+[Guid]::NewGuid()
    $renewInf=$inf.Replace('KeyContainer="'+$container+'"','KeyContainer="'+$renewContainer+'"')
    $renewInfFile=Join-Path $temp 'renew-request.inf';$renewCsrFile=Join-Path $temp 'renew-request.pem'
    [IO.File]::WriteAllText($renewInfFile,$renewInf,[Text.Encoding]::ASCII)
    & "$env:SystemRoot\System32\certreq.exe" -new -machine -q -f $renewInfFile $renewCsrFile | Out-Null
    if($LASTEXITCODE -ne 0) { throw 'Renewal CNG CSR creation failed' }
    $renewCsr=(Get-Content $renewCsrFile -Raw).Replace('BEGIN NEW CERTIFICATE REQUEST','BEGIN CERTIFICATE REQUEST').Replace('END NEW CERTIFICATE REQUEST','END CERTIFICATE REQUEST')
    [IO.File]::WriteAllText($renewCsrFile,$renewCsr,[Text.Encoding]::ASCII)
    $renewKey=[Security.Cryptography.CngKey]::Open($renewContainer,[Security.Cryptography.CngProvider]::MicrosoftSoftwareKeyStorageProvider,[Security.Cryptography.CngKeyOpenOptions]::MachineKey)
    if($renewKey.ExportPolicy -ne [Security.Cryptography.CngExportPolicies]::None) { throw 'Renewal private key export permitted' }
    $renewPrivate=New-Object Security.Cryptography.RSACng($renewKey)

    python -m tools.device_fixture --root $temp --step renew-challenge
    if($LASTEXITCODE -ne 0) { throw 'Renewal challenge failed' }
    $renewChallenge=Get-Content (Join-Path $temp 'renew-challenge.json') -Raw | ConvertFrom-Json
    $renewProof=$renewPrivate.SignData([Convert]::FromBase64String($renewChallenge.payload),[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1)
    [IO.File]::WriteAllText((Join-Path $temp 'renew-proof.txt'),[Convert]::ToBase64String($renewProof),[Text.Encoding]::ASCII)

    python -m tools.device_fixture --root $temp --step renew-issue
    if($LASTEXITCODE -ne 0) { throw 'Renewal issuance failed' }
    & "$env:SystemRoot\System32\certreq.exe" -accept -machine -q (Join-Path $temp 'renew-issued.pem')
    if($LASTEXITCODE -ne 0) { throw 'Renewal machine certificate installation failed' }
    $renewLeaf=New-Object Security.Cryptography.X509Certificates.X509Certificate2((Join-Path $temp 'renew-issued.pem'))
    $renewInstalled=Get-Item ('Cert:\LocalMachine\My\'+$renewLeaf.Thumbprint)
    if(!$renewInstalled.HasPrivateKey) { throw 'Renewal leaf lacks the CNG private key' }
    $renewIssued=Get-Content (Join-Path $temp 'renew-issued.json') -Raw | ConvertFrom-Json
    $renewInstalledPrivate=[Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($renewInstalled)
    try { $renewReceiptProof=$renewInstalledPrivate.SignData([Convert]::FromBase64String($renewIssued.receipt_payload),[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1) } finally { $renewInstalledPrivate.Dispose() }
    [IO.File]::WriteAllText((Join-Path $temp 'renew-receipt-proof.txt'),[Convert]::ToBase64String($renewReceiptProof),[Text.Encoding]::ASCII)
    python -m tools.device_fixture --root $temp --step renew-receipt
    if($LASTEXITCODE -ne 0) { throw 'Renewal installed-key receipt rejected' }

    # Successful cutover must not destroy the predecessor immediately.
    if(!(Get-Item ('Cert:\LocalMachine\My\'+$leaf.Thumbprint) -ErrorAction SilentlyContinue)) { throw 'Predecessor certificate removed before retirement window' }
    Write-Output 'Native Windows initial enrollment and second CNG certificate renewal both passed.'
} finally {
    if($renewLeaf) { Remove-Item ('Cert:\LocalMachine\My\'+$renewLeaf.Thumbprint) -ErrorAction SilentlyContinue;$renewLeaf.Dispose() }
    if($leaf) { Remove-Item ('Cert:\LocalMachine\My\'+$leaf.Thumbprint) -ErrorAction SilentlyContinue;$leaf.Dispose() }
    if($renewPrivate) { $renewPrivate.Dispose() }
    if($renewKey) { $renewKey.Delete();$renewKey.Dispose() }
    if($private) { $private.Dispose() }
    if($key) { $key.Delete();$key.Dispose() }
    foreach($ca in @($fixtureTrust)) {
        if($ca) { Remove-Item ('Cert:\LocalMachine\'+$ca.store+'\'+$ca.thumbprint) -ErrorAction SilentlyContinue }
    }
    Remove-Item $temp -Recurse -Force
}
