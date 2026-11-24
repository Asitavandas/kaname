#Requires -Version 5.1
# Focused new regression: real native candidate handles and five-second live
# observation window. Identity, signature verification and AD are explicit
# fixture shims; no real grant, channel, production GPO or stage is created.
$ErrorActionPreference='Stop';Set-StrictMode -Version 2
$lib=Join-Path $PSScriptRoot '..\windows\connector'
. (Join-Path $lib 'Test-AuthWireDeploymentCandidate.ps1') -LibraryOnly
foreach($name in @('Invoke-AuthWireConnectorProbeJob.ps1','Invoke-AuthWireCandidateJob.ps1','Invoke-AuthWireCombinedJob.ps1','DeploymentScope.ps1','CombinedDeploymentScope.ps1','SysvolInventory.ps1','StagingFilesystem.ps1','StagingWritePreclaim.ps1','StagingWriteExecution.ps1','StagingWriteResult.ps1','StagingRollbackEvidence.ps1')){. (Join-Path $lib $name)}
Initialize-AuthWireStagingFilesystemTypes
$script:checks=0
function Check($v,[string]$n){if(-not $v){throw ('ROLLBACK_LIVE_WINDOW_FIXTURE:'+ $n)};$script:checks++}
function Reject([scriptblock]$fn,[string]$n){$bad=$false;try{& $fn|Out-Null}catch{$bad=$true};Check $bad $n}
$connector=[guid]::NewGuid().ToString('N');$plan=[guid]::NewGuid().ToString('D')
$root=$env:SystemDrive+'\aw-rb-'+[guid]::NewGuid().ToString('N').Substring(0,8)
$networkRoot=Join-Path $env:ProgramData ('AuthWire-DeploymentCandidates-'+$connector)
$combinedRoot=Join-Path $env:ProgramData ('AuthWire-CombinedCandidates-'+$connector)
$lease=$null
try{
 $current=[Security.Principal.WindowsIdentity]::GetCurrent();try{$sid=$current.User.Value}finally{$current.Dispose()}
 $b=@{connector_id=([guid]$connector).ToString('D');service_sid=$sid}
 Reject {Assert-AuthWireRollbackReaderIdentity $b} 'administrator is rejected before fixture identity shim'
 # Explicit simulation boundaries. Native paths, file identities/ACLs, mutexes,
 # deny-write handles, tree inventories and both clocks remain production code.
 function Assert-AuthWireRollbackReaderIdentity { }
 function Assert-AuthWireCandidateAcl {param($Path,$Sid,[switch]$Directory);if(-not(Test-Path -LiteralPath $Path)){throw 'FIXTURE_MISSING_CONTENT'}}
 function Assert-AuthWireCombinedScopeTarget { }
 function Assert-AuthWireWriteOffer($Offer){if([DateTimeOffset]::UtcNow.ToUnixTimeSeconds() -ge $Offer.expires_at){throw 'FIXTURE_EXPIRED_OFFER'}}
 function Get-AuthWireJobScope {return ('1'*64)}
 function Get-AuthWireStagingWriteJournalRoot {return $root}
 function Assert-AuthWireStagingWriteJournalLocation($Path){if($Path -cne $root){throw 'FIXTURE_ROOT_CHANGED'}}
 function Get-AuthWireWriteGpoPath {return $gpo}
 $gpo=Join-Path $root 'gpo';$stageId=[guid]::NewGuid().ToString('D');$op=[guid]::NewGuid().ToString('D')
 foreach($d in @($gpo,(Join-Path $gpo 'Machine'),(Join-Path $root $stageId),(Join-Path $root $op),$networkRoot,$combinedRoot)){[IO.Directory]::CreateDirectory($d)|Out-Null}
 [IO.File]::WriteAllText((Join-Path $gpo 'outside.txt'),'retained baseline')
 $relative='Machine/AuthWire-'+([guid]$plan).ToString('N')+'-v1-'+('2'*64)
 $destination=Join-Path $gpo $relative.Replace('/','\')
 foreach($d in @($destination,(Join-Path $destination 'network'),(Join-Path $destination 'enrollment'))){[IO.Directory]::CreateDirectory($d)|Out-Null}
 foreach($n in 1..20){[IO.File]::WriteAllText((Join-Path $destination ('f'+$n+'.txt')),('owned fixture file '+$n))}
 $tree=[AuthWire.Staging.TreeLeaseV1]::Tree($destination,$false)
 try{$treeHash=Get-AuthWireStagingFilesystemDigest (Get-AuthWireStagingFilesystemRows $tree)}finally{$tree.Dispose()}
 $all=Get-AuthWireSysvolInventory $gpo;$outside=@($all.Entries|Where-Object {$_.Path -cne $relative -and -not $_.Path.StartsWith($relative+'/',[StringComparison]::Ordinal)})
 $network=Join-Path $networkRoot (([guid]$plan).ToString('N')+'-v1-'+('3'*64));[IO.Directory]::CreateDirectory($network)|Out-Null
 $approval=Join-Path $network 'approval.json';[IO.File]::WriteAllText($approval,'{"fixture":"approval"}')
 $combined=Join-Path $combinedRoot ($plan+'-v1-'+('4'*64)+'-ab1a11c683810061');[IO.Directory]::CreateDirectory($combined)|Out-Null
 $contentFile=Join-Path $combined 'signed-fixture.txt';[IO.File]::WriteAllText($contentFile,'fixture content verifier input')
 $approvalHash=Get-AuthWireCandidateHash ([IO.File]::ReadAllBytes($approval));$contentHash=Get-AuthWireCandidateHash ([IO.File]::ReadAllBytes($contentFile))
 $t=[pscustomobject]@{plan_id=$plan;plan_version=1;approval_sha256=$approvalHash;draft_sha256=('4'*64);manifest_sha256=('2'*64);gpo_id=[guid]::NewGuid().ToString('D')}
 $complete=[pscustomobject]@{tree_sha256=$treeHash}
 $offer=[pscustomobject]@{job_id=[guid]::NewGuid().ToString('D');request_id=('5'*64);intent_sha256=('6'*64);expires_at=([DateTimeOffset]::UtcNow.ToUnixTimeSeconds()+90);operation='combined.filesystem.rollback.v1';target=[pscustomobject]@{scope_target=$t;stage_receipt=[pscustomobject]@{stage_job_id=$stageId;complete_journal_sha256=(Get-AuthWireScopeDataHash $complete);staged_tree_sha256=$treeHash};preview_record=[pscustomobject]@{Preview=[pscustomobject]@{scope_observations_sha256=('7'*64)}}}}
 $protected=[guid]::NewGuid().ToString('D')
 $origin=[pscustomobject]@{StageJobId=$stageId;StageReleaseId=[guid]::NewGuid().ToString('D');FilesystemOperationId=$op;ChainSha256=('8'*64);Complete=$complete;StageLive=[pscustomobject]@{gpo_root=$gpo;pdc='dc01.lab.example'};Intent=[pscustomobject]@{relative_destination=$relative;protected_gpo_id=$protected;baseline_sha256=(Get-AuthWireScopeDataHash $outside)}}
 $script:contentCalls=0;$script:contentDelay=0;$script:adReads=0;$script:adDelay=0
 $script:initCalls=0;$script:initDelay=0;$script:initFinished=0;$script:liveScopeChanged=$false
 function Initialize-AuthWireRollbackDirectoryReader($Offer,$Binding,$Context){
  if(-not $Context.verified){throw 'FIXTURE_UNVERIFIED_CONTEXT'}
  $script:initCalls++;if($script:initDelay){Start-Sleep -Milliseconds $script:initDelay}
  $script:initFinished=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
 }
 function Get-AuthWireCombinedScopeContext {
  $script:contentCalls++;if($script:contentDelay){Start-Sleep -Milliseconds $script:contentDelay}
  if((Get-AuthWireCandidateHash ([IO.File]::ReadAllBytes($approval))) -cne $approvalHash -or (Get-AuthWireCandidateHash ([IO.File]::ReadAllBytes($contentFile))) -cne $contentHash){throw 'FIXTURE_CONTENT_CHANGED'}
  return [pscustomobject]@{verified=$true}
 }
 function Get-AuthWireRollbackDirectoryObservationFromContext($Offer,$Binding,$Context){
  if(-not $Context.verified){throw 'FIXTURE_UNVERIFIED_CONTEXT'}
  $script:adReads++;if($script:adDelay -and $script:adReads -eq 1){Start-Sleep -Milliseconds $script:adDelay}
  $scope=if($script:liveScopeChanged){'9'*64}else{'7'*64}
  return [pscustomobject]@{pdc='dc01.lab.example';gpo_root=$gpo;protected_gpo_id=$protected;scope_sha256=$scope}
 }
 $lease=New-AuthWireRollbackContentLease $offer $b ('A'*40) 'https://fixture.example/'
 Reject {[IO.File]::WriteAllText($contentFile,'substituted')} 'verified combined file cannot change during AD observation'
 Reject {[IO.File]::Delete($approval)} 'verified network approval cannot disappear during observation'
 $foreign=Join-Path $networkRoot 'foreign';[IO.Directory]::CreateDirectory($foreign)|Out-Null
 Reject {Assert-AuthWireRollbackContentLease $lease} 'candidate namespace addition invalidates held context'
 [IO.Directory]::Delete($foreign);Assert-AuthWireRollbackContentLease $lease
 Close-AuthWireRollbackContentLease $lease;$lease=$null
 $script:contentCalls=0;$script:adReads=0;$script:contentDelay=5200
 $clock=[Diagnostics.Stopwatch]::StartNew();$at=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
 $result=Get-AuthWireRollbackLivePreflight $offer $b ([guid]::NewGuid().ToString('D')) ('A'*40) 'https://fixture.example/' $origin
 Check ($script:contentCalls -eq 1 -and $script:adReads -eq 2) 'one pinned content validation and two current directory observations'
 Check ($result.checked_at -ge $at+5 -and $clock.ElapsedMilliseconds -lt 15000) 'cold signature/content work consumes outer budget without aging not-yet-started AD observation'
 Check ($result.expires_at -eq $result.checked_at+5 -and -not $result.can_delete -and -not $result.write_authorized) 'original five second observation and false authority flags preserved'
 $script:contentDelay=0;$script:initDelay=5200;$script:initCalls=0;$script:adReads=0
 $clock=[Diagnostics.Stopwatch]::StartNew();$at=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
 $result=Get-AuthWireRollbackLivePreflight $offer $b ([guid]::NewGuid().ToString('D')) ('A'*40) 'https://fixture.example/' $origin
 Check ($script:initCalls -eq 1 -and $script:adReads -eq 2) 'cold report initialization is separate from both fresh directory observations'
 Check ($result.checked_at -ge $at+5 -and $result.checked_at -ge $script:initFinished -and $clock.ElapsedMilliseconds -lt 15000) 'report initialization consumes outer budget before the unchanged live window'
 Check ($result.expires_at -eq $result.checked_at+5 -and -not $result.can_delete) 'report warmup never extends the original five second lifetime or grants authority'
 $script:initDelay=0;$script:liveScopeChanged=$true;$script:adReads=0
 Reject {Get-AuthWireRollbackLivePreflight $offer $b ([guid]::NewGuid().ToString('D')) ('A'*40) 'https://fixture.example/' $origin} 'successful initialization never replaces a rejected fresh directory observation'
 $script:liveScopeChanged=$false
 $script:contentDelay=0;$script:adDelay=5100;$script:adReads=0
 $expired='';try{$null=Get-AuthWireRollbackLivePreflight $offer $b ([guid]::NewGuid().ToString('D')) ('A'*40) 'https://fixture.example/' $origin}catch{$expired=$_.Exception.Message}
 Check ($expired -ceq 'ROLLBACK_PREFLIGHT_EXPIRED') 'actual slow AD observation still expires at five seconds'
 Check ((Get-AuthWireSysvolInventory $gpo).Sha256 -ceq $all.Sha256) 'new read-only checks preserve owned files and entire baseline'
 Write-Host ('AUTHWIRE_ROLLBACK_LIVE_WINDOW_OK checks='+$script:checks+' native_handles=true simulated_ad_content_identity=true real_grants=false')
}finally{
 if($lease){Close-AuthWireRollbackContentLease $lease}
 foreach($path in @($root,$networkRoot,$combinedRoot)){if(Test-Path -LiteralPath $path){Remove-Item -LiteralPath $path -Recurse -Force}}
}
