#Requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('Inspect','PrepareAccount')][string]$Mode = 'Inspect',
    [Parameter(Mandatory=$true)][ValidatePattern('^[A-Za-z0-9][A-Za-z0-9.-]{0,251}[A-Za-z0-9]$')][string]$ExpectedDomain,
    [Parameter(Mandatory=$true)][ValidatePattern('^[A-Za-z0-9][A-Za-z0-9-]{0,14}$')][string]$ConnectorComputer,
    [Parameter(Mandatory=$true)][guid]$InstanceId,
    [ValidatePattern('^[A-Za-z][A-Za-z0-9-]{0,14}$')][string]$AccountName = 'aw-deploy',
    [guid]$GpoId = [guid]::Empty,
    [ValidatePattern('^$|^[A-Fa-f0-9]{40}$')][string]$PublisherThumbprint = ''
)

function Get-AuthWireKdsReadiness {
    param([string]$Server,[string]$Configuration)
    $now = [datetime]::UtcNow
    $objects = @(Get-ADObject -Server $Server -SearchBase $Configuration -LDAPFilter '(objectClass=msKds-ProvRootKey)' -Properties whenCreated,msKds-UseStartTime -ErrorAction Stop)
    $results = @()
    foreach ($key in $objects) {
        $checkAfter = $null
        $tested = $false
        $state = 'metadata_invalid'
        try {
            $keyId = [guid]$key.Name
            $created = ([datetime]$key.whenCreated).ToUniversalTime()
            $rawStart = [long]([string]$key.'msKds-UseStartTime')
            if ($created -eq [datetime]::MinValue -or $rawStart -le 0) { throw 'KDS_METADATA_INVALID' }
            $effective = [datetime]::FromFileTimeUtc($rawStart)
            $checkAfter = $created.AddHours(10)
            if ($effective -gt $checkAfter) { $checkAfter = $effective }
            if ($now -lt $checkAfter) { $state = 'propagation_wait' }
            else {
                $testResult = @(Test-KdsRootKey -KeyId $keyId -ErrorAction Stop)
                $tested = ($testResult.Count -eq 1 -and $testResult[0] -is [bool] -and $testResult[0])
                if ($tested) { $state = 'configuration_valid' } else { $state = 'configuration_invalid' }
            }
        } catch { $state = 'metadata_or_configuration_check_failed' }
        $results += [pscustomobject]@{
            State = $state
            CheckAfterUtc = $(if ($null -ne $checkAfter) { $checkAfter.ToString('o') } else { $null })
            CheckAfterLocal = $(if ($null -ne $checkAfter) { $checkAfter.ToLocalTime().ToString('o') } else { $null })
            ConfigurationValid = $tested
        }
    }
    [pscustomobject]@{
        Count = $objects.Count
        Ready = ($objects.Count -eq 1 -and @($results | Where-Object ConfigurationValid).Count -eq 1)
        Keys = $results
    }
}

function Get-AuthWireAccountCandidate {
    param([string]$Server,[string]$DomainDn,[string]$Name)
    # Name is validated at the entry point before interpolation into LDAP.
    $filter = '(|(sAMAccountName=' + $Name + '$)(name=' + $Name + '))'
    $found = @(Get-ADObject -Server $Server -SearchBase $DomainDn -LDAPFilter $filter -ErrorAction Stop)
    if ($found.Count -gt 1) { throw 'ACCOUNT_NAME_AMBIGUOUS' }
    if ($found.Count -eq 0) { return $null }
    if ($found[0].ObjectClass -ne 'msDS-GroupManagedServiceAccount') { throw 'ACCOUNT_NAME_IN_USE' }
    Get-ADServiceAccount -Server $Server -Identity $found[0].ObjectGUID -Properties Description,Enabled,DNSHostName,PrincipalsAllowedToRetrieveManagedPassword,KerberosEncryptionType,AccountNotDelegated,TrustedForDelegation,TrustedToAuthForDelegation,ServicePrincipalNames,MemberOf,PrimaryGroupID -ErrorAction Stop
}

function Assert-AuthWireAccountShape {
    param($Account,$Computer,[string]$Marker,[string]$DnsName,[string]$Name)
    if ($Account.Description -cne $Marker -or $Account.SamAccountName -ine ($Name + '$') -or
        $Account.DNSHostName -ine $DnsName -or -not $Account.Enabled -or
        -not $Account.AccountNotDelegated -or $Account.TrustedForDelegation -or
        $Account.TrustedToAuthForDelegation -or [int]$Account.KerberosEncryptionType -ne 24 -or
        @($Account.ServicePrincipalNames).Count -ne 0 -or @($Account.MemberOf).Count -ne 0 -or
        [int]$Account.PrimaryGroupID -notin @(513,515)) { throw 'ACCOUNT_OWNERSHIP_OR_SETTINGS_MISMATCH' }
    $readers = @($Account.PrincipalsAllowedToRetrieveManagedPassword)
    $readerDn = $null
    if ($readers.Count -eq 1) {
        if ($readers[0] -is [string]) { $readerDn = $readers[0] }
        else { $readerDn = $readers[0].DistinguishedName }
    }
    if ($readers.Count -ne 1 -or $readerDn -ine $Computer.DistinguishedName) {
        throw 'ACCOUNT_PASSWORD_READER_MISMATCH'
    }
}

