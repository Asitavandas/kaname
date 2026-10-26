# Fixed package preparation/control helpers. No AD writes, key creation or trust changes.
Set-StrictMode -Version 2
function Get-AuthWireServicePayloadNames {
 @('ConnectorServiceRuntime.ps1','Compare-AuthWireSigningKeyAcl.ps1','ConnectorChannelTypes.ps1','ConnectorChannelKey.ps1','New-AuthWireConnectorHealthProof.ps1','Invoke-AuthWireConnectorHealth.ps1')
}
function Assert-AuthWireServiceAdmin {
 $i=[Security.Principal.WindowsIdentity]::GetCurrent()
 try{if(-not [Environment]::Is64BitProcess -or -not ([Security.Principal.WindowsPrincipal]::new($i)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){throw 'CONNECTOR_ADMIN_REQUIRED'}}finally{$i.Dispose()}
}
function Set-AuthWireServiceAcl {
 param([string]$Path,[string]$Sid,[switch]$Directory,[switch]$Writable)
 $flags=if($Directory){'OICI'}else{''};$rights=if($Writable){'0x1301bf'}elseif($Directory){'FRFX'}else{'FR'}
 $acl=Get-Acl -LiteralPath $Path
 $acl.SetSecurityDescriptorSddlForm(('O:BAG:BAD:P(A;'+$flags+';FA;;;SY)(A;'+$flags+';FA;;;BA)(A;'+$flags+';'+$rights+';;;'+$Sid+')'))
 Set-Acl -LiteralPath $Path -AclObject $acl
}
function Assert-AuthWireServiceConfig {
 param($Config)
 $fields=@('Version','ReleaseId','ServiceName','AccountName','PublisherThumbprint','BaseUrl','Binding','KeyName','ExpectedKeySddl','RootPath')
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
 param($Config,[Security.Cryptography.X509Certificates.X509Certificate2]$Publisher,[string]$SourceDirectory=$PSScriptRoot)
 Assert-AuthWireServiceAdmin;Assert-AuthWireServiceConfig $Config
 Assert-AuthWireServiceChannelKey $Config
 if($Publisher.Thumbprint -cne $Config.PublisherThumbprint -or -not $Publisher.HasPrivateKey){throw 'CONNECTOR_PUBLISHER_REJECTED'}
 $root=$Config.RootPath;$sid=$Config.Binding.service_sid
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
 foreach($file in (Get-AuthWireServicePayloadNames)){
  $inputPath=Join-Path $SourceDirectory $file;Assert-AuthWireChannelPath $inputPath
  $path=Join-Path $root $file;Copy-Item -LiteralPath $inputPath -Destination $path
  $sig=Set-AuthenticodeSignature -FilePath $path -Certificate $Publisher -HashAlgorithm SHA256
  if($sig.Status.ToString() -ne 'Valid' -or $sig.SignerCertificate.Thumbprint -cne $Publisher.Thumbprint){throw 'CONNECTOR_SIGNING_FAILED'}
  Set-AuthWireServiceAcl $path $sid;$hashes+=$file
 }
 $hashLines=@($hashes|ForEach-Object{'   {"'+$_+'","'+(Get-FileHash -LiteralPath (Join-Path $root $_) -Algorithm SHA256).Hash.ToLowerInvariant()+'"},'}) -join "`n"
 $sourcePath=Join-Path $SourceDirectory 'ConnectorServiceHost.cs';Assert-AuthWireChannelPath $sourcePath
 $code=[IO.File]::ReadAllText($sourcePath).Replace('@@NAME@@',$Config.ServiceName).Replace('@@SID@@',$sid).Replace('@@ROOT@@',$root).Replace('@@HASHES@@',$hashLines)
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
 Set-AuthWireServiceAcl $exe $sid
 $manifest=@{Format=1;ReleaseId=$Config.ReleaseId;ServiceName=$Config.ServiceName;AccountName=$Config.AccountName;ServiceSid=$sid;PublisherThumbprint=$Publisher.Thumbprint;Files=@{}}
 foreach($f in ($hashes+@('AuthWireConnector.exe'))){$manifest.Files[$f]=(Get-FileHash -LiteralPath (Join-Path $root $f) -Algorithm SHA256).Hash}
 $mp=Join-Path $root 'package.json';[IO.File]::WriteAllText($mp,($manifest|ConvertTo-Json -Depth 6),[Text.UTF8Encoding]::new($false));Set-AuthWireServiceAcl $mp $sid
 [pscustomobject]@{Event='WINDOWS_CONNECTOR_SERVICE_PACKAGE_PREPARED';RootPath=$root;ServiceName=$Config.ServiceName;ReleaseId=$Config.ReleaseId;PackagePrepared=$true;ServiceCreated=$false;ServiceStarted=$false;AdChanged=$false;GpoChanged=$false;SecretsExported=$false}
}
function Get-AuthWireServicePackage {
 param([string]$RootPath,[string]$ExpectedPublisher)
 Assert-AuthWireChannelPath $RootPath
 $mp=Join-Path $RootPath 'package.json'
 if((Get-Item -LiteralPath $mp).Length -gt 16384){throw 'CONNECTOR_MANIFEST_REJECTED'}
 $m=Get-Content -LiteralPath $mp -Raw|ConvertFrom-Json
 $c=Get-Content -LiteralPath (Join-Path $RootPath 'service.json') -Raw|ConvertFrom-Json
 Assert-AuthWireServiceConfig $c
 if($c.RootPath -cne $RootPath -or $c.PublisherThumbprint -cne $ExpectedPublisher -or $m.Format -ne 1 -or $m.ReleaseId -cne $c.ReleaseId -or $m.ServiceName -cne $c.ServiceName -or $m.AccountName -cne $c.AccountName -or $m.ServiceSid -cne $c.Binding.service_sid -or $m.PublisherThumbprint -cne $ExpectedPublisher){throw 'CONNECTOR_MANIFEST_REJECTED'}
 $sid=$c.Binding.service_sid
 foreach($path in @($RootPath,$mp)){
  $acl=Get-Acl -LiteralPath $path
  $directory=(Get-Item -LiteralPath $path).PSIsContainer
  $flags=if($directory){'OICI'}else{''};$read=if($directory){'FRFX'}else{'FR'}
  $expected='O:BAG:BAD:P(A;'+$flags+';FA;;;SY)(A;'+$flags+';FA;;;BA)(A;'+$flags+';'+$read+';;;'+$sid+')'
  if(-not (Compare-AuthWireSigningKeyAcl $expected $acl.Sddl).AclEquivalent){throw 'CONNECTOR_PACKAGE_ACL_REJECTED'}
 }
 $names=@('service.json','AuthWireConnector.exe')+@(Get-AuthWireServicePayloadNames)
 if(@($m.Files.PSObject.Properties).Count -ne $names.Count){throw 'CONNECTOR_MANIFEST_REJECTED'}
 foreach($file in $names){
  $path=Join-Path $RootPath $file;Assert-AuthWireChannelPath $path
  $expected='O:BAG:BAD:P(A;;FA;;;SY)(A;;FA;;;BA)(A;;FR;;;'+$sid+')'
  if(-not (Compare-AuthWireSigningKeyAcl $expected (Get-Acl -LiteralPath $path).Sddl).AclEquivalent -or (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -cne $m.Files.$file){throw 'CONNECTOR_PACKAGE_REJECTED'}
  if($file -ne 'service.json'){
   $s=Get-AuthenticodeSignature -FilePath $path
   if($s.Status.ToString() -ne 'Valid' -or $s.SignerCertificate.Thumbprint -cne $ExpectedPublisher){throw 'CONNECTOR_SIGNATURE_REJECTED'}
  }
 }
 return $c
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
