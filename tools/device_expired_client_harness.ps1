# CI-only transport harness: execute the signed production client's main AST
# with synthetic session/transport, real local issuer and native machine keys.
param([string]$FixtureRoot,[string]$ClientSource)
$ErrorActionPreference='Stop'
if([Security.Principal.WindowsIdentity]::GetCurrent().User.Value -ne 'S-1-5-18') {throw 'SYSTEM fixture required.'}
if(!(Test-Path (Join-Path $FixtureRoot 'EXPIRED_RECOVERY_FIXTURE_ONLY'))) {throw 'Fixture marker required.'}
if((Get-AuthenticodeSignature $ClientSource).Status -ne 'Valid') {throw 'Signed production source required.'}
. $ClientSource -ValidateOnly
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile($ClientSource,[ref]$tokens,[ref]$errors)
if($errors.Count) {throw 'Client parse failed.'}
foreach($name in @('Save-State','Key-Proof')) {
    $definition=@($ast.EndBlock.Statements | Where-Object {$_ -is [Management.Automation.Language.FunctionDefinitionAst] -and $_.Name -eq $name})
    if($definition.Count -ne 1) {throw 'Unexpected client function layout.'}
    . ([scriptblock]::Create($definition[0].Extent.Text))
}
function New-AuthWireFixtureSession {
    $value=New-Object PSObject
    $value | Add-Member ScriptMethod Start {return ,([byte[]]@(1))}
    $value | Add-Member ScriptMethod Finish {param($token)}
    $value | Add-Member ScriptMethod Dispose {}
    return $value
}
function Post-Json($path,$data) {
    if($path -ne '/api/device/session') {throw 'Unexpected unprotected fixture route.'}
    return @{token='';id='synthetic-kerberos-fixture'}
}
function Protected-Post($path,$data) {
    $request=@{path=$path;body=$data}|ConvertTo-Json -Depth 8 -Compress
    [IO.File]::WriteAllText((Join-Path $FixtureRoot 'bridge-request.json'),$request,(New-Object Text.UTF8Encoding($false)))
    $result=& $script:fixturePython -m tools.device_expired_fixture --root $FixtureRoot --step dispatch
    if($LASTEXITCODE -ne 0) {throw 'Isolated fixture bridge failed.'}
    $answer=($result|Out-String)|ConvertFrom-Json
    if($answer.fixture_error) {$script:serverError=[string]$answer.fixture_error;throw 'Isolated issuer rejected request.'}
    return $answer
}
$script:fixturePython=(Get-Content (Join-Path $FixtureRoot 'python-path.txt') -Raw).Trim()
Set-Location (Get-Content (Join-Path $FixtureRoot 'repository-path.txt') -Raw).Trim()
$directory=$FixtureRoot
$profile=Get-Content (Join-Path $FixtureRoot 'profile.json') -Raw|ConvertFrom-Json
$config=@{url='https://authwire.lab.example:8765';spn='HTTP/authwire.lab.example';profile_id=$profile.id;tls_sha256=('0'*64)}
$NoJitter=$true;$session=$null;$private=$null;$stage='bootstrap';$serverError=$null
$mutex=New-Object Threading.Mutex($false,('Global\AuthWire-Expired-CI-'+(Split-Path $FixtureRoot -Leaf)))
$null=$mutex.WaitOne(0)
$main=@($ast.EndBlock.Statements | Where-Object {$_ -is [Management.Automation.Language.TryStatementAst]})
if($main.Count -ne 1) {throw 'Unexpected client main layout.'}
$mainText=$main[0].Extent.Text
$needle='New-Object AuthWireSspi($config.spn)'
if([regex]::Matches($mainText,[regex]::Escape($needle)).Count -ne 2) {throw 'Unexpected session construction count.'}
# Only the Kerberos constructor/transport is replaced. Actual client state,
# CNG/CSR, expiry catch, chain checks, certreq install and receipt flow execute.
$mainText=$mainText.Replace($needle,'New-AuthWireFixtureSession')
. ([scriptblock]::Create($mainText))
