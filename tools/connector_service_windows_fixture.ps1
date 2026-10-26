param([Parameter(Mandatory=$true)][string]$Directory)
$ErrorActionPreference='Stop';Set-StrictMode -Version 2
if($env:RUNNER_ENVIRONMENT -ne 'github-hosted'){throw 'Hosted Windows fixture only'}
$source=Join-Path $PSScriptRoot '..\windows\connector'
foreach($f in @('Compare-AuthWireSigningKeyAcl.ps1','ConnectorChannelTypes.ps1','ConnectorChannelKey.ps1','New-AuthWireConnectorHealthProof.ps1','ConnectorServicePackage.ps1','ConnectorServiceControl.ps1')){. (Join-Path $source $f)}
$checks=0
function Check([bool]$v,[string]$m){if(-not $v){throw $m};$script:checks++}
function Reject([scriptblock]$s,[string]$m){$caught=$false;try{$null=& $s}catch{$caught=$true};Check $caught $m}
function Wait-Until([scriptblock]$s,[int]$seconds,[string]$message){$end=[DateTime]::UtcNow.AddSeconds($seconds);do{if(& $s){return};Start-Sleep -Milliseconds 500}while([DateTime]::UtcNow -lt $end);throw $message}
function Read-Status {if(Test-Path -LiteralPath $script:statusPath){try{return (Get-Content -LiteralPath $script:statusPath -Raw|ConvertFrom-Json)}catch{}};return $null}
$user=$null;$sid=$null;$key=$null;$root=$null;$keyRoot=$null;$name=$null;$publisher=$null;$public=$null;$web=$null;$roots=$null;$publishers=$null;$hostBytes=$null;$rightsAdded=$false;$secret=$null
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
 $publisher=New-SelfSignedCertificate -Type CodeSigningCert -Subject ('CN=AuthWire permanent service fixture '+$id) -CertStoreLocation 'Cert:\CurrentUser\My' -KeyExportPolicy NonExportable -HashAlgorithm SHA256 -NotAfter (Get-Date).AddDays(1)
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
 $package=New-AuthWireServicePackageCore -Config $config -Publisher $publisher -SourceDirectory $source
 Check ($package.PackagePrepared -and -not $package.ServiceCreated -and -not $package.ServiceStarted) 'Build creates signed package, not an AD account or service'
 $inspect=Invoke-AuthWireServiceControlCore -Mode Inspect -RootPath $root -ExpectedPublisher $publisher.Thumbprint
 Check (-not $inspect.ServiceInstalled -and -not $inspect.ServiceCreated) 'Inspect creates no service'
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
 $r=Invoke-AuthWireServiceControlCore -Mode Start -RootPath $root -ExpectedPublisher $publisher.Thumbprint
 Wait-Until {$s=Read-Status;return ($s -and $s.Healthy)} 35 'Real signed service did not prove HTTPS health'
 $s=Read-Status;$first=$s.WorkerPid
 Check ($r.ServiceInstalled -and $s.RuntimeSid -ceq $sid -and -not $s.CanApply -and -not $s.DirectorySyncReady -and -not $s.KerberosReady) 'Actual low-privilege SCM worker proves health without AD/GPO authority'
 $process=Get-CimInstance Win32_Process -Filter ("ProcessId="+$first)
 Check ((Invoke-CimMethod -InputObject $process -MethodName GetOwnerSid).Sid -ceq $sid) 'Native worker process token belongs to the exact temporary account'
 $null=Invoke-AuthWireServiceControlCore -Mode Start -RootPath $root -ExpectedPublisher $publisher.Thumbprint
 Check ((Read-Status).WorkerPid -eq $first) 'Repeated start does not create a duplicate worker'
 Set-Content -LiteralPath (Join-Path $Directory 'case.txt') -Value offline -Encoding ASCII
 Wait-Until {$s=Read-Status;return ($s -and -not $s.Healthy -and $s.ConsecutiveFailures -ge 1)} 40 'Outage did not become unhealthy'
 Check ((Read-Status).NextAttemptSeconds -eq 30) 'First failed health request gets bounded retry, not a tight loop'
 Set-Content -LiteralPath (Join-Path $Directory 'case.txt') -Value normal -Encoding ASCII
 Wait-Until {$s=Read-Status;return ($s -and $s.Healthy -and $s.SuccessCount -ge 2)} 45 'Service did not recover automatically after HTTPS outage'
 Check ((Read-Status).WorkerPid -eq $first) 'Transient network outage recovers in the same worker'
 $null=Invoke-AuthWireServiceControlCore -Mode Stop -RootPath $root -ExpectedPublisher $publisher.Thumbprint
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
 $null=Invoke-AuthWireServiceControlCore -Mode Start -RootPath $root -ExpectedPublisher $publisher.Thumbprint
 Wait-Until {$s=Read-Status;return ($s -and $s.Healthy -and $s.WorkerPid -ne $first -and $s.CheckedUtc -ne $oldTicks)} 35 'Explicit restart did not produce a fresh worker'
 $old=(Read-Status).WorkerPid
 $hostProcess=(Get-CimInstance Win32_Service -Filter ("Name='"+$name+"'")).ProcessId
 Stop-Process -Id $hostProcess -Force
 Wait-Until {-not (Get-Process -Id $old -ErrorAction SilentlyContinue)} 16 'Crash left an orphan worker'
 Check $true 'Worker detects parent crash and exits without waiting for the full retry interval'
 Wait-Until {$s=Read-Status;return ($s -and $s.Healthy -and $s.WorkerPid -ne $old)} 100 'SCM did not restart crashed host into a healthy fresh worker'
 Check $true 'Real SCM recovery restarts the signed host and health worker'
 $null=Invoke-AuthWireServiceControlCore -Mode Remove -RootPath $root -ExpectedPublisher $publisher.Thumbprint
 Wait-Until {-not (Get-Service -Name $name -ErrorAction SilentlyContinue)} 10 'Removed service is still present'
 Check ((Test-Path -LiteralPath $root) -and [Security.Cryptography.CngKey]::Exists($key,[Security.Cryptography.CngProvider]::MicrosoftSoftwareKeyStorageProvider,[Security.Cryptography.CngKeyOpenOptions]::MachineKey)) 'Removal leaves owned package and channel key intact'
 $k=[Security.Cryptography.CngKey]::Open($key,[Security.Cryptography.CngProvider]::MicrosoftSoftwareKeyStorageProvider,[Security.Cryptography.CngKeyOpenOptions]::MachineKey)
 try{$path=Join-Path (Join-Path $env:ProgramData 'Microsoft\Crypto\Keys') $k.UniqueName;Check ((Compare-AuthWireSigningKeyAcl $receipt.ExpectedKeySddl (Get-Acl -LiteralPath $path).Sddl).AclEquivalent -and [int]$k.ExportPolicy -eq 0) 'All service lifecycle tests preserve the non-exportable key and its ACL'}finally{$k.Dispose()}
 @{checks=$checks;real_signed_scm=$true;actual_https=$true;low_privilege_runtime=$true;automatic_outage_recovery=$true;crash_recovery=$true;orphan_cleanup=$true;customer_gmsa_tested=$false;ad_changed=$false;gpo_changed=$false}|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $Directory 'service-result.json') -Encoding UTF8
}finally{
 if($name){$service=Get-Service -Name $name -ErrorAction SilentlyContinue;if($service){if($service.Status -ne 'Stopped'){Stop-Service -Name $name -Force;$service.WaitForStatus([ServiceProcess.ServiceControllerStatus]::Stopped,[TimeSpan]::FromSeconds(35))};$service.Dispose();Initialize-AuthWirePermanentServiceControl;[AuthWire.Connector.PermanentServiceV1]::Remove($name)}}
 if($rightsAdded){[AuthWire.Connector.FixtureServiceRightCleanupV1]::RemoveFixtureRight($sid,'SeServiceLogonRight')}
 if($user -and (Get-LocalUser -Name $user -ErrorAction SilentlyContinue)){Remove-LocalUser -Name $user}
 if(-not $key -and $keyRoot -and (Test-Path -LiteralPath (Join-Path $keyRoot 'channel-key.json'))){$key=(Get-Content -LiteralPath (Join-Path $keyRoot 'channel-key.json') -Raw|ConvertFrom-Json).KeyName;if($key -cnotmatch ('\AAuthWire-Channel-'+$id+'-[0-9a-f]{32}\z')){throw 'Fixture key cleanup scope mismatch'}}
 if($key -and [Security.Cryptography.CngKey]::Exists($key,[Security.Cryptography.CngProvider]::MicrosoftSoftwareKeyStorageProvider,[Security.Cryptography.CngKeyOpenOptions]::MachineKey)){$k=[Security.Cryptography.CngKey]::Open($key,[Security.Cryptography.CngProvider]::MicrosoftSoftwareKeyStorageProvider,[Security.Cryptography.CngKeyOpenOptions]::MachineKey);$k.Delete();$k.Dispose()}
 foreach($path in @($root,$keyRoot)){if($path -and (Test-Path -LiteralPath $path)){Assert-AuthWireChannelPath $path;Remove-Item -LiteralPath $path -Recurse -Force}}
 if($hostBytes){[IO.File]::WriteAllBytes($hosts,$hostBytes)}
 if($publishers){if($public){$publishers.Remove($public)};$publishers.Dispose()}
 if($roots){if($public){$roots.Remove($public)};if($web){$roots.Remove($web)};$roots.Dispose()}
 if($publisher){Remove-Item -LiteralPath ('Cert:\CurrentUser\My\'+$publisher.Thumbprint) -DeleteKey -Force;$publisher.Dispose()}
 if($public){$public.Dispose()};if($web){$web.Dispose()};if($null -ne $secret){$secret.Dispose()}
}
