#Requires -Version 5.1
# A bounded, temporary SCM probe of the read-only verifier under an exact SID.
# The existing permanent Connector is never stopped or upgraded by this tool.
Set-StrictMode -Version 2

function Assert-AuthWireCandidateVerifierSource {
 $p=Join-Path $PSScriptRoot 'Test-AuthWireDeploymentCandidate.ps1'
 $item=Get-Item -LiteralPath $p -Force
 if($item.PSIsContainer -or ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -or $item.Length -gt 131072){throw 'VERIFIER_SOURCE_REJECTED'}
 $text=[IO.File]::ReadAllText($p);$body=($text -split '(?m)^# SIG # Begin signature block\r?$',2)[0]
 $bytes=[Text.UTF8Encoding]::new($false).GetBytes($body.Replace("`r`n","`n").TrimEnd([char[]]"`r`n")+"`n")
 $hash=[Security.Cryptography.SHA256]::Create()
 try{if(([BitConverter]::ToString($hash.ComputeHash($bytes))).Replace('-','') -cne '8260DC67D8BA7AF49447D20A02031A60DC0370E6C5F5733802CBFD2C1358CA09'){throw 'UNREVIEWED_VERIFIER_REJECTED'}}finally{$hash.Dispose()}
 $sig=Get-AuthenticodeSignature -LiteralPath $p
 if($sig.Status.ToString() -cne 'Valid' -or $sig.SignerCertificate.Thumbprint -cne $script:CandidateProbePublisher){throw 'SIGNED_VERIFIER_REQUIRED'}
}
function Assert-AuthWireCandidateProbePins([hashtable]$Pins,[string]$Sid,[string]$Publisher){
 $names=@('ConnectorId','PlanId','PlanVersion','PreviewHash','GpoId','ProtectedGpoId','ServiceSid','PublisherThumbprint','ApprovalSha256','ManifestSha256')
 if($null -eq $Pins -or $Pins.Count -ne $names.Count -or @($Pins.Keys|Where-Object{$_ -cnotin $names}).Count -or
    $Pins.ServiceSid -cne $Sid -or $Pins.PublisherThumbprint -cne $Publisher){throw 'EXACT_CANDIDATE_PINS_REQUIRED'}
 foreach($n in @('ConnectorId','PlanId','GpoId','ProtectedGpoId')){$g=[guid]::Empty;if($Pins[$n] -isnot [string] -or -not [guid]::TryParseExact($Pins[$n],'D',[ref]$g) -or $g -eq [guid]::Empty -or $g.ToString('D') -cne $Pins[$n]){throw 'EXACT_CANDIDATE_PINS_REQUIRED'}}
 foreach($n in @('PreviewHash','ApprovalSha256','ManifestSha256')){if($Pins[$n] -isnot [string] -or $Pins[$n] -cnotmatch '\A[0-9a-f]{64}\z'){throw 'EXACT_CANDIDATE_PINS_REQUIRED'}}
 if($Pins.PlanVersion -isnot [int] -or $Pins.PlanVersion -lt 1 -or $Pins.GpoId -ceq $Pins.ProtectedGpoId -or $Publisher -cnotmatch '\A[0-9A-F]{40}\z'){throw 'EXACT_CANDIDATE_PINS_REQUIRED'}
 $script:CandidateProbePublisher=$Publisher
}
function Assert-AuthWireCandidateProbeResult($Value,[hashtable]$Pins){
 $names=@('Event','Version','RuntimeSid','ConnectorId','PlanId','PlanVersion','GpoId','ApprovalSha256','ManifestSha256','CandidateVerified','SignatureVerified','NetworkContentVerified','PrivateKeyOpened','ArtifactExecuted','CanApplyGpo','GpoStateChecked','DirectoryFreshnessChecked','AdChanged','GpoChanged','EndpointChanged','KeyAclChanged','TrustStoreChanged','SecretsExported')
 if($null -eq $Value -or @($Value.PSObject.Properties).Count -ne $names.Count -or @($Value.PSObject.Properties.Name|Where-Object{$_ -cnotin $names}).Count -or $Value.Event -cne 'WINDOWS_CONNECTOR_CANDIDATE_READONLY_VERIFIED' -or $Value.Version -isnot [int] -or $Value.Version -ne 1 -or $Value.RuntimeSid -cne $Pins.ServiceSid){throw 'EXACT_CANDIDATE_RESULT_REQUIRED'}
 foreach($n in @('ConnectorId','PlanId','PlanVersion','GpoId','ApprovalSha256','ManifestSha256')){if($Value.$n -cne $Pins[$n]){throw 'EXACT_CANDIDATE_RESULT_REQUIRED'}}
 foreach($n in @('CandidateVerified','SignatureVerified','NetworkContentVerified')){if($Value.$n -isnot [bool] -or -not $Value.$n){throw 'EXACT_CANDIDATE_RESULT_REQUIRED'}}
 foreach($n in @('PrivateKeyOpened','ArtifactExecuted','CanApplyGpo','GpoStateChecked','DirectoryFreshnessChecked','AdChanged','GpoChanged','EndpointChanged','KeyAclChanged','TrustStoreChanged','SecretsExported')){if($Value.$n -isnot [bool] -or $Value.$n){throw 'EXACT_CANDIDATE_RESULT_REQUIRED'}}
}

