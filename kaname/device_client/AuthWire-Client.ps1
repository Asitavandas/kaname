# AuthWire domain computer enrollment/renewal. Run as SYSTEM through GPO.
# Sign this file with the enterprise Authenticode publisher before deployment.
param([switch]$ValidateOnly, [switch]$NoJitter)
$ErrorActionPreference = 'Stop'
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Security.Cryptography.X509Certificates;
using System.Net.Security;
public static class AuthWireTls {
 public static string Pin;
 public static bool Validate(object sender, X509Certificate certificate, X509Chain chain, SslPolicyErrors errors) {
  if(errors != SslPolicyErrors.None || certificate == null) return false;
  using(var h=SHA256.Create()) return BitConverter.ToString(h.ComputeHash(certificate.GetRawCertData())).Replace("-","").ToLowerInvariant()==Pin;
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
if ($ValidateOnly) { return }
if ([Security.Principal.WindowsIdentity]::GetCurrent().User.Value -ne 'S-1-5-18') { throw 'AuthWire client must run as SYSTEM.' }
$directory = $PSScriptRoot
$config = Get-Content (Join-Path $directory 'config.json') -Raw | ConvertFrom-Json
$uri = [Uri]$config.url
if ($uri.Scheme -ne 'https' -or $uri.HostNameType -ne [UriHostNameType]::Dns -or $config.spn -cne ('HTTP/'+$uri.DnsSafeHost) -or $uri.AbsolutePath -ne '/' -or $uri.Query -or $uri.UserInfo) { throw 'Invalid AuthWire HTTPS/SPN configuration.' }
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
    if (Test-Path $target) { [IO.File]::Replace($temporary,$target,$null) } else { [IO.File]::Move($temporary,$target) }
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
    Save-State 'installed.json' @{serial=$issued.serial;thumbprint=$cert.Thumbprint;container=$pending.container;renew_at=$issued.renew_at;receipt_payload=$issued.receipt_payload;previous=$previous}
    Remove-Item $pendingFile,$retryFile -ErrorAction SilentlyContinue
    Save-State 'status.json' @{state='installed';last_success=[DateTimeOffset]::UtcNow.ToString('o');serial=$issued.serial}
} catch {
    # Persist no ticket, body, credential or raw exception. Task retries with
    # bounded backoff; jitter also distributes online/domain-startup spikes.
    $attempts = if($retry) { [Math]::Min(8,[int]$retry.attempts+1) } else { 1 }
    $minutes = [Math]::Min(720,[Math]::Pow(2,$attempts)*5)+(Get-Random -Minimum 0 -Maximum 16)
    Save-State 'retry.json' @{attempts=$attempts;next_attempt=[DateTimeOffset]::UtcNow.AddMinutes($minutes).ToString('o')}
    $status = @{state='retry_pending';error='ENROLLMENT_OR_INSTALL_FAILED';stage=$stage;checked_at=[DateTimeOffset]::UtcNow.ToString('o')}
    if($serverError) { $status.server_error = $serverError }
    Save-State 'status.json' $status
    Write-Error 'AuthWire enrollment/renewal failed. Check HTTPS DNS/trust, DC access, time, SPN/keytab and profile eligibility.' -ErrorAction Continue
    exit 1
} finally {
    if($private) { $private.Dispose() }
    if($session) { $session.Dispose() }
    $mutex.ReleaseMutex(); $mutex.Dispose()
}
