# Fixed DC01 delivery: signs reviewed helper sources, then inspects/prepares a local candidate.
# Never updates the existing service, AD, GPO, SYSVOL, endpoint or trust settings.
param([ValidateSet('Inspect','Prepare','Verify')][string]$Mode='Inspect',
      [Parameter(Mandatory=$true)][string]$NetworkProfileZip)
$ErrorActionPreference='Stop'
Set-StrictMode -Version 2
Import-Module (Join-Path $PSHOME 'Modules\Microsoft.PowerShell.Security\Microsoft.PowerShell.Security.psd1') -ErrorAction Stop
Add-Type -AssemblyName System.IO.Compression
$reviewedSources=@{
 'New-AuthWireDeploymentCandidate.ps1'='8043963d673488b6a07f91e9fe228675134e4d067270e7d30a8084d945316a01'
}
$embeddedSources='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'
$archiveSha256='89bf426c67776add8057bb49f994d61c10a695a292f0de3690ebf5c0824f6e07'
$approvalSha256='3b5587d5e6fcdc3cbdb753e097fe36d377e27e9e6bc549c289383baa345577ad'
$approvalJson=@'
{
  "format": 1,
  "zip_sha256": "528a793a637e2a8bdd30808acf7a624b83b125419d1ef1c8077249955a146e38",
  "plan_id": "524653f5-1359-46f5-84a5-46355bb82aff",
  "plan_version": 1,
  "preview_hash": "ae98c8426953aced3f70bebfdc701cd85be52e3a08f9434a7d087a6bdb6ca9b7",
  "machine_profile_id": "e3597842-3499-4ace-aaf3-29890eabd908",
  "machine_profile_version": 3,
  "group_sid": "S-1-5-21-34256453-3348971241-2809240126-1647",
  "domain": "vizyonveri.local",
  "server_name": "kaname.vizyonveri.local",
  "ssid": "VV_802.1X",
  "root_thumbprint": "C789A0595ADB95A6BE4534D01B1D205F6C37DE18",
  "connector_id": "4c23eebe-0715-46d1-88ee-a2e96ad7ee46",
  "service_sid": "S-1-5-21-34256453-3348971241-2809240126-1648",
  "gpo_id": "8c6808fd-a382-4bf2-9c9c-d9e1d46082a3",
  "protected_gpo_id": "e5a9ab39-3709-49cb-837a-0208d2eb3b12",
  "publisher_thumbprint": "FFC134BC305757457163F99C7479B4168E397129"
}
'@
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
$stage='preflight';$directory=$null;$sourcesPrepared=$false;$candidateStarted=$false
try{
 Assert-AuthWireCandidateDeliveryHost
 $item=Get-Item -LiteralPath $NetworkProfileZip -Force
 if($item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -or $item.Length -gt 262144 -or (Get-FileHash -LiteralPath $NetworkProfileZip -Algorithm SHA256).Hash -ine '528a793a637e2a8bdd30808acf7a624b83b125419d1ef1c8077249955a146e38'){throw 'REVIEWED_NETWORK_ZIP_REQUIRED'}
 $approvalBytes=[Text.UTF8Encoding]::new($false,$true).GetBytes($approvalJson.Replace("`r`n","`n")+"`n")
 if((Get-AuthWireDeliveryHash $approvalBytes) -cne $approvalSha256){throw 'REVIEWED_APPROVAL_CHANGED'}
 $directory=Join-Path $env:ProgramData 'AuthWire-DeploymentCandidateSources-3b5587d5e6fcdc3c'
 $signer=Get-AuthWireExistingDeliverySigner 'FFC134BC305757457163F99C7479B4168E397129'
 try{
  if(Test-Path -LiteralPath $directory){Assert-AuthWireSignedDelivery $directory $signer.Thumbprint}
  else{
   $stage='sources_preparation'
   $sources=Read-AuthWireReviewedSourceBytes ([Convert]::FromBase64String($embeddedSources)) $archiveSha256
   New-AuthWireSignedDelivery $sources $directory $signer
   $sourcesPrepared=$true
  }
 }finally{$signer.Dispose()}
 $approvalPath=Join-Path $directory 'approval.json'
 if(Test-Path -LiteralPath $approvalPath){Assert-AuthWireDeliveryAcl $approvalPath;if((Get-FileHash -LiteralPath $approvalPath -Algorithm SHA256).Hash -ine $approvalSha256){throw 'EXISTING_APPROVAL_CHANGED'}}
 else{[IO.File]::WriteAllBytes($approvalPath,$approvalBytes);Set-AuthWireDeliveryFileAcl $approvalPath}
 $stage='candidate_'+$Mode.ToLowerInvariant();$candidateStarted=$true
 $tool=Join-Path $directory 'New-AuthWireDeploymentCandidate.ps1'
 $candidate=((& $tool -Mode $Mode -NetworkProfileZip $NetworkProfileZip -ApprovalPath $approvalPath -ExpectedApprovalSha256 $approvalSha256)|Out-String)|ConvertFrom-Json
 $finishedStage=switch($Mode){'Inspect'{'inspected'};'Prepare'{'prepared'};'Verify'{'verified'}}
 [pscustomobject]@{Event='WINDOWS_DEPLOYMENT_CANDIDATE_DELIVERY';ToolVersion='1.0.0';Mode=$Mode;Computer=$env:COMPUTERNAME;SourceCommit='3707cfbe0aa54caf33176ea3dbe2167f6afc8e8a';SourcesDirectory=$directory;SourcesPreparedNow=$sourcesPrepared;SourceSignaturesValid=$true;ApprovalSha256=$approvalSha256;Stage=$finishedStage;Candidate=$candidate;ExistingConnectorChanged=$false;AdChanged=$false;GpoChanged=$false;TrustStoreChanged=$false;KeyAclChanged=$false;WindowsEndpointChanged=$false;CanApplyGpo=$false;SecretsExported=$false}|ConvertTo-Json -Depth 7
}catch{
 [pscustomobject]@{Event='WINDOWS_DEPLOYMENT_CANDIDATE_DELIVERY_FAILED';Mode=$Mode;Stage=$stage;SourcesDirectory=$directory;SourcesPreparedNow=$sourcesPrepared;CandidateOperationStarted=$candidateStarted;Error=$_.Exception.Message;AdChanged=$false;GpoChanged=$false;ExistingConnectorChanged=$false;CanApplyGpo=$false}|ConvertTo-Json -Depth 5
 throw
}
