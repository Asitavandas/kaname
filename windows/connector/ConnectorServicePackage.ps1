# Fixed package preparation/control helpers. No AD writes, key creation or trust changes.
Set-StrictMode -Version 2
function Get-AuthWireReviewedPayloadHashes {
 @{
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
 'CombinedStagingPreview.ps1'='B141175A0B16B1B2B5687DA4A515D24EEA2B8DAAB5D11106F9382B5D514281B9'
 'Invoke-AuthWireStagingPreviewJob.ps1'='949D805820F9C19AA2B42FF15C0CF1AF0D3D472A0D1E9984FF86E4C061C623A7'
 'Read-AuthWireCombinedStagingPreview.ps1'='2BE2E3CB48C3D10B2AB033F9952D846655271EA1E62487188186B938E449D534'
 'ConnectorWriteServiceRuntime.ps1'='2F4A3AD0F4E5B75B64A6CCE8B0DE32CF0A8D25CA468471D046D7B68844089BEA'
 'StagingFilesystem.ps1'='D45CFC86D4508737D951AE68C2D54C5446B678BEBD3A88FD946FF7180A6A54AC'
 'StagingWritePreclaim.ps1'='CFF553BB69C170CB9B39A8A476B2193743ED86B537C28BEEE38BE242B7537C4D'
 'StagingWriteTransport.ps1'='1FB72C2D75677A5A3FB6085FC4B5EB6B5BBF711AD193C143643D6629A52D1693'
 'StagingWriteConsumption.ps1'='F66733483B40424E82823B71D558B527FFD5350302359C560159F7B7AD139182'
 'StagingWriteProcess.ps1'='D5812DD81979E04F1BB4041CF0279021649346F0B53BC8E18015DDF3320B800A'
 'StagingWriteExecution.ps1'='D1B90C9682E2AA66B7AABD4882CA5734FC5AF7949B425E3F8F8E77F3A269AA66'
 'StagingWriteResult.ps1'='43D0AD067FEB756ABE7D42786CC42B902F36E78BA437B35EE25111EF3BE62260'
 'StagingWriteCycle.ps1'='BB47EEB8C2EC4C1AC51177FBED1FDE210C019EB96B4E1B50ABEAF493939EF082'
 'StagingRollbackEvidence.ps1'='0ED09088B77D04EE95035FBEEB3456E85D229D5052A4CC0B8678BAE874DBD7F9'
 'StagingRollbackAuthorization.ps1'='3695001CD68BB00B49F8F6950A76E901C2B1ABBC4EAA5162D6C4EF4A1EBFD439'
 'StagingRollbackExecution.ps1'='53C06F6F85A3EB217344A15433F5710A34341D084CC933F96FE789C65F043BDA'
 'StagingRollbackResult.ps1'='4F36935A632466225E6662DD645152E7FB567C5A98866F91287831B95CC530C3'
 'StagingWritePollRecord.ps1'='3299B7D751752D2A564A6ABA536C6465722B69150263692F560DBB1558441882'
 'StagingWriteHistory.ps1'='BEA7ABF30A401619CAA9049783323CEBF7045153BF625B820C63C31274DC639F'
 'StagingWriteRefusal.ps1'='072381971B10396015D2F94EEADDEFE75E256F7881063BBCEA2CCA2BEC0311D7'
 'StagingWriteLifecycle.ps1'='685F94E38ABA7A8DDE4E4221DEE62765809FD8F4AFE7BA7EDA4E0608587DA4D8'
 'StagingWriteScheduler.ps1'='A45C8E00767CABD53854D85AA071465F227074F354C234B0F1A0B5E291D65853'
 'Read-AuthWireStagingWritePreflight.ps1'='5DBCDCA4A92CB819BBE08BC23AB228EF657F9E4C9052A99BBA2FA0C5E0D12349'
 'Read-AuthWireRollbackPreflight.ps1'='F61CD09323E0A0AB7437406B69C6C98CE640BF57D52B639D3FE04934098C9603'
 'Invoke-AuthWireStagingWriteChild.ps1'='FCD6000D4D2BD8B3DC35637D9EAD532A66D65ADF461315D71864DEABCDC53477'
 'Invoke-AuthWireRollbackChild.ps1'='7EC17843C66957CAC8BE8571675E8B952B9955F5E6509EBD5BB905294E0AE7B1'
 }
}
function Get-AuthWireSourceBody {
 param([string]$Text)
 $body=($Text -split '(?m)^# SIG # Begin signature block\r?$',2)[0]
 return ($body.Replace("`r`n","`n").TrimEnd([char[]]"`r`n")+"`n")
}
function Get-AuthWireSourceDigest {
 param([string]$Text)
 $sha=[Security.Cryptography.SHA256]::Create()
 try{return ([BitConverter]::ToString($sha.ComputeHash([Text.UTF8Encoding]::new($false).GetBytes((Get-AuthWireSourceBody $Text))))).Replace('-','')}
 finally{$sha.Dispose()}
}
function Get-AuthWireServicePayloadNames {
 param($Config)
 @('ConnectorServiceRuntime.ps1','Compare-AuthWireSigningKeyAcl.ps1','ConnectorChannelTypes.ps1','ConnectorChannelKey.ps1','New-AuthWireConnectorHealthProof.ps1','Invoke-AuthWireConnectorHealth.ps1','Invoke-AuthWireConnectorProbeJob.ps1','Invoke-AuthWireCandidateJob.ps1','Test-AuthWireDeploymentCandidate.ps1','DeploymentScope.ps1','Invoke-AuthWireScopeJob.ps1','Read-AuthWireDeploymentScope.ps1','CombinedCandidateContent.ps1','Invoke-AuthWireCombinedJob.ps1','CombinedDeploymentScope.ps1','Invoke-AuthWireCombinedScopeJob.ps1','Read-AuthWireCombinedDeploymentScope.ps1','SysvolInventory.ps1','CombinedStagingPreview.ps1','Invoke-AuthWireStagingPreviewJob.ps1','Read-AuthWireCombinedStagingPreview.ps1')
 if($Config.PSObject.Properties['WriteSchedulerEnabled'] -and $Config.WriteSchedulerEnabled){Get-AuthWireServiceWritePayloadNames}
}
function Get-AuthWireServiceWritePayloadNames {
 @('ConnectorWriteServiceRuntime.ps1','StagingFilesystem.ps1','StagingWritePreclaim.ps1','StagingWriteTransport.ps1',
   'StagingWriteConsumption.ps1','StagingWriteProcess.ps1','StagingWriteExecution.ps1','StagingWriteResult.ps1',
   'StagingWriteCycle.ps1','StagingRollbackEvidence.ps1','StagingRollbackAuthorization.ps1','StagingRollbackExecution.ps1',
   'StagingRollbackResult.ps1','StagingWritePollRecord.ps1','StagingWriteHistory.ps1','StagingWriteRefusal.ps1',
   'StagingWriteLifecycle.ps1','StagingWriteScheduler.ps1','Read-AuthWireStagingWritePreflight.ps1',
   'Read-AuthWireRollbackPreflight.ps1','Invoke-AuthWireStagingWriteChild.ps1','Invoke-AuthWireRollbackChild.ps1')
}
function Assert-AuthWireServiceAdmin {
 $i=[Security.Principal.WindowsIdentity]::GetCurrent()
 try{if(-not [Environment]::Is64BitProcess -or -not ([Security.Principal.WindowsPrincipal]::new($i)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){throw 'CONNECTOR_ADMIN_REQUIRED'}}finally{$i.Dispose()}
}
function Set-AuthWireServiceAcl {
 param([string]$Path,[string]$Sid,[switch]$Directory,[switch]$Writable,[switch]$Executable)
 $flags=if($Directory){'OICI'}else{''};$rights=if($Writable){'0x1301bf'}elseif($Directory -or $Executable){'FRFX'}else{'FR'}
 $acl=Get-Acl -LiteralPath $Path
 $acl.SetSecurityDescriptorSddlForm(('O:BAG:BAD:P(A;'+$flags+';FA;;;SY)(A;'+$flags+';FA;;;BA)(A;'+$flags+';'+$rights+';;;'+$Sid+')'))
 Set-Acl -LiteralPath $Path -AclObject $acl
}
function Get-AuthWireConnectorWriteJournalReadiness {
 param($Config)
 $binding=$Config.Binding
 $sid=$binding.service_sid
 $path=Join-Path ([Environment]::GetFolderPath('CommonApplicationData')) ('AuthWire-WriteJournal-'+([guid]$binding.connector_id).ToString('N'))
 $result=[ordered]@{Event='WINDOWS_CONNECTOR_WRITE_JOURNAL_READINESS';ServiceName=$Config.ServiceName;ReleaseId=$Config.ReleaseId;JournalPath=$path;Ready=$false;Reason='journal_missing'}
 if($path -cnotmatch '\A[A-Za-z]:\\' -or $path -match ':.*:'){
  $result.Reason='journal_path_rejected';return [pscustomobject]$result
 }
 Assert-AuthWireChannelPath $path
 try{$item=Get-Item -LiteralPath $path -Force -ErrorAction Stop}
 catch [Management.Automation.ItemNotFoundException]{return [pscustomobject]$result}
 if(-not $item.PSIsContainer){$result.Reason='journal_not_directory';return [pscustomobject]$result}

 $acl=Get-Acl -LiteralPath $path -ErrorAction Stop
 $sidType=[Security.Principal.SecurityIdentifier]
 $allowed=@($sid,'S-1-5-18','S-1-5-32-544')
 $rules=@($acl.GetAccessRules($true,$true,$sidType))
 if(-not $acl.AreAccessRulesProtected -or $acl.GetOwner($sidType).Value -cnotin $allowed -or
    @($rules|Where-Object{$_.AccessControlType -ne 'Allow' -or $_.IdentityReference.Value -cnotin $allowed}).Count){
  $result.Reason='journal_acl_rejected';return [pscustomobject]$result
 }
 $rights=0
 foreach($rule in $rules){
  if($rule.IdentityReference.Value -ceq $sid -and -not ($rule.PropagationFlags -band [Security.AccessControl.PropagationFlags]::InheritOnly)){
   $rights=$rights -bor [int]$rule.FileSystemRights
  }
 }
 $required=[int][Security.AccessControl.FileSystemRights]::Modify
 if(($rights -band $required) -ne $required){$result.Reason='journal_service_access_missing';return [pscustomobject]$result}
 $result.Ready=$true;$result.Reason='journal_acl_verified'
 return [pscustomobject]$result
}
function Assert-AuthWireServiceConfig {
 param($Config)
 $fields=@('Version','ReleaseId','ServiceName','AccountName','PublisherThumbprint','BaseUrl','Binding','KeyName','ExpectedKeySddl','RootPath')
 if($Config.PSObject.Properties['WriteSchedulerEnabled']){
  if($Config.PSObject.Properties['WriteSchedulerEnabled'].Name -cne 'WriteSchedulerEnabled' -or $Config.WriteSchedulerEnabled -isnot [bool]){throw 'CONNECTOR_CONFIG_REJECTED'}
  $fields+= 'WriteSchedulerEnabled'
 }
 if(@($Config.PSObject.Properties).Count -ne $fields.Count -or @($Config.PSObject.Properties.Name|Where-Object{$_ -notin $fields}).Count -or $Config.Version -isnot [int] -or $Config.Version -ne 1){throw 'CONNECTOR_CONFIG_REJECTED'}
 $id=[guid]::Empty
 if(-not [guid]::TryParseExact($Config.ReleaseId,'D',[ref]$id) -or $id -eq [guid]::Empty){throw 'CONNECTOR_CONFIG_REJECTED'}
 $binding=$Config.Binding
 $names=@('instance_id','connector_id','generation','host_guid','host_fqdn','service_sid','appliance_fqdn','appliance_tls_sha256','channel_key_sha256')
 if(@($binding.PSObject.Properties).Count -ne 9 -or @($binding.PSObject.Properties.Name|Where-Object{$_ -notin $names}).Count){throw 'CONNECTOR_CONFIG_REJECTED'}
 foreach($n in @('instance_id','connector_id','host_guid')){
  if($binding.$n -isnot [string] -or -not [guid]::TryParseExact($binding.$n,'D',[ref]$id) -or $id -eq [guid]::Empty -or $id.ToString('D') -cne $binding.$n){throw 'CONNECTOR_CONFIG_REJECTED'}
 }
 foreach($n in @('host_fqdn','appliance_fqdn')){
  $v=$binding.$n
  if($v -isnot [string] -or $v -cne $v.ToLowerInvariant() -or $v.Length -gt 253 -or $v.Split('.').Count -lt 2){throw 'CONNECTOR_CONFIG_REJECTED'}
  foreach($label in $v.Split('.')){if($label -cnotmatch '\A[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\z'){throw 'CONNECTOR_CONFIG_REJECTED'}}
 }
 if($binding.host_fqdn.Split('.')[0] -cne [Environment]::MachineName.ToLowerInvariant() -or $binding.service_sid -cnotmatch '\AS-1-5-21-(?:[1-9][0-9]{0,9}-){3}[1-9][0-9]{0,9}\z' -or $binding.generation -isnot [int] -or $binding.generation -lt 1){throw 'CONNECTOR_CONFIG_REJECTED'}
 foreach($n in @('appliance_tls_sha256','channel_key_sha256')){if($binding.$n -cnotmatch '\A[0-9a-f]{64}\z'){throw 'CONNECTOR_CONFIG_REJECTED'}}
 $name='AuthWireConnector-'+([guid]$binding.connector_id).ToString('N')
 $root=Join-Path $env:ProgramW6432 ('AuthWire-Connector-'+([guid]$binding.connector_id).ToString('N'))
 $uri=$null
 if($Config.ServiceName -cne $name -or $Config.RootPath -cne $root -or $root.Contains('"') -or
  $Config.PublisherThumbprint -cnotmatch '\A[0-9A-F]{40}\z' -or
  $Config.AccountName -cnotmatch '\A[A-Za-z0-9][A-Za-z0-9.-]{0,252}\\[A-Za-z0-9][A-Za-z0-9-]{0,19}\$?\z' -or
  $Config.KeyName -cnotmatch ('\AAuthWire-Channel-'+([guid]$binding.connector_id).ToString('N')+'-[0-9a-f]{32}\z') -or
  -not [uri]::TryCreate($Config.BaseUrl,[UriKind]::Absolute,[ref]$uri) -or $uri.Scheme -cne 'https' -or $uri.Host -cne $binding.appliance_fqdn -or $uri.AbsolutePath -cne '/' -or $uri.Query -ne '' -or $uri.Fragment -ne '' -or $uri.UserInfo -ne ''){throw 'CONNECTOR_CONFIG_REJECTED'}
 $descriptor=[Security.AccessControl.RawSecurityDescriptor]::new($Config.ExpectedKeySddl)
 if(-not $descriptor.DiscretionaryAcl){throw 'CONNECTOR_CONFIG_REJECTED'}
}
function New-AuthWireServicePackageCore {
 param($Config,[Security.Cryptography.X509Certificates.X509Certificate2]$Publisher,[string]$SourceDirectory=$PSScriptRoot,[string]$BuildPath)
 Assert-AuthWireServiceAdmin;Assert-AuthWireServiceConfig $Config
 Assert-AuthWireServiceChannelKey $Config
 if($Publisher.Thumbprint -cne $Config.PublisherThumbprint -or -not $Publisher.HasPrivateKey){throw 'CONNECTOR_PUBLISHER_REJECTED'}
 $root=$Config.RootPath;$sid=$Config.Binding.service_sid
 if($BuildPath){
  $expected=$Config.RootPath+'.candidate-'+([guid]$Config.ReleaseId).ToString('N')
  if($BuildPath -cne $expected){throw 'CONNECTOR_STAGING_PATH_REJECTED'}
  $root=$BuildPath
 }
 Assert-AuthWireChannelPath $root
 if(Test-Path -LiteralPath $root){throw 'CONNECTOR_PACKAGE_EXISTS_REQUIRES_REVIEW'}
 $null=New-Item -ItemType Directory -Path $root
 Set-AuthWireServiceAcl $root $sid -Directory
 $state=Join-Path $root 'state';$null=New-Item -ItemType Directory -Path $state
 Set-AuthWireServiceAcl $state $sid -Directory -Writable
 $json=Join-Path $root 'service.json'
 [IO.File]::WriteAllText($json,($Config|ConvertTo-Json -Depth 6),[Text.UTF8Encoding]::new($false))
 Set-AuthWireServiceAcl $json $sid
 $hashes=@('service.json')
 $reviewed=Get-AuthWireReviewedPayloadHashes
 foreach($file in (Get-AuthWireServicePayloadNames $Config)){
  $inputPath=Join-Path $SourceDirectory $file;Assert-AuthWireChannelPath $inputPath
  $path=Join-Path $root $file;Copy-Item -LiteralPath $inputPath -Destination $path
  if((Get-AuthWireSourceDigest ([IO.File]::ReadAllText($path))) -cne $reviewed[$file]){throw 'CONNECTOR_UNREVIEWED_SOURCE_REJECTED'}
  $sig=Set-AuthenticodeSignature -FilePath $path -Certificate $Publisher -HashAlgorithm SHA256
  if($sig.Status.ToString() -ne 'Valid' -or $sig.SignerCertificate.Thumbprint -cne $Publisher.Thumbprint){throw 'CONNECTOR_SIGNING_FAILED'}
  Set-AuthWireServiceAcl $path $sid;$hashes+=$file
 }
 $hashLines=@($hashes|ForEach-Object{'   {"'+$_+'","'+(Get-FileHash -LiteralPath (Join-Path $root $_) -Algorithm SHA256).Hash.ToLowerInvariant()+'"},'}) -join "`n"
 $sourcePath=Join-Path $SourceDirectory 'ConnectorServiceHost.cs';Assert-AuthWireChannelPath $sourcePath
 $raw=[IO.File]::ReadAllText($sourcePath)
 if((Get-AuthWireSourceDigest $raw) -cne $reviewed['ConnectorServiceHost.cs']){throw 'CONNECTOR_UNREVIEWED_SOURCE_REJECTED'}
 $writeScheduler=if($Config.PSObject.Properties['WriteSchedulerEnabled'] -and $Config.WriteSchedulerEnabled){'enabled'}else{'disabled'}
 $code=$raw.Replace('@@NAME@@',$Config.ServiceName).Replace('@@SID@@',$sid).Replace('@@ROOT@@',$Config.RootPath).Replace('@@HASHES@@',$hashLines).Replace('@@WRITE_SCHEDULER@@',$writeScheduler)
 $exe=Join-Path $root 'AuthWireConnector.exe'
 Add-Type -AssemblyName Microsoft.CSharp
 $compiler=[Microsoft.CSharp.CSharpCodeProvider]::new()
 try{
  $parameters=[CodeDom.Compiler.CompilerParameters]::new()
  $parameters.GenerateExecutable=$true;$parameters.GenerateInMemory=$false;$parameters.OutputAssembly=$exe
  $parameters.CompilerOptions='/target:winexe /platform:x64 /optimize+'
  foreach($assembly in @('System.dll','System.Core.dll','System.ServiceProcess.dll')){$null=$parameters.ReferencedAssemblies.Add($assembly)}
  $compiled=$compiler.CompileAssemblyFromSource($parameters,$code)
  if($compiled.Errors.HasErrors){throw ('CONNECTOR_HOST_COMPILATION_FAILED: '+(($compiled.Errors|Where-Object{-not $_.IsWarning}|ForEach-Object{$_.ErrorText}) -join '; '))}
 }finally{$compiler.Dispose()}
 $sig=Set-AuthenticodeSignature -FilePath $exe -Certificate $Publisher -HashAlgorithm SHA256
 if($sig.Status.ToString() -ne 'Valid' -or $sig.SignerCertificate.Thumbprint -cne $Publisher.Thumbprint){throw 'CONNECTOR_SIGNING_FAILED'}
 Set-AuthWireServiceAcl $exe $sid -Executable
 $manifest=@{Format=1;ReleaseId=$Config.ReleaseId;ServiceName=$Config.ServiceName;AccountName=$Config.AccountName;ServiceSid=$sid;PublisherThumbprint=$Publisher.Thumbprint;Files=@{}}
 foreach($f in ($hashes+@('AuthWireConnector.exe'))){$manifest.Files[$f]=(Get-FileHash -LiteralPath (Join-Path $root $f) -Algorithm SHA256).Hash}
 $mp=Join-Path $root 'package.json';[IO.File]::WriteAllText($mp,($manifest|ConvertTo-Json -Depth 6),[Text.UTF8Encoding]::new($false));Set-AuthWireServiceAcl $mp $sid
 [pscustomobject]@{Event='WINDOWS_CONNECTOR_SERVICE_PACKAGE_PREPARED';RootPath=$root;ServiceName=$Config.ServiceName;ReleaseId=$Config.ReleaseId;PackagePrepared=$true;ServiceCreated=$false;ServiceStarted=$false;AdChanged=$false;GpoChanged=$false;SecretsExported=$false}
}
function Get-AuthWireServicePackage {
 param([string]$RootPath,[string]$ExpectedPublisher,[switch]$Staged,[switch]$AllowLegacy)
 Assert-AuthWireChannelPath $RootPath
 $mp=Join-Path $RootPath 'package.json'
 if((Get-Item -LiteralPath $mp).Length -gt 16384){throw 'CONNECTOR_MANIFEST_REJECTED'}
 $m=Get-Content -LiteralPath $mp -Raw|ConvertFrom-Json
 $c=Get-Content -LiteralPath (Join-Path $RootPath 'service.json') -Raw|ConvertFrom-Json
 Assert-AuthWireServiceConfig $c
 $pathMatches=($c.RootPath -ceq $RootPath)
 if($Staged){$pathMatches=($RootPath -ceq ($c.RootPath+'.candidate-'+([guid]$c.ReleaseId).ToString('N')) -or $RootPath -ceq ($c.RootPath+'.previous-'+([guid]$c.ReleaseId).ToString('N')))}
 if(-not $pathMatches -or $c.PublisherThumbprint -cne $ExpectedPublisher -or $m.Format -ne 1 -or $m.ReleaseId -cne $c.ReleaseId -or $m.ServiceName -cne $c.ServiceName -or $m.AccountName -cne $c.AccountName -or $m.ServiceSid -cne $c.Binding.service_sid -or $m.PublisherThumbprint -cne $ExpectedPublisher){throw 'CONNECTOR_MANIFEST_REJECTED'}
 $sid=$c.Binding.service_sid
 foreach($path in @($RootPath,$mp)){
  $acl=Get-Acl -LiteralPath $path
  $directory=(Get-Item -LiteralPath $path).PSIsContainer
  $flags=if($directory){'OICI'}else{''};$read=if($directory){'FRFX'}else{'FR'}
  $expected='O:BAG:BAD:P(A;'+$flags+';FA;;;SY)(A;'+$flags+';FA;;;BA)(A;'+$flags+';'+$read+';;;'+$sid+')'
  if(-not (Compare-AuthWireSigningKeyAcl $expected $acl.Sddl).AclEquivalent){throw 'CONNECTOR_PACKAGE_ACL_REJECTED'}
 }
 $stagingLegacy=$AllowLegacy -and -not $m.Files.PSObject.Properties['Invoke-AuthWireStagingPreviewJob.ps1']
 $combinedScopeLegacy=$AllowLegacy -and -not $m.Files.PSObject.Properties['Invoke-AuthWireCombinedScopeJob.ps1']
 $combinedLegacy=$combinedScopeLegacy -and -not $m.Files.PSObject.Properties['Invoke-AuthWireCombinedJob.ps1']
 $scopeLegacy=$combinedLegacy -and -not $m.Files.PSObject.Properties['Invoke-AuthWireScopeJob.ps1']
 $probeLegacy=$scopeLegacy -and -not $m.Files.PSObject.Properties['Invoke-AuthWireCandidateJob.ps1']
 $legacy=$probeLegacy -and -not $m.Files.PSObject.Properties['Invoke-AuthWireConnectorProbeJob.ps1']
 $payload=@(Get-AuthWireServicePayloadNames $c)
 if($stagingLegacy){$payload=@($payload|Where-Object{$_ -cnotin @('SysvolInventory.ps1','CombinedStagingPreview.ps1','Invoke-AuthWireStagingPreviewJob.ps1','Read-AuthWireCombinedStagingPreview.ps1')})}
 if($combinedScopeLegacy){$payload=@($payload|Where-Object{$_ -cnotin @('CombinedDeploymentScope.ps1','Invoke-AuthWireCombinedScopeJob.ps1','Read-AuthWireCombinedDeploymentScope.ps1','SysvolInventory.ps1','CombinedStagingPreview.ps1','Invoke-AuthWireStagingPreviewJob.ps1','Read-AuthWireCombinedStagingPreview.ps1')})}
 if($combinedLegacy){$payload=@($payload|Where-Object{$_ -cnotin @('CombinedCandidateContent.ps1','Invoke-AuthWireCombinedJob.ps1')})}
 if($scopeLegacy){$payload=@($payload|Where-Object{$_ -cnotin @('DeploymentScope.ps1','Invoke-AuthWireScopeJob.ps1','Read-AuthWireDeploymentScope.ps1')})}
 if($probeLegacy){$payload=@($payload|Where-Object{$_ -cnotin @('Invoke-AuthWireCandidateJob.ps1','Test-AuthWireDeploymentCandidate.ps1')})}
 if($legacy){$payload=@($payload|Where-Object{$_ -cne 'Invoke-AuthWireConnectorProbeJob.ps1'})}
 $names=@('service.json','AuthWireConnector.exe')+$payload
 if(@($m.Files.PSObject.Properties).Count -ne $names.Count){throw 'CONNECTOR_MANIFEST_REJECTED'}
 foreach($file in $names){
  $path=Join-Path $RootPath $file;Assert-AuthWireChannelPath $path
  $read=if($file -eq 'AuthWireConnector.exe'){'FRFX'}else{'FR'}
  $expected='O:BAG:BAD:P(A;;FA;;;SY)(A;;FA;;;BA)(A;;'+$read+';;;'+$sid+')'
  if(-not (Compare-AuthWireSigningKeyAcl $expected (Get-Acl -LiteralPath $path).Sddl).AclEquivalent -or (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -cne $m.Files.$file){throw 'CONNECTOR_PACKAGE_REJECTED'}
  if($file -ne 'service.json'){
   $s=Get-AuthenticodeSignature -FilePath $path
   if($s.Status.ToString() -ne 'Valid' -or $s.SignerCertificate.Thumbprint -cne $ExpectedPublisher){throw 'CONNECTOR_SIGNATURE_REJECTED'}
  }
 }
 if($stagingLegacy -and -not $combinedScopeLegacy){
  $oldHashes=Get-AuthWireCombinedScopeOnlyPayloadHashes
  foreach($file in $payload){if((Get-AuthWireSourceDigest ([IO.File]::ReadAllText((Join-Path $RootPath $file)))) -cne $oldHashes[$file]){throw 'CONNECTOR_LEGACY_SOURCE_REJECTED'}}
 }
 if($combinedScopeLegacy){
  $legacyHashes=if($legacy){Get-AuthWireLegacyPayloadHashes}elseif($probeLegacy){Get-AuthWireProbeOnlyPayloadHashes}elseif($scopeLegacy){Get-AuthWireCandidateOnlyPayloadHashes}elseif($combinedLegacy){Get-AuthWireScopeOnlyPayloadHashes}else{Get-AuthWireCombinedOnlyPayloadHashes}
  foreach($file in $payload){if((Get-AuthWireSourceDigest ([IO.File]::ReadAllText((Join-Path $RootPath $file)))) -cne $legacyHashes[$file]){throw 'CONNECTOR_LEGACY_SOURCE_REJECTED'}}
 }
 return $c
}
function Get-AuthWireLegacyPayloadHashes {
 @{
 'ConnectorServiceRuntime.ps1'='58BECDFB6F2E08659F9E4C5443DC89A6F265E7767A612E0FFEC67C39ABD0DD0B'
 'Compare-AuthWireSigningKeyAcl.ps1'='EA8D67AC4F7673654C24BEE7B59AAF6D50F0427BDAC6D05C535CD5D2D47E8734'
 'ConnectorChannelTypes.ps1'='FA198F9A1C0AD75DB2C577A9D109246C7811249E8124E6541CE8B5AE19FAB61C'
 'ConnectorChannelKey.ps1'='D6F0D2CEBDE20B9016AC8BC1C1CDE566245A722AE447164FE55C946CFAD43BD6'
 'New-AuthWireConnectorHealthProof.ps1'='E8E369DCD0B60375EA2ADB672F904DDA217D22DB3BAB5A9B4981607E24958940'
 'Invoke-AuthWireConnectorHealth.ps1'='1A58B86580FF123D2CD253B774F015A9BBA747E5B072346786D6C133BED2122D'
 }
}
function Assert-AuthWireServiceChannelKey {
 param($Config)
 $key=$null;$rsa=$null
 try{
  $key=[Security.Cryptography.CngKey]::Open($Config.KeyName,[Security.Cryptography.CngProvider]::MicrosoftSoftwareKeyStorageProvider,[Security.Cryptography.CngKeyOpenOptions]::MachineKey)
  $rsa=[Security.Cryptography.RSACng]::new($key)
  if(-not $key.IsMachineKey -or $key.IsEphemeral -or $rsa.KeySize -ne 3072 -or [int]$key.ExportPolicy -ne 0 -or [int]$key.KeyUsage -ne 2 -or (Get-AuthWireChannelPublicKeyId $rsa) -cne $Config.Binding.channel_key_sha256){throw 'CONNECTOR_CHANNEL_KEY_REJECTED'}
  $file=Join-Path (Join-Path $env:ProgramData 'Microsoft\Crypto\Keys') $key.UniqueName
  Assert-AuthWireChannelPath $file;Assert-AuthWireChannelOwner $file
  $expected=Get-AuthWireChannelFileSddl $file $Config.Binding.service_sid
  if(-not (Compare-AuthWireSigningKeyAcl $expected $Config.ExpectedKeySddl).AclEquivalent -or -not (Compare-AuthWireSigningKeyAcl $expected (Get-Acl -LiteralPath $file).Sddl).AclEquivalent){throw 'CONNECTOR_CHANNEL_KEY_ACL_REJECTED'}
 }finally{if($rsa){$rsa.Dispose()};if($key){$key.Dispose()}}
}

function Get-AuthWireProbeOnlyPayloadHashes {
 @{
 'ConnectorServiceRuntime.ps1'='DFC6295927C18750DFBA399C7E59768326206CF97D1F44D43B719D4BCE27DF77'
 'Compare-AuthWireSigningKeyAcl.ps1'='EA8D67AC4F7673654C24BEE7B59AAF6D50F0427BDAC6D05C535CD5D2D47E8734'
 'ConnectorChannelTypes.ps1'='C52C2F8414CE09B2ABE303E6628C9DE3BC3F8121D7EB7FCBCFE39C735E04A1D5'
 'ConnectorChannelKey.ps1'='D6F0D2CEBDE20B9016AC8BC1C1CDE566245A722AE447164FE55C946CFAD43BD6'
 'New-AuthWireConnectorHealthProof.ps1'='E8E369DCD0B60375EA2ADB672F904DDA217D22DB3BAB5A9B4981607E24958940'
 'Invoke-AuthWireConnectorHealth.ps1'='1A58B86580FF123D2CD253B774F015A9BBA747E5B072346786D6C133BED2122D'
 'ConnectorServiceHost.cs'='14E2246637793391937D16E8FB73218E237E9A57F26B7210B560F9A1C9F8082F'
 'Invoke-AuthWireConnectorProbeJob.ps1'='D032EB81410B2914EB72D9D70AD7A742773AFCBFE8D536B820D81D1C8B9D85B6'
 }
}

function Get-AuthWireCandidateOnlyPayloadHashes {
 @{
 'ConnectorServiceRuntime.ps1'='5FBB6F04207336AB19977788E771E5434250BED640402C56B1694D7013FF0DBB'
 'Compare-AuthWireSigningKeyAcl.ps1'='EA8D67AC4F7673654C24BEE7B59AAF6D50F0427BDAC6D05C535CD5D2D47E8734'
 'ConnectorChannelTypes.ps1'='C5C72DD8FDACD703773609C0527DD91816477E8FFC3F87F2F304001B3F87AE79'
 'ConnectorChannelKey.ps1'='D6F0D2CEBDE20B9016AC8BC1C1CDE566245A722AE447164FE55C946CFAD43BD6'
 'New-AuthWireConnectorHealthProof.ps1'='E8E369DCD0B60375EA2ADB672F904DDA217D22DB3BAB5A9B4981607E24958940'
 'Invoke-AuthWireConnectorHealth.ps1'='1A58B86580FF123D2CD253B774F015A9BBA747E5B072346786D6C133BED2122D'
 'ConnectorServiceHost.cs'='14E2246637793391937D16E8FB73218E237E9A57F26B7210B560F9A1C9F8082F'
 'Invoke-AuthWireConnectorProbeJob.ps1'='D032EB81410B2914EB72D9D70AD7A742773AFCBFE8D536B820D81D1C8B9D85B6'
 'Invoke-AuthWireCandidateJob.ps1'='8252BC3048D823DF34183B49C87BEC7667908A06176CCE4F5EF65140190F3CDD'
 'Test-AuthWireDeploymentCandidate.ps1'='24D3868C7D9D1B9747535092B2F3234FE8A18BF9D6EB5DEB1A36780E894C8829'
 }
}

function Get-AuthWireScopeOnlyPayloadHashes {
 @{
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
 }
}

function Get-AuthWireCombinedOnlyPayloadHashes {
 @{
 'ConnectorServiceRuntime.ps1'='A9DDCF9B823893E9CEB3F8BE9B837A10FDA9F6C0FC90729B69BBEF361AB56EB0'
 'Compare-AuthWireSigningKeyAcl.ps1'='EA8D67AC4F7673654C24BEE7B59AAF6D50F0427BDAC6D05C535CD5D2D47E8734'
 'ConnectorChannelTypes.ps1'='6D374E58F4D9DED209825E6D43C2DCB3D12A22A32DA2B4079BD4FAE5DE60CC0E'
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
 'CombinedCandidateContent.ps1'='1E8436F3204AA4AD1A0B0BE83D0C1BCC5B1A6DB5B90B7B9B2887DBDCF2478029'
 'Invoke-AuthWireCombinedJob.ps1'='3A5488AD6C8766FB1C5A69294AEB8997204C70B6DAF1FC4F43D2F07434664BB3'
 }
}

function Get-AuthWireCombinedScopeOnlyPayloadHashes {
 @{
 'ConnectorServiceRuntime.ps1'='4177CC3A24DEEED8104BFE7E40CC772B0EF2367EE902722960519A6589C9C78A'
 'Compare-AuthWireSigningKeyAcl.ps1'='EA8D67AC4F7673654C24BEE7B59AAF6D50F0427BDAC6D05C535CD5D2D47E8734'
 'ConnectorChannelTypes.ps1'='9B97A227189DF1A375574184E7085AB5DCF2E2ABBF7A30E6E73823EF553EF37B'
 'ConnectorChannelKey.ps1'='D6F0D2CEBDE20B9016AC8BC1C1CDE566245A722AE447164FE55C946CFAD43BD6'
 'New-AuthWireConnectorHealthProof.ps1'='E8E369DCD0B60375EA2ADB672F904DDA217D22DB3BAB5A9B4981607E24958940'
 'Invoke-AuthWireConnectorHealth.ps1'='1A58B86580FF123D2CD253B774F015A9BBA747E5B072346786D6C133BED2122D'
 'Invoke-AuthWireConnectorProbeJob.ps1'='D032EB81410B2914EB72D9D70AD7A742773AFCBFE8D536B820D81D1C8B9D85B6'
 'Invoke-AuthWireCandidateJob.ps1'='8252BC3048D823DF34183B49C87BEC7667908A06176CCE4F5EF65140190F3CDD'
 'Test-AuthWireDeploymentCandidate.ps1'='24D3868C7D9D1B9747535092B2F3234FE8A18BF9D6EB5DEB1A36780E894C8829'
 'DeploymentScope.ps1'='EA53CA58E5B1911C306808DCB42B973CA402E4F1A7C9ADA677B0ACEB0E727D7F'
 'Invoke-AuthWireScopeJob.ps1'='A3DA082AF17D6F17948D03A867144F6435175DE615E5C7BD7369EF6F3B34B9C7'
 'Read-AuthWireDeploymentScope.ps1'='AAB6A44FE9A727C1A13528B1291DEC6BF3B5232B95312882415E6E5925BDF370'
 'CombinedCandidateContent.ps1'='1E8436F3204AA4AD1A0B0BE83D0C1BCC5B1A6DB5B90B7B9B2887DBDCF2478029'
 'Invoke-AuthWireCombinedJob.ps1'='3A5488AD6C8766FB1C5A69294AEB8997204C70B6DAF1FC4F43D2F07434664BB3'
 'CombinedDeploymentScope.ps1'='03F0E13BBE87EA7C5474C0C55C018E3980611E1E192161316F5D55DCE8346BD5'
 'Invoke-AuthWireCombinedScopeJob.ps1'='918DC2A74A2FA78E07B4D24660304A4628714B2A46F98AC90DA973C0D8F6A3B5'
 'Read-AuthWireCombinedDeploymentScope.ps1'='4D9301DC6CC0924E1381CE30C97F6F27C9E1E76034A7192424278E0F3926790B'
 }
}
