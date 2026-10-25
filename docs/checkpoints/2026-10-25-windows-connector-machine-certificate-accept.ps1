# DC01 elevated operator command. Basic public certificate guards, Accept same response in machine context; no service signing/key ACL/trust acceptance yet.
$ErrorActionPreference = 'Stop'
if ($env:COMPUTERNAME -ine 'DC01') { throw 'DC01 uzerinde calistirilmali' }
$awFolder = 'C:\ProgramData\AuthWire-SigningTemplate-b05c01482d03415897d290ccde085a37'
$awCer = Join-Path $awFolder 'machine-signing-v2.cer'
$awIssued = [Security.Cryptography.X509Certificates.X509Certificate2]::new($awCer)

if ($awIssued.GetNameInfo([Security.Cryptography.X509Certificates.X509NameType]::SimpleName, $false) -ine 'dc01.vizyonveri.local' -or
    $awIssued.GetNameInfo([Security.Cryptography.X509Certificates.X509NameType]::SimpleName, $true) -ine 'vizyonveri-DC01-CA' -or
    $awIssued.NotBefore -gt (Get-Date) -or $awIssued.NotAfter -le (Get-Date)) {
    throw 'Sertifika kimligi veya gecerlilik tarihleri eslesmedi'
}
$awEkuExtensions = @($awIssued.Extensions | Where-Object { $_.Oid.Value -eq '2.5.29.37' })
if ($awEkuExtensions.Count -ne 1) { throw 'Sertifika EKU alani beklenen sekilde degil' }
$awEku = New-Object Security.Cryptography.X509Certificates.X509EnhancedKeyUsageExtension
$awEku.CopyFrom($awEkuExtensions[0])
$awEkuOids = @($awEku.EnhancedKeyUsages | ForEach-Object { $_.Value })
if ($awEkuOids.Count -ne 1 -or $awEkuOids[0] -ne '1.3.6.1.5.5.7.3.3') { throw 'Sertifika yalniz kod imzalama amacli olmali' }
if ($awIssued.PublicKey.Oid.Value -ne '1.2.840.113549.1.1.1' -or $awIssued.PublicKey.Key.KeySize -ne 3072) { throw 'RSA 3072 kontrolu basarisiz' }

$awStorePath = 'Cert:\LocalMachine\My\' + $awIssued.Thumbprint
$awInstalled = Get-Item -LiteralPath $awStorePath -ErrorAction SilentlyContinue
if ($null -eq $awInstalled -or -not $awInstalled.HasPrivateKey) {
    & "$env:SystemRoot\System32\certreq.exe" -accept -machine -q $awCer
    if ($LASTEXITCODE -ne 0) { throw 'Yukleme tamamlanamadi; ciktiyi paylasin' }
}
$awInstalled = Get-Item -LiteralPath $awStorePath
if (-not $awInstalled.HasPrivateKey) { throw 'Sertifika ozel anahtariyla eslesmedi' }

[pscustomobject]@{
    Event = 'WINDOWS_CONNECTOR_MACHINE_SIGNER_INSTALLED'
    RequestId = 6
    Store = 'LocalMachine\My'
    Subject = $awInstalled.Subject
    Issuer = $awInstalled.Issuer
    Thumbprint = $awInstalled.Thumbprint
    SerialNumber = $awInstalled.SerialNumber
    HasPrivateKey = $awInstalled.HasPrivateKey
    NotAfter = $awInstalled.NotAfter.ToString('o')
    ServiceKeyAccessVerified = $false
} | Tee-Object -Variable awInstallResult | ConvertTo-Json
$awInstallResult | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $awFolder 'machine-signing-v2-install.json') -Encoding UTF8
