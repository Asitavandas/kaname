# One-off HTTPS diagnostic under the installed CRL task's SYSTEM identity.
# Strict normal TLS validation, online revocation, and the existing pin remain required.
$ErrorActionPreference='Stop'
if([Security.Principal.WindowsIdentity]::GetCurrent().User.Value -ne 'S-1-5-18'){throw 'SYSTEM required'}
$config=Get-Content 'C:\ProgramData\AuthWire\config.json' -Raw|ConvertFrom-Json
if($config.url -cne 'https://kaname.vizyonveri.local:8765' -or $config.tls_sha256 -cne 'a58838b95510f759943e5f1b7fefe29e227960a5c1171b5ebc6d5089df47a76d'){throw 'Existing endpoint pin required'}
Add-Type -TypeDefinition @'
using System;
using System.Net.Security;
using System.Security.Cryptography;
using System.Security.Cryptography.X509Certificates;
public static class AuthWireStrictCrlDiagnostic {
 public static string Pin;
 public static string Errors;
 public static string Leaf;
 public static string[] ChainStatus;
 public static bool PinMatches;
 public static bool Validate(object sender,X509Certificate certificate,X509Chain chain,SslPolicyErrors errors) {
  Errors=errors.ToString();
  if(chain!=null) { ChainStatus=new string[chain.ChainStatus.Length];for(int i=0;i<chain.ChainStatus.Length;i++) ChainStatus[i]=chain.ChainStatus[i].Status.ToString(); }
  if(certificate==null)return false;
  Leaf=certificate.GetCertHashString();
  using(var h=SHA256.Create())PinMatches=BitConverter.ToString(h.ComputeHash(certificate.GetRawCertData())).Replace("-","").ToLowerInvariant()==Pin;
  return errors==SslPolicyErrors.None&&PinMatches;
 }
}
'@
[AuthWireStrictCrlDiagnostic]::Pin=$config.tls_sha256
[Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12
[Net.ServicePointManager]::CheckCertificateRevocationList=$true
$r=[ordered]@{event='AUTHWIRE_CRL_STRICT_SYSTEM_HTTPS';started=[datetime]::UtcNow.ToString('o');http=$null;errors=@()}
try{
 $request=[Net.HttpWebRequest]::Create($config.url+'/api/public/crls')
 $request.Method='GET';$request.AllowAutoRedirect=$false;$request.Proxy=$null
 $request.Timeout=30000;$request.ReadWriteTimeout=30000
 $request.ServerCertificateValidationCallback=[Delegate]::CreateDelegate([Net.Security.RemoteCertificateValidationCallback],[AuthWireStrictCrlDiagnostic].GetMethod('Validate'))
 $response=$request.GetResponse()
 try{$r.http=[int]$response.StatusCode;$r.content_type=$response.ContentType;$r.content_length=$response.ContentLength}finally{$response.Dispose()}
}catch{
 $e=$_.Exception
 for($i=0;$e -and $i -lt 6;$i++){
  $r.errors+=@{type=$e.GetType().FullName;hresult=$e.HResult;web_status=if($e -is [Net.WebException]){[string]$e.Status}else{$null}}
  $e=$e.InnerException
 }
}
$r.tls_errors=[AuthWireStrictCrlDiagnostic]::Errors
$r.chain_status=[AuthWireStrictCrlDiagnostic]::ChainStatus
$r.leaf=[AuthWireStrictCrlDiagnostic]::Leaf
$r.pin_matches=[AuthWireStrictCrlDiagnostic]::PinMatches
$r.finished=[datetime]::UtcNow.ToString('o')
[IO.File]::WriteAllText((Join-Path $PSScriptRoot 'crl-https-diagnostic-result.json'),($r|ConvertTo-Json -Depth 5),(New-Object Text.UTF8Encoding($false)))

