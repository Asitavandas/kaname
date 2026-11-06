# Exact on-prem natural-expiry pilot. No clock, NIC, GPO or main-client state edits.
param([ValidateSet('Check','Seed','Arm','Recover','Inspect')][string]$Mode='Check')
$ErrorActionPreference='Stop'
$operatorPath=$PSCommandPath;$caseRoot=$PSScriptRoot;$run='20261106-expiry-natural-7249ec821a0d4c97'
$taskName='AuthWire-Expiry-Natural-7249ec821a0d4c97'
$description='AuthWire natural expiry pilot 7249ec821a0d4c97'
$publisher='6E74B513F766E01730719684A41B2664380CA68A'
$mainRoot='C:\ProgramData\AuthWire';$mainThumb='BD498F87BB886AE760B3FAC40AB7BB6D2AC3B987'
$pins=@{'AuthWire-Client.ps1'='F11A857F727F8CC04D43583A3B0BF4532A1E864EAD74836370242A9682CAE60F';'config.json'='A02B6946A929C65508402070BEA230493239FB7C67328F6A1C130D39F269B4C1';'root-ca.pem'='4F25C29BB9C373A9BE8DA92A0ECBA7B6FD123264E398427FD67060CD3AF96328';'issuer-ca.pem'='B09A9E69771E30FC08257F04AFD7C3613770A20E06F15D9845FB4A4790063B42';'https-trust.pem'='88C30E357D38359F9A7CC1F087229C05757760EB54E8EF4E5A90F14444C83083'}
function Hash($p){(Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash}
function Management {
 [ordered]@{Adapter=@(Get-NetAdapter Ethernet1|Select-Object Name,InterfaceGuid,ifIndex,MacAddress);IPv4=@(Get-NetIPAddress -InterfaceAlias Ethernet1 -AddressFamily IPv4|Select-Object IPAddress,PrefixLength,SkipAsSource,PrefixOrigin,SuffixOrigin);IPInterface=@(Get-NetIPInterface -InterfaceAlias Ethernet1 -AddressFamily IPv4|Select-Object Dhcp,AutomaticMetric,InterfaceMetric);DNS=@(Get-DnsClientServerAddress -InterfaceAlias Ethernet1 -AddressFamily IPv4|Select-Object ServerAddresses);DefaultRoute=@(Get-NetRoute -InterfaceAlias Ethernet1 -DestinationPrefix '0.0.0.0/0'|Select-Object NextHop,RouteMetric)}|ConvertTo-Json -Depth 6 -Compress
}
function Save-Case($name,$value){
 $p=Join-Path $caseRoot $name;$tmp=$p+'.next'
 foreach($f in $p,$tmp){if((Test-Path $f) -and ((Get-Item $f).Attributes -band [IO.FileAttributes]::ReparsePoint)){throw 'Case reparse point refused'}}
 [IO.File]::WriteAllText($tmp,($value|ConvertTo-Json -Depth 8),(New-Object Text.UTF8Encoding($false)))
 [AuthWireTls]::AtomicReplace($tmp,$p)
}
function Assert-Identity {
 $base=(Get-Content (Join-Path (Split-Path $caseRoot) 'management-before.json') -Raw|ConvertFrom-Json)|ConvertTo-Json -Depth 6 -Compress
 if((Management) -cne $base -or (Get-NetAdapter Ethernet1).Status -ne 'Up'){throw 'Management baseline changed'}
 $m=Get-Content (Join-Path $mainRoot 'installed.json') -Raw|ConvertFrom-Json
 if($m.thumbprint -cne $mainThumb -or !(Get-Item ('Cert:\LocalMachine\My\'+$mainThumb)).HasPrivateKey){throw 'Existing production identity changed'}
 return $m
}
function Arm-Case([datetime]$When){
 $existing=Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
 $exe="$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
 $taskArguments='-NoProfile -NonInteractive -ExecutionPolicy AllSigned -File "'+$operatorPath+'" -Mode Recover'
 if($existing -and ($existing.Description -cne $description -or @($existing.Actions).Count -ne 1 -or $existing.Actions.Execute -ine $exe -or $existing.Actions.Arguments -notin @($taskArguments,$taskArguments.Replace('-Mode Recover','-Mode Seed')))){throw 'Owned task definition changed'}
 $minimum=[datetime]::UtcNow.AddSeconds(10);if($When -lt $minimum){$When=$minimum}
 $fraction=$When.Ticks % [TimeSpan]::TicksPerSecond;if($fraction){$When=$When.AddTicks([TimeSpan]::TicksPerSecond-$fraction)}
 $a=New-ScheduledTaskAction -Execute $exe -Argument $taskArguments
 $settings=New-ScheduledTaskSettingsSet -StartWhenAvailable -RunOnlyIfNetworkAvailable -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 10)
 $null=Register-ScheduledTask -TaskName $taskName -Action $a -Trigger (New-ScheduledTaskTrigger -Once -At $When.ToLocalTime()) -Settings $settings -Principal (New-ScheduledTaskPrincipal -UserId SYSTEM -LogonType ServiceAccount -RunLevel Highest) -Description $description -Force
 $sc=New-Object -ComObject Schedule.Service;$sc.Connect();$sc.GetFolder('\').GetTask($taskName).SetSecurityDescriptor('D:P(A;;GA;;;SY)(A;;GA;;;BA)',0)
 return $When.ToString('o')
}
if($env:COMPUTERNAME -ine 'VV-CLIENT01' -or (Split-Path $caseRoot -Leaf) -cne $run){throw 'Exact isolated endpoint case required'}
foreach($n in $pins.Keys){$p=Join-Path $caseRoot $n;if((Get-Item $p).Attributes -band [IO.FileAttributes]::ReparsePoint -or (Hash $p) -cne $pins[$n]){throw 'Case asset pin changed'}}
foreach($p in $PSCommandPath,(Join-Path $caseRoot 'AuthWire-Client.ps1')){$s=Get-AuthenticodeSignature $p;if($s.Status -ne 'Valid' -or $s.SignerCertificate.Thumbprint -cne $publisher){throw 'Existing publisher required'}}
$source=Join-Path $caseRoot 'AuthWire-Client.ps1'
. $source -ValidateOnly
$tokens=$null;$errors=$null;$ast=[Management.Automation.Language.Parser]::ParseFile($source,[ref]$tokens,[ref]$errors)
if($errors.Count){throw 'Production source parse failed'}
foreach($name in 'Save-State','Post-Json','Protected-Post','Key-Proof'){
 $fn=@($ast.EndBlock.Statements|Where-Object {$_ -is [Management.Automation.Language.FunctionDefinitionAst] -and $_.Name -eq $name})
 if($fn.Count -ne 1){throw 'Production function layout changed'};. ([scriptblock]::Create($fn[0].Extent.Text))
}
$main=@($ast.EndBlock.Statements|Where-Object {$_ -is [Management.Automation.Language.TryStatementAst]})
$csrBlock=@($main[0].Body.Statements|Where-Object {$_ -is [Management.Automation.Language.IfStatementAst] -and $_.Extent.Text.StartsWith('if(!(Test-Path $pendingFile))')})
if($main.Count -ne 1 -or $csrBlock.Count -ne 1){throw 'Production CSR layout changed'}
$config=Get-Content (Join-Path $caseRoot 'config.json') -Raw|ConvertFrom-Json
if($config.profile_id -cne '6d839150-d909-4844-bd45-f0bf5a341ca8'){throw 'Separate pilot profile required'}
$mainIdentity=Assert-Identity
if($Mode -eq 'Check'){'AUTHWIRE_NATURAL_EXPIRY_READ_ONLY_CHECK_OK';return}
if($Mode -eq 'Inspect'){foreach($n in 'seed-result.json','recovery-result.json'){if(Test-Path (Join-Path $caseRoot $n)){Get-Content (Join-Path $caseRoot $n) -Raw}};return}
if([Security.Principal.WindowsIdentity]::GetCurrent().User.Value -ne 'S-1-5-18'){throw 'SYSTEM required'}
$seedFile=Join-Path $caseRoot 'seed-result.json'
if($Mode -eq 'Seed'){
 if(Test-Path $seedFile){throw 'Seed already exists; use Arm or Inspect'}
 $directory=$caseRoot;$pendingFile=Join-Path $caseRoot 'pending.json';$session=$null;$private=$null;$serverError=$null
 $result=[ordered]@{event='AUTHWIRE_NATURAL_EXPIRY_SEED';started=[datetime]::UtcNow.ToString('o');seeded=$false;profile_id=$config.profile_id}
 $mutex=New-Object Threading.Mutex($false,'Global\AuthWire-Certificate-Client');$locked=$false
 try{
  $locked=$mutex.WaitOne(0);if(!$locked){throw 'Production enrollment currently active'}
  . ([scriptblock]::Create($csrBlock[0].Extent.Text))
  $pending=Get-Content $pendingFile -Raw|ConvertFrom-Json
  $key=[Security.Cryptography.CngKey]::Open($pending.container,[Security.Cryptography.CngProvider]::MicrosoftSoftwareKeyStorageProvider,[Security.Cryptography.CngKeyOpenOptions]::MachineKey)
  if($key.ExportPolicy -ne [Security.Cryptography.CngExportPolicies]::None){throw 'Nonexportable key required'}
  $private=New-Object Security.Cryptography.RSACng($key)
  [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
  [Net.ServicePointManager]::CheckCertificateRevocationList=$true;[AuthWireTls]::Pin=$config.tls_sha256
  $stage='session';$session=New-Object AuthWireSspi($config.spn)
  $answer=Post-Json '/api/device/session' @{token=[Convert]::ToBase64String($session.Start())}
  $session.Finish([Convert]::FromBase64String($answer.token));$sessionId=$answer.id
  $stage='challenge';$challenge=Protected-Post '/api/device/challenge' @{profile_id=$config.profile_id;csr=$pending.csr}
  $stage='issue';$issued=Protected-Post '/api/device/issue' @{challenge_id=$challenge.challenge_id;csr=$pending.csr;proof=(Key-Proof $challenge.payload)}
  $cert=New-Object Security.Cryptography.X509Certificates.X509Certificate2(,[Text.Encoding]::ASCII.GetBytes($issued.certificate))
  if($cert.Subject -cne 'CN=AuthWire computer 81089596-7e4a-44b7-a7af-d84bc4fbf974' -or $cert.NotAfter.ToUniversalTime() -lt [datetime]::UtcNow.AddHours(47)){throw 'Natural two-day issuance required'}
  if(Test-Path ('Cert:\LocalMachine\My\'+$cert.Thumbprint)){throw 'Seed must remain uninstalled'}
  [IO.File]::WriteAllText((Join-Path $caseRoot 'seed-certificate.pem'),$issued.certificate,[Text.Encoding]::ASCII)
  $result.seeded=$true;$result.serial=$issued.serial;$result.thumbprint=$cert.Thumbprint;$result.container=$pending.container
  $result.not_before=$cert.NotBefore.ToUniversalTime().ToString('o');$result.not_after=$cert.NotAfter.ToUniversalTime().ToString('o')
  $result.pending_sha256=Hash $pendingFile;$result.key_nonexportable=$true;$result.certificate_installed=$false
  $result.actual_kerberos_and_https=$true;$result.synthetic_transport=$false;$result.system_clock_changed=$false
  $result.original_installed_sha256=Hash (Join-Path $mainRoot 'installed.json')
  $null=Assert-Identity
  Save-Case 'seed-result.json' $result
  $result.next_run_utc=Arm-Case ($cert.NotAfter.ToUniversalTime().AddSeconds(60))
 }catch{$result.error_type=$_.Exception.GetType().FullName;$result.error_line=$_.InvocationInfo.ScriptLineNumber;$result.phase=$stage;$result.server_error=$serverError;throw}
 finally{if($private){$private.Dispose()};if($session){$session.Dispose()};if($locked){$mutex.ReleaseMutex()};$mutex.Dispose();$result.finished=[datetime]::UtcNow.ToString('o');Save-Case 'seed-result.json' $result;$result|ConvertTo-Json -Depth 5 -Compress}
 return
}
$seed=Get-Content $seedFile -Raw|ConvertFrom-Json
if(!$seed.seeded -or $seed.profile_id -cne $config.profile_id){throw 'Successful immutable seed required'}
$expiry=[datetimeoffset]::Parse($seed.not_after).UtcDateTime
if($Mode -eq 'Arm' -or [datetime]::UtcNow -le $expiry){Arm-Case ($expiry.AddSeconds(60));return}
$statePath=Join-Path $caseRoot 'recovery-result.json'
$result=[ordered]@{event='AUTHWIRE_NATURAL_EXPIRED_PENDING_RECOVERY';profile_id=$config.profile_id;attempts=0;expired_pending_archived=$false;recovered=$false;cleanup_complete=$false}
if(Test-Path $statePath){
 $previous=Get-Content $statePath -Raw|ConvertFrom-Json
 foreach($n in @('attempts','expired_pending_archived','archive_name','first_expired_rejection_utc','old_key_retained_by_client','recovered','cleanup_complete')){if($previous.PSObject.Properties.Name -contains $n){$result[$n]=$previous.$n}}
}
if($result.recovered){throw 'Recovery already terminal; inspect retained evidence'}
try {
 if([datetime]::UtcNow -gt $expiry.AddHours(24) -or $result.attempts -ge 20){throw 'Natural pilot observation bound reached'}
 if((Hash (Join-Path $mainRoot 'installed.json')) -cne $seed.original_installed_sha256){throw 'Main installed identity changed independently'}
 $retryPath=Join-Path $caseRoot 'retry.json'
 if(Test-Path $retryPath){
  $r=Get-Content $retryPath -Raw|ConvertFrom-Json
  $due=[datetimeoffset]::Parse($r.next_attempt).UtcDateTime
  if($due -gt [datetime]::UtcNow){$result.state='WAITING_REAL_CLIENT_DEADLINE';$result.next_run_utc=Arm-Case $due;Save-Case 'recovery-result.json' $result;return}
 }
 $result.attempts=[int]$result.attempts+1;$result.last_started=[datetime]::UtcNow.ToString('o')
 $before=[datetime]::UtcNow
 $out=Join-Path $caseRoot ('attempt-'+$result.attempts+'.stdout.txt');$err=Join-Path $caseRoot ('attempt-'+$result.attempts+'.stderr.txt')
 if((Test-Path $out) -or (Test-Path $err)){throw 'Attempt evidence already exists'}
 $child=Start-Process -FilePath "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -ArgumentList ('-NoProfile -NonInteractive -ExecutionPolicy AllSigned -File "'+$source+'" -NoJitter') -PassThru -WindowStyle Hidden -RedirectStandardOutput $out -RedirectStandardError $err
 if(!$child.WaitForExit(480000)){$child.Kill();throw 'Owned production client exceeded pilot bound'}
 $child.Refresh();$result.last_exit=[int]$child.ExitCode
 $statusFile=Join-Path $caseRoot 'status.json'
 if(!(Test-Path $statusFile)){$result.state='WAITING_ENROLLMENT_MUTEX';$result.next_run_utc=Arm-Case ([datetime]::UtcNow.AddMinutes(5));Save-Case 'recovery-result.json' $result;return}
 $status=Get-Content $statusFile -Raw|ConvertFrom-Json
 if($status.server_error -ceq 'DEVICE_CERTIFICATE_EXPIRED' -and $status.expired_pending_archived){
  $r=Get-Content $retryPath -Raw|ConvertFrom-Json
  if($r.expired_pending_archive -cnotmatch '^[0-9a-f]{32}\.json$'){throw 'Unexpected archive name'}
  $archive=Join-Path (Join-Path $caseRoot 'expired-pending') $r.expired_pending_archive
  if((Hash $archive) -cne $seed.pending_sha256 -or (Test-Path (Join-Path $caseRoot 'pending.json'))){throw 'Expired request archive mismatch'}
  $oldKey=[Security.Cryptography.CngKey]::Open($seed.container,[Security.Cryptography.CngProvider]::MicrosoftSoftwareKeyStorageProvider,[Security.Cryptography.CngKeyOpenOptions]::MachineKey)
  try{if($oldKey.ExportPolicy -ne [Security.Cryptography.CngExportPolicies]::None){throw 'Old pending key policy changed'}}finally{$oldKey.Dispose()}
  $result.expired_pending_archived=$true;$result.archive_name=$r.expired_pending_archive;$result.old_key_retained_by_client=$true
  if(!$result.Contains('first_expired_rejection_utc')){$result.first_expired_rejection_utc=$status.checked_at}
 }
 if($result.last_exit -eq 0 -and $status.state -ceq 'installed'){
  if(!$result.expired_pending_archived){throw 'Real expired rejection evidence missing'}
  $i=Get-Content (Join-Path $caseRoot 'installed.json') -Raw|ConvertFrom-Json
  if($i.serial -ceq $seed.serial -or $i.container -ceq $seed.container -or $i.thumbprint -ceq $mainThumb -or $i.container -ceq $mainIdentity.container -or (Test-Path $retryPath) -or (Test-Path (Join-Path $caseRoot 'pending.json'))){throw 'Fresh isolated recovered identity required'}
  $cert=Get-Item ('Cert:\LocalMachine\My\'+$i.thumbprint)
  $chain=New-Object Security.Cryptography.X509Certificates.X509Chain($true)
  try{
   $chain.ChainPolicy.RevocationMode='Online';$chain.ChainPolicy.RevocationFlag='ExcludeRoot';$chain.ChainPolicy.VerificationFlags='NoFlag';$chain.ChainPolicy.UrlRetrievalTimeout=[TimeSpan]::FromSeconds(10)
   if(!$cert.HasPrivateKey -or $cert.Subject -cne 'CN=AuthWire computer 81089596-7e4a-44b7-a7af-d84bc4fbf974' -or !$chain.Build($cert) -or $chain.ChainElements.Count -ne 3 -or $chain.ChainElements[1].Certificate.Thumbprint -cne 'E981DD42A758B6C2408E211F82833F6B2EC6EED2' -or $chain.ChainElements[2].Certificate.Thumbprint -cne 'C789A0595ADB95A6BE4534D01B1D205F6C37DE18'){throw 'Recovered identity or online chain invalid'}
  }finally{$chain.Dispose()}
  $result.recovered=$true;$result.new_serial=$i.serial;$result.new_thumbprint=$i.thumbprint;$result.new_container=$i.container
  $result.actual_kerberos_and_https=$true;$result.client_install_and_receipt=$true;$result.online_chain_valid=$true;$result.synthetic_transport=$false;$result.system_clock_changed=$false
  Save-Case 'recovery-result.json' $result
  # Only the two generated pilot keys and its recovered leaf are disposable.
  $mainNow=Assert-Identity
  $protected=@($mainNow.container)+@($mainNow.previous|ForEach-Object {$_.container})
  foreach($n in @($seed.container,$i.container)){if($n -cnotmatch '^AuthWire-[0-9a-fA-F-]{36}$' -or $n -in $protected){throw 'Disposable key ownership refused'}}
  $rsa=[Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($cert)
  try{if($rsa.Key.KeyName -cne $i.container){throw 'Recovered key reference differs'};$rsa.Key.Delete()}finally{$rsa.Dispose()}
  Remove-Item ('Cert:\LocalMachine\My\'+$i.thumbprint)
  $oldKey=[Security.Cryptography.CngKey]::Open($seed.container,[Security.Cryptography.CngProvider]::MicrosoftSoftwareKeyStorageProvider,[Security.Cryptography.CngKeyOpenOptions]::MachineKey)
  try{$oldKey.Delete()}finally{$oldKey.Dispose()}
  $null=Assert-Identity
  if((Hash (Join-Path $mainRoot 'installed.json')) -cne $seed.original_installed_sha256){throw 'Main installed identity changed'}
  $result.cleanup_complete=$true;$result.state='RECOVERED_AND_DISPOSABLE_KEYS_CLEANED';$result.completed_utc=[datetime]::UtcNow.ToString('o')
  $result.ethernet1_unchanged=$true;$result.production_identity_unchanged=$true;$result.radius_selected_leaf_measured=$false
  Save-Case 'recovery-result.json' $result
  $t=Get-ScheduledTask $taskName
  if($t.Description -cne $description -or $t.Actions.Arguments -cne ('-NoProfile -NonInteractive -ExecutionPolicy AllSigned -File "'+$operatorPath+'" -Mode Recover')){throw 'Owned terminal task changed'}
  Unregister-ScheduledTask $taskName -Confirm:$false
 }elseif(Test-Path $retryPath){
  $r=Get-Content $retryPath -Raw|ConvertFrom-Json;$due=[datetimeoffset]::Parse($r.next_attempt).UtcDateTime
  if($due -gt [datetime]::UtcNow.AddHours(13)){throw 'Client deadline outside bound'}
  $result.state='WAITING_REAL_CLIENT_DEADLINE';$result.next_run_utc=Arm-Case $due
 }else{
  $result.state='WAITING_ENROLLMENT_MUTEX';$result.next_run_utc=Arm-Case ([datetime]::UtcNow.AddMinutes(5))
 }
}catch{
 $result.state=if($result.recovered){'RECOVERED_CLEANUP_REVIEW_REQUIRED'}else{'BLOCKED_REQUIRES_REVIEW'}
 $result.error_type=$_.Exception.GetType().FullName;$result.error_line=$_.InvocationInfo.ScriptLineNumber
 $t=Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
 if($t -and $t.Description -ceq $description){Disable-ScheduledTask -TaskName $taskName|Out-Null}
}finally{
 $result.checked_utc=[datetime]::UtcNow.ToString('o');Save-Case 'recovery-result.json' $result
 $result|ConvertTo-Json -Depth 7 -Compress
}

