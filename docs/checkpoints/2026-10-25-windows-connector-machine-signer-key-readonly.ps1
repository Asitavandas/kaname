# DC01 elevated operator metadata read. Opens exact machine RSA key for property reads only; no export/sign/ACL mutation. Live result pending.
$ErrorActionPreference = 'Stop'
if ($env:COMPUTERNAME -ine 'DC01') { throw 'DC01 uzerinde calistirilmali' }
$awFolder = 'C:\ProgramData\AuthWire-SigningTemplate-b05c01482d03415897d290ccde085a37'
$awThumb = 'FFC134BC305757457163F99C7479B4168E397129'
$awExpectedOid = '1.3.6.1.4.1.311.21.8.3959278.2860114.5195160.9103069.14061966.47.142634815.777644557.3157432960.2289567679'
$awCert = Get-Item -LiteralPath ('Cert:\LocalMachine\My\' + $awThumb)
$awExtensions = @($awCert.Extensions | Where-Object { $_.Oid.Value -eq '1.3.6.1.4.1.311.21.7' })
if ($awExtensions.Count -ne 1) { throw 'Sertifika sablon uzantisi beklenen sekilde degil' }
$awDecoder = New-Object -ComObject X509Enrollment.CX509ExtensionTemplate
try {
    $awDecoder.InitializeDecode(1, [Convert]::ToBase64String($awExtensions[0].RawData))
    $awTemplateOid = [string]$awDecoder.TemplateOid.Value
} finally {
    $null = [Runtime.InteropServices.Marshal]::FinalReleaseComObject($awDecoder)
}
if ($awTemplateOid -ne $awExpectedOid) { throw 'Sertifika farkli bir sablondan uretilmis' }

$awRsa = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($awCert)
try {
    if ($awRsa -isnot [Security.Cryptography.RSACng]) { throw 'Beklenen CNG RSA anahtari bulunamadi' }
    $awKey = $awRsa.Key
    $awResult = [pscustomobject]@{
        Event = 'WINDOWS_CONNECTOR_MACHINE_SIGNER_KEY_READONLY'
        Thumbprint = $awThumb
        TemplateOidMatches = ($awTemplateOid -eq $awExpectedOid)
        Provider = $awKey.Provider.Provider
        Algorithm = $awKey.Algorithm.Algorithm
        KeySize = $awRsa.KeySize
        IsMachineKey = $awKey.IsMachineKey
        IsEphemeral = $awKey.IsEphemeral
        ExportPolicy = $awKey.ExportPolicy.ToString()
        ExportPolicyCode = [int]$awKey.ExportPolicy
        KeyUsage = $awKey.KeyUsage.ToString()
        KeyUsageCode = [int]$awKey.KeyUsage
        InspectedAs = [Security.Principal.WindowsIdentity]::GetCurrent().Name
        KeyAclChanged = $false
        ServiceKeyAccessVerified = $false
    }
    $awResult | ConvertTo-Json
    $awResult | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $awFolder 'machine-signing-v2-key-check.json') -Encoding UTF8
} finally {
    if ($null -ne $awRsa) { $awRsa.Dispose() }
}
