# Native PowerShell 5.1 execution with AD/KDS/GPMC/certificate reads simulated.
# This fixture never contacts a domain and does not claim real gMSA readiness.
$ErrorActionPreference = 'Stop'
if ($env:RUNNER_ENVIRONMENT -ne 'github-hosted') { throw 'Hosted fixture only.' }
$source = Join-Path $PSScriptRoot '..\windows\connector\Initialize-AuthWireWindows.ps1'
$tokens = $null; $parseErrors = $null
$null = [Management.Automation.Language.Parser]::ParseFile($source,[ref]$tokens,[ref]$parseErrors)
if ($parseErrors.Count) { throw ('PowerShell parser: ' + ($parseErrors.Message -join '; ')) }
$instance = [guid]'e195f912-5418-4262-966a-eab64cdcc121'
$computerGuid = [guid]'477782fc-e1a1-45ec-9aee-59c42f5050b9'
$gpoGuid = [guid]'f45f61ee-dab4-41d1-b8af-3d46b0debcdd'
$checks = @()

function Reset-Fixture {
    $global:AwConnectorFixture = @{
        Domain = 'test.example'; DomainRole = 5; Rodc = $false; DomainMember = $true
        Keys = @([pscustomobject]@{Name='9d17dba6-76d1-424c-bd74-1bba56f5509b';whenCreated=[datetime]::UtcNow.AddDays(-2);'msKds-UseStartTime'=[datetime]::UtcNow.AddDays(-2).ToFileTimeUtc()})
        KdsValid = $true; KdsTests = 0; Account = $null; Creates = 0
        LookupCount = 0; Collision = ''; Race = $false; PostCreateUnknown = $false
        DirectoryReadFails = $false; Modules = @()
    }
}
function Computer-Fixture {
    [pscustomobject]@{Name='DC01';SamAccountName='DC01$';ObjectGUID=$computerGuid;DistinguishedName='CN=DC01,OU=Domain Controllers,DC=test,DC=example';DNSHostName='dc01.test.example';Enabled=$true}
}
function Account-Fixture {
    [pscustomobject]@{
        ObjectGUID=[guid]'dc737a57-9ee0-4de5-874f-2107a571cb77';SamAccountName='aw-deploy$'
        Description=('AuthWireConnector:v1;instance=' + $instance.ToString('D') + ';host=' + $computerGuid.ToString('D'))
        DNSHostName='aw-deploy.test.example';Enabled=$true;AccountNotDelegated=$true
        TrustedForDelegation=$false;TrustedToAuthForDelegation=$false;KerberosEncryptionType=24
        ServicePrincipalNames=@();MemberOf=@();PrimaryGroupID=515
        PrincipalsAllowedToRetrieveManagedPassword=@((Computer-Fixture))
        SID=[pscustomobject]@{Value='S-1-5-21-111-222-333-1234'}
    }
}
function Import-Module { [CmdletBinding()]param([string]$Name) $global:AwConnectorFixture.Modules += $Name }
function Get-CimInstance { [CmdletBinding()]param([string]$ClassName) [pscustomobject]@{Domain=$global:AwConnectorFixture.Domain;PartOfDomain=$global:AwConnectorFixture.DomainMember;DomainRole=$global:AwConnectorFixture.DomainRole} }
function Get-ADDomainController { [CmdletBinding()]param([string]$Identity) [pscustomobject]@{HostName='dc01.test.example';Domain='test.example';IsReadOnly=$global:AwConnectorFixture.Rodc} }
function Get-ADDomain { [CmdletBinding()]param([string]$Server) [pscustomobject]@{DNSRoot='test.example';DistinguishedName='DC=test,DC=example'} }
function Get-ADComputer { [CmdletBinding()]param([string]$Server,[string]$Identity,[string[]]$Properties) Computer-Fixture }
function Get-ADRootDSE { [CmdletBinding()]param([string]$Server) [pscustomobject]@{configurationNamingContext='CN=Configuration,DC=test,DC=example'} }
function Get-ADObject {
    [CmdletBinding()]param([string]$Server,[string]$SearchBase,[string]$LDAPFilter,[string[]]$Properties)
    if ($global:AwConnectorFixture.DirectoryReadFails) { throw 'DIRECTORY_READ_FAILED' }
    if ($LDAPFilter -eq '(objectClass=msKds-ProvRootKey)') { return $global:AwConnectorFixture.Keys }
    if ($LDAPFilter -ne '(|(sAMAccountName=aw-deploy$)(name=aw-deploy))') { throw 'Unsafe/unexpected account query.' }
    $global:AwConnectorFixture.LookupCount++
    if ($global:AwConnectorFixture.Collision -eq 'ambiguous') {
        return @([pscustomobject]@{ObjectClass='user'},[pscustomobject]@{ObjectClass='user'})
    }
    if ($global:AwConnectorFixture.Collision -eq 'user' -or
        ($global:AwConnectorFixture.Race -and $global:AwConnectorFixture.LookupCount -gt 1)) {
        return [pscustomobject]@{ObjectClass='user';ObjectGUID=[guid]::NewGuid()}
    }
    if ($global:AwConnectorFixture.PostCreateUnknown -and $global:AwConnectorFixture.Creates -gt 0) { return }
    if ($null -ne $global:AwConnectorFixture.Account) {
        return [pscustomobject]@{ObjectClass='msDS-GroupManagedServiceAccount';ObjectGUID=$global:AwConnectorFixture.Account.ObjectGUID}
    }
}
function Get-ADServiceAccount { [CmdletBinding()]param([string]$Server,[guid]$Identity,[string[]]$Properties) $global:AwConnectorFixture.Account }
function Test-KdsRootKey { [CmdletBinding()]param([guid]$KeyId) $global:AwConnectorFixture.KdsTests++; $global:AwConnectorFixture.KdsValid }
function New-ADServiceAccount {
    [CmdletBinding()]param([string]$Name,[string]$SamAccountName,[string]$DNSHostName,[string]$DisplayName,[string]$Description,[bool]$Enabled,[string[]]$KerberosEncryptionType,[bool]$AccountNotDelegated,[bool]$TrustedForDelegation,[object[]]$PrincipalsAllowedToRetrieveManagedPassword,[string]$Server)
    if ($Name -ne 'aw-deploy' -or $SamAccountName -ne 'aw-deploy' -or $DNSHostName -ne 'aw-deploy.test.example' -or
        -not $Enabled -or -not $AccountNotDelegated -or $TrustedForDelegation -or
        ($KerberosEncryptionType -join ',') -ne 'AES128,AES256' -or
        $PrincipalsAllowedToRetrieveManagedPassword.Count -ne 1 -or
        $PrincipalsAllowedToRetrieveManagedPassword[0].ObjectGUID -ne $computerGuid -or $Server -ne 'dc01.test.example') {
        throw 'Account create escaped intended identity/host/cryptographic scope.'
    }
    $global:AwConnectorFixture.Creates++
    $global:AwConnectorFixture.Account = Account-Fixture
    $global:AwConnectorFixture.Account.Description = $Description
}
function Get-GPO { [CmdletBinding()]param([guid]$Guid,[string]$Domain,[string]$Server) [pscustomobject]@{Id=$Guid;DisplayName='Existing customer pilot';GpoStatus='AllSettingsEnabled'} }
function Get-GPPermission { [CmdletBinding()]param([guid]$Guid,[switch]$All,[string]$Domain,[string]$Server) [pscustomobject]@{Trustee=[pscustomobject]@{Name='Pilot-Computers'};Permission='GpoApply'} }
function Get-ChildItem { [CmdletBinding()]param([string]$Path) return }
function Check([bool]$Value,[string]$Name) { if (-not $Value) { throw $Name }; $script:checks += $Name }
function Run-Fixture([string]$Mode='Inspect') {
    & $source -Mode $Mode -ExpectedDomain 'test.example' -ConnectorComputer 'DC01' -InstanceId $instance -GpoId $gpoGuid -PublisherThumbprint ('A' * 40) | ConvertFrom-Json
}
function Expect-Blocked([string]$Code,[string]$Mode='PrepareAccount') {
    $caught = $false
    try { $null = Run-Fixture $Mode } catch { if ($_.Exception.Message -notlike ('*' + $Code + '*')) { throw }; $caught=$true }
    Check $caught ('Rejected ' + $Code)
    Check ($global:AwConnectorFixture.Creates -eq 0) ('No AD writes for ' + $Code)
}
try {
    Reset-Fixture
    $r = Run-Fixture
    Check ($r.ReadyForAccountPreparation -and -not $r.AdChanged -and $global:AwConnectorFixture.Creates -eq 0) 'Default inspect is read only and ready'
    Check (-not $r.GmsaReadinessVerified -and -not $r.CanApplyGpo -and -not $r.Gpo.OwnershipAdopted) 'KDS configuration never implies service or GPO authority'
    Check ($r.Gpo.Status -eq 'AllSettingsEnabled' -and $r.Gpo.Permissions[0].Permission -eq 'GpoApply') 'Existing GPO enum names preserved'

    Reset-Fixture; $global:AwConnectorFixture.Keys=@()
    $r=Run-Fixture
    Check ($r.Kds.Count -eq 0 -and $r.Blockers -contains 'KDS_ROOT_MISSING') 'Empty AD collection is zero keys'
    Expect-Blocked 'KDS_ROOT_MISSING'

    Reset-Fixture; $global:AwConnectorFixture.Keys[0].whenCreated=[datetime]::UtcNow
    $r=Run-Fixture
    Check ($r.Kds.Keys[0].State -eq 'propagation_wait' -and $global:AwConnectorFixture.KdsTests -eq 0) 'Ten hour wait prevents premature key test'
    Expect-Blocked 'KDS_WAIT_OR_CONFIGURATION_CHECK_REQUIRED'

    Reset-Fixture; $global:AwConnectorFixture.Keys[0].'msKds-UseStartTime'=[datetime]::UtcNow.AddDays(1).ToFileTimeUtc()
    Expect-Blocked 'KDS_WAIT_OR_CONFIGURATION_CHECK_REQUIRED'

    Reset-Fixture; $global:AwConnectorFixture.KdsValid=$false
    Expect-Blocked 'KDS_WAIT_OR_CONFIGURATION_CHECK_REQUIRED'
    Reset-Fixture; $global:AwConnectorFixture.KdsValid='False'
    Expect-Blocked 'KDS_WAIT_OR_CONFIGURATION_CHECK_REQUIRED'
    Reset-Fixture; $global:AwConnectorFixture.Keys[0].'msKds-UseStartTime'='unparseable'
    Expect-Blocked 'KDS_WAIT_OR_CONFIGURATION_CHECK_REQUIRED'
    Reset-Fixture; $global:AwConnectorFixture.Keys += $global:AwConnectorFixture.Keys[0]
    Expect-Blocked 'KDS_MULTIPLE_ROOTS_REVIEW_REQUIRED'

    Reset-Fixture; $global:AwConnectorFixture.Domain='other.example'
    Expect-Blocked 'RUN_ON_WRITABLE_DC_IN_EXPECTED_DOMAIN'
    Reset-Fixture; $global:AwConnectorFixture.Rodc=$true
    Expect-Blocked 'WRITABLE_DC_DOMAIN_MISMATCH'
    Reset-Fixture; $global:AwConnectorFixture.DomainRole=3
    Expect-Blocked 'RUN_ON_WRITABLE_DC_IN_EXPECTED_DOMAIN'
    Reset-Fixture; $global:AwConnectorFixture.DirectoryReadFails=$true
    Expect-Blocked 'DIRECTORY_READ_FAILED'

    Reset-Fixture; $global:AwConnectorFixture.Collision='user'
    Expect-Blocked 'ACCOUNT_NAME_IN_USE'
    Reset-Fixture; $global:AwConnectorFixture.Collision='ambiguous'
    Expect-Blocked 'ACCOUNT_NAME_AMBIGUOUS'
    Reset-Fixture; $global:AwConnectorFixture.Account=Account-Fixture
    $global:AwConnectorFixture.Account.Description='Customer service account'
    Expect-Blocked 'ACCOUNT_OWNERSHIP_OR_SETTINGS_MISMATCH'
    Reset-Fixture; $global:AwConnectorFixture.Account=Account-Fixture
    $global:AwConnectorFixture.Account.PrincipalsAllowedToRetrieveManagedPassword=@('CN=Unapproved,DC=test,DC=example')
    Expect-Blocked 'ACCOUNT_PASSWORD_READER_MISMATCH'
    Reset-Fixture; $global:AwConnectorFixture.Account=Account-Fixture
    $global:AwConnectorFixture.Account.MemberOf=@('CN=Domain Admins,CN=Users,DC=test,DC=example')
    Expect-Blocked 'ACCOUNT_OWNERSHIP_OR_SETTINGS_MISMATCH'
    Reset-Fixture; $global:AwConnectorFixture.Account=Account-Fixture
    $global:AwConnectorFixture.Account.PrimaryGroupID=512
    Expect-Blocked 'ACCOUNT_OWNERSHIP_OR_SETTINGS_MISMATCH'
    Reset-Fixture; $global:AwConnectorFixture.Account=Account-Fixture
    $global:AwConnectorFixture.Account.KerberosEncryptionType=28
    Expect-Blocked 'ACCOUNT_OWNERSHIP_OR_SETTINGS_MISMATCH'
    Reset-Fixture; $global:AwConnectorFixture.Race=$true
    Expect-Blocked 'ACCOUNT_NAME_IN_USE'

    Reset-Fixture
    $r=Run-Fixture 'PrepareAccount'
    Check ($r.Account.Created -and $r.AdChanged -and $global:AwConnectorFixture.Creates -eq 1) 'Exactly one scoped gMSA create'
    Check (-not $r.GpoChanged -and -not $r.CertificatesChanged -and -not $r.LocalPolicyChanged -and -not $r.ConnectorInstalled) 'Account preparation keeps independent gates closed'
    $r=Run-Fixture 'PrepareAccount'
    Check (-not $r.Account.Created -and -not $r.AdChanged -and $global:AwConnectorFixture.Creates -eq 1) 'Known matching account reused without mutation'
    $global:AwConnectorFixture.Account.PrincipalsAllowedToRetrieveManagedPassword=@((Computer-Fixture).DistinguishedName)
    $r=Run-Fixture
    Check $r.ReadyForAccountPreparation 'Password reader DN string normalization'

    Reset-Fixture; $global:AwConnectorFixture.PostCreateUnknown=$true
    $caught=$false
    try {$null=Run-Fixture 'PrepareAccount'} catch {if ($_.Exception.Message -notlike '*ACCOUNT_CREATE_RESULT_UNKNOWN*') {throw}; $caught=$true}
    Check ($caught -and $global:AwConnectorFixture.Creates -eq 1) 'Lost create receipt never triggers second create'
    Write-Output ('AUTHWIRE_CONNECTOR_BOOTSTRAP_FIXTURE_OK ' + (@{checks=$checks.Count;native_powershell=$PSVersionTable.PSVersion.ToString();directory_kds_gpmc_calls_mocked=$true;real_ad_tested=$false;real_gmsa_installed=$false;customer_state_used=$false;network_calls=0}|ConvertTo-Json -Compress))
} finally { Remove-Variable AwConnectorFixture -Scope Global -ErrorAction SilentlyContinue }
