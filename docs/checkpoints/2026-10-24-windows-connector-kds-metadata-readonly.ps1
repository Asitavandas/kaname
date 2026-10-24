# Read only non-secret KDS object metadata; no RootKeyData or account/GPO writes.
$awDc = 'dc01.vizyonveri.local'
$awConfiguration = (Get-ADRootDSE -Server $awDc -ErrorAction Stop).configurationNamingContext
$awKdsObjects = @(Get-ADObject -Server $awDc -SearchBase $awConfiguration `
    -LDAPFilter '(objectClass=msKds-ProvRootKey)' `
    -Properties whenCreated,msKds-UseStartTime -ErrorAction Stop)

[pscustomobject]@{
    Event = 'WINDOWS_CONNECTOR_KDS_METADATA_READONLY'
    Computer = $env:COMPUTERNAME
    ServerQueried = $awDc
    Caller = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    RootKeyObjectsVisible = $awKdsObjects.Count
    RootKeys = @($awKdsObjects | Select-Object Name,
        @{Name='CreatedUtc';Expression={$_.whenCreated.ToUniversalTime().ToString('o')}},
        @{Name='EffectiveTimeRaw';Expression={ [string]($_.'msKds-UseStartTime') }})
    DomainControllers = @(Get-ADDomainController -Filter * -Server $awDc -ErrorAction Stop |
        Select-Object HostName,OperatingSystem,IsReadOnly)
    AdChanged = $false
    GpoChanged = $false
    KeyMaterialRequested = $false
} | ConvertTo-Json -Depth 5
