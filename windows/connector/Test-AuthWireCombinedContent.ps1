#Requires -Version 5.1
# Public-only combined verifier. No signer acquisition, elevation, signing or writes.
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
function Read-AuthWireCombinedDraft([string]$Path,[string]$ExpectedHash) {
 Initialize-AuthWireCandidateTypes
 if($ExpectedHash -cnotmatch '\A[0-9a-f]{64}\z'){throw 'COMBINED_DRAFT_PIN_REQUIRED'}
 $raw=Read-AuthWireCandidateBytes $Path 1048576
 if((Get-AuthWireCandidateHash $raw) -cne $ExpectedHash){throw 'COMBINED_DRAFT_CHANGED'}
 $allowed=@('README.txt','bundle-manifest.json','network-profiles.zip','network/README.txt','network/WiFi-EAP-TLS.xml','network/Wired-EAP-TLS.xml','network/issuer-ca.pem','network/manifest.json','network/plan.json','network/root-ca.pem','enrollment/AuthWire-Client.ps1','enrollment/Install-AuthWire.ps1','enrollment/README.txt','enrollment/SHA256SUMS.txt','enrollment/config.json','enrollment/https-trust.pem','enrollment/issuer-ca.pem','enrollment/root-ca.pem')
 $memory=[IO.MemoryStream]::new($raw,$false);$zip=$null;$files=@{};$total=0
 try {
  $zip=[IO.Compression.ZipArchive]::new($memory,[IO.Compression.ZipArchiveMode]::Read,$false)
  if($zip.Entries.Count -ne $allowed.Count){throw 'COMBINED_FILE_SET_REJECTED'}
  foreach($entry in $zip.Entries){
   if($entry.FullName -cnotin $allowed -or $files.ContainsKey($entry.FullName) -or $entry.Length -gt 262144 -or (($entry.ExternalAttributes -shr 16) -band 0xf000) -eq 0xa000){throw 'COMBINED_FILE_SET_REJECTED'}
   $total+=$entry.Length;if($total -gt 1048576){throw 'COMBINED_CONTENT_LIMIT'}
   $stream=$entry.Open();$out=[IO.MemoryStream]::new()
   try {
    [byte[]]$buffer=New-Object byte[] 4096
    while(($n=$stream.Read($buffer,0,$buffer.Length)) -gt 0){$out.Write($buffer,0,$n);if($out.Length -gt 262144){throw 'COMBINED_CONTENT_LIMIT'}}
    if($out.Length -ne $entry.Length){throw 'COMBINED_CONTENT_LIMIT'}
    $files[$entry.FullName]=$out.ToArray()
   }finally{$stream.Dispose();$out.Dispose()}
  }
 }finally{if($zip){$zip.Dispose()};$memory.Dispose()}
 $m=ConvertFrom-AuthWireCandidateJson $files['bundle-manifest.json']
 Assert-AuthWireCandidateFields $m @('format','plan_id','plan_version','machine_profile_id','machine_profile_version','network_zip_sha256','source_preview_sha256','requires_windows_signing','certificate_service_runtime_tested','can_stage','can_apply','runtime_applied','gpo_changed','files')
 Assert-AuthWireCandidateFields $m.files @($allowed|Where-Object{$_ -cne 'bundle-manifest.json'})
 foreach($f in $m.files.PSObject.Properties){if($f.Value -isnot [string] -or $f.Value -cnotmatch '\A[0-9a-f]{64}\z' -or (Get-AuthWireCandidateHash $files[$f.Name]) -cne $f.Value){throw 'COMBINED_CONTENT_CHANGED'}}
 if($m.format -cne 'AuthWireMachineDeploymentDraftV1' -or $m.requires_windows_signing -isnot [bool] -or -not $m.requires_windows_signing){throw 'COMBINED_FORMAT_REJECTED'}
 foreach($n in @('can_stage','can_apply','runtime_applied','gpo_changed','certificate_service_runtime_tested')){if($m.$n -isnot [bool] -or $m.$n){throw 'COMBINED_NOT_AN_UNSIGNED_DRAFT'}}
 foreach($n in @('plan_id','machine_profile_id')){Assert-AuthWireCandidateGuid $m.$n}
 foreach($n in @('plan_version','machine_profile_version')){if($m.$n -isnot [int] -or $m.$n -lt 1){throw 'COMBINED_VERSION_REJECTED'}}
 foreach($n in @('network_zip_sha256','source_preview_sha256')){if($m.$n -cnotmatch '\A[0-9a-f]{64}\z'){throw 'COMBINED_PIN_REJECTED'}}
 if((Get-AuthWireCandidateHash $files['network-profiles.zip']) -cne $m.network_zip_sha256){throw 'COMBINED_NETWORK_CHANGED'}
 $cfg=ConvertFrom-AuthWireCandidateJson $files['enrollment/config.json']
 Assert-AuthWireCandidateFields $cfg @('url','spn','domain','profile_id','tls_sha256')
 if($cfg.profile_id -cne $m.machine_profile_id -or $cfg.url -cnotmatch '\Ahttps://[a-z0-9.-]+:[1-9][0-9]{0,4}\z' -or $cfg.tls_sha256 -cnotmatch '\A[0-9a-f]{64}\z'){throw 'COMBINED_CONFIG_REJECTED'}
 return [pscustomobject]@{Raw=$raw;Files=$files;Manifest=$m;Hash=$ExpectedHash}
}
function Get-AuthWireCombinedBody([byte[]]$Bytes,[switch]$Signed){
 $text=[Text.UTF8Encoding]::new($false,$true).GetString($Bytes).TrimStart([char]0xfeff)
 if($Signed){$parts=$text -split '(?m)^# SIG # Begin signature block\r?$',2;if($parts.Count -ne 2){throw 'COMBINED_SIGNATURE_BLOCK_REQUIRED'};$text=$parts[0]}
 return ($text.Replace("`r`n","`n").TrimEnd([char[]]"`r`n")+"`n")
}
function New-AuthWireCombinedInstaller([byte[]]$Template,[string]$ExpectedHash,[hashtable]$Files){
 if($ExpectedHash -cnotmatch '\A[0-9a-f]{64}\z' -or (Get-AuthWireCandidateHash $Template) -cne $ExpectedHash){throw 'COMBINED_INSTALLER_TEMPLATE_CHANGED'}
 $text=[Text.UTF8Encoding]::new($false,$true).GetString($Template)
 if([regex]::Matches($text,'__AUTHWIRE_ASSET_HASHES__').Count -ne 1 -or $text.Contains('# SIG # Begin signature block')){throw 'COMBINED_INSTALLER_TEMPLATE_REJECTED'}
 $assets=[ordered]@{}
 foreach($name in @('config.json','https-trust.pem','issuer-ca.pem','root-ca.pem')){$assets[$name]=Get-AuthWireCandidateHash $Files['enrollment/'+$name]}
 return ,([Text.UTF8Encoding]::new($false).GetBytes($text.Replace('__AUTHWIRE_ASSET_HASHES__',($assets|ConvertTo-Json -Compress))))
}
function Test-AuthWireCombinedScript([string]$Path,[byte[]]$Expected,[string]$Publisher){
 $raw=Read-AuthWireCandidateBytes $Path 262144
 if((Get-AuthWireCombinedBody $raw -Signed) -cne (Get-AuthWireCombinedBody $Expected)){throw 'COMBINED_SIGNED_BODY_CHANGED'}
 $sig=Get-AuthenticodeSignature -LiteralPath $Path
 if($sig.Status.ToString() -cne 'Valid' -or $null -eq $sig.SignerCertificate -or $sig.SignerCertificate.Thumbprint -cne $Publisher -or $sig.SignatureType.ToString() -cne 'Authenticode'){throw 'COMBINED_SIGNATURE_REJECTED'}
 $t=$null;$e=$null;$null=[Management.Automation.Language.Parser]::ParseFile($Path,[ref]$t,[ref]$e)
 if($e.Count){throw 'COMBINED_SCRIPT_SYNTAX_REJECTED'}
}
function Get-AuthWireCombinedManifestBody([byte[]]$Json){
 return [Text.UTF8Encoding]::new($false).GetBytes("# AuthWireCombinedCandidateV1`r`n# Manifest-Base64: "+[Convert]::ToBase64String($Json)+"`r`n")
}
function Test-AuthWireCombinedPrepared([string]$Path,$Draft,[byte[]]$Installer,[string]$TemplateHash,[string]$Publisher,[string]$ServiceSid){
 Assert-AuthWireCandidateAcl $Path $ServiceSid -Directory
 foreach($d in @('enrollment','network')){Assert-AuthWireCandidateAcl (Join-Path $Path $d) $ServiceSid -Directory}
 $all=@(Get-ChildItem -LiteralPath $Path -Force)
 foreach($entry in $all){if($entry.PSIsContainer -and ($entry.Name -cnotin @('enrollment','network') -or ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint))){throw 'COMBINED_EXTRA_DIRECTORY'}}
 $all+=@(Get-ChildItem -LiteralPath (Join-Path $Path 'enrollment') -Force)
 $all+=@(Get-ChildItem -LiteralPath (Join-Path $Path 'network') -Force)
 $actual=@{};foreach($entry in $all){
  if($entry.Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'COMBINED_REPARSE_REJECTED'}
  if($entry.PSIsContainer){if($entry.FullName -cnotin @((Join-Path $Path 'enrollment'),(Join-Path $Path 'network'))){throw 'COMBINED_EXTRA_DIRECTORY'};continue}
  Assert-AuthWireCandidateAcl $entry.FullName $ServiceSid
  $relative=$entry.FullName.Substring($Path.Length+1).Replace('\','/');$actual[$relative]=Read-AuthWireCandidateBytes $entry.FullName 1048576
 }
 $names=@($Draft.Files.Keys|Where-Object{$_ -cne 'bundle-manifest.json'})+@('original-draft.zip','signed-manifest.json','AuthWire-Combined-Manifest.ps1')
 if($actual.Count -ne $names.Count -or @($actual.Keys|Where-Object{$_ -cnotin $names}).Count){throw 'COMBINED_PREPARED_FILE_SET'}
 $json=$actual['signed-manifest.json'];$m=ConvertFrom-AuthWireCandidateJson $json
 Assert-AuthWireCandidateFields $m @('format','draft_sha256','plan_id','plan_version','installer_template_sha256','publisher_thumbprint','installer_template_updated','can_stage','can_apply','runtime_applied','files')
 Assert-AuthWireCandidateFields $m.files @($names|Where-Object{$_ -cnotin @('signed-manifest.json','AuthWire-Combined-Manifest.ps1')})
 if($m.format -cne 'AuthWireCombinedSignedPreparationV1' -or $m.draft_sha256 -cne $Draft.Hash -or $m.installer_template_sha256 -cne $TemplateHash -or $m.publisher_thumbprint -cne $Publisher -or $m.plan_id -cne $Draft.Manifest.plan_id -or $m.plan_version -ne $Draft.Manifest.plan_version -or $m.installer_template_updated -isnot [bool] -or -not $m.installer_template_updated){throw 'COMBINED_PREPARED_METADATA'}
 foreach($n in @('can_stage','can_apply','runtime_applied')){if($m.$n -isnot [bool] -or $m.$n){throw 'COMBINED_PREPARED_NOT_APPLICABLE'}}
 foreach($f in $m.files.PSObject.Properties){if((Get-AuthWireCandidateHash $actual[$f.Name]) -cne $f.Value){throw 'COMBINED_PREPARED_CONTENT_CHANGED'}}
 if((Get-AuthWireCandidateHash $actual['original-draft.zip']) -cne $Draft.Hash){throw 'COMBINED_ORIGINAL_CHANGED'}
 foreach($n in $Draft.Files.Keys){if($n -cnotin @('bundle-manifest.json','README.txt','enrollment/AuthWire-Client.ps1','enrollment/Install-AuthWire.ps1','enrollment/SHA256SUMS.txt')){if((Get-AuthWireCandidateHash $actual[$n]) -cne (Get-AuthWireCandidateHash $Draft.Files[$n])){throw 'COMBINED_UNEXPECTED_ASSET_CHANGE'}}}
 $sumNames=@($actual.Keys|Where-Object{$_ -clike 'enrollment/*' -and $_ -cne 'enrollment/SHA256SUMS.txt'}|Sort-Object)
 $sums=@($sumNames|ForEach-Object{(Get-AuthWireCandidateHash $actual[$_])+'  '+$_.Substring(11)}) -join "`n"
 if([Text.Encoding]::ASCII.GetString($actual['enrollment/SHA256SUMS.txt']) -cne $sums){throw 'COMBINED_CHECKSUM_LIST_CHANGED'}
 Test-AuthWireCombinedScript (Join-Path $Path 'enrollment/AuthWire-Client.ps1') $Draft.Files['enrollment/AuthWire-Client.ps1'] $Publisher
 Test-AuthWireCombinedScript (Join-Path $Path 'enrollment/Install-AuthWire.ps1') $Installer $Publisher
 Test-AuthWireCombinedScript (Join-Path $Path 'AuthWire-Combined-Manifest.ps1') (Get-AuthWireCombinedManifestBody $json) $Publisher
 $t=$null;$e=$null;$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $Path 'AuthWire-Combined-Manifest.ps1'),[ref]$t,[ref]$e)
 if($ast.ParamBlock -or $ast.BeginBlock -or $ast.ProcessBlock -or $ast.DynamicParamBlock -or ($ast.EndBlock -and $ast.EndBlock.Statements.Count)){throw 'COMBINED_EXECUTABLE_MANIFEST_REJECTED'}
 return [pscustomobject]@{Event='WINDOWS_COMBINED_CANDIDATE_PREPARED';CandidatePath=$Path;PlanId=$Draft.Manifest.plan_id;PlanVersion=$Draft.Manifest.plan_version;DraftSha256=$Draft.Hash;ManifestSha256=(Get-AuthWireCandidateHash $json);PublisherThumbprint=$Publisher;SignaturesVerified=3;InstallerTemplateUpdated=$true;CanStage=$false;CanApplyGpo=$false;ArtifactExecuted=$false;AdChanged=$false;GpoChanged=$false;EndpointChanged=$false;ServicesChanged=$false;KeyAclChanged=$false;TrustStoreChanged=$false;SecretsExported=$false}
}

