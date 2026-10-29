# Native WinPS5.1, disposable non-exportable CNG key/local journals; AD is simulated.
$ErrorActionPreference='Stop';Set-StrictMode -Version 2
$lib=Join-Path $PSScriptRoot '..\windows\connector'
. (Join-Path $lib 'Test-AuthWireDeploymentCandidate.ps1') -LibraryOnly
foreach($n in @('Compare-AuthWireSigningKeyAcl.ps1','New-AuthWireConnectorHealthProof.ps1','ConnectorChannelTypes.ps1','Invoke-AuthWireConnectorProbeJob.ps1','Invoke-AuthWireCandidateJob.ps1','Invoke-AuthWireCombinedJob.ps1','DeploymentScope.ps1','Invoke-AuthWireScopeJob.ps1','CombinedDeploymentScope.ps1','Invoke-AuthWireCombinedScopeJob.ps1','SysvolInventory.ps1','CombinedStagingPreview.ps1','StagingFilesystem.ps1','StagingWritePreclaim.ps1')){. (Join-Path $lib $n)}
$script:checks=0
function Check($v,[string]$name){if(-not $v){throw ('PRECLAIM_FIXTURE:'+ $name)};$script:checks++}
function Reject([scriptblock]$fn,[string]$name){$failed=$false;try{& $fn|Out-Null}catch{$failed=$true};Check $failed $name}
function Clone($v){return ($v|ConvertTo-Json -Depth 12 -Compress|ConvertFrom-Json)}
foreach($n in @('StagingWritePreclaim.ps1','Read-AuthWireStagingWritePreflight.ps1')){
 $tokens=$null;$errors=$null;$a=[Management.Automation.Language.Parser]::ParseFile((Join-Path $lib $n),[ref]$tokens,[ref]$errors)
 Check ($errors.Count -eq 0) ('native parser '+$n)
 $calls=@($a.FindAll({param($node)$node -is [Management.Automation.Language.CommandAst]},$true)|ForEach-Object {$_.GetCommandName()})
 Check (@($calls|Where-Object {$_ -cmatch '\A(?:Invoke-AuthWireStagingFilesystem|Remove-|Set-Acl|New-Service|Start-Service|Set-GP|New-GP|Set-AD)'}).Count -eq 0) ('no execution/deletion/GPO/ACL commands '+$n)
}
$root=[IO.Path]::GetFullPath((Join-Path $env:TEMP ('aw-preclaim-'+[guid]::NewGuid().ToString('N'))))
$key=$null;$rsa=$null;$signer=$null;$public=$null
try{
 $null=New-Item -ItemType Directory -Path $root
 $acl=Get-Acl -LiteralPath $root;$acl.SetSecurityDescriptorSddlForm('O:BAG:BAD:P(A;OICI;FA;;;SY)(A;OICI;FA;;;BA)');Set-Acl -LiteralPath $root -AclObject $acl
 $p=[Security.Cryptography.CngKeyCreationParameters]::new();$p.Provider=[Security.Cryptography.CngProvider]::MicrosoftSoftwareKeyStorageProvider
 $p.KeyCreationOptions=[Security.Cryptography.CngKeyCreationOptions]::MachineKey;$p.ExportPolicy=[Security.Cryptography.CngExportPolicies]::None;$p.KeyUsage=[Security.Cryptography.CngKeyUsages]::Signing
 $p.Parameters.Add([Security.Cryptography.CngProperty]::new('Length',[BitConverter]::GetBytes(3072),[Security.Cryptography.CngPropertyOptions]::None))
 $key=[Security.Cryptography.CngKey]::Create([Security.Cryptography.CngAlgorithm]::Rsa,('aw-preclaim-'+[guid]::NewGuid().ToString('N')),$p);$rsa=[Security.Cryptography.RSACng]::new($key)
 $sid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value;$domainSid=$sid.Substring(0,$sid.LastIndexOf('-'))
 $b=@{instance_id=[guid]::NewGuid().ToString('D');connector_id=[guid]::NewGuid().ToString('D');generation=1;host_guid=[guid]::NewGuid().ToString('D');host_fqdn=([Environment]::MachineName.ToLowerInvariant()+'.lab.example');service_sid=$sid;appliance_fqdn='kaname.lab.example';appliance_tls_sha256=('a'*64);channel_key_sha256=(Get-AuthWireChannelPublicKeyId $rsa)}
 $release=[guid]::NewGuid().ToString('D');$request='1'*64
 $t=[pscustomobject][ordered]@{candidate_id=[guid]::NewGuid().ToString('D');network_candidate_id=[guid]::NewGuid().ToString('D');plan_id=[guid]::NewGuid().ToString('D');plan_version=1;gpo_id=[guid]::NewGuid().ToString('D');approval_sha256=('a'*64);network_manifest_sha256=('b'*64);manifest_sha256=('c'*64);draft_sha256=('d'*64);dependency_sha256=('e'*64);publisher_thumbprint=('A'*40);machine_profile_id=[guid]::NewGuid().ToString('D');machine_profile_version=3;domain='lab.example';root_thumbprint=('f'*40);group_sid=($domainSid+'-1647');content_result_sha256=('2'*64);target_sids_sha256=('3'*64);target_count=1}
 $gpoRoot=Join-Path $root ('fixture-{'+$t.gpo_id+'}');$null=New-Item -ItemType Directory -Path $gpoRoot
 foreach($n in @('Machine','User')){$null=New-Item -ItemType Directory -Path (Join-Path $gpoRoot $n)}
 [IO.File]::WriteAllText((Join-Path $gpoRoot 'GPT.INI'),"[General]`r`nVersion=0`r`n");[IO.File]::WriteAllText((Join-Path $gpoRoot 'GPO.cmt'),'never execute fixture')
 $inventory=Get-AuthWireSysvolInventory $gpoRoot;$files=@()
 foreach($n in Get-AuthWireCombinedStagingNames){$hash=Get-AuthWireJobHash ([Text.Encoding]::ASCII.GetBytes($n));if($n -ceq 'signed-manifest.json'){$hash=$t.manifest_sha256};if($n -ceq 'original-draft.zip'){$hash=$t.draft_sha256};$files+=,[pscustomobject][ordered]@{Path=$n;Size=31;Sha256=$hash;Sddl='O:BAG:BAD:P(A;;FA;;;SY)(A;;FA;;;BA)'}}
 $preview=New-AuthWireCombinedStagingPlanCore $t $files $inventory ('4'*64) ([DateTimeOffset]::UtcNow.ToUnixTimeSeconds())
 $target=[pscustomobject][ordered]@{scope_target=$t;preview_record=$preview;preview_job_id=[guid]::NewGuid().ToString('D');preview_result_sha256=('5'*64);writer_release_id=$release;stage_receipt=$null}
 function MakeOffer($WriteTarget=$target){
  $id=[guid]::NewGuid().ToString('D');$scope=Get-AuthWireJobScope $b
  $intent='AuthWireStagingWriteIntentV1'+"`n"+$scope+"`n"+$id+"`ncombined.filesystem.stage.v1`n"+(Get-AuthWireWriteHash $WriteTarget)+"`n"
  return [pscustomobject][ordered]@{format=1;request_id=$request;scope_sha256=$scope;job_id=$id;operation='combined.filesystem.stage.v1';lease_id=('6'*64);intent_sha256=(Get-AuthWireJobHash ([Text.Encoding]::ASCII.GetBytes($intent)));expires_at=$WriteTarget.preview_record.Preview.expires_at;target=$WriteTarget;write_authorized=$false;can_apply_gpo=$false}
 }
 $offer=MakeOffer
 Assert-AuthWireWriteOffer $offer $b $release $request;Check $true 'valid bounded offer'
 Check ((Get-AuthWireWritePreviewHash $preview.Preview) -ceq $preview.PreviewSha256) 'fixed preview order matches existing plan'
 Check ((ConvertTo-AuthWireWriteJson ([pscustomobject]@{z='quote" slash\ apostrophe''';a=@($null,$true,42)})) -ceq '{"a":[null,true,42],"z":"quote\" slash\\ apostrophe''"}') 'canonical JSON exact ASCII quoting and types'
 $reversed=ConvertFrom-AuthWireCandidateJson ([Text.Encoding]::ASCII.GetBytes((ConvertTo-AuthWireWriteJson $target)))
 Check ((Get-AuthWireWriteHash $reversed) -ceq (Get-AuthWireWriteHash $target)) 'target hash ignores property order'
 foreach($change in @('path','command','extra')){$v=Clone $offer;$v|Add-Member NoteProperty $change 'untrusted';Reject {Assert-AuthWireWriteOffer $v $b $release $request} 'unknown request field rejected'}
 foreach($field in @('write_authorized','can_apply_gpo')){$v=Clone $offer;$v.$field=$true;Reject {Assert-AuthWireWriteOffer $v $b $release $request} 'offer cannot grant authority'}
 foreach($field in @('intent_sha256','scope_sha256','lease_id')){$v=Clone $offer;$v.$field='bad';Reject {Assert-AuthWireWriteOffer $v $b $release $request} 'offer identity hash rejected'}
 $v=Clone $offer;$v.target.writer_release_id=[guid]::NewGuid().ToString('D');Reject {Assert-AuthWireWriteOffer $v $b $release $request} 'wrong worker release'
 $v=Clone $offer;$v.expires_at=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()-1;Reject {Assert-AuthWireWriteOffer $v $b $release $request} 'expired lease'
 $v=Clone $target;$v.preview_record.Preview.files[0].Path='../escape';Reject {Assert-AuthWireWriteTarget $v 'combined.filesystem.stage.v1'} 'source traversal'
 $v=Clone $target;$v.preview_record.Preview.files=$v.preview_record.Preview.files[0..18];Reject {Assert-AuthWireWriteTarget $v 'combined.filesystem.stage.v1'} 'missing file'
 $v=Clone $target;$v.preview_record.Preview.files[0].Sddl+='x';Reject {Assert-AuthWireWriteTarget $v 'combined.filesystem.stage.v1'} 'ACL hash drift'
 $v=Clone $target;$v.preview_record.Preview.checked_at=$true;Reject {Assert-AuthWireWriteTarget $v 'combined.filesystem.stage.v1'} 'bool is not a timestamp'
 $v=Clone $target;$v.scope_target.target_count=513;Reject {Assert-AuthWireWriteTarget $v 'combined.filesystem.stage.v1'} 'scope remains bounded at512'
 Reject {ConvertTo-AuthWireWriteJson ([double]1)} 'floating point not canonical integer'
 Reject {ConvertTo-AuthWireWriteJson ([string][char]256)} 'nonASCII target refused'
 Reject {ConvertFrom-AuthWireCandidateJson ([Text.Encoding]::ASCII.GetBytes('{"a":1,"a":2}'))} 'duplicate JSON keys'
 $journal=Join-Path $root 'journal';$null=New-Item -ItemType Directory -Path $journal
 $ja=Get-Acl -LiteralPath $journal;$ja.SetAccessRuleProtection($true,$true);Set-Acl -LiteralPath $journal -AclObject $ja
 $saved=Save-AuthWireStagingWriteOffer $offer $b $release $request $journal
 Check ($saved.Phase -ceq 'offer_saved' -and -not $saved.FilesystemWriteEnabled -and -not $saved.CanApplyGpo) 'durable offer is not execution'
 $loaded=Read-AuthWireStagingWriteOffer $journal $offer.job_id $b $release
 Check ((Get-AuthWireWriteHash $loaded) -ceq (Get-AuthWireWriteHash $offer)) 'exact offer persisted'
 Add-Type -TypeDefinition @'
using System;
using System.Threading;
namespace AuthWire.PreclaimFixture {
 public sealed class StoreHolderV1 : IDisposable {
  public readonly ManualResetEvent Ready=new ManualResetEvent(false), Release=new ManualResetEvent(false);
  public bool Held; readonly Thread thread;
  public StoreHolderV1(){thread=new Thread(Run);thread.IsBackground=true;thread.Start();}
  void Run(){try{using(var m=new Mutex(false,"Global\\AuthWireWritePreclaimStoreV1")){Held=m.WaitOne(1000);Ready.Set();if(Held){try{Release.WaitOne(5000);}finally{m.ReleaseMutex();}}}}finally{Ready.Set();}}
  public void Dispose(){Release.Set();if(!thread.Join(6000))throw new InvalidOperationException("FIXTURE_MUTEX_THREAD_TIMEOUT");Ready.Dispose();Release.Dispose();}
 }
}
'@
 $holder=[AuthWire.PreclaimFixture.StoreHolderV1]::new()
 try{
  Check ($holder.Ready.WaitOne(2000) -and $holder.Held) 'independent thread holds machine-wide prepare mutex'
  $code='';try{Save-AuthWireStagingWriteOffer $offer $b $release $request $journal|Out-Null}catch{$code=$_.Exception.Message}
  Check ($code -ceq 'WRITE_LOCAL_STORE_BUSY') 'parallel prepare fails at store mutex before journal changes'
 }finally{$holder.Dispose()}
 Reject {Save-AuthWireStagingWriteOffer $offer $b $release $request $journal} 'same job never recreated'
 $second=MakeOffer;Reject {Save-AuthWireStagingWriteOffer $second $b $release $request $journal} 'same GPO second job blocked'
 $rotated=@{};foreach($n in $b.Keys){$rotated[$n]=$b[$n]};$rotated.generation=2
 Reject {Read-AuthWireStagingWriteOffer $journal $offer.job_id $rotated $release} 'binding generation cannot reuse local intent'
 $weak=Join-Path $root 'weak-journal';$null=New-Item -ItemType Directory -Path $weak
 $wa=Get-Acl -LiteralPath $weak;$wa.SetAccessRuleProtection($true,$true);$wa.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new([Security.Principal.SecurityIdentifier]::new('S-1-5-11'),'ReadAndExecute','Allow'));Set-Acl -LiteralPath $weak -AclObject $wa
 Reject {Save-AuthWireStagingWriteOffer $offer $b $release $request $weak} 'broad journal ACL refused'
 Check (@(Get-ChildItem -LiteralPath $weak -Force).Count -eq 0) 'ACL failure writes no local intent'
 $junction=Join-Path $root 'journal-link';$null=New-Item -ItemType Junction -Path $junction -Target $journal
 try{Reject {Read-AuthWireStagingWriteOffer $junction $offer.job_id $b $release} 'journal reparse refused'}finally{[IO.Directory]::Delete($junction,$false)}
 Check (Test-Path -LiteralPath $journal) 'unlinking only fixture junction preserves journal'
 $file=Join-Path (Join-Path $journal $offer.job_id) 'offer.json'
 $link=Join-Path $root 'offer-hardlink.json';$null=New-Item -ItemType HardLink -Path $link -Target $file
 Reject {Read-AuthWireStagingWriteOffer $journal $offer.job_id $b $release} 'journal hardlink refused';Remove-Item -LiteralPath $link
 Set-Content -LiteralPath $file -Stream hostile -Value x
 Reject {Read-AuthWireStagingWriteOffer $journal $offer.job_id $b $release} 'journal alternate stream refused';Remove-Item -LiteralPath $file -Stream hostile
 # Only simulated directory/public-content observations are substituted here.
 $script:protected=[guid]::NewGuid().ToString('D');$script:pdc='dc01.lab.example';$script:domainCalls=0;$script:pdcChanges=$false
 function Get-AuthWireCombinedScopeContext {return [pscustomobject]@{Approval=[pscustomobject]@{domain=$t.domain;protected_gpo_id=$script:protected}}}
 function Get-ADDomain {$script:domainCalls++;$server=if($script:pdcChanges -and $script:domainCalls -gt 1){'dc02.lab.example'}else{$script:pdc};return [pscustomobject]@{DNSRoot=$t.domain;DomainSID=[pscustomobject]@{Value=$domainSid};PDCEmulator=$server}}
 function Get-AuthWireCombinedStagingPreview {return (Clone $preview)}
 $live=Get-AuthWireWriteStageLiveContext $offer $b $t.publisher_thumbprint 'https://kaname.lab.example/'
 Assert-AuthWireWriteLiveContext $live $offer $b
 Check ($live.gpo_root -ceq ('\\dc01.lab.example\SYSVOL\lab.example\Policies\{'+$t.gpo_id+'}')) 'GPO path derived locally'
 Check ($live.source_root.StartsWith([Environment]::GetFolderPath('CommonApplicationData'),[StringComparison]::Ordinal)) 'source path derived from ProgramData'
 $permutedOffer=MakeOffer $reversed
 $permutedLive=Get-AuthWireWriteStageLiveContext $permutedOffer $b $t.publisher_thumbprint 'https://kaname.lab.example/'
 Check ($permutedLive.target_sha256 -ceq (Get-AuthWireWriteHash $target)) 'permuted JSON property order reaches the original fixed-order context guard'
 $script:pdcChanges=$true;$script:domainCalls=0
 Reject {Get-AuthWireWriteStageLiveContext $offer $b $t.publisher_thumbprint 'https://kaname.lab.example/'} 'PDC movement during preflight'
 $script:pdcChanges=$false;$script:protected=$t.gpo_id
 Reject {Get-AuthWireWriteStageLiveContext $offer $b $t.publisher_thumbprint 'https://kaname.lab.example/'} 'protected trust GPO rejected'
 $script:protected=[guid]::NewGuid().ToString('D')
 $v=Clone $live;$v.source_root='C:\Windows';Reject {Assert-AuthWireWriteLiveContext $v $offer $b} 'returned source path cannot override local derivation'
 $v=Clone $live;$v.gpo_root='\\evil\share';Reject {Assert-AuthWireWriteLiveContext $v $offer $b} 'returned UNC cannot redirect'
 $v=Clone $live;$v.checked_at=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()-6;Reject {Assert-AuthWireWriteLiveContext $v $offer $b} 'five second claim preflight freshness'
 $v=Clone $live;$v.can_apply_gpo=$true;Reject {Assert-AuthWireWriteLiveContext $v $offer $b} 'context never grants GPO activation'
 # Test the durable preclaim gate using a controlled already-validated reader result.
 $live.checked_at=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
 Write-AuthWireStagingJournal (Join-Path (Join-Path $journal $offer.job_id) 'preflight.json') $live
 $proof=New-AuthWireStagingWriteClaim $journal $offer.job_id $b $release $rsa
 Check (Test-Path -LiteralPath (Join-Path (Join-Path $journal $offer.job_id) 'claim-started.json')) 'claim-started durable before returned proof'
 Check (Test-Path -LiteralPath (Join-Path (Join-Path $journal $offer.job_id) 'claim-proof.json')) 'claim proof persisted before return'
 Reject {New-AuthWireStagingWriteClaim $journal $offer.job_id $b $release $rsa} 'lost reply never produces second claim'
 . (Join-Path $lib 'StagingWritePreclaim.ps1')
 Reject {New-AuthWireStagingWriteClaim $journal $offer.job_id $b $release $rsa} 'module reload does not reset durable claim'
 $failedJournal=Join-Path $root 'failed-signing';$null=New-Item -ItemType Directory -Path $failedJournal
 $ja=Get-Acl -LiteralPath $failedJournal;$ja.SetAccessRuleProtection($true,$true);Set-Acl -LiteralPath $failedJournal -AclObject $ja
 $null=Save-AuthWireStagingWriteOffer $offer $b $release $request $failedJournal
 $live.checked_at=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds();Write-AuthWireStagingJournal (Join-Path (Join-Path $failedJournal $offer.job_id) 'preflight.json') $live
 $originalProof=${function:New-AuthWireStagingWriteProof}
 try{function New-AuthWireStagingWriteProof {throw 'SIMULATED_SIGNING_FAILURE'};Reject {New-AuthWireStagingWriteClaim $failedJournal $offer.job_id $b $release $rsa} 'signing failure refused'}finally{Set-Item -Path Function:New-AuthWireStagingWriteProof -Value $originalProof}
 Check (Test-Path -LiteralPath (Join-Path (Join-Path $failedJournal $offer.job_id) 'claim-started.json')) 'failed signing retains intent'
 Check (-not (Test-Path -LiteralPath (Join-Path (Join-Path $failedJournal $offer.job_id) 'claim-proof.json'))) 'failed signing does not publish a proof'
 Reject {New-AuthWireStagingWriteClaim $failedJournal $offer.job_id $b $release $rsa} 'failed signing cannot be blindly retried'
 $fullJournal=Join-Path $root 'full-store';$null=New-Item -ItemType Directory -Path $fullJournal
 $ja=Get-Acl -LiteralPath $fullJournal;$ja.SetAccessRuleProtection($true,$true);Set-Acl -LiteralPath $fullJournal -AclObject $ja
 foreach($i in 1..64){[IO.File]::WriteAllText((Join-Path $fullJournal ('owned-fixture-'+$i)), 'fixture')}
 Reject {Save-AuthWireStagingWriteOffer $offer $b $release $request $fullJournal} 'local store bounded before another job'
 $poll=New-AuthWireStagingWriteProof $b $rsa POLL @{capability='combined.filesystem.write.v1';release_id=$release}
 $result=New-AuthWireStagingWriteProof $b $rsa RESULT @{job_id=$offer.job_id;lease_id=$offer.lease_id;intent_sha256=$offer.intent_sha256;target_sha256=(Get-AuthWireWriteHash $target);release_id=$release;authorization_id='';checked_at=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds();outcome='refused_before_authorization';reason='PREFLIGHT_FAILED';journal_sha256='';tree_sha256='';filesystem_effects='none'}
 Reject {New-AuthWireStagingWriteProof $b $rsa CLAIM @{padding=('x'*1025)}} 'proof payload bounded'
 $gpoAfter=Get-AuthWireSysvolInventory $gpoRoot
 Check ($gpoAfter.Sha256 -ceq $inventory.Sha256) 'no GPO tree bytes or ACL changed'
 Check (@(Get-ChildItem -LiteralPath (Join-Path $gpoRoot 'Machine') -Force).Count -eq 0) 'no package staged or executed'
 foreach($name in @('ConnectorServicePackage.ps1','ConnectorServiceRuntime.ps1')){Check (-not ([IO.File]::ReadAllText((Join-Path $lib $name))).Contains('StagingWritePreclaim')) 'new preclaim not registered in active package/runtime'}
 Initialize-AuthWireChannelTypes
 if($env:AUTHWIRE_WRITE_WIRE_OUTPUT){$wire=[ordered]@{binding=$b;public_key_pem=[AuthWire.Connector.ChannelTypesV1]::PublicPem($rsa);target=$target;target_sha256=(Get-AuthWireWriteHash $target);offer=$offer;proofs=@(@{kind='POLL';proof=$poll},@{kind='CLAIM';proof=$proof},@{kind='RESULT';proof=$result})};[IO.File]::WriteAllText($env:AUTHWIRE_WRITE_WIRE_OUTPUT,($wire|ConvertTo-Json -Depth 15 -Compress),[Text.UTF8Encoding]::new($false))}
 # Genuine fixed AllSigned child: use only a disposable signed package with an
 # invalid config, so the real entry loads but stops BEFORE AD access.
 $readerPackage=Join-Path $root 'signed-reader';$null=New-Item -ItemType Directory -Path $readerPackage
 $signer=New-SelfSignedCertificate -Type CodeSigningCert -Subject ('CN=AuthWire-Preclaim-Fixture-'+[guid]::NewGuid().ToString('N')) -CertStoreLocation Cert:\LocalMachine\My -KeyAlgorithm RSA -KeyLength 3072 -KeyExportPolicy NonExportable -NotAfter (Get-Date).AddDays(1)
 $public=[Security.Cryptography.X509Certificates.X509Certificate2]::new($signer.Export([Security.Cryptography.X509Certificates.X509ContentType]::Cert))
 foreach($storeName in @('Root','TrustedPublisher')){$s=[Security.Cryptography.X509Certificates.X509Store]::new($storeName,'LocalMachine');try{$s.Open('ReadWrite');$s.Add($public)}finally{$s.Close()}}
 $dependencies=@('Compare-AuthWireSigningKeyAcl.ps1','Invoke-AuthWireConnectorProbeJob.ps1','Invoke-AuthWireCandidateJob.ps1','DeploymentScope.ps1','Invoke-AuthWireScopeJob.ps1','CombinedCandidateContent.ps1','Invoke-AuthWireCombinedJob.ps1','CombinedDeploymentScope.ps1','Invoke-AuthWireCombinedScopeJob.ps1','SysvolInventory.ps1','CombinedStagingPreview.ps1','StagingFilesystem.ps1','StagingWritePreclaim.ps1','Test-AuthWireDeploymentCandidate.ps1','Read-AuthWireStagingWritePreflight.ps1')
 foreach($name in $dependencies){$to=Join-Path $readerPackage $name;[IO.File]::WriteAllBytes($to,[IO.File]::ReadAllBytes((Join-Path $lib $name)));$sig=Set-AuthenticodeSignature -FilePath $to -Certificate $signer -HashAlgorithm SHA256;Check ($sig.Status -eq 'Valid') 'disposable signed reader dependency'}
 [IO.File]::WriteAllText((Join-Path $readerPackage 'service.json'),'{"RootPath":"deliberately-wrong"}')
 Initialize-AuthWireScopeProcess
 $exe=Join-Path ([Environment]::GetFolderPath('Windows')) 'System32\WindowsPowerShell\v1.0\powershell.exe'
 $arguments='-NoLogo -NoProfile -NonInteractive -ExecutionPolicy AllSigned -File "'+(Join-Path $readerPackage 'Read-AuthWireStagingWritePreflight.ps1')+'" -JournalRoot "'+$journal+'" -JobId '+$offer.job_id
 $read=[AuthWire.Connector.ScopeProcessV1]::Run($exe,$arguments,10000)
 Check (-not $read.TimedOut -and -not $read.Truncated -and $read.ExitCode -eq 20 -and $read.Output.Trim() -ceq '{"error":"WRITE_PREFLIGHT_FAILED"}') 'actual signed fixed child safely refuses config before AD'
 . (Join-Path $readerPackage 'StagingWritePreclaim.ps1')
 $preflightPath=Join-Path (Join-Path $journal $offer.job_id) 'preflight.json'
 $preflightBefore=Get-AuthWireCandidateHash (Read-AuthWireCandidateBytes $preflightPath 65536)
 $refusal='';try{Invoke-AuthWireStagingWritePreflight $journal $offer.job_id $b $release|Out-Null}catch{$refusal=$_.Exception.Message}
 Check ($refusal -ceq 'WRITE_PREFLIGHT_FAILED') 'actual parent invokes fixed signed child and rejects failure'
 Check ((Get-AuthWireCandidateHash (Read-AuthWireCandidateBytes $preflightPath 65536)) -ceq $preflightBefore) 'failed child never replaces earlier preflight record'
 $slow=Join-Path $readerPackage 'bounded-fixture.ps1';[IO.File]::WriteAllText($slow,'Start-Sleep -Seconds 3');$null=Set-AuthenticodeSignature -FilePath $slow -Certificate $signer -HashAlgorithm SHA256
 $timer=[Diagnostics.Stopwatch]::StartNew();$read=[AuthWire.Connector.ScopeProcessV1]::Run($exe,('-NoLogo -NoProfile -NonInteractive -ExecutionPolicy AllSigned -File "'+$slow+'"'),200);$timer.Stop()
 Check ($read.TimedOut -and $timer.ElapsedMilliseconds -lt 5000) 'actual AllSigned timeout is bounded'
 Write-Host ('AUTHWIRE_WRITE_PRECLAIM_WINDOWS_OK checks='+$checks+' customer_ad_tested=false write_enabled=false claim_sent=false')
}finally{
 if($signer){foreach($storeName in @('Root','TrustedPublisher','My')){$path='Cert:\LocalMachine\'+$storeName+'\'+$signer.Thumbprint;if(Test-Path -LiteralPath $path){if($storeName -ceq 'My'){Remove-Item -LiteralPath $path -DeleteKey -Force}else{Remove-Item -LiteralPath $path -Force}}}}
 if($public){$public.Dispose()}
 if($rsa){$rsa.Dispose()};if($key){try{$key.Delete()}finally{$key.Dispose()}}
 if(Test-Path -LiteralPath $root){Remove-Item -LiteralPath $root -Recurse -Force}
}
