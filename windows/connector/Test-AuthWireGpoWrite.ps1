#Requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('Inspect','RunProbe')][string]$Mode='Inspect',
    [Parameter(Mandatory=$true)][string]$ExpectedComputer,
    [Parameter(Mandatory=$true)][string]$ExpectedDomain,
    [Parameter(Mandatory=$true)][guid]$InstanceId,
    [string]$AccountName='aw-deploy',
    [Parameter(Mandatory=$true)][string]$AccountSid,
    [Parameter(Mandatory=$true)][string]$ScopeGroupSid,
    [Parameter(Mandatory=$true)][string]$ScopeGroupName,
    [Parameter(Mandatory=$true)][guid]$ExpectedGpoId,
    [Parameter(Mandatory=$true)][guid]$ProtectedGpoId,
    [Parameter(Mandatory=$true)][string]$PreparationReceiptPath,
    [Parameter(Mandatory=$true)][string]$BootstrapPath,
    [Parameter(Mandatory=$true)][string]$RightsToolPath,
    [Parameter(Mandatory=$true)][string]$LogonToolPath,
    [Parameter(Mandatory=$true)][string]$DeploymentToolPath,
    [Parameter(Mandatory=$true)][ValidatePattern('^[A-Fa-f0-9]{40}$')][string]$PublisherThumbprint
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version 2

function Import-AuthWireSignedProbeHelpers {
    param([string]$Path,[string[]]$Names,[string]$PublisherThumbprint)
    $signature=Get-AuthenticodeSignature -FilePath $Path
    if($signature.Status.ToString() -ne 'Valid' -or $signature.SignerCertificate.Thumbprint -ine $PublisherThumbprint) { throw 'PROBE_HELPER_SIGNATURE_INVALID' }
    $tokens=$null;$errors=$null
    $ast=[Management.Automation.Language.Parser]::ParseFile($Path,[ref]$tokens,[ref]$errors)
    if($errors.Count) { throw 'PROBE_HELPER_PARSE_FAILED' }
    $definitions=@($ast.EndBlock.Statements | Where-Object {$_ -is [Management.Automation.Language.FunctionDefinitionAst] -and $_.Name -in $Names})
    if($definitions.Count -ne $Names.Count -or @($definitions.Name|Select-Object -Unique).Count -ne $Names.Count) { throw 'PROBE_HELPER_FUNCTION_SET_INVALID' }
    return (($definitions|ForEach-Object{$_.Extent.Text}) -join [Environment]::NewLine)
}
function Get-AuthWireGpoBusinessFingerprint {
    param([guid]$Id,[string]$Domain,[string]$Server)
    $gpo=Get-GPO -Guid $Id -Domain $Domain -Server $Server -ErrorAction Stop
    $doc=Get-AuthWireGpoDocument $Id $Domain $Server
    foreach($node in @($doc.SelectNodes("//*[local-name()='ReadTime' or local-name()='ModificationTime']"))) { $null=$node.ParentNode.RemoveChild($node) }
    $path=Get-AuthWireGpoRoot $Id $Domain $Server
    $files=@(Get-ChildItem -LiteralPath $path -Recurse -Force -ErrorAction Stop | ForEach-Object {
        if(($_.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) {throw 'GPO_SYSVOL_REPARSE_POINT_REJECTED'}
        if(-not $_.PSIsContainer) {
            [pscustomobject]@{Path=$_.FullName.Substring($path.Length).ToLowerInvariant();Hash=(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash}
        }
    } | Sort-Object Path)
    $permissions=@(Get-AuthWireGpoPermissionRows $Id $Domain $Server|Sort-Object Sid,Permission)
    $acl=Get-Acl -LiteralPath $path -ErrorAction Stop
    $value=([string]$gpo.Description)+$doc.OuterXml+($files|ConvertTo-Json -Compress)+($permissions|ConvertTo-Json -Compress)+$acl.GetSecurityDescriptorSddlForm([Security.AccessControl.AccessControlSections]::All)
    $sha=[Security.Cryptography.SHA256]::Create()
    try{return ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($value)))).Replace('-','').ToLowerInvariant()}
    finally{$sha.Dispose()}
}
function Test-AuthWireGpoOperationProof {
    param($Proof,$Configuration)
    if($null -eq $Proof) {return $false}
    foreach($name in @('AdWriteReadVerified','AdProbeRemoved','SysvolWriteReadVerified','SysvolProbeRemoved','AdWriteAttempted','SysvolWriteAttempted')) {
        $property=$Proof.PSObject.Properties[$name]
        if($null -eq $property -or $property.Value -isnot [bool] -or -not $property.Value) {return $false}
    }
    foreach($name in @('GpoId','InstanceId','Server','Error','CleanupErrors')) {
        if($null -eq $Proof.PSObject.Properties[$name]) {return $false}
    }
    return ($Proof.GpoId -ceq $Configuration.GpoId -and $Proof.InstanceId -ceq $Configuration.InstanceId -and
        $Proof.Server -ieq $Configuration.Server -and $null -eq $Proof.Error -and
        $Proof.CleanupErrors -is [array] -and $Proof.CleanupErrors.Count -eq 0)
}

