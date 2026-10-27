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

function Get-AuthWireNamedMachineKeyMetadata {
 param([Security.Cryptography.X509Certificates.X509Certificate2]$Certificate)
 Initialize-AuthWirePersistedKeyReader
 $binding=[AuthWire.Crypto.PersistedKeyReaderV1]::Read($Certificate)
 $report=[ordered]@{ProviderInfo=$binding;NamedKeyOpened=$false;OpenError=$null}
 $key=$null;$rsa=$null;$public=$null
 try{
  # This diagnostic deliberately refuses user storage, other providers and handles
  # flagged as ephemeral. It opens an existing named machine key; no fallback.
  if($binding.ProviderType -ne 0 -or $binding.ProviderName -cne 'Microsoft Software Key Storage Provider' -or
     -not ($binding.Flags -band 32) -or $binding.ParameterCount -ne 0 -or [string]::IsNullOrWhiteSpace($binding.ContainerName)){
   throw 'EXPECTED_NAMED_MACHINE_KSP_BINDING_REQUIRED'
  }
  $options=[Security.Cryptography.CngKeyOpenOptions]::MachineKey -bor [Security.Cryptography.CngKeyOpenOptions]::Silent
  $key=[Security.Cryptography.CngKey]::Open($binding.ContainerName,[Security.Cryptography.CngProvider]::MicrosoftSoftwareKeyStorageProvider,$options)
  $report.NamedKeyOpened=$true
  $report.Algorithm=$key.Algorithm.Algorithm
  $report.Provider=$key.Provider.Provider
  $report.IsMachineKey=$key.IsMachineKey
  $report.IsEphemeral=$key.IsEphemeral
  $report.ExportPolicy=$key.ExportPolicy.ToString();$report.ExportPolicyCode=[int]$key.ExportPolicy
  $report.KeyUsage=$key.KeyUsage.ToString();$report.KeyUsageCode=[int]$key.KeyUsage
  $report.KeyName=$key.KeyName;$report.UniqueName=$key.UniqueName
  if(-not $key.IsMachineKey -or $key.IsEphemeral -or $key.AlgorithmGroup.AlgorithmGroup -cne 'RSA'){throw 'NAMED_MACHINE_RSA_KEY_REQUIRED'}
  $rsa=[Security.Cryptography.RSACng]::new($key)
  $public=[Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPublicKey($Certificate)
  $actual=$rsa.ExportParameters($false);$expected=$public.ExportParameters($false)
  $report.KeySize=$rsa.KeySize
  $report.PublicKeyMatchesCertificate=([Convert]::ToBase64String($actual.Modulus) -ceq [Convert]::ToBase64String($expected.Modulus) -and [Convert]::ToBase64String($actual.Exponent) -ceq [Convert]::ToBase64String($expected.Exponent))
  if([string]::IsNullOrWhiteSpace($key.UniqueName) -or $key.UniqueName.Length -gt 256 -or [IO.Path]::GetFileName($key.UniqueName) -cne $key.UniqueName){throw 'KEY_BASENAME_REQUIRED'}
  $file=Join-Path (Join-Path ([Environment]::GetFolderPath('CommonApplicationData')) 'Microsoft\Crypto\Keys') $key.UniqueName
  $item=Get-Item -LiteralPath $file -Force
  if($item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)){throw 'NORMAL_PERSISTED_KEY_FILE_REQUIRED'}
  $report.KeyFile=$file;$report.KeySddl=(Get-Acl -LiteralPath $file).Sddl
 }catch{$report.OpenError=$_.Exception.Message}
 finally{if($public){$public.Dispose()};if($rsa){$rsa.Dispose()};if($key){$key.Dispose()}}
 return [pscustomobject]$report
}

$store=[Security.Cryptography.X509Certificates.X509Store]::new('My','LocalMachine')
try{
 $store.Open([Security.Cryptography.X509Certificates.OpenFlags]::ReadOnly)
 $certs=$store.Certificates.Find([Security.Cryptography.X509Certificates.X509FindType]::FindByThumbprint,$Thumbprint,$false)
 if($certs.Count -ne 1){throw 'EXACT_MACHINE_CERTIFICATE_REQUIRED'}
 $metadata=Get-AuthWireNamedMachineKeyMetadata $certs[0]
 [pscustomobject]@{Event='WINDOWS_SIGNER_PERSISTED_METADATA_READONLY';Version=1;Computer=[Environment]::MachineName;Thumbprint=$certs[0].Thumbprint;Subject=$certs[0].Subject;Metadata=$metadata;SigningPerformed=$false;PrivateMaterialExported=$false;KeyCreated=$false;KeyPropertyWritten=$false;KeyAclWritten=$false;CertificateAssociationWritten=$false;ServicesChanged=$false}|ConvertTo-Json -Depth 7
}finally{$store.Dispose()}
