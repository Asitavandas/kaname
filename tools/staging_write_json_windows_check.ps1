#Requires -Version 5.1
param([string]$SourceRoot=(Join-Path $PSScriptRoot '..\windows\connector'))
$ErrorActionPreference='Stop';Set-StrictMode -Version 2
. (Join-Path $SourceRoot 'Test-AuthWireDeploymentCandidate.ps1') -LibraryOnly
. (Join-Path $SourceRoot 'StagingWritePreclaim.ps1')
. (Join-Path $SourceRoot 'StagingRollbackAuthorization.ps1')
. (Join-Path $SourceRoot 'StagingWriteLifecycle.ps1')
$checks=0
function Check($ok,[string]$message){if(-not $ok){throw ('CHECK_FAILED '+$message)};$script:checks++}
function ErrorCode([scriptblock]$f){try{& $f|Out-Null;return 'ACCEPTED'}catch{return $_.Exception.GetBaseException().Message}}
function ConvertTo-AuthWireReferenceJson($Value,[bool]$Sort=$true,[int]$Depth=0){
 if($Depth -gt 12){throw 'WRITE_JSON_DEPTH'}
 if($null -eq $Value){return 'null'}
 if($Value -is [bool]){if($Value){return 'true'}else{return 'false'}}
 if($Value -is [string]){
  if($Value -cmatch '[^\x20-\x7e]'){throw 'WRITE_ASCII_REQUIRED'}
  return ('"'+$Value.Replace('\','\\').Replace('"','\"')+'"')
 }
 if($Value -is [int] -or $Value -is [long]){return $Value.ToString([Globalization.CultureInfo]::InvariantCulture)}
 if($Value -is [array]){
  if($Value.Count -gt 64){throw 'WRITE_JSON_LIMIT'}
  $parts=@(foreach($v in $Value){ConvertTo-AuthWireReferenceJson $v $Sort ($Depth+1)})
  return ('['+($parts -join ',')+']')
 }
 if($Value -is [Collections.IDictionary]){$names=[string[]]@($Value.Keys)}
 elseif($Value -is [pscustomobject]){$names=[string[]]@($Value.PSObject.Properties.Name)}
 else{throw 'WRITE_JSON_KIND'}
 if($names.Count -gt 40){throw 'WRITE_JSON_LIMIT'}
 if($Sort){[Array]::Sort($names,[StringComparer]::Ordinal)}
 $parts=@(foreach($n in $names){
  $v=if($Value -is [Collections.IDictionary]){$Value[$n]}else{$Value.$n}
  (ConvertTo-AuthWireReferenceJson $n $false ($Depth+1))+':'+(ConvertTo-AuthWireReferenceJson $v $Sort ($Depth+1))
 })
 return ('{'+($parts -join ',')+'}')
}

$cases=@(
 @{TimedOut=$true;Truncated=$false;ExitCode=20;Output='private child output'},
 @{TimedOut=$false;Truncated=$true;ExitCode=20;Output='private child output'},
 @{TimedOut=$false;Truncated=$false;ExitCode=20;Output='{"error":"ROLLBACK_PREFLIGHT_FAILED","phase":"modules","exception_kind":"io"}'},
 @{TimedOut=$false;Truncated=$false;ExitCode=20;Output='{"error":"ROLLBACK_PREFLIGHT_FAILED","phase":"private path","exception_kind":"io"}'},
 @{TimedOut=$false;Truncated=$false;ExitCode=20;Output='sensitive raw exception'},
 @{TimedOut=$false;Truncated=$false;ExitCode=0;Output='success'})
$expected=@('ROLLBACK_PREFLIGHT_TIMEOUT','ROLLBACK_PREFLIGHT_OUTPUT_TRUNCATED','ROLLBACK_PREFLIGHT_CHILD_MODULES_IO','ROLLBACK_PREFLIGHT_FAILED','ROLLBACK_PREFLIGHT_FAILED','')
for($n=0;$n -lt $cases.Count;$n++){
 $code=Get-AuthWireRollbackPreflightFailureCode ([pscustomobject]$cases[$n])
 Check ($code -ceq $expected[$n]) ('preflight failure extracts only bounded safe enums case '+$n+' actual '+$code)
}
foreach($code in @($expected|Where-Object {$_})+@('private path or password')){
 $v=New-AuthWireLifecycleDispatchFailureRecord 'combined.filesystem.rollback.v1' 'execute' $code
 Check ($v.format -ceq 'AuthWireLifecycleDispatchFailedV3' -and (Test-AuthWireRollbackConsumptionDiagnostic $v.diagnostic_code)) 'rollback execute diagnostic survives strict durable shape'
 Check ((ConvertTo-AuthWireWriteJson $v).Length -lt 256 -and $v.diagnostic_code -cnotmatch 'private|password') 'diagnostic never stores raw exception text'
}
Check ((New-AuthWireLifecycleDispatchFailureRecord 'combined.filesystem.rollback.v1' 'preflight' 'private').format -ceq 'AuthWireLifecycleDispatchFailedV1') 'no-authorization refusal remains V1'
Check ((New-AuthWireLifecycleDispatchFailureRecord 'combined.filesystem.stage.v1' 'consume' 'WRITE_INTENT_PREFLIGHT_TIMEOUT').format -ceq 'AuthWireLifecycleDispatchFailedV2') 'stage diagnostic remains V2'
$culture=[Threading.Thread]::CurrentThread.CurrentCulture
try{
 [Threading.Thread]::CurrentThread.CurrentCulture=[Globalization.CultureInfo]::GetCultureInfo('tr-TR')
 $caseKeys=[Collections.Generic.Dictionary[string,object]]::new([StringComparer]::Ordinal);$caseKeys.Add('I','upper');$caseKeys.Add('i','lower')
 Check ((ConvertTo-AuthWireWriteJson @{a=@()}) -ceq '{"a":null}') 'legacy empty property collection remains null'
 Check ((ConvertTo-AuthWireWriteJson @{a=@(1)}) -ceq '{"a":1}') 'legacy singleton property collection remains scalar'
 Check ((ConvertTo-AuthWireWriteJson @()) -ceq '[]') 'top-level empty array remains array'
 $vectors=@($null,$true,$false,'',('quote"slash\'),[int]::MinValue,[long]::MaxValue,[long]::MinValue,@(),@(1),$caseKeys,[pscustomobject]@{z=@(1,$false,$null);I='upper';j='lower';A='a';a1='aa'},[ordered]@{z=1;b='two';A=@{k=$false}},[hashtable]@{1='numeric key';x='mixed'},[psobject]::AsPSObject(17))
 foreach($v in $vectors){foreach($sort in @($true,$false)){
  $a=ConvertTo-AuthWireReferenceJson $v $sort;$b=ConvertTo-AuthWireWriteJson $v $sort
  Check ($a -ceq $b) 'golden bytes and insertion/ordinal order under Turkish culture'
 }}
 $random=[Random]::new(7341)
 for($i=0;$i -lt 500;$i++){
  $array=@(for($k=0;$k -lt $random.Next(0,12);$k++){[pscustomobject][ordered]@{Path=('Machine/a'+$random.Next(10000));Size=[long]$random.Next(65536);Flags=@($true,$false,$null);Sha256=('ab'*32);Sddl='O:BAG:BAD:P(A;;FA;;;SY)(A;;FR;;;BA)'}})
  $v=[pscustomobject][ordered]@{format='FixtureV1';N=$i;Z=@{inner=$array;empty=@();text=('a"b\c'+$i)};ticks=[long]639000000000000000;ok=$true}
  $expectedJson=ConvertTo-AuthWireReferenceJson $v;$actualJson=ConvertTo-AuthWireWriteJson $v
  if($expectedJson -cne $actualJson){throw ('JSON_MISMATCH case '+$i+' expected '+$expectedJson+' actual '+$actualJson)}
  Check $true 'random nested protocol bytes'
  if($i%10 -eq 0){Check ((ConvertTo-AuthWireReferenceJson $v $false) -ceq (ConvertTo-AuthWireWriteJson $v $false)) 'random insertion-order bytes'}
 }
 $nested='leaf';foreach($n in 1..13){$nested=@{next=$nested}}
 $largeArray=@(1..65);$largeObject=@{};foreach($n in 1..41){$largeObject['p'+$n]=$n}
 $invalid=@([char]65,[double]1.5,[decimal]1,[int16]1,[datetime]::UtcNow,"bad`nline",[char]0x100,$largeArray,$largeObject,$nested,[pscustomobject]@{bad="x`t"})
 foreach($v in $invalid){$a=ErrorCode {ConvertTo-AuthWireReferenceJson $v};$b=ErrorCode {ConvertTo-AuthWireWriteJson $v};Check ($a -ceq $b -and $a -cne 'ACCEPTED') 'strict kind ASCII count and depth limits unchanged'}
 foreach($d in @(-1,0,11,12,13)){
  foreach($v in @('leaf',@{a='v'},@('v'))){$a=ErrorCode {ConvertTo-AuthWireReferenceJson $v $true $d};$b=ErrorCode {ConvertTo-AuthWireWriteJson $v $true $d};Check ($a -ceq $b) 'explicit starting depth boundary'}
 }
 $v=[pscustomobject]@{job_id='5e20416c-b226-4fba-925d-27da63484158';outcome='requires_review';result=@{reason='OUTCOME_UNKNOWN';filesystem_effects='unconfirmed';rows=$array}}
 $key=[Security.Cryptography.RSACng]::new(2048)
 try{
  $old=[Text.Encoding]::ASCII.GetBytes((ConvertTo-AuthWireReferenceJson $v));$fresh=[Text.Encoding]::ASCII.GetBytes((ConvertTo-AuthWireWriteJson $v))
  $sig=$key.SignData($old,[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1)
  Check ($key.VerifyData($fresh,$sig,[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1)) 'native CNG signature over old bytes verifies with accelerated bytes'
 }finally{$key.Dispose()}
 $watch=[Diagnostics.Stopwatch]::StartNew();foreach($n in 1..60){$null=ConvertTo-AuthWireReferenceJson $v};$oldMs=$watch.Elapsed.TotalMilliseconds
 $watch.Restart();foreach($n in 1..60){$null=ConvertTo-AuthWireWriteJson $v};$newMs=$watch.Elapsed.TotalMilliseconds
 [pscustomobject]@{status='canonical_json_compatibility_passed';checks=$checks;reference_ms=[int]$oldMs;native_ms=[int]$newMs;speedup=[Math]::Round($oldMs/[Math]::Max(1,$newMs),2)}|ConvertTo-Json -Compress
}finally{[Threading.Thread]::CurrentThread.CurrentCulture=$culture}
