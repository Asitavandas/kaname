#Requires -Version 5.1
param([Parameter(Mandatory=$true)][string]$StopEventName,
 [Parameter(Mandatory=$true)][string]$StartEventName,
 [Parameter(Mandatory=$true)][int]$HostPid,
 [Parameter(Mandatory=$true)][long]$HostStartedTicks)
$ErrorActionPreference='Stop';Set-StrictMode -Version 2
$stop=$null;$start=$null;$parent=$null;$key=$null;$rsa=$null;$statusPath=$null
try{
 $configPath=Join-Path $PSScriptRoot 'service.json'
 if((Get-Item -LiteralPath $configPath).Length -gt 16384){throw 'CONNECTOR_CONFIG_REJECTED'}
 $c=Get-Content -LiteralPath $configPath -Raw|ConvertFrom-Json
 $name='AuthWireConnector-'+([guid]$c.Binding.connector_id).ToString('N')
 if($c.Version -ne 1 -or $c.ServiceName -cne $name -or $c.WriteSchedulerEnabled -isnot [bool] -or -not $c.WriteSchedulerEnabled -or
    $StopEventName -cnotmatch ('\ALocal\\'+$name+'-[0-9a-f]{32}\z') -or $StartEventName -cne ($StopEventName+'-Write')){throw 'CONNECTOR_CONFIG_REJECTED'}
 $parent=[Diagnostics.Process]::GetProcessById($HostPid)
 if($parent.StartTime.ToUniversalTime().Ticks -ne $HostStartedTicks -or $parent.MainModule.FileName -ine (Join-Path $PSScriptRoot 'AuthWireConnector.exe')){throw 'CONNECTOR_PARENT_REJECTED'}
 $stop=[Threading.EventWaitHandle]::OpenExisting($StopEventName)
 $start=[Threading.EventWaitHandle]::OpenExisting($StartEventName)
 if([Threading.WaitHandle]::WaitAny(@($stop,$start),5000) -ne 1 -or $parent.HasExited){exit 0}

 . (Join-Path $PSScriptRoot 'Test-AuthWireDeploymentCandidate.ps1') -LibraryOnly
 foreach($file in @('Compare-AuthWireSigningKeyAcl.ps1','ConnectorChannelTypes.ps1','ConnectorChannelKey.ps1',
  'New-AuthWireConnectorHealthProof.ps1','Invoke-AuthWireConnectorProbeJob.ps1','Invoke-AuthWireCandidateJob.ps1',
  'DeploymentScope.ps1','Invoke-AuthWireScopeJob.ps1','CombinedCandidateContent.ps1','Invoke-AuthWireCombinedJob.ps1',
  'CombinedDeploymentScope.ps1','Invoke-AuthWireCombinedScopeJob.ps1','SysvolInventory.ps1','CombinedStagingPreview.ps1',
  'StagingFilesystem.ps1','StagingWritePreclaim.ps1','StagingWriteTransport.ps1','StagingWriteConsumption.ps1',
  'StagingWriteProcess.ps1','StagingWriteExecution.ps1','StagingWriteResult.ps1','StagingWriteCycle.ps1',
  'StagingRollbackEvidence.ps1','StagingRollbackAuthorization.ps1','StagingRollbackExecution.ps1','StagingRollbackResult.ps1',
  'StagingWritePollRecord.ps1','StagingWriteLifecycle.ps1','StagingWriteScheduler.ps1')){. (Join-Path $PSScriptRoot $file)}
 Assert-AuthWireWriteServiceConfigFields $c
 $writeBaseUrl=Get-AuthWireWriteTransportBaseUrl $c

 $binding=@{};foreach($property in $c.Binding.PSObject.Properties){$binding[$property.Name]=$property.Value}
 $state=Join-Path $PSScriptRoot 'state';Assert-AuthWireChannelPath $state
 $sid=$binding.service_sid
 $expected='O:BAG:BAD:P(A;OICI;FA;;;SY)(A;OICI;FA;;;BA)(A;OICI;0x1301bf;;;'+$sid+')'
 if(-not (Compare-AuthWireSigningKeyAcl $expected (Get-Acl -LiteralPath $state).Sddl).AclEquivalent){throw 'CONNECTOR_STATUS_ACL_REJECTED'}
 $statusPath=Join-Path $state 'write-scheduler.json'
 $status=@{Event='WINDOWS_CONNECTOR_WRITE_SCHEDULER';ReleaseId=$c.ReleaseId;ServiceName=$name;WorkerPid=$PID;
  State='blocked';StopReason='startup_rejected';Steps=0;LastPhase=''}
 $root=Get-AuthWireStagingWriteJournalRoot $binding
 try{Assert-AuthWireStagingWriteJournalLocation $root $binding}catch{
  $status.StopReason='journal_unavailable';Write-AuthWireChannelReceipt $statusPath $status;exit 0
 }
 $key=[Security.Cryptography.CngKey]::Open($c.KeyName,[Security.Cryptography.CngProvider]::MicrosoftSoftwareKeyStorageProvider,[Security.Cryptography.CngKeyOpenOptions]::MachineKey)
 $rsa=[Security.Cryptography.RSACng]::new($key)
 $keyPath=Join-Path (Join-Path $env:ProgramData 'Microsoft\Crypto\Keys') $key.UniqueName
 Assert-AuthWireChannelPath $keyPath
 if(-not (Compare-AuthWireSigningKeyAcl $c.ExpectedKeySddl (Get-Acl -LiteralPath $keyPath).Sddl).AclEquivalent){throw 'CONNECTOR_KEY_ACL_MISMATCH'}
 $null=New-AuthWireConnectorPollProof -Binding $binding -ChannelKey $rsa
 $status.State='running';$status.StopReason=''
 Write-AuthWireChannelReceipt $statusPath $status
 $summary=Invoke-AuthWireStagingWriteScheduler -Root $root -Binding $binding -Release $c.ReleaseId -Key $rsa -BaseUrl $writeBaseUrl -StopSignal $stop -HostProcess $parent
 $status.State='stopped';$status.StopReason=$summary.StopReason;$status.Steps=$summary.Steps;$status.LastPhase=$summary.LastPhase
 Write-AuthWireChannelReceipt $statusPath $status
}catch{
 if($statusPath){$status.State='blocked';$status.StopReason='startup_or_runtime_failed';Write-AuthWireChannelReceipt $statusPath $status}
 exit 20
}finally{
 if($rsa){$rsa.Dispose()};if($key){$key.Dispose()};if($start){$start.Dispose()};if($stop){$stop.Dispose()};if($parent){$parent.Dispose()}
}
