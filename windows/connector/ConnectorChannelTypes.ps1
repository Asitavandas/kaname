# Fixed .NET Framework-compatible public-key encoding and per-request TLS client.
function Initialize-AuthWireChannelTypes {
    if('AuthWire.Connector.ChannelTypesV1' -as [type]){return}
    Add-Type -AssemblyName System.Net.Http
    $httpAssembly=[Net.Http.HttpClientHandler].Assembly.Location
    Add-Type -ReferencedAssemblies @('System.dll','System.Core.dll',$httpAssembly) -TypeDefinition @'
using System;
using System.IO;
using System.Net;
using System.Net.Http;
using System.Threading;
using System.Net.Security;
using System.Security.Authentication;
using System.Security.Cryptography;
using System.Security.Cryptography.X509Certificates;
using System.Text;
using System.Text.RegularExpressions;
namespace AuthWire.Connector {
public static class ChannelTypesV1 {
 static byte[] Join(params byte[][] values){using(var s=new MemoryStream()){foreach(var v in values)s.Write(v,0,v.Length);return s.ToArray();}}
 static byte[] Len(int n){if(n<128)return new byte[]{(byte)n};if(n<256)return new byte[]{129,(byte)n};return new byte[]{130,(byte)(n>>8),(byte)n};}
 static byte[] Der(byte tag,byte[] v){return Join(new byte[]{tag},Len(v.Length),v);}
 static byte[] Integer(byte[] v){return Der(2,(v[0]&128)!=0?Join(new byte[]{0},v):v);}
 public static string PublicPem(RSA rsa){var p=rsa.ExportParameters(false);var pub=Der(48,Join(Integer(p.Modulus),Integer(p.Exponent)));
  byte[] alg={48,13,6,9,42,134,72,134,247,13,1,1,1,5,0};
  string b=Convert.ToBase64String(Der(48,Join(alg,Der(3,Join(new byte[]{0},pub)))));
  var s=new StringBuilder("-----BEGIN PUBLIC KEY-----\n");for(int i=0;i<b.Length;i+=64)s.Append(b.Substring(i,Math.Min(64,b.Length-i))).Append('\n');
  return s.Append("-----END PUBLIC KEY-----\n").ToString(); }
 public static string Post(string baseUrl,string fqdn,string pin,string path,string json){
  Uri root;if(!Uri.TryCreate(baseUrl,UriKind.Absolute,out root)||root.Scheme!="https"||root.Host!=fqdn||root.UserInfo!=""||root.Query!=""||root.Fragment!=""||root.AbsolutePath!="/"||!Regex.IsMatch(pin,"\\A[0-9a-f]{64}\\z")||
    (path!="/api/connector/v1/challenge"&&path!="/api/connector/v1/health"))throw new InvalidOperationException("CONNECTOR_HTTPS_CONFIGURATION_REJECTED");
  byte[] body=new UTF8Encoding(false,true).GetBytes(json);if(body.Length>4096)throw new InvalidOperationException("CONNECTOR_HTTPS_BODY_LIMIT");
  using(var handler=new HttpClientHandler()){
   handler.SslProtocols=SslProtocols.Tls12;handler.AllowAutoRedirect=false;handler.UseProxy=false;handler.Proxy=null;
   handler.UseCookies=false;handler.UseDefaultCredentials=false;handler.Credentials=null;handler.PreAuthenticate=false;
   handler.MaxResponseHeadersLength=16;handler.AutomaticDecompression=DecompressionMethods.None;
   handler.CheckCertificateRevocationList=true;
   handler.ServerCertificateCustomValidationCallback=delegate(HttpRequestMessage message,X509Certificate2 cert,X509Chain chain,SslPolicyErrors errors){
    if(errors!=SslPolicyErrors.None||cert==null)return false;
    if(DateTime.UtcNow<cert.NotBefore.ToUniversalTime()||DateTime.UtcNow>=cert.NotAfter.ToUniversalTime())return false;
    using(var sha=SHA256.Create())return BitConverter.ToString(sha.ComputeHash(cert.RawData)).Replace("-","").ToLowerInvariant()==pin;
   };
   using(var client=new HttpClient(handler)){
    client.Timeout=TimeSpan.FromSeconds(5);client.MaxResponseContentBufferSize=4096;
    using(var timeout=new CancellationTokenSource(5000))
    using(var request=new HttpRequestMessage(HttpMethod.Post,new Uri(root,path))){
     request.Headers.ConnectionClose=true;request.Headers.Accept.ParseAdd("application/json");
     request.Content=new ByteArrayContent(body);request.Content.Headers.ContentType=new System.Net.Http.Headers.MediaTypeHeaderValue("application/json");
     try{using(var response=client.SendAsync(request,HttpCompletionOption.ResponseContentRead,timeout.Token).GetAwaiter().GetResult()){
      var content=response.Content;var type=content.Headers.ContentType;
      if(response.StatusCode!=HttpStatusCode.OK||content.Headers.ContentLength>4096||content.Headers.ContentEncoding.Count!=0||type==null||
       !String.Equals(type.MediaType,"application/json",StringComparison.OrdinalIgnoreCase)||
       (type.CharSet!=null&&!String.Equals(type.CharSet,"utf-8",StringComparison.OrdinalIgnoreCase)))throw new InvalidOperationException();
      byte[] bytes=content.ReadAsByteArrayAsync().GetAwaiter().GetResult();if(bytes.Length>4096)throw new InvalidOperationException();
      return new UTF8Encoding(false,true).GetString(bytes);
     }}catch{throw new InvalidOperationException("CONNECTOR_HTTPS_REJECTED");}
    }
   }
  }
 }
 public static string Frame(string json){var m=Regex.Match(json,"\\A\\s*\\{\\s*\"frame\"\\s*:\\s*\"([A-Za-z0-9+/=]{1,2732})\"\\s*\\}\\s*\\z");if(!m.Success)throw new InvalidOperationException("CONNECTOR_REPLY_REJECTED");return m.Groups[1].Value;}
 public static bool Healthy(string json){
  var head=Regex.Match(json,"\\A\\s*\\{(.*)\\}\\s*\\z",RegexOptions.Singleline);if(!head.Success)return false;
  var parts=head.Groups[1].Value.Split(',');if(parts.Length!=4)return false;var seen=new System.Collections.Generic.HashSet<string>();
  foreach(var part in parts){var m=Regex.Match(part,"\\A\\s*\"(channel_proof_verified|can_apply|directory_sync_ready|kerberos_ready)\"\\s*:\\s*(true|false)\\s*\\z");
   if(!m.Success||!seen.Add(m.Groups[1].Value)||(m.Groups[2].Value=="true")!=(m.Groups[1].Value=="channel_proof_verified"))return false;}
  return true;
 }
}
}
'@
}
