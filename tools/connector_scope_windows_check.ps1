# Native WinPS 5.1 pure scope validation and bounded process fixture; no AD writes.
$ErrorActionPreference='Stop';Set-StrictMode -Version 2
$root=Join-Path $PSScriptRoot '..\windows\connector'
foreach($p in Get-ChildItem -LiteralPath $root -Filter '*.ps1'){
 $tokens=$null;$errors=$null;$null=[Management.Automation.Language.Parser]::ParseFile($p.FullName,[ref]$tokens,[ref]$errors)
 if($errors.Count){throw ($p.Name+': '+($errors|Out-String))}
}
. (Join-Path $root 'Test-AuthWireDeploymentCandidate.ps1') -LibraryOnly
. (Join-Path $root 'Invoke-AuthWireConnectorProbeJob.ps1')
. (Join-Path $root 'Invoke-AuthWireCandidateJob.ps1')
. (Join-Path $root 'DeploymentScope.ps1')
. (Join-Path $root 'Invoke-AuthWireScopeJob.ps1')
$script:checks=0
function Check($ok,[string]$name){if(-not $ok){throw ('SCOPE_FIXTURE:'+ $name)};$script:checks++}
function Reject([scriptblock]$action,[string]$name){$failed=$false;try{& $action|Out-Null}catch{$failed=$true};Check $failed $name}
$d='S-1-5-21-111-222-333'
$b=@{service_sid=$d+'-1648';connector_id='4c23eebe-0715-46d1-88ee-a2e96ad7ee46';host_guid='0fa4143f-aae3-4bc3-9cd3-db8a1de24acd';host_fqdn='dc01.lab.example'}
$a=[pscustomobject]@{group_sid=$d+'-1647';protected_gpo_id='e5a9ab39-3709-49cb-837a-0208d2eb3b12';domain='lab.example'}
$rows=@(1..200|ForEach-Object {[pscustomobject][ordered]@{Sid=$d+'-'+(2000+$_);Guid=[guid]::NewGuid().ToString('D');Enabled=$true}})
$t=[pscustomobject]@{candidate_id=[guid]::NewGuid().ToString('D');plan_id=[guid]::NewGuid().ToString('D');plan_version=1;gpo_id='8c6808fd-a382-4bf2-9c9c-d9e1d46082a3';approval_sha256='a'*64;manifest_sha256='b'*64;dependency_sha256='c'*64;target_count=200;target_sids_sha256=(Get-AuthWireScopeSidHash @($rows.Sid))}
$v=[pscustomobject][ordered]@{Computers=$rows;GpoId=$t.gpo_id;GpoName='AuthWire-Managed-Deployment-4c23eebe';Marker=('AuthWireDeployment:v1;instance='+$b.connector_id+';host='+$b.host_guid+';service='+$b.service_sid+';scope='+$a.group_sid);OwnerSid=$d+'-512';Status='AllSettingsEnabled';LinkCount=0;SettingsCount=0;Versions=@('0','0','0','0');Permissions=@(($d+'-512|GpoEditDeleteModifySecurity'),($d+'-519|GpoEditDeleteModifySecurity'),'S-1-5-18|GpoEditDeleteModifySecurity','S-1-5-11|GpoRead','S-1-5-9|GpoRead',($b.service_sid+'|GpoEdit'),($a.group_sid+'|GpoApply'))|Sort-Object -CaseSensitive;RootOwnerSid=$d+'-512';RootProtected=$true;RootRules=@('S-1-3-0|Allow|2032127|3|2|0','S-1-5-18|Allow|2032127|3|0|0',($d+'-512|Allow|2032127|3|0|0'),($d+'-519|Allow|2032127|3|0|0'),'S-1-5-9|Allow|1179817|3|0|0','S-1-5-11|Allow|1179817|3|0|0',($a.group_sid+'|Allow|1179817|3|0|0'),($b.service_sid+'|Allow|1180159|3|0|0'))|Sort-Object -CaseSensitive;RootEntries=@('gpo.cmt|0','gpt.ini|0','machine|1','user|1')}
Check (Test-AuthWireScopeData $v $a $t $b) 'full 200-computer snapshot'
Check ((Get-AuthWireScopeSidHash @($rows.Sid|Sort-Object -Descending)) -ceq $t.target_sids_sha256) 'ordinal SID order'
foreach($field in @('GpoId','GpoName','Marker','OwnerSid','Status','RootOwnerSid')){$old=$v.$field;try{$v.$field='changed';Reject {Test-AuthWireScopeData $v $a $t $b} $field}finally{$v.$field=$old}}
foreach($field in @('LinkCount','SettingsCount')){try{$v.$field=1;Reject {Test-AuthWireScopeData $v $a $t $b} $field}finally{$v.$field=0}}
foreach($field in @('Versions','Permissions','RootRules','RootEntries')){$old=$v.$field;try{$v.$field=@('changed');Reject {Test-AuthWireScopeData $v $a $t $b} $field}finally{$v.$field=$old}}
try{$v.RootProtected=$false;Reject {Test-AuthWireScopeData $v $a $t $b} 'unprotected root'}finally{$v.RootProtected=$true}
try{$rows[199].Enabled=$false;Reject {Test-AuthWireScopeData $v $a $t $b} 'disabled account outside first twenty'}finally{$rows[199].Enabled=$true}
$old=$rows[199].Sid;try{$rows[199].Sid=$rows[0].Sid;Reject {Test-AuthWireScopeData $v $a $t $b} 'duplicate SID'}finally{$rows[199].Sid=$old}
try{$t.target_count=20;Reject {Test-AuthWireScopeData $v $a $t $b} 'preview truncation'}finally{$t.target_count=200}
foreach($count in @(0,513)){$old=$t.target_count;try{$t.target_count=$count;Reject {Assert-AuthWireScopeTarget $t} 'target bound'}finally{$t.target_count=$old}}
$t|Add-Member NoteProperty path 'C:\evil';Reject {Assert-AuthWireScopeTarget $t} 'arbitrary request field';$t.PSObject.Properties.Remove('path')
# Directory traversal uses typed RIDs/GUID bytes, includes nested and primary groups.
function Get-ADDomain{param($Identity,$Server,$ErrorAction)[pscustomobject]@{DNSRoot='lab.example';DomainSID=[pscustomobject]@{Value=$d};PDCEmulator='dc01.lab.example';DistinguishedName='DC=lab,DC=example'}}
$script:filter='';$script:groupCalls=0
function Get-ADComputer{param($Identity,$Server,$Properties,$ErrorAction,$LDAPFilter,$SearchBase,$SearchScope,$ResultSetSize,$ResultPageSize)
 if($LDAPFilter){$script:filter=$LDAPFilter;if($ResultSetSize -ne 513 -or $ResultPageSize -ne 200){throw 'wrong limits'};throw 'FIXTURE_SEARCH_CAPTURED'}
 [pscustomobject]@{ObjectGUID=[guid]$b.host_guid;DNSHostName=$b.host_fqdn}
}
function Get-ADGroup{param($Identity,$Server,$Properties,$ErrorAction)$script:groupCalls++;[pscustomobject]@{SID=[pscustomobject]@{Value=$Identity};GroupCategory='Security'}}
function Get-ADGroupMember{param($Identity,$Server,$ErrorAction)
 if($Identity -ceq $a.group_sid){[pscustomobject]@{objectClass='group';SID=[pscustomobject]@{Value=$d+'-1700'}}}
 else{[pscustomobject]@{objectClass='computer';ObjectGUID=[guid]$rows[0].Guid}}
}
Reject {Get-AuthWireScopeData $a $t $b} 'controlled directory search stop'
Check ($script:groupCalls -eq 2 -and $script:filter.Contains('(primaryGroupID=1647)') -and $script:filter.Contains('(primaryGroupID=1700)') -and $script:filter.Contains('(objectGUID=\')) 'nested primary group filter'
# Exercise the complete snapshot assembler with typed AD/GPO and NTFS fixtures.
# This is deliberately not a real forest or customer gMSA acceptance.
function Get-ADComputer{param($Identity,$Server,$Properties,$ErrorAction,$LDAPFilter,$SearchBase,$SearchScope,$ResultSetSize,$ResultPageSize)
 if($LDAPFilter){return $rows|ForEach-Object {[pscustomobject]@{SID=[pscustomobject]@{Value=$_.Sid};ObjectGUID=[guid]$_.Guid;Enabled=$_.Enabled}}}
 [pscustomobject]@{ObjectGUID=[guid]$b.host_guid;DNSHostName=$b.host_fqdn}
}
function Get-GPO{param($Guid,$Domain,$Server,$ErrorAction)[pscustomobject]@{Id=[guid]$t.gpo_id;DisplayName=$v.GpoName;Description=$v.Marker;GpoStatus='AllSettingsEnabled';Owner=([Security.Principal.SecurityIdentifier]::new('S-1-5-32-544').Translate([Security.Principal.NTAccount]).Value)}}
function Get-GPOReport{param($Guid,$Domain,$Server,$ReportType,$ErrorAction)'<GPO xmlns="http://www.microsoft.com/GroupPolicy/Settings"><Computer><VersionDirectory>0</VersionDirectory><VersionSysvol>0</VersionSysvol></Computer><User><VersionDirectory>0</VersionDirectory><VersionSysvol>0</VersionSysvol></User></GPO>'}
function Get-GPPermission{param($Guid,$Domain,$Server,[switch]$All,$ErrorAction)foreach($row in $v.Permissions){$parts=$row.Split('|');[pscustomobject]@{Trustee=[pscustomobject]@{Sid=[pscustomobject]@{Value=$parts[0]}};Permission=$parts[1]}}}
function Get-ADObject{param($Identity,$Server,$Properties,$ErrorAction)[pscustomobject]@{ObjectClass='groupPolicyContainer';gPCFileSysPath=('\\lab.example\SYSVOL\lab.example\Policies\{'+$t.gpo_id+'}')}}
function Get-Item{param($LiteralPath,[switch]$Force,$ErrorAction)[pscustomobject]@{PSIsContainer=$true;Attributes=[IO.FileAttributes]::Directory}}
$script:fixtureAcl=[Security.AccessControl.DirectorySecurity]::new()
$script:fixtureAcl.SetSecurityDescriptorSddlForm(('O:'+$d+'-512G:'+$d+'-513D:P(A;OICIIO;FA;;;CO)(A;OICI;FA;;;SY)(A;OICI;FA;;;'+$d+'-512)(A;OICI;FA;;;'+$d+'-519)(A;OICI;0x1200a9;;;S-1-5-9)(A;OICI;0x1200a9;;;S-1-5-11)(A;OICI;0x1200a9;;;'+$a.group_sid+')(A;OICI;0x1201ff;;;'+$b.service_sid+')'))
function Get-Acl{param($LiteralPath,$ErrorAction)return $script:fixtureAcl}
function Get-ChildItem{param($LiteralPath,[switch]$Force,$ErrorAction)foreach($n in @('Machine','User','GPO.cmt','GPT.INI')){[pscustomobject]@{Name=$n;PSIsContainer=($n -in @('Machine','User'));Attributes=[IO.FileAttributes]::Normal;Length=1}}}
$assembled=Get-AuthWireScopeData $a $t $b
Check ($assembled.Computers.Count -eq 200 -and $assembled.OwnerSid -ceq 'S-1-5-32-544' -and $assembled.RootOwnerSid -ceq ($d+'-512')) 'complete typed snapshot assembly'
Check (($assembled.Versions -join ';') -ceq '0;0;0;0' -and $assembled.SettingsCount -eq 0 -and $assembled.LinkCount -eq 0) 'namespaced GPO XML extraction'
Check (($assembled.RootEntries -join ';') -ceq ($v.RootEntries -join ';') -and $assembled.RootRules.Count -eq 8 -and $assembled.Permissions.Count -eq 7) 'root entry and ACL extraction'
$assembled.OwnerSid=$v.OwnerSid
Check (Test-AuthWireScopeData $assembled $a $t $b) 'assembled real NTFS rule objects match exact pure policy'
foreach($n in @('Get-Item','Get-Acl','Get-ChildItem')){Remove-Item ('Function:\'+$n)}
# Native .NET process drains: finite normal output, timeout, long unbroken stdout,
# stderr, exit code and AllSigned refusal all exercise the production helper.
Initialize-AuthWireScopeProcess
$exe=Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
$r=[AuthWire.Connector.ScopeProcessV1]::Run($exe,'-NoProfile -NonInteractive -Command "[Console]::Write(''ok'')"',10000)
Check ($r.ExitCode -eq 0 -and $r.Output -ceq 'ok' -and -not $r.Truncated -and -not $r.TimedOut) 'normal child'
$r=[AuthWire.Connector.ScopeProcessV1]::Run($exe,'-NoProfile -NonInteractive -Command "Start-Sleep -Seconds 30"',500)
Check $r.TimedOut 'hung child killed'
$r=[AuthWire.Connector.ScopeProcessV1]::Run($exe,'-NoProfile -NonInteractive -Command "[Console]::Write((''x''*20000))"',10000)
Check ($r.Truncated -and $r.Output.Length -le 8192) 'unbroken oversized stdout bounded'
$r=[AuthWire.Connector.ScopeProcessV1]::Run($exe,'-NoProfile -NonInteractive -Command "[Console]::Error.Write(''failed'')"',10000)
Check ($r.ExitCode -ne 0) 'stderr fails closed'
$r=[AuthWire.Connector.ScopeProcessV1]::Run($exe,'-NoProfile -NonInteractive -Command "exit 5"',10000)
Check ($r.ExitCode -eq 5) 'exit code retained'
$temp=Join-Path $env:TEMP ('aw-scope-unsigned-'+[guid]::NewGuid().ToString('N')+'.ps1')
try{
 [IO.File]::WriteAllText($temp,'throw ''UNSIGNED_MUST_NOT_RUN''')
 $r=[AuthWire.Connector.ScopeProcessV1]::Run($exe,('-NoProfile -NonInteractive -ExecutionPolicy AllSigned -File "'+$temp+'"'),10000)
 Check ($r.ExitCode -ne 0 -and -not $r.Output.Contains('UNSIGNED_MUST_NOT_RUN')) 'unsigned child refused'
}finally{Remove-Item -LiteralPath $temp -Force}
Write-Output ('AUTHWIRE_SCOPE_WINDOWS_OK checks='+$script:checks+' customer_ad_tested=false')
