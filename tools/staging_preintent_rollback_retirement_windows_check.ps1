#Requires -Version 5.1
# Real CNG signatures, NTFS pins, immutable records and current tree/outside
# checks. Historical transport/origin and privileged HTTPS are explicit seams.
$ErrorActionPreference='Stop';Set-StrictMode -Version 2
$lib=Join-Path $PSScriptRoot '..\windows\connector'
. (Join-Path $lib 'Test-AuthWireDeploymentCandidate.ps1') -LibraryOnly
foreach($n in @('Invoke-AuthWireConnectorProbeJob.ps1','DeploymentScope.ps1','CombinedDeploymentScope.ps1','SysvolInventory.ps1','StagingFilesystem.ps1','StagingWritePreclaim.ps1','StagingWriteTransport.ps1','StagingWriteExecution.ps1','StagingWriteCycle.ps1','StagingRollbackAuthorization.ps1','StagingRollbackEvidence.ps1','StagingRollbackExecution.ps1','StagingRollbackResult.ps1','StagingWriteHistory.ps1')){. (Join-Path $lib $n)}
Initialize-AuthWireStagingFilesystemTypes
$checks=0
function Check($Value,[string]$Name){if(-not $Value){throw ('PREINTENT_RETIRE_FIXTURE:'+ $Name)};$script:checks++}
function Reject([scriptblock]$Action,[string]$Name){$failed=$false;try{& $Action|Out-Null}catch{$failed=$true};Check $failed $Name}
function Clone($Value){return ($Value|ConvertTo-Json -Depth 32 -Compress|ConvertFrom-Json)}
$root=$env:SystemDrive+'\aw-pir-'+[guid]::NewGuid().ToString('N').Substring(0,8);$gpo=$root+'-gpo';$key=$null;$rsa=$null;$wrong=$null
try{
 $now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds();$release=[guid]::NewGuid().ToString('D');$jobId=[guid]::NewGuid().ToString('D');$stage=[guid]::NewGuid().ToString('D');$op=[guid]::NewGuid().ToString('D');$gpoId=[guid]::NewGuid().ToString('D')
 $b=@{connector_id=[guid]::NewGuid().ToString('D');service_sid='S-1-5-21-1-2-3-1001'}
 $job=Join-Path $root $jobId;$engine=Join-Path $root $op;$stageDir=Join-Path $root $stage;$life=Join-Path $root 'write-lifecycle';$slot=Join-Path $life '000001';$dest=Join-Path $gpo 'Machine\AuthWire-fixture'
 foreach($dir in @($job,$engine,$stageDir,$slot,$dest)){[IO.Directory]::CreateDirectory($dir)|Out-Null}
 $payload=Join-Path $dest 'payload.ps1';[IO.File]::WriteAllText($payload,'# bytes never executed');[IO.File]::WriteAllText((Join-Path $gpo 'gpt.ini'),'[General]')
 function Get-AuthWireJobScope {return ('1'*64)}
 function Assert-AuthWireRollbackReaderIdentity { }
 function Assert-AuthWireStagingWriteJournalLocation($Path){if($Path -cne $root){throw 'FIXTURE_ROOT_CHANGED'}}
 function Add-AuthWireStagingGpoPins($Pins,$Path){$Pins.PinStableAncestors($Path)}
 function Assert-AuthWireNoActiveStage { }
 function Assert-AuthWireNoActiveRollback { }
 $lease=[AuthWire.Staging.TreeLeaseV1]::Tree($dest,$false)
 try{$tree=Get-AuthWireStagingFilesystemDigest (Get-AuthWireStagingFilesystemRows $lease)}finally{$lease.Dispose()}
 $inventory=Get-AuthWireSysvolInventory $gpo;$relative='Machine/AuthWire-fixture';$outside=@($inventory.Entries|Where-Object {$_.Path -cne $relative -and -not $_.Path.StartsWith($relative+'/',[StringComparison]::Ordinal)});$baseline=Get-AuthWireScopeDataHash $outside
 $origin=[pscustomobject]@{StageJobId=$stage;StageReleaseId=$release;FilesystemOperationId=$op;ChainSha256=('2'*64);Complete=[pscustomobject]@{tree_sha256=$tree};Intent=[pscustomobject]@{gpo_root=$gpo;relative_destination=$relative;baseline_sha256=$baseline}}
 $offer=[pscustomobject]@{job_id=$jobId;operation='combined.filesystem.rollback.v1';intent_sha256=('3'*64);expires_at=($now-30);target=[pscustomobject]@{stage_receipt=[pscustomobject]@{stage_job_id=$stage};scope_target=[pscustomobject]@{gpo_id=$gpoId}}}
 $state=[pscustomobject]@{Phase='reply_saved';Slot='000001';Offer=$offer;Started=[pscustomobject]@{release_id=$release}}
 $a=[pscustomobject]@{Offer=$offer;Origin=$origin;Receipt=[pscustomobject]@{release_id=$release;received_at=($now-60);grant=[pscustomobject]@{authorization_id=('a'*64);expires_at=($now-30)}};AuthorizationSha256=('4'*64);Reservation=[pscustomobject]@{job_id=$jobId;stage_job_id=$stage}}
 foreach($n in @('rollback-offer.json','rollback-preflight.json','rollback-claim-started.json','rollback-claim-proof.json','rollback-claim-sent.json','rollback-authorization.json','rollback-result-accepted.json')){Write-AuthWireStagingJournal (Join-Path $job $n) ([pscustomobject]@{fixture=$n})}
 $consumed=[pscustomobject]@{format='AuthWireRollbackGrantConsumedV1';binding_scope=('1'*64);release_id=$release;job_id=$jobId;stage_job_id=$stage;stage_operation_id=$op;authorization_sha256=('4'*64);origin_chain_sha256=('2'*64);consumed_at=($now-50);expires_at=($now-30)}
 $consumedPath=Join-Path $job 'rollback-grant-consumed.json';Write-AuthWireStagingJournal $consumedPath $consumed
 foreach($n in @('intent.json','complete.json')){Write-AuthWireStagingJournal (Join-Path $engine $n) ([pscustomobject]@{fixture=$n})}
 Write-AuthWireStagingJournal (Join-Path $stageDir 'original.json') ([pscustomobject]@{stage=$stage})
 $anchor=Get-AuthWireRollbackReservationPath $root $stage;Write-AuthWireStagingJournal $anchor ([pscustomobject]@{job_id=$jobId;stage_job_id=$stage})
 $gpoLock=Join-Path $root ('gpo-'+$gpoId+'.json');Write-AuthWireStagingJournal $gpoLock ([pscustomobject]@{job_id=$stage})
 $box=[pscustomobject]@{body_sha256=('5'*64);body=[pscustomobject]@{outcome='requires_review';reason='OUTCOME_UNKNOWN';filesystem_effects='unconfirmed';authorization_id=('a'*64)}}
 Write-AuthWireStagingJournal (Join-Path $job 'rollback-result-outbox.json') $box
 Write-AuthWireStagingJournal (Join-Path $slot 'completion.json') ([pscustomobject]@{outcome='requires_review';completed_at=($now-25)})
 Write-AuthWireStagingJournal (Join-Path $slot 'dispatch-failed.json') ([pscustomobject]@{format='AuthWireLifecycleDispatchFailedV1';phase='execute';checked_at=($now-40)})
 function Read-AuthWireLifecycleHistory {return [pscustomobject]@{Life=$life;ActiveStates=@($state);States=@($state)}}
 function Read-AuthWireLifecycleCompletion {return (Read-AuthWireStagingJournal (Join-Path $slot 'completion.json'))}
 function Read-AuthWireRollbackAuthorizationEvidence {return $a}
 function Read-AuthWireRollbackResultOutbox {return (Read-AuthWireStagingJournal (Join-Path $job 'rollback-result-outbox.json'))}
 function Get-AuthWireLifecycleOutcomeEvidence {return [pscustomobject]@{Outcome='requires_review';BodySha256=('5'*64);AckSha256=('6'*64)}}
 $parameters=[Security.Cryptography.CngKeyCreationParameters]::new();$parameters.KeyUsage=[Security.Cryptography.CngKeyUsages]::Signing;$parameters.ExportPolicy=[Security.Cryptography.CngExportPolicies]::None
 $key=[Security.Cryptography.CngKey]::Create([Security.Cryptography.CngAlgorithm]::Rsa,('AuthWire-PreIntentFixture-'+[guid]::NewGuid().ToString('N')),$parameters);$rsa=[Security.Cryptography.RSACng]::new($key)
 $review=Get-AuthWirePreIntentRollbackRetirementReview $root $jobId $b $rsa
 Check ($review.Proof.Body.filesystem_intent_absent -and $review.Proof.Body.filesystem_effects -ceq 'unconfirmed' -and -not $review.Proof.Body.can_delete) 'separate pre-intent review preserves original unknown outcome'
 foreach($domain in @('AUTHWIRE-CONSUMED-ROLLBACK-RETIRE-REVIEW-V1','AUTHWIRE-REFUSED-ROLLBACK-RETIRE-REVIEW-V1')){Reject {Assert-AuthWireRollbackRetirementProof $review.Proof $rsa $domain} 'old retirement domains cannot validate new proof'}
 foreach($n in @('rollback-consumption-preflight.json','rollback-filesystem-intent.json','rollback-launch.json','rollback-child.json','rollback-entered.json','rollback-execution-requires-review.json','unknown.json')){
  $p=Join-Path $job $n;[IO.File]::WriteAllText($p,'{}');try{Reject {Get-AuthWirePreIntentRollbackRetirementReview $root $jobId $b $rsa} ('existing execution or unknown file blocks '+$n)}finally{[IO.File]::Delete($p)}
 }
 foreach($n in @('rollback-started.json','rolled-back.json')){$p=Join-Path $engine $n;[IO.File]::WriteAllText($p,'{}');try{Reject {Get-AuthWirePreIntentRollbackRetirementReview $root $jobId $b $rsa} 'engine entry blocks pre-intent review'}finally{[IO.File]::Delete($p)}}
 $raw=[IO.File]::ReadAllBytes($consumedPath);[IO.File]::Delete($consumedPath);try{Reject {Get-AuthWirePreIntentRollbackRetirementReview $root $jobId $b $rsa} 'missing consumption cannot be inferred'}finally{[IO.File]::WriteAllBytes($consumedPath,$raw)}
 foreach($field in @('job_id','authorization_sha256','origin_chain_sha256','binding_scope','release_id')){
  $bad=Clone $consumed;$bad.$field='changed';[IO.File]::WriteAllText($consumedPath,($bad|ConvertTo-Json -Compress));try{Reject {Get-AuthWirePreIntentRollbackRetirementReview $root $jobId $b $rsa} ('consumption bound '+$field)}finally{[IO.File]::WriteAllBytes($consumedPath,$raw)}
 }
 $original=[IO.File]::ReadAllBytes($payload);[IO.File]::WriteAllText($payload,'drift');try{Reject {Get-AuthWirePreIntentRollbackRetirementReview $root $jobId $b $rsa} 'current staged NTFS bytes must match'}finally{[IO.File]::WriteAllBytes($payload,$original)}
 $foreign=Join-Path $gpo 'foreign.txt';[IO.File]::WriteAllText($foreign,'drift');try{Reject {Get-AuthWirePreIntentRollbackRetirementReview $root $jobId $b $rsa} 'current outside baseline must match'}finally{[IO.File]::Delete($foreign)}
 $receipt=[pscustomobject]@{job_id=$jobId;decision='acknowledge_saved_result';decision_recorded=$true;revision=11;approval_enabled=$false;write_authorization_enabled=$false;execution_adapter_available=$false;can_apply_gpo=$false}
 $ack=[pscustomobject]@{expected_revision=10;evidence=$review.Evidence;decision='acknowledge_saved_result';review_hash=('7'*64);acknowledge='record_reconciliation_decision'}
 $session=ConvertTo-SecureString ('c'*43) -AsPlainText -Force;$csrf=ConvertTo-SecureString ('d'*43) -AsPlainText -Force;$script:calls=0;$script:deny=$true;$script:drift=$false
 function Confirm-AuthWireRollbackRetirementAcknowledgement {
  $script:calls++;if($script:deny){throw 'FIXTURE_CURRENT_SESSION_DENIED'}
  Reject {[IO.File]::WriteAllText($payload,'changed')} 'staged bytes remain pinned during ACK'
  Reject {[IO.File]::WriteAllText($consumedPath,'changed')} 'consumption remains pinned during ACK'
  if($script:drift){[IO.File]::WriteAllText($foreign,'after ACK')};return $receipt
 }
 $word='retire_consumed_rollback_before_intent_preserve_unknown_outcome'
 Reject {Complete-AuthWirePreIntentRollbackRetirement $root $jobId $b $rsa 'https://fixture/' $review $ack $session $csrf 'retire_consumed_rollback_preserve_unknown_outcome'} 'old acknowledgement cannot retire missing-intent case'
 Check ($script:calls -eq 0) 'wrong acknowledgement refused before HTTP'
 Reject {Complete-AuthWirePreIntentRollbackRetirement $root $jobId $b $rsa 'https://fixture/' $review $ack $session $csrf $word} 'fresh session still required'
 $script:deny=$false;$script:drift=$true;try{Reject {Complete-AuthWirePreIntentRollbackRetirement $root $jobId $b $rsa 'https://fixture/' $review $ack $session $csrf $word} 'drift after ACK prevents local closure'}finally{[IO.File]::Delete($foreign);$script:drift=$false}
 $reviewPath=Join-Path $job 'rollback-preintent-retirement-review.json';$closedPath=Join-Path $job 'rollback-preintent-retirement-complete.json';Check (-not(Test-Path $reviewPath)) 'failed ACK/drift appends no closure'
 $review=Get-AuthWirePreIntentRollbackRetirementReview $root $jobId $b $rsa;$ack.evidence=$review.Evidence
 $frozen=@{};foreach($f in @(Get-ChildItem $root -Recurse -File)){$frozen[$f.FullName]=[IO.File]::ReadAllBytes($f.FullName)}
 $closed=Complete-AuthWirePreIntentRollbackRetirement $root $jobId $b $rsa 'https://fixture/' $review $ack $session $csrf $word
 Check (Test-AuthWirePreIntentRollbackRetired $root $life $state $b $rsa) 'separate paired CNG closure validates historical originals'
 Check (Test-AuthWireHistoryAcceptedOutcome $root $life $state ([pscustomobject]@{outcome='requires_review'}) $b $rsa) 'complete exact signed retirement is eligible for both active and archived history'
 Check ($closed.Body.original_unknown_result_preserved -and $closed.Body.filesystem_intent_absent -and -not $closed.Body.authority_renewed) 'unknown result and consumed grant stay unchanged'
 foreach($f in $frozen.Keys){Check ([Convert]::ToBase64String([IO.File]::ReadAllBytes($f)) -ceq [Convert]::ToBase64String($frozen[$f])) 'original record bytes unchanged'}
 $calls=$script:calls;Reject {Complete-AuthWirePreIntentRollbackRetirement $root $jobId $b $rsa 'https://fixture/' $review $ack $session $csrf $word} 'closure never replays';Check ($calls -eq $script:calls) 'replay refused before HTTP'
 $anchorBytes=[IO.File]::ReadAllBytes($anchor);$badAnchor=Get-Content $anchor -Raw|ConvertFrom-Json;$badAnchor.job_id=[guid]::NewGuid().ToString('D');[IO.File]::WriteAllText($anchor,($badAnchor|ConvertTo-Json -Compress));try{Reject {Test-AuthWirePreIntentRollbackRetired $root $life $state $b $rsa} 'original root reservation is frozen as well as per-job reservation'}finally{[IO.File]::WriteAllBytes($anchor,$anchorBytes)}
 $bytes=[IO.File]::ReadAllBytes($closedPath);[IO.File]::Delete($closedPath);try{Check (-not(Test-AuthWirePreIntentRollbackRetired $root $life $state $b $rsa)) 'partial closure remains blocked'}finally{[IO.File]::WriteAllBytes($closedPath,$bytes)}
 $bad=Clone $closed;$bad.Body.authority_renewed=$true;[IO.File]::WriteAllText($closedPath,($bad|ConvertTo-Json -Depth 16 -Compress));try{Reject {Test-AuthWirePreIntentRollbackRetired $root $life $state $b $rsa} 'tampered closure rejected'}finally{[IO.File]::WriteAllBytes($closedPath,$bytes)}
 Remove-Item $dest -Recurse -Force;[IO.File]::WriteAllText((Join-Path $engine 'rollback-started.json'),'later separately authorized rollback')
 Check (Test-AuthWirePreIntentRollbackRetired $root $life $state $b $rsa) 'later separately authorized live effects do not renew or invalidate frozen historical proof'
 [pscustomobject]@{status='preintent_retirement_passed';checks=$checks;new_write_authority=$false}|ConvertTo-Json -Compress
}finally{
 if($rsa){$rsa.Dispose()};if($key){$key.Delete();$key.Dispose()};foreach($p in @($root,$gpo)){if(Test-Path $p){Remove-Item $p -Recurse -Force}}
}

