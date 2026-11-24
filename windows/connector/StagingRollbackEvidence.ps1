# Source-only rollback origin/preflight evidence. No CLAIM, consumption, writer,
# transport, cleanup, unlock or active worker/package registration.
Set-StrictMode -Version 2

function Read-AuthWireRollbackOrigin($Offer,[hashtable]$Binding,[string]$Release,[Security.Cryptography.RSACng]$Key){
 Assert-AuthWireWriteOffer $Offer $Binding $Release $Offer.request_id
 $id=$Offer.target.stage_receipt.stage_job_id;$root=Get-AuthWireStagingWriteJournalRoot $Binding
 $lock=Enter-AuthWireWriteOutcomeLock $id
 try{
  $origin=Read-AuthWireRollbackOriginEvidenceAt $Offer $Binding $Release $Key ([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())
  $p=[AuthWire.Staging.TreeLeaseV1]::new()
  try{
   $p.PinAncestors($root);$job=Join-Path $root $id;$p.PinAncestors($job)
   $engine=Join-Path $root $origin.FilesystemOperationId;$p.PinAncestors($engine)
   if(Test-Path -LiteralPath (Join-Path $job 'execution-requires-review.json')){throw 'ROLLBACK_STAGE_REVIEW_REQUIRED'}
   Assert-AuthWireNoActiveStage $root $id
   foreach($n in @('rollback-started.json','rolled-back.json')){if(Test-Path -LiteralPath (Join-Path $engine $n)){throw 'ROLLBACK_PREVIOUS_ATTEMPT_REQUIRES_REVIEW'}}
   return $origin
  }finally{$p.Dispose()}
 }finally{$lock.ReleaseMutex();$lock.Dispose()}
}

# Historical proof only; this never establishes CURRENT eligibility or renews authority.
function Read-AuthWireRollbackOriginEvidenceAt($Offer,[hashtable]$Binding,[string]$Release,[Security.Cryptography.RSACng]$Key,[long]$ObservedAt){
 if(-not (Test-AuthWireWriteInteger $ObservedAt) -or $ObservedAt -gt [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()){throw 'ROLLBACK_HISTORY_TIME_REJECTED'}
 Assert-AuthWireWriteOfferAt $Offer $Binding $Release $Offer.request_id $ObservedAt
 if($Offer.operation -cne 'combined.filesystem.rollback.v1'){throw 'ROLLBACK_OPERATION_REQUIRED'}
 $id=$Offer.target.stage_receipt.stage_job_id
 if($id -ceq $Offer.job_id){throw 'ROLLBACK_DISTINCT_JOB_REQUIRED'}
 $root=Get-AuthWireStagingWriteJournalRoot $Binding
 Assert-AuthWireStagingWriteJournalLocation $root $Binding
 Initialize-AuthWireStagingFilesystemTypes
 $lock=Enter-AuthWireWriteOutcomeLock $id;$p=[AuthWire.Staging.TreeLeaseV1]::new()
 try{
  $job=Join-Path $root $id;$p.PinAncestors($root);$p.PinAncestors($job)
  # Hold the ENTIRE immutable authority/observation/result chain for this read.
  foreach($n in @('offer.json','preflight.json','claim-started.json','claim-proof.json','claim-sent.json','authorization.json','grant-consumed.json','filesystem-intent.json','stage-launch.json','stage-child.json','stage-preflight.json','execution-complete.json','execution-observed.json','result-outbox.json','result-accepted.json')){$p.PinFile((Join-Path $job $n))}
  $p.PinFile((Join-Path $root ('gpo-'+$Offer.target.scope_target.gpo_id+'.json')))
  $record=Read-AuthWireStagingJournal (Join-Path $job 'offer.json')
  Assert-AuthWireCandidateFields $record @('format','binding_scope','release_id','offer')
  Assert-AuthWireCandidateGuid $record.release_id
  # Reading an older release does not migrate a binding/key generation. The
  # original proof must still verify under this exact current binding scope.
  $s=Read-AuthWireAuthorizedStageIntentEvidence $root $id $Binding $record.release_id $Key
  $old=$s.Authorization.Offer
  foreach($n in @('scope_target','preview_record','preview_job_id','preview_result_sha256')){
   if((Get-AuthWireWriteHash $old.target.$n) -cne (Get-AuthWireWriteHash $Offer.target.$n)){throw 'ROLLBACK_STAGE_TARGET_CHANGED'}
  }
  $op=$s.Intent.filesystem_operation_id;$engine=Join-Path $root $op;$p.PinAncestors($engine)
  foreach($n in @('intent.json','complete.json')){$p.PinFile((Join-Path $engine $n))}
  $observed=Read-AuthWireObservedStageBody $root $id $Binding $record.release_id $Key
  $outbox=Read-AuthWireWriteResultOutbox $root $id $Binding $record.release_id $Key
  if((Get-AuthWireWriteHash $observed) -cne $outbox.body_sha256 -or (Get-AuthWireWriteHash $outbox.body) -cne $outbox.body_sha256 -or
     $observed.journal_sha256 -cne $Offer.target.stage_receipt.complete_journal_sha256 -or $observed.tree_sha256 -cne $Offer.target.stage_receipt.staged_tree_sha256){throw 'ROLLBACK_STAGE_RESULT_CHANGED'}
  $accepted=Read-AuthWireStagingJournal (Join-Path $job 'result-accepted.json')
  Assert-AuthWireCandidateFields $accepted @('format','job_id','body_sha256','request_id','ack')
  Assert-AuthWireStageStrings $accepted @('format','job_id','body_sha256','request_id')
  if($accepted.format -cne 'AuthWireWriteResultAcceptedV1' -or $accepted.job_id -cne $id -or $accepted.body_sha256 -cne $outbox.body_sha256 -or -not (Test-AuthWireWriteHash $accepted.request_id)){throw 'ROLLBACK_STAGE_ACK_REQUIRED'}
  Assert-AuthWireWriteResultAck $accepted.ack $accepted.request_id $id
  $intent=Read-AuthWireStagingJournal (Join-Path $engine 'intent.json');$complete=Read-AuthWireStagingJournal (Join-Path $engine 'complete.json')
  if((Get-AuthWireScopeDataHash $complete) -cne $observed.journal_sha256){throw 'ROLLBACK_STAGE_RESULT_CHANGED'}
  # Only hashes of fixed local records enter the witness. No path is accepted
  # from an offer, and no saved timestamp is changed to make old authority live.
  $chain=[pscustomobject][ordered]@{stage_authorization_sha256=$s.Authorization.AuthorizationSha256;stage_intent_sha256=$s.IntentSha256;observed_body_sha256=$outbox.body_sha256;accepted_sha256=(Get-AuthWireWriteHash $accepted);complete_sha256=$observed.journal_sha256;tree_sha256=$observed.tree_sha256}
  return [pscustomobject]@{StageJobId=$id;StageReleaseId=$record.release_id;FilesystemOperationId=$op;ChainSha256=(Get-AuthWireWriteHash $chain);Intent=$intent;Complete=$complete;StageLive=$s.Intent.live_context;CanDelete=$false;CanApplyGpo=$false}
 }finally{$p.Dispose();$lock.ReleaseMutex();$lock.Dispose()}
}

function Assert-AuthWireRollbackReaderIdentity([hashtable]$Binding){
 $identity=[Security.Principal.WindowsIdentity]::GetCurrent()
 try{if($identity.User.Value -cne $Binding.service_sid -or -not $identity.IsAuthenticated -or ([Security.Principal.WindowsPrincipal]::new($identity)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){throw 'ROLLBACK_SERVICE_IDENTITY_REQUIRED'}}finally{$identity.Dispose()}
}
function Get-AuthWireRollbackDirectoryObservation($Offer,[hashtable]$Binding,[string]$Publisher,[string]$BaseUrl){
 # Explicit service identity plus existing bounded content/AD/GPO/ACL checks.
 # Unlike the stage preview this does not require an empty Machine directory.
 Assert-AuthWireRollbackReaderIdentity $Binding
 $context=Get-AuthWireCombinedScopeContext $Offer.target.scope_target $Binding $Publisher $BaseUrl
 return (Get-AuthWireRollbackDirectoryObservationFromContext $Offer $Binding $context)
}
function New-AuthWireRollbackContentLease($Offer,[hashtable]$Binding,[string]$Publisher,[string]$BaseUrl){
 # Fixed local candidates, never paths or cached context from a peer. Hold the
 # verified bytes through BOTH current AD observations. Expensive signature/
 # ZIP validation belongs to the enclosing 15s budget, not the 5s AD window.
 Assert-AuthWireRollbackReaderIdentity $Binding
 Assert-AuthWireCombinedScopeTarget $Offer.target.scope_target
 $t=$Offer.target.scope_target;$pins=[AuthWire.Staging.TreeLeaseV1]::new()
 $leases=[Collections.Generic.List[IDisposable]]::new()
 try{
  $id=([guid]$Binding.connector_id).ToString('N');$area=[Environment]::GetFolderPath('CommonApplicationData')
  $networkRoot=Join-Path $area ('AuthWire-DeploymentCandidates-'+$id)
  $combinedRoot=Join-Path $area ('AuthWire-CombinedCandidates-'+$id)
  foreach($root in @($networkRoot,$combinedRoot)){$pins.PinStableAncestors($root);Assert-AuthWireCandidateAcl $root $Binding.service_sid -Directory}
  $prefix=([guid]$t.plan_id).ToString('N')+'-v'+$t.plan_version+'-'
  $items=@(Get-ChildItem -LiteralPath $networkRoot -Force);if($items.Count -gt 32){throw 'ROLLBACK_CONTENT_LIMIT'}
  $found=0;$selectedNetwork=''
  foreach($item in $items){
   if($item.Name -cnotmatch ('\A'+[regex]::Escape($prefix)+'[0-9a-f]{64}\z')){continue}
   if(-not $item.PSIsContainer){throw 'ROLLBACK_CONTENT_CHANGED'}
   $pins.PinStableAncestors($item.FullName);$file=Join-Path $item.FullName 'approval.json';$pins.PinFile($file)
   if((Get-AuthWireCandidateHash (Read-AuthWireCandidateBytes $file 8192)) -cne $t.approval_sha256){continue}
   $leases.Add([AuthWire.Staging.TreeLeaseV1]::Tree($item.FullName,$false));$selectedNetwork=$item.FullName;$found++
  }
  if($found -ne 1){throw 'ROLLBACK_CONTENT_CHANGED'}
  # The staging ledger admits only the combined startup installer template.
  $template='ab1a11c68381006173518df77deeb0d32fc56e0b28cc260c42b7378c624be14a'
  $combined=Join-Path $combinedRoot ($t.plan_id+'-v'+$t.plan_version+'-'+$t.draft_sha256+'-'+$template.Substring(0,16))
  $pins.PinStableAncestors($combined);$leases.Add([AuthWire.Staging.TreeLeaseV1]::Tree($combined,$false))
  # This retains the complete existing public signer, network/combined content,
  # fixed ACL, domain/profile/CA and enrollment/TLS binding validation.
  $namespaces=@(foreach($root in @($networkRoot,$combinedRoot)){
   $names=@(Get-ChildItem -LiteralPath $root -Force|ForEach-Object {$_.Name+'|'+[int]$_.PSIsContainer}|Sort-Object -CaseSensitive)
   [pscustomobject]@{Root=$root;Names=($names -join ';')}
  })
  $context=Get-AuthWireCombinedScopeContext $t $Binding $Publisher $BaseUrl
  $lease=[pscustomobject]@{Context=$context;Pins=$pins;Trees=$leases;Namespaces=$namespaces;SelectedPaths=@($selectedNetwork,$combined)}
  Assert-AuthWireRollbackContentLease $lease
  return $lease
 }catch{foreach($lease in $leases){$lease.Dispose()};$pins.Dispose();throw}
}
function Close-AuthWireRollbackContentLease($Lease){
 if($Lease){foreach($tree in $Lease.Trees){$tree.Dispose()};$Lease.Pins.Dispose()}
}
function Assert-AuthWireRollbackContentLease($Lease){
 foreach($namespace in $Lease.Namespaces){
  $names=@(Get-ChildItem -LiteralPath $namespace.Root -Force|ForEach-Object {$_.Name+'|'+[int]$_.PSIsContainer}|Sort-Object -CaseSensitive)
  if(($names -join ';') -cne $namespace.Names){throw 'ROLLBACK_CONTENT_CHANGED'}
 }
 if(@($Lease.SelectedPaths).Count -ne $Lease.Trees.Count){throw 'ROLLBACK_CONTENT_CHANGED'}
 for($i=0;$i -lt $Lease.Trees.Count;$i++){
  $again=[AuthWire.Staging.TreeLeaseV1]::Tree($Lease.SelectedPaths[$i],$false)
  try{if((Get-AuthWireStagingFilesystemDigest (Get-AuthWireStagingFilesystemRows $again)) -cne (Get-AuthWireStagingFilesystemDigest (Get-AuthWireStagingFilesystemRows $Lease.Trees[$i]))){throw 'ROLLBACK_CONTENT_CHANGED'}}finally{$again.Dispose()}
 }
}
function Initialize-AuthWireRollbackDirectoryReader($Offer,[hashtable]$Binding,$context){
 # The first GroupPolicy report call initializes native/report machinery and
 # may take seconds. Pay that cold cost inside the OUTER budget, before the
 # live observation starts. Discard this report completely: both subsequent
 # current AD/GPO observations still execute and validate the full reader.
 Assert-AuthWireRollbackReaderIdentity $Binding
 $t=$Offer.target.scope_target;$a=$context.Approval
 $domain=Get-ADDomain -Identity $a.domain -Server $a.domain -ErrorAction Stop
 $sid=$Binding.service_sid.Substring(0,$Binding.service_sid.LastIndexOf('-'))
 if($domain.DNSRoot -cne $t.domain -or $domain.DomainSID.Value -cne $sid){throw 'ROLLBACK_DIRECTORY_CHANGED'}
 $server=[string]$domain.PDCEmulator
 $null=Get-AuthWireWriteGpoPath $server $t
 $report=Get-GPOReport -Guid ([guid]$t.gpo_id) -Domain $a.domain -Server $server -ReportType Xml -ErrorAction Stop
 if($report.Length -gt 1048576 -or $report.IndexOf('<!DOCTYPE',[StringComparison]::OrdinalIgnoreCase) -ge 0){throw 'ROLLBACK_DIRECTORY_CHANGED'}
 # No saved context, report, directory digest, eligibility or timestamp leaves
 # initialization. It cannot substitute for either live observation.
}
function Get-AuthWireRollbackDirectoryObservationFromContext($Offer,[hashtable]$Binding,$context){
 # Only a locally verified context held by New-AuthWireRollbackContentLease is
 # reused. This internal reader still makes a fresh complete AD/GPO/ACL read.
 Assert-AuthWireRollbackReaderIdentity $Binding
 $t=$Offer.target.scope_target
 $a=$context.Approval;$domain=Get-ADDomain -Identity $a.domain -Server $a.domain -ErrorAction Stop
 $server=[string]$domain.PDCEmulator;$sid=$Binding.service_sid.Substring(0,$Binding.service_sid.LastIndexOf('-'))
 if($domain.DNSRoot -cne $t.domain -or $domain.DomainSID.Value -cne $sid){throw 'ROLLBACK_DIRECTORY_CHANGED'}
 $root=Get-AuthWireWriteGpoPath $server $t
 $data=Get-AuthWireScopeData $a $context.NetworkTarget $Binding
 $null=Test-AuthWireScopeData $data $a $context.NetworkTarget $Binding
 $hash=Get-AuthWireScopeDataHash $data
 if($hash -cne $Offer.target.preview_record.Preview.scope_observations_sha256){throw 'ROLLBACK_DIRECTORY_CHANGED'}
 return [pscustomobject]@{pdc=$server;gpo_root=$root;protected_gpo_id=$a.protected_gpo_id;scope_sha256=$hash}
}

function New-AuthWireRollbackOriginInputPins([string]$Root,$Offer){
 Assert-AuthWireCandidateGuid $Offer.target.stage_receipt.stage_job_id
 $p=[AuthWire.Staging.TreeLeaseV1]::new()
 try{
  $p.PinAncestors($Root);$job=Join-Path $Root $Offer.target.stage_receipt.stage_job_id;$p.PinAncestors($job)
  foreach($n in @('offer.json','preflight.json','claim-started.json','claim-proof.json','claim-sent.json','authorization.json','grant-consumed.json','filesystem-intent.json','stage-launch.json','stage-child.json','stage-preflight.json','execution-complete.json','execution-observed.json','result-outbox.json','result-accepted.json')){$p.PinFile((Join-Path $job $n))}
  $p.PinFile((Join-Path $Root ('gpo-'+$Offer.target.scope_target.gpo_id+'.json')))
  # GUID locator only; the full check independently derives the same operation
  # from these immutable records. This early pin never grants authority.
  $locator=Read-AuthWireStagingJournal (Join-Path $job 'filesystem-intent.json')
  Assert-AuthWireCandidateGuid $locator.filesystem_operation_id
  $engine=Join-Path $Root $locator.filesystem_operation_id;$p.PinAncestors($engine)
  foreach($n in @('intent.json','complete.json')){$p.PinFile((Join-Path $engine $n))}
  return $p
 }catch{$p.Dispose();throw}
}

function Get-AuthWireRollbackLivePreflight($Offer,[hashtable]$Binding,[string]$Release,[string]$Publisher,[string]$BaseUrl,$origin){
 # Internal READ-ONLY live observation over an origin already verified under
 # held native pins. This function cannot authorize, consume or delete anything.
 Assert-AuthWireWriteOffer $Offer $Binding $Release $Offer.request_id
 if($Offer.operation -cne 'combined.filesystem.rollback.v1' -or $origin.StageJobId -cne $Offer.target.stage_receipt.stage_job_id -or
    (Get-AuthWireScopeDataHash $origin.Complete) -cne $Offer.target.stage_receipt.complete_journal_sha256 -or $origin.Complete.tree_sha256 -cne $Offer.target.stage_receipt.staged_tree_sha256){throw 'ROLLBACK_ORIGIN_CHANGED'}
 $root=Get-AuthWireStagingWriteJournalRoot $Binding;Assert-AuthWireStagingWriteJournalLocation $root $Binding
 $clock=[Diagnostics.Stopwatch]::StartNew();$start=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
 $decision=Enter-AuthWireWriteOutcomeLock $origin.StageJobId;$contentLease=$null
 try{
  $stage=Join-Path $root $origin.StageJobId;$engine=Join-Path $root $origin.FilesystemOperationId
  if(Test-Path -LiteralPath (Join-Path $stage 'execution-requires-review.json')){throw 'ROLLBACK_STAGE_REVIEW_REQUIRED'}
  Assert-AuthWireNoActiveStage $root $origin.StageJobId
  foreach($n in @('rollback-started.json','rolled-back.json')){if(Test-Path -LiteralPath (Join-Path $engine $n)){throw 'ROLLBACK_PREVIOUS_ATTEMPT_REQUIRES_REVIEW'}}
 $contentLease=New-AuthWireRollbackContentLease $Offer $Binding $Publisher $BaseUrl
 $null=Initialize-AuthWireRollbackDirectoryReader $Offer $Binding $contentLease.Context
 # Freshness begins BEFORE live directory/tree reads, never after the final
 # history recheck. Slow validation must consume the observation's lifetime.
 $observedAt=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds();$observationClock=[Diagnostics.Stopwatch]::StartNew()
 $directory=Get-AuthWireRollbackDirectoryObservationFromContext $Offer $Binding $contentLease.Context
 $expected=Get-AuthWireWriteGpoPath $directory.pdc $Offer.target.scope_target
 Assert-AuthWireCandidateGuid $directory.protected_gpo_id
 if($directory.gpo_root -cne $expected -or $directory.gpo_root -cne $origin.StageLive.gpo_root -or $directory.pdc -cne $origin.StageLive.pdc -or $directory.protected_gpo_id -cne $origin.Intent.protected_gpo_id -or
    $directory.protected_gpo_id -ceq $Offer.target.scope_target.gpo_id -or $directory.scope_sha256 -cne $Offer.target.preview_record.Preview.scope_observations_sha256){throw 'ROLLBACK_DIRECTORY_CHANGED'}
 $p=[AuthWire.Staging.TreeLeaseV1]::new();$tree=$null
 try{
  Add-AuthWireStagingGpoPins $p $directory.gpo_root $directory.gpo_root
  Add-AuthWireStagingGpoPins $p (Join-Path $directory.gpo_root 'Machine') $directory.gpo_root
  $relative=$origin.Intent.relative_destination
  $fixed='Machine/AuthWire-'+([guid]$Offer.target.scope_target.plan_id).ToString('N')+'-v'+$Offer.target.scope_target.plan_version+'-'+$Offer.target.scope_target.manifest_sha256
  if($relative -cne $fixed){throw 'ROLLBACK_STAGE_TARGET_CHANGED'}
  $tree=[AuthWire.Staging.TreeLeaseV1]::Tree((Join-Path $directory.gpo_root $relative.Replace('/','\')),$false)
  $rows=Get-AuthWireStagingFilesystemRows $tree
  if($rows.Count -ne 23 -or (Get-AuthWireStagingFilesystemDigest $rows) -cne $origin.Complete.tree_sha256){throw 'ROLLBACK_STAGED_TREE_CHANGED'}
  $all=Get-AuthWireSysvolInventory $directory.gpo_root
  $outside=@($all.Entries|Where-Object {$_.Path -cne $relative -and -not $_.Path.StartsWith($relative+'/',[StringComparison]::Ordinal)})
  if((Get-AuthWireScopeDataHash $outside) -cne $origin.Intent.baseline_sha256){throw 'ROLLBACK_OUTSIDE_CHANGED'}
  $again=Get-AuthWireRollbackDirectoryObservationFromContext $Offer $Binding $contentLease.Context
  if((Get-AuthWireWriteHash $again) -cne (Get-AuthWireWriteHash $directory)){throw 'ROLLBACK_DIRECTORY_CHANGED'}
  Assert-AuthWireRollbackContentLease $contentLease
  $stage=Join-Path $root $origin.StageJobId;$engine=Join-Path $root $origin.FilesystemOperationId
  if(Test-Path -LiteralPath (Join-Path $stage 'execution-requires-review.json')){throw 'ROLLBACK_STAGE_REVIEW_REQUIRED'}
  Assert-AuthWireNoActiveStage $root $origin.StageJobId
  foreach($n in @('rollback-started.json','rolled-back.json')){if(Test-Path -LiteralPath (Join-Path $engine $n)){throw 'ROLLBACK_PREVIOUS_ATTEMPT_REQUIRES_REVIEW'}}
  $now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
  if($now -lt $start -or $now -lt $observedAt -or $now -ge $observedAt+5 -or $now -ge $Offer.expires_at -or $observationClock.Elapsed.TotalSeconds -ge 5 -or $clock.Elapsed.TotalSeconds -ge 15){throw 'ROLLBACK_PREFLIGHT_EXPIRED'}
  # This timestamp is a NEW observation, never an extension of the old preview
  # or grant. All old timestamps and the stage/GPO durable lock stay unchanged.
  return [pscustomobject][ordered]@{format='AuthWireRollbackPreflightV1';job_id=$Offer.job_id;intent_sha256=$Offer.intent_sha256;target_sha256=(Get-AuthWireWriteHash $Offer.target);binding_scope=(Get-AuthWireJobScope $Binding);release_id=$Release;stage_job_id=$origin.StageJobId;stage_release_id=$origin.StageReleaseId;filesystem_operation_id=$origin.FilesystemOperationId;origin_chain_sha256=$origin.ChainSha256;complete_sha256=$Offer.target.stage_receipt.complete_journal_sha256;tree_sha256=$Offer.target.stage_receipt.staged_tree_sha256;directory_sha256=(Get-AuthWireWriteHash $directory);checked_at=$observedAt;expires_at=([long][Math]::Min(($observedAt+5),[long]$Offer.expires_at));read_only=$true;write_authorized=$false;can_delete=$false;can_apply_gpo=$false;requires_separate_claim=$true}
 }finally{if($tree){$tree.Dispose()};$p.Dispose()}
 }finally{Close-AuthWireRollbackContentLease $contentLease;$decision.ReleaseMutex();$decision.Dispose()}
}

function Get-AuthWireRollbackPreflight($Offer,[hashtable]$Binding,[string]$Release,[Security.Cryptography.RSACng]$Key,[string]$Publisher,[string]$BaseUrl){
 # Trusted local read-only entry. It is NOT a grant or a filesystem intent and
 # must not be passed to the low-level deletion engine as authorization.
 $clock=[Diagnostics.Stopwatch]::StartNew();$start=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
 Assert-AuthWireWriteOffer $Offer $Binding $Release $Offer.request_id
 if($Offer.operation -cne 'combined.filesystem.rollback.v1'){throw 'ROLLBACK_OPERATION_REQUIRED'}
 $originLock=Enter-AuthWireWriteOutcomeLock $Offer.target.stage_receipt.stage_job_id;$originPins=$null
 try{
 $root=Get-AuthWireStagingWriteJournalRoot $Binding;Assert-AuthWireStagingWriteJournalLocation $root $Binding
 # Pin the fixed original chain BEFORE validating it. Keep the exact verified
 # bytes and original-stage mutex held through both live observations; do not
 # waste their short lifetime repeating the entire historical traversal.
 $originPins=New-AuthWireRollbackOriginInputPins $root $Offer
 $origin=Read-AuthWireRollbackOrigin $Offer $Binding $Release $Key
 $result=Get-AuthWireRollbackLivePreflight $Offer $Binding $Release $Publisher $BaseUrl $origin
 if($clock.Elapsed.TotalSeconds -ge 15 -or [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() -lt $start){throw 'ROLLBACK_PREFLIGHT_EXPIRED'}
 return $result
 }finally{if($originPins){$originPins.Dispose()};$originLock.ReleaseMutex();$originLock.Dispose()}
}
