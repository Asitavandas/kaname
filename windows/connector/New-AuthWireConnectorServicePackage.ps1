#Requires -Version 5.1
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$ConfigPath,
 [Parameter(Mandatory=$true)][ValidatePattern('^[0-9A-F]{40}$')][string]$PublisherThumbprint)
$ErrorActionPreference='Stop';Set-StrictMode -Version 2
# Canonical body hashes are generated from this reviewed release, not caller input.
$reviewed=@{
 'ConnectorServiceRuntime.ps1'='DFC6295927C18750DFBA399C7E59768326206CF97D1F44D43B719D4BCE27DF77'
 'Compare-AuthWireSigningKeyAcl.ps1'='EA8D67AC4F7673654C24BEE7B59AAF6D50F0427BDAC6D05C535CD5D2D47E8734'
 'ConnectorChannelTypes.ps1'='C52C2F8414CE09B2ABE303E6628C9DE3BC3F8121D7EB7FCBCFE39C735E04A1D5'
 'ConnectorChannelKey.ps1'='D6F0D2CEBDE20B9016AC8BC1C1CDE566245A722AE447164FE55C946CFAD43BD6'
 'New-AuthWireConnectorHealthProof.ps1'='E8E369DCD0B60375EA2ADB672F904DDA217D22DB3BAB5A9B4981607E24958940'
 'Invoke-AuthWireConnectorHealth.ps1'='1A58B86580FF123D2CD253B774F015A9BBA747E5B072346786D6C133BED2122D'
 'ConnectorServiceHost.cs'='14E2246637793391937D16E8FB73218E237E9A57F26B7210B560F9A1C9F8082F'
 'Invoke-AuthWireConnectorProbeJob.ps1'='D032EB81410B2914EB72D9D70AD7A742773AFCBFE8D536B820D81D1C8B9D85B6'
 'ConnectorServicePackage.ps1'='0CE1B962B0D1504DF24F5B563A1FDEC4EE9CF5187D7B1DE26E89B36A480A02D5'
 'ConnectorServiceControl.ps1'='A6BA90BB2AABD1BB0AD12F649A0E7EABBEDC54776194042A538D5FE8FEC3F97D'
 'Install-AuthWireConnectorService.ps1'='FD91F9AF6E7838CE1F795E8E3F64F0E10AFE7380FBEB9524D211CADFEBD7227F'
 'Initialize-AuthWireConnectorChannelKey.ps1'='836FC43FEACB286239E556A1E2339E8AB141F1FE8363BF243764C087DDB0EECE'
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
  if((Get-SourceDigest ([IO.File]::ReadAllText($path))) -cne $reviewed[$file]){throw ('CONNECTOR_UNREVIEWED_SOURCE_REJECTED:'+$file)}
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
  $destination=Join-Path $admin $file;Copy-Item -LiteralPath $inputPath -Destination $destination
  $fileSecurity=[Security.AccessControl.FileSecurity]::new();$fileSecurity.SetSecurityDescriptorSddlForm('O:BAG:BAD:P(A;;FA;;;SY)(A;;FA;;;BA)')
  Set-Acl -LiteralPath $destination -AclObject $fileSecurity
 }
 $result|ConvertTo-Json -Depth 4
}finally{foreach($handle in $locks){$handle.Dispose()}}
