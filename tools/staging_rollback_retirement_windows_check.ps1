#Requires -Version 5.1
# New focused append-only retirement checks. CNG, NTFS CreateNew records, held
# handles, reservation succession and proof validation are real. Original
# stage/AD/result-chain inputs and privileged HTTPS acknowledgement are explicit
# fixture shims; they are covered separately by existing protocol checks.
$ErrorActionPreference='Stop';Set-StrictMode -Version 2
$lib=Join-Path $PSScriptRoot '..\windows\connector'
. (Join-Path $lib 'Test-AuthWireDeploymentCandidate.ps1') -LibraryOnly
foreach($n in @('Invoke-AuthWireConnectorProbeJob.ps1','StagingFilesystem.ps1','StagingWritePreclaim.ps1','StagingWriteTransport.ps1','StagingWriteExecution.ps1','StagingWriteCycle.ps1','StagingRollbackAuthorization.ps1','StagingRollbackEvidence.ps1','StagingWriteHistory.ps1')){. (Join-Path $lib $n)}
Initialize-AuthWireStagingFilesystemTypes
$script:checks=0
function Check($v,[string]$n){if(-not $v){throw ('ROLLBACK_RETIRE_FIXTURE:'+ $n)};$script:checks++}
function Reject([scriptblock]$fn,[string]$n){$failed=$false;try{& $fn|Out-Null}catch{$failed=$true};Check $failed $n}
$root=$env:SystemDrive+'\aw-rr-'+[guid]::NewGuid().ToString('N').Substring(0,8);$key=$null;$rsa=$null;$wrong=$null;$wrongRsa=$null
try{
 $b=@{connector_id=[guid]::NewGuid().ToString('D');service_sid='S-1-5-21-1-2-3-1001'}
 $stage=[guid]::NewGuid().ToString('D');$jobId=[guid]::NewGuid().ToString('D');$gpo=[guid]::NewGuid().ToString('D');$release=[guid]::NewGuid().ToString('D')
 [IO.Directory]::CreateDirectory($root)|Out-Null;$job=Join-Path $root $jobId;[IO.Directory]::CreateDirectory($job)|Out-Null
 $life=Join-Path $root 'write-lifecycle';[IO.Directory]::CreateDirectory((Join-Path $life '000001'))|Out-Null
 function Get-AuthWireJobScope {return ('1'*64)}
 function Assert-AuthWireRollbackReaderIdentity { }
 function Get-AuthWireStagingWriteJournalRoot {return $root}
 function Assert-AuthWireStagingWriteJournalLocation($Path){if($Path -cne $root){throw 'FIXTURE_ROOT_CHANGED'}}
 function Assert-AuthWireWriteOffer { }
 function Assert-AuthWireWriteOfferAt { }
 $origin=[pscustomobject]@{StageJobId=$stage;StageReleaseId=$release;FilesystemOperationId=[guid]::NewGuid().ToString('D');ChainSha256=('2'*64);Complete=[pscustomobject]@{tree_sha256=('3'*64)};Intent=[pscustomobject]@{baseline_sha256=('4'*64)}}
 function Read-AuthWireRollbackOrigin {return $origin}
 $offer=[pscustomobject]@{job_id=$jobId;request_id=('5'*64);intent_sha256=('6'*64);operation='combined.filesystem.rollback.v1';target=[pscustomobject]@{stage_receipt=[pscustomobject]@{stage_job_id=$stage};scope_target=[pscustomobject]@{gpo_id=$gpo}}}
 $oldState=[pscustomobject]@{Phase='reply_saved';Slot='000001';Offer=$offer}
 $script:fixtureOriginalOffer=$offer
 $reservation=[pscustomobject]@{format='AuthWireRollbackReservationV1';binding_scope=('1'*64);release_id=$release;job_id=$jobId;stage_job_id=$stage;stage_release_id=$release;stage_operation_id=$origin.FilesystemOperationId;intent_sha256=$offer.intent_sha256;origin_chain_sha256=$origin.ChainSha256}
 $anchor=Get-AuthWireRollbackReservationPath $root $stage
 Write-AuthWireStagingJournal $anchor $reservation
 $gpoLock=Join-Path $root ('gpo-'+$gpo+'.json');Write-AuthWireStagingJournal $gpoLock ([pscustomobject]@{format='AuthWireWriteGpoLockV1';job_id=$stage;intent_sha256=('7'*64)})
 $oldResult=Join-Path $job 'retained-refusal-fixture.json';Write-AuthWireStagingJournal $oldResult ([pscustomobject]@{outcome='refused_before_authorization';authorization_id='';filesystem_effects='none'})
 $original=@{};foreach($f in @($anchor,$gpoLock,$oldResult)){$original[$f]=[IO.File]::ReadAllBytes($f)}
 # This state seam avoids inventing protocol signatures/AD in this unit check.
 # The actual product getter remains unchanged and is used in field acceptance.
 function Get-AuthWireRollbackRetirementState($Root,$JobId,$Binding,$Key,$Pins,$ExistingState=$null,$ExistingLife='',$Historical=$false){
  if($JobId -cne $jobId){throw 'FIXTURE_JOB_CHANGED'}
  foreach($f in @($anchor,$gpoLock,$oldResult)){$Pins.PinFile($f)}
  $frozen=[pscustomobject]@{reservation=(Get-AuthWireWriteHash (Read-AuthWireStagingJournal $anchor));lock=(Get-AuthWireWriteHash (Read-AuthWireStagingJournal $gpoLock));result=(Get-AuthWireWriteHash (Read-AuthWireStagingJournal $oldResult))}
  return [pscustomobject]@{State=$oldState;Life=$life;Origin=$origin;OriginalSha256=(Get-AuthWireWriteHash $frozen);Frozen=$frozen;Evidence=[pscustomobject]@{job_id=$jobId;scope_sha256=('1'*64);intent_sha256=$script:fixtureOriginalOffer.intent_sha256;result_body_sha256=('8'*64);accepted_ack=$true}}
 }
 $script:successorState=$null
 function Read-AuthWireLifecycleHistory {return [pscustomobject]@{Life=$life;ActiveStates=@($oldState);States=$(if($script:successorState){@($oldState,$script:successorState)}else{@($oldState)})}}
 $parameters=[Security.Cryptography.CngKeyCreationParameters]::new();$parameters.KeyUsage=[Security.Cryptography.CngKeyUsages]::Signing;$parameters.ExportPolicy=[Security.Cryptography.CngExportPolicies]::None
 $key=[Security.Cryptography.CngKey]::Create([Security.Cryptography.CngAlgorithm]::Rsa,('AuthWire-RetireFixture-'+[guid]::NewGuid().ToString('N')),$parameters);$rsa=[Security.Cryptography.RSACng]::new($key)
 $review=Get-AuthWireRefusedRollbackRetirementReview $root $jobId $b $rsa
 Check ($review.Proof.Body.retain_original_reservation -and $review.Proof.Body.retain_gpo_lock -and -not $review.Proof.Body.can_delete) 'review cannot unlock GPO or delete old reservation'
 $next=[pscustomobject]@{job_id=[guid]::NewGuid().ToString('D');request_id=('9'*64);intent_sha256=('a'*64);operation=$offer.operation;target=$offer.target}
 Reject {Save-AuthWireRollbackOffer $next $b $release $rsa $next.request_id} 'fresh job cannot bypass unretired original reservation'
 Check (-not(Test-Path -LiteralPath (Join-Path $root $next.job_id))) 'refused succession leaves no new job directory'
 $ack=[pscustomobject]@{expected_revision=10;evidence=$review.Evidence;decision='acknowledge_saved_result';review_hash=('b'*64);acknowledge='record_reconciliation_decision'}
 $script:ackDenied=$true;$script:ackCalls=0
 function Confirm-AuthWireRollbackRetirementAcknowledgement {
  $script:ackCalls++;if($script:ackDenied){throw 'FIXTURE_PRIVILEGED_SESSION_DENIED'}
  return [pscustomobject]@{job_id=$jobId;decision='acknowledge_saved_result';decision_recorded=$true;revision=11;approval_enabled=$false;write_authorization_enabled=$false;execution_adapter_available=$false;can_apply_gpo=$false}
 }
 $session=ConvertTo-SecureString ('c'*43) -AsPlainText -Force;$csrf=ConvertTo-SecureString ('d'*43) -AsPlainText -Force
 Reject {Complete-AuthWireRefusedRollbackRetirement $root $jobId $b $rsa 'https://fixture.example/' $review.Proof ('0'*64) $ack $session $csrf 'retire_refused_rollback_without_replay'} 'different reviewed proof cannot authorize local closure'
 Check ($script:ackCalls -eq 0) 'invalid review is refused before privileged HTTP'
 Reject {Complete-AuthWireRefusedRollbackRetirement $root $jobId $b $rsa 'https://fixture.example/' $review.Proof $review.ProofSha256 $ack $session $csrf 'retire_refused_rollback_without_replay'} 'current privileged-session refusal preserves barrier'
 Check (-not(Test-Path (Join-Path $job 'rollback-retirement-review.json'))) 'failed acknowledgement creates no retirement record'
 $script:ackDenied=$false
 $fp=[AuthWire.Staging.TreeLeaseV1]::new()
 try{$fake=Get-AuthWireRollbackRetirementState $root $jobId $b $rsa $fp}finally{$fp.Dispose()}
 $sourceReceipt=[pscustomobject]@{job_id=$jobId;decision='acknowledge_saved_result';decision_recorded=$true;revision=11;approval_enabled=$false;write_authorization_enabled=$false;execution_adapter_available=$false;can_apply_gpo=$false}
 Assert-AuthWireRollbackRetirementAcknowledgement $ack $sourceReceipt $fake
 Check $true 'source-only acknowledgement metadata remains supported'
 $badReceipt=[pscustomobject]@{job_id=$jobId;decision='acknowledge_saved_result';decision_recorded=$true;revision=11;source_only=$false;approval_enabled=$true;write_authorization_enabled=$true;execution_adapter_available=$true;can_apply_gpo=$true}
 Reject {Assert-AuthWireRollbackRetirementAcknowledgement $ack $badReceipt $fake} 'pilot capability metadata never enables GPO activation'
 function Confirm-AuthWireRollbackRetirementAcknowledgement {
  $script:ackCalls++
  return [pscustomobject]@{job_id=$jobId;decision='acknowledge_saved_result';decision_recorded=$true;revision=11;source_only=$false;approval_enabled=$true;write_authorization_enabled=$true;execution_adapter_available=$true;can_apply_gpo=$false}
 }
 $complete=Complete-AuthWireRefusedRollbackRetirement $root $jobId $b $rsa 'https://fixture.example/' $review.Proof $review.ProofSha256 $ack $session $csrf 'retire_refused_rollback_without_replay'
 Check (Test-AuthWireRefusedRollbackRetired $root $life $oldState $b $rsa) 'signed append-only completion validates'
 Check (Test-AuthWireHistoryAcceptedOutcome $root $life $oldState ([pscustomobject]@{outcome='refused_before_authorization'}) $b $rsa) 'complete exact signed retirement is eligible for both active and archived history'
 Check ($complete.Body.original_reservation_retained -and $complete.Body.gpo_lock_retained -and -not $complete.Body.authority_renewed -and -not $complete.Body.can_delete) 'completion retains immutable records and grants no authority'
 foreach($f in $original.Keys){Check ([Convert]::ToBase64String([IO.File]::ReadAllBytes($f)) -ceq [Convert]::ToBase64String($original[$f])) 'original reservation GPO lock and refusal bytes unchanged'}
 $calls=$script:ackCalls
 Reject {Complete-AuthWireRefusedRollbackRetirement $root $jobId $b $rsa 'https://fixture.example/' $review.Proof $review.ProofSha256 $ack $session $csrf 'retire_refused_rollback_without_replay'} 'closed retirement is never replayed'
 Check ($script:ackCalls -eq $calls) 'replay is refused before another acknowledgement'
 $bytes=[IO.File]::ReadAllBytes($oldResult)
 try{[IO.File]::WriteAllText($oldResult,'{"changed":true}');Reject {Test-AuthWireRefusedRollbackRetired $root $life $oldState $b $rsa} 'changed original refusal invalidates retirement'}finally{[IO.File]::WriteAllBytes($oldResult,$bytes)}
 $file=Join-Path $job 'rollback-retirement-complete.json';$bytes=[IO.File]::ReadAllBytes($file)
 try{[IO.File]::Delete($file);Check (-not(Test-AuthWireRefusedRollbackRetired $root $life $oldState $b $rsa)) 'partial retirement remains blocked';Reject {Save-AuthWireRollbackOffer $next $b $release $rsa $next.request_id} 'partial closure cannot admit new offer'}finally{[IO.File]::WriteAllBytes($file,$bytes)}
 $wrong=[Security.Cryptography.CngKey]::Create([Security.Cryptography.CngAlgorithm]::Rsa,('AuthWire-WrongRetireFixture-'+[guid]::NewGuid().ToString('N')),$parameters);$wrongRsa=[Security.Cryptography.RSACng]::new($wrong)
 Reject {Test-AuthWireRefusedRollbackRetired $root $life $oldState $b $wrongRsa} 'different channel key cannot inherit retirement'
 $saved=Save-AuthWireRollbackOffer $next $b $release $rsa $next.request_id
 $newPath=Get-AuthWireRollbackReservationPath $root $stage $next.job_id
 Check ($newPath -ceq (Join-Path (Join-Path $root $next.job_id) 'rollback-reservation.json')) 'successor gets distinct append-only per-job reservation'
 Check ([Convert]::ToBase64String([IO.File]::ReadAllBytes($anchor)) -ceq [Convert]::ToBase64String($original[$anchor])) 'succession does not replace original root reservation'
 $loaded=Read-AuthWireRollbackOfferAt $root $next.job_id $b $release ([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())
 Check ($loaded.Reservation.job_id -ceq $next.job_id -and $loaded.Reservation.stage_job_id -ceq $stage) 'new offer reads its own exact reservation and same original stage'
 $script:successorState=[pscustomobject]@{Phase='reply_saved';Slot='000002';Offer=$next}
 $third=[pscustomobject]@{job_id=[guid]::NewGuid().ToString('D');request_id=('e'*64);intent_sha256=('f'*64);operation=$offer.operation;target=$offer.target}
 Reject {Save-AuthWireRollbackOffer $third $b $release $rsa $third.request_id} 'new job ID cannot bypass outstanding successor reservation'
 Write-Host ('AUTHWIRE_ROLLBACK_RETIREMENT_OK checks='+$script:checks+' native_cng_ntfs=true append_only=true simulated_stage_chain_and_admin_https=true')
}catch{Write-Host $_.ScriptStackTrace;throw}finally{
 if($wrongRsa){$wrongRsa.Dispose()};if($wrong){$wrong.Delete();$wrong.Dispose()};if($rsa){$rsa.Dispose()};if($key){$key.Delete();$key.Dispose()}
 if(Test-Path -LiteralPath $root){Remove-Item -LiteralPath $root -Recurse -Force}
}

