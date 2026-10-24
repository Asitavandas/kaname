# Read names from the installed Windows enum types; never infer numeric mappings.
$awGpoNames = Get-GPO -Guid 'e5a9ab39-3709-49cb-837a-0208d2eb3b12' -Domain 'vizyonveri.local' -ErrorAction Stop
$awPermissionNames = @(Get-GPPermission -Guid $awGpoNames.Id -All -Domain 'vizyonveri.local' -ErrorAction Stop |
    Select-Object @{Name='Trustee';Expression={$_.Trustee.Name}},
        @{Name='Permission';Expression={$_.Permission.ToString()}})
[pscustomobject]@{
    Event = 'WINDOWS_CONNECTOR_READONLY_NAMES'
    Computer = $env:COMPUTERNAME
    GpoName = $awGpoNames.DisplayName
    GpoStatus = $awGpoNames.GpoStatus.ToString()
    Permissions = $awPermissionNames
    ExecutionPolicies = @(Get-ExecutionPolicy -List | Select-Object `
        @{Name='Scope';Expression={$_.Scope.ToString()}},
        @{Name='ExecutionPolicy';Expression={$_.ExecutionPolicy.ToString()}})
    KdsTimes = @(Get-KdsRootKey -ErrorAction Stop | Select-Object `
        @{Name='CreationTimeUtc';Expression={$_.CreationTime.ToUniversalTime().ToString('o')}},
        @{Name='EffectiveTimeUtc';Expression={$_.EffectiveTime.ToUniversalTime().ToString('o')}})
    AdChanged = $false
    GpoChanged = $false
    ExecutionPolicyChanged = $false
} | ConvertTo-Json -Depth 5