function Get-AuthWireProbeExecutableSource {
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
        [DataMember] public string CandidateJson;
        [DataMember] public string CandidateError;
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
                try {
                    string helper = System.Text.Encoding.UTF8.GetString(Convert.FromBase64String("__HELPER_PATH__"));
                    using (var hash = System.Security.Cryptography.SHA256.Create()) {
                        string actual = BitConverter.ToString(hash.ComputeHash(File.ReadAllBytes(helper))).Replace("-", "");
                        if (actual != "__HELPER_HASH__") throw new InvalidOperationException("HELPER_CHANGED");
                    }
                    string options = System.Text.Encoding.UTF8.GetString(Convert.FromBase64String("__PIN_OPTIONS__"));
                    var pins = (System.Collections.IDictionary)new System.Web.Script.Serialization.JavaScriptSerializer().DeserializeObject(options);
                    var state = System.Management.Automation.Runspaces.InitialSessionState.CreateDefault();
                    state.ExecutionPolicy = Microsoft.PowerShell.ExecutionPolicy.AllSigned;
                    using (var runspace = System.Management.Automation.Runspaces.RunspaceFactory.CreateRunspace(state)) {
                        runspace.Open();
                        using (var shell = System.Management.Automation.PowerShell.Create()) {
                            shell.Runspace = runspace;
                            shell.AddCommand(helper).AddParameters(pins);
                            var output = shell.Invoke();
                            if (shell.HadErrors || output.Count != 1 || !(output[0].BaseObject is string))
                                throw new InvalidOperationException("CANDIDATE_REJECTED");
                            proof.CandidateJson = (string)output[0].BaseObject;
                        }
                    }
                } catch (Exception error) { proof.CandidateError = error.GetType().Name; }
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
    $options=[Convert]::ToBase64String([Text.UTF8Encoding]::new($false).GetBytes(($script:CandidateProbeOptions|ConvertTo-Json -Compress)))
    $helper=[Convert]::ToBase64String([Text.UTF8Encoding]::new($false).GetBytes($script:CandidateProbeHelper))
    return $source.Replace('__PIN_OPTIONS__',$options).Replace('__HELPER_PATH__',$helper).Replace('__HELPER_HASH__',(Get-FileHash -LiteralPath $script:CandidateProbeHelper -Algorithm SHA256).Hash)
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
    param([string]$Path,[string]$PublisherThumbprint)
    Add-Type -AssemblyName Microsoft.CSharp
    $compiler=New-Object Microsoft.CSharp.CSharpCodeProvider
    try {
        $parameters=New-Object System.CodeDom.Compiler.CompilerParameters
        $parameters.GenerateExecutable=$true
        $parameters.GenerateInMemory=$false
        $parameters.OutputAssembly=$Path
        $parameters.IncludeDebugInformation=$false
        $parameters.CompilerOptions='/target:winexe'
        foreach($assembly in @('System.dll','System.Core.dll','System.ServiceProcess.dll','System.Runtime.Serialization.dll','System.Xml.dll','System.Web.Extensions.dll',[Management.Automation.PowerShell].Assembly.Location)) {
            $null=$parameters.ReferencedAssemblies.Add($assembly)
        }
        $compiled=$compiler.CompileAssemblyFromSource($parameters,(Get-AuthWireProbeExecutableSource))
        if($compiled.Errors.HasErrors) { throw ('PROBE_COMPILE_FAILED:' + (($compiled.Errors | Where-Object {-not $_.IsWarning} | ForEach-Object {$_.ErrorNumber + ':' + $_.ErrorText}) -join ';')) }
    } finally { $compiler.Dispose() }
    $certificate=Get-Item -LiteralPath ('Cert:\LocalMachine\My\' + $PublisherThumbprint)
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
    param([string]$RuntimeAccount,[string]$ExpectedSid,[string]$PublisherThumbprint,[hashtable]$Pins,[string]$ServiceName)
    Initialize-AuthWireProbeController
    $sid=[System.Security.Principal.SecurityIdentifier]::new($ExpectedSid).Value
    if(-not $ServiceName){$ServiceName='AuthWireLogonProbe-' + [guid]::NewGuid().ToString('N')}
    if($ServiceName -cnotmatch '\AAuthWireLogonProbe-[0-9a-f]{32}\z'){throw 'OWNED_PROBE_NAME_REQUIRED'}
    $nonce=[guid]::NewGuid().ToString('N')
    $root=Join-Path ([Environment]::GetFolderPath('CommonApplicationData')) ('AuthWire-CandidateProbe-' + [guid]::NewGuid().ToString('N'))
    $resultDirectory=Join-Path $root 'result'
    $proofFile=Join-Path $resultDirectory 'service-proof.json'
    $binary=Join-Path $root 'probe.exe'
    $verifier=Join-Path $root 'Test-AuthWireDeploymentCandidate.ps1'
    $candidate=$null;$verifierRemoved=$false
    Assert-AuthWireCandidateProbePins $Pins $ExpectedSid $PublisherThumbprint
    Assert-AuthWireCandidateVerifierSource
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
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Test-AuthWireDeploymentCandidate.ps1') -Destination $verifier
        $script:CandidateProbeOptions=$Pins;$script:CandidateProbeHelper=$verifier
        $stage='compile_and_sign'
        New-AuthWireSignedProbeExecutable -Path $binary -PublisherThumbprint $PublisherThumbprint
        $stage='create_owned_service'
        $command='"{0}" "{1}" "{2}" "{3}"' -f $binary,$serviceName,$proofFile,$nonce
        $owned=[AuthWire.Connector.OwnedProbeServiceV1]::Create($serviceName,$command,$RuntimeAccount)
        $created=$true
        $controller=New-Object System.ServiceProcess.ServiceController -ArgumentList $serviceName
        $stage='start_service'
        $controller.Start()
        $controller.WaitForStatus([System.ServiceProcess.ServiceControllerStatus]::Running,[timespan]::FromSeconds(20))
        $stage='read_runtime_proof'
        $deadline=[datetime]::UtcNow.AddSeconds(10)
        while(-not (Test-Path -LiteralPath $proofFile -PathType Leaf) -and [datetime]::UtcNow -lt $deadline) {
            Start-Sleep -Milliseconds 100
        }
        $proof=Get-Content -LiteralPath $proofFile -Raw | ConvertFrom-Json
        $running=Get-CimInstance Win32_Service -Filter ("Name='" + $serviceName + "'") -Property Name,State,ProcessId,StartName,PathName
        if($null -eq $running -or $running.State -ne 'Running' -or $running.StartName -ine $RuntimeAccount -or
            -not (Test-AuthWireRuntimeProof -Proof $proof -Sid $sid -ServiceName $serviceName -Nonce $nonce -ProcessId ([int]$running.ProcessId))) {
            throw 'SERVICE_RUNTIME_IDENTITY_OR_BINDING_MISMATCH'
        }
        $runtimeVerified=$true
        if($proof.CandidateError -or $proof.CandidateJson -isnot [string] -or $proof.CandidateJson.Length -gt 8192){throw 'SERVICE_CANDIDATE_VERIFICATION_FAILED'}
        $candidate=$proof.CandidateJson|ConvertFrom-Json
        Assert-AuthWireCandidateProbeResult $candidate $Pins
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
                if(Test-Path -LiteralPath $verifier){Remove-Item -LiteralPath $verifier -Force}
                $verifierRemoved=-not (Test-Path -LiteralPath $verifier)
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
        Event='WINDOWS_CONNECTOR_CANDIDATE_SERVICE_PROBE';ProbeVersion='1.0.0'
        Computer=[Environment]::MachineName;Account=$RuntimeAccount;ExpectedSid=$sid
        ServiceName=$serviceName;ServiceCreated=$created;ServiceLogonVerified=$runtimeVerified
        RuntimeSid=$(if($null -ne $proof){$proof.IdentitySid}else{$null})
        RuntimeProcessId=$(if($null -ne $proof){$proof.ProcessId}else{$null})
        TemporaryServiceRemoved=$removed;TemporaryBinaryRemoved=$binaryRemoved;TemporaryResultDirectoryRemoved=$dataRemoved
        EvidencePath=$summaryPath;Stage=$stage;Error=$failure;NativeErrorCode=$nativeError;CleanupErrors=$cleanupErrors
        ProbeVerified=($runtimeVerified -and $null -ne $candidate -and $null -eq $failure -and $removed -and $binaryRemoved -and $verifierRemoved -and $dataRemoved -and $cleanupErrors.Count -eq 0)
        CandidateVerified=($null -ne $candidate -and $null -eq $failure);Candidate=$candidate;TemporaryVerifierRemoved=$verifierRemoved
        PrivateKeyOpenedByVerifier=$false;ArtifactExecuted=$false;GpoStateChecked=$false;DirectoryFreshnessChecked=$false;PermanentConnectorChanged=$false
        AdChanged=$false;GpoChanged=$false;LogonRightsChanged=$false;SecretsExported=$false
        GpoPersistenceVerified=$false;ConnectorInstalled=$false;CanApplyGpo=$false
    }
    if(Test-Path -LiteralPath $root) { Write-AuthWireProbeEvidence -Path $summaryPath -Value $result }
    return $result
}
