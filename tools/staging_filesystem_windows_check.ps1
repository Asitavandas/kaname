# Native WinPS5.1 transaction-engine tests on synthetic local + real SMB trees; no AD.
$ErrorActionPreference='Stop';Set-StrictMode -Version 2
$lib=Join-Path $PSScriptRoot '..\windows\connector'
. (Join-Path $lib 'Test-AuthWireDeploymentCandidate.ps1') -LibraryOnly
foreach($n in @('Compare-AuthWireSigningKeyAcl.ps1','Invoke-AuthWireConnectorProbeJob.ps1','Invoke-AuthWireCandidateJob.ps1','Invoke-AuthWireCombinedJob.ps1','DeploymentScope.ps1','CombinedDeploymentScope.ps1','Invoke-AuthWireCombinedScopeJob.ps1','SysvolInventory.ps1','CombinedStagingPreview.ps1','StagingFilesystem.ps1')){. (Join-Path $lib $n)}
$script:checks=0
function Check($value,[string]$name){if(-not $value){throw ('STAGING_PREVIEW_FIXTURE:'+ $name)};$script:checks++}
function Reject([scriptblock]$action,[string]$name){$failed=$false;try{& $action|Out-Null}catch{$failed=$true};Check $failed $name}
function Clone($v){return ($v|ConvertTo-Json -Depth 10|ConvertFrom-Json)}
$tokens=$null;$errors=$null;$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $lib 'CombinedStagingPreview.ps1'),[ref]$tokens,[ref]$errors)
Check ($errors.Count -eq 0) 'native parser'
# Library must not acquire execution capability through new write/process commands.
$commands=@($ast.FindAll({param($n)$n -is [Management.Automation.Language.CommandAst]},$true)|ForEach-Object {$_.GetCommandName()})
Check (@($commands|Where-Object {$_ -cne 'Set-StrictMode' -and $_ -match '^(Set-|New-Item|Remove-|Copy-|Move-|Start-|Stop-|Invoke-|Register-|Import-Certificate)' }).Count -eq 0) 'no mutating or invocation cmdlets'
$root=Join-Path $env:TEMP ('aw-staging-preview-'+[guid]::NewGuid().ToString('N'))
$connector=[guid]::NewGuid().ToString('D')
$candidateRoot=Join-Path $env:ProgramData ('AuthWire-CombinedCandidates-'+([guid]$connector).ToString('N'))
$serviceSid='S-1-5-21-111-222-333-1648'
$b=@{connector_id=$connector;service_sid=$serviceSid}
$t=[pscustomobject][ordered]@{
 candidate_id=[guid]::NewGuid().ToString('D');network_candidate_id=[guid]::NewGuid().ToString('D')
 plan_id=[guid]::NewGuid().ToString('D');plan_version=1;gpo_id=[guid]::NewGuid().ToString('D')
 approval_sha256=('a'*64);network_manifest_sha256=('b'*64);manifest_sha256=('c'*64);draft_sha256=('d'*64)
 dependency_sha256=('e'*64);publisher_thumbprint=('A'*40);machine_profile_id=[guid]::NewGuid().ToString('D')
 machine_profile_version=3;domain='lab.example';root_thumbprint=('f'*40);group_sid='S-1-5-21-111-222-333-1647'
 content_result_sha256=('1'*64);target_sids_sha256=('2'*64);target_count=1
}
function SourceAcl([string]$path,[switch]$Directory) {
 $inherit=if($Directory){'OICI'}else{''}
 $read=if($Directory){'0x1200a9'}else{'0x120089'}
 $sddl='O:BAG:BAD:P(A;'+$inherit+';FA;;;SY)(A;'+$inherit+';FA;;;BA)(A;'+$inherit+';'+$read+';;;'+$serviceSid+')'
 $acl=if($Directory){[Security.AccessControl.DirectorySecurity]::new()}else{[Security.AccessControl.FileSecurity]::new()}
 $acl.SetSecurityDescriptorSddlForm($sddl);Set-Acl -LiteralPath $path -AclObject $acl
}
$share=$null;$startedServer=$false;$journalRoot=Join-Path $env:TEMP ('aw-stage-journal-'+[guid]::NewGuid().ToString('N'))
try{
 $null=New-Item -ItemType Directory -Path $root
 # Managed GPO roots have protected DACLs. An inherited TEMP share root can
 # report inherited ACE flags differently over SMB and is not that baseline.
 $rootAcl=Get-Acl -LiteralPath $root
 $rootAcl.SetAccessRuleProtection($true,$true)
 Set-Acl -LiteralPath $root -AclObject $rootAcl
 Check ((Get-Acl -LiteralPath $root).AreAccessRulesProtected) 'fixture matches protected managed-GPO root'
 foreach($n in @('Machine','User')){$null=New-Item -ItemType Directory -Path (Join-Path $root $n)}
 [IO.File]::WriteAllText((Join-Path $root 'GPT.INI'),"[General]`r`nVersion=0`r`n")
 [IO.File]::WriteAllText((Join-Path $root 'GPO.cmt'),'synthetic marker')
 $before=Get-AuthWireSysvolInventory $root
 $null=New-Item -ItemType Directory -Path $candidateRoot
 SourceAcl $candidateRoot -Directory
 $candidate=Join-Path $candidateRoot ($t.plan_id+'-v1-'+$t.draft_sha256+'-ab1a11c683810061')
 $null=New-Item -ItemType Directory -Path $candidate;SourceAcl $candidate -Directory
 foreach($d in @('network','enrollment')){$p=Join-Path $candidate $d;$null=New-Item -ItemType Directory -Path $p;SourceAcl $p -Directory}
 $manifestFiles=[ordered]@{}
 foreach($n in Get-AuthWireCombinedStagingNames) {
  if($n -cin @('signed-manifest.json','AuthWire-Combined-Manifest.ps1')){continue}
  $bytes=[Text.Encoding]::UTF8.GetBytes(('never execute synthetic asset '+$n))
  if($n -ceq 'original-draft.zip'){
   # Fixed candidate path must bind the same draft hash.
   $t.draft_sha256=Get-AuthWireCandidateHash $bytes
  }
  $manifestFiles[$n]=Get-AuthWireCandidateHash $bytes
  [IO.File]::WriteAllBytes((Join-Path $candidate $n),$bytes)
 }
 # Rename our own synthetic directory to its finalized hash-bound name.
 $fixedCandidate=Join-Path $candidateRoot ($t.plan_id+'-v1-'+$t.draft_sha256+'-ab1a11c683810061')
 [IO.Directory]::Move($candidate,$fixedCandidate);$candidate=$fixedCandidate
 $manifest=[Text.Encoding]::UTF8.GetBytes((@{files=$manifestFiles}|ConvertTo-Json -Compress))
 $t.manifest_sha256=Get-AuthWireCandidateHash $manifest
 [IO.File]::WriteAllBytes((Join-Path $candidate 'signed-manifest.json'),$manifest)
 [IO.File]::WriteAllText((Join-Path $candidate 'AuthWire-Combined-Manifest.ps1'),"throw 'FIXTURE_MUST_NOT_EXECUTE'")
 foreach($f in Get-ChildItem -LiteralPath $candidate -Recurse -File){SourceAcl $f.FullName}
 $ledger=@(Get-AuthWireCombinedStagingLedger $t $b)
 Check ($ledger.Count -eq 20) 'fixed complete twenty-file ledger'
 $p=New-AuthWireCombinedStagingPlanCore $t $ledger $before ('3'*64) 1793196000
 Check ($p.Preview.file_count -eq 20 -and $p.Preview.total_bytes -gt 0) 'complete proposal'
 Check ($p.Preview.relative_destination -ceq ('Machine/AuthWire-'+([guid]$t.plan_id).ToString('N')+'-v1-'+$t.manifest_sha256)) 'fixed destination derived from plan and manifest'
 Check ($p.Preview.read_only -and -not $p.Preview.can_stage -and -not $p.Preview.can_apply_gpo -and -not $p.Preview.writer_available -and $p.Preview.requires_new_write_approval) 'proposal grants no execution authority'
 Check ($p.Preview.expires_at-$p.Preview.checked_at -eq 90) 'bounded proposal lifetime'
 Check ($p.Preview.rollback.relative_directory -ceq $p.Preview.relative_destination -and $p.Preview.rollback.requires_ownership_journal -and $p.Preview.rollback.requires_exact_staged_tree -and $p.Preview.rollback.drift_requires_review -and -not $p.Preview.rollback.delete_existing_data) 'rollback is an exact ownership-bound requirement, not implemented delete'
 if($env:AUTHWIRE_STAGING_WIRE_OUTPUT){[IO.File]::WriteAllText($env:AUTHWIRE_STAGING_WIRE_OUTPUT,(@{target=$t;preview=$p.Preview;preview_sha256=$p.PreviewSha256}|ConvertTo-Json -Depth 10),[Text.UTF8Encoding]::new($false))}
 $reverse=@($ledger);[Array]::Reverse($reverse)
 $r=New-AuthWireCombinedStagingPlanCore $t $reverse $before ('3'*64) 1793196000
 Check ($p.PreviewSha256 -ceq $r.PreviewSha256) 'ordinal row order stable'
 $r=New-AuthWireCombinedStagingPlanCore $t $ledger $before ('4'*64) 1793196000
 Check ($p.PreviewSha256 -cne $r.PreviewSha256) 'live scope observations bound'
 $changed=Clone $t;$changed.dependency_sha256='5'*64
 Check ((New-AuthWireCombinedStagingPlanCore $changed $ledger $before ('3'*64) 1793196000).PreviewSha256 -cne $p.PreviewSha256) 'dependency changes bind new proposal'
 $changed=Clone $t;$changed|Add-Member NoteProperty destination '..\outside'
 Reject {New-AuthWireCombinedStagingPlanCore $changed $ledger $before ('3'*64) 1793196000} 'arbitrary requested destination refused'
 foreach($bad in @('../escape','enrollment/../escape','enrollment\\config.json','enrollment/config.json:stream','Enrollment/config.json')) {
  $rows=@(Clone $ledger);$rows[0].Path=$bad
  Reject {New-AuthWireCombinedStagingPlanCore $t $rows $before ('3'*64) 1793196000} 'unexpected path refused'
 }
 $rows=@(Clone $ledger);$rows[0].Path=$rows[1].Path
 Reject {New-AuthWireCombinedStagingPlanCore $t $rows $before ('3'*64) 1793196000} 'duplicate source row refused'
 Reject {New-AuthWireCombinedStagingPlanCore $t @($ledger|Select-Object -Skip 1) $before ('3'*64) 1793196000} 'missing asset refused'
 foreach($size in @(0,-1,1048577,'10')) {
  $rows=@(Clone $ledger);$rows[0].Size=$size
  Reject {New-AuthWireCombinedStagingPlanCore $t $rows $before ('3'*64) 1793196000} 'invalid source size refused'
 }
 $rows=@(Clone $ledger);$rows|ForEach-Object {$_.Size=1048576}
 Reject {New-AuthWireCombinedStagingPlanCore $t $rows $before ('3'*64) 1793196000} 'aggregate source size bounded'
 foreach($name in @('signed-manifest.json','original-draft.zip')) {
  $rows=@(Clone $ledger);@($rows|Where-Object {$_.Path -ceq $name})[0].Sha256='6'*64
  Reject {New-AuthWireCombinedStagingPlanCore $t $rows $before ('3'*64) 1793196000} 'content pins enforced'
 }
 $rows=@(Clone $ledger);$rows[0].Sha256='not-a-hash'
 Reject {New-AuthWireCombinedStagingPlanCore $t $rows $before ('3'*64) 1793196000} 'invalid hash refused'
 $rows=@(Clone $ledger);$rows[0].Sddl='invalid'
 Reject {New-AuthWireCombinedStagingPlanCore $t $rows $before ('3'*64) 1793196000} 'invalid ACL refused'
 $rows=@(Clone $ledger);$rows[0].Sddl='O:BAG:BAD:P(A;;FA;;;SY)'
 Check ((New-AuthWireCombinedStagingPlanCore $t $rows $before ('3'*64) 1793196000).PreviewSha256 -cne $p.PreviewSha256) 'ACL drift changes proposal'
 $extra=Join-Path $root 'Machine\foreign.ps1';[IO.File]::WriteAllText($extra,"throw 'foreign must not execute'")
 Reject {New-AuthWireCombinedStagingPlanCore $t $ledger (Get-AuthWireSysvolInventory $root) ('3'*64) 1793196000} 'foreign descendant prevents proposal'
 Remove-Item -LiteralPath $extra -Force
 $source=Join-Path $candidate 'enrollment\config.json';$old=[IO.File]::ReadAllBytes($source)
 try{[IO.File]::WriteAllText($source,'tampered');Reject {Get-AuthWireCombinedStagingLedger $t $b} 'changed source asset refused'}finally{[IO.File]::WriteAllBytes($source,$old)}
 Reject {New-AuthWireCombinedStagingPlanCore $t $ledger $before 'bad' 1793196000} 'missing live observations refused'
 Reject {New-AuthWireCombinedStagingPlanCore $t $ledger $before ('3'*64) 0} 'missing observation time refused'
 Reject {Get-AuthWireCombinedStagingPreview $t $b $t.publisher_thumbprint 'https://example.invalid/'} 'administrator is not service identity'
 # Read the exact same fixture through a real SMB share, retaining original guard.
 $server=Get-Service LanmanServer
 if($server.Status -ne 'Running'){Start-Service LanmanServer;$startedServer=$true}
 $share='aw-stage-preview-'+[guid]::NewGuid().ToString('N')
 $who=[Security.Principal.WindowsIdentity]::GetCurrent().Name
 $null=New-SmbShare -Name $share -Path $root -FullAccess $who -ErrorAction Stop
 $unc='\\localhost\'+$share
 $uncInventory=Get-AuthWireSysvolInventory $unc
 if($uncInventory.Sha256 -cne $before.Sha256){
  $currentLocal=Get-AuthWireSysvolInventory $root
  Write-Host ('STAGING_FIXTURE_BASELINE='+($before.Entries|ConvertTo-Json -Depth 5 -Compress))
  Write-Host ('STAGING_FIXTURE_LOCAL_NOW='+($currentLocal.Entries|ConvertTo-Json -Depth 5 -Compress))
  Write-Host ('STAGING_FIXTURE_UNC='+($uncInventory.Entries|ConvertTo-Json -Depth 5 -Compress))
 }
 Check ($uncInventory.Sha256 -ceq $before.Sha256) 'real SMB full inventory equals local bytes and ACL'
 Check ((New-AuthWireCombinedStagingPlanCore $t $ledger $uncInventory ('3'*64) 1793196000).PreviewSha256 -ceq $p.PreviewSha256) 'UNC and local proposal canonical equality'
 Reject {Read-AuthWireCandidateBytes (Join-Path $unc 'GPT.INI') 4096} 'local-candidate UNC prohibition preserved'
 Check ((Get-AuthWireSysvolInventory $root).Sha256 -ceq $before.Sha256) 'all proposal operations preserved fixture tree'
 Check (@(Get-ChildItem -LiteralPath (Join-Path $root 'Machine') -Force).Count -eq 0) 'no staging directory created'
 # No product service, endpoint, CA, publisher or AD objects are touched below.
 $null=New-Item -ItemType Directory -Path $journalRoot
 $jacl=[Security.AccessControl.DirectorySecurity]::new()
 $jacl.SetSecurityDescriptorSddlForm('O:BAG:BAD:P(A;OICI;FA;;;SY)(A;OICI;FA;;;BA)')
 Set-Acl -LiteralPath $journalRoot -AclObject $jacl
 Initialize-AuthWireStagingFilesystemTypes
 $now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
 $fresh=New-AuthWireCombinedStagingPlanCore $t $ledger $before ('3'*64) $now
 $protected=[guid]::NewGuid().ToString('D')
 # Use a GPO GUID leaf as required by the transaction engine.
 Remove-SmbShare -Name $share -Force;$share=$null
 $guidRoot=Join-Path (Split-Path $root -Parent) ('{'+$t.gpo_id+'}')
 [IO.Directory]::Move($root,$guidRoot);$root=$guidRoot
 $share='aw-stage-write-'+[guid]::NewGuid().ToString('N')
 $shareParent=Join-Path $env:TEMP ('aw-share-'+[guid]::NewGuid().ToString('N'))
 $null=New-Item -ItemType Directory -Path $shareParent
 $newRoot=Join-Path $shareParent ('{'+$t.gpo_id+'}')
 [IO.Directory]::Move($root,$newRoot);$root=$shareParent
 $null=New-SmbShare -Name $share -Path $shareParent -FullAccess $who
 $unc='\\localhost\'+$share+'\{'+$t.gpo_id+'}'
 Check ((Get-AuthWireSysvolInventory $unc).Sha256 -ceq $before.Sha256) 'moved isolated GPO fixture baseline unchanged'
 function Stage([string]$id,$proposal=$fresh,[string]$pin=$fresh.PreviewSha256,[string]$protectedId=$protected){
  Invoke-AuthWireStagingFilesystemStage -Target $t -PreviewRecord $proposal -ApprovedPreviewSha256 $pin -SourceRoot $candidate -GpoRoot $unc -JournalRoot $journalRoot -OperationId $id -ProtectedGpoId $protectedId
 }
 function Rollback([string]$id,[string]$pin){Invoke-AuthWireStagingFilesystemRollback -GpoRoot $unc -JournalRoot $journalRoot -OperationId $id -ApprovedCompleteSha256 $pin}
 Reject {Stage ([guid]::NewGuid().ToString('D')) $fresh ('0'*64)} 'wrong approval hash refuses any write'
 Reject {Stage ([guid]::NewGuid().ToString('D')) $fresh $fresh.PreviewSha256 $t.gpo_id} 'protected GPO refuses write'
 $expired=New-AuthWireCombinedStagingPlanCore $t $ledger $before ('3'*64) ($now-100)
 Reject {Stage ([guid]::NewGuid().ToString('D')) $expired $expired.PreviewSha256} 'expired preview refuses write'
 $future=New-AuthWireCombinedStagingPlanCore $t $ledger $before ('3'*64) ($now+100)
 Reject {Stage ([guid]::NewGuid().ToString('D')) $future $future.PreviewSha256} 'future preview refuses write'
 $source=Join-Path $candidate 'enrollment\config.json';$original=[IO.File]::ReadAllBytes($source)
 try{[IO.File]::WriteAllText($source,'tampered');Reject {Stage ([guid]::NewGuid().ToString('D'))} 'source byte drift before write'}finally{[IO.File]::WriteAllBytes($source,$original)}
 $foreign=Join-Path $candidate 'unexpected.txt'
 try{[IO.File]::WriteAllText($foreign,'foreign');Reject {Stage ([guid]::NewGuid().ToString('D'))} 'foreign source refuses write'}finally{Remove-Item -LiteralPath $foreign}
 try{Set-Content -LiteralPath $source -Stream foreign -Value hidden;Reject {Stage ([guid]::NewGuid().ToString('D'))} 'source ADS refuses write'}finally{Remove-Item -LiteralPath $source -Stream foreign -ErrorAction SilentlyContinue}
 $foreign=Join-Path $unc 'Machine\foreign.txt'
 try{[IO.File]::WriteAllText($foreign,'foreign');Reject {Stage ([guid]::NewGuid().ToString('D'))} 'baseline drift refuses write'}finally{Remove-Item -LiteralPath $foreign}
 Check (@(Get-ChildItem -LiteralPath $journalRoot).Count -eq 0) 'all refused preflights leave no transaction directories'
 Check ((Get-AuthWireSysvolInventory $unc).Sha256 -ceq $before.Sha256) 'all refused preflights preserve GPO'
 $op=[guid]::NewGuid().ToString('D')
 $stage=Stage $op
 Check ($stage.Phase -ceq 'staged' -and $stage.FileCount -eq 20 -and -not $stage.CanApplyGpo) 'actual SMB stage completes without activation'
 $destination=Join-Path $unc $fresh.Preview.relative_destination.Replace('/','\')
 Check (@(Get-ChildItem -LiteralPath $destination -Recurse -File).Count -eq 20) 'twenty staged files'
 $completePath=Join-Path (Join-Path $journalRoot $op) 'complete.json'
 $complete=Read-AuthWireStagingJournal $completePath;$completePin=Get-AuthWireScopeDataHash $complete
 Check ($complete.tree.Count -eq 23 -and $complete.tree_sha256 -ceq (Get-AuthWireStagingFilesystemDigest $complete.tree)) 'ownership journal contains exact identities hashes ACLs'
 $stagedHash=(Get-AuthWireSysvolInventory $unc).Sha256
 Reject {Stage $op} 'same operation cannot replay stage'
 Reject {Stage ([guid]::NewGuid().ToString('D'))} 'existing destination is never overwritten'
 Reject {Rollback $op ('0'*64)} 'rollback needs exact completed journal pin'
 $file=Join-Path $destination 'README.txt';$saved=[IO.File]::ReadAllBytes($file)
 try{[IO.File]::WriteAllText($file,'changed');Reject {Rollback $op $completePin} 'rollback refuses byte drift';Check (Test-Path -LiteralPath $destination) 'drift refusal keeps staged tree'}finally{[IO.File]::WriteAllBytes($file,$saved)}
 $foreign=Join-Path $destination 'foreign.txt'
 try{[IO.File]::WriteAllText($foreign,'foreign');Reject {Rollback $op $completePin} 'rollback refuses extra file';Check (Test-Path -LiteralPath $foreign) 'foreign file never deleted'}finally{Remove-Item -LiteralPath $foreign}
 try{Set-Content -LiteralPath $file -Stream foreign -Value hidden;Reject {Rollback $op $completePin} 'rollback refuses hidden stream'}finally{Remove-Item -LiteralPath $file -Stream foreign -ErrorAction SilentlyContinue}
 $savedAcl=Get-Acl -LiteralPath $file
 try{$changedAcl=Get-Acl -LiteralPath $file;$changedAcl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new([Security.Principal.SecurityIdentifier]::new('S-1-1-0'),'Read','Allow'));Set-Acl -LiteralPath $file -AclObject $changedAcl;Reject {Rollback $op $completePin} 'rollback refuses ACL drift'}finally{Set-Acl -LiteralPath $file -AclObject $savedAcl}
 Check ((Get-AuthWireSysvolInventory $unc).Sha256 -ceq $stagedHash) 'all drift cases restored before approved rollback'
 $rolled=Rollback $op $completePin
 Check ($rolled.Phase -ceq 'rolled_back' -and $rolled.BaselineRestored -and -not $rolled.CanApplyGpo) 'handle-based rollback succeeds'
 Check ((Get-AuthWireSysvolInventory $unc).Sha256 -ceq $before.Sha256) 'full original GPO bytes and ACL baseline restored'
 Reject {Rollback $op $completePin} 'rollback cannot replay'
 Check (Test-Path -LiteralPath $completePath) 'audit journal survives rollback'
 # An I/O failure while persisting completion must leave an explicit incomplete
 # transaction; production engine has no fault injection parameter.
 $writerBody=${function:Write-AuthWireStagingJournal}
 function Write-AuthWireStagingJournal([string]$Path,$Value){if([IO.Path]::GetFileName($Path) -ceq 'complete.json'){throw 'FIXTURE_DISK_FAILURE'};& $writerBody $Path $Value}
 $op2=[guid]::NewGuid().ToString('D')
 try{Reject {Stage $op2} 'injected completion failure surfaces'}finally{Set-Item Function:Write-AuthWireStagingJournal $writerBody}
 Check (Test-Path -LiteralPath $destination) 'incomplete transaction not recursively erased'
 Check (Test-Path -LiteralPath (Join-Path (Join-Path $journalRoot $op2) 'intent.json')) 'durable intent survives failure'
 Reject {Rollback $op2 $completePin} 'no completion means no guessed rollback ownership'
 Check (Test-Path -LiteralPath $destination) 'incomplete tree retained for review'
 Write-Host ('AUTHWIRE_STAGING_FILESYSTEM_WINDOWS_OK checks='+$checks+' smb_stage=true exact_rollback=true failure_requires_review=true customer_ad_tested=false live_writer_enabled=false')
}finally{
 if($share){Remove-SmbShare -Name $share -Force -ErrorAction SilentlyContinue}
 if($startedServer){Stop-Service LanmanServer -ErrorAction SilentlyContinue}
 foreach($p in @($root,$candidateRoot,$journalRoot)){if(Test-Path -LiteralPath $p){Remove-Item -LiteralPath $p -Recurse -Force}}
}
