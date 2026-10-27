#Requires -Version 5.1
[CmdletBinding()]
param([ValidateSet('Inspect','Prepare','Apply','Rollback')][string]$Mode='Inspect',
 [Parameter(Mandatory=$true)][guid]$ConnectorId,
 [Parameter(Mandatory=$true)][guid]$ExpectedCurrentRelease,
 [Parameter(Mandatory=$true)][guid]$NewReleaseId,
 [Parameter(Mandatory=$true)][ValidatePattern('^[0-9A-F]{40}$')][string]$PublisherThumbprint)
$ErrorActionPreference='Stop';Set-StrictMode -Version 2
# Generated reviewed source pins; customer input cannot expand the executor.
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
 'Invoke-AuthWireScopeJob.ps1'='A3DA082AF17D6F17948D03A867144F6435175DE615E5C7BD7369EF6F3B34B9C7'
 'Read-AuthWireDeploymentScope.ps1'='AAB6A44FE9A727C1A13528B1291DEC6BF3B5232B95312882415E6E5925BDF370'
 'ConnectorServicePackage.ps1'='C356F5E97E9A3D246E676B8622B739293D3CF33D35A9A57B7C26167937B657CE'
 'ConnectorServiceControl.ps1'='A6BA90BB2AABD1BB0AD12F649A0E7EABBEDC54776194042A538D5FE8FEC3F97D'
 'Install-AuthWireConnectorService.ps1'='FD91F9AF6E7838CE1F795E8E3F64F0E10AFE7380FBEB9524D211CADFEBD7227F'
 'Initialize-AuthWireConnectorChannelKey.ps1'='836FC43FEACB286239E556A1E2339E8AB141F1FE8363BF243764C087DDB0EECE'
 'ConnectorServiceUpgrade.ps1'='21BFC416413A506FD345911B1FA3B0A919FBA9C83DBAB80CB2100C68C04650E2'
}
$locks=@()
try{
 foreach($file in $reviewed.Keys){
  $p=Join-Path $PSScriptRoot $file
  $locks+=([IO.File]::Open($p,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::Read))
  $text=[IO.File]::ReadAllText($p);$body=($text -split '(?m)^# SIG # Begin signature block\r?$',2)[0]
  $body=$body.Replace("`r`n","`n").TrimEnd([char[]]"`r`n")+"`n"
  $sha=[Security.Cryptography.SHA256]::Create()
  try{$hash=([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($body)))).Replace('-','')}finally{$sha.Dispose()}
  if($hash -cne $reviewed[$file]){throw ('CONNECTOR_UPGRADE_UNREVIEWED_SOURCE:'+ $file)}
  if($file.EndsWith('.ps1')){
   $sig=Get-AuthenticodeSignature -FilePath $p
   if($sig.Status.ToString() -cne 'Valid' -or $sig.SignerCertificate.Thumbprint -cne $PublisherThumbprint){throw 'CONNECTOR_UPGRADE_TOOL_SIGNATURE_REJECTED'}
  }
 }
 foreach($file in @('ConnectorServicePackage.ps1','ConnectorServiceControl.ps1','ConnectorChannelKey.ps1','ConnectorChannelTypes.ps1','Compare-AuthWireSigningKeyAcl.ps1','New-AuthWireConnectorHealthProof.ps1','ConnectorServiceUpgrade.ps1')){. (Join-Path $PSScriptRoot $file)}
 Invoke-AuthWireServiceUpgradeCore -Mode $Mode -ConnectorId $ConnectorId -ExpectedCurrentRelease $ExpectedCurrentRelease -NewReleaseId $NewReleaseId -PublisherThumbprint $PublisherThumbprint -SourceDirectory $PSScriptRoot|ConvertTo-Json -Depth 6
}finally{foreach($handle in $locks){$handle.Dispose()}}
