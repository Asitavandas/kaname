# Source-only separate rollback CLAIM/receipt and one-use local intent.
# Not loaded by the worker/package; no delete, unlock, RESULT or peer route here.
Set-StrictMode -Version 2

function Get-AuthWireRollbackReservationPath([string]$Root,[string]$StageJobId){
 Assert-AuthWireCandidateGuid $StageJobId
 return (Join-Path $Root ('rollback-stage-'+$StageJobId+'.json'))
}
function Assert-AuthWireRollbackReservation($Value,$Offer,[hashtable]$Binding,[string]$Release){
 Assert-AuthWireCandidateFields $Value @('format','binding_scope','release_id','job_id','stage_job_id','stage_release_id','stage_operation_id','intent_sha256','origin_chain_sha256')
 Assert-AuthWireStageStrings $Value @('format','binding_scope','release_id','job_id','stage_job_id','stage_release_id','stage_operation_id','intent_sha256','origin_chain_sha256')
 foreach($n in @('stage_job_id','stage_release_id','stage_operation_id')){Assert-AuthWireCandidateGuid $Value.$n}
 if($Value.format -cne 'AuthWireRollbackReservationV1' -or $Value.binding_scope -cne (Get-AuthWireJobScope $Binding) -or $Value.release_id -cne $Release -or
    $Value.job_id -cne $Offer.job_id -or $Value.stage_job_id -cne $Offer.target.stage_receipt.stage_job_id -or $Value.stage_job_id -ceq $Offer.job_id -or
    $Value.intent_sha256 -cne $Offer.intent_sha256 -or -not (Test-AuthWireWriteHash $Value.origin_chain_sha256)){throw 'ROLLBACK_RESERVATION_REJECTED'}
}
function Read-AuthWireRollbackOfferAt([string]$Root,[string]$JobId,[hashtable]$Binding,[string]$Release,[long]$ObservedAt){
 Assert-AuthWireStagingWriteJournalLocation $Root $Binding;Assert-AuthWireCandidateGuid $JobId;Initialize-AuthWireStagingFilesystemTypes
 $p=[AuthWire.Staging.TreeLeaseV1]::new()
 try{
  $p.PinAncestors($Root);$job=Join-Path $Root $JobId;$p.PinAncestors($job)
  $file=Join-Path $job 'rollback-offer.json';$p.PinFile($file);$v=Read-AuthWireStagingJournal $file
  Assert-AuthWireCandidateFields $v @('format','binding_scope','release_id','reservation_sha256','offer')
  Assert-AuthWireStageStrings $v @('format','binding_scope','release_id','reservation_sha256')
  if($v.format -cne 'AuthWireRollbackOfferV1' -or $v.binding_scope -cne (Get-AuthWireJobScope $Binding) -or $v.release_id -cne $Release -or $v.offer.job_id -cne $JobId -or $v.offer.operation -cne 'combined.filesystem.rollback.v1'){throw 'ROLLBACK_OFFER_REJECTED'}
  Assert-AuthWireWriteOfferAt $v.offer $Binding $Release $v.offer.request_id $ObservedAt
  $file=Get-AuthWireRollbackReservationPath $Root $v.offer.target.stage_receipt.stage_job_id;$p.PinFile($file);$r=Read-AuthWireStagingJournal $file
  Assert-AuthWireRollbackReservation $r $v.offer $Binding $Release
  if($v.reservation_sha256 -cne (Get-AuthWireWriteHash $r)){throw 'ROLLBACK_RESERVATION_REJECTED'}
  $file=Join-Path $Root ('gpo-'+$v.offer.target.scope_target.gpo_id+'.json');$p.PinFile($file);$l=Read-AuthWireStagingJournal $file
  Assert-AuthWireCandidateFields $l @('format','job_id','intent_sha256')
  if($l.format -cne 'AuthWireWriteGpoLockV1' -or $l.job_id -cne $r.stage_job_id -or -not (Test-AuthWireWriteHash $l.intent_sha256)){throw 'ROLLBACK_ORIGINAL_LOCK_REQUIRED'}
  return [pscustomobject]@{Offer=$v.offer;Reservation=$r}
 }finally{$p.Dispose()}
}
function Read-AuthWireRollbackOffer([string]$Root,[string]$JobId,[hashtable]$Binding,[string]$Release){
 return (Read-AuthWireRollbackOfferAt $Root $JobId $Binding $Release ([DateTimeOffset]::UtcNow.ToUnixTimeSeconds()))
}
function New-AuthWireRollbackInputPins([string]$Root,[string]$JobId,$Saved,[string[]]$Names){
 $p=[AuthWire.Staging.TreeLeaseV1]::new()
 try{
  $p.PinAncestors($Root);$job=Join-Path $Root $JobId;$p.PinAncestors($job)
  foreach($n in @('rollback-offer.json')+$Names){$p.PinFile((Join-Path $job $n))}
  $p.PinFile((Get-AuthWireRollbackReservationPath $Root $Saved.Reservation.stage_job_id))
  $p.PinFile((Join-Path $Root ('gpo-'+$Saved.Offer.target.scope_target.gpo_id+'.json')))
  return $p
 }catch{$p.Dispose();throw}
}
function Save-AuthWireRollbackOffer($Offer,[hashtable]$Binding,[string]$Release,[Security.Cryptography.RSACng]$Key,[string]$RequestId){
 Assert-AuthWireWriteOffer $Offer $Binding $Release $RequestId
 $origin=Read-AuthWireRollbackOrigin $Offer $Binding $Release $Key
 $root=Get-AuthWireStagingWriteJournalRoot $Binding;Assert-AuthWireStagingWriteJournalLocation $root $Binding
 $p=[AuthWire.Staging.TreeLeaseV1]::new();$mutex=$null;$taken=$false
 try{
  $p.PinAncestors($root);$mutex=[Threading.Mutex]::new($false,'Global\AuthWireWritePreclaimStoreV1')
  try{$taken=$mutex.WaitOne(0)}catch [Threading.AbandonedMutexException]{$taken=$true;throw 'ROLLBACK_STORE_ABANDONED_REQUIRES_REVIEW'}
  if(-not $taken){throw 'ROLLBACK_STORE_BUSY'}
  $children=@(Get-ChildItem -LiteralPath $root -Force)
  if($children.Count -gt 62 -or @($children|Where-Object PSIsContainer).Count -ge 32){throw 'ROLLBACK_STORE_LIMIT'}
  $job=Join-Path $root $Offer.job_id;$file=Get-AuthWireRollbackReservationPath $root $origin.StageJobId
  if((Test-Path -LiteralPath $job) -or (Test-Path -LiteralPath $file)){throw 'ROLLBACK_PRIOR_RESERVATION_REQUIRES_REVIEW'}
  $again=Read-AuthWireRollbackOrigin $Offer $Binding $Release $Key
  if($again.ChainSha256 -cne $origin.ChainSha256){throw 'ROLLBACK_ORIGIN_CHANGED'}
  $r=[pscustomobject]@{format='AuthWireRollbackReservationV1';binding_scope=(Get-AuthWireJobScope $Binding);release_id=$Release;job_id=$Offer.job_id;stage_job_id=$origin.StageJobId;stage_release_id=$origin.StageReleaseId;stage_operation_id=$origin.FilesystemOperationId;intent_sha256=$Offer.intent_sha256;origin_chain_sha256=$origin.ChainSha256}
  # Original-stage reservation is flushed BEFORE the new job directory. A new
  # rollback job ID or an incomplete local write cannot bypass this reservation.
  Write-AuthWireStagingJournal $file $r
  [AuthWire.Staging.TreeLeaseV1]::CreateNewDirectory($job);$p.PinAncestors($job)
  Write-AuthWireStagingJournal (Join-Path $job 'rollback-offer.json') ([pscustomobject]@{format='AuthWireRollbackOfferV1';binding_scope=$r.binding_scope;release_id=$Release;reservation_sha256=(Get-AuthWireWriteHash $r);offer=$Offer})
  return [pscustomobject]@{JobId=$Offer.job_id;Phase='rollback_offer_saved';CanDelete=$false;CanApplyGpo=$false}
 }finally{if($taken){$mutex.ReleaseMutex()};if($mutex){$mutex.Dispose()};$p.Dispose()}
}
function Assert-AuthWireRollbackPreflightAt($Value,$Saved,[hashtable]$Binding,[string]$Release,[long]$ObservedAt){
 $v=$Value;$o=$Saved.Offer;$r=$Saved.Reservation
 Assert-AuthWireCandidateFields $v @('format','job_id','intent_sha256','target_sha256','binding_scope','release_id','stage_job_id','stage_release_id','filesystem_operation_id','origin_chain_sha256','complete_sha256','tree_sha256','directory_sha256','checked_at','expires_at','read_only','write_authorized','can_delete','can_apply_gpo','requires_separate_claim')
 Assert-AuthWireStageStrings $v @('format','job_id','intent_sha256','target_sha256','binding_scope','release_id','stage_job_id','stage_release_id','filesystem_operation_id','origin_chain_sha256','complete_sha256','tree_sha256','directory_sha256')
 if($v.format -cne 'AuthWireRollbackPreflightV1' -or $v.job_id -cne $o.job_id -or $v.intent_sha256 -cne $o.intent_sha256 -or $v.target_sha256 -cne (Get-AuthWireWriteHash $o.target) -or
    $v.binding_scope -cne (Get-AuthWireJobScope $Binding) -or $v.release_id -cne $Release -or $v.stage_job_id -cne $r.stage_job_id -or $v.stage_release_id -cne $r.stage_release_id -or
    $v.filesystem_operation_id -cne $r.stage_operation_id -or $v.origin_chain_sha256 -cne $r.origin_chain_sha256 -or $v.complete_sha256 -cne $o.target.stage_receipt.complete_journal_sha256 -or
    $v.tree_sha256 -cne $o.target.stage_receipt.staged_tree_sha256 -or -not (Test-AuthWireWriteHash $v.directory_sha256) -or
    -not (Test-AuthWireWriteInteger $v.checked_at) -or -not (Test-AuthWireWriteInteger $v.expires_at) -or $v.expires_at -ne [Math]::Min(($v.checked_at+5),[long]$o.expires_at)){throw 'ROLLBACK_PREFLIGHT_REJECTED'}
 if($v.checked_at -gt $ObservedAt -or $ObservedAt -ge $v.expires_at){throw 'ROLLBACK_PREFLIGHT_STALE'}
 foreach($n in @('read_only','requires_separate_claim')){if($v.$n -isnot [bool] -or -not $v.$n){throw 'ROLLBACK_PREFLIGHT_REJECTED'}}
 foreach($n in @('write_authorized','can_delete','can_apply_gpo')){if($v.$n -isnot [bool] -or $v.$n){throw 'ROLLBACK_PREFLIGHT_REJECTED'}}
}
function Read-AuthWireRollbackPreflightProcess([string]$Root,[string]$JobId,[hashtable]$Binding,[string]$Release,[long]$NotAfter=0){
 $saved=Read-AuthWireRollbackOffer $Root $JobId $Binding $Release
 Initialize-AuthWireScopeProcess
 if($Root.Length -gt 1800 -or $Root.Contains('"')){throw 'WRITE_JOURNAL_PATH_REJECTED'}
 $now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
 $budget=[int][Math]::Min(15000,($saved.Offer.expires_at-$now-5)*1000)
 if($NotAfter -ne 0){if(-not (Test-AuthWireWriteInteger $NotAfter)){throw 'ROLLBACK_DEADLINE_REJECTED'};$budget=[int][Math]::Min(8000,[Math]::Min($budget,($NotAfter-$now-2)*1000))}
 if($budget -lt 100){throw 'ROLLBACK_AUTHORIZATION_EXPIRED'}
 $file=Join-Path $PSScriptRoot 'Read-AuthWireRollbackPreflight.ps1'
 $exe=Join-Path ([Environment]::GetFolderPath('Windows')) 'System32\WindowsPowerShell\v1.0\powershell.exe'
 $arguments='-NoLogo -NoProfile -NonInteractive -ExecutionPolicy AllSigned -File "'+$file+'" -JournalRoot "'+$Root.TrimEnd('\')+'" -JobId '+$JobId
 $r=[AuthWire.Connector.ScopeProcessV1]::Run($exe,$arguments,$budget)
 if($r.TimedOut){throw 'ROLLBACK_PREFLIGHT_TIMEOUT'}
 if($r.Truncated -or $r.ExitCode -ne 0){throw 'ROLLBACK_PREFLIGHT_FAILED'}
 $v=ConvertFrom-AuthWireCandidateJson ([Text.UTF8Encoding]::new($false,$true).GetBytes($r.Output))
 Assert-AuthWireRollbackPreflightAt $v $saved $Binding $Release ([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())
 if($v.checked_at -lt $now){throw 'ROLLBACK_PREFLIGHT_REJECTED'}
 return $v
}
function Invoke-AuthWireRollbackPreflight([string]$Root,[string]$JobId,[hashtable]$Binding,[string]$Release){
 $v=Read-AuthWireRollbackPreflightProcess $Root $JobId $Binding $Release
 $saved=Read-AuthWireRollbackOffer $Root $JobId $Binding $Release
 $p=New-AuthWireRollbackInputPins $Root $JobId $saved @()
 try{Assert-AuthWireRollbackPreflightAt $v $saved $Binding $Release ([DateTimeOffset]::UtcNow.ToUnixTimeSeconds());Write-AuthWireStagingJournal (Join-Path (Join-Path $Root $JobId) 'rollback-preflight.json') $v}finally{$p.Dispose()}
}
function New-AuthWireRollbackClaim([string]$Root,[string]$JobId,[hashtable]$Binding,[string]$Release,[Security.Cryptography.RSACng]$Key){
 $saved=Read-AuthWireRollbackOffer $Root $JobId $Binding $Release;$offer=$saved.Offer
 $p=New-AuthWireRollbackInputPins $Root $JobId $saved @('rollback-preflight.json')
 try{
  $job=Join-Path $Root $JobId;$v=Read-AuthWireStagingJournal (Join-Path $job 'rollback-preflight.json')
  Assert-AuthWireRollbackPreflightAt $v $saved $Binding $Release ([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())
  Write-AuthWireStagingJournal (Join-Path $job 'rollback-claim-started.json') ([pscustomobject]@{format='AuthWireWriteClaimStartedV1';job_id=$JobId;intent_sha256=$offer.intent_sha256;checked_at=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()})
  $proof=New-AuthWireStagingWriteProof $Binding $Key CLAIM @{job_id=$JobId;lease_id=$offer.lease_id;intent_sha256=$offer.intent_sha256;target_sha256=(Get-AuthWireWriteHash $offer.target);release_id=$Release}
  Write-AuthWireStagingJournal (Join-Path $job 'rollback-claim-proof.json') ([pscustomobject]@{format='AuthWireWriteClaimProofV1';job_id=$JobId;proof=$proof})
  return $proof
 }finally{$p.Dispose()}
}
function Invoke-AuthWireRollbackClaimTransport([string]$Root,[string]$JobId,[hashtable]$Binding,[string]$Release,[Security.Cryptography.RSACng]$Key,[string]$BaseUrl){
 $saved=Read-AuthWireRollbackOffer $Root $JobId $Binding $Release;$offer=$saved.Offer
 Initialize-AuthWireWriteTransportTypes
 $p=New-AuthWireRollbackInputPins $Root $JobId $saved @('rollback-preflight.json','rollback-claim-started.json','rollback-claim-proof.json')
 try{
  $again=Read-AuthWireRollbackOffer $Root $JobId $Binding $Release
  if((Get-AuthWireWriteHash $again) -cne (Get-AuthWireWriteHash $saved)){throw 'ROLLBACK_RECORD_CHANGED'}
  $job=Join-Path $Root $JobId;$v=Read-AuthWireStagingJournal (Join-Path $job 'rollback-preflight.json')
  Assert-AuthWireRollbackPreflightAt $v $saved $Binding $Release ([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())
  $started=Read-AuthWireStagingJournal (Join-Path $job 'rollback-claim-started.json');$record=Read-AuthWireStagingJournal (Join-Path $job 'rollback-claim-proof.json')
  Assert-AuthWireCandidateFields $record @('format','job_id','proof')
  if($record.format -cne 'AuthWireWriteClaimProofV1' -or $record.job_id -cne $JobId){throw 'ROLLBACK_PROOF_REJECTED'}
  $request=Assert-AuthWireStoredWriteClaim $record.proof $started $offer $Binding $Release $Key
  if(Test-Path -LiteralPath (Join-Path $job 'rollback-authorization.json')){throw 'ROLLBACK_RECEIPT_EXISTS_REQUIRES_REVIEW'}
  $sentAt=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds();$hash=Get-AuthWireWriteHash $record.proof
  # CreateNew + Flush(true) BEFORE HTTP: uncertainty never causes CLAIM replay.
  Write-AuthWireStagingJournal (Join-Path $job 'rollback-claim-sent.json') ([pscustomobject]@{format='AuthWireWriteClaimSentV1';job_id=$JobId;request_id=$request;proof_sha256=$hash;sent_at=$sentAt})
  $reply=[AuthWire.Connector.WriteTransportV1]::Post($BaseUrl,$Binding.appliance_fqdn,$Binding.appliance_tls_sha256,'/api/connector/v1/staging-write/claim',(ConvertTo-AuthWireWriteJson $record.proof))
  $grant=ConvertFrom-AuthWireCandidateJson ([Text.UTF8Encoding]::new($false,$true).GetBytes($reply));Assert-AuthWireWriteGrant $grant $offer $request $sentAt
  Write-AuthWireStagingJournal (Join-Path $job 'rollback-authorization.json') ([pscustomobject]@{format='AuthWireRollbackAuthorizationReceiptV1';binding_scope=(Get-AuthWireJobScope $Binding);release_id=$Release;offer_sha256=(Get-AuthWireWriteHash $offer);preflight_sha256=(Get-AuthWireWriteHash $v);claim_proof_sha256=$hash;sent_at=$sentAt;received_at=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds();grant=$grant})
  return [pscustomobject]@{JobId=$JobId;Phase='rollback_authorization_recorded';GrantRecorded=$true;CanDelete=$false;CanApplyGpo=$false}
 }finally{$p.Dispose()}
}

function Read-AuthWireRollbackAuthorization([string]$Root,[string]$JobId,[hashtable]$Binding,[string]$Release,[Security.Cryptography.RSACng]$Key){
 $a=Read-AuthWireRollbackAuthorizationEvidence $Root $JobId $Binding $Release $Key
 if([DateTimeOffset]::UtcNow.ToUnixTimeSeconds() -ge $a.Receipt.grant.expires_at){throw 'WRITE_AUTHORIZATION_EXPIRED'}
 return $a
}
function Read-AuthWireRollbackAuthorizationEvidence([string]$Root,[string]$JobId,[hashtable]$Binding,[string]$Release,[Security.Cryptography.RSACng]$Key){
 Assert-AuthWireStagingWriteJournalLocation $Root $Binding
 Assert-AuthWireCandidateGuid $JobId;Initialize-AuthWireStagingFilesystemTypes
 $timePin=[AuthWire.Staging.TreeLeaseV1]::new()
 try{
 $timePin.PinAncestors($Root);$timePin.PinAncestors((Join-Path $Root $JobId))
 $timeFile=Join-Path (Join-Path $Root $JobId) 'rollback-claim-sent.json';$timePin.PinFile($timeFile)
 $timeRecord=Read-AuthWireStagingJournal $timeFile
 Assert-AuthWireCandidateFields $timeRecord @('format','job_id','request_id','proof_sha256','sent_at')
 if(-not (Test-AuthWireWriteInteger $timeRecord.sent_at)){throw 'WRITE_AUTHORIZATION_REJECTED'}
 $saved=Read-AuthWireRollbackOfferAt $Root $JobId $Binding $Release $timeRecord.sent_at;$offer=$saved.Offer
 $pin=[AuthWire.Staging.TreeLeaseV1]::new()
 try{
  $pin.PinAncestors($Root);$job=Join-Path $Root $JobId;$pin.PinAncestors($job)
  foreach($n in @('rollback-offer.json','rollback-preflight.json','rollback-claim-started.json','rollback-claim-proof.json','rollback-claim-sent.json','rollback-authorization.json')){$pin.PinFile((Join-Path $job $n))}
  $pin.PinFile((Join-Path $Root ('gpo-'+$offer.target.scope_target.gpo_id+'.json')))
  $pin.PinFile((Get-AuthWireRollbackReservationPath $Root $offer.target.stage_receipt.stage_job_id))
  $again=Read-AuthWireRollbackOfferAt $Root $JobId $Binding $Release $timeRecord.sent_at
  if((Get-AuthWireWriteHash $again) -cne (Get-AuthWireWriteHash $saved)){throw 'WRITE_LOCAL_RECORD_CHANGED'}
  $preflight=Read-AuthWireStagingJournal (Join-Path $job 'rollback-preflight.json')
  $started=Read-AuthWireStagingJournal (Join-Path $job 'rollback-claim-started.json')
  $proofRecord=Read-AuthWireStagingJournal (Join-Path $job 'rollback-claim-proof.json')
  Assert-AuthWireCandidateFields $proofRecord @('format','job_id','proof')
  if($proofRecord.format -isnot [string] -or $proofRecord.format -cne 'AuthWireWriteClaimProofV1' -or $proofRecord.job_id -isnot [string] -or $proofRecord.job_id -cne $JobId){throw 'WRITE_AUTHORIZATION_REJECTED'}
  $sent=Read-AuthWireStagingJournal (Join-Path $job 'rollback-claim-sent.json')
  Assert-AuthWireCandidateFields $sent @('format','job_id','request_id','proof_sha256','sent_at')
  foreach($n in @('format','job_id','request_id','proof_sha256')){if($sent.$n -isnot [string]){throw 'WRITE_AUTHORIZATION_REJECTED'}}
  if($sent.format -cne 'AuthWireWriteClaimSentV1' -or $sent.job_id -cne $JobId -or -not (Test-AuthWireWriteInteger $sent.sent_at) -or $sent.proof_sha256 -cne (Get-AuthWireWriteHash $proofRecord.proof)){throw 'WRITE_AUTHORIZATION_REJECTED'}
  # Check the proof/preflight at the recorded send time, not at a fabricated
  # new issuance time. Freshness at use is separately enforced below.
  $request=Assert-AuthWireStoredWriteClaimAt $proofRecord.proof $started $offer $Binding $Release $Key $sent.sent_at
  Assert-AuthWireRollbackPreflightAt $preflight $saved $Binding $Release $sent.sent_at
  if($sent.request_id -cne $request){throw 'WRITE_AUTHORIZATION_REJECTED'}
  $receipt=Read-AuthWireStagingJournal (Join-Path $job 'rollback-authorization.json')
  Assert-AuthWireCandidateFields $receipt @('format','binding_scope','release_id','offer_sha256','preflight_sha256','claim_proof_sha256','sent_at','received_at','grant')
  foreach($n in @('format','binding_scope','release_id','offer_sha256','preflight_sha256','claim_proof_sha256')){if($receipt.$n -isnot [string]){throw 'WRITE_AUTHORIZATION_REJECTED'}}
  if($receipt.format -cne 'AuthWireRollbackAuthorizationReceiptV1' -or $receipt.binding_scope -cne (Get-AuthWireJobScope $Binding) -or $receipt.release_id -cne $Release -or
     $receipt.offer_sha256 -cne (Get-AuthWireWriteHash $offer) -or $receipt.preflight_sha256 -cne (Get-AuthWireWriteHash $preflight) -or $receipt.claim_proof_sha256 -cne $sent.proof_sha256 -or
     -not (Test-AuthWireWriteInteger $receipt.sent_at) -or $receipt.sent_at -ne $sent.sent_at -or -not (Test-AuthWireWriteInteger $receipt.received_at)){throw 'WRITE_AUTHORIZATION_REJECTED'}
  Assert-AuthWireWriteGrantAt $receipt.grant $offer $request $sent.sent_at $receipt.received_at
  $now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
  if($now -lt $receipt.received_at){throw 'WRITE_AUTHORIZATION_EXPIRED'}
  $origin=Read-AuthWireRollbackOriginEvidenceAt $offer $Binding $Release $Key $sent.sent_at
  if($origin.ChainSha256 -cne $saved.Reservation.origin_chain_sha256 -or $origin.FilesystemOperationId -cne $saved.Reservation.stage_operation_id -or $origin.StageReleaseId -cne $saved.Reservation.stage_release_id){throw 'ROLLBACK_ORIGIN_CHANGED'}
  return [pscustomobject]@{Offer=$offer;Reservation=$saved.Reservation;Receipt=$receipt;Preflight=$preflight;Origin=$origin;AuthorizationSha256=(Get-AuthWireWriteHash $receipt)}
 }finally{$pin.Dispose()}
 }finally{$timePin.Dispose()}
}

function New-AuthWireRollbackFilesystemIntent([string]$Root,[string]$JobId,[hashtable]$Binding,[string]$Release,[Security.Cryptography.RSACng]$Key){
 Assert-AuthWireStagingWriteJournalLocation $Root $Binding;Assert-AuthWireCandidateGuid $JobId
 $lock=Enter-AuthWireWriteOutcomeLock $JobId;$p=$null
 try{
  $job=Join-Path $Root $JobId
  # Refuse replay before any key verification, reader process or network call.
  foreach($n in @('rollback-grant-consumed.json','rollback-filesystem-intent.json')){if(Test-Path -LiteralPath (Join-Path $job $n)){throw 'ROLLBACK_ALREADY_CONSUMED_REQUIRES_REVIEW'}}
  $a=Read-AuthWireRollbackAuthorization $Root $JobId $Binding $Release $Key
  $p=New-AuthWireRollbackInputPins $Root $JobId $a @('rollback-preflight.json','rollback-claim-started.json','rollback-claim-proof.json','rollback-claim-sent.json','rollback-authorization.json')
  $again=Read-AuthWireRollbackAuthorization $Root $JobId $Binding $Release $Key
  if($again.AuthorizationSha256 -cne $a.AuthorizationSha256){throw 'ROLLBACK_RECORD_CHANGED'}
  $now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds();$clock=[Diagnostics.Stopwatch]::StartNew();$expiry=$a.Receipt.grant.expires_at
  if($now -lt $a.Receipt.received_at -or $now -ge $expiry){throw 'ROLLBACK_AUTHORIZATION_EXPIRED'}
  $c=[pscustomobject]@{format='AuthWireRollbackGrantConsumedV1';binding_scope=(Get-AuthWireJobScope $Binding);release_id=$Release;job_id=$JobId;stage_job_id=$a.Reservation.stage_job_id;stage_operation_id=$a.Reservation.stage_operation_id;authorization_sha256=$a.AuthorizationSha256;origin_chain_sha256=$a.Reservation.origin_chain_sha256;consumed_at=$now;expires_at=$expiry}
  # CreateNew + Flush(true) BEFORE the second bounded read. Even a failed read
  # or failed intent flush permanently consumes this local grant for review.
  Write-AuthWireStagingJournal (Join-Path $job 'rollback-grant-consumed.json') $c
  $live=Read-AuthWireRollbackPreflightProcess $Root $JobId $Binding $Release $expiry
  Assert-AuthWireRollbackPreflightAt $live $a $Binding $Release ([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())
  if($live.checked_at -lt $now -or $live.directory_sha256 -cne $a.Preflight.directory_sha256 -or [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() -lt $now -or
     [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() -ge $expiry -or $clock.ElapsedMilliseconds -ge ($expiry-$now)*1000){throw 'ROLLBACK_INTENT_DEADLINE_OR_SCOPE_CHANGED'}
  # Authority inputs remain pinned while the signed reader rechecks the entire
  # origin chain twice. No third historical traversal refreshes live timestamps.
  Write-AuthWireStagingJournal (Join-Path $job 'rollback-consumption-preflight.json') $live
  $i=[pscustomobject]@{format='AuthWireRollbackFilesystemIntentV1';job_id=$JobId;binding_scope=$c.binding_scope;release_id=$Release;stage_job_id=$c.stage_job_id;stage_operation_id=$c.stage_operation_id;authorization_sha256=$a.AuthorizationSha256;consumption_sha256=(Get-AuthWireWriteHash $c);offer_sha256=$a.Receipt.offer_sha256;target_sha256=(Get-AuthWireWriteHash $a.Offer.target);origin_chain_sha256=$c.origin_chain_sha256;live_preflight_sha256=(Get-AuthWireWriteHash $live);expires_at=$expiry;can_delete=$false;can_apply_gpo=$false}
  Write-AuthWireStagingJournal (Join-Path $job 'rollback-filesystem-intent.json') $i
  $after=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
  if($after -lt $now -or $after -ge $expiry -or $clock.ElapsedMilliseconds -ge ($expiry-$now)*1000){throw 'ROLLBACK_AUTHORIZATION_EXPIRED'}
  return [pscustomobject]@{JobId=$JobId;Phase='rollback_intent_recorded';GrantConsumed=$true;FilesystemIntentSha256=(Get-AuthWireWriteHash $i);StageOperationId=$c.stage_operation_id;CanDelete=$false;CanApplyGpo=$false;RollbackExecuted=$false}
 }finally{if($p){$p.Dispose()};$lock.ReleaseMutex();$lock.Dispose()}
}
