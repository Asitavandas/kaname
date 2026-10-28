# Read-only staging proposal. This module contains no writer or execution token.
Set-StrictMode -Version 2

function Get-AuthWireCombinedStagingNames {
 return @('README.txt','network-profiles.zip','network/README.txt','network/WiFi-EAP-TLS.xml','network/Wired-EAP-TLS.xml','network/issuer-ca.pem','network/manifest.json','network/plan.json','network/root-ca.pem','enrollment/AuthWire-Client.ps1','enrollment/Install-AuthWire.ps1','enrollment/README.txt','enrollment/SHA256SUMS.txt','enrollment/config.json','enrollment/https-trust.pem','enrollment/issuer-ca.pem','enrollment/root-ca.pem','original-draft.zip','signed-manifest.json','AuthWire-Combined-Manifest.ps1')
}

function Get-AuthWireCombinedStagingLedger($Target,[hashtable]$Binding) {
 # Signature/content and service identity are checked by the public preview
 # adapter before and after this bounded read. No request can supply a path.
 Assert-AuthWireCombinedScopeTarget $Target
 $template='ab1a11c68381006173518df77deeb0d32fc56e0b28cc260c42b7378c624be14a'
 $root=Join-Path ([Environment]::GetFolderPath('CommonApplicationData')) ('AuthWire-CombinedCandidates-'+([guid]$Binding.connector_id).ToString('N'))
 Assert-AuthWireCandidateAcl $root $Binding.service_sid -Directory
 $path=Join-Path $root ($Target.plan_id+'-v'+$Target.plan_version+'-'+$Target.draft_sha256+'-'+$template.Substring(0,16))
 Assert-AuthWireCandidateAcl $path $Binding.service_sid -Directory
 $manifestPath=Join-Path $path 'signed-manifest.json'
 Assert-AuthWireCandidateAcl $manifestPath $Binding.service_sid
 $manifestBytes=Read-AuthWireCandidateBytes $manifestPath 65536
 if((Get-AuthWireCandidateHash $manifestBytes) -cne $Target.manifest_sha256){throw 'STAGING_SOURCE_CHANGED'}
 $manifest=ConvertFrom-AuthWireCandidateJson $manifestBytes
 $names=Get-AuthWireCombinedStagingNames
 Assert-AuthWireCandidateFields $manifest.files @($names|Where-Object {$_ -cnotin @('signed-manifest.json','AuthWire-Combined-Manifest.ps1')})
 foreach($d in @('enrollment','network')){Assert-AuthWireCandidateAcl (Join-Path $path $d) $Binding.service_sid -Directory}
 $rows=@();$total=0L
 foreach($name in $names) {
  $file=Join-Path $path $name.Replace('/','\')
  Assert-AuthWireCandidateAcl $file $Binding.service_sid
  $before=Get-Item -LiteralPath $file -Force -ErrorAction Stop
  $sddl=(Get-Acl -LiteralPath $file -ErrorAction Stop).Sddl
  $bytes=Read-AuthWireCandidateBytes $file 1048576
  $hash=Get-AuthWireCandidateHash $bytes
  if($name -ceq 'signed-manifest.json'){$expected=$Target.manifest_sha256}
  elseif($name -ceq 'AuthWire-Combined-Manifest.ps1'){$expected=$hash} # Authenticode/body rechecked by adapter.
  else{$expected=$manifest.files.$name}
  if($hash -cne $expected -or $bytes.Length -ne $before.Length){throw 'STAGING_SOURCE_CHANGED'}
  $after=Get-Item -LiteralPath $file -Force -ErrorAction Stop
  if(($after.Attributes -band [IO.FileAttributes]::ReparsePoint) -or $after.Length -ne $before.Length -or (Get-Acl -LiteralPath $file -ErrorAction Stop).Sddl -cne $sddl){throw 'STAGING_SOURCE_CHANGED'}
  $total+=$bytes.Length;if($total -gt 4194304){throw 'STAGING_SOURCE_LIMIT'}
  $rows+=,[pscustomobject][ordered]@{Path=$name;Size=[long]$bytes.Length;Sha256=$hash;Sddl=$sddl}
 }
 return @($rows)
}

function New-AuthWireCombinedStagingPlanCore {
 param($Target,[object[]]$SourceFiles,$Inventory,[string]$ScopeObservationsSha256,[long]$CheckedAt)
 # A data projection only. Even a valid result grants no write permission.
 Assert-AuthWireCombinedScopeTarget $Target
 if($ScopeObservationsSha256 -cnotmatch '\A[0-9a-f]{64}\z' -or $CheckedAt -lt 1 -or $CheckedAt -ge 1099511627776){throw 'STAGING_SCOPE_REQUIRED'}
 if($Inventory.Sha256 -isnot [string] -or $Inventory.Sha256 -cnotmatch '\A[0-9a-f]{64}\z' -or @($Inventory.Entries).Count -ne 5 -or -not (Test-AuthWireSysvolEmptyDeployment $Inventory)){throw 'STAGING_EMPTY_BASELINE_REQUIRED'}
 $names=[string[]](Get-AuthWireCombinedStagingNames);[Array]::Sort($names,[StringComparer]::Ordinal)
 if($SourceFiles.Count -ne $names.Count){throw 'STAGING_FILE_SET_REJECTED'}
 $map=@{};$total=0L
 foreach($row in $SourceFiles) {
  Assert-AuthWireCandidateFields $row @('Path','Size','Sha256','Sddl')
  if($row.Path -isnot [string] -or $row.Path -cnotin $names -or $map.ContainsKey($row.Path)){throw 'STAGING_FILE_SET_REJECTED'}
  if(($row.Size -isnot [int] -and $row.Size -isnot [long]) -or $row.Size -lt 1 -or $row.Size -gt 1048576 -or $row.Sha256 -isnot [string] -or $row.Sha256 -cnotmatch '\A[0-9a-f]{64}\z' -or $row.Sddl -isnot [string] -or $row.Sddl.Length -lt 1 -or $row.Sddl.Length -gt 16384){throw 'STAGING_FILE_ROW_REJECTED'}
  $null=[Security.AccessControl.RawSecurityDescriptor]::new($row.Sddl)
  $total+=$row.Size;if($total -gt 4194304){throw 'STAGING_SOURCE_LIMIT'}
  $map[$row.Path]=$row
 }
 if($map['signed-manifest.json'].Sha256 -cne $Target.manifest_sha256 -or $map['original-draft.zip'].Sha256 -cne $Target.draft_sha256){throw 'STAGING_CONTENT_PIN_MISMATCH'}
 $files=@(foreach($name in $names){$r=$map[$name];[pscustomobject][ordered]@{Path=$name;Size=[long]$r.Size;Sha256=$r.Sha256;Sddl=$r.Sddl}})
 $relative='Machine/AuthWire-'+([guid]$Target.plan_id).ToString('N')+'-v'+$Target.plan_version+'-'+$Target.manifest_sha256
 $body=[pscustomobject][ordered]@{
  format='AuthWireCombinedStagingPreviewV1';operation='combined.stage.preview.v1'
  scope_target_sha256=(Get-AuthWireCombinedScopeTargetHash $Target)
  scope_observations_sha256=$ScopeObservationsSha256
  baseline_inventory_sha256=$Inventory.Sha256
  source_ledger_sha256=(Get-AuthWireScopeDataHash $files)
  plan_id=$Target.plan_id;plan_version=$Target.plan_version;gpo_id=$Target.gpo_id
  manifest_sha256=$Target.manifest_sha256;draft_sha256=$Target.draft_sha256
  relative_destination=$relative;files=$files;file_count=$files.Count;total_bytes=$total
  checked_at=$CheckedAt;expires_at=($CheckedAt+90)
  rollback=[pscustomobject][ordered]@{relative_directory=$relative;requires_ownership_journal=$true;requires_exact_staged_tree=$true;drift_requires_review=$true;delete_existing_data=$false}
  read_only=$true;can_stage=$false;can_apply_gpo=$false
  writer_available=$false;requires_new_write_approval=$true
 }
 return [pscustomobject]@{Preview=$body;PreviewSha256=(Get-AuthWireScopeDataHash $body)}
}

function Get-AuthWireCombinedStagingPreview {
 param($Target,[hashtable]$Binding,[string]$PublisherThumbprint,[string]$BaseUrl)
 # Future fixed, bounded child entry point; not installed in the live worker.
 $identity=[Security.Principal.WindowsIdentity]::GetCurrent()
 try {
  if($identity.User.Value -cne $Binding.service_sid -or -not $identity.IsAuthenticated -or ([Security.Principal.WindowsPrincipal]::new($identity)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){throw 'STAGING_SERVICE_IDENTITY_REQUIRED'}
 }finally{$identity.Dispose()}
 $checked=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
 $context=Get-AuthWireCombinedScopeContext $Target $Binding $PublisherThumbprint $BaseUrl
 $a=$context.Approval;$network=$context.NetworkTarget
 $domain=Get-ADDomain -Identity $a.domain -Server $a.domain -ErrorAction Stop
 $server=[string]$domain.PDCEmulator
 $domainSid=$Binding.service_sid.Substring(0,$Binding.service_sid.LastIndexOf('-'))
 if($domain.DNSRoot -cne $a.domain -or $domain.DomainSID.Value -cne $domainSid -or $server -cnotmatch '\A[a-z0-9.-]{1,253}\z' -or -not $server.EndsWith('.'+$a.domain,[StringComparison]::Ordinal)){throw 'SCOPE_DIRECTORY_CHANGED'}
 $root='\\'+$server+'\SYSVOL\'+$a.domain+'\Policies\{'+$Target.gpo_id+'}'
 $sourceOne=@(Get-AuthWireCombinedStagingLedger $Target $Binding)
 $one=Get-AuthWireScopeData $a $network $Binding
 $null=Test-AuthWireScopeData $one $a $network $Binding
 $null=Read-AuthWireCombinedSysvolTree $root
 $inventoryOne=Get-AuthWireSysvolInventory $root
 $two=Get-AuthWireScopeData $a $network $Binding
 $null=Test-AuthWireScopeData $two $a $network $Binding
 $null=Read-AuthWireCombinedSysvolTree $root
 $inventoryTwo=Get-AuthWireSysvolInventory $root
 $null=Get-AuthWireCombinedScopeContext $Target $Binding $PublisherThumbprint $BaseUrl
 $sourceTwo=@(Get-AuthWireCombinedStagingLedger $Target $Binding)
 $scopeHash=Get-AuthWireScopeDataHash $one
 if($scopeHash -cne (Get-AuthWireScopeDataHash $two) -or $inventoryOne.Sha256 -cne $inventoryTwo.Sha256 -or (Get-AuthWireScopeDataHash $sourceOne) -cne (Get-AuthWireScopeDataHash $sourceTwo)){throw 'STAGING_OBSERVATIONS_CHANGED'}
 # PDC selection is part of this scope; a changed domain view requires a new read.
 $lastDomain=Get-ADDomain -Identity $a.domain -Server $a.domain -ErrorAction Stop
 if($lastDomain.DNSRoot -cne $a.domain -or $lastDomain.DomainSID.Value -cne $domainSid -or [string]$lastDomain.PDCEmulator -cne $server -or [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() -ge $checked+90){throw 'STAGING_OBSERVATIONS_CHANGED'}
 return (New-AuthWireCombinedStagingPlanCore $Target $sourceTwo $inventoryTwo $scopeHash $checked)
}
