# Source-only rollback origin/preflight evidence. No CLAIM, consumption, writer,
# transport, cleanup, unlock or active worker/package registration.
Set-StrictMode -Version 2

function Read-AuthWireRollbackOrigin($Offer,[hashtable]$Binding,[string]$Release,[Security.Cryptography.RSACng]$Key){
 Assert-AuthWireWriteOffer $Offer $Binding $Release $Offer.request_id
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
  if(Test-Path -LiteralPath (Join-Path $job 'execution-requires-review.json')){throw 'ROLLBACK_STAGE_REVIEW_REQUIRED'}
  Assert-AuthWireNoActiveStage $root $id
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
  foreach($n in @('rollback-started.json','rolled-back.json')){if(Test-Path -LiteralPath (Join-Path $engine $n)){throw 'ROLLBACK_PREVIOUS_ATTEMPT_REQUIRES_REVIEW'}}
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

function Get-AuthWireRollbackDirectoryObservation($Offer,[hashtable]$Binding,[string]$Publisher,[string]$BaseUrl){
 # Explicit service identity plus existing bounded content/AD/GPO/ACL checks.
 # Unlike the stage preview this does not require an empty Machine directory.
 $identity=[Security.Principal.WindowsIdentity]::GetCurrent()
 try{if($identity.User.Value -cne $Binding.service_sid -or -not $identity.IsAuthenticated -or ([Security.Principal.WindowsPrincipal]::new($identity)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){throw 'ROLLBACK_SERVICE_IDENTITY_REQUIRED'}}finally{$identity.Dispose()}
 $t=$Offer.target.scope_target;$context=Get-AuthWireCombinedScopeContext $t $Binding $Publisher $BaseUrl
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

function Get-AuthWireRollbackPreflight($Offer,[hashtable]$Binding,[string]$Release,[Security.Cryptography.RSACng]$Key,[string]$Publisher,[string]$BaseUrl){
 # Trusted local read-only entry. It is NOT a grant or a filesystem intent and
 # must not be passed to the low-level deletion engine as authorization.
 $clock=[Diagnostics.Stopwatch]::StartNew();$start=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
 $origin=Read-AuthWireRollbackOrigin $Offer $Binding $Release $Key
 # Freshness begins BEFORE live directory/tree reads, never after the final
 # history recheck. Slow validation must consume the observation's lifetime.
 $observedAt=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds();$observationClock=[Diagnostics.Stopwatch]::StartNew()
 $directory=Get-AuthWireRollbackDirectoryObservation $Offer $Binding $Publisher $BaseUrl
 $expected=Get-AuthWireWriteGpoPath $directory.pdc $Offer.target.scope_target
 Assert-AuthWireCandidateGuid $directory.protected_gpo_id
 if($directory.gpo_root -cne $expected -or $directory.gpo_root -cne $origin.StageLive.gpo_root -or $directory.pdc -cne $origin.StageLive.pdc -or $directory.protected_gpo_id -cne $origin.Intent.protected_gpo_id -or
    $directory.protected_gpo_id -ceq $Offer.target.scope_target.gpo_id -or $directory.scope_sha256 -cne $Offer.target.preview_record.Preview.scope_observations_sha256){throw 'ROLLBACK_DIRECTORY_CHANGED'}
 $p=[AuthWire.Staging.TreeLeaseV1]::new();$tree=$null
 try{
  $p.PinAncestors($directory.gpo_root);$p.PinAncestors((Join-Path $directory.gpo_root 'Machine'))
  $relative=$origin.Intent.relative_destination
  $fixed='Machine/AuthWire-'+([guid]$Offer.target.scope_target.plan_id).ToString('N')+'-v'+$Offer.target.scope_target.plan_version+'-'+$Offer.target.scope_target.manifest_sha256
  if($relative -cne $fixed){throw 'ROLLBACK_STAGE_TARGET_CHANGED'}
  $tree=[AuthWire.Staging.TreeLeaseV1]::Tree((Join-Path $directory.gpo_root $relative.Replace('/','\')),$false)
  $rows=Get-AuthWireStagingFilesystemRows $tree
  if($rows.Count -ne 23 -or (Get-AuthWireStagingFilesystemDigest $rows) -cne $origin.Complete.tree_sha256){throw 'ROLLBACK_STAGED_TREE_CHANGED'}
  $all=Get-AuthWireSysvolInventory $directory.gpo_root
  $outside=@($all.Entries|Where-Object {$_.Path -cne $relative -and -not $_.Path.StartsWith($relative+'/',[StringComparison]::Ordinal)})
  if((Get-AuthWireScopeDataHash $outside) -cne $origin.Intent.baseline_sha256){throw 'ROLLBACK_OUTSIDE_CHANGED'}
  $again=Get-AuthWireRollbackDirectoryObservation $Offer $Binding $Publisher $BaseUrl
  if((Get-AuthWireWriteHash $again) -cne (Get-AuthWireWriteHash $directory)){throw 'ROLLBACK_DIRECTORY_CHANGED'}
  $last=Read-AuthWireRollbackOrigin $Offer $Binding $Release $Key
  if($last.ChainSha256 -cne $origin.ChainSha256){throw 'ROLLBACK_STAGE_RESULT_CHANGED'}
  $now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
  if($now -lt $start -or $now -lt $observedAt -or $now -ge $observedAt+5 -or $now -ge $Offer.expires_at -or $observationClock.Elapsed.TotalSeconds -ge 5 -or $clock.Elapsed.TotalSeconds -ge 15){throw 'ROLLBACK_PREFLIGHT_EXPIRED'}
  # This timestamp is a NEW observation, never an extension of the old preview
  # or grant. All old timestamps and the stage/GPO durable lock stay unchanged.
  return [pscustomobject][ordered]@{format='AuthWireRollbackPreflightV1';job_id=$Offer.job_id;intent_sha256=$Offer.intent_sha256;target_sha256=(Get-AuthWireWriteHash $Offer.target);binding_scope=(Get-AuthWireJobScope $Binding);release_id=$Release;stage_job_id=$origin.StageJobId;stage_release_id=$origin.StageReleaseId;filesystem_operation_id=$origin.FilesystemOperationId;origin_chain_sha256=$origin.ChainSha256;complete_sha256=$Offer.target.stage_receipt.complete_journal_sha256;tree_sha256=$Offer.target.stage_receipt.staged_tree_sha256;directory_sha256=(Get-AuthWireWriteHash $directory);checked_at=$observedAt;expires_at=([long][Math]::Min(($observedAt+5),[long]$Offer.expires_at));read_only=$true;write_authorized=$false;can_delete=$false;can_apply_gpo=$false;requires_separate_claim=$true}
 }finally{if($tree){$tree.Dispose()};$p.Dispose()}
}
