#Requires -Version 5.1
# Focused new gate checks. CNG, signatures, NTFS handles, immutable records,
# child liveness, actual tree digests and outside inventory are real. Historical
# POLL/CLAIM/origin and privileged HTTPS are explicit fixture seams; no field AD.
$ErrorActionPreference='Stop';Set-StrictMode -Version 2
$lib=Join-Path $PSScriptRoot '..\windows\connector'
. (Join-Path $lib 'Test-AuthWireDeploymentCandidate.ps1') -LibraryOnly
foreach($n in @('Invoke-AuthWireConnectorProbeJob.ps1','DeploymentScope.ps1','CombinedDeploymentScope.ps1','SysvolInventory.ps1','StagingFilesystem.ps1','StagingWritePreclaim.ps1','StagingWriteTransport.ps1','StagingWriteExecution.ps1','StagingWriteCycle.ps1','StagingRollbackAuthorization.ps1','StagingRollbackEvidence.ps1','StagingRollbackExecution.ps1','StagingRollbackResult.ps1','StagingWriteHistory.ps1')){. (Join-Path $lib $n)}
Initialize-AuthWireStagingFilesystemTypes
$script:checks=0
function Check($Value,[string]$Name){if(-not $Value){throw ('CONSUMED_ROLLBACK_RETIRE_FIXTURE:'+ $Name)};$script:checks++}
function Reject([scriptblock]$Action,[string]$Name){$failed=$false;try{& $Action|Out-Null}catch{$failed=$true};Check $failed $Name}
function Clone($Value){return ($Value|ConvertTo-Json -Depth 32 -Compress|ConvertFrom-Json)}
$root=$env:SystemDrive+'\aw-crr-'+[guid]::NewGuid().ToString('N').Substring(0,8);$gpo=$root+'-gpo';$key=$null;$rsa=$null;$wrong=$null;$wrongRsa=$null
try{
 $now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds();$release=[guid]::NewGuid().ToString('D');$jobId=[guid]::NewGuid().ToString('D');$stage=[guid]::NewGuid().ToString('D');$op=[guid]::NewGuid().ToString('D');$gpoId=[guid]::NewGuid().ToString('D')
 $b=@{connector_id=[guid]::NewGuid().ToString('D');service_sid='S-1-5-21-1-2-3-1001'}
 $job=Join-Path $root $jobId;$engine=Join-Path $root $op;$stageDir=Join-Path $root $stage;$life=Join-Path $root 'write-lifecycle';$slot=Join-Path $life '000001';$dest=Join-Path $gpo 'Machine\AuthWire-fixture'
 foreach($dir in @($job,$engine,$stageDir,$slot,$dest)){[IO.Directory]::CreateDirectory($dir)|Out-Null}
 [IO.File]::WriteAllText((Join-Path $dest 'payload.ps1'),'# fixture bytes; never executed');[IO.File]::WriteAllText((Join-Path $gpo 'gpt.ini'),'[General]')
 function Get-AuthWireJobScope {return ('1'*64)}
 function Assert-AuthWireRollbackReaderIdentity { }
 function Assert-AuthWireStagingWriteJournalLocation($Path){if($Path -cne $root){throw 'FIXTURE_ROOT_CHANGED'}}
 function Add-AuthWireStagingGpoPins($Pins,$Path){$Pins.PinAncestors($Path)}
 function Assert-AuthWireNoActiveStage { }
 $lease=[AuthWire.Staging.TreeLeaseV1]::Tree($dest,$false)
 try{$tree=Get-AuthWireStagingFilesystemDigest (Get-AuthWireStagingFilesystemRows $lease);$rowCount=@(Get-AuthWireStagingFilesystemRows $lease).Count}finally{$lease.Dispose()}
 $inventory=Get-AuthWireSysvolInventory $gpo;$relative='Machine/AuthWire-fixture';$outside=@($inventory.Entries|Where-Object {$_.Path -cne $relative -and -not $_.Path.StartsWith($relative+'/',[StringComparison]::Ordinal)});$baseline=Get-AuthWireScopeDataHash $outside
 $origin=[pscustomobject]@{StageJobId=$stage;StageReleaseId=$release;FilesystemOperationId=$op;ChainSha256=('2'*64);Complete=[pscustomobject]@{tree_sha256=$tree};Intent=[pscustomobject]@{gpo_root=$gpo;relative_destination=$relative;baseline_sha256=$baseline}}
 $offer=[pscustomobject]@{job_id=$jobId;operation='combined.filesystem.rollback.v1';intent_sha256=('3'*64);expires_at=($now-30);target=[pscustomobject]@{stage_receipt=[pscustomobject]@{stage_job_id=$stage};scope_target=[pscustomobject]@{gpo_id=$gpoId}}}
 $state=[pscustomobject]@{Phase='reply_saved';Slot='000001';Offer=$offer;Started=[pscustomobject]@{release_id=$release}}
 $intent=[pscustomobject]@{stage_operation_id=$op;expires_at=($now-30)}
 $authorization=[pscustomobject]@{Offer=$offer;Origin=$origin;Receipt=[pscustomobject]@{release_id=$release};AuthorizationSha256=('4'*64);Reservation=[pscustomobject]@{job_id=$jobId;stage_job_id=$stage}}
 $original=[pscustomobject]@{Authorization=$authorization;Intent=$intent;IntentSha256=(Get-AuthWireWriteHash $intent);Consumed=[pscustomobject]@{consumed_at=($now-50)}}
 foreach($n in @('rollback-offer.json','rollback-preflight.json','rollback-claim-started.json','rollback-claim-proof.json','rollback-claim-sent.json','rollback-authorization.json','rollback-grant-consumed.json','rollback-consumption-preflight.json','rollback-filesystem-intent.json','rollback-result-accepted.json')){Write-AuthWireStagingJournal (Join-Path $job $n) ([pscustomobject]@{fixture=$n})}
 foreach($n in @('intent.json','complete.json')){Write-AuthWireStagingJournal (Join-Path $engine $n) ([pscustomobject]@{fixture=$n})}
 Write-AuthWireStagingJournal (Join-Path $stageDir 'original.json') ([pscustomobject]@{stage=$stage})
 $anchor=Get-AuthWireRollbackReservationPath $root $stage;Write-AuthWireStagingJournal $anchor ([pscustomobject]@{job_id=$jobId;stage_job_id=$stage})
 $gpoLock=Join-Path $root ('gpo-'+$gpoId+'.json');Write-AuthWireStagingJournal $gpoLock ([pscustomobject]@{job_id=$stage})
 $launch=[pscustomobject]@{format='AuthWireRollbackLaunchV1';job_id=$jobId;stage_operation_id=$op;execution_intent_sha256=$original.IntentSha256;authorization_sha256=$authorization.AuthorizationSha256;gate_name=('Local\AuthWireRollback-'+([guid]$jobId).ToString('N')+'-'+[guid]::NewGuid().ToString('N'));started_at=($now-40);expires_at=$intent.expires_at;work_budget_ms=6000}
 Write-AuthWireStagingJournal (Join-Path $job 'rollback-launch.json') $launch
 Write-AuthWireStagingJournal (Join-Path $job 'rollback-child.json') ([pscustomobject]@{format='AuthWireRollbackChildIdentityV1';job_id=$jobId;launch_sha256=(Get-AuthWireWriteHash $launch);process_id=2147483647;process_started_ticks=[DateTime]::UtcNow.Ticks.ToString()})
 Write-AuthWireStagingJournal (Join-Path $job 'rollback-execution-requires-review.json') ([pscustomobject]@{format='AuthWireRollbackReviewV1';job_id=$jobId;execution_intent_sha256=$original.IntentSha256;reason='OUTCOME_REQUIRES_REVIEW';checked_at=($now-33);diagnostic=[pscustomobject]@{timed_out=$true}})
 $box=[pscustomobject]@{body_sha256=('5'*64);body=[pscustomobject]@{outcome='requires_review';reason='OUTCOME_UNKNOWN';filesystem_effects='unconfirmed';authorization_id=[guid]::NewGuid().ToString('D')}}
 Write-AuthWireStagingJournal (Join-Path $job 'rollback-result-outbox.json') $box
 Write-AuthWireStagingJournal (Join-Path $slot 'completion.json') ([pscustomobject]@{outcome='requires_review';completed_at=($now-31)})
 function Read-AuthWireLifecycleHistory {return [pscustomobject]@{Life=$life;ActiveStates=@($state);States=@($state)}}
 function Read-AuthWireLifecycleCompletion {return (Read-AuthWireStagingJournal (Join-Path $slot 'completion.json'))}
 function Read-AuthWireAuthorizedRollbackIntentEvidence {return $original}
 function Read-AuthWireRollbackResultOutbox {return (Read-AuthWireStagingJournal (Join-Path $job 'rollback-result-outbox.json'))}
 function Get-AuthWireLifecycleOutcomeEvidence {return [pscustomobject]@{Outcome='requires_review';BodySha256=('5'*64);AckSha256=('6'*64)}}
 $parameters=[Security.Cryptography.CngKeyCreationParameters]::new();$parameters.KeyUsage=[Security.Cryptography.CngKeyUsages]::Signing;$parameters.ExportPolicy=[Security.Cryptography.CngExportPolicies]::None
 $key=[Security.Cryptography.CngKey]::Create([Security.Cryptography.CngAlgorithm]::Rsa,('AuthWire-ConsumedRetireFixture-'+[guid]::NewGuid().ToString('N')),$parameters);$rsa=[Security.Cryptography.RSACng]::new($key)
 $body=[pscustomobject]@{format='AuthWireRollbackReadOnlyObservationV1';job_id=$jobId;stage_job_id=$stage;stage_operation_id=$op;active_release=$release;authority_expired=$true;intent_sha256=$original.IntentSha256;original_child_running=$false;entered_marker_exists=$false;engine_markers=[pscustomobject]@{'rolled-back.json'=$false;'rollback-started.json'=$false};tree_sha256=$tree;outside_baseline_sha256=$baseline;tree_rows=$rowCount;staged_tree_unchanged=$true;outside_unchanged=$true;read_only=$true;can_delete=$false;authority_renewed=$false;at=($now-20)}
 $frame=[Text.Encoding]::UTF8.GetBytes('AUTHWIRE-ROLLBACK-READONLY-OBSERVATION-V1'+[char]10+(ConvertTo-AuthWireWriteJson $body))
 $observation=[pscustomobject]@{domain='AUTHWIRE-ROLLBACK-READONLY-OBSERVATION-V1';body=$body;signature=[Convert]::ToBase64String($rsa.SignData($frame,[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1))}
 Assert-AuthWireRollbackReadOnlyObservation $observation $original $rsa;Check $true 'existing signed observation validates without resigning or replay'
 foreach($field in @('job_id','intent_sha256','tree_sha256','active_release')){$bad=Clone $observation;$bad.body.$field='changed';Reject {Get-AuthWireConsumedRollbackRetirementReview $root $jobId $b $rsa $bad} ('tampered observation '+$field)}
 $bad=Clone $observation;$bad.body.authority_expired=$false;Reject {Get-AuthWireConsumedRollbackRetirementReview $root $jobId $b $rsa $bad} 'observation cannot renew authority'
 $bad=Clone $observation;$bad.body.original_child_running=$true;Reject {Get-AuthWireConsumedRollbackRetirementReview $root $jobId $b $rsa $bad} 'active-child assertion cannot pass'
 $path=Join-Path $job 'rollback-grant-consumed.json';$raw=[IO.File]::ReadAllBytes($path);[IO.File]::Delete($path)
 try{Reject {Get-AuthWireConsumedRollbackRetirementReview $root $jobId $b $rsa $observation} 'missing consumed grant fails before review'}finally{[IO.File]::WriteAllBytes($path,$raw)}
 $entered=Join-Path $job 'rollback-entered.json';[IO.File]::WriteAllText($entered,'{}')
 try{Reject {Get-AuthWireConsumedRollbackRetirementReview $root $jobId $b $rsa $observation} 'entry or unknown history remains blocked'}finally{[IO.File]::Delete($entered)}
 $marker=Join-Path $engine 'rollback-started.json';[IO.File]::WriteAllText($marker,'{}')
 try{Reject {Get-AuthWireConsumedRollbackRetirementReview $root $jobId $b $rsa $observation} 'engine start excludes not-entered retirement'}finally{[IO.File]::Delete($marker)}
 $payload=Join-Path $dest 'payload.ps1';$raw=[IO.File]::ReadAllBytes($payload);[IO.File]::WriteAllText($payload,'drift')
 try{Reject {Get-AuthWireConsumedRollbackRetirementReview $root $jobId $b $rsa $observation} 'actual staged NTFS bytes must match'}finally{[IO.File]::WriteAllBytes($payload,$raw)}
 $foreign=Join-Path $gpo 'foreign.txt';[IO.File]::WriteAllText($foreign,'drift')
 try{Reject {Get-AuthWireConsumedRollbackRetirementReview $root $jobId $b $rsa $observation} 'actual outside inventory must match'}finally{[IO.File]::Delete($foreign)}
 $review=Get-AuthWireConsumedRollbackRetirementReview $root $jobId $b $rsa $observation
 Check ($review.Proof.Body.filesystem_effects -ceq 'unconfirmed' -and $review.Proof.Body.original_outcome -ceq 'requires_review' -and -not $review.Proof.Body.can_delete) 'review never upgrades unknown history to success or no effects'
 Reject {Assert-AuthWireRollbackRetirementProof $review.Proof $rsa 'AUTHWIRE-REFUSED-ROLLBACK-RETIRE-REVIEW-V1'} 'consumed review cannot be used as a pre-authority refusal review'
 $receipt=[pscustomobject]@{job_id=$jobId;decision='acknowledge_saved_result';decision_recorded=$true;revision=11;approval_enabled=$false;write_authorization_enabled=$false;execution_adapter_available=$false;can_apply_gpo=$false}
 $ack=[pscustomobject]@{expected_revision=10;evidence=$review.Evidence;decision='acknowledge_saved_result';review_hash=('7'*64);acknowledge='record_reconciliation_decision'}
 $session=ConvertTo-SecureString ('c'*43) -AsPlainText -Force;$csrf=ConvertTo-SecureString ('d'*43) -AsPlainText -Force
 $script:ackCalls=0;$script:deny=$true;$script:driftAfterAck=$false
 function Confirm-AuthWireRollbackRetirementAcknowledgement {
  $script:ackCalls++;if($script:deny){throw 'FIXTURE_CURRENT_SESSION_DENIED'}
  Reject {[IO.File]::WriteAllText($payload,'changed')} 'real staged file remains write-locked during HTTPS acknowledgement'
  if($script:driftAfterAck){[IO.File]::WriteAllText($foreign,'new after ack')}
  return $receipt
 }
 $ackWord='retire_consumed_rollback_preserve_unknown_outcome'
 Reject {Complete-AuthWireConsumedRollbackRetirement $root $jobId $b $rsa 'https://fixture.example/' $review $ack $session $csrf 'retire_refused_rollback_without_replay'} 'refusal acknowledgement cannot close consumed intent'
 Check ($script:ackCalls -eq 0) 'wrong acknowledgement rejected before HTTP'
 Reject {Complete-AuthWireConsumedRollbackRetirement $root $jobId $b $rsa 'https://fixture.example/' $review $ack $session $csrf $ackWord} 'current privileged session still required'
 $reviewPath=Join-Path $job 'rollback-consumed-retirement-review.json';$closedPath=Join-Path $job 'rollback-consumed-retirement-complete.json'
 Check (-not (Test-Path $reviewPath)) 'failed HTTPS cannot append closure'
 $script:deny=$false;$script:driftAfterAck=$true
 try{Reject {Complete-AuthWireConsumedRollbackRetirement $root $jobId $b $rsa 'https://fixture.example/' $review $ack $session $csrf $ackWord} 'new outside drift after HTTPS blocks finalization'}finally{[IO.File]::Delete($foreign);$script:driftAfterAck=$false}
 Check (-not (Test-Path $reviewPath)) 'post-ack drift leaves old barrier intact'
 $frozen=@{};foreach($f in @(Get-ChildItem $job -File)+@(Get-Item $anchor,$gpoLock)){$frozen[$f.FullName]=[IO.File]::ReadAllBytes($f.FullName)}
 $closed=Complete-AuthWireConsumedRollbackRetirement $root $jobId $b $rsa 'https://fixture.example/' $review $ack $session $csrf $ackWord
 Check (Test-AuthWireConsumedRollbackRetired $root $life $state $b $rsa) 'distinct signed append-only completion validates'
 Check ($closed.Body.original_unknown_result_preserved -and $closed.Body.original_reservation_retained -and $closed.Body.gpo_lock_retained -and -not $closed.Body.authority_renewed -and -not $closed.Body.can_delete) 'completion preserves result reservation lock and expired authority'
 foreach($f in $frozen.Keys){Check ([Convert]::ToBase64String([IO.File]::ReadAllBytes($f)) -ceq [Convert]::ToBase64String($frozen[$f])) 'original journal and reservation bytes retained'}
 $calls=$script:ackCalls;Reject {Complete-AuthWireConsumedRollbackRetirement $root $jobId $b $rsa 'https://fixture.example/' $review $ack $session $csrf $ackWord} 'closure never replays';Check ($calls -eq $script:ackCalls) 'replay refused before HTTP'
 $saved=[IO.File]::ReadAllBytes($closedPath);[IO.File]::Delete($closedPath)
 try{Check (-not (Test-AuthWireConsumedRollbackRetired $root $life $state $b $rsa)) 'partial closure cannot permit continuation'}finally{[IO.File]::WriteAllBytes($closedPath,$saved)}
 $path=Join-Path $job 'rollback-grant-consumed.json';$saved=[IO.File]::ReadAllBytes($path);[IO.File]::WriteAllText($path,'{"changed":true}')
 try{Reject {Test-AuthWireConsumedRollbackRetired $root $life $state $b $rsa} 'changed original consumed grant invalidates signed closure'}finally{[IO.File]::WriteAllBytes($path,$saved)}
 $wrong=[Security.Cryptography.CngKey]::Create([Security.Cryptography.CngAlgorithm]::Rsa,('AuthWire-WrongConsumedRetire-'+[guid]::NewGuid().ToString('N')),$parameters);$wrongRsa=[Security.Cryptography.RSACng]::new($wrong)
 Reject {Test-AuthWireConsumedRollbackRetired $root $life $state $b $wrongRsa} 'another CNG key cannot inherit closure'
 $stream=[IO.File]::Open($payload,[IO.FileMode]::Open,[IO.FileAccess]::Write,[IO.FileShare]::ReadWrite);$stream.Dispose();Check $true 'all native pins released after success and failure'
 # A separately approved later rollback can change live tree state. Historical
 # retirement remains a preserved proof of its original observation, never a
 # new live authorization or an assertion that the old RESULT was successful.
 [IO.File]::WriteAllText($marker,'{"later_job":true}');[IO.File]::Delete($payload)
 Check (Test-AuthWireConsumedRollbackRetired $root $life $state $b $rsa) 'historical validation does not reopen a consumed rollback after later changes'
 Write-Host ('AUTHWIRE_CONSUMED_ROLLBACK_RETIREMENT_OK checks='+$script:checks+' native_cng_ntfs=true immutable_unknown_result=true simulated_original_authority_and_admin_https=true')
}catch{Write-Host $_.ScriptStackTrace;throw}finally{
 if($wrongRsa){$wrongRsa.Dispose()};if($wrong){$wrong.Delete();$wrong.Dispose()};if($rsa){$rsa.Dispose()};if($key){$key.Delete();$key.Dispose()}
 foreach($p in @($root,$gpo)){if(Test-Path -LiteralPath $p){Remove-Item -LiteralPath $p -Recurse -Force}}
}
