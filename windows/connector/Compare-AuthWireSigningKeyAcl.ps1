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