function Get-AuthWireCombinedReadonlyTemplate {
 return ,([Convert]::FromBase64String('IyBTaWduIHdpdGggZW50ZXJwcmlzZSBBdXRoZW50aWNvZGUuIERlcGxveSBvbmNlIGFzIGNvbXB1dGVyIHN0YXJ0dXAgdmlhIEdQTy4KcGFyYW0oW3N3aXRjaF0kUnVuQ2xpZW50LCBbc3dpdGNoXSRSZXRyeUNoZWNrKQokRXJyb3JBY3Rpb25QcmVmZXJlbmNlID0gJ1N0b3AnCmlmIChbU2VjdXJpdHkuUHJpbmNpcGFsLldpbmRvd3NJZGVudGl0eV06OkdldEN1cnJlbnQoKS5Vc2VyLlZhbHVlIC1uZSAnUy0xLTUtMTgnKSB7IHRocm93ICdBdXRoV2lyZSBpbnN0YWxsYXRpb24gcmVxdWlyZXMgU1lTVEVNLicgfQokcHVibGlzaGVyID0gJG51bGwKZm9yZWFjaCgkbmFtZSBpbiBAKCdJbnN0YWxsLUF1dGhXaXJlLnBzMScsJ0F1dGhXaXJlLUNsaWVudC5wczEnKSkgewogICAgJHNpZ25hdHVyZSA9IEdldC1BdXRoZW50aWNvZGVTaWduYXR1cmUgKEpvaW4tUGF0aCAkUFNTY3JpcHRSb290ICRuYW1lKQogICAgaWYoJHNpZ25hdHVyZS5TdGF0dXMgLW5lICdWYWxpZCcpIHsgdGhyb3cgJ0F1dGhXaXJlIHJlcXVpcmVzIHZhbGlkIGVudGVycHJpc2UgQXV0aGVudGljb2RlIHNpZ25hdHVyZXMuJyB9CiAgICBpZighJHB1Ymxpc2hlcikgeyAkcHVibGlzaGVyID0gJHNpZ25hdHVyZS5TaWduZXJDZXJ0aWZpY2F0ZS5UaHVtYnByaW50IH0KICAgIGlmKCRzaWduYXR1cmUuU2lnbmVyQ2VydGlmaWNhdGUuVGh1bWJwcmludCAtbmUgJHB1Ymxpc2hlcikgeyB0aHJvdyAnQXV0aFdpcmUgc2NyaXB0cyBtdXN0IHVzZSB0aGUgc2FtZSB0cnVzdGVkIHB1Ymxpc2hlci4nIH0KfQojIFBhY2thZ2UgZ2VuZXJhdGlvbiBlbWJlZHMgdGhlc2UgaGFzaGVzIEJFRk9SRSB0aGUgb3BlcmF0b3Igc2lnbnMgdGhpcyBmaWxlLgojIFRodXMgdGhlIEF1dGhlbnRpY29kZSBzaWduYXR1cmUgY292ZXJzIHRoZSBjb25maWcgYW5kIHB1YmxpYyB0cnVzdCBhc3NldHMgdG9vLgokZXhwZWN0ZWRBc3NldHMgPSBAJwpfX0FVVEhXSVJFX0FTU0VUX0hBU0hFU19fCidAIHwgQ29udmVydEZyb20tSnNvbgokdmVyaWZpZWRBc3NldHMgPSBAe30KZm9yZWFjaCgkYXNzZXQgaW4gJGV4cGVjdGVkQXNzZXRzLlBTT2JqZWN0LlByb3BlcnRpZXMpIHsKICAgIGlmKCRhc3NldC5OYW1lIC1ub3RpbiBAKCdjb25maWcuanNvbicsJ3Jvb3QtY2EucGVtJywnaXNzdWVyLWNhLnBlbScsJ2h0dHBzLXRydXN0LnBlbScpKSB7IHRocm93ICdVbmV4cGVjdGVkIEF1dGhXaXJlIGFzc2V0LicgfQogICAgJGFzc2V0RmlsZSA9IEpvaW4tUGF0aCAkUFNTY3JpcHRSb290ICRhc3NldC5OYW1lCiAgICBpZigoR2V0LUl0ZW0gJGFzc2V0RmlsZSkuQXR0cmlidXRlcyAtYmFuZCBbSU8uRmlsZUF0dHJpYnV0ZXNdOjpSZXBhcnNlUG9pbnQpIHsgdGhyb3cgJ0F1dGhXaXJlIGFzc2V0IHJlcGFyc2UgcG9pbnQgcmVmdXNlZC4nIH0KICAgICRieXRlcyA9IFtJTy5GaWxlXTo6UmVhZEFsbEJ5dGVzKCRhc3NldEZpbGUpCiAgICAkaGFzaCA9IFtTZWN1cml0eS5DcnlwdG9ncmFwaHkuU0hBMjU2XTo6Q3JlYXRlKCkKICAgIHRyeSB7ICRhY3R1YWwgPSBbQml0Q29udmVydGVyXTo6VG9TdHJpbmcoJGhhc2guQ29tcHV0ZUhhc2goJGJ5dGVzKSkuUmVwbGFjZSgnLScsJycpIH0gZmluYWxseSB7ICRoYXNoLkRpc3Bvc2UoKSB9CiAgICBpZigkYWN0dWFsIC1pbmUgJGFzc2V0LlZhbHVlKSB7IHRocm93ICdBdXRoV2lyZSBjb25maWcvdHJ1c3QgYXNzZXQgd2FzIG1vZGlmaWVkIGFmdGVyIHNpZ25pbmcuJyB9CiAgICAkdmVyaWZpZWRBc3NldHNbJGFzc2V0Lk5hbWVdID0gJGJ5dGVzCn0KJHRhcmdldCA9IEpvaW4tUGF0aCAkZW52OlByb2dyYW1EYXRhICdBdXRoV2lyZScKZnVuY3Rpb24gUmVhZC1BdXRoV2lyZVJldHJ5RGVhZGxpbmUoW3N0cmluZ10kRGlyZWN0b3J5KSB7CiAgICAkcGF0aCA9IEpvaW4tUGF0aCAkRGlyZWN0b3J5ICdyZXRyeS5qc29uJwogICAgaWYoIShUZXN0LVBhdGggLUxpdGVyYWxQYXRoICRwYXRoKSkgeyByZXR1cm4gJG51bGwgfQogICAgaWYoKEdldC1JdGVtIC1MaXRlcmFsUGF0aCAkcGF0aCkuQXR0cmlidXRlcyAtYmFuZCBbSU8uRmlsZUF0dHJpYnV0ZXNdOjpSZXBhcnNlUG9pbnQpIHsgdGhyb3cgJ0F1dGhXaXJlIHJldHJ5IHJlcGFyc2UgcG9pbnQgcmVmdXNlZC4nIH0KICAgICRyZXRyeSA9IEdldC1Db250ZW50IC1MaXRlcmFsUGF0aCAkcGF0aCAtUmF3IHwgQ29udmVydEZyb20tSnNvbgogICAgJGRlYWRsaW5lID0gW0RhdGVUaW1lT2Zmc2V0XTo6UGFyc2UoW3N0cmluZ10kcmV0cnkubmV4dF9hdHRlbXB0KQogICAgaWYoJGRlYWRsaW5lIC1ndCBbRGF0ZVRpbWVPZmZzZXRdOjpVdGNOb3cuQWRkSG91cnMoMTMpKSB7IHRocm93ICdBdXRoV2lyZSByZXRyeSBkZWFkbGluZSBvdXRzaWRlIGJvdW5kZWQgYmFja29mZi4nIH0KICAgIHJldHVybiAkZGVhZGxpbmUKfQpmdW5jdGlvbiBTZXQtQXV0aFdpcmVSZXRyeVRhc2soW3N0cmluZ10kRGlyZWN0b3J5LCBbc3RyaW5nXSRUYXNrTmFtZSwgW0RhdGVUaW1lT2Zmc2V0XSRXaGVuKSB7CiAgICAkc2NyaXB0RmlsZSA9IEpvaW4tUGF0aCAkRGlyZWN0b3J5ICdJbnN0YWxsLUF1dGhXaXJlLnBzMScKICAgICRyZXRyeUFjdGlvbiA9IE5ldy1TY2hlZHVsZWRUYXNrQWN0aW9uIC1FeGVjdXRlICIkZW52OlN5c3RlbVJvb3RcU3lzdGVtMzJcV2luZG93c1Bvd2VyU2hlbGxcdjEuMFxwb3dlcnNoZWxsLmV4ZSIgLUFyZ3VtZW50ICgnLU5vUHJvZmlsZSAtTm9uSW50ZXJhY3RpdmUgLUV4ZWN1dGlvblBvbGljeSBBbGxTaWduZWQgLUZpbGUgIicrJHNjcmlwdEZpbGUrJyIgLVJldHJ5Q2hlY2snKQogICAgJHJldHJ5U2V0dGluZ3MgPSBOZXctU2NoZWR1bGVkVGFza1NldHRpbmdzU2V0IC1TdGFydFdoZW5BdmFpbGFibGUgLVJ1bk9ubHlJZk5ldHdvcmtBdmFpbGFibGUgLUFsbG93U3RhcnRJZk9uQmF0dGVyaWVzIC1Eb250U3RvcElmR29pbmdPbkJhdHRlcmllcyAtTXVsdGlwbGVJbnN0YW5jZXMgSWdub3JlTmV3IC1FeGVjdXRpb25UaW1lTGltaXQgKE5ldy1UaW1lU3BhbiAtTWludXRlcyAyKQogICAgJHJldHJ5UHJpbmNpcGFsID0gTmV3LVNjaGVkdWxlZFRhc2tQcmluY2lwYWwgLVVzZXJJZCAnU1lTVEVNJyAtTG9nb25UeXBlIFNlcnZpY2VBY2NvdW50IC1SdW5MZXZlbCBIaWdoZXN0CiAgICAkZGVzY3JpcHRpb24gPSAnQXV0aFdpcmUgbWFuYWdlZCBlbnJvbGxtZW50IHJldHJ5IGRlYWRsaW5lJwogICAgJGV4aXN0aW5nUmV0cnkgPSBHZXQtU2NoZWR1bGVkVGFzayAtVGFza05hbWUgJFRhc2tOYW1lIC1FcnJvckFjdGlvbiBTaWxlbnRseUNvbnRpbnVlCiAgICBpZigkZXhpc3RpbmdSZXRyeSAtYW5kICgkZXhpc3RpbmdSZXRyeS5EZXNjcmlwdGlvbiAtbmUgJGRlc2NyaXB0aW9uIC1vciAkZXhpc3RpbmdSZXRyeS5QcmluY2lwYWwuVXNlcklkIC1ub3RpbiBAKCdTWVNURU0nLCdOVCBBVVRIT1JJVFlcU1lTVEVNJywnUy0xLTUtMTgnKSkpIHsgdGhyb3cgJ1VuZXhwZWN0ZWQgZXhpc3RpbmcgQXV0aFdpcmUgcmV0cnkgdGFzay4nIH0KICAgICMgU3RhcnRCb3VuZGFyeSB1c2VzIHdob2xlLXNlY29uZCBwcmVjaXNpb24uIERvIG5vdCB0cnVuY2F0ZSBhIGZyYWN0aW9uYWwKICAgICMgZGVhZGxpbmUgaW50byBhbiBlYXJseSBydW4gb3IgcmUtcmVnaXN0ZXIgYW4gYWxyZWFkeSBlbGFwc2VkIHRyaWdnZXIuCiAgICAjIGh0dHBzOi8vbGVhcm4ubWljcm9zb2Z0LmNvbS9lbi11cy93aW5kb3dzL3dpbjMyL3Rhc2tzY2hkL3RyaWdnZXItc3RhcnRib3VuZGFyeQogICAgJGVhcmxpZXN0ID0gW0RhdGVUaW1lT2Zmc2V0XTo6VXRjTm93LkFkZFNlY29uZHMoNSkKICAgICRzY2hlZHVsZWQgPSBpZigkV2hlbiAtZ3QgJGVhcmxpZXN0KSB7ICRXaGVuLlV0Y0RhdGVUaW1lIH0gZWxzZSB7ICRlYXJsaWVzdC5VdGNEYXRlVGltZSB9CiAgICAkZnJhY3Rpb24gPSAkc2NoZWR1bGVkLlRpY2tzICUgW1RpbWVTcGFuXTo6VGlja3NQZXJTZWNvbmQKICAgIGlmKCRmcmFjdGlvbiAtbmUgMCkgeyAkc2NoZWR1bGVkID0gJHNjaGVkdWxlZC5BZGRUaWNrcyhbVGltZVNwYW5dOjpUaWNrc1BlclNlY29uZCAtICRmcmFjdGlvbikgfQogICAgJHJldHJ5VHJpZ2dlciA9IE5ldy1TY2hlZHVsZWRUYXNrVHJpZ2dlciAtT25jZSAtQXQgJHNjaGVkdWxlZC5Ub0xvY2FsVGltZSgpCiAgICAkbnVsbCA9IFJlZ2lzdGVyLVNjaGVkdWxlZFRhc2sgLVRhc2tOYW1lICRUYXNrTmFtZSAtQWN0aW9uICRyZXRyeUFjdGlvbiAtVHJpZ2dlciAkcmV0cnlUcmlnZ2VyIC1TZXR0aW5ncyAkcmV0cnlTZXR0aW5ncyAtUHJpbmNpcGFsICRyZXRyeVByaW5jaXBhbCAtRGVzY3JpcHRpb24gJGRlc2NyaXB0aW9uIC1Gb3JjZQogICAgIyBSZXN0cmljdCB0aGUgdGFzayBkZWZpbml0aW9uIGl0c2VsZiwgYXMgd2VsbCBhcyB0aGUgcHJpdmF0ZSBzaWduZWQgZmlsZXMuCiAgICAkc2NoZWR1bGVyID0gTmV3LU9iamVjdCAtQ29tT2JqZWN0ICdTY2hlZHVsZS5TZXJ2aWNlJwogICAgJHNjaGVkdWxlci5Db25uZWN0KCkKICAgICRyZWdpc3RlcmVkID0gJHNjaGVkdWxlci5HZXRGb2xkZXIoJ1wnKS5HZXRUYXNrKCRUYXNrTmFtZSkKICAgICRyZWdpc3RlcmVkLlNldFNlY3VyaXR5RGVzY3JpcHRvcignRDpQKEE7O0dBOzs7U1kpKEE7O0dBOzs7QkEpJywwKQp9CmZ1bmN0aW9uIEludm9rZS1BdXRoV2lyZVJldHJ5Q2hlY2soW3N0cmluZ10kRGlyZWN0b3J5LCBbc3RyaW5nXSRNYWluVGFza05hbWUsIFtzdHJpbmddJFJldHJ5VGFza05hbWUpIHsKICAgICRkZWFkbGluZSA9IFJlYWQtQXV0aFdpcmVSZXRyeURlYWRsaW5lICREaXJlY3RvcnkKICAgIGlmKCEkZGVhZGxpbmUpIHsgcmV0dXJuICdub3RoaW5nX3BlbmRpbmcnIH0KICAgIGlmKFtEYXRlVGltZU9mZnNldF06OlV0Y05vdyAtbHQgJGRlYWRsaW5lKSB7CiAgICAgICAgU2V0LUF1dGhXaXJlUmV0cnlUYXNrICREaXJlY3RvcnkgJFJldHJ5VGFza05hbWUgJGRlYWRsaW5lCiAgICAgICAgcmV0dXJuICdkZWFkbGluZV9yZWFybWVkJwogICAgfQogICAgJG1haW4gPSBHZXQtU2NoZWR1bGVkVGFzayAtVGFza05hbWUgJE1haW5UYXNrTmFtZSAtRXJyb3JBY3Rpb24gU3RvcAogICAgaWYoJG1haW4uU3RhdGUgLWluIEAoJ1J1bm5pbmcnLCdRdWV1ZWQnKSkgeyByZXR1cm4gJ2FscmVhZHlfcGVuZGluZycgfQogICAgU3RhcnQtU2NoZWR1bGVkVGFzayAtVGFza05hbWUgJE1haW5UYXNrTmFtZSAtRXJyb3JBY3Rpb24gU3RvcAogICAgcmV0dXJuICdyZXRyeV9yZXF1ZXN0ZWQnCn0KZnVuY3Rpb24gQ29tcGxldGUtQXV0aFdpcmVSZWNvdmVyeVN0YXR1cyhbc3RyaW5nXSREaXJlY3RvcnkpIHsKICAgIGlmKFRlc3QtUGF0aCAtTGl0ZXJhbFBhdGggKEpvaW4tUGF0aCAkRGlyZWN0b3J5ICdyZXRyeS5qc29uJykpIHsgcmV0dXJuIH0KICAgICRzdGF0dXNGaWxlID0gSm9pbi1QYXRoICREaXJlY3RvcnkgJ3N0YXR1cy5qc29uJwogICAgJGluc3RhbGxlZEZpbGUgPSBKb2luLVBhdGggJERpcmVjdG9yeSAnaW5zdGFsbGVkLmpzb24nCiAgICBpZighKFRlc3QtUGF0aCAtTGl0ZXJhbFBhdGggJHN0YXR1c0ZpbGUpIC1vciAhKFRlc3QtUGF0aCAtTGl0ZXJhbFBhdGggJGluc3RhbGxlZEZpbGUpKSB7IHJldHVybiB9CiAgICBmb3JlYWNoKCRwYXRoIGluIEAoJHN0YXR1c0ZpbGUsJGluc3RhbGxlZEZpbGUpKSB7CiAgICAgICAgaWYoKEdldC1JdGVtIC1MaXRlcmFsUGF0aCAkcGF0aCkuQXR0cmlidXRlcyAtYmFuZCBbSU8uRmlsZUF0dHJpYnV0ZXNdOjpSZXBhcnNlUG9pbnQpIHsgdGhyb3cgJ0F1dGhXaXJlIHN0YXRlIHJlcGFyc2UgcG9pbnQgcmVmdXNlZC4nIH0KICAgIH0KICAgICRvbGRTdGF0dXMgPSBHZXQtQ29udGVudCAtTGl0ZXJhbFBhdGggJHN0YXR1c0ZpbGUgLVJhdyB8IENvbnZlcnRGcm9tLUpzb24KICAgIGlmKCRvbGRTdGF0dXMuc3RhdGUgLW5lICdyZXRyeV9wZW5kaW5nJykgeyByZXR1cm4gfQogICAgJGluc3RhbGxlZFN0YXRlID0gR2V0LUNvbnRlbnQgLUxpdGVyYWxQYXRoICRpbnN0YWxsZWRGaWxlIC1SYXcgfCBDb252ZXJ0RnJvbS1Kc29uCiAgICBpZigkaW5zdGFsbGVkU3RhdGUudGh1bWJwcmludCAtbm90bWF0Y2ggJ15bQS1GYS1mMC05XXs0MH0kJyAtb3IgJGluc3RhbGxlZFN0YXRlLnNlcmlhbCAtbm90bWF0Y2ggJ15bQS1GYS1mMC05XSskJykgeyB0aHJvdyAnSW52YWxpZCBBdXRoV2lyZSBpbnN0YWxsZWQgaWRlbnRpdHkuJyB9CiAgICAkbGVhZiA9IEdldC1JdGVtICgnQ2VydDpcTG9jYWxNYWNoaW5lXE15XCcrJGluc3RhbGxlZFN0YXRlLnRodW1icHJpbnQpIC1FcnJvckFjdGlvbiBTdG9wCiAgICBpZighJGxlYWYuSGFzUHJpdmF0ZUtleSAtb3IgJGxlYWYuTm90QmVmb3JlIC1ndCAoR2V0LURhdGUpIC1vciAkbGVhZi5Ob3RBZnRlciAtbGUgKEdldC1EYXRlKSkgeyB0aHJvdyAnQXV0aFdpcmUgY3VycmVudCBjZXJ0aWZpY2F0ZSB1bmF2YWlsYWJsZS4nIH0KICAgICMgVGhpcyBpcyBhIHN1Y2Nlc3NmdWwgcmVjZWlwdCBjaGVjaywgbm90IGEgbmV3IGNlcnRpZmljYXRlIGlzc3VhbmNlIGRhdGUuCiAgICAkcmVjb3ZlcmVkID0gQHtzdGF0ZT0naW5zdGFsbGVkJztzZXJpYWw9JGluc3RhbGxlZFN0YXRlLnNlcmlhbDtjaGVja2VkX2F0PVtEYXRlVGltZU9mZnNldF06OlV0Y05vdy5Ub1N0cmluZygnbycpO2xhc3RfdmVyaWZpZWQ9W0RhdGVUaW1lT2Zmc2V0XTo6VXRjTm93LlRvU3RyaW5nKCdvJyk7b3BlcmF0aW9uPSdyZW5ld2FsX2NoZWNrJ30KICAgIGlmKCRvbGRTdGF0dXMubGFzdF9zdWNjZXNzKSB7ICRyZWNvdmVyZWRbJ2xhc3Rfc3VjY2VzcyddID0gJG9sZFN0YXR1cy5sYXN0X3N1Y2Nlc3MgfQogICAgJHRlbXBvcmFyeSA9ICRzdGF0dXNGaWxlKycudG1wJwogICAgaWYoKFRlc3QtUGF0aCAtTGl0ZXJhbFBhdGggJHRlbXBvcmFyeSkgLWFuZCAoKEdldC1JdGVtIC1MaXRlcmFsUGF0aCAkdGVtcG9yYXJ5KS5BdHRyaWJ1dGVzIC1iYW5kIFtJTy5GaWxlQXR0cmlidXRlc106OlJlcGFyc2VQb2ludCkpIHsgdGhyb3cgJ0F1dGhXaXJlIHRlbXBvcmFyeSBzdGF0ZSByZXBhcnNlIHBvaW50IHJlZnVzZWQuJyB9CiAgICBbSU8uRmlsZV06OldyaXRlQWxsVGV4dCgkdGVtcG9yYXJ5LCgkcmVjb3ZlcmVkfENvbnZlcnRUby1Kc29uIC1EZXB0aCA1KSwoTmV3LU9iamVjdCBUZXh0LlVURjhFbmNvZGluZygkZmFsc2UpKSkKICAgIFtJTy5GaWxlXTo6UmVwbGFjZSgkdGVtcG9yYXJ5LCRzdGF0dXNGaWxlLFtOdWxsU3RyaW5nXTo6VmFsdWUpCn0KZnVuY3Rpb24gSW52b2tlLUF1dGhXaXJlRW5yb2xsbWVudENsaWVudChbc3RyaW5nXSREaXJlY3RvcnksIFtzdHJpbmddJFJldHJ5VGFza05hbWUpIHsKICAgICRsYXVuY2hlck11dGV4ID0gTmV3LU9iamVjdCBUaHJlYWRpbmcuTXV0ZXgoJGZhbHNlLCdHbG9iYWxcQXV0aFdpcmUtQ2VydGlmaWNhdGUtTGF1bmNoZXInKQogICAgJGxvY2tlZCA9ICRmYWxzZQogICAgdHJ5IHsKICAgICAgICB0cnkgeyAkbG9ja2VkID0gJGxhdW5jaGVyTXV0ZXguV2FpdE9uZSgwKSB9CiAgICAgICAgY2F0Y2ggW1RocmVhZGluZy5BYmFuZG9uZWRNdXRleEV4Y2VwdGlvbl0geyAkbG9ja2VkID0gJHRydWUgfQogICAgICAgIGlmKCEkbG9ja2VkKSB7IHJldHVybiAwIH0KICAgICAgICAkZGVhZGxpbmUgPSBSZWFkLUF1dGhXaXJlUmV0cnlEZWFkbGluZSAkRGlyZWN0b3J5CiAgICAgICAgaWYoJGRlYWRsaW5lIC1hbmQgW0RhdGVUaW1lT2Zmc2V0XTo6VXRjTm93IC1sdCAkZGVhZGxpbmUpIHsKICAgICAgICAgICAgU2V0LUF1dGhXaXJlUmV0cnlUYXNrICREaXJlY3RvcnkgJFJldHJ5VGFza05hbWUgJGRlYWRsaW5lCiAgICAgICAgICAgIHJldHVybiAwCiAgICAgICAgfQogICAgICAgICRhcmd1bWVudHMgPSAnLU5vUHJvZmlsZSAtTm9uSW50ZXJhY3RpdmUgLUV4ZWN1dGlvblBvbGljeSBBbGxTaWduZWQgLUZpbGUgIicrKEpvaW4tUGF0aCAkRGlyZWN0b3J5ICdBdXRoV2lyZS1DbGllbnQucHMxJykrJyInCiAgICAgICAgJGNoaWxkID0gU3RhcnQtUHJvY2VzcyAtRmlsZVBhdGggIiRlbnY6U3lzdGVtUm9vdFxTeXN0ZW0zMlxXaW5kb3dzUG93ZXJTaGVsbFx2MS4wXHBvd2Vyc2hlbGwuZXhlIiAtQXJndW1lbnRMaXN0ICRhcmd1bWVudHMgLVdpbmRvd1N0eWxlIEhpZGRlbiAtV2FpdCAtUGFzc1RocnUKICAgICAgICAkY2hpbGQuUmVmcmVzaCgpCiAgICAgICAgJHJlc3VsdCA9IFtpbnRdJGNoaWxkLkV4aXRDb2RlCiAgICAgICAgJGRlYWRsaW5lID0gUmVhZC1BdXRoV2lyZVJldHJ5RGVhZGxpbmUgJERpcmVjdG9yeQogICAgICAgIGlmKCRkZWFkbGluZSkgewogICAgICAgICAgICBpZigkZGVhZGxpbmUgLWxlIFtEYXRlVGltZU9mZnNldF06OlV0Y05vdykgeyB0aHJvdyAnQXV0aFdpcmUgY2xpZW50IGRpZCBub3QgYWR2YW5jZSBpdHMgcmV0cnkgZGVhZGxpbmUuJyB9CiAgICAgICAgICAgIFNldC1BdXRoV2lyZVJldHJ5VGFzayAkRGlyZWN0b3J5ICRSZXRyeVRhc2tOYW1lICRkZWFkbGluZQogICAgICAgIH0gZWxzZWlmKCRyZXN1bHQgLWVxIDApIHsKICAgICAgICAgICAgQ29tcGxldGUtQXV0aFdpcmVSZWNvdmVyeVN0YXR1cyAkRGlyZWN0b3J5CiAgICAgICAgfQogICAgICAgIHJldHVybiAkcmVzdWx0CiAgICB9IGZpbmFsbHkgewogICAgICAgIGlmKCRsb2NrZWQpIHsgJGxhdW5jaGVyTXV0ZXguUmVsZWFzZU11dGV4KCkgfQogICAgICAgICRsYXVuY2hlck11dGV4LkRpc3Bvc2UoKQogICAgfQp9CmlmKCRSdW5DbGllbnQgLW9yICRSZXRyeUNoZWNrKSB7CiAgICBpZigkUnVuQ2xpZW50IC1hbmQgJFJldHJ5Q2hlY2spIHsgdGhyb3cgJ0NvbmZsaWN0aW5nIEF1dGhXaXJlIGxhdW5jaGVyIG1vZGVzLicgfQogICAgaWYoW0lPLlBhdGhdOjpHZXRGdWxsUGF0aCgkUFNTY3JpcHRSb290KS5UcmltRW5kKCdcJykgLWluZSBbSU8uUGF0aF06OkdldEZ1bGxQYXRoKCR0YXJnZXQpLlRyaW1FbmQoJ1wnKSkgeyB0aHJvdyAnQXV0aFdpcmUgbGF1bmNoZXIgcmVxdWlyZXMgdGhlIHByaXZhdGUgaW5zdGFsbGVkIGRpcmVjdG9yeS4nIH0KICAgIGlmKChHZXQtSXRlbSAtTGl0ZXJhbFBhdGggJHRhcmdldCkuQXR0cmlidXRlcyAtYmFuZCBbSU8uRmlsZUF0dHJpYnV0ZXNdOjpSZXBhcnNlUG9pbnQpIHsgdGhyb3cgJ0F1dGhXaXJlIHByaXZhdGUgZGlyZWN0b3J5IHJlcGFyc2UgcG9pbnQgcmVmdXNlZC4nIH0KICAgIGlmKCRSZXRyeUNoZWNrKSB7CiAgICAgICAgV3JpdGUtT3V0cHV0ICgnQXV0aFdpcmUgcmV0cnk6ICcrKEludm9rZS1BdXRoV2lyZVJldHJ5Q2hlY2sgJHRhcmdldCAnQXV0aFdpcmUgQ2VydGlmaWNhdGUgRW5yb2xsbWVudCcgJ0F1dGhXaXJlIENlcnRpZmljYXRlIEVucm9sbG1lbnQgUmV0cnknKSkKICAgICAgICBleGl0IDAKICAgIH0KICAgIGV4aXQgKEludm9rZS1BdXRoV2lyZUVucm9sbG1lbnRDbGllbnQgJHRhcmdldCAnQXV0aFdpcmUgQ2VydGlmaWNhdGUgRW5yb2xsbWVudCBSZXRyeScpCn0KaWYoVGVzdC1QYXRoICR0YXJnZXQpIHsKICAgIGlmKChHZXQtSXRlbSAkdGFyZ2V0KS5BdHRyaWJ1dGVzIC1iYW5kIFtJTy5GaWxlQXR0cmlidXRlc106OlJlcGFyc2VQb2ludCkgeyB0aHJvdyAnQXV0aFdpcmUgcmVwYXJzZSBwb2ludCByZWZ1c2VkLicgfQp9IGVsc2UgeyAkbnVsbCA9IE5ldy1JdGVtICR0YXJnZXQgLUl0ZW1UeXBlIERpcmVjdG9yeSB9CiMgUHJpdmF0ZSBjbGllbnQgc3RhdGUvY29uZmlnIGFuZCBwZW5kaW5nIENORyByZXF1ZXN0cyBhcmUgbm90IHVzZXItd3JpdGFibGUuCiRhY2wgPSBOZXctT2JqZWN0IFNlY3VyaXR5LkFjY2Vzc0NvbnRyb2wuRGlyZWN0b3J5U2VjdXJpdHkKJGFjbC5TZXRBY2Nlc3NSdWxlUHJvdGVjdGlvbigkdHJ1ZSwkZmFsc2UpCiRhY2wuU2V0T3duZXIoKE5ldy1PYmplY3QgU2VjdXJpdHkuUHJpbmNpcGFsLlNlY3VyaXR5SWRlbnRpZmllcignUy0xLTUtMzItNTQ0JykpKQpmb3JlYWNoKCRzaWQgaW4gQCgnUy0xLTUtMTgnLCdTLTEtNS0zMi01NDQnKSkgewogICAgJHJ1bGUgPSBOZXctT2JqZWN0IFNlY3VyaXR5LkFjY2Vzc0NvbnRyb2wuRmlsZVN5c3RlbUFjY2Vzc1J1bGUoKE5ldy1PYmplY3QgU2VjdXJpdHkuUHJpbmNpcGFsLlNlY3VyaXR5SWRlbnRpZmllcigkc2lkKSksICdGdWxsQ29udHJvbCcsICdDb250YWluZXJJbmhlcml0LE9iamVjdEluaGVyaXQnLCAnTm9uZScsICdBbGxvdycpCiAgICAkYWNsLkFkZEFjY2Vzc1J1bGUoJHJ1bGUpCn0KU2V0LUFjbCAkdGFyZ2V0ICRhY2wKZm9yZWFjaCgkbmFtZSBpbiBAKCdBdXRoV2lyZS1DbGllbnQucHMxJywnSW5zdGFsbC1BdXRoV2lyZS5wczEnKSArIEAoJHZlcmlmaWVkQXNzZXRzLktleXMpKSB7CiAgICAkZGVzdGluYXRpb24gPSBKb2luLVBhdGggJHRhcmdldCAkbmFtZQogICAgaWYoKFRlc3QtUGF0aCAkZGVzdGluYXRpb24pIC1hbmQgKChHZXQtSXRlbSAkZGVzdGluYXRpb24pLkF0dHJpYnV0ZXMgLWJhbmQgW0lPLkZpbGVBdHRyaWJ1dGVzXTo6UmVwYXJzZVBvaW50KSkgeyB0aHJvdyAnQXV0aFdpcmUgZmlsZSByZXBhcnNlIHBvaW50IHJlZnVzZWQuJyB9CiAgICBpZigkbmFtZSAtaW4gQCgnQXV0aFdpcmUtQ2xpZW50LnBzMScsJ0luc3RhbGwtQXV0aFdpcmUucHMxJykpIHsKICAgICAgICBDb3B5LUl0ZW0gKEpvaW4tUGF0aCAkUFNTY3JpcHRSb290ICRuYW1lKSAkZGVzdGluYXRpb24gLUZvcmNlCiAgICAgICAgJGNvcGllZFNpZ25hdHVyZSA9IEdldC1BdXRoZW50aWNvZGVTaWduYXR1cmUgJGRlc3RpbmF0aW9uCiAgICAgICAgaWYoJGNvcGllZFNpZ25hdHVyZS5TdGF0dXMgLW5lICdWYWxpZCcgLW9yICRjb3BpZWRTaWduYXR1cmUuU2lnbmVyQ2VydGlmaWNhdGUuVGh1bWJwcmludCAtbmUgJHB1Ymxpc2hlcikgeyB0aHJvdyAnQ29waWVkIEF1dGhXaXJlIHNjcmlwdCBzaWduYXR1cmUgaW52YWxpZC4nIH0KICAgIH0gZWxzZSB7IFtJTy5GaWxlXTo6V3JpdGVBbGxCeXRlcygkZGVzdGluYXRpb24sIFtieXRlW11dJHZlcmlmaWVkQXNzZXRzWyRuYW1lXSkgfQogICAgJGZpbGVBY2wgPSBOZXctT2JqZWN0IFNlY3VyaXR5LkFjY2Vzc0NvbnRyb2wuRmlsZVNlY3VyaXR5CiAgICAkZmlsZUFjbC5TZXRBY2Nlc3NSdWxlUHJvdGVjdGlvbigkdHJ1ZSwkZmFsc2UpCiAgICAkZmlsZUFjbC5TZXRPd25lcigoTmV3LU9iamVjdCBTZWN1cml0eS5QcmluY2lwYWwuU2VjdXJpdHlJZGVudGlmaWVyKCdTLTEtNS0zMi01NDQnKSkpCiAgICBmb3JlYWNoKCRzaWQgaW4gQCgnUy0xLTUtMTgnLCdTLTEtNS0zMi01NDQnKSkgewogICAgICAgICRmaWxlQWNsLkFkZEFjY2Vzc1J1bGUoKE5ldy1PYmplY3QgU2VjdXJpdHkuQWNjZXNzQ29udHJvbC5GaWxlU3lzdGVtQWNjZXNzUnVsZSgoTmV3LU9iamVjdCBTZWN1cml0eS5QcmluY2lwYWwuU2VjdXJpdHlJZGVudGlmaWVyKCRzaWQpKSwgJ0Z1bGxDb250cm9sJywgJ0FsbG93JykpKQogICAgfQogICAgU2V0LUFjbCAkZGVzdGluYXRpb24gJGZpbGVBY2wKfQpmb3JlYWNoKCRlbnRyeSBpbiBAKEAoJ3Jvb3QtY2EucGVtJywnUm9vdCcpLEAoJ2lzc3Vlci1jYS5wZW0nLCdDQScpLEAoJ2h0dHBzLXRydXN0LnBlbScsJ1Jvb3QnKSkpIHsKICAgICRmaWxlID0gSm9pbi1QYXRoICR0YXJnZXQgJGVudHJ5WzBdCiAgICBpZihUZXN0LVBhdGggJGZpbGUpIHsKICAgICAgICAkY2VydGlmaWNhdGUgPSBOZXctT2JqZWN0IFNlY3VyaXR5LkNyeXB0b2dyYXBoeS5YNTA5Q2VydGlmaWNhdGVzLlg1MDlDZXJ0aWZpY2F0ZTIoJGZpbGUpCiAgICAgICAgJHN0b3JlID0gTmV3LU9iamVjdCBTZWN1cml0eS5DcnlwdG9ncmFwaHkuWDUwOUNlcnRpZmljYXRlcy5YNTA5U3RvcmUoJGVudHJ5WzFdLCdMb2NhbE1hY2hpbmUnKQogICAgICAgIHRyeSB7ICRzdG9yZS5PcGVuKCdSZWFkV3JpdGUnKTsgJHN0b3JlLkFkZCgkY2VydGlmaWNhdGUpIH0gZmluYWxseSB7ICRzdG9yZS5DbG9zZSgpOyAkY2VydGlmaWNhdGUuRGlzcG9zZSgpIH0KICAgIH0KfQokYWN0aW9uID0gTmV3LVNjaGVkdWxlZFRhc2tBY3Rpb24gLUV4ZWN1dGUgIiRlbnY6U3lzdGVtUm9vdFxTeXN0ZW0zMlxXaW5kb3dzUG93ZXJTaGVsbFx2MS4wXHBvd2Vyc2hlbGwuZXhlIiAtQXJndW1lbnQgKCctTm9Qcm9maWxlIC1Ob25JbnRlcmFjdGl2ZSAtRXhlY3V0aW9uUG9saWN5IEFsbFNpZ25lZCAtRmlsZSAiJysoSm9pbi1QYXRoICR0YXJnZXQgJ0luc3RhbGwtQXV0aFdpcmUucHMxJykrJyIgLVJ1bkNsaWVudCcpCiRkYWlseSA9IE5ldy1TY2hlZHVsZWRUYXNrVHJpZ2dlciAtRGFpbHkgLUF0ICcwOTowMCc7ICRldmVuaW5nID0gTmV3LVNjaGVkdWxlZFRhc2tUcmlnZ2VyIC1EYWlseSAtQXQgJzIxOjAwJwokc3RhcnR1cCA9IE5ldy1TY2hlZHVsZWRUYXNrVHJpZ2dlciAtQXRTdGFydHVwCiMgU3RhcnR1cCBwbHVzIFN0YXJ0V2hlbkF2YWlsYWJsZS9SdW5Pbmx5SWZOZXR3b3JrQXZhaWxhYmxlIGRlZmVycyBlbnJvbGxtZW50CiMgdW50aWwgbmV0d29ya2luZyBpcyB1c2FibGUuIEF2b2lkIHJhdyBNU0ZUX1Rhc2tFdmVudFRyaWdnZXIgQ0lNIGluc3RhbmNlczoKIyBSZWdpc3Rlci1TY2hlZHVsZWRUYXNrIHJlamVjdHMgdGhlaXIgUFNUeXBlTmFtZSBvbiBzdXBwb3J0ZWQgV2luZG93cyBjbGllbnRzLgokcHJpbmNpcGFsID0gTmV3LVNjaGVkdWxlZFRhc2tQcmluY2lwYWwgLVVzZXJJZCAnU1lTVEVNJyAtTG9nb25UeXBlIFNlcnZpY2VBY2NvdW50IC1SdW5MZXZlbCBIaWdoZXN0CiRzZXR0aW5ncyA9IE5ldy1TY2hlZHVsZWRUYXNrU2V0dGluZ3NTZXQgLVN0YXJ0V2hlbkF2YWlsYWJsZSAtUnVuT25seUlmTmV0d29ya0F2YWlsYWJsZSAtQWxsb3dTdGFydElmT25CYXR0ZXJpZXMgLURvbnRTdG9wSWZHb2luZ09uQmF0dGVyaWVzIC1NdWx0aXBsZUluc3RhbmNlcyBJZ25vcmVOZXcgLUV4ZWN1dGlvblRpbWVMaW1pdCAoTmV3LVRpbWVTcGFuIC1NaW51dGVzIDEwKQokbnVsbCA9IFJlZ2lzdGVyLVNjaGVkdWxlZFRhc2sgLVRhc2tOYW1lICdBdXRoV2lyZSBDZXJ0aWZpY2F0ZSBFbnJvbGxtZW50JyAtQWN0aW9uICRhY3Rpb24gLVRyaWdnZXIgQCgkZGFpbHksJGV2ZW5pbmcsJHN0YXJ0dXApIC1QcmluY2lwYWwgJHByaW5jaXBhbCAtU2V0dGluZ3MgJHNldHRpbmdzIC1Gb3JjZQojIFJlYXBwbGljYXRpb24gYWxzbyByZXBhaXJzIGEgcGVuZGluZyBkZWFkbGluZSBjcmVhdGVkIGJ5IHRoZSBvbGRlciBjbGllbnQuCiRwZW5kaW5nUmV0cnkgPSBSZWFkLUF1dGhXaXJlUmV0cnlEZWFkbGluZSAkdGFyZ2V0CmlmKCRwZW5kaW5nUmV0cnkpIHsKICAgICRyZXRyeUF0ID0gaWYoJHBlbmRpbmdSZXRyeSAtZ3QgW0RhdGVUaW1lT2Zmc2V0XTo6VXRjTm93KSB7ICRwZW5kaW5nUmV0cnkgfSBlbHNlIHsgW0RhdGVUaW1lT2Zmc2V0XTo6VXRjTm93LkFkZE1pbnV0ZXMoMSkgfQogICAgU2V0LUF1dGhXaXJlUmV0cnlUYXNrICR0YXJnZXQgJ0F1dGhXaXJlIENlcnRpZmljYXRlIEVucm9sbG1lbnQgUmV0cnknICRyZXRyeUF0Cn0KIyBHUE8gY2FuIHJlZ2lzdGVyL3VwZGF0ZSBhbiBleGlzdGluZyB0YXNrIGFmdGVyIHRoZSBib290IGV2ZW50IHdhcyBtaXNzZWQuCiMgVGFzayBleGlzdGVuY2UgZG9lcyBub3QgcHJvdmUgdGhhdCBpdHMgYm9vdCB0cmlnZ2VyIGFjdHVhbGx5IHJhbi4KZnVuY3Rpb24gU3RhcnQtQXV0aFdpcmVFbnJvbGxtZW50Rm9yQm9vdChbc3RyaW5nXSRUYXNrTmFtZSkgewogICAgJHRhc2sgPSBHZXQtU2NoZWR1bGVkVGFzayAtVGFza05hbWUgJFRhc2tOYW1lIC1FcnJvckFjdGlvbiBTdG9wCiAgICAkaW5mbyA9IEdldC1TY2hlZHVsZWRUYXNrSW5mbyAtVGFza05hbWUgJFRhc2tOYW1lIC1FcnJvckFjdGlvbiBTdG9wCiAgICAkYm9vdCA9IChHZXQtQ2ltSW5zdGFuY2UgV2luMzJfT3BlcmF0aW5nU3lzdGVtIC1FcnJvckFjdGlvbiBTdG9wKS5MYXN0Qm9vdFVwVGltZQogICAgaWYgKCEkYm9vdCAtb3IgISRpbmZvLkxhc3RSdW5UaW1lKSB7IHRocm93ICdBdXRoV2lyZSBib290IHN0YXRlIHVuYXZhaWxhYmxlLicgfQogICAgaWYgKCR0YXNrLlN0YXRlIC1pbiBAKCdSdW5uaW5nJywnUXVldWVkJykpIHsgcmV0dXJuICdhbHJlYWR5X3BlbmRpbmcnIH0KICAgIGlmICgkaW5mby5MYXN0UnVuVGltZSAtZ2UgJGJvb3QpIHsgcmV0dXJuICdhbHJlYWR5X3Jhbl90aGlzX2Jvb3QnIH0KICAgIFN0YXJ0LVNjaGVkdWxlZFRhc2sgLVRhc2tOYW1lICRUYXNrTmFtZSAtRXJyb3JBY3Rpb24gU3RvcAogICAgcmV0dXJuICdib290X3J1bl9yZXF1ZXN0ZWQnCn0KJGJvb3RSdW4gPSBTdGFydC1BdXRoV2lyZUVucm9sbG1lbnRGb3JCb290ICdBdXRoV2lyZSBDZXJ0aWZpY2F0ZSBFbnJvbGxtZW50JwpXcml0ZS1PdXRwdXQgKCdBdXRoV2lyZSBlbnJvbGxtZW50IHN0YXJ0dXA6ICcgKyAkYm9vdFJ1bikKIyBObyBzdXBwbGljYW50IHBvbGljeSwgcG9ydCBjb250cm9sIG9yIFJBRElVUyBjaGFuZ2VzIGluIHRoaXMgcGFja2FnZS4K'))
}

