# Fixed DC01 read-only candidate verification under the existing aw-deploy$ SID.
# Signs only two reviewed helpers and an owned temporary SCM probe. No GPO apply.
param([ValidateSet('Inspect','RunProbe')][string]$Mode='Inspect')
$ErrorActionPreference='Stop';Set-StrictMode -Version 2
Import-Module (Join-Path $PSHOME 'Modules\Microsoft.PowerShell.Security\Microsoft.PowerShell.Security.psd1') -ErrorAction Stop
Add-Type -AssemblyName System.IO.Compression
$reviewedSources=@{
 'Test-AuthWireDeploymentCandidate.ps1'='8260dc67d8ba7af49447d20a02031a60dc0370e6c5f5733802cbfd2c1358ca09'
 'Test-AuthWireCandidateService.ps1'='894b305024e50209a7a77e9f21c8107095454e02362fca6593a7bc4bb857b9a1'
}
$embeddedSources='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'
$archiveSha256='1aa7a203a3d1f19d5f40eb36d4e4f52dd98514e04d2d3a9026027673fc1c86e6'
function Get-AuthWireDeliveryHash([byte[]]$Bytes){
 $sha=[Security.Cryptography.SHA256]::Create()
 try{([BitConverter]::ToString($sha.ComputeHash($Bytes))).Replace('-','').ToLowerInvariant()}finally{$sha.Dispose()}
}
function Get-AuthWireDeliveryBodyHash([string]$Text){
 $body=($Text -split '(?m)^# SIG # Begin signature block\r?$',2)[0]
 $body=$body.Replace("`r`n","`n").TrimEnd([char[]]"`r`n")+"`n"
 Get-AuthWireDeliveryHash ([Text.UTF8Encoding]::new($false,$true).GetBytes($body))
}
function Read-AuthWireReviewedSourceBytes([byte[]]$Archive,[string]$ExpectedHash){
 if($Archive.Length -gt 524288 -or $Archive.Length -lt 100 -or (Get-AuthWireDeliveryHash $Archive) -cne $ExpectedHash){throw 'REVIEWED_ARCHIVE_HASH_OR_SIZE_REJECTED'}
 $memory=[IO.MemoryStream]::new($Archive,$false);$zip=$null
 try{
  $zip=[IO.Compression.ZipArchive]::new($memory,[IO.Compression.ZipArchiveMode]::Read,$true)
  if($zip.Entries.Count -ne $reviewedSources.Count){throw 'REVIEWED_ARCHIVE_FILE_SET_REJECTED'}
  $result=@{}
  foreach($entry in $zip.Entries){
   $name=$entry.FullName
   if(@($reviewedSources.Keys|Where-Object{$_ -ceq $name}).Count -ne 1 -or $result.ContainsKey($name) -or $entry.Length -gt 131072 -or $entry.Length -lt 1){throw 'REVIEWED_ARCHIVE_ENTRY_REJECTED'}
   $stream=$entry.Open();$output=[IO.MemoryStream]::new()
   try{
    $buffer=New-Object byte[] 4096
    while(($count=$stream.Read($buffer,0,$buffer.Length)) -gt 0){
     if($output.Length+$count -gt 131072){throw 'REVIEWED_SOURCE_SIZE_REJECTED'}
     $output.Write($buffer,0,$count)
    }
    $bytes=$output.ToArray()
   }finally{$output.Dispose();$stream.Dispose()}
   if((Get-AuthWireDeliveryHash $bytes) -cne $reviewedSources[$name]){throw ('UNREVIEWED_SOURCE:'+ $name)}
   $null=[Text.UTF8Encoding]::new($false,$true).GetString($bytes)
   $result[$name]=$bytes
  }
  return $result
 }finally{if($null -ne $zip){$zip.Dispose()};$memory.Dispose()}
}
function Assert-AuthWireDeliveryAcl([string]$Path,[switch]$Directory){
 $item=Get-Item -LiteralPath $Path -Force
 if($item.Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'DELIVERY_REPARSE_POINT_REJECTED'}
 if([bool]$item.PSIsContainer -ne [bool]$Directory){throw 'DELIVERY_PATH_TYPE_REJECTED'}
 $acl=Get-Acl -LiteralPath $Path
 $rules=@($acl.GetAccessRules($true,$true,[Security.Principal.SecurityIdentifier]))
 if($acl.GetOwner([Security.Principal.SecurityIdentifier]).Value -ne 'S-1-5-32-544' -or -not $acl.AreAccessRulesProtected -or $rules.Count -ne 2){throw 'DELIVERY_ACL_REJECTED'}
 $inheritance=0;if($Directory){$inheritance=3}
 foreach($sid in @('S-1-5-18','S-1-5-32-544')){
  $r=@($rules|Where-Object{$_.IdentityReference.Value -ceq $sid})
  if($r.Count -ne 1 -or $r[0].IsInherited -or $r[0].AccessControlType -ne 'Allow' -or [int]$r[0].FileSystemRights -ne 2032127 -or [int]$r[0].InheritanceFlags -ne $inheritance -or [int]$r[0].PropagationFlags -ne 0){throw 'DELIVERY_ACL_REJECTED'}
 }
}
function Set-AuthWireDeliveryFileAcl([string]$Path){
 if((Get-Item -LiteralPath $Path -Force).Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'DELIVERY_FILE_REPARSE_REJECTED'}
 $acl=[Security.AccessControl.FileSecurity]::new()
 $acl.SetSecurityDescriptorSddlForm('O:BAG:BAD:P(A;;FA;;;SY)(A;;FA;;;BA)')
 Set-Acl -LiteralPath $Path -AclObject $acl
 Assert-AuthWireDeliveryAcl $Path
}
function Assert-AuthWireSignedDelivery([string]$Directory,[string]$PublisherThumbprint){
 Assert-AuthWireDeliveryAcl $Directory -Directory
 foreach($name in $reviewedSources.Keys){
  $path=Join-Path $Directory $name
  Assert-AuthWireDeliveryAcl $path
  if((Get-Item -LiteralPath $path).Length -gt 196608 -or (Get-AuthWireDeliveryBodyHash ([IO.File]::ReadAllText($path))) -cne $reviewedSources[$name]){throw ('SIGNED_DELIVERY_BODY_REJECTED:'+ $name)}
  if($name.EndsWith('.ps1',[StringComparison]::Ordinal)){
   $s=Get-AuthenticodeSignature -LiteralPath $path
   if($s.Status.ToString() -cne 'Valid' -or $s.SignerCertificate.Thumbprint -ine $PublisherThumbprint){throw ('SIGNED_DELIVERY_PUBLISHER_REJECTED:'+ $name)}
  }
 }
}
function New-AuthWireSignedDelivery([hashtable]$Sources,[string]$Directory,[Security.Cryptography.X509Certificates.X509Certificate2]$Publisher){
 # Only fixed reviewed bytes may be signed; verify every input before output.
 if($Sources.Count -ne $reviewedSources.Count -or -not $Publisher.HasPrivateKey){throw 'SIGNING_INPUT_REJECTED'}
 foreach($name in $reviewedSources.Keys){
  if(-not $Sources.ContainsKey($name) -or $Sources[$name] -isnot [byte[]] -or (Get-AuthWireDeliveryHash $Sources[$name]) -cne $reviewedSources[$name]){throw 'UNREVIEWED_SIGNING_INPUT_REJECTED'}
 }
 if(Test-Path -LiteralPath $Directory){throw 'EXISTING_DELIVERY_REQUIRES_INSPECTION'}
 $parent=Get-Item -LiteralPath ([IO.Path]::GetDirectoryName($Directory)) -Force
 if($parent.Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'DELIVERY_PARENT_REPARSE_REJECTED'}
 $acl=[Security.AccessControl.DirectorySecurity]::new()
 $acl.SetSecurityDescriptorSddlForm('O:BAG:BAD:P(A;OICI;FA;;;SY)(A;OICI;FA;;;BA)')
 $null=[IO.Directory]::CreateDirectory($Directory,$acl)
 Assert-AuthWireDeliveryAcl $Directory -Directory
 foreach($name in $reviewedSources.Keys){
  $path=Join-Path $Directory $name
  [IO.File]::WriteAllBytes($path,$Sources[$name])
  Set-AuthWireDeliveryFileAcl $path
  if($name.EndsWith('.ps1',[StringComparison]::Ordinal)){
   $s=Set-AuthenticodeSignature -LiteralPath $path -Certificate $Publisher -HashAlgorithm SHA256
   if($s.Status.ToString() -cne 'Valid'){throw ('DELIVERY_SIGNING_FAILED:'+ $name)}
  }
 }
 Assert-AuthWireSignedDelivery $Directory $Publisher.Thumbprint
}
function Get-AuthWireExistingDeliverySigner([string]$Thumbprint){
 $certificate=Get-Item -LiteralPath ('Cert:\LocalMachine\My\'+$Thumbprint)
 if(-not $certificate.HasPrivateKey -or $certificate.Subject -cne 'CN=dc01.vizyonveri.local' -or $certificate.NotBefore -gt (Get-Date) -or $certificate.NotAfter -le (Get-Date)){throw 'EXISTING_MACHINE_SIGNER_REQUIRED'}
 $trusted=Get-Item -LiteralPath ('Cert:\LocalMachine\TrustedPublisher\'+$Thumbprint)
 if((Get-AuthWireDeliveryHash $trusted.RawData) -cne (Get-AuthWireDeliveryHash $certificate.RawData)){throw 'EXISTING_MACHINE_PUBLISHER_TRUST_REQUIRED'}
 $chain=[Security.Cryptography.X509Certificates.X509Chain]::new($true)
 try{
  $chain.ChainPolicy.RevocationMode='Online';$chain.ChainPolicy.RevocationFlag='ExcludeRoot';$chain.ChainPolicy.VerificationFlags='NoFlag'
  $chain.ChainPolicy.UrlRetrievalTimeout=[timespan]::FromSeconds(15)
  $null=$chain.ChainPolicy.ApplicationPolicy.Add([Security.Cryptography.Oid]::new('1.3.6.1.5.5.7.3.3'))
  if(-not $chain.Build($certificate) -or $chain.ChainElements[$chain.ChainElements.Count-1].Certificate.Thumbprint -ine '4D6D3C94B878B75AE02B436C0A19D3A3104C68BB'){throw 'EXISTING_MACHINE_SIGNER_CHAIN_REJECTED'}
 }finally{$chain.Dispose()}
 return $certificate
}

function Assert-AuthWireCandidateDeliveryHost {
 $identity=[Security.Principal.WindowsIdentity]::GetCurrent()
 try{if(-not [Environment]::Is64BitProcess -or $PSVersionTable.PSVersion.Major -ne 5 -or -not ([Security.Principal.WindowsPrincipal]::new($identity)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){throw 'DC01_WINDOWS_POWERSHELL_ADMIN_REQUIRED'}}finally{$identity.Dispose()}
 if([Environment]::MachineName -cne 'DC01'){throw 'DC01_HOST_REQUIRED'}
 $system=Get-CimInstance Win32_ComputerSystem
 if(-not $system.PartOfDomain -or $system.Domain -ine 'vizyonveri.local'){throw 'DC01_DOMAIN_MISMATCH'}
 Import-Module ActiveDirectory -ErrorAction Stop
 $computer=Get-ADComputer -Identity 'DC01' -Server 'dc01.vizyonveri.local'
 if($computer.ObjectGUID.ToString('D') -cne '0fa4143f-aae3-4bc3-9cd3-db8a1de24acd'){throw 'DC01_HOST_GUID_MISMATCH'}
 $serviceName='AuthWireConnector-4c23eebe071546d188eea2e96ad7ee46'
 $service=Get-CimInstance Win32_Service -Filter ("Name='"+$serviceName+"'")
 if($null -eq $service -or $service.StartName -ine 'VIZYONVERI\aw-deploy$' -or $service.State -cne 'Running'){throw 'EXISTING_CONNECTOR_REQUIRED'}
 $config=Get-Content -LiteralPath 'C:\Program Files\AuthWire-Connector-4c23eebe071546d188eea2e96ad7ee46\service.json' -Raw|ConvertFrom-Json
 if($config.ReleaseId -cne '970d7039-3798-478b-a5f4-a57e245693a0' -or $config.Binding.connector_id -cne '4c23eebe-0715-46d1-88ee-a2e96ad7ee46' -or $config.Binding.instance_id -cne '6796fa84-fcff-41c1-b9c5-d725b95ba139' -or $config.Binding.service_sid -cne 'S-1-5-21-34256453-3348971241-2809240126-1648' -or $config.PublisherThumbprint -cne 'FFC134BC305757457163F99C7479B4168E397129'){throw 'EXISTING_CONNECTOR_CONTEXT_CHANGED'}
}

function Get-AuthWireCandidateDeliverySnapshot {
 $service=Get-CimInstance Win32_Service -Filter "Name='AuthWireConnector-4c23eebe071546d188eea2e96ad7ee46'"
 if($service.State -cne 'Running' -or $service.StartName -ine 'VIZYONVERI\aw-deploy$' -or $service.ProcessId -lt 1){throw 'EXISTING_CONNECTOR_CHANGED'}
 $base='C:\Program Files\AuthWire-Connector-4c23eebe071546d188eea2e96ad7ee46'
 $candidate='C:\ProgramData\AuthWire-DeploymentCandidates-4c23eebe071546d188eea2e96ad7ee46\524653f5135946f584a546355bb82aff-v1-ae98c8426953aced3f70bebfdc701cd85be52e3a08f9434a7d087a6bdb6ca9b7'
 $files=@{}
 foreach($p in @((Join-Path $base 'service.json'),(Join-Path $base 'package.json'),(Join-Path $base 'AuthWireConnector.exe'),(Join-Path $candidate 'approval.json'),(Join-Path $candidate 'network-profiles.zip'),(Join-Path $candidate 'AuthWire-Candidate-Manifest.ps1'))){
  $i=Get-Item -LiteralPath $p -Force
  if($i.PSIsContainer -or ($i.Attributes -band [IO.FileAttributes]::ReparsePoint)){throw 'EXISTING_SOURCE_REPARSE_REJECTED'}
  $files[$p]=@{hash=(Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash;sddl=(Get-Acl -LiteralPath $p).Sddl}
 }
 $health=Get-Content -LiteralPath (Join-Path $base 'state\status.json') -Raw|ConvertFrom-Json
 $age=([DateTimeOffset]::UtcNow-[DateTimeOffset]::Parse($health.CheckedUtc)).TotalSeconds
 if($health.Healthy -isnot [bool] -or -not $health.Healthy -or $health.ReleaseId -cne '970d7039-3798-478b-a5f4-a57e245693a0' -or $health.RuntimeSid -cne 'S-1-5-21-34256453-3348971241-2809240126-1648' -or $age -lt 0 -or $age -gt 90){throw 'FRESH_EXISTING_CONNECTOR_HEALTH_REQUIRED'}
 $cert=Get-Item -LiteralPath 'Cert:\LocalMachine\My\FFC134BC305757457163F99C7479B4168E397129'
 $key=[Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($cert)
 try{
  if($key -isnot [Security.Cryptography.RSACng] -or -not $key.Key.IsMachineKey -or $key.Key.IsEphemeral -or $key.KeySize -ne 3072 -or [int]$key.Key.ExportPolicy -ne 0 -or [int]$key.Key.KeyUsage -ne 2){throw 'EXISTING_NONEXPORTABLE_SIGNER_REQUIRED'}
  $kp=Join-Path (Join-Path $env:ProgramData 'Microsoft\Crypto\Keys') $key.Key.UniqueName
  return @{ServicePid=[int]$service.ProcessId;ServiceAccount=$service.StartName;KeyAcl=(Get-Acl -LiteralPath $kp).Sddl;Files=$files}
 }finally{$key.Dispose();$cert.Dispose()}
}
function Test-AuthWireCandidateSnapshotSame($Before,$After){
 if($Before.ServicePid -ne $After.ServicePid -or $Before.ServiceAccount -cne $After.ServiceAccount -or $Before.KeyAcl -cne $After.KeyAcl -or $Before.Files.Count -ne $After.Files.Count){return $false}
 foreach($p in $Before.Files.Keys){if(-not $After.Files.ContainsKey($p) -or $Before.Files[$p].hash -cne $After.Files[$p].hash -or $Before.Files[$p].sddl -cne $After.Files[$p].sddl){return $false}}
 return $true
}
$directory=$null;$prepared=$false;$probeStarted=$false;$stage='preflight'
try{
 Assert-AuthWireCandidateDeliveryHost
 $ready=@(Test-ADServiceAccount -Identity 'S-1-5-21-34256453-3348971241-2809240126-1648' -ErrorAction Stop)
 if($ready.Count -ne 1 -or $ready[0] -isnot [bool] -or -not $ready[0]){throw 'EXISTING_GMSA_NOT_READY'}
 $runtime=[Security.Principal.SecurityIdentifier]::new('S-1-5-21-34256453-3348971241-2809240126-1648').Translate([Security.Principal.NTAccount]).Value
 if($runtime -cne 'VIZYONVERI\aw-deploy$'){throw 'EXISTING_SERVICE_ACCOUNT_REQUIRED'}
 $before=Get-AuthWireCandidateDeliverySnapshot
 $directory=Join-Path $env:ProgramData ('AuthWire-CandidateVerifySources-'+$archiveSha256.Substring(0,16))
 $signer=Get-AuthWireExistingDeliverySigner 'FFC134BC305757457163F99C7479B4168E397129'
 try{
  if(Test-Path -LiteralPath $directory){Assert-AuthWireSignedDelivery $directory $signer.Thumbprint}
  else{$stage='prepare_reviewed_sources';$bytes=Read-AuthWireReviewedSourceBytes ([Convert]::FromBase64String($embeddedSources)) $archiveSha256;New-AuthWireSignedDelivery $bytes $directory $signer;$prepared=$true}
 }finally{$signer.Dispose()}
 . (Join-Path $directory 'Test-AuthWireCandidateService.ps1')
 $pins=@{ConnectorId='4c23eebe-0715-46d1-88ee-a2e96ad7ee46';PlanId='524653f5-1359-46f5-84a5-46355bb82aff';PlanVersion=1;PreviewHash='ae98c8426953aced3f70bebfdc701cd85be52e3a08f9434a7d087a6bdb6ca9b7';GpoId='8c6808fd-a382-4bf2-9c9c-d9e1d46082a3';ProtectedGpoId='e5a9ab39-3709-49cb-837a-0208d2eb3b12';ServiceSid='S-1-5-21-34256453-3348971241-2809240126-1648';PublisherThumbprint='FFC134BC305757457163F99C7479B4168E397129';ApprovalSha256='3b5587d5e6fcdc3cbdb753e097fe36d377e27e9e6bc549c289383baa345577ad';ManifestSha256='4f7a463d3404428703bb95424d8c8a7f275e85f6a3a42d7a270f6eaae5ba9a6d'}
 Assert-AuthWireCandidateProbePins $pins $pins.ServiceSid $pins.PublisherThumbprint;Assert-AuthWireCandidateVerifierSource
 $result=$null
 if($Mode -ceq 'RunProbe'){
  $stage='runtime_probe';$probeStarted=$true
  $result=Invoke-AuthWireServiceProbeCore -RuntimeAccount $runtime -ExpectedSid $pins.ServiceSid -PublisherThumbprint $pins.PublisherThumbprint -Pins $pins
 }
 $stage='preservation_after'
 if(-not (Test-AuthWireCandidateSnapshotSame $before (Get-AuthWireCandidateDeliverySnapshot))){throw 'PERMANENT_CONNECTOR_CANDIDATE_OR_KEY_ACL_CHANGED'}
 [pscustomobject]@{Event='WINDOWS_CANDIDATE_READONLY_SERVICE_DELIVERY';ToolVersion='1.0.0';Mode=$Mode;Computer=$env:COMPUTERNAME;SourceCommit='bdb6e8945bc1cf4b490ab400dd4d3efb9eb46157';SourcesDirectory=$directory;SourcesPreparedNow=$prepared;SourceSignaturesValid=$true;ProbeStarted=$probeStarted;Probe=$result;PermanentConnectorPreserved=$true;CandidatePreserved=$true;KeyAclPreserved=$true;AdChanged=$false;GpoChanged=$false;TrustStoreChanged=$false;CanApplyGpo=$false;TypedWorkerJobDeliveryPending=$true;PanelAttestationUpdated=$false;SecretsExported=$false}|ConvertTo-Json -Depth 8
}catch{
 [pscustomobject]@{Event='WINDOWS_CANDIDATE_READONLY_SERVICE_DELIVERY_FAILED';Mode=$Mode;Stage=$stage;SourcesDirectory=$directory;SourcesPreparedNow=$prepared;ProbeStarted=$probeStarted;Error=$_.Exception.Message;PermanentConnectorChangedByTool=$false;GpoApplyEnabled=$false;PanelAttestationUpdated=$false}|ConvertTo-Json -Depth 5
 throw
}
