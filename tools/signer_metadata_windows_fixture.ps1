# Disposable Windows-only fixture. No customer certificate, account, AD or GPO.
$ErrorActionPreference='Stop';Set-StrictMode -Version 2
if($env:RUNNER_ENVIRONMENT -ne 'github-hosted'){throw 'Hosted fixture only'}
Import-Module (Join-Path $PSHOME 'Modules\Microsoft.PowerShell.Security\Microsoft.PowerShell.Security.psd1') -ErrorAction Stop
$path=Join-Path $PSScriptRoot '..\windows\connector\Get-AuthWireMachineSignerMetadata.ps1'
$t=$null;$e=$null;$ast=[Management.Automation.Language.Parser]::ParseFile($path,[ref]$t,[ref]$e)
if($e.Count){throw ($e.Message -join '; ')}
. ([scriptblock]::Create((@($ast.EndBlock.Statements|Where-Object{$_ -is [Management.Automation.Language.FunctionDefinitionAst]}|ForEach-Object{$_.Extent.Text}) -join "`n")))
Initialize-AuthWirePersistedKeyReader
# Only this isolated test setter writes native properties, on public cert copies.
# The product contains CertGetCertificateContextProperty only.
Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Security.Cryptography.X509Certificates;
public static class IsolatedKeyBindingFixture {
 [DllImport("crypt32.dll",SetLastError=true)]
 private static extern bool CertGetCertificateContextProperty(IntPtr c,uint p,IntPtr d,ref uint s);
 [DllImport("crypt32.dll",SetLastError=true)]
 private static extern bool CertSetCertificateContextProperty(IntPtr c,uint p,uint f,IntPtr d);
 public static void CopyBinding(X509Certificate2 source,X509Certificate2 target){
  uint size=0;if(!CertGetCertificateContextProperty(source.Handle,2,IntPtr.Zero,ref size))throw new Win32Exception();
  IntPtr buffer=Marshal.AllocHGlobal((int)size);
  try{if(!CertGetCertificateContextProperty(source.Handle,2,buffer,ref size)||!CertSetCertificateContextProperty(target.Handle,2,0,buffer))throw new Win32Exception();}
  finally{Marshal.FreeHGlobal(buffer);}
 }
 public static void AttachCachedHandle(X509Certificate2 target,IntPtr handle){
  IntPtr buffer=Marshal.AllocHGlobal(IntPtr.Size);
  try{Marshal.WriteIntPtr(buffer,handle);if(!CertSetCertificateContextProperty(target.Handle,78,1,buffer))throw new Win32Exception();}
  finally{Marshal.FreeHGlobal(buffer);}
 }
 public static void ClearCachedHandle(X509Certificate2 target){if(!CertSetCertificateContextProperty(target.Handle,78,1,IntPtr.Zero))throw new Win32Exception();}
}
'@
$script:checks=0
function Check([bool]$Value,[string]$Name){if(-not $Value){throw $Name};$script:checks++}
$cert=$null;$other=$null;$copy=$null;$ephemeral=$null;$rsa=$null
try{
 $cert=New-SelfSignedCertificate -Type CodeSigningCert -Subject 'CN=Isolated named signer metadata fixture' -CertStoreLocation 'Cert:\LocalMachine\My' -Provider 'Microsoft Software Key Storage Provider' -KeyLength 3072 -HashAlgorithm SHA256 -KeyUsage DigitalSignature -KeyUsageProperty Sign -KeyExportPolicy NonExportable -NotAfter (Get-Date).AddDays(1)
 $metadata=Get-AuthWireNamedMachineKeyMetadata $cert
 Check ($metadata.NamedKeyOpened -and -not $metadata.OpenError -and $metadata.PublicKeyMatchesCertificate) 'Named persisted key opens and public RSA matches certificate'
 Check ($metadata.IsMachineKey -and -not $metadata.IsEphemeral -and $metadata.KeySize -eq 3072 -and $metadata.ExportPolicyCode -eq 0 -and $metadata.KeyUsageCode -eq 2) 'Machine, named, non-exportable, signing-only 3072-bit properties preserved'
 Check ($metadata.ProviderInfo.ProviderType -eq 0 -and ($metadata.ProviderInfo.Flags -band 32) -and $metadata.ProviderInfo.ProviderName -ceq 'Microsoft Software Key Storage Provider') 'Real CERT_KEY_PROV_INFO parsed and machine binding enforced'
 Check (Test-Path -LiteralPath $metadata.KeyFile) 'Unique name resolves an existing persisted key file'
 $acl=$metadata.KeySddl;$raw=[Convert]::ToBase64String($cert.RawData)
 $again=Get-AuthWireNamedMachineKeyMetadata $cert
 Check ($again.KeyName -ceq $metadata.KeyName -and $again.KeySddl -ceq $acl -and [Convert]::ToBase64String($cert.RawData) -ceq $raw) 'Repeated reads preserve certificate, named key and ACL'
 $copy=[Security.Cryptography.X509Certificates.X509Certificate2]::new($cert.RawData)
 $missing=$false;try{$null=Get-AuthWireNamedMachineKeyMetadata $copy}catch{$missing=$true}
 Check $missing 'Public certificate without persisted provider binding is not guessed or repaired'
 [IsolatedKeyBindingFixture]::CopyBinding($cert,$copy)
 $bound=Get-AuthWireNamedMachineKeyMetadata $copy
 Check ($bound.NamedKeyOpened -and $bound.PublicKeyMatchesCertificate -and $bound.UniqueName -ceq $metadata.UniqueName) 'Explicit persisted binding reopens the same key from a public cert context'
 $ephemeral=[Security.Cryptography.RSACng]::new(3072)
 $handle=$ephemeral.Key.Handle;$added=$false;$handle.DangerousAddRef([ref]$added)
 try{
  [IsolatedKeyBindingFixture]::AttachCachedHandle($copy,$handle.DangerousGetHandle())
  $cachedError=$null;$cached=$null
  try{$cached=[Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($copy)}catch{$cachedError=$_.Exception.Message}finally{if($cached){$cached.Dispose()}}
  $conflicted=Get-AuthWireNamedMachineKeyMetadata $copy
  Check ($conflicted.NamedKeyOpened -and -not $conflicted.OpenError -and $conflicted.PublicKeyMatchesCertificate -and $conflicted.UniqueName -ceq $metadata.UniqueName -and -not $conflicted.IsEphemeral) 'Cached ephemeral handle cannot replace named persisted-key metadata'
  Write-Host ('Cached private-key acquisition diagnostic: '+$cachedError)
 }finally{[IsolatedKeyBindingFixture]::ClearCachedHandle($copy);if($added){$handle.DangerousRelease()}}
 $other=New-SelfSignedCertificate -Type CodeSigningCert -Subject 'CN=Isolated mismatched signer fixture' -CertStoreLocation 'Cert:\LocalMachine\My' -Provider 'Microsoft Software Key Storage Provider' -KeyLength 3072 -HashAlgorithm SHA256 -KeyUsage DigitalSignature -KeyUsageProperty Sign -KeyExportPolicy NonExportable -NotAfter (Get-Date).AddDays(1)
 [IsolatedKeyBindingFixture]::CopyBinding($other,$copy)
 $wrong=Get-AuthWireNamedMachineKeyMetadata $copy
 Check ($wrong.NamedKeyOpened -and -not $wrong.PublicKeyMatchesCertificate) 'Different persisted key is reported as public-key mismatch'
 $after=Get-AuthWireNamedMachineKeyMetadata $cert
 Check ($after.KeySddl -ceq $acl -and $after.UniqueName -ceq $metadata.UniqueName -and $after.ExportPolicyCode -eq 0 -and $after.KeyUsageCode -eq 2) 'Negative fixtures do not change the original key or ACL'
 $fresh=& "$PSHOME\powershell.exe" -NoProfile -NonInteractive -File $path -Thumbprint $cert.Thumbprint
 Check ($LASTEXITCODE -eq 0) 'Exact diagnostic entry runs in a fresh native PowerShell 5.1 process'
 $result=($fresh -join "`n")|ConvertFrom-Json
 Check ($result.Metadata.PublicKeyMatchesCertificate -and -not $result.PrivateMaterialExported -and -not $result.KeyCreated -and -not $result.KeyPropertyWritten -and -not $result.CertificateAssociationWritten -and -not $result.SigningPerformed) 'Entry result reports read-only metadata with no signing or private export'
 [pscustomobject]@{Event='SIGNER_METADATA_NATIVE_FIXTURE';Checks=$checks;ActualWindowsPowerShell=$PSVersionTable.PSVersion.ToString();CustomerKeyInspected=$false}|ConvertTo-Json
}finally{
 if($ephemeral){$ephemeral.Dispose()};if($copy){$copy.Dispose()}
 foreach($c in @($cert,$other)){if($c){Remove-Item -LiteralPath ('Cert:\LocalMachine\My\'+$c.Thumbprint) -DeleteKey -Force -ErrorAction SilentlyContinue;$c.Dispose()}}
}
