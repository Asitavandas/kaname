#Requires -Version 5.1
# Fixed read-only child; parent supplies its LOCAL protected journal root/job ID.
param([Parameter(Mandatory=$true)][ValidateLength(1,1800)][string]$JournalRoot,
      [Parameter(Mandatory=$true)][string]$JobId)
$ErrorActionPreference='Stop';$ProgressPreference='SilentlyContinue';Set-StrictMode -Version 2
try{
 foreach($f in @('Compare-AuthWireSigningKeyAcl.ps1','Invoke-AuthWireConnectorProbeJob.ps1','Invoke-AuthWireCandidateJob.ps1','DeploymentScope.ps1','Invoke-AuthWireScopeJob.ps1','CombinedCandidateContent.ps1','Invoke-AuthWireCombinedJob.ps1','CombinedDeploymentScope.ps1','Invoke-AuthWireCombinedScopeJob.ps1','SysvolInventory.ps1','CombinedStagingPreview.ps1','StagingFilesystem.ps1','StagingWritePreclaim.ps1')){. (Join-Path $PSScriptRoot $f)}
 . (Join-Path $PSScriptRoot 'Test-AuthWireDeploymentCandidate.ps1') -LibraryOnly
 $c=ConvertFrom-AuthWireCandidateJson (Read-AuthWireCandidateBytes (Join-Path $PSScriptRoot 'service.json') 16384)
 if($c.RootPath -cne $PSScriptRoot){throw 'WRITE_PACKAGE_REJECTED'}
 $binding=@{};foreach($p in $c.Binding.PSObject.Properties){$binding[$p.Name]=$p.Value}
 $offer=Read-AuthWireStagingWriteOffer $JournalRoot $JobId $binding $c.ReleaseId
 Import-Module ActiveDirectory -ErrorAction Stop;Import-Module GroupPolicy -ErrorAction Stop
 $result=Get-AuthWireWriteStageLiveContext $offer $binding $c.PublisherThumbprint $c.BaseUrl
 [Console]::Out.WriteLine(($result|ConvertTo-Json -Depth 8 -Compress))
}catch{
 [Console]::Out.WriteLine('{"error":"WRITE_PREFLIGHT_FAILED"}')
 exit 20
}
