$ErrorActionPreference='Stop';Set-StrictMode -Version 2
. (Join-Path $PSScriptRoot '..\windows\connector\SysvolInventory.ps1')
$root=Join-Path $env:TEMP ('AuthWire-SysvolFixture-'+[guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory -Path $root
$checks=0
function Check($v,$message){if(-not $v){throw $message};$script:checks++}
function Reject([scriptblock]$f){$failed=$false;try{& $f|Out-Null}catch{$failed=$true};Check $failed 'Expected inventory rejection'}
try{
 foreach($n in @('Machine','User')){$null=New-Item -ItemType Directory -Path (Join-Path $root $n)}
 [IO.File]::WriteAllText((Join-Path $root 'GPT.INI'),"[General]`r`nVersion=0`r`n")
 [IO.File]::WriteAllText((Join-Path $root 'GPO.cmt'),'fixture marker')
 $a=Get-AuthWireSysvolInventory $root;$b=Get-AuthWireSysvolInventory $root
 Check ($a.Entries.Count -eq 5 -and $a.Sha256 -ceq $b.Sha256) 'Stable complete inventory'
 Check (Test-AuthWireSysvolEmptyDeployment $a) 'Empty managed deployment accepted'
 $file=Join-Path $root 'Machine\hidden.ps1';[IO.File]::WriteAllText($file,'throw ''must not execute''')
 $b=Get-AuthWireSysvolInventory $root
 Check (-not (Test-AuthWireSysvolEmptyDeployment $b)) 'Descendant file rejected even with empty GPO report'
 Check ($b.Sha256 -cne $a.Sha256) 'Descendant bytes included'
 [IO.File]::WriteAllText($file,'different');$c=Get-AuthWireSysvolInventory $root
 Check ($b.Sha256 -cne $c.Sha256) 'File modification changes inventory'
 Remove-Item -LiteralPath $file -Force
 $link=Join-Path $root 'Machine\link';$null=New-Item -ItemType Junction -Path $link -Target (Join-Path $root 'User')
 try{Reject {Get-AuthWireSysvolInventory $root}}finally{[IO.Directory]::Delete($link)}
 $large=Join-Path $root 'Machine\large';$stream=[IO.File]::Create($large);try{$stream.SetLength(16777217)}finally{$stream.Dispose()}
 try{Reject {Get-AuthWireSysvolInventory $root}}finally{Remove-Item -LiteralPath $large}
 $deep=Join-Path $root 'Machine';1..17|ForEach-Object {$deep=Join-Path $deep 'd';$null=New-Item -ItemType Directory -Path $deep}
 Reject {Get-AuthWireSysvolInventory $root}
 Write-Host ('AUTHWIRE_SYSVOL_INVENTORY_WINDOWS_OK checks='+$checks+' customer_sysvol_tested=false')
}finally{Remove-Item -LiteralPath $root -Recurse -Force}
# Exact operator wrapper is parsed, its embedded body is checked, and its fixed
# GPO guard is exercised with simulated directory responses; never customer AD.
$entry=Join-Path $PSScriptRoot '..\docs\checkpoints\2026-10-27-dc01-sysvol-inventory.ps1'
$tokens=$null;$errors=$null;$ast=[Management.Automation.Language.Parser]::ParseFile($entry,[ref]$tokens,[ref]$errors)
Check ($errors.Count -eq 0) 'Operator wrapper native parser'
$assign=@{};foreach($node in $ast.FindAll({param($n)$n -is [Management.Automation.Language.AssignmentStatementAst] -and $n.Left -is [Management.Automation.Language.VariableExpressionAst]},$false)){$assign[$node.Left.VariablePath.UserPath]=$node.Right}
function Literal($n){return @($n.FindAll({param($x)$x -is [Management.Automation.Language.StringConstantExpressionAst]},$true))[0].Value}
$embedded=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String((Literal $assign.awLibrary)))
Check ($embedded -ceq ([IO.File]::ReadAllText((Join-Path $PSScriptRoot '..\windows\connector\SysvolInventory.ps1')).Replace("`r`n","`n"))) 'Exact embedded inventory code'
$f=$ast.Find({param($n)$n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -ceq 'Read-AuthWireInventoryGpoState'},$false)
. ([scriptblock]::Create($f.Extent.Text))
$awGpo=[guid]'8c6808fd-a382-4bf2-9c9c-d9e1d46082a3';$awDomain='lab.example';$awServer='dc.lab.example';$awMarker='fixture-owned-marker'
function Get-GPO{param($Guid,$Domain,$Server,$ErrorAction)[pscustomobject]@{Id=$awGpo;DisplayName='AuthWire-Managed-Deployment-4c23eebe';Description=$awMarker;GpoStatus='AllSettingsEnabled'}}
$script:report='<GPO xmlns="http://www.microsoft.com/GroupPolicy/Settings"><Computer><VersionDirectory>0</VersionDirectory><VersionSysvol>0</VersionSysvol></Computer><User><VersionDirectory>0</VersionDirectory><VersionSysvol>0</VersionSysvol></User></GPO>'
function Get-GPOReport{param($Guid,$Domain,$Server,$ReportType,$ErrorAction)return $script:report}
Check ((Read-AuthWireInventoryGpoState).Id -eq $awGpo) 'Unlinked empty report accepted'
$good=$script:report
foreach($bad in @($good.Replace('</GPO>','<LinksTo/></GPO>'),$good.Replace('<VersionDirectory>0','<VersionDirectory>1'),$good.Replace('</Computer>','<ExtensionData/></Computer>'),$good.Replace('<VersionDirectory>0</VersionDirectory>',''))){
 try{$script:report=$bad;Reject {Read-AuthWireInventoryGpoState}}finally{$script:report=$good}
}
Write-Host ('AUTHWIRE_SYSVOL_OPERATOR_GUARDS_WINDOWS_OK total_checks='+$checks+' customer_ad_tested=false')
