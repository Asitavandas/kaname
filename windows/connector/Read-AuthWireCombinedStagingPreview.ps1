#Requires -Version 5.1
param([Parameter(Mandatory=$true)][ValidateLength(1,4096)][string]$RequestBase64)
$ErrorActionPreference='Stop';$ProgressPreference='SilentlyContinue';Set-StrictMode -Version 2
$result=@{format=1;checked_at=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds();reason='READ_FAILED';preview=$null;preview_sha256=''}
try{
 foreach($f in @('Compare-AuthWireSigningKeyAcl.ps1','Invoke-AuthWireConnectorProbeJob.ps1','Invoke-AuthWireCandidateJob.ps1','DeploymentScope.ps1','CombinedCandidateContent.ps1','Invoke-AuthWireCombinedJob.ps1','CombinedDeploymentScope.ps1','Invoke-AuthWireCombinedScopeJob.ps1','SysvolInventory.ps1','CombinedStagingPreview.ps1')){. (Join-Path $PSScriptRoot $f)}
 . (Join-Path $PSScriptRoot 'Test-AuthWireDeploymentCandidate.ps1') -LibraryOnly
 $target=ConvertFrom-AuthWireCandidateJson ([Convert]::FromBase64String($RequestBase64))
 Assert-AuthWireCombinedScopeTarget $target
 $c=ConvertFrom-AuthWireCandidateJson (Read-AuthWireCandidateBytes (Join-Path $PSScriptRoot 'service.json') 16384)
 if($c.RootPath -cne $PSScriptRoot){throw 'STAGING_CONTENT_REJECTED'}
 $binding=@{};foreach($p in $c.Binding.PSObject.Properties){$binding[$p.Name]=$p.Value}
 Import-Module ActiveDirectory -ErrorAction Stop
 Import-Module GroupPolicy -ErrorAction Stop
 $value=Get-AuthWireCombinedStagingPreview $target $binding $c.PublisherThumbprint $c.BaseUrl
 $result.checked_at=$value.Preview.checked_at;$result.reason='OK';$result.preview=$value.Preview;$result.preview_sha256=$value.PreviewSha256
}catch{
 $message=$_.Exception.Message
 if($message -ceq 'SCOPE_DIRECTORY_CHANGED'){$result.reason='DIRECTORY_SCOPE_CHANGED'}
 elseif($message -ceq 'SCOPE_GPO_CHANGED'){$result.reason='GPO_SCOPE_CHANGED'}
 elseif($message -ceq 'STAGING_OBSERVATIONS_CHANGED'){$result.reason='OBSERVATIONS_CHANGED'}
 elseif($message -match 'CONTENT|STAGING_SOURCE|STAGING_FILE|DEPLOYMENT_'){$result.reason='CONTENT_REJECTED'}
}
[Console]::Out.WriteLine(($result|ConvertTo-Json -Depth 10 -Compress))
