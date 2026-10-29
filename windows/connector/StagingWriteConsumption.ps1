# Source-only one-use grant consumption and authorized filesystem intent.
# Not in the live package/worker. No filesystem stage or rollback call here.
Set-StrictMode -Version 2

function Get-AuthWireStagingWriteJournalRoot([hashtable]$Binding){
 Assert-AuthWireCandidateGuid $Binding.connector_id
 return (Join-Path ([Environment]::GetFolderPath('CommonApplicationData')) ('AuthWire-WriteJournal-'+([guid]$Binding.connector_id).ToString('N')))
}
function Assert-AuthWireStagingWriteJournalLocation([string]$JournalRoot,[hashtable]$Binding){
 # A new/alternate empty store is not recovery. The installer must provision
 # this stable private root; this SDK never creates or changes its ACL.
 if($JournalRoot -cne (Get-AuthWireStagingWriteJournalRoot $Binding)){throw 'WRITE_JOURNAL_LOCATION_REJECTED'}
 Assert-AuthWireStagingJournalRoot $JournalRoot
}
function Read-AuthWireWriteAuthorization([string]$JournalRoot,[string]$JobId,[hashtable]$Binding,[string]$Release,[Security.Cryptography.RSACng]$Key){
 Assert-AuthWireStagingWriteJournalLocation $JournalRoot $Binding
 $offer=Read-AuthWireStagingWriteOffer $JournalRoot $JobId $Binding $Release
 if($offer.operation -cne 'combined.filesystem.stage.v1'){throw 'WRITE_ROLLBACK_CONSUMPTION_UNAVAILABLE'}
 $pin=[AuthWire.Staging.TreeLeaseV1]::new()
 try{
  $pin.PinAncestors($JournalRoot);$job=Join-Path $JournalRoot $JobId;$pin.PinAncestors($job)
  foreach($n in @('offer.json','preflight.json','claim-started.json','claim-proof.json','claim-sent.json','authorization.json')){$pin.PinFile((Join-Path $job $n))}
  $pin.PinFile((Join-Path $JournalRoot ('gpo-'+$offer.target.scope_target.gpo_id+'.json')))
  $again=Read-AuthWireStagingWriteOffer $JournalRoot $JobId $Binding $Release
  if((Get-AuthWireWriteHash $again) -cne (Get-AuthWireWriteHash $offer)){throw 'WRITE_LOCAL_RECORD_CHANGED'}
  $preflight=Read-AuthWireStagingJournal (Join-Path $job 'preflight.json')
  $started=Read-AuthWireStagingJournal (Join-Path $job 'claim-started.json')
  $proofRecord=Read-AuthWireStagingJournal (Join-Path $job 'claim-proof.json')
  Assert-AuthWireCandidateFields $proofRecord @('format','job_id','proof')
  if($proofRecord.format -isnot [string] -or $proofRecord.format -cne 'AuthWireWriteClaimProofV1' -or $proofRecord.job_id -isnot [string] -or $proofRecord.job_id -cne $JobId){throw 'WRITE_AUTHORIZATION_REJECTED'}
  $sent=Read-AuthWireStagingJournal (Join-Path $job 'claim-sent.json')
  Assert-AuthWireCandidateFields $sent @('format','job_id','request_id','proof_sha256','sent_at')
  foreach($n in @('format','job_id','request_id','proof_sha256')){if($sent.$n -isnot [string]){throw 'WRITE_AUTHORIZATION_REJECTED'}}
  if($sent.format -cne 'AuthWireWriteClaimSentV1' -or $sent.job_id -cne $JobId -or -not (Test-AuthWireWriteInteger $sent.sent_at) -or $sent.proof_sha256 -cne (Get-AuthWireWriteHash $proofRecord.proof)){throw 'WRITE_AUTHORIZATION_REJECTED'}
  # Check the proof/preflight at the recorded send time, not at a fabricated
  # new issuance time. Freshness at use is separately enforced below.
  $request=Assert-AuthWireStoredWriteClaimAt $proofRecord.proof $started $offer $Binding $Release $Key $sent.sent_at
  Assert-AuthWireWriteLiveContextAt $preflight $offer $Binding $sent.sent_at
  if($sent.request_id -cne $request){throw 'WRITE_AUTHORIZATION_REJECTED'}
  $receipt=Read-AuthWireStagingJournal (Join-Path $job 'authorization.json')
  Assert-AuthWireCandidateFields $receipt @('format','binding_scope','release_id','offer_sha256','preflight_sha256','claim_proof_sha256','sent_at','received_at','grant')
  foreach($n in @('format','binding_scope','release_id','offer_sha256','preflight_sha256','claim_proof_sha256')){if($receipt.$n -isnot [string]){throw 'WRITE_AUTHORIZATION_REJECTED'}}
  if($receipt.format -cne 'AuthWireWriteAuthorizationReceiptV1' -or $receipt.binding_scope -cne (Get-AuthWireJobScope $Binding) -or $receipt.release_id -cne $Release -or
     $receipt.offer_sha256 -cne (Get-AuthWireWriteHash $offer) -or $receipt.preflight_sha256 -cne (Get-AuthWireWriteHash $preflight) -or $receipt.claim_proof_sha256 -cne $sent.proof_sha256 -or
     -not (Test-AuthWireWriteInteger $receipt.sent_at) -or $receipt.sent_at -ne $sent.sent_at -or -not (Test-AuthWireWriteInteger $receipt.received_at)){throw 'WRITE_AUTHORIZATION_REJECTED'}
  Assert-AuthWireWriteGrantAt $receipt.grant $offer $request $sent.sent_at $receipt.received_at
  $now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
  if($now -lt $receipt.received_at -or $now -ge $receipt.grant.expires_at){throw 'WRITE_AUTHORIZATION_EXPIRED'}
  return [pscustomobject]@{Offer=$offer;Receipt=$receipt;Preflight=$preflight;AuthorizationSha256=(Get-AuthWireWriteHash $receipt)}
 }finally{$pin.Dispose()}
}
function Read-AuthWireWriteIntentContext([string]$JournalRoot,[string]$JobId,$Offer,[hashtable]$Binding,[long]$ExpiresAt){
 Initialize-AuthWireScopeProcess
 $now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
 $budget=[int][Math]::Min(8000,($ExpiresAt-$now-2)*1000)
 if($budget -lt 100){throw 'WRITE_AUTHORIZATION_EXPIRED'}
 if($JournalRoot.Length -gt 1800 -or $JournalRoot.Contains('"')){throw 'WRITE_JOURNAL_PATH_REJECTED'}
 $file=Join-Path $PSScriptRoot 'Read-AuthWireStagingWritePreflight.ps1'
 $exe=Join-Path ([Environment]::GetFolderPath('Windows')) 'System32\WindowsPowerShell\v1.0\powershell.exe'
 $arguments='-NoLogo -NoProfile -NonInteractive -ExecutionPolicy AllSigned -File "'+$file+'" -JournalRoot "'+$JournalRoot.TrimEnd('\')+'" -JobId '+$JobId
 $r=[AuthWire.Connector.ScopeProcessV1]::Run($exe,$arguments,$budget)
 if($r.TimedOut -or $r.Truncated -or $r.ExitCode -ne 0){throw 'WRITE_INTENT_PREFLIGHT_FAILED'}
 $v=ConvertFrom-AuthWireCandidateJson ([Text.UTF8Encoding]::new($false,$true).GetBytes($r.Output))
 Assert-AuthWireWriteLiveContext $v $Offer $Binding
 if($v.checked_at -lt $now){throw 'WRITE_INTENT_PREFLIGHT_STALE'}
 return $v
}
function Get-AuthWireFilesystemOperationId($Authorization){
 $r=$Authorization.Receipt;$o=$Authorization.Offer
 $frame='AuthWireAuthorizedFilesystemOperationV1'+"`n"+$r.binding_scope+"`n"+$o.job_id+"`n"+$r.grant.authorization_id+"`n"+$Authorization.AuthorizationSha256+"`n"
 $hash=Get-AuthWireJobHash ([Text.Encoding]::ASCII.GetBytes($frame))
 return ([guid]::ParseExact($hash.Substring(0,32),'N').ToString('D'))
}
function New-AuthWireAuthorizedFilesystemIntent([string]$JournalRoot,[string]$JobId,[hashtable]$Binding,[string]$Release,[Security.Cryptography.RSACng]$Key){
 $a=Read-AuthWireWriteAuthorization $JournalRoot $JobId $Binding $Release $Key
 $pin=[AuthWire.Staging.TreeLeaseV1]::new()
 try{
  $pin.PinAncestors($JournalRoot);$job=Join-Path $JournalRoot $JobId;$pin.PinAncestors($job)
  foreach($n in @('offer.json','preflight.json','claim-started.json','claim-proof.json','claim-sent.json','authorization.json')){$pin.PinFile((Join-Path $job $n))}
  $pin.PinFile((Join-Path $JournalRoot ('gpo-'+$a.Offer.target.scope_target.gpo_id+'.json')))
  $again=Read-AuthWireWriteAuthorization $JournalRoot $JobId $Binding $Release $Key
  if($again.AuthorizationSha256 -cne $a.AuthorizationSha256){throw 'WRITE_LOCAL_RECORD_CHANGED'}
  $op=Get-AuthWireFilesystemOperationId $a
  Assert-AuthWireCandidateGuid $op
  # Local operation ID is a journal locator, NOT an authorization substitute.
  if($op -ceq $JobId -or (Test-Path -LiteralPath (Join-Path $JournalRoot $op)) -or (Test-Path -LiteralPath (Join-Path $job 'filesystem-intent.json'))){throw 'WRITE_FILESYSTEM_JOURNAL_EXISTS_REQUIRES_REVIEW'}
  $now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
  if($now -lt $a.Receipt.received_at -or $now -ge $a.Receipt.grant.expires_at){throw 'WRITE_AUTHORIZATION_EXPIRED'}
  $useWatch=[Diagnostics.Stopwatch]::StartNew()
  $consumed=[pscustomobject][ordered]@{format='AuthWireWriteGrantConsumedV1';binding_scope=(Get-AuthWireJobScope $Binding);release_id=$Release;job_id=$JobId;authorization_sha256=$a.AuthorizationSha256;filesystem_operation_id=$op;consumed_at=$now;expires_at=$a.Receipt.grant.expires_at}
  # This atomic CreateNew + Flush(true) happens BEFORE another reader/process,
  # filesystem intent or future write. No automatic retry after this point.
  Write-AuthWireStagingJournal (Join-Path $job 'grant-consumed.json') $consumed
  $live=Read-AuthWireWriteIntentContext $JournalRoot $JobId $a.Offer $Binding $a.Receipt.grant.expires_at
  Assert-AuthWireWriteLiveContext $live $a.Offer $Binding
  if($live.checked_at -lt $now -or [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() -lt $now -or $useWatch.ElapsedMilliseconds -ge ($a.Receipt.grant.expires_at-$now)*1000){throw 'WRITE_INTENT_USE_CLOCK_REJECTED'}
  foreach($n in @('source_root','gpo_root','protected_gpo_id','pdc')){if($live.$n -cne $a.Preflight.$n){throw 'WRITE_INTENT_SCOPE_CHANGED'}}
  # Current signatures/AD/PDC/source/ACL observations must still match the
  # originally approved preview. Network paths never come from a grant field.
  $again=Read-AuthWireWriteAuthorization $JournalRoot $JobId $Binding $Release $Key
  if($again.AuthorizationSha256 -cne $a.AuthorizationSha256){throw 'WRITE_LOCAL_RECORD_CHANGED'}
  $intent=[pscustomobject][ordered]@{format='AuthWireAuthorizedFilesystemIntentV1';job_id=$JobId;filesystem_operation_id=$op;binding_scope=$consumed.binding_scope;release_id=$Release;authorization_sha256=$a.AuthorizationSha256;consumption_sha256=(Get-AuthWireWriteHash $consumed);offer_sha256=$a.Receipt.offer_sha256;target_sha256=(Get-AuthWireWriteHash $a.Offer.target);preview_sha256=$a.Offer.target.preview_record.PreviewSha256;live_context=$live;expires_at=$a.Receipt.grant.expires_at;filesystem_write_enabled=$false;can_apply_gpo=$false}
  Write-AuthWireStagingJournal (Join-Path $job 'filesystem-intent.json') $intent
  # Persistence cannot extend the grant. An expired/uncertain saved intent is
  # retained for review and never reported as executable/completed staging.
  $after=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
  if($after -lt $now -or $after -ge $a.Receipt.grant.expires_at -or $useWatch.ElapsedMilliseconds -ge ($a.Receipt.grant.expires_at-$now)*1000){throw 'WRITE_AUTHORIZATION_EXPIRED'}
  return [pscustomobject]@{JobId=$JobId;Phase='filesystem_intent_recorded';GrantConsumed=$true;FilesystemOperationId=$op;FilesystemIntentSha256=(Get-AuthWireWriteHash $intent);FilesystemWriteEnabled=$false;CanApplyGpo=$false}
 }finally{$pin.Dispose()}
}
