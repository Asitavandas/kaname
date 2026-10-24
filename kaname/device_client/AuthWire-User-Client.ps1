# AuthWire user enrollment/renewal. Run in the signed-in user context.
# Sign with your enterprise Authenticode publisher before distribution.
param([switch]$ValidateOnly,[switch]$NoJitter)
$ErrorActionPreference = 'Stop'
Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Security.Cryptography.X509Certificates;
using System.Net.Security;
public static class AuthWireUserTls {
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
public sealed class AuthWireUserSspi : IDisposable {
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
 public AuthWireUserSspi(string target) { spn=target; long expiry; Check(AcquireCredentialsHandle(null,"Kerberos",2,IntPtr.Zero,IntPtr.Zero,IntPtr.Zero,IntPtr.Zero,out cred,out expiry)); hasCred=true; }
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

function Get-AuthWireUserContext {
    $identity=[Security.Principal.WindowsIdentity]::GetCurrent()
    try {
        $sid=$identity.User.Value
        if($sid -notmatch '^S-1-5-21-(?:[0-9]+-){3}[0-9]+$' -or $identity.IsSystem -or $identity.Name.EndsWith('$')) { throw 'A signed-in user context is required.' }
        return $sid
    } finally { $identity.Dispose() }
}
function Assert-AuthWireUserPath([string]$Path) {
    $item=[IO.Path]::GetFullPath($Path)
    while($item) {
        if((Test-Path -LiteralPath $item) -and ((Get-Item -LiteralPath $item -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'User enrollment reparse point refused.' }
        $parent=[IO.Directory]::GetParent($item)
        $item=if($parent){$parent.FullName}else{$null}
    }
}
function Get-AuthWireUserTarget([string]$Profile) {
    if($Profile -cnotmatch '^[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}$') { throw 'Invalid user profile identifier.' }
    return Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) ('AuthWire\UserEnrollment\'+$Profile)
}
function Initialize-AuthWireUserDirectory([string]$Directory,[string]$Profile,[string]$Sid) {
    $expected=Get-AuthWireUserTarget $Profile
    if([IO.Path]::GetFullPath($Directory).TrimEnd('\') -ine [IO.Path]::GetFullPath($expected).TrimEnd('\')) { throw 'User enrollment directory mismatch.' }
    Assert-AuthWireUserPath $Directory
    $null=[IO.Directory]::CreateDirectory($Directory)
    $acl=New-Object Security.AccessControl.DirectorySecurity
    $acl.SetAccessRuleProtection($true,$false)
    $acl.SetOwner((New-Object Security.Principal.SecurityIdentifier($Sid)))
    foreach($principal in @($Sid,'S-1-5-18','S-1-5-32-544')) {
        $acl.AddAccessRule((New-Object Security.AccessControl.FileSystemAccessRule((New-Object Security.Principal.SecurityIdentifier($principal)),'FullControl','ContainerInherit,ObjectInherit','None','Allow')))
    }
    Set-Acl -LiteralPath $Directory -AclObject $acl
}
function Get-AuthWireUserHash([byte[]]$Bytes) {
    $hash=[Security.Cryptography.SHA256]::Create()
    try { return [BitConverter]::ToString($hash.ComputeHash($Bytes)).Replace('-','').ToLowerInvariant() } finally { $hash.Dispose() }
}
function Assert-AuthWireUserPackage([string]$Directory) {
    Assert-AuthWireUserPath $Directory
    $publisher=$null
    foreach($name in @('Install-AuthWire-User.ps1','AuthWire-User-Client.ps1')) {
        $signature=Get-AuthenticodeSignature (Join-Path $Directory $name)
        if($signature.Status -ne 'Valid') { throw 'Valid enterprise Authenticode signatures are required.' }
        if(!$publisher){$publisher=$signature.SignerCertificate.Thumbprint}
        if($signature.SignerCertificate.Thumbprint -ne $publisher) { throw 'User scripts must have the same trusted publisher.' }
    }
    $expected=@'
__AUTHWIRE_USER_ASSET_HASHES__
'@ | ConvertFrom-Json
    $verified=@{}
    foreach($asset in $expected.PSObject.Properties) {
        if($asset.Name -notin @('config.json','root-ca.pem','issuer-ca.pem','https-trust.pem')) { throw 'Unexpected user package asset.' }
        $file=Join-Path $Directory $asset.Name;Assert-AuthWireUserPath $file
        $bytes=[IO.File]::ReadAllBytes($file)
        if((Get-AuthWireUserHash $bytes) -ine $asset.Value) { throw 'Signed user package asset was changed.' }
        $verified[$asset.Name]=$bytes
    }
    foreach($required in @('config.json','root-ca.pem','issuer-ca.pem')) { if(!$verified.ContainsKey($required)){throw 'Incomplete user package.'} }
    $config=[Text.Encoding]::UTF8.GetString($verified['config.json'])|ConvertFrom-Json
    $uri=[Uri]$config.url
    if($config.kind -cne 'user' -or $uri.Scheme -ne 'https' -or $uri.HostNameType -ne [UriHostNameType]::Dns -or $config.spn -cne ('HTTP/'+$uri.DnsSafeHost) -or $uri.AbsolutePath -ne '/' -or $uri.Query -or $uri.Fragment -or $uri.UserInfo -or $config.url.EndsWith('/') -or $config.tls_sha256 -cnotmatch '^[0-9a-f]{64}$') { throw 'Invalid user HTTPS/SPN configuration.' }
    $null=Get-AuthWireUserTarget $config.profile_id
    return @{config=$config;assets=$verified;publisher=$publisher}
}
# USER_COMMON_END
function Get-AuthWireUserPublicHash($Rsa) {
    $parameters=$Rsa.ExportParameters($false)
    return Get-AuthWireUserHash ([Text.Encoding]::ASCII.GetBytes(([Convert]::ToBase64String($parameters.Modulus)+':'+[Convert]::ToBase64String($parameters.Exponent))))
}
function Assert-AuthWireUserContainer([string]$Container,[string]$Profile) {
    if($Container -cnotmatch ('^AuthWire-User-'+[regex]::Escape($Profile)+'-[0-9a-f]{32}$')) { throw 'Unowned user key container refused.' }
}
function Read-AuthWireUserState([string]$Directory,[string]$Name,[string]$Sid,[string]$Profile) {
    $file=Join-Path $Directory $Name;Assert-AuthWireUserPath $file
    if(!(Test-Path -LiteralPath $file)){return $null}
    if((Get-Item -LiteralPath $file).Length -gt 131072){throw 'User state size exceeded.'}
    $value=Get-Content -LiteralPath $file -Raw|ConvertFrom-Json
    if($value.owner_sid -cne $Sid -or $value.profile_id -cne $Profile){throw 'User state ownership mismatch.'}
    return $value
}
function Save-AuthWireUserState([string]$Directory,[string]$Name,$Data,[string]$Sid,[string]$Profile) {
    if($Name -notin @('installed.json','pending.json','retry.json','status.json')){throw 'Invalid user state name.'}
    $Data['owner_sid']=$Sid;$Data['profile_id']=$Profile
    $target=Join-Path $Directory $Name;Assert-AuthWireUserPath $target
    $temporary=$target+'.'+[Guid]::NewGuid().ToString('N')+'.tmp'
    [IO.File]::WriteAllText($temporary,($Data|ConvertTo-Json -Depth 8),(New-Object Text.UTF8Encoding($false)))
    [AuthWireUserTls]::AtomicReplace($temporary,$target)
}
function Remove-AuthWireUserPredecessors([string]$Directory,$Installed,[string]$Profile) {
    $keep=@()
    foreach($old in @($Installed.previous)) {
        if(!$old){continue}
        Assert-AuthWireUserContainer $old.container $Profile
        if($old.thumbprint -notmatch '^[A-Fa-f0-9]{40}$' -or $old.key_hash -cnotmatch '^[0-9a-f]{64}$' -or $old.thumbprint -eq $Installed.thumbprint -or $old.container -ceq $Installed.container -or $old.key_hash -ceq $Installed.key_hash){throw 'Invalid predecessor reference.'}
        if([DateTimeOffset]::UtcNow -lt [DateTimeOffset]::Parse($old.remove_at)){$keep+=,$old;continue}
        $leaf=Get-Item ('Cert:\CurrentUser\My\'+$old.thumbprint) -ErrorAction SilentlyContinue
        if($leaf) {
            $public=[Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPublicKey($leaf)
            try { if(!$leaf.Subject.StartsWith('CN=AuthWire user ') -or (Get-AuthWireUserPublicHash $public) -cne $old.key_hash){throw 'Predecessor certificate binding mismatch.'} } finally {if($public){$public.Dispose()}}
        }
        $key=$null;$rsa=$null
        if([Security.Cryptography.CngKey]::Exists($old.container,[Security.Cryptography.CngProvider]::MicrosoftSoftwareKeyStorageProvider,[Security.Cryptography.CngKeyOpenOptions]::None)) {
            $key=[Security.Cryptography.CngKey]::Open($old.container,[Security.Cryptography.CngProvider]::MicrosoftSoftwareKeyStorageProvider,[Security.Cryptography.CngKeyOpenOptions]::None)
            $rsa=New-Object Security.Cryptography.RSACng($key)
            try { if($key.IsMachineKey -or (Get-AuthWireUserPublicHash $rsa) -cne $old.key_hash){throw 'Predecessor key binding mismatch.'} }
            catch {$rsa.Dispose();$key.Dispose();throw}
        }
        try {
            if($leaf){Remove-Item ('Cert:\CurrentUser\My\'+$old.thumbprint) -ErrorAction Stop}
            if($key){$key.Delete()}
        } finally {if($rsa){$rsa.Dispose()};if($key){$key.Dispose()}}
    }
    return ,$keep
}
function Post-AuthWireUserJson($Path,$Data) {
    $request=[Net.HttpWebRequest]::Create($config.url+$Path)
    $request.Method='POST';$request.ContentType='application/json';$request.AllowAutoRedirect=$false;$request.Proxy=$null;$request.Timeout=90000;$request.ReadWriteTimeout=90000
    $request.ServerCertificateValidationCallback=[Delegate]::CreateDelegate([Net.Security.RemoteCertificateValidationCallback],[AuthWireUserTls].GetMethod('Validate'))
    $bytes=[Text.Encoding]::UTF8.GetBytes(($Data|ConvertTo-Json -Depth 8 -Compress));$request.ContentLength=$bytes.Length
    $stream=$request.GetRequestStream();try{$stream.Write($bytes,0,$bytes.Length)}finally{$stream.Dispose()}
    try {$response=$request.GetResponse()}
    catch [Net.WebException] {
        $response=$_.Exception.Response
        if($response){try{$reader=New-Object IO.StreamReader($response.GetResponseStream());try{$answer=$reader.ReadToEnd()|ConvertFrom-Json;if([string]$answer.error -cmatch '^[A-Z0-9_]{1,64}$'){$script:awUserServerError=[string]$answer.error}}finally{$reader.Dispose()}}catch{}finally{$response.Dispose()}}
        throw
    }
    try{$reader=New-Object IO.StreamReader($response.GetResponseStream());try{return $reader.ReadToEnd()|ConvertFrom-Json}finally{$reader.Dispose()}}finally{$response.Dispose()}
}
function Protected-AuthWireUserPost($Path,$Data) {
    $raw=[Text.Encoding]::UTF8.GetBytes(($Data|ConvertTo-Json -Depth 8 -Compress));$prefix=[Text.Encoding]::UTF8.GetBytes($Path+"`n")
    $response=Post-AuthWireUserJson $Path @{id=$sessionId;message=[Convert]::ToBase64String($raw);mic=[Convert]::ToBase64String($session.Sign([byte[]]($prefix+$raw)))}
    $message=[Convert]::FromBase64String($response.message);$session.Verify([byte[]]($prefix+$message),[Convert]::FromBase64String($response.mic))
    return [Text.Encoding]::UTF8.GetString($message)|ConvertFrom-Json
}
function Get-AuthWireUserProof($Payload) {return [Convert]::ToBase64String($private.SignData([Convert]::FromBase64String($Payload),[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1))}
function Invoke-AuthWireUserCertreq([string[]]$Arguments) {
    $start=New-Object Diagnostics.ProcessStartInfo
    $start.FileName=Join-Path ([Environment]::GetFolderPath('System')) 'certreq.exe'
    foreach($argument in $Arguments){if($argument.Contains('"')){throw 'Invalid certreq argument.'}}
    $start.Arguments=($Arguments|ForEach-Object {'"'+$_+'"'}) -join ' '
    $start.UseShellExecute=$false;$start.CreateNoWindow=$true
    $start.RedirectStandardOutput=$true;$start.RedirectStandardError=$true
    $process=New-Object Diagnostics.Process
    $process.StartInfo=$start
    try {
        $null=$process.Start();$stdout=$process.StandardOutput.ReadToEndAsync();$stderr=$process.StandardError.ReadToEndAsync()
        if(!$process.WaitForExit(60000)){try{$process.Kill()}catch{};throw 'User certificate operation timed out.'}
        $process.WaitForExit()
        if($process.ExitCode -ne 0){throw 'User certificate operation failed.'}
    } finally {$process.Dispose()}
}
function Invoke-AuthWireUserEnrollment([string]$Directory,$Config,[switch]$NoJitter) {
    $sid=Get-AuthWireUserContext;$profile=[string]$Config.profile_id
    Initialize-AuthWireUserDirectory $Directory $profile $sid
    $lock=$null
    try{$lock=[IO.File]::Open((Join-Path $Directory 'run.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)}catch [IO.IOException]{return 0}
    $session=$null;$private=$null;$key=$null;$stage='bootstrap';$script:awUserServerError=$null;$pending=$null;$installed=$null;$retry=$null
    try {
        $retry=Read-AuthWireUserState $Directory 'retry.json' $sid $profile
        $installed=Read-AuthWireUserState $Directory 'installed.json' $sid $profile
        $pending=Read-AuthWireUserState $Directory 'pending.json' $sid $profile
        if($installed){Assert-AuthWireUserContainer $installed.container $profile;$installed.previous=Remove-AuthWireUserPredecessors $Directory $installed $profile}
        if($retry -and [DateTimeOffset]::UtcNow -lt [DateTimeOffset]::Parse($retry.next_attempt)){return 0}
        if($installed -and !$pending -and !$retry -and $installed.next_check -and [DateTimeOffset]::UtcNow -lt [DateTimeOffset]::Parse($installed.next_check)){return 0}
        if(!$NoJitter){Start-Sleep -Seconds (Get-Random -Minimum 0 -Maximum 31)}
        [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12;[AuthWireUserTls]::Pin=$Config.tls_sha256
        $stage='session';$session=New-Object AuthWireUserSspi($Config.spn)
        $answer=Post-AuthWireUserJson '/api/user/session' @{token=[Convert]::ToBase64String($session.Start())};$session.Finish([Convert]::FromBase64String($answer.token));$sessionId=$answer.id
        if($installed -and !$pending) {
            $existing=Get-Item ('Cert:\CurrentUser\My\'+$installed.thumbprint) -ErrorAction SilentlyContinue
            if($existing -and $existing.HasPrivateKey -and [DateTimeOffset]::UtcNow -lt [DateTimeOffset]::Parse($installed.renew_at)) {
                $stage='renewal_check';$key=[Security.Cryptography.CngKey]::Open($installed.container,[Security.Cryptography.CngProvider]::MicrosoftSoftwareKeyStorageProvider,[Security.Cryptography.CngKeyOpenOptions]::None);$private=New-Object Security.Cryptography.RSACng($key)
                if($key.IsMachineKey -or (Get-AuthWireUserPublicHash $private) -cne $installed.key_hash){throw 'Installed user key mismatch.'}
                $server=Protected-AuthWireUserPost '/api/user/receipt' @{serial=$installed.serial;proof=(Get-AuthWireUserProof $installed.receipt_payload)}
                if(!$server.installed){throw 'User receipt rejected.'}
                if(!$server.renew_now) {
                    $next=@{};foreach($p in $installed.PSObject.Properties){$next[$p.Name]=$p.Value};$next.next_check=[DateTimeOffset]::UtcNow.AddHours(6).ToString('o')
                    Save-AuthWireUserState $Directory 'installed.json' $next $sid $profile
                    Remove-Item (Join-Path $Directory 'retry.json') -ErrorAction SilentlyContinue
                    Save-AuthWireUserState $Directory 'status.json' @{state='installed';serial=$installed.serial;last_verified=[DateTimeOffset]::UtcNow.ToString('o')} $sid $profile
                    return 0
                }
                $private.Dispose();$private=$null;$key.Dispose();$key=$null
                $session.Dispose();$session=New-Object AuthWireUserSspi($Config.spn)
                $answer=Post-AuthWireUserJson '/api/user/session' @{token=[Convert]::ToBase64String($session.Start())};$session.Finish([Convert]::FromBase64String($answer.token));$sessionId=$answer.id
            }
        }
        if(!$pending){$pending=@{container=('AuthWire-User-'+$profile+'-'+[Guid]::NewGuid().ToString('N'));csr=$null;owner_sid=$sid;profile_id=$profile};Save-AuthWireUserState $Directory 'pending.json' $pending $sid $profile}
        Assert-AuthWireUserContainer $pending.container $profile
        if(!$pending.csr) {
            $stage='csr';$container=$pending.container
            $exists=[Security.Cryptography.CngKey]::Exists($container,[Security.Cryptography.CngProvider]::MicrosoftSoftwareKeyStorageProvider,[Security.Cryptography.CngKeyOpenOptions]::None)
            $keyOptions=if($exists){'UseExistingKeySet=TRUE'}else{'Exportable=FALSE'}
            $inf=@"
[Version]
Signature="`$Windows NT`$"
[NewRequest]
Subject="CN=AuthWire user request"
KeyAlgorithm=RSA
KeyLength=2048
HashAlgorithm=sha256
$keyOptions
MachineKeySet=FALSE
Silent=TRUE
ProviderName="Microsoft Software Key Storage Provider"
KeyContainer="$container"
RequestType=PKCS10
SuppressDefaults=TRUE
"@
            $infFile=Join-Path $Directory 'request.inf';$csrFile=Join-Path $Directory 'request.pem';Assert-AuthWireUserPath $infFile;Assert-AuthWireUserPath $csrFile
            [IO.File]::WriteAllText($infFile,$inf,[Text.Encoding]::ASCII)
            Invoke-AuthWireUserCertreq @('-new','-user','-q','-f',$infFile,$csrFile)
            $pending.csr=(Get-Content -LiteralPath $csrFile -Raw).Replace('BEGIN NEW CERTIFICATE REQUEST','BEGIN CERTIFICATE REQUEST').Replace('END NEW CERTIFICATE REQUEST','END CERTIFICATE REQUEST')
            Save-AuthWireUserState $Directory 'pending.json' @{container=$container;csr=$pending.csr} $sid $profile
        }
        $key=[Security.Cryptography.CngKey]::Open($pending.container,[Security.Cryptography.CngProvider]::MicrosoftSoftwareKeyStorageProvider,[Security.Cryptography.CngKeyOpenOptions]::None)
        if($key.IsMachineKey -or $key.ExportPolicy -ne [Security.Cryptography.CngExportPolicies]::None){throw 'User private-key scope/export policy rejected.'}
        $private=New-Object Security.Cryptography.RSACng($key)
        $stage='challenge';$challenge=Protected-AuthWireUserPost '/api/user/challenge' @{profile_id=$profile;csr=$pending.csr}
        $stage='issue';$issued=Protected-AuthWireUserPost '/api/user/issue' @{challenge_id=$challenge.challenge_id;csr=$pending.csr;proof=(Get-AuthWireUserProof $challenge.payload)}
        $stage='validate_certificate';$certFile=Join-Path $Directory 'issued.pem';Assert-AuthWireUserPath $certFile;[IO.File]::WriteAllText($certFile,$issued.certificate,[Text.Encoding]::ASCII);$cert=New-Object Security.Cryptography.X509Certificates.X509Certificate2($certFile)
        $public=[Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPublicKey($cert)
        try{if((Get-AuthWireUserPublicHash $public) -cne (Get-AuthWireUserPublicHash $private) -or !$cert.Subject.StartsWith('CN=AuthWire user ') -or $issued.kind -cne 'user' -or $cert.SerialNumber.TrimStart('0').ToLowerInvariant() -cne ([string]$issued.serial).TrimStart('0').ToLowerInvariant()){throw 'User certificate key/identity mismatch.'}}finally{if($public){$public.Dispose()}}
        $constraints=@($cert.Extensions|Where-Object {$_.Oid.Value -eq '2.5.29.19'});$usage=@($cert.Extensions|Where-Object {$_.Oid.Value -eq '2.5.29.15'})
        if($constraints.Count -ne 1 -or $constraints[0].CertificateAuthority -or $usage.Count -ne 1 -or !($usage[0].KeyUsages -band [Security.Cryptography.X509Certificates.X509KeyUsageFlags]::DigitalSignature)){throw 'Invalid user certificate constraints.'}
        $chain=New-Object Security.Cryptography.X509Certificates.X509Chain
        $issuer=New-Object Security.Cryptography.X509Certificates.X509Certificate2((Join-Path $Directory 'issuer-ca.pem'));$root=New-Object Security.Cryptography.X509Certificates.X509Certificate2((Join-Path $Directory 'root-ca.pem'))
        try {
            $chain.ChainPolicy.RevocationMode=[Security.Cryptography.X509Certificates.X509RevocationMode]::NoCheck
            $null=$chain.ChainPolicy.ExtraStore.Add($issuer);$null=$chain.ChainPolicy.ApplicationPolicy.Add((New-Object Security.Cryptography.Oid('1.3.6.1.5.5.7.3.2')))
            if(!$chain.Build($cert) -or $chain.ChainElements.Count -ne 3 -or $chain.ChainElements[1].Certificate.Thumbprint -ne $issuer.Thumbprint -or $chain.ChainElements[2].Certificate.Thumbprint -ne $root.Thumbprint){throw 'User certificate chain mismatch.'}
        } finally {$chain.Dispose();$issuer.Dispose();$root.Dispose()}
        $stage='install_certificate';$certFile=Join-Path $Directory 'issued.pem';Assert-AuthWireUserPath $certFile;[IO.File]::WriteAllText($certFile,$issued.certificate,[Text.Encoding]::ASCII)
        $found=Get-Item ('Cert:\CurrentUser\My\'+$cert.Thumbprint) -ErrorAction SilentlyContinue
        if(!$found -or !$found.HasPrivateKey){Invoke-AuthWireUserCertreq @('-accept','-user','-q',$certFile)}
        $verified=Get-Item ('Cert:\CurrentUser\My\'+$cert.Thumbprint)
        if(!$verified.HasPrivateKey){throw 'User installed private key unavailable.'}
        $stage='final_receipt';$receipt=Protected-AuthWireUserPost '/api/user/receipt' @{serial=$issued.serial;proof=(Get-AuthWireUserProof $issued.receipt_payload)}
        if(!$receipt.installed){throw 'User installation not confirmed.'}
        $previous=@();if($installed){$previous=@($installed.previous);if($installed.thumbprint -ne $cert.Thumbprint){$previous+=@{thumbprint=$installed.thumbprint;container=$installed.container;key_hash=$installed.key_hash;remove_at=[DateTimeOffset]::UtcNow.AddHours(24).ToString('o')}}}
        $stage='persist_installed';Save-AuthWireUserState $Directory 'installed.json' @{serial=$issued.serial;thumbprint=$cert.Thumbprint;container=$pending.container;key_hash=(Get-AuthWireUserPublicHash $private);renew_at=$issued.renew_at;receipt_payload=$issued.receipt_payload;previous=$previous;next_check=[DateTimeOffset]::UtcNow.AddHours(6).ToString('o')} $sid $profile
        Remove-Item (Join-Path $Directory 'pending.json'),(Join-Path $Directory 'retry.json') -ErrorAction SilentlyContinue
        Save-AuthWireUserState $Directory 'status.json' @{state='installed';serial=$issued.serial;last_success=[DateTimeOffset]::UtcNow.ToString('o')} $sid $profile
        return 0
    } catch {
        $archive=$null
        if($stage -ceq 'issue' -and $script:awUserServerError -ceq 'USER_CERTIFICATE_EXPIRED' -and $pending) {
            $file=Join-Path $Directory 'pending.json';Assert-AuthWireUserPath $file
            $folder=Join-Path $Directory 'expired-pending';Assert-AuthWireUserPath $folder;$null=[IO.Directory]::CreateDirectory($folder)
            $archive=[Guid]::NewGuid().ToString('N')+'.json';[IO.File]::Move($file,(Join-Path $folder $archive))
        }
        $attempts=if($retry){[Math]::Min(8,[int]$retry.attempts+1)}else{1}
        $minutes=[Math]::Min(720,[Math]::Pow(2,$attempts)*5)
        $failure=@{attempts=$attempts;next_attempt=[DateTimeOffset]::UtcNow.AddMinutes($minutes).ToString('o');stage=$stage}
        $status=@{state='retry_pending';error='USER_ENROLLMENT_OR_INSTALL_FAILED';stage=$stage;checked_at=[DateTimeOffset]::UtcNow.ToString('o')}
        if($script:awUserServerError){$failure.server_error=$script:awUserServerError;$status.server_error=$script:awUserServerError}
        if($archive){$status.expired_pending_archived=$true}
        Save-AuthWireUserState $Directory 'retry.json' $failure $sid $profile;Save-AuthWireUserState $Directory 'status.json' $status $sid $profile
        Write-Warning ('AuthWire user enrollment failed at '+$stage+'. Retry remains pending.')
        return 1
    } finally {if($private){$private.Dispose()};if($key){$key.Dispose()};if($session){$session.Dispose()};$lock.Dispose()}
}
if($ValidateOnly){return}
$package=Assert-AuthWireUserPackage $PSScriptRoot
exit (Invoke-AuthWireUserEnrollment $PSScriptRoot $package.config -NoJitter:$NoJitter)
