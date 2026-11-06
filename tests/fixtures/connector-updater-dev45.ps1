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
 'ConnectorServiceRuntime.ps1'='7F621C13DA00434CFCE0C0A8203EAED4B871E023C284DC2DF22113D992796457'
 'Compare-AuthWireSigningKeyAcl.ps1'='EA8D67AC4F7673654C24BEE7B59AAF6D50F0427BDAC6D05C535CD5D2D47E8734'
 'ConnectorChannelTypes.ps1'='8CA28590A49A7A48DBA1CC7413AFA0CDF7844435EF532A0E028209FB4F7E4AAB'
 'ConnectorChannelKey.ps1'='D6F0D2CEBDE20B9016AC8BC1C1CDE566245A722AE447164FE55C946CFAD43BD6'
 'New-AuthWireConnectorHealthProof.ps1'='E8E369DCD0B60375EA2ADB672F904DDA217D22DB3BAB5A9B4981607E24958940'
 'Invoke-AuthWireConnectorHealth.ps1'='1A58B86580FF123D2CD253B774F015A9BBA747E5B072346786D6C133BED2122D'
 'ConnectorServiceHost.cs'='14E2246637793391937D16E8FB73218E237E9A57F26B7210B560F9A1C9F8082F'
 'Invoke-AuthWireConnectorProbeJob.ps1'='D032EB81410B2914EB72D9D70AD7A742773AFCBFE8D536B820D81D1C8B9D85B6'
 'Invoke-AuthWireCandidateJob.ps1'='8252BC3048D823DF34183B49C87BEC7667908A06176CCE4F5EF65140190F3CDD'
 'Test-AuthWireDeploymentCandidate.ps1'='24D3868C7D9D1B9747535092B2F3234FE8A18BF9D6EB5DEB1A36780E894C8829'
 'DeploymentScope.ps1'='EA53CA58E5B1911C306808DCB42B973CA402E4F1A7C9ADA677B0ACEB0E727D7F'
 'Invoke-AuthWireScopeJob.ps1'='BEF0E5AEB8996F9CD93887F328BE96EAF27E1AED8197E957E02F4289E7DB7476'
 'Read-AuthWireDeploymentScope.ps1'='AAB6A44FE9A727C1A13528B1291DEC6BF3B5232B95312882415E6E5925BDF370'
 'CombinedCandidateContent.ps1'='1E8436F3204AA4AD1A0B0BE83D0C1BCC5B1A6DB5B90B7B9B2887DBDCF2478029'
 'Invoke-AuthWireCombinedJob.ps1'='3A5488AD6C8766FB1C5A69294AEB8997204C70B6DAF1FC4F43D2F07434664BB3'
 'CombinedDeploymentScope.ps1'='03F0E13BBE87EA7C5474C0C55C018E3980611E1E192161316F5D55DCE8346BD5'
 'Invoke-AuthWireCombinedScopeJob.ps1'='918DC2A74A2FA78E07B4D24660304A4628714B2A46F98AC90DA973C0D8F6A3B5'
 'Read-AuthWireCombinedDeploymentScope.ps1'='4D9301DC6CC0924E1381CE30C97F6F27C9E1E76034A7192424278E0F3926790B'
 'SysvolInventory.ps1'='26B578A4ECF3177AFA21092CD790995ABF1B4A6E6EE73AAF5565653A4A824CF9'
 'CombinedStagingPreview.ps1'='B141175A0B16B1B2B5687DA4A515D24EEA2B8DAAB5D11106F9382B5D514281B9'
 'Invoke-AuthWireStagingPreviewJob.ps1'='949D805820F9C19AA2B42FF15C0CF1AF0D3D472A0D1E9984FF86E4C061C623A7'
 'Read-AuthWireCombinedStagingPreview.ps1'='2BE2E3CB48C3D10B2AB033F9952D846655271EA1E62487188186B938E449D534'
 'ConnectorServicePackage.ps1'='3D02316FBCED376CD0A5A4637917F8EF8DA3018AB97102527CAB38E22ABE3DA7'
 'ConnectorServiceControl.ps1'='A6BA90BB2AABD1BB0AD12F649A0E7EABBEDC54776194042A538D5FE8FEC3F97D'
 'Install-AuthWireConnectorService.ps1'='FD91F9AF6E7838CE1F795E8E3F64F0E10AFE7380FBEB9524D211CADFEBD7227F'
 'Initialize-AuthWireConnectorChannelKey.ps1'='836FC43FEACB286239E556A1E2339E8AB141F1FE8363BF243764C087DDB0EECE'
 'ConnectorServiceUpgrade.ps1'='366EDD58D2435B01DC13D8831B3768137D3CD4438F9C9B2284EDE59F19B4E976'
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
