# DC01 elevated operator command: bounded exact-file SID Read grant. Actual live result pending. No actual service key use verified by ACL alone.
$ErrorActionPreference = 'Stop'
if ($env:COMPUTERNAME -ine 'DC01') { throw 'DC01 uzerinde calistirilmali' }
Import-Module ActiveDirectory
$awFolder = 'C:\ProgramData\AuthWire-SigningTemplate-b05c01482d03415897d290ccde085a37'
$awThumb = 'FFC134BC305757457163F99C7479B4168E397129'
$awSid = 'S-1-5-21-34256453-3348971241-2809240126-1648'
$awPath = 'C:\ProgramData\Microsoft\Crypto\Keys\6d83645dd6648563b32f0fdecaf3d56e_1fed02ca-1f1d-4faf-839e-e8eb2f0eff4a'
$awExpectedBefore = 'O:BAG:DUD:P(A;;FA;;;SY)(A;;FA;;;BA)'
$awReceiptPath = Join-Path $awFolder 'machine-signing-v2-key-access.json'
if (Test-Path -LiteralPath $awReceiptPath) { throw 'Onceki izin islem kaydi mevcut; tekrar calistirmadan ciktiyi paylasin' }

$awAccount = Get-ADServiceAccount -Identity 'aw-deploy' -Server 'dc01.vizyonveri.local' -Properties Description
if ($awAccount.SID.Value -ne $awSid -or $awAccount.ObjectClass -ne 'msDS-GroupManagedServiceAccount' -or
    $awAccount.Description -ne 'AuthWireConnector:v1;instance=4c23eebe-0715-46d1-88ee-a2e96ad7ee46;host=0fa4143f-aae3-4bc3-9cd3-db8a1de24acd') {
    throw 'Hizmet hesabi kimligi veya sahiplik kaydi eslesmedi'
}
$awCert = Get-Item -LiteralPath ('Cert:\LocalMachine\My\' + $awThumb)
$awRsa = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($awCert)
try {
    if ($awRsa -isnot [Security.Cryptography.RSACng]) { throw 'CNG anahtari bekleniyordu' }
    $awKey = $awRsa.Key
    if (-not $awKey.IsMachineKey -or $awKey.IsEphemeral -or $awKey.Provider.Provider -ne 'Microsoft Software Key Storage Provider' -or [int]$awKey.ExportPolicy -ne 0 -or [int]$awKey.KeyUsage -ne 2 -or $awRsa.KeySize -ne 3072 -or $awKey.UniqueName -ne [IO.Path]::GetFileName($awPath)) {
        throw 'Sertifika-anahtar dosyasi veya anahtar ozellikleri eslesmedi'
    }
    $awItem = Get-Item -LiteralPath $awPath -Force
    if ($awItem.PSIsContainer -or ($awItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Normal anahtar dosyasi bekleniyordu' }
    $awAcl = Get-Acl -LiteralPath $awPath
    if ($awAcl.Sddl -cne $awExpectedBefore) { throw 'Baslangic izinleri degismis; islem uygulanmadi' }

    $awRule = [Security.AccessControl.FileSystemAccessRule]::new(
        [Security.Principal.SecurityIdentifier]::new($awSid),
        [Security.AccessControl.FileSystemRights]::Read,
        [Security.AccessControl.AccessControlType]::Allow
    )
    $awAcl.AddAccessRule($awRule)
    $awExpectedAfter = $awAcl.Sddl
    $awReceipt = [ordered]@{
        Version = 1
        Thumbprint = $awThumb
        ServiceSid = $awSid
        KeyFile = $awPath
        StartedUtc = [datetime]::UtcNow.ToString('o')
        BeforeSddl = $awExpectedBefore
        ExpectedAfterSddl = $awExpectedAfter
        ActualAfterSddl = $null
        Phase = 'before_change'
    }
    $awBytes = [Text.Encoding]::UTF8.GetBytes(($awReceipt | ConvertTo-Json))
    $awFile = [IO.File]::Open($awReceiptPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try { $awFile.Write($awBytes, 0, $awBytes.Length) } finally { $awFile.Dispose() }

    if ((Get-Acl -LiteralPath $awPath).Sddl -cne $awExpectedBefore) { throw 'Izinler islem oncesinde degisti; ciktiyi paylasin' }
    Set-Acl -LiteralPath $awPath -AclObject $awAcl
    $awAfter = Get-Acl -LiteralPath $awPath
    $awReceipt.ActualAfterSddl = $awAfter.Sddl
    $awReceipt.Phase = 'postcheck'
    $awReceipt | ConvertTo-Json | Set-Content -LiteralPath $awReceiptPath -Encoding UTF8
    if ($awAfter.Sddl -cne $awExpectedAfter) { throw 'Izin sonrasi kontrol eslesmedi; tekrar calistirmadan ciktiyi paylasin' }
    $awReceipt.Phase = 'verified'
    $awReceipt | ConvertTo-Json | Set-Content -LiteralPath $awReceiptPath -Encoding UTF8

    [pscustomobject]@{
        Event = 'WINDOWS_CONNECTOR_SIGNER_KEY_ACCESS_PREPARED'
        Thumbprint = $awThumb
        ServiceSid = $awSid
        ReadPermissionAdded = $true
        GrantedRights = $awRule.FileSystemRights.ToString()
        GrantedRightsCode = [long]$awRule.FileSystemRights
        ExistingRightsPreserved = $true
        KeyAclChanged = $true
        ReceiptPath = $awReceiptPath
        ServiceKeyAccessVerified = $false
    } | ConvertTo-Json
} finally {
    if ($null -ne $awRsa) { $awRsa.Dispose() }
}
