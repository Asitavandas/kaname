#Requires -Version 5.1
# Operator read-only inventory. It does not attest the gMSA runtime or authorize GPO application.
& {
 $ErrorActionPreference='Stop'
 Set-StrictMode -Version 2
 $awStarted=[DateTime]::UtcNow
 $awErrors=New-Object 'System.Collections.Generic.List[string]'
 $awResult=[ordered]@{
  Event='WINDOWS_DEPLOYMENT_SCOPE_OPERATOR_READONLY';ToolVersion='1.0.0'
  Computer=$env:COMPUTERNAME;Caller=[Security.Principal.WindowsIdentity]::GetCurrent().Name
  StartedUtc=$awStarted.ToString('o');CompletedUtc=$null
  PlanId='524653f5-1359-46f5-84a5-46355bb82aff';PlanVersion=1
  PinnedCandidateRead=$false;Directory=$null;Gpo=$null;ProtectedTrustGpo=$null
  Blockers=@();OperationError=$null;ReadyForNextReview=$false
  OperatorReadOnlySnapshot=$true;GmsaRuntimeTested=$false
  PanelAttestationUpdated=$false;CanApplyGpo=$false
  AdChanged=$false;GpoChanged=$false;ServicesChanged=$false
  EndpointChanged=$false;KeyAclChanged=$false;TrustStoreChanged=$false;SecretsExported=$false
 }
 try {
  if($env:COMPUTERNAME -ine 'DC01'){throw 'EXPECTED_DC01_REQUIRED'}
  Import-Module ActiveDirectory
  Import-Module GroupPolicy
  Add-Type -AssemblyName System.IO.Compression
  $awServer='dc01.vizyonveri.local';$awDomainName='vizyonveri.local'
  $awDomainSid='S-1-5-21-34256453-3348971241-2809240126'
  $awServiceSid=$awDomainSid+'-1648';$awGroupSid=$awDomainSid+'-1647'
  $awHostGuid='0fa4143f-aae3-4bc3-9cd3-db8a1de24acd'
  $awGpoId=[guid]'8c6808fd-a382-4bf2-9c9c-d9e1d46082a3'
  $awProtectedId=[guid]'e5a9ab39-3709-49cb-837a-0208d2eb3b12'
  $awMarker='AuthWireDeployment:v1;instance=4c23eebe-0715-46d1-88ee-a2e96ad7ee46;host='+$awHostGuid+';service='+$awServiceSid+';scope='+$awGroupSid
  $awDomain=Get-ADDomain -Server $awServer
  if($awDomain.DNSRoot -ine $awDomainName -or $awDomain.DomainSID.Value -cne $awDomainSid){throw 'DOMAIN_SCOPE_MISMATCH'}
  $awHost=Get-ADComputer -Identity ([guid]$awHostGuid) -Server $awServer
  if($awHost.Name -ine 'DC01'){throw 'HOST_GUID_MISMATCH'}
  $awCandidate='C:\ProgramData\AuthWire-DeploymentCandidates-4c23eebe071546d188eea2e96ad7ee46\524653f5135946f584a546355bb82aff-v1-ae98c8426953aced3f70bebfdc701cd85be52e3a08f9434a7d087a6bdb6ca9b7'
  $awZipPath=Join-Path $awCandidate 'network-profiles.zip'
  $awZipInfo=Get-Item -LiteralPath $awZipPath -Force
  if($awZipInfo.PSIsContainer -or $awZipInfo.Length -gt 262144 -or ($awZipInfo.Attributes -band [IO.FileAttributes]::ReparsePoint)){throw 'PINNED_ARCHIVE_REQUIRED'}
  [byte[]]$awBytes=[IO.File]::ReadAllBytes($awZipPath)
  $awSha=[Security.Cryptography.SHA256]::Create()
  try{$awHash=([BitConverter]::ToString($awSha.ComputeHash($awBytes))).Replace('-','').ToLowerInvariant()}finally{$awSha.Dispose()}
  if($awHash -cne '528a793a637e2a8bdd30808acf7a624b83b125419d1ef1c8077249955a146e38'){throw 'PINNED_ARCHIVE_CHANGED'}
  $awMemory=[IO.MemoryStream]::new($awBytes,$false);$awZip=$null;$awReader=$null
  try{
   $awZip=[IO.Compression.ZipArchive]::new($awMemory,[IO.Compression.ZipArchiveMode]::Read,$false)
   $awEntries=@($awZip.Entries|Where-Object {$_.FullName -ceq 'plan.json'})
   if($awEntries.Count -ne 1 -or $awEntries[0].Length -gt 65536){throw 'PINNED_PLAN_REQUIRED'}
   $awReader=[IO.StreamReader]::new($awEntries[0].Open(),[Text.UTF8Encoding]::new($false,$true))
   $awPlan=$awReader.ReadToEnd()|ConvertFrom-Json
  }finally{if($awReader){$awReader.Dispose()};if($awZip){$awZip.Dispose()};$awMemory.Dispose()}
  if($awPlan.id -cne $awResult.PlanId -or $awPlan.version -ne 1 -or $awPlan.plan.computer_group_sid -cne $awGroupSid){throw 'PINNED_PLAN_SCOPE_MISMATCH'}
  $awSample=@($awPlan.computer_targets.sample)
  if($awSample.Count -eq 0 -or $awSample.Count -ne $awPlan.computer_targets.count -or $awPlan.computer_targets.unresolved -ne 0){throw 'COMPLETE_PINNED_TARGET_SET_REQUIRED'}
  $awResult.PinnedCandidateRead=$true
  $awGroup=Get-ADGroup -Identity $awGroupSid -Properties GroupCategory,GroupScope -Server $awServer
  if($awGroup.Name -cne 'AuthWire-Pilot-Computers' -or $awGroup.GroupCategory.ToString() -ne 'Security'){throw 'PILOT_GROUP_SCOPE_MISMATCH'}
  $awMembers=@(Get-ADGroupMember -Identity $awGroupSid -Recursive -Server $awServer)
  if($awMembers.Count -gt 512){throw 'PILOT_MEMBER_LIMIT'}
  $awComputers=@(foreach($awMember in $awMembers){
   if($awMember.objectClass -eq 'computer'){
    $awComputer=Get-ADComputer -Identity $awMember.ObjectGUID -Properties Enabled,DNSHostName -Server $awServer
    [pscustomobject]@{Name=$awComputer.Name;Guid=$awComputer.ObjectGUID.ToString('D');Sid=$awComputer.SID.Value;Enabled=[bool]$awComputer.Enabled;DnsName=$awComputer.DNSHostName}
   }
  })
  $awExpected=@($awSample|ForEach-Object {$_.sid}|Sort-Object -Unique)
  $awActual=@($awComputers|ForEach-Object {$_.Sid}|Sort-Object -Unique)
  $awSame=(($awExpected -join '|') -ceq ($awActual -join '|'))
  $awDisabled=@($awComputers|Where-Object {-not $_.Enabled}).Count
  if(-not $awSame){$awErrors.Add('DIRECTORY_TARGET_MEMBERSHIP_CHANGED')}
  if($awDisabled -ne 0){$awErrors.Add('DIRECTORY_TARGET_DISABLED')}
  $awResult.Directory=[ordered]@{Domain=$awDomainName;ServerQueried=$awServer;Group=$awGroup.Name;GroupSid=$awGroupSid;Recursive=$true;ExpectedComputerSids=$awExpected;Computers=@($awComputers|Sort-Object Sid);TargetSidsMatchPinnedPlan=$awSame;DisabledComputerCount=$awDisabled;OtherMemberCount=($awMembers.Count-$awComputers.Count)}
  $awGpo=Get-GPO -Guid $awGpoId -Domain $awDomainName -Server $awServer
  $awOwnerSid=[Security.Principal.NTAccount]::new([string]$awGpo.Owner).Translate([Security.Principal.SecurityIdentifier]).Value
  $awText=Get-GPOReport -Guid $awGpoId -Domain $awDomainName -Server $awServer -ReportType Xml
  if($awText.IndexOf('<!DOCTYPE',[StringComparison]::OrdinalIgnoreCase) -ge 0){throw 'GPO_REPORT_DTD_REJECTED'}
  $awXml=New-Object Xml.XmlDocument;$awXml.XmlResolver=$null;$awXml.LoadXml($awText)
  if($null -eq $awXml.SelectSingleNode("/*[local-name()='GPO']")){throw 'GPO_REPORT_SHAPE_INVALID'}
  $awLinks=@($awXml.SelectNodes("/*[local-name()='GPO']/*[local-name()='LinksTo']")|ForEach-Object {$_.InnerText})
  $awSettings=$awXml.SelectNodes("/*[local-name()='GPO']/*[local-name()='Computer' or local-name()='User']/*[local-name()='ExtensionData']").Count
  $awVersions=@(foreach($awKind in @('Computer','User')){
   foreach($awVersionName in @('VersionDirectory','VersionSysvol')){
    $awNode=$awXml.SelectSingleNode("/*[local-name()='GPO']/*[local-name()='$awKind']/*[local-name()='$awVersionName']")
    $awValue=$null
    if($null -ne $awNode){$awValue=$awNode.InnerText}
    [pscustomobject]@{Section=$awKind;Field=$awVersionName;Value=$awValue}
    if($null -eq $awNode -or $awValue -cne '0'){$awErrors.Add('GPO_VERSION_REQUIRES_REVIEW')}
   }
  })
  $awPermissions=@(Get-GPPermission -Guid $awGpoId -All -Domain $awDomainName -Server $awServer|ForEach-Object {[pscustomobject]@{Sid=$_.Trustee.Sid.Value;Permission=$_.Permission.ToString()}}|Sort-Object Sid,Permission)
  $awExpectedPermissions=@(
   ($awGroupSid+'|GpoApply'),($awServiceSid+'|GpoEdit'),($awDomainSid+'-512|GpoEditDeleteModifySecurity'),($awDomainSid+'-519|GpoEditDeleteModifySecurity'),'S-1-5-11|GpoRead','S-1-5-9|GpoRead','S-1-5-18|GpoEditDeleteModifySecurity'
  )|Sort-Object
  $awPermissionShape=@($awPermissions|ForEach-Object {$_.Sid+'|'+$_.Permission}|Sort-Object)
  $awPermissionMatches=(($awExpectedPermissions -join ';') -ceq ($awPermissionShape -join ';'))
  $awGpc=Get-ADObject -Identity ('CN={'+$awGpoId.ToString('D')+'},CN=Policies,CN=System,'+$awDomain.DistinguishedName) -Properties gPCFileSysPath -Server $awServer
  $awSysvolPaths=@(foreach($awPath in $awGpc.gPCFileSysPath){[string]$awPath})
  $awExpectedSysvol='\\vizyonveri.local\SYSVOL\vizyonveri.local\Policies\{'+$awGpoId.ToString('D')+'}'
  $awSysvolPathMatches=($awSysvolPaths.Count -eq 1 -and $awSysvolPaths[0].TrimEnd('\') -ieq $awExpectedSysvol)
  if(-not $awSysvolPathMatches){throw 'GPO_SYSVOL_PATH_MISMATCH'}
  $awRoot='\\dc01.vizyonveri.local\SYSVOL\vizyonveri.local\Policies\{'+$awGpoId.ToString('D')+'}'
  $awRootInfo=Get-Item -LiteralPath $awRoot -Force
  if(-not $awRootInfo.PSIsContainer -or ($awRootInfo.Attributes -band [IO.FileAttributes]::ReparsePoint)){throw 'GPO_SYSVOL_DIRECTORY_REQUIRED'}
  $awAcl=Get-Acl -LiteralPath $awRoot
  $awRules=@($awAcl.GetAccessRules($true,$true,[Security.Principal.SecurityIdentifier])|ForEach-Object {[pscustomobject]@{Sid=$_.IdentityReference.Value;Type=$_.AccessControlType.ToString();Rights=$_.FileSystemRights.ToString();Inherited=$_.IsInherited;Inheritance=$_.InheritanceFlags.ToString();Propagation=$_.PropagationFlags.ToString()}})
  $awRootEntries=@(Get-ChildItem -LiteralPath $awRoot -Force|Select-Object Name,PSIsContainer,Length)
  $awIdentityMatches=($awGpo.DisplayName -ceq 'AuthWire-Managed-Deployment-4c23eebe' -and $awGpo.Description -ceq $awMarker -and $awOwnerSid -ceq ($awDomainSid+'-512'))
  if(-not $awIdentityMatches){$awErrors.Add('GPO_IDENTITY_OR_OWNERSHIP_CHANGED')}
  if(-not $awPermissionMatches){$awErrors.Add('GPO_PERMISSION_METADATA_CHANGED')}
  if($awLinks.Count -ne 0 -or $awSettings -ne 0){$awErrors.Add('GPO_LINKED_OR_SETTINGS_PRESENT')}
  if($awGpo.GpoStatus.ToString() -cne 'AllSettingsEnabled'){$awErrors.Add('GPO_STATUS_CHANGED')}
  $awResult.Gpo=[ordered]@{Id=$awGpoId.ToString('D');Name=$awGpo.DisplayName;OwnershipMarkerMatches=($awGpo.Description -ceq $awMarker);OwnerSid=$awOwnerSid;Status=$awGpo.GpoStatus.ToString();LinkedPaths=$awLinks;SettingsExtensionCount=$awSettings;Versions=$awVersions;Permissions=$awPermissions;PermissionMetadataMatchesPreviousScope=$awPermissionMatches;SysvolPathMatches=$awSysvolPathMatches;SysvolRootEntries=$awRootEntries;SysvolRootOwnerSid=$awAcl.GetOwner([Security.Principal.SecurityIdentifier]).Value;SysvolRootDaclProtected=$awAcl.AreAccessRulesProtected;SysvolRootRules=$awRules;SysvolDescendantsEnumerated=$false;EffectiveGmsaWriteAccessTested=$false}
  $awProtected=Get-GPO -Guid $awProtectedId -Domain $awDomainName -Server $awServer
  $awResult.ProtectedTrustGpo=[ordered]@{Id=$awProtected.Id.ToString('D');Name=$awProtected.DisplayName;Status=$awProtected.GpoStatus.ToString();DefinitionsChangedByTool=$false;HistoricalEqualityCompared=$false}
  if($awProtected.DisplayName -cne 'AuthWire-Pilot-Trust'){$awErrors.Add('PROTECTED_TRUST_GPO_IDENTITY_CHANGED')}
  $awAgain=@(Get-ADGroupMember -Identity $awGroupSid -Recursive -Server $awServer|ForEach-Object {$_.ObjectGUID.ToString('D')}|Sort-Object)
  $awBefore=@($awMembers|ForEach-Object {$_.ObjectGUID.ToString('D')}|Sort-Object)
  if(($awAgain -join '|') -cne ($awBefore -join '|')){$awErrors.Add('DIRECTORY_MEMBERS_CHANGED_DURING_READ')}
 }catch{
  $awResult.OperationError=[ordered]@{Type=$_.Exception.GetType().FullName;Message=$_.Exception.Message}
  $awErrors.Add('READONLY_INSPECTION_INCOMPLETE')
 }
 $awResult.CompletedUtc=[DateTime]::UtcNow.ToString('o')
 $awResult.Blockers=@($awErrors|Sort-Object -Unique)
 $awResult.ReadyForNextReview=($awErrors.Count -eq 0)
 [pscustomobject]$awResult|ConvertTo-Json -Depth 10
}
