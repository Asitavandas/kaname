#Requires -Version 5.1
# Read persisted key-provider information without acquiring a cached certificate
# private-key handle. Never creates, signs, exports private data or writes policy.
[CmdletBinding()]
param([Parameter(Mandatory=$true)][ValidatePattern('\A[0-9A-Fa-f]{40}\z')][string]$Thumbprint)
$ErrorActionPreference='Stop';Set-StrictMode -Version 2

function Initialize-AuthWirePersistedKeyReader {
 if('AuthWire.Crypto.PersistedKeyReaderV1' -as [type]){return}
 Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Security.Cryptography.X509Certificates;
namespace AuthWire.Crypto {
 public sealed class KeyProviderInfoV1 {
  public string ContainerName, ProviderName;
  public uint ProviderType, Flags, ParameterCount, KeySpec;
 }
 public static class PersistedKeyReaderV1 {
  [StructLayout(LayoutKind.Sequential)]
  private struct Info {
   public IntPtr ContainerName, ProviderName;
   public uint ProviderType, Flags, ParameterCount;
   public IntPtr Parameters;
   public uint KeySpec;
  }
  [DllImport("crypt32.dll", SetLastError=true)]
  [return:MarshalAs(UnmanagedType.Bool)]
  private static extern bool CertGetCertificateContextProperty(IntPtr certificate, uint property, IntPtr output, ref uint size);
  public static KeyProviderInfoV1 Read(X509Certificate2 certificate) {
   if(certificate==null)throw new ArgumentNullException("certificate");
   uint size=0;
   if(!CertGetCertificateContextProperty(certificate.Handle,2,IntPtr.Zero,ref size))
    throw new Win32Exception(Marshal.GetLastWin32Error(),"CERT_KEY_PROV_INFO_READ_FAILED");
   if(size<Marshal.SizeOf(typeof(Info))||size>65536)throw new InvalidOperationException("KEY_PROV_INFO_SIZE_REJECTED");
   uint capacity=size;IntPtr buffer=Marshal.AllocHGlobal((int)size);
   try {
    if(!CertGetCertificateContextProperty(certificate.Handle,2,buffer,ref size))
     throw new Win32Exception(Marshal.GetLastWin32Error(),"CERT_KEY_PROV_INFO_READ_FAILED");
    if(size>capacity||size<Marshal.SizeOf(typeof(Info)))throw new InvalidOperationException("KEY_PROV_INFO_SIZE_REJECTED");
    var info=(Info)Marshal.PtrToStructure(buffer,typeof(Info));
    return new KeyProviderInfoV1 {ContainerName=ReadString(info.ContainerName,buffer,size),ProviderName=ReadString(info.ProviderName,buffer,size),
     ProviderType=info.ProviderType,Flags=info.Flags,ParameterCount=info.ParameterCount,KeySpec=info.KeySpec};
   } finally {Marshal.FreeHGlobal(buffer);GC.KeepAlive(certificate);}
  }
  private static string ReadString(IntPtr address,IntPtr buffer,uint size){
   long offset=address.ToInt64()-buffer.ToInt64();
   if(address==IntPtr.Zero||offset<0||offset>=size||(offset%2)!=0)throw new InvalidOperationException("KEY_PROV_INFO_STRING_REJECTED");
   int available=(int)((size-offset)/2);
   for(int i=0;i<available&&i<=1024;i++)if(Marshal.ReadInt16(address,i*2)==0)return Marshal.PtrToStringUni(address,i);
   throw new InvalidOperationException("KEY_PROV_INFO_STRING_REJECTED");
  }
 }
}
'@
}


