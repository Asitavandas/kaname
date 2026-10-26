# Local, signed network preparation only. Never imports profiles, installs clients or writes GPOs.
param(
 [ValidateSet('Inspect','Prepare','Verify')][string]$Mode='Inspect',
 [Parameter(Mandatory=$true)][string]$NetworkProfileZip,
 [Parameter(Mandatory=$true)][string]$ApprovalPath,
 [Parameter(Mandatory=$true)][string]$ExpectedApprovalSha256
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version 2

function Initialize-AuthWireCandidateTypes {
 if('AuthWire.Deployment.CandidateJsonV1' -as [type]){return}
 Add-Type -AssemblyName System.Web.Extensions
 Add-Type -AssemblyName System.IO.Compression
 Add-Type -ReferencedAssemblies @('System.dll','System.Core.dll',[Web.Script.Serialization.JavaScriptSerializer].Assembly.Location) -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Text.RegularExpressions;
using System.Web.Script.Serialization;
namespace AuthWire.Deployment {
 public sealed class CandidateJsonV1 {
  string s; int p, tokens; JavaScriptSerializer j=new JavaScriptSerializer();
  CandidateJsonV1(string value){s=value;j.MaxJsonLength=65536;j.RecursionLimit=20;}
  void Fail(){throw new InvalidOperationException("DEPLOYMENT_JSON_REJECTED");}
  void White(){while(p<s.Length&&(s[p]==' '||s[p]=='\r'||s[p]=='\n'||s[p]=='\t'))p++;}
  void Take(char c){White();if(p>=s.Length||s[p++]!=c)Fail();}
  string Str(){White();int start=p;Take('"');bool escape=false;while(p<s.Length){char c=s[p++];if(c<32)Fail();if(escape){escape=false;continue;}if(c=='\\'){escape=true;continue;}if(c=='"')return j.Deserialize<string>(s.Substring(start,p-start));}Fail();return null;}
  void Value(int depth){
   if(depth>16||++tokens>4096)Fail();White();if(p>=s.Length)Fail();char c=s[p];
   if(c=='{'){p++;White();var seen=new HashSet<string>(StringComparer.OrdinalIgnoreCase);if(p<s.Length&&s[p]=='}'){p++;return;}while(true){string key=Str();if(!seen.Add(key))Fail();Take(':');Value(depth+1);White();if(p<s.Length&&s[p]=='}'){p++;return;}Take(',');}}
   if(c=='['){p++;White();if(p<s.Length&&s[p]==']'){p++;return;}while(true){Value(depth+1);White();if(p<s.Length&&s[p]==']'){p++;return;}Take(',');}}
   if(c=='"'){Str();return;}
   int begin=p;while(p<s.Length&&s[p]!=','&&s[p]!=']'&&s[p]!='}'&&s[p]!=' '&&s[p]!='\n'&&s[p]!='\r'&&s[p]!='\t')p++;
   string word=s.Substring(begin,p-begin);if(word!="true"&&word!="false"&&word!="null"&&!Regex.IsMatch(word,@"\A-?(?:0|[1-9][0-9]*)(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?\z"))Fail();
  }
  public static void Check(string text){if(text==null||text.Length>65536)throw new InvalidOperationException("DEPLOYMENT_JSON_LIMIT");var parser=new CandidateJsonV1(text);parser.Value(0);parser.White();if(parser.p!=text.Length)parser.Fail();}
 }
}
'@
}
function Get-AuthWireCandidateHash([byte[]]$Bytes){
 $sha=[Security.Cryptography.SHA256]::Create()
 try{return ([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-','').ToLowerInvariant()}finally{$sha.Dispose()}
}
function Assert-AuthWireCandidatePath([string]$Path){
 if(-not [IO.Path]::IsPathRooted($Path) -or $Path.StartsWith('\\') -or $Path -match ':.*:'){throw 'DEPLOYMENT_PATH_REJECTED'}
 $full=[IO.Path]::GetFullPath($Path);$part=$full
 while($part){
  if(Test-Path -LiteralPath $part){if((Get-Item -LiteralPath $part -Force).Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'DEPLOYMENT_REPARSE_REJECTED'}}
  $parent=[IO.Path]::GetDirectoryName($part);if($parent -eq $part){break};$part=$parent
 }
 return $full
}
function Read-AuthWireCandidateBytes([string]$Path,[int]$Limit){
 $full=Assert-AuthWireCandidatePath $Path;$item=Get-Item -LiteralPath $full -Force
 if($item.PSIsContainer -or $item.Length -gt $Limit){throw 'DEPLOYMENT_FILE_LIMIT'}
 $bytes=[IO.File]::ReadAllBytes($full);if($bytes.Length -gt $Limit){throw 'DEPLOYMENT_FILE_LIMIT'}
 return ,$bytes
}
function ConvertFrom-AuthWireCandidateJson([byte[]]$Bytes){
 Initialize-AuthWireCandidateTypes
 $text=[Text.UTF8Encoding]::new($false,$true).GetString($Bytes)
 [AuthWire.Deployment.CandidateJsonV1]::Check($text)
 return ($text|ConvertFrom-Json)
}
function Assert-AuthWireCandidateFields($Value,[string[]]$Names){
 if($null -eq $Value -or $Value -isnot [pscustomobject] -or @($Value.PSObject.Properties).Count -ne $Names.Count -or @($Value.PSObject.Properties.Name|Where-Object{$_ -cnotin $Names}).Count){throw 'DEPLOYMENT_FIELDS_REJECTED'}
}
function Assert-AuthWireCandidateGuid($Value){
 $id=[guid]::Empty
 if($Value -isnot [string] -or -not [guid]::TryParseExact($Value,'D',[ref]$id) -or $id -eq [guid]::Empty -or $id.ToString('D') -cne $Value){throw 'DEPLOYMENT_ID_REJECTED'}
}
function Read-AuthWireCandidateApproval([string]$Path,[string]$ExpectedHash){
 if($ExpectedHash -cnotmatch '\A[0-9a-f]{64}\z'){throw 'DEPLOYMENT_APPROVAL_PIN_REQUIRED'}
 $bytes=Read-AuthWireCandidateBytes $Path 8192
 if((Get-AuthWireCandidateHash $bytes) -cne $ExpectedHash){throw 'DEPLOYMENT_APPROVAL_CHANGED'}
 $a=ConvertFrom-AuthWireCandidateJson $bytes
 Assert-AuthWireCandidateFields $a @('format','zip_sha256','plan_id','plan_version','preview_hash','machine_profile_id','machine_profile_version','group_sid','domain','server_name','ssid','root_thumbprint','connector_id','service_sid','gpo_id','protected_gpo_id','publisher_thumbprint')
 if($a.format -isnot [int] -or $a.format -ne 1){throw 'DEPLOYMENT_APPROVAL_REJECTED'}
 foreach($n in @('zip_sha256','preview_hash')){if($a.$n -isnot [string] -or $a.$n -cnotmatch '\A[0-9a-f]{64}\z'){throw 'DEPLOYMENT_APPROVAL_REJECTED'}}
 foreach($n in @('plan_id','machine_profile_id','connector_id','gpo_id','protected_gpo_id')){Assert-AuthWireCandidateGuid $a.$n}
 if($a.gpo_id -ceq $a.protected_gpo_id){throw 'DEPLOYMENT_PROTECTED_GPO_REJECTED'}
 foreach($n in @('plan_version','machine_profile_version')){if($a.$n -isnot [int] -or $a.$n -lt 1){throw 'DEPLOYMENT_APPROVAL_REJECTED'}}
 foreach($n in @('group_sid','service_sid')){if($a.$n -isnot [string] -or $a.$n -cnotmatch '\AS-1-5-21-(?:[1-9][0-9]{0,9}-){3}[1-9][0-9]{0,9}\z'){throw 'DEPLOYMENT_APPROVAL_REJECTED'}}
 if($a.group_sid -ceq $a.service_sid){throw 'DEPLOYMENT_APPROVAL_REJECTED'}
 foreach($n in @('root_thumbprint','publisher_thumbprint')){if($a.$n -isnot [string] -or $a.$n -cnotmatch '\A[0-9A-F]{40}\z'){throw 'DEPLOYMENT_APPROVAL_REJECTED'}}
 foreach($n in @('domain','server_name')){
  if($a.$n -isnot [string] -or $a.$n.Length -gt 253 -or $a.$n.Split('.').Count -lt 2){throw 'DEPLOYMENT_APPROVAL_REJECTED'}
  foreach($label in $a.$n.Split('.')){if($label -cnotmatch '\A[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\z'){throw 'DEPLOYMENT_APPROVAL_REJECTED'}}
 }
 # This first candidate format is deliberately the accepted machine + wired/Wi-Fi pilot.
 if($a.ssid -isnot [string] -or [Text.Encoding]::UTF8.GetByteCount($a.ssid) -lt 1 -or [Text.Encoding]::UTF8.GetByteCount($a.ssid) -gt 32 -or $a.ssid -match '[\x00-\x1f\x7f]'){throw 'DEPLOYMENT_APPROVAL_REJECTED'}
 return [pscustomobject]@{Value=$a;Bytes=$bytes;Hash=$ExpectedHash}
}
function Read-AuthWireCandidateXml([byte[]]$Bytes){
 $settings=[Xml.XmlReaderSettings]::new();$settings.DtdProcessing=[Xml.DtdProcessing]::Prohibit;$settings.XmlResolver=$null;$settings.MaxCharactersInDocument=32768
 $stream=[IO.MemoryStream]::new($Bytes,$false);$reader=$null
 try{$reader=[Xml.XmlReader]::Create($stream,$settings);$doc=[Xml.XmlDocument]::new();$doc.XmlResolver=$null;$doc.Load($reader);return ,$doc}finally{if($reader){$reader.Dispose()};$stream.Dispose()}
}
function Get-AuthWireCandidateXmlShape([Xml.XmlNode]$Node){
 if($Node.NodeType -eq [Xml.XmlNodeType]::XmlDeclaration -or $Node.NodeType -eq [Xml.XmlNodeType]::Whitespace){return ''}
 if($Node.NodeType -eq [Xml.XmlNodeType]::Document){return (@($Node.ChildNodes|ForEach-Object{Get-AuthWireCandidateXmlShape $_}) -join '')}
 if($Node.NodeType -eq [Xml.XmlNodeType]::Text){return 'T'+$Node.Value.Length+':'+$Node.Value}
 if($Node.NodeType -ne [Xml.XmlNodeType]::Element){throw 'DEPLOYMENT_XML_SHAPE_REJECTED'}
 $attrs=@($Node.Attributes|Where-Object{$_.NamespaceURI -ne 'http://www.w3.org/2000/xmlns/'})
 if($attrs.Count){throw 'DEPLOYMENT_XML_SHAPE_REJECTED'}
 return '{'+$Node.NamespaceURI+'}'+$Node.LocalName+'['+(@($Node.ChildNodes|ForEach-Object{Get-AuthWireCandidateXmlShape $_}) -join '')+']'
}
function New-AuthWireExpectedCandidateXml($Approval,[bool]$Wireless){
 $lan='http://www.microsoft.com/networking/LAN/profile/v1';$wlan='http://www.microsoft.com/networking/WLAN/profile/v1';$one='http://www.microsoft.com/networking/OneX/v1';$prov='http://www.microsoft.com/provisioning/'
 $ssid=[Security.SecurityElement]::Escape($Approval.ssid);$name=[Security.SecurityElement]::Escape($Approval.server_name)
 $hex=([BitConverter]::ToString([Text.Encoding]::UTF8.GetBytes($Approval.ssid))).Replace('-','')
 $thumb=($Approval.root_thumbprint.ToLowerInvariant() -split '(.{2})'|Where-Object{$_}) -join ' '
 $auth='<OneX xmlns="'+$one+'"><authMode>machine</authMode><EAPConfig><EapHostConfig xmlns="'+$prov+'EapHostConfig"><EapMethod><Type xmlns="'+$prov+'EapCommon">13</Type><VendorId xmlns="'+$prov+'EapCommon">0</VendorId><VendorType xmlns="'+$prov+'EapCommon">0</VendorType><AuthorId xmlns="'+$prov+'EapCommon">0</AuthorId></EapMethod><Config><Eap xmlns="'+$prov+'BaseEapConnectionPropertiesV1"><Type>13</Type><EapType xmlns="'+$prov+'EapTlsConnectionPropertiesV1"><CredentialsSource><CertificateStore><SimpleCertSelection>true</SimpleCertSelection></CertificateStore></CredentialsSource><ServerValidation><DisableUserPromptForServerValidation>true</DisableUserPromptForServerValidation><ServerNames>'+$name+'</ServerNames><TrustedRootCA>'+$thumb+'</TrustedRootCA></ServerValidation><DifferentUsername>false</DifferentUsername><PerformServerValidation xmlns="'+$prov+'EapTlsConnectionPropertiesV2">true</PerformServerValidation><AcceptServerName xmlns="'+$prov+'EapTlsConnectionPropertiesV2">true</AcceptServerName></EapType></Eap></Config></EapHostConfig></EAPConfig></OneX>'
 if($Wireless){$xml='<WLANProfile xmlns="'+$wlan+'"><name>'+$ssid+'</name><SSIDConfig><SSID><hex>'+$hex+'</hex><name>'+$ssid+'</name></SSID></SSIDConfig><connectionType>ESS</connectionType><connectionMode>auto</connectionMode><MSM><security><authEncryption><authentication>WPA2</authentication><encryption>AES</encryption><useOneX>true</useOneX></authEncryption>'+$auth+'</security></MSM></WLANProfile>'}
 else{$xml='<LANProfile xmlns="'+$lan+'"><MSM><security><OneXEnforced>false</OneXEnforced><OneXEnabled>true</OneXEnabled>'+$auth+'</security></MSM></LANProfile>'}
 return (Read-AuthWireCandidateXml ([Text.Encoding]::UTF8.GetBytes($xml)))
}
function Read-AuthWireNetworkCandidate([string]$Path,$Approval){
 Initialize-AuthWireCandidateTypes
 $bytes=Read-AuthWireCandidateBytes $Path 262144
 if((Get-AuthWireCandidateHash $bytes) -cne $Approval.zip_sha256){throw 'DEPLOYMENT_ZIP_CHANGED'}
 $files=@{};$memory=[IO.MemoryStream]::new($bytes,$false);$zip=$null;$total=0
 try{
  $zip=[IO.Compression.ZipArchive]::new($memory,[IO.Compression.ZipArchiveMode]::Read,$false)
  $allowed=@('README.txt','WiFi-EAP-TLS.xml','Wired-EAP-TLS.xml','issuer-ca.pem','manifest.json','plan.json','root-ca.pem')
  if($zip.Entries.Count -ne $allowed.Count){throw 'DEPLOYMENT_ZIP_FILES_REJECTED'}
  foreach($entry in $zip.Entries){
   if($entry.FullName -cnotin $allowed -or $files.ContainsKey($entry.FullName) -or $entry.Length -gt 65536){throw 'DEPLOYMENT_ZIP_FILES_REJECTED'}
   $total+=$entry.Length;if($total -gt 196608){throw 'DEPLOYMENT_ZIP_LIMIT'}
   $entryStream=$entry.Open();$output=[IO.MemoryStream]::new()
   try{[byte[]]$buffer=New-Object byte[] 4096;while(($count=$entryStream.Read($buffer,0,$buffer.Length)) -gt 0){$output.Write($buffer,0,$count);if($output.Length -gt 65536){throw 'DEPLOYMENT_ZIP_LIMIT'}};$files[$entry.FullName]=$output.ToArray()}finally{$entryStream.Dispose();$output.Dispose()}
  }
 }finally{if($zip){$zip.Dispose()};$memory.Dispose()}
 $m=ConvertFrom-AuthWireCandidateJson $files['manifest.json'];$p=ConvertFrom-AuthWireCandidateJson $files['plan.json']
 Assert-AuthWireCandidateFields $m @('files','format','plan_id','preview_hash','version')
 Assert-AuthWireCandidateFields $m.files @('README.txt','WiFi-EAP-TLS.xml','Wired-EAP-TLS.xml','issuer-ca.pem','plan.json','root-ca.pem')
 foreach($f in $m.files.PSObject.Properties){if($f.Value -isnot [string] -or $f.Value -cnotmatch '\A[0-9a-f]{64}\z' -or (Get-AuthWireCandidateHash $files[$f.Name]) -cne $f.Value){throw 'DEPLOYMENT_MANIFEST_HASH_REJECTED'}}
 if($m.format -isnot [int] -or $m.format -ne 1 -or $m.plan_id -cne $Approval.plan_id -or $m.preview_hash -cne $Approval.preview_hash -or $m.version -isnot [int] -or $m.version -ne $Approval.plan_version){throw 'DEPLOYMENT_PLAN_REJECTED'}
 if($p.id -cne $m.plan_id -or $p.preview_hash -cne $m.preview_hash -or $p.version -isnot [int] -or $p.version -ne $m.version -or $p.domain -cne $Approval.domain -or $p.runtime_applied -isnot [bool] -or $p.runtime_applied -or $p.gpo_changed -isnot [bool] -or $p.gpo_changed -or $p.can_apply -isnot [bool] -or $p.can_apply -or $p.can_export_profiles -isnot [bool] -or -not $p.can_export_profiles -or $p.artifact_blockers -isnot [array] -or $p.artifact_blockers.Count){throw 'DEPLOYMENT_PLAN_REJECTED'}
 $plan=$p.plan
 foreach($n in @('id','machine_profile_id','computer_group_sid','domain','server_name','ssid')){
  $expected=switch($n){'id'{$Approval.plan_id};'computer_group_sid'{$Approval.group_sid};default{$Approval.$n}}
  if($plan.$n -isnot [string] -or $plan.$n -cne $expected){throw 'DEPLOYMENT_PLAN_REJECTED'}
 }
 if($plan.version -isnot [int] -or $plan.version -ne $Approval.plan_version -or $plan.auth_mode -cne 'machine' -or $plan.user_profile_id -cne '' -or $plan.wired -isnot [bool] -or -not $plan.wired -or $plan.wireless -isnot [bool] -or -not $plan.wireless){throw 'DEPLOYMENT_PLAN_REJECTED'}
 if($p.enrollment_profiles -isnot [array] -or $p.enrollment_profiles.Count -ne 1){throw 'DEPLOYMENT_PROFILE_REJECTED'}
 $profile=$p.enrollment_profiles[0]
 if($profile.id -cne $Approval.machine_profile_id -or $profile.version -isnot [int] -or $profile.version -ne $Approval.machine_profile_version -or $profile.group_sid -cne $Approval.group_sid -or $profile.domain -cne $Approval.domain -or $profile.enabled -isnot [int] -or $profile.enabled -ne 1){throw 'DEPLOYMENT_PROFILE_REJECTED'}
 if($p.computer_targets.available -isnot [bool] -or -not $p.computer_targets.available -or $p.computer_targets.enabled -isnot [int] -or $p.computer_targets.enabled -lt 1 -or $p.computer_targets.unresolved -isnot [int] -or $p.computer_targets.unresolved -ne 0 -or $null -ne $p.user_targets -or $p.trust.ready -isnot [bool] -or -not $p.trust.ready -or $p.trust.root_thumbprint -cne $Approval.root_thumbprint.ToLowerInvariant()){throw 'DEPLOYMENT_TARGET_OR_TRUST_REJECTED'}
 foreach($wireless in @($false,$true)){
  $name=if($wireless){'WiFi-EAP-TLS.xml'}else{'Wired-EAP-TLS.xml'}
  $actual=Read-AuthWireCandidateXml $files[$name];$expected=New-AuthWireExpectedCandidateXml $Approval $wireless
  if((Get-AuthWireCandidateXmlShape $actual) -cne (Get-AuthWireCandidateXmlShape $expected)){throw 'DEPLOYMENT_XML_REJECTED'}
 }
 # Exact DER pin and issuer path; no OS trust-store mutation or online revocation claim.
 $certs=@()
 try{
  foreach($name in @('root-ca.pem','issuer-ca.pem')){
   $pem=[Text.Encoding]::ASCII.GetString($files[$name]);$match=[regex]::Match($pem,'\A-----BEGIN CERTIFICATE-----\s+([A-Za-z0-9+/=\r\n]+)-----END CERTIFICATE-----\s*\z')
   if(-not $match.Success){throw 'DEPLOYMENT_CA_REJECTED'}
   $cert=[Security.Cryptography.X509Certificates.X509Certificate2]::new([Convert]::FromBase64String($match.Groups[1].Value));$certs+=,$cert
   if($cert.HasPrivateKey -or $cert.NotBefore.ToUniversalTime() -gt [DateTime]::UtcNow -or $cert.NotAfter.ToUniversalTime() -le [DateTime]::UtcNow){throw 'DEPLOYMENT_CA_REJECTED'}
   $bc=@($cert.Extensions|Where-Object{$_.Oid.Value -ceq '2.5.29.19'});if($bc.Count -ne 1 -or -not ([Security.Cryptography.X509Certificates.X509BasicConstraintsExtension]$bc[0]).CertificateAuthority){throw 'DEPLOYMENT_CA_REJECTED'}
  }
  if($certs[0].Thumbprint -cne $Approval.root_thumbprint -or (Get-AuthWireCandidateHash $certs[0].RawData) -cne $p.trust.root_sha256 -or $certs[0].Subject -cne $certs[0].Issuer -or $certs[1].Issuer -cne $certs[0].Subject){throw 'DEPLOYMENT_CA_REJECTED'}
  $chain=[Security.Cryptography.X509Certificates.X509Chain]::new()
  try{
   $chain.ChainPolicy.RevocationMode=[Security.Cryptography.X509Certificates.X509RevocationMode]::NoCheck
   $chain.ChainPolicy.VerificationFlags=[Security.Cryptography.X509Certificates.X509VerificationFlags]::AllowUnknownCertificateAuthority
   $chain.ChainPolicy.UrlRetrievalTimeout=[TimeSpan]::Zero;$null=$chain.ChainPolicy.ExtraStore.Add($certs[0])
   $null=$chain.Build($certs[1])
   if($chain.ChainElements.Count -ne 2 -or $chain.ChainElements[0].Certificate.Thumbprint -cne $certs[1].Thumbprint -or $chain.ChainElements[1].Certificate.Thumbprint -cne $Approval.root_thumbprint -or @($chain.ChainStatus|Where-Object{$_.Status -ne [Security.Cryptography.X509Certificates.X509ChainStatusFlags]::UntrustedRoot -and $_.Status -ne [Security.Cryptography.X509Certificates.X509ChainStatusFlags]::NoError}).Count){throw 'DEPLOYMENT_CA_REJECTED'}
  }finally{$chain.Dispose()}
 }finally{foreach($cert in $certs){$cert.Dispose()}}
 return [pscustomobject]@{Bytes=$bytes;PlanId=$m.plan_id;Version=$m.version;TargetCount=$p.computer_targets.enabled;ZipSha256=$Approval.zip_sha256}
}
function Get-AuthWireCandidateSigner($Approval,[switch]$OpenPrivateKey){
 $cert=Get-Item -LiteralPath ('Cert:\LocalMachine\My\'+$Approval.publisher_thumbprint)
 if($cert.NotBefore.ToUniversalTime() -gt [DateTime]::UtcNow -or $cert.NotAfter.ToUniversalTime() -le [DateTime]::UtcNow -or -not $cert.HasPrivateKey){throw 'DEPLOYMENT_SIGNER_REJECTED'}
 $eku=@($cert.Extensions|Where-Object{$_.Oid.Value -ceq '2.5.29.37'})
 if($eku.Count -ne 1 -or $eku[0].EnhancedKeyUsages.Count -ne 1 -or $eku[0].EnhancedKeyUsages[0].Value -cne '1.3.6.1.5.5.7.3.3'){throw 'DEPLOYMENT_SIGNER_REJECTED'}
 $chain=[Security.Cryptography.X509Certificates.X509Chain]::new()
 try{$chain.ChainPolicy.RevocationMode=[Security.Cryptography.X509Certificates.X509RevocationMode]::Online;$chain.ChainPolicy.UrlRetrievalTimeout=[TimeSpan]::FromSeconds(5);if(-not $chain.Build($cert)){throw 'DEPLOYMENT_SIGNER_CHAIN_REJECTED'}}finally{$chain.Dispose()}
 if($OpenPrivateKey){
  $key=[Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($cert)
  try{if($key -isnot [Security.Cryptography.RSACng] -or -not $key.Key.IsMachineKey -or $key.Key.IsEphemeral -or [int]$key.Key.ExportPolicy -ne 0 -or [int]$key.Key.KeyUsage -ne 2 -or $key.KeySize -lt 3072 -or $key.Key.Provider.Provider -cne 'Microsoft Software Key Storage Provider'){throw 'DEPLOYMENT_SIGNER_KEY_REJECTED'}}finally{if($key){$key.Dispose()}}
 }
 return $cert
}
function Set-AuthWireCandidateAcl([string]$Path,[string]$ServiceSid,[switch]$Directory){
 $flags=if($Directory){'OICI'}else{''};$rights=if($Directory){'FRFX'}else{'FR'}
 $acl=Get-Acl -LiteralPath $Path
 $acl.SetSecurityDescriptorSddlForm(('O:BAG:BAD:P(A;'+$flags+';FA;;;SY)(A;'+$flags+';FA;;;BA)(A;'+$flags+';'+$rights+';;;'+$ServiceSid+')'))
 Set-Acl -LiteralPath $Path -AclObject $acl
}
function Assert-AuthWireCandidateAcl([string]$Path,[string]$ServiceSid,[switch]$Directory){
 $null=Assert-AuthWireCandidatePath $Path;$acl=Get-Acl -LiteralPath $Path
 if(-not $acl.AreAccessRulesProtected -or $acl.GetOwner([Security.Principal.SecurityIdentifier]).Value -cne 'S-1-5-32-544'){throw 'DEPLOYMENT_ACL_REJECTED'}
 $rules=@($acl.GetAccessRules($true,$true,[Security.Principal.SecurityIdentifier]));if($rules.Count -ne 3){throw 'DEPLOYMENT_ACL_REJECTED'}
 $seen=@{}
 foreach($rule in $rules){
  $sid=$rule.IdentityReference.Value;$rights=if($sid -ceq $ServiceSid){if($Directory){1179817}else{1179785}}else{2032127}
  $inherit=if($Directory){3}else{0}
  if($sid -cnotin @('S-1-5-18','S-1-5-32-544',$ServiceSid) -or $seen.ContainsKey($sid) -or $rule.IsInherited -or $rule.AccessControlType.ToString() -cne 'Allow' -or [int]$rule.FileSystemRights -ne $rights -or [int]$rule.InheritanceFlags -ne $inherit -or [int]$rule.PropagationFlags -ne 0){throw 'DEPLOYMENT_ACL_REJECTED'}
  $seen[$sid]=$true
 }
}
function Get-AuthWireCandidateManifestText($Approval,[string]$ApprovalHash){
 $manifest=[ordered]@{format=1;purpose='network_preparation_only';approval_sha256=$ApprovalHash;zip_sha256=$Approval.zip_sha256;plan_id=$Approval.plan_id;plan_version=$Approval.plan_version;preview_hash=$Approval.preview_hash;connector_id=$Approval.connector_id;gpo_id=$Approval.gpo_id;publisher_thumbprint=$Approval.publisher_thumbprint;can_apply=$false}
 $encoded=[Convert]::ToBase64String([Text.UTF8Encoding]::new($false).GetBytes(($manifest|ConvertTo-Json -Compress)))
 return "# AuthWireDeploymentCandidateV1`r`n# Manifest-Base64: $encoded`r`n"
}
function Test-AuthWirePreparedCandidate([string]$Path,$Approval,[byte[]]$ApprovalBytes,[string]$ApprovalHash){
 Assert-AuthWireCandidateAcl $Path $Approval.service_sid -Directory
 $entries=@(Get-ChildItem -LiteralPath $Path -Force)
 if($entries.Count -ne 3 -or @($entries|Where-Object{$_.PSIsContainer -or $_.Name -cnotin @('network-profiles.zip','approval.json','AuthWire-Candidate-Manifest.ps1')}).Count){throw 'DEPLOYMENT_CANDIDATE_FILES_REJECTED'}
 foreach($entry in $entries){Assert-AuthWireCandidateAcl $entry.FullName $Approval.service_sid}
 if((Get-AuthWireCandidateHash (Read-AuthWireCandidateBytes (Join-Path $Path 'approval.json') 8192)) -cne $ApprovalHash -or (Get-AuthWireCandidateHash (Read-AuthWireCandidateBytes (Join-Path $Path 'network-profiles.zip') 262144)) -cne $Approval.zip_sha256){throw 'DEPLOYMENT_CANDIDATE_CHANGED'}
 $manifestPath=Join-Path $Path 'AuthWire-Candidate-Manifest.ps1'
 $raw=Read-AuthWireCandidateBytes $manifestPath 65536;$text=[Text.UTF8Encoding]::new($false,$true).GetString($raw).TrimStart([char]0xfeff)
 $body=($text -split '(?m)^# SIG # Begin signature block\r?$',2)[0]
 if($body.TrimEnd([char[]]"`r`n") -cne (Get-AuthWireCandidateManifestText $Approval $ApprovalHash).TrimEnd([char[]]"`r`n")){throw 'DEPLOYMENT_MANIFEST_BODY_REJECTED'}
 $sig=Get-AuthenticodeSignature -LiteralPath $manifestPath
 if($sig.Status.ToString() -cne 'Valid' -or $null -eq $sig.SignerCertificate -or $sig.SignerCertificate.Thumbprint -cne $Approval.publisher_thumbprint){throw 'DEPLOYMENT_SIGNATURE_REJECTED'}
 $tokens=$null;$errors=$null;$ast=[Management.Automation.Language.Parser]::ParseFile($manifestPath,[ref]$tokens,[ref]$errors)
 if($errors.Count -or $ast.ParamBlock -or $ast.BeginBlock -or $ast.ProcessBlock -or $ast.DynamicParamBlock -or ($ast.EndBlock -and $ast.EndBlock.Statements.Count)){throw 'DEPLOYMENT_EXECUTABLE_MANIFEST_REJECTED'}
 return [pscustomobject]@{Event='WINDOWS_DEPLOYMENT_CANDIDATE';CandidatePath=$Path;PlanId=$Approval.plan_id;PlanVersion=$Approval.plan_version;GpoId=$Approval.gpo_id;ManifestSha256=(Get-AuthWireCandidateHash $raw);SignatureVerified=$true;ArtifactExecuted=$false;CanApplyGpo=$false;AdChanged=$false;GpoChanged=$false;EndpointChanged=$false;ServicesChanged=$false;TrustStoreChanged=$false;KeyAclChanged=$false;SecretsExported=$false}
}
function Invoke-AuthWireDeploymentCandidate {
 param([string]$Mode,[string]$NetworkProfileZip,[string]$ApprovalPath,[string]$ExpectedApprovalSha256)
 $identity=[Security.Principal.WindowsIdentity]::GetCurrent()
 try{if(-not [Environment]::Is64BitProcess -or -not ([Security.Principal.WindowsPrincipal]::new($identity)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){throw 'DEPLOYMENT_ADMIN_REQUIRED'}}finally{$identity.Dispose()}
 $receipt=Read-AuthWireCandidateApproval $ApprovalPath $ExpectedApprovalSha256;$a=$receipt.Value
 $network=Read-AuthWireNetworkCandidate $NetworkProfileZip $a
 $parent=Join-Path $env:ProgramData ('AuthWire-DeploymentCandidates-'+([guid]$a.connector_id).ToString('N'))
 $target=Join-Path $parent (([guid]$a.plan_id).ToString('N')+'-v'+$a.plan_version+'-'+$a.preview_hash)
 $null=Assert-AuthWireCandidatePath $target
 $exists=Test-Path -LiteralPath $target
 if(Test-Path -LiteralPath $parent){Assert-AuthWireCandidateAcl $parent $a.service_sid -Directory}
 $cert=Get-AuthWireCandidateSigner $a
 try{
  if($Mode -ceq 'Inspect'){
   if($exists){$null=Test-AuthWirePreparedCandidate $target $a $receipt.Bytes $receipt.Hash}
   return [pscustomobject]@{Event='WINDOWS_DEPLOYMENT_CANDIDATE';Mode=$Mode;ReadyForPrepare=$true;CandidateExists=$exists;CandidatePath=$target;PlanId=$a.plan_id;PlanVersion=$a.plan_version;TargetCount=$network.TargetCount;CanApplyGpo=$false;AdChanged=$false;GpoChanged=$false;EndpointChanged=$false;ArtifactExecuted=$false;PrivateKeyOpened=$false}
  }
  if($Mode -cnotin @('Prepare','Verify')){throw 'DEPLOYMENT_MODE_REJECTED'}
  if($exists){$result=Test-AuthWirePreparedCandidate $target $a $receipt.Bytes $receipt.Hash;$result|Add-Member NoteProperty PreparedNow $false;return $result}
  if($Mode -ceq 'Verify'){throw 'DEPLOYMENT_CANDIDATE_MISSING'}
 }finally{$cert.Dispose()}
 $cert=Get-AuthWireCandidateSigner $a -OpenPrivateKey;$temporary=$null
 try{
  if(-not (Test-Path -LiteralPath $parent)){$null=New-Item -ItemType Directory -Path $parent;Set-AuthWireCandidateAcl $parent $a.service_sid -Directory}
  Assert-AuthWireCandidateAcl $parent $a.service_sid -Directory
  $temporary=Join-Path $parent ('.preparing-'+[guid]::NewGuid().ToString('N'))
  $null=New-Item -ItemType Directory -Path $temporary;Set-AuthWireCandidateAcl $temporary $a.service_sid -Directory
  foreach($name in @('network-profiles.zip','approval.json','AuthWire-Candidate-Manifest.ps1')){
   $path=Join-Path $temporary $name
   $bytes=switch($name){'network-profiles.zip'{$network.Bytes};'approval.json'{$receipt.Bytes};default{[Text.UTF8Encoding]::new($false).GetBytes((Get-AuthWireCandidateManifestText $a $receipt.Hash))}}
   [IO.File]::WriteAllBytes($path,[byte[]]$bytes);Set-AuthWireCandidateAcl $path $a.service_sid
  }
  $signed=Set-AuthenticodeSignature -LiteralPath (Join-Path $temporary 'AuthWire-Candidate-Manifest.ps1') -Certificate $cert -HashAlgorithm SHA256
  if($signed.Status.ToString() -cne 'Valid' -or $signed.SignerCertificate.Thumbprint -cne $a.publisher_thumbprint){throw 'DEPLOYMENT_SIGNING_FAILED'}
  $null=Test-AuthWirePreparedCandidate $temporary $a $receipt.Bytes $receipt.Hash
  [IO.Directory]::Move($temporary,$target);$temporary=$null
  $result=Test-AuthWirePreparedCandidate $target $a $receipt.Bytes $receipt.Hash
  $result|Add-Member NoteProperty PreparedNow $true;return $result
 }finally{
  $cert.Dispose()
  if($temporary -and (Test-Path -LiteralPath $temporary)){Remove-Item -LiteralPath $temporary -Recurse -Force}
 }
}

Invoke-AuthWireDeploymentCandidate -Mode $Mode -NetworkProfileZip $NetworkProfileZip -ApprovalPath $ApprovalPath -ExpectedApprovalSha256 $ExpectedApprovalSha256 | ConvertTo-Json -Depth 5
