#Requires -Version 5.1
[CmdletBinding()]
param([ValidateSet('Inspect','Install','Start','Stop','Remove')][string]$Mode='Inspect',
 [Parameter(Mandatory=$true)][guid]$ConnectorId,
 [Parameter(Mandatory=$true)][ValidatePattern('^[0-9A-F]{40}$')][string]$PublisherThumbprint,
 [string]$BootstrapPath,[string]$BootstrapPublisherThumbprint,
 [string]$ChannelPreparationPath)
$ErrorActionPreference='Stop';Set-StrictMode -Version 2
foreach($f in @('ConnectorServicePackage.ps1','ConnectorServiceControl.ps1','ConnectorChannelKey.ps1','ConnectorChannelTypes.ps1','Compare-AuthWireSigningKeyAcl.ps1','New-AuthWireConnectorHealthProof.ps1')){
 $p=Join-Path $PSScriptRoot $f;$s=Get-AuthenticodeSignature -FilePath $p
 if($s.Status.ToString() -ne 'Valid' -or $s.SignerCertificate.Thumbprint -cne $PublisherThumbprint){throw 'CONNECTOR_TOOL_SIGNATURE_REJECTED'}
 . $p
}
$root=Join-Path $env:ProgramW6432 ('AuthWire-Connector-'+$ConnectorId.ToString('N'))
$c=Get-AuthWireServicePackage $root $PublisherThumbprint
if($c.Binding.connector_id -cne $ConnectorId.ToString('D')){throw 'CONNECTOR_ID_MISMATCH'}
if($Mode -eq 'Install'){
 if($c.AccountName -notmatch '\\([A-Za-z0-9][A-Za-z0-9-]{0,14})\$\z'){throw 'CONNECTOR_EXISTING_GMSA_REQUIRED'}
 $account=$Matches[1]
 $name=[Security.Principal.NTAccount]::new($c.AccountName)
 if($name.Translate([Security.Principal.SecurityIdentifier]).Value -cne $c.Binding.service_sid){throw 'CONNECTOR_ACCOUNT_SID_MISMATCH'}
 $signature=Get-AuthenticodeSignature -FilePath $ChannelPreparationPath
 if($signature.Status.ToString() -ne 'Valid' -or $signature.SignerCertificate.Thumbprint -cne $PublisherThumbprint){throw 'CONNECTOR_PREPARATION_SIGNATURE_REJECTED'}
 $domain=$c.Binding.host_fqdn.Substring($c.Binding.host_fqdn.IndexOf('.')+1)
 $key=& $ChannelPreparationPath -Mode Inspect -ExpectedComputer ([Environment]::MachineName) -ExpectedDomain $domain -ConnectorId $ConnectorId -ApplianceInstanceId ([guid]$c.Binding.instance_id) -ApplianceFqdn $c.Binding.appliance_fqdn -ApplianceTlsSha256 $c.Binding.appliance_tls_sha256 -AccountName $account -AccountSid $c.Binding.service_sid -BootstrapPath $BootstrapPath -PublisherThumbprint $PublisherThumbprint -BootstrapPublisherThumbprint $BootstrapPublisherThumbprint|ConvertFrom-Json
 if(-not $key.ReadAclVerified -or -not $key.KeyPropertiesVerified -or $key.KeyCreated -or $key.KeyName -cne $c.KeyName -or $key.KeySha256 -cne $c.Binding.channel_key_sha256){throw 'CONNECTOR_OWNED_KEY_REQUIRED'}
 $trusted=[Security.Cryptography.X509Certificates.X509Store]::new('TrustedPublisher','LocalMachine')
 try{$trusted.Open([Security.Cryptography.X509Certificates.OpenFlags]::ReadOnly);if($trusted.Certificates.Find([Security.Cryptography.X509Certificates.X509FindType]::FindByThumbprint,$PublisherThumbprint,$true).Count -ne 1){throw 'CONNECTOR_MACHINE_PUBLISHER_TRUST_REQUIRED'}}finally{$trusted.Dispose()}
}
Invoke-AuthWireServiceControlCore -Mode $Mode -RootPath $root -ExpectedPublisher $PublisherThumbprint|ConvertTo-Json -Depth 4
