#Requires -Version 5.1
# Focused SDK contract checks under an actual non-admin service identity.
# AD/content observations below are synthetic; no grant or writer is called.
param([Parameter(Mandatory=$true)][string]$PackageRoot,
      [Parameter(Mandatory=$true)][string]$ObservationSourceRoot,
      [Parameter(Mandatory=$true)][string]$JobRoot)
$ErrorActionPreference='Stop';$ProgressPreference='SilentlyContinue';Set-StrictMode -Version 2
. (Join-Path $PackageRoot 'Test-AuthWireDeploymentCandidate.ps1') -LibraryOnly
foreach($f in @('New-AuthWireConnectorHealthProof.ps1','Invoke-AuthWireConnectorProbeJob.ps1','Invoke-AuthWireCandidateJob.ps1','DeploymentScope.ps1','Invoke-AuthWireScopeJob.ps1','CombinedCandidateContent.ps1','Invoke-AuthWireCombinedJob.ps1','CombinedDeploymentScope.ps1','Invoke-AuthWireCombinedScopeJob.ps1','SysvolInventory.ps1','CombinedStagingPreview.ps1','StagingFilesystem.ps1','StagingWritePreclaim.ps1')){. (Join-Path $PackageRoot $f)}
foreach($f in @('CombinedStagingPreview.ps1','StagingWritePreclaim.ps1')){. (Join-Path $ObservationSourceRoot $f)}
$c=ConvertFrom-AuthWireCandidateJson (Read-AuthWireCandidateBytes (Join-Path $PackageRoot 'service.json') 16384)
$binding=@{};foreach($p in $c.Binding.PSObject.Properties){$binding[$p.Name]=$p.Value}
$identity=[Security.Principal.WindowsIdentity]::GetCurrent();try{if($identity.User.Value -cne $binding.service_sid -or ([Security.Principal.WindowsPrincipal]::new($identity)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){throw 'OBSERVATION_FIXTURE_NONADMIN_IDENTITY_REQUIRED'}}finally{$identity.Dispose()}
$script:seed=(Read-AuthWireStagingJournal (Join-Path $JobRoot 'offer.json')).offer
$live=Read-AuthWireStagingJournal (Join-Path $JobRoot 'stage-preflight.json')
$script:baseline=Get-AuthWireSysvolInventory $live.gpo_root
$script:domain=$script:seed.target.scope_target.domain;$script:pdc=$live.pdc
$script:domainSid=$binding.service_sid.Substring(0,$binding.service_sid.LastIndexOf('-'))
$script:ctx=[pscustomobject]@{Approval=[pscustomobject]@{domain=$script:domain;protected_gpo_id=$live.protected_gpo_id};NetworkTarget=[pscustomobject]@{fixture='fixed'}}
$script:checks=0
function Check($v,[string]$name){if(-not $v){throw ('OBSERVATION_FIXTURE:'+ $name)};$script:checks++}
function Clone($v){return ($v|ConvertTo-Json -Depth 25 -Compress|ConvertFrom-Json)}
function Reset([string]$mode){$script:mode=$mode;$script:counts=@{context=0;source=0;scope=0;inventory=0;domain=0}}
function Reject([scriptblock]$fn,[string]$message){$seen='';try{& $fn|Out-Null}catch{$seen=$_.Exception.Message};Check ($seen -ceq $message) ('reject '+$message+'; observed '+$seen)}
function Get-AuthWireCombinedScopeContext($Target,$Binding,$Publisher,$BaseUrl){$script:counts.context++;$r=Clone $script:ctx;if($script:mode -ceq 'context' -and $script:counts.context -eq 2){$r.Approval.protected_gpo_id=[guid]::NewGuid().ToString('D')};return $r}
function Get-ADDomain {param($Identity,$Server,$ErrorAction);$script:counts.domain++;$r=[pscustomobject]@{DNSRoot=$script:domain;PDCEmulator=$script:pdc;DomainSID=[pscustomobject]@{Value=$script:domainSid}};if(($script:mode -ceq 'pdc' -and $script:counts.domain -eq 2) -or ($script:mode -ceq 'stage_pdc' -and $script:counts.domain -eq 3)){$r.PDCEmulator='dc99.'+$script:domain};return $r}
function Get-AuthWireCombinedStagingLedger($Target,$Binding){$script:counts.source++;$rows=Clone $script:seed.target.preview_record.Preview.files;if($script:mode -ceq 'source' -and $script:counts.source -eq 2){$rows[0].Sha256='f'*64};return @($rows)}
function Get-AuthWireScopeData($Approval,$Target,$Binding){$script:counts.scope++;$v='fixed';if($script:mode -ceq 'scope' -and $script:counts.scope -eq 2){$v='changed'};return [pscustomobject]@{fixture=$v}}
function Test-AuthWireScopeData($Data,$Approval,$Target,$Binding){return $true}
function Read-AuthWireCombinedSysvolTree([string]$Root){return @()}
function Get-AuthWireSysvolInventory([string]$Root){$script:counts.inventory++;$r=Clone $script:baseline;if($script:mode -ceq 'inventory' -and $script:counts.inventory -eq 2){$r.Sha256='e'*64};return $r}
$target=$script:seed.target.scope_target
Reset 'stable';$ob=Get-AuthWireCombinedStagingObservation $target $binding $c.PublisherThumbprint $c.BaseUrl
Check ($script:counts.context -eq 2) 'both signed content boundaries retained'
Check ($script:counts.source -eq 2 -and $script:counts.scope -eq 2 -and $script:counts.inventory -eq 2 -and $script:counts.domain -eq 2) 'both source AD inventory and PDC observations retained'
Check ($ob.PreviewRecord.Preview.file_count -eq 20 -and $ob.PreviewRecord.Preview.total_bytes -eq $script:seed.target.preview_record.Preview.total_bytes) 'same exact 20-file plan'
Check ($ob.PreviewRecord.Preview.expires_at-$ob.PreviewRecord.Preview.checked_at -eq 90) 'same preview lifetime'
Reset 'stable';$public=Get-AuthWireCombinedStagingPreview $target $binding $c.PublisherThumbprint $c.BaseUrl
Check (@($public.PSObject.Properties).Count -eq 2 -and $null -ne $public.Preview -and $null -ne $public.PreviewSha256) 'public preview wire shape unchanged'
Check ($public.Preview.read_only -and -not $public.Preview.can_stage -and -not $public.Preview.can_apply_gpo) 'preview cannot authorize execution'
foreach($mode in @('context','source','scope','inventory')){Reset $mode;Reject {Get-AuthWireCombinedStagingObservation $target $binding $c.PublisherThumbprint $c.BaseUrl} 'STAGING_OBSERVATIONS_CHANGED'}
Reset 'pdc';Reject {Get-AuthWireCombinedStagingObservation $target $binding $c.PublisherThumbprint $c.BaseUrl} 'STAGING_OBSERVATIONS_CHANGED'
Reset 'stable';$approved=Get-AuthWireCombinedStagingObservation $target $binding $c.PublisherThumbprint $c.BaseUrl
$offer=Clone $script:seed;$offer.target.preview_record=$approved.PreviewRecord
$originalChecked=$offer.target.preview_record.Preview.checked_at;$originalExpiry=$offer.target.preview_record.Preview.expires_at
Reset 'stable';$current=Get-AuthWireWriteStageLiveContext $offer $binding $c.PublisherThumbprint $c.BaseUrl
Check ($script:counts.context -eq 2 -and $script:counts.domain -eq 3) 'stage reuses bounded observation and independently checks final PDC'
Check ($current.gpo_root -ceq $live.gpo_root -and $current.protected_gpo_id -ceq $live.protected_gpo_id -and -not $current.can_apply_gpo) 'same fixed scope and non-apply result'
Check ($offer.target.preview_record.Preview.checked_at -eq $originalChecked -and $offer.target.preview_record.Preview.expires_at -eq $originalExpiry) 'approved timestamps never renewed'
Reset 'stage_pdc';Reject {Get-AuthWireWriteStageLiveContext $offer $binding $c.PublisherThumbprint $c.BaseUrl} 'WRITE_LIVE_PDC_CHANGED'
$expired=Clone $offer;$expired.target.preview_record.Preview.checked_at=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()-100;$expired.target.preview_record.Preview.expires_at=$expired.target.preview_record.Preview.checked_at+90
$expired.target.preview_record.PreviewSha256=Get-AuthWireWritePreviewHash $expired.target.preview_record.Preview
Reset 'stable';Reject {Get-AuthWireWriteStageLiveContext $expired $binding $c.PublisherThumbprint $c.BaseUrl} 'STAGING_PREVIEW_EXPIRED'
$bad=Clone $offer;$bad.target.preview_record.PreviewSha256='d'*64
Reset 'stable';Reject {Get-AuthWireWriteStageLiveContext $bad $binding $c.PublisherThumbprint $c.BaseUrl} 'WRITE_LIVE_PREVIEW_CHANGED'
$bad=Clone $offer;$bad.operation='combined.filesystem.rollback.v1'
Reset 'stable';Reject {Get-AuthWireWriteStageLiveContext $bad $binding $c.PublisherThumbprint $c.BaseUrl} 'WRITE_ROLLBACK_PREFLIGHT_UNAVAILABLE'
[pscustomobject]@{status='passed';checks=$script:checks;identity=$binding.service_sid;ad_and_content_synthetic=$true;engine_invoked=$false;grant_created=$false;original_job_replayed=$false}|ConvertTo-Json -Compress
