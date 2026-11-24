#Requires -Version 5.1
# Pure deadline admission checks. No journal, key, AD, GPO or writer operation.
$ErrorActionPreference='Stop';Set-StrictMode -Version 2
$lib=Join-Path $PSScriptRoot '..\windows\connector'
. (Join-Path $lib 'Test-AuthWireDeploymentCandidate.ps1') -LibraryOnly
. (Join-Path $lib 'StagingWritePreclaim.ps1')
. (Join-Path $lib 'StagingWriteExecution.ps1')
$script:checks=0
function Check($v,[string]$name){if(-not $v){throw ('BUDGET_FIXTURE:'+ $name)};$script:checks++}
function Reject([scriptblock]$fn,[string]$name){$bad=$false;try{& $fn|Out-Null}catch{$bad=$true};Check $bad $name}
function Launch($at,$budget,$expiry){return [pscustomobject]@{started_at=$at;work_budget_ms=$budget;expires_at=$expiry}}
$at=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
$w=Get-AuthWireStageWorkWindow (Launch $at 15000 ($at+30))
Check ($w.FinishNotAfter -eq $at+15) 'parent budget caps later original grant'
Check ($w.EngineNotAfter -eq $at+14) 'one second reserved for completion'
$w=Get-AuthWireStageWorkWindow (Launch $at 14000 ($at+16))
Check ($w.EngineNotAfter -eq $at+13 -and $w.FinishNotAfter -eq $at+14) 'actual 14 second field launch has its own earlier window'
$w=Get-AuthWireStageWorkWindow (Launch $at 14999 ($at+30))
Check ($w.FinishNotAfter -eq $at+14) 'fractional seconds round down'
foreach($budget in @($true,'15000',15000.5,-1,0,99,15001)){Reject {Get-AuthWireStageWorkWindow (Launch $at $budget ($at+30))} 'invalid budget cannot coerce or enlarge'}
foreach($start in @($true,"$at",1.5,-1,0,1099511627776L)){Reject {Get-AuthWireStageWorkWindow (Launch $start 15000 ($at+30))} 'invalid start rejected'}
Reject {Get-AuthWireStageWorkWindow (Launch $at 15000 ($at+16))} 'two second original grant reserve retained'
Reject {Get-AuthWireStageWorkWindow (Launch $at 100 ($at+30))} 'tiny child window cannot admit engine'
Reject {Get-AuthWireStageWorkWindow (Launch $at 3999 ($at+30))} 'less than four whole seconds cannot admit engine'
$w=Get-AuthWireStageWorkWindow (Launch ($at-20) 15000 ($at+30))
Reject {Assert-AuthWireStageEngineBudget $w} 'expired parent budget rejected despite live grant'
$w=Get-AuthWireStageWorkWindow (Launch ($at+20) 15000 ($at+50))
Reject {Assert-AuthWireStageEngineBudget $w} 'clock before launch rejected'
Reject {Assert-AuthWireStageEngineBudget ([pscustomobject]@{StartedAt=($at-10);EngineNotAfter=($at+1)})} 'late context with less than two seconds cannot start effects'
$w=Get-AuthWireStageWorkWindow (Launch $at 15000 ($at+30));Assert-AuthWireStageEngineBudget $w
Check ($w.EngineNotAfter -lt $w.FinishNotAfter -and $w.FinishNotAfter -lt $at+30) 'adequate original window remains bounded'
Write-Host ('AUTHWIRE_STAGE_BUDGET_CHECKS_OK checks='+$script:checks+' no_effects=true')