function Get-AuthWireGpoWriteExecutableSource {
    @'
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.DirectoryServices.Protocols;
using System.IO;
using System.Runtime.Serialization;
using System.Runtime.Serialization.Json;
using System.Security.Principal;
using System.ServiceProcess;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;

namespace AuthWire.GpoWriteProbe {
    [DataContract]
    public sealed class ProbeConfiguration {
        [DataMember] public string Computer;
        [DataMember] public string Domain;
        [DataMember] public string Server;
        [DataMember] public string InstanceId;
        [DataMember] public string GpoId;
        [DataMember] public string ProtectedGpoId;
        [DataMember] public string ExpectedSid;
        [DataMember] public string Nonce;
        public string DistinguishedName, SysvolPath, Token;
        public void Validate() {
            Guid instance, gpo, protectedGpo, nonce;
            if (!Guid.TryParseExact(InstanceId,"D",out instance) || instance == Guid.Empty ||
                !Guid.TryParseExact(GpoId,"D",out gpo) || gpo == Guid.Empty ||
                !Guid.TryParseExact(ProtectedGpoId,"D",out protectedGpo) || protectedGpo == Guid.Empty || gpo == protectedGpo ||
                !Guid.TryParseExact(Nonce,"N",out nonce) || nonce == Guid.Empty)
                throw new InvalidOperationException("PROBE_CONFIGURATION_GUID_INVALID");
            if (Computer == null || !Regex.IsMatch(Computer,@"^[A-Za-z0-9][A-Za-z0-9-]{0,14}$") ||
                Domain == null || !Regex.IsMatch(Domain,@"^(?=.{1,253}$)[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?)+$") ||
                !String.Equals(Server, Computer+"."+Domain,StringComparison.OrdinalIgnoreCase))
                throw new InvalidOperationException("PROBE_CONFIGURATION_SERVER_INVALID");
            SecurityIdentifier sid = new SecurityIdentifier(ExpectedSid);
            if (sid.AccountDomainSid == null) throw new InvalidOperationException("DOMAIN_SERVICE_SID_REQUIRED");
            string[] labels=Domain.Split('.');
            for(int i=0;i<labels.Length;i++) labels[i]="DC="+labels[i];
            DistinguishedName="CN={"+gpo.ToString("D")+"},CN=Policies,CN=System,"+String.Join(",",labels);
            SysvolPath=@"\\"+Server+@"\SYSVOL\"+Domain+@"\Policies\{"+gpo.ToString("D")+@"}\AuthWire-WriteProbe-"+Nonce+".tmp";
            Token="AuthWireWriteProbe:v1;instance="+instance.ToString("D")+";gpo="+gpo.ToString("D")+";nonce="+Nonce;
        }
    }
    public interface IGpoDirectory : IDisposable {
        void ValidateTarget();
        string[] ReadDescriptions();
        void AddOwnDescription(string value);
        void DeleteOwnDescription(string value);
    }
    public sealed class LdapGpoDirectory : IGpoDirectory {
        private readonly ProbeConfiguration config;
        private readonly LdapConnection connection;
        public LdapGpoDirectory(ProbeConfiguration value) {
            config=value;
            connection=new LdapConnection(new LdapDirectoryIdentifier(config.Server,389,false,false));
            connection.AuthType=AuthType.Kerberos;
            connection.Timeout=TimeSpan.FromSeconds(5);
            connection.SessionOptions.ProtocolVersion=3;
            connection.SessionOptions.Signing=true;
            connection.SessionOptions.Sealing=true;
            connection.SessionOptions.ReferralChasing=ReferralChasingOptions.None;
            try { connection.Bind(); } catch { connection.Dispose(); throw; }
        }
        private SearchResultEntry Read(string[] names) {
            SearchRequest request=new SearchRequest(config.DistinguishedName,"(objectClass=groupPolicyContainer)",SearchScope.Base,names);
            SearchResponse response=(SearchResponse)connection.SendRequest(request);
            if(response.Entries.Count!=1) throw new InvalidOperationException("GPO_DIRECTORY_IDENTITY_INVALID");
            return response.Entries[0];
        }
        private static string[] Values(SearchResultEntry entry,string name) {
            if(!entry.Attributes.Contains(name)) return new string[0];
            List<string> values=new List<string>();
            foreach(object value in entry.Attributes[name].GetValues(typeof(string))) {
                if(!(value is string)) throw new InvalidOperationException("LDAP_ATTRIBUTE_SHAPE_INVALID");
                values.Add((string)value);
            }
            return values.ToArray();
        }
        public void ValidateTarget() {
            SearchResultEntry entry=Read(new string[]{"displayName","gPCFileSysPath","gPCMachineExtensionNames","gPCUserExtensionNames"});
            string[] names=Values(entry,"displayName"),paths=Values(entry,"gPCFileSysPath");
            string expectedName="AuthWire-Managed-Deployment-"+Guid.Parse(config.InstanceId).ToString("N").Substring(0,8);
            string expectedPath=@"\\"+config.Domain+@"\SYSVOL\"+config.Domain+@"\Policies\{"+Guid.Parse(config.GpoId).ToString("D")+"}";
            if(names.Length!=1 || names[0]!=expectedName || paths.Length!=1 ||
                !String.Equals(paths[0].TrimEnd('\\'),expectedPath,StringComparison.OrdinalIgnoreCase) ||
                Values(entry,"gPCMachineExtensionNames").Length!=0 || Values(entry,"gPCUserExtensionNames").Length!=0)
                throw new InvalidOperationException("GPO_DIRECTORY_TARGET_OR_SETTINGS_MISMATCH");
        }
        public string[] ReadDescriptions() { return Values(Read(new string[]{"description"}),"description"); }
        private void Modify(DirectoryAttributeOperation operation,string value) {
            // Add/Delete this exact unique value; never Replace or clear the whole attribute.
            DirectoryAttributeModification modification=new DirectoryAttributeModification();
            modification.Name="description";modification.Operation=operation;modification.Add(value);
            ModifyRequest request=new ModifyRequest();
            request.DistinguishedName=config.DistinguishedName;request.Modifications.Add(modification);
            connection.SendRequest(request);
        }
        public void AddOwnDescription(string value) { Modify(DirectoryAttributeOperation.Add,value); }
        public void DeleteOwnDescription(string value) { Modify(DirectoryAttributeOperation.Delete,value); }
        public void Dispose() { connection.Dispose(); }
    }
    public sealed class OperationResult {
        public bool AdWriteReadVerified, AdProbeRemoved, SysvolWriteReadVerified, SysvolProbeRemoved;
        public bool AdWriteAttempted, SysvolWriteAttempted;
        public string Error;
        public string[] CleanupErrors;
    }
    public static class ProbeOperations {
        private static bool Has(string[] values,string value) {
            foreach(string entry in values) if(entry==value) return true;
            return false;
        }
        public static OperationResult Run(IGpoDirectory directory,string path,string token) {
            OperationResult result=new OperationResult();
            List<string> cleanup=new List<string>();
            try {
                directory.ValidateTarget();
                if(directory.ReadDescriptions().Length!=0) throw new InvalidOperationException("GPO_LDAP_DESCRIPTION_NOT_EMPTY");
                result.AdWriteAttempted=true;
                directory.AddOwnDescription(token);
                string[] read=directory.ReadDescriptions();
                if(read.Length!=1 || read[0]!=token) throw new InvalidOperationException("GPO_AD_WRITE_READ_MISMATCH");
                result.AdWriteReadVerified=true;
                byte[] bytes=Encoding.UTF8.GetBytes(token);
                result.SysvolWriteAttempted=true;
                using(FileStream stream=new FileStream(path,FileMode.CreateNew,FileAccess.ReadWrite,FileShare.None,4096,FileOptions.WriteThrough|FileOptions.DeleteOnClose)) {
                    stream.Write(bytes,0,bytes.Length);stream.Flush(true);stream.Position=0;
                    byte[] received=new byte[bytes.Length];int used=0,n;
                    while(used<received.Length && (n=stream.Read(received,used,received.Length-used))>0) used+=n;
                    if(used!=bytes.Length || stream.Length!=bytes.Length || Encoding.UTF8.GetString(received)!=token)
                        throw new InvalidOperationException("GPO_SYSVOL_WRITE_READ_MISMATCH");
                    result.SysvolWriteReadVerified=true;
                }
                result.SysvolProbeRemoved=!File.Exists(path);
                if(!result.SysvolProbeRemoved) throw new InvalidOperationException("GPO_SYSVOL_PROBE_NOT_REMOVED");
            } catch(Exception error) { result.Error=error.GetType().Name+":"+error.Message; }
            finally {
                if(result.AdWriteAttempted) {
                    try {
                        string[] present=directory.ReadDescriptions();
                        if(Has(present,token)) directory.DeleteOwnDescription(token);
                        string[] after=directory.ReadDescriptions();
                        result.AdProbeRemoved=!Has(after,token);
                        if(!result.AdProbeRemoved) cleanup.Add("GPO_OWN_LDAP_VALUE_REMAINS");
                        if(after.Length!=0) cleanup.Add("GPO_LDAP_DESCRIPTION_CONCURRENT_CHANGE_PRESERVED");
                    } catch(Exception error) { cleanup.Add("GPO_AD_CLEANUP:"+error.GetType().Name+":"+error.Message); }
                } else { result.AdProbeRemoved=true; }
                // DeleteOnClose removes only the file created by this process, including on a process exit.
                if(result.SysvolWriteReadVerified && !result.SysvolProbeRemoved)
                    result.SysvolProbeRemoved=!File.Exists(path);
                result.CleanupErrors=cleanup.ToArray();
            }
            return result;
        }
    }
    [DataContract]
    public sealed class ServiceProof {
        [DataMember] public string ServiceName, Nonce, Computer, IdentityName, IdentitySid, RecordedUtc;
        [DataMember] public int ProcessId;
        [DataMember] public bool IsAuthenticated, ServiceGroupPresent;
        [DataMember] public string GpoId, InstanceId, Server;
        [DataMember] public bool AdWriteReadVerified, AdProbeRemoved, SysvolWriteReadVerified, SysvolProbeRemoved, AdWriteAttempted, SysvolWriteAttempted;
        [DataMember] public string Error;
        [DataMember] public string[] CleanupErrors;
    }
    public sealed class ShortLivedService : ServiceBase {
        private readonly string proofPath, nonce, configPath;
        private Thread worker;
        private Timer watchdog;
        private ShortLivedService(string name,string proof,string binding,string configuration) {
            ServiceName=name;proofPath=proof;nonce=binding;configPath=configuration;
            AutoLog=false;CanStop=true;CanShutdown=true;
        }
        protected override void OnStart(string[] args) {
            worker=new Thread(Execute);worker.IsBackground=true;
            watchdog=new Timer(delegate(object unused){try{Stop();}catch{}},null,90000,Timeout.Infinite);
            worker.Start();
        }
        private void Execute() {
            ServiceProof proof=new ServiceProof();
            proof.ServiceName=ServiceName;proof.Nonce=nonce;proof.Computer=Environment.MachineName;
            proof.ProcessId=Process.GetCurrentProcess().Id;proof.RecordedUtc=DateTime.UtcNow.ToString("o");
            proof.CleanupErrors=new string[0];
            try {
                using(WindowsIdentity identity=WindowsIdentity.GetCurrent()) {
                    proof.IdentityName=identity.Name;proof.IdentitySid=identity.User.Value;proof.IsAuthenticated=identity.IsAuthenticated;
                    foreach(IdentityReference group in identity.Groups) if(group.Value=="S-1-5-6") proof.ServiceGroupPresent=true;
                }
                ProbeConfiguration config;
                using(FileStream input=new FileStream(configPath,FileMode.Open,FileAccess.Read,FileShare.Read)) {
                    if(input.Length>32768) throw new InvalidOperationException("CONFIGURATION_TOO_LARGE");
                    config=(ProbeConfiguration)new DataContractJsonSerializer(typeof(ProbeConfiguration)).ReadObject(input);
                }
                config.Validate();
                proof.GpoId=config.GpoId;proof.InstanceId=config.InstanceId;proof.Server=config.Server;
                if(!proof.IsAuthenticated || !proof.ServiceGroupPresent || proof.IdentitySid!=config.ExpectedSid ||
                    !String.Equals(config.Computer,Environment.MachineName,StringComparison.OrdinalIgnoreCase) || config.Nonce!=nonce)
                    throw new InvalidOperationException("SERVICE_RUNTIME_IDENTITY_MISMATCH");
                using(IGpoDirectory directory=new LdapGpoDirectory(config)) {
                    OperationResult result=ProbeOperations.Run(directory,config.SysvolPath,config.Token);
                    proof.AdWriteReadVerified=result.AdWriteReadVerified;proof.AdProbeRemoved=result.AdProbeRemoved;
                    proof.SysvolWriteReadVerified=result.SysvolWriteReadVerified;proof.SysvolProbeRemoved=result.SysvolProbeRemoved;
                    proof.AdWriteAttempted=result.AdWriteAttempted;proof.SysvolWriteAttempted=result.SysvolWriteAttempted;
                    proof.Error=result.Error;proof.CleanupErrors=result.CleanupErrors;
                }
            } catch(Exception error) { proof.Error=error.GetType().Name+":"+error.Message; }
            // Atomic proof publication: the controller never reads a partially serialized JSON file.
            string temporary=proofPath+".writing";
            using(FileStream output=new FileStream(temporary,FileMode.CreateNew,FileAccess.Write,FileShare.None))
                new DataContractJsonSerializer(typeof(ServiceProof)).WriteObject(output,proof);
            File.Move(temporary,proofPath);
        }
        protected override void OnStop() {
            if(watchdog!=null) watchdog.Dispose();
            if(worker!=null && worker.IsAlive) worker.Join(10000);
        }
        public static void Main(string[] args) {
            Guid parsed;
            if(args.Length!=4 || !args[0].StartsWith("AuthWireLogonProbe-",StringComparison.Ordinal) ||
                !Guid.TryParseExact(args[0].Substring(19),"N",out parsed) || !Guid.TryParseExact(args[2],"N",out parsed)) return;
            string root=AppDomain.CurrentDomain.BaseDirectory;
            if(!String.Equals(Path.GetFullPath(args[1]),Path.Combine(root,@"result\service-proof.json"),StringComparison.OrdinalIgnoreCase) ||
                !String.Equals(Path.GetFullPath(args[3]),Path.Combine(root,"config.json"),StringComparison.OrdinalIgnoreCase)) return;
            ServiceBase.Run(new ShortLivedService(args[0],args[1],args[2],args[3]));
        }
    }
}

'@
}
function New-AuthWireSignedGpoWriteExecutable {
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
        foreach($assembly in @('System.dll','System.Core.dll','System.ServiceProcess.dll','System.Runtime.Serialization.dll','System.Xml.dll','System.DirectoryServices.Protocols.dll')) {
            $null=$parameters.ReferencedAssemblies.Add($assembly)
        }
        $compiled=$compiler.CompileAssemblyFromSource($parameters,(Get-AuthWireGpoWriteExecutableSource))
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
function Invoke-AuthWireGpoWriteProbeCore {
    param([string]$RuntimeAccount,[string]$ExpectedSid,[string]$PublisherThumbprint,$Configuration)
    Initialize-AuthWireProbeController
    $sid=[System.Security.Principal.SecurityIdentifier]::new($ExpectedSid).Value
    $serviceName='AuthWireLogonProbe-' + [guid]::NewGuid().ToString('N')
    $nonce=[guid]::NewGuid().ToString('N')
    $root=Join-Path ([Environment]::GetFolderPath('CommonApplicationData')) ('AuthWire-GpoWriteProbe-' + [guid]::NewGuid().ToString('N'))
    $resultDirectory=Join-Path $root 'result'
    $proofFile=Join-Path $resultDirectory 'service-proof.json'
    $binary=Join-Path $root 'probe.exe'
    $summaryPath=Join-Path $root 'summary.json'
    $configPath=Join-Path $root 'config.json'
    $owned=$null; $controller=$null; $created=$false; $removed=$false
    $runtimeVerified=$false; $binaryRemoved=$false; $dataRemoved=$false
    $failure=$null; $nativeError=$null; $cleanupErrors=@(); $proof=$null; $stage='prepare_directory'
    try {
        New-AuthWireProbeDirectory -Path $root -Sid $sid
        New-AuthWireProbeDirectory -Path $resultDirectory -Sid $sid -Writable
        Write-AuthWireProbeEvidence -Path (Join-Path $root 'manifest.json') -Value ([ordered]@{
            Version=1;ServiceName=$serviceName;Nonce=$nonce;ExpectedSid=$sid;RuntimeAccount=$RuntimeAccount
            CreatedUtc=[datetime]::UtcNow.ToString('o');BinaryPath=$binary;PasswordSupplied=$false
            InstanceId=$Configuration.InstanceId;GpoId=$Configuration.GpoId;ProtectedGpoId=$Configuration.ProtectedGpoId
            Domain=$Configuration.Domain;Server=$Configuration.Server
            OwnedLdapDescription=('AuthWireWriteProbe:v1;instance='+$Configuration.InstanceId+';gpo='+$Configuration.GpoId+';nonce='+$nonce)
            OwnedSysvolFile=('\\'+$Configuration.Server+'\SYSVOL\'+$Configuration.Domain+'\Policies\{'+$Configuration.GpoId+'}\AuthWire-WriteProbe-'+$nonce+'.tmp')
        })
        $Configuration | Add-Member -NotePropertyName Nonce -NotePropertyValue $nonce -Force
        [IO.File]::WriteAllText($configPath,($Configuration | ConvertTo-Json -Depth 4),[Text.UTF8Encoding]::new($false))
        $stage='compile_and_sign'
        New-AuthWireSignedGpoWriteExecutable -Path $binary -PublisherThumbprint $PublisherThumbprint
        $stage='create_owned_service'
        $command='"{0}" "{1}" "{2}" "{3}" "{4}"' -f $binary,$serviceName,$proofFile,$nonce,$configPath
        $owned=[AuthWire.Connector.OwnedProbeServiceV1]::Create($serviceName,$command,$RuntimeAccount)
        $created=$true
        $controller=New-Object System.ServiceProcess.ServiceController -ArgumentList $serviceName
        $stage='start_service'
        $controller.Start()
        $controller.WaitForStatus([System.ServiceProcess.ServiceControllerStatus]::Running,[timespan]::FromSeconds(20))
        $stage='read_runtime_proof'
        $deadline=[datetime]::UtcNow.AddSeconds(60)
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
        Write-AuthWireProbeEvidence -Path (Join-Path $root 'verified-proof.json') -Value $proof
        if(-not (Test-AuthWireGpoOperationProof $proof $Configuration)) { throw 'SERVICE_GPO_WRITE_OR_CLEANUP_NOT_VERIFIED' }
        $stage='runtime_write_verified'
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
                if(Test-Path -LiteralPath $configPath) { Remove-Item -LiteralPath $configPath -Force }
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
        Event='WINDOWS_CONNECTOR_GPO_WRITE_PROBE';ProbeVersion='1.0.0'
        Computer=[Environment]::MachineName;Account=$RuntimeAccount;ExpectedSid=$sid
        ServiceName=$serviceName;ServiceCreated=$created;ServiceLogonVerified=$runtimeVerified
        RuntimeSid=$(if($null -ne $proof){$proof.IdentitySid}else{$null})
        RuntimeProcessId=$(if($null -ne $proof){$proof.ProcessId}else{$null})
        TemporaryServiceRemoved=$removed;TemporaryBinaryRemoved=$binaryRemoved;TemporaryResultDirectoryRemoved=$dataRemoved
        EvidencePath=$summaryPath;Stage=$stage;Error=$failure;NativeErrorCode=$nativeError;CleanupErrors=$cleanupErrors
        ProbeVerified=($runtimeVerified -and $null -eq $failure -and $removed -and $binaryRemoved -and $dataRemoved -and $cleanupErrors.Count -eq 0)
        GpoId=$Configuration.GpoId;InstanceId=$Configuration.InstanceId
        AdWriteReadVerified=($null -ne $proof -and $proof.AdWriteReadVerified);AdProbeRemoved=($null -ne $proof -and $proof.AdProbeRemoved)
        SysvolWriteReadVerified=($null -ne $proof -and $proof.SysvolWriteReadVerified);SysvolProbeRemoved=($null -ne $proof -and $proof.SysvolProbeRemoved)
        OperationError=$(if($null -ne $proof){$proof.Error}else{$null})
        OperationCleanupErrors=@(if($null -ne $proof){$proof.CleanupErrors})
        ServiceWriteAccessVerified=$false;ProtectedTrustPreserved=$false;TargetStatePreserved=$false
        AdChanged=$(if($null -ne $proof){[bool]$proof.AdWriteAttempted}elseif($created){$null}else{$false})
        GpoChanged=$(if($null -ne $proof){[bool]$proof.AdWriteAttempted}elseif($created){$null}else{$false})
        AdWriteOutcomeKnown=($null -ne $proof);LogonRightsChanged=$false;SecretsExported=$false
        GpoPersistenceVerified=$false;ConnectorInstalled=$false;CanApplyGpo=$false
    }
    if(Test-Path -LiteralPath $root) { Write-AuthWireProbeEvidence -Path $summaryPath -Value $result }
    return $result
}

if(-not [Environment]::Is64BitProcess) { throw 'POWERSHELL_64_BIT_REQUIRED' }
if([Environment]::MachineName -ine $ExpectedComputer) { throw 'LOCAL_COMPUTER_MISMATCH' }
if($ExpectedGpoId -eq [guid]::Empty -or $ProtectedGpoId -eq [guid]::Empty -or $ExpectedGpoId -eq $ProtectedGpoId) { throw 'EXPLICIT_MANAGED_AND_PROTECTED_GPO_IDS_REQUIRED' }
foreach($path in @($BootstrapPath,$RightsToolPath,$LogonToolPath,$DeploymentToolPath)) {
    $signature=Get-AuthenticodeSignature -FilePath $path
    if($signature.Status.ToString() -ne 'Valid' -or $signature.SignerCertificate.Thumbprint -ine $PublisherThumbprint) {throw 'PREPARATION_TOOL_SIGNATURE_INVALID'}
}
. ([scriptblock]::Create((Import-AuthWireSignedProbeHelpers $LogonToolPath @('Initialize-AuthWireProbeController','New-AuthWireProbeDirectory','Write-AuthWireProbeEvidence','Test-AuthWireRuntimeProof') $PublisherThumbprint)))
. ([scriptblock]::Create((Import-AuthWireSignedProbeHelpers $DeploymentToolPath @('Get-AuthWireGpoDocument','Get-AuthWireGpoRoot','Get-AuthWireGpoPermissionRows','Get-AuthWireProtectedGpoHash') $PublisherThumbprint)))
$common=@{ExpectedComputer=$ExpectedComputer;ExpectedDomain=$ExpectedDomain;InstanceId=$InstanceId;AccountName=$AccountName
    AccountSid=$AccountSid;BootstrapPath=$BootstrapPath;PublisherThumbprint=$PublisherThumbprint}
$gate=& $RightsToolPath -Mode Inspect @common|ConvertFrom-Json
if($gate.Event -ne 'WINDOWS_CONNECTOR_SERVICE_RIGHT_PREPARATION' -or $gate.ToolVersion -ne '1.0.0' -or $gate.Mode -ne 'Inspect' -or
    $gate.AccountSid -ne $AccountSid -or $gate.Computer -ine $ExpectedComputer -or $gate.Account -ine ($AccountName+'$') -or
    $gate.Right -ne 'SeServiceLogonRight' -or -not $gate.DirectServiceRightAssigned -or @($gate.DenyAssignedSids).Count -ne 0 -or
    $gate.LocalPolicyChanged -or $gate.AdChanged -or $gate.GpoChanged) { throw 'OWNED_ACCOUNT_AND_SERVICE_RIGHT_REQUIRED' }
$gpoParams=$common.Clone()
$gpoParams.PreparationReceiptPath=$PreparationReceiptPath;$gpoParams.ExpectedGpoId=$ExpectedGpoId
$gpoParams.ScopeGroupSid=$ScopeGroupSid;$gpoParams.ScopeGroupName=$ScopeGroupName;$gpoParams.ProtectedGpoId=$ProtectedGpoId
$gpoGate=& $DeploymentToolPath -Mode Inspect @gpoParams|ConvertFrom-Json
if($gpoGate.Event -ne 'WINDOWS_CONNECTOR_DEPLOYMENT_GPO_PREPARATION' -or $gpoGate.ToolVersion -ne '1.0.1' -or $gpoGate.Mode -ne 'Inspect' -or
    $gpoGate.Computer -ine $ExpectedComputer -or $gpoGate.Domain -ine $ExpectedDomain -or $gpoGate.InstanceId -ine $InstanceId.ToString('D') -or
    $gpoGate.ServiceSid -ne $AccountSid -or $gpoGate.ScopeGroupSid -ne $ScopeGroupSid -or $gpoGate.ProtectedTrustGpoId -ine $ProtectedGpoId.ToString('D') -or
    $gpoGate.GpoState.Id -ine $ExpectedGpoId.ToString('D') -or -not $gpoGate.GpoState.MetadataComplete -or
    $gpoGate.GpoState.Linked -or $gpoGate.GpoState.ContainsSettings -or -not $gpoGate.ReadyForResume -or -not $gpoGate.ProtectedTrustPreserved -or
    @($gpoGate.Blockers).Count -ne 0 -or $gpoGate.AdChanged -or $gpoGate.GpoChanged) {throw 'VERIFIED_EMPTY_UNLINKED_MANAGED_GPO_REQUIRED'}
Import-Module ActiveDirectory -ErrorAction Stop
Import-Module GroupPolicy -ErrorAction Stop
$ready=@(Test-ADServiceAccount -Identity $AccountSid -ErrorAction Stop)
if($ready.Count -ne 1 -or $ready[0] -isnot [bool] -or -not $ready[0]) {throw 'LOCAL_GMSA_READINESS_REQUIRED'}
$runtime=[Security.Principal.SecurityIdentifier]::new($AccountSid).Translate([Security.Principal.NTAccount]).Value
if(-not $runtime.EndsWith('\'+$AccountName+'$',[StringComparison]::OrdinalIgnoreCase)) {throw 'RUNTIME_ACCOUNT_NAME_MISMATCH'}
$server=$ExpectedComputer+'.'+$ExpectedDomain
$dn='CN={'+$ExpectedGpoId.ToString('D')+'},CN=Policies,CN=System,'+((Get-ADDomain -Server $server).DistinguishedName)
$gpc=Get-ADObject -Identity $dn -Server $server -Properties description -ErrorAction Stop
$descriptions=@(foreach($value in $gpc.description){if($null -ne $value){[string]$value}})
if($descriptions.Count -ne 0) {throw 'GPO_LDAP_DESCRIPTION_NOT_EMPTY'}
$protectedBefore=Get-AuthWireProtectedGpoHash $ProtectedGpoId $ExpectedDomain $server
$targetBefore=Get-AuthWireGpoBusinessFingerprint $ExpectedGpoId $ExpectedDomain $server
if($Mode -eq 'Inspect') {
    [pscustomobject]@{Event='WINDOWS_CONNECTOR_GPO_WRITE_PREFLIGHT';ProbeVersion='1.0.0';Computer=$ExpectedComputer
        Account=$runtime;GpoId=$ExpectedGpoId.ToString('D');ReadyForProbe=$true;ServiceCreated=$false
        AdChanged=$false;GpoChanged=$false;ServiceWriteAccessVerified=$false;ConnectorInstalled=$false;CanApplyGpo=$false}|ConvertTo-Json
} else {
    $configuration=[pscustomobject]@{Computer=$ExpectedComputer;Domain=$ExpectedDomain;Server=$server;InstanceId=$InstanceId.ToString('D')
        GpoId=$ExpectedGpoId.ToString('D');ProtectedGpoId=$ProtectedGpoId.ToString('D');ExpectedSid=$AccountSid}
    $result=Invoke-AuthWireGpoWriteProbeCore -RuntimeAccount $runtime -ExpectedSid $AccountSid -PublisherThumbprint $PublisherThumbprint -Configuration $configuration
    try {
        $result.ProtectedTrustPreserved=((Get-AuthWireProtectedGpoHash $ProtectedGpoId $ExpectedDomain $server) -ceq $protectedBefore)
        $after=Get-ADObject -Identity $dn -Server $server -Properties description -ErrorAction Stop
        $values=@(foreach($value in $after.description){if($null -ne $value){[string]$value}})
        $result.TargetStatePreserved=($values.Count -eq 0 -and (Get-AuthWireGpoBusinessFingerprint $ExpectedGpoId $ExpectedDomain $server) -ceq $targetBefore)
        if(-not $result.ProtectedTrustPreserved -or -not $result.TargetStatePreserved) {
            $result.ProbeVerified=$false;$result.CleanupErrors+= 'GPO_POSTCHECK_REQUIRES_REVIEW'
        }
    } catch { $result.ProbeVerified=$false;$result.CleanupErrors+=('GPO_POSTCHECK:'+ $_.Exception.Message) }
    $result.ServiceWriteAccessVerified=($result.ProbeVerified -and $result.AdWriteReadVerified -and $result.AdProbeRemoved -and
        $result.SysvolWriteReadVerified -and $result.SysvolProbeRemoved -and $result.TargetStatePreserved -and $result.ProtectedTrustPreserved)
    Write-AuthWireProbeEvidence -Path $result.EvidencePath -Value $result
    $result|ConvertTo-Json -Depth 7
}
