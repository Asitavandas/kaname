#Requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('Inspect','RunProbe')][string]$Mode='Inspect',
    [Parameter(Mandatory=$true)][ValidatePattern('^[A-Za-z0-9][A-Za-z0-9-]{0,14}$')][string]$ExpectedComputer,
    [Parameter(Mandatory=$true)][string]$ExpectedDomain,
    [Parameter(Mandatory=$true)][guid]$InstanceId,
    [ValidatePattern('^[A-Za-z][A-Za-z0-9-]{0,14}$')][string]$AccountName='aw-deploy',
    [Parameter(Mandatory=$true)][ValidatePattern('^S-1-5-21-(\d+-){3}\d+$')][string]$AccountSid,
    [Parameter(Mandatory=$true)][string]$BootstrapPath,
    [Parameter(Mandatory=$true)][string]$RightsToolPath,
    [Parameter(Mandatory=$true)][ValidatePattern('^[A-Fa-f0-9]{40}$')][string]$SignerThumbprint,
    [Parameter(Mandatory=$true)][string]$KeyAccessReceiptPath,
    [Parameter(Mandatory=$true)][ValidatePattern('^[A-Fa-f0-9]{40}$')][string]$PublisherThumbprint
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version 2

function Get-AuthWireProbeExecutableSource {
    param([string]$SignerThumbprint)
    if($SignerThumbprint -notmatch '^[A-Fa-f0-9]{40}$'){throw 'EXACT_SIGNER_THUMBPRINT_REQUIRED'}
    $source=@'
using System;
using System.Diagnostics;
using System.IO;
using System.Runtime.Serialization;
using System.Runtime.Serialization.Json;
using System.Security.Principal;
using System.ServiceProcess;
using System.Threading;

namespace AuthWire.Probe {
    [DataContract]
    public sealed class ServiceProof {
        [DataMember] public string ServiceName;
        [DataMember] public string Nonce;
        [DataMember] public string Computer;
        [DataMember] public string IdentityName;
        [DataMember] public string IdentitySid;
        [DataMember] public int ProcessId;
        [DataMember] public bool IsAuthenticated;
        [DataMember] public bool ServiceGroupPresent;
        [DataMember] public string RecordedUtc;
        [DataMember] public string SignerThumbprint;
        [DataMember] public string SignatureBase64;
        [DataMember] public bool SigningKeyPropertiesVerified;
    }
    public sealed class ShortLivedService : ServiceBase {
        private readonly string path, nonce;
        private Timer watchdog;
        private ShortLivedService(string name, string output, string binding) {
            ServiceName = name; path = output; nonce = binding;
            AutoLog = false; CanStop = true; CanShutdown = true;
        }
        protected override void OnStart(string[] args) {
            using (WindowsIdentity identity = WindowsIdentity.GetCurrent()) {
                bool serviceGroup = false;
                foreach (IdentityReference group in identity.Groups)
                    if (group.Value == "S-1-5-6") serviceGroup = true;
                ServiceProof proof = new ServiceProof();
                proof.ServiceName = ServiceName; proof.Nonce = nonce;
                proof.Computer = Environment.MachineName;
                proof.IdentityName = identity.Name; proof.IdentitySid = identity.User.Value;
                proof.ProcessId = Process.GetCurrentProcess().Id;
                proof.IsAuthenticated = identity.IsAuthenticated;
                proof.ServiceGroupPresent = serviceGroup;
                proof.RecordedUtc = DateTime.UtcNow.ToString("o");
                // Identity-bound challenge only: no package/file signing or private-key export.
                proof.SignerThumbprint = "__AUTHWIRE_SIGNER_THUMBPRINT__";
                using (var store = new System.Security.Cryptography.X509Certificates.X509Store(
                    System.Security.Cryptography.X509Certificates.StoreName.My,
                    System.Security.Cryptography.X509Certificates.StoreLocation.LocalMachine)) {
                    store.Open(System.Security.Cryptography.X509Certificates.OpenFlags.ReadOnly |
                        System.Security.Cryptography.X509Certificates.OpenFlags.OpenExistingOnly);
                    var certificates = store.Certificates.Find(
                        System.Security.Cryptography.X509Certificates.X509FindType.FindByThumbprint,
                        proof.SignerThumbprint, false);
                    if (certificates.Count != 1) throw new InvalidOperationException("EXACT_MACHINE_SIGNER_REQUIRED");
                    using (var certificate = certificates[0])
                    using (var rsa = System.Security.Cryptography.X509Certificates.RSACertificateExtensions.GetRSAPrivateKey(certificate)) {
                        var cng = rsa as System.Security.Cryptography.RSACng;
                        if (cng == null || !cng.Key.IsMachineKey || cng.Key.IsEphemeral ||
                            cng.Key.Provider.Provider != "Microsoft Software Key Storage Provider" ||
                            (int)cng.Key.ExportPolicy != 0 || (int)cng.Key.KeyUsage != 2 || rsa.KeySize != 3072)
                            throw new InvalidOperationException("BOUND_NONEXPORTABLE_MACHINE_SIGNING_KEY_REQUIRED");
                        string message = proof.ServiceName + "|" + proof.Nonce + "|" + proof.Computer + "|" +
                            proof.IdentitySid + "|" + proof.ProcessId.ToString(System.Globalization.CultureInfo.InvariantCulture);
                        proof.SignatureBase64 = Convert.ToBase64String(rsa.SignData(
                            System.Text.Encoding.UTF8.GetBytes(message),
                            System.Security.Cryptography.HashAlgorithmName.SHA256,
                            System.Security.Cryptography.RSASignaturePadding.Pkcs1));
                        proof.SigningKeyPropertiesVerified = true;
                    }
                }

                using (FileStream stream = new FileStream(path, FileMode.CreateNew, FileAccess.Write, FileShare.None))
                    new DataContractJsonSerializer(typeof(ServiceProof)).WriteObject(stream, proof);
            }
            watchdog = new Timer(delegate(object unused) { try { Stop(); } catch {} }, null, 45000, Timeout.Infinite);
        }
        protected override void OnStop() { if (watchdog != null) watchdog.Dispose(); }
        public static void Main(string[] args) {
            Guid parsed;
            if (args.Length != 3 || !args[0].StartsWith("AuthWireLogonProbe-", StringComparison.Ordinal) ||
                !Guid.TryParseExact(args[0].Substring(19), "N", out parsed) ||
                !Guid.TryParseExact(args[2], "N", out parsed) || !Path.IsPathRooted(args[1])) return;
            ServiceBase.Run(new ShortLivedService(args[0], args[1], args[2]));
        }
    }
}
'@
    return $source.Replace('__AUTHWIRE_SIGNER_THUMBPRINT__',$SignerThumbprint.ToUpperInvariant())
}
function Initialize-AuthWireProbeController {
    Add-Type -AssemblyName System.ServiceProcess
    if (-not ('AuthWire.Connector.OwnedProbeServiceV1' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;

namespace AuthWire.Connector {
    public sealed class OwnedProbeServiceV1 : IDisposable {
        private IntPtr manager, service;
        public string Name { get; private set; }
        [DllImport("advapi32.dll", CharSet=CharSet.Unicode, ExactSpelling=true, SetLastError=true)]
        private static extern IntPtr OpenSCManagerW(string machine, string database, uint access);
        [DllImport("advapi32.dll", CharSet=CharSet.Unicode, ExactSpelling=true, SetLastError=true)]
        private static extern IntPtr CreateServiceW(IntPtr manager, string name, string display, uint access,
            uint type, uint start, uint errorControl, string binary, string group, IntPtr tag,
            string dependencies, string account, string password);
        [DllImport("advapi32.dll", CharSet=CharSet.Unicode, ExactSpelling=true, SetLastError=true)]
        private static extern IntPtr OpenServiceW(IntPtr manager, string name, uint access);
        [DllImport("advapi32.dll", SetLastError=true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool DeleteService(IntPtr service);
        [DllImport("advapi32.dll")]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool CloseServiceHandle(IntPtr handle);
        private static void ValidateName(string name) {
            Guid parsed;
            if (name == null || !name.StartsWith("AuthWireLogonProbe-", StringComparison.Ordinal) ||
                !Guid.TryParseExact(name.Substring(19), "N", out parsed))
                throw new ArgumentException("Owned temporary probe name required.");
        }
        public static OwnedProbeServiceV1 Create(string name, string binary, string account) {
            ValidateName(name);
            if (String.IsNullOrEmpty(account)) throw new ArgumentException("Explicit service account required.");
            OwnedProbeServiceV1 result = new OwnedProbeServiceV1();
            result.Name = name;
            try {
                result.manager = OpenSCManagerW(null, null, 0x0003); // Local CONNECT | CREATE_SERVICE.
                if (result.manager == IntPtr.Zero) throw new Win32Exception(Marshal.GetLastWin32Error(), "OpenSCManager");
                // DELETE | QUERY_STATUS | START | STOP; demand-start own process.
                // NULL password is required for a managed service account. No credential is read or stored here.
                result.service = CreateServiceW(result.manager, name, name, 0x00010034,
                    0x10, 3, 1, binary, null, IntPtr.Zero, null, account, null);
                if (result.service == IntPtr.Zero) throw new Win32Exception(Marshal.GetLastWin32Error(), "CreateService");
                return result;
            } catch { result.Dispose(); throw; }
        }
        public void MarkForDeletion() {
            if (service == IntPtr.Zero) throw new InvalidOperationException("No owned service handle.");
            if (!DeleteService(service)) {
                int error = Marshal.GetLastWin32Error();
                if (error != 1072) throw new Win32Exception(error, "DeleteOwnedService");
            }
        }
        public static bool Exists(string name) {
            ValidateName(name);
            IntPtr scm = OpenSCManagerW(null, null, 0x0001);
            if (scm == IntPtr.Zero) throw new Win32Exception(Marshal.GetLastWin32Error(), "OpenSCManager");
            IntPtr found = IntPtr.Zero;
            try {
                found = OpenServiceW(scm, name, 0x0004);
                if (found != IntPtr.Zero) return true;
                int error = Marshal.GetLastWin32Error();
                if (error == 1060) return false;
                if (error == 1072) return true;
                throw new Win32Exception(error, "OpenService");
            } finally {
                if (found != IntPtr.Zero) CloseServiceHandle(found);
                CloseServiceHandle(scm);
            }
        }
        public void Dispose() {
            if (service != IntPtr.Zero) { CloseServiceHandle(service); service = IntPtr.Zero; }
            if (manager != IntPtr.Zero) { CloseServiceHandle(manager); manager = IntPtr.Zero; }
        }
    }
}
'@
    }
}
function New-AuthWireProbeDirectory {
    param([string]$Path,[string]$Sid,[switch]$Writable)
    if (Test-Path -LiteralPath $Path) { throw 'PROBE_PATH_ALREADY_EXISTS' }
    $security=New-Object System.Security.AccessControl.DirectorySecurity
    $access=$(if($Writable){'0x1301bf'}else{'0x1200a9'})
    $security.SetSecurityDescriptorSddlForm('D:P(A;OICI;FA;;;SY)(A;OICI;FA;;;BA)(A;OICI;' + $access + ';;;' + $Sid + ')')
    $null=[IO.Directory]::CreateDirectory($Path,$security)
}
function Write-AuthWireProbeEvidence {
    param([string]$Path,$Value)
    $Value | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $Path -Encoding UTF8
    $security=New-Object System.Security.AccessControl.FileSecurity
    $security.SetSecurityDescriptorSddlForm('D:P(A;;FA;;;SY)(A;;FA;;;BA)')
    Set-Acl -LiteralPath $Path -AclObject $security
}
function New-AuthWireSignedProbeExecutable {
    param([string]$Path,[string]$PublisherThumbprint,[string]$SignerThumbprint)
    Add-Type -AssemblyName Microsoft.CSharp
    $compiler=New-Object Microsoft.CSharp.CSharpCodeProvider
    try {
        $parameters=New-Object System.CodeDom.Compiler.CompilerParameters
        $parameters.GenerateExecutable=$true
        $parameters.GenerateInMemory=$false
        $parameters.OutputAssembly=$Path
        $parameters.IncludeDebugInformation=$false
        $parameters.CompilerOptions='/target:winexe'
        foreach($assembly in @('System.dll','System.Core.dll','System.ServiceProcess.dll','System.Runtime.Serialization.dll','System.Xml.dll')) {
            $null=$parameters.ReferencedAssemblies.Add($assembly)
        }
        $compiled=$compiler.CompileAssemblyFromSource($parameters,(Get-AuthWireProbeExecutableSource -SignerThumbprint $SignerThumbprint))
        if($compiled.Errors.HasErrors) { throw ('PROBE_COMPILE_FAILED:' + (($compiled.Errors | Where-Object {-not $_.IsWarning} | ForEach-Object {$_.ErrorNumber + ':' + $_.ErrorText}) -join ';')) }
    } finally { $compiler.Dispose() }
    $certificate=Get-Item -LiteralPath ('Cert:\CurrentUser\My\' + $PublisherThumbprint)
    if(-not $certificate.HasPrivateKey) { throw 'PROBE_SIGNING_KEY_REQUIRED' }
    $signed=Set-AuthenticodeSignature -FilePath $Path -Certificate $certificate -HashAlgorithm SHA256
    if($signed.Status.ToString() -ne 'Valid' -or $signed.SignerCertificate.Thumbprint -ine $PublisherThumbprint) {
        throw 'PROBE_EXECUTABLE_SIGNATURE_INVALID'
    }
    $verified=Get-AuthenticodeSignature -FilePath $Path
    if($verified.Status.ToString() -ne 'Valid' -or $verified.SignerCertificate.Thumbprint -ine $PublisherThumbprint) {
        throw 'PROBE_EXECUTABLE_SIGNATURE_INVALID'
    }
}
function Test-AuthWireRuntimeProof {
    param($Proof,[string]$Sid,[string]$ServiceName,[string]$Nonce,[int]$ProcessId)
    return ($null -ne $Proof -and $Proof.IdentitySid -ceq $Sid -and $Proof.ServiceName -ceq $ServiceName -and
        $Proof.Nonce -ceq $Nonce -and $Proof.Computer -ieq [Environment]::MachineName -and
        $Proof.ProcessId -eq $ProcessId -and $ProcessId -gt 0 -and
        $Proof.IsAuthenticated -is [bool] -and $Proof.IsAuthenticated -and
        $Proof.ServiceGroupPresent -is [bool] -and $Proof.ServiceGroupPresent)
}
function Invoke-AuthWireServiceProbeCore {
    param([string]$RuntimeAccount,[string]$ExpectedSid,[string]$PublisherThumbprint,[string]$SignerThumbprint)
    Initialize-AuthWireProbeController
    $sid=[System.Security.Principal.SecurityIdentifier]::new($ExpectedSid).Value
    $serviceName='AuthWireLogonProbe-' + [guid]::NewGuid().ToString('N')
    $nonce=[guid]::NewGuid().ToString('N')
    $root=Join-Path ([Environment]::GetFolderPath('CommonApplicationData')) ('AuthWire-ServiceProbe-' + [guid]::NewGuid().ToString('N'))
    $resultDirectory=Join-Path $root 'result'
    $proofFile=Join-Path $resultDirectory 'service-proof.json'
    $binary=Join-Path $root 'probe.exe'
    $summaryPath=Join-Path $root 'summary.json'
    $owned=$null; $controller=$null; $created=$false; $removed=$false
    $runtimeVerified=$false; $binaryRemoved=$false; $dataRemoved=$false
    $failure=$null; $nativeError=$null; $cleanupErrors=@(); $proof=$null; $stage='prepare_directory'
    try {
        New-AuthWireProbeDirectory -Path $root -Sid $sid
        New-AuthWireProbeDirectory -Path $resultDirectory -Sid $sid -Writable
        Write-AuthWireProbeEvidence -Path (Join-Path $root 'manifest.json') -Value ([ordered]@{
            Version=1;ServiceName=$serviceName;Nonce=$nonce;ExpectedSid=$sid;RuntimeAccount=$RuntimeAccount
            CreatedUtc=[datetime]::UtcNow.ToString('o');BinaryPath=$binary;PasswordSupplied=$false
        })
        $stage='compile_and_sign'
        New-AuthWireSignedProbeExecutable -Path $binary -PublisherThumbprint $PublisherThumbprint -SignerThumbprint $SignerThumbprint
        $stage='create_owned_service'
        $command='"{0}" "{1}" "{2}" "{3}"' -f $binary,$serviceName,$proofFile,$nonce
        $owned=[AuthWire.Connector.OwnedProbeServiceV1]::Create($serviceName,$command,$RuntimeAccount)
        $created=$true
        $controller=New-Object System.ServiceProcess.ServiceController -ArgumentList $serviceName
        $stage='start_service'
        $controller.Start()
        $controller.WaitForStatus([System.ServiceProcess.ServiceControllerStatus]::Running,[timespan]::FromSeconds(20))
        $stage='read_runtime_proof'
        $deadline=[datetime]::UtcNow.AddSeconds(5)
        while(-not (Test-Path -LiteralPath $proofFile -PathType Leaf) -and [datetime]::UtcNow -lt $deadline) {
            Start-Sleep -Milliseconds 100
        }
        $proof=Get-Content -LiteralPath $proofFile -Raw | ConvertFrom-Json
        $running=Get-CimInstance Win32_Service -Filter ("Name='" + $serviceName + "'") -Property Name,State,ProcessId,StartName,PathName
        if($null -eq $running -or $running.State -ne 'Running' -or $running.StartName -ine $RuntimeAccount -or
            -not (Test-AuthWireRuntimeProof -Proof $proof -Sid $sid -ServiceName $serviceName -Nonce $nonce -ProcessId ([int]$running.ProcessId))) {
            throw 'SERVICE_RUNTIME_IDENTITY_OR_BINDING_MISMATCH'
        }
        $signer=Get-Item -LiteralPath ('Cert:\LocalMachine\My\'+$SignerThumbprint)
        if(-not (Test-AuthWireSigningProof -Proof $proof -Certificate $signer)){throw 'SERVICE_SIGNATURE_INVALID'}
        $runtimeVerified=$true
        Write-AuthWireProbeEvidence -Path (Join-Path $root 'verified-proof.json') -Value $proof
        $stage='runtime_verified'
    } catch {
        $failure=$_.Exception.Message
        $inner=$_.Exception
        while($null -ne $inner) {
            if($inner -is [System.ComponentModel.Win32Exception]) { $nativeError=$inner.NativeErrorCode; break }
            $inner=$inner.InnerException
        }
    } finally {
        if($created) {
            try {
                $controller.Refresh()
                if($controller.Status -ne [System.ServiceProcess.ServiceControllerStatus]::Stopped) {
                    $controller.Stop()
                    $controller.WaitForStatus([System.ServiceProcess.ServiceControllerStatus]::Stopped,[timespan]::FromSeconds(10))
                }
            } catch { $cleanupErrors += ('stop:' + $_.Exception.Message) }
            try { $owned.MarkForDeletion() } catch { $cleanupErrors += ('delete:' + $_.Exception.Message) }
        }
        if($null -ne $controller) { $controller.Dispose() }
        if($null -ne $owned) { $owned.Dispose() }
        if($created) {
            try {
                $deadline=[datetime]::UtcNow.AddSeconds(5)
                do {
                    $removed=-not [AuthWire.Connector.OwnedProbeServiceV1]::Exists($serviceName)
                    if(-not $removed) { Start-Sleep -Milliseconds 100 }
                } while(-not $removed -and [datetime]::UtcNow -lt $deadline)
            } catch { $cleanupErrors += ('verify_delete:' + $_.Exception.Message) }
        }
        if(-not $created -or $removed) {
            try {
                # The SCM can report Stopped just before the process releases its image.
                $fileDeadline=[datetime]::UtcNow.AddSeconds(5)
                while(Test-Path -LiteralPath $binary) {
                    try { Remove-Item -LiteralPath $binary -Force } catch {
                        if([datetime]::UtcNow -ge $fileDeadline) { throw }
                        Start-Sleep -Milliseconds 100
                    }
                }
                $binaryRemoved=-not (Test-Path -LiteralPath $binary)
                if(Test-Path -LiteralPath $resultDirectory) { Remove-Item -LiteralPath $resultDirectory -Recurse -Force }
                $dataRemoved=-not (Test-Path -LiteralPath $resultDirectory)
                if(Test-Path -LiteralPath $root) {
                    $security=New-Object System.Security.AccessControl.DirectorySecurity
                    $security.SetSecurityDescriptorSddlForm('D:P(A;OICI;FA;;;SY)(A;OICI;FA;;;BA)')
                    Set-Acl -LiteralPath $root -AclObject $security
                }
            } catch { $cleanupErrors += ('artifact_cleanup:' + $_.Exception.Message) }
        }
    }
    $result=[pscustomobject]@{
        Event='WINDOWS_CONNECTOR_SERVICE_SIGNING_PROBE';ProbeVersion='1.0.0'
        Computer=[Environment]::MachineName;Account=$RuntimeAccount;ExpectedSid=$sid
        ServiceName=$serviceName;ServiceCreated=$created;ServiceLogonVerified=$runtimeVerified
        RuntimeSid=$(if($null -ne $proof){$proof.IdentitySid}else{$null})
        RuntimeProcessId=$(if($null -ne $proof){$proof.ProcessId}else{$null})
        TemporaryServiceRemoved=$removed;TemporaryBinaryRemoved=$binaryRemoved;TemporaryResultDirectoryRemoved=$dataRemoved
        EvidencePath=$summaryPath;Stage=$stage;Error=$failure;NativeErrorCode=$nativeError;CleanupErrors=$cleanupErrors
        ProbeVerified=($runtimeVerified -and $removed -and $binaryRemoved -and $dataRemoved -and $cleanupErrors.Count -eq 0)
        AdChanged=$false;GpoChanged=$false;LogonRightsChanged=$false;SecretsExported=$false
        GpoPersistenceVerified=$false;ConnectorInstalled=$false;CanApplyGpo=$false
        SignerThumbprint=$SignerThumbprint;SignatureVerified=$runtimeVerified;RuntimeSigningTested=$runtimeVerified
        ServiceKeyAccessVerified=($runtimeVerified -and $removed -and $binaryRemoved -and $dataRemoved -and $cleanupErrors.Count -eq 0)
        AuthenticodePackageSigningVerified=$false;CertificateChainValidationPerformed=$false;KeyAclChanged=$false
    }
    if(Test-Path -LiteralPath $root) { Write-AuthWireProbeEvidence -Path $summaryPath -Value $result }
    return $result
}

# Pure comparison only: never writes an ACL or drops ACEs, owners, groups or protection flags.
function Compare-AuthWireSigningKeyAcl {
    param([Parameter(Mandatory=$true)][string]$ExpectedSddl,[Parameter(Mandatory=$true)][string]$ActualSddl)
    $left=[Security.AccessControl.RawSecurityDescriptor]::new($ExpectedSddl)
    $right=[Security.AccessControl.RawSecurityDescriptor]::new($ActualSddl)
    $difference=[int]$left.ControlFlags -bxor [int]$right.ControlFlags
    $metadata=[int][Security.AccessControl.ControlFlags]::DiscretionaryAclAutoInherited
    $hasDacls=($null -ne $left.DiscretionaryAcl -and $null -ne $right.DiscretionaryAcl)
    $allowed=($difference -eq 0 -or $difference -eq $metadata)
    $left.SetFlags([Security.AccessControl.ControlFlags]([int]$left.ControlFlags -band (-bnot $metadata)))
    $right.SetFlags([Security.AccessControl.ControlFlags]([int]$right.ControlFlags -band (-bnot $metadata)))
    $same=($left.GetSddlForm([Security.AccessControl.AccessControlSections]::All) -ceq
        $right.GetSddlForm([Security.AccessControl.AccessControlSections]::All))
    $equivalent=($hasDacls -and $allowed -and $same)
    [pscustomobject]@{
        AclEquivalent=$equivalent
        AutoInheritedMetadataOnly=($equivalent -and $difference -eq $metadata)
        ChangedControlFlagsCode=$difference
        IgnoredMetadataFlag='SE_DACL_AUTO_INHERITED'
        AclWritten=$false
    }
}

function Test-AuthWireSigningProof {
    param($Proof,[Security.Cryptography.X509Certificates.X509Certificate2]$Certificate)
    try {
        if($null -eq $Proof -or $Proof.SigningKeyPropertiesVerified -isnot [bool] -or -not $Proof.SigningKeyPropertiesVerified -or
            $Proof.SignerThumbprint -ine $Certificate.Thumbprint -or
            $Proof.SignatureBase64 -isnot [string] -or $Proof.SignatureBase64.Length -gt 1024){return $false}
        $signature=[Convert]::FromBase64String($Proof.SignatureBase64)
        if($signature.Length -ne 384){return $false}
        $message=$Proof.ServiceName+'|'+$Proof.Nonce+'|'+$Proof.Computer+'|'+$Proof.IdentitySid+'|'+([int]$Proof.ProcessId).ToString([Globalization.CultureInfo]::InvariantCulture)
        $public=[Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPublicKey($Certificate)
        try{return $public.VerifyData([Text.Encoding]::UTF8.GetBytes($message),$signature,
            [Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1)}
        finally{if($null -ne $public){$public.Dispose()}}
    }catch{return $false}
}
function Get-AuthWireSigningKeyGate {
    param([string]$Thumbprint,[string]$ServiceSid,[string]$ReceiptPath)
    $receipt=Get-Content -LiteralPath $ReceiptPath -Raw|ConvertFrom-Json
    if($receipt.Event -ne 'WINDOWS_CONNECTOR_SIGNER_KEY_ACL_VERIFIED' -or $receipt.ComparisonVersion -ne '1.0.1' -or
        $receipt.Thumbprint -ine $Thumbprint -or $receipt.ServiceSid -ne $ServiceSid -or
        $receipt.ReadPermissionVerified -isnot [bool] -or -not $receipt.ReadPermissionVerified -or
        $receipt.ExistingRightsPreserved -isnot [bool] -or -not $receipt.ExistingRightsPreserved -or
        $receipt.KeyAclChangedByThisCheck -isnot [bool] -or $receipt.KeyAclChangedByThisCheck){throw 'VERIFIED_EXACT_KEY_ACCESS_RECEIPT_REQUIRED'}
    $certificate=Get-Item -LiteralPath ('Cert:\LocalMachine\My\'+$Thumbprint)
    if($certificate.NotBefore -gt (Get-Date) -or $certificate.NotAfter -le (Get-Date) -or -not $certificate.HasPrivateKey){throw 'CURRENT_MACHINE_SIGNER_REQUIRED'}
    $extensions=@($certificate.Extensions|Where-Object {$_.Oid.Value -eq '2.5.29.37'})
    if($extensions.Count -ne 1){throw 'CODE_SIGNING_ONLY_EKU_REQUIRED'}
    $eku=[Security.Cryptography.X509Certificates.X509EnhancedKeyUsageExtension]::new($extensions[0],$extensions[0].Critical)
    $oids=@($eku.EnhancedKeyUsages|ForEach-Object {$_.Value})
    if($oids.Count -ne 1 -or $oids[0] -ne '1.3.6.1.5.5.7.3.3'){throw 'CODE_SIGNING_ONLY_EKU_REQUIRED'}
    $rsa=[Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($certificate)
    try{
        if($rsa -isnot [Security.Cryptography.RSACng] -or -not $rsa.Key.IsMachineKey -or $rsa.Key.IsEphemeral -or
            $rsa.Key.Provider.Provider -ne 'Microsoft Software Key Storage Provider' -or
            [int]$rsa.Key.ExportPolicy -ne 0 -or [int]$rsa.Key.KeyUsage -ne 2 -or $rsa.KeySize -ne 3072){throw 'BOUND_NONEXPORTABLE_MACHINE_SIGNING_KEY_REQUIRED'}
        $name=$rsa.Key.UniqueName
        if([string]::IsNullOrWhiteSpace($name) -or [IO.Path]::GetFileName($name) -ne $name){throw 'KEY_BASENAME_REQUIRED'}
        $path=Join-Path (Join-Path $env:ProgramData 'Microsoft\Crypto\Keys') $name
        $item=Get-Item -LiteralPath $path -Force
        if($item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0){throw 'NORMAL_KEY_FILE_REQUIRED'}
        $acl=Get-Acl -LiteralPath $path
        $domainSid=[Security.Principal.SecurityIdentifier]::new($ServiceSid).AccountDomainSid.Value
        $expected='O:BAG:'+$domainSid+'-513D:P(A;;FA;;;SY)(A;;FA;;;BA)(A;;FR;;;'+$ServiceSid+')'
        if(-not (Compare-AuthWireSigningKeyAcl $expected $acl.Sddl).AclEquivalent -or
            -not (Compare-AuthWireSigningKeyAcl $expected $receipt.CurrentSddl).AclEquivalent){throw 'EXACT_SERVICE_READ_KEY_ACL_REQUIRED'}
        [pscustomobject]@{Path=$path;Sddl=$acl.Sddl;ReceiptSha256=(Get-FileHash -LiteralPath $ReceiptPath -Algorithm SHA256).Hash}
    }finally{if($null -ne $rsa){$rsa.Dispose()}}
}

if(-not [Environment]::Is64BitProcess) { throw 'POWERSHELL_64_BIT_REQUIRED' }
if([Environment]::MachineName -ine $ExpectedComputer) { throw 'LOCAL_COMPUTER_MISMATCH' }
foreach($path in @($BootstrapPath,$RightsToolPath)) {
    if(-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw 'SIGNED_PREPARATION_TOOLS_REQUIRED' }
    $signature=Get-AuthenticodeSignature -FilePath $path
    if($signature.Status.ToString() -ne 'Valid' -or $signature.SignerCertificate.Thumbprint -ine $PublisherThumbprint) {
        throw 'PREPARATION_TOOL_SIGNATURE_INVALID'
    }
}
$gate=& $RightsToolPath -Mode Inspect -ExpectedComputer $ExpectedComputer -ExpectedDomain $ExpectedDomain `
    -InstanceId $InstanceId -AccountName $AccountName -AccountSid $AccountSid `
    -BootstrapPath $BootstrapPath -PublisherThumbprint $PublisherThumbprint | ConvertFrom-Json
if($gate.Event -ne 'WINDOWS_CONNECTOR_SERVICE_RIGHT_PREPARATION' -or $gate.ToolVersion -ne '1.0.0' -or
    $gate.Mode -ne 'Inspect' -or $gate.Computer -ine $ExpectedComputer -or
    $gate.AccountSid -ne $AccountSid -or $gate.Account -ine ($AccountName + '$') -or
    $gate.Right -ne 'SeServiceLogonRight' -or -not $gate.DirectServiceRightAssigned -or
    @($gate.DenyAssignedSids).Count -ne 0 -or $gate.LocalPolicyChanged -or $gate.AdChanged -or $gate.GpoChanged) {
    throw 'OWNED_ACCOUNT_AND_SERVICE_RIGHT_REQUIRED'
}
Import-Module ActiveDirectory -ErrorAction Stop
$ready=@(Test-ADServiceAccount -Identity $AccountSid -ErrorAction Stop)
if($ready.Count -ne 1 -or $ready[0] -isnot [bool] -or -not $ready[0]) { throw 'LOCAL_GMSA_READINESS_REQUIRED' }
$runtimeAccount=[System.Security.Principal.SecurityIdentifier]::new($AccountSid).Translate([System.Security.Principal.NTAccount]).Value
if(-not $runtimeAccount.EndsWith('\' + $AccountName + '$',[StringComparison]::OrdinalIgnoreCase)) {
    throw 'RUNTIME_ACCOUNT_NAME_MISMATCH'
}
$keyGate=Get-AuthWireSigningKeyGate -Thumbprint $SignerThumbprint -ServiceSid $AccountSid -ReceiptPath $KeyAccessReceiptPath
if($Mode -eq 'Inspect') {
    [pscustomobject]@{
        Event='WINDOWS_CONNECTOR_SERVICE_SIGNING_PREFLIGHT';Computer=$ExpectedComputer;Account=$runtimeAccount
        AccountSid=$AccountSid;ReadyForProbe=$true;ServiceCreated=$false;ServiceLogonVerified=$false
        AdChanged=$false;GpoChanged=$false;LogonRightsChanged=$false;ConnectorInstalled=$false;CanApplyGpo=$false
    } | ConvertTo-Json
} else {
    $result=Invoke-AuthWireServiceProbeCore -RuntimeAccount $runtimeAccount -ExpectedSid $AccountSid -PublisherThumbprint $PublisherThumbprint -SignerThumbprint $SignerThumbprint
    $unchanged=(Compare-AuthWireSigningKeyAcl $keyGate.Sddl (Get-Acl -LiteralPath $keyGate.Path).Sddl).AclEquivalent
    $result|Add-Member NoteProperty KeyAclPreserved $unchanged
    $result|Add-Member NoteProperty KeyAccessReceiptSha256 $keyGate.ReceiptSha256
    $result.ServiceKeyAccessVerified=($result.ServiceKeyAccessVerified -and $unchanged)
    $result.ProbeVerified=($result.ProbeVerified -and $unchanged)
    if(Test-Path -LiteralPath (Split-Path -Parent $result.EvidencePath)){
        Write-AuthWireProbeEvidence -Path $result.EvidencePath -Value $result
    }
    $result|ConvertTo-Json -Depth 6
}
