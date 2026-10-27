#Requires -Version 5.1
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$ConfigPath,
 [Parameter(Mandatory=$true)][ValidatePattern('^[0-9A-F]{40}$')][string]$PublisherThumbprint)
$ErrorActionPreference='Stop';Set-StrictMode -Version 2
# Canonical body hashes are generated from this reviewed release, not caller input.
$reviewed=@{
 'ConnectorServiceRuntime.ps1'='AD15F8458DF71C82BFF1B572C2AC12B598D9F74E8AAE1FABBCE0736F766AADAC'
 'Compare-AuthWireSigningKeyAcl.ps1'='EA8D67AC4F7673654C24BEE7B59AAF6D50F0427BDAC6D05C535CD5D2D47E8734'
 'ConnectorChannelTypes.ps1'='F8528467E767200FE16FB97414CD1F494DC9F8813D73EE0D2BFB5088EABB592C'
 'ConnectorChannelKey.ps1'='D6F0D2CEBDE20B9016AC8BC1C1CDE566245A722AE447164FE55C946CFAD43BD6'
 'New-AuthWireConnectorHealthProof.ps1'='E8E369DCD0B60375EA2ADB672F904DDA217D22DB3BAB5A9B4981607E24958940'
 'Invoke-AuthWireConnectorHealth.ps1'='1A58B86580FF123D2CD253B774F015A9BBA747E5B072346786D6C133BED2122D'
 'ConnectorServiceHost.cs'='14E2246637793391937D16E8FB73218E237E9A57F26B7210B560F9A1C9F8082F'
 'Invoke-AuthWireConnectorProbeJob.ps1'='D032EB81410B2914EB72D9D70AD7A742773AFCBFE8D536B820D81D1C8B9D85B6'
 'Invoke-AuthWireCandidateJob.ps1'='8252BC3048D823DF34183B49C87BEC7667908A06176CCE4F5EF65140190F3CDD'
 'Test-AuthWireDeploymentCandidate.ps1'='24D3868C7D9D1B9747535092B2F3234FE8A18BF9D6EB5DEB1A36780E894C8829'
 'DeploymentScope.ps1'='EA53CA58E5B1911C306808DCB42B973CA402E4F1A7C9ADA677B0ACEB0E727D7F'
 'Invoke-AuthWireScopeJob.ps1'='18C9CF374DC20724AC8889AB409448DAABDD7BE383BD4D8DBE307395EC389A05'
 'Read-AuthWireDeploymentScope.ps1'='AAB6A44FE9A727C1A13528B1291DEC6BF3B5232B95312882415E6E5925BDF370'
 'ConnectorServicePackage.ps1'='471B1DCE6F31DF9785F62A1E17B86DF3172327D7C6A662DF274CF18EE90B4B0F'
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
