# Fixed read-only directory/GPO reader. No credentials, signer key or write cmdlets.
Set-StrictMode -Version 2
function Assert-AuthWireScopeTarget($Target){
 Assert-AuthWireCandidateFields $Target @('candidate_id','plan_id','plan_version','gpo_id','approval_sha256','manifest_sha256','dependency_sha256','target_sids_sha256','target_count')
 foreach($n in @('candidate_id','plan_id','gpo_id')){Assert-AuthWireCandidateGuid $Target.$n}
 foreach($n in @('approval_sha256','manifest_sha256','dependency_sha256','target_sids_sha256')){if($Target.$n -isnot [string] -or $Target.$n -cnotmatch '\A[0-9a-f]{64}\z'){throw 'SCOPE_TARGET_REJECTED'}}
 if($Target.plan_version -isnot [int] -or $Target.plan_version -lt 1 -or $Target.target_count -isnot [int] -or $Target.target_count -lt 1 -or $Target.target_count -gt 512){throw 'SCOPE_TARGET_REJECTED'}
}
function Get-AuthWireScopeSidHash([string[]]$Sids){
 $sorted=[string[]]@($Sids);[Array]::Sort($sorted,[StringComparer]::Ordinal)
 return (Get-AuthWireCandidateHash ([Text.Encoding]::ASCII.GetBytes("AuthWireDeploymentTargetsV1`n"+($sorted -join "`n")+"`n")))
}
function Get-AuthWireScopeContext($Target,[hashtable]$Binding,[string]$Publisher){
 Assert-AuthWireScopeTarget $Target
 $small=[ordered]@{};foreach($n in @('candidate_id','plan_id','plan_version','gpo_id','approval_sha256','manifest_sha256','dependency_sha256')){$small[$n]=$Target.$n}
 if(-not (Test-AuthWireJobCandidateContent ([pscustomobject]$small) $Binding $Publisher)){throw 'SCOPE_CONTENT_REJECTED'}
 $root=Join-Path ([Environment]::GetFolderPath('CommonApplicationData')) ('AuthWire-DeploymentCandidates-'+([guid]$Binding.connector_id).ToString('N'))
 $prefix=([guid]$Target.plan_id).ToString('N')+'-v'+$Target.plan_version+'-';$found=@()
 $items=@(Get-ChildItem -LiteralPath $root -Force);if($items.Count -gt 32){throw 'SCOPE_CONTENT_REJECTED'}
 foreach($item in $items){
  if($item.PSIsContainer -and $item.Name -cmatch ('\A'+[regex]::Escape($prefix)+'[0-9a-f]{64}\z')){
   Assert-AuthWireCandidateAcl $item.FullName $Binding.service_sid -Directory
   $p=Join-Path $item.FullName 'approval.json';Assert-AuthWireCandidateAcl $p $Binding.service_sid
   if((Get-AuthWireCandidateHash (Read-AuthWireCandidateBytes $p 8192)) -ceq $Target.approval_sha256){$found+=,(Read-AuthWireCandidateApproval $p $Target.approval_sha256).Value}
  }
 }
 if($found.Count -ne 1){throw 'SCOPE_CONTENT_REJECTED'}
 $a=$found[0]
 if($a.domain -isnot [string] -or -not $Binding.host_fqdn.EndsWith('.'+$a.domain,[StringComparison]::Ordinal) -or $a.gpo_id -cne $Target.gpo_id -or $a.gpo_id -ceq $a.protected_gpo_id -or $a.connector_id -cne $Binding.connector_id -or $a.service_sid -cne $Binding.service_sid){throw 'SCOPE_CONTENT_REJECTED'}
 return $a
}
function Get-AuthWireScopeData($Approval,$Target,[hashtable]$Binding){
 $domain=Get-ADDomain -Identity $Approval.domain -Server $Approval.domain -ErrorAction Stop
 $domainSid=$Binding.service_sid.Substring(0,$Binding.service_sid.LastIndexOf('-'))
 if($domain.DNSRoot -cne $Approval.domain -or $domain.DomainSID.Value -cne $domainSid){throw 'SCOPE_DIRECTORY_CHANGED'}
 $server=[string]$domain.PDCEmulator
 if($server -cnotmatch '\A[a-z0-9.-]{1,253}\z' -or -not $server.EndsWith('.'+$Approval.domain,[StringComparison]::Ordinal)){throw 'SCOPE_DIRECTORY_CHANGED'}
 $hostObject=Get-ADComputer -Identity ([guid]$Binding.host_guid) -Server $server -Properties DNSHostName -ErrorAction Stop
 if($hostObject.ObjectGUID.ToString('D') -cne $Binding.host_guid -or $hostObject.DNSHostName -ine $Binding.host_fqdn){throw 'SCOPE_DIRECTORY_CHANGED'}
 if($Approval.group_sid -cnotmatch ('\A'+[regex]::Escape($domainSid)+'-[1-9][0-9]{0,9}\z')){throw 'SCOPE_DIRECTORY_CHANGED'}
 $queue=New-Object 'System.Collections.Generic.Queue[string]';$queue.Enqueue($Approval.group_sid)
 $groups=@{};$computerGuids=@{};$edges=0
 while($queue.Count){
  $sid=$queue.Dequeue();if($groups.ContainsKey($sid)){continue}
  if($groups.Count -ge 128 -or $sid -cnotmatch ('\A'+[regex]::Escape($domainSid)+'-[1-9][0-9]{0,9}\z')){throw 'SCOPE_DIRECTORY_CHANGED'}
  $group=Get-ADGroup -Identity $sid -Server $server -Properties GroupCategory -ErrorAction Stop
  if($group.SID.Value -cne $sid -or $group.GroupCategory.ToString() -cne 'Security'){throw 'SCOPE_DIRECTORY_CHANGED'}
  $groups[$sid]=$true
  $members=@(Get-ADGroupMember -Identity $sid -Server $server -ErrorAction Stop);$edges+=$members.Count
  if($edges -gt 4096){throw 'SCOPE_DIRECTORY_CHANGED'}
  foreach($member in $members){
   if($member.objectClass -ceq 'group'){$queue.Enqueue($member.SID.Value)}
   elseif($member.objectClass -ceq 'computer'){$computerGuids[$member.ObjectGUID.ToString('D')]=$true}
   elseif($member.objectClass -cne 'user'){throw 'SCOPE_DIRECTORY_CHANGED'}
  }
  if($computerGuids.Count -gt 512){throw 'SCOPE_DIRECTORY_CHANGED'}
 }
 # AD groupMember does not include primaryGroupID membership. Include every
 # visited group's RID in the same bounded computer search.
 $terms=@(foreach($sid in $groups.Keys){'(primaryGroupID='+$sid.Substring($sid.LastIndexOf('-')+1)+')'})
 foreach($id in $computerGuids.Keys){$escaped=([guid]$id).ToByteArray()|ForEach-Object {'\'+$_.ToString('x2')};$terms+=('(objectGUID='+($escaped -join '')+')')}
 $filter='(|'+($terms -join '')+')'
 if($filter.Length -gt 40000){throw 'SCOPE_DIRECTORY_CHANGED'}
 $computers=@(Get-ADComputer -LDAPFilter $filter -SearchBase $domain.DistinguishedName -SearchScope Subtree -Server $server -Properties Enabled -ResultSetSize 513 -ResultPageSize 200 -ErrorAction Stop)
 if($computers.Count -lt 1 -or $computers.Count -gt 512){throw 'SCOPE_DIRECTORY_CHANGED'}
 $rows=@(foreach($computer in $computers){[pscustomobject][ordered]@{Sid=$computer.SID.Value;Guid=$computer.ObjectGUID.ToString('D');Enabled=[bool]$computer.Enabled}})
 foreach($id in $computerGuids.Keys){if(@($rows|Where-Object {$_.Guid -ceq $id}).Count -ne 1){throw 'SCOPE_DIRECTORY_CHANGED'}}
 $gpo=Get-GPO -Guid ([guid]$Target.gpo_id) -Domain $Approval.domain -Server $server -ErrorAction Stop
 $report=Get-GPOReport -Guid ([guid]$Target.gpo_id) -Domain $Approval.domain -Server $server -ReportType Xml -ErrorAction Stop
 if($report.Length -gt 1048576 -or $report.IndexOf('<!DOCTYPE',[StringComparison]::OrdinalIgnoreCase) -ge 0){throw 'SCOPE_GPO_CHANGED'}
 $xml=New-Object Xml.XmlDocument;$xml.XmlResolver=$null;$xml.LoadXml($report)
 if($null -eq $xml.SelectSingleNode("/*[local-name()='GPO']")){throw 'SCOPE_GPO_CHANGED'}
 $versions=@(foreach($kind in @('Computer','User')){foreach($name in @('VersionDirectory','VersionSysvol')){
  $node=$xml.SelectSingleNode("/*[local-name()='GPO']/*[local-name()='$kind']/*[local-name()='$name']")
  if($null -eq $node){throw 'SCOPE_GPO_CHANGED'}
  $node.InnerText
 }})
 $permissions=@(Get-GPPermission -Guid ([guid]$Target.gpo_id) -Domain $Approval.domain -Server $server -All -ErrorAction Stop|ForEach-Object {$_.Trustee.Sid.Value+'|'+$_.Permission.ToString()}|Sort-Object -CaseSensitive)
 $dn='CN={'+$Target.gpo_id+'},CN=Policies,CN=System,'+$domain.DistinguishedName
 $gpc=Get-ADObject -Identity $dn -Server $server -Properties gPCFileSysPath -ErrorAction Stop
 $paths=@(foreach($path in $gpc.gPCFileSysPath){[string]$path})
 $expectedPath='\\'+$Approval.domain+'\SYSVOL\'+$Approval.domain+'\Policies\{'+$Target.gpo_id+'}'
 if($gpc.ObjectClass -cne 'groupPolicyContainer' -or $paths.Count -ne 1 -or $paths[0].TrimEnd('\') -ine $expectedPath){throw 'SCOPE_GPO_CHANGED'}
 $root='\\'+$server+'\SYSVOL\'+$Approval.domain+'\Policies\{'+$Target.gpo_id+'}'
 $item=Get-Item -LiteralPath $root -Force -ErrorAction Stop
 if(-not $item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)){throw 'SCOPE_GPO_CHANGED'}
 $acl=Get-Acl -LiteralPath $root -ErrorAction Stop
 $aclRows=@($acl.GetAccessRules($true,$true,[Security.Principal.SecurityIdentifier])|ForEach-Object {$_.IdentityReference.Value+'|'+$_.AccessControlType.ToString()+'|'+[int]$_.FileSystemRights+'|'+[int]$_.InheritanceFlags+'|'+[int]$_.PropagationFlags+'|'+[int]$_.IsInherited}|Sort-Object -CaseSensitive)
 $entries=@(Get-ChildItem -LiteralPath $root -Force -ErrorAction Stop)
 if($entries.Count -ne 4){throw 'SCOPE_GPO_CHANGED'}
 $entryRows=@(foreach($entry in $entries){
  if(($entry.Attributes -band [IO.FileAttributes]::ReparsePoint) -or (-not $entry.PSIsContainer -and $entry.Length -gt 4096)){throw 'SCOPE_GPO_CHANGED'}
  $entry.Name.ToLowerInvariant()+'|'+[int]$entry.PSIsContainer
 })|Sort-Object -CaseSensitive
 $owner=[Security.Principal.NTAccount]::new([string]$gpo.Owner).Translate([Security.Principal.SecurityIdentifier]).Value
 return [pscustomobject][ordered]@{
  Computers=@($rows|Sort-Object Sid -CaseSensitive);GpoId=$gpo.Id.ToString('D');GpoName=$gpo.DisplayName
  Marker=[string]$gpo.Description;OwnerSid=$owner;Status=$gpo.GpoStatus.ToString()
  LinkCount=$xml.SelectNodes("/*[local-name()='GPO']/*[local-name()='LinksTo']").Count
  SettingsCount=$xml.SelectNodes("/*[local-name()='GPO']/*[local-name()='Computer' or local-name()='User']/*[local-name()='ExtensionData']").Count
  Versions=$versions;Permissions=$permissions;RootOwnerSid=$acl.GetOwner([Security.Principal.SecurityIdentifier]).Value
  RootProtected=[bool]$acl.AreAccessRulesProtected;RootRules=$aclRows;RootEntries=$entryRows
 }
}
function Test-AuthWireScopeData($Data,$Approval,$Target,[hashtable]$Binding){
 $domainSid=$Binding.service_sid.Substring(0,$Binding.service_sid.LastIndexOf('-'))
 $sids=@($Data.Computers|ForEach-Object {$_.Sid})
 if($sids.Count -ne $Target.target_count -or @($sids|Select-Object -Unique).Count -ne $sids.Count -or
    @($Data.Computers|Where-Object {$_.Enabled -isnot [bool] -or -not $_.Enabled -or $_.Sid -cnotmatch ('\A'+[regex]::Escape($domainSid)+'-[1-9][0-9]{0,9}\z')}).Count -ne 0 -or
    (Get-AuthWireScopeSidHash $sids) -cne $Target.target_sids_sha256){throw 'SCOPE_DIRECTORY_CHANGED'}
 $expectedName='AuthWire-Managed-Deployment-'+([guid]$Binding.connector_id).ToString('D').Substring(0,8)
 $marker='AuthWireDeployment:v1;instance='+$Binding.connector_id+';host='+$Binding.host_guid+';service='+$Binding.service_sid+';scope='+$Approval.group_sid
 if($Data.GpoId -cne $Target.gpo_id -or $Data.GpoId -ceq $Approval.protected_gpo_id -or $Data.GpoName -cne $expectedName -or $Data.Marker -cne $marker -or $Data.OwnerSid -cne ($domainSid+'-512') -or $Data.Status -cne 'AllSettingsEnabled'){throw 'SCOPE_GPO_CHANGED'}
 $expected=@(($domainSid+'-512|GpoEditDeleteModifySecurity'),($domainSid+'-519|GpoEditDeleteModifySecurity'),'S-1-5-18|GpoEditDeleteModifySecurity','S-1-5-11|GpoRead','S-1-5-9|GpoRead',($Binding.service_sid+'|GpoEdit'),($Approval.group_sid+'|GpoApply'))|Sort-Object -CaseSensitive
 if(($Data.Permissions -join ';') -cne ($expected -join ';') -or $Data.LinkCount -ne 0 -or $Data.SettingsCount -ne 0 -or @($Data.Versions).Count -ne 4 -or @($Data.Versions|Where-Object {$_ -cne '0'}).Count){throw 'SCOPE_GPO_CHANGED'}
 $read=[int]([Security.AccessControl.FileSystemRights]::ReadAndExecute -bor [Security.AccessControl.FileSystemRights]::Synchronize)
 $write=$read -bor [int][Security.AccessControl.FileSystemRights]::Write -bor [int][Security.AccessControl.FileSystemRights]::DeleteSubdirectoriesAndFiles
 $rules=@('S-1-3-0|Allow|2032127|3|2|0','S-1-5-18|Allow|2032127|3|0|0',($domainSid+'-512|Allow|2032127|3|0|0'),($domainSid+'-519|Allow|2032127|3|0|0'),('S-1-5-9|Allow|'+$read+'|3|0|0'),('S-1-5-11|Allow|'+$read+'|3|0|0'),($Approval.group_sid+'|Allow|'+$read+'|3|0|0'),($Binding.service_sid+'|Allow|'+$write+'|3|0|0'))|Sort-Object -CaseSensitive
 if($Data.RootOwnerSid -cne ($domainSid+'-512') -or $Data.RootProtected -isnot [bool] -or -not $Data.RootProtected -or
    ($Data.RootRules -join ';') -cne ($rules -join ';') -or ($Data.RootEntries -join ';') -cne 'gpo.cmt|0;gpt.ini|0;machine|1;user|1'){throw 'SCOPE_GPO_CHANGED'}
 return $true
}
function Get-AuthWireScopeDataHash($Data){
 return (Get-AuthWireCandidateHash ([Text.UTF8Encoding]::new($false,$true).GetBytes(($Data|ConvertTo-Json -Depth 8 -Compress))))
}
