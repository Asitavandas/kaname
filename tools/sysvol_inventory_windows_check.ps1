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
