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
$cert=$null;$other=$null;$copy=$null;$ephemeral=$null;$rsa=$null;$markerKey=$null;$fixtureRoot=$null;$fixturePublisher=$null;$signingPublic=$null;$signedArtifact=$null
try{
 $cert=New-SelfSignedCertificate -Type CodeSigningCert -Subject 'CN=Isolated named signer metadata fixture' -CertStoreLocation 'Cert:\LocalMachine\My' -Provider 'Microsoft Software Key Storage Provider' -KeyLength 3072 -HashAlgorithm SHA256 -KeyUsage DigitalSignature -KeyUsageProperty Sign -KeyExportPolicy NonExportable -NotAfter (Get-Date).AddDays(1)
 $metadata=Get-AuthWireNamedMachineKeyMetadata $cert
 Check ($metadata.NamedKeyOpened -and -not $metadata.OpenError -and $metadata.Native.PublicKeyMatchesCertificate) 'Named persisted key opens and public RSA matches certificate'
 Check (($metadata.Native.KeyType -band 32) -and $metadata.Native.NativeKeyNameMatchesBinding -and $metadata.Native.KeySize -eq 3072 -and $metadata.Native.ExportPolicyCode -eq 0 -and $metadata.Native.KeyUsageCode -eq 2) 'Machine, named, non-exportable, signing-only 3072-bit properties preserved'
 Check ($metadata.ProviderInfo.ProviderType -eq 0 -and ($metadata.ProviderInfo.Flags -band 32) -and $metadata.ProviderInfo.ProviderName -ceq 'Microsoft Software Key Storage Provider') 'Real CERT_KEY_PROV_INFO parsed and machine binding enforced'
 Check (Test-Path -LiteralPath $metadata.KeyFile) 'Unique name resolves an existing persisted key file'
 $acl=$metadata.KeySddl;$raw=[Convert]::ToBase64String($cert.RawData)
 $again=Get-AuthWireNamedMachineKeyMetadata $cert
 Check ($again.Native.KeyName -ceq $metadata.Native.KeyName -and $again.KeySddl -ceq $acl -and [Convert]::ToBase64String($cert.RawData) -ceq $raw) 'Repeated reads preserve certificate, named key and ACL'
 $copy=[Security.Cryptography.X509Certificates.X509Certificate2]::new($cert.RawData)
 $missing=$false;try{$null=Get-AuthWireNamedMachineKeyMetadata $copy}catch{$missing=$true}
 Check $missing 'Public certificate without persisted provider binding is not guessed or repaired'
 [IsolatedKeyBindingFixture]::CopyBinding($cert,$copy)
 $bound=Get-AuthWireNamedMachineKeyMetadata $copy
 Check ($bound.NamedKeyOpened -and $bound.Native.PublicKeyMatchesCertificate -and $bound.Native.UniqueName -ceq $metadata.Native.UniqueName) 'Explicit persisted binding reopens the same key from a public cert context'
 $ephemeral=[Security.Cryptography.RSACng]::new(3072)
 $handle=$ephemeral.Key.Handle;$added=$false;$handle.DangerousAddRef([ref]$added)
 try{
  [IsolatedKeyBindingFixture]::AttachCachedHandle($copy,$handle.DangerousGetHandle())
  $cachedError=$null;$cached=$null
  try{$cached=[Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($copy)}catch{$cachedError=$_.Exception.Message}finally{if($cached){$cached.Dispose()}}
  $conflicted=Get-AuthWireNamedMachineKeyMetadata $copy
  Check ($conflicted.NamedKeyOpened -and -not $conflicted.OpenError -and $conflicted.Native.PublicKeyMatchesCertificate -and $conflicted.Native.UniqueName -ceq $metadata.Native.UniqueName -and $conflicted.Native.MarkerUnchanged) 'Cached ephemeral handle cannot replace named persisted-key metadata'
  Write-Host ('Cached private-key acquisition diagnostic: '+$cachedError)
 }finally{[IsolatedKeyBindingFixture]::ClearCachedHandle($copy);if($added){$handle.DangerousRelease()}}
 $other=New-SelfSignedCertificate -Type CodeSigningCert -Subject 'CN=Isolated mismatched signer fixture' -CertStoreLocation 'Cert:\LocalMachine\My' -Provider 'Microsoft Software Key Storage Provider' -KeyLength 3072 -HashAlgorithm SHA256 -KeyUsage DigitalSignature -KeyUsageProperty Sign -KeyExportPolicy NonExportable -NotAfter (Get-Date).AddDays(1)
 [IsolatedKeyBindingFixture]::CopyBinding($other,$copy)
 $wrong=Get-AuthWireNamedMachineKeyMetadata $copy
 Check ($wrong.NamedKeyOpened -and -not $wrong.Native.PublicKeyMatchesCertificate) 'Different persisted key is reported as public-key mismatch'
 $after=Get-AuthWireNamedMachineKeyMetadata $cert
 Check ($after.KeySddl -ceq $acl -and $after.Native.UniqueName -ceq $metadata.Native.UniqueName -and $after.Native.ExportPolicyCode -eq 0 -and $after.Native.KeyUsageCode -eq 2) 'Negative fixtures do not change the original key or ACL'
 # Reproduce the customer's named-open/CLR-ephemeral contradiction on a key
 # owned solely by this disposable fixture. The product never writes this marker.
 $markerKey=[Security.Cryptography.CngKey]::Open($metadata.Native.KeyName,[Security.Cryptography.CngProvider]::MicrosoftSoftwareKeyStorageProvider,[Security.Cryptography.CngKeyOpenOptions]::MachineKey)
 $markerOptions=[Security.Cryptography.CngPropertyOptions]::CustomProperty -bor [Security.Cryptography.CngPropertyOptions]::Persist
 $markerKey.SetProperty([Security.Cryptography.CngProperty]::new('CLR IsEphemeral',[byte[]]@(1),$markerOptions))
 Check ($markerKey.IsEphemeral -and $null -eq $markerKey.KeyName -and $null -eq $markerKey.UniqueName) 'Real named key reproduces CLR marker true and managed names null'
 $marked=Get-AuthWireNamedMachineKeyMetadata $cert
 Check ($marked.NamedKeyOpened -and -not $marked.OpenError -and $marked.Native.ClrEphemeralMarkerHex -ceq '01' -and $marked.Native.MarkerUnchanged) 'Native read reports and preserves the contradictory marker'
 Check ($marked.Native.KeyName -ceq $metadata.Native.KeyName -and $marked.Native.UniqueName -ceq $metadata.Native.UniqueName -and $marked.Native.NativeKeyNameMatchesBinding -and $marked.Native.PublicKeyMatchesCertificate) 'Native names and public RSA binding remain independently verifiable'
 Check ($marked.Native.ExportPolicyCode -eq 0 -and $marked.Native.KeyUsageCode -eq 2 -and $marked.Native.KeySize -eq 3072 -and $marked.KeySddl -ceq $acl) 'No weakening of export, usage, size or ACL with CLR marker true'
 $fresh=& "$PSHOME\powershell.exe" -NoProfile -NonInteractive -File $path -Thumbprint $cert.Thumbprint
 Check ($LASTEXITCODE -eq 0) 'Exact diagnostic entry runs in a fresh native PowerShell 5.1 process'
 $result=($fresh -join "`n")|ConvertFrom-Json
 Check ($result.Metadata.Native.PublicKeyMatchesCertificate -and -not $result.PrivateMaterialExported -and -not $result.KeyCreated -and -not $result.KeyPropertyWritten -and -not $result.CertificateAssociationWritten -and -not $result.SigningPerformed) 'Entry result reports read-only metadata with no signing or private export'
 # Exercise the exact future delivery guard and Windows Authenticode with CLR marker 01.
 $delivery=Join-Path $PSScriptRoot '..\docs\checkpoints\2026-10-27-dc01-scope-worker-upgrade.ps1'
 $tokens=$null;$errors=$null;$deliveryAst=[Management.Automation.Language.Parser]::ParseFile($delivery,[ref]$tokens,[ref]$errors)
 Check ($errors.Count -eq 0) 'Exact candidate delivery parses with its native signer guard'
 foreach($f in $deliveryAst.EndBlock.Statements|Where-Object{$_ -is [Management.Automation.Language.FunctionDefinitionAst]}){. ([scriptblock]::Create($f.Extent.Text))}
 $snapshot=Get-AuthWireDeliverySignerSnapshot $cert $metadata.Native.KeyName $metadata.Native.UniqueName $acl
 Check ($snapshot.ClrMarkerHex -ceq '01' -and $snapshot.PublicKeyMatchesCertificate) 'Exact delivery guard accepts independent persisted binding despite CLR marker 01'
 $caught=$false;try{$null=Get-AuthWireDeliverySignerSnapshot $cert 'wrong-container' $metadata.Native.UniqueName $acl}catch{$caught=$true};Check $caught 'Delivery guard rejects another container'
 $caught=$false;try{$null=Get-AuthWireDeliverySignerSnapshot $cert $metadata.Native.KeyName 'wrong-file' $acl}catch{$caught=$true};Check $caught 'Delivery guard rejects another key file'
 $caught=$false;try{$null=Get-AuthWireDeliverySignerSnapshot $cert $metadata.Native.KeyName $metadata.Native.UniqueName 'O:SYG:SYD:P(A;;FA;;;SY)'}catch{$caught=$true};Check $caught 'Delivery guard rejects different key rights'
 $signingPublic=[Security.Cryptography.X509Certificates.X509Certificate2]::new($cert.RawData)
 $fixtureRoot=[Security.Cryptography.X509Certificates.X509Store]::new('Root','LocalMachine');$fixtureRoot.Open('ReadWrite');$fixtureRoot.Add($signingPublic)
 $fixturePublisher=[Security.Cryptography.X509Certificates.X509Store]::new('TrustedPublisher','LocalMachine');$fixturePublisher.Open('ReadWrite');$fixturePublisher.Add($signingPublic)
 $signedArtifact=Join-Path $env:TEMP ('AuthWire-MarkedSigner-'+[guid]::NewGuid().ToString('N')+'.ps1')
 [IO.File]::WriteAllText($signedArtifact,"# comment-only fixture; never executed`r`n",[Text.UTF8Encoding]::new($false))
 $signature=Set-AuthenticodeSignature -LiteralPath $signedArtifact -Certificate $cert -HashAlgorithm SHA256
 Check ($signature.Status.ToString() -ceq 'Valid' -and $signature.SignerCertificate.Thumbprint -ceq $cert.Thumbprint) 'Native Authenticode can sign with the named non-exportable key while CLR marker is 01'
 $afterSigning=Get-AuthWireDeliverySignerSnapshot $cert $metadata.Native.KeyName $metadata.Native.UniqueName $acl
 Check (($afterSigning|ConvertTo-Json -Compress) -ceq ($snapshot|ConvertTo-Json -Compress)) 'Actual signing preserves native binding, export policy, CLR marker and ACL'
 [pscustomobject]@{Event='SIGNER_METADATA_NATIVE_FIXTURE';Checks=$checks;ActualWindowsPowerShell=$PSVersionTable.PSVersion.ToString();CustomerKeyInspected=$false}|ConvertTo-Json
}finally{
 if($signedArtifact -and (Test-Path -LiteralPath $signedArtifact)){Remove-Item -LiteralPath $signedArtifact -Force}
 if($fixturePublisher){if($signingPublic){$fixturePublisher.Remove($signingPublic)};$fixturePublisher.Dispose()}
 if($fixtureRoot){if($signingPublic){$fixtureRoot.Remove($signingPublic)};$fixtureRoot.Dispose()}
 if($signingPublic){$signingPublic.Dispose()}
 if($ephemeral){$ephemeral.Dispose()};if($copy){$copy.Dispose()}
 if($markerKey){
  # This owned key was deliberately marked in the fixture. Delete it by its
  # already-open handle, then remove only the now-keyless certificate entry.
  $markerKey.Delete();$markerKey.Dispose()
  if($cert){Remove-Item -LiteralPath ('Cert:\LocalMachine\My\'+$cert.Thumbprint) -Force;$cert.Dispose();$cert=$null}
 }
 foreach($c in @($cert,$other)){if($c){Remove-Item -LiteralPath ('Cert:\LocalMachine\My\'+$c.Thumbprint) -DeleteKey -Force -ErrorAction SilentlyContinue;$c.Dispose()}}
}
