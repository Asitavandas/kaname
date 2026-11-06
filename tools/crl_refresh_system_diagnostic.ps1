# Temporary SYSTEM diagnostic; uses the installed signed client unchanged.
$ErrorActionPreference='Stop'
if([Security.Principal.WindowsIdentity]::GetCurrent().User.Value -ne 'S-1-5-18'){throw 'SYSTEM required'}
$client='C:\ProgramData\AuthWire\AuthWire-Client.ps1'
if((Get-FileHash $client).Hash -cne 'F444A1C06D8E7F743CF6ABF2B759982E844A98B45710A0FFC0ADD952393F010B'){throw 'Installed client changed'}
$s=Get-AuthenticodeSignature $client
if($s.Status -ne 'Valid' -or $s.SignerCertificate.Thumbprint -cne '6E74B513F766E01730719684A41B2664380CA68A'){throw 'Existing publisher required'}
$result=[ordered]@{event='AUTHWIRE_CRL_SYSTEM_ERROR_HISTORY';started=[datetime]::UtcNow.ToString('o');success=$false;errors=@()}
$Error.Clear()
try{& $client -CrlOnly -NoJitter;$result.success=$true}catch{
 # Intentionally omit messages, response bodies, target objects and stack text.
 $result.errors=@($Error|Select-Object -First 4|ForEach-Object {
  $e=$_.Exception;$nested=@()
  for($depth=0;$e -and $depth -lt 6;$depth++){
   $nested+=@{type=$e.GetType().FullName;hresult=$e.HResult;web_status=if($e -is [Net.WebException]){[string]$e.Status}else{$null};http_status=if($e -is [Net.WebException] -and $e.Response -is [Net.HttpWebResponse]){[int]$e.Response.StatusCode}else{$null};socket_error=if($e -is [Net.Sockets.SocketException]){[string]$e.SocketErrorCode}else{$null}}
   $e=$e.InnerException
  }
  [ordered]@{line=$_.InvocationInfo.ScriptLineNumber;file=[IO.Path]::GetFileName($_.InvocationInfo.ScriptName);exceptions=$nested}
 })
}
$result.finished=[datetime]::UtcNow.ToString('o')
$result.crl_status=Get-Content 'C:\ProgramData\AuthWire\crl-status.json' -Raw|ConvertFrom-Json
[IO.File]::WriteAllText((Join-Path $PSScriptRoot 'crl-diagnostic-result.json'),($result|ConvertTo-Json -Depth 6),(New-Object Text.UTF8Encoding($false)))
if(!$result.success){exit 1}
