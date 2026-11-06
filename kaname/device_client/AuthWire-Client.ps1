# AuthWire domain computer enrollment/renewal. Run as SYSTEM through GPO.
# Sign this file with the enterprise Authenticode publisher before deployment.
param([switch]$ValidateOnly, [switch]$NoJitter, [switch]$CrlOnly)
$ErrorActionPreference = 'Stop'
Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Security.Cryptography.X509Certificates;
using System.Net.Security;
public static class AuthWireTls {
 [DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode)] static extern bool MoveFileEx(string existing,string replacement,uint flags);
 const uint MOVEFILE_REPLACE_EXISTING=0x1, MOVEFILE_WRITE_THROUGH=0x8;
 public static void AtomicReplace(string source,string destination) {
  if(!MoveFileEx(source,destination,MOVEFILE_REPLACE_EXISTING|MOVEFILE_WRITE_THROUGH)) throw new Win32Exception(Marshal.GetLastWin32Error());
 }
 public static string Pin;
 public static bool Validate(object sender, X509Certificate certificate, X509Chain chain, SslPolicyErrors errors) {
  if(errors != SslPolicyErrors.None || certificate == null) return false;
  using(var h=SHA256.Create()) return BitConverter.ToString(h.ComputeHash(certificate.GetRawCertData())).Replace("-","").ToLowerInvariant()==Pin;
 }
}
public static class AuthWireCrl {
 [StructLayout(LayoutKind.Sequential)] struct Blob { public int size; public IntPtr data; }
 [StructLayout(LayoutKind.Sequential)] struct Algorithm { public IntPtr oid; public Blob parameters; }
 [StructLayout(LayoutKind.Sequential)] struct Context { public int encoding; public IntPtr encoded; public int length; public IntPtr info,store; }
 [StructLayout(LayoutKind.Sequential)] struct Info { public int version; public Algorithm algorithm; public Blob issuer; public System.Runtime.InteropServices.ComTypes.FILETIME updated,next; public int count; public IntPtr entries; public int extensionCount; public IntPtr extensions; }
 [StructLayout(LayoutKind.Sequential)] struct Entry { public Blob serial; public System.Runtime.InteropServices.ComTypes.FILETIME revoked; public int count; public IntPtr extensions; }
 [StructLayout(LayoutKind.Sequential)] struct Extension { public IntPtr oid; public int critical; public Blob value; }
 [DllImport("crypt32.dll",SetLastError=true)] static extern IntPtr CertCreateCRLContext(int encoding,byte[] data,int length);
 [DllImport("crypt32.dll")] static extern bool CertFreeCRLContext(IntPtr context);
 [DllImport("crypt32.dll",SetLastError=true)] static extern bool CryptVerifyCertificateSignatureEx(IntPtr provider,int encoding,int subjectType,IntPtr subject,int issuerType,IntPtr issuer,int flags,IntPtr extra);
 [DllImport("crypt32.dll",SetLastError=true)] static extern IntPtr CertEnumCRLsInStore(IntPtr store,IntPtr previous);
 [DllImport("crypt32.dll",SetLastError=true)] static extern bool CertAddCRLContextToStore(IntPtr store,IntPtr context,int disposition,IntPtr output);
 sealed class Parsed {
  public byte[] raw; public long number; public DateTime updated,next;
  public System.Collections.Generic.Dictionary<string,string> entries = new System.Collections.Generic.Dictionary<string,string>();
 }
 public sealed class Result { public long RootNumber,IssuerNumber; public string RootNextUpdate,IssuerNextUpdate; public int Added; }
 static void Require(bool condition) { if(!condition) throw new InvalidOperationException("CRL validation refused"); }
 static byte[] Bytes(Blob b) { Require(b.size>=0 && b.size<=1048576); byte[] a=new byte[b.size]; if(a.Length>0) Marshal.Copy(b.data,a,0,a.Length); return a; }
 static string Hex(byte[] a) { return BitConverter.ToString(a).Replace("-",""); }
 static bool Equal(byte[] a,byte[] b) { return Hex(a)==Hex(b); }
 static DateTime Time(System.Runtime.InteropServices.ComTypes.FILETIME t) { return DateTime.FromFileTimeUtc(((long)(uint)t.dwHighDateTime<<32)|(uint)t.dwLowDateTime); }
 // Minimal canonical DER length reader for CRLNumber and AKI. Native crypt32
 // verifies the signed object; these fields must have one unambiguous encoding.
 static byte[] Der(byte[] input,byte tag) {
  Require(input.Length>=2 && input[0]==tag); int n=input[1],offset=2;
  if(n>=128) { int count=n&127; Require(count>0&&count<=3&&input.Length>=2+count&&input[2]!=0); n=0; for(int i=0;i<count;i++) n=(n<<8)|input[offset++]; Require(n>=128); }
  Require(n==input.Length-offset); byte[] result=new byte[n]; Buffer.BlockCopy(input,offset,result,0,n); return result;
 }
 static long Number(byte[] der) { byte[] v=Der(der,2); Require(v.Length>0&&v.Length<=8&&(v[0]&128)==0&&(v.Length==1||v[0]!=0||(v[1]&128)!=0)); long n=0; foreach(byte b in v) n=(n<<8)|b; Require(n>0); return n; }
 static string Serial(byte[] little) { Array.Reverse(little); return Hex(little).TrimStart('0'); }
 static System.Collections.Generic.Dictionary<string,byte[]> Extensions(int count,IntPtr address,bool entry) {
  Require(count>=0&&count<=32); var values=new System.Collections.Generic.Dictionary<string,byte[]>(); int size=Marshal.SizeOf(typeof(Extension));
  for(int i=0;i<count;i++) {
   Extension e=(Extension)Marshal.PtrToStructure(IntPtr.Add(address,i*size),typeof(Extension)); string oid=Marshal.PtrToStringAnsi(e.oid);
   Require(e.critical==0&&!values.ContainsKey(oid));
   Require(entry ? oid!="2.5.29.29" : oid!="2.5.29.27"&&oid!="2.5.29.28"&&oid!="2.5.29.46");
   values.Add(oid,Bytes(e.value));
  }
  return values;
 }
 static Parsed Parse(byte[] data,X509Certificate2 signer,DateTime now,bool current) {
  Require(data!=null&&data.Length>0&&data.Length<=1048576); Der(data,0x30);
  IntPtr p=CertCreateCRLContext(1,data,data.Length); Require(p!=IntPtr.Zero);
  try {
   Context c=(Context)Marshal.PtrToStructure(p,typeof(Context)); Info v=(Info)Marshal.PtrToStructure(c.info,typeof(Info));
   Require(Equal(Bytes(v.issuer),signer.SubjectName.RawData));
   Require(CryptVerifyCertificateSignatureEx(IntPtr.Zero,1,3,p,2,signer.Handle,0,IntPtr.Zero));
   Require(v.version==1&&Marshal.PtrToStringAnsi(v.algorithm.oid)=="1.2.840.113549.1.1.11");
   var ext=Extensions(v.extensionCount,v.extensions,false); Require(ext.ContainsKey("2.5.29.20")&&ext.ContainsKey("2.5.29.35"));
   var ski=(X509SubjectKeyIdentifierExtension)signer.Extensions["2.5.29.14"]; Require(ski!=null);
   Require(Hex(Der(Der(ext["2.5.29.35"],0x30),0x80))==ski.SubjectKeyIdentifier);
   Parsed parsed=new Parsed{raw=data,number=Number(ext["2.5.29.20"]),updated=Time(v.updated),next=Time(v.next)};
   Require(parsed.updated<=now&&parsed.next>parsed.updated&&parsed.next<=signer.NotAfter.ToUniversalTime()&&(!current||now<parsed.next));
   Require(v.count>=0&&v.count<=25000); int size=Marshal.SizeOf(typeof(Entry));
   for(int i=0;i<v.count;i++) {
    Entry e=(Entry)Marshal.PtrToStructure(IntPtr.Add(v.entries,i*size),typeof(Entry)); string serial=Serial(Bytes(e.serial)); DateTime date=Time(e.revoked);
    Require(serial.Length>0&&!parsed.entries.ContainsKey(serial)&&date<=parsed.updated);
    var entryExt=Extensions(e.count,e.extensions,true); var keys=new System.Collections.Generic.List<string>(entryExt.Keys); keys.Sort(StringComparer.Ordinal);
    string record=date.Ticks.ToString(System.Globalization.CultureInfo.InvariantCulture);
    foreach(string oid in keys) record+="|"+oid+":"+Hex(entryExt[oid]); parsed.entries.Add(serial,record);
   }
   return parsed;
  } finally { CertFreeCRLContext(p); }
 }
 static void Certificate(X509Certificate2 cert,X509Certificate2 signer,int depth,DateTime now) {
  Require(cert.NotBefore.ToUniversalTime()<=now&&now<cert.NotAfter.ToUniversalTime());
  Require(cert.SignatureAlgorithm.Value=="1.2.840.113549.1.1.11"&&Equal(cert.IssuerName.RawData,signer.SubjectName.RawData));
  Require(CryptVerifyCertificateSignatureEx(IntPtr.Zero,1,2,cert.Handle,2,signer.Handle,0,IntPtr.Zero));
  var bc=(X509BasicConstraintsExtension)cert.Extensions["2.5.29.19"]; var ku=(X509KeyUsageExtension)cert.Extensions["2.5.29.15"];
  Require(bc!=null&&bc.Critical&&bc.CertificateAuthority&&bc.HasPathLengthConstraint&&bc.PathLengthConstraint==depth);
  Require(ku!=null&&ku.Critical&&(ku.KeyUsages&(X509KeyUsageFlags.KeyCertSign|X509KeyUsageFlags.CrlSign))==(X509KeyUsageFlags.KeyCertSign|X509KeyUsageFlags.CrlSign));
  using(RSA key=RSACertificateExtensions.GetRSAPublicKey(cert)) Require(key!=null&&key.KeySize==3072);
 }
 static void Advance(Parsed candidate,Parsed old) {
  Require(candidate.number>=old.number&&candidate.updated>=old.updated&&candidate.next>=old.next);
  if(candidate.number==old.number) Require(Equal(candidate.raw,old.raw));
  foreach(var e in old.entries) Require(candidate.entries.ContainsKey(e.Key)&&candidate.entries[e.Key]==e.Value);
 }
 public static void ValidateAdvance(byte[] candidate,byte[] old,X509Certificate2 signer,DateTime now) { Advance(Parse(candidate,signer,now,true),Parse(old,signer,now,false)); }
 static Parsed[] Pair(byte[] rootCrl,byte[] issuerCrl,X509Certificate2 root,X509Certificate2 issuer,DateTime now) {
  Certificate(root,root,1,now); Certificate(issuer,root,0,now);
  Parsed a=Parse(rootCrl,root,now,true),b=Parse(issuerCrl,issuer,now,true);
  Require(!a.entries.ContainsKey(issuer.SerialNumber.TrimStart('0'))); return new[]{a,b};
 }
 static Result Metadata(Parsed[] pair,int added) { return new Result{RootNumber=pair[0].number,IssuerNumber=pair[1].number,RootNextUpdate=pair[0].next.ToString("o"),IssuerNextUpdate=pair[1].next.ToString("o"),Added=added}; }
 public static Result ValidatePair(byte[] rootCrl,byte[] issuerCrl,X509Certificate2 root,X509Certificate2 issuer,DateTime now) { return Metadata(Pair(rootCrl,issuerCrl,root,issuer,now),0); }
 public static Result ApplyToStore(byte[] rootCrl,byte[] issuerCrl,X509Certificate2 root,X509Certificate2 issuer,DateTime now,IntPtr store) {
  Parsed[] pair=Pair(rootCrl,issuerCrl,root,issuer,now); X509Certificate2[] signers={root,issuer}; bool[] identical={false,false};
  // Validate both candidates AND every authenticated predecessor before writes.
  IntPtr p=IntPtr.Zero;
  try {
   while((p=CertEnumCRLsInStore(store,p))!=IntPtr.Zero) {
    Context c=(Context)Marshal.PtrToStructure(p,typeof(Context)); Info v=(Info)Marshal.PtrToStructure(c.info,typeof(Info));
    for(int i=0;i<2;i++) {
     if(!Equal(Bytes(v.issuer),signers[i].SubjectName.RawData)||!CryptVerifyCertificateSignatureEx(IntPtr.Zero,1,3,p,2,signers[i].Handle,0,IntPtr.Zero)) continue;
     Require(c.length>0&&c.length<=1048576); byte[] old=new byte[c.length]; Marshal.Copy(c.encoded,old,0,old.Length);
     Advance(pair[i],Parse(old,signers[i],now,false)); if(Equal(pair[i].raw,old)) identical[i]=true;
    }
   }
   // CRYPT_E_NOT_FOUND means normal end-of-enumeration; other errors fail closed.
   Require(Marshal.GetLastWin32Error()==unchecked((int)0x80092004));
  } finally { if(p!=IntPtr.Zero) CertFreeCRLContext(p); }
  int added=0;
  for(int i=0;i<2;i++) if(!identical[i]) {
   p=CertCreateCRLContext(1,pair[i].raw,pair[i].raw.Length); Require(p!=IntPtr.Zero);
   try { if(!CertAddCRLContextToStore(store,p,3,IntPtr.Zero)) throw new Win32Exception(Marshal.GetLastWin32Error()); added++; }
   finally { CertFreeCRLContext(p); }
  }
  return Metadata(pair,added);
 }
}
public sealed class AuthWireSspi : IDisposable {
 [StructLayout(LayoutKind.Sequential)] struct Handle { public IntPtr lo,hi; }
 [StructLayout(LayoutKind.Sequential)] struct Buffer { public int length,type; public IntPtr data; }
 [StructLayout(LayoutKind.Sequential)] struct Desc { public int version,count; public IntPtr buffers; }
 [DllImport("secur32.dll",CharSet=CharSet.Unicode)] static extern int AcquireCredentialsHandle(string principal,string package,int use,IntPtr logon,IntPtr auth,IntPtr getkey,IntPtr arg,out Handle cred,out long expiry);
 [DllImport("secur32.dll",EntryPoint="InitializeSecurityContextW",CharSet=CharSet.Unicode)] static extern int First(ref Handle cred,IntPtr ctx,string name,uint flags,uint reserved,uint rep,IntPtr input,uint reserved2,out Handle result,ref Desc output,out uint attr,out long expiry);
 [DllImport("secur32.dll",EntryPoint="InitializeSecurityContextW",CharSet=CharSet.Unicode)] static extern int Next(ref Handle cred,ref Handle ctx,string name,uint flags,uint reserved,uint rep,ref Desc input,uint reserved2,out Handle result,ref Desc output,out uint attr,out long expiry);
 [DllImport("secur32.dll")] static extern int MakeSignature(ref Handle ctx,uint qop,ref Desc message,uint seq);
 [DllImport("secur32.dll")] static extern int VerifySignature(ref Handle ctx,ref Desc message,uint seq,out uint qop);
 [DllImport("secur32.dll")] static extern int FreeContextBuffer(IntPtr buffer);
 [DllImport("secur32.dll")] static extern int DeleteSecurityContext(ref Handle context);
 [DllImport("secur32.dll")] static extern int FreeCredentialsHandle(ref Handle credential);
 Handle cred,ctx; bool hasCred,hasCtx; uint send,receive; string spn;
 const uint Flags=2|4|8|256|65536; // mutual, replay, sequence, allocated token, integrity
 static void Check(int code) { if(code!=0) throw new InvalidOperationException("Kerberos SSPI error 0x"+code.ToString("X8")); }
 static Desc Describe(Buffer[] buffers) {
  int size=Marshal.SizeOf(typeof(Buffer)); IntPtr array=Marshal.AllocHGlobal(size*buffers.Length);
  for(int i=0;i<buffers.Length;i++) Marshal.StructureToPtr(buffers[i],IntPtr.Add(array,i*size),false);
  return new Desc{version=0,count=buffers.Length,buffers=array};
 }
 static Buffer Read(Desc desc,int i=0) { return (Buffer)Marshal.PtrToStructure(IntPtr.Add(desc.buffers,i*Marshal.SizeOf(typeof(Buffer))),typeof(Buffer)); }
 static IntPtr Copy(byte[] bytes) { IntPtr p=Marshal.AllocHGlobal(Math.Max(1,bytes.Length)); Marshal.Copy(bytes,0,p,bytes.Length); return p; }
 static byte[] Bytes(Buffer buffer) { byte[] b=new byte[buffer.length]; if(b.Length>0) Marshal.Copy(buffer.data,b,0,b.Length); return b; }
 public AuthWireSspi(string target) { spn=target; long expiry; Check(AcquireCredentialsHandle(null,"Kerberos",2,IntPtr.Zero,IntPtr.Zero,IntPtr.Zero,IntPtr.Zero,out cred,out expiry)); hasCred=true; }
 public byte[] Start() {
  Desc output=Describe(new[]{new Buffer{type=2}}); uint attr; long expiry;
  try { int code=First(ref cred,IntPtr.Zero,spn,Flags,0,16,IntPtr.Zero,0,out ctx,ref output,out attr,out expiry); hasCtx=code==0||code==0x90312; if(code!=0x90312) Check(code); return Bytes(Read(output)); }
  finally { Buffer b=Read(output); if(b.data!=IntPtr.Zero) FreeContextBuffer(b.data); Marshal.FreeHGlobal(output.buffers); }
 }
 public void Finish(byte[] token) {
  IntPtr data=Copy(token); Desc input=Describe(new[]{new Buffer{type=2,length=token.Length,data=data}}),output=Describe(new[]{new Buffer{type=2}}); uint attr; long expiry;
  try { Handle result; Check(Next(ref cred,ref ctx,spn,Flags,0,16,ref input,0,out result,ref output,out attr,out expiry)); ctx=result; if((attr&(2|4|8|65536))!=(2|4|8|65536)) throw new InvalidOperationException("Kerberos integrity/mutual authentication unavailable"); }
  finally { Buffer b=Read(output); if(b.data!=IntPtr.Zero) FreeContextBuffer(b.data); Marshal.FreeHGlobal(output.buffers); Marshal.FreeHGlobal(input.buffers); Marshal.FreeHGlobal(data); }
 }
 public byte[] Sign(byte[] message) {
  IntPtr data=Copy(message),token=Marshal.AllocHGlobal(4096); Desc desc=Describe(new[]{new Buffer{type=2,length=4096,data=token},new Buffer{type=1,length=message.Length,data=data}});
  try { Check(MakeSignature(ref ctx,0,ref desc,send++)); return Bytes(Read(desc)); }
  finally { Marshal.FreeHGlobal(desc.buffers); Marshal.FreeHGlobal(data); Marshal.FreeHGlobal(token); }
 }
 public void Verify(byte[] message,byte[] signature) {
  IntPtr data=Copy(message),token=Copy(signature); Desc desc=Describe(new[]{new Buffer{type=2,length=signature.Length,data=token},new Buffer{type=1,length=message.Length,data=data}}); uint qop;
  try { Check(VerifySignature(ref ctx,ref desc,receive++,out qop)); if(qop!=0) throw new InvalidOperationException("Unexpected Kerberos protection"); }
  finally { Marshal.FreeHGlobal(desc.buffers); Marshal.FreeHGlobal(data); Marshal.FreeHGlobal(token); }
 }
 public void Dispose() { if(hasCtx) DeleteSecurityContext(ref ctx); if(hasCred) FreeCredentialsHandle(ref cred); hasCtx=hasCred=false; }
}
'@
function Move-AuthWireExpiredPending([string]$Directory, [string]$Stage, [string]$ServerError, $Pending) {
    # A protected issuer response can identify an expired issuance whose local
    # installation never completed. Reusing that CSR can never recover it.
    # Preserve the request/key reference for diagnosis; never delete a key or
    # certificate here. The next normal, authenticated retry creates a new key.
    if($Stage -cne 'issue' -or $ServerError -cne 'DEVICE_CERTIFICATE_EXPIRED' -or !$Pending) { return $null }
    $path = Join-Path $Directory 'pending.json'
    if(!(Test-Path -LiteralPath $path)) { return $null }
    if((Get-Item -LiteralPath $path).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Pending request reparse point refused.' }
    $current = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
    if(!$Pending.container -or !$Pending.csr -or $current.container -cne $Pending.container -or $current.csr -cne $Pending.csr) { throw 'Pending request changed during recovery.' }
    $archiveDirectory = Join-Path $Directory 'expired-pending'
    if((Test-Path -LiteralPath $archiveDirectory) -and ((Get-Item -LiteralPath $archiveDirectory).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'Pending archive reparse point refused.' }
    $null = [IO.Directory]::CreateDirectory($archiveDirectory)
    $archiveName = [Guid]::NewGuid().ToString('N')+'.json'
    [IO.File]::Move($path,(Join-Path $archiveDirectory $archiveName))
    return $archiveName
}
function Get-AuthWireCrlTransportStatus([Exception]$Exception) {
    for($depth=0;$Exception -and $depth -lt 8;$depth++) {
        if($Exception -is [Net.WebException]) { return [string]$Exception.Status }
        $Exception=$Exception.InnerException
    }
    return 'None'
}
function New-AuthWireCrlRequest([string]$Url) {
    $request = [Net.HttpWebRequest]::Create($Url)
    $request.Method = 'GET'; $request.AllowAutoRedirect = $false; $request.Proxy = $null
    $request.Timeout = 15000; $request.ReadWriteTimeout = 15000
    $request.ServerCertificateValidationCallback = [Delegate]::CreateDelegate([Net.Security.RemoteCertificateValidationCallback], [AuthWireTls].GetMethod('Validate'))
    return $request
}
function Get-AuthWireCrlResponse([string]$Url) {
    $script:AuthWireCrlTransportAttempts=0
    $script:AuthWireCrlLastTransportStatus='None'
    for($attempt=1;$attempt -le 3;$attempt++) {
        $script:AuthWireCrlTransportAttempts=$attempt
        # A failed HttpWebRequest is never reused. No IP fallback, redirect,
        # trust bypass, enrollment retry or system DNS change is permitted.
        $request=New-AuthWireCrlRequest $Url
        try { return $request.GetResponse() } catch {
            $status=Get-AuthWireCrlTransportStatus $_.Exception
            $script:AuthWireCrlLastTransportStatus=$status
            if($attempt -ge 3 -or $status -notin @('NameResolutionFailure','ConnectFailure','Timeout','ReceiveFailure','ConnectionClosed','KeepAliveFailure')) { throw }
            Start-Sleep -Seconds 10
        }
    }
}
function Invoke-AuthWireCrlRefresh {
    $crlMutex = New-Object Threading.Mutex($false,'Global\AuthWire-CRL-Refresh')
    $locked = $false
    try {
        try { $locked = $crlMutex.WaitOne(0) } catch [Threading.AbandonedMutexException] { $locked = $true }
        if(!$locked) { return }
        if(!$NoJitter) { Start-Sleep -Seconds (Get-Random -Minimum 0 -Maximum 31) }
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        [Net.ServicePointManager]::CheckCertificateRevocationList = $true
        [AuthWireTls]::Pin = $config.tls_sha256
        $response = Get-AuthWireCrlResponse ($config.url+'/api/public/crls')
        try {
            if($response.StatusCode -ne [Net.HttpStatusCode]::OK -or $response.ContentLength -gt 3145728 -or $response.ContentType -notmatch '^application/json(?:;|$)') { throw 'CRL response refused.' }
            $stream = $response.GetResponseStream(); $memory = New-Object IO.MemoryStream
            try {
                $buffer = New-Object byte[] 8192
                while(($count = $stream.Read($buffer,0,$buffer.Length)) -gt 0) {
                    if($memory.Length + $count -gt 3145728) { throw 'CRL response exceeds limit.' }
                    $memory.Write($buffer,0,$count)
                }
                $bundle = (New-Object Text.UTF8Encoding($false,$true)).GetString($memory.ToArray()) | ConvertFrom-Json
            } finally { $stream.Dispose(); $memory.Dispose() }
        } finally { $response.Dispose() }
        if($bundle.version -ne 1 -or @($bundle.PSObject.Properties).Count -ne 3 -or $bundle.root_crl -isnot [string] -or $bundle.issuer_crl -isnot [string]) { throw 'CRL format refused.' }
        $rootBytes = [Convert]::FromBase64String($bundle.root_crl)
        $issuerBytes = [Convert]::FromBase64String($bundle.issuer_crl)
        $root = New-Object Security.Cryptography.X509Certificates.X509Certificate2((Join-Path $directory 'root-ca.pem'))
        $issuer = New-Object Security.Cryptography.X509Certificates.X509Certificate2((Join-Path $directory 'issuer-ca.pem'))
        $trust = New-Object Security.Cryptography.X509Certificates.X509Store('Root','LocalMachine')
        $store = New-Object Security.Cryptography.X509Certificates.X509Store('CA','LocalMachine')
        try {
            $trust.Open('ReadOnly')
            $anchors = @($trust.Certificates | Where-Object { $_.Thumbprint -eq $root.Thumbprint -and [Convert]::ToBase64String($_.RawData) -ceq [Convert]::ToBase64String($root.RawData) })
            if($anchors.Count -ne 1) { throw 'Existing AuthWire root trust required.' }
            $store.Open('ReadWrite')
            $result = [AuthWireCrl]::ApplyToStore($rootBytes,$issuerBytes,$root,$issuer,[DateTime]::UtcNow,$store.StoreHandle)
            $installedPath = Join-Path $directory 'installed.json'
            if(Test-Path -LiteralPath $installedPath) {
                $installed = Get-Content -LiteralPath $installedPath -Raw | ConvertFrom-Json
                if($installed.thumbprint -notmatch '^[A-Fa-f0-9]{40}$') { throw 'Installed identity refused.' }
                $leaf = Get-Item ('Cert:\LocalMachine\My\'+$installed.thumbprint) -ErrorAction Stop
                $chain = New-Object Security.Cryptography.X509Certificates.X509Chain($true)
                try {
                    $chain.ChainPolicy.RevocationMode = [Security.Cryptography.X509Certificates.X509RevocationMode]::Online
                    $chain.ChainPolicy.RevocationFlag = [Security.Cryptography.X509Certificates.X509RevocationFlag]::ExcludeRoot
                    $chain.ChainPolicy.VerificationFlags = [Security.Cryptography.X509Certificates.X509VerificationFlags]::NoFlag
                    $chain.ChainPolicy.UrlRetrievalTimeout = [TimeSpan]::FromSeconds(10)
                    $null = $chain.ChainPolicy.ExtraStore.Add($issuer)
                    $null = $chain.ChainPolicy.ApplicationPolicy.Add((New-Object Security.Cryptography.Oid('1.3.6.1.5.5.7.3.2')))
                    if(!$leaf.HasPrivateKey -or !$chain.Build($leaf) -or $chain.ChainElements.Count -ne 3 -or $chain.ChainElements[1].Certificate.Thumbprint -ne $issuer.Thumbprint -or $chain.ChainElements[2].Certificate.Thumbprint -ne $root.Thumbprint) { throw 'Current machine revocation check failed.' }
                } finally { $chain.Dispose() }
            }
            Write-AuthWireCrlState @{state='current';checked_at=[DateTimeOffset]::UtcNow.ToString('o');root_number=$result.RootNumber;issuer_number=$result.IssuerNumber;root_next_update=$result.RootNextUpdate;issuer_next_update=$result.IssuerNextUpdate;added=$result.Added}
        } finally { $trust.Close(); $store.Close(); $root.Dispose(); $issuer.Dispose() }
    } catch {
        # No enrollment backoff, credentials, CA password or diagnostic payload
        # is written to this independent refresh status.
        # Fixed enum/counter only: never expose exception messages, URLs,
        # response bodies, credentials or enrollment state.
        Write-AuthWireCrlState @{state='refresh_failed';checked_at=[DateTimeOffset]::UtcNow.ToString('o');error='CRL_REFRESH_FAILED';transport_status=(Get-AuthWireCrlTransportStatus $_.Exception);transport_attempts=[int]$script:AuthWireCrlTransportAttempts}
        throw 'AuthWire CRL refresh failed; existing revocation checks remain enforced.'
    } finally {
        if($locked) { $crlMutex.ReleaseMutex() }; $crlMutex.Dispose()
    }
}
function Write-AuthWireCrlState($data) {
    $target = Join-Path $directory 'crl-status.json'; $temporary = $target+'.tmp'
    foreach($path in @($target,$temporary)) {
        if((Test-Path -LiteralPath $path) -and ((Get-Item -LiteralPath $path).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'CRL state reparse point refused.' }
    }
    [IO.File]::WriteAllText($temporary,($data | ConvertTo-Json -Depth 4),(New-Object Text.UTF8Encoding($false)))
    [AuthWireTls]::AtomicReplace($temporary,$target)
}
if ($ValidateOnly) { return }
if ([Security.Principal.WindowsIdentity]::GetCurrent().User.Value -ne 'S-1-5-18') { throw 'AuthWire client must run as SYSTEM.' }
$directory = $PSScriptRoot
$config = Get-Content (Join-Path $directory 'config.json') -Raw | ConvertFrom-Json
$uri = [Uri]$config.url
if ($uri.Scheme -ne 'https' -or $uri.HostNameType -ne [UriHostNameType]::Dns -or $config.spn -cne ('HTTP/'+$uri.DnsSafeHost) -or $uri.AbsolutePath -ne '/' -or $uri.Query -or $uri.UserInfo) { throw 'Invalid AuthWire HTTPS/SPN configuration.' }
if($CrlOnly) { Invoke-AuthWireCrlRefresh; return }
$mutex = New-Object Threading.Mutex($false, 'Global\AuthWire-Certificate-Client')
if (!$mutex.WaitOne(0)) { $mutex.Dispose(); return }
$session = $null
$private = $null
$stage = 'bootstrap'
$serverError = $null
function Save-State($name, $data) {
    $target = Join-Path $directory $name
    $temporary = $target + '.tmp'
    [IO.File]::WriteAllText($temporary, ($data | ConvertTo-Json -Depth 6), (New-Object Text.UTF8Encoding($false)))
    [AuthWireTls]::AtomicReplace($temporary,$target)
}
function Post-Json($path, $data) {
    $request = [Net.HttpWebRequest]::Create($config.url+$path)
    $request.Method = 'POST'; $request.ContentType = 'application/json'; $request.AllowAutoRedirect = $false
    $request.Proxy = $null; $request.Timeout = 90000; $request.ReadWriteTimeout = 90000
    $request.ServerCertificateValidationCallback = [Delegate]::CreateDelegate([Net.Security.RemoteCertificateValidationCallback], [AuthWireTls].GetMethod('Validate'))
    $bytes = [Text.Encoding]::UTF8.GetBytes(($data | ConvertTo-Json -Compress -Depth 8))
    $request.ContentLength = $bytes.Length
    $stream = $request.GetRequestStream(); try { $stream.Write($bytes,0,$bytes.Length) } finally { $stream.Dispose() }
    try {
        $response = $request.GetResponse()
    } catch [Net.WebException] {
        $webResponse = $_.Exception.Response
        if($webResponse) {
            try {
                $reader = New-Object IO.StreamReader($webResponse.GetResponseStream())
                try {
                    $body = $reader.ReadToEnd() | ConvertFrom-Json
                    $errorCode = [string]$body.error
                    if($errorCode -and $errorCode.Length -le 64 -and $errorCode -notmatch '[^A-Z0-9_]') { $script:serverError = $errorCode }
                } finally { $reader.Dispose() }
            } catch {}
            finally { $webResponse.Dispose() }
        }
        throw
    }
    try { $reader = New-Object IO.StreamReader($response.GetResponseStream()); try { $reader.ReadToEnd() | ConvertFrom-Json } finally { $reader.Dispose() } }
    finally { $response.Dispose() }
}
function Protected-Post($path, $data) {
    $json = [Text.Encoding]::UTF8.GetBytes(($data | ConvertTo-Json -Compress -Depth 8))
    $signed = [Text.Encoding]::UTF8.GetBytes($path+"`n"+([Text.Encoding]::UTF8.GetString($json)))
    $response = Post-Json $path @{id=$sessionId; message=[Convert]::ToBase64String($json); mic=[Convert]::ToBase64String($session.Sign($signed))}
    $raw = [Convert]::FromBase64String($response.message)
    $session.Verify([Text.Encoding]::UTF8.GetBytes($path+"`n"+([Text.Encoding]::UTF8.GetString($raw))), [Convert]::FromBase64String($response.mic))
    [Text.Encoding]::UTF8.GetString($raw) | ConvertFrom-Json
}
function Key-Proof($payload) { [Convert]::ToBase64String($private.SignData([Convert]::FromBase64String($payload),[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1)) }
try {
    if (!$NoJitter) { Start-Sleep -Seconds (Get-Random -Minimum 0 -Maximum 121) }
    $retryFile = Join-Path $directory 'retry.json'
    $retry = if(Test-Path $retryFile) { Get-Content $retryFile -Raw | ConvertFrom-Json } else { $null }
    if($retry -and [DateTimeOffset]::UtcNow -lt [DateTimeOffset]::Parse($retry.next_attempt)) { return }
    $installedFile = Join-Path $directory 'installed.json'
    $installed = if(Test-Path $installedFile) { Get-Content $installedFile -Raw | ConvertFrom-Json } else { $null }
    # Remove only this client's verified predecessor after successful cutover.
    # A reboot/offline return performs cleanup before enrollment networking.
    if($installed) {
        foreach($old in @($installed.previous)) {
            if($old -and [DateTimeOffset]::UtcNow -ge [DateTimeOffset]::Parse($old.remove_at) -and $old.thumbprint -ne $installed.thumbprint) {
                Remove-Item ('Cert:\LocalMachine\My\'+$old.thumbprint) -ErrorAction SilentlyContinue
                if($old.container) {
                    try { $oldKey = [Security.Cryptography.CngKey]::Open($old.container,[Security.Cryptography.CngProvider]::MicrosoftSoftwareKeyStorageProvider,[Security.Cryptography.CngKeyOpenOptions]::MachineKey);$oldKey.Delete();$oldKey.Dispose() } catch {}
                }
            }
        }
    }
    $stage = 'session'
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    [AuthWireTls]::Pin = $config.tls_sha256
    $session = New-Object AuthWireSspi($config.spn)
    $answer = Post-Json '/api/device/session' @{token=[Convert]::ToBase64String($session.Start())}
    $session.Finish([Convert]::FromBase64String($answer.token)); $sessionId = $answer.id
    $pendingFile = Join-Path $directory 'pending.json'
    if($installed -and !(Test-Path $pendingFile)) {
        $existing = Get-Item ('Cert:\LocalMachine\My\'+$installed.thumbprint) -ErrorAction SilentlyContinue
        if($existing -and $existing.HasPrivateKey -and [DateTimeOffset]::UtcNow -lt [DateTimeOffset]::Parse($installed.renew_at)) {
            $stage = 'renewal_check'
            $private = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($existing)
            $serverState = Protected-Post '/api/device/receipt' @{serial=$installed.serial; proof=(Key-Proof $installed.receipt_payload)}
            Remove-Item $retryFile -ErrorAction SilentlyContinue
            if(!$serverState.renew_now) { return }
            $private.Dispose(); $private = $null
            # The server intentionally closes a Kerberos application session after
            # every receipt. Renewal must therefore establish a fresh protected
            # session before challenge/issue instead of reusing the closed one.
            $session.Dispose(); $session = New-Object AuthWireSspi($config.spn)
            $answer = Post-Json '/api/device/session' @{token=[Convert]::ToBase64String($session.Start())}
            $session.Finish([Convert]::FromBase64String($answer.token)); $sessionId = $answer.id
        }
    }
    if(!(Test-Path $pendingFile)) {
        $stage = 'csr'
        $container = 'AuthWire-'+[Guid]::NewGuid().ToString()
        $inf = @"
[Version]
Signature="`$Windows NT`$"
[NewRequest]
Subject="CN=AuthWire computer request"
KeyAlgorithm=RSA
KeyLength=2048
HashAlgorithm=sha256
Exportable=FALSE
MachineKeySet=TRUE
ProviderName="Microsoft Software Key Storage Provider"
KeyContainer="$container"
RequestType=PKCS10
SuppressDefaults=TRUE
"@
        $infFile = Join-Path $directory 'request.inf'; $csrFile = Join-Path $directory 'request.pem'
        [IO.File]::WriteAllText($infFile,$inf,[Text.Encoding]::ASCII)
        & "$env:SystemRoot\System32\certreq.exe" -new -machine -q -f $infFile $csrFile | Out-Null
        if($LASTEXITCODE -ne 0) { throw 'CSR generation failed.' }
        $csr = (Get-Content $csrFile -Raw).Replace('BEGIN NEW CERTIFICATE REQUEST','BEGIN CERTIFICATE REQUEST').Replace('END NEW CERTIFICATE REQUEST','END CERTIFICATE REQUEST')
        Save-State 'pending.json' @{container=$container;csr=$csr}
    }
    $stage = 'challenge'
    $pending = Get-Content $pendingFile -Raw | ConvertFrom-Json
    $key = [Security.Cryptography.CngKey]::Open($pending.container,[Security.Cryptography.CngProvider]::MicrosoftSoftwareKeyStorageProvider,[Security.Cryptography.CngKeyOpenOptions]::MachineKey)
    $private = New-Object Security.Cryptography.RSACng($key)
    $challenge = Protected-Post '/api/device/challenge' @{profile_id=$config.profile_id;csr=$pending.csr}
    $stage = 'issue'
    $issued = Protected-Post '/api/device/issue' @{challenge_id=$challenge.challenge_id;csr=$pending.csr;proof=(Key-Proof $challenge.payload)}
    $certFile = Join-Path $directory 'issued.pem'
    [IO.File]::WriteAllText($certFile,$issued.certificate,[Text.Encoding]::ASCII)
    $cert = New-Object Security.Cryptography.X509Certificates.X509Certificate2($certFile)
    $public = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPublicKey($cert)
    try {
        $actual = $public.ExportParameters($false); $expected = $private.ExportParameters($false)
        if([Convert]::ToBase64String($actual.Modulus) -cne [Convert]::ToBase64String($expected.Modulus) -or [Convert]::ToBase64String($actual.Exponent) -cne [Convert]::ToBase64String($expected.Exponent)) { throw 'Certificate key mismatch.' }
    } finally { $public.Dispose() }
    $stage = 'validate_certificate'
    $chain = New-Object Security.Cryptography.X509Certificates.X509Chain
    $chain.ChainPolicy.RevocationMode = [Security.Cryptography.X509Certificates.X509RevocationMode]::NoCheck
    $expectedIssuer = New-Object Security.Cryptography.X509Certificates.X509Certificate2((Join-Path $directory 'issuer-ca.pem'))
    $expectedRoot = New-Object Security.Cryptography.X509Certificates.X509Certificate2((Join-Path $directory 'root-ca.pem'))
    $null = $chain.ChainPolicy.ExtraStore.Add($expectedIssuer)
    $null = $chain.ChainPolicy.ApplicationPolicy.Add((New-Object Security.Cryptography.Oid('1.3.6.1.5.5.7.3.2')))
    try {
        if(!$chain.Build($cert) -or $chain.ChainElements.Count -ne 3 -or $chain.ChainElements[1].Certificate.Thumbprint -ne $expectedIssuer.Thumbprint -or $chain.ChainElements[2].Certificate.Thumbprint -ne $expectedRoot.Thumbprint) { throw 'Certificate chain mismatch.' }
    } finally { $chain.Dispose(); $expectedIssuer.Dispose(); $expectedRoot.Dispose() }
    $stage = 'install_certificate'
    $alreadyInstalled = Get-Item ('Cert:\LocalMachine\My\'+$cert.Thumbprint) -ErrorAction SilentlyContinue
    if(!$alreadyInstalled -or !$alreadyInstalled.HasPrivateKey) {
        & "$env:SystemRoot\System32\certreq.exe" -accept -machine -q $certFile | Out-Null
        if($LASTEXITCODE -ne 0) { throw 'Certificate installation failed.' }
    }
    $verified = Get-Item ('Cert:\LocalMachine\My\'+$cert.Thumbprint)
    if(!$verified.HasPrivateKey) { throw 'Installed private key is unavailable.' }
    $private.Dispose(); $private = [Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($verified)
    $stage = 'final_receipt'
    $receipt = Protected-Post '/api/device/receipt' @{serial=$issued.serial;proof=(Key-Proof $issued.receipt_payload)}
    if(!$receipt.installed) { throw 'Installation receipt rejected.' }
    $previous = @()
    if($installed -and $installed.thumbprint -ne $cert.Thumbprint) {
        $previous = @(@{thumbprint=$installed.thumbprint;container=$installed.container;remove_at=[DateTimeOffset]::UtcNow.AddHours(12).ToString('o')})
    }
    $stage = 'persist_installed'
    Save-State 'installed.json' @{serial=$issued.serial;thumbprint=$cert.Thumbprint;container=$pending.container;renew_at=$issued.renew_at;receipt_payload=$issued.receipt_payload;previous=$previous}
    Remove-Item $pendingFile,$retryFile -ErrorAction SilentlyContinue
    Save-State 'status.json' @{state='installed';last_success=[DateTimeOffset]::UtcNow.ToString('o');serial=$issued.serial}
} catch {
    $expiredPendingArchive = $null
    $pendingRecoveryFailed = $false
    try { $expiredPendingArchive = Move-AuthWireExpiredPending $directory $stage $serverError $pending }
    catch { $pendingRecoveryFailed = $true }
    # Persist no ticket, body, credential or raw exception. Task retries with
    # bounded backoff; jitter also distributes online/domain-startup spikes.
    $attempts = if($retry) { [Math]::Min(8,[int]$retry.attempts+1) } else { 1 }
    $minutes = [Math]::Min(720,[Math]::Pow(2,$attempts)*5)+(Get-Random -Minimum 0 -Maximum 16)
    $retryState = @{attempts=$attempts;next_attempt=[DateTimeOffset]::UtcNow.AddMinutes($minutes).ToString('o');stage=$stage}
    if($serverError) { $retryState['server_error'] = $serverError }
    if($expiredPendingArchive) { $retryState['expired_pending_archive'] = $expiredPendingArchive }
    Save-State 'retry.json' $retryState
    $status = @{state='retry_pending';error='ENROLLMENT_OR_INSTALL_FAILED';stage=$stage;checked_at=[DateTimeOffset]::UtcNow.ToString('o')}
    if($serverError) { $status['server_error'] = $serverError }
    if($expiredPendingArchive) { $status['expired_pending_archived'] = $true }
    if($pendingRecoveryFailed) { $status['recovery_error'] = 'EXPIRED_PENDING_ARCHIVE_FAILED' }
    Save-State 'status.json' $status
    Write-Error 'AuthWire enrollment/renewal failed. Check HTTPS DNS/trust, DC access, time, SPN/keytab and profile eligibility.' -ErrorAction Continue
    exit 1
} finally {
    if($private) { $private.Dispose() }
    if($session) { $session.Dispose() }
    $mutex.ReleaseMutex(); $mutex.Dispose()
}
