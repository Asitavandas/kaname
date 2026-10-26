#Requires -Version 5.1
[CmdletBinding()]
param([ValidateSet('Inspect','PrepareTrust')][string]$Mode = 'Inspect')
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

function Get-AuthWirePublicCertificateHash {
    param([Security.Cryptography.X509Certificates.X509Certificate2]$Certificate)
    $sha = [Security.Cryptography.SHA256]::Create()
    try { ([BitConverter]::ToString($sha.ComputeHash($Certificate.RawData))).Replace('-', '').ToLowerInvariant() }
    finally { $sha.Dispose() }
}

function Assert-AuthWirePublicTrustCertificate {
    param([Security.Cryptography.X509Certificates.X509Certificate2]$Certificate,
        [ValidateSet('Root','TrustedPublisher')][string]$StoreName,
        [string]$ExpectedSha256)
    if ($ExpectedSha256 -cnotmatch '^[a-f0-9]{64}$' -or
        (Get-AuthWirePublicCertificateHash $Certificate) -cne $ExpectedSha256) { throw 'PUBLIC_CERTIFICATE_SHA256_MISMATCH' }
    if ($Certificate.NotBefore -gt (Get-Date) -or $Certificate.NotAfter -le (Get-Date)) { throw 'PUBLIC_CERTIFICATE_NOT_CURRENT' }
    $eku = @($Certificate.Extensions | Where-Object { $_.Oid.Value -eq '2.5.29.37' })
    if ($eku.Count -ne 1) { throw 'EXPLICIT_EKU_REQUIRED' }
    $purposes = @($eku[0].EnhancedKeyUsages | ForEach-Object { $_.Value })
    $required = '1.3.6.1.5.5.7.3.3'
    if ($StoreName -eq 'Root') {
        $required = '1.3.6.1.5.5.7.3.1'
        if ($Certificate.Subject -cne $Certificate.Issuer) { throw 'PINNED_SELF_ISSUED_WEB_CERTIFICATE_REQUIRED' }
        $bc = @($Certificate.Extensions | Where-Object { $_.Oid.Value -eq '2.5.29.19' })
        if ($bc.Count -ne 1 -or $bc[0].CertificateAuthority) { throw 'WEB_END_ENTITY_CERTIFICATE_REQUIRED' }
    }
    if ($purposes.Count -ne 1 -or $purposes[0] -cne $required) { throw 'EXACT_CERTIFICATE_PURPOSE_REQUIRED' }
}

function Get-AuthWirePublicTrustSnapshot {
    param([ValidateSet('Root','TrustedPublisher')][string]$StoreName)
    $store = [Security.Cryptography.X509Certificates.X509Store]::new($StoreName,
        [Security.Cryptography.X509Certificates.StoreLocation]::LocalMachine)
    try {
        $store.Open([Security.Cryptography.X509Certificates.OpenFlags]::ReadOnly -bor
            [Security.Cryptography.X509Certificates.OpenFlags]::OpenExistingOnly)
        foreach ($item in $store.Certificates) { Get-AuthWirePublicCertificateHash $item }
    } finally { $store.Close() }
}

