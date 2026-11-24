# Source-only governed local history archiving. No peer, scheduler or service API.
# Completed cycles are copied, verified and sealed before local originals retire.
# Partial maintenance is a durable stop; this module never repairs or unlocks it.
Set-StrictMode -Version 2
function Read-AuthWireEmptyStageEngine($Original,$State,[string]$Root,$Pins){
 $s=$Original.Intent;$live=$Original.Live;$op=$s.Intent.filesystem_operation_id
 $engine=Join-Path $Root $op;$Pins.PinAncestors($engine)
 $items=@(Get-ChildItem -LiteralPath $engine -Force)
 if($items.Count -ne 1 -or $items[0].Name -cne 'intent.json' -or $items[0].PSIsContainer){throw 'EMPTY_RECOVERY_ENGINE_NOT_INTENT_ONLY'}
 $file=Join-Path $engine 'intent.json';$Pins.PinFile($file);$ei=Read-AuthWireStagingJournal $file
 Assert-AuthWireCandidateFields $ei @('format','operation_id','preview_sha256','target_sha256','gpo_root','relative_destination','baseline_sha256','protected_gpo_id')
 $approved=$State.Offer.target.preview_record
 # Validate historical ownership at the recorded original consumption time.
 # This is not a new stage approval: execution still uses the unmodified live
 # preview-expiry gate; cleanup additionally requires fresh current observations.
 $target=$State.Offer.target.scope_target;Assert-AuthWireCombinedScopeTarget $target
 Assert-AuthWireCandidateGuid $live.protected_gpo_id
 if($target.gpo_id -ceq $live.protected_gpo_id -or [IO.Path]::GetFileName($live.gpo_root) -cne ('{'+$target.gpo_id+'}')){throw 'EMPTY_RECOVERY_GPO_BOUNDARY_REJECTED'}
 $pv=$approved.Preview;$at=$s.Consumed.consumed_at
 if((Get-AuthWireWritePreviewHash $pv) -cne $approved.PreviewSha256 -or $pv.checked_at -gt $at -or $pv.expires_at -le $at -or $pv.expires_at-$pv.checked_at -ne 90){throw 'EMPTY_RECOVERY_ORIGINAL_PREVIEW_REJECTED'}
 $relative='Machine/AuthWire-'+([guid]$target.plan_id).ToString('N')+'-v'+$target.plan_version+'-'+$target.manifest_sha256
 if($pv.relative_destination -cne $relative -or $pv.scope_target_sha256 -cne (Get-AuthWireCombinedScopeTargetHash $target)){throw 'EMPTY_RECOVERY_TARGET_CHANGED'}
 if($ei.format -cne 'AuthWireFilesystemIntentV1' -or $ei.operation_id -cne $op -or $ei.preview_sha256 -cne $approved.PreviewSha256 -or $ei.target_sha256 -cne $approved.Preview.scope_target_sha256 -or $ei.gpo_root -cne $live.gpo_root -or $ei.relative_destination -cne $relative -or $ei.baseline_sha256 -cne $approved.Preview.baseline_inventory_sha256 -or $ei.protected_gpo_id -cne $live.protected_gpo_id){throw 'EMPTY_RECOVERY_ENGINE_INTENT_REJECTED'}
 return $ei
}
function Get-AuthWireEmptyStageInventory([string]$Gpo,[string]$Relative,[string]$Baseline){
 $v=Get-AuthWireSysvolInventory $Gpo
 $inside=@($v.Entries|Where-Object {$_.Path -ceq $Relative -or $_.Path.StartsWith($Relative+'/',[StringComparison]::Ordinal)})
 if($inside.Count -ne 1 -or $inside[0].Path -cne $Relative -or $inside[0].Kind -cne 'directory'){throw 'EMPTY_RECOVERY_DESTINATION_NOT_EMPTY'}
 $outside=@($v.Entries|Where-Object {$_.Path -cne $Relative -and -not $_.Path.StartsWith($Relative+'/',[StringComparison]::Ordinal)})
 if((Get-AuthWireScopeDataHash $outside) -cne $Baseline){throw 'EMPTY_RECOVERY_OUTSIDE_DRIFT'}
 return [pscustomobject]@{Entries=$outside;FileBytes=$v.FileBytes;Sha256=$Baseline}
}
function Assert-AuthWireEmptyStageRow($Rows,[hashtable]$Binding){
 if(@($Rows).Count -ne 1 -or $Rows[0].Path -cne '' -or $Rows[0].Kind -cne 'directory' -or $Rows[0].Size -ne 0){throw 'EMPTY_RECOVERY_DESTINATION_NOT_EMPTY'}
 if(([Security.AccessControl.RawSecurityDescriptor]::new($Rows[0].Sddl)).Owner.Value -cne $Binding.service_sid){throw 'EMPTY_RECOVERY_OWNER_CHANGED'}
}
function Get-AuthWireEmptyCleanupFrame($Body,[string]$Purpose){
 if($Purpose -cnotin @('AUTHWIRE-EMPTY-STAGE-CLEANUP-REVIEW-V1','AUTHWIRE-EMPTY-STAGE-CLEANUP-COMPLETE-V1')){throw 'EMPTY_RECOVERY_PURPOSE_REJECTED'}
 return ,([Text.Encoding]::ASCII.GetBytes($Purpose+[char]10+(Get-AuthWireWriteHash $Body)+[char]10))
}
function New-AuthWireEmptyCleanupProof($Body,[Security.Cryptography.RSACng]$Key,[string]$Purpose){
 return [pscustomobject]@{Body=$Body;Signature=[Convert]::ToBase64String($Key.SignData((Get-AuthWireEmptyCleanupFrame $Body $Purpose),[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1))}
}
function Assert-AuthWireEmptyCleanupProof($Proof,[Security.Cryptography.RSACng]$Key,[string]$Purpose){
 Assert-AuthWireCandidateFields $Proof @('Body','Signature')
 if(-not $Key.VerifyData((Get-AuthWireEmptyCleanupFrame $Proof.Body $Purpose),(ConvertFrom-AuthWireWriteBase64 $Proof.Signature 512),[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1)){throw 'EMPTY_RECOVERY_SIGNATURE_REJECTED'}
}
function Get-AuthWireEmptyCleanupState([string]$Root,[string]$JobId,[hashtable]$Binding,[Security.Cryptography.RSACng]$Key,$Pins,[bool]$Historical=$false,$ExistingState=$null,[string]$ExistingLife=''){
 if($null -eq $ExistingState){$h=Read-AuthWireLifecycleHistory $Root $Binding $Key;$state=$h.ActiveStates[-1];$life=$h.Life}
 else{$state=$ExistingState;$life=if($ExistingLife -ceq ''){Get-AuthWireWriteLifecyclePath $Root $Binding}else{$ExistingLife}}
 if($state.Offer.job_id -cne $JobId){throw 'EMPTY_RECOVERY_NOT_LATEST'}
 $done=Read-AuthWireLifecycleCompletion $Root $life $state $Binding $Key
 if($done.outcome -cne 'requires_review'){throw 'EMPTY_RECOVERY_RESULT_REJECTED'}
 $job=Join-Path $Root $JobId;$Pins.PinAncestors($job)
 foreach($n in @('offer.json','authorization.json','grant-consumed.json','filesystem-intent.json','stage-launch.json','stage-child.json','stage-entered.json','stage-preflight.json','execution-requires-review.json','result-outbox.json','result-accepted.json')){$Pins.PinFile((Join-Path $job $n))}
 $value=Get-AuthWireEmptyStageOriginal $Root (Join-Path $life $state.Slot) $state $Binding $Key $Historical
 if($null -eq $value){throw 'EMPTY_RECOVERY_ORIGINAL_REJECTED'}
 $engine=Read-AuthWireEmptyStageEngine $value $state $Root $Pins
 $s=$value.Intent;$box=Read-AuthWireWriteResultOutbox $Root $JobId $Binding $state.Started.release_id $Key
 if($box.body.outcome -cne 'requires_review' -or $box.body.reason -cne 'OUTCOME_UNKNOWN' -or $box.body.journal_sha256 -cne '' -or $box.body.tree_sha256 -cne ''){throw 'EMPTY_RECOVERY_RESULT_REJECTED'}
 $hash=Get-AuthWireWriteHash ([pscustomobject]@{consumption=$value.Review;engine=$engine;result=$box.body_sha256;completion=(Get-AuthWireWriteHash $done);offer=(Get-AuthWireWriteHash $state.Offer)})
 $relative=$engine.relative_destination
 return [pscustomobject]@{State=$state;Completion=$done;Original=$value;Engine=$engine;OriginalSha256=$hash;Relative=$relative;Gpo=$engine.gpo_root;Destination=[IO.Path]::Combine($engine.gpo_root,$relative.Replace('/','\'));Baseline=$engine.baseline_sha256}
}
function New-AuthWireEmptyCleanupBody($Original,$Row,$Fresh,[hashtable]$Binding,[long]$At){
 Assert-AuthWireEmptyStageRow @($Row) $Binding
 $now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
 if($At -gt $now -or $Fresh.Preview.checked_at -gt $now -or $now -ge $Fresh.Preview.checked_at+60){throw 'EMPTY_RECOVERY_FRESH_OBSERVATION_EXPIRED'}
 $p=ConvertTo-AuthWireWriteOrderedPreview $Fresh.Preview;$approved=$Original.State.Offer.target.preview_record
 $p.checked_at=$approved.Preview.checked_at;$p.expires_at=$approved.Preview.expires_at
 if((Get-AuthWireWritePreviewHash $p) -cne $approved.PreviewSha256){throw 'EMPTY_RECOVERY_FRESH_OBSERVATIONS_CHANGED'}
 return [pscustomobject]@{format='AuthWireEmptyStageCleanupReviewV1';job_id=$Original.State.Offer.job_id;filesystem_operation_id=$Original.Engine.operation_id;scope_sha256=(Get-AuthWireJobScope $Binding);original_records_sha256=$Original.OriginalSha256;engine_intent_sha256=(Get-AuthWireWriteHash $Original.Engine);destination_row_sha256=(Get-AuthWireWriteHash ([pscustomobject]@{Path=[string]$Row.Path;Kind=[string]$Row.Kind;Size=[long]$Row.Size;Sha256=[string]$Row.Sha256;Sddl=[string]$Row.Sddl;Identity=[string]$Row.Identity}));baseline_inventory_sha256=$Original.Baseline;approved_preview_sha256=$approved.PreviewSha256;observed_at=$At;expires_at=($At+60);delete_only_empty_directory=$true;release_gpo_lock=$false;can_apply_gpo=$false}
}
function Get-AuthWireEmptyStageCleanupReview([string]$Root,[string]$JobId,[hashtable]$Binding,[Security.Cryptography.RSACng]$Key,[string]$Publisher,[string]$BaseUrl){
 $lock=Enter-AuthWireWriteCycleLock $Binding;$pins=[AuthWire.Staging.TreeLeaseV1]::new();$tree=$null
 try{
  $o=Get-AuthWireEmptyCleanupState $Root $JobId $Binding $Key $pins
  Add-AuthWireStagingGpoPins $pins $o.Gpo $o.Gpo;Add-AuthWireStagingGpoPins $pins ([IO.Path]::Combine($o.Gpo,'Machine')) $o.Gpo
  $tree=[AuthWire.Staging.TreeLeaseV1]::Tree($o.Destination,$false);Assert-AuthWireEmptyStageRow $tree.Rows $Binding
  $fresh=Get-AuthWireEmptyStageCleanupPreview $o.State.Offer.target.scope_target $Binding $Publisher $BaseUrl $o
  return (New-AuthWireEmptyCleanupProof (New-AuthWireEmptyCleanupBody $o $tree.Rows[0] $fresh $Binding $fresh.Preview.checked_at) $Key 'AUTHWIRE-EMPTY-STAGE-CLEANUP-REVIEW-V1')
 }finally{if($tree){$tree.Dispose()};$pins.Dispose();$lock.ReleaseMutex();$lock.Dispose()}
}
function Complete-AuthWireEmptyStageCleanup([string]$Root,[string]$JobId,[hashtable]$Binding,[Security.Cryptography.RSACng]$Key,[string]$Publisher,[string]$BaseUrl,$Proof,[string]$ExpectedReviewSha256,[string]$Acknowledge){
 # Explicit, administrator-reviewed AllSigned maintenance only. Never called
 # by the peer HTTP endpoint, worker, or original expired write grant.
 if($Acknowledge -cne 'remove_exact_empty_owned_stage_directory' -or (Get-AuthWireWriteHash $Proof) -cne $ExpectedReviewSha256){throw 'EMPTY_RECOVERY_EXPLICIT_REVIEW_REQUIRED'}
 Assert-AuthWireEmptyCleanupProof $Proof $Key 'AUTHWIRE-EMPTY-STAGE-CLEANUP-REVIEW-V1'
 $lock=Enter-AuthWireWriteCycleLock $Binding;$outcome=$null;$pins=[AuthWire.Staging.TreeLeaseV1]::new();$owned=$null
 try{
  $outcome=Enter-AuthWireWriteOutcomeLock $JobId
  $job=Join-Path $Root $JobId
  foreach($n in @('empty-stage-cleanup-intent.json','empty-stage-cleanup-complete.json')){if(Test-Path -LiteralPath (Join-Path $job $n)){throw 'EMPTY_RECOVERY_ALREADY_STARTED_REQUIRES_REVIEW'}}
  $o=Get-AuthWireEmptyCleanupState $Root $JobId $Binding $Key $pins
  Add-AuthWireStagingGpoPins $pins $o.Gpo $o.Gpo;Add-AuthWireStagingGpoPins $pins ([IO.Path]::Combine($o.Gpo,'Machine')) $o.Gpo
  $pins.PinFile((Join-Path $Root ('gpo-'+$o.State.Offer.target.scope_target.gpo_id+'.json')))
  $owned=[AuthWire.Staging.TreeLeaseV1]::Tree($o.Destination,$true);Assert-AuthWireEmptyStageRow $owned.Rows $Binding
  $fresh=Get-AuthWireEmptyStageCleanupPreview $o.State.Offer.target.scope_target $Binding $Publisher $BaseUrl $o
  $expected=New-AuthWireEmptyCleanupBody $o $owned.Rows[0] $fresh $Binding $Proof.Body.observed_at
  $now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
  if((Get-AuthWireWriteHash $expected) -cne (Get-AuthWireWriteHash $Proof.Body) -or $now -lt $Proof.Body.observed_at -or $now -ge $Proof.Body.expires_at){throw 'EMPTY_RECOVERY_REVIEW_CHANGED_OR_EXPIRED'}
  $record=[pscustomobject]@{format='AuthWireEmptyStageCleanupIntentV1';review=$Proof;review_sha256=$ExpectedReviewSha256;acknowledge=$Acknowledge}
  Write-AuthWireStagingJournal (Join-Path $job 'empty-stage-cleanup-intent.json') $record
  $start=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds();$ticks=[Diagnostics.Stopwatch]::GetTimestamp();$until=[long][Math]::Min($start+30,$Proof.Body.expires_at)
  $owned.DeleteOwnedTreeBefore($until,$start,$ticks);$owned.Dispose();$owned=$null
  if(Test-Path -LiteralPath $o.Destination){throw 'EMPTY_RECOVERY_DESTINATION_STILL_PRESENT'}
  $restored=Get-AuthWireSysvolInventory $o.Gpo
  if($restored.Sha256 -cne $o.Baseline){throw 'EMPTY_RECOVERY_POSTCHECK_DRIFT'}
  $body=[pscustomobject]@{format='AuthWireEmptyStageCleanupCompleteV1';job_id=$JobId;filesystem_operation_id=$o.Engine.operation_id;scope_sha256=(Get-AuthWireJobScope $Binding);original_records_sha256=$o.OriginalSha256;engine_intent_sha256=(Get-AuthWireWriteHash $o.Engine);destination_row_sha256=$Proof.Body.destination_row_sha256;baseline_inventory_sha256=$o.Baseline;restored_inventory_sha256=$restored.Sha256;cleanup_intent_sha256=(Get-AuthWireWriteHash $record);review_evidence_sha256=$ExpectedReviewSha256;completed_at=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds();removed_empty_directory=$true;can_apply_gpo=$false}
  $receipt=New-AuthWireEmptyCleanupProof $body $Key 'AUTHWIRE-EMPTY-STAGE-CLEANUP-COMPLETE-V1'
  Write-AuthWireStagingJournal (Join-Path $job 'empty-stage-cleanup-complete.json') $receipt
  return $receipt
 }finally{if($owned){$owned.Dispose()};$pins.Dispose();if($outcome){$outcome.ReleaseMutex();$outcome.Dispose()};$lock.ReleaseMutex();$lock.Dispose()}
}
function Get-AuthWireRecoveredEmptyStageReview([string]$Root,$State,[hashtable]$Binding,[Security.Cryptography.RSACng]$Key,[bool]$Historical=$false,[string]$Life=''){
 $job=Join-Path $Root $State.Offer.job_id;$path=Join-Path $job 'empty-stage-cleanup-complete.json'
 if(-not (Test-Path -LiteralPath $path)){return}
 $pins=[AuthWire.Staging.TreeLeaseV1]::new()
 try{
  $o=Get-AuthWireEmptyCleanupState $Root $State.Offer.job_id $Binding $Key $pins $Historical $State $Life
  $pins.PinFile($path);$pins.PinFile((Join-Path $job 'empty-stage-cleanup-intent.json'))
  $receipt=Read-AuthWireStagingJournal $path;Assert-AuthWireEmptyCleanupProof $receipt $Key 'AUTHWIRE-EMPTY-STAGE-CLEANUP-COMPLETE-V1';$b=$receipt.Body
  Assert-AuthWireCandidateFields $b @('format','job_id','filesystem_operation_id','scope_sha256','original_records_sha256','engine_intent_sha256','destination_row_sha256','baseline_inventory_sha256','restored_inventory_sha256','cleanup_intent_sha256','review_evidence_sha256','completed_at','removed_empty_directory','can_apply_gpo')
  $intent=Read-AuthWireStagingJournal (Join-Path $job 'empty-stage-cleanup-intent.json');Assert-AuthWireCandidateFields $intent @('format','review','review_sha256','acknowledge')
  Assert-AuthWireEmptyCleanupProof $intent.review $Key 'AUTHWIRE-EMPTY-STAGE-CLEANUP-REVIEW-V1';$r=$intent.review.Body
  if($intent.format -cne 'AuthWireEmptyStageCleanupIntentV1' -or $intent.acknowledge -cne 'remove_exact_empty_owned_stage_directory' -or $intent.review_sha256 -cne (Get-AuthWireWriteHash $intent.review) -or $b.format -cne 'AuthWireEmptyStageCleanupCompleteV1' -or $b.job_id -cne $State.Offer.job_id -or $b.filesystem_operation_id -cne $o.Engine.operation_id -or $b.scope_sha256 -cne (Get-AuthWireJobScope $Binding) -or $b.original_records_sha256 -cne $o.OriginalSha256 -or $b.engine_intent_sha256 -cne (Get-AuthWireWriteHash $o.Engine) -or $b.baseline_inventory_sha256 -cne $o.Baseline -or $b.restored_inventory_sha256 -cne $o.Baseline -or $b.cleanup_intent_sha256 -cne (Get-AuthWireWriteHash $intent) -or $b.review_evidence_sha256 -cne $intent.review_sha256 -or $b.removed_empty_directory -isnot [bool] -or -not $b.removed_empty_directory -or $b.can_apply_gpo -isnot [bool] -or $b.can_apply_gpo -or -not (Test-AuthWireWriteInteger $b.completed_at) -or $b.completed_at -gt [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() -or $b.completed_at -lt $r.observed_at -or $b.completed_at -ge $r.expires_at){throw 'EMPTY_RECOVERY_RECEIPT_REJECTED'}
  foreach($n in @('job_id','filesystem_operation_id','scope_sha256','original_records_sha256','engine_intent_sha256','destination_row_sha256','baseline_inventory_sha256')){if($r.$n -cne $b.$n){throw 'EMPTY_RECOVERY_RECEIPT_REJECTED'}}
  foreach($n in @('destination_row_sha256','cleanup_intent_sha256','review_evidence_sha256')){if(-not (Test-AuthWireWriteHash $b.$n)){throw 'EMPTY_RECOVERY_RECEIPT_REJECTED'}}
  $v=$o.Original.Review;$v.Phase='recovered_empty_stage_destination'
  $v|Add-Member NoteProperty EngineIntentSha256 $b.engine_intent_sha256
  $v|Add-Member NoteProperty EmptyCleanupReceiptSha256 (Get-AuthWireWriteHash $receipt)
  $v|Add-Member NoteProperty DestinationRowSha256 $b.destination_row_sha256
  return $v
 }finally{$pins.Dispose()}
}

function Get-AuthWireHistoryCycleRows($Lease){
 $rows=@()
 foreach($r in $Lease.Rows){
  if($r.Kind -ceq 'directory' -and $r.Path -ceq ''){continue}
  if($r.Kind -cne 'file' -or $r.Path -cmatch '[/\\:]' -or $r.Size -lt 1 -or $r.Size -gt 65536){throw 'HISTORY_CYCLE_RECORD_REJECTED'}
  $rows+=,[pscustomobject]@{path=$r.Path;size=[long]$r.Size;sha256=$r.Sha256}
 }
 if($rows.Count -lt 1 -or $rows.Count -gt 7){throw 'HISTORY_CYCLE_RECORD_REJECTED'}
 return ,$rows
}
function Get-AuthWireHistoryArchiveFrame($Body){
 return [Text.Encoding]::ASCII.GetBytes(("AUTHWIRE-WRITE-HISTORY-ARCHIVE-V1`n"+(ConvertTo-AuthWireWriteJson $Body)+"`n"))
}
# Shared active/archive eligibility: uncertain results require their exact
# complete, independently signed closure; their original outcome stays unknown.
function Test-AuthWireHistoryAcceptedOutcome([string]$Root,[string]$Life,$State,$Completion,[hashtable]$Binding,[Security.Cryptography.RSACng]$Key){
 if($Completion.outcome -cin @('no_job','staged','rolled_back')){return $true}
 if($Completion.outcome -ceq 'refused_before_authorization'){return (Test-AuthWireRefusedRollbackRetired $Root $Life $State $Binding $Key)}
 if($Completion.outcome -ceq 'requires_review'){
  if(Test-AuthWireConsumedStageClosed $Root $Life $State $Binding $Key){return $true}
  if(Test-AuthWireConsumedRollbackRetired $Root $Life $State $Binding $Key){return $true}
  return (Test-AuthWirePreIntentRollbackRetired $Root $Life $State $Binding $Key)
 }
 return $false
}

function Read-AuthWireHistoryArchives([string]$Root,[string]$Life,$Baseline,[hashtable]$Binding,[Security.Cryptography.RSACng]$Key){
 $area=Join-Path $Life 'history-archives';$states=@();$through=0;$head='';$count=0
 if(-not (Test-Path -LiteralPath $area)){return [pscustomobject]@{States=$states;Through=$through;Head=$head;Count=$count}}
 $p=[AuthWire.Staging.TreeLeaseV1]::new();$leases=[Collections.Generic.List[IDisposable]]::new()
 try{
  $p.PinAncestors($area);$p.PinDirectory($area);Assert-AuthWireStagingJournalRoot $area
  $items=@(Get-ChildItem -LiteralPath $area -Force|Sort-Object Name)
  if($items.Count -lt 1 -or $items.Count -gt 8){throw 'HISTORY_ARCHIVE_QUOTA_REQUIRES_MAINTENANCE'}
  foreach($item in $items){
   $count++;$index=$count.ToString('D6')
   if(-not $item.PSIsContainer -or $item.Name -cne $index){throw 'HISTORY_ARCHIVE_SEQUENCE_REJECTED'}
   $dir=$item.FullName;$p.PinAncestors($dir);$p.PinDirectory($dir)
   $entries=@(Get-ChildItem -LiteralPath $dir -Force)
   if($entries.Count -ne 4){throw 'HISTORY_RETENTION_RECONCILIATION_REQUIRED'}
   foreach($i in $entries){
    if($i.Name -ceq 'cycles' -and $i.PSIsContainer){$p.PinAncestors($i.FullName);$p.PinDirectory($i.FullName);continue}
    if($i.PSIsContainer -or $i.Name -cnotin @('intent.json','archive.json','committed.json')){throw 'HISTORY_UNKNOWN_ARCHIVE_RECORD'}
    $p.PinFile($i.FullName)
   }
   foreach($n in @('intent.json','archive.json','committed.json','cycles')){if(-not (Test-Path -LiteralPath (Join-Path $dir $n))){throw 'HISTORY_RETENTION_RECONCILIATION_REQUIRED'}}
   $intent=Read-AuthWireStagingJournal (Join-Path $dir 'intent.json')
   Assert-AuthWireCandidateFields $intent @('format','binding_scope','archive_index','baseline_sha256','previous_archive_sha256','review_sha256','first_slot','last_slot','started_at')
   $v=Read-AuthWireStagingJournal (Join-Path $dir 'archive.json');Assert-AuthWireCandidateFields $v @('body','signature')
   $a=$v.body
   Assert-AuthWireCandidateFields $a @('format','policy','binding_scope','baseline_sha256','previous_archive_sha256','archive_index','first_slot','last_slot','cycle_count','record_count','total_bytes','cycle_manifest_sha256','protected_manifest_sha256','review_sha256','review_checked_at','review_expires_at','intent_sha256','created_at','cycles')
   Assert-AuthWireStageStrings $a @('format','policy','binding_scope','baseline_sha256','previous_archive_sha256','first_slot','last_slot','cycle_manifest_sha256','protected_manifest_sha256','review_sha256','intent_sha256')
   $scope=Get-AuthWireJobScope $Binding;$baselineHash=Get-AuthWireWriteHash $Baseline
   if($a.format -cne 'AuthWireWriteHistoryArchiveV1' -or $a.policy -cne 'retain_observed_cycles_v1' -or $a.binding_scope -cne $scope -or $a.baseline_sha256 -cne $baselineHash -or $a.previous_archive_sha256 -cne $head -or
      $a.archive_index -isnot [int] -or $a.archive_index -ne $count -or $a.first_slot -cne ($through+1).ToString('D6') -or $a.last_slot -cne ($through+64).ToString('D6') -or
      $a.cycle_count -isnot [int] -or $a.cycle_count -ne 64 -or $a.cycles -isnot [array] -or $a.cycles.Count -ne 64 -or
      -not (Test-AuthWireWriteInteger $a.record_count) -or $a.record_count -gt 448 -or -not (Test-AuthWireWriteInteger $a.total_bytes) -or $a.total_bytes -gt 16777216 -or
      -not (Test-AuthWireWriteInteger $a.created_at) -or $a.created_at -gt [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() -or
      -not (Test-AuthWireWriteInteger $a.review_checked_at) -or -not (Test-AuthWireWriteInteger $a.review_expires_at) -or $a.review_expires_at-$a.review_checked_at -ne 60 -or $a.created_at -lt $a.review_checked_at -or $a.created_at -ge $a.review_expires_at){throw 'HISTORY_ARCHIVE_REJECTED'}
   foreach($n in @('cycle_manifest_sha256','protected_manifest_sha256','review_sha256','intent_sha256')){if(-not (Test-AuthWireWriteHash $a.$n)){throw 'HISTORY_ARCHIVE_REJECTED'}}
   if($a.cycle_manifest_sha256 -cne (Get-AuthWireWriteHash @($a.cycles))){throw 'HISTORY_ARCHIVE_REJECTED'}
   $sig=ConvertFrom-AuthWireWriteBase64 $v.signature 512
   if($sig.Length -ne $Key.KeySize/8 -or -not $Key.VerifyData((Get-AuthWireHistoryArchiveFrame $a),$sig,[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1)){throw 'HISTORY_ARCHIVE_SIGNATURE_REJECTED'}
   if($intent.format -cne 'AuthWireWriteHistoryIntentV1' -or $intent.binding_scope -cne $scope -or $intent.archive_index -isnot [int] -or $intent.archive_index -ne $count -or
      $intent.baseline_sha256 -cne $baselineHash -or $intent.previous_archive_sha256 -cne $head -or $intent.review_sha256 -cne $a.review_sha256 -or $intent.first_slot -cne $a.first_slot -or $intent.last_slot -cne $a.last_slot -or
      $intent.started_at -ne $a.created_at -or $a.intent_sha256 -cne (Get-AuthWireWriteHash $intent)){throw 'HISTORY_ARCHIVE_INTENT_REJECTED'}
   $committed=Read-AuthWireStagingJournal (Join-Path $dir 'committed.json')
   Assert-AuthWireCandidateFields $committed @('format','binding_scope','archive_index','archive_sha256','completed_at')
   $archiveHash=Get-AuthWireWriteHash $v
   if($committed.format -cne 'AuthWireWriteHistoryCommittedV1' -or $committed.binding_scope -cne $scope -or $committed.archive_index -isnot [int] -or $committed.archive_index -ne $count -or $committed.archive_sha256 -cne $archiveHash -or
      -not (Test-AuthWireWriteInteger $committed.completed_at) -or $committed.completed_at -lt $a.created_at -or $committed.completed_at -ge $a.review_expires_at -or $committed.completed_at -gt [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()){throw 'HISTORY_ARCHIVE_COMMIT_REJECTED'}
   $cycles=Join-Path $dir 'cycles';$dirs=@(Get-ChildItem -LiteralPath $cycles -Force|Sort-Object Name)
   if($dirs.Count -ne 64){throw 'HISTORY_ARCHIVE_CYCLES_REJECTED'}
   $bytes=[long]0;$records=0
   for($j=0;$j -lt 64;$j++){
    $slot=($through+$j+1).ToString('D6');$row=$a.cycles[$j];Assert-AuthWireCandidateFields $row @('slot','records_sha256')
    if(-not $dirs[$j].PSIsContainer -or $dirs[$j].Name -cne $slot -or $row.slot -cne $slot -or -not (Test-AuthWireWriteHash $row.records_sha256)){throw 'HISTORY_ARCHIVE_CYCLES_REJECTED'}
    $lease=[AuthWire.Staging.TreeLeaseV1]::Tree($dirs[$j].FullName,$false);$leases.Add($lease)
    $rows=Get-AuthWireHistoryCycleRows $lease
    if((Get-AuthWireWriteHash $rows) -cne $row.records_sha256){throw 'HISTORY_ARCHIVE_BYTES_CHANGED'}
    foreach($r in $rows){$bytes+=$r.size;$records++}
    $s=Read-AuthWireLifecyclePoll $cycles $slot $Binding $Key
    if($s.Phase -cne 'reply_saved'){throw 'HISTORY_ARCHIVE_INCOMPLETE_CYCLE'}
    $done=Read-AuthWireLifecycleCompletion $Root $cycles $s $Binding $Key
    $safe=Test-AuthWireHistoryAcceptedOutcome $Root $cycles $s $done $Binding $Key
    if(-not $safe -or $done.completed_at -gt $a.created_at){throw 'HISTORY_ARCHIVE_INCOMPLETE_CYCLE'}
    $states+=,$s
   }
   if($bytes -ne $a.total_bytes -or $records -ne $a.record_count){throw 'HISTORY_ARCHIVE_TOTALS_REJECTED'}
   $through+=64;$head=$archiveHash
  }
  return [pscustomobject]@{States=$states;Through=$through;Head=$head;Count=$count}
 }finally{foreach($lease in $leases){$lease.Dispose()};$p.Dispose()}
}

function Read-AuthWireLifecycleHistory([string]$Root,[hashtable]$Binding,[Security.Cryptography.RSACng]$Key){
 $life=Get-AuthWireWriteLifecyclePath $Root $Binding;$baseline=Read-AuthWireLifecycleBaseline $Root $Binding $Key
 $archives=Read-AuthWireHistoryArchives $Root $life $baseline $Binding $Key
 $slots=Get-AuthWireLifecycleSlots $life $archives.Through;$active=@()
 foreach($slot in $slots){$active+=,(Read-AuthWireLifecyclePoll $life $slot $Binding $Key)}
 $all=@($archives.States)+@($active);$requests=@{};$jobs=@{}
 if($null -ne $baseline.legacy){$legacy=Read-AuthWireStagingJournal (Join-Path $Root 'cycle-poll.json');$requests[$legacy.request_id]=$true;$jobs[$baseline.legacy.job_id]=$true}
 foreach($s in $all){if($null -ne $s.Offer){
  if($requests.ContainsKey($s.Offer.request_id)){throw 'LIFECYCLE_DUPLICATE_POLL_HISTORY'};$requests[$s.Offer.request_id]=$true
  if($s.Offer.job_id -cne ''){if($jobs.ContainsKey($s.Offer.job_id)){throw 'LIFECYCLE_DUPLICATE_JOB_HISTORY'};$jobs[$s.Offer.job_id]=$true}
 }}
 Assert-AuthWireLifecycleRootEntries $Root $baseline $all $Binding $Key
 return [pscustomobject]@{Life=$life;Baseline=$baseline;Slots=$slots;States=$all;ActiveStates=$active;ArchivedThrough=$archives.Through;ArchiveHead=$archives.Head;ArchiveCount=$archives.Count}
}

function Get-AuthWireHistoryProtectedHash([string]$Root,$Pins){
 $hash=Get-AuthWireJobHash ([Text.Encoding]::ASCII.GetBytes("AUTHWIRE-WRITE-HISTORY-PROTECTED-V1`n"));$count=0;$bytes=[long]0
 $files=@(Get-ChildItem -LiteralPath $Root -Force|Where-Object {$_.Name -cne 'write-lifecycle'}|ForEach-Object {if($_.PSIsContainer){$Pins.PinAncestors($_.FullName);Get-ChildItem -LiteralPath $_.FullName -Force}else{$_}})
 foreach($file in @($files|Sort-Object FullName)){
  if($file.PSIsContainer){throw 'HISTORY_PROTECTED_TREE_REJECTED'}
  $Pins.PinFile($file.FullName);$raw=Read-AuthWireCandidateBytes $file.FullName 65536
  $count++;$bytes+=$raw.Length;if($count -gt 2048 -or $bytes -gt 33554432){throw 'HISTORY_PROTECTED_LIMIT'}
  $relative=$file.FullName.Substring($Root.Length+1).Replace('\','/')
  $row=[pscustomobject]@{path=$relative;size=$raw.Length;sha256=(Get-AuthWireJobHash $raw)}
  $hash=Get-AuthWireJobHash ([Text.Encoding]::ASCII.GetBytes(($hash+"`n"+(ConvertTo-AuthWireWriteJson $row)+"`n")))
 }
 return $hash
}
function New-AuthWireHistoryReviewState([string]$Root,[hashtable]$Binding,[Security.Cryptography.RSACng]$Key){
 Assert-AuthWireStagingWriteJournalLocation $Root $Binding;Initialize-AuthWireStagingFilesystemTypes
 $pins=[AuthWire.Staging.TreeLeaseV1]::new();$leases=[Collections.Generic.List[IDisposable]]::new()
 try{
  $pins.PinAncestors($Root);$h=Read-AuthWireLifecycleHistory $Root $Binding $Key
  $pins.PinAncestors($h.Life);$pins.PinFile((Join-Path $h.Life 'baseline.json'))
  $protected=Get-AuthWireHistoryProtectedHash $Root $pins
  $cycleRows=@();$details=@();$total=[long]0;$records=0
  foreach($slot in $h.Slots){
   $lease=[AuthWire.Staging.TreeLeaseV1]::Tree((Join-Path $h.Life $slot),$false);$leases.Add($lease)
   $rows=Get-AuthWireHistoryCycleRows $lease
   $cycleRows+=,[pscustomobject]@{slot=$slot;records_sha256=(Get-AuthWireWriteHash $rows)}
   $details+=,[pscustomobject]@{Slot=$slot;Rows=$rows}
   foreach($r in $rows){$total+=$r.size;$records++}
  }
  # Revalidate semantics while all active bytes and protected originals are held.
  $h=Read-AuthWireLifecycleHistory $Root $Binding $Key
  if((Get-AuthWireHistoryProtectedHash $Root $pins) -cne $protected){throw 'HISTORY_PROTECTED_CHANGED'}
  $reason='active_history_not_full';$eligible=$h.Slots.Count -eq 64
  for($j=0;$j -lt $h.ActiveStates.Count;$j++){
   $s=$h.ActiveStates[$j]
   if($s.Phase -cne 'reply_saved' -or -not (Test-Path -LiteralPath (Join-Path (Join-Path $h.Life $s.Slot) 'completion.json'))){$eligible=$false;$reason='pending_cycle';if($j -ne $h.ActiveStates.Count-1){throw 'LIFECYCLE_PENDING_HISTORY_GAP'};continue}
   $done=Read-AuthWireLifecycleCompletion $Root $h.Life $s $Binding $Key
   $safe=Test-AuthWireHistoryAcceptedOutcome $Root $h.Life $s $done $Binding $Key
   if(-not $safe){$eligible=$false;$reason='review_barrier';if($j -ne $h.ActiveStates.Count-1){throw 'LIFECYCLE_PENDING_HISTORY_GAP'}}
  }
  if($h.ArchiveCount -ge 8){$eligible=$false;$reason='archive_quota'}
  if($total -gt 16777216){$eligible=$false;$reason='archive_byte_limit'}
  if($eligible){$reason='observed_complete_history'}
  $now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds();$first=($h.ArchivedThrough+1).ToString('D6');$last=($h.ArchivedThrough+$h.Slots.Count).ToString('D6')
  $body=[pscustomobject]@{format='AuthWireWriteHistoryReviewV1';policy='retain_observed_cycles_v1';binding_scope=(Get-AuthWireJobScope $Binding);baseline_sha256=(Get-AuthWireWriteHash $h.Baseline);previous_archive_sha256=$h.ArchiveHead;archive_index=($h.ArchiveCount+1);archived_through=$h.ArchivedThrough;first_slot=$first;last_slot=$last;cycle_count=$h.Slots.Count;record_count=$records;total_bytes=$total;cycle_manifest_sha256=(Get-AuthWireWriteHash $cycleRows);protected_manifest_sha256=$protected;checked_at=$now;expires_at=($now+60);can_archive=[bool]$eligible;reason=$reason}
  return [pscustomobject]@{Review=$body;ReviewSha256=(Get-AuthWireWriteHash $body);History=$h;Cycles=$cycleRows;Details=$details;Pins=$pins;Leases=$leases}
 }catch{foreach($lease in $leases){$lease.Dispose()};$pins.Dispose();throw}
}
function Get-AuthWireWriteHistoryReview([string]$Root,[hashtable]$Binding,[Security.Cryptography.RSACng]$Key){
 $lock=Enter-AuthWireWriteCycleLock $Binding;$state=$null
 try{
  $state=New-AuthWireHistoryReviewState $Root $Binding $Key
  return [pscustomobject]@{Review=$state.Review;ReviewSha256=$state.ReviewSha256}
 }finally{if($state){foreach($lease in $state.Leases){$lease.Dispose()};$state.Pins.Dispose()};$lock.ReleaseMutex();$lock.Dispose()}
}

function Get-AuthWireStageConsumptionReview([string]$Root,[string]$SlotPath,$State,[hashtable]$Binding,[Security.Cryptography.RSACng]$Key){
 # Evidence classification only. Missing markers never authorize a retry or unlock.
 if($State.Offer.operation -cne 'combined.filesystem.stage.v1'){return}
 $jobId=$State.Offer.job_id;$release=$State.Started.release_id
 $job=Join-Path $Root $jobId;$failure=Join-Path $SlotPath 'dispatch-failed.json'
 $consumed=Join-Path $job 'grant-consumed.json'
 if(-not (Test-Path -LiteralPath $failure) -or -not (Test-Path -LiteralPath $consumed)){return}
 $p=[AuthWire.Staging.TreeLeaseV1]::new()
 try{
  $p.PinAncestors($SlotPath);$p.PinAncestors($job);$p.PinFile($failure);$p.PinFile($consumed)
  $f=Read-AuthWireStagingJournal $failure
  if($f.phase -cne 'consume'){return}
  foreach($name in @('filesystem-intent.json','stage-launch.json','stage-child.json','stage-entered.json','stage-preflight.json','execution-complete.json','execution-observed.json','execution-requires-review.json')){
   if(Test-Path -LiteralPath (Join-Path $job $name)){return}
  }
  $auth=Read-AuthWireWriteAuthorizationEvidence $Root $jobId $Binding $release $Key
  $op=Get-AuthWireFilesystemOperationId $auth
  if((Get-AuthWireWriteHash $auth.Offer) -cne (Get-AuthWireWriteHash $State.Offer) -or
     (Test-Path -LiteralPath (Join-Path $Root $op))){return}
  $record=Read-AuthWireStagingJournal $consumed
  Assert-AuthWireCandidateFields $record @('format','binding_scope','release_id','job_id','authorization_sha256','filesystem_operation_id','consumed_at','expires_at')
  if($record.format -cne 'AuthWireWriteGrantConsumedV1' -or $record.binding_scope -cne (Get-AuthWireJobScope $Binding) -or
     $record.release_id -cne $release -or $record.job_id -cne $jobId -or $record.authorization_sha256 -cne $auth.AuthorizationSha256 -or
     $record.filesystem_operation_id -cne $op -or -not (Test-AuthWireWriteInteger $record.consumed_at) -or
     -not (Test-AuthWireWriteInteger $record.expires_at) -or $record.expires_at -ne $auth.Receipt.grant.expires_at -or
     $record.consumed_at -lt $auth.Receipt.received_at -or $record.consumed_at -ge $record.expires_at -or
     $record.consumed_at -gt $f.checked_at){throw 'WRITE_CONSUMPTION_REVIEW_REJECTED'}
  $diagnostic=if($f.format -ceq 'AuthWireLifecycleDispatchFailedV2'){$f.diagnostic_code}else{'unavailable'}
  return [pscustomobject]@{Phase='consumed_without_filesystem_intent';DiagnosticCode=$diagnostic;GrantConsumedSha256=(Get-AuthWireWriteHash $record);GrantExpiresAt=$record.expires_at}
 }finally{$p.Dispose()}
}

function Get-AuthWireEmptyStageOriginal([string]$Root,[string]$SlotPath,$State,[hashtable]$Binding,[Security.Cryptography.RSACng]$Key,[bool]$Historical=$false){
 # Separate, narrow classification: an observed child exited in the engine
 # before ANY ownership journal/destination existed. Never accepts timeout,
 # missing child evidence, an active original grant, or partial engine effects.
 if($State.Offer.operation -cne 'combined.filesystem.stage.v1'){return}
 $id=$State.Offer.job_id;$job=Join-Path $Root $id
 if(-not (Test-Path -LiteralPath (Join-Path $job 'filesystem-intent.json'))){return}
 $p=[AuthWire.Staging.TreeLeaseV1]::new()
 try{
  $p.PinAncestors($job);$p.PinAncestors($SlotPath)
  $failureFile=Join-Path $SlotPath 'dispatch-failed.json';$p.PinFile($failureFile)
  $failure=Read-AuthWireStagingJournal $failureFile
  if($failure.phase -cne 'execute'){return}
  $s=Read-AuthWireAuthorizedStageIntentEvidence $Root $id $Binding $State.Started.release_id $Key
  $launch=Read-AuthWireStageLaunch $Root $id $s
  $child=Read-AuthWireStageChildIdentity $Root $id $launch
  $now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
  if($now -lt $s.Consumed.expires_at){return}
  foreach($n in @('execution-complete.json','execution-observed.json')){if(Test-Path -LiteralPath (Join-Path $job $n)){return}}
  foreach($n in @('stage-entered.json','stage-preflight.json','execution-requires-review.json')){$p.PinFile((Join-Path $job $n))}
  $entered=Read-AuthWireStagingJournal (Join-Path $job 'stage-entered.json')
  Assert-AuthWireCandidateFields $entered @('format','job_id','launch_sha256','child_identity_sha256','entered_at')
  if($entered.format -cne 'AuthWireStageEnteredV1' -or $entered.job_id -cne $id -or
     $entered.launch_sha256 -cne (Get-AuthWireWriteHash $launch) -or $entered.child_identity_sha256 -cne (Get-AuthWireWriteHash $child) -or
     -not (Test-AuthWireWriteInteger $entered.entered_at) -or $entered.entered_at -lt $launch.started_at -or $entered.entered_at -ge $launch.expires_at){throw 'WRITE_INTENT_RECOVERY_RECORD_REJECTED'}
  $live=Read-AuthWireStagingJournal (Join-Path $job 'stage-preflight.json')
  Assert-AuthWireWriteLiveContextAt $live $s.Authorization.Offer $Binding $live.checked_at
  if($live.checked_at -lt $entered.entered_at -or $live.checked_at -ge $launch.expires_at){throw 'WRITE_INTENT_RECOVERY_RECORD_REJECTED'}
  foreach($n in @('source_root','gpo_root','protected_gpo_id','pdc')){if($live.$n -cne $s.Intent.live_context.$n){throw 'WRITE_INTENT_RECOVERY_RECORD_REJECTED'}}
  $review=Read-AuthWireStagingJournal (Join-Path $job 'execution-requires-review.json')
  Assert-AuthWireCandidateFields $review @('format','job_id','execution_intent_sha256','reason','checked_at','diagnostic')
  $d=$review.diagnostic
  Assert-AuthWireCandidateFields $d @('format','parent_phase','child_phase','exception_kind','timed_out','truncated','exit_code','elapsed_ms','work_budget_ms')
  if($review.format -cne 'AuthWireStageReviewV2' -or $review.job_id -cne $id -or $review.execution_intent_sha256 -cne $s.IntentSha256 -or
     $review.reason -cne 'OUTCOME_REQUIRES_REVIEW' -or -not (Test-AuthWireWriteInteger $review.checked_at) -or $review.checked_at -lt $live.checked_at -or $review.checked_at -gt $now -or
     $d.format -cne 'AuthWireStageDiagnosticV1' -or $d.parent_phase -cne 'child_exit' -or $d.child_phase -cnotin @('unknown','engine') -or
     $d.exception_kind -cnotin @('unknown','runtime','timeout') -or $d.timed_out -isnot [bool] -or -not $d.timed_out -or $d.truncated -isnot [bool] -or $d.truncated -or
     $d.exit_code -isnot [int] -or $d.exit_code -ne 20 -or -not (Test-AuthWireWriteInteger $d.elapsed_ms) -or
     $d.work_budget_ms -ne $launch.work_budget_ms -or $d.elapsed_ms -lt $d.work_budget_ms){throw 'WRITE_INTENT_RECOVERY_RECORD_REJECTED'}
  # This unique operation journal can never belong to a later job, unlike the
  # reusable version destination. Its unexpected appearance always blocks.
  if(-not $Historical){
   # A reused PID is safe only if its immutable start identity differs. Access
   # errors are fatal; no process is stopped or killed by this observer.
   $process=$null
   try{$process=[Diagnostics.Process]::GetProcessById([int]$child.process_id)}catch [ArgumentException]{}
   if($process){try{if(-not $process.HasExited -and $process.StartTime.ToUniversalTime().Ticks.ToString([Globalization.CultureInfo]::InvariantCulture) -ceq $child.process_started_ticks){return}}finally{$process.Dispose()}}
   $gpoPins=[AuthWire.Staging.TreeLeaseV1]::new()
   try{
    Add-AuthWireStagingGpoPins $gpoPins $live.gpo_root $live.gpo_root
    Add-AuthWireStagingGpoPins $gpoPins ([IO.Path]::Combine($live.gpo_root,'Machine')) $live.gpo_root
    $relative=$s.Authorization.Offer.target.preview_record.Preview.relative_destination

   }finally{$gpoPins.Dispose()}
  }
  # Historical verification does not probe today's destination or PID: a later
  # separately authorized job can legitimately own that same version path.
  $value=[pscustomobject]@{Phase='expired_intent_without_engine_journal';GrantConsumedSha256=(Get-AuthWireWriteHash $s.Consumed);GrantExpiresAt=$s.Consumed.expires_at;FilesystemIntentSha256=$s.IntentSha256;FilesystemOperationId=$s.Intent.filesystem_operation_id;StageLaunchSha256=(Get-AuthWireWriteHash $launch);StageChildSha256=(Get-AuthWireWriteHash $child);StageEnteredSha256=(Get-AuthWireWriteHash $entered);StagePreflightSha256=(Get-AuthWireWriteHash $live);ExecutionReviewSha256=(Get-AuthWireWriteHash $review)}
  return [pscustomobject]@{Review=$value;Intent=$s;Live=$live}
 }finally{$p.Dispose()}
}
function Get-AuthWireExpiredStageIntentReview([string]$Root,[string]$SlotPath,$State,[hashtable]$Binding,[Security.Cryptography.RSACng]$Key,[bool]$Historical=$false){
 # Separate, narrow classification: an observed child exited in the engine
 # before ANY ownership journal/destination existed. Never accepts timeout,
 # missing child evidence, an active original grant, or partial engine effects.
 if($State.Offer.operation -cne 'combined.filesystem.stage.v1'){return}
 $id=$State.Offer.job_id;$job=Join-Path $Root $id
 if(-not (Test-Path -LiteralPath (Join-Path $job 'filesystem-intent.json'))){return}
 $p=[AuthWire.Staging.TreeLeaseV1]::new()
 try{
  $p.PinAncestors($job);$p.PinAncestors($SlotPath)
  $failureFile=Join-Path $SlotPath 'dispatch-failed.json';$p.PinFile($failureFile)
  $failure=Read-AuthWireStagingJournal $failureFile
  if($failure.phase -cne 'execute'){return}
  $s=Read-AuthWireAuthorizedStageIntentEvidence $Root $id $Binding $State.Started.release_id $Key
  $launch=Read-AuthWireStageLaunch $Root $id $s
  $child=Read-AuthWireStageChildIdentity $Root $id $launch
  $now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
  if($now -lt $s.Consumed.expires_at){return}
  foreach($n in @('execution-complete.json','execution-observed.json')){if(Test-Path -LiteralPath (Join-Path $job $n)){return}}
  foreach($n in @('stage-entered.json','stage-preflight.json','execution-requires-review.json')){$p.PinFile((Join-Path $job $n))}
  $entered=Read-AuthWireStagingJournal (Join-Path $job 'stage-entered.json')
  Assert-AuthWireCandidateFields $entered @('format','job_id','launch_sha256','child_identity_sha256','entered_at')
  if($entered.format -cne 'AuthWireStageEnteredV1' -or $entered.job_id -cne $id -or
     $entered.launch_sha256 -cne (Get-AuthWireWriteHash $launch) -or $entered.child_identity_sha256 -cne (Get-AuthWireWriteHash $child) -or
     -not (Test-AuthWireWriteInteger $entered.entered_at) -or $entered.entered_at -lt $launch.started_at -or $entered.entered_at -ge $launch.expires_at){throw 'WRITE_INTENT_RECOVERY_RECORD_REJECTED'}
  $live=Read-AuthWireStagingJournal (Join-Path $job 'stage-preflight.json')
  Assert-AuthWireWriteLiveContextAt $live $s.Authorization.Offer $Binding $live.checked_at
  if($live.checked_at -lt $entered.entered_at -or $live.checked_at -ge $launch.expires_at){throw 'WRITE_INTENT_RECOVERY_RECORD_REJECTED'}
  foreach($n in @('source_root','gpo_root','protected_gpo_id','pdc')){if($live.$n -cne $s.Intent.live_context.$n){throw 'WRITE_INTENT_RECOVERY_RECORD_REJECTED'}}
  $review=Read-AuthWireStagingJournal (Join-Path $job 'execution-requires-review.json')
  Assert-AuthWireCandidateFields $review @('format','job_id','execution_intent_sha256','reason','checked_at','diagnostic')
  $d=$review.diagnostic
  Assert-AuthWireCandidateFields $d @('format','parent_phase','child_phase','exception_kind','timed_out','truncated','exit_code','elapsed_ms','work_budget_ms')
  if($review.format -cne 'AuthWireStageReviewV2' -or $review.job_id -cne $id -or $review.execution_intent_sha256 -cne $s.IntentSha256 -or
     $review.reason -cne 'OUTCOME_REQUIRES_REVIEW' -or -not (Test-AuthWireWriteInteger $review.checked_at) -or $review.checked_at -lt $live.checked_at -or $review.checked_at -gt $now -or
     $d.format -cne 'AuthWireStageDiagnosticV1' -or $d.parent_phase -cne 'child_exit' -or $d.child_phase -cne 'engine' -or
     $d.exception_kind -cne 'runtime' -or $d.timed_out -isnot [bool] -or $d.timed_out -or $d.truncated -isnot [bool] -or $d.truncated -or
     $d.exit_code -isnot [int] -or $d.exit_code -ne 20 -or -not (Test-AuthWireWriteInteger $d.elapsed_ms) -or
     $d.work_budget_ms -ne $launch.work_budget_ms -or $d.elapsed_ms -gt $d.work_budget_ms){throw 'WRITE_INTENT_RECOVERY_RECORD_REJECTED'}
  # This unique operation journal can never belong to a later job, unlike the
  # reusable version destination. Its unexpected appearance always blocks.
  if(Test-Path -LiteralPath (Join-Path $Root $s.Intent.filesystem_operation_id)){return}
  if(-not $Historical){
   # A reused PID is safe only if its immutable start identity differs. Access
   # errors are fatal; no process is stopped or killed by this observer.
   $process=$null
   try{$process=[Diagnostics.Process]::GetProcessById([int]$child.process_id)}catch [ArgumentException]{}
   if($process){try{if(-not $process.HasExited -and $process.StartTime.ToUniversalTime().Ticks.ToString([Globalization.CultureInfo]::InvariantCulture) -ceq $child.process_started_ticks){return}}finally{$process.Dispose()}}
   $gpoPins=[AuthWire.Staging.TreeLeaseV1]::new()
   try{
    Add-AuthWireStagingGpoPins $gpoPins $live.gpo_root $live.gpo_root
    Add-AuthWireStagingGpoPins $gpoPins ([IO.Path]::Combine($live.gpo_root,'Machine')) $live.gpo_root
    $relative=$s.Authorization.Offer.target.preview_record.Preview.relative_destination
    if(Test-Path -LiteralPath ([IO.Path]::Combine($live.gpo_root,$relative.Replace('/','\')))){return}
   }finally{$gpoPins.Dispose()}
  }
  # Historical verification does not probe today's destination or PID: a later
  # separately authorized job can legitimately own that same version path.
  return [pscustomobject]@{Phase='expired_intent_without_engine_journal';GrantConsumedSha256=(Get-AuthWireWriteHash $s.Consumed);GrantExpiresAt=$s.Consumed.expires_at;FilesystemIntentSha256=$s.IntentSha256;FilesystemOperationId=$s.Intent.filesystem_operation_id;StageLaunchSha256=(Get-AuthWireWriteHash $launch);StageChildSha256=(Get-AuthWireWriteHash $child);StageEnteredSha256=(Get-AuthWireWriteHash $entered);StagePreflightSha256=(Get-AuthWireWriteHash $live);ExecutionReviewSha256=(Get-AuthWireWriteHash $review)}
 }finally{$p.Dispose()}
}
function Get-AuthWireEmptyStageCleanupPreview {
 param($Target,[hashtable]$Binding,[string]$PublisherThumbprint,[string]$BaseUrl,$Original)
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
 if($root -cne $Original.Gpo -or $server -cne $Original.Original.Live.pdc){throw 'EMPTY_RECOVERY_PDC_CHANGED'}
 $sourceOne=@(Get-AuthWireCombinedStagingLedger $Target $Binding)
 $one=Get-AuthWireScopeData $a $network $Binding
 $null=Test-AuthWireScopeData $one $a $network $Binding
 $inventoryOne=Get-AuthWireEmptyStageInventory $root $Original.Relative $Original.Baseline
 $two=Get-AuthWireScopeData $a $network $Binding
 $null=Test-AuthWireScopeData $two $a $network $Binding
 $inventoryTwo=Get-AuthWireEmptyStageInventory $root $Original.Relative $Original.Baseline
 $null=Get-AuthWireCombinedScopeContext $Target $Binding $PublisherThumbprint $BaseUrl
 $sourceTwo=@(Get-AuthWireCombinedStagingLedger $Target $Binding)
 $scopeHash=Get-AuthWireScopeDataHash $one
 if($scopeHash -cne (Get-AuthWireScopeDataHash $two) -or $inventoryOne.Sha256 -cne $inventoryTwo.Sha256 -or (Get-AuthWireScopeDataHash $sourceOne) -cne (Get-AuthWireScopeDataHash $sourceTwo)){throw 'STAGING_OBSERVATIONS_CHANGED'}
 # PDC selection is part of this scope; a changed domain view requires a new read.
 $lastDomain=Get-ADDomain -Identity $a.domain -Server $a.domain -ErrorAction Stop
 if($lastDomain.DNSRoot -cne $a.domain -or $lastDomain.DomainSID.Value -cne $domainSid -or [string]$lastDomain.PDCEmulator -cne $server -or [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() -ge $checked+90){throw 'STAGING_OBSERVATIONS_CHANGED'}
 return (New-AuthWireCombinedStagingPlanCore $Target $sourceTwo $inventoryTwo $scopeHash $checked)
}

function Get-AuthWireStageRecoveryClassification([string]$Root,[string]$SlotPath,$State,[hashtable]$Binding,[Security.Cryptography.RSACng]$Key,[bool]$Historical=$false){
 # SlotPath is supplied by the already validated active or archived cycle reader.
 # Keep all original completion/signature/ownership checks at that same location.
 $empty=Get-AuthWireRecoveredEmptyStageReview $Root $State $Binding $Key $Historical ([IO.Path]::GetDirectoryName($SlotPath))
 if($null -ne $empty){return $empty}
 $value=Get-AuthWireStageConsumptionReview $Root $SlotPath $State $Binding $Key
 if($null -ne $value){return $value}
 return (Get-AuthWireExpiredStageIntentReview $Root $SlotPath $State $Binding $Key $Historical)
}

function New-AuthWireConsumedStageRecoveryBody($State,$Completion,$Consumption,$Fresh,[long]$Now){
 $offer=$State.Offer;$approved=$offer.target.preview_record;$seen=$Fresh.Preview
 if($null -eq $Consumption -or $Completion.outcome -cne 'requires_review' -or $Consumption.Phase -cnotin @('consumed_without_filesystem_intent','expired_intent_without_engine_journal','recovered_empty_stage_destination') -or
    -not (Test-AuthWireWriteInteger $Consumption.GrantExpiresAt) -or -not (Test-AuthWireWriteInteger $seen.checked_at) -or
    $seen.checked_at -lt $Consumption.GrantExpiresAt -or $seen.checked_at -gt $Now -or $Now -ge $seen.checked_at+60){
  throw 'WRITE_RECOVERY_EVIDENCE_NOT_CURRENT'
 }
 if((Get-AuthWireWritePreviewHash $seen) -cne $Fresh.PreviewSha256){throw 'WRITE_RECOVERY_PREVIEW_REJECTED'}
 # Compare all approved observations, excluding the fresh timestamps only.
 $normalized=ConvertTo-AuthWireWriteOrderedPreview $seen
 $normalized.checked_at=$approved.Preview.checked_at
 $normalized.expires_at=$approved.Preview.expires_at
 if((Get-AuthWireWritePreviewHash $normalized) -cne $approved.PreviewSha256){throw 'WRITE_RECOVERY_OBSERVATIONS_CHANGED'}
 $lock=[pscustomobject]@{format='AuthWireWriteGpoLockV1';job_id=$offer.job_id;intent_sha256=$offer.intent_sha256}
 $body=[pscustomobject][ordered]@{
  format='AuthWireConsumedStageRecoveryEvidenceV1'
  job_id=$offer.job_id
  gpo_id=$offer.target.scope_target.gpo_id
  scope_sha256=$offer.scope_sha256
  intent_sha256=$offer.intent_sha256
  result_body_sha256=$Completion.result_body_sha256
  accepted_ack_sha256=$Completion.ack_sha256
  completion_sha256=(Get-AuthWireWriteHash $Completion)
  grant_consumed_sha256=$Consumption.GrantConsumedSha256
  lock_sha256=(Get-AuthWireWriteHash $lock)
  approved_preview_sha256=$approved.PreviewSha256
  observed_preview_sha256=$Fresh.PreviewSha256
  baseline_inventory_sha256=$seen.baseline_inventory_sha256
  grant_expires_at=$Consumption.GrantExpiresAt
  observed_at=$seen.checked_at
  expires_at=($seen.checked_at+60)
 }
 if($Consumption.Phase -cin @('expired_intent_without_engine_journal','recovered_empty_stage_destination')){
  $body.format='AuthWireStageIntentRecoveryEvidenceV1'
  foreach($pair in @(@('filesystem_intent_sha256','FilesystemIntentSha256'),@('stage_launch_sha256','StageLaunchSha256'),@('stage_child_sha256','StageChildSha256'),@('stage_entered_sha256','StageEnteredSha256'),@('stage_preflight_sha256','StagePreflightSha256'),@('execution_review_sha256','ExecutionReviewSha256'))){if(-not (Test-AuthWireWriteHash $Consumption.($pair[1]))){throw 'WRITE_INTENT_RECOVERY_RECORD_REJECTED'};$body|Add-Member NoteProperty $pair[0] $Consumption.($pair[1])}
  Assert-AuthWireCandidateGuid $Consumption.FilesystemOperationId
  $body|Add-Member NoteProperty filesystem_operation_id $Consumption.FilesystemOperationId
  if($Consumption.Phase -ceq 'recovered_empty_stage_destination'){
   $body.format='AuthWireEmptyStageRecoveryEvidenceV1'
   foreach($pair in @(@('engine_intent_sha256','EngineIntentSha256'),@('empty_cleanup_receipt_sha256','EmptyCleanupReceiptSha256'),@('destination_row_sha256','DestinationRowSha256'))){if(-not (Test-AuthWireWriteHash $Consumption.($pair[1]))){throw 'EMPTY_RECOVERY_RECEIPT_REJECTED'};$body|Add-Member NoteProperty $pair[0] $Consumption.($pair[1])}
   foreach($n in @('child_exit_confirmed','engine_intent_retained','empty_destination_removed','destination_absent')){$body|Add-Member NoteProperty $n $true}
  }else{
   foreach($n in @('child_exit_confirmed','engine_journal_absent','destination_absent')){$body|Add-Member NoteProperty $n $true}
  }
 }
 return $body
}

function Get-AuthWireConsumedStageRecoveryFrame($Body){
 if($Body.format -ceq 'AuthWireEmptyStageRecoveryEvidenceV1'){return ,([Text.Encoding]::ASCII.GetBytes("AUTHWIRE-EMPTY-STAGE-RECOVERY-EVIDENCE-V1`n"+(Get-AuthWireWriteHash $Body)+"`n"))}
 if($Body.format -ceq 'AuthWireStageIntentRecoveryEvidenceV1'){return ,([Text.Encoding]::ASCII.GetBytes("AUTHWIRE-STAGE-INTENT-RECOVERY-EVIDENCE-V1`n"+(Get-AuthWireWriteHash $Body)+"`n"))}
 if($Body.format -cne 'AuthWireConsumedStageRecoveryEvidenceV1'){throw 'WRITE_RECOVERY_EVIDENCE_FORMAT_REJECTED'}
 return ,([Text.Encoding]::ASCII.GetBytes("AUTHWIRE-CONSUMED-STAGE-RECOVERY-EVIDENCE-V1`n"+(Get-AuthWireWriteHash $Body)+"`n"))
}

function New-AuthWireConsumedStageRecoveryProof($State,$Completion,$Consumption,$Fresh,[Security.Cryptography.RSACng]$Key,[long]$Now){
 # Domain-separated evidence for an operator review. It is never a write grant.
 $body=New-AuthWireConsumedStageRecoveryBody $State $Completion $Consumption $Fresh $Now
 $signature=$Key.SignData((Get-AuthWireConsumedStageRecoveryFrame $body),[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1)
 return [pscustomobject]@{Body=$body;Signature=[Convert]::ToBase64String($signature)}
}

function Read-AuthWireConsumedStageRecoveryState([string]$Root,[string]$JobId,[hashtable]$Binding,[Security.Cryptography.RSACng]$Key,$Pins,[bool]$PinLock=$true){
  # The caller holds the Connector cycle mutex and owns the file pins.
  $pins.PinAncestors($Root)
  $history=Read-AuthWireLifecycleHistory $Root $Binding $Key
  if(-not $history.ActiveStates.Count){throw 'WRITE_RECOVERY_STAGE_NOT_FOUND'}
  $state=$history.ActiveStates[-1]
  if($state.Phase -cne 'reply_saved' -or $state.Offer.job_id -cne $JobId -or $state.Offer.operation -cne 'combined.filesystem.stage.v1'){
   throw 'WRITE_RECOVERY_STAGE_NOT_FOUND'
  }
  $slot=Join-Path $history.Life $state.Slot
  $target=$state.Offer.target.scope_target
  $pins.PinAncestors($slot)
  $pins.PinFile((Join-Path $slot 'completion.json'))
  if($PinLock){$pins.PinFile((Join-Path $Root ('gpo-'+$target.gpo_id+'.json')))}
  $done=Read-AuthWireLifecycleCompletion $Root $history.Life $state $Binding $Key
  $consumed=Get-AuthWireStageRecoveryClassification $Root $slot $state $Binding $Key
  if($done.outcome -cne 'requires_review' -or $null -eq $consumed -or
     [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() -lt $consumed.GrantExpiresAt){throw 'WRITE_RECOVERY_STAGE_NOT_ELIGIBLE'}
  return [pscustomobject]@{State=$state;Slot=$slot;Completion=$done;Consumption=$consumed}
}

function Get-AuthWireConsumedStageRecoveryEvidence([string]$Root,[string]$JobId,[hashtable]$Binding,[Security.Cryptography.RSACng]$Key,[string]$PublisherThumbprint,[string]$BaseUrl){
 Assert-AuthWireStagingWriteJournalLocation $Root $Binding
 Assert-AuthWireCandidateGuid $JobId
 Initialize-AuthWireStagingFilesystemTypes
 $lock=Enter-AuthWireWriteCycleLock $Binding;$pins=[AuthWire.Staging.TreeLeaseV1]::new()
 try{
  $current=Read-AuthWireConsumedStageRecoveryState $Root $JobId $Binding $Key $pins
  $fresh=Get-AuthWireCombinedStagingPreview $current.State.Offer.target.scope_target $Binding $PublisherThumbprint $BaseUrl
  $again=Get-AuthWireStageRecoveryClassification $Root $current.Slot $current.State $Binding $Key
  if($null -eq $again -or $again.GrantConsumedSha256 -cne $current.Consumption.GrantConsumedSha256){throw 'WRITE_RECOVERY_STAGE_CHANGED'}
  return (New-AuthWireConsumedStageRecoveryProof $current.State $current.Completion $again $fresh $Key ([DateTimeOffset]::UtcNow.ToUnixTimeSeconds()))
 }finally{$pins.Dispose();$lock.ReleaseMutex();$lock.Dispose()}
}

function Assert-AuthWireConsumedStageRecoveryReceipt($Request,$Reply,[long]$Now){
 $approval=$Request.approval;$proof=$approval.consumed_stage_proof;$body=$proof.Body
 Assert-AuthWireCandidateFields $Reply @('job_id','gpo_id','decision','approval_revision','approval_verified','approval_request_sha256','consumed_stage_proof_sha256','evidence_expires_at','review_only','source_only','approval_enabled','write_authorization_enabled','execution_adapter_available','can_apply_gpo')
 if($Reply.job_id -cne $body.job_id -or $Reply.gpo_id -cne $body.gpo_id -or
    $Reply.decision -cne 'approve_consumed_stage_lock_release' -or
    -not (Test-AuthWireWriteInteger $Reply.approval_revision) -or $Reply.approval_revision -ne $Request.approval_revision -or
    $Reply.approval_request_sha256 -cne (Get-AuthWireWriteHash $approval) -or
    $Reply.consumed_stage_proof_sha256 -cne (Get-AuthWireWriteHash $proof) -or
    -not (Test-AuthWireWriteInteger $Reply.evidence_expires_at) -or $Reply.evidence_expires_at -ne $body.expires_at -or
    $Now -lt $body.observed_at -or $Now -ge $body.expires_at){throw 'WRITE_RECOVERY_RECEIPT_REJECTED'}
 foreach($field in @('approval_verified','review_only','approval_enabled','write_authorization_enabled','execution_adapter_available')){
  if($Reply.$field -isnot [bool] -or -not $Reply.$field){throw 'WRITE_RECOVERY_RECEIPT_REJECTED'}
 }
 foreach($field in @('source_only','can_apply_gpo')){
  if($Reply.$field -isnot [bool] -or $Reply.$field){throw 'WRITE_RECOVERY_RECEIPT_REJECTED'}
 }
}

function Confirm-AuthWireConsumedStageRecoveryApproval([string]$Root,[string]$JobId,[hashtable]$Binding,[Security.Cryptography.RSACng]$Key,[string]$BaseUrl,$Request,[securestring]$Session,[securestring]$Csrf){
 Assert-AuthWireStagingWriteJournalLocation $Root $Binding
 Assert-AuthWireCandidateGuid $JobId
 Assert-AuthWireCandidateFields $Request @('approval','approval_revision')
 $approval=$Request.approval
 Assert-AuthWireCandidateFields $approval @('expected_revision','evidence','decision','review_hash','acknowledge','reconciliation_receipt','consumed_stage_proof')
 $proof=$approval.consumed_stage_proof
 Assert-AuthWireCandidateFields $proof @('Body','Signature')
 $body=$proof.Body
 if($body.job_id -cne $JobId -or $approval.decision -cne 'approve_consumed_stage_lock_release' -or
    -not (Test-AuthWireWriteInteger $body.observed_at) -or
    -not (Test-AuthWireWriteInteger $approval.expected_revision) -or
    -not (Test-AuthWireWriteInteger $Request.approval_revision) -or $Request.approval_revision -ne ($approval.expected_revision+1)){
  throw 'WRITE_RECOVERY_APPROVAL_REJECTED'
 }
 Initialize-AuthWireStagingFilesystemTypes
 Initialize-AuthWireWriteTransportTypes
 $lock=Enter-AuthWireWriteCycleLock $Binding;$pins=[AuthWire.Staging.TreeLeaseV1]::new()
 try{
  $current=Read-AuthWireConsumedStageRecoveryState $Root $JobId $Binding $Key $pins
  # Rebuild the attested body from the pinned local journals and approved preview
  # at the original observation time. The existing proof must still be fresh.
  $preview=ConvertTo-AuthWireWriteOrderedPreview $current.State.Offer.target.preview_record.Preview
  $preview.checked_at=$body.observed_at;$preview.expires_at=$body.observed_at+90
  $fresh=[pscustomobject]@{Preview=$preview;PreviewSha256=(Get-AuthWireWritePreviewHash $preview)}
  $expected=New-AuthWireConsumedStageRecoveryBody $current.State $current.Completion $current.Consumption $fresh ([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())
  $signature=ConvertFrom-AuthWireWriteBase64 $proof.Signature 512
  if((Get-AuthWireWriteHash $expected) -cne (Get-AuthWireWriteHash $body) -or $signature.Length -ne $Key.KeySize/8 -or
     -not $Key.VerifyData((Get-AuthWireConsumedStageRecoveryFrame $expected),$signature,[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1)){
   throw 'WRITE_RECOVERY_APPROVAL_REJECTED'
  }
  $reply=[AuthWire.Connector.WriteTransportV1]::VerifyStageRecovery($BaseUrl,$Binding.appliance_fqdn,$Binding.appliance_tls_sha256,(ConvertTo-AuthWireWriteJson $Request),[Net.NetworkCredential]::new('',$Session).Password,[Net.NetworkCredential]::new('',$Csrf).Password)
  $receipt=ConvertFrom-AuthWireCandidateJson ([Text.UTF8Encoding]::new($false,$true).GetBytes($reply))
  Assert-AuthWireConsumedStageRecoveryReceipt $Request $receipt ([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())
  return $receipt
 }finally{$pins.Dispose();$lock.ReleaseMutex();$lock.Dispose()}
}


function Get-AuthWireConsumedStageClosureFrame($Body){
 if($Body.format -ceq 'AuthWireEmptyStageClosureV1'){return ,([Text.Encoding]::ASCII.GetBytes("AUTHWIRE-EMPTY-STAGE-CLOSURE-V1`n"+(Get-AuthWireWriteHash $Body)+"`n"))}
 if($Body.format -ceq 'AuthWireStageIntentClosureV1'){return ,([Text.Encoding]::ASCII.GetBytes("AUTHWIRE-STAGE-INTENT-CLOSURE-V1`n"+(Get-AuthWireWriteHash $Body)+"`n"))}
 if($Body.format -cne 'AuthWireConsumedStageClosureV1'){throw 'WRITE_RECOVERY_CLOSURE_REJECTED'}
 return ,([Text.Encoding]::ASCII.GetBytes("AUTHWIRE-CONSUMED-STAGE-CLOSURE-V1`n"+(Get-AuthWireWriteHash $Body)+"`n"))
}
function New-AuthWireConsumedStageClosureBody($Request,[long]$At){
 $approval=$Request.approval;$b=$approval.consumed_stage_proof.Body
 $body=[pscustomobject][ordered]@{
  format='AuthWireConsumedStageClosureV1';job_id=$b.job_id;gpo_id=$b.gpo_id
  scope_sha256=$b.scope_sha256;intent_sha256=$b.intent_sha256;result_body_sha256=$b.result_body_sha256
  completion_sha256=$b.completion_sha256;lock_sha256=$b.lock_sha256
  consumed_stage_proof_sha256=(Get-AuthWireWriteHash $approval.consumed_stage_proof)
  approval_request_sha256=(Get-AuthWireWriteHash $approval);approval_revision=$Request.approval_revision
  closed_at=$At;evidence_expires_at=$b.expires_at;lock_released=$true
 }
 if($b.format -cin @('AuthWireStageIntentRecoveryEvidenceV1','AuthWireEmptyStageRecoveryEvidenceV1')){$body.format='AuthWireStageIntentClosureV1';$body|Add-Member NoteProperty filesystem_intent_sha256 $b.filesystem_intent_sha256;$body|Add-Member NoteProperty filesystem_operation_id $b.filesystem_operation_id}
 if($b.format -ceq 'AuthWireEmptyStageRecoveryEvidenceV1'){$body.format='AuthWireEmptyStageClosureV1';foreach($n in @('engine_intent_sha256','empty_cleanup_receipt_sha256','destination_row_sha256')){$body|Add-Member NoteProperty $n $b.$n}}
 return $body
}
function Test-AuthWireConsumedStageClosed([string]$Root,[string]$Life,$State,[hashtable]$Binding,[Security.Cryptography.RSACng]$Key){
 $job=Join-Path $Root $State.Offer.job_id;$file=Join-Path $job 'consumed-stage-closed.json'
 if(-not (Test-Path -LiteralPath $file)){return $false}
 $p=[AuthWire.Staging.TreeLeaseV1]::new()
 try{
  $p.PinAncestors($Root);$p.PinAncestors($job);$p.PinFile($file)
  $releaseFile=Join-Path $job 'consumed-stage-release.json';$p.PinFile($releaseFile)
  $savedLock=Join-Path $job 'released-gpo-lock.json';$p.PinFile($savedLock)
  $release=Read-AuthWireStagingJournal $releaseFile
  Assert-AuthWireCandidateFields $release @('format','request','receipt')
  if($release.format -cne 'AuthWireConsumedStageReleaseV1'){throw 'WRITE_RECOVERY_CLOSURE_REJECTED'}
  $request=$release.request;$body=$request.approval.consumed_stage_proof.Body
  Assert-AuthWireCandidateFields $request @('approval','approval_revision')
  $closed=Read-AuthWireStagingJournal $file
  Assert-AuthWireCandidateFields $closed @('Body','Signature')
  if(-not (Test-AuthWireWriteInteger $closed.Body.closed_at) -or $closed.Body.closed_at -gt [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()){throw 'WRITE_RECOVERY_CLOSURE_REJECTED'}
  Assert-AuthWireConsumedStageRecoveryReceipt $request $release.receipt $closed.Body.closed_at
  $expected=New-AuthWireConsumedStageClosureBody $request $closed.Body.closed_at
  if((Get-AuthWireWriteHash $expected) -cne (Get-AuthWireWriteHash $closed.Body) -or
     -not $Key.VerifyData((Get-AuthWireConsumedStageClosureFrame $expected),(ConvertFrom-AuthWireWriteBase64 $closed.Signature 512),[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1)){throw 'WRITE_RECOVERY_CLOSURE_REJECTED'}
  $done=Read-AuthWireLifecycleCompletion $Root $Life $State $Binding $Key
  $consumed=Get-AuthWireStageRecoveryClassification $Root (Join-Path $Life $State.Slot) $State $Binding $Key $true
  $preview=ConvertTo-AuthWireWriteOrderedPreview $State.Offer.target.preview_record.Preview
  $preview.checked_at=$body.observed_at;$preview.expires_at=$body.observed_at+90
  $fresh=[pscustomobject]@{Preview=$preview;PreviewSha256=(Get-AuthWireWritePreviewHash $preview)}
  $attested=New-AuthWireConsumedStageRecoveryBody $State $done $consumed $fresh $closed.Body.closed_at
  if((Get-AuthWireWriteHash $body) -cne (Get-AuthWireWriteHash $attested) -or
     -not $Key.VerifyData((Get-AuthWireConsumedStageRecoveryFrame $attested),(ConvertFrom-AuthWireWriteBase64 $request.approval.consumed_stage_proof.Signature 512),[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1) -or
     (Get-AuthWireWriteHash (Read-AuthWireStagingJournal $savedLock)) -cne $body.lock_sha256){throw 'WRITE_RECOVERY_CLOSURE_REJECTED'}
  # A later job may own a new lock for the same GPO. It must never be mistaken
  # for this retired job or removed by recovery of the old job.
  $active=Join-Path $Root ('gpo-'+$body.gpo_id+'.json')
  if(Test-Path -LiteralPath $active){
   $p.PinFile($active);$l=Read-AuthWireStagingJournal $active
   if($l.job_id -ceq $State.Offer.job_id){throw 'WRITE_RECOVERY_LOCK_STILL_PRESENT'}
  }
  return $true
 }finally{$p.Dispose()}
}
function Complete-AuthWireConsumedStageLocalClosure([string]$Root,[string]$JobId,[hashtable]$Binding,[Security.Cryptography.RSACng]$Key,[string]$PublisherThumbprint,[string]$BaseUrl,$Request,[securestring]$Session,[securestring]$Csrf,[string]$EnrollmentBaseUrl=''){
 Assert-AuthWireStagingWriteJournalLocation $Root $Binding;Assert-AuthWireCandidateGuid $JobId
 # The isolated write HTTPS port is transport only. Signed enrollment content
 # remains bound to the canonical appliance URL in the protected service config.
 if($EnrollmentBaseUrl -ceq ''){$EnrollmentBaseUrl=$BaseUrl}
 $enrollment=$null
 if(-not [uri]::TryCreate($EnrollmentBaseUrl,[UriKind]::Absolute,[ref]$enrollment) -or
    $enrollment.Scheme -cne 'https' -or $enrollment.Host -cne $Binding.appliance_fqdn -or
    $enrollment.UserInfo -or $enrollment.Query -or $enrollment.Fragment -or $enrollment.AbsolutePath -cne '/'){
  throw 'WRITE_RECOVERY_ENROLLMENT_URL_REJECTED'
 }
 Initialize-AuthWireStagingFilesystemTypes
 $mutex=Enter-AuthWireWriteCycleLock $Binding;$p=[AuthWire.Staging.TreeLeaseV1]::new();$owned=$null
 try{
  $p.PinAncestors($Root)
  $current=Read-AuthWireConsumedStageRecoveryState $Root $JobId $Binding $Key $p $false
  $job=Join-Path $Root $JobId;$p.PinAncestors($job)
  foreach($name in @('consumed-stage-release.json','released-gpo-lock.json','consumed-stage-closed.json')){
   if(Test-Path -LiteralPath (Join-Path $job $name)){throw 'WRITE_RECOVERY_PARTIAL_REQUIRES_REVIEW'}
  }
  foreach($file in Get-ChildItem -LiteralPath $job -Force){
   if($file.PSIsContainer){throw 'WRITE_RECOVERY_CLOSURE_REJECTED'};$p.PinFile($file.FullName)
  }
  $receipt=Confirm-AuthWireConsumedStageRecoveryApproval $Root $JobId $Binding $Key $BaseUrl $Request $Session $Csrf
  # A second real observation immediately precedes retirement. Normalize only
  # timestamps; any AD, source, ACL or SYSVOL drift keeps the lock closed.
  $fresh=Get-AuthWireCombinedStagingPreview $current.State.Offer.target.scope_target $Binding $PublisherThumbprint $EnrollmentBaseUrl
  $again=Get-AuthWireStageRecoveryClassification $Root $current.Slot $current.State $Binding $Key
  if($null -eq $again -or (Get-AuthWireWriteHash $again) -cne (Get-AuthWireWriteHash $current.Consumption)){throw 'WRITE_RECOVERY_STAGE_CHANGED'}
  $null=New-AuthWireConsumedStageRecoveryBody $current.State $current.Completion $again $fresh ([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())
  $now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
  Assert-AuthWireConsumedStageRecoveryReceipt $Request $receipt $now
  $lockPath=Join-Path $Root ('gpo-'+$Request.approval.consumed_stage_proof.Body.gpo_id+'.json')
  $owned=[AuthWire.Staging.TreeLeaseV1]::OwnedLockFile($lockPath)
  $lockRecord=ConvertFrom-AuthWireCandidateJson ($owned.ReadOwnedBytes('lock'))
  if((Get-AuthWireWriteHash $lockRecord) -cne $Request.approval.consumed_stage_proof.Body.lock_sha256){throw 'WRITE_RECOVERY_LOCK_CHANGED'}
  Write-AuthWireStagingJournal (Join-Path $job 'consumed-stage-release.json') ([pscustomobject]@{format='AuthWireConsumedStageReleaseV1';request=$Request;receipt=$receipt})
  Write-AuthWireStagingJournal (Join-Path $job 'released-gpo-lock.json') $lockRecord
  # The only deletion is the exact held local lock, after immutable evidence
  # and its historical copy are flushed. No SYSVOL, AD, job or grant is deleted.
  $start=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds();$ticks=[Diagnostics.Stopwatch]::GetTimestamp()
  $until=[long][Math]::Min($start+30,$Request.approval.consumed_stage_proof.Body.expires_at)
  $owned.DeleteOwnedTreeBefore($until,$start,$ticks);$owned.Dispose();$owned=$null
  $at=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
  Assert-AuthWireConsumedStageRecoveryReceipt $Request $receipt $at
  $body=New-AuthWireConsumedStageClosureBody $Request $at
  $sig=$Key.SignData((Get-AuthWireConsumedStageClosureFrame $body),[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1)
  $closed=[pscustomobject]@{Body=$body;Signature=[Convert]::ToBase64String($sig)}
  Write-AuthWireStagingJournal (Join-Path $job 'consumed-stage-closed.json') $closed
  if(-not (Test-AuthWireConsumedStageClosed $Root (Get-AuthWireWriteLifecyclePath $Root $Binding) $current.State $Binding $Key)){throw 'WRITE_RECOVERY_CLOSURE_REJECTED'}
  return $closed
 }finally{if($owned){$owned.Dispose()};$p.Dispose();$mutex.ReleaseMutex();$mutex.Dispose()}
}
function Send-AuthWireConsumedStageClosure([hashtable]$Binding,[string]$BaseUrl,$Request,$Closure,[securestring]$Session,[securestring]$Csrf){
 Initialize-AuthWireWriteTransportTypes
 $value=[pscustomobject]@{approval=$Request.approval;approval_revision=$Request.approval_revision;closure=$Closure}
 $raw=[AuthWire.Connector.WriteTransportV1]::CloseStageRecovery($BaseUrl,$Binding.appliance_fqdn,$Binding.appliance_tls_sha256,(ConvertTo-AuthWireWriteJson $value),[Net.NetworkCredential]::new('',$Session).Password,[Net.NetworkCredential]::new('',$Csrf).Password)
 $reply=ConvertFrom-AuthWireCandidateJson ([Text.UTF8Encoding]::new($false,$true).GetBytes($raw))
 Assert-AuthWireCandidateFields $reply @('job_id','gpo_id','closed','closure_revision','closure_sha256','source_only','approval_enabled','write_authorization_enabled','execution_adapter_available','can_apply_gpo')
 if($reply.job_id -cne $Closure.Body.job_id -or $reply.gpo_id -cne $Closure.Body.gpo_id -or
    $reply.closed -isnot [bool] -or -not $reply.closed -or $reply.can_apply_gpo -isnot [bool] -or $reply.can_apply_gpo -or
    -not (Test-AuthWireWriteInteger $reply.closure_revision) -or $reply.closure_sha256 -cne (Get-AuthWireWriteHash $Closure)){throw 'WRITE_RECOVERY_CLOSURE_RECEIPT_REJECTED'}
 return $reply
}

function Get-AuthWireWriteReconciliationReview([string]$Root,[hashtable]$Binding,[Security.Cryptography.RSACng]$Key){
 # This is a local evidence read. Even a valid ACK is not fresh approval.
 Assert-AuthWireStagingWriteJournalLocation $Root $Binding
 Initialize-AuthWireStagingFilesystemTypes
 $lock=Enter-AuthWireWriteCycleLock $Binding;$pins=[AuthWire.Staging.TreeLeaseV1]::new()
 $review=[pscustomobject]@{Phase='no_active_cycles';Slot='';JobId='';RecordedOutcome='';AcceptedAck=$false;Evidence=$null;StageConsumption=$null}
 try{
  $pins.PinAncestors($Root)
  if(-not (Get-ChildItem -LiteralPath $Root -Force -ErrorAction Stop|Select-Object -First 1)){return $review}
  $h=Read-AuthWireLifecycleHistory $Root $Binding $Key
  for($i=0;$i -lt $h.ActiveStates.Count;$i++){
   $state=$h.ActiveStates[$i];$dir=Join-Path $h.Life $state.Slot
   $pins.PinAncestors($dir)
   $review.Slot=$state.Slot;$review.JobId='';$review.RecordedOutcome='';$review.AcceptedAck=$false;$review.Evidence=$null;$review.StageConsumption=$null
   if($state.Phase -cne 'reply_saved'){
    if($i -ne $h.ActiveStates.Count-1 -or (Test-Path -LiteralPath (Join-Path $dir 'completion.json'))){throw 'LIFECYCLE_PENDING_HISTORY_GAP'}
    $review.Phase=$state.Phase
    return $review
   }
   $review.JobId=$state.Offer.job_id
   if($review.JobId -cne ''){
    $review.Evidence=[pscustomobject]@{job_id=$review.JobId;scope_sha256=$state.Offer.scope_sha256;intent_sha256=$state.Offer.intent_sha256;result_body_sha256='';accepted_ack=$false}
   }
   if(Test-Path -LiteralPath (Join-Path $dir 'completion.json')){
    $done=Read-AuthWireLifecycleCompletion $Root $h.Life $state $Binding $Key
    $review.Phase='completion_verified';$review.RecordedOutcome=$done.outcome;$review.AcceptedAck=$review.JobId -cne ''
    if($review.Evidence){$review.Evidence.result_body_sha256=$done.result_body_sha256;$review.Evidence.accepted_ack=$true}
    if($done.outcome -ceq 'requires_review' -and (Test-AuthWireConsumedStageClosed $Root $h.Life $state $Binding $Key)){
     $closed=Read-AuthWireStagingJournal (Join-Path (Join-Path $Root $state.Offer.job_id) 'consumed-stage-closed.json')
     $review.Phase=if($closed.Body.format -ceq 'AuthWireEmptyStageClosureV1'){'closed_after_empty_stage_cleanup'}elseif($closed.Body.format -ceq 'AuthWireStageIntentClosureV1'){'closed_without_engine_journal'}else{'closed_without_filesystem_intent'};continue
    }
    if($done.outcome -ceq 'refused_before_authorization' -and (Test-AuthWireRefusedRollbackRetired $Root $h.Life $state $Binding $Key)){$review.Phase='refused_rollback_retired_reservation_retained';continue}
    if($done.outcome -ceq 'requires_review' -and (Test-AuthWireConsumedRollbackRetired $Root $h.Life $state $Binding $Key)){$review.Phase='consumed_rollback_retired_unknown_result_preserved';continue}
    if($done.outcome -ceq 'requires_review' -and (Test-AuthWirePreIntentRollbackRetired $Root $h.Life $state $Binding $Key)){$review.Phase='preintent_rollback_retired_unknown_result_preserved';continue}
    if($done.outcome -ceq 'requires_review'){$review.StageConsumption=Get-AuthWireStageRecoveryClassification $Root $dir $state $Binding $Key}
    if($done.outcome -cin @('requires_review','refused_before_authorization') -and $i -ne $h.ActiveStates.Count-1){throw 'LIFECYCLE_PENDING_HISTORY_GAP'}
    continue
   }
   if($i -ne $h.ActiveStates.Count-1){throw 'LIFECYCLE_PENDING_HISTORY_GAP'}
   if($review.JobId -ceq ''){$review.Phase='idle_completion_missing';return $review}
   if(-not (Test-Path -LiteralPath (Join-Path $dir 'dispatch-started.json'))){$review.Phase='dispatch_record_missing';return $review}
   Assert-AuthWireLifecycleDispatch $h.Life $state
   $job=Join-Path $Root $review.JobId;$release=$state.Started.release_id
   $rollback=$state.Offer.operation -ceq 'combined.filesystem.rollback.v1'
   $prefix=if($rollback){'rollback-'}else{''}
   $refusal=(Test-Path -LiteralPath (Join-Path $job 'refusal-outbox.json')) -or (Test-Path -LiteralPath (Join-Path $job 'refusal-accepted.json'))
   $resultPresent=(Test-Path -LiteralPath (Join-Path $job ($prefix+'result-outbox.json'))) -or (Test-Path -LiteralPath (Join-Path $job ($prefix+'result-accepted.json')))
   if($refusal -and $resultPresent){throw 'LIFECYCLE_OUTCOME_REJECTED'}
   $ackFile=if($refusal){'refusal-accepted.json'}else{$prefix+'result-accepted.json'}
   if(Test-Path -LiteralPath (Join-Path $job $ackFile)){
    $e=Get-AuthWireLifecycleOutcomeEvidence $Root $state $Binding $Key
    $review.Phase='accepted_ack_completion_missing';$review.RecordedOutcome=$e.Outcome;$review.AcceptedAck=$true
    if($e.Outcome -ceq 'requires_review'){$review.StageConsumption=Get-AuthWireStageRecoveryClassification $Root $dir $state $Binding $Key}
    $review.Evidence.result_body_sha256=$e.BodySha256;$review.Evidence.accepted_ack=$true
   }elseif($refusal -or $resultPresent){
    if($refusal){$box=Read-AuthWireWriteRefusalOutbox $Root $h.Life $state $Binding $Key}
    elseif($rollback){$box=Read-AuthWireRollbackResultOutbox $Root $review.JobId $Binding $release $Key}
    else{$box=Read-AuthWireWriteResultOutbox $Root $review.JobId $Binding $release $Key}
    $review.Evidence.result_body_sha256=$box.body_sha256
    $review.Phase='outbox_without_accepted_ack'
   }elseif(Test-Path -LiteralPath (Join-Path $job ($prefix+'authorization.json'))){
    if($rollback){$null=Read-AuthWireRollbackAuthorizationEvidence $Root $review.JobId $Binding $release $Key}
    else{$null=Read-AuthWireWriteAuthorizationEvidence $Root $review.JobId $Binding $release $Key}
    $review.Phase='authorization_without_frozen_outcome'
   }elseif(Test-Path -LiteralPath (Join-Path $job ($prefix+'claim-sent.json'))){
    $review.Phase='claim_outcome_unknown'
   }else{$review.Phase='authorization_evidence_missing'}
   return $review
  }
  return $review
 }catch{
  return [pscustomobject]@{Phase='evidence_invalid_or_unavailable';Slot='';JobId='';RecordedOutcome='';AcceptedAck=$false;Evidence=$null;StageConsumption=$null}
 }finally{$pins.Dispose();$lock.ReleaseMutex();$lock.Dispose()}
}

function Write-AuthWireHistoryBytes([string]$Path,[byte[]]$Bytes){
 $s=[IO.File]::Open($Path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
 try{$s.Write($Bytes,0,$Bytes.Length);$s.Flush($true)}finally{$s.Dispose()}
}
function Invoke-AuthWireWriteHistoryArchive([string]$Root,[hashtable]$Binding,[Security.Cryptography.RSACng]$Key,$Reviewed,[string]$Acknowledge){
 # Trusted local SDK only. Review hashes constrain consent; they are not a
 # network credential, a new write grant or an independent service identity.
 if($Acknowledge -cne 'archive_observed_history_preserve_all_evidence'){throw 'HISTORY_ARCHIVE_ACK_REQUIRED'}
 Assert-AuthWireCandidateFields $Reviewed @('Review','ReviewSha256')
 if(-not (Test-AuthWireWriteHash $Reviewed.ReviewSha256) -or (Get-AuthWireWriteHash $Reviewed.Review) -cne $Reviewed.ReviewSha256){throw 'HISTORY_REVIEW_CHANGED'}
 $approved=$Reviewed.Review
 if(-not (Test-AuthWireWriteInteger $approved.checked_at) -or -not (Test-AuthWireWriteInteger $approved.expires_at) -or $approved.expires_at-$approved.checked_at -ne 60 -or $approved.checked_at -gt [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() -or $approved.expires_at -le [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()){throw 'HISTORY_REVIEW_EXPIRED'}
 $lock=Enter-AuthWireWriteCycleLock $Binding;$state=$null;$owned=[Collections.Generic.List[IDisposable]]::new();$copies=[Collections.Generic.List[IDisposable]]::new()
 try{
  $state=New-AuthWireHistoryReviewState $Root $Binding $Key
  $fresh=$state.Review;$fresh.checked_at=$approved.checked_at;$fresh.expires_at=$approved.expires_at
  if((Get-AuthWireWriteHash $fresh) -cne $Reviewed.ReviewSha256){throw 'HISTORY_REVIEW_CHANGED'}
  if(-not $fresh.can_archive -or $fresh.cycle_count -ne 64 -or $fresh.archive_index -gt 8){throw 'HISTORY_ARCHIVE_NOT_ELIGIBLE'}
  foreach($lease in $state.Leases){$lease.Dispose()};$state.Leases.Clear()
  # Protected job/origin/lock records remain pinned. Bind delete-capable local
  # cycle leases to the exact reviewed bytes before publishing an intent.
  foreach($detail in $state.Details){
   $lease=[AuthWire.Staging.TreeLeaseV1]::Tree((Join-Path $state.History.Life $detail.Slot),$true);$owned.Add($lease)
   if((Get-AuthWireWriteHash (Get-AuthWireHistoryCycleRows $lease)) -cne (Get-AuthWireWriteHash $detail.Rows)){throw 'HISTORY_REVIEW_CHANGED'}
  }
  if((Get-AuthWireHistoryProtectedHash $Root $state.Pins) -cne $fresh.protected_manifest_sha256){throw 'HISTORY_PROTECTED_CHANGED'}
  if([DateTimeOffset]::UtcNow.ToUnixTimeSeconds() -ge $fresh.expires_at){throw 'HISTORY_REVIEW_EXPIRED'}
  $life=$state.History.Life;$area=Join-Path $life 'history-archives'
  if(-not (Test-Path -LiteralPath $area)){
   [AuthWire.Staging.TreeLeaseV1]::CreateNewDirectory($area)
   $identity=[Security.Principal.WindowsIdentity]::GetCurrent();try{$sid=$identity.User.Value}finally{$identity.Dispose()}
   $acl=Get-Acl -LiteralPath $area
   $acl.SetSecurityDescriptorSddlForm(('D:P(A;OICI;FA;;;'+ $sid +')(A;OICI;FA;;;SY)(A;OICI;FA;;;BA)'),[Security.AccessControl.AccessControlSections]::Access)
   Set-Acl -LiteralPath $area -AclObject $acl -ErrorAction Stop
  }
  $state.Pins.PinAncestors($area);$state.Pins.PinDirectory($area);Assert-AuthWireStagingJournalRoot $area
  $dir=Join-Path $area $fresh.archive_index.ToString('D6');[AuthWire.Staging.TreeLeaseV1]::CreateNewDirectory($dir);$state.Pins.PinAncestors($dir)
  $started=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
  $intent=[pscustomobject]@{format='AuthWireWriteHistoryIntentV1';binding_scope=$fresh.binding_scope;archive_index=$fresh.archive_index;baseline_sha256=$fresh.baseline_sha256;previous_archive_sha256=$fresh.previous_archive_sha256;review_sha256=$Reviewed.ReviewSha256;first_slot=$fresh.first_slot;last_slot=$fresh.last_slot;started_at=$started}
  Write-AuthWireStagingJournal (Join-Path $dir 'intent.json') $intent
  $target=Join-Path $dir 'cycles';[AuthWire.Staging.TreeLeaseV1]::CreateNewDirectory($target);$state.Pins.PinAncestors($target)
  for($j=0;$j -lt 64;$j++){
   $detail=$state.Details[$j];$destination=Join-Path $target $detail.Slot;[AuthWire.Staging.TreeLeaseV1]::CreateNewDirectory($destination)
   foreach($row in $detail.Rows){Write-AuthWireHistoryBytes (Join-Path $destination $row.path) ($owned[$j].ReadOwnedBytes($row.path))}
   $copy=[AuthWire.Staging.TreeLeaseV1]::Tree($destination,$false);$copies.Add($copy)
   if((Get-AuthWireWriteHash (Get-AuthWireHistoryCycleRows $copy)) -cne (Get-AuthWireWriteHash $detail.Rows)){throw 'HISTORY_ARCHIVE_BYTES_CHANGED'}
  }
  $body=[pscustomobject]@{format='AuthWireWriteHistoryArchiveV1';policy=$fresh.policy;binding_scope=$fresh.binding_scope;baseline_sha256=$fresh.baseline_sha256;previous_archive_sha256=$fresh.previous_archive_sha256;archive_index=$fresh.archive_index;first_slot=$fresh.first_slot;last_slot=$fresh.last_slot;cycle_count=64;record_count=$fresh.record_count;total_bytes=$fresh.total_bytes;cycle_manifest_sha256=$fresh.cycle_manifest_sha256;protected_manifest_sha256=$fresh.protected_manifest_sha256;review_sha256=$Reviewed.ReviewSha256;review_checked_at=$fresh.checked_at;review_expires_at=$fresh.expires_at;intent_sha256=(Get-AuthWireWriteHash $intent);created_at=$started;cycles=$state.Cycles}
  $signature=$Key.SignData((Get-AuthWireHistoryArchiveFrame $body),[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1)
  $archive=[pscustomobject]@{body=$body;signature=[Convert]::ToBase64String($signature)}
  Write-AuthWireStagingJournal (Join-Path $dir 'archive.json') $archive;$state.Pins.PinFile((Join-Path $dir 'archive.json'))
  if([DateTimeOffset]::UtcNow.ToUnixTimeSeconds() -ge $fresh.expires_at){throw 'HISTORY_REVIEW_EXPIRED'}
  # Local maintenance has its own <=30-second retirement budget inside the
  # original 60-second review. No server CLAIM/grant/deadline is generated.
  $at=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds();$deadline=[Math]::Min($at+30,[long]$fresh.expires_at);$ticks=[Diagnostics.Stopwatch]::GetTimestamp()
  foreach($lease in $owned){$lease.DeleteOwnedTreeBefore($deadline,$at,$ticks)}
  if((Get-AuthWireHistoryProtectedHash $Root $state.Pins) -cne $fresh.protected_manifest_sha256){throw 'HISTORY_PROTECTED_CHANGED'}
  [AuthWire.Staging.TreeLeaseV1]::AssertRollbackDeadline($deadline,$at,$ticks)
  Write-AuthWireStagingJournal (Join-Path $dir 'committed.json') ([pscustomobject]@{format='AuthWireWriteHistoryCommittedV1';binding_scope=$fresh.binding_scope;archive_index=$fresh.archive_index;archive_sha256=(Get-AuthWireWriteHash $archive);completed_at=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()})
  return [pscustomobject]@{Phase='history_archived';ArchivedThrough=[int]$fresh.last_slot;ArchivedCycles=64;ArchiveCount=$fresh.archive_index;ArchiveSha256=(Get-AuthWireWriteHash $archive);ProtectedRecordsPreserved=$true;CanApplyGpo=$false;NetworkSent=$false}
 }finally{foreach($lease in $copies){$lease.Dispose()};foreach($lease in $owned){$lease.Dispose()};if($state){foreach($lease in $state.Leases){$lease.Dispose()};$state.Pins.Dispose()};$lock.ReleaseMutex();$lock.Dispose()}
}



# Explicit AllSigned local maintenance. This appends an immutable logical
# retirement, retaining the original reservation, refusal, stage and GPO lock.
# A server saved-result acknowledgement is NOT rollback/delete authorization.
function Get-AuthWireRollbackRetirementFrame($Body,[string]$Purpose){
 if($Purpose -cnotin @('AUTHWIRE-REFUSED-ROLLBACK-RETIRE-REVIEW-V1','AUTHWIRE-REFUSED-ROLLBACK-RETIRE-COMPLETE-V1','AUTHWIRE-CONSUMED-ROLLBACK-RETIRE-REVIEW-V1','AUTHWIRE-CONSUMED-ROLLBACK-RETIRE-COMPLETE-V1','AUTHWIRE-PREINTENT-ROLLBACK-OBSERVATION-V1','AUTHWIRE-PREINTENT-ROLLBACK-RETIRE-REVIEW-V1','AUTHWIRE-PREINTENT-ROLLBACK-RETIRE-COMPLETE-V1')){throw 'ROLLBACK_RETIRE_PURPOSE_REJECTED'}
 return ,([Text.Encoding]::ASCII.GetBytes($Purpose+[char]10+(Get-AuthWireWriteHash $Body)+[char]10))
}
function New-AuthWireRollbackRetirementProof($Body,[Security.Cryptography.RSACng]$Key,[string]$Purpose){
 return [pscustomobject]@{Body=$Body;Signature=[Convert]::ToBase64String($Key.SignData((Get-AuthWireRollbackRetirementFrame $Body $Purpose),[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1))}
}
function Assert-AuthWireRollbackRetirementProof($Proof,[Security.Cryptography.RSACng]$Key,[string]$Purpose){
 Assert-AuthWireCandidateFields $Proof @('Body','Signature')
 if(-not $Key.VerifyData((Get-AuthWireRollbackRetirementFrame $Proof.Body $Purpose),(ConvertFrom-AuthWireWriteBase64 $Proof.Signature 512),[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1)){throw 'ROLLBACK_RETIRE_SIGNATURE_REJECTED'}
}
function Get-AuthWireRollbackRetirementState([string]$Root,[string]$JobId,[hashtable]$Binding,[Security.Cryptography.RSACng]$Key,$Pins,$ExistingState=$null,[string]$ExistingLife='',[bool]$Historical=$false){
 Assert-AuthWireStagingWriteJournalLocation $Root $Binding;Assert-AuthWireCandidateGuid $JobId
 if($null -eq $ExistingState){
  $h=Read-AuthWireLifecycleHistory $Root $Binding $Key
  if($h.ActiveStates.Count -lt 1){throw 'ROLLBACK_RETIRE_NOT_LATEST'}
  $state=$h.ActiveStates[-1];$life=$h.Life
 }else{$state=$ExistingState;$life=$ExistingLife}
 if($state.Phase -cne 'reply_saved' -or $state.Offer.job_id -cne $JobId -or $state.Offer.operation -cne 'combined.filesystem.rollback.v1'){throw 'ROLLBACK_RETIRE_NOT_REFUSED_ROLLBACK'}
 $job=Join-Path $Root $JobId;$Pins.PinAncestors($Root);$Pins.PinAncestors($job)
 $slot=Join-Path $life $state.Slot;$Pins.PinAncestors($slot)
 foreach($dir in @($slot,$job)){foreach($f in Get-ChildItem -LiteralPath $dir -Force){if($f.PSIsContainer){throw 'ROLLBACK_RETIRE_UNKNOWN_HISTORY'};$Pins.PinFile($f.FullName)}}
 $done=Read-AuthWireLifecycleCompletion $Root $life $state $Binding $Key
 if($done.outcome -cne 'refused_before_authorization'){throw 'ROLLBACK_RETIRE_NOT_REFUSED_ROLLBACK'}
 # These readers verify the signed POLL/offer, strict no-CLAIM allow-list,
 # failure record, frozen refusal and exact accepted server ACK/completion.
 $box=Read-AuthWireWriteRefusalOutbox $Root $life $state $Binding $Key ($life -cne (Get-AuthWireWriteLifecyclePath $Root $Binding))
 $ack=Read-AuthWireWriteRefusalAccepted $Root $state $box
 if($box.body.authorization_id -cne '' -or $box.body.filesystem_effects -cne 'none' -or $box.body.reason -cne 'PREFLIGHT_FAILED'){throw 'ROLLBACK_RETIRE_AUTHORITY_OR_EFFECTS'}
 $saved=Read-AuthWireRollbackOfferAt $Root $JobId $Binding $state.Started.release_id $state.Response.received_at
 $reservationPath=Get-AuthWireRollbackReservationPath $Root $saved.Reservation.stage_job_id $JobId;$Pins.PinFile($reservationPath)
 $stage=Join-Path $Root $saved.Reservation.stage_job_id;$Pins.PinAncestors($stage)
 foreach($f in Get-ChildItem -LiteralPath $stage -File){$Pins.PinFile($f.FullName)}
 $engine=Join-Path $Root $saved.Reservation.stage_operation_id;$Pins.PinAncestors($engine)
 foreach($f in Get-ChildItem -LiteralPath $engine -File){$Pins.PinFile($f.FullName)}
 $gpoLock=Join-Path $Root ('gpo-'+$state.Offer.target.scope_target.gpo_id+'.json');$Pins.PinFile($gpoLock)
 $origin=Read-AuthWireRollbackOriginEvidenceAt $state.Offer $Binding $state.Started.release_id $Key $state.Response.received_at
 if(-not $Historical){
  if([DateTimeOffset]::UtcNow.ToUnixTimeSeconds() -lt $state.Offer.expires_at){throw 'ROLLBACK_RETIRE_OFFER_NOT_EXPIRED'}
  Assert-AuthWireNoActiveStage $Root $origin.StageJobId
  foreach($n in @('rollback-started.json','rolled-back.json')){if(Test-Path -LiteralPath (Join-Path $engine $n)){throw 'ROLLBACK_RETIRE_ENGINE_ALREADY_ENTERED'}}
  $tree=$null
  try{
   Add-AuthWireStagingGpoPins $Pins $origin.Intent.gpo_root $origin.Intent.gpo_root
   Add-AuthWireStagingGpoPins $Pins (Join-Path $origin.Intent.gpo_root 'Machine') $origin.Intent.gpo_root
   $tree=[AuthWire.Staging.TreeLeaseV1]::Tree((Join-Path $origin.Intent.gpo_root $origin.Intent.relative_destination.Replace('/','\')),$false)
   if((Get-AuthWireStagingFilesystemDigest (Get-AuthWireStagingFilesystemRows $tree)) -cne $origin.Complete.tree_sha256){throw 'ROLLBACK_RETIRE_STAGE_DRIFT'}
   $v=Get-AuthWireSysvolInventory $origin.Intent.gpo_root;$rel=$origin.Intent.relative_destination
   $outside=@($v.Entries|Where-Object {$_.Path -cne $rel -and -not $_.Path.StartsWith($rel+'/',[StringComparison]::Ordinal)})
   if((Get-AuthWireScopeDataHash $outside) -cne $origin.Intent.baseline_sha256){throw 'ROLLBACK_RETIRE_OUTSIDE_DRIFT'}
  }finally{if($tree){$tree.Dispose()}}
 }
 $evidence=[pscustomobject]@{job_id=$JobId;scope_sha256=(Get-AuthWireJobScope $Binding);intent_sha256=$state.Offer.intent_sha256;result_body_sha256=$box.body_sha256;accepted_ack=$true}
 $frozen=[pscustomobject]@{offer=(Get-AuthWireWriteHash $state.Offer);completion=(Get-AuthWireWriteHash $done);ack=(Get-AuthWireWriteHash $ack);refusal=(Get-AuthWireWriteHash $box);reservation=(Get-AuthWireWriteHash $saved.Reservation);origin=$origin.ChainSha256;gpo_lock=(Get-AuthWireWriteHash (Read-AuthWireStagingJournal $gpoLock))}
 return [pscustomobject]@{State=$state;Life=$life;Origin=$origin;Evidence=$evidence;Frozen=$frozen;OriginalSha256=(Get-AuthWireWriteHash $frozen);Reservation=$saved.Reservation}
}
function New-AuthWireRollbackRetirementBody($State,[hashtable]$Binding,[long]$At){
 if(-not (Test-AuthWireWriteInteger $At)){throw 'ROLLBACK_RETIRE_TIME_REJECTED'}
 return [pscustomobject]@{format='AuthWireRefusedRollbackRetirementReviewV1';job_id=$State.State.Offer.job_id;stage_job_id=$State.Origin.StageJobId;gpo_id=$State.State.Offer.target.scope_target.gpo_id;binding_scope=(Get-AuthWireJobScope $Binding);original_records_sha256=$State.OriginalSha256;reservation_sha256=$State.Frozen.reservation;origin_chain_sha256=$State.Origin.ChainSha256;tree_sha256=$State.Origin.Complete.tree_sha256;baseline_sha256=$State.Origin.Intent.baseline_sha256;result_body_sha256=$State.Evidence.result_body_sha256;observed_at=$At;expires_at=($At+60);retain_original_reservation=$true;retain_gpo_lock=$true;requires_new_rollback_job=$true;can_delete=$false;can_apply_gpo=$false}
}
function Assert-AuthWireRollbackRetirementReview($Proof,$State,[hashtable]$Binding,[Security.Cryptography.RSACng]$Key,[long]$At){
 Assert-AuthWireRollbackRetirementProof $Proof $Key 'AUTHWIRE-REFUSED-ROLLBACK-RETIRE-REVIEW-V1'
 $expected=New-AuthWireRollbackRetirementBody $State $Binding $Proof.Body.observed_at
 if((Get-AuthWireWriteHash $expected) -cne (Get-AuthWireWriteHash $Proof.Body) -or $At -lt $Proof.Body.observed_at -or $At -ge $Proof.Body.expires_at){throw 'ROLLBACK_RETIRE_REVIEW_CHANGED_OR_EXPIRED'}
}
function Assert-AuthWireRollbackRetirementAcknowledgement($Request,$Receipt,$State){
 Assert-AuthWireCandidateFields $Request @('expected_revision','evidence','decision','review_hash','acknowledge')
 if($Request.decision -cne 'acknowledge_saved_result' -or $Request.acknowledge -cne 'record_reconciliation_decision' -or -not (Test-AuthWireWriteInteger $Request.expected_revision) -or -not (Test-AuthWireWriteHash $Request.review_hash) -or (Get-AuthWireWriteHash $Request.evidence) -cne (Get-AuthWireWriteHash $State.Evidence)){throw 'ROLLBACK_RETIRE_SERVER_ACK_REJECTED'}
 $fields=@('job_id','decision','decision_recorded','revision','approval_enabled','write_authorization_enabled','execution_adapter_available','can_apply_gpo')
 if($Receipt.PSObject.Properties['source_only']){$fields+='source_only'}
 Assert-AuthWireCandidateFields $Receipt $fields
 if($Receipt.job_id -cne $State.State.Offer.job_id -or $Receipt.decision -cne $Request.decision -or $Receipt.decision_recorded -isnot [bool] -or -not $Receipt.decision_recorded -or -not (Test-AuthWireWriteInteger $Receipt.revision) -or $Receipt.revision -ne $Request.expected_revision+1){throw 'ROLLBACK_RETIRE_SERVER_ACK_REJECTED'}
 # These three describe the endpoint's capabilities, NOT this acknowledgement's
 # authority. The fixed G01 pilot reports enabled capabilities; the source-only
 # product route reports disabled capabilities. Neither reply contains a grant.
 foreach($n in @('approval_enabled','write_authorization_enabled','execution_adapter_available')){if($Receipt.$n -isnot [bool] -or $Receipt.$n -ne $Receipt.approval_enabled){throw 'ROLLBACK_RETIRE_SERVER_ACK_REJECTED'}}
 if($Receipt.PSObject.Properties['source_only']){
  if($Receipt.source_only -isnot [bool] -or $Receipt.source_only -eq $Receipt.approval_enabled){throw 'ROLLBACK_RETIRE_SERVER_ACK_REJECTED'}
 }elseif($Receipt.approval_enabled){throw 'ROLLBACK_RETIRE_SERVER_ACK_REJECTED'}
 if($Receipt.can_apply_gpo -isnot [bool] -or $Receipt.can_apply_gpo){throw 'ROLLBACK_RETIRE_SERVER_ACK_REJECTED'}
}
function Confirm-AuthWireRollbackRetirementAcknowledgement([hashtable]$Binding,[string]$BaseUrl,$Request,[securestring]$Session,[securestring]$Csrf){
 Initialize-AuthWireWriteTransportTypes
 $raw=[AuthWire.Connector.WriteTransportV1]::ConfirmSavedRefusal($BaseUrl,$Binding.appliance_fqdn,$Binding.appliance_tls_sha256,(ConvertTo-AuthWireWriteJson $Request),[Net.NetworkCredential]::new('',$Session).Password,[Net.NetworkCredential]::new('',$Csrf).Password)
 return (ConvertFrom-AuthWireCandidateJson ([Text.UTF8Encoding]::new($false,$true).GetBytes($raw)))
}
function Get-AuthWireRefusedRollbackRetirementReview([string]$Root,[string]$JobId,[hashtable]$Binding,[Security.Cryptography.RSACng]$Key){
 Assert-AuthWireRollbackReaderIdentity $Binding
 $lock=Enter-AuthWireWriteCycleLock $Binding;$p=[AuthWire.Staging.TreeLeaseV1]::new()
 try{
  $s=Get-AuthWireRollbackRetirementState $Root $JobId $Binding $Key $p
  $proof=New-AuthWireRollbackRetirementProof (New-AuthWireRollbackRetirementBody $s $Binding ([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())) $Key 'AUTHWIRE-REFUSED-ROLLBACK-RETIRE-REVIEW-V1'
  return [pscustomobject]@{Proof=$proof;ProofSha256=(Get-AuthWireWriteHash $proof);Evidence=$s.Evidence}
 }finally{$p.Dispose();$lock.ReleaseMutex();$lock.Dispose()}
}
function New-AuthWireRollbackRetirementCompletion($Record,$State,[hashtable]$Binding,[long]$At){
 return [pscustomobject]@{format='AuthWireRefusedRollbackRetirementCompleteV1';job_id=$State.State.Offer.job_id;stage_job_id=$State.Origin.StageJobId;binding_scope=(Get-AuthWireJobScope $Binding);original_records_sha256=$State.OriginalSha256;review_record_sha256=(Get-AuthWireWriteHash $Record);reservation_sha256=$State.Frozen.reservation;closed_at=$At;original_refusal_preserved=$true;original_reservation_retained=$true;gpo_lock_retained=$true;authority_renewed=$false;can_delete=$false;can_apply_gpo=$false}
}
function Complete-AuthWireRefusedRollbackRetirement([string]$Root,[string]$JobId,[hashtable]$Binding,[Security.Cryptography.RSACng]$Key,[string]$BaseUrl,$Proof,[string]$ExpectedProofSha256,$Acknowledgement,[securestring]$Session,[securestring]$Csrf,[string]$Acknowledge){
 if($Acknowledge -cne 'retire_refused_rollback_without_replay' -or (Get-AuthWireWriteHash $Proof) -cne $ExpectedProofSha256){throw 'ROLLBACK_RETIRE_EXPLICIT_REVIEW_REQUIRED'}
 Assert-AuthWireRollbackReaderIdentity $Binding
 $lock=Enter-AuthWireWriteCycleLock $Binding;$decision=$null;$p=[AuthWire.Staging.TreeLeaseV1]::new();$store=$null;$taken=$false
 try{
  $decision=Enter-AuthWireWritePreauthorizationLock $JobId
  $store=[Threading.Mutex]::new($false,'Global\AuthWireWritePreclaimStoreV1')
  try{$taken=$store.WaitOne(0)}catch [Threading.AbandonedMutexException]{$taken=$true;throw 'ROLLBACK_RETIRE_STORE_ABANDONED'}
  if(-not $taken){throw 'ROLLBACK_RETIRE_STORE_BUSY'}
  $job=Join-Path $Root $JobId
  foreach($n in @('rollback-retirement-review.json','rollback-retirement-complete.json')){if(Test-Path -LiteralPath (Join-Path $job $n)){throw 'ROLLBACK_RETIRE_ALREADY_STARTED_READ_EXISTING'}}
  $s=Get-AuthWireRollbackRetirementState $Root $JobId $Binding $Key $p
  Assert-AuthWireRollbackRetirementReview $Proof $s $Binding $Key ([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())
  # Fresh privileged session/Origin/CSRF and existing dual permissions are
  # checked by the product. The exact saved acknowledgement is idempotent.
  $receipt=Confirm-AuthWireRollbackRetirementAcknowledgement $Binding $BaseUrl $Acknowledgement $Session $Csrf
  Assert-AuthWireRollbackRetirementAcknowledgement $Acknowledgement $receipt $s
  $now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds();Assert-AuthWireRollbackRetirementReview $Proof $s $Binding $Key $now
  $record=[pscustomobject]@{format='AuthWireRefusedRollbackRetirementRecordV1';review=$Proof;acknowledgement_request=$Acknowledgement;acknowledgement_receipt=$receipt;acknowledge=$Acknowledge}
  Write-AuthWireStagingJournal (Join-Path $job 'rollback-retirement-review.json') $record
  $closed=New-AuthWireRollbackRetirementProof (New-AuthWireRollbackRetirementCompletion $record $s $Binding $now) $Key 'AUTHWIRE-REFUSED-ROLLBACK-RETIRE-COMPLETE-V1'
  Write-AuthWireStagingJournal (Join-Path $job 'rollback-retirement-complete.json') $closed
  return $closed
 }finally{if($taken){$store.ReleaseMutex()};if($store){$store.Dispose()};$p.Dispose();if($decision){$decision.ReleaseMutex();$decision.Dispose()};$lock.ReleaseMutex();$lock.Dispose()}
}
function Test-AuthWireRefusedRollbackRetired([string]$Root,[string]$Life,$State,[hashtable]$Binding,[Security.Cryptography.RSACng]$Key){
 $job=Join-Path $Root $State.Offer.job_id;$file=Join-Path $job 'rollback-retirement-complete.json'
 if(-not (Test-Path -LiteralPath $file)){return $false}
 $p=[AuthWire.Staging.TreeLeaseV1]::new()
 try{
  $s=Get-AuthWireRollbackRetirementState $Root $State.Offer.job_id $Binding $Key $p $State $Life $true
  $record=Read-AuthWireStagingJournal (Join-Path $job 'rollback-retirement-review.json');$closed=Read-AuthWireStagingJournal $file
  Assert-AuthWireCandidateFields $record @('format','review','acknowledgement_request','acknowledgement_receipt','acknowledge')
  if($record.format -cne 'AuthWireRefusedRollbackRetirementRecordV1' -or $record.acknowledge -cne 'retire_refused_rollback_without_replay'){throw 'ROLLBACK_RETIRE_COMPLETION_REJECTED'}
  Assert-AuthWireRollbackRetirementProof $closed $Key 'AUTHWIRE-REFUSED-ROLLBACK-RETIRE-COMPLETE-V1'
  if(-not (Test-AuthWireWriteInteger $closed.Body.closed_at) -or $closed.Body.closed_at -gt [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()){throw 'ROLLBACK_RETIRE_COMPLETION_REJECTED'}
  Assert-AuthWireRollbackRetirementReview $record.review $s $Binding $Key $closed.Body.closed_at
  Assert-AuthWireRollbackRetirementAcknowledgement $record.acknowledgement_request $record.acknowledgement_receipt $s
  $expected=New-AuthWireRollbackRetirementCompletion $record $s $Binding $closed.Body.closed_at
  if((Get-AuthWireWriteHash $expected) -cne (Get-AuthWireWriteHash $closed.Body)){throw 'ROLLBACK_RETIRE_COMPLETION_REJECTED'}
  return $true
 }finally{$p.Dispose()}
}
function Assert-AuthWireRetiredRollbackPredecessors([string]$Root,$Offer,[hashtable]$Binding,[Security.Cryptography.RSACng]$Key){
 $h=Read-AuthWireLifecycleHistory $Root $Binding $Key;$found=0;$stage=$Offer.target.stage_receipt.stage_job_id
 foreach($s in $h.States){
  if($null -eq $s.Offer -or $s.Offer.job_id -ceq '' -or $s.Offer.job_id -ceq $Offer.job_id -or $s.Offer.operation -cne 'combined.filesystem.rollback.v1' -or $s.Offer.target.stage_receipt.stage_job_id -cne $stage){continue}
  $life=$h.Life
  if(-not (Test-Path -LiteralPath (Join-Path $life $s.Slot))){
   $matches=@(Get-ChildItem -LiteralPath (Join-Path $h.Life 'history-archives') -Directory|ForEach-Object {Join-Path $_.FullName 'cycles'}|Where-Object {Test-Path -LiteralPath (Join-Path $_ $s.Slot)})
   if($matches.Count -ne 1){throw 'ROLLBACK_RETIRE_PREDECESSOR_HISTORY_REJECTED'};$life=$matches[0]
  }
  $retired=if(Test-Path -LiteralPath (Join-Path (Join-Path $Root $s.Offer.job_id) 'rollback-preintent-retirement-complete.json')){Test-AuthWirePreIntentRollbackRetired $Root $life $s $Binding $Key}elseif($s.Offer.operation -ceq 'combined.filesystem.rollback.v1' -and (Test-Path -LiteralPath (Join-Path (Join-Path $Root $s.Offer.job_id) 'rollback-consumed-retirement-complete.json'))){Test-AuthWireConsumedRollbackRetired $Root $life $s $Binding $Key}else{Test-AuthWireRefusedRollbackRetired $Root $life $s $Binding $Key}
  if(-not $retired){throw 'ROLLBACK_PRIOR_RESERVATION_REQUIRES_REVIEW'}
  $found++
 }
 if($found -lt 1){throw 'ROLLBACK_PRIOR_RESERVATION_REQUIRES_REVIEW'}
}

# Intent-bearing rollback retirement is deliberately separate from a refusal.
# It preserves OUTCOME_UNKNOWN; a later unchanged-tree observation does not
# retroactively prove that no transient filesystem effect ever occurred.
function Assert-AuthWireRollbackReadOnlyObservation($Observation,$Original,[Security.Cryptography.RSACng]$Key){
 Assert-AuthWireCandidateFields $Observation @('domain','body','signature')
 $b=$Observation.body;$a=$Original.Authorization;$origin=$a.Origin
 Assert-AuthWireCandidateFields $b @('format','job_id','stage_job_id','stage_operation_id','active_release','authority_expired','intent_sha256','original_child_running','entered_marker_exists','engine_markers','tree_sha256','outside_baseline_sha256','tree_rows','staged_tree_unchanged','outside_unchanged','read_only','can_delete','authority_renewed','at')
 Assert-AuthWireCandidateFields $b.engine_markers @('rolled-back.json','rollback-started.json')
 foreach($n in @('authority_expired','staged_tree_unchanged','outside_unchanged','read_only')){if($b.$n -isnot [bool] -or -not $b.$n){throw 'ROLLBACK_CONSUMED_OBSERVATION_REJECTED'}}
 foreach($n in @('original_child_running','entered_marker_exists','can_delete','authority_renewed')){if($b.$n -isnot [bool] -or $b.$n){throw 'ROLLBACK_CONSUMED_OBSERVATION_REJECTED'}}
 foreach($n in @('rolled-back.json','rollback-started.json')){if($b.engine_markers.$n -isnot [bool] -or $b.engine_markers.$n){throw 'ROLLBACK_CONSUMED_OBSERVATION_REJECTED'}}
 if($Observation.domain -cne 'AUTHWIRE-ROLLBACK-READONLY-OBSERVATION-V1' -or $b.format -cne 'AuthWireRollbackReadOnlyObservationV1' -or
    $b.job_id -cne $a.Offer.job_id -or $b.stage_job_id -cne $origin.StageJobId -or $b.stage_operation_id -cne $origin.FilesystemOperationId -or
    $b.active_release -cne $a.Receipt.release_id -or $b.intent_sha256 -cne $Original.IntentSha256 -or $b.tree_sha256 -cne $origin.Complete.tree_sha256 -or
    $b.outside_baseline_sha256 -cne $origin.Intent.baseline_sha256 -or -not (Test-AuthWireWriteInteger $b.tree_rows) -or $b.tree_rows -lt 1 -or
    -not (Test-AuthWireWriteInteger $b.at) -or $b.at -lt $Original.Intent.expires_at -or $b.at -gt [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()){throw 'ROLLBACK_CONSUMED_OBSERVATION_REJECTED'}
 $frame=[Text.Encoding]::UTF8.GetBytes($Observation.domain+[char]10+(ConvertTo-AuthWireWriteJson $b))
 if(-not $Key.VerifyData($frame,(ConvertFrom-AuthWireWriteBase64 $Observation.signature 512),[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1)){throw 'ROLLBACK_CONSUMED_OBSERVATION_SIGNATURE_REJECTED'}
}
function Assert-AuthWireConsumedRollbackCurrentState([string]$Root,[string]$JobId,$State,$Original,$Observation,$Pins){
 $state=$State;$original=$Original;$origin=$Original.Authorization.Origin
  if([DateTimeOffset]::UtcNow.ToUnixTimeSeconds() -lt [Math]::Max($state.Offer.expires_at,$original.Intent.expires_at)){throw 'ROLLBACK_CONSUMED_AUTHORITY_NOT_EXPIRED'}
  Assert-AuthWireNoActiveRollback $Root $JobId;Assert-AuthWireNoActiveStage $Root $origin.StageJobId
  $engine=Join-Path $Root $origin.FilesystemOperationId
  foreach($n in @('rollback-started.json','rolled-back.json')){if(Test-Path -LiteralPath (Join-Path $engine $n)){throw 'ROLLBACK_CONSUMED_ENGINE_ENTERED'}}
  $tree=$null
  try{
   Add-AuthWireStagingGpoPins $Pins $origin.Intent.gpo_root $origin.Intent.gpo_root;Add-AuthWireStagingGpoPins $Pins (Join-Path $origin.Intent.gpo_root 'Machine') $origin.Intent.gpo_root
   $dest=Join-Path $origin.Intent.gpo_root $origin.Intent.relative_destination.Replace('/','\');$tree=[AuthWire.Staging.TreeLeaseV1]::Tree($dest,$false)
   $rows=Get-AuthWireStagingFilesystemRows $tree
   if((Get-AuthWireStagingFilesystemDigest $rows) -cne $origin.Complete.tree_sha256 -or @($rows).Count -ne $Observation.body.tree_rows){throw 'ROLLBACK_CONSUMED_STAGE_DRIFT'}
   foreach($row in $rows){$path=if($row.Path -ceq ''){$dest}else{Join-Path $dest $row.Path.Replace('/','\')};if($row.Kind -ceq 'file'){$Pins.PinFile($path)}else{Add-AuthWireStagingGpoPins $Pins $path $origin.Intent.gpo_root}}
   $v=Get-AuthWireSysvolInventory $origin.Intent.gpo_root;$rel=$origin.Intent.relative_destination
   $outside=@($v.Entries|Where-Object {$_.Path -cne $rel -and -not $_.Path.StartsWith($rel+'/',[StringComparison]::Ordinal)})
   if((Get-AuthWireScopeDataHash $outside) -cne $origin.Intent.baseline_sha256){throw 'ROLLBACK_CONSUMED_OUTSIDE_DRIFT'}
  }finally{if($tree){$tree.Dispose()}}
}
function Get-AuthWireConsumedRollbackRetirementState([string]$Root,[string]$JobId,[hashtable]$Binding,[Security.Cryptography.RSACng]$Key,$Pins,$Observation,$ExistingState=$null,[string]$ExistingLife='',[bool]$Historical=$false){
 Assert-AuthWireStagingWriteJournalLocation $Root $Binding;Assert-AuthWireCandidateGuid $JobId
 if($null -eq $ExistingState){
  $h=Read-AuthWireLifecycleHistory $Root $Binding $Key
  if($h.ActiveStates.Count -lt 1){throw 'ROLLBACK_CONSUMED_NOT_LATEST'}
  $state=$h.ActiveStates[-1];$life=$h.Life
 }else{$state=$ExistingState;$life=$ExistingLife}
 if($state.Phase -cne 'reply_saved' -or $state.Offer.job_id -cne $JobId -or $state.Offer.operation -cne 'combined.filesystem.rollback.v1'){throw 'ROLLBACK_CONSUMED_NOT_ROLLBACK'}
 $job=Join-Path $Root $JobId;$slot=Join-Path $life $state.Slot;$Pins.PinAncestors($Root);$Pins.PinAncestors($job);$Pins.PinAncestors($slot)
 $allowed=@('rollback-offer.json','rollback-preflight.json','rollback-claim-started.json','rollback-claim-proof.json','rollback-claim-sent.json','rollback-authorization.json','rollback-grant-consumed.json','rollback-consumption-preflight.json','rollback-filesystem-intent.json','rollback-launch.json','rollback-child.json','rollback-execution-requires-review.json','rollback-result-outbox.json','rollback-result-accepted.json','rollback-reservation.json')
 foreach($n in @($allowed|Where-Object {$_ -cne 'rollback-reservation.json'})){$Pins.PinFile((Join-Path $job $n))}
 foreach($i in 1..3){foreach($kind in @('attempt','proof')){$allowed+=,('rollback-result-'+$kind+'-'+$i+'.json')}}
 $records=@()
 foreach($f in @(Get-ChildItem -LiteralPath $job -Force|Sort-Object Name -CaseSensitive)){
  if($f.PSIsContainer){throw 'ROLLBACK_CONSUMED_UNKNOWN_HISTORY'}
  $Pins.PinFile($f.FullName)
  if($f.Name -cin @('rollback-consumed-retirement-review.json','rollback-consumed-retirement-complete.json')){continue}
  if($f.Name -cnotin $allowed){throw 'ROLLBACK_CONSUMED_UNKNOWN_HISTORY'}
  $records+=,[pscustomobject]@{name=$f.Name;sha256=(Get-AuthWireJobHash (Read-AuthWireCandidateBytes $f.FullName 65536))}
 }
 foreach($f in Get-ChildItem -LiteralPath $slot -Force){if($f.PSIsContainer){throw 'ROLLBACK_CONSUMED_UNKNOWN_HISTORY'};$Pins.PinFile($f.FullName)}
 $done=Read-AuthWireLifecycleCompletion $Root $life $state $Binding $Key
 if($done.outcome -cne 'requires_review'){throw 'ROLLBACK_CONSUMED_RESULT_REJECTED'}
 $original=Read-AuthWireAuthorizedRollbackIntentEvidence $Root $JobId $Binding $state.Started.release_id $Key
 $a=$original.Authorization;$origin=$a.Origin
 $Pins.PinFile((Get-AuthWireRollbackReservationPath $Root $origin.StageJobId $JobId))
 $Pins.PinFile((Get-AuthWireRollbackReservationPath $Root $origin.StageJobId))
 $gpoLock=Join-Path $Root ('gpo-'+$state.Offer.target.scope_target.gpo_id+'.json');$Pins.PinFile($gpoLock)
 foreach($dir in @((Join-Path $Root $origin.StageJobId),(Join-Path $Root $origin.FilesystemOperationId))){$Pins.PinAncestors($dir);foreach($f in Get-ChildItem -LiteralPath $dir -File){$Pins.PinFile($f.FullName)}}
 $box=Read-AuthWireRollbackResultOutbox $Root $JobId $Binding $state.Started.release_id $Key
 if($box.body.outcome -cne 'requires_review' -or $box.body.reason -cne 'OUTCOME_UNKNOWN' -or $box.body.filesystem_effects -cne 'unconfirmed' -or $box.body.authorization_id -ceq ''){throw 'ROLLBACK_CONSUMED_RESULT_REJECTED'}
 $accepted=Get-AuthWireLifecycleOutcomeEvidence $Root $state $Binding $Key $life
 if($accepted.Outcome -cne 'requires_review' -or $accepted.BodySha256 -cne $box.body_sha256){throw 'ROLLBACK_CONSUMED_ACK_REJECTED'}
 $launch=Read-AuthWireRollbackLaunch $Root $JobId $original
 $child=Read-AuthWireRollbackChildIdentity $Root $JobId $launch
 $review=Read-AuthWireStagingJournal (Join-Path $job 'rollback-execution-requires-review.json')
 Assert-AuthWireCandidateFields $review @('format','job_id','execution_intent_sha256','reason','checked_at','diagnostic')
 if($review.format -cne 'AuthWireRollbackReviewV1' -or $review.job_id -cne $JobId -or $review.execution_intent_sha256 -cne $original.IntentSha256 -or $review.reason -cne 'OUTCOME_REQUIRES_REVIEW' -or
    -not (Test-AuthWireWriteInteger $review.checked_at) -or $review.checked_at -lt $launch.started_at -or $review.checked_at -gt $done.completed_at){throw 'ROLLBACK_CONSUMED_EXECUTION_REJECTED'}
 Assert-AuthWireRollbackReadOnlyObservation $Observation $original $Key
 if(-not $Historical){Assert-AuthWireConsumedRollbackCurrentState $Root $JobId $state $original $Observation $Pins}
 $frozen=[pscustomobject]@{offer=(Get-AuthWireWriteHash $state.Offer);completion=(Get-AuthWireWriteHash $done);ack=$accepted.AckSha256;result=(Get-AuthWireWriteHash $box);reservation=(Get-AuthWireWriteHash $a.Reservation);origin=$origin.ChainSha256;gpo_lock=(Get-AuthWireWriteHash (Read-AuthWireStagingJournal $gpoLock));intent=$original.IntentSha256;launch=(Get-AuthWireWriteHash $launch);child=(Get-AuthWireWriteHash $child);observation=(Get-AuthWireWriteHash $Observation);job_records=(Get-AuthWireWriteHash $records)}
 $evidence=[pscustomobject]@{job_id=$JobId;scope_sha256=(Get-AuthWireJobScope $Binding);intent_sha256=$state.Offer.intent_sha256;result_body_sha256=$box.body_sha256;accepted_ack=$true}
 return [pscustomobject]@{State=$state;Life=$life;Origin=$origin;Evidence=$evidence;Frozen=$frozen;OriginalSha256=(Get-AuthWireWriteHash $frozen);Reservation=$a.Reservation;Original=$original}
}
function New-AuthWireConsumedRollbackRetirementBody($State,[hashtable]$Binding,[long]$At){
 $v=New-AuthWireRollbackRetirementBody $State $Binding $At;$v.format='AuthWireConsumedRollbackRetirementReviewV1'
 $v|Add-Member NoteProperty filesystem_intent_sha256 $State.Frozen.intent
 $v|Add-Member NoteProperty prior_observation_sha256 $State.Frozen.observation
 $v|Add-Member NoteProperty original_outcome 'requires_review'
 $v|Add-Member NoteProperty filesystem_effects 'unconfirmed'
 return $v
}
function Assert-AuthWireConsumedRollbackRetirementReview($Proof,$State,[hashtable]$Binding,[Security.Cryptography.RSACng]$Key,[long]$At){
 Assert-AuthWireRollbackRetirementProof $Proof $Key 'AUTHWIRE-CONSUMED-ROLLBACK-RETIRE-REVIEW-V1'
 $expected=New-AuthWireConsumedRollbackRetirementBody $State $Binding $Proof.Body.observed_at
 if((Get-AuthWireWriteHash $expected) -cne (Get-AuthWireWriteHash $Proof.Body) -or $At -lt $Proof.Body.observed_at -or $At -ge $Proof.Body.expires_at){throw 'ROLLBACK_CONSUMED_REVIEW_CHANGED_OR_EXPIRED'}
}
function Get-AuthWireConsumedRollbackRetirementReview([string]$Root,[string]$JobId,[hashtable]$Binding,[Security.Cryptography.RSACng]$Key,$Observation){
 Assert-AuthWireRollbackReaderIdentity $Binding
 $lock=Enter-AuthWireWriteCycleLock $Binding;$p=[AuthWire.Staging.TreeLeaseV1]::new()
 try{
  $s=Get-AuthWireConsumedRollbackRetirementState $Root $JobId $Binding $Key $p $Observation
  $proof=New-AuthWireRollbackRetirementProof (New-AuthWireConsumedRollbackRetirementBody $s $Binding ([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())) $Key 'AUTHWIRE-CONSUMED-ROLLBACK-RETIRE-REVIEW-V1'
  return [pscustomobject]@{Proof=$proof;ProofSha256=(Get-AuthWireWriteHash $proof);Evidence=$s.Evidence;Observation=$Observation}
 }finally{$p.Dispose();$lock.ReleaseMutex();$lock.Dispose()}
}
function New-AuthWireConsumedRollbackRetirementCompletion($Record,$State,[hashtable]$Binding,[long]$At){
 $v=New-AuthWireRollbackRetirementCompletion $Record $State $Binding $At;$v.format='AuthWireConsumedRollbackRetirementCompleteV1'
 $v.PSObject.Properties.Remove('original_refusal_preserved')
 $v|Add-Member NoteProperty original_unknown_result_preserved $true
 $v|Add-Member NoteProperty filesystem_intent_sha256 $State.Frozen.intent
 $v|Add-Member NoteProperty prior_observation_sha256 $State.Frozen.observation
 return $v
}
function Complete-AuthWireConsumedRollbackRetirement([string]$Root,[string]$JobId,[hashtable]$Binding,[Security.Cryptography.RSACng]$Key,[string]$BaseUrl,$Reviewed,$Acknowledgement,[securestring]$Session,[securestring]$Csrf,[string]$Acknowledge){
 Assert-AuthWireCandidateFields $Reviewed @('Proof','ProofSha256','Evidence','Observation')
 if($Acknowledge -cne 'retire_consumed_rollback_preserve_unknown_outcome' -or (Get-AuthWireWriteHash $Reviewed.Proof) -cne $Reviewed.ProofSha256){throw 'ROLLBACK_CONSUMED_EXPLICIT_REVIEW_REQUIRED'}
 Assert-AuthWireRollbackReaderIdentity $Binding
 $lock=Enter-AuthWireWriteCycleLock $Binding;$decision=$null;$p=[AuthWire.Staging.TreeLeaseV1]::new();$store=$null;$taken=$false
 try{
  $decision=Enter-AuthWireWritePreauthorizationLock $JobId;$store=[Threading.Mutex]::new($false,'Global\AuthWireWritePreclaimStoreV1')
  try{$taken=$store.WaitOne(0)}catch [Threading.AbandonedMutexException]{$taken=$true;throw 'ROLLBACK_CONSUMED_STORE_ABANDONED'}
  if(-not $taken){throw 'ROLLBACK_CONSUMED_STORE_BUSY'}
  $job=Join-Path $Root $JobId
  foreach($n in @('rollback-consumed-retirement-review.json','rollback-consumed-retirement-complete.json')){if(Test-Path -LiteralPath (Join-Path $job $n)){throw 'ROLLBACK_CONSUMED_ALREADY_STARTED_READ_EXISTING'}}
  $s=Get-AuthWireConsumedRollbackRetirementState $Root $JobId $Binding $Key $p $Reviewed.Observation
  if((Get-AuthWireWriteHash $Reviewed.Evidence) -cne (Get-AuthWireWriteHash $s.Evidence)){throw 'ROLLBACK_CONSUMED_ACK_REJECTED'}
  Assert-AuthWireConsumedRollbackRetirementReview $Reviewed.Proof $s $Binding $Key ([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())
  $receipt=Confirm-AuthWireRollbackRetirementAcknowledgement $Binding $BaseUrl $Acknowledgement $Session $Csrf
  Assert-AuthWireRollbackRetirementAcknowledgement $Acknowledgement $receipt $s
  Assert-AuthWireConsumedRollbackCurrentState $Root $JobId $s.State $s.Original $Reviewed.Observation $p
  $now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds();Assert-AuthWireConsumedRollbackRetirementReview $Reviewed.Proof $s $Binding $Key $now
  $record=[pscustomobject]@{format='AuthWireConsumedRollbackRetirementRecordV1';review=$Reviewed.Proof;observation=$Reviewed.Observation;acknowledgement_request=$Acknowledgement;acknowledgement_receipt=$receipt;acknowledge=$Acknowledge}
  Write-AuthWireStagingJournal (Join-Path $job 'rollback-consumed-retirement-review.json') $record
  $closed=New-AuthWireRollbackRetirementProof (New-AuthWireConsumedRollbackRetirementCompletion $record $s $Binding $now) $Key 'AUTHWIRE-CONSUMED-ROLLBACK-RETIRE-COMPLETE-V1'
  Write-AuthWireStagingJournal (Join-Path $job 'rollback-consumed-retirement-complete.json') $closed
  return $closed
 }finally{if($taken){$store.ReleaseMutex()};if($store){$store.Dispose()};$p.Dispose();if($decision){$decision.ReleaseMutex();$decision.Dispose()};$lock.ReleaseMutex();$lock.Dispose()}
}
function Test-AuthWireConsumedRollbackRetired([string]$Root,[string]$Life,$State,[hashtable]$Binding,[Security.Cryptography.RSACng]$Key){
 if($State.Offer.operation -cne 'combined.filesystem.rollback.v1'){return $false}
 $job=Join-Path $Root $State.Offer.job_id;$file=Join-Path $job 'rollback-consumed-retirement-complete.json'
 if(-not (Test-Path -LiteralPath $file)){return $false}
 $p=[AuthWire.Staging.TreeLeaseV1]::new()
 try{
  $p.PinFile($file);$p.PinFile((Join-Path $job 'rollback-consumed-retirement-review.json'))
  $record=Read-AuthWireStagingJournal (Join-Path $job 'rollback-consumed-retirement-review.json');$closed=Read-AuthWireStagingJournal $file
  Assert-AuthWireCandidateFields $record @('format','review','observation','acknowledgement_request','acknowledgement_receipt','acknowledge')
  if($record.format -cne 'AuthWireConsumedRollbackRetirementRecordV1' -or $record.acknowledge -cne 'retire_consumed_rollback_preserve_unknown_outcome'){throw 'ROLLBACK_CONSUMED_COMPLETION_REJECTED'}
  Assert-AuthWireRollbackRetirementProof $closed $Key 'AUTHWIRE-CONSUMED-ROLLBACK-RETIRE-COMPLETE-V1'
  if(-not (Test-AuthWireWriteInteger $closed.Body.closed_at) -or $closed.Body.closed_at -gt [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()){throw 'ROLLBACK_CONSUMED_COMPLETION_REJECTED'}
  $s=Get-AuthWireConsumedRollbackRetirementState $Root $State.Offer.job_id $Binding $Key $p $record.observation $State $Life $true
  Assert-AuthWireConsumedRollbackRetirementReview $record.review $s $Binding $Key $closed.Body.closed_at
  Assert-AuthWireRollbackRetirementAcknowledgement $record.acknowledgement_request $record.acknowledgement_receipt $s
  $expected=New-AuthWireConsumedRollbackRetirementCompletion $record $s $Binding $closed.Body.closed_at
  if((Get-AuthWireWriteHash $expected) -cne (Get-AuthWireWriteHash $closed.Body)){throw 'ROLLBACK_CONSUMED_COMPLETION_REJECTED'}
  return $true
 }finally{$p.Dispose()}
}


# Consumed grant without a filesystem intent. Distinct proof domains/files;
# original OUTCOME_UNKNOWN, authority, reservation and GPO lock stay immutable.
function Get-AuthWirePreIntentRollbackState([string]$Root,[string]$JobId,[hashtable]$Binding,[Security.Cryptography.RSACng]$Key,$Pins,$ExistingState=$null,[string]$ExistingLife='',[bool]$Historical=$false){
 Assert-AuthWireStagingWriteJournalLocation $Root $Binding;Assert-AuthWireCandidateGuid $JobId
 if($null -eq $ExistingState){$h=Read-AuthWireLifecycleHistory $Root $Binding $Key;if($h.ActiveStates.Count -lt 1){throw 'ROLLBACK_PREINTENT_NOT_LATEST'};$state=$h.ActiveStates[-1];$life=$h.Life}else{$state=$ExistingState;$life=$ExistingLife}
 if($state.Phase -cne 'reply_saved' -or $state.Offer.job_id -cne $JobId -or $state.Offer.operation -cne 'combined.filesystem.rollback.v1'){throw 'ROLLBACK_PREINTENT_NOT_ROLLBACK'}
 $job=Join-Path $Root $JobId;$slot=Join-Path $life $state.Slot;$Pins.PinAncestors($Root);$Pins.PinAncestors($job);$Pins.PinAncestors($slot)
 $required=@('rollback-offer.json','rollback-preflight.json','rollback-claim-started.json','rollback-claim-proof.json','rollback-claim-sent.json','rollback-authorization.json','rollback-grant-consumed.json','rollback-result-outbox.json','rollback-result-accepted.json')
 foreach($n in $required){$Pins.PinFile((Join-Path $job $n))}
 $allowed=$required+@('rollback-reservation.json','rollback-preintent-retirement-review.json','rollback-preintent-retirement-complete.json')
 foreach($i in 1..3){foreach($kind in @('attempt','proof')){$allowed+=,('rollback-result-'+$kind+'-'+$i+'.json')}}
 $rows=@();foreach($f in @(Get-ChildItem -LiteralPath $job -Force|Sort-Object Name -CaseSensitive)){
  if($f.PSIsContainer -or $f.Name -cnotin $allowed){throw 'ROLLBACK_PREINTENT_UNKNOWN_OR_EXECUTION_HISTORY'}
  $Pins.PinFile($f.FullName)
  if($f.Name -cin @('rollback-preintent-retirement-review.json','rollback-preintent-retirement-complete.json')){continue}
  $rows+=,[pscustomobject]@{name=$f.Name;sha256=(Get-AuthWireJobHash (Read-AuthWireCandidateBytes $f.FullName 65536))}
 }
 $slotRows=@();foreach($f in @(Get-ChildItem -LiteralPath $slot -Force|Sort-Object Name -CaseSensitive)){
  if($f.PSIsContainer){throw 'ROLLBACK_PREINTENT_UNKNOWN_HISTORY'};$Pins.PinFile($f.FullName)
  $slotRows+=,[pscustomobject]@{name=$f.Name;sha256=(Get-AuthWireJobHash (Read-AuthWireCandidateBytes $f.FullName 65536))}
 }
 $done=Read-AuthWireLifecycleCompletion $Root $life $state $Binding $Key
 $failure=Read-AuthWireStagingJournal (Join-Path $slot 'dispatch-failed.json')
 if($done.outcome -cne 'requires_review' -or $failure.phase -cne 'execute'){throw 'ROLLBACK_PREINTENT_RESULT_REJECTED'}
 $a=Read-AuthWireRollbackAuthorizationEvidence $Root $JobId $Binding $state.Started.release_id $Key;$origin=$a.Origin
 $c=Read-AuthWireStagingJournal (Join-Path $job 'rollback-grant-consumed.json')
 Assert-AuthWireCandidateFields $c @('format','binding_scope','release_id','job_id','stage_job_id','stage_operation_id','authorization_sha256','origin_chain_sha256','consumed_at','expires_at')
 if($c.format -cne 'AuthWireRollbackGrantConsumedV1' -or $c.binding_scope -cne (Get-AuthWireJobScope $Binding) -or $c.release_id -cne $state.Started.release_id -or $c.job_id -cne $JobId -or
    $c.stage_job_id -cne $origin.StageJobId -or $c.stage_operation_id -cne $origin.FilesystemOperationId -or $c.authorization_sha256 -cne $a.AuthorizationSha256 -or $c.origin_chain_sha256 -cne $origin.ChainSha256 -or
    -not (Test-AuthWireWriteInteger $c.consumed_at) -or -not (Test-AuthWireWriteInteger $c.expires_at) -or $c.consumed_at -lt $a.Receipt.received_at -or $c.consumed_at -ge $c.expires_at -or $c.expires_at -ne $a.Receipt.grant.expires_at -or
    $failure.checked_at -lt $c.consumed_at -or $failure.checked_at -gt $done.completed_at){throw 'ROLLBACK_PREINTENT_CONSUMPTION_REJECTED'}
 $Pins.PinFile((Get-AuthWireRollbackReservationPath $Root $origin.StageJobId $JobId));$Pins.PinFile((Get-AuthWireRollbackReservationPath $Root $origin.StageJobId))
 $gpoLock=Join-Path $Root ('gpo-'+$state.Offer.target.scope_target.gpo_id+'.json');$Pins.PinFile($gpoLock)
 foreach($dir in @((Join-Path $Root $origin.StageJobId),(Join-Path $Root $origin.FilesystemOperationId))){$Pins.PinAncestors($dir);foreach($f in Get-ChildItem -LiteralPath $dir -File){$Pins.PinFile($f.FullName)}}
 $box=Read-AuthWireRollbackResultOutbox $Root $JobId $Binding $state.Started.release_id $Key
 if($box.body.outcome -cne 'requires_review' -or $box.body.reason -cne 'OUTCOME_UNKNOWN' -or $box.body.filesystem_effects -cne 'unconfirmed' -or $box.body.authorization_id -cne $a.Receipt.grant.authorization_id){throw 'ROLLBACK_PREINTENT_RESULT_REJECTED'}
 $ack=Get-AuthWireLifecycleOutcomeEvidence $Root $state $Binding $Key $life
 if($ack.Outcome -cne 'requires_review' -or $ack.BodySha256 -cne $box.body_sha256){throw 'ROLLBACK_PREINTENT_ACK_REJECTED'}
 $frozen=[pscustomobject]@{offer=(Get-AuthWireWriteHash $state.Offer);completion=(Get-AuthWireWriteHash $done);ack=$ack.AckSha256;result=(Get-AuthWireWriteHash $box);reservation=(Get-AuthWireWriteHash $a.Reservation);root_reservation=(Get-AuthWireWriteHash (Read-AuthWireStagingJournal (Get-AuthWireRollbackReservationPath $Root $origin.StageJobId)));origin=$origin.ChainSha256;gpo_lock=(Get-AuthWireWriteHash (Read-AuthWireStagingJournal $gpoLock));consumption=(Get-AuthWireWriteHash $c);job_records=(Get-AuthWireWriteHash $rows);slot_records=(Get-AuthWireWriteHash $slotRows)}
 $evidence=[pscustomobject]@{job_id=$JobId;scope_sha256=(Get-AuthWireJobScope $Binding);intent_sha256=$state.Offer.intent_sha256;result_body_sha256=$box.body_sha256;accepted_ack=$true}
 $s=[pscustomobject]@{State=$state;Life=$life;Origin=$origin;Authorization=$a;Consumed=$c;Evidence=$evidence;Frozen=$frozen;OriginalSha256=(Get-AuthWireWriteHash $frozen)}
 if(-not $Historical){$null=Get-AuthWirePreIntentRollbackCurrentObservation $Root $s $Binding $Pins}
 return $s
}
function Get-AuthWirePreIntentRollbackCurrentObservation([string]$Root,$State,[hashtable]$Binding,$Pins){
 $s=$State;$o=$s.Origin;$job=Join-Path $Root $s.State.Offer.job_id
 if([DateTimeOffset]::UtcNow.ToUnixTimeSeconds() -lt [Math]::Max($s.State.Offer.expires_at,$s.Consumed.expires_at)){throw 'ROLLBACK_PREINTENT_AUTHORITY_NOT_EXPIRED'}
 Assert-AuthWireNoActiveRollback $Root $s.State.Offer.job_id;Assert-AuthWireNoActiveStage $Root $o.StageJobId
 foreach($n in @('rollback-consumption-preflight.json','rollback-filesystem-intent.json','rollback-launch.json','rollback-child.json','rollback-entered.json','rollback-execution-preflight.json','rollback-execution-complete.json','rollback-execution-observed.json','rollback-execution-requires-review.json')){if(Test-Path -LiteralPath (Join-Path $job $n)){throw 'ROLLBACK_PREINTENT_EXECUTION_HISTORY_PRESENT'}}
 foreach($n in @('rollback-started.json','rolled-back.json')){if(Test-Path -LiteralPath (Join-Path (Join-Path $Root $o.FilesystemOperationId) $n)){throw 'ROLLBACK_PREINTENT_ENGINE_ENTERED'}}
 $tree=$null
 try{
  Add-AuthWireStagingGpoPins $Pins $o.Intent.gpo_root $o.Intent.gpo_root;Add-AuthWireStagingGpoPins $Pins (Join-Path $o.Intent.gpo_root 'Machine') $o.Intent.gpo_root
  $destination=Join-Path $o.Intent.gpo_root $o.Intent.relative_destination.Replace('/','\');$tree=[AuthWire.Staging.TreeLeaseV1]::Tree($destination,$false)
  foreach($r in $tree.Rows){if($r.Kind -ceq 'directory'){Add-AuthWireStagingGpoPins $Pins $(if($r.Path -ceq ''){$destination}else{Join-Path $destination $r.Path.Replace('/','\')}) $o.Intent.gpo_root}else{$Pins.PinFile((Join-Path $destination $r.Path.Replace('/','\')))}}
  $rows=Get-AuthWireStagingFilesystemRows $tree;$hash=Get-AuthWireStagingFilesystemDigest $rows
  $all=Get-AuthWireSysvolInventory $o.Intent.gpo_root;$rel=$o.Intent.relative_destination
  $outside=@($all.Entries|Where-Object {$_.Path -cne $rel -and -not $_.Path.StartsWith($rel+'/',[StringComparison]::Ordinal)})
  if($hash -cne $o.Complete.tree_sha256 -or (Get-AuthWireScopeDataHash $outside) -cne $o.Intent.baseline_sha256){throw 'ROLLBACK_PREINTENT_TREE_OR_OUTSIDE_DRIFT'}
  return [pscustomobject]@{format='AuthWireRollbackPreIntentObservationV1';job_id=$s.State.Offer.job_id;stage_job_id=$o.StageJobId;stage_operation_id=$o.FilesystemOperationId;binding_scope=(Get-AuthWireJobScope $Binding);authority_release=$s.State.Started.release_id;authorization_id=$s.Authorization.Receipt.grant.authorization_id;authorization_sha256=$s.Authorization.AuthorizationSha256;grant_consumption_sha256=$s.Frozen.consumption;original_records_sha256=$s.OriginalSha256;consumed_at=$s.Consumed.consumed_at;expires_at=$s.Consumed.expires_at;tree_sha256=$hash;outside_baseline_sha256=$o.Intent.baseline_sha256;tree_rows=$rows.Count;authority_expired=$true;filesystem_intent_absent=$true;execution_markers_absent=$true;staged_tree_unchanged=$true;outside_unchanged=$true;read_only=$true;can_delete=$false;authority_renewed=$false;observed_at=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()}
 }finally{if($tree){$tree.Dispose()}}
}
function Assert-AuthWirePreIntentRollbackObservation($Proof,$State,[hashtable]$Binding,[Security.Cryptography.RSACng]$Key){
 Assert-AuthWireRollbackRetirementProof $Proof $Key 'AUTHWIRE-PREINTENT-ROLLBACK-OBSERVATION-V1'
 $v=$Proof.Body;$s=$State;$o=$s.Origin
 Assert-AuthWireCandidateFields $v @('format','job_id','stage_job_id','stage_operation_id','binding_scope','authority_release','authorization_id','authorization_sha256','grant_consumption_sha256','original_records_sha256','consumed_at','expires_at','tree_sha256','outside_baseline_sha256','tree_rows','authority_expired','filesystem_intent_absent','execution_markers_absent','staged_tree_unchanged','outside_unchanged','read_only','can_delete','authority_renewed','observed_at')
 if($v.format -cne 'AuthWireRollbackPreIntentObservationV1' -or $v.job_id -cne $s.State.Offer.job_id -or $v.stage_job_id -cne $o.StageJobId -or $v.stage_operation_id -cne $o.FilesystemOperationId -or $v.binding_scope -cne (Get-AuthWireJobScope $Binding) -or
    $v.authority_release -cne $s.State.Started.release_id -or $v.authorization_id -cne $s.Authorization.Receipt.grant.authorization_id -or $v.authorization_sha256 -cne $s.Authorization.AuthorizationSha256 -or $v.grant_consumption_sha256 -cne $s.Frozen.consumption -or $v.original_records_sha256 -cne $s.OriginalSha256 -or
    $v.consumed_at -ne $s.Consumed.consumed_at -or $v.expires_at -ne $s.Consumed.expires_at -or $v.tree_sha256 -cne $o.Complete.tree_sha256 -or $v.outside_baseline_sha256 -cne $o.Intent.baseline_sha256 -or -not (Test-AuthWireWriteInteger $v.tree_rows) -or
    -not (Test-AuthWireWriteInteger $v.observed_at) -or $v.observed_at -lt [Math]::Max($s.Consumed.expires_at,$s.State.Offer.expires_at) -or $v.observed_at -gt [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()){throw 'ROLLBACK_PREINTENT_OBSERVATION_REJECTED'}
 foreach($n in @('authority_expired','filesystem_intent_absent','execution_markers_absent','staged_tree_unchanged','outside_unchanged','read_only')){if($v.$n -isnot [bool] -or -not $v.$n){throw 'ROLLBACK_PREINTENT_OBSERVATION_REJECTED'}}
 foreach($n in @('can_delete','authority_renewed')){if($v.$n -isnot [bool] -or $v.$n){throw 'ROLLBACK_PREINTENT_OBSERVATION_REJECTED'}}
}
function New-AuthWirePreIntentRollbackReviewBody($State,$Observation,[hashtable]$Binding,[long]$At){
 $v=New-AuthWireRollbackRetirementBody $State $Binding $At;$v.format='AuthWirePreIntentRollbackRetirementReviewV1'
 $v|Add-Member NoteProperty grant_consumption_sha256 $State.Frozen.consumption;$v|Add-Member NoteProperty observation_sha256 (Get-AuthWireWriteHash $Observation)
 $v|Add-Member NoteProperty original_outcome 'requires_review';$v|Add-Member NoteProperty filesystem_effects 'unconfirmed';$v|Add-Member NoteProperty filesystem_intent_absent $true
 return $v
}
function Assert-AuthWirePreIntentRollbackReview($Reviewed,$State,[hashtable]$Binding,[Security.Cryptography.RSACng]$Key,[long]$At){
 Assert-AuthWireCandidateFields $Reviewed @('Proof','ProofSha256','Evidence','Observation')
 if((Get-AuthWireWriteHash $Reviewed.Proof) -cne $Reviewed.ProofSha256 -or (Get-AuthWireWriteHash $Reviewed.Evidence) -cne (Get-AuthWireWriteHash $State.Evidence)){throw 'ROLLBACK_PREINTENT_REVIEW_REJECTED'}
 Assert-AuthWirePreIntentRollbackObservation $Reviewed.Observation $State $Binding $Key
 Assert-AuthWireRollbackRetirementProof $Reviewed.Proof $Key 'AUTHWIRE-PREINTENT-ROLLBACK-RETIRE-REVIEW-V1'
 $b=$Reviewed.Proof.Body;$expected=New-AuthWirePreIntentRollbackReviewBody $State $Reviewed.Observation $Binding $b.observed_at
 if((Get-AuthWireWriteHash $b) -cne (Get-AuthWireWriteHash $expected) -or $At -lt $b.observed_at -or $At -ge $b.expires_at -or $b.observed_at -lt $Reviewed.Observation.Body.observed_at){throw 'ROLLBACK_PREINTENT_REVIEW_EXPIRED_OR_CHANGED'}
}
function Get-AuthWirePreIntentRollbackRetirementReview([string]$Root,[string]$JobId,[hashtable]$Binding,[Security.Cryptography.RSACng]$Key){
 Assert-AuthWireRollbackReaderIdentity $Binding;$lock=Enter-AuthWireWriteCycleLock $Binding;$p=[AuthWire.Staging.TreeLeaseV1]::new()
 try{
  $s=Get-AuthWirePreIntentRollbackState $Root $JobId $Binding $Key $p
  $ob=New-AuthWireRollbackRetirementProof (Get-AuthWirePreIntentRollbackCurrentObservation $Root $s $Binding $p) $Key 'AUTHWIRE-PREINTENT-ROLLBACK-OBSERVATION-V1'
  $proof=New-AuthWireRollbackRetirementProof (New-AuthWirePreIntentRollbackReviewBody $s $ob $Binding ([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())) $Key 'AUTHWIRE-PREINTENT-ROLLBACK-RETIRE-REVIEW-V1'
  return [pscustomobject]@{Proof=$proof;ProofSha256=(Get-AuthWireWriteHash $proof);Evidence=$s.Evidence;Observation=$ob}
 }finally{$p.Dispose();$lock.ReleaseMutex();$lock.Dispose()}
}
function New-AuthWirePreIntentRollbackCompletion($Record,$State,[hashtable]$Binding,[long]$At){
 $v=New-AuthWireRollbackRetirementCompletion $Record $State $Binding $At;$v.format='AuthWirePreIntentRollbackRetirementCompleteV1';$v.PSObject.Properties.Remove('original_refusal_preserved')
 $v|Add-Member NoteProperty original_unknown_result_preserved $true;$v|Add-Member NoteProperty grant_consumption_sha256 $State.Frozen.consumption;$v|Add-Member NoteProperty observation_sha256 (Get-AuthWireWriteHash $Record.observation);$v|Add-Member NoteProperty filesystem_intent_absent $true
 return $v
}
function Complete-AuthWirePreIntentRollbackRetirement([string]$Root,[string]$JobId,[hashtable]$Binding,[Security.Cryptography.RSACng]$Key,[string]$BaseUrl,$Reviewed,$Acknowledgement,[securestring]$Session,[securestring]$Csrf,[string]$Acknowledge){
 if($Acknowledge -cne 'retire_consumed_rollback_before_intent_preserve_unknown_outcome'){throw 'ROLLBACK_PREINTENT_EXPLICIT_REVIEW_REQUIRED'}
 Assert-AuthWireRollbackReaderIdentity $Binding;$lock=Enter-AuthWireWriteCycleLock $Binding;$p=[AuthWire.Staging.TreeLeaseV1]::new();$decision=$null;$store=$null;$taken=$false
 try{
  $decision=Enter-AuthWireWritePreauthorizationLock $JobId;$store=[Threading.Mutex]::new($false,'Global\AuthWireWritePreclaimStoreV1');try{$taken=$store.WaitOne(0)}catch [Threading.AbandonedMutexException]{$taken=$true;throw 'ROLLBACK_PREINTENT_STORE_ABANDONED'}
  if(-not $taken){throw 'ROLLBACK_PREINTENT_STORE_BUSY'}
  $job=Join-Path $Root $JobId;foreach($n in @('rollback-preintent-retirement-review.json','rollback-preintent-retirement-complete.json')){if(Test-Path (Join-Path $job $n)){throw 'ROLLBACK_PREINTENT_ALREADY_STARTED_READ_EXISTING'}}
  $s=Get-AuthWirePreIntentRollbackState $Root $JobId $Binding $Key $p
  Assert-AuthWirePreIntentRollbackReview $Reviewed $s $Binding $Key ([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())
  $receipt=Confirm-AuthWireRollbackRetirementAcknowledgement $Binding $BaseUrl $Acknowledgement $Session $Csrf;Assert-AuthWireRollbackRetirementAcknowledgement $Acknowledgement $receipt $s
  # Re-read the complete immutable chain and current tree AFTER the HTTP ACK.
  $again=Get-AuthWirePreIntentRollbackState $Root $JobId $Binding $Key $p
  if($again.OriginalSha256 -cne $s.OriginalSha256){throw 'ROLLBACK_PREINTENT_ORIGINAL_CHANGED'}
  $now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds();Assert-AuthWirePreIntentRollbackReview $Reviewed $again $Binding $Key $now
  $record=[pscustomobject]@{format='AuthWirePreIntentRollbackRetirementRecordV1';review=$Reviewed.Proof;observation=$Reviewed.Observation;acknowledgement_request=$Acknowledgement;acknowledgement_receipt=$receipt;acknowledge=$Acknowledge}
  Write-AuthWireStagingJournal (Join-Path $job 'rollback-preintent-retirement-review.json') $record
  $closed=New-AuthWireRollbackRetirementProof (New-AuthWirePreIntentRollbackCompletion $record $again $Binding $now) $Key 'AUTHWIRE-PREINTENT-ROLLBACK-RETIRE-COMPLETE-V1'
  Write-AuthWireStagingJournal (Join-Path $job 'rollback-preintent-retirement-complete.json') $closed;return $closed
 }finally{if($taken){$store.ReleaseMutex()};if($store){$store.Dispose()};if($decision){$decision.ReleaseMutex();$decision.Dispose()};$p.Dispose();$lock.ReleaseMutex();$lock.Dispose()}
}
function Test-AuthWirePreIntentRollbackRetired([string]$Root,[string]$Life,$State,[hashtable]$Binding,[Security.Cryptography.RSACng]$Key){
 if($State.Offer.operation -cne 'combined.filesystem.rollback.v1'){return $false}
 $job=Join-Path $Root $State.Offer.job_id;$file=Join-Path $job 'rollback-preintent-retirement-complete.json';if(-not(Test-Path $file)){return $false}
 $p=[AuthWire.Staging.TreeLeaseV1]::new()
 try{
  $p.PinFile($file);$p.PinFile((Join-Path $job 'rollback-preintent-retirement-review.json'));$record=Read-AuthWireStagingJournal (Join-Path $job 'rollback-preintent-retirement-review.json');$closed=Read-AuthWireStagingJournal $file
  Assert-AuthWireCandidateFields $record @('format','review','observation','acknowledgement_request','acknowledgement_receipt','acknowledge')
  if($record.format -cne 'AuthWirePreIntentRollbackRetirementRecordV1' -or $record.acknowledge -cne 'retire_consumed_rollback_before_intent_preserve_unknown_outcome'){throw 'ROLLBACK_PREINTENT_COMPLETION_REJECTED'}
  Assert-AuthWireRollbackRetirementProof $closed $Key 'AUTHWIRE-PREINTENT-ROLLBACK-RETIRE-COMPLETE-V1'
  if(-not(Test-AuthWireWriteInteger $closed.Body.closed_at) -or $closed.Body.closed_at -gt [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()){throw 'ROLLBACK_PREINTENT_COMPLETION_REJECTED'}
  $s=Get-AuthWirePreIntentRollbackState $Root $State.Offer.job_id $Binding $Key $p $State $Life $true
  $reviewed=[pscustomobject]@{Proof=$record.review;ProofSha256=(Get-AuthWireWriteHash $record.review);Evidence=$s.Evidence;Observation=$record.observation}
  Assert-AuthWirePreIntentRollbackReview $reviewed $s $Binding $Key $closed.Body.closed_at;Assert-AuthWireRollbackRetirementAcknowledgement $record.acknowledgement_request $record.acknowledgement_receipt $s
  if((Get-AuthWireWriteHash (New-AuthWirePreIntentRollbackCompletion $record $s $Binding $closed.Body.closed_at)) -cne (Get-AuthWireWriteHash $closed.Body)){throw 'ROLLBACK_PREINTENT_COMPLETION_REJECTED'}
  return $true
 }finally{$p.Dispose()}
}