function Initialize-AuthWireNativeKeyMetadata {
 if('AuthWire.Crypto.NativeKeyMetadataV2' -as [type]){return}
 Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Security.Cryptography.X509Certificates;
using System.Text;
namespace AuthWire.Crypto {
 public sealed class NativeMetadataV2 {
  public string KeyName,UniqueName,Algorithm,AlgorithmGroup,Provider,ClrEphemeralMarkerHex,ClrEphemeralMarkerAfterHex;
  public uint KeySize,KeyType,ExportPolicyCode,KeyUsageCode;
  public bool PublicKeyMatchesCertificate,NativeKeyNameMatchesBinding,MarkerUnchanged;
 }
 public static class NativeKeyMetadataV2 {
  [DllImport("ncrypt.dll",CharSet=CharSet.Unicode)] private static extern int NCryptOpenStorageProvider(out IntPtr provider,string name,uint flags);
  [DllImport("ncrypt.dll",CharSet=CharSet.Unicode)] private static extern int NCryptOpenKey(IntPtr provider,out IntPtr key,string name,uint spec,uint flags);
  [DllImport("ncrypt.dll",CharSet=CharSet.Unicode)] private static extern int NCryptGetProperty(IntPtr key,string name,byte[] output,uint capacity,out uint actual,uint flags);
  [DllImport("ncrypt.dll",CharSet=CharSet.Unicode)] private static extern int NCryptExportKey(IntPtr key,IntPtr exportKey,string format,IntPtr parameters,byte[] output,uint capacity,out uint actual,uint flags);
  [DllImport("ncrypt.dll")] private static extern int NCryptFreeObject(IntPtr handle);
  private static void Check(int code){if(code!=0)throw new InvalidOperationException("NCRYPT_READ_FAILED_"+unchecked((uint)code).ToString("X8"));}
  private static byte[] Property(IntPtr key,string name,uint flags,bool optional){
   uint size;int status=NCryptGetProperty(key,name,null,0,out size,flags);
   if(optional&&(unchecked((uint)status)==0x80090011||unchecked((uint)status)==0x80090029))return null;
   Check(status);if(size==0||size>8192)throw new InvalidOperationException("NCRYPT_PROPERTY_SIZE_REJECTED");
   byte[] data=new byte[size];uint used;Check(NCryptGetProperty(key,name,data,size,out used,flags));
   if(used!=size)throw new InvalidOperationException("NCRYPT_PROPERTY_SIZE_CHANGED");return data;
  }
  private static uint Number(IntPtr key,string name){byte[] data=Property(key,name,0,false);if(data.Length!=4)throw new InvalidOperationException("NCRYPT_DWORD_REJECTED");return BitConverter.ToUInt32(data,0);}
  private static string Text(IntPtr key,string name){byte[] data=Property(key,name,0,false);if(data.Length<2||data.Length%2!=0||data[data.Length-1]!=0||data[data.Length-2]!=0)throw new InvalidOperationException("NCRYPT_STRING_REJECTED");string text=new UnicodeEncoding(false,false,true).GetString(data,0,data.Length-2);if(text.IndexOf('\0')>=0||text.Length>1024)throw new InvalidOperationException("NCRYPT_STRING_REJECTED");return text;}
  private static string Marker(IntPtr key){byte[] data=Property(key,"CLR IsEphemeral",0x40000000,true);return data==null?null:BitConverter.ToString(data).Replace("-","");}
  // This method exports ONLY RSAPUBLICBLOB. It has no selectable blob type and
  // never returns a public or private blob to the PowerShell report.
  private static bool Matches(IntPtr key,X509Certificate2 cert,uint bits){
   if(cert.PublicKey.Oid.Value!="1.2.840.113549.1.1.1")return false;
   uint size;Check(NCryptExportKey(key,IntPtr.Zero,"RSAPUBLICBLOB",IntPtr.Zero,null,0,out size,64));
   if(size<24||size>8192)throw new InvalidOperationException("RSA_PUBLIC_BLOB_SIZE_REJECTED");
   byte[] blob=new byte[size];uint used;Check(NCryptExportKey(key,IntPtr.Zero,"RSAPUBLICBLOB",IntPtr.Zero,blob,size,out used,64));
   uint exponent=BitConverter.ToUInt32(blob,8),modulus=BitConverter.ToUInt32(blob,12);
   if(used!=size||BitConverter.ToUInt32(blob,0)!=0x31415352||BitConverter.ToUInt32(blob,4)!=bits||exponent<1||exponent>8||modulus<64||modulus>2048||bits!=modulus*8||size!=24+exponent+modulus||BitConverter.ToUInt32(blob,16)!=0||BitConverter.ToUInt32(blob,20)!=0)throw new InvalidOperationException("RSA_PUBLIC_BLOB_REJECTED");
   byte[] der=cert.PublicKey.EncodedKeyValue.RawData;if(der.Length>8192)throw new InvalidOperationException("RSA_PUBLIC_DER_LIMIT");
   int at=0;int end=Item(der,ref at,0x30);if(end!=der.Length)throw new InvalidOperationException("RSA_PUBLIC_DER_TRAILING");
   byte[] n=Integer(der,ref at),e=Integer(der,ref at);if(at!=end)throw new InvalidOperationException("RSA_PUBLIC_DER_TRAILING");
   return Equal(blob,24,(int)exponent,e)&&Equal(blob,24+(int)exponent,(int)modulus,n);
  }
  private static int Item(byte[] b,ref int at,int tag){
   if(at+2>b.Length||b[at++]!=tag)throw new InvalidOperationException("RSA_PUBLIC_DER_REJECTED");
   int count=b[at++],length=count;
   if(count>=128){count&=127;if(count<1||count>2||at+count>b.Length||b[at]==0)throw new InvalidOperationException("RSA_PUBLIC_DER_REJECTED");length=0;for(int i=0;i<count;i++)length=(length<<8)|b[at++];if(length<128)throw new InvalidOperationException("RSA_PUBLIC_DER_REJECTED");}
   if(length<1||length>b.Length-at)throw new InvalidOperationException("RSA_PUBLIC_DER_REJECTED");return at+length;
  }
  private static byte[] Integer(byte[] b,ref int at){int end=Item(b,ref at,2);int start=at;at=end;if((b[start]&128)!=0)throw new InvalidOperationException("RSA_PUBLIC_DER_NEGATIVE");if(b[start]==0){if(end-start==1||(b[start+1]&128)==0)throw new InvalidOperationException("RSA_PUBLIC_DER_PADDING");start++;}byte[] value=new byte[end-start];Buffer.BlockCopy(b,start,value,0,value.Length);return value;}
  private static bool Equal(byte[] b,int at,int length,byte[] expected){if(length!=expected.Length)return false;int diff=0;for(int i=0;i<length;i++)diff|=b[at+i]^expected[i];return diff==0;}
  public static NativeMetadataV2 Read(X509Certificate2 cert,string keyName,string provider){
   if(cert==null||provider!="Microsoft Software Key Storage Provider"||String.IsNullOrWhiteSpace(keyName)||keyName.Length>1024)throw new InvalidOperationException("EXACT_MACHINE_KSP_BINDING_REQUIRED");
   IntPtr storage=IntPtr.Zero,key=IntPtr.Zero;
   try{
    Check(NCryptOpenStorageProvider(out storage,provider,0));Check(NCryptOpenKey(storage,out key,keyName,0,96));
    var v=new NativeMetadataV2();v.Provider=Text(storage,"Name");v.KeyName=Text(key,"Name");v.UniqueName=Text(key,"Unique Name");v.Algorithm=Text(key,"Algorithm Name");v.AlgorithmGroup=Text(key,"Algorithm Group");v.KeySize=Number(key,"Length");v.KeyType=Number(key,"Key Type");v.ExportPolicyCode=Number(key,"Export Policy");v.KeyUsageCode=Number(key,"Key Usage");v.ClrEphemeralMarkerHex=Marker(key);
    v.NativeKeyNameMatchesBinding=String.Equals(v.KeyName,keyName,StringComparison.Ordinal);
    if(v.AlgorithmGroup!="RSA"||v.Algorithm!="RSA"||(v.KeyType&32)==0)throw new InvalidOperationException("NATIVE_MACHINE_RSA_REQUIRED");
    v.PublicKeyMatchesCertificate=Matches(key,cert,v.KeySize);v.ClrEphemeralMarkerAfterHex=Marker(key);v.MarkerUnchanged=v.ClrEphemeralMarkerHex==v.ClrEphemeralMarkerAfterHex;return v;
   }finally{if(key!=IntPtr.Zero)NCryptFreeObject(key);if(storage!=IntPtr.Zero)NCryptFreeObject(storage);GC.KeepAlive(cert);}
  }
 }
}
'@
}
function Get-AuthWireNamedMachineKeyMetadata {
 param([Security.Cryptography.X509Certificates.X509Certificate2]$Certificate)
 Initialize-AuthWirePersistedKeyReader;Initialize-AuthWireNativeKeyMetadata
 $binding=[AuthWire.Crypto.PersistedKeyReaderV1]::Read($Certificate)
 $report=[ordered]@{ProviderInfo=$binding;NamedKeyOpened=$false;OpenError=$null;Native=$null}
 try{
  if($binding.ProviderType -ne 0 -or $binding.ProviderName -cne 'Microsoft Software Key Storage Provider' -or -not ($binding.Flags -band 32) -or $binding.ParameterCount -ne 0 -or [string]::IsNullOrWhiteSpace($binding.ContainerName)){throw 'EXPECTED_NAMED_MACHINE_KSP_BINDING_REQUIRED'}
  $native=[AuthWire.Crypto.NativeKeyMetadataV2]::Read($Certificate,$binding.ContainerName,$binding.ProviderName)
  $report.NamedKeyOpened=$true;$report.Native=$native
  if([string]::IsNullOrWhiteSpace($native.UniqueName) -or $native.UniqueName.Length -gt 256 -or [IO.Path]::GetFileName($native.UniqueName) -cne $native.UniqueName){throw 'KEY_BASENAME_REQUIRED'}
  $file=Join-Path (Join-Path ([Environment]::GetFolderPath('CommonApplicationData')) 'Microsoft\Crypto\Keys') $native.UniqueName
  $item=Get-Item -LiteralPath $file -Force
  if($item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)){throw 'NORMAL_PERSISTED_KEY_FILE_REQUIRED'}
  $report.KeyFile=$file;$report.KeySddl=(Get-Acl -LiteralPath $file).Sddl
 }catch{$report.OpenError=$_.Exception.Message}
 return [pscustomobject]$report
}

$store=[Security.Cryptography.X509Certificates.X509Store]::new('My','LocalMachine')
try{
 $store.Open([Security.Cryptography.X509Certificates.OpenFlags]::ReadOnly)
 $certs=$store.Certificates.Find([Security.Cryptography.X509Certificates.X509FindType]::FindByThumbprint,$Thumbprint,$false)
 if($certs.Count -ne 1){throw 'EXACT_MACHINE_CERTIFICATE_REQUIRED'}
 $metadata=Get-AuthWireNamedMachineKeyMetadata $certs[0]
 [pscustomobject]@{Event='WINDOWS_SIGNER_PERSISTED_METADATA_READONLY';Version=2;Computer=[Environment]::MachineName;Thumbprint=$certs[0].Thumbprint;Subject=$certs[0].Subject;Metadata=$metadata;SigningPerformed=$false;PrivateMaterialExported=$false;KeyCreated=$false;KeyPropertyWritten=$false;KeyAclWritten=$false;CertificateAssociationWritten=$false;ServicesChanged=$false}|ConvertTo-Json -Depth 7
}finally{$store.Dispose()}
