# Source-only single controlled transaction; not a permanent polling worker.
# Installer-provisioned empty private root required. Never resets or unlocks it.
Set-StrictMode -Version 2
function Enter-AuthWireWriteCycleLock([hashtable]$Binding){
 Assert-AuthWireCandidateGuid $Binding.connector_id
 $m=[Threading.Mutex]::new($false,('Global\AuthWireWriteCycle-'+([guid]$Binding.connector_id).ToString('N')))
 try{if(-not $m.WaitOne(0)){throw 'WRITE_CYCLE_BUSY'};return $m}catch [Threading.AbandonedMutexException]{$m.ReleaseMutex();$m.Dispose();throw 'WRITE_CYCLE_ABANDONED_REQUIRES_REVIEW'}catch{$m.Dispose();throw}
}
function Assert-AuthWireWritePollReply($Value,[hashtable]$Binding,[string]$Release,[string]$RequestId){
 Assert-AuthWireCandidateFields $Value @('format','request_id','scope_sha256','job_id','operation','lease_id','intent_sha256','expires_at','target','write_authorized','can_apply_gpo')
 Assert-AuthWireStageStrings $Value @('request_id','scope_sha256','job_id','operation','lease_id','intent_sha256')
 if($Value.format -isnot [int] -or $Value.format -ne 1 -or $Value.request_id -cne $RequestId -or $Value.scope_sha256 -cne (Get-AuthWireJobScope $Binding) -or $Value.write_authorized -isnot [bool] -or $Value.write_authorized -or $Value.can_apply_gpo -isnot [bool] -or $Value.can_apply_gpo){throw 'WRITE_CYCLE_POLL_REJECTED'}
 if($Value.job_id -ceq ''){
  if($Value.operation -cne '' -or $Value.lease_id -cne '' -or $Value.intent_sha256 -cne '' -or $null -ne $Value.target -or $Value.expires_at -isnot [int] -or $Value.expires_at -ne 0){throw 'WRITE_CYCLE_POLL_REJECTED'}
 }else{
  Assert-AuthWireWriteOffer $Value $Binding $Release $RequestId
  if($Value.operation -cne 'combined.filesystem.stage.v1'){throw 'WRITE_CYCLE_ROLLBACK_UNAVAILABLE'}
 }
}
function Read-AuthWireWriteCycleOffer([string]$JournalRoot,[hashtable]$Binding,[string]$Release){
 Assert-AuthWireStagingWriteJournalLocation $JournalRoot $Binding
 Initialize-AuthWireStagingFilesystemTypes
 $p=[AuthWire.Staging.TreeLeaseV1]::new()
 try{
  $p.PinAncestors($JournalRoot);$path=Join-Path $JournalRoot 'cycle-offer.json';$p.PinFile($path);$v=Read-AuthWireStagingJournal $path
  Assert-AuthWireCandidateFields $v @('format','binding_scope','release_id','job_id','offer_sha256','poll_sha256')
  Assert-AuthWireStageStrings $v @('format','binding_scope','release_id','job_id','offer_sha256','poll_sha256')
  Assert-AuthWireCandidateGuid $v.job_id
  if($v.format -cne 'AuthWireWriteCycleOfferV1' -or $v.binding_scope -cne (Get-AuthWireJobScope $Binding) -or $v.release_id -cne $Release -or -not (Test-AuthWireWriteHash $v.offer_sha256) -or -not (Test-AuthWireWriteHash $v.poll_sha256)){throw 'WRITE_CYCLE_RECORD_REJECTED'}
  $path=Join-Path $JournalRoot 'cycle-poll.json';$p.PinFile($path)
  if((Get-AuthWireWriteHash (Read-AuthWireStagingJournal $path)) -cne $v.poll_sha256){throw 'WRITE_CYCLE_RECORD_REJECTED'}
  $job=Join-Path $JournalRoot $v.job_id;$p.PinAncestors($job);$path=Join-Path $job 'offer.json';$p.PinFile($path);$saved=Read-AuthWireStagingJournal $path
  if((Get-AuthWireWriteHash $saved.offer) -cne $v.offer_sha256){throw 'WRITE_CYCLE_RECORD_REJECTED'}
  return $v
 }finally{$p.Dispose()}
}
function Get-AuthWireWriteCycleResult([string]$JournalRoot,[string]$JobId,[hashtable]$Binding,[string]$Release,[Security.Cryptography.RSACng]$Key,[bool]$Recorded){
 $v=Read-AuthWireWriteResultOutbox $JournalRoot $JobId $Binding $Release $Key
 return [pscustomobject]@{JobId=$JobId;Phase=$(if($Recorded){'result_recorded'}else{'result_pending'});Outcome=$v.body.outcome;FilesystemEffects=$v.body.filesystem_effects;ResultRecorded=$Recorded;CanApplyGpo=$false;ArtifactExecuted=$false}
}
function Resume-AuthWireStagingWriteCycleResult([string]$JournalRoot,[hashtable]$Binding,[string]$Release,[Security.Cryptography.RSACng]$Key,[string]$BaseUrl){
 # Explicit result-only recovery. No POLL, CLAIM, consumption or stage call.
 Assert-AuthWireStagingWriteJournalLocation $JournalRoot $Binding
 $m=Enter-AuthWireWriteCycleLock $Binding
 try{
  $v=Read-AuthWireWriteCycleOffer $JournalRoot $Binding $Release
  $null=Read-AuthWireWriteAuthorizationEvidence $JournalRoot $v.job_id $Binding $Release $Key
  $sent=Send-AuthWireWriteResult $JournalRoot $v.job_id $Binding $Release $Key $BaseUrl
  return (Get-AuthWireWriteCycleResult $JournalRoot $v.job_id $Binding $Release $Key $sent.ResultRecorded)
 }finally{$m.ReleaseMutex();$m.Dispose()}
}
function Invoke-AuthWireStagingWriteCycle([string]$JournalRoot,[hashtable]$Binding,[string]$Release,[Security.Cryptography.RSACng]$Key,[string]$BaseUrl){
 Assert-AuthWireCandidateGuid $Release
 Assert-AuthWireStagingWriteJournalLocation $JournalRoot $Binding
 Initialize-AuthWireStagingFilesystemTypes
 $m=Enter-AuthWireWriteCycleLock $Binding;$p=[AuthWire.Staging.TreeLeaseV1]::new()
 try{
  $p.PinAncestors($JournalRoot)
  # This is deliberately one controlled cycle, not an unattended idle loop.
  # Any prior record (even a lost/no-job poll) requires explicit reconciliation.
  if([IO.Directory]::GetFileSystemEntries($JournalRoot).Length -ne 0){throw 'WRITE_CYCLE_EXISTING_HISTORY_REQUIRES_REVIEW'}
  $proof=New-AuthWireStagingWriteProof $Binding $Key POLL @{capability='combined.filesystem.write.v1';release_id=$Release}
  $request=[Text.Encoding]::ASCII.GetString([Convert]::FromBase64String($proof.frame)).Split([char]10)[10]
  $record=[pscustomobject]@{format='AuthWireWriteCyclePollV1';binding_scope=(Get-AuthWireJobScope $Binding);release_id=$Release;request_id=$request;sent_at=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds();proof=$proof}
  Write-AuthWireStagingJournal (Join-Path $JournalRoot 'cycle-poll.json') $record
  $p.PinFile((Join-Path $JournalRoot 'cycle-poll.json'))
  Initialize-AuthWireWriteTransportTypes
  $raw=[AuthWire.Connector.WriteTransportV1]::Post($BaseUrl,$Binding.appliance_fqdn,$Binding.appliance_tls_sha256,'/api/connector/v1/staging-write/poll',(ConvertTo-AuthWireWriteJson $proof))
  $offer=ConvertFrom-AuthWireCandidateJson ([Text.UTF8Encoding]::new($false,$true).GetBytes($raw));Assert-AuthWireWritePollReply $offer $Binding $Release $request
  if($offer.job_id -ceq ''){
   Write-AuthWireStagingJournal (Join-Path $JournalRoot 'cycle-idle.json') ([pscustomobject]@{format='AuthWireWriteCycleIdleV1';poll_sha256=(Get-AuthWireWriteHash $record);checked_at=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()})
   return [pscustomobject]@{JobId='';Phase='no_job';Outcome='';FilesystemEffects='none';ResultRecorded=$false;CanApplyGpo=$false;ArtifactExecuted=$false}
  }
  $null=Save-AuthWireStagingWriteOffer $offer $Binding $Release $request $JournalRoot
  Write-AuthWireStagingJournal (Join-Path $JournalRoot 'cycle-offer.json') ([pscustomobject]@{format='AuthWireWriteCycleOfferV1';binding_scope=(Get-AuthWireJobScope $Binding);release_id=$Release;job_id=$offer.job_id;offer_sha256=(Get-AuthWireWriteHash $offer);poll_sha256=(Get-AuthWireWriteHash $record)})
  $job=Join-Path $JournalRoot $offer.job_id;$phase='preflight'
  try{
   $null=Invoke-AuthWireStagingWritePreflight $JournalRoot $offer.job_id $Binding $Release
   $phase='claim';$null=New-AuthWireStagingWriteClaim $JournalRoot $offer.job_id $Binding $Release $Key
   $null=Invoke-AuthWireStagingWriteClaimTransport $JournalRoot $offer.job_id $Binding $Release $Key $BaseUrl
   $phase='consume';$null=New-AuthWireAuthorizedFilesystemIntent $JournalRoot $offer.job_id $Binding $Release $Key
   $phase='stage';$null=Invoke-AuthWireAuthorizedFilesystemStage $JournalRoot $offer.job_id $Binding $Release $Key
  }catch{
   # An authorization receipt may be absent even if the server issued a grant.
   # Neither lost receipt nor timeout permits another claim or execution.
   Write-AuthWireStagingJournal (Join-Path $job 'cycle-review.json') ([pscustomobject]@{format='AuthWireWriteCycleReviewV1';job_id=$offer.job_id;phase=$phase;reason='OUTCOME_REQUIRES_REVIEW';checked_at=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()})
  }
  if(-not (Test-Path -LiteralPath (Join-Path $job 'authorization.json'))){return [pscustomobject]@{JobId=$offer.job_id;Phase='local_reconciliation_required';Outcome='';FilesystemEffects='unconfirmed';ResultRecorded=$false;CanApplyGpo=$false;ArtifactExecuted=$false}}
  try{$sent=Send-AuthWireWriteResult $JournalRoot $offer.job_id $Binding $Release $Key $BaseUrl}
  catch{
   # Outbox/attempt records retain uncertainty; this catch never loops.
   if(Test-Path -LiteralPath (Join-Path $job 'result-outbox.json')){return (Get-AuthWireWriteCycleResult $JournalRoot $offer.job_id $Binding $Release $Key $false)}
   throw 'WRITE_CYCLE_RESULT_REQUIRES_REVIEW'
  }
  return (Get-AuthWireWriteCycleResult $JournalRoot $offer.job_id $Binding $Release $Key $sent.ResultRecorded)
 }finally{$p.Dispose();$m.ReleaseMutex();$m.Dispose()}
}
