# Source-only preclaim primitives. Not loaded by the permanent worker/package.
# No network send, filesystem executor, recovery deletion or GPO activation here.
Set-StrictMode -Version 2

function ConvertTo-AuthWireWriteJson($Value,[bool]$Sort=$true,[int]$Depth=0){
 if($Depth -gt 12){throw 'WRITE_JSON_DEPTH'}
 if($null -eq $Value){return 'null'}
 if($Value -is [bool]){if($Value){return 'true'}else{return 'false'}}
 if($Value -is [string]){
  if($Value -cmatch '[^\x20-\x7e]'){throw 'WRITE_ASCII_REQUIRED'}
  return ('"'+$Value.Replace('\','\\').Replace('"','\"')+'"')
 }
 if($Value -is [int] -or $Value -is [long]){return $Value.ToString([Globalization.CultureInfo]::InvariantCulture)}
 if($Value -is [array]){
  if($Value.Count -gt 64){throw 'WRITE_JSON_LIMIT'}
  $parts=@(foreach($v in $Value){ConvertTo-AuthWireWriteJson $v $Sort ($Depth+1)})
  return ('['+($parts -join ',')+']')
 }
 if($Value -is [Collections.IDictionary]){$names=[string[]]@($Value.Keys)}
 elseif($Value -is [pscustomobject]){$names=[string[]]@($Value.PSObject.Properties.Name)}
 else{throw 'WRITE_JSON_KIND'}
 if($names.Count -gt 40){throw 'WRITE_JSON_LIMIT'}
 if($Sort){[Array]::Sort($names,[StringComparer]::Ordinal)}
 $parts=@(foreach($n in $names){
  $v=if($Value -is [Collections.IDictionary]){$Value[$n]}else{$Value.$n}
  (ConvertTo-AuthWireWriteJson $n $false ($Depth+1))+':'+(ConvertTo-AuthWireWriteJson $v $Sort ($Depth+1))
 })
 return ('{'+($parts -join ',')+'}')
}
function Get-AuthWireWriteHash($Value){
 return (Get-AuthWireJobHash ([Text.Encoding]::ASCII.GetBytes((ConvertTo-AuthWireWriteJson $Value))))
}
function Test-AuthWireWriteHash($Value){return ($Value -is [string] -and $Value -cmatch '\A[0-9a-f]{64}\z')}
function Test-AuthWireWriteInteger($Value){return (($Value -is [int] -or $Value -is [long]) -and $Value -gt 0 -and $Value -lt 1099511627776)}
function ConvertTo-AuthWireWriteOrderedPreview($Preview){
 $ordered=[ordered]@{}
 $names=@('format','operation','scope_target_sha256','scope_observations_sha256','baseline_inventory_sha256','source_ledger_sha256','plan_id','plan_version','gpo_id','manifest_sha256','draft_sha256','relative_destination','files','file_count','total_bytes','checked_at','expires_at','rollback','read_only','can_stage','can_apply_gpo','writer_available','requires_new_write_approval')
 Assert-AuthWireCandidateFields $Preview $names
 foreach($n in $names){
  if($n -ceq 'files'){$ordered[$n]=@(foreach($r in $Preview.files){Assert-AuthWireCandidateFields $r @('Path','Size','Sha256','Sddl');$v=[ordered]@{};foreach($k in @('Path','Size','Sha256','Sddl')){$v[$k]=$r.$k};[pscustomobject]$v})}
  elseif($n -ceq 'rollback'){$fields=@('relative_directory','requires_ownership_journal','requires_exact_staged_tree','drift_requires_review','delete_existing_data');Assert-AuthWireCandidateFields $Preview.rollback $fields;$v=[ordered]@{};foreach($k in $fields){$v[$k]=$Preview.rollback.$k};$ordered[$n]=[pscustomobject]$v}
  else{$ordered[$n]=$Preview.$n}
 }
 return [pscustomobject]$ordered
}
function Get-AuthWireWritePreviewHash($Preview){
 $ordered=ConvertTo-AuthWireWriteOrderedPreview $Preview
 $json=ConvertTo-AuthWireWriteJson $ordered $false
 if([Text.Encoding]::ASCII.GetByteCount($json) -gt 14000){throw 'WRITE_PREVIEW_LIMIT'}
 return (Get-AuthWireJobHash ([Text.Encoding]::ASCII.GetBytes($json)))
}
function Assert-AuthWireWriteTarget($Target,[string]$Operation){
 Assert-AuthWireCandidateFields $Target @('scope_target','preview_record','preview_job_id','preview_result_sha256','writer_release_id','stage_receipt')
 Assert-AuthWireCombinedScopeTarget $Target.scope_target
 foreach($n in @('preview_job_id','writer_release_id')){Assert-AuthWireCandidateGuid $Target.$n}
 if(-not (Test-AuthWireWriteHash $Target.preview_result_sha256)){throw 'WRITE_TARGET_REJECTED'}
 Assert-AuthWireCandidateFields $Target.preview_record @('Preview','PreviewSha256')
 $p=$Target.preview_record.Preview;$t=$Target.scope_target
 Assert-AuthWireCandidateFields $p @('format','operation','scope_target_sha256','scope_observations_sha256','baseline_inventory_sha256','source_ledger_sha256','plan_id','plan_version','gpo_id','manifest_sha256','draft_sha256','relative_destination','files','file_count','total_bytes','checked_at','expires_at','rollback','read_only','can_stage','can_apply_gpo','writer_available','requires_new_write_approval')
 if($p.format -cne 'AuthWireCombinedStagingPreviewV1' -or $p.operation -cne 'combined.stage.preview.v1' -or
    $p.read_only -isnot [bool] -or -not $p.read_only -or $p.requires_new_write_approval -isnot [bool] -or -not $p.requires_new_write_approval){throw 'WRITE_PREVIEW_REJECTED'}
 foreach($n in @('can_stage','can_apply_gpo','writer_available')){if($p.$n -isnot [bool] -or $p.$n){throw 'WRITE_PREVIEW_REJECTED'}}
 foreach($n in @('scope_observations_sha256','baseline_inventory_sha256','source_ledger_sha256')){if(-not (Test-AuthWireWriteHash $p.$n)){throw 'WRITE_PREVIEW_REJECTED'}}
 if($p.scope_target_sha256 -cne (Get-AuthWireCombinedScopeTargetHash $t)){throw 'WRITE_PREVIEW_REJECTED'}
 foreach($n in @('plan_id','plan_version','gpo_id','manifest_sha256','draft_sha256')){if($p.$n.GetType() -ne $t.$n.GetType() -or $p.$n -cne $t.$n){throw 'WRITE_PREVIEW_REJECTED'}}
 if(-not (Test-AuthWireWriteInteger $p.checked_at) -or -not (Test-AuthWireWriteInteger $p.expires_at) -or $p.expires_at-$p.checked_at -ne 90){throw 'WRITE_PREVIEW_REJECTED'}
 $relative='Machine/AuthWire-'+([guid]$t.plan_id).ToString('N')+'-v'+$t.plan_version+'-'+$t.manifest_sha256
 if($p.relative_destination -cne $relative){throw 'WRITE_PREVIEW_REJECTED'}
 Assert-AuthWireCandidateFields $p.rollback @('relative_directory','requires_ownership_journal','requires_exact_staged_tree','drift_requires_review','delete_existing_data')
 if($p.rollback.relative_directory -cne $relative -or $p.rollback.delete_existing_data -isnot [bool] -or $p.rollback.delete_existing_data){throw 'WRITE_PREVIEW_REJECTED'}
 foreach($n in @('requires_ownership_journal','requires_exact_staged_tree','drift_requires_review')){if($p.rollback.$n -isnot [bool] -or -not $p.rollback.$n){throw 'WRITE_PREVIEW_REJECTED'}}
 $names=[string[]](Get-AuthWireCombinedStagingNames);[Array]::Sort($names,[StringComparer]::Ordinal)
 if($p.files -isnot [array] -or $p.files.Count -ne 20 -or $p.file_count -isnot [int] -or $p.file_count -ne 20){throw 'WRITE_PREVIEW_REJECTED'}
 $rows=@();$total=0L
 for($i=0;$i -lt 20;$i++){
  $r=$p.files[$i];Assert-AuthWireCandidateFields $r @('Path','Size','Sha256','Sddl')
  if($r.Path -cne $names[$i] -or -not (Test-AuthWireWriteInteger $r.Size) -or $r.Size -gt 1048576 -or -not (Test-AuthWireWriteHash $r.Sha256) -or $r.Sddl -isnot [string] -or $r.Sddl.Length -lt 1 -or $r.Sddl.Length -gt 1024 -or $r.Sddl -cmatch '[^\x20-\x7e]'){throw 'WRITE_PREVIEW_REJECTED'}
  $null=[Security.AccessControl.RawSecurityDescriptor]::new($r.Sddl)
  if($r.Path -ceq 'signed-manifest.json' -and $r.Sha256 -cne $t.manifest_sha256){throw 'WRITE_PREVIEW_REJECTED'}
  if($r.Path -ceq 'original-draft.zip' -and $r.Sha256 -cne $t.draft_sha256){throw 'WRITE_PREVIEW_REJECTED'}
  $total+=$r.Size;$rows+=,[pscustomobject][ordered]@{Path=$r.Path;Size=$r.Size;Sha256=$r.Sha256;Sddl=$r.Sddl}
 }
 if(-not (Test-AuthWireWriteInteger $p.total_bytes) -or $total -ne $p.total_bytes -or $total -gt 4194304 -or
    $p.source_ledger_sha256 -cne (Get-AuthWireJobHash ([Text.Encoding]::ASCII.GetBytes((ConvertTo-AuthWireWriteJson $rows $false)))) -or
    -not (Test-AuthWireWriteHash $Target.preview_record.PreviewSha256) -or $Target.preview_record.PreviewSha256 -cne (Get-AuthWireWritePreviewHash $p)){throw 'WRITE_PREVIEW_REJECTED'}
 if($Operation -ceq 'combined.filesystem.stage.v1'){if($null -ne $Target.stage_receipt){throw 'WRITE_TARGET_REJECTED'}}
 elseif($Operation -ceq 'combined.filesystem.rollback.v1'){
  Assert-AuthWireCandidateFields $Target.stage_receipt @('stage_job_id','complete_journal_sha256','staged_tree_sha256')
  Assert-AuthWireCandidateGuid $Target.stage_receipt.stage_job_id
  foreach($n in @('complete_journal_sha256','staged_tree_sha256')){if(-not (Test-AuthWireWriteHash $Target.stage_receipt.$n)){throw 'WRITE_TARGET_REJECTED'}}
 }else{throw 'WRITE_OPERATION_REJECTED'}
}
function Assert-AuthWireWriteOffer($Offer,[hashtable]$Binding,[string]$Release,[string]$RequestId){
 Assert-AuthWireCandidateFields $Offer @('format','request_id','scope_sha256','job_id','operation','lease_id','intent_sha256','expires_at','target','write_authorized','can_apply_gpo')
 Assert-AuthWireCandidateGuid $Release
 $scope=Get-AuthWireJobScope $Binding
 foreach($n in @('request_id','scope_sha256','intent_sha256')){if(-not (Test-AuthWireWriteHash $Offer.$n)){throw 'WRITE_OFFER_REJECTED'}}
 if($Offer.format -isnot [int] -or $Offer.format -ne 1 -or -not (Test-AuthWireWriteHash $RequestId) -or $Offer.request_id -cne $RequestId -or
    $Offer.scope_sha256 -cne $scope -or $Offer.write_authorized -isnot [bool] -or $Offer.write_authorized -or $Offer.can_apply_gpo -isnot [bool] -or $Offer.can_apply_gpo){throw 'WRITE_OFFER_REJECTED'}
 Assert-AuthWireCandidateGuid $Offer.job_id
 Assert-AuthWireWriteTarget $Offer.target $Offer.operation
 $intent='AuthWireStagingWriteIntentV1'+"`n"+$scope+"`n"+$Offer.job_id+"`n"+$Offer.operation+"`n"+(Get-AuthWireWriteHash $Offer.target)+"`n"
 $now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
 if(-not (Test-AuthWireWriteHash $Offer.lease_id) -or $Offer.intent_sha256 -cne (Get-AuthWireJobHash ([Text.Encoding]::ASCII.GetBytes($intent))) -or
    $Offer.target.writer_release_id -cne $Release -or -not (Test-AuthWireWriteInteger $Offer.expires_at) -or $Offer.expires_at -le $now+5 -or $Offer.expires_at -gt $now+90){throw 'WRITE_OFFER_REJECTED'}
 if($Offer.operation -ceq 'combined.filesystem.stage.v1' -and ($Offer.target.preview_record.Preview.checked_at -gt $now -or $Offer.expires_at -gt $Offer.target.preview_record.Preview.expires_at)){throw 'WRITE_OFFER_REJECTED'}
}
function New-AuthWireStagingWriteProof([hashtable]$Binding,[Security.Cryptography.RSACng]$Key,[ValidateSet('POLL','CLAIM','RESULT')][string]$Kind,[hashtable]$Payload){
 $h=New-AuthWireConnectorPollProof -Binding $Binding -ChannelKey $Key
 $f=[Text.Encoding]::ASCII.GetString([Convert]::FromBase64String($h.frame)).Split([char]10)
 $bytes=[Text.UTF8Encoding]::new($false,$true).GetBytes(($Payload|ConvertTo-Json -Depth 8 -Compress))
 if($bytes.Length -gt 1024){throw 'WRITE_PAYLOAD_LIMIT'}
 $path='/api/connector/v1/staging-write/'+$Kind.ToLowerInvariant()
 $raw=[Text.Encoding]::ASCII.GetBytes(((@('AUTHWIRE-STAGING-WRITE-JOB-'+$Kind+'-V1')+@($f[1..13])+@((Get-AuthWireJobHash $bytes),'POST',$path)) -join "`n")+"`n")
 $sig=$Key.SignData($raw,[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1)
 $proof=@{frame=[Convert]::ToBase64String($raw);signature=[Convert]::ToBase64String($sig);payload=[Convert]::ToBase64String($bytes)}
 if([Text.Encoding]::UTF8.GetByteCount(($proof|ConvertTo-Json -Compress)) -gt 4096){throw 'WRITE_PROOF_LIMIT'}
 return $proof
}

function Get-AuthWireWriteStageLiveContext($Offer,[hashtable]$Binding,[string]$Publisher,[string]$BaseUrl){
 # Trusted local caller only; no path is taken from the offer. Existing public
 # candidate/signature + non-admin service identity validation remains in use.
 if($Offer.operation -cne 'combined.filesystem.stage.v1'){throw 'WRITE_ROLLBACK_PREFLIGHT_UNAVAILABLE'}
 $target=$Offer.target.scope_target
 $context=Get-AuthWireCombinedScopeContext $target $Binding $Publisher $BaseUrl
 $a=$context.Approval
 $before=Get-ADDomain -Identity $a.domain -Server $a.domain -ErrorAction Stop
 $server=[string]$before.PDCEmulator;$domainSid=$Binding.service_sid.Substring(0,$Binding.service_sid.LastIndexOf('-'))
 if($before.DNSRoot -cne $target.domain -or $before.DomainSID.Value -cne $domainSid -or $server -cnotmatch '\A[a-z0-9.-]{1,253}\z' -or -not $server.EndsWith('.'+$target.domain,[StringComparison]::Ordinal)){throw 'WRITE_LIVE_SCOPE_CHANGED'}
 $fresh=Get-AuthWireCombinedStagingPreview $target $Binding $Publisher $BaseUrl
 # Compare current business observations at the ORIGINAL approved timestamps.
 # A later snapshot must not silently replace/extend the approved preview.
 $fresh.Preview.checked_at=$Offer.target.preview_record.Preview.checked_at
 $fresh.Preview.expires_at=$Offer.target.preview_record.Preview.expires_at
 if((Get-AuthWireWritePreviewHash $fresh.Preview) -cne $Offer.target.preview_record.PreviewSha256){throw 'WRITE_LIVE_PREVIEW_CHANGED'}
 $after=Get-ADDomain -Identity $a.domain -Server $a.domain -ErrorAction Stop
 if($after.DNSRoot -cne $before.DNSRoot -or $after.DomainSID.Value -cne $domainSid -or [string]$after.PDCEmulator -cne $server){throw 'WRITE_LIVE_PDC_CHANGED'}
 $source=Join-Path ([Environment]::GetFolderPath('CommonApplicationData')) ('AuthWire-CombinedCandidates-'+([guid]$Binding.connector_id).ToString('N'))
 $source=Join-Path $source ($target.plan_id+'-v'+$target.plan_version+'-'+$target.draft_sha256+'-ab1a11c683810061')
 $gpo='\\'+$server+'\SYSVOL\'+$target.domain+'\Policies\{'+$target.gpo_id+'}'
 # The original engine hashes a fixed-property-order object. Network/persisted
 # object ordering is irrelevant to approval; normalize without changing data.
 $normalized=[pscustomobject]@{Preview=(ConvertTo-AuthWireWriteOrderedPreview $fresh.Preview);PreviewSha256=$Offer.target.preview_record.PreviewSha256}
 $null=Assert-AuthWireStagingFilesystemContext $target $normalized $normalized.PreviewSha256 $gpo $a.protected_gpo_id
 return [pscustomobject][ordered]@{format='AuthWireWriteLiveContextV1';job_id=$Offer.job_id;intent_sha256=$Offer.intent_sha256;target_sha256=(Get-AuthWireWriteHash $Offer.target);source_root=$source;gpo_root=$gpo;protected_gpo_id=$a.protected_gpo_id;pdc=$server;checked_at=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds();can_apply_gpo=$false}
}

function Save-AuthWireStagingWriteOffer($Offer,[hashtable]$Binding,[string]$Release,[string]$RequestId,[string]$JournalRoot){
 Assert-AuthWireWriteOffer $Offer $Binding $Release $RequestId
 if($Offer.operation -cne 'combined.filesystem.stage.v1'){throw 'WRITE_ROLLBACK_PREFLIGHT_UNAVAILABLE'}
 Initialize-AuthWireStagingFilesystemTypes;Assert-AuthWireStagingJournalRoot $JournalRoot
 $pin=[AuthWire.Staging.TreeLeaseV1]::new()
 $mutex=$null;$taken=$false
 try{
  $pin.PinAncestors($JournalRoot)
  # Serialize only the short local create step across this machine, including
  # alternate spellings of the same directory. Durable GPO locks survive reboot.
  $mutex=[Threading.Mutex]::new($false,'Global\AuthWireWritePreclaimStoreV1')
  try{$taken=$mutex.WaitOne(0)}catch [Threading.AbandonedMutexException]{$taken=$true;throw 'WRITE_STORE_ABANDONED_REQUIRES_REVIEW'}
  if(-not $taken){throw 'WRITE_LOCAL_STORE_BUSY'}
  $children=@(Get-ChildItem -LiteralPath $JournalRoot -Force)
  if($children.Count -gt 62 -or @($children|Where-Object PSIsContainer).Count -ge 32){throw 'WRITE_LOCAL_STORE_LIMIT'}
  $job=Join-Path $JournalRoot $Offer.job_id
  if(Test-Path -LiteralPath $job){throw 'WRITE_LOCAL_JOB_EXISTS_REQUIRES_REVIEW'}
  # Durable lock is GPO-bound, not binding-generation-bound. Any incomplete lock
  # remains conservative after a crash. No automatic unlock/delete is provided.
  $lock=Join-Path $JournalRoot ('gpo-'+$Offer.target.scope_target.gpo_id+'.json')
  Write-AuthWireStagingJournal $lock ([pscustomobject]@{format='AuthWireWriteGpoLockV1';job_id=$Offer.job_id;intent_sha256=$Offer.intent_sha256})
  [AuthWire.Staging.TreeLeaseV1]::CreateNewDirectory($job);$pin.PinAncestors($job)
  $record=[pscustomobject][ordered]@{format='AuthWireWriteOfferV1';binding_scope=(Get-AuthWireJobScope $Binding);release_id=$Release;offer=$Offer}
  Write-AuthWireStagingJournal (Join-Path $job 'offer.json') $record
  return [pscustomobject]@{JobId=$Offer.job_id;Phase='offer_saved';FilesystemWriteEnabled=$false;CanApplyGpo=$false}
 }finally{if($taken){$mutex.ReleaseMutex()};if($mutex){$mutex.Dispose()};$pin.Dispose()}
}
function Read-AuthWireStagingWriteOffer([string]$JournalRoot,[string]$JobId,[hashtable]$Binding,[string]$Release){
 Assert-AuthWireCandidateGuid $JobId;Assert-AuthWireStagingJournalRoot $JournalRoot;Initialize-AuthWireStagingFilesystemTypes
 $pin=[AuthWire.Staging.TreeLeaseV1]::new()
 try{
  $pin.PinAncestors($JournalRoot);$job=Join-Path $JournalRoot $JobId;$pin.PinAncestors($job)
  $file=Join-Path $job 'offer.json';$pin.PinFile($file);$v=Read-AuthWireStagingJournal $file
  Assert-AuthWireCandidateFields $v @('format','binding_scope','release_id','offer')
  if($v.format -cne 'AuthWireWriteOfferV1' -or $v.binding_scope -cne (Get-AuthWireJobScope $Binding) -or $v.release_id -cne $Release -or $v.offer.job_id -cne $JobId){throw 'WRITE_LOCAL_RECORD_CHANGED'}
  Assert-AuthWireWriteOffer $v.offer $Binding $Release $v.offer.request_id
  $lock=Join-Path $JournalRoot ('gpo-'+$v.offer.target.scope_target.gpo_id+'.json');$pin.PinFile($lock)
  $l=Read-AuthWireStagingJournal $lock;Assert-AuthWireCandidateFields $l @('format','job_id','intent_sha256')
  if($l.format -cne 'AuthWireWriteGpoLockV1' -or $l.job_id -cne $JobId -or $l.intent_sha256 -cne $v.offer.intent_sha256){throw 'WRITE_LOCAL_RECORD_CHANGED'}
  return $v.offer
 }finally{$pin.Dispose()}
}
function Assert-AuthWireWriteLiveContext($Value,$Offer,[hashtable]$Binding){
 Assert-AuthWireWriteLiveContextAt $Value $Offer $Binding ([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())
}
function Assert-AuthWireWriteLiveContextAt($Value,$Offer,[hashtable]$Binding,[long]$ObservedAt){
 # Historical receipt validation only. Live callers use the wall-clock wrapper.
 $v=$Value;$t=$Offer.target.scope_target
 Assert-AuthWireCandidateFields $v @('format','job_id','intent_sha256','target_sha256','source_root','gpo_root','protected_gpo_id','pdc','checked_at','can_apply_gpo')
 foreach($n in @('format','job_id','intent_sha256','target_sha256','source_root','gpo_root')){if($v.$n -isnot [string]){throw 'WRITE_PREFLIGHT_REJECTED'}}
 $now=$ObservedAt
 if($v.format -cne 'AuthWireWriteLiveContextV1' -or $v.job_id -cne $Offer.job_id -or $v.intent_sha256 -cne $Offer.intent_sha256 -or $v.target_sha256 -cne (Get-AuthWireWriteHash $Offer.target) -or $v.can_apply_gpo -isnot [bool] -or $v.can_apply_gpo -or -not (Test-AuthWireWriteInteger $v.checked_at) -or $v.checked_at -gt $now -or $now-$v.checked_at -gt 5){throw 'WRITE_PREFLIGHT_STALE'}
 Assert-AuthWireCandidateGuid $v.protected_gpo_id
 if($v.protected_gpo_id -ceq $t.gpo_id -or $v.pdc -isnot [string] -or $v.pdc -cnotmatch '\A[a-z0-9.-]{1,253}\z' -or -not $v.pdc.EndsWith('.'+$t.domain,[StringComparison]::Ordinal)){throw 'WRITE_PREFLIGHT_REJECTED'}
 $source=Join-Path ([Environment]::GetFolderPath('CommonApplicationData')) ('AuthWire-CombinedCandidates-'+([guid]$Binding.connector_id).ToString('N'))
 $source=Join-Path $source ($t.plan_id+'-v'+$t.plan_version+'-'+$t.draft_sha256+'-ab1a11c683810061')
 $gpo='\\'+$v.pdc+'\SYSVOL\'+$t.domain+'\Policies\{'+$t.gpo_id+'}'
 if($v.source_root -cne $source -or $v.gpo_root -cne $gpo){throw 'WRITE_PREFLIGHT_PATH_REJECTED'}
}
function Invoke-AuthWireStagingWritePreflight([string]$JournalRoot,[string]$JobId,[hashtable]$Binding,[string]$Release){
 $offer=Read-AuthWireStagingWriteOffer $JournalRoot $JobId $Binding $Release
 Initialize-AuthWireScopeProcess
 $file=Join-Path $PSScriptRoot 'Read-AuthWireStagingWritePreflight.ps1'
 $exe=Join-Path ([Environment]::GetFolderPath('Windows')) 'System32\WindowsPowerShell\v1.0\powershell.exe'
 if($JournalRoot.Length -gt 1800 -or $JournalRoot.Contains('"')){throw 'WRITE_JOURNAL_PATH_REJECTED'}
 $now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds();$budget=[int][Math]::Min(30000,($offer.expires_at-$now-5)*1000)
 if($budget -lt 100){throw 'WRITE_OFFER_EXPIRED'}
 $arguments='-NoLogo -NoProfile -NonInteractive -ExecutionPolicy AllSigned -File "'+$file+'" -JournalRoot "'+$JournalRoot.TrimEnd('\')+'" -JobId '+$JobId
 $r=[AuthWire.Connector.ScopeProcessV1]::Run($exe,$arguments,$budget)
 if($r.TimedOut -or $r.Truncated -or $r.ExitCode -ne 0){throw 'WRITE_PREFLIGHT_FAILED'}
 $v=ConvertFrom-AuthWireCandidateJson ([Text.UTF8Encoding]::new($false,$true).GetBytes($r.Output))
 Assert-AuthWireWriteLiveContext $v $offer $Binding
 if($v.checked_at -lt $now){throw 'WRITE_PREFLIGHT_REJECTED'}
 $null=Read-AuthWireStagingWriteOffer $JournalRoot $JobId $Binding $Release
 # Context paths are returned only by the fixed signed reader and will require
 # another live validation before a future filesystem call.
 $pin=[AuthWire.Staging.TreeLeaseV1]::new()
 try{$pin.PinAncestors($JournalRoot);$job=Join-Path $JournalRoot $JobId;$pin.PinAncestors($job);Write-AuthWireStagingJournal (Join-Path $job 'preflight.json') $v}finally{$pin.Dispose()}
 return [pscustomobject]@{JobId=$JobId;Phase='preflight_saved';FilesystemWriteEnabled=$false;CanApplyGpo=$false}
}
function New-AuthWireStagingWriteClaim([string]$JournalRoot,[string]$JobId,[hashtable]$Binding,[string]$Release,[Security.Cryptography.RSACng]$Key){
 $offer=Read-AuthWireStagingWriteOffer $JournalRoot $JobId $Binding $Release
 $pin=[AuthWire.Staging.TreeLeaseV1]::new()
 try{
  $pin.PinAncestors($JournalRoot);$job=Join-Path $JournalRoot $JobId;$pin.PinAncestors($job)
  $file=Join-Path $job 'preflight.json';$pin.PinFile($file);$v=Read-AuthWireStagingJournal $file
  Assert-AuthWireWriteLiveContext $v $offer $Binding
  $now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
  $body=@{job_id=$JobId;lease_id=$offer.lease_id;intent_sha256=$offer.intent_sha256;target_sha256=(Get-AuthWireWriteHash $offer.target);release_id=$Release}
  # Flush BEFORE constructing a proof. Lost reply or even failed signing is not
  # automatically retried. Reboot leaves claim-started plus the durable GPO lock.
  Write-AuthWireStagingJournal (Join-Path $job 'claim-started.json') ([pscustomobject]@{format='AuthWireWriteClaimStartedV1';job_id=$JobId;intent_sha256=$offer.intent_sha256;checked_at=$now})
  $proof=New-AuthWireStagingWriteProof $Binding $Key CLAIM $body
  Write-AuthWireStagingJournal (Join-Path $job 'claim-proof.json') ([pscustomobject]@{format='AuthWireWriteClaimProofV1';job_id=$JobId;proof=$proof})
  return $proof
 }finally{$pin.Dispose()}
}
