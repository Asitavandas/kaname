# Read-only AD adapter. Credential JSON arrives on stdin; nothing is written to disk.
param([switch]$SelfTest)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2
[Console]::InputEncoding = New-Object System.Text.UTF8Encoding($false)
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
$connection = $null
$request = $null
$failure = 'AD_INPUT_INVALID'
function Attribute-Text($entry, [string]$name) {
    if ($entry.Attributes.Contains($name) -and $entry.Attributes[$name].Count -gt 0) {
        return [string]$entry.Attributes[$name][0]
    }
    return ''
}
function Read-Objects([string]$kind, [string]$filter, [string]$base) {
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
    $cookies = New-Object 'System.Collections.Generic.HashSet[string]'
    do {
        $response = [System.DirectoryServices.Protocols.SearchResponse]$connection.SendRequest($search)
        if ($response.ResultCode -ne [System.DirectoryServices.Protocols.ResultCode]::Success -or $response.References.Count -ne 0) {
            throw 'AD_SEARCH_FAILED'
        }
        foreach ($entry in $response.Entries) {
            $sid = [System.Security.Principal.SecurityIdentifier]::new([byte[]]$entry.Attributes['objectSid'][0], 0)
            $guid = [Guid]::new([byte[]]$entry.Attributes['objectGUID'][0])
            $name = Attribute-Text $entry 'displayName'
            if (-not $name) { $name = Attribute-Text $entry 'name' }
            $record = @{guid=$guid.ToString(); sid=$sid.Value; sam=(Attribute-Text $entry 'sAMAccountName'); name=$name}
            if ($kind -ne 'groups') {
                $uac = Attribute-Text $entry 'userAccountControl'
                if (-not $uac) { throw 'AD_SEARCH_FAILED' }
                $record.enabled = (([int64]$uac -band 2) -eq 0)
            }
            $objects.Add($record)
            if ($objects.Count -gt 10000) { throw 'AD_DIRECTORY_LIMIT' }
        }
        $control = @($response.Controls | Where-Object { $_ -is [System.DirectoryServices.Protocols.PageResultResponseControl] })
        if ($control.Count -ne 1) { throw 'AD_SEARCH_FAILED' }
        $page.Cookie = $control[0].Cookie
        if ($page.Cookie.Length -gt 0 -and -not $cookies.Add([Convert]::ToBase64String($page.Cookie))) { throw 'AD_SEARCH_FAILED' }
    } while ($page.Cookie.Length -gt 0)
    return ,$objects.ToArray()
}
try {
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
        @{self_test='passed'; transport='kerberos-sign-seal'; network_called=$false} | ConvertTo-Json -Compress
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
    $connection.Bind()
    $failure = 'AD_PROTECTION_REQUIRED'
    if (-not $connection.SessionOptions.Signing -or -not $connection.SessionOptions.Sealing -or $connection.AuthType -ne [System.DirectoryServices.Protocols.AuthType]::Kerberos) { throw 'AD_PROTECTION_REQUIRED' }
    $failure = 'AD_SEARCH_FAILED'
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
    @{domain=[string]$request.domain; dc_fqdn=[string]$request.dc_fqdn; transport='kerberos-sign-seal'; users=@($users); groups=@($groups); computers=@($computers)} | ConvertTo-Json -Depth 8 -Compress
} catch {
    $errorCode = $failure
    $exception = $_.Exception
    while ($exception.InnerException) { $exception = $exception.InnerException }
    if ($exception.GetType().FullName -eq 'System.DirectoryServices.Protocols.LdapException' -and $exception.ErrorCode -eq 49) { $errorCode = 'AD_CREDENTIALS_REJECTED' }
    if ($_.Exception.Message -eq 'AD_DIRECTORY_LIMIT') { $errorCode = 'AD_DIRECTORY_LIMIT' }
    @{error=$errorCode} | ConvertTo-Json -Compress
    exit 1
} finally {
    if ($connection) { $connection.Dispose() }
    if ($request) { $request.password = '' }
    $credential = $null
}
