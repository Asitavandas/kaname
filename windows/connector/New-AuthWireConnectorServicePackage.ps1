#Requires -Version 5.1
[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$ConfigPath,
 [Parameter(Mandatory=$true)][ValidatePattern('^[0-9A-F]{40}$')][string]$PublisherThumbprint)
$ErrorActionPreference='Stop';Set-StrictMode -Version 2
# Canonical body hashes are generated from this reviewed release, not caller input.
$reviewed=@{
 'ConnectorServiceRuntime.ps1'='7F621C13DA00434CFCE0C0A8203EAED4B871E023C284DC2DF22113D992796457'
 'Compare-AuthWireSigningKeyAcl.ps1'='EA8D67AC4F7673654C24BEE7B59AAF6D50F0427BDAC6D05C535CD5D2D47E8734'
 'ConnectorChannelTypes.ps1'='8CA28590A49A7A48DBA1CC7413AFA0CDF7844435EF532A0E028209FB4F7E4AAB'
 'ConnectorChannelKey.ps1'='D6F0D2CEBDE20B9016AC8BC1C1CDE566245A722AE447164FE55C946CFAD43BD6'
 'New-AuthWireConnectorHealthProof.ps1'='E8E369DCD0B60375EA2ADB672F904DDA217D22DB3BAB5A9B4981607E24958940'
 'Invoke-AuthWireConnectorHealth.ps1'='1A58B86580FF123D2CD253B774F015A9BBA747E5B072346786D6C133BED2122D'
 'ConnectorServiceHost.cs'='B8023A8055E237143E80F12063DF9AC322918696E6A72B11F497EA22ECFB8E3F'
 'Invoke-AuthWireConnectorProbeJob.ps1'='D032EB81410B2914EB72D9D70AD7A742773AFCBFE8D536B820D81D1C8B9D85B6'
 'Invoke-AuthWireCandidateJob.ps1'='8252BC3048D823DF34183B49C87BEC7667908A06176CCE4F5EF65140190F3CDD'
 'Test-AuthWireDeploymentCandidate.ps1'='24D3868C7D9D1B9747535092B2F3234FE8A18BF9D6EB5DEB1A36780E894C8829'
 'DeploymentScope.ps1'='EA53CA58E5B1911C306808DCB42B973CA402E4F1A7C9ADA677B0ACEB0E727D7F'
 'Invoke-AuthWireScopeJob.ps1'='BEF0E5AEB8996F9CD93887F328BE96EAF27E1AED8197E957E02F4289E7DB7476'
 'Read-AuthWireDeploymentScope.ps1'='AAB6A44FE9A727C1A13528B1291DEC6BF3B5232B95312882415E6E5925BDF370'
 'CombinedCandidateContent.ps1'='34FE2AC6B5F0ADCF27FD8E7866D88315CA5CCDB9A699B8B77DB68125E0665800'
 'Invoke-AuthWireCombinedJob.ps1'='05124E51ABAFF9E6DC97A80D4732911E066E0579021795EED762D7A3BA0E0059'
 'CombinedDeploymentScope.ps1'='03F0E13BBE87EA7C5474C0C55C018E3980611E1E192161316F5D55DCE8346BD5'
 'Invoke-AuthWireCombinedScopeJob.ps1'='918DC2A74A2FA78E07B4D24660304A4628714B2A46F98AC90DA973C0D8F6A3B5'
 'Read-AuthWireCombinedDeploymentScope.ps1'='4D9301DC6CC0924E1381CE30C97F6F27C9E1E76034A7192424278E0F3926790B'
 'SysvolInventory.ps1'='26B578A4ECF3177AFA21092CD790995ABF1B4A6E6EE73AAF5565653A4A824CF9'
 'CombinedStagingPreview.ps1'='E64EA0E962CFE5B21EA5E74BDFB9693E047A557A0DFED3A820148BB1CA8EE610'
 'Invoke-AuthWireStagingPreviewJob.ps1'='949D805820F9C19AA2B42FF15C0CF1AF0D3D472A0D1E9984FF86E4C061C623A7'
 'Read-AuthWireCombinedStagingPreview.ps1'='2BE2E3CB48C3D10B2AB033F9952D846655271EA1E62487188186B938E449D534'
 'ConnectorWriteServiceRuntime.ps1'='DD44B8392D868176676F5B4E7660008D9B2C90BBFF89D746C43124E35EE685DC'
 'StagingFilesystem.ps1'='EEA7B1523D53A85C019D6C61469B166CAEE6CBD101D304ED753B0CB24F27AA08'
 'StagingWritePreclaim.ps1'='749EE2F337254421EC6138F6378E951717BBB41F5B97B38DC214B503BBD8592C'
 'StagingWriteTransport.ps1'='9D1197ACD057B84F73053313920C15A917F205CF69EEB515CFB544DE4FC2D33A'
 'StagingWriteConsumption.ps1'='BC55821F4D2969B397DF4ED7A41BC1150ECC9C5F0089715D55A2D53DA3FC2D8F'
 'StagingWriteProcess.ps1'='D5812DD81979E04F1BB4041CF0279021649346F0B53BC8E18015DDF3320B800A'
 'StagingWriteExecution.ps1'='E87B647E651F6AD6854F9E0203E8B0DEAE64BF41E4407A8E248B2ACF665A0B51'
 'StagingWriteResult.ps1'='43D0AD067FEB756ABE7D42786CC42B902F36E78BA437B35EE25111EF3BE62260'
 'StagingWriteCycle.ps1'='BB47EEB8C2EC4C1AC51177FBED1FDE210C019EB96B4E1B50ABEAF493939EF082'
 'StagingRollbackEvidence.ps1'='337DE9B297E67E4134091C74B82E0CF04C43704FBD0DD83ED3A60379D7278200'
 'StagingRollbackAuthorization.ps1'='B93F77C52900D9BA81603CBA5126AAFBE7B520007E2EAFB00D84B9E09B39407E'
 'StagingRollbackExecution.ps1'='9D7C9C1123B4A71792B52949A1D962DEDC0497F358197DC94FE934AAA423EF8E'
 'StagingRollbackResult.ps1'='4F36935A632466225E6662DD645152E7FB567C5A98866F91287831B95CC530C3'
 'StagingWritePollRecord.ps1'='3299B7D751752D2A564A6ABA536C6465722B69150263692F560DBB1558441882'
 'StagingWriteHistory.ps1'='71054897356538FADB1B2325239A900730CC80E0DF245C5CC49CF68557763364'
 'StagingWriteRefusal.ps1'='905222CCE47BCCEE1B0164E4F50F851D9BA3C914120889FFB0D34D8A97221CCD'
 'StagingWriteLifecycle.ps1'='77EA8868586BE1CAEF511EC91E688520664B1884EF2DF8B87C72B26F0CA9F37E'
 'StagingWriteScheduler.ps1'='A45C8E00767CABD53854D85AA071465F227074F354C234B0F1A0B5E291D65853'
 'Read-AuthWireStagingWritePreflight.ps1'='5DBCDCA4A92CB819BBE08BC23AB228EF657F9E4C9052A99BBA2FA0C5E0D12349'
 'Read-AuthWireRollbackPreflight.ps1'='F61CD09323E0A0AB7437406B69C6C98CE640BF57D52B639D3FE04934098C9603'
 'Invoke-AuthWireStagingWriteChild.ps1'='0AEA7D1380AC7284915491E8D528E401BBAAF7A8B5218B53BBDE998ED648AF0D'
 'Invoke-AuthWireRollbackChild.ps1'='7EC17843C66957CAC8BE8571675E8B952B9955F5E6509EBD5BB905294E0AE7B1'
 'ConnectorServicePackage.ps1'='0993946234912D3E58681EBC69A12A161E49965108908D64F736312C9CA01A6E'
 'ConnectorServiceControl.ps1'='A6BA90BB2AABD1BB0AD12F649A0E7EABBEDC54776194042A538D5FE8FEC3F97D'
 'Install-AuthWireConnectorService.ps1'='B82C8CEF7B625092517136E6A7A05E8AE82EF97B6FD1D65DC78AD2C36C3B4C3E'
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


