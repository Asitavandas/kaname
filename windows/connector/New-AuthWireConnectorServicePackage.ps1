#Requires -Version 5.1
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$ConfigPath,
 [Parameter(Mandatory=$true)][ValidatePattern('^[0-9A-F]{40}$')][string]$PublisherThumbprint)
$ErrorActionPreference='Stop';Set-StrictMode -Version 2
# Canonical body hashes are generated from this reviewed release, not caller input.
$reviewed=@{
 'ConnectorServiceHost.cs'='F228C76BC2057CD051D421F38F6E9DA863877557FB19C13D446C857541511FFC'
 'ConnectorServiceRuntime.ps1'='58BECDFB6F2E08659F9E4C5443DC89A6F265E7767A612E0FFEC67C39ABD0DD0B'
 'ConnectorServicePackage.ps1'='B3E3FEDF8859558C3A7210B69D032D9A2FEED8223D9C26C396FA6DFD6ECCE2F9'
 'ConnectorServiceControl.ps1'='0CB60C8D3BD090A5F1F514E678F8F88C7E2B2D2A0A8A7516988C51028E359F30'
 'Install-AuthWireConnectorService.ps1'='FD91F9AF6E7838CE1F795E8E3F64F0E10AFE7380FBEB9524D211CADFEBD7227F'
 'Initialize-AuthWireConnectorChannelKey.ps1'='836FC43FEACB286239E556A1E2339E8AB141F1FE8363BF243764C087DDB0EECE'
 'ConnectorChannelKey.ps1'='D6F0D2CEBDE20B9016AC8BC1C1CDE566245A722AE447164FE55C946CFAD43BD6'
 'ConnectorChannelTypes.ps1'='FA198F9A1C0AD75DB2C577A9D109246C7811249E8124E6541CE8B5AE19FAB61C'
 'Compare-AuthWireSigningKeyAcl.ps1'='EA8D67AC4F7673654C24BEE7B59AAF6D50F0427BDAC6D05C535CD5D2D47E8734'
 'New-AuthWireConnectorHealthProof.ps1'='E8E369DCD0B60375EA2ADB672F904DDA217D22DB3BAB5A9B4981607E24958940'
 'Invoke-AuthWireConnectorHealth.ps1'='1A58B86580FF123D2CD253B774F015A9BBA747E5B072346786D6C133BED2122D'
}
function Get-SourceDigest([string]$text){
 $body=($text -split '(?m)^# SIG # Begin signature block\r?$',2)[0]
 $body=$body.Replace("`r`n","`n").TrimEnd([char[]]"`r`n")+"`n"
 $sha=[Security.Cryptography.SHA256]::Create()
 try{return ([BitConverter]::ToString($sha.ComputeHash([Text.UTF8Encoding]::new($false).GetBytes($body)))).Replace('-','')}finally{$sha.Dispose()}
}
$locks=@()
try{
 foreach($file in $reviewed.Keys){
  $path=Join-Path $PSScriptRoot $file
  # Keep source bytes locked against write/rename through validation, loading and build.
  $locks+=([IO.File]::Open($path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read))
  if((Get-SourceDigest ([IO.File]::ReadAllText($path))) -cne $reviewed[$file]){throw 'CONNECTOR_UNREVIEWED_SOURCE_REJECTED'}
 }
 foreach($file in @('ConnectorServicePackage.ps1','Compare-AuthWireSigningKeyAcl.ps1','ConnectorChannelTypes.ps1','ConnectorChannelKey.ps1','New-AuthWireConnectorHealthProof.ps1')){
  $path=Join-Path $PSScriptRoot $file;$s=Get-AuthenticodeSignature -FilePath $path
  if($s.Status.ToString() -ne 'Valid' -or $s.SignerCertificate.Thumbprint -cne $PublisherThumbprint){throw 'CONNECTOR_BUILD_TOOL_SIGNATURE_REJECTED'}
  . $path
 }
 Assert-AuthWireServiceAdmin;Assert-AuthWireChannelPath $ConfigPath
 if((Get-Item -LiteralPath $ConfigPath).Length -gt 16384){throw 'CONNECTOR_CONFIG_REJECTED'}
 $c=Get-Content -LiteralPath $ConfigPath -Raw|ConvertFrom-Json
 if($c.PublisherThumbprint -cne $PublisherThumbprint){throw 'CONNECTOR_PUBLISHER_REJECTED'}
 $certificate=Get-Item -LiteralPath ('Cert:\LocalMachine\My\'+$PublisherThumbprint)
 if(-not $certificate.HasPrivateKey -or [DateTime]::UtcNow -lt $certificate.NotBefore.ToUniversalTime() -or [DateTime]::UtcNow -ge $certificate.NotAfter.ToUniversalTime()){throw 'CONNECTOR_SIGNER_UNAVAILABLE'}
 $result=New-AuthWireServicePackageCore -Config $c -Publisher $certificate
 # Administrative tools stay unreadable/unwritable to the service account.
 $admin=Join-Path $result.RootPath 'admin'
 $security=[Security.AccessControl.DirectorySecurity]::new();$security.SetSecurityDescriptorSddlForm('O:BAG:BAD:P(A;OICI;FA;;;SY)(A;OICI;FA;;;BA)')
 $null=[IO.Directory]::CreateDirectory($admin,$security)
 foreach($file in @('Install-AuthWireConnectorService.ps1','ConnectorServicePackage.ps1','ConnectorServiceControl.ps1','Initialize-AuthWireConnectorChannelKey.ps1','ConnectorChannelKey.ps1','ConnectorChannelTypes.ps1','Compare-AuthWireSigningKeyAcl.ps1','New-AuthWireConnectorHealthProof.ps1')){
  $inputPath=Join-Path $PSScriptRoot $file;$s=Get-AuthenticodeSignature -FilePath $inputPath
  if($s.Status.ToString() -ne 'Valid' -or $s.SignerCertificate.Thumbprint -cne $PublisherThumbprint){throw 'CONNECTOR_ADMIN_TOOL_SIGNATURE_REJECTED'}
  Copy-Item -LiteralPath $inputPath -Destination (Join-Path $admin $file)
 }
 $result|ConvertTo-Json -Depth 4
}finally{foreach($handle in $locks){$handle.Dispose()}}
