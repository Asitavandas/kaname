# Read-only AD adapter. Credential JSON arrives on stdin; nothing is written to disk.
param([switch]$SelfTest, [int]$FixturePort=0)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2
[Console]::InputEncoding = New-Object System.Text.UTF8Encoding($false)
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
$connection = $null
$request = $null
$failure = 'AD_INPUT_INVALID'
$script:stage = 'input'
function Attribute-Text($entry, [string]$name) {
    if ($entry.Attributes.Contains($name) -and $entry.Attributes[$name].Count -gt 0) {
        return [string]$entry.Attributes[$name].GetValues([string])[0]
    }
    return ''
}
function Attribute-Bytes($entry, [string]$name, [int]$minimum, [int]$maximum) {
    if (-not $entry.Attributes.Contains($name) -or $entry.Attributes[$name].Count -ne 1) { throw 'ATTRIBUTE_MISSING' }
    # Search-result indexers may decode valid UTF-8 binary values as strings.
    # GetValues(byte[]) preserves the LDAP bytes for every SID/GUID.
    $values = $entry.Attributes[$name].GetValues([byte[]])
    [byte[]]$bytes = $values[0]
    if ($bytes.Length -lt $minimum -or $bytes.Length -gt $maximum) { throw 'BINARY_ATTRIBUTE_INVALID' }
    return ,$bytes
}
function Convert-Object($entry, [string]$kind) {
    $sid = [System.Security.Principal.SecurityIdentifier]::new((Attribute-Bytes $entry 'objectSid' 8 68), 0)
    $guid = [Guid]::new((Attribute-Bytes $entry 'objectGUID' 16 16))
    $name = Attribute-Text $entry 'displayName'
    if (-not $name) { $name = Attribute-Text $entry 'name' }
    $record = @{guid=$guid.ToString(); sid=$sid.Value; sam=(Attribute-Text $entry 'sAMAccountName'); name=$name}
    if ($kind -ne 'groups') {
        $uac = Attribute-Text $entry 'userAccountControl'
        if (-not $uac) { throw 'ATTRIBUTE_MISSING' }
        $record.enabled = (([int64]$uac -band 2) -eq 0)
    }
    return $record
}
function Read-Objects([string]$kind, [string]$filter, [string]$base) {
    $script:stage = $kind + '_prepare'
    $objects = New-Object 'System.Collections.Generic.List[object]'
    $search = New-Object System.DirectoryServices.Protocols.SearchRequest
    $search.DistinguishedName = $base
    $search.Filter = $filter
    $search.Scope = [System.DirectoryServices.Protocols.SearchScope]::Subtree
    $search.TimeLimit = [TimeSpan]::FromSeconds(10)
    foreach ($attribute in @('objectGUID','objectSid','sAMAccountName','displayName','name','userAccountControl')) {
        [void]$search.Attributes.Add($attribute)
    }
    $page = New-Object System.DirectoryServices.Protocols.PageResultRequestControl(250)
    $page.IsCritical = $true
    [void]$search.Controls.Add($page)
    # Restrict the search to the authenticated domain naming context. AD may
    # otherwise return subordinate DNS/configuration/child-domain references.
    # Do not chase or silently accept those references.
    $domainScope = [System.DirectoryServices.Protocols.DirectoryControl]::new('1.2.840.113556.1.4.1339', [byte[]]@(), $true, $true)
    [void]$search.Controls.Add($domainScope)
    $cookies = New-Object 'System.Collections.Generic.HashSet[string]'
    do {
        $script:stage = $kind + '_search'
        $response = [System.DirectoryServices.Protocols.SearchResponse]$connection.SendRequest($search)
        if ($response.ResultCode -ne [System.DirectoryServices.Protocols.ResultCode]::Success) { throw 'LDAP_RESULT' }
        if ($response.References.Count -ne 0) { throw 'REFERRAL_RETURNED' }
        foreach ($entry in $response.Entries) {
            $script:stage = $kind + '_decode'
            $record = Convert-Object $entry $kind
            $objects.Add($record)
            if ($objects.Count -gt 10000) { throw 'AD_DIRECTORY_LIMIT' }
        }
        $script:stage = $kind + '_page'
        $control = @($response.Controls | Where-Object { $_ -is [System.DirectoryServices.Protocols.PageResultResponseControl] })
        if ($control.Count -ne 1) { throw 'AD_SEARCH_FAILED' }
        $page.Cookie = $control[0].Cookie
        if ($page.Cookie.Length -gt 0 -and -not $cookies.Add([Convert]::ToBase64String($page.Cookie))) { throw 'AD_SEARCH_FAILED' }
    } while ($page.Cookie.Length -gt 0)
    return ,$objects.ToArray()
}
try {
    if ($FixturePort -ne 0 -and (-not $SelfTest -or $FixturePort -lt 1024 -or $FixturePort -gt 65535)) { throw 'Invalid fixture mode' }
    if ($SelfTest) {
        Add-Type -AssemblyName System.DirectoryServices.Protocols
        $identifier = New-Object System.DirectoryServices.Protocols.LdapDirectoryIdentifier('dc01.example.invalid', 389, $true, $false)
        $credential = New-Object System.Net.NetworkCredential('fixture@example.invalid', 'fixture-only-password')
        $connection = New-Object System.DirectoryServices.Protocols.LdapConnection($identifier, $credential, [System.DirectoryServices.Protocols.AuthType]::Kerberos)
        $connection.SessionOptions.ProtocolVersion = 3
        $connection.SessionOptions.Signing = $true
        $connection.SessionOptions.Sealing = $true
        $connection.SessionOptions.ReferralChasing = [System.DirectoryServices.Protocols.ReferralChasingOptions]::None
        $page = New-Object System.DirectoryServices.Protocols.PageResultRequestControl(250)
        if ($page.PageSize -ne 250 -or -not $connection.SessionOptions.Sealing -or -not $connection.SessionOptions.Signing) { throw 'Self test failed' }
        $sid = [System.Security.Principal.SecurityIdentifier]::new('S-1-5-21-1-2-3-500')
        $bytes = New-Object byte[] $sid.BinaryLength
        $sid.GetBinaryForm($bytes, 0)
        if ([System.Security.Principal.SecurityIdentifier]::new($bytes, 0).Value -ne $sid.Value) { throw 'Self test failed' }
        # Actual .NET DirectoryAttribute objects exercise binary values, display
        # name fallback, disabled users, GUID conversion, and JSON projection.
        foreach ($fixtureSid in @('S-1-5-32-544', 'S-1-5-32-545', 'S-1-5-21-1-2-3-500')) {
            $fixture = [System.Security.Principal.SecurityIdentifier]::new($fixtureSid)
            $binary = New-Object byte[] $fixture.BinaryLength
            $fixture.GetBinaryForm($binary, 0)
            $attributes = @{
                objectSid=[System.DirectoryServices.Protocols.DirectoryAttribute]::new('objectSid', $binary)
                objectGUID=[System.DirectoryServices.Protocols.DirectoryAttribute]::new('objectGUID', ([Guid]'00000000-0000-0000-0000-000000000001').ToByteArray())
                sAMAccountName=[System.DirectoryServices.Protocols.DirectoryAttribute]::new('sAMAccountName', 'fixture')
                name=[System.DirectoryServices.Protocols.DirectoryAttribute]::new('name', 'Fixture')
                userAccountControl=[System.DirectoryServices.Protocols.DirectoryAttribute]::new('userAccountControl', '514')
            }
            # Framework search-result flags reproduce the indexer's UTF-8 path.
            foreach ($attribute in $attributes.Values) {
                foreach ($field in $attribute.GetType().GetFields([System.Reflection.BindingFlags]'Instance,NonPublic')) {
                    if ($field.FieldType -eq [bool] -and $field.Name -match 'searchResult') { $field.SetValue($attribute, $true) }
                }
            }
            $entry = [pscustomobject]@{Attributes=$attributes}
            $decoded = Convert-Object $entry 'users'
            if ($decoded.sid -ne $fixtureSid -or $decoded.guid -ne '00000000-0000-0000-0000-000000000001' -or $decoded.enabled -ne $false -or $decoded.name -ne 'Fixture') { throw 'Binary projection fixture failed' }
            $group = Convert-Object $entry 'groups'
            if ($group.ContainsKey('enabled') -or (($group | ConvertTo-Json -Compress | ConvertFrom-Json).sid -ne $fixtureSid)) { throw 'Group fixture failed' }
        }
        if ($FixturePort -ne 0) {
            # Only the explicit test CLI can reach this branch. Fixed loopback
            # destination, anonymous fixture bind, no production credentials.
            $connection.Dispose()
            $identifier = [System.DirectoryServices.Protocols.LdapDirectoryIdentifier]::new('127.0.0.1', $FixturePort, $false, $false)
            $connection = [System.DirectoryServices.Protocols.LdapConnection]::new($identifier)
            $connection.AuthType = [System.DirectoryServices.Protocols.AuthType]::Anonymous
            $connection.SessionOptions.ProtocolVersion = 3
            $connection.SessionOptions.ReferralChasing = [System.DirectoryServices.Protocols.ReferralChasingOptions]::None
            $connection.Timeout = [TimeSpan]::FromSeconds(5)
            $failure = 'AD_SEARCH_FAILED'
            $users = Read-Objects 'users' '(&(objectCategory=person)(objectClass=user))' 'DC=fixture,DC=invalid'
            $groups = Read-Objects 'groups' '(&(objectCategory=group)(groupType:1.2.840.113556.1.4.803:=2147483648))' 'DC=fixture,DC=invalid'
            $computers = Read-Objects 'computers' '(objectCategory=computer)' 'DC=fixture,DC=invalid'
            if ($users.Count -ne 2 -or $groups.Count -ne 1 -or $computers.Count -ne 1 -or $users[0].enabled -ne $false -or $users[1].enabled -ne $true -or $groups[0].sid -ne 'S-1-5-32-544') { throw 'Fixture result failed' }
            @{self_test='passed'; fixture='paged-ldap'; external_network_called=$false; counts=@{users=$users.Count; groups=$groups.Count; computers=$computers.Count}} | ConvertTo-Json -Compress
        } else {
            @{self_test='passed'; transport='kerberos-sign-seal'; network_called=$false} | ConvertTo-Json -Compress
        }
        exit 0
    }
    $request = [Console]::In.ReadToEnd() | ConvertFrom-Json
    Add-Type -AssemblyName System.DirectoryServices.Protocols
    $failure = 'AD_PROTOCOL_UNAVAILABLE'
    $identifier = New-Object System.DirectoryServices.Protocols.LdapDirectoryIdentifier([string]$request.dc_fqdn, 389, $true, $false)
    $credential = New-Object System.Net.NetworkCredential([string]$request.username, [string]$request.password)
    $connection = New-Object System.DirectoryServices.Protocols.LdapConnection($identifier, $credential, [System.DirectoryServices.Protocols.AuthType]::Kerberos)
    $connection.Timeout = [TimeSpan]::FromSeconds(10)
    $connection.SessionOptions.ProtocolVersion = 3
    $connection.SessionOptions.ReferralChasing = [System.DirectoryServices.Protocols.ReferralChasingOptions]::None
    $connection.SessionOptions.Signing = $true
    $connection.SessionOptions.Sealing = $true
    $failure = 'AD_BIND_FAILED'
    $script:stage = 'bind'
    $connection.Bind()
    $failure = 'AD_PROTECTION_REQUIRED'
    if (-not $connection.SessionOptions.Signing -or -not $connection.SessionOptions.Sealing -or $connection.AuthType -ne [System.DirectoryServices.Protocols.AuthType]::Kerberos) { throw 'AD_PROTECTION_REQUIRED' }
    $failure = 'AD_SEARCH_FAILED'
    $script:stage = 'rootdse'
    $root = New-Object System.DirectoryServices.Protocols.SearchRequest
    $root.DistinguishedName = ''
    $root.Filter = '(objectClass=*)'
    $root.Scope = [System.DirectoryServices.Protocols.SearchScope]::Base
    [void]$root.Attributes.Add('defaultNamingContext')
    $rootResponse = [System.DirectoryServices.Protocols.SearchResponse]$connection.SendRequest($root)
    if ($rootResponse.Entries.Count -ne 1) { throw 'AD_SEARCH_FAILED' }
    $base = Attribute-Text $rootResponse.Entries[0] 'defaultNamingContext'
    $expectedBase = ($request.domain.Split('.') | ForEach-Object { 'DC=' + $_ }) -join ','
    $failure = 'AD_DOMAIN_MISMATCH'
    if ($base -ine $expectedBase) { throw 'AD_DOMAIN_MISMATCH' }
    $failure = 'AD_SEARCH_FAILED'
    $users = Read-Objects 'users' '(&(objectCategory=person)(objectClass=user))' $base
    $groups = Read-Objects 'groups' '(&(objectCategory=group)(groupType:1.2.840.113556.1.4.803:=2147483648))' $base
    $computers = Read-Objects 'computers' '(objectCategory=computer)' $base
    $script:stage = 'serialize'
    @{domain=[string]$request.domain; dc_fqdn=[string]$request.dc_fqdn; transport='kerberos-sign-seal'; users=@($users); groups=@($groups); computers=@($computers)} | ConvertTo-Json -Depth 8 -Compress
} catch {
    $errorCode = $failure
    $exception = $_.Exception
    while ($exception.InnerException) { $exception = $exception.InnerException }
    if ($exception.GetType().FullName -eq 'System.DirectoryServices.Protocols.LdapException' -and $exception.ErrorCode -eq 49) { $errorCode = 'AD_CREDENTIALS_REJECTED' }
    if ($_.Exception.Message -eq 'AD_DIRECTORY_LIMIT') { $errorCode = 'AD_DIRECTORY_LIMIT' }
    $reason = 'UNKNOWN'
    if ($_.FullyQualifiedErrorId -in @('PropertyNotFoundStrict', 'PropertyAssignmentException')) { $reason = 'PROPERTY_ACCESS' }
    if ($_.FullyQualifiedErrorId -in @('MethodNotFound', 'MethodException', 'MethodArgumentConversionInvalidCastArgument')) { $reason = 'METHOD_BINDING' }
    if ($exception.GetType().FullName -eq 'System.DirectoryServices.Protocols.DirectoryOperationException') {
        $reason = 'LDAP_RESULT'
        if ($exception.Response -and $exception.Response.ResultCode -eq [System.DirectoryServices.Protocols.ResultCode]::InsufficientAccessRights) { $reason = 'ACCESS_DENIED' }
    }
    if ($exception.GetType().FullName -eq 'System.DirectoryServices.Protocols.LdapException') { $reason = 'LDAP_CONNECTION' }
    if ($exception -is [System.ArgumentException] -or $exception -is [System.FormatException] -or $exception -is [System.InvalidCastException]) { $reason = 'VALUE_CONVERSION' }
    if ($_.Exception.Message -in @('ATTRIBUTE_MISSING', 'BINARY_ATTRIBUTE_INVALID', 'REFERRAL_RETURNED', 'LDAP_RESULT')) { $reason = $_.Exception.Message }
    # Fixed enums only; no exception messages, credentials, DNs or object values.
    @{error=$errorCode; stage=$script:stage; reason=$reason} | ConvertTo-Json -Compress
    exit 1
} finally {
    if ($connection) { $connection.Dispose() }
    if ($request) { $request.password = '' }
    $credential = $null
}
