# DC01 elevated operator metadata only. No key content/export/sign, no ACL mutation. Saves protected starting ACL evidence.
$ErrorActionPreference = 'Stop'
if ($env:COMPUTERNAME -ine 'DC01') { throw 'DC01 uzerinde calistirilmali' }
Import-Module ActiveDirectory
$awFolder = 'C:\ProgramData\AuthWire-SigningTemplate-b05c01482d03415897d290ccde085a37'
$awThumb = 'FFC134BC305757457163F99C7479B4168E397129'
$awServiceSid = 'S-1-5-21-34256453-3348971241-2809240126-1648'
$awAccount = Get-ADServiceAccount -Identity 'aw-deploy' -Server 'dc01.vizyonveri.local'
if ($awAccount.SID.Value -ne $awServiceSid) { throw 'Hizmet hesabi SID eslesmedi' }
$awCert = Get-Item -LiteralPath ('Cert:\LocalMachine\My\' + $awThumb)
$awRsa = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($awCert)
try {
    if ($awRsa -isnot [Security.Cryptography.RSACng]) { throw 'CNG anahtari bekleniyordu' }
    $awKey = $awRsa.Key
    if (-not $awKey.IsMachineKey -or $awKey.IsEphemeral -or $awKey.Provider.Provider -ne 'Microsoft Software Key Storage Provider' -or [int]$awKey.ExportPolicy -ne 0 -or [int]$awKey.KeyUsage -ne 2 -or $awRsa.KeySize -ne 3072) {
        throw 'Anahtar ozellikleri beklenen durumda degil'
    }
    $awUnique = $awKey.UniqueName
    if ([string]::IsNullOrWhiteSpace($awUnique) -or [IO.Path]::GetFileName($awUnique) -ne $awUnique) { throw 'Anahtar dosya adi gecersiz' }
    $awKeyPath = Join-Path (Join-Path $env:ProgramData 'Microsoft\Crypto\Keys') $awUnique
    $awItem = Get-Item -LiteralPath $awKeyPath -Force
    if ($awItem.PSIsContainer -or ($awItem.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'Normal anahtar dosyasi bekleniyordu' }
    $awAcl = Get-Acl -LiteralPath $awKeyPath
    $awRules = @($awAcl.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier]) | ForEach-Object {
        [pscustomobject]@{
            Sid = $_.IdentityReference.Value
            Type = $_.AccessControlType.ToString()
            Rights = $_.FileSystemRights.ToString()
            RightsCode = [long]$_.FileSystemRights
            Inherited = $_.IsInherited
            Inheritance = $_.InheritanceFlags.ToString()
            Propagation = $_.PropagationFlags.ToString()
        }
    })
    $awResult = [pscustomobject]@{
        Event = 'WINDOWS_CONNECTOR_SIGNER_KEY_ACL_READONLY'
        Thumbprint = $awThumb
        ServiceSid = $awServiceSid
        KeyFile = $awKeyPath
        OwnerSid = $awAcl.GetOwner([Security.Principal.SecurityIdentifier]).Value
        GroupSid = $awAcl.GetGroup([Security.Principal.SecurityIdentifier]).Value
        DaclProtected = $awAcl.AreAccessRulesProtected
        Sddl = $awAcl.Sddl
        Rules = $awRules
        DirectServiceEntryPresent = (@($awRules | Where-Object { $_.Sid -eq $awServiceSid -and -not $_.Inherited }).Count -gt 0)
        KeyAclChanged = $false
        ServiceKeyAccessVerified = $false
    }
    $awResult | ConvertTo-Json -Depth 6
    $awResult | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $awFolder 'machine-signing-v2-key-acl-before.json') -Encoding UTF8
} finally {
    if ($null -ne $awRsa) { $awRsa.Dispose() }
}
