# DC01 operator readonly receipt/current-ACL diagnostic. No acceptance or repair until live diff is reviewed.
$ErrorActionPreference = 'Stop'
$awFolder = 'C:\ProgramData\AuthWire-SigningTemplate-b05c01482d03415897d290ccde085a37'
$awReceiptPath = Join-Path $awFolder 'machine-signing-v2-key-access.json'
$awReceipt = Get-Content -LiteralPath $awReceiptPath -Raw | ConvertFrom-Json
$awReceipt | ConvertTo-Json -Depth 6

$awKeyPath = 'C:\ProgramData\Microsoft\Crypto\Keys\6d83645dd6648563b32f0fdecaf3d56e_1fed02ca-1f1d-4faf-839e-e8eb2f0eff4a'
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
    Event = 'WINDOWS_CONNECTOR_SIGNER_KEY_ACL_POSTCHECK_READONLY'
    Thumbprint = 'FFC134BC305757457163F99C7479B4168E397129'
    ReceiptPhase = $awReceipt.Phase
    BeforeSddl = $awReceipt.BeforeSddl
    ExpectedAfterSddl = $awReceipt.ExpectedAfterSddl
    RecordedAfterSddl = $awReceipt.ActualAfterSddl
    CurrentSddl = $awAcl.Sddl
    CurrentOwnerSid = $awAcl.GetOwner([Security.Principal.SecurityIdentifier]).Value
    CurrentGroupSid = $awAcl.GetGroup([Security.Principal.SecurityIdentifier]).Value
    CurrentDaclProtected = $awAcl.AreAccessRulesProtected
    Rules = $awRules
    PermissionsChangedByThisCheck = $false
    ServiceKeyAccessVerified = $false
}
$awResult | ConvertTo-Json -Depth 6
$awResult | ConvertTo-Json -Depth 6 |
    Set-Content -LiteralPath (Join-Path $awFolder 'machine-signing-v2-key-access-postcheck.json') -Encoding UTF8
