# Invoked only inside the existing disposable signed CNG/TLS/SQLite/SMB fixture,
# after a real stage RESULT is accepted. AD/content/service-identity are explicit
# directory-observation shims. No product reset or fault hook is introduced.
$directoryBody=${function:Get-AuthWireRollbackDirectoryObservation}
$rootPath=Get-AuthWireStagingWriteJournalRoot $b
$stageJob=Join-Path $rootPath $id
$stageOutbox=Read-AuthWireStagingJournal (Join-Path $stageJob 'result-outbox.json')
$stageIntent=Read-AuthWireStagingJournal (Join-Path $stageJob 'filesystem-intent.json')
$enginePath=Join-Path $rootPath $stageIntent.filesystem_operation_id
$stageTree=Join-Path $gpo $preview.Preview.relative_destination.Replace('/','\')
$fixtureBefore=Get-AuthWireSysvolInventory $gpo
$originalProofFiles=@{}
foreach($folder in @($stageJob,$enginePath)){
 foreach($file in Get-ChildItem -LiteralPath $folder -File){$originalProofFiles[$file.FullName]=Get-AuthWireCandidateHash ([IO.File]::ReadAllBytes($file.FullName))}
}
$gpoLock=Join-Path $rootPath ('gpo-'+$t.gpo_id+'.json');$gpoLockBefore=[IO.File]::ReadAllBytes($gpoLock)
$oldPreview=Get-AuthWireWriteHash $preview
function NewRollbackOffer {
 $v=Clone $offer
 $v.job_id=[guid]::NewGuid().ToString('D');$v.request_id='7'*64;$v.lease_id='8'*64
 $v.operation='combined.filesystem.rollback.v1';$v.expires_at=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()+85
 $v.target.stage_receipt=[pscustomobject]@{stage_job_id=$id;complete_journal_sha256=$stageOutbox.body.journal_sha256;staged_tree_sha256=$stageOutbox.body.tree_sha256}
 $frame='AuthWireStagingWriteIntentV1'+"`n"+(Get-AuthWireJobScope $b)+"`n"+$v.job_id+"`n"+$v.operation+"`n"+(Get-AuthWireWriteHash $v.target)+"`n"
 $v.intent_sha256=Get-AuthWireJobHash ([Text.Encoding]::ASCII.GetBytes($frame))
 return $v
}
function RehashRollback($v){
 $frame='AuthWireStagingWriteIntentV1'+"`n"+(Get-AuthWireJobScope $b)+"`n"+$v.job_id+"`n"+$v.operation+"`n"+(Get-AuthWireWriteHash $v.target)+"`n"
 $v.intent_sha256=Get-AuthWireJobHash ([Text.Encoding]::ASCII.GetBytes($frame));return $v
}
$script:rollbackDirectoryDrift=$false;$script:rollbackDirectoryReads=0;$script:rollbackDirectoryDelay=$false
function Get-AuthWireRollbackDirectoryObservation($Offer,[hashtable]$Binding,[string]$Publisher,[string]$BaseUrl){
 $script:rollbackDirectoryReads++
 if($script:rollbackDirectoryDelay){Start-Sleep -Milliseconds 5100}
 return [pscustomobject]@{pdc=$(if($script:rollbackDirectoryDrift){'dc02.lab.example'}else{'dc01.lab.example'});gpo_root=$gpo;protected_gpo_id=$stageIntent.live_context.protected_gpo_id;scope_sha256=$Offer.target.preview_record.Preview.scope_observations_sha256}
}
try{
 $r=NewRollbackOffer
 # The production directory adapter rejects an administrator BEFORE AD/content
 # lookup. Restore it only for this negative native identity check.
 Set-Item Function:Get-AuthWireRollbackDirectoryObservation $directoryBody
 Reject {Get-AuthWireRollbackDirectoryObservation $r $b $signer.Thumbprint $url} 'rollback refuses administrator as customer service identity'
 function Get-AuthWireRollbackDirectoryObservation($Offer,[hashtable]$Binding,[string]$Publisher,[string]$BaseUrl){
  $script:rollbackDirectoryReads++
 if($script:rollbackDirectoryDelay){Start-Sleep -Milliseconds 5100}
  return [pscustomobject]@{pdc=$(if($script:rollbackDirectoryDrift){'dc02.lab.example'}else{'dc01.lab.example'});gpo_root=$gpo;protected_gpo_id=$stageIntent.live_context.protected_gpo_id;scope_sha256=$Offer.target.preview_record.Preview.scope_observations_sha256}
 }
 $rollbackWatch=[Diagnostics.Stopwatch]::StartNew();$w=Get-AuthWireRollbackPreflight $r $b $release $rsa $signer.Thumbprint $url;$rollbackWatch.Stop()
 Check ($w.format -ceq 'AuthWireRollbackPreflightV1' -and $w.stage_job_id -ceq $id -and $w.job_id -ceq $r.job_id -and $w.filesystem_operation_id -ceq $stageIntent.filesystem_operation_id) 'rollback binds exact observed original stage and distinct job'
 Check ($w.read_only -and $w.requires_separate_claim -and -not $w.write_authorized -and -not $w.can_delete -and -not $w.can_apply_gpo) 'rollback preflight grants no claim consumption or delete authority'
 Check ($w.complete_sha256 -ceq $stageOutbox.body.journal_sha256 -and $w.tree_sha256 -ceq $stageOutbox.body.tree_sha256 -and $w.expires_at-$w.checked_at -le 5) 'exact completion tree and short observation lifetime'
 Check ($script:rollbackDirectoryReads -ge 2 -and $rollbackWatch.Elapsed.TotalSeconds -lt 15) 'two independent directory observations within review budget'
 foreach($field in @('complete_journal_sha256','staged_tree_sha256')){
  $bad=NewRollbackOffer;$bad.target.stage_receipt.$field='0'*64;$bad=RehashRollback $bad
  Reject {Read-AuthWireRollbackOrigin $bad $b $release $rsa} ('rollback refuses different '+$field)
 }
 $bad=NewRollbackOffer;$bad.target.stage_receipt.stage_job_id=[guid]::NewGuid().ToString('D');$bad=RehashRollback $bad
 Reject {Read-AuthWireRollbackOrigin $bad $b $release $rsa} 'rollback cannot invent another original stage job'
 $bad=NewRollbackOffer;$bad.job_id=$id;$bad=RehashRollback $bad
 Reject {Read-AuthWireRollbackOrigin $bad $b $release $rsa} 'rollback requires a separate job identity'
 $bad=NewRollbackOffer;$bad.target.preview_job_id=[guid]::NewGuid().ToString('D');$bad=RehashRollback $bad
 Reject {Read-AuthWireRollbackOrigin $bad $b $release $rsa} 'rollback cannot substitute original preview lineage'
 $bad=NewRollbackOffer;$bad.target.scope_target.dependency_sha256='0'*64
 Reject {Read-AuthWireRollbackOrigin (RehashRollback $bad) $b $release $rsa} 'rollback target drift rejected'
 $wrongBinding=@{};foreach($name in $b.Keys){$wrongBinding[$name]=$b[$name]};$wrongBinding.generation++
 Reject {Read-AuthWireRollbackOrigin (NewRollbackOffer) $wrongBinding $release $rsa} 'new binding generation cannot inherit old stage authority'
 $bad=NewRollbackOffer;$bad.expires_at=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()-1
 Reject {Read-AuthWireRollbackOrigin $bad $b $release $rsa} 'expired rollback offer rejected'
 Reject {Read-AuthWireRollbackOrigin $offer $b $release $rsa} 'stage offer is not rollback approval'
 foreach($fileName in @('execution-observed.json','result-outbox.json','result-accepted.json')){
  $path=Join-Path $stageJob $fileName;$saved=[IO.File]::ReadAllBytes($path)
  try{[IO.File]::Delete($path);Reject {Read-AuthWireRollbackOrigin (NewRollbackOffer) $b $release $rsa} ('missing '+$fileName+' cannot authorize rollback')}finally{[IO.File]::WriteAllBytes($path,$saved)}
 }
 $ackPath=Join-Path $stageJob 'result-accepted.json';$saved=[IO.File]::ReadAllBytes($ackPath)
 try{
  $ack=Read-AuthWireStagingJournal $ackPath;$ack.body_sha256='0'*64;[IO.File]::WriteAllText($ackPath,($ack|ConvertTo-Json -Depth 8 -Compress))
  Reject {Read-AuthWireRollbackOrigin (NewRollbackOffer) $b $release $rsa} 'changed accepted result link rejected'
 }finally{[IO.File]::WriteAllBytes($ackPath,$saved)}
 $outboxPath=Join-Path $stageJob 'result-outbox.json';$saved=[IO.File]::ReadAllBytes($outboxPath)
 try{
  $box=Read-AuthWireStagingJournal $outboxPath;$box.body.outcome='requires_review';$box.body.reason='OUTCOME_UNKNOWN';$box.body.filesystem_effects='unconfirmed';$box.body.journal_sha256='';$box.body.tree_sha256='';$box.body_sha256=Get-AuthWireWriteHash $box.body
  [IO.File]::WriteAllText($outboxPath,($box|ConvertTo-Json -Depth 10 -Compress))
  Reject {Read-AuthWireRollbackOrigin (NewRollbackOffer) $b $release $rsa} 'review outbox cannot substitute an observed accepted stage result'
 }finally{[IO.File]::WriteAllBytes($outboxPath,$saved)}
 foreach($marker in @('rollback-started.json','rolled-back.json')){
  $path=Join-Path $enginePath $marker
  try{Write-AuthWireStagingJournal $path ([pscustomobject]@{fixture=$true});Reject {Read-AuthWireRollbackOrigin (NewRollbackOffer) $b $release $rsa} ('previous '+$marker+' blocks new rollback')}finally{[IO.File]::Delete($path)}
 }
 $path=Join-Path $stageJob 'execution-requires-review.json'
 try{Write-AuthWireStagingJournal $path ([pscustomobject]@{fixture=$true});Reject {Read-AuthWireRollbackOrigin (NewRollbackOffer) $b $release $rsa} 'review state cannot be promoted to rollback-ready'}finally{[IO.File]::Delete($path)}
 $file=Join-Path $stageTree 'README.txt';$saved=[IO.File]::ReadAllBytes($file)
 try{[IO.File]::WriteAllText($file,'changed');Reject {Get-AuthWireRollbackPreflight (NewRollbackOffer) $b $release $rsa $signer.Thumbprint $url} 'current staged bytes must still equal ownership journal'}finally{[IO.File]::WriteAllBytes($file,$saved)}
 $foreign=Join-Path $stageTree 'foreign.txt'
 try{[IO.File]::WriteAllText($foreign,'foreign');Reject {Get-AuthWireRollbackPreflight (NewRollbackOffer) $b $release $rsa $signer.Thumbprint $url} 'foreign descendant blocks rollback preflight'}finally{[IO.File]::Delete($foreign)}
 try{Set-Content -LiteralPath $file -Stream hidden -Value hidden;Reject {Get-AuthWireRollbackPreflight (NewRollbackOffer) $b $release $rsa $signer.Thumbprint $url} 'staged ADS blocks rollback preflight'}finally{Remove-Item -LiteralPath $file -Stream hidden}
 $acl=Get-Acl -LiteralPath $file
 try{$changed=Get-Acl -LiteralPath $file;$changed.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new([Security.Principal.SecurityIdentifier]::new('S-1-1-0'),'Read','Allow'));Set-Acl -LiteralPath $file -AclObject $changed;Reject {Get-AuthWireRollbackPreflight (NewRollbackOffer) $b $release $rsa $signer.Thumbprint $url} 'staged ACL drift blocks rollback preflight'}finally{Set-Acl -LiteralPath $file -AclObject $acl}
 $foreign=Join-Path $gpo 'User\foreign.txt'
 try{[IO.File]::WriteAllText($foreign,'outside');Reject {Get-AuthWireRollbackPreflight (NewRollbackOffer) $b $release $rsa $signer.Thumbprint $url} 'outside baseline drift blocks rollback preflight'}finally{[IO.File]::Delete($foreign)}
 $script:rollbackDirectoryDrift=$true
 try{Reject {Get-AuthWireRollbackPreflight (NewRollbackOffer) $b $release $rsa $signer.Thumbprint $url} 'PDC path drift cannot reuse original tree identity'}finally{$script:rollbackDirectoryDrift=$false}
 $script:rollbackDirectoryDelay=$true
 try{
  $expired='';try{Get-AuthWireRollbackPreflight (NewRollbackOffer) $b $release $rsa $signer.Thumbprint $url|Out-Null}catch{$expired=$_.Exception.Message}
  Check ($expired -ceq 'ROLLBACK_PREFLIGHT_EXPIRED') 'slow live observation is rejected instead of receiving a fresh end timestamp'
 }finally{$script:rollbackDirectoryDelay=$false}
 # The stage mutex/gate are still honored; no new rollback lock replaces them.
 $launch=Read-AuthWireStagingJournal (Join-Path $stageJob 'stage-launch.json')
 $event=[Threading.EventWaitHandle]::new($false,[Threading.EventResetMode]::AutoReset,$launch.gate_name)
 try{Reject {Read-AuthWireRollbackOrigin (NewRollbackOffer) $b $release $rsa} 'active stage gate blocks rollback evidence'}finally{$event.Dispose()}
 $w=Get-AuthWireRollbackPreflight (NewRollbackOffer) $b $release $rsa $signer.Thumbprint $url
 Check ($w.read_only -and $w.requires_separate_claim) 'restored disposable evidence verifies again without issuing authority'
 Check ((Get-AuthWireSysvolInventory $gpo).Sha256 -ceq $fixtureBefore.Sha256) 'all evidence/preflight reads preserve original SMB bytes and ACL'
 Check ([Convert]::ToBase64String([IO.File]::ReadAllBytes($gpoLock)) -ceq [Convert]::ToBase64String($gpoLockBefore)) 'original durable GPO lock never rewritten or unlocked'
 Check ((Get-AuthWireWriteHash $preview) -ceq $oldPreview) 'old preview timestamps never renewed'
 foreach($entry in $originalProofFiles.GetEnumerator()){Check ((Get-AuthWireCandidateHash ([IO.File]::ReadAllBytes($entry.Key))) -ceq $entry.Value) 'original proof and result journals preserved byte-for-byte'}
 Write-Host ('AUTHWIRE_ROLLBACK_EVIDENCE_WINDOWS_OK case='+$case+' preflight_ms='+$rollbackWatch.ElapsedMilliseconds+' actual_stage_and_accepted_result=true synthetic_rollback_offer=true directory_observation_simulated=true claim_sent=false files_deleted=false')
}finally{Set-Item Function:Get-AuthWireRollbackDirectoryObservation $directoryBody}