function Test-AuthWireCombinedContent {
 param([string]$ConnectorId,[string]$PlanId,[int]$PlanVersion,[string]$DraftSha256,[string]$ManifestSha256,[string]$PublisherThumbprint,[string]$ServiceSid)
 foreach($id in @($ConnectorId,$PlanId)){Assert-AuthWireCandidateGuid $id}
 foreach($h in @($DraftSha256,$ManifestSha256)){if($h -cnotmatch '\A[0-9a-f]{64}\z'){throw 'COMBINED_READONLY_PIN_REQUIRED'}}
 if($PlanVersion -lt 1 -or $ServiceSid -cnotmatch '\AS-1-5-21-(?:[1-9][0-9]{0,9}-){3}[1-9][0-9]{0,9}\z' -or $PublisherThumbprint -cnotmatch '\A[0-9A-F]{40}\z'){throw 'COMBINED_READONLY_IDENTITY_REQUIRED'}
 $templateHash='ab1a11c68381006173518df77deeb0d32fc56e0b28cc260c42b7378c624be14a'
 $root=Join-Path ([Environment]::GetFolderPath('CommonApplicationData')) ('AuthWire-CombinedCandidates-'+([guid]$ConnectorId).ToString('N'))
 Assert-AuthWireCandidateAcl $root $ServiceSid -Directory
 $path=Join-Path $root ($PlanId+'-v'+$PlanVersion+'-'+$DraftSha256+'-'+$templateHash.Substring(0,16))
 Assert-AuthWireCandidateAcl $path $ServiceSid -Directory
 $manifestPath=Join-Path $path 'signed-manifest.json';Assert-AuthWireCandidateAcl $manifestPath $ServiceSid
 if((Get-AuthWireCandidateHash (Read-AuthWireCandidateBytes $manifestPath 65536)) -cne $ManifestSha256){throw 'COMBINED_READONLY_MANIFEST_CHANGED'}
 $draftPath=Join-Path $path 'original-draft.zip';Assert-AuthWireCandidateAcl $draftPath $ServiceSid
 $draft=Read-AuthWireCombinedDraft $draftPath $DraftSha256
 if($draft.Manifest.plan_id -cne $PlanId -or $draft.Manifest.plan_version -ne $PlanVersion){throw 'COMBINED_READONLY_PLAN_CHANGED'}
 $installer=New-AuthWireCombinedInstaller (Get-AuthWireCombinedReadonlyTemplate) $templateHash $draft.Files
 $checked=Test-AuthWireCombinedPrepared $path $draft $installer $templateHash $PublisherThumbprint $ServiceSid
 if($checked.ManifestSha256 -cne $ManifestSha256){throw 'COMBINED_READONLY_MANIFEST_CHANGED'}
 return [pscustomobject]@{Event='WINDOWS_COMBINED_CONTENT_VERIFIED';PlanId=$PlanId;PlanVersion=$PlanVersion;ManifestSha256=$ManifestSha256;DraftSha256=$DraftSha256;ContentVerified=$true;SignaturesVerified=3;PrivateKeyOpened=$false;ArtifactExecuted=$false;GpoStateChecked=$false;DirectoryFreshnessChecked=$false;CanStage=$false;CanApplyGpo=$false}
}
function Test-AuthWireServiceCombinedContent {
 param([string]$ConnectorId,[string]$PlanId,[int]$PlanVersion,[string]$DraftSha256,[string]$ManifestSha256,[string]$PublisherThumbprint,[string]$ServiceSid)
 $identity=[Security.Principal.WindowsIdentity]::GetCurrent()
 try{if($identity.User.Value -cne $ServiceSid -or -not $identity.IsAuthenticated){throw 'COMBINED_SERVICE_IDENTITY_REQUIRED'}}finally{$identity.Dispose()}
 $result=Test-AuthWireCombinedContent @PSBoundParameters
 $result|Add-Member NoteProperty RuntimeSid $ServiceSid
 $result|Add-Member NoteProperty ServiceIdentityVerified $true
 return $result
}
