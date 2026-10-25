# Disposable hosted Windows only. AD calls are simulated; actual local files and SCM are exercised.
$ErrorActionPreference='Stop'
Set-StrictMode -Version 2
if($env:RUNNER_ENVIRONMENT -ne 'github-hosted') {throw 'Hosted fixture only.'}
$source=Join-Path $PSScriptRoot '..\windows\connector\Test-AuthWireGpoWrite.ps1'
$logon=Join-Path $PSScriptRoot '..\windows\connector\Test-AuthWireServiceLogon.ps1'
foreach($path in @($source,$logon)){
    $tokens=$null;$errors=$null
    $ast=[Management.Automation.Language.Parser]::ParseFile($path,[ref]$tokens,[ref]$errors)
    if($errors.Count){throw ($errors.Message -join '; ')}
    $functions=@($ast.EndBlock.Statements|Where-Object {$_ -is [Management.Automation.Language.FunctionDefinitionAst]})
    . ([scriptblock]::Create(($functions|ForEach-Object {$_.Extent.Text}) -join [Environment]::NewLine))
}
$script:checks=0
function Check([bool]$Value,[string]$Name){if(-not $Value){throw $Name};$script:checks++}
$realSource=Get-AuthWireGpoWriteExecutableSource
$fixture=@'
namespace AuthWire.GpoWriteProbe {
    public sealed class FixtureDirectory : IGpoDirectory {
        public readonly System.Collections.Generic.List<string> Values=new System.Collections.Generic.List<string>();
        public bool BadTarget, ThrowAfterAdd, ConcurrentChange, FailDelete;
        public int Adds, Deletes;
        public void ValidateTarget(){if(BadTarget)throw new System.InvalidOperationException("FIXTURE_BAD_TARGET");}
        public string[] ReadDescriptions(){return Values.ToArray();}
        public void AddOwnDescription(string value){
            Adds++;Values.Add(value);
            if(ConcurrentChange)Values.Add("CUSTOMER-CONCURRENT-VALUE");
            if(ThrowAfterAdd)throw new System.InvalidOperationException("FIXTURE_LOST_ADD_RESPONSE");
        }
        public void DeleteOwnDescription(string value){
            Deletes++;if(FailDelete)throw new System.InvalidOperationException("FIXTURE_DELETE_FAILURE");Values.Remove(value);
        }
        public void Dispose(){}
    }
}
'@
Add-Type -TypeDefinition ($realSource+[Environment]::NewLine+$fixture) -ReferencedAssemblies @('System.dll','System.Core.dll','System.ServiceProcess.dll','System.Runtime.Serialization.dll','System.Xml.dll','System.DirectoryServices.Protocols.dll')
$unitRoot=Join-Path $env:RUNNER_TEMP ('AuthWire-WriteUnit-'+[guid]::NewGuid().ToString('N'))
$null=New-Item -ItemType Directory -Path $unitRoot
$cert=$null;$public=$null;$roots=$null;$publishers=$null;$folders=@()
try{
    foreach($case in @('success','repeat','collision','existingDescription','targetMismatch','lostReply','concurrent','deleteFailure','missingDirectory')){
        $directory=New-Object AuthWire.GpoWriteProbe.FixtureDirectory
        $path=Join-Path $unitRoot ('probe-'+[guid]::NewGuid().ToString('N')+'.tmp')
        $token='AuthWireWriteProbe:v1;nonce='+[guid]::NewGuid().ToString('N')
        switch($case){
            'collision' {[IO.File]::WriteAllText($path,'CUSTOMER-FILE')}
            'existingDescription' {$directory.Values.Add('CUSTOMER-LDAP-VALUE')}
            'targetMismatch' {$directory.BadTarget=$true}
            'lostReply' {$directory.ThrowAfterAdd=$true}
            'concurrent' {$directory.ConcurrentChange=$true}
            'deleteFailure' {$directory.FailDelete=$true}
            'missingDirectory' {$path=Join-Path (Join-Path $unitRoot 'absent') 'probe.tmp'}
        }
        $r=[AuthWire.GpoWriteProbe.ProbeOperations]::Run($directory,$path,$token)
        if($case -in @('success','repeat')){
            Check ($r.AdWriteReadVerified -and $r.SysvolWriteReadVerified -and $r.AdProbeRemoved -and $r.SysvolProbeRemoved -and $null -eq $r.Error -and $r.CleanupErrors.Count -eq 0) 'Engine writes reads and cleans exact temporary values'
            Check ($directory.Values.Count -eq 0 -and -not (Test-Path -LiteralPath $path)) 'DeleteOnClose file and LDAP value removed'
        }else{
            Check ($null -ne $r.Error -or $r.CleanupErrors.Count -ne 0) ('Failure is explicit: '+$case)
        }
        switch($case){
            'collision' {Check ([IO.File]::ReadAllText($path) -eq 'CUSTOMER-FILE' -and $r.AdProbeRemoved) 'CreateNew preserves existing file and restores LDAP';Remove-Item -LiteralPath $path}
            'existingDescription' {Check ($directory.Adds -eq 0 -and $directory.Deletes -eq 0 -and $directory.Values[0] -eq 'CUSTOMER-LDAP-VALUE') 'Existing LDAP description never replaced or cleared'}
            'targetMismatch' {Check ($directory.Adds -eq 0 -and $directory.Deletes -eq 0 -and -not (Test-Path $path)) 'Wrong target blocks all modifications'}
            'lostReply' {Check ($directory.Adds -eq 1 -and $directory.Deletes -eq 1 -and $directory.Values.Count -eq 0 -and $r.AdProbeRemoved) 'Lost modify reply still cleans own unique value'}
            'concurrent' {Check ($directory.Values.Count -eq 1 -and $directory.Values[0] -eq 'CUSTOMER-CONCURRENT-VALUE' -and $r.AdProbeRemoved -and $r.CleanupErrors.Count -eq 1) 'Concurrent LDAP data preserved and reported'}
            'deleteFailure' {Check (-not $r.AdProbeRemoved -and $r.CleanupErrors.Count -eq 1 -and $directory.Values.Contains($token)) 'Cleanup failure never claims successful removal'}
            'missingDirectory' {Check ($r.AdProbeRemoved -and $directory.Values.Count -eq 0) 'File failure restores only own LDAP value'}
        }
    }
    $valid=@{Computer=[Environment]::MachineName;Domain='test.example';Server=([Environment]::MachineName+'.test.example')
        InstanceId='4c23eebe-0715-46d1-88ee-a2e96ad7ee46';GpoId='8c6808fd-a382-4bf2-9c9c-d9e1d46082a3'
        ProtectedGpoId='e5a9ab39-3709-49cb-837a-0208d2eb3b12';ExpectedSid='S-1-5-21-111-222-333-1648';Nonce=[guid]::NewGuid().ToString('N')}
    foreach($case in @('valid','sameProtected','empty','server','domain','sid','nonce')){
        $config=New-Object AuthWire.GpoWriteProbe.ProbeConfiguration
        foreach($key in $valid.Keys){$config.$key=$valid[$key]}
        switch($case){
            'sameProtected' {$config.GpoId=$config.ProtectedGpoId}
            'empty' {$config.GpoId=[guid]::Empty.ToString('D')}
            'server' {$config.Server='unapproved.test.example'}
            'domain' {$config.Domain='test/example'}
            'sid' {$config.ExpectedSid='S-1-5-19'}
            'nonce' {$config.Nonce='../../file'}
        }
        $caught=$false;try{$config.Validate()}catch{$caught=$true}
        if($case -eq 'valid'){
            Check (-not $caught -and $config.DistinguishedName -eq 'CN={8c6808fd-a382-4bf2-9c9c-d9e1d46082a3},CN=Policies,CN=System,DC=test,DC=example') 'Configuration constructs fixed GPC DN'
            Check ($config.SysvolPath.StartsWith('\\'+$valid.Server+'\SYSVOL\test.example\Policies\{'+$valid.GpoId+'}\') -and $config.SysvolPath.EndsWith($valid.Nonce+'.tmp')) 'Configuration pins UNC and unique file leaf'
        }else{Check $caught ('Configuration rejects '+$case)}
    }
    # Source-only fixture substitution: production always binds Kerberos LDAP to the fixed DC/GPC.
    # CI has no AD forest; this does not validate customer LDAP or SMB connectivity.
    $script:fixtureSource=$realSource.Replace('if (sid.AccountDomainSid == null) throw new InvalidOperationException("DOMAIN_SERVICE_SID_REQUIRED");','')
    $script:fixtureSource=$script:fixtureSource.Replace('using(IGpoDirectory directory=new LdapGpoDirectory(config)) {',
        'config.SysvolPath=Path.Combine(Path.GetDirectoryName(proofPath),"AuthWire-WriteProbe-"+nonce+".tmp"); using(IGpoDirectory directory=new FixtureDirectory()) {')+$fixture
    Check ($script:fixtureSource -ne $realSource -and $script:fixtureSource.Contains('new FixtureDirectory()')) 'LocalService fixture explicitly substitutes directory and UNC, never customer state'
    function Get-AuthWireGpoWriteExecutableSource {return $script:fixtureSource}
    $cert=New-SelfSignedCertificate -Type CodeSigningCert -Subject 'CN=AuthWire isolated GPO write fixture' -CertStoreLocation 'Cert:\CurrentUser\My' -KeyAlgorithm RSA -KeyLength 2048 -HashAlgorithm SHA256 -KeyExportPolicy NonExportable -NotAfter (Get-Date).AddDays(1)
    $public=[Security.Cryptography.X509Certificates.X509Certificate2]::new($cert.RawData)
    $roots=[Security.Cryptography.X509Certificates.X509Store]::new('Root','LocalMachine')
    $roots.Open([Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite);$roots.Add($public)
    $publishers=[Security.Cryptography.X509Certificates.X509Store]::new('TrustedPublisher','LocalMachine')
    $publishers.Open([Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite);$publishers.Add($public)
    $configuration=[pscustomobject]@{};foreach($key in $valid.Keys){if($key -ne 'Nonce'){$configuration|Add-Member -NotePropertyName $key -NotePropertyValue $valid[$key]}}
    $configuration.ExpectedSid='S-1-5-19'
    $result=Invoke-AuthWireGpoWriteProbeCore -RuntimeAccount 'NT AUTHORITY\LocalService' -ExpectedSid 'S-1-5-19' -PublisherThumbprint $cert.Thumbprint -Configuration $configuration
    Write-Host ('GPO_WRITE_FIXTURE_RESULT '+($result|ConvertTo-Json -Depth 6 -Compress))
    if(Test-Path -LiteralPath (Split-Path -Parent $result.EvidencePath)){$folders+=Split-Path -Parent $result.EvidencePath}
    Check ($result.ProbeVerified -and $result.ServiceLogonVerified -and $result.RuntimeSid -eq 'S-1-5-19' -and $result.AdWriteReadVerified -and $result.SysvolWriteReadVerified) 'Real signed SCM helper runs engine under low privilege with simulated directory'
    Check ($result.AdProbeRemoved -and $result.SysvolProbeRemoved -and $result.TemporaryServiceRemoved -and $result.TemporaryBinaryRemoved -and $result.TemporaryResultDirectoryRemoved) 'Helper cleans own probe data, service and artifacts'
    Check (-not $result.ServiceWriteAccessVerified -and -not $result.ConnectorInstalled -and -not $result.CanApplyGpo) 'Core cannot claim customer GPO write acceptance without independent postcheck'
    Check (-not [AuthWire.Connector.OwnedProbeServiceV1]::Exists($result.ServiceName)) 'SCM confirms write probe service absent'
    $proof=Get-Content -LiteralPath (Join-Path (Split-Path -Parent $result.EvidencePath) 'verified-proof.json') -Raw|ConvertFrom-Json
    Check (Test-AuthWireRuntimeProof $proof 'S-1-5-19' $proof.ServiceName $proof.Nonce $proof.ProcessId) 'Write proof binds runtime SID, SCM PID, nonce and host'
    Check (Test-AuthWireGpoOperationProof $proof $configuration) 'Write proof requires typed operation and cleanup acceptance'
    foreach($bad in @('GpoId','InstanceId','Server','Error','CleanupErrors','AdWriteReadVerified','AdProbeRemoved','SysvolWriteReadVerified','SysvolProbeRemoved','AdWriteAttempted','SysvolWriteAttempted')){
        $changed=$proof|ConvertTo-Json -Depth 5|ConvertFrom-Json
        switch($bad){
            'GpoId' {$changed.GpoId=[guid]::NewGuid().ToString('D')}
            'InstanceId' {$changed.InstanceId=[guid]::NewGuid().ToString('D')}
            'Server' {$changed.Server='wrong.test.example'}
            'Error' {$changed.Error='FAILED'}
            'CleanupErrors' {$changed.CleanupErrors=@('FAILED')}
            default {$changed.$bad='true'}
        }
        Check (-not (Test-AuthWireGpoOperationProof $changed $configuration)) ('Write proof rejects '+$bad)
    }
    $script:fixtureSource=$script:fixtureSource.Replace('new FixtureDirectory()','new FixtureDirectory(){FailDelete=true}')
    $failed=Invoke-AuthWireGpoWriteProbeCore -RuntimeAccount 'NT AUTHORITY\LocalService' -ExpectedSid 'S-1-5-19' -PublisherThumbprint $cert.Thumbprint -Configuration $configuration
    if(Test-Path -LiteralPath (Split-Path -Parent $failed.EvidencePath)){$folders+=Split-Path -Parent $failed.EvidencePath}
    Check (-not $failed.ProbeVerified -and -not $failed.ServiceWriteAccessVerified -and $failed.ServiceLogonVerified -and -not $failed.AdProbeRemoved) 'Actual SCM identity success cannot hide operation cleanup failure'
    Check ($failed.TemporaryServiceRemoved -and $failed.TemporaryBinaryRemoved -and $failed.TemporaryResultDirectoryRemoved -and $failed.OperationCleanupErrors.Count -eq 1) 'Failure still cleans service artifacts and retains explicit operation error'
    $caught=$false
    try{
        $params=@{ExpectedComputer='WRONG-HOST';ExpectedDomain='test.example';InstanceId=$valid.InstanceId;AccountSid=$valid.ExpectedSid
            ScopeGroupSid='S-1-5-21-111-222-333-1647';ScopeGroupName='Pilot';ExpectedGpoId=$valid.GpoId;ProtectedGpoId=$valid.ProtectedGpoId
            PreparationReceiptPath='missing';BootstrapPath='missing';RightsToolPath='missing';LogonToolPath='missing';DeploymentToolPath='missing';PublisherThumbprint=('A'*40)}
        $null=& $source -Mode RunProbe @params
    }catch{Check ($_.Exception.Message -like '*LOCAL_COMPUTER_MISMATCH*') 'Full entry rejects wrong host before writes';$caught=$true}
    Check $caught 'Entry guard enforced'
    Check ($realSource.Contains('DirectoryAttributeOperation.Add') -and $realSource.Contains('DirectoryAttributeOperation.Delete') -and -not $realSource.Contains('DirectoryAttributeOperation.Replace')) 'LDAP probe never replaces whole attributes'
    Check ($realSource.Contains('AuthType.Kerberos') -and $realSource.Contains('connection.SessionOptions.Sealing=true') -and $realSource.Contains('ReferralChasingOptions.None')) 'Production LDAP uses Kerberos signing sealing and no supplied passwords'
    Check ($realSource.Contains('FileMode.CreateNew') -and $realSource.Contains('FileOptions.DeleteOnClose')) 'Production file cannot overwrite an existing leaf and auto-deletes own handle'
    Write-Output ('AUTHWIRE_GPO_WRITE_PROBE_NATIVE_OK '+(@{checks=$checks;native_powershell=$PSVersionTable.PSVersion.ToString();actual_scm_service_tested=$true
        actual_local_file_io_tested=$true;directory_operations_simulated=$true;unc_substituted_with_local_fixture=$true;real_customer_gmsa_tested=$false
        real_customer_ad_smb_tested=$false;fixture_certificate_stores_modified=$true;private_keys_exported=0}|ConvertTo-Json -Compress))
}finally{
    foreach($folder in $folders){if(Test-Path -LiteralPath $folder){Remove-Item -LiteralPath $folder -Recurse -Force}}
    if(Test-Path -LiteralPath $unitRoot){Remove-Item -LiteralPath $unitRoot -Recurse -Force}
    if($null -ne $publishers){if($null -ne $public){$publishers.Remove($public)};$publishers.Dispose()}
    if($null -ne $roots){if($null -ne $public){$roots.Remove($public)};$roots.Dispose()}
    if($null -ne $cert){Remove-Item -LiteralPath ('Cert:\CurrentUser\My\'+$cert.Thumbprint) -DeleteKey -Force -ErrorAction SilentlyContinue;$cert.Dispose()}
    if($null -ne $public){$public.Dispose()}
}
