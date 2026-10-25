# Health-channel primitive only. No service installation, network, AD, GPO or key creation.
# Load from an administrator-controlled, corporate-signed connector package.
Set-StrictMode -Version 2

function Get-AuthWireChannelPublicKeyId {
    param([Parameter(Mandatory=$true)][Security.Cryptography.RSACng]$ChannelKey)
    if ($ChannelKey.KeySize -notin @(3072,4096)) { throw 'CONNECTOR_KEY_INVALID' }
    $parameters=$ChannelKey.ExportParameters($false) # Public modulus/exponent only.
    if ([Convert]::ToBase64String($parameters.Exponent) -cne 'AQAB') { throw 'CONNECTOR_KEY_INVALID' }
    $raw=[Text.Encoding]::ASCII.GetBytes("AuthWireConnectorKeyV1`n"+[Convert]::ToBase64String($parameters.Modulus)+"`nAQAB`n")
    $sha=[Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($sha.ComputeHash($raw))).Replace('-','').ToLowerInvariant() }
    finally { $sha.Dispose() }
}

function New-AuthWireConnectorHealthProof {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$FrameBase64,
        [Parameter(Mandatory=$true)][hashtable]$Binding,
        [Parameter(Mandatory=$true)][Security.Cryptography.RSACng]$ChannelKey
    )
    $names=@('instance_id','connector_id','generation','host_guid','host_fqdn','service_sid','appliance_fqdn','appliance_tls_sha256','channel_key_sha256')
    if ($Binding.Count -ne $names.Count -or @($names|Where-Object {-not $Binding.ContainsKey($_)}).Count) { throw 'CONNECTOR_BINDING_INVALID' }
    foreach ($n in @('instance_id','connector_id','host_guid')) {
        $g=[guid]::Empty
        if ($Binding[$n] -isnot [string] -or -not [guid]::TryParseExact($Binding[$n],'D',[ref]$g) -or $g -eq [guid]::Empty -or $g.ToString('D') -cne $Binding[$n]) { throw 'CONNECTOR_BINDING_INVALID' }
    }
    if (($Binding.generation -isnot [int] -and $Binding.generation -isnot [long]) -or $Binding.generation -lt 1 -or $Binding.generation -gt 2147483647) { throw 'CONNECTOR_BINDING_INVALID' }
    foreach ($n in @('host_fqdn','appliance_fqdn')) {
        $v=$Binding[$n]
        if ($v -isnot [string] -or $v.Length -gt 253 -or $v -cne $v.ToLowerInvariant() -or $v.Split('.').Count -lt 2) { throw 'CONNECTOR_BINDING_INVALID' }
        foreach ($label in $v.Split('.')) {
            if ($label -cnotmatch '\A[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\z') { throw 'CONNECTOR_BINDING_INVALID' }
        }
    }
    if ($Binding.service_sid -isnot [string] -or $Binding.service_sid -cnotmatch '\AS-1-5-21-(?:[1-9][0-9]{0,9}-){3}[1-9][0-9]{0,9}\z') { throw 'CONNECTOR_BINDING_INVALID' }
    foreach ($part in $Binding.service_sid.Split('-')[4..7]) {
        if ([long]$part -gt 4294967295) { throw 'CONNECTOR_BINDING_INVALID' }
    }
    foreach ($n in @('appliance_tls_sha256','channel_key_sha256')) {
        if ($Binding[$n] -isnot [string] -or $Binding[$n] -cnotmatch '\A[0-9a-f]{64}\z') { throw 'CONNECTOR_BINDING_INVALID' }
    }
    $identity=[Security.Principal.WindowsIdentity]::GetCurrent()
    try { $sid=$identity.User.Value } finally { $identity.Dispose() }
    if ($sid -cne $Binding.service_sid -or [Environment]::MachineName.ToLowerInvariant() -cne $Binding.host_fqdn.Split('.')[0]) { throw 'CONNECTOR_RUNTIME_IDENTITY_MISMATCH' }
    $key=$ChannelKey.Key
    if (-not $key.IsMachineKey -or $key.IsEphemeral -or [int]$key.ExportPolicy -ne 0 -or [int]$key.KeyUsage -ne 2 -or $key.Provider.Provider -cne 'Microsoft Software Key Storage Provider') { throw 'CONNECTOR_KEY_POLICY_REJECTED' }
    if ((Get-AuthWireChannelPublicKeyId -ChannelKey $ChannelKey) -cne $Binding.channel_key_sha256) { throw 'CONNECTOR_KEY_MISMATCH' }
    if ($FrameBase64.Length -gt 4096) { throw 'CONNECTOR_FRAME_REJECTED' }
    try { $raw=[Convert]::FromBase64String($FrameBase64) } catch { throw 'CONNECTOR_FRAME_REJECTED' }
    if ([Convert]::ToBase64String($raw) -cne $FrameBase64 -or $raw.Length -gt 2048) { throw 'CONNECTOR_FRAME_REJECTED' }
    foreach ($b in $raw) { if ($b -ne 10 -and ($b -lt 32 -or $b -gt 126)) { throw 'CONNECTOR_FRAME_REJECTED' } }
    $parts=[Text.Encoding]::ASCII.GetString($raw).Split([char]10)
    if ($parts.Count -ne 17 -or $parts[16] -cne '' -or $parts[0] -cne 'AUTHWIRE-CONNECTOR-HEALTH-V1' -or $parts[14] -cne 'POST' -or $parts[15] -cne '/api/connector/v1/health') { throw 'CONNECTOR_FRAME_REJECTED' }
    for ($i=0; $i -lt $names.Count; $i++) {
        $expected=if ($names[$i] -eq 'generation') { $Binding.generation.ToString([Globalization.CultureInfo]::InvariantCulture) } else { $Binding[$names[$i]] }
        if ($parts[$i+1] -cne $expected) { throw 'CONNECTOR_FRAME_BINDING_MISMATCH' }
    }
    if ($parts[10] -cnotmatch '\A[0-9a-f]{64}\z' -or $parts[11] -cnotmatch '\A[0-9a-f]{64}\z' -or $parts[12] -cnotmatch '\A[1-9][0-9]{0,10}\z' -or $parts[13] -cnotmatch '\A[1-9][0-9]{0,10}\z') { throw 'CONNECTOR_FRAME_REJECTED' }
    $issued=[long]$parts[12]; $expires=[long]$parts[13]; $now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    if ($expires-$issued -ne 60 -or $now -lt $issued-5 -or $now -ge $expires) { throw 'CONNECTOR_FRAME_EXPIRED' }
    $signature=$ChannelKey.SignData($raw,[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1)
    [pscustomobject]@{challenge_id=$parts[10]; signature=[Convert]::ToBase64String($signature)}
}
