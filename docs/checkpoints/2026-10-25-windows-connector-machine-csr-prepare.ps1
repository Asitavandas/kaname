# DC01 elevated operator step; CSR generation only, live success not yet received. Does not submit to CA.
$ErrorActionPreference = 'Stop'
if ($env:COMPUTERNAME -ine 'DC01') { throw 'DC01 uzerinde calistirilmali' }

$awFolder = 'C:\ProgramData\AuthWire-SigningTemplate-b05c01482d03415897d290ccde085a37'
$awInf = Join-Path $awFolder 'machine-signing-v2.inf'
$awReq = Join-Path $awFolder 'machine-signing-v2.req'
if ((Test-Path -LiteralPath $awInf) -or (Test-Path -LiteralPath $awReq)) {
    throw 'Onceki hazirlik dosyasi mevcut; tekrar calistirmadan ciktiyi paylasin'
}

$awInfText = @'
[Version]
Signature="$Windows NT$"

[NewRequest]
Subject = "CN=dc01.vizyonveri.local"
RequestType = PKCS10
MachineKeySet = TRUE
ProviderName = "Microsoft Software Key Storage Provider"
ProviderType = 0
KeyAlgorithm = RSA
KeyLength = 3072
KeySpec = 2
HashAlgorithm = SHA256
KeyUsage = 0x80
KeyUsageProperty = NCRYPT_ALLOW_SIGNING_FLAG
Exportable = FALSE
ExportableEncrypted = FALSE
PrivateKeyArchive = FALSE
KeyProtection = 0
Silent = TRUE
SecurityDescriptor = "D:P(A;;GA;;;SY)(A;;GA;;;BA)"

[EnhancedKeyUsageExtension]
OID = 1.3.6.1.5.5.7.3.3
Critical = FALSE

[RequestAttributes]
CertificateTemplate = AuthWireConnectorCodeSigning-4c23eebe
'@

$awBytes = [Text.Encoding]::ASCII.GetBytes($awInfText)
$awFile = [IO.File]::Open($awInf, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
try { $awFile.Write($awBytes, 0, $awBytes.Length) } finally { $awFile.Dispose() }

[pscustomobject]@{
    StartedUtc = [datetime]::UtcNow.ToString('o')
    BeforeThumbprints = @(Get-ChildItem Cert:\LocalMachine\My | ForEach-Object { $_.Thumbprint })
    TemplateName = 'AuthWireConnectorCodeSigning-4c23eebe'
    Ca = 'dc01.vizyonveri.local\vizyonveri-DC01-CA'
    RequestFile = $awReq
} | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $awFolder 'machine-signing-v2-before.json') -Encoding UTF8

& "$env:SystemRoot\System32\certreq.exe" -new -machine -q $awInf $awReq
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $awReq)) {
    throw 'Istek hazirlanamadi; komutu tekrarlamadan tum ciktiyi paylasin'
}

[pscustomobject]@{
    Event = 'WINDOWS_CONNECTOR_MACHINE_CSR_PREPARED'
    RequestFile = $awReq
    RequestSha256 = (Get-FileHash -LiteralPath $awReq -Algorithm SHA256).Hash
    SubmittedToCa = $false
} | ConvertTo-Json
