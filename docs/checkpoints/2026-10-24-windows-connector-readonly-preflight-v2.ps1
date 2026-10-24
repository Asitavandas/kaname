# Read-only DC/management-host facts. No GPO, account, key or policy writes.
$awErrors = @()
$awComputer = Get-CimInstance Win32_ComputerSystem
$awOs = Get-CimInstance Win32_OperatingSystem
$awModules = @(Get-Module -ListAvailable -Name ActiveDirectory,GroupPolicy,Kds |
    Select-Object Name,Version)
$awDomain = $null; $awSchema = $null; $awGpo = $null
$awPermissions = @(); $awKdsCount = $null
try {
    $awDomain = Get-ADDomain -Identity 'vizyonveri.local' -ErrorAction Stop
    $awRootDse = Get-ADRootDSE -ErrorAction Stop
    $awSchema = (Get-ADObject -Identity $awRootDse.schemaNamingContext `
        -Properties objectVersion -ErrorAction Stop).objectVersion
} catch { $awErrors += 'AD_READ_FAILED:' + $_.Exception.GetType().Name }
try {
    $awGpo = Get-GPO -Guid 'e5a9ab39-3709-49cb-837a-0208d2eb3b12' `
        -Domain 'vizyonveri.local' -ErrorAction Stop
    $awPermissions = @(Get-GPPermission -Guid $awGpo.Id -All `
        -Domain 'vizyonveri.local' -ErrorAction Stop |
        Select-Object @{Name='Trustee';Expression={$_.Trustee.Name}},
            @{Name='Permission';Expression={$_.Permission.ToString()}})
} catch { $awErrors += 'GPO_READ_FAILED:' + $_.Exception.GetType().Name }
try { $awKdsCount = @(Get-KdsRootKey -ErrorAction Stop).Count }
catch { $awErrors += 'KDS_READ_UNAVAILABLE:' + $_.Exception.GetType().Name }
$awPublishers = @(Get-ChildItem Cert:\CurrentUser\My,Cert:\LocalMachine\My `
    -ErrorAction SilentlyContinue |
    Where-Object Thumbprint -EQ '6E74B513F766E01730719684A41B2664380CA68A' |
    Select-Object Subject,Thumbprint,HasPrivateKey,NotAfter,PSParentPath)
[pscustomobject]@{
    Event = 'WINDOWS_CONNECTOR_READONLY_PREFLIGHT'
    Computer = $env:COMPUTERNAME
    Domain = $awComputer.Domain
    PartOfDomain = $awComputer.PartOfDomain
    Windows = $awOs.Caption
    Build = $awOs.BuildNumber
    PowerShell = $PSVersionTable.PSVersion.ToString()
    Modules = $awModules
    DomainMode = $(if ($awDomain) { [string]$awDomain.DomainMode } else { $null })
    SchemaVersion = $awSchema
    KdsRootKeyCount = $awKdsCount
    Gpo = $(if ($awGpo) { $awGpo | Select-Object DisplayName,Id,
        @{Name='GpoStatus';Expression={$_.GpoStatus.ToString()}} } else { $null })
    GpoPermissions = $awPermissions
    PublisherCertificates = $awPublishers
    ExecutionPolicies = @(Get-ExecutionPolicy -List | Select-Object `
        @{Name='Scope';Expression={$_.Scope.ToString()}},
        @{Name='ExecutionPolicy';Expression={$_.ExecutionPolicy.ToString()}})
    Errors = $awErrors
    AdChanged = $false
    GpoChanged = $false
    TrustStoreChanged = $false
    PrivateKeyAccessTested = $false
} | ConvertTo-Json -Depth 6
