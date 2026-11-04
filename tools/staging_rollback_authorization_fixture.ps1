# Only inside disposable native fixture after actual stage + accepted RESULT.
# Rollback review/create/POLL/CLAIM are real core bodies; AD/content is simulated.
$rbRoot=Get-AuthWireStagingWriteJournalRoot $b
$rbStage=Join-Path $rbRoot $id
$rbStageIntent=Read-AuthWireStagingJournal (Join-Path $rbStage 'filesystem-intent.json')
$rbEngine=Join-Path $rbRoot $rbStageIntent.filesystem_operation_id
$rbBefore=(Get-AuthWireSysvolInventory $gpo).Sha256
$rbOriginal=@{}
foreach($rbFolder in @($rbStage,$rbEngine)){
 foreach($rbFile in Get-ChildItem -LiteralPath $rbFolder -File){$rbOriginal[$rbFile.FullName]=Get-AuthWireCandidateHash ([IO.File]::ReadAllBytes($rbFile.FullName))}
}
$rbLock=Join-Path $rbRoot ('gpo-'+$t.gpo_id+'.json');$rbLockHash=Get-AuthWireCandidateHash ([IO.File]::ReadAllBytes($rbLock))
$rbModePath=Join-Path $flowDirectory 'rollback-mode.json'
$rbId=[guid]::NewGuid().ToString('D')
[IO.File]::WriteAllText($rbModePath,(@{stage_job_id=$id;job_id=$rbId;actor=[guid]::NewGuid().ToString('D');case=$case}|ConvertTo-Json -Compress))
try{
 # Direct fixture POLL, not a product durable rollback cycle/worker.
 $rbPoll=New-AuthWireStagingWriteProof $b $rsa POLL @{capability='combined.filesystem.write.v1';release_id=$release}
 $rbRequest=[Text.Encoding]::ASCII.GetString([Convert]::FromBase64String($rbPoll.frame)).Split([char]10)[10]
 $rbRaw=[AuthWire.Connector.WriteTransportV1]::Post($url,$b.appliance_fqdn,$b.appliance_tls_sha256,'/api/connector/v1/staging-write/poll',(ConvertTo-AuthWireWriteJson $rbPoll))
 $rbOffer=ConvertFrom-AuthWireCandidateJson ([Text.UTF8Encoding]::new($false,$true).GetBytes($rbRaw))
 Assert-AuthWireWriteOffer $rbOffer $b $release $rbRequest
 Check ($rbOffer.job_id -ceq $rbId -and $rbOffer.operation -ceq 'combined.filesystem.rollback.v1' -and $rbOffer.target.stage_receipt.stage_job_id -ceq $id) 'real separate operator approval derives rollback from accepted original stage'
 Reject {Save-AuthWireRollbackOffer $offer $b $release $rsa $request} 'stage offer never becomes rollback authority'
 $null=Save-AuthWireRollbackOffer $rbOffer $b $release $rsa $rbRequest
 $rbJob=Join-Path $rbRoot $rbId
 Reject {Read-AuthWireStagingWriteOffer $rbRoot $rbId $b $release} 'stage reader rejects distinct rollback records'
 Reject {Read-AuthWireRollbackOffer $root $rbId $b $release} 'alternate root cannot hide original reservation'
 if($case -ceq 'rollback_success'){
  $rbReader=Join-Path $package 'Read-AuthWireRollbackPreflight.ps1';$rbReaderBytes=[IO.File]::ReadAllBytes($rbReader)
  try{
   [IO.File]::WriteAllText($rbReader,'throw ''unsigned fixture reader''')
   Reject {Invoke-AuthWireRollbackPreflight $rbRoot $rbId $b $release} 'AllSigned refuses substituted unsigned reader before claim'
   Check (-not (Test-Path -LiteralPath (Join-Path $rbJob 'rollback-preflight.json'))) 'failed reader grants no saved witness'
  }finally{[IO.File]::WriteAllBytes($rbReader,$rbReaderBytes)}
 }
 $rbWatch=[Diagnostics.Stopwatch]::StartNew()
 $null=Invoke-AuthWireRollbackPreflight $rbRoot $rbId $b $release
 $rbProofFailure='';try{$null=New-AuthWireRollbackClaim $rbRoot $rbId $b $release $rsa}catch{$rbProofFailure=$_.Exception.Message}
 if($case -ceq 'rollback_proof_disk'){
  Check ($rbProofFailure -ceq 'FIXTURE_ROLLBACK_PROOF_DISK' -and (Test-Path -LiteralPath (Join-Path $rbJob 'rollback-claim-started.json'))) 'proof failure preserves before-signing reservation'
  Reject {New-AuthWireRollbackClaim $rbRoot $rbId $b $release $rsa} 'failed proof cannot sign a second claim'
  Check (-not (Test-Path -LiteralPath (Join-Path $rbJob 'rollback-claim-sent.json'))) 'proof failure sends no network request'
 }else{
  if($rbProofFailure){throw $rbProofFailure}
  $rbSendFailure='';$rbGrant=$null
  try{$rbGrant=Invoke-AuthWireRollbackClaimTransport $rbRoot $rbId $b $release $rsa $url}catch{$rbSendFailure=$_.Exception.Message}
  if(-not (Test-Path -LiteralPath (Join-Path $rbJob 'rollback-claim-sent.json'))){
   $rbSafe=if($rbSendFailure -cin @('ROLLBACK_PREFLIGHT_REJECTED','WRITE_CLAIM_RECORD_REJECTED','WRITE_CLAIM_RECORD_STALE','WRITE_CLAIM_KEY_REJECTED','ROLLBACK_RECORD_CHANGED')){$rbSendFailure}else{'UNCLASSIFIED'}
   $rbObserved=Read-AuthWireStagingJournal (Join-Path $rbJob 'rollback-preflight.json')
   Write-Host ('ROLLBACK_SAFE_SEND_DIAGNOSTIC '+(@{code=$rbSafe;observation_age_seconds=([DateTimeOffset]::UtcNow.ToUnixTimeSeconds()-$rbObserved.checked_at);control_elapsed_ms=$rbWatch.ElapsedMilliseconds}|ConvertTo-Json -Compress))
  }
  Check (Test-Path -LiteralPath (Join-Path $rbJob 'rollback-claim-sent.json')) 'one-send record flushed before HTTPS'
  if($case -cin @('rollback_lost_grant','rollback_bad_grant','rollback_receipt_disk')){
   Check ($rbSendFailure -cne '' -and -not (Test-Path -LiteralPath (Join-Path $rbJob 'rollback-authorization.json'))) 'uncertain or altered grant creates no authorization receipt'
   Reject {Invoke-AuthWireRollbackClaimTransport $rbRoot $rbId $b $release $rsa $url} 'unknown claim outcome never retransmitted'
   Reject {New-AuthWireRollbackFilesystemIntent $rbRoot $rbId $b $release $rsa} 'absent durable receipt never consumes or records intent'
   Check (-not (Test-Path -LiteralPath (Join-Path $rbJob 'rollback-grant-consumed.json'))) 'no receipt means no local consumption'
  }else{
   if($rbSendFailure){throw $rbSendFailure}
   Check ($rbGrant.GrantRecorded -and -not $rbGrant.CanDelete -and -not $rbGrant.CanApplyGpo) 'separate grant is recorded without enabling deletion'
   if($case -ceq 'rollback_live_drift'){
    $fixture.rollback_drift=$true;[IO.File]::WriteAllText((Join-Path $package 'fixture.json'),($fixture|ConvertTo-Json -Depth 12 -Compress))
   }
   if($case -ceq 'rollback_expired'){Start-Sleep -Seconds 31}
   $rbUseFailure='';$rbUse=$null
   try{$rbUse=New-AuthWireRollbackFilesystemIntent $rbRoot $rbId $b $release $rsa}catch{$rbUseFailure=$_.Exception.Message}
   if($case -ceq 'rollback_success'){
    if($rbUseFailure){throw $rbUseFailure}
    Check ($rbUse.GrantConsumed -and -not $rbUse.RollbackExecuted -and -not $rbUse.CanDelete -and $rbUse.StageOperationId -ceq $rbStageIntent.filesystem_operation_id) 'one use binds original operation but never calls delete engine'
    $rbIntent=Read-AuthWireStagingJournal (Join-Path $rbJob 'rollback-filesystem-intent.json')
    $rbReceipt=Read-AuthWireStagingJournal (Join-Path $rbJob 'rollback-authorization.json')
    Check ($rbIntent.expires_at -eq $rbReceipt.grant.expires_at -and -not $rbIntent.can_delete) 'intent preserves exact original server deadline and false execution flag'
   }else{
    Check ($rbUseFailure -cne '' -and -not (Test-Path -LiteralPath (Join-Path $rbJob 'rollback-filesystem-intent.json'))) 'disk drift and expiry never yield successful intent'
    if($case -ceq 'rollback_expired'){
     Check (-not (Test-Path -LiteralPath (Join-Path $rbJob 'rollback-grant-consumed.json'))) 'expired authorization refused before consumption'
     $rbHistory=Read-AuthWireRollbackAuthorizationEvidence $rbRoot $rbId $b $release $rsa
     Check ($rbHistory.Receipt.grant.expires_at -lt [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()) 'historical receipt readable without renewed current authority'
    }else{Check (Test-Path -LiteralPath (Join-Path $rbJob 'rollback-grant-consumed.json')) 'post-consumption failure remains consumed for review'}
   }
   if($case -cne 'rollback_expired'){
    $rbReadPath=Join-Path $package ('rollback-reads-'+$rbId+'.txt');$rbReads=[IO.File]::ReadAllText($rbReadPath)
    Reject {New-AuthWireRollbackFilesystemIntent $rbRoot $rbId $b $release $rsa} 'success or uncertain consumption cannot be replayed'
    Check ([IO.File]::ReadAllText($rbReadPath) -ceq $rbReads) 'consumption replay refused before another signed live reader'
   }
   Reject {Read-AuthWireWriteAuthorizationEvidence $rbRoot $rbId $b $release $rsa} 'rollback receipt cannot authorize stage executor'
  }
 }
 Reject {New-AuthWireRollbackClaim $rbRoot $rbId $b $release $rsa} 'durable signing gate remains after every outcome'
 # Same-stage reservation is stable even if a different offered job ID is valid.
 $rbSecond=Clone $rbOffer;$rbSecond.job_id=[guid]::NewGuid().ToString('D');$rbSecond.expires_at=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()+85
 $rbFrame='AuthWireStagingWriteIntentV1'+[char]10+(Get-AuthWireJobScope $b)+[char]10+$rbSecond.job_id+[char]10+$rbSecond.operation+[char]10+(Get-AuthWireWriteHash $rbSecond.target)+[char]10
 $rbSecond.intent_sha256=Get-AuthWireJobHash ([Text.Encoding]::ASCII.GetBytes($rbFrame))
 Reject {Save-AuthWireRollbackOffer $rbSecond $b $release $rsa $rbSecond.request_id} 'new job ID cannot bypass same-original-stage reservation'
 Check ((Get-AuthWireSysvolInventory $gpo).Sha256 -ceq $rbBefore) 'all rollback authorization paths preserve entire staged SMB tree and ACL'
 Check ((Get-AuthWireCandidateHash ([IO.File]::ReadAllBytes($rbLock))) -ceq $rbLockHash) 'original durable GPO lock remains byte-identical'
 foreach($rbEntry in $rbOriginal.GetEnumerator()){Check ((Get-AuthWireCandidateHash ([IO.File]::ReadAllBytes($rbEntry.Key))) -ceq $rbEntry.Value) 'original stage authority observation and accepted result remain byte-identical'}
 Check (-not (Test-Path -LiteralPath (Join-Path $rbEngine 'rollback-started.json'))) 'no rollback engine or cleanup invoked'
 Write-Host ('ROLLBACK_AUTHORIZATION_CASE_OK case='+$case+' control_ms='+$rbWatch.ElapsedMilliseconds+' original_stage_preserved=true files_deleted=false')
}finally{[IO.File]::Delete($rbModePath)}
