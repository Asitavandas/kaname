#Requires -Version 5.1
# Local signed preparation only. Dependencies are function-only imports from
# New-AuthWireDeploymentCandidate.ps1 and Get-AuthWireMachineSignerMetadata.ps1.
# Never imports a network profile, runs enrollment, writes SYSVOL or changes keys.
Set-StrictMode -Version 2

function Read-AuthWireCombinedDraft([string]$Path,[string]$ExpectedHash) {
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

function Get-AuthWireCombinedSignerSnapshot($Certificate,[string]$KeyName,[string]$UniqueName,[string]$Sddl){
 $m=Get-AuthWireNamedMachineKeyMetadata $Certificate;$n=$m.Native
 if($m.OpenError -or -not $m.NamedKeyOpened -or $null -eq $n -or $n.KeyName -cne $KeyName -or $n.UniqueName -cne $UniqueName -or $m.KeySddl -cne $Sddl -or -not $n.PublicKeyMatchesCertificate -or -not $n.NativeKeyNameMatchesBinding -or -not $n.MarkerUnchanged -or $n.Provider -cne 'Microsoft Software Key Storage Provider' -or $n.Algorithm -cne 'RSA' -or $n.KeySize -ne 3072 -or $n.KeyType -ne 32 -or $n.ExportPolicyCode -ne 0 -or $n.KeyUsageCode -ne 2){throw 'COMBINED_PERSISTED_SIGNER_MISMATCH'}
 return (($m|ConvertTo-Json -Depth 8 -Compress)+'|'+[Convert]::ToBase64String($Certificate.RawData))
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
function Invoke-AuthWireCombinedCandidate {
 param([ValidateSet('Inspect','Prepare','Verify')][string]$Mode,[string]$DraftZip,[string]$ExpectedDraftSha256,[string]$InstallerTemplatePath,[string]$ExpectedInstallerTemplateSha256,[string]$PublisherThumbprint,[string]$ServiceSid,[string]$ExpectedKeyName,[string]$ExpectedUniqueName,[string]$ExpectedKeySddl,[string]$OutputParent)
 if($Mode -cnotin @('Inspect','Prepare','Verify')){throw 'COMBINED_MODE_REQUIRED'}
 $identity=[Security.Principal.WindowsIdentity]::GetCurrent()
 try{if(-not [Environment]::Is64BitProcess -or -not ([Security.Principal.WindowsPrincipal]::new($identity)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){throw 'COMBINED_ADMIN_REQUIRED'}}finally{$identity.Dispose()}
 if($ServiceSid -cnotmatch '\AS-1-5-21-(?:[1-9][0-9]{0,9}-){3}[1-9][0-9]{0,9}\z' -or $PublisherThumbprint -cnotmatch '\A[0-9A-F]{40}\z'){throw 'COMBINED_IDENTITY_PIN_REQUIRED'}
 $draft=Read-AuthWireCombinedDraft $DraftZip $ExpectedDraftSha256
 $template=Read-AuthWireCandidateBytes $InstallerTemplatePath 65536
 $installer=New-AuthWireCombinedInstaller $template $ExpectedInstallerTemplateSha256 $draft.Files
 $cert=Get-AuthWireCandidateSigner ([pscustomobject]@{publisher_thumbprint=$PublisherThumbprint})
 $temporary=$null;$before=$null;$result=$null
 try {
  $trusted=Get-Item -LiteralPath ('Cert:\LocalMachine\TrustedPublisher\'+$PublisherThumbprint)
  if([Convert]::ToBase64String($trusted.RawData) -cne [Convert]::ToBase64String($cert.RawData)){throw 'COMBINED_PUBLISHER_TRUST_REQUIRED'}
  $before=Get-AuthWireCombinedSignerSnapshot $cert $ExpectedKeyName $ExpectedUniqueName $ExpectedKeySddl
  $parent=Assert-AuthWireCandidatePath $OutputParent
  if([IO.Path]::GetFileName($parent) -cnotmatch '\AAuthWire-CombinedCandidates-[0-9a-f]{32}\z' -or [IO.Path]::GetDirectoryName($parent) -ine [Environment]::GetFolderPath('CommonApplicationData')){throw 'COMBINED_OUTPUT_PARENT_REJECTED'}
  $target=Join-Path $parent ($draft.Manifest.plan_id+'-v'+$draft.Manifest.plan_version+'-'+$draft.Hash+'-'+$ExpectedInstallerTemplateSha256.Substring(0,16))
  if(Test-Path -LiteralPath $parent){Assert-AuthWireCandidateAcl $parent $ServiceSid -Directory}
  $exists=Test-Path -LiteralPath $target
  if($exists){$result=Test-AuthWireCombinedPrepared $target $draft $installer $ExpectedInstallerTemplateSha256 $PublisherThumbprint $ServiceSid;$result|Add-Member NoteProperty PreparedNow $false}
  elseif($Mode -ceq 'Verify'){throw 'COMBINED_CANDIDATE_MISSING'}
  elseif($Mode -ceq 'Inspect'){$result=[pscustomobject]@{Event='WINDOWS_COMBINED_CANDIDATE_INSPECT';ReadyForPrepare=$true;CandidatePath=$target;DraftSha256=$draft.Hash;PrivateKeyOpenedForSigning=$false;CanStage=$false;CanApplyGpo=$false}}
  else {
   if(-not (Test-Path -LiteralPath $parent)){$null=New-Item -ItemType Directory -Path $parent;Set-AuthWireCandidateAcl $parent $ServiceSid -Directory}
   Assert-AuthWireCandidateAcl $parent $ServiceSid -Directory
   $temporary=Join-Path $parent ('.preparing-'+[guid]::NewGuid().ToString('N'))
   $null=New-Item -ItemType Directory -Path $temporary;Set-AuthWireCandidateAcl $temporary $ServiceSid -Directory
   foreach($d in @('enrollment','network')){$p=Join-Path $temporary $d;$null=New-Item -ItemType Directory -Path $p;Set-AuthWireCandidateAcl $p $ServiceSid -Directory}
   $files=@{};foreach($n in $draft.Files.Keys){if($n -cne 'bundle-manifest.json'){$files[$n]=$draft.Files[$n]}}
   $files['original-draft.zip']=$draft.Raw;$files['enrollment/Install-AuthWire.ps1']=$installer
   $files['README.txt']=[Text.Encoding]::ASCII.GetBytes("AuthWire signed LOCAL preparation only.`r`nNo SYSVOL staging, GPO link, enrollment or network activation performed.`r`nInstaller template includes the reviewed retry trigger timing correction.`r`nOriginal unsigned input is preserved in original-draft.zip.`r`n")
   foreach($n in $files.Keys){$p=Join-Path $temporary $n;[IO.File]::WriteAllBytes($p,[byte[]]$files[$n]);Set-AuthWireCandidateAcl $p $ServiceSid}
   foreach($n in @('enrollment/AuthWire-Client.ps1','enrollment/Install-AuthWire.ps1')){
    $p=Join-Path $temporary $n;$sig=Set-AuthenticodeSignature -LiteralPath $p -Certificate $cert -HashAlgorithm SHA256
    if($sig.Status.ToString() -cne 'Valid' -or $sig.SignerCertificate.Thumbprint -cne $PublisherThumbprint){throw 'COMBINED_SIGNING_FAILED'}
    $files[$n]=Read-AuthWireCandidateBytes $p 262144
   }
   $sums=@($files.Keys|Where-Object{$_ -clike 'enrollment/*' -and $_ -cne 'enrollment/SHA256SUMS.txt'}|Sort-Object|ForEach-Object{(Get-AuthWireCandidateHash $files[$_])+'  '+$_.Substring(11)}) -join "`n"
   $files['enrollment/SHA256SUMS.txt']=[Text.Encoding]::ASCII.GetBytes($sums)
   [IO.File]::WriteAllBytes((Join-Path $temporary 'enrollment/SHA256SUMS.txt'),$files['enrollment/SHA256SUMS.txt'])
   $hashes=[ordered]@{};foreach($n in $files.Keys|Sort-Object){$hashes[$n]=Get-AuthWireCandidateHash $files[$n]}
   $m=[ordered]@{format='AuthWireCombinedSignedPreparationV1';draft_sha256=$draft.Hash;plan_id=$draft.Manifest.plan_id;plan_version=$draft.Manifest.plan_version;installer_template_sha256=$ExpectedInstallerTemplateSha256;publisher_thumbprint=$PublisherThumbprint;installer_template_updated=$true;can_stage=$false;can_apply=$false;runtime_applied=$false;files=$hashes}
   $json=[Text.UTF8Encoding]::new($false).GetBytes(($m|ConvertTo-Json -Depth 5 -Compress))
   foreach($n in @('signed-manifest.json','AuthWire-Combined-Manifest.ps1')){$p=Join-Path $temporary $n;$bytes=if($n -ceq 'signed-manifest.json'){$json}else{Get-AuthWireCombinedManifestBody $json};[IO.File]::WriteAllBytes($p,[byte[]]$bytes);Set-AuthWireCandidateAcl $p $ServiceSid}
   $sig=Set-AuthenticodeSignature -LiteralPath (Join-Path $temporary 'AuthWire-Combined-Manifest.ps1') -Certificate $cert -HashAlgorithm SHA256
   if($sig.Status.ToString() -cne 'Valid'){throw 'COMBINED_MANIFEST_SIGNING_FAILED'}
   $null=Test-AuthWireCombinedPrepared $temporary $draft $installer $ExpectedInstallerTemplateSha256 $PublisherThumbprint $ServiceSid
   if((Get-AuthWireCombinedSignerSnapshot $cert $ExpectedKeyName $ExpectedUniqueName $ExpectedKeySddl) -cne $before){throw 'COMBINED_SIGNER_PRESERVATION_FAILED'}
   [IO.Directory]::Move($temporary,$target);$temporary=$null
   $result=Test-AuthWireCombinedPrepared $target $draft $installer $ExpectedInstallerTemplateSha256 $PublisherThumbprint $ServiceSid;$result|Add-Member NoteProperty PreparedNow $true
  }
  if((Get-AuthWireCombinedSignerSnapshot $cert $ExpectedKeyName $ExpectedUniqueName $ExpectedKeySddl) -cne $before){throw 'COMBINED_SIGNER_PRESERVATION_FAILED'}
  $result|Add-Member NoteProperty SignerSnapshotPreserved $true
  return $result
 }finally{
  try{if($before -and (Get-AuthWireCombinedSignerSnapshot $cert $ExpectedKeyName $ExpectedUniqueName $ExpectedKeySddl) -cne $before){throw 'COMBINED_SIGNER_PRESERVATION_FAILED'}}
  finally{$cert.Dispose();if($temporary -and (Test-Path -LiteralPath $temporary)){Remove-Item -LiteralPath $temporary -Recurse -Force}}
 }
}
