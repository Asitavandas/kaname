param([ValidateSet('Create','Client','Cleanup')][string]$Mode,[string]$Directory)
$ErrorActionPreference='Stop';Set-StrictMode -Version 2
if($env:RUNNER_ENVIRONMENT -ne 'github-hosted'){throw 'Hosted fixture only'}
$source=Join-Path $PSScriptRoot '..\windows\connector'
foreach($f in @('Compare-AuthWireSigningKeyAcl.ps1','ConnectorChannelTypes.ps1','New-AuthWireConnectorHealthProof.ps1','ConnectorChannelKey.ps1','Invoke-AuthWireConnectorHealth.ps1')){. (Join-Path $source $f)}
Initialize-AuthWireChannelTypes
$script:checks=0
function Check([bool]$v,[string]$m){if(-not $v){throw $m};$script:checks++}
function Reject([scriptblock]$call,[string]$m){$bad=$false;try{$null=& $call}catch{$bad=$true};Check $bad $m}
$root=Join-Path $Directory 'key-root';$prepFile=Join-Path $Directory 'prepared.json'
if($Mode -eq 'Create'){
 $base=Get-Content -LiteralPath (Join-Path $Directory 'base.json') -Raw|ConvertFrom-Json
 $i=[Security.Principal.WindowsIdentity]::GetCurrent();try{$sid=$i.User.Value}finally{$i.Dispose()}
 $b=@{instance_id=$base.instance_id;connector_id=$base.connector_id;host_guid=$base.host_guid;host_fqdn=([Environment]::MachineName.ToLowerInvariant()+'.lab.example');service_sid=$sid;appliance_fqdn=$base.appliance_fqdn;appliance_tls_sha256=$base.appliance_tls_sha256}
 $r=Initialize-AuthWireChannelKeyCore -Mode Inspect -Directory $root -BaseBinding $b
 Check ($r.ReadyForPrepare -and -not (Test-Path -LiteralPath $root)) 'Inspect missing key creates nothing'
 $r=Initialize-AuthWireChannelKeyCore -Mode PrepareKey -Directory $root -BaseBinding $b
 $r|ConvertTo-Json -Depth 6|Set-Content -LiteralPath $prepFile -Encoding UTF8
 Check ($r.KeyCreated -and $r.ReadAclVerified -and $r.KeyPropertiesVerified -and -not $r.ServiceKeyAccessVerified) 'Prepare creates only dedicated machine key and bounded ACL'
 $again=Initialize-AuthWireChannelKeyCore -Mode PrepareKey -Directory $root -BaseBinding $b
 Check (-not $again.KeyCreated -and $again.KeyName -ceq $r.KeyName) 'Repeated verified preparation reuses the same key'
 $receipt=Join-Path $root 'channel-key.json';$bytes=[IO.File]::ReadAllBytes($receipt)
 $key=[Security.Cryptography.CngKey]::Open($r.KeyName,[Security.Cryptography.CngProvider]::MicrosoftSoftwareKeyStorageProvider,[Security.Cryptography.CngKeyOpenOptions]::MachineKey)
 try{
  $path=Join-Path (Join-Path $env:ProgramData 'Microsoft\Crypto\Keys') $key.UniqueName
  $before=(Get-Acl -LiteralPath $path).Sddl
  $acl=Get-Acl -LiteralPath $path;$acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new([Security.Principal.SecurityIdentifier]::new('S-1-1-0'),[Security.AccessControl.FileSystemRights]::Read,[Security.AccessControl.AccessControlType]::Allow));Set-Acl -LiteralPath $path -AclObject $acl
  Reject {Initialize-AuthWireChannelKeyCore -Mode Inspect -Directory $root -BaseBinding $b} 'Unexpected key reader blocks inspection, no repair'
  $acl.SetSecurityDescriptorSddlForm($before);Set-Acl -LiteralPath $path -AclObject $acl
  $changed=$b.Clone();$changed.appliance_tls_sha256='b'*64
  Reject {Initialize-AuthWireChannelKeyCore -Mode PrepareKey -Directory $root -BaseBinding $changed} 'Existing receipt cannot be rebound silently'
  $record=Get-Content -LiteralPath $receipt -Raw|ConvertFrom-Json;$record.Phase='key_created'
  $record|ConvertTo-Json -Depth 6|Set-Content -LiteralPath $receipt -Encoding UTF8
  Reject {Initialize-AuthWireChannelKeyCore -Mode PrepareKey -Directory $root -BaseBinding $b} 'Interrupted preparation refuses a second key'
  [IO.File]::WriteAllBytes($receipt,$bytes)
  $racl=(Get-Acl -LiteralPath $receipt).Sddl
  $acl=Get-Acl -LiteralPath $receipt;$acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new([Security.Principal.SecurityIdentifier]::new($sid),[Security.AccessControl.FileSystemRights]::Write,[Security.AccessControl.AccessControlType]::Allow));Set-Acl -LiteralPath $receipt -AclObject $acl
  Reject {Initialize-AuthWireChannelKeyCore -Mode Inspect -Directory $root -BaseBinding $b} 'Writable receipt rejected'
  $acl.SetSecurityDescriptorSddlForm($racl);Set-Acl -LiteralPath $receipt -AclObject $acl
  $r=Initialize-AuthWireChannelKeyCore -Mode Inspect -Directory $root -BaseBinding $b
  Check ($r.ReadAclVerified -and -not $r.KeyCreated -and (Get-Acl -LiteralPath $path).Sddl -ceq $before) 'Fixture changes restored; inspect preserves exact key ACL'
 }finally{$key.Dispose()}
 @{create_checks=$script:checks}|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $Directory 'create-result.json') -Encoding UTF8
 exit 0
}
if($Mode -eq 'Cleanup'){
 $base=Get-Content -LiteralPath (Join-Path $Directory 'base.json') -Raw|ConvertFrom-Json
 $name=$null
 if(Test-Path -LiteralPath $prepFile){$name=(Get-Content -LiteralPath $prepFile -Raw|ConvertFrom-Json).KeyName}
 elseif(Test-Path -LiteralPath (Join-Path $root 'channel-key.json')){$name=(Get-Content -LiteralPath (Join-Path $root 'channel-key.json') -Raw|ConvertFrom-Json).KeyName}
 if($name){
  if($name -cnotmatch ('\AAuthWire-Channel-'+([guid]$base.connector_id).ToString('N')+'-[0-9a-f]{32}\z')){throw 'Fixture key name mismatch'}
  if([Security.Cryptography.CngKey]::Exists($name,[Security.Cryptography.CngProvider]::MicrosoftSoftwareKeyStorageProvider,[Security.Cryptography.CngKeyOpenOptions]::MachineKey)){
   $key=[Security.Cryptography.CngKey]::Open($name,[Security.Cryptography.CngProvider]::MicrosoftSoftwareKeyStorageProvider,[Security.Cryptography.CngKeyOpenOptions]::MachineKey);$key.Delete();$key.Dispose()
  }
  if([Security.Cryptography.CngKey]::Exists($name,[Security.Cryptography.CngProvider]::MicrosoftSoftwareKeyStorageProvider,[Security.Cryptography.CngKeyOpenOptions]::MachineKey)){throw 'Fixture key cleanup failed'}
 }
 if(Test-Path -LiteralPath $root){Assert-AuthWireChannelPath $root;Remove-Item -LiteralPath $root -Recurse -Force}
 exit 0
}
$prep=Get-Content -LiteralPath $prepFile -Raw|ConvertFrom-Json
if($prep.KeyName -cnotmatch '\AAuthWire-Channel-[0-9a-f]{32}-[0-9a-f]{32}\z'){throw 'Fixture key name mismatch'}
$key=[Security.Cryptography.CngKey]::Open($prep.KeyName,[Security.Cryptography.CngProvider]::MicrosoftSoftwareKeyStorageProvider,[Security.Cryptography.CngKeyOpenOptions]::MachineKey)
$rsa=[Security.Cryptography.RSACng]::new($key)
$b=@{};foreach($p in $prep.PairingCandidate.PSObject.Properties){if($p.Name -ne 'public_key_pem'){$b[$p.Name]=$p.Value}}
$b.generation=1;$b.channel_key_sha256=$prep.KeySha256
$base=Get-Content -LiteralPath (Join-Path $Directory 'base.json') -Raw|ConvertFrom-Json
$url='https://'+$b.appliance_fqdn+':'+$base.port+'/'
$rootStore=[Security.Cryptography.X509Certificates.X509Store]::new('Root','LocalMachine')
$cert=[Security.Cryptography.X509Certificates.X509Certificate2]::new((Join-Path $Directory 'web.crt'))
$hosts=Join-Path $env:SystemRoot 'System32\drivers\etc\hosts';$hostBytes=[IO.File]::ReadAllBytes($hosts);$added=$false
$keyPath=Join-Path (Join-Path $env:ProgramData 'Microsoft\Crypto\Keys') $key.UniqueName
$before=(Get-Acl -LiteralPath $keyPath).Sddl
try{
 $extra="`r`n127.0.0.1 "+$b.appliance_fqdn+' other-'+$b.appliance_fqdn+"`r`n"
 [IO.File]::WriteAllBytes($hosts,($hostBytes+[Text.Encoding]::ASCII.GetBytes($extra)))
 Reject {Invoke-AuthWireConnectorHealth -BaseUrl $url -Binding $b -ChannelKey $rsa} 'Untrusted TLS certificate rejected'
 $rootStore.Open([Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
 if($rootStore.Certificates.Find([Security.Cryptography.X509Certificates.X509FindType]::FindByThumbprint,$cert.Thumbprint,$false).Count){throw 'Unexpected existing fixture trust'}
 $rootStore.Add($cert);$added=$true
 $wrong=$b.Clone();$wrong.appliance_tls_sha256='b'*64
 Reject {Invoke-AuthWireConnectorHealth -BaseUrl $url -Binding $wrong -ChannelKey $rsa} 'Trusted chain with wrong pin rejected'
 $wrong=$b.Clone();$wrong.appliance_fqdn='other-'+$b.appliance_fqdn
 Reject {Invoke-AuthWireConnectorHealth -BaseUrl ($url.Replace($b.appliance_fqdn,$wrong.appliance_fqdn)) -Binding $wrong -ChannelKey $rsa} 'Hostname mismatch rejected despite matching pin'
 Reject {Invoke-AuthWireConnectorHealth -BaseUrl ($url.Replace('https:','http:')) -Binding $b -ChannelKey $rsa} 'Plain HTTP rejected before network'
 foreach($case in @('redirect','oversized','slow','slow_body')){
  Set-Content -LiteralPath (Join-Path $Directory 'case.txt') -Value $case -Encoding ASCII
  $watch=[Diagnostics.Stopwatch]::StartNew()
  Reject {Invoke-AuthWireConnectorHealth -BaseUrl $url -Binding $b -ChannelKey $rsa} ('Reject server '+$case)
  if($case -in @('slow','slow_body')){Check ($watch.Elapsed.TotalSeconds -lt 9) 'Absolute HTTP deadline is bounded'}
 }
 Set-Content -LiteralPath (Join-Path $Directory 'case.txt') -Value 'normal' -Encoding ASCII
 $r=Invoke-AuthWireConnectorHealth -BaseUrl $url -Binding $b -ChannelKey $rsa
 Check ($r.Verified -and -not $r.CanApply -and -not $r.ConnectorInstalled -and -not $r.AdChanged) 'Actual Windows HTTPS signed health roundtrip'
 Check ((Get-Acl -LiteralPath $keyPath).Sddl -ceq $before) 'Client leaves machine key ACL unchanged'
 foreach($s in @('{"channel_proof_verified":true,"can_apply":true,"directory_sync_ready":false,"kerberos_ready":false}','{"channel_proof_verified":true,"can_apply":false,"can_apply":false,"kerberos_ready":false}','[]')){Check (-not [AuthWire.Connector.ChannelTypesV1]::Healthy($s)) 'Reject invalid or overclaiming server reply'}
 Reject {[AuthWire.Connector.ChannelTypesV1]::Frame('{"frame":"AAAA","frame":"BBBB"}')} 'Duplicate challenge JSON rejected'
 @{client_checks=$script:checks;verified=$r.Verified;key_acl_preserved=$true;ad_changed=$false;gpo_changed=$false;service_installed=$false}|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $Directory 'client-result.json') -Encoding UTF8
}finally{
 [IO.File]::WriteAllBytes($hosts,$hostBytes)
 if($added){$rootStore.Remove($cert)}
 $rootStore.Close();$rootStore.Dispose();$cert.Dispose();$rsa.Dispose();$key.Dispose()
}
