#Requires -Version 5.1
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$ConfigPath,
 [Parameter(Mandatory=$true)][ValidatePattern('^[0-9A-F]{40}$')][string]$PublisherThumbprint)
$ErrorActionPreference='Stop';Set-StrictMode -Version 2
foreach($file in @('ConnectorServicePackage.ps1','Compare-AuthWireSigningKeyAcl.ps1','ConnectorChannelTypes.ps1','ConnectorChannelKey.ps1','New-AuthWireConnectorHealthProof.ps1')){
 $path=Join-Path $PSScriptRoot $file;$s=Get-AuthenticodeSignature -FilePath $path
 if($s.Status.ToString() -ne 'Valid' -or $s.SignerCertificate.Thumbprint -cne $PublisherThumbprint){throw 'CONNECTOR_BUILD_TOOL_SIGNATURE_REJECTED'}
 . $path
}
Assert-AuthWireServiceAdmin;Assert-AuthWireChannelPath $ConfigPath
if((Get-Item -LiteralPath $ConfigPath).Length -gt 16384){throw 'CONNECTOR_CONFIG_REJECTED'}
$c=Get-Content -LiteralPath $ConfigPath -Raw|ConvertFrom-Json
if($c.PublisherThumbprint -cne $PublisherThumbprint){throw 'CONNECTOR_PUBLISHER_REJECTED'}
$source=Join-Path $PSScriptRoot 'ConnectorServiceHost.cs';Assert-AuthWireChannelPath $source
if((Get-FileHash -LiteralPath $source -Algorithm SHA256).Hash -cne 'F228C76BC2057CD051D421F38F6E9DA863877557FB19C13D446C857541511FFC'){throw 'CONNECTOR_HOST_SOURCE_REJECTED'}
$certificate=Get-Item -LiteralPath ('Cert:\LocalMachine\My\'+$PublisherThumbprint)
if(-not $certificate.HasPrivateKey -or [DateTime]::UtcNow -lt $certificate.NotBefore.ToUniversalTime() -or [DateTime]::UtcNow -ge $certificate.NotAfter.ToUniversalTime()){throw 'CONNECTOR_SIGNER_UNAVAILABLE'}
New-AuthWireServicePackageCore -Config $c -Publisher $certificate|ConvertTo-Json -Depth 4
