$ErrorActionPreference='Stop'
Set-StrictMode -Version 2
if($env:RUNNER_ENVIRONMENT -ne 'github-hosted'){throw 'Hosted fixture only'}
. (Join-Path $PSScriptRoot '..\windows\connector\Compare-AuthWireSigningKeyAcl.ps1')
$script:checks=0
function Check([bool]$Value,[string]$Name){if(-not $Value){throw $Name};$script:checks++}
$sid='S-1-5-21-111-222-333-1648'
$expected='O:BAG:BUD:P(A;;FA;;;SY)(A;;FA;;;BA)(A;;FR;;;'+$sid+')'
$actual=$expected.Replace('D:P(','D:PAI(')
$r=Compare-AuthWireSigningKeyAcl $expected $actual
Check ($r.AclEquivalent -and $r.AutoInheritedMetadataOnly -and $r.ChangedControlFlagsCode -eq 1024 -and -not $r.AclWritten) 'Only DACL auto-inherited flag is accepted'
$r=Compare-AuthWireSigningKeyAcl $expected $expected
Check ($r.AclEquivalent -and -not $r.AutoInheritedMetadataOnly -and $r.ChangedControlFlagsCode -eq 0) 'Exact match accepted'
$r=Compare-AuthWireSigningKeyAcl $actual $expected
Check ($r.AclEquivalent -and $r.AutoInheritedMetadataOnly) 'Comparison is symmetric for this metadata bit'
foreach($case in @('owner','group','unprotected','autoRequest','fullControl','write','deny','sid','extraAce','missingSystem','missingAdmin','inherited','inheritChildren','nullDacl','emptyDacl','sacl','saclFlag')){
    $changed=$actual
    switch($case){
        'owner' {$changed=$changed.Replace('O:BA','O:SY')}
        'group' {$changed=$changed.Replace('G:BU','G:BA')}
        'unprotected' {$changed=$changed.Replace('D:PAI','D:AI')}
        'autoRequest' {$changed=$changed.Replace('D:PAI','D:PARAI')}
        'fullControl' {$changed=$changed.Replace('(A;;FR;;;'+$sid+')','(A;;FA;;;'+$sid+')')}
        'write' {$changed=$changed.Replace('(A;;FR;;;'+$sid+')','(A;;FW;;;'+$sid+')')}
        'deny' {$changed=$changed.Replace('(A;;FR;;;'+$sid+')','(D;;FR;;;'+$sid+')')}
        'sid' {$changed=$changed.Replace($sid,'S-1-5-21-111-222-333-1649')}
        'extraAce' {$changed+='(A;;FR;;;WD)'}
        'missingSystem' {$changed=$changed.Replace('(A;;FA;;;SY)','')}
        'missingAdmin' {$changed=$changed.Replace('(A;;FA;;;BA)','')}
        'inherited' {$changed=$changed.Replace('(A;;FR;;;'+$sid+')','(A;ID;FR;;;'+$sid+')')}
        'inheritChildren' {$changed=$changed.Replace('(A;;FR;;;'+$sid+')','(A;OICI;FR;;;'+$sid+')')}
        'nullDacl' {$changed='O:BAG:BUD:NO_ACCESS_CONTROL'}
        'emptyDacl' {$changed='O:BAG:BUD:P'}
        'sacl' {$changed+='S:(AU;SA;FR;;;WD)'}
        'saclFlag' {$changed+='S:AI'}
    }
    Check (-not (Compare-AuthWireSigningKeyAcl $expected $changed).AclEquivalent) ('Reject meaningful change: '+$case)
}
# Actual NTFS Set-Acl roundtrip; no customer key or directory service is used.
$file=Join-Path $env:RUNNER_TEMP ('AuthWire-KeyAcl-'+[guid]::NewGuid().ToString('N')+'.txt')
try{
    [IO.File]::WriteAllText($file,'public disposable ACL fixture')
    $acl=Get-Acl -LiteralPath $file
    $acl.SetSecurityDescriptorSddlForm('O:BAG:BUD:P(A;;FA;;;SY)(A;;FA;;;BA)')
    Set-Acl -LiteralPath $file -AclObject $acl
    $acl=Get-Acl -LiteralPath $file
    $before=$acl.Sddl
    $rule=[Security.AccessControl.FileSystemAccessRule]::new([Security.Principal.SecurityIdentifier]::new($sid),[Security.AccessControl.FileSystemRights]::Read,[Security.AccessControl.AccessControlType]::Allow)
    $acl.AddAccessRule($rule)
    $planned=$acl.Sddl
    Set-Acl -LiteralPath $file -AclObject $acl
    $after=Get-Acl -LiteralPath $file
    Check ((Compare-AuthWireSigningKeyAcl $planned $after.Sddl).AclEquivalent) 'Real Windows file ACL roundtrip matches with bounded metadata comparison'
    Check ($after.AreAccessRulesProtected -and $after.GetOwner([Security.Principal.SecurityIdentifier]).Value -eq 'S-1-5-32-544' -and $after.GetGroup([Security.Principal.SecurityIdentifier]).Value -eq 'S-1-5-32-545') 'Owner, group and protection preserved'
    $rules=@($after.GetAccessRules($true,$true,[Security.Principal.SecurityIdentifier]))
    $added=@($rules|Where-Object {$_.IdentityReference.Value -eq $sid})
    Check ($rules.Count -eq 3 -and $added.Count -eq 1 -and [long]$added[0].FileSystemRights -eq 1179785 -and -not $added[0].IsInherited) 'Only explicit Read+Synchronize is added'
    Check (-not (Compare-AuthWireSigningKeyAcl $before $after.Sddl).AclEquivalent) 'Grant itself cannot be mistaken for metadata-only baseline preservation'
    $current=$after.Sddl
    $null=Compare-AuthWireSigningKeyAcl $planned $current
    Check ((Get-Acl -LiteralPath $file).Sddl -ceq $current) 'Comparator never writes the file ACL'
    Write-Output ('AUTHWIRE_KEY_ACL_COMPARISON_NATIVE_OK '+(@{checks=$checks;actual_ntfs_roundtrip=$true;customer_keys_used=$false;gmsa_signing_tested=$false;native_powershell=$PSVersionTable.PSVersion.ToString()}|ConvertTo-Json -Compress))
}finally{if(Test-Path -LiteralPath $file){Remove-Item -LiteralPath $file -Force}}