function Get-AuthWireCodeSigningUsage {
    param([System.Security.Cryptography.X509Certificates.X509Certificate2]$Certificate)
    # Cert: provider EnhancedKeyUsageList.ObjectId may be a string or an Oid.
    # Decode the certificate's actual DER extension instead of provider display properties.
    $result = [pscustomobject]@{CodeSigningEku=$false;EkuReadState='absent'}
    try {
        $extensions = @($Certificate.Extensions | Where-Object { $_.Oid.Value -eq '2.5.29.37' })
        if ($extensions.Count -eq 0) { return $result }
        if ($extensions.Count -ne 1) { throw 'EKU_EXTENSION_AMBIGUOUS' }
        $eku = New-Object System.Security.Cryptography.X509Certificates.X509EnhancedKeyUsageExtension
        $eku.CopyFrom($extensions[0])
        foreach ($oid in $eku.EnhancedKeyUsages) {
            if ($oid.Value -eq '1.3.6.1.5.5.7.3.3') { $result.CodeSigningEku = $true }
        }
        $result.EkuReadState = 'valid'
    } catch {
        $result.CodeSigningEku = $false
        $result.EkuReadState = 'invalid'
    }
    return $result
}

function Get-AuthWirePublisherInventory {
    param([string]$Thumbprint)
    if (-not $Thumbprint) { return @() }
    $found = @()
    foreach ($store in @('Cert:\CurrentUser\My','Cert:\LocalMachine\My')) {
        foreach ($cert in @(Get-ChildItem -Path $store -ErrorAction Stop | Where-Object Thumbprint -eq $Thumbprint)) {
            $usage = Get-AuthWireCodeSigningUsage -Certificate $cert
            $found += [pscustomobject]@{
                Store = $store
                Thumbprint = $cert.Thumbprint
                CodeSigningEku = $usage.CodeSigningEku
                EkuReadState = $usage.EkuReadState
                HasPrivateKey = [bool]$cert.HasPrivateKey
                CurrentlyValid = ($cert.NotBefore.ToUniversalTime() -le [datetime]::UtcNow -and $cert.NotAfter.ToUniversalTime() -gt [datetime]::UtcNow)
                ServiceKeyAccessVerified = $false
            }
        }
    }
    return $found
}

