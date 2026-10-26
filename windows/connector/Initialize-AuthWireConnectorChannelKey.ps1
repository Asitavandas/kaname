#Requires -Version 5.1
[CmdletBinding()]
param(
 [ValidateSet('Inspect','PrepareKey')][string]$Mode='Inspect',
 [Parameter(Mandatory=$true)][string]$ExpectedComputer,
 [Parameter(Mandatory=$true)][string]$ExpectedDomain,
 [Parameter(Mandatory=$true)][guid]$ConnectorId,
 [Parameter(Mandatory=$true)][guid]$ApplianceInstanceId,
 [Parameter(Mandatory=$true)][string]$ApplianceFqdn,
 [Parameter(Mandatory=$true)][ValidatePattern('^[0-9a-f]{64}$')][string]$ApplianceTlsSha256,
 [string]$AccountName='aw-deploy',
 [Parameter(Mandatory=$true)][string]$AccountSid,
 [Parameter(Mandatory=$true)][string]$BootstrapPath,
 [Parameter(Mandatory=$true)][ValidatePattern('^[0-9A-Fa-f]{40}$')][string]$PublisherThumbprint,
 [ValidatePattern('^[0-9A-Fa-f]{40}$')][string]$BootstrapPublisherThumbprint
)
$ErrorActionPreference='Stop';Set-StrictMode -Version 2
if(-not $BootstrapPublisherThumbprint){$BootstrapPublisherThumbprint=$PublisherThumbprint}
if(-not [Environment]::Is64BitProcess -or [Environment]::MachineName -ine $ExpectedComputer){throw 'LOCAL_COMPUTER_MISMATCH'}
foreach($path in @($BootstrapPath,(Join-Path $PSScriptRoot 'ConnectorChannelTypes.ps1'),(Join-Path $PSScriptRoot 'ConnectorChannelKey.ps1'),(Join-Path $PSScriptRoot 'Compare-AuthWireSigningKeyAcl.ps1'),(Join-Path $PSScriptRoot 'New-AuthWireConnectorHealthProof.ps1'))){
 if((Get-Item -LiteralPath $path).Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'SIGNED_TOOL_REQUIRED'}
 $s=Get-AuthenticodeSignature -FilePath $path
 $expectedPublisher=if($path -eq $BootstrapPath){$BootstrapPublisherThumbprint}else{$PublisherThumbprint}
 if($s.Status.ToString() -ne 'Valid' -or $s.SignerCertificate.Thumbprint -ine $expectedPublisher){throw 'PREPARATION_TOOL_SIGNATURE_INVALID'}
}
$gate=& $BootstrapPath -Mode Inspect -ExpectedDomain $ExpectedDomain -ConnectorComputer $ExpectedComputer -InstanceId $ConnectorId -AccountName $AccountName -PublisherThumbprint $BootstrapPublisherThumbprint|ConvertFrom-Json
if($gate.Event -ne 'WINDOWS_CONNECTOR_BOOTSTRAP' -or $gate.BootstrapVersion -ne '1.0.3' -or $gate.Mode -ne 'Inspect' -or $gate.Computer -ine $ExpectedComputer -or $gate.ConnectorComputer -ine $ExpectedComputer -or $gate.Domain -ine $ExpectedDomain -or @($gate.Blockers).Count -ne 0 -or -not $gate.ReadyForAccountPreparation -or -not $gate.Kds.Ready -or -not $gate.Account.Exists -or $gate.Account.Created -or $gate.Account.Name -ine ($AccountName+'$') -or $gate.Account.Sid -cne $AccountSid -or $gate.InstanceId -ine $ConnectorId.ToString('D') -or $gate.AdChanged -or $gate.GpoChanged -or $gate.CertificatesChanged -or $gate.LocalPolicyChanged -or $gate.SecretsExported){throw 'OWNED_ACCOUNT_REQUIRED'}
Import-Module ActiveDirectory -ErrorAction Stop
$ready=@(Test-ADServiceAccount -Identity $AccountSid -ErrorAction Stop)
if($ready.Count -ne 1 -or $ready[0] -isnot [bool] -or -not $ready[0]){throw 'LOCAL_GMSA_READINESS_REQUIRED'}
foreach($file in @('Compare-AuthWireSigningKeyAcl.ps1','ConnectorChannelTypes.ps1','New-AuthWireConnectorHealthProof.ps1','ConnectorChannelKey.ps1')){. (Join-Path $PSScriptRoot $file)}
$base=@{instance_id=$ApplianceInstanceId.ToString('D');connector_id=$ConnectorId.ToString('D');host_guid=[string]$gate.ConnectorComputerGuid;host_fqdn=($ExpectedComputer.ToLowerInvariant()+'.'+$ExpectedDomain.ToLowerInvariant());service_sid=$AccountSid;appliance_fqdn=$ApplianceFqdn;appliance_tls_sha256=$ApplianceTlsSha256}
$directory=Join-Path $env:ProgramData ('AuthWire-Connector-'+$ConnectorId.ToString('N'))
Initialize-AuthWireChannelKeyCore -Mode $Mode -Directory $directory -BaseBinding $base|ConvertTo-Json -Depth 6
