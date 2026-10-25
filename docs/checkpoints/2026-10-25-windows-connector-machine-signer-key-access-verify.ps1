#Requires -Version 5.1
# Pure comparison only: never writes an ACL or drops ACEs, owners, groups or protection flags.
function Compare-AuthWireSigningKeyAcl {
    param([Parameter(Mandatory=$true)][string]$ExpectedSddl,[Parameter(Mandatory=$true)][string]$ActualSddl)
    $left=[Security.AccessControl.RawSecurityDescriptor]::new($ExpectedSddl)
    $right=[Security.AccessControl.RawSecurityDescriptor]::new($ActualSddl)
    $difference=[int]$left.ControlFlags -bxor [int]$right.ControlFlags
    $metadata=[int][Security.AccessControl.ControlFlags]::DiscretionaryAclAutoInherited
    $hasDacls=($null -ne $left.DiscretionaryAcl -and $null -ne $right.DiscretionaryAcl)
    $allowed=($difference -eq 0 -or $difference -eq $metadata)
    $left.SetFlags([Security.AccessControl.ControlFlags]([int]$left.ControlFlags -band (-bnot $metadata)))
    $right.SetFlags([Security.AccessControl.ControlFlags]([int]$right.ControlFlags -band (-bnot $metadata)))
    $same=($left.GetSddlForm([Security.AccessControl.AccessControlSections]::All) -ceq
        $right.GetSddlForm([Security.AccessControl.AccessControlSections]::All))
    $equivalent=($hasDacls -and $allowed -and $same)
    [pscustomobject]@{
        AclEquivalent=$equivalent
        AutoInheritedMetadataOnly=($equivalent -and $difference -eq $metadata)
        ChangedControlFlagsCode=$difference
        IgnoredMetadataFlag='SE_DACL_AUTO_INHERITED'
        AclWritten=$false
    }
}

$ErrorActionPreference='Stop'
if($env:COMPUTERNAME -ine 'DC01'){throw 'DC01_REQUIRED'}
$folder='C:\ProgramData\AuthWire-SigningTemplate-b05c01482d03415897d290ccde085a37'
$receiptPath=Join-Path $folder 'machine-signing-v2-key-access.json'
$receipt=Get-Content -LiteralPath $receiptPath -Raw|ConvertFrom-Json
$sid='S-1-5-21-34256453-3348971241-2809240126-1648'
$thumb='FFC134BC305757457163F99C7479B4168E397129'
$path='C:\ProgramData\Microsoft\Crypto\Keys\6d83645dd6648563b32f0fdecaf3d56e_1fed02ca-1f1d-4faf-839e-e8eb2f0eff4a'
$before='O:BAG:DUD:P(A;;FA;;;SY)(A;;FA;;;BA)'
$expected=$before+'(A;;FR;;;'+$sid+')'
if($receipt.Thumbprint -ine $thumb -or $receipt.ServiceSid -ne $sid -or $receipt.KeyFile -ine $path -or
    $receipt.BeforeSddl -cne $before -or $receipt.ExpectedAfterSddl -cne $expected -or
    $receipt.Phase -notin @('postcheck','verified')){throw 'KEY_ACCESS_RECEIPT_SCOPE_MISMATCH'}
$cert=Get-Item -LiteralPath ('Cert:\LocalMachine\My\'+$thumb)
$rsa=[Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($cert)
try{
    if($rsa -isnot [Security.Cryptography.RSACng] -or -not $rsa.Key.IsMachineKey -or
        $rsa.Key.Provider.Provider -ne 'Microsoft Software Key Storage Provider' -or
        $rsa.Key.UniqueName -ne [IO.Path]::GetFileName($path)){throw 'CERTIFICATE_KEY_FILE_MISMATCH'}
    $item=Get-Item -LiteralPath $path -Force
    if($item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){throw 'NORMAL_KEY_FILE_REQUIRED'}
    $acl=Get-Acl -LiteralPath $path
    $comparison=Compare-AuthWireSigningKeyAcl $expected $acl.Sddl
    if(-not $comparison.AclEquivalent){throw 'KEY_ACL_MEANINGFUL_CHANGE_REQUIRES_REVIEW'}
    $result=[pscustomobject]@{
        Event='WINDOWS_CONNECTOR_SIGNER_KEY_ACL_VERIFIED'
        ComparisonVersion='1.0.1';Thumbprint=$thumb;ServiceSid=$sid
        ReadPermissionVerified=$true;ExistingRightsPreserved=$true
        AutoInheritedMetadataOnly=$comparison.AutoInheritedMetadataOnly
        ChangedControlFlagsCode=$comparison.ChangedControlFlagsCode
        OriginalReceiptPhase=$receipt.Phase
        OriginalReceiptSha256=(Get-FileHash -LiteralPath $receiptPath -Algorithm SHA256).Hash
        CurrentSddl=$acl.Sddl;KeyAclChangedByThisCheck=$false
        ServiceKeyAccessVerified=$false;RuntimeSigningTested=$false
    }
    $result|ConvertTo-Json
    $result|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $folder 'machine-signing-v2-key-access-verified.json') -Encoding UTF8
}finally{if($null -ne $rsa){$rsa.Dispose()}}
