# Isolated hosted-runner fixture only. Creates/removes one unique CNG key; no AD/cert/trust/SCM changes.
param([ValidateSet('Create','Sign','Cleanup')][string]$Mode,[Parameter(Mandatory=$true)][string]$Directory)
$ErrorActionPreference='Stop'
Set-StrictMode -Version 2
if ($env:RUNNER_ENVIRONMENT -ne 'github-hosted') { throw 'Hosted fixture only' }
. (Join-Path $PSScriptRoot '..\windows\connector\New-AuthWireConnectorHealthProof.ps1')
$manifest=Join-Path $Directory 'fixture.json'
if ($Mode -eq 'Create') {
    $name='AuthWire-ChannelFixture-'+[guid]::NewGuid().ToString('N')
    $parameters=[Security.Cryptography.CngKeyCreationParameters]::new()
    $parameters.Provider=[Security.Cryptography.CngProvider]::MicrosoftSoftwareKeyStorageProvider
    $parameters.KeyCreationOptions=[Security.Cryptography.CngKeyCreationOptions]::MachineKey
    $parameters.ExportPolicy=[Security.Cryptography.CngExportPolicies]::None
    $parameters.KeyUsage=[Security.Cryptography.CngKeyUsages]::Signing
    $parameters.Parameters.Add([Security.Cryptography.CngProperty]::new('Length',[BitConverter]::GetBytes(3072),[Security.Cryptography.CngPropertyOptions]::None))
    $key=[Security.Cryptography.CngKey]::Create([Security.Cryptography.CngAlgorithm]::Rsa,$name,$parameters)
    $rsa=[Security.Cryptography.RSACng]::new($key)
    try {
        $public=$rsa.ExportParameters($false)
        $identity=[Security.Principal.WindowsIdentity]::GetCurrent()
        try { $sid=$identity.User.Value } finally { $identity.Dispose() }
        $binding=@{instance_id=[guid]::NewGuid().ToString('D');connector_id=[guid]::NewGuid().ToString('D');generation=1;host_guid=[guid]::NewGuid().ToString('D');host_fqdn=([Environment]::MachineName.ToLowerInvariant()+'.fixture.example');service_sid=$sid;appliance_fqdn='authwire.fixture.example';appliance_tls_sha256=('a'*64);channel_key_sha256=(Get-AuthWireChannelPublicKeyId $rsa)}
        @{key_name=$name;binding=$binding;modulus=[Convert]::ToBase64String($public.Modulus);exponent=[Convert]::ToBase64String($public.Exponent)}|ConvertTo-Json -Depth 5|Set-Content -LiteralPath $manifest -Encoding UTF8
    } catch { $key.Delete();throw } finally { $rsa.Dispose();$key.Dispose() }
    exit 0
}
$fixture=Get-Content -LiteralPath $manifest -Raw|ConvertFrom-Json
if ($fixture.key_name -cnotmatch '\AAuthWire-ChannelFixture-[0-9a-f]{32}\z') { throw 'Fixture key name mismatch' }
$key=[Security.Cryptography.CngKey]::Open($fixture.key_name,[Security.Cryptography.CngProvider]::MicrosoftSoftwareKeyStorageProvider,[Security.Cryptography.CngKeyOpenOptions]::MachineKey)
if ($Mode -eq 'Cleanup') { $key.Delete();$key.Dispose();exit 0 }
$rsa=[Security.Cryptography.RSACng]::new($key)
$script:checks=0
function Check([bool]$Value,[string]$Name) { if(-not $Value){throw $Name};$script:checks++ }
function Reject([scriptblock]$Call,[string]$Name) {
    $failed=$false
    try { $null=& $Call } catch { $failed=$_.Exception.Message -like 'CONNECTOR_*' }
    Check $failed $Name
}
try {
    $binding=@{};foreach($p in $fixture.binding.PSObject.Properties){$binding[$p.Name]=$p.Value}
    $challenge=Get-Content -LiteralPath (Join-Path $Directory 'challenge.json') -Raw|ConvertFrom-Json
    $before=(Get-Acl -LiteralPath (Join-Path (Join-Path $env:ProgramData 'Microsoft\Crypto\Keys') $key.UniqueName)).Sddl
    Check ($key.IsMachineKey -and -not $key.IsEphemeral -and [int]$key.ExportPolicy -eq 0 -and [int]$key.KeyUsage -eq 2) 'Native persistent non-exportable machine signing key'
    $proof=New-AuthWireConnectorHealthProof -FrameBase64 $challenge.frame -Binding $binding -ChannelKey $rsa
    $raw=[Convert]::FromBase64String($challenge.frame)
    Check ($rsa.VerifyData($raw,[Convert]::FromBase64String($proof.signature),[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1)) 'Actual CNG signature independently verifies'
    $proof|ConvertTo-Json -Compress|Set-Content -LiteralPath (Join-Path $Directory 'proof.json') -Encoding UTF8
    for($i=0;$i -lt 16;$i++) {
        $parts=[Text.Encoding]::ASCII.GetString($raw).Split([char]10)
        $parts[$i]+='x'
        $bad=[Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(($parts -join "`n")))
        Reject { New-AuthWireConnectorHealthProof -FrameBase64 $bad -Binding $binding -ChannelKey $rsa } ('Reject changed frame field '+$i)
    }
    foreach($case in @('old','future','long-life','crlf','no-newline','non-ascii','base64-space','extra-line')) {
        $parts=[Text.Encoding]::ASCII.GetString($raw).Split([char]10)
        switch($case) {
            'old' {$parts[12]=([DateTimeOffset]::UtcNow.ToUnixTimeSeconds()-120).ToString();$parts[13]=([long]$parts[12]+60).ToString()}
            'future' {$parts[12]=([DateTimeOffset]::UtcNow.ToUnixTimeSeconds()+120).ToString();$parts[13]=([long]$parts[12]+60).ToString()}
            'long-life' {$parts[13]=([long]$parts[12]+61).ToString()}
        }
        $changed=$parts -join "`n"
        switch($case) {
            'crlf' {$changed=$changed.Replace("`n","`r`n")}
            'no-newline' {$changed=$changed.TrimEnd([char]10)}
            'extra-line' {$changed+="extra`n"}
            'non-ascii' {$changed=$changed.Replace('POST',([string][char]255))}
        }
        $bad=[Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($changed))
        if($case -eq 'base64-space'){$bad+="`n"}
        Reject { New-AuthWireConnectorHealthProof -FrameBase64 $bad -Binding $binding -ChannelKey $rsa } ('Reject '+$case)
    }
    foreach($case in @('sid','host','generation-type','extra-property','key-id')) {
        $badBinding=$binding.Clone()
        switch($case) {
            'sid' {$badBinding.service_sid='S-1-5-21-111-222-333-1648'}
            'host' {$badBinding.host_fqdn='another.fixture.example'}
            'generation-type' {$badBinding.generation='1'}
            'extra-property' {$badBinding.command='cmd.exe'}
            'key-id' {$badBinding.channel_key_sha256='b'*64}
        }
        Reject { New-AuthWireConnectorHealthProof -FrameBase64 $challenge.frame -Binding $badBinding -ChannelKey $rsa } ('Reject binding '+$case)
    }
    $ephemeral=[Security.Cryptography.RSACng]::new(3072)
    try {
        Reject { New-AuthWireConnectorHealthProof -FrameBase64 $challenge.frame -Binding $binding -ChannelKey $ephemeral } 'Reject ephemeral/non-machine key'
    } finally { $ephemeral.Dispose() }
    Check ((Get-Acl -LiteralPath (Join-Path (Join-Path $env:ProgramData 'Microsoft\Crypto\Keys') $key.UniqueName)).Sddl -ceq $before) 'Key ACL unchanged'
    @{native_checks=$script:checks;private_key_exported=$false;ad_changed=$false;gpo_changed=$false;service_installed=$false}|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $Directory 'native-result.json') -Encoding UTF8
} finally { $rsa.Dispose();$key.Dispose() }
