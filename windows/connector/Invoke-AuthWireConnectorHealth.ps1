# Load only from a verified, administrator-controlled connector package.
function Invoke-AuthWireConnectorHealth {
    param([Parameter(Mandatory=$true)][string]$BaseUrl,
          [Parameter(Mandatory=$true)][hashtable]$Binding,
          [Parameter(Mandatory=$true)][Security.Cryptography.RSACng]$ChannelKey)
    Initialize-AuthWireChannelTypes
    $poll=New-AuthWireConnectorPollProof -Binding $Binding -ChannelKey $ChannelKey
    $reply=[AuthWire.Connector.ChannelTypesV1]::Post($BaseUrl,$Binding.appliance_fqdn,$Binding.appliance_tls_sha256,'/api/connector/v1/challenge',($poll|ConvertTo-Json -Compress))
    $frame=[AuthWire.Connector.ChannelTypesV1]::Frame($reply)
    $proof=New-AuthWireConnectorHealthProof -FrameBase64 $frame -Binding $Binding -ChannelKey $ChannelKey
    $result=[AuthWire.Connector.ChannelTypesV1]::Post($BaseUrl,$Binding.appliance_fqdn,$Binding.appliance_tls_sha256,'/api/connector/v1/health',($proof|ConvertTo-Json -Compress))
    if(-not [AuthWire.Connector.ChannelTypesV1]::Healthy($result)){throw 'CONNECTOR_REPLY_REJECTED'}
    [pscustomobject]@{Event='WINDOWS_CONNECTOR_HTTPS_HEALTH';Verified=$true;CanApply=$false;DirectorySyncReady=$false;KerberosReady=$false;AdChanged=$false;GpoChanged=$false;ConnectorInstalled=$false;SecretsExported=$false}
}
