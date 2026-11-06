# Synthetic in-memory CRL store only. No LocalMachine store, NIC or service writes.
param([Parameter(Mandatory=$true)][string]$FixtureJson,
 [string]$ClientScript=(Join-Path $PSScriptRoot '..\kaname\device_client\AuthWire-Client.ps1'),
 [string]$InstallerScript=(Join-Path $PSScriptRoot '..\kaname\device_client\Install-AuthWire.ps1'))
$ErrorActionPreference='Stop'
foreach($path in @($ClientScript,$InstallerScript)) {
 $t=$null;$e=$null;$ast=[Management.Automation.Language.Parser]::ParseFile($path,[ref]$t,[ref]$e)
 if($e.Count) { throw ('PowerShell syntax rejected: '+$e[0].Message) }
 if($path -eq $ClientScript) {
  $literal=$ast.Find({param($n) $n -is [Management.Automation.Language.StringConstantExpressionAst] -and $n.Value.StartsWith("using System;`n")},$true)
  if(!$literal) { throw 'Native source missing' }; Add-Type -TypeDefinition $literal.Value
 }
}
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class AuthWireFixtureStore {
 [DllImport("crypt32.dll",SetLastError=true)] public static extern IntPtr CertOpenStore(IntPtr provider,int encoding,IntPtr hprov,int flags,IntPtr parameter);
 [DllImport("crypt32.dll")] public static extern bool CertCloseStore(IntPtr store,int flags);
}
'@
$f=Get-Content -LiteralPath $FixtureJson -Raw | ConvertFrom-Json
function Bytes([string]$name) { return ,([Convert]::FromBase64String($f.$name)) }
function Refuse([scriptblock]$operation,[string]$name) {
 $rejected=$false;try { & $operation | Out-Null } catch { $rejected=$true }
 if(!$rejected) { throw ('Unsafe CRL accepted: '+$name) }; $rejections.Add($name)
}
$rejections=New-Object 'Collections.Generic.List[string]';$checks=0;$root=New-Object Security.Cryptography.X509Certificates.X509Certificate2(,(Bytes 'root'))
$issuer=New-Object Security.Cryptography.X509Certificates.X509Certificate2(,(Bytes 'issuer'))
$now=[DateTimeOffset]::Parse($f.now).UtcDateTime
$rootCrl=Bytes 'root_crl';$issuerCrl=Bytes 'issuer_crl'
try {
 $null=[AuthWireCrl]::ValidatePair($rootCrl,$issuerCrl,$root,$issuer,$now);$checks++
 foreach($name in @('expired','future','forged','delta','critical')) {
  Refuse { [AuthWireCrl]::ValidatePair($rootCrl,(Bytes $name),$root,$issuer,$now) } $name
 }
 Refuse { [AuthWireCrl]::ValidatePair((Bytes 'revoked_issuer'),$issuerCrl,$root,$issuer,$now) } 'revoked issuer'
 Refuse { [AuthWireCrl]::ValidatePair($issuerCrl,$rootCrl,$root,$issuer,$now) } 'wrong issuer'
 Refuse { [AuthWireCrl]::ValidatePair(($rootCrl+[byte]0),$issuerCrl,$root,$issuer,$now) } 'trailing DER'
 $null=[AuthWireCrl]::ValidateAdvance($issuerCrl,(Bytes 'previous'),$issuer,$now);$checks++
 foreach($name in @('rollback','lost_revocation','reused_number')) {
  Refuse { [AuthWireCrl]::ValidateAdvance((Bytes $name),$issuerCrl,$issuer,$now) } $name
 }
 $memory=[AuthWireFixtureStore]::CertOpenStore([IntPtr]2,0,[IntPtr]::Zero,0,[IntPtr]::Zero)
 if($memory -eq [IntPtr]::Zero) { throw 'Memory store unavailable' }
 try {
  $first=[AuthWireCrl]::ApplyToStore($rootCrl,$issuerCrl,$root,$issuer,$now,$memory)
  $repeat=[AuthWireCrl]::ApplyToStore($rootCrl,$issuerCrl,$root,$issuer,$now,$memory)
  if($first.Added -ne 2 -or $repeat.Added -ne 0) { throw 'CRL store idempotence failed' };$checks++
  Refuse { [AuthWireCrl]::ApplyToStore($rootCrl,(Bytes 'lost_revocation'),$root,$issuer,$now,$memory) } 'store revocation loss'
  $unchanged=[AuthWireCrl]::ApplyToStore($rootCrl,$issuerCrl,$root,$issuer,$now,$memory)
  if($unchanged.Added -ne 0) { throw 'Rejected input mutated CRL store' };$checks++
  $advanced=[AuthWireCrl]::ApplyToStore($rootCrl,(Bytes 'newer'),$root,$issuer,$now,$memory)
  if($advanced.Added -ne 1 -or $advanced.IssuerNumber -ne 10) { throw 'Newer CRL not installed' };$checks++
 } finally { $null=[AuthWireFixtureStore]::CertCloseStore($memory,0) }
 [pscustomobject]@{event='AUTHWIRE_CRL_MEMORY_STORE_CHECK';passed=$true;checks=($checks+$rejections.Count);local_machine_store_changed=$false;network_changed=$false}|ConvertTo-Json -Compress
} finally { $root.Dispose();$issuer.Dispose() }