function Invoke-AuthWireConnectorBootstrap {
    [CmdletBinding()]
    param(
        [ValidateSet('Inspect','PrepareAccount')][string]$Mode,
        [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9.-]{0,251}[A-Za-z0-9]$')][string]$ExpectedDomain,
        [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9-]{0,14}$')][string]$ConnectorComputer,
        [guid]$InstanceId,
        [ValidatePattern('^[A-Za-z][A-Za-z0-9-]{0,14}$')][string]$AccountName,
        [guid]$GpoId,
        [ValidatePattern('^$|^[A-Fa-f0-9]{40}$')][string]$PublisherThumbprint
    )
    $ErrorActionPreference = 'Stop'
    Set-StrictMode -Version 2
    if ($InstanceId -eq [guid]::Empty) { throw 'INSTANCE_ID_REQUIRED' }
    if (-not [Environment]::Is64BitProcess) { throw 'POWERSHELL_64_BIT_REQUIRED' }
    Import-Module ActiveDirectory -ErrorAction Stop
    Import-Module Kds -ErrorAction Stop
    $local = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
    if (-not $local.PartOfDomain -or $local.Domain -ine $ExpectedDomain -or $local.DomainRole -lt 4) {
        throw 'RUN_ON_WRITABLE_DC_IN_EXPECTED_DOMAIN'
    }
    $dc = Get-ADDomainController -Identity $env:COMPUTERNAME -ErrorAction Stop
    if ($dc.IsReadOnly -or $dc.Domain -ine $ExpectedDomain) { throw 'WRITABLE_DC_DOMAIN_MISMATCH' }
    $server = $dc.HostName
    $domain = Get-ADDomain -Server $server -ErrorAction Stop
    if ($domain.DNSRoot -ine $ExpectedDomain) { throw 'DOMAIN_MISMATCH' }
    $hostAccount = Get-ADComputer -Server $server -Identity $ConnectorComputer -Properties Enabled,DNSHostName -ErrorAction Stop
    if (-not $hostAccount.Enabled -or $hostAccount.SamAccountName -ine ($ConnectorComputer + '$') -or
        -not $hostAccount.DNSHostName.EndsWith('.' + $ExpectedDomain,[StringComparison]::OrdinalIgnoreCase)) {
        throw 'CONNECTOR_COMPUTER_MISMATCH'
    }
    $config = (Get-ADRootDSE -Server $server -ErrorAction Stop).configurationNamingContext
    $kds = Get-AuthWireKdsReadiness -Server $server -Configuration $config
    $blockers = @()
    if ($kds.Count -eq 0) { $blockers += 'KDS_ROOT_MISSING' }
    elseif ($kds.Count -gt 1) { $blockers += 'KDS_MULTIPLE_ROOTS_REVIEW_REQUIRED' }
    elseif (-not $kds.Ready) { $blockers += 'KDS_WAIT_OR_CONFIGURATION_CHECK_REQUIRED' }
    $marker = 'AuthWireConnector:v1;instance=' + $InstanceId.ToString('D') + ';host=' + $hostAccount.ObjectGUID.ToString('D')
    $dnsName = $AccountName + '.' + $domain.DNSRoot
    $candidate = $null
    try {
        $candidate = Get-AuthWireAccountCandidate -Server $server -DomainDn $domain.DistinguishedName -Name $AccountName
        if ($null -ne $candidate) {
            Assert-AuthWireAccountShape -Account $candidate -Computer $hostAccount -Marker $marker -DnsName $dnsName -Name $AccountName
        }
    } catch { $blockers += $_.Exception.Message }
    $gpo = $null
    if ($GpoId -ne [guid]::Empty) {
        Import-Module GroupPolicy -ErrorAction Stop
        $selected = Get-GPO -Guid $GpoId -Domain $domain.DNSRoot -Server $server -ErrorAction Stop
        $gpo = [pscustomobject]@{
            Id = $selected.Id.ToString('D')
            Name = $selected.DisplayName
            Status = $selected.GpoStatus.ToString()
            Permissions = @(Get-GPPermission -Guid $GpoId -All -Domain $domain.DNSRoot -Server $server -ErrorAction Stop |
                Select-Object @{Name='Trustee';Expression={$_.Trustee.Name}},@{Name='Permission';Expression={$_.Permission.ToString()}})
            OwnershipAdopted = $false
            ServiceWriteAccessVerified = $false
        }
    }
    $publishers = @(Get-AuthWirePublisherInventory -Thumbprint $PublisherThumbprint)
    $created = $false
    if ($Mode -eq 'PrepareAccount') {
        if ($blockers.Count -gt 0) { throw ('ACCOUNT_PREPARATION_BLOCKED:' + ($blockers -join ',')) }
        if ($null -eq $candidate) {
            # A second lookup catches an intervening account before a single create.
            $candidate = Get-AuthWireAccountCandidate -Server $server -DomainDn $domain.DistinguishedName -Name $AccountName
            if ($null -ne $candidate) { throw 'ACCOUNT_APPEARED_DURING_PREPARATION_REINSPECT' }
            $accountParams = @{
                Name = $AccountName
                SamAccountName = $AccountName
                DNSHostName = $dnsName
                DisplayName = 'AuthWire Windows Deployment'
                Description = $marker
                Enabled = $true
                KerberosEncryptionType = @('AES128','AES256')
                AccountNotDelegated = $true
                TrustedForDelegation = $false
                PrincipalsAllowedToRetrieveManagedPassword = @($hostAccount)
                Server = $server
                ErrorAction = 'Stop'
            }
            New-ADServiceAccount @accountParams
            $created = $true
            $candidate = Get-AuthWireAccountCandidate -Server $server -DomainDn $domain.DistinguishedName -Name $AccountName
            if ($null -eq $candidate) { throw 'ACCOUNT_CREATE_RESULT_UNKNOWN_REINSPECT_DO_NOT_RECREATE' }
            Assert-AuthWireAccountShape -Account $candidate -Computer $hostAccount -Marker $marker -DnsName $dnsName -Name $AccountName
        }
    }
    [pscustomobject]@{
        Event = 'WINDOWS_CONNECTOR_BOOTSTRAP'
        Version = 1
        BootstrapVersion = '1.0.1'
        Mode = $Mode
        Computer = $env:COMPUTERNAME
        Domain = $domain.DNSRoot
        ConnectorComputer = $hostAccount.Name
        ConnectorComputerGuid = $hostAccount.ObjectGUID.ToString('D')
        InstanceId = $InstanceId.ToString('D')
        Kds = $kds
        Blockers = $blockers
        ReadyForAccountPreparation = ($blockers.Count -eq 0)
        Account = [pscustomobject]@{
            Name = $AccountName + '$'
            Exists = ($null -ne $candidate)
            Created = $created
            Sid = $(if ($null -ne $candidate -and $blockers.Count -eq 0) { $candidate.SID.Value } else { $null })
            AllowedPasswordHost = $hostAccount.Name
            LocalInstallationVerified = $false
            ServiceLogonVerified = $false
        }
        Gpo = $gpo
        Publishers = $publishers
        GmsaReadinessVerified = $false
        ConnectorInstalled = $false
        CanApplyGpo = $false
        AdChanged = $created
        GpoChanged = $false
        CertificatesChanged = $false
        LocalPolicyChanged = $false
        SecretsExported = $false
    }
}

Invoke-AuthWireConnectorBootstrap -Mode $Mode -ExpectedDomain $ExpectedDomain -ConnectorComputer $ConnectorComputer -InstanceId $InstanceId -AccountName $AccountName -GpoId $GpoId -PublisherThumbprint $PublisherThumbprint | ConvertTo-Json -Depth 8
