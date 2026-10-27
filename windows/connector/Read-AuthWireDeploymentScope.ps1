#Requires -Version 5.1
param([Parameter(Mandatory=$true)][ValidateLength(1,4096)][string]$RequestBase64)
$ErrorActionPreference='Stop';$ProgressPreference='SilentlyContinue';Set-StrictMode -Version 2
$reason='READ_FAILED';$checks=@();$observations='';$identity=$null
try{
 foreach($f in @('Compare-AuthWireSigningKeyAcl.ps1','Invoke-AuthWireCandidateJob.ps1','DeploymentScope.ps1')){. (Join-Path $PSScriptRoot $f)}
 . (Join-Path $PSScriptRoot 'Test-AuthWireDeploymentCandidate.ps1') -LibraryOnly
 $target=ConvertFrom-AuthWireCandidateJson ([Convert]::FromBase64String($RequestBase64))
 Assert-AuthWireScopeTarget $target
 $cp=Join-Path $PSScriptRoot 'service.json'
 $c=ConvertFrom-AuthWireCandidateJson (Read-AuthWireCandidateBytes $cp 16384)
 $binding=@{};foreach($p in $c.Binding.PSObject.Properties){$binding[$p.Name]=$p.Value}
 $identity=[Security.Principal.WindowsIdentity]::GetCurrent()
 if($identity.User.Value -cne $binding.service_sid -or ([Security.Principal.WindowsPrincipal]::new($identity)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator) -or $c.RootPath -cne $PSScriptRoot){throw 'SCOPE_READ_REJECTED'}
 $reason='CONTENT_REJECTED'
 $a=Get-AuthWireScopeContext $target $binding $c.PublisherThumbprint
 $reason='READ_FAILED'
 Import-Module ActiveDirectory -ErrorAction Stop
 Import-Module GroupPolicy -ErrorAction Stop
 $one=Get-AuthWireScopeData $a $target $binding
 $null=Test-AuthWireScopeData $one $a $target $binding
 $two=Get-AuthWireScopeData $a $target $binding
 $null=Test-AuthWireScopeData $two $a $target $binding
 $h=Get-AuthWireScopeDataHash $one
 if($h -cne (Get-AuthWireScopeDataHash $two)){throw 'SCOPE_DIRECTORY_CHANGED'}
 # Recheck the pinned public candidate after the directory read as well.
 $null=Get-AuthWireScopeContext $target $binding $c.PublisherThumbprint
 $reason='OK';$observations=$h
 $checks=@('content','directory','gpo_identity','gpo_permissions','gpo_unlinked','gpo_empty','sysvol_root_acl')
}catch{
 if($_.Exception.Message -ceq 'SCOPE_DIRECTORY_CHANGED'){$reason='DIRECTORY_SCOPE_CHANGED'}
 elseif($_.Exception.Message -ceq 'SCOPE_GPO_CHANGED'){$reason='GPO_SCOPE_CHANGED'}
 elseif($_.Exception.Message -ceq 'SCOPE_CONTENT_REJECTED'){$reason='CONTENT_REJECTED'}
 $checks=@()
}finally{if($identity){$identity.Dispose()}}
if(-not $observations){$sha=[Security.Cryptography.SHA256]::Create();try{$observations=([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::ASCII.GetBytes('AuthWireScopeReadFailureV1:'+ $reason)))).Replace('-','').ToLowerInvariant()}finally{$sha.Dispose()}}
[Console]::Out.WriteLine((@{checked_at=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds();checks=$checks;reason=$reason;observations_sha256=$observations}|ConvertTo-Json -Compress))