function Add-AuthWireExactPublicTrust {
    param([Security.Cryptography.X509Certificates.X509Certificate2]$Certificate,
        [ValidateSet('Root','TrustedPublisher')][string]$StoreName,[string]$ExpectedSha256)
    Assert-AuthWirePublicTrustCertificate $Certificate $StoreName $ExpectedSha256
    $before = @(Get-AuthWirePublicTrustSnapshot $StoreName)
    if ($before -contains $ExpectedSha256) { return $false }
    # RawData contains the public certificate only, never a private key.
    $publicCopy = [Security.Cryptography.X509Certificates.X509Certificate2]::new($Certificate.RawData)
    $store = [Security.Cryptography.X509Certificates.X509Store]::new($StoreName,
        [Security.Cryptography.X509Certificates.StoreLocation]::LocalMachine)
    try {
        if ($publicCopy.HasPrivateKey) { throw 'PUBLIC_COPY_UNEXPECTED_PRIVATE_KEY' }
        $store.Open([Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite -bor
            [Security.Cryptography.X509Certificates.OpenFlags]::OpenExistingOnly)
        $store.Add($publicCopy)
    } finally { $store.Close(); $publicCopy.Dispose() }
    $after = @(Get-AuthWirePublicTrustSnapshot $StoreName)
    if ($after -notcontains $ExpectedSha256) { throw 'PUBLIC_TRUST_ADDITION_NOT_VISIBLE' }
    foreach ($prior in $before) {
        if ($after -notcontains $prior) { throw 'PREEXISTING_TRUST_ENTRY_MISSING_REVIEW_REQUIRED' }
    }
    return $true
}

function Assert-AuthWireMachineSigningChain {
    param([Security.Cryptography.X509Certificates.X509Certificate2]$Certificate)
    $chain = [Security.Cryptography.X509Certificates.X509Chain]::new($true)
    try {
        $chain.ChainPolicy.RevocationMode = 'Online'
        $chain.ChainPolicy.RevocationFlag = 'ExcludeRoot'
        $chain.ChainPolicy.VerificationFlags = 'NoFlag'
        $chain.ChainPolicy.UrlRetrievalTimeout = [timespan]::FromSeconds(15)
        $null = $chain.ChainPolicy.ApplicationPolicy.Add([Security.Cryptography.Oid]::new('1.3.6.1.5.5.7.3.3'))
        if (-not $chain.Build($Certificate)) {
            $status = @($chain.ChainStatus | ForEach-Object { $_.Status.ToString() }) -join ','
            throw ('MACHINE_SIGNING_CHAIN_INVALID:' + $status)
        }
        $root = $chain.ChainElements[$chain.ChainElements.Count - 1].Certificate
        if ($root.Thumbprint -ine '4D6D3C94B878B75AE02B436C0A19D3A3104C68BB') { throw 'MACHINE_SIGNING_ISSUER_ROOT_MISMATCH' }
    } finally { $chain.Dispose() }
}

function New-AuthWireTrustReceiptDirectory {
    $parent = Get-Item -LiteralPath $env:ProgramData -Force
    if (($parent.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'PROGRAMDATA_REPARSE_POINT' }
    $path = Join-Path $parent.FullName ('AuthWire-ConnectorTrust-' + [guid]::NewGuid().ToString('N'))
    if (Test-Path -LiteralPath $path) { throw 'RECEIPT_PATH_ALREADY_EXISTS' }
    $acl = [Security.AccessControl.DirectorySecurity]::new()
    $acl.SetAccessRuleProtection($true, $false)
    $admin = [Security.Principal.SecurityIdentifier]::new('S-1-5-32-544')
    $acl.SetOwner($admin)
    $acl.SetGroup($admin)
    foreach ($sid in @('S-1-5-18','S-1-5-32-544')) {
        $rule = [Security.AccessControl.FileSystemAccessRule]::new(
            [Security.Principal.SecurityIdentifier]::new($sid), 'FullControl',
            'ContainerInherit,ObjectInherit', 'None', 'Allow')
        $null = $acl.AddAccessRule($rule)
    }
    $null = [IO.Directory]::CreateDirectory($path, $acl)
    return $path
}

# The next section embeds only the public web certificate whose SHA256 was
# established by the operator's protected dev.35 appliance metadata and matched
# independently by DC01. No certificate is fetched from an untrusted URL here.
$webBase64 = 'MIIBlTCCATugAwIBAgIUc0XfQeAWr/pCszl4TQAt5ayvJLAwCgYIKoZIzj0EAwIwIjEgMB4GA1UEAwwXa2FuYW1lLnZpenlvbnZlcmkubG9jYWwwHhcNMjYxMDA0MTY0NzI5WhcNMjcxMDA0MTY1MjI5WjAiMSAwHgYDVQQDDBdrYW5hbWUudml6eW9udmVyaS5sb2NhbDBZMBMGByqGSM49AgEGCCqGSM49AwEHA0IABNm6vQcjGFBhLOzf2Cn1KRRkv9eN0y0c/8utFqumRnVjiFpB3fINy2rnw5+pXbuXbwB7HXte4eFeCsJ3eLR0F72jTzBNMCgGA1UdEQQhMB+CF2thbmFtZS52aXp5b252ZXJpLmxvY2FshwQKIzL2MAwGA1UdEwEB/wQCMAAwEwYDVR0lBAwwCgYIKwYBBQUHAwEwCgYIKoZIzj0EAwIDSAAwRQIhAL4AfD71r+mi93JeJa06eziv4pw1rM8wguQ+APli6i8dAiAffJMSRMCFHP1gizYkcSPO3KbVSO667U8MLDV4/ygvGA=='
$webSha256 = 'a58838b95510f759943e5f1b7fefe29e227960a5c1171b5ebc6d5089df47a76d'
$signerThumbprint = 'FFC134BC305757457163F99C7479B4168E397129'
$web = $null
$signer = $null
$receiptDirectory = $null
$phase = 'preflight'
$result = [ordered]@{
    Event = 'WINDOWS_CONNECTOR_TRUST_PREPARATION'
    ToolVersion = '1.0.0'
    Mode = $Mode
    Computer = $env:COMPUTERNAME
    CheckedAtUtc = [datetime]::UtcNow.ToString('o')
    Stage = 'preflight'
    WebCertificateSha256 = $webSha256
    MachinePublisherThumbprint = $signerThumbprint
    WebTrustAddedNow = $false
    PublisherTrustAddedNow = $false
    MachineWebTrustPresent = $false
    MachinePublisherTrusted = $false
    ExistingTrustEntriesPreserved = $false
    HttpsVerifiedAfterPreparation = $false
    Tls = $null
    ReceiptPath = $null
    Error = $null
    GmsaHttpsTested = $false
    AdChanged = $false
    GpoChanged = $false
    KeyAclChanged = $false
    CertificatesIssued = $false
    ServicesCreated = $false
    SecretsExported = $false
    CanApplyGpo = $false
}
try {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { throw 'ELEVATED_ADMINISTRATOR_REQUIRED' }
    $computer = Get-CimInstance Win32_ComputerSystem
    if ($env:COMPUTERNAME -ine 'DC01' -or -not $computer.PartOfDomain -or
        $computer.Domain -ine 'vizyonveri.local' -or -not [Environment]::Is64BitProcess) { throw 'EXPECTED_DC01_X64_DOMAIN_HOST_REQUIRED' }
Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Net;
using System.Net.Security;
using System.Net.Sockets;
using System.Security.Authentication;
using System.Security.Cryptography;
using System.Security.Cryptography.X509Certificates;

namespace AuthWire.Diagnostics {
    public sealed class TlsObservation {
        public bool TcpConnected;
        public bool ValidationCallbackReached;
        public string PolicyErrors;
        public readonly List<string> ChainStatus = new List<string>();
        public readonly List<string> ChainElements = new List<string>();
        public string Subject;
        public string Issuer;
        public string DnsName;
        public string NotBeforeUtc;
        public string NotAfterUtc;
        public string LeafSha256;
        public bool LeafPinMatches;
        public bool NormalValidationPassed;
        public bool TlsHandshakePassed;
        public readonly List<string> Exceptions = new List<string>();
    }

    public static class TlsProbeV1 {
        public static TlsObservation Run() {
            const string host = "kaname.vizyonveri.local";
            const string pin = "a58838b95510f759943e5f1b7fefe29e227960a5c1171b5ebc6d5089df47a76d";
            TlsObservation result = new TlsObservation();
            try {
                using (TcpClient client = new TcpClient()) {
                    if (!client.ConnectAsync(host, 8765).Wait(5000))
                        throw new TimeoutException("TCP connection timeout");
                    result.TcpConnected = client.Connected;
                    client.ReceiveTimeout = 10000;
                    client.SendTimeout = 10000;
                    RemoteCertificateValidationCallback validate = delegate(object sender,
                        X509Certificate certificate, X509Chain chain, SslPolicyErrors errors) {
                        result.ValidationCallbackReached = true;
                        result.PolicyErrors = errors.ToString();
                        result.NormalValidationPassed = errors == SslPolicyErrors.None;
                        if (chain != null) {
                            foreach (X509ChainStatus status in chain.ChainStatus)
                                result.ChainStatus.Add(status.Status + ": " + status.StatusInformation.Trim());
                            foreach (X509ChainElement element in chain.ChainElements) {
                                List<string> statuses = new List<string>();
                                foreach (X509ChainStatus status in element.ChainElementStatus)
                                    statuses.Add(status.Status.ToString());
                                result.ChainElements.Add(element.Certificate.Subject + " | " +
                                    element.Certificate.Thumbprint + " | " + String.Join(",", statuses));
                            }
                        }
                        if (certificate != null) {
                            using (X509Certificate2 leaf = new X509Certificate2(certificate)) {
                                result.Subject = leaf.Subject;
                                result.Issuer = leaf.Issuer;
                                result.DnsName = leaf.GetNameInfo(X509NameType.DnsName, false);
                                result.NotBeforeUtc = leaf.NotBefore.ToUniversalTime().ToString("o");
                                result.NotAfterUtc = leaf.NotAfter.ToUniversalTime().ToString("o");
                                using (SHA256 sha = SHA256.Create())
                                    result.LeafSha256 = BitConverter.ToString(sha.ComputeHash(leaf.RawData))
                                        .Replace("-", "").ToLowerInvariant();
                                result.LeafPinMatches = String.Equals(result.LeafSha256, pin, StringComparison.Ordinal);
                            }
                        }
                        // Pin alone never authorizes an invalid Windows chain/name.
                        return result.NormalValidationPassed && result.LeafPinMatches;
                    };
                    using (SslStream ssl = new SslStream(client.GetStream(), false, validate)) {
                        ssl.ReadTimeout = 10000;
                        ssl.WriteTimeout = 10000;
                        ssl.AuthenticateAsClient(host, new X509CertificateCollection(), SslProtocols.Tls12, true);
                        result.TlsHandshakePassed = ssl.IsAuthenticated && ssl.IsEncrypted;
                    }
                }
            } catch (Exception error) {
                for (Exception item = error; item != null; item = item.InnerException)
                    result.Exceptions.Add(item.GetType().FullName + " [" + item.HResult + "]: " + item.Message);
            }
            return result;
        }
    }
}
'@
    $web = [Security.Cryptography.X509Certificates.X509Certificate2]::new([Convert]::FromBase64String($webBase64))
    Assert-AuthWirePublicTrustCertificate $web 'Root' $webSha256
    if ($web.Thumbprint -ine '06AC51AF9AB4F7EBAFD3EA89E55BDD191E289636' -or
        $web.GetNameInfo([Security.Cryptography.X509Certificates.X509NameType]::DnsName, $false) -cne 'kaname.vizyonveri.local') {
        throw 'WEB_CERTIFICATE_IDENTITY_MISMATCH'
    }
    $signer = Get-Item -LiteralPath ('Cert:\LocalMachine\My\' + $signerThumbprint)
    if (-not $signer.HasPrivateKey -or $signer.Subject -cne 'CN=dc01.vizyonveri.local') { throw 'EXPECTED_LOCAL_MACHINE_SIGNER_REQUIRED' }
    $signerHash = Get-AuthWirePublicCertificateHash $signer
    Assert-AuthWirePublicTrustCertificate $signer 'TrustedPublisher' $signerHash
    Assert-AuthWireMachineSigningChain $signer
    $rootBefore = @(Get-AuthWirePublicTrustSnapshot 'Root')
    $publishersBefore = @(Get-AuthWirePublicTrustSnapshot 'TrustedPublisher')
    $result.MachineWebTrustPresent = ($rootBefore -contains $webSha256)
    $result.MachinePublisherTrusted = ($publishersBefore -contains $signerHash)
    $result.ExistingTrustEntriesPreserved = $true
    if ($Mode -eq 'PrepareTrust') {
        $receiptDirectory = New-AuthWireTrustReceiptDirectory
        $result.ReceiptPath = Join-Path $receiptDirectory 'trust-preparation.json'
        $before = [ordered]@{ Phase='before'; WebSha256=$webSha256; SignerSha256=$signerHash;
            Root=$rootBefore; TrustedPublisher=$publishersBefore; CheckedAtUtc=$result.CheckedAtUtc }
        [IO.File]::WriteAllText((Join-Path $receiptDirectory 'before.json'), ($before | ConvertTo-Json -Depth 4), [Text.UTF8Encoding]::new($false))
        $phase = 'public_trust_addition'
        $result.WebTrustAddedNow = Add-AuthWireExactPublicTrust $web 'Root' $webSha256
        $result.PublisherTrustAddedNow = Add-AuthWireExactPublicTrust $signer 'TrustedPublisher' $signerHash
        $rootAfter = @(Get-AuthWirePublicTrustSnapshot 'Root')
        $publishersAfter = @(Get-AuthWirePublicTrustSnapshot 'TrustedPublisher')
        $result.MachineWebTrustPresent = ($rootAfter -contains $webSha256)
        $result.MachinePublisherTrusted = ($publishersAfter -contains $signerHash)
        foreach ($prior in $rootBefore) { if ($rootAfter -notcontains $prior) { throw 'PREEXISTING_ROOT_MISSING' } }
        foreach ($prior in $publishersBefore) { if ($publishersAfter -notcontains $prior) { throw 'PREEXISTING_PUBLISHER_MISSING' } }
        $phase = 'https_postcheck'
        $result.Tls = [AuthWire.Diagnostics.TlsProbeV1]::Run()
        $result.HttpsVerifiedAfterPreparation = $result.Tls.TlsHandshakePassed -and
            $result.Tls.NormalValidationPassed -and $result.Tls.LeafPinMatches
        if (-not $result.HttpsVerifiedAfterPreparation) { throw 'HTTPS_POSTCHECK_REQUIRES_REVIEW' }
        $result.Stage = 'prepared'
    } else { $result.Stage = 'inspected' }
} catch {
    $result.Stage = $phase + '_requires_review'
    $result.Error = $_.Exception.GetBaseException().Message
} finally {
    if ($null -ne $web) { $web.Dispose() }
    if ($null -ne $receiptDirectory) {
        [IO.File]::WriteAllText($result.ReceiptPath, ($result | ConvertTo-Json -Depth 7), [Text.UTF8Encoding]::new($false))
    }
}
$result | ConvertTo-Json -Depth 7
