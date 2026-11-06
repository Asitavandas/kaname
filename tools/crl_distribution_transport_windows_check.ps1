# In-memory transport faults only. No DNS, network, certificate store or task writes.
param([string]$ClientScript=(Join-Path $PSScriptRoot '..\kaname\device_client\AuthWire-Client.ps1'))
$ErrorActionPreference='Stop'
$t=$null;$e=$null
$ast=[Management.Automation.Language.Parser]::ParseFile($ClientScript,[ref]$t,[ref]$e)
if($e.Count){throw 'Client parse failed'}
foreach($name in 'Get-AuthWireCrlTransportStatus','New-AuthWireCrlRequest','Get-AuthWireCrlResponse'){
 $fn=$ast.Find({param($n)$n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name},$true)
 if(!$fn){throw 'Production transport function missing'}
 . ([scriptblock]::Create($fn.Extent.Text))
}
# Compile the production validator, and inspect an unconnected real request first.
$literal=$ast.Find({param($n)$n -is [Management.Automation.Language.StringConstantExpressionAst] -and $n.Value.StartsWith("using System;")},$true)
Add-Type -TypeDefinition $literal.Value
$request=New-AuthWireCrlRequest 'https://fixture.invalid/api/public/crls'
if($request.Method -cne 'GET' -or $request.AllowAutoRedirect -or $null -ne $request.Proxy -or $request.Timeout -ne 15000 -or $request.ReadWriteTimeout -ne 15000 -or !$request.ServerCertificateValidationCallback){throw 'Strict GET defaults changed'}
$request.Abort()
Add-Type -TypeDefinition @'
using System;
using System.Net;
public sealed class AuthWireCrlFaultRequest {
 public string Status;
 public object GetResponse() {
  if(Status=="OK")return new object();
  throw new WebException("synthetic transport failure",null,(WebExceptionStatus)Enum.Parse(typeof(WebExceptionStatus),Status),null);
 }
}
'@
$script:statuses=@();$script:created=0;$script:waits=0
function New-AuthWireCrlRequest([string]$Url){
 if($Url -cne 'https://fixture.invalid/api/public/crls'){throw 'Unexpected fixture destination'}
 $r=New-Object AuthWireCrlFaultRequest
 if($script:created -ge $script:statuses.Count){throw 'Request bound exceeded'}
 $r.Status=$script:statuses[$script:created];$script:created++
 return $r
}
function Start-Sleep([int]$Seconds){if($Seconds -ne 10){throw 'Retry delay changed'};$script:waits++}
$results=@()
function Case([string]$Name,[string[]]$Statuses,[int]$Attempts,[int]$Waits,[bool]$Success){
 $script:statuses=$Statuses;$script:created=0;$script:waits=0;$ok=$false
 try{$null=Get-AuthWireCrlResponse 'https://fixture.invalid/api/public/crls';$ok=$true}catch{if($Success){throw}}
 if($ok -ne $Success -or $script:created -ne $Attempts -or $script:AuthWireCrlTransportAttempts -ne $Attempts -or $script:waits -ne $Waits){throw ('Transport outcome mismatch: '+$Name)}
 [pscustomobject]@{case=$Name;attempts=$Attempts;waits=$Waits;success=$ok}
}
$results+=Case 'healthy' @('OK') 1 0 $true
$results+=Case 'DNS returns on third attempt' @('NameResolutionFailure','NameResolutionFailure','OK') 3 2 $true
$results+=Case 'persistent DNS bounded' @('NameResolutionFailure','NameResolutionFailure','NameResolutionFailure') 3 2 $false
foreach($status in 'ConnectFailure','Timeout','ReceiveFailure','ConnectionClosed','KeepAliveFailure'){
 $results+=Case ($status+' recovery') @($status,'OK') 2 1 $true
}
foreach($status in 'TrustFailure','SecureChannelFailure','ProtocolError','ServerProtocolViolation','RequestCanceled','ProxyNameResolutionFailure'){
 $results+=Case ($status+' no retry') @($status) 1 0 $false
}
[pscustomobject]@{event='AUTHWIRE_CRL_TRANSPORT_RETRY_FIXTURE';passed=$true;cases=$results;network_changed=$false;trust_changed=$false}|ConvertTo-Json -Depth 4 -Compress

