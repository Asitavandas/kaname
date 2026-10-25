# Fixed .NET Framework-compatible public-key encoding and per-request TLS client.
function Initialize-AuthWireChannelTypes {
    if('AuthWire.Connector.ChannelTypesV1' -as [type]){return}
    Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Net;
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
  var r=(HttpWebRequest)WebRequest.Create(new Uri(root,path));r.Method="POST";r.ContentType="application/json";r.Accept="application/json";
  r.AllowAutoRedirect=false;r.KeepAlive=false;r.Proxy=null;r.UseDefaultCredentials=false;r.Credentials=null;r.PreAuthenticate=false;
  r.Timeout=5000;r.ReadWriteTimeout=5000;r.MaximumResponseHeadersLength=16;r.ContentLength=body.Length;r.SslProtocols=SslProtocols.Tls12;
  r.ConnectionGroupName=Guid.NewGuid().ToString("N");
  r.ServerCertificateValidationCallback=delegate(object sender,X509Certificate cert,X509Chain chain,SslPolicyErrors errors){
   if(errors!=SslPolicyErrors.None||cert==null)return false;
   using(var c=new X509Certificate2(cert)){if(DateTime.UtcNow<c.NotBefore.ToUniversalTime()||DateTime.UtcNow>=c.NotAfter.ToUniversalTime())return false;
    using(var sha=SHA256.Create())return BitConverter.ToString(sha.ComputeHash(c.RawData)).Replace("-","").ToLowerInvariant()==pin;}
  };
  using(var timer=new System.Threading.Timer(delegate(object _){r.Abort();},null,5000,System.Threading.Timeout.Infinite)){
   try{using(var s=r.GetRequestStream())s.Write(body,0,body.Length);
    using(var response=(HttpWebResponse)r.GetResponse()){
     if(response.StatusCode!=HttpStatusCode.OK||response.ContentLength>4096||response.ContentEncoding!=""||response.ContentType.Split(';')[0].Trim().ToLowerInvariant()!="application/json")throw new InvalidOperationException();
     using(var input=response.GetResponseStream())using(var data=new MemoryStream()){
      byte[] block=new byte[1024];int n;while((n=input.Read(block,0,block.Length))>0){if(data.Length+n>4096)throw new InvalidOperationException();data.Write(block,0,n);}
      return new UTF8Encoding(false,true).GetString(data.ToArray());
     }
    }
   }catch{throw new InvalidOperationException("CONNECTOR_HTTPS_REJECTED");}
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
