#Requires -Version 5.1
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0
if ($env:COMPUTERNAME -ine 'DC01') { throw 'Bu kontrol DC01 uzerinde calistirilmali.' }

# Capture normal Windows validation errors in C#, without a PowerShell callback
# on a thread that may not have a runspace. Every validation error is rejected.
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
$probe = [AuthWire.Diagnostics.TlsProbeV1]::Run()
$addresses = @()
$dnsError = $null
try {
    $addresses = @([Net.Dns]::GetHostAddresses('kaname.vizyonveri.local') | ForEach-Object { $_.IPAddressToString })
} catch { $dnsError = $_.Exception.GetBaseException().Message }
[pscustomobject]@{
    Event = 'WINDOWS_CONNECTOR_TLS_DIAGNOSTIC_READONLY'
    ProbeVersion = '1.0.0'
    Computer = $env:COMPUTERNAME
    CheckedAtUtc = [datetime]::UtcNow.ToString('o')
    ResolvedAddresses = $addresses
    DnsError = $dnsError
    Tls = $probe
    InspectedAs = [Security.Principal.WindowsIdentity]::GetCurrent().Name
    GmsaHttpsTested = $false
    AdChanged = $false
    GpoChanged = $false
    TrustStoreChanged = $false
    KeyAclChanged = $false
    ServicesCreated = $false
    HttpRequestsSent = $false
    SecretsExported = $false
} | ConvertTo-Json -Depth 7
