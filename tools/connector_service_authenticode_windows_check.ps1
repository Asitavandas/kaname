# Disposable native Windows SCM/CNG fixture. Never uses customer AD, accounts or keys.
$ErrorActionPreference='Stop'
Set-StrictMode -Version 2
if($env:RUNNER_ENVIRONMENT -ne 'github-hosted'){throw 'Hosted fixture only'}
$source=Join-Path $PSScriptRoot '..\windows\connector\Test-AuthWireServiceAuthenticode.ps1'
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile($source,[ref]$tokens,[ref]$errors)
if($errors.Count){throw ($errors.Message -join '; ')}
$definitions=@($ast.EndBlock.Statements|Where-Object {$_ -is [Management.Automation.Language.FunctionDefinitionAst]})
. ([scriptblock]::Create(($definitions|ForEach-Object {$_.Extent.Text}) -join [Environment]::NewLine))
$script:checks=0
function Check([bool]$Value,[string]$Name){if(-not $Value){throw $Name};$script:checks++}
$publisher=$null;$signer=$null;$signerPublic=$null;$public=$null;$roots=$null;$publishers=$null;$folders=@()
try{
    $publisher=New-SelfSignedCertificate -Type CodeSigningCert -Subject 'CN=AuthWire signing probe executable fixture' -CertStoreLocation 'Cert:\CurrentUser\My' -KeyLength 2048 -HashAlgorithm SHA256 -KeyExportPolicy NonExportable -NotAfter (Get-Date).AddDays(1)
    $public=[Security.Cryptography.X509Certificates.X509Certificate2]::new($publisher.RawData)
    $roots=[Security.Cryptography.X509Certificates.X509Store]::new('Root','LocalMachine')
    $roots.Open([Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite);$roots.Add($public)
    $publishers=[Security.Cryptography.X509Certificates.X509Store]::new('TrustedPublisher','LocalMachine')
    $publishers.Open([Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite);$publishers.Add($public)
    $signer=New-SelfSignedCertificate -Type CodeSigningCert -Subject 'CN=AuthWire isolated machine RSA signing fixture' -CertStoreLocation 'Cert:\LocalMachine\My' -Provider 'Microsoft Software Key Storage Provider' -KeyLength 3072 -HashAlgorithm SHA256 -KeyUsage DigitalSignature -KeyUsageProperty Sign -KeyExportPolicy NonExportable -NotAfter (Get-Date).AddDays(1)
    $rsa=[Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($signer)
    try{
        Check ($rsa -is [Security.Cryptography.RSACng] -and $rsa.Key.IsMachineKey -and [int]$rsa.Key.ExportPolicy -eq 0 -and [int]$rsa.Key.KeyUsage -eq 2) 'Actual machine CNG non-exportable signing-only key'
        $keyPath=Join-Path (Join-Path $env:ProgramData 'Microsoft\Crypto\Keys') $rsa.Key.UniqueName
    }finally{$rsa.Dispose()}
    $acl=Get-Acl -LiteralPath $keyPath
    $acl.SetSecurityDescriptorSddlForm('D:P(A;;FA;;;SY)(A;;FA;;;BA)')
    Set-Acl -LiteralPath $keyPath -AclObject $acl
    $r=Invoke-AuthWireServiceProbeCore -RuntimeAccount 'NT AUTHORITY\LocalService' -ExpectedSid 'S-1-5-19' -PublisherThumbprint $publisher.Thumbprint -SignerThumbprint $signer.Thumbprint
    $folders+=Split-Path -Parent $r.EvidencePath
    Write-Host ('AUTHENTICODE_FIXTURE_RESULT '+($r|ConvertTo-Json -Depth 6 -Compress))
    Check (-not $r.ProbeVerified -and -not $r.ServiceKeyAccessVerified -and -not $r.SignatureVerified) 'Real service without key Read cannot prove signing'
    Check ($r.ServiceCreated -and $r.TemporaryServiceRemoved -and $r.TemporaryBinaryRemoved -and $r.TemporaryResultDirectoryRemoved) 'Denied-key service is also cleaned up'
    $acl=Get-Acl -LiteralPath $keyPath
    $rule=[Security.AccessControl.FileSystemAccessRule]::new([Security.Principal.SecurityIdentifier]::new('S-1-5-19'),[Security.AccessControl.FileSystemRights]::Read,[Security.AccessControl.AccessControlType]::Allow)
    $acl.AddAccessRule($rule);Set-Acl -LiteralPath $keyPath -AclObject $acl
    $r=Invoke-AuthWireServiceProbeCore -RuntimeAccount 'NT AUTHORITY\LocalService' -ExpectedSid 'S-1-5-19' -PublisherThumbprint $publisher.Thumbprint -SignerThumbprint $signer.Thumbprint
    $folders+=Split-Path -Parent $r.EvidencePath
    Write-Host ('AUTHENTICODE_FIXTURE_RESULT '+($r|ConvertTo-Json -Depth 6 -Compress))
    Check (-not $r.ProbeVerified -and -not $r.AuthenticodePackageSigningVerified) 'Untrusted signer cannot pass Authenticode Valid check'
    Check ($r.TemporaryServiceRemoved -and $r.TemporaryBinaryRemoved -and $r.TemporaryResultDirectoryRemoved) 'Untrusted-signature worker cleaned up'
    $signerPublic=[Security.Cryptography.X509Certificates.X509Certificate2]::new($signer.RawData)
    $roots.Add($signerPublic)
    $before=(Get-Acl -LiteralPath $keyPath).Sddl
    $r=Invoke-AuthWireServiceProbeCore -RuntimeAccount 'NT AUTHORITY\LocalService' -ExpectedSid 'S-1-5-19' -PublisherThumbprint $publisher.Thumbprint -SignerThumbprint $signer.Thumbprint
    $folders+=Split-Path -Parent $r.EvidencePath
    Write-Host ('AUTHENTICODE_FIXTURE_RESULT '+($r|ConvertTo-Json -Depth 6 -Compress))
    if(-not $r.ProbeVerified){throw ('Signing fixture failed: '+($r|ConvertTo-Json -Compress -Depth 6))}
    Check ($r.ServiceLogonVerified -and $r.SignatureVerified -and $r.ServiceKeyAccessVerified -and $r.RuntimeSid -eq 'S-1-5-19' -and $r.RuntimeProcessId -gt 0) 'Actual signed SCM worker uses machine key under low-privilege service identity'
    Check ($r.TemporaryServiceRemoved -and $r.TemporaryBinaryRemoved -and $r.TemporaryResultDirectoryRemoved -and $r.CleanupErrors.Count -eq 0) 'Successful worker service and transient artifacts removed'
    Check ((Get-Acl -LiteralPath $keyPath).Sddl -ceq $before -and -not $r.KeyAclChanged -and -not $r.SecretsExported) 'Probe does not alter key ACL or export private keys'
    Check ($r.AuthenticodePackageSigningVerified -and $r.AuthenticodeSignatureVerified -and -not $r.ArtifactExecuted -and -not $r.ConnectorInstalled -and -not $r.CanApplyGpo) 'Actual Authenticode signing and independent verification pass without artifact execution/deployment'
    Check (Test-Path -LiteralPath $r.EvidenceArtifactPath) 'Public signed audit artifact retained'
    Check ((Get-AuthenticodeSignature -FilePath $r.EvidenceArtifactPath).Status.ToString() -eq 'Valid') 'Retained audit artifact has a valid native Authenticode signature'
    $proof=Get-Content -LiteralPath (Join-Path (Split-Path -Parent $r.EvidencePath) 'verified-proof.json') -Raw|ConvertFrom-Json
    Check (Test-AuthWireSigningProof -Proof $proof -Certificate $signer) 'Public RSA verification independently validates service signature'
    foreach($case in @('nonce','name','host','sid','pid','thumbprint','signature','invalidBase64','oversizedSignature','missingPolicy','typedBoolean')){
        $changed=$proof|ConvertTo-Json|ConvertFrom-Json
        switch($case){
            'nonce' {$changed.Nonce=[guid]::NewGuid().ToString('N')}
            'name' {$changed.ServiceName='OtherService'}
            'host' {$changed.Computer='OtherHost'}
            'sid' {$changed.IdentitySid='S-1-5-20'}
            'pid' {$changed.ProcessId++}
            'thumbprint' {$changed.SignerThumbprint='A'*40}
            'signature' {$bytes=[Convert]::FromBase64String($changed.SignatureBase64);$bytes[0]=$bytes[0] -bxor 1;$changed.SignatureBase64=[Convert]::ToBase64String($bytes)}
            'invalidBase64' {$changed.SignatureBase64='!notbase64'}
            'oversizedSignature' {$changed.SignatureBase64='A'*1025}
            'missingPolicy' {$changed.SigningKeyPropertiesVerified=$false}
            'typedBoolean' {$changed.SigningKeyPropertiesVerified='true'}
        }
        Check (-not (Test-AuthWireSigningProof -Proof $changed -Certificate $signer)) ('Crypto proof rejects '+$case)
    }
    Check (-not (Test-AuthWireSigningProof -Proof $proof -Certificate $publisher)) 'Different certificate cannot validate signature'
    Check (Test-AuthWireAuthenticodeArtifact $r.EvidenceArtifactPath $signer.Thumbprint $proof.AuthenticodeArtifactSha256) 'Controller artifact verifier validates actual signed content'
    Check (-not (Test-AuthWireAuthenticodeArtifact $r.EvidenceArtifactPath $publisher.Thumbprint $proof.AuthenticodeArtifactSha256)) 'Wrong Authenticode signer rejected'
    Check (-not (Test-AuthWireAuthenticodeArtifact $r.EvidenceArtifactPath $signer.Thumbprint ('A'*64))) 'Different artifact bytes rejected'
    $tampered=Join-Path (Split-Path -Parent $r.EvidencePath) 'tampered.ps1'
    [IO.File]::WriteAllText($tampered,("# changed"+[Environment]::NewLine+[IO.File]::ReadAllText($r.EvidenceArtifactPath)),[Text.Encoding]::Unicode)
    $tamperedHash=(Get-FileHash -LiteralPath $tampered -Algorithm SHA256).Hash
    Check (-not (Test-AuthWireAuthenticodeArtifact $tampered $signer.Thumbprint $tamperedHash)) 'Changed signed body rejected even with its current matching file hash'
    Check ((Get-AuthenticodeSignature -FilePath $tampered).Status.ToString() -ne 'Valid') 'Windows itself rejects changed signed body'
    $caught=$false;try{$null=Get-AuthWireProbeExecutableSource -SignerThumbprint 'bad";'}catch{$caught=$true}
    Check $caught 'Exact thumbprint guard prevents source injection'
    $caught=$false
    try{
        $null=& $source -Mode RunProbe -ExpectedComputer 'WRONG-HOST' -ExpectedDomain 'test.example' -InstanceId ([guid]::NewGuid()) -AccountSid 'S-1-5-21-111-222-333-1648' -BootstrapPath 'missing' -RightsToolPath 'missing' -PublisherThumbprint ('A'*40) -SignerThumbprint ('B'*40) -KeyAccessReceiptPath 'missing'
    }catch{$caught=$_.Exception.Message -like '*LOCAL_COMPUTER_MISMATCH*'}
    Check $caught 'Full production entry refuses wrong host before service creation'
    $text=[IO.File]::ReadAllText($source)
    Check (-not $text.Contains('Export-PfxCertificate') -and -not $text.Contains('ExportParameters') -and -not $text.Contains('LsaAddAccountRights') -and -not $text.Contains('Set-ADServiceAccount') -and -not $text.Contains('Set-AuthenticodeSignature -Certificate $signer')) 'No key export, logon-right or AD mutation path'
    Check (-not $text.Contains('AddScript(') -and -not $text.Contains('-ExecutionPolicy') -and $text.Contains('PSLanguageMode.NoLanguage')) 'SDK invokes fixed signing cmdlets without script execution or execution-policy override'
    Write-Output ('AUTHWIRE_SERVICE_AUTHENTICODE_NATIVE_OK '+(@{checks=$checks;actual_signed_scm_service=$true;actual_nonexportable_cng_signing=$true;runtime_identity='LocalService';native_service_runs=3;denied_without_key_read=$true;actual_authenticode_signed_and_verified=$true;untrusted_signer_rejected=$true;artifact_executed=$false;customer_gmsa_tested=$false;customer_keys_used=$false;private_keys_exported=0;native_powershell=$PSVersionTable.PSVersion.ToString()}|ConvertTo-Json -Compress))
}finally{
    foreach($folder in $folders){if(Test-Path -LiteralPath $folder){Remove-Item -LiteralPath $folder -Recurse -Force}}
    if($null -ne $publishers){if($null -ne $public){$publishers.Remove($public)};$publishers.Dispose()}
    if($null -ne $roots){if($null -ne $signerPublic){$roots.Remove($signerPublic)};if($null -ne $public){$roots.Remove($public)};$roots.Dispose()}
    if($null -ne $signer){Remove-Item -LiteralPath ('Cert:\LocalMachine\My\'+$signer.Thumbprint) -DeleteKey -Force -ErrorAction SilentlyContinue;$signer.Dispose()}
    if($null -ne $publisher){Remove-Item -LiteralPath ('Cert:\CurrentUser\My\'+$publisher.Thumbprint) -DeleteKey -Force -ErrorAction SilentlyContinue;$publisher.Dispose()}
    if($null -ne $signerPublic){$signerPublic.Dispose()}
    if($null -ne $public){$public.Dispose()}
}
