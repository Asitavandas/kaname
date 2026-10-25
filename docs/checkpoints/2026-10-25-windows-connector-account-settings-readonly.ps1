& {
    $ErrorActionPreference = 'Stop'
    Import-Module ActiveDirectory

    $awServer = 'dc01.vizyonveri.local'
    $awFields = @(
        'Description','DNSHostName','Enabled','AccountNotDelegated',
        'TrustedForDelegation','TrustedToAuthForDelegation',
        'KerberosEncryptionType','msDS-SupportedEncryptionTypes',
        'PrimaryGroupID','MemberOf','ServicePrincipalNames',
        'PrincipalsAllowedToRetrieveManagedPassword'
    )
    $awAccount = Get-ADServiceAccount -Identity 'aw-deploy' `
        -Server $awServer -Properties $awFields
    $awComputer = Get-ADComputer -Identity 'DC01' -Server $awServer

    [pscustomobject]@{
        Event = 'WINDOWS_CONNECTOR_ACCOUNT_SETTINGS_READONLY'
        Account = $awAccount.SamAccountName
        ObjectClass = $awAccount.ObjectClass
        Sid = [string]$awAccount.SID
        ExpectedDescription = 'AuthWireConnector:v1;instance=4c23eebe-0715-46d1-88ee-a2e96ad7ee46;host=' + $awComputer.ObjectGUID.ToString('D')
        ExpectedPasswordReader = $awComputer.DistinguishedName
        Attributes = @(
            foreach ($awField in $awFields) {
                $awRaw = $awAccount.$awField
                [pscustomobject]@{
                    Name = $awField
                    Type = $(if ($null -ne $awRaw) { $awRaw.GetType().FullName } else { 'null' })
                    BootstrapArrayCount = @($awRaw).Count
                    Values = @(foreach ($awValue in $awRaw) { [string]$awValue })
                }
            }
        )
        AdChanged = $false
    } | ConvertTo-Json -Depth 6
}
