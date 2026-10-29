# Source-only transport and durable grant receipt. Not loaded by the worker.
# No filesystem executor, GPO activation, automatic retry or cleanup is provided.
Set-StrictMode -Version 2

function Initialize-AuthWireWriteTransportTypes {
 if('AuthWire.Connector.WriteTransportV1' -as [type]){return}
 Add-Type -AssemblyName System.Net.Http
 Add-Type -ReferencedAssemblies @('System.dll','System.Core.dll',[Net.Http.HttpClientHandler].Assembly.Location) -TypeDefinition @'
using System;
using System.IO;
using System.Net;
using System.Net.Http;
using System.Net.Security;
using System.Security.Authentication;
using System.Security.Cryptography;
using System.Security.Cryptography.X509Certificates;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
namespace AuthWire.Connector {
public static class WriteTransportV1 {
 public static string Post(string baseUrl,string fqdn,string pin,string path,string json){
  Uri root;
  if(!Uri.TryCreate(baseUrl,UriKind.Absolute,out root)||root.Scheme!="https"||root.Host!=fqdn||root.UserInfo!=""||root.Query!=""||root.Fragment!=""||root.AbsolutePath!="/"||
   !Regex.IsMatch(fqdn,"\\A[a-z0-9](?:[a-z0-9.-]{0,251}[a-z0-9])?\\z")||fqdn.IndexOf('.')<1||!Regex.IsMatch(pin,"\\A[0-9a-f]{64}\\z")||
   (path!="/api/connector/v1/staging-write/poll"&&path!="/api/connector/v1/staging-write/claim"&&path!="/api/connector/v1/staging-write/result"))throw new InvalidOperationException("WRITE_HTTPS_CONFIGURATION_REJECTED");
  byte[] body=new UTF8Encoding(false,true).GetBytes(json);
  if(body.Length==0||body.Length>4096)throw new InvalidOperationException("WRITE_HTTPS_BODY_LIMIT");
  int limit=path.EndsWith("/poll",StringComparison.Ordinal)?32768:4096;
  using(var handler=new HttpClientHandler()){
   handler.SslProtocols=SslProtocols.Tls12;handler.AllowAutoRedirect=false;handler.UseProxy=false;handler.Proxy=null;
   handler.UseCookies=false;handler.UseDefaultCredentials=false;handler.Credentials=null;handler.PreAuthenticate=false;
   handler.MaxResponseHeadersLength=16;handler.AutomaticDecompression=DecompressionMethods.None;handler.CheckCertificateRevocationList=true;
   handler.ServerCertificateCustomValidationCallback=delegate(HttpRequestMessage message,X509Certificate2 cert,X509Chain chain,SslPolicyErrors errors){
    if(errors!=SslPolicyErrors.None||cert==null||DateTime.UtcNow<cert.NotBefore.ToUniversalTime()||DateTime.UtcNow>=cert.NotAfter.ToUniversalTime())return false;
    using(var sha=SHA256.Create())return BitConverter.ToString(sha.ComputeHash(cert.RawData)).Replace("-","").ToLowerInvariant()==pin;
   };
   using(var client=new HttpClient(handler))
   using(var timeout=new CancellationTokenSource(5000))
   using(var request=new HttpRequestMessage(HttpMethod.Post,new Uri(root,path))){
    client.Timeout=TimeSpan.FromSeconds(5);request.Headers.ConnectionClose=true;request.Headers.Accept.ParseAdd("application/json");
    request.Content=new ByteArrayContent(body);request.Content.Headers.ContentType=new System.Net.Http.Headers.MediaTypeHeaderValue("application/json");
    try{
     using(var response=client.SendAsync(request,HttpCompletionOption.ResponseHeadersRead,timeout.Token).GetAwaiter().GetResult()){
      var content=response.Content;var type=content.Headers.ContentType;
      if(response.StatusCode!=HttpStatusCode.OK||content.Headers.ContentLength>limit||content.Headers.ContentEncoding.Count!=0||type==null||
       !String.Equals(type.MediaType,"application/json",StringComparison.OrdinalIgnoreCase)||
       (type.CharSet!=null&&!String.Equals(type.CharSet,"utf-8",StringComparison.OrdinalIgnoreCase)))throw new InvalidOperationException();
      using(var abort=timeout.Token.Register(delegate{response.Dispose();}))
      using(var stream=content.ReadAsStreamAsync().GetAwaiter().GetResult())
      using(var bytes=new MemoryStream()){
       byte[] buffer=new byte[1024];
       // The SAME deadline covers headers and every body read, including chunked
       // replies with no Content-Length. Never buffer an unbounded response.
       while(true){int n=stream.ReadAsync(buffer,0,Math.Min(buffer.Length,limit+1-(int)bytes.Length),timeout.Token).GetAwaiter().GetResult();
        if(n==0)break;bytes.Write(buffer,0,n);if(bytes.Length>limit)throw new InvalidOperationException();}
       timeout.Token.ThrowIfCancellationRequested();return new UTF8Encoding(false,true).GetString(bytes.ToArray());
      }
     }
    }catch{throw new InvalidOperationException("WRITE_HTTPS_REJECTED");}
   }
  }
 }
}
}
'@
}

