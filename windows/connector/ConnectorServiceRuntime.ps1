#Requires -Version 5.1
param([Parameter(Mandatory=$true)][string]$StopEventName,
 [Parameter(Mandatory=$true)][int]$HostPid,
 [Parameter(Mandatory=$true)][long]$HostStartedTicks)
$ErrorActionPreference='Stop';Set-StrictMode -Version 2
$stop=$null;$key=$null;$rsa=$null;$parent=$null;$single=$null
try{
 $configPath=Join-Path $PSScriptRoot 'service.json'
 if((Get-Item -LiteralPath $configPath).Length -gt 16384){throw 'CONNECTOR_CONFIG_REJECTED'}
 $c=Get-Content -LiteralPath $configPath -Raw|ConvertFrom-Json
 $name='AuthWireConnector-'+([guid]$c.Binding.connector_id).ToString('N')
 if($c.Version -ne 1 -or $c.ServiceName -cne $name -or $StopEventName -cnotmatch ('\ALocal\\'+$name+'-[0-9a-f]{32}\z')){throw 'CONNECTOR_CONFIG_REJECTED'}
 $stop=[Threading.EventWaitHandle]::OpenExisting($StopEventName)
 $parent=[Diagnostics.Process]::GetProcessById($HostPid)
 if($parent.StartTime.ToUniversalTime().Ticks -ne $HostStartedTicks -or $parent.MainModule.FileName -ine (Join-Path $PSScriptRoot 'AuthWireConnector.exe')){throw 'CONNECTOR_PARENT_REJECTED'}
 $mutexAcl=[Security.AccessControl.MutexSecurity]::new()
 $mutexAcl.AddAccessRule([Security.AccessControl.MutexAccessRule]::new([Security.Principal.SecurityIdentifier]::new($c.Binding.service_sid),[Security.AccessControl.MutexRights]::FullControl,[Security.AccessControl.AccessControlType]::Allow))
 $created=$false
 $single=[Threading.Mutex]::new($false,('Global\'+$name+'-Worker'),[ref]$created,$mutexAcl)
 if(-not $created){throw 'CONNECTOR_DUPLICATE_WORKER'}
 foreach($file in @('Compare-AuthWireSigningKeyAcl.ps1','ConnectorChannelTypes.ps1','ConnectorChannelKey.ps1','New-AuthWireConnectorHealthProof.ps1','Invoke-AuthWireConnectorHealth.ps1','Invoke-AuthWireConnectorProbeJob.ps1')){. (Join-Path $PSScriptRoot $file)}
 . (Join-Path $PSScriptRoot 'Test-AuthWireDeploymentCandidate.ps1') -LibraryOnly
 . (Join-Path $PSScriptRoot 'Invoke-AuthWireCandidateJob.ps1')
 $binding=@{};foreach($p in $c.Binding.PSObject.Properties){$binding[$p.Name]=$p.Value}
 $key=[Security.Cryptography.CngKey]::Open($c.KeyName,[Security.Cryptography.CngProvider]::MicrosoftSoftwareKeyStorageProvider,[Security.Cryptography.CngKeyOpenOptions]::MachineKey)
 $rsa=[Security.Cryptography.RSACng]::new($key)
 $keyPath=Join-Path (Join-Path $env:ProgramData 'Microsoft\Crypto\Keys') $key.UniqueName
 Assert-AuthWireChannelPath $keyPath
 if(-not (Compare-AuthWireSigningKeyAcl $c.ExpectedKeySddl (Get-Acl -LiteralPath $keyPath).Sddl).AclEquivalent){throw 'CONNECTOR_KEY_ACL_MISMATCH'}
 $null=New-AuthWireConnectorPollProof -Binding $binding -ChannelKey $rsa
 $state=Join-Path $PSScriptRoot 'state';Assert-AuthWireChannelPath $state
 $sid=$binding.service_sid;$acl=Get-Acl -LiteralPath $state
 $expected='O:BAG:BAD:P(A;OICI;FA;;;SY)(A;OICI;FA;;;BA)(A;OICI;0x1301bf;;;'+$sid+')'
 if(-not (Compare-AuthWireSigningKeyAcl $expected $acl.Sddl).AclEquivalent){throw 'CONNECTOR_STATUS_ACL_REJECTED'}
 $failures=0;$success=0;$lastSuccess=$null;$jobCount=0;$lastJob=''
 while(-not $stop.WaitOne(0) -and -not $parent.HasExited){
  $ok=$false
  try{
   if(-not (Compare-AuthWireSigningKeyAcl $c.ExpectedKeySddl (Get-Acl -LiteralPath $keyPath).Sddl).AclEquivalent){throw 'CONNECTOR_KEY_ACL_MISMATCH'}
   $r=Invoke-AuthWireConnectorHealth -BaseUrl $c.BaseUrl -Binding $binding -ChannelKey $rsa
   $ok=($r.Verified -and -not $r.CanApply -and -not $r.KerberosReady -and -not $r.DirectorySyncReady)
  }catch{$ok=$false}
  if($ok){$failures=0;$success++;$lastSuccess=[DateTimeOffset]::UtcNow.ToString('o');$delay=30}
  else{$failures=[Math]::Min(1000,$failures+1);$delay=if($failures -eq 1){30}elseif($failures -eq 2){60}else{120}}
  $probeReady=$false
  if($ok){try{
   $probe=Invoke-AuthWireConnectorProbeJob -BaseUrl $c.BaseUrl -Binding $binding -ChannelKey $rsa -PackageReleaseId $c.ReleaseId
   $probeReady=$probe.ProbeChannelVerified
   if($probe.JobCompleted){$jobCount++;$lastJob=$probe.JobId}
  }catch{$probeReady=$false}}
  $candidateReady=$false
  if($ok){try{
   $candidate=Invoke-AuthWireCandidateJob -BaseUrl $c.BaseUrl -Binding $binding -ChannelKey $rsa -PackageReleaseId $c.ReleaseId -PublisherThumbprint $c.PublisherThumbprint
   $candidateReady=$candidate.ChannelVerified
  }catch{$candidateReady=$false}}
  $status=@{Event='WINDOWS_CONNECTOR_SERVICE_HEALTH';Version=1;ReleaseId=$c.ReleaseId;ServiceName=$name;RuntimeSid=$sid;WorkerPid=$PID;CheckedUtc=[DateTimeOffset]::UtcNow.ToString('o');LastSuccessUtc=$lastSuccess;SuccessCount=$success;ConsecutiveFailures=$failures;Healthy=$ok;CanApply=$false;DirectorySyncReady=$false;KerberosReady=$false;NextAttemptSeconds=$delay;ProbeChannelVerified=$probeReady;ProbeJobsCompleted=$jobCount;LastProbeJobId=$lastJob;CandidateChannelVerified=$candidateReady}
  Write-AuthWireChannelReceipt -Path (Join-Path $state 'status.json') -Value $status
  for($i=0;$i -lt $delay;$i++){if($stop.WaitOne(1000) -or $parent.HasExited){break}}
 }
 exit 0
}catch{exit 20}
finally{if($rsa){$rsa.Dispose()};if($key){$key.Dispose()};if($stop){$stop.Dispose()};if($single){$single.Dispose()};if($parent){$parent.Dispose()}}
