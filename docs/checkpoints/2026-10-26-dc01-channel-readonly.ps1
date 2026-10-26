#Requires -Version 5.1
[CmdletBinding()]
param()

# Site-specific observation only. No service, key, trust, AD or GPO writes.
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0
$blockers = New-Object 'System.Collections.Generic.List[string]'
$expectedSid = 'S-1-5-21-34256453-3348971241-2809240126-1648'
$connectorId = '4c23eebe-0715-46d1-88ee-a2e96ad7ee46'
$applianceId = '6796fa84-fcff-41c1-b9c5-d725b95ba139'
$signerThumb = 'FFC134BC305757457163F99C7479B4168E397129'
$expectedPin = 'a58838b95510f759943e5f1b7fefe29e227960a5c1171b5ebc6d5089df47a76d'
$fqdn = 'kaname.vizyonveri.local'
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'DC01 uzerinde yonetici PowerShell acin.'
}
$computer = Get-CimInstance Win32_ComputerSystem
if ($env:COMPUTERNAME -ine 'DC01' -or -not $computer.PartOfDomain -or
    $computer.Domain -ine 'vizyonveri.local' -or -not [Environment]::Is64BitProcess) {
    throw 'Bu kontrol yalniz DC01 uzerindeki 64-bit PowerShell icindir.'
}
Import-Module ActiveDirectory -ErrorAction Stop
$hostAd = Get-ADComputer -Server 'dc01.vizyonveri.local' -Identity 'DC01'
if ($hostAd.ObjectGUID.ToString() -ine '0fa4143f-aae3-4bc3-9cd3-db8a1de24acd') {
    throw 'CONNECTOR_HOST_GUID_MISMATCH'
}
$account = Get-ADServiceAccount -Server 'dc01.vizyonveri.local' -Identity 'aw-deploy'
$sidMatches = ($account.SID.Value -eq $expectedSid)
$accountReady = [bool](Test-ADServiceAccount -Identity 'aw-deploy' -ErrorAction Stop)
if (-not $sidMatches -or -not $accountReady) { $blockers.Add('GMSA_NOT_READY') }
$signer = Get-Item -LiteralPath ('Cert:\LocalMachine\My\' + $signerThumb) -ErrorAction SilentlyContinue
$signerPresent = ($null -ne $signer)
$signerCurrent = $false
$signerPrivateKey = $false
if ($signerPresent) {
    $signerCurrent = ($signer.NotBefore -le (Get-Date) -and $signer.NotAfter -gt (Get-Date))
    $signerPrivateKey = [bool]$signer.HasPrivateKey
}
if (-not $signerPresent -or -not $signerCurrent -or -not $signerPrivateKey) {
    $blockers.Add('MACHINE_SIGNER_NOT_READY')
}
$publisherTrusted = Test-Path -LiteralPath ('Cert:\LocalMachine\TrustedPublisher\' + $signerThumb)
if (-not $publisherTrusted) { $blockers.Add('MACHINE_PUBLISHER_NOT_TRUSTED') }
$tlsVerified = $false
$pinMatches = $false
$peerPin = $null
$tlsErrorType = $null
$client = $null
$ssl = $null
$peer = $null
$sha = $null
try {
    $client = New-Object Net.Sockets.TcpClient
    $connect = $client.ConnectAsync($fqdn, 8765)
    if (-not $connect.Wait(5000)) { throw 'CONNECT_TIMEOUT' }
    $connect.GetAwaiter().GetResult()
    $client.ReceiveTimeout = 10000
    $client.SendTimeout = 10000
    # No validation callback: Windows checks the chain and server name.
    $ssl = [Net.Security.SslStream]::new($client.GetStream(), $false)
    $ssl.ReadTimeout = 10000
    $ssl.WriteTimeout = 10000
    $ssl.AuthenticateAsClient($fqdn, [Security.Cryptography.X509Certificates.X509CertificateCollection]::new(),
        [Security.Authentication.SslProtocols]::Tls12, $true)
    $tlsVerified = $ssl.IsAuthenticated -and $ssl.IsEncrypted
    $peer = [Security.Cryptography.X509Certificates.X509Certificate2]::new($ssl.RemoteCertificate)
    $sha = [Security.Cryptography.SHA256]::Create()
    $peerPin = ([BitConverter]::ToString($sha.ComputeHash($peer.RawData))).Replace('-', '').ToLowerInvariant()
    $pinMatches = ($peerPin -ceq $expectedPin)
} catch {
    # Report the category, never credentials or a raw remote response.
    $tlsErrorType = $_.Exception.GetType().FullName
} finally {
    if ($null -ne $sha) { $sha.Dispose() }
    if ($null -ne $peer) { $peer.Dispose() }
    if ($null -ne $ssl) { $ssl.Dispose() }
    if ($null -ne $client) { $client.Dispose() }
}
if (-not $tlsVerified) { $blockers.Add('HTTPS_CHAIN_NAME_OR_CONNECTIVITY_CHECK_FAILED') }
elseif (-not $pinMatches) { $blockers.Add('APPLIANCE_TLS_PIN_MISMATCH') }
$idN = ([guid]$connectorId).ToString('N')
$keyRootExists = Test-Path -LiteralPath (Join-Path $env:ProgramData ('AuthWire-Connector-' + $idN))
$packageExists = Test-Path -LiteralPath (Join-Path $env:ProgramW6432 ('AuthWire-Connector-' + $idN))
$service = Get-Service -Name ('AuthWireConnector-' + $idN) -ErrorAction SilentlyContinue
if ($keyRootExists -or $packageExists -or $null -ne $service) {
    $blockers.Add('EXISTING_CHANNEL_OR_PACKAGE_REQUIRES_INSPECTION')
}
[pscustomobject]@{
    Event = 'WINDOWS_CONNECTOR_CHANNEL_READONLY_PREFLIGHT'
    ProbeVersion = '1.0.0'
    Computer = $env:COMPUTERNAME
    CheckedAtUtc = [datetime]::UtcNow.ToString('o')
    ConnectorId = $connectorId
    ApplianceInstanceId = $applianceId
    ServiceSidMatches = $sidMatches
    LocalAccountReady = $accountReady
    MachineSignerPresent = $signerPresent
    MachineSignerCurrent = $signerCurrent
    MachineSignerHasPrivateKey = $signerPrivateKey
    MachinePublisherTrusted = $publisherTrusted
    HttpsChainNameRevocationCheckPassed = $tlsVerified
    ApplianceTlsSha256 = $peerPin
    ApplianceTlsPinMatches = $pinMatches
    HttpsErrorType = $tlsErrorType
    ChannelDirectoryExists = $keyRootExists
    PackageDirectoryExists = $packageExists
    PermanentServiceExists = ($null -ne $service)
    Blockers = @($blockers.ToArray())
    ReadyForControlledPreparation = ($blockers.Count -eq 0)
    InspectedAs = $identity.Name
    GmsaHttpsTested = $false
    AdChanged = $false
    GpoChanged = $false
    KeyAclChanged = $false
    TrustStoreChanged = $false
    ServicesCreated = $false
    ChannelKeyCreated = $false
    SecretsExported = $false
    CanApplyGpo = $false
} | ConvertTo-Json -Depth 5