function ConvertFrom-AuthWireWriteBase64($Value,[int]$Limit){
 if($Value -isnot [string] -or $Value.Length -gt 4*[Math]::Ceiling($Limit/3.0)){throw 'WRITE_CLAIM_RECORD_REJECTED'}
 $raw=[Convert]::FromBase64String($Value)
 if($raw.Length -gt $Limit -or [Convert]::ToBase64String($raw) -cne $Value){throw 'WRITE_CLAIM_RECORD_REJECTED'}
 return ,$raw
}
function Assert-AuthWireStoredWriteClaim($Proof,$Started,$Offer,[hashtable]$Binding,[string]$Release,[Security.Cryptography.RSACng]$Key){
 Assert-AuthWireCandidateFields $Started @('format','job_id','intent_sha256','checked_at')
 Assert-AuthWireCandidateFields $Proof @('frame','signature','payload')
 $now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
 if($Started.format -cne 'AuthWireWriteClaimStartedV1' -or $Started.job_id -cne $Offer.job_id -or $Started.intent_sha256 -cne $Offer.intent_sha256 -or
    -not (Test-AuthWireWriteInteger $Started.checked_at) -or $Started.checked_at -gt $now -or $now-$Started.checked_at -gt 5){throw 'WRITE_CLAIM_RECORD_STALE'}
 $names=@('instance_id','connector_id','generation','host_guid','host_fqdn','service_sid','appliance_fqdn','appliance_tls_sha256','channel_key_sha256')
 if($Binding.Count -ne 9 -or @($names|Where-Object{-not $Binding.ContainsKey($_)}).Count){throw 'WRITE_CLAIM_RECORD_REJECTED'}
 $identity=[Security.Principal.WindowsIdentity]::GetCurrent()
 try{$sid=$identity.User.Value}finally{$identity.Dispose()}
 $keyPolicy=$Key.Key
 if($sid -cne $Binding.service_sid -or [Environment]::MachineName.ToLowerInvariant() -cne $Binding.host_fqdn.Split('.')[0] -or
    -not $keyPolicy.IsMachineKey -or $keyPolicy.IsEphemeral -or [int]$keyPolicy.ExportPolicy -ne 0 -or [int]$keyPolicy.KeyUsage -ne 2 -or
    $keyPolicy.Provider.Provider -cne 'Microsoft Software Key Storage Provider' -or (Get-AuthWireChannelPublicKeyId $Key) -cne $Binding.channel_key_sha256){throw 'WRITE_CLAIM_KEY_REJECTED'}
 $raw=ConvertFrom-AuthWireWriteBase64 $Proof.frame 2048
 foreach($c in $raw){if($c -ne 10 -and ($c -lt 32 -or $c -gt 126)){throw 'WRITE_CLAIM_RECORD_REJECTED'}}
 $f=[Text.Encoding]::ASCII.GetString($raw).Split([char]10)
 if($f.Count -ne 18 -or $f[0] -cne 'AUTHWIRE-STAGING-WRITE-JOB-CLAIM-V1' -or $f[15] -cne 'POST' -or $f[16] -cne '/api/connector/v1/staging-write/claim' -or $f[17] -cne ''){throw 'WRITE_CLAIM_RECORD_REJECTED'}
 for($i=0;$i -lt 9;$i++){if($f[$i+1] -cne [string]$Binding[$names[$i]]){throw 'WRITE_CLAIM_RECORD_REJECTED'}}
 foreach($i in @(10,11,14)){if(-not (Test-AuthWireWriteHash $f[$i])){throw 'WRITE_CLAIM_RECORD_REJECTED'}}
 foreach($i in @(12,13)){if($f[$i] -cnotmatch '\A[1-9][0-9]{0,10}\z'){throw 'WRITE_CLAIM_RECORD_REJECTED'}}
 $issued=[long]$f[12];$expires=[long]$f[13]
 if($expires-$issued -ne 60 -or $issued -lt $Started.checked_at -or $issued -gt $Started.checked_at+2 -or $issued -gt $now -or $now -ge $expires){throw 'WRITE_CLAIM_RECORD_STALE'}
 $payload=ConvertFrom-AuthWireWriteBase64 $Proof.payload 1024
 $signature=ConvertFrom-AuthWireWriteBase64 $Proof.signature 512
 if((Get-AuthWireJobHash $payload) -cne $f[14] -or -not $Key.VerifyData($raw,$signature,[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1)){throw 'WRITE_CLAIM_RECORD_REJECTED'}
 $body=ConvertFrom-AuthWireCandidateJson $payload
 Assert-AuthWireCandidateFields $body @('job_id','lease_id','intent_sha256','target_sha256','release_id')
 if($body.job_id -cne $Offer.job_id -or $body.lease_id -cne $Offer.lease_id -or $body.intent_sha256 -cne $Offer.intent_sha256 -or $body.target_sha256 -cne (Get-AuthWireWriteHash $Offer.target) -or $body.release_id -cne $Release){throw 'WRITE_CLAIM_RECORD_REJECTED'}
 return $f[10]
}
function Assert-AuthWireWriteGrant($Value,$Offer,[string]$RequestId,[long]$SentAt){
 Assert-AuthWireCandidateFields $Value @('format','request_id','job_id','operation','intent_sha256','target_sha256','authorization_id','expires_at','write_authorized','can_apply_gpo')
 $now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
 if($Value.format -isnot [int] -or $Value.format -ne 1 -or -not (Test-AuthWireWriteHash $RequestId) -or $Value.request_id -cne $RequestId -or
    $Value.job_id -cne $Offer.job_id -or $Value.operation -cne $Offer.operation -or $Value.intent_sha256 -cne $Offer.intent_sha256 -or $Value.target_sha256 -cne (Get-AuthWireWriteHash $Offer.target) -or
    -not (Test-AuthWireWriteHash $Value.authorization_id) -or $Value.write_authorized -isnot [bool] -or -not $Value.write_authorized -or $Value.can_apply_gpo -isnot [bool] -or $Value.can_apply_gpo -or
    $SentAt -gt $now -or $now-$SentAt -gt 5 -or -not (Test-AuthWireWriteInteger $Value.expires_at) -or $Value.expires_at -le $now -or
    $Value.expires_at -gt $Offer.expires_at -or $Value.expires_at -gt $now+30 -or $Value.expires_at -gt $SentAt+35){throw 'WRITE_GRANT_REJECTED'}
}
function Invoke-AuthWireStagingWriteClaimTransport([string]$JournalRoot,[string]$JobId,[hashtable]$Binding,[string]$Release,[Security.Cryptography.RSACng]$Key,[string]$BaseUrl){
 $offer=Read-AuthWireStagingWriteOffer $JournalRoot $JobId $Binding $Release
 Initialize-AuthWireWriteTransportTypes
 $pin=[AuthWire.Staging.TreeLeaseV1]::new()
 try{
  $pin.PinAncestors($JournalRoot);$job=Join-Path $JournalRoot $JobId;$pin.PinAncestors($job)
  foreach($name in @('offer.json','preflight.json','claim-started.json','claim-proof.json')){$pin.PinFile((Join-Path $job $name))}
  $pin.PinFile((Join-Path $JournalRoot ('gpo-'+$offer.target.scope_target.gpo_id+'.json')))
  # Re-read under native file pins: no edit/rename can replace an observed input
  # while the request is being sent and its receipt flushed.
  $again=Read-AuthWireStagingWriteOffer $JournalRoot $JobId $Binding $Release
  if((Get-AuthWireWriteHash $again) -cne (Get-AuthWireWriteHash $offer)){throw 'WRITE_LOCAL_RECORD_CHANGED'}
  $preflight=Read-AuthWireStagingJournal (Join-Path $job 'preflight.json');Assert-AuthWireWriteLiveContext $preflight $offer $Binding
  $started=Read-AuthWireStagingJournal (Join-Path $job 'claim-started.json')
  $record=Read-AuthWireStagingJournal (Join-Path $job 'claim-proof.json')
  Assert-AuthWireCandidateFields $record @('format','job_id','proof')
  if($record.format -cne 'AuthWireWriteClaimProofV1' -or $record.job_id -cne $JobId){throw 'WRITE_CLAIM_RECORD_REJECTED'}
  $request=Assert-AuthWireStoredWriteClaim $record.proof $started $offer $Binding $Release $Key
  if(Test-Path -LiteralPath (Join-Path $job 'authorization.json')){throw 'WRITE_LOCAL_RECEIPT_EXISTS_REQUIRES_REVIEW'}
  $sentAt=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
  $proofHash=Get-AuthWireWriteHash $record.proof
  # CreateNew + Flush(true) is the one-send gate across threads/reboots. Even a
  # failed TLS connection or local receipt write MUST NOT re-send this claim.
  Write-AuthWireStagingJournal (Join-Path $job 'claim-sent.json') ([pscustomobject]@{format='AuthWireWriteClaimSentV1';job_id=$JobId;request_id=$request;proof_sha256=$proofHash;sent_at=$sentAt})
  $reply=[AuthWire.Connector.WriteTransportV1]::Post($BaseUrl,$Binding.appliance_fqdn,$Binding.appliance_tls_sha256,'/api/connector/v1/staging-write/claim',(ConvertTo-AuthWireWriteJson $record.proof))
  $grant=ConvertFrom-AuthWireCandidateJson ([Text.UTF8Encoding]::new($false,$true).GetBytes($reply))
  Assert-AuthWireWriteGrant $grant $offer $request $sentAt
  Write-AuthWireStagingJournal (Join-Path $job 'authorization.json') ([pscustomobject]@{format='AuthWireWriteAuthorizationReceiptV1';binding_scope=(Get-AuthWireJobScope $Binding);release_id=$Release;offer_sha256=(Get-AuthWireWriteHash $offer);preflight_sha256=(Get-AuthWireWriteHash $preflight);claim_proof_sha256=$proofHash;sent_at=$sentAt;received_at=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds();grant=$grant})
  return [pscustomobject]@{JobId=$JobId;Phase='authorization_recorded';GrantRecorded=$true;FilesystemWriteEnabled=$false;CanApplyGpo=$false}
 }finally{$pin.Dispose()}
}
