# Disposable Windows runner only: real SCM service under LocalService, never a customer gMSA.
$ErrorActionPreference='Stop'
Set-StrictMode -Version 2
if($env:RUNNER_ENVIRONMENT -ne 'github-hosted') { throw 'Hosted fixture only.' }
$source=Join-Path $PSScriptRoot '..\windows\connector\Test-AuthWireServiceLogon.ps1'
$tokens=$null; $errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile($source,[ref]$tokens,[ref]$errors)
if($errors.Count) { throw ($errors.Message -join '; ') }
$definitions=@($ast.FindAll({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst]},$true))
. ([scriptblock]::Create(($definitions | ForEach-Object {$_.Extent.Text}) -join [Environment]::NewLine))
$script:checks=0
function Check([bool]$Value,[string]$Name) {
    if(-not $Value) { throw $Name }; $script:checks++
}
$cert=$null; $public=$null; $roots=$null; $publishers=$null; $folders=@()
try {
    $cert=New-SelfSignedCertificate -Type CodeSigningCert -Subject 'CN=AuthWire isolated SCM fixture' `
        -CertStoreLocation 'Cert:\CurrentUser\My' -KeyAlgorithm RSA -KeyLength 2048 `
        -HashAlgorithm SHA256 -KeyExportPolicy NonExportable -NotAfter (Get-Date).AddDays(1)
    Write-Host 'SCM_FIXTURE certificate_generated'
    $public=[System.Security.Cryptography.X509Certificates.X509Certificate2]::new($cert.RawData)
    $roots=[System.Security.Cryptography.X509Certificates.X509Store]::new('Root','LocalMachine')
    $roots.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
    $roots.Add($public)
    Write-Host 'SCM_FIXTURE local_machine_root_trusted'
    $publishers=[System.Security.Cryptography.X509Certificates.X509Store]::new('TrustedPublisher','LocalMachine')
    $publishers.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
    $publishers.Add($public)
    Write-Host 'SCM_FIXTURE local_machine_publisher_trusted'
    for($attempt=0;$attempt -lt 2;$attempt++) {
        Write-Host ('SCM_FIXTURE runtime_attempt_' + $attempt)
        $r=Invoke-AuthWireServiceProbeCore -RuntimeAccount 'NT AUTHORITY\LocalService' -ExpectedSid 'S-1-5-19' -PublisherThumbprint $cert.Thumbprint
        Write-Host ('SCM_FIXTURE runtime_result ' + ($r | ConvertTo-Json -Depth 6 -Compress))
        if(Test-Path -LiteralPath (Split-Path -Parent $r.EvidencePath)) { $folders += Split-Path -Parent $r.EvidencePath }
        if(-not $r.ProbeVerified) { throw ('SCM fixture failed: ' + ($r | ConvertTo-Json -Depth 7 -Compress)) }
        Check ($r.ServiceCreated -and $r.ServiceLogonVerified -and $r.RuntimeSid -eq 'S-1-5-19' -and $r.RuntimeProcessId -gt 0) 'Real signed service started with expected low-privilege identity'
        Check ($r.TemporaryServiceRemoved -and $r.TemporaryBinaryRemoved -and $r.TemporaryResultDirectoryRemoved) 'Owned temporary service and executable removed'
        Check (-not $r.AdChanged -and -not $r.GpoChanged -and -not $r.LogonRightsChanged -and -not $r.ConnectorInstalled -and -not $r.CanApplyGpo -and -not $r.SecretsExported) 'Probe keeps unrelated permissions and connector gates unchanged'
        Check (-not [AuthWire.Connector.OwnedProbeServiceV1]::Exists($r.ServiceName)) 'SCM confirms probe service absent'
        $root=Split-Path -Parent $r.EvidencePath
        $acl=Get-Acl -LiteralPath $root
        $rules=@($acl.GetAccessRules($true,$true,[System.Security.Principal.SecurityIdentifier]))
        Check ($acl.AreAccessRulesProtected -and $rules.Count -eq 2 -and @($rules | Where-Object {$_.IdentityReference.Value -notin @('S-1-5-18','S-1-5-32-544')}).Count -eq 0) 'Retained evidence accessible only to SYSTEM and Administrators'
        $proof=Get-Content -LiteralPath (Join-Path $root 'verified-proof.json') -Raw | ConvertFrom-Json
        Check (Test-AuthWireRuntimeProof -Proof $proof -Sid 'S-1-5-19' -ServiceName $proof.ServiceName -Nonce $proof.Nonce -ProcessId $proof.ProcessId) 'Runtime proof binds SID, SCM process, service, host and nonce'
        foreach($bad in @('sid','nonce','name','pid','host','authenticated','serviceGroup','typedBoolean')) {
            $changed=$proof | ConvertTo-Json | ConvertFrom-Json
            switch($bad) {
                'sid' {$changed.IdentitySid='S-1-5-20'}
                'nonce' {$changed.Nonce=[guid]::NewGuid().ToString('N')}
                'name' {$changed.ServiceName='OtherService'}
                'pid' {$changed.ProcessId=$proof.ProcessId+1}
                'host' {$changed.Computer='WRONG-HOST'}
                'authenticated' {$changed.IsAuthenticated=$false}
                'serviceGroup' {$changed.ServiceGroupPresent=$false}
                'typedBoolean' {$changed.ServiceGroupPresent='true'}
            }
            Check (-not (Test-AuthWireRuntimeProof -Proof $changed -Sid 'S-1-5-19' -ServiceName $proof.ServiceName -Nonce $proof.Nonce -ProcessId $proof.ProcessId)) ('Runtime proof rejects ' + $bad)
        }
    }
    # A name collision must fail without adopting, deleting or reconfiguring the existing object.
    $collision='AuthWireLogonProbe-' + [guid]::NewGuid().ToString('N')
    $owned=$null
    try {
        $owned=[AuthWire.Connector.OwnedProbeServiceV1]::Create($collision,('"' + $env:WINDIR + '\System32\cmd.exe"'),'NT AUTHORITY\LocalService')
        $caught=$false
        try { $unexpected=[AuthWire.Connector.OwnedProbeServiceV1]::Create($collision,('"' + $env:WINDIR + '\System32\cmd.exe"'),'NT AUTHORITY\LocalService'); $unexpected.Dispose() } catch {
            $e=$_.Exception
            while($null -ne $e.InnerException) {$e=$e.InnerException}
            Check ($e -is [System.ComponentModel.Win32Exception] -and $e.NativeErrorCode -eq 1073) 'Native existing-service collision is preserved'
            $caught=$true
        }
        Check ($caught -and [AuthWire.Connector.OwnedProbeServiceV1]::Exists($collision)) 'Collision leaves original owned fixture service present'
    } finally {
        if($null -ne $owned) {$owned.MarkForDeletion();$owned.Dispose()}
    }
    Check (-not [AuthWire.Connector.OwnedProbeServiceV1]::Exists($collision)) 'Unstarted collision fixture removed'
    $caught=$false
    try {$null=[AuthWire.Connector.OwnedProbeServiceV1]::Create('EventLog','unused','NT AUTHORITY\LocalService')} catch {$caught=$true}
    Check $caught 'Native controller refuses non-probe service names before SCM access'

    $caught=$false
    try {
        $null=& $source -Mode RunProbe -ExpectedComputer 'WRONG-HOST' -ExpectedDomain 'test.example' `
            -InstanceId ([guid]::NewGuid()) -AccountSid 'S-1-5-21-111-222-333-1234' `
            -BootstrapPath 'missing' -RightsToolPath 'missing' -PublisherThumbprint ('A'*40)
    } catch {
        Check ($_.Exception.Message -like '*LOCAL_COMPUTER_MISMATCH*') 'Full entry rejects wrong computer before any service or file creation'
        $caught=$true
    }
    Check $caught 'Full entry guard enforced'
    $text=[IO.File]::ReadAllText($source)
    Check ($text.Contains('CreateServiceW') -and $text.Contains('account, null)') -and -not $text.Contains('LsaAddAccountRights') -and -not $text.Contains('Set-ADServiceAccount')) 'Managed account uses NULL password without privilege or AD writes'
    Write-Output ('AUTHWIRE_SERVICE_LOGON_PROBE_NATIVE_OK ' + (@{
        checks=$checks;native_powershell=$PSVersionTable.PSVersion.ToString()
        actual_scm_service_tested=$true;runtime_identity='LocalService';native_service_runs=2
        signed_probe_executable_tested=$true;temporary_services_removed=$true
        real_customer_gmsa_tested=$false;real_customer_ad_tested=$false
        fixture_certificate_stores_modified=$true;private_keys_exported=0
    }|ConvertTo-Json -Compress))
} finally {
    foreach($folder in $folders) { if(Test-Path -LiteralPath $folder) {Remove-Item -LiteralPath $folder -Recurse -Force} }
    if($null -ne $publishers) {if($null -ne $public){$publishers.Remove($public)};$publishers.Dispose()}
    if($null -ne $roots) {if($null -ne $public){$roots.Remove($public)};$roots.Dispose()}
    if($null -ne $cert) {Remove-Item -LiteralPath ('Cert:\CurrentUser\My\' + $cert.Thumbprint) -DeleteKey -Force -ErrorAction SilentlyContinue;$cert.Dispose()}
    if($null -ne $public) {$public.Dispose()}
}
