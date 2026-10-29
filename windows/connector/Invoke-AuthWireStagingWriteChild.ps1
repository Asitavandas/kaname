#Requires -Version 5.1
# Fixed AllSigned entry point; no URL, command or source/GPO path in arguments.
param([Parameter(Mandatory=$true)][ValidateLength(1,1800)][string]$JournalRoot,
      [Parameter(Mandatory=$true)][string]$JobId,
      [Parameter(Mandatory=$true)][string]$IntentSha256)
$ErrorActionPreference='Stop';$ProgressPreference='SilentlyContinue';Set-StrictMode -Version 2
$key=$null;$rsa=$null;$pin=$null;$script:AuthWireStageChildPhase='load'
try{
 . (Join-Path $PSScriptRoot 'Test-AuthWireDeploymentCandidate.ps1') -LibraryOnly
 foreach($f in @('Compare-AuthWireSigningKeyAcl.ps1','New-AuthWireConnectorHealthProof.ps1','Invoke-AuthWireConnectorProbeJob.ps1','Invoke-AuthWireCandidateJob.ps1','DeploymentScope.ps1','Invoke-AuthWireScopeJob.ps1','CombinedCandidateContent.ps1','Invoke-AuthWireCombinedJob.ps1','CombinedDeploymentScope.ps1','Invoke-AuthWireCombinedScopeJob.ps1','SysvolInventory.ps1','CombinedStagingPreview.ps1','StagingFilesystem.ps1','StagingWritePreclaim.ps1','StagingWriteTransport.ps1','StagingWriteConsumption.ps1','StagingWriteExecution.ps1')){. (Join-Path $PSScriptRoot $f)}
 Initialize-AuthWireStagingFilesystemTypes
 $pin=[AuthWire.Staging.TreeLeaseV1]::new();$pin.PinAncestors($PSScriptRoot)
 $script:AuthWireStageChildPhase='config'
 $file=Join-Path $PSScriptRoot 'service.json';$pin.PinFile($file)
 $c=ConvertFrom-AuthWireCandidateJson (Read-AuthWireCandidateBytes $file 16384)
 Assert-AuthWireCandidateFields $c @('Version','ReleaseId','ServiceName','AccountName','PublisherThumbprint','BaseUrl','Binding','KeyName','ExpectedKeySddl','RootPath')
 Assert-AuthWireStageStrings $c @('ReleaseId','ServiceName','AccountName','PublisherThumbprint','BaseUrl','KeyName','ExpectedKeySddl','RootPath')
 if($c.Version -isnot [int] -or $c.Version -ne 1 -or $c.RootPath -cne $PSScriptRoot -or $c.PublisherThumbprint -cnotmatch '\A[0-9A-F]{40}\z'){throw 'WRITE_EXECUTION_CONFIG_REJECTED'}
 $binding=@{};foreach($p in $c.Binding.PSObject.Properties){$binding[$p.Name]=$p.Value}
 Assert-AuthWireCandidateGuid $binding.connector_id
 $id=([guid]$binding.connector_id).ToString('N')
 if($c.ServiceName -cne ('AuthWireConnector-'+$id) -or $c.KeyName -cnotmatch ('\AAuthWire-Channel-'+$id+'-[0-9a-f]{32}\z')){throw 'WRITE_EXECUTION_CONFIG_REJECTED'}
 $script:AuthWireStageChildPhase='key'
 $key=[Security.Cryptography.CngKey]::Open($c.KeyName,[Security.Cryptography.CngProvider]::MicrosoftSoftwareKeyStorageProvider,[Security.Cryptography.CngKeyOpenOptions]::MachineKey)
 $rsa=[Security.Cryptography.RSACng]::new($key)
 $keyPath=Join-Path (Join-Path ([Environment]::GetFolderPath('CommonApplicationData')) 'Microsoft\Crypto\Keys') $key.UniqueName
 if(-not (Compare-AuthWireSigningKeyAcl $c.ExpectedKeySddl (Get-Acl -LiteralPath $keyPath).Sddl).AclEquivalent){throw 'WRITE_EXECUTION_KEY_ACL_REJECTED'}
 # Import happens only after private intent, binding and original claim validation.
 $script:AuthWireStageChildPhase='intent'
 $null=Read-AuthWireAuthorizedStageIntent $JournalRoot $JobId $binding $c.ReleaseId $rsa
 $script:AuthWireStageChildPhase='modules'
 Import-Module ActiveDirectory -ErrorAction Stop;Import-Module GroupPolicy -ErrorAction Stop
 $result=Invoke-AuthWireAuthorizedStageChild $JournalRoot $JobId $IntentSha256 $binding $c.ReleaseId $rsa $c.PublisherThumbprint $c.BaseUrl
 [Console]::Out.WriteLine(($result|ConvertTo-Json -Depth 8 -Compress))
}catch{
 $kind='other'
 if($_.Exception -is [IO.IOException]){$kind='io'}elseif($_.Exception -is [UnauthorizedAccessException] -or $_.Exception -is [Security.SecurityException]){$kind='security'}elseif($_.Exception -is [TimeoutException]){$kind='timeout'}elseif($_.Exception -is [Management.Automation.RuntimeException]){$kind='runtime'}
 [Console]::Out.WriteLine(([ordered]@{error='WRITE_EXECUTION_REQUIRES_REVIEW';phase=$script:AuthWireStageChildPhase;exception_kind=$kind}|ConvertTo-Json -Compress))
 exit 20
}finally{if($pin){$pin.Dispose()};if($rsa){$rsa.Dispose()};if($key){$key.Dispose()}}
