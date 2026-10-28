param([Parameter(Mandatory=$true)][string]$Directory)
$ErrorActionPreference='Stop';Set-StrictMode -Version 2
if($env:RUNNER_ENVIRONMENT -ne 'github-hosted'){throw 'Hosted Windows fixture only'}
$source=Join-Path $PSScriptRoot '..\windows\connector'
foreach($f in @('Compare-AuthWireSigningKeyAcl.ps1','ConnectorChannelTypes.ps1','ConnectorChannelKey.ps1','New-AuthWireConnectorHealthProof.ps1','ConnectorServicePackage.ps1','ConnectorServiceControl.ps1','Invoke-AuthWireConnectorProbeJob.ps1','ConnectorServiceUpgrade.ps1')){. (Join-Path $source $f)}
$checks=0
function Check([bool]$v,[string]$m){if(-not $v){throw $m};$script:checks++}
function Reject([scriptblock]$s,[string]$m){$caught=$false;try{$null=& $s}catch{$caught=$true};Check $caught $m}
function Wait-Until([scriptblock]$s,[int]$seconds,[string]$message){$end=[DateTime]::UtcNow.AddSeconds($seconds);do{if(& $s){return};Start-Sleep -Milliseconds 500}while([DateTime]::UtcNow -lt $end);throw $message}
function Read-Status {if(Test-Path -LiteralPath $script:statusPath){try{return (Get-Content -LiteralPath $script:statusPath -Raw|ConvertFrom-Json)}catch{}};return $null}
$freshControlModes=@()
function Invoke-FreshPublicControl([string]$Mode){
 # Do not preload System.ServiceProcess or run Get-Service in this child.
 # The signed public entry point must load its own framework dependencies.
 $powershell=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
 $output=@(& $powershell -NoLogo -NoProfile -NonInteractive -ExecutionPolicy AllSigned -File $script:adminTool -Mode $Mode -ConnectorId $script:base.connector_id -PublisherThumbprint $script:publisher.Thumbprint 2>&1)
 if($LASTEXITCODE -ne 0){throw ('Fresh public '+$Mode+' failed: '+($output -join "`n"))}
 $result=($output -join "`n")|ConvertFrom-Json
 if($result.Event -cne 'WINDOWS_CONNECTOR_SERVICE_CONTROL' -or $result.Mode -cne $Mode -or $result.ServiceName -cne $script:name -or $result.ReleaseId -cne $script:config.ReleaseId){throw 'Fresh public control returned unexpected scope'}
 $script:freshControlModes+=$Mode
 return $result
}
$user=$null;$sid=$null;$key=$null;$root=$null;$keyRoot=$null;$name=$null;$publisher=$null;$public=$null;$web=$null;$roots=$null;$publishers=$null;$hostBytes=$null;$rightsAdded=$false;$secret=$null
$upgradePaths=@()
$hosts=Join-Path $env:SystemRoot 'System32\drivers\etc\hosts'
try{
 # The fixture owns a new, temporary local user; no AD/gMSA credential is used.
 $user='awt'+[guid]::NewGuid().ToString('N').Substring(0,10)
 $random=New-Object byte[] 32;$rng=[Security.Cryptography.RandomNumberGenerator]::Create();try{$rng.GetBytes($random)}finally{$rng.Dispose()}
 $secret=ConvertTo-SecureString ('Aa1!'+[Convert]::ToBase64String($random)) -AsPlainText -Force
 $local=New-LocalUser -Name $user -Password $secret -AccountNeverExpires -PasswordNeverExpires
 $sid=$local.Sid.Value;$credential=[Management.Automation.PSCredential]::new(([Environment]::MachineName+'\'+$user),$secret)
 $base=Get-Content -LiteralPath (Join-Path $Directory 'base.json') -Raw|ConvertFrom-Json
 $b=@{instance_id=$base.instance_id;connector_id=$base.connector_id;host_guid=$base.host_guid;host_fqdn=([Environment]::MachineName.ToLowerInvariant()+'.lab.example');service_sid=$sid;appliance_fqdn=$base.appliance_fqdn;appliance_tls_sha256=$base.appliance_tls_sha256}
 $id=([guid]$base.connector_id).ToString('N');$name='AuthWireConnector-'+$id
 $keyRoot=Join-Path $env:ProgramData ('AuthWire-Connector-'+$id)
 if(Test-Path -LiteralPath $keyRoot){$keyRoot=$null;throw 'Fixture key directory collision'}
 $prepared=Initialize-AuthWireChannelKeyCore -Mode PrepareKey -Directory $keyRoot -BaseBinding $b
 $key=$prepared.KeyName;$b.generation=1;$b.channel_key_sha256=$prepared.KeySha256
 $receipt=Get-Content -LiteralPath $prepared.ReceiptPath -Raw|ConvertFrom-Json
 $publisher=New-SelfSignedCertificate -Type CodeSigningCert -Subject ('CN=AuthWire permanent service fixture '+$id) -CertStoreLocation 'Cert:\LocalMachine\My' -KeyExportPolicy NonExportable -HashAlgorithm SHA256 -NotAfter (Get-Date).AddDays(1)
 $public=[Security.Cryptography.X509Certificates.X509Certificate2]::new($publisher.RawData)
 $web=[Security.Cryptography.X509Certificates.X509Certificate2]::new((Join-Path $Directory 'web.crt'))
 $roots=[Security.Cryptography.X509Certificates.X509Store]::new('Root','LocalMachine');$roots.Open([Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite);$roots.Add($public);$roots.Add($web)
 $publishers=[Security.Cryptography.X509Certificates.X509Store]::new('TrustedPublisher','LocalMachine');$publishers.Open([Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite);$publishers.Add($public)
 $hostBytes=[IO.File]::ReadAllBytes($hosts)
 [IO.File]::WriteAllBytes($hosts,($hostBytes+[Text.Encoding]::ASCII.GetBytes("`r`n127.0.0.1 "+$b.appliance_fqdn+"`r`n")))
 # Load only existing, bounded LSA helpers. Mutate our new local SID, then remove it.
 $tokens=$null;$errors=$null
 $ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $source 'Initialize-AuthWireServiceLogon.ps1'),[ref]$tokens,[ref]$errors)
 $literal=@($ast.FindAll({param($n)$n -is [Management.Automation.Language.StringConstantExpressionAst] -and $n.Value -like '*class LocalServiceRightV1*'},$true))[0]
 Add-Type -TypeDefinition $literal.Value
 $ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot 'connector_service_right_prepare_windows_check.ps1'),[ref]$tokens,[ref]$errors)
 $literal=@($ast.FindAll({param($n)$n -is [Management.Automation.Language.StringConstantExpressionAst] -and $n.Value -like '*class FixtureServiceRightCleanupV1*'},$true))[0]
 Add-Type -TypeDefinition $literal.Value
 $rightsAdded=$true;[AuthWire.Connector.LocalServiceRightV1]::GrantServiceRight($sid)
 $root=Join-Path $env:ProgramW6432 ('AuthWire-Connector-'+$id)
 if(Test-Path -LiteralPath $root){$root=$null;throw 'Fixture package directory collision'}
 $config=@{Version=1;ReleaseId=[guid]::NewGuid().ToString('D');ServiceName=$name;AccountName=$credential.UserName;PublisherThumbprint=$publisher.Thumbprint;BaseUrl=('https://'+$b.appliance_fqdn+':'+$base.port+'/');Binding=$b;KeyName=$key;ExpectedKeySddl=$receipt.ExpectedKeySddl;RootPath=$root}|ConvertTo-Json -Depth 6|ConvertFrom-Json
 $buildSource=Join-Path $Directory 'reviewed-source';$null=New-Item -ItemType Directory -Path $buildSource
 foreach($file in @('ConnectorServiceHost.cs','ConnectorServiceRuntime.ps1','ConnectorServicePackage.ps1','ConnectorServiceControl.ps1','Install-AuthWireConnectorService.ps1','New-AuthWireConnectorServicePackage.ps1','Initialize-AuthWireConnectorChannelKey.ps1','ConnectorChannelKey.ps1','ConnectorChannelTypes.ps1','Compare-AuthWireSigningKeyAcl.ps1','New-AuthWireConnectorHealthProof.ps1','Invoke-AuthWireConnectorHealth.ps1','Invoke-AuthWireConnectorProbeJob.ps1','Invoke-AuthWireCandidateJob.ps1','Test-AuthWireDeploymentCandidate.ps1','DeploymentScope.ps1','Invoke-AuthWireScopeJob.ps1','Read-AuthWireDeploymentScope.ps1','ConnectorServiceUpgrade.ps1','Update-AuthWireConnectorService.ps1','CombinedCandidateContent.ps1','Invoke-AuthWireCombinedJob.ps1','CombinedDeploymentScope.ps1','Invoke-AuthWireCombinedScopeJob.ps1','Read-AuthWireCombinedDeploymentScope.ps1')){
  $path=Join-Path $buildSource $file;Copy-Item -LiteralPath (Join-Path $source $file) -Destination $path
  if($file.EndsWith('.ps1')){$signed=Set-AuthenticodeSignature -FilePath $path -Certificate $publisher -HashAlgorithm SHA256;if($signed.Status.ToString() -ne 'Valid'){throw 'Fixture source signing failed'}}
 }
 $configPath=Join-Path $Directory 'service-config.json';$config|ConvertTo-Json -Depth 6|Set-Content -LiteralPath $configPath -Encoding UTF8
 $builder=Join-Path $buildSource 'New-AuthWireConnectorServicePackage.ps1'
 $inputWorker=Join-Path $buildSource 'ConnectorServiceRuntime.ps1';$inputBytes=[IO.File]::ReadAllBytes($inputWorker)
 try{
  [IO.File]::WriteAllText($inputWorker,("# modified executable source`r`n"+[IO.File]::ReadAllText($inputWorker)))
  Reject {& $builder -ConfigPath $configPath -PublisherThumbprint $publisher.Thumbprint} 'Public builder refuses an unreviewed input before signing or creating a package'
  Check (-not (Test-Path -LiteralPath $root)) 'Rejected source produces no package'
 }finally{[IO.File]::WriteAllBytes($inputWorker,$inputBytes)}
 $package=& $builder -ConfigPath $configPath -PublisherThumbprint $publisher.Thumbprint|ConvertFrom-Json
 Initialize-AuthWireChannelTypes
 Check (-not [AuthWire.Connector.ChannelTypesV1]::JobOffer('{"format":1,"format":1}')) 'Job reply parser refuses duplicate JSON fields'
 Check (-not [AuthWire.Connector.ChannelTypesV1]::JobOffer('{"command":"powershell.exe","payload":{"x":1}}')) 'Job reply parser refuses arbitrary commands and nested payloads'
 Check (-not (Test-AuthWireJobGuid '00000000-0000-0000-0000-000000000000')) 'Job identity refuses the empty GUID'
 Check ($package.PackagePrepared -and -not $package.ServiceCreated -and -not $package.ServiceStarted) 'Build creates signed package, not an AD account or service'
 $inspect=Invoke-AuthWireServiceControlCore -Mode Inspect -RootPath $root -ExpectedPublisher $publisher.Thumbprint
 Check (-not $inspect.ServiceInstalled -and -not $inspect.ServiceCreated) 'Inspect creates no service'
 $adminTool=Join-Path $root 'admin\Install-AuthWireConnectorService.ps1'
 $adminAcl=Get-Acl -LiteralPath $adminTool;$adminRules=@($adminAcl.GetAccessRules($true,$true,[Security.Principal.SecurityIdentifier]))
 Check ($adminAcl.AreAccessRulesProtected -and $adminRules.Count -eq 2 -and @($adminRules|Where-Object{$_.IdentityReference.Value -notin @('S-1-5-18','S-1-5-32-544')}).Count -eq 0) 'Administrative control code stays inaccessible to the service account'
 $inspect=Invoke-FreshPublicControl Inspect
 Check ($inspect.Mode -eq 'Inspect' -and -not $inspect.ServiceInstalled -and -not $inspect.ServiceCreated) 'Default signed public installer inspection performs no service or AD write'
 $rejected=$false
 try{$null=& $adminTool -Mode Install -ConnectorId ([guid]$base.connector_id) -PublisherThumbprint $publisher.Thumbprint}catch{$rejected=$_.Exception.Message -like '*CONNECTOR_EXISTING_GMSA_REQUIRED*'}
 Check $rejected 'Public installation refuses the fixture local account before any AD or service mutation'
 Check (-not (Get-Service -Name $name -ErrorAction SilentlyContinue)) 'Rejected public installation creates no service'
 Reject {New-AuthWireServicePackageCore -Config $config -Publisher $publisher -SourceDirectory $source} 'Existing package is not overwritten or silently upgraded'
 $exe=Join-Path $root 'AuthWireConnector.exe';$binary='"'+$exe+'"';$marker=Get-AuthWireServiceMarker $config
 Initialize-AuthWirePermanentServiceControl
 # Real production SCM creation/configuration with a built-in identity, unstarted.
 [AuthWire.Connector.PermanentServiceV1]::Create($name,$binary,'NT AUTHORITY\LocalService',$marker,$sid)
 $created=Get-CimInstance Win32_Service -Filter ("Name='"+$name+"'")
 $reg=Get-ItemProperty -LiteralPath ('HKLM:\SYSTEM\CurrentControlSet\Services\'+$name)
 Check ($created.StartMode -eq 'Auto' -and $reg.DelayedAutoStart -eq 1 -and $reg.FailureActions.Length -gt 20) 'Actual managed-account creation path configures automatic delayed start and bounded SCM recovery'
 Reject {Invoke-AuthWireServiceControlCore -Mode Start -RootPath $root -ExpectedPublisher $publisher.Thumbprint} 'Foreign service identity is refused before start'
 [AuthWire.Connector.PermanentServiceV1]::Remove($name)
 Wait-Until {-not (Get-Service -Name $name -ErrorAction SilentlyContinue)} 10 'Unstarted service not removed'
 # Hosted AD is unavailable: use an explicitly isolated local account for real SCM health.
 $null=New-Service -Name $name -BinaryPathName $binary -Credential $credential -StartupType Automatic -Description $marker
 Set-ItemProperty -LiteralPath ('HKLM:\SYSTEM\CurrentControlSet\Services\'+$name) -Name DelayedAutoStart -Value 1
 & sc.exe failure $name reset= 86400 actions= restart/60000/restart/60000/none/0|Out-Null
 if($LASTEXITCODE -ne 0){throw 'Fixture recovery configuration failed'}
 $statusPath=Join-Path $root 'state\status.json'
 Write-AuthWireChannelReceipt -Path (Join-Path $Directory 'candidate.json') -Value $prepared.PairingCandidate
 Wait-Until {(Test-Path -LiteralPath (Join-Path $Directory 'paired')) -or (Test-Path -LiteralPath (Join-Path $Directory 'abort'))} 60 'Server pairing did not finish'
 if(Test-Path -LiteralPath (Join-Path $Directory 'abort')){throw 'Fixture parent aborted'}
 $debug=Get-CimInstance Win32_Service -Filter ("Name='"+$name+"'")
 Write-Host ('SERVICE_FIXTURE_PUBLIC_CONFIG '+(@{path=$debug.PathName;expected_path=$binary;account=$debug.StartName;expected_account=$config.AccountName;description=$debug.Description;expected_description=$marker}|ConvertTo-Json -Compress))
 $r=Invoke-FreshPublicControl Start
 Wait-Until {$s=Read-Status;return ($s -and $s.Healthy)} 35 'Real signed service did not prove HTTPS health'
 Wait-Until {$s=Read-Status;return ($s -and $s.ProbeChannelVerified -and $s.ProbeJobsCompleted -ge 1)} 35 'Real signed service did not complete the bounded probe job'
 Wait-Until {$s=Read-Status;return ((Test-Path -LiteralPath (Join-Path $Directory 'scope-rejected')) -and $s -and $s.ScopeJobsCompleted -ge 1 -and $s.LastScopeReason -ceq 'CONTENT_REJECTED')} 170 'Actual signed child scope rejection and local status not both committed'
 Wait-Until {$s=Read-Status;return ((Test-Path -LiteralPath (Join-Path $Directory 'combined-rejected')) -and $s -and $s.CombinedJobsCompleted -ge 1)} 170 'Actual combined rejection and local status missing'
 Wait-Until {$s=Read-Status;return ((Test-Path -LiteralPath (Join-Path $Directory 'combined-scope-rejected')) -and $s -and $s.CombinedScopeJobsCompleted -ge 1 -and $s.LastCombinedScopeReason -ceq 'CONTENT_REJECTED')} 170 'Combined signed child negative scope result missing'
 Check ((Read-Status).CombinedJobsCompleted -ge 1) 'Actual AllSigned child completed typed combined job over HTTPS'
 Check ((Read-Status).ScopeJobsCompleted -ge 1 -and (Read-Status).LastScopeReason -ceq 'CONTENT_REJECTED') 'Actual low-privilege AllSigned child returns a scoped negative result'
 Check (Test-AuthWireJobGuid (Read-Status).LastProbeJobId) 'Real SCM worker completed a scoped read-only probe job over verified HTTPS'
 $s=Read-Status;$first=$s.WorkerPid
 Check ($r.ServiceInstalled -and $s.RuntimeSid -ceq $sid -and -not $s.CanApply -and -not $s.DirectorySyncReady -and -not $s.KerberosReady) 'Actual low-privilege SCM worker proves health without AD/GPO authority'
 $process=Get-CimInstance Win32_Process -Filter ("ProcessId="+$first)
 Check ((Invoke-CimMethod -InputObject $process -MethodName GetOwnerSid).Sid -ceq $sid) 'Native worker process token belongs to the exact temporary account'
 $null=Invoke-FreshPublicControl Start
 Check ((Read-Status).WorkerPid -eq $first) 'Repeated start does not create a duplicate worker'
 Set-Content -LiteralPath (Join-Path $Directory 'case.txt') -Value offline -Encoding ASCII
 Wait-Until {$s=Read-Status;return ($s -and -not $s.Healthy -and $s.ConsecutiveFailures -ge 1)} 40 'Outage did not become unhealthy'
 Check ((Read-Status).NextAttemptSeconds -eq 30) 'First failed health request gets bounded retry, not a tight loop'
 Set-Content -LiteralPath (Join-Path $Directory 'case.txt') -Value normal -Encoding ASCII
 Wait-Until {$s=Read-Status;return ($s -and $s.Healthy -and $s.SuccessCount -ge 2)} 45 'Service did not recover automatically after HTTPS outage'
 Check ((Read-Status).WorkerPid -eq $first) 'Transient network outage recovers in the same worker'
 $null=Invoke-FreshPublicControl Stop
 Wait-Until {-not (Get-Process -Id $first -ErrorAction SilentlyContinue)} 10 'Stop left an orphan worker'
 Check ((Get-Service $name).Status -eq 'Stopped') 'Bounded service stop also ends its child'
 $worker=Join-Path $root 'ConnectorServiceRuntime.ps1';$bytes=[IO.File]::ReadAllBytes($worker)
 try{[IO.File]::AppendAllText($worker,"`r`n# tampered");Reject {Invoke-AuthWireServiceControlCore -Mode Start -RootPath $root -ExpectedPublisher $publisher.Thumbprint} 'Tampered signed worker is rejected before SCM start'}finally{[IO.File]::WriteAllBytes($worker,$bytes)}
 $cfg=Join-Path $root 'service.json';$before=(Get-Acl -LiteralPath $cfg).Sddl
 try{
  $acl=Get-Acl -LiteralPath $cfg;$acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new([Security.Principal.SecurityIdentifier]::new($sid),[Security.AccessControl.FileSystemRights]::Write,[Security.AccessControl.AccessControlType]::Allow));Set-Acl -LiteralPath $cfg -AclObject $acl
  Reject {Invoke-AuthWireServiceControlCore -Mode Start -RootPath $root -ExpectedPublisher $publisher.Thumbprint} 'Service-writable trusted config is rejected'
 }finally{$acl.SetSecurityDescriptorSddlForm($before);Set-Acl -LiteralPath $cfg -AclObject $acl}
 $oldTicks=(Read-Status).CheckedUtc
 $null=Invoke-FreshPublicControl Start
 Wait-Until {$s=Read-Status;return ($s -and $s.Healthy -and $s.WorkerPid -ne $first -and $s.CheckedUtc -ne $oldTicks)} 35 'Explicit restart did not produce a fresh worker'
 $old=(Read-Status).WorkerPid
 $hostProcess=(Get-CimInstance Win32_Service -Filter ("Name='"+$name+"'")).ProcessId
 Stop-Process -Id $hostProcess -Force
 Wait-Until {-not (Get-Process -Id $old -ErrorAction SilentlyContinue)} 16 'Crash left an orphan worker'
 Check $true 'Worker detects parent crash and exits without waiting for the full retry interval'
 Wait-Until {$s=Read-Status;return ($s -and $s.Healthy -and $s.WorkerPid -ne $old)} 100 'SCM did not restart crashed host into a healthy fresh worker'
 Check $true 'Real SCM recovery restarts the signed host and health worker'
 $null=Invoke-FreshPublicControl Remove
 Wait-Until {-not (Get-Service -Name $name -ErrorAction SilentlyContinue)} 10 'Removed service is still present'
 Check ((Test-Path -LiteralPath $root) -and [Security.Cryptography.CngKey]::Exists($key,[Security.Cryptography.CngProvider]::MicrosoftSoftwareKeyStorageProvider,[Security.Cryptography.CngKeyOpenOptions]::MachineKey)) 'Removal leaves owned package and channel key intact'
 $k=[Security.Cryptography.CngKey]::Open($key,[Security.Cryptography.CngProvider]::MicrosoftSoftwareKeyStorageProvider,[Security.Cryptography.CngKeyOpenOptions]::MachineKey)
 try{$path=Join-Path (Join-Path $env:ProgramData 'Microsoft\Crypto\Keys') $k.UniqueName;Check ((Compare-AuthWireSigningKeyAcl $receipt.ExpectedKeySddl (Get-Acl -LiteralPath $path).Sddl).AclEquivalent -and [int]$k.ExportPolicy -eq 0) 'All service lifecycle tests preserve the non-exportable key and its ACL'}finally{$k.Dispose()}
 Check (($freshControlModes -join ',') -ceq 'Inspect,Start,Start,Stop,Start,Remove') 'Signed public lifecycle works across six independent clean WinPS processes'

 # Build the genuine immutable customer v1 from its own independent checkout.
 # This exercises a legacy six-script manifest, not a synthetic missing file.
 $kept=$root+'.fixture-current';[IO.Directory]::Move($root,$kept);$upgradePaths+=$kept
 $legacySource=Join-Path $Directory 'legacy-reviewed-source';$null=New-Item -ItemType Directory -Path $legacySource
 $baselineSource=Join-Path $PSScriptRoot '..\reviewed-connector-baseline\windows\connector'
 foreach($file in Get-ChildItem -LiteralPath $baselineSource -File){
  $path=Join-Path $legacySource $file.Name;Copy-Item -LiteralPath $file.FullName -Destination $path
  if($file.Extension -ceq '.ps1'){$sig=Set-AuthenticodeSignature -FilePath $path -Certificate $publisher -HashAlgorithm SHA256;if($sig.Status.ToString() -cne 'Valid'){throw 'Legacy signing failed'}}
 }
 $legacyConfig=$config|ConvertTo-Json -Depth 6|ConvertFrom-Json;$legacyConfig.ReleaseId=[guid]::NewGuid().ToString('D')
 $legacyConfigPath=Join-Path $Directory 'legacy-config.json';$legacyConfig|ConvertTo-Json -Depth 6|Set-Content -LiteralPath $legacyConfigPath -Encoding UTF8
 $null=& (Join-Path $legacySource 'New-AuthWireConnectorServicePackage.ps1') -ConfigPath $legacyConfigPath -PublisherThumbprint $publisher.Thumbprint
 $null=Get-AuthWireServicePackage $root $publisher.Thumbprint -AllowLegacy
 Reject {Get-AuthWireServicePackage $root $publisher.Thumbprint} 'Legacy package cannot silently claim current probe payload'
 $null=New-Service -Name $name -BinaryPathName $binary -Credential $credential -StartupType Automatic -Description (Get-AuthWireServiceMarker $legacyConfig)
 Set-ItemProperty -LiteralPath ('HKLM:\SYSTEM\CurrentControlSet\Services\'+$name) -Name DelayedAutoStart -Value 1
 & sc.exe failure $name reset= 86400 actions= restart/60000/restart/60000/none/0|Out-Null
 Start-AuthWireUpgradeService $name
 Wait-AuthWireUpgradeHealth $legacyConfig ([DateTimeOffset]::UtcNow.AddSeconds(-5))
 $beforeUpgradeWorker=(Read-Status).WorkerPid
 $serviceSecurityBefore=(& sc.exe sdshow $name|Out-String).Trim()
 $newRelease=[guid]::NewGuid();$updater=Join-Path $buildSource 'Update-AuthWireConnectorService.ps1'
 $upgradeArgs=@{ConnectorId=[guid]$base.connector_id;ExpectedCurrentRelease=[guid]$legacyConfig.ReleaseId;NewReleaseId=$newRelease;PublisherThumbprint=$publisher.Thumbprint}
 $stage=$root+'.candidate-'+$newRelease.ToString('N');$archive=$root+'.previous-'+([guid]$legacyConfig.ReleaseId).ToString('N')
 $journalRoot=Join-Path $env:ProgramData ('AuthWire-ConnectorUpgrade-'+$id+'-'+$newRelease.ToString('N'));$upgradePaths+=@($stage,$archive,$journalRoot)
 $powershell=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
 function Fresh-Upgrade([string]$Mode){
  $out=@(& $powershell -NoLogo -NoProfile -NonInteractive -ExecutionPolicy AllSigned -File $updater -Mode $Mode @upgradeArgs 2>&1)
  if($LASTEXITCODE -ne 0){throw ('Fresh upgrade '+$Mode+' failed: '+($out -join "`n"))}
  return (($out -join "`n")|ConvertFrom-Json)
 }
 $u=Fresh-Upgrade Inspect
 Check ($u.Phase -ceq 'not_prepared' -and -not (Test-Path -LiteralPath $stage) -and -not (Test-Path -LiteralPath $journalRoot)) 'Fresh signed Inspect of actual legacy package creates no stage or journal'
 $u=Fresh-Upgrade Prepare
 Check ($u.Phase -ceq 'prepared' -and (Read-Status).WorkerPid -eq $beforeUpgradeWorker) 'Staged signed build leaves the existing running legacy worker untouched'
 $candidate=Get-AuthWireServicePackage $stage $publisher.Thumbprint -Staged
 Check ($candidate.RootPath -ceq $root -and $candidate.KeyName -ceq $config.KeyName -and ($candidate.Binding|ConvertTo-Json -Compress) -ceq ($config.Binding|ConvertTo-Json -Compress)) 'Candidate keeps final path, original key and exact pairing'
 $u=Fresh-Upgrade Prepare
 Check ($u.Phase -ceq 'prepared' -and (Read-Status).WorkerPid -eq $beforeUpgradeWorker) 'Repeated prepare verifies the same candidate without restart or re-sign'
 $journalPath=Join-Path $journalRoot 'upgrade.json';$journalBytes=[IO.File]::ReadAllBytes($journalPath)
 try{
  $bad=Get-Content -LiteralPath $journalPath -Raw|ConvertFrom-Json;$bad.NewConfig.KeyName=$bad.NewConfig.KeyName.Substring(0,$bad.NewConfig.KeyName.Length-32)+[guid]::NewGuid().ToString('N')
  [IO.File]::WriteAllText($journalPath,($bad|ConvertTo-Json -Depth 6))
  Reject {Invoke-AuthWireServiceUpgradeCore -Mode Apply @upgradeArgs -SourceDirectory $buildSource} 'Journal cannot change the existing channel key or pairing'
 }finally{[IO.File]::WriteAllBytes($journalPath,$journalBytes)}
 try{
  $bad=Get-Content -LiteralPath $journalPath -Raw|ConvertFrom-Json;$bad.Phase='archiving';[IO.File]::WriteAllText($journalPath,($bad|ConvertTo-Json -Depth 6))
  Reject {Invoke-AuthWireServiceUpgradeCore -Mode Apply @upgradeArgs -SourceDirectory $buildSource} 'Interrupted transition is not silently resumed or overwritten'
  Check ((Read-Status).WorkerPid -eq $beforeUpgradeWorker) 'Rejected journal leaves the running worker unchanged'
 }finally{[IO.File]::WriteAllBytes($journalPath,$journalBytes)}
 $candidateWorker=Join-Path $stage 'ConnectorServiceRuntime.ps1';$candidateBytes=[IO.File]::ReadAllBytes($candidateWorker)
 try{
  [IO.File]::AppendAllText($candidateWorker,"`r`n# tampered")
  Reject {Invoke-AuthWireServiceUpgradeCore -Mode Apply @upgradeArgs -SourceDirectory $buildSource} 'Candidate tampering is refused before stopping the original service'
  Check ((Read-Status).WorkerPid -eq $beforeUpgradeWorker -and (Get-Service $name).Status -eq 'Running') 'Rejected candidate leaves running legacy service intact'
 }finally{[IO.File]::WriteAllBytes($candidateWorker,$candidateBytes)}
 # Fault injection changes only this disposable caller's command resolution.
 # The public customer updater has no failure-injection flag or callback.
 $realStart=(Get-Command Start-AuthWireUpgradeService).ScriptBlock;$script:failUpgradeStart=$true
 try{
  Set-Item Function:\Start-AuthWireUpgradeService -Value {param([string]$Name)if($script:failUpgradeStart){$script:failUpgradeStart=$false;throw 'fixture candidate start failure'};& $realStart $Name}
  $caught=$false
  try{Invoke-AuthWireServiceUpgradeCore -Mode Apply @upgradeArgs -SourceDirectory $buildSource|Out-Null}catch{$caught=$_.Exception.Message -like 'CONNECTOR_UPGRADE_FAILED_OLD_RELEASE_RESTORED:*'}
  Check $caught 'Failed candidate start automatically restores the exact archived legacy package'
 }finally{Set-Item Function:\Start-AuthWireUpgradeService -Value $realStart}
 Check ((Read-Status).ReleaseId -ceq $legacyConfig.ReleaseId -and (Read-Status).Healthy -and (Get-Service $name).Status -eq 'Running') 'Automatic rollback produces fresh actual legacy HTTPS health'
 # Health/probe alone must not accept a new release with a broken candidate channel.
 [IO.File]::WriteAllText((Join-Path $Directory 'case.txt'),'candidate-offline')
 try{
  $caught=$false
  try{Invoke-AuthWireServiceUpgradeCore -Mode Apply @upgradeArgs -SourceDirectory $buildSource|Out-Null}catch{$caught=$_.Exception.Message -like 'CONNECTOR_UPGRADE_FAILED_OLD_RELEASE_RESTORED:*'}
  Check $caught 'A failed candidate channel rolls back even when health and old probe still work'
  Check ((Read-Status).ReleaseId -ceq $legacyConfig.ReleaseId -and (Read-Status).Healthy) 'Candidate-channel rejection restores fresh legacy service health'
 }finally{[IO.File]::WriteAllText((Join-Path $Directory 'case.txt'),'normal')}
 [IO.File]::WriteAllText((Join-Path $Directory 'case.txt'),'scope-offline')
 try{
  $caught=$false
  try{Invoke-AuthWireServiceUpgradeCore -Mode Apply @upgradeArgs -SourceDirectory $buildSource|Out-Null}catch{$caught=$_.Exception.Message -like 'CONNECTOR_UPGRADE_FAILED_OLD_RELEASE_RESTORED:*'}
  Check $caught 'Scope channel must work even when all older channels work'
  Check ((Read-Status).ReleaseId -ceq $legacyConfig.ReleaseId -and (Read-Status).Healthy) 'Scope channel rejection restores legacy health'
 }finally{[IO.File]::WriteAllText((Join-Path $Directory 'case.txt'),'normal')}
 [IO.File]::WriteAllText((Join-Path $Directory 'case.txt'),'combined-offline')
 try{
  $caught=$false
  try{Invoke-AuthWireServiceUpgradeCore -Mode Apply @upgradeArgs -SourceDirectory $buildSource|Out-Null}catch{$caught=$_.Exception.Message -like 'CONNECTOR_UPGRADE_FAILED_OLD_RELEASE_RESTORED:*'}
  Check $caught 'Failed combined channel rolls back even when other channels work'
 }finally{[IO.File]::WriteAllText((Join-Path $Directory 'case.txt'),'normal')}
 [IO.File]::WriteAllText((Join-Path $Directory 'case.txt'),'combined-scope-offline')
 try{
  $caught=$false
  try{Invoke-AuthWireServiceUpgradeCore -Mode Apply @upgradeArgs -SourceDirectory $buildSource|Out-Null}catch{$caught=$_.Exception.Message -like 'CONNECTOR_UPGRADE_FAILED_OLD_RELEASE_RESTORED:*'}
  Check $caught 'Failed combined scope channel rolls back when all older channels work'
 }finally{[IO.File]::WriteAllText((Join-Path $Directory 'case.txt'),'normal')}
 [IO.File]::WriteAllText((Join-Path $Directory 'case.txt'),'staging-preview-offline')
 try{
  $caught=$false
  try{Invoke-AuthWireServiceUpgradeCore -Mode Apply @upgradeArgs -SourceDirectory $buildSource|Out-Null}catch{$caught=$_.Exception.Message -like 'CONNECTOR_UPGRADE_FAILED_OLD_RELEASE_RESTORED:*'}
  Check $caught 'Failed staging preview channel rolls back when all older channels work'
 }finally{[IO.File]::WriteAllText((Join-Path $Directory 'case.txt'),'normal')}
 $u=Fresh-Upgrade Apply
 Check ($u.Phase -ceq 'applied' -and (Read-Status).ReleaseId -ceq $newRelease.ToString('D') -and (Read-Status).ProbeChannelVerified -and (Read-Status).CandidateChannelVerified -and (Read-Status).ScopeChannelVerified -and (Read-Status).CombinedChannelVerified -and (Read-Status).CombinedScopeChannelVerified -and (Read-Status).StagingPreviewChannelVerified) 'Fresh signed Apply requires health, probe and candidate capability'
 Check ((Test-Path -LiteralPath $archive) -and (Get-AuthWireUpgradeTreeHash $archive) -ceq (Get-Content -LiteralPath (Join-Path $journalRoot 'upgrade.json') -Raw|ConvertFrom-Json).OldTree) 'Original static package/admin bytes and ACLs survive in the scoped rollback archive'
 $archiveWorker=Join-Path $archive 'ConnectorServiceRuntime.ps1';$archiveBytes=[IO.File]::ReadAllBytes($archiveWorker);$activePid=(Read-Status).WorkerPid
 try{
  [IO.File]::AppendAllText($archiveWorker,"`r`n# tampered rollback source")
  Reject {Invoke-AuthWireServiceUpgradeCore -Mode Rollback @upgradeArgs -SourceDirectory $buildSource} 'Corrupted rollback archive is refused before stopping the healthy candidate'
  Check ((Read-Status).WorkerPid -eq $activePid) 'Rejected rollback leaves the healthy candidate running'
 }finally{[IO.File]::WriteAllBytes($archiveWorker,$archiveBytes)}
 $u=Fresh-Upgrade Rollback
 Check ($u.Phase -ceq 'rolled_back' -and (Read-Status).ReleaseId -ceq $legacyConfig.ReleaseId -and (Read-Status).Healthy) 'Explicit signed rollback restores legacy health with the same key and service'
 [IO.File]::WriteAllText((Join-Path $Directory 'case.txt'),'staging-preview-offline')
 try{
  $caught=$false
  try{Invoke-AuthWireServiceUpgradeCore -Mode Apply @upgradeArgs -SourceDirectory $buildSource|Out-Null}catch{$caught=$_.Exception.Message -like 'CONNECTOR_UPGRADE_FAILED_OLD_RELEASE_RESTORED:*'}
  Check $caught 'Failed staging preview channel rolls back when all older channels work'
 }finally{[IO.File]::WriteAllText((Join-Path $Directory 'case.txt'),'normal')}
 $u=Fresh-Upgrade Apply
 Check ($u.Phase -ceq 'applied' -and (Read-Status).ProbeChannelVerified) 'Reviewed candidate can be applied again after a verified rollback'
 Check ((& sc.exe sdshow $name|Out-String).Trim() -ceq $serviceSecurityBefore) 'Upgrade and rollback preserve native SCM security descriptor'
 $null=Invoke-AuthWireServiceControlCore -Mode Remove -RootPath $root -ExpectedPublisher $publisher.Thumbprint
 Wait-Until {-not (Get-Service -Name $name -ErrorAction SilentlyContinue)} 10 'Upgraded fixture service not removed'

 # Parse the exact customer wrapper without invoking its DC01-only entry point.
 # Exercise its immutable reviewed archive/signing functions with our own cert.
 # Match the customer entry point's declared framework dependency.
 Add-Type -AssemblyName System.IO.Compression
 $deliveryScript=Join-Path $PSScriptRoot '..\docs\checkpoints\2026-10-26-dc01-service-upgrade.ps1'
 $tokens=$null;$errors=$null;$deliveryAst=[Management.Automation.Language.Parser]::ParseFile($deliveryScript,[ref]$tokens,[ref]$errors)
 Check ($errors.Count -eq 0) 'Exact customer delivery entry point parses in native WinPS5.1'
 foreach($f in $deliveryAst.FindAll({param($node)$node -is [Management.Automation.Language.FunctionDefinitionAst]},$false)){. ([scriptblock]::Create($f.Extent.Text))}
 $assignments=@{};foreach($a in $deliveryAst.FindAll({param($node)$node -is [Management.Automation.Language.AssignmentStatementAst] -and $node.Left -is [Management.Automation.Language.VariableExpressionAst]},$false)){$assignments[$a.Left.VariablePath.UserPath]=$a.Right}
 function Read-FixtureLiteral($node){
  $values=@($node.FindAll({param($value)$value -is [Management.Automation.Language.StringConstantExpressionAst]},$true))
  if($values.Count -ne 1){throw 'Expected one literal source value'}
  return $values[0].Value
 }
 $table=$assignments['reviewedSources'].Find({param($node)$node -is [Management.Automation.Language.HashtableAst]},$true)
 $reviewedSources=@{};foreach($pair in $table.KeyValuePairs){
  if($pair.Item1 -isnot [Management.Automation.Language.StringConstantExpressionAst]){throw 'Expected literal source name'}
  $reviewedSources[$pair.Item1.Value]=Read-FixtureLiteral $pair.Item2
 }
 $zipBytes=[Convert]::FromBase64String((Read-FixtureLiteral $assignments['embeddedSources']));$zipHash=Read-FixtureLiteral $assignments['archiveSha256']
 $unpacked=Read-AuthWireReviewedSourceBytes $zipBytes $zipHash
 Check ($unpacked.Count -eq 14) 'Pinned customer delivery admits exactly fourteen reviewed source files'
 Reject {Read-AuthWireReviewedSourceBytes $zipBytes ('0'*64)} 'Customer delivery refuses a mismatched archive hash before signing'
 $deliveryDirectory=Join-Path $Directory 'signed-customer-source-fixture';$upgradePaths+=$deliveryDirectory
 New-AuthWireSignedDelivery $unpacked $deliveryDirectory $publisher
 Assert-AuthWireSignedDelivery $deliveryDirectory $publisher.Thumbprint
 Check $true 'All fourteen exact customer sources sign and verify with protected administrator ACLs'
 Reject {New-AuthWireSignedDelivery $unpacked $deliveryDirectory $publisher} 'Customer source delivery refuses overwrite or adoption of an existing directory'
 $testSource=Join-Path $deliveryDirectory 'ConnectorServiceUpgrade.ps1';[IO.File]::AppendAllText($testSource,"`r`n# changed")
 Reject {Assert-AuthWireSignedDelivery $deliveryDirectory $publisher.Thumbprint} 'Existing signed customer source drift is rejected before package preparation'

 # The new fixed nineteen-file delivery is tested without running its DC01-only main.
 $deliveryScript=Join-Path $PSScriptRoot '..\docs\checkpoints\2026-10-28-dc01-sysvol-unc-fix.ps1'
 $tokens=$null;$errors=$null;$deliveryAst=[Management.Automation.Language.Parser]::ParseFile($deliveryScript,[ref]$tokens,[ref]$errors)
 Check ($errors.Count -eq 0) 'Candidate worker delivery parses in native Windows PowerShell 5.1'
 foreach($f in $deliveryAst.FindAll({param($node)$node -is [Management.Automation.Language.FunctionDefinitionAst]},$false)){. ([scriptblock]::Create($f.Extent.Text))}
 $assignments=@{};foreach($a in $deliveryAst.FindAll({param($node)$node -is [Management.Automation.Language.AssignmentStatementAst] -and $node.Left -is [Management.Automation.Language.VariableExpressionAst]},$false)){$assignments[$a.Left.VariablePath.UserPath]=$a.Right}
 $table=$assignments['reviewedSources'].Find({param($node)$node -is [Management.Automation.Language.HashtableAst]},$true)
 $reviewedSources=@{};foreach($pair in $table.KeyValuePairs){$reviewedSources[$pair.Item1.Value]=Read-FixtureLiteral $pair.Item2}
 $bytes=[Convert]::FromBase64String((Read-FixtureLiteral $assignments['embeddedSources']));$pin=Read-FixtureLiteral $assignments['archiveSha256']
 $unpacked=Read-AuthWireReviewedSourceBytes $bytes $pin
 Check ($unpacked.Count -eq 24) 'New delivery contains nineteen fixed reviewed sources'
 # This is the immutable, hash-pinned historical 24-file UNC-fix delivery.
 # Changed generation files are verified against its own reviewed archive pins.
 foreach($f in $unpacked.Keys){if($f -cnotin @('ConnectorChannelTypes.ps1','ConnectorServiceRuntime.ps1','ConnectorServicePackage.ps1','ConnectorServiceUpgrade.ps1','Invoke-AuthWireScopeJob.ps1','New-AuthWireConnectorServicePackage.ps1','Update-AuthWireConnectorService.ps1')){Check ((Get-AuthWireDeliveryBodyHash ([IO.File]::ReadAllText((Join-Path $source $f)))) -ceq $reviewedSources[$f]) 'Unchanged historical source body remains identical'}}
 $nextDirectory=Join-Path $Directory 'candidate-worker-delivery';$upgradePaths+=$nextDirectory
 New-AuthWireSignedDelivery $unpacked $nextDirectory $publisher
 Assert-AuthWireSignedDelivery $nextDirectory $publisher.Thumbprint
 Check $true 'All new source bodies sign, verify and retain administrator-only delivery ACLs'
 Reject {Read-AuthWireReviewedSourceBytes $bytes ('0'*64)} 'New archive refuses an incorrect hash before source signing'
 $output=@(& $powershell -NoProfile -NonInteractive -File $deliveryScript -Mode Inspect)
 $outcome=($output -join "`n")|ConvertFrom-Json
 Check ($LASTEXITCODE -eq 0 -and $outcome.Error -ceq 'EXPECTED_ELEVATED_DC01_X64_REQUIRED' -and -not $outcome.ChangesMayBePartial) 'New delivery refuses other hosts before signer, sources or service changes'


 @{release_id=$config.ReleaseId;checks=$checks;real_signed_scm=$true;actual_https=$true;low_privilege_runtime=$true;automatic_outage_recovery=$true;crash_recovery=$true;orphan_cleanup=$true;fresh_public_control=$true;fresh_control_modes=$freshControlModes;legacy_staged_upgrade=$true;automatic_upgrade_rollback=$true;explicit_upgrade_rollback=$true;candidate_channel_required=$true;candidate_channel_failed_upgrade_rollback=$true;scope_channel_required=$true;scope_channel_failed_upgrade_rollback=$true;staging_preview_channel_required=$true;staging_preview_channel_failed_upgrade_rollback=$true;combined_scope_channel_required=$true;combined_scope_channel_failed_upgrade_rollback=$true;combined_channel_required=$true;combined_channel_failed_upgrade_rollback=$true;customer_gmsa_tested=$false;ad_changed=$false;gpo_changed=$false}|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $Directory 'service-result.json') -Encoding UTF8
}finally{
 if($name){$service=Get-Service -Name $name -ErrorAction SilentlyContinue;if($service){if($service.Status -ne 'Stopped'){Stop-Service -Name $name -Force;$service.WaitForStatus([ServiceProcess.ServiceControllerStatus]::Stopped,[TimeSpan]::FromSeconds(35))};$service.Dispose();Initialize-AuthWirePermanentServiceControl;[AuthWire.Connector.PermanentServiceV1]::Remove($name)}}
 if($rightsAdded){[AuthWire.Connector.FixtureServiceRightCleanupV1]::RemoveFixtureRight($sid,'SeServiceLogonRight')}
 if($user -and (Get-LocalUser -Name $user -ErrorAction SilentlyContinue)){Remove-LocalUser -Name $user}
 if(-not $key -and $keyRoot -and (Test-Path -LiteralPath (Join-Path $keyRoot 'channel-key.json'))){$key=(Get-Content -LiteralPath (Join-Path $keyRoot 'channel-key.json') -Raw|ConvertFrom-Json).KeyName;if($key -cnotmatch ('\AAuthWire-Channel-'+$id+'-[0-9a-f]{32}\z')){throw 'Fixture key cleanup scope mismatch'}}
 if($key -and [Security.Cryptography.CngKey]::Exists($key,[Security.Cryptography.CngProvider]::MicrosoftSoftwareKeyStorageProvider,[Security.Cryptography.CngKeyOpenOptions]::MachineKey)){$k=[Security.Cryptography.CngKey]::Open($key,[Security.Cryptography.CngProvider]::MicrosoftSoftwareKeyStorageProvider,[Security.Cryptography.CngKeyOpenOptions]::MachineKey);$k.Delete();$k.Dispose()}
 foreach($path in (@($root,$keyRoot)+$upgradePaths)){if($path -and (Test-Path -LiteralPath $path)){Assert-AuthWireChannelPath $path;Remove-Item -LiteralPath $path -Recurse -Force}}
 if($hostBytes){[IO.File]::WriteAllBytes($hosts,$hostBytes)}
 if($publishers){if($public){$publishers.Remove($public)};$publishers.Dispose()}
 if($roots){if($public){$roots.Remove($public)};if($web){$roots.Remove($web)};$roots.Dispose()}
 if($publisher){Remove-Item -LiteralPath ('Cert:\LocalMachine\My\'+$publisher.Thumbprint) -DeleteKey -Force;$publisher.Dispose()}
 if($public){$public.Dispose()};if($web){$web.Dispose()};if($null -ne $secret){$secret.Dispose()}
}
