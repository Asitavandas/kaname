# Combined scope only: public candidate validation and bounded SYSVOL reads.
Set-StrictMode -Version 2
function Get-AuthWireCombinedScopeContentTarget($Target){
 $v=[ordered]@{}
 foreach($n in @('candidate_id','network_candidate_id','plan_id','plan_version','gpo_id','approval_sha256','network_manifest_sha256','manifest_sha256','draft_sha256','dependency_sha256','publisher_thumbprint','machine_profile_id','machine_profile_version','domain','root_thumbprint','group_sid')){$v[$n]=$Target.$n}
 return [pscustomobject]$v
}
function Assert-AuthWireCombinedScopeTarget($Target){
 Assert-AuthWireCandidateFields $Target @('candidate_id','network_candidate_id','plan_id','plan_version','gpo_id','approval_sha256','network_manifest_sha256','manifest_sha256','draft_sha256','dependency_sha256','publisher_thumbprint','machine_profile_id','machine_profile_version','domain','root_thumbprint','group_sid','content_result_sha256','target_sids_sha256','target_count')
 Assert-AuthWireCombinedJobTarget (Get-AuthWireCombinedScopeContentTarget $Target)
 foreach($n in @('content_result_sha256','target_sids_sha256')){if($Target.$n -isnot [string] -or $Target.$n -cnotmatch '\A[0-9a-f]{64}\z'){throw 'COMBINED_SCOPE_TARGET_REJECTED'}}
 if($Target.target_count -isnot [int] -or $Target.target_count -lt 1 -or $Target.target_count -gt 512){throw 'COMBINED_SCOPE_TARGET_REJECTED'}
}
function Get-AuthWireCombinedScopeContext($Target,[hashtable]$Binding,[string]$Publisher,[string]$BaseUrl){
 Assert-AuthWireCombinedScopeTarget $Target
 $content=Get-AuthWireCombinedScopeContentTarget $Target
 if(-not (Test-AuthWireJobCombinedContent $content $Binding $Publisher $BaseUrl)){throw 'SCOPE_CONTENT_REJECTED'}
 $network=[pscustomobject]@{candidate_id=$Target.network_candidate_id;plan_id=$Target.plan_id;plan_version=$Target.plan_version;gpo_id=$Target.gpo_id;approval_sha256=$Target.approval_sha256;manifest_sha256=$Target.network_manifest_sha256;dependency_sha256=$Target.dependency_sha256;target_sids_sha256=$Target.target_sids_sha256;target_count=$Target.target_count}
 $approval=Get-AuthWireScopeContext $network $Binding $Publisher
 if($approval.group_sid -cne $Target.group_sid -or $approval.domain -cne $Target.domain -or $approval.machine_profile_id -cne $Target.machine_profile_id -or $approval.machine_profile_version -ne $Target.machine_profile_version){throw 'SCOPE_CONTENT_REJECTED'}
 return [pscustomobject]@{Approval=$approval;NetworkTarget=$network}
}
function Read-AuthWireCombinedSysvolTree([string]$Root){
 # The caller constructs Root from its verified domain/PDC and pinned GPO GUID.
 $item=Get-Item -LiteralPath $Root -Force -ErrorAction Stop
 if(-not $item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)){throw 'SCOPE_GPO_CHANGED'}
 $children=@(Get-ChildItem -LiteralPath $Root -Force -ErrorAction Stop)
 if($children.Count -ne 4){throw 'SCOPE_GPO_CHANGED'}
 $names=@($children|ForEach-Object {$_.Name.ToLowerInvariant()}|Sort-Object -CaseSensitive)
 if(($names -join ';') -cne 'gpo.cmt;gpt.ini;machine;user'){throw 'SCOPE_GPO_CHANGED'}
 $rows=@()
 foreach($child in @($children|Sort-Object Name -CaseSensitive)){
  if($child.Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'SCOPE_GPO_CHANGED'}
  $name=$child.Name.ToLowerInvariant();$hash='';$length=0
  if($name -in @('machine','user')){
   if(-not $child.PSIsContainer -or @(Get-ChildItem -LiteralPath $child.FullName -Force -ErrorAction Stop).Count -ne 0){throw 'SCOPE_GPO_CHANGED'}
  }else{
   if($child.PSIsContainer -or $child.Length -gt 4096 -or $child.Length -lt 1){throw 'SCOPE_GPO_CHANGED'}
   $bytes=Read-AuthWireCandidateBytes $child.FullName 4096;$length=$bytes.Length
   $hash=Get-AuthWireCandidateHash $bytes
   if($name -ceq 'gpt.ini'){
    if($bytes.Length -ge 2 -and $bytes[0] -eq 255 -and $bytes[1] -eq 254){$text=[Text.UnicodeEncoding]::new($false,$true,$true).GetString($bytes,2,$bytes.Length-2)}
    else{$text=[Text.UTF8Encoding]::new($false,$true).GetString($bytes).TrimStart([char]0xfeff)}
    if([regex]::Matches($text,'(?im)^\[General\]\r?$').Count -ne 1 -or [regex]::Matches($text,'(?im)^Version=0\r?$').Count -ne 1 -or [regex]::Matches($text,'(?im)^Version=').Count -ne 1 -or [regex]::Matches($text,'(?m)^\[').Count -ne 1){throw 'SCOPE_GPO_CHANGED'}
   }
  }
  $acl=Get-Acl -LiteralPath $child.FullName -ErrorAction Stop
  $rows+=,[pscustomobject][ordered]@{Path=$name;Directory=[bool]$child.PSIsContainer;Length=$length;Sha256=$hash;Sddl=$acl.Sddl}
 }
 return @($rows)
}
function Get-AuthWireCombinedSysvolTree($Approval,$Target,[hashtable]$Binding){
 $domain=Get-ADDomain -Identity $Approval.domain -Server $Approval.domain -ErrorAction Stop
 $sid=$Binding.service_sid.Substring(0,$Binding.service_sid.LastIndexOf('-'));$server=[string]$domain.PDCEmulator
 if($domain.DNSRoot -cne $Approval.domain -or $domain.DomainSID.Value -cne $sid -or $server -cnotmatch '\A[a-z0-9.-]{1,253}\z' -or -not $server.EndsWith('.'+$Approval.domain,[StringComparison]::Ordinal)){throw 'SCOPE_DIRECTORY_CHANGED'}
 $root='\\'+$server+'\SYSVOL\'+$Approval.domain+'\Policies\{'+$Target.gpo_id+'}'
 return @(Read-AuthWireCombinedSysvolTree $root)
}
