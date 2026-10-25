# Disposable hosted Windows only: real provider metadata; AD/CA discovery is simulated.
$ErrorActionPreference='Stop'
Set-StrictMode -Version 2
if($env:RUNNER_ENVIRONMENT -ne 'github-hosted'){throw 'Hosted fixture only.'}
Import-Module ActiveDirectory -ErrorAction Stop
$source=Join-Path $PSScriptRoot '..\windows\connector\Get-AuthWireSigningReadiness.ps1'
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile($source,[ref]$tokens,[ref]$errors)
if($errors.Count){throw ($errors.Message -join '; ')}
$functions=@($ast.EndBlock.Statements|Where-Object {$_ -is [Management.Automation.Language.FunctionDefinitionAst]})
. ([scriptblock]::Create(($functions|ForEach-Object {$_.Extent.Text}) -join [Environment]::NewLine))
$script:checks=0
function Check([bool]$Value,[string]$Name){if(-not $Value){throw $Name};$script:checks++}
function Wrapped($Value){
    $collection=New-Object Microsoft.ActiveDirectory.Management.ADPropertyValueCollection
    foreach($entry in $Value){$null=$collection.Add($entry)}
    return ,$collection
}
function Template {
    $security=New-Object DirectoryServices.ActiveDirectorySecurity
    $security.AddAccessRule([DirectoryServices.ActiveDirectoryAccessRule]::new([Security.Principal.SecurityIdentifier]::new('S-1-5-21-111-222-333-1648'),[DirectoryServices.ActiveDirectoryRights]::ExtendedRight,[Security.AccessControl.AccessControlType]::Allow,[guid]'0e10c968-78fb-11d2-90d4-00c04f79dc55'))
    [pscustomobject]@{Name='AuthWireSigning';DisplayName='AuthWire signing';DistinguishedName='CN=AuthWireSigning,CN=Certificate Templates,CN=Public Key Services,CN=Services,CN=Configuration,DC=test,DC=example'
        flags=(Wrapped 64);pKIExtendedKeyUsage=(Wrapped '1.3.6.1.5.5.7.3.3');'msPKI-Certificate-Application-Policy'=(Wrapped '1.3.6.1.5.5.7.3.3')
        'msPKI-Private-Key-Flag'=(Wrapped 0);'msPKI-Certificate-Name-Flag'=(Wrapped 0);'msPKI-Enrollment-Flag'=(Wrapped 0)
        'msPKI-Template-Schema-Version'=(Wrapped 4);'msPKI-Minimal-Key-Size'=(Wrapped 3072)
        pKIDefaultCSPs=(Wrapped '1,Microsoft Software Key Storage Provider');nTSecurityDescriptor=$security}
}
$certs=@();$public=$null
$fake=Join-Path $env:RUNNER_TEMP ('AuthWire-Signing-Bootstrap-'+[guid]::NewGuid().ToString('N')+'.ps1')
@'
param($Mode,$ExpectedDomain,$ConnectorComputer,$InstanceId,$AccountName,$PublisherThumbprint)
if($Mode -ne 'Inspect'){throw 'Mutation mode attempted.'}
$global:AwSigningFixture.Account|ConvertTo-Json -Depth 6
'@|Set-Content -LiteralPath $fake -Encoding UTF8
try{
    $cert=New-SelfSignedCertificate -Type CodeSigningCert -Subject 'CN=AuthWire user CNG metadata fixture' -CertStoreLocation 'Cert:\CurrentUser\My' -Provider 'Microsoft Software Key Storage Provider' -KeyExportPolicy NonExportable -NotAfter (Get-Date).AddDays(1)
    $certs+=@{Certificate=$cert;Store='Cert:\CurrentUser\My'}
    $user=Get-AuthWireSigningCertificateMetadata $cert 'Cert:\CurrentUser\My'
    Check ($user.CodeSigningOnly -and $user.CurrentlyValid -and $user.HasPrivateKeyMetadata -and $user.ProviderMetadata.Available -and $user.ProviderMetadata.Cng -and -not $user.ProviderMetadata.MachineKeySet) 'Actual user CNG certificate metadata remains user-scoped'
    Check ($user.ProviderMetadata.ContainerNameSha256.Length -eq 64 -and -not $user.PrivateKeyUseTested -and -not $user.ServiceKeyAccessVerified) 'HasPrivateKey and provider metadata never imply service use'
    $machine=New-SelfSignedCertificate -Type CodeSigningCert -Subject 'CN=AuthWire machine CNG metadata fixture' -CertStoreLocation 'Cert:\LocalMachine\My' -Provider 'Microsoft Software Key Storage Provider' -KeyExportPolicy NonExportable -NotAfter (Get-Date).AddDays(1)
    $certs+=@{Certificate=$machine;Store='Cert:\LocalMachine\My'}
    $info=Get-AuthWireSigningCertificateMetadata $machine 'Cert:\LocalMachine\My'
    Check ($info.ProviderMetadata.MachineKeySet -and $info.ProviderMetadata.Cng -and $info.CodeSigningOnly) 'Actual machine CNG keyset flag is decoded without key acquisition'
    $csp=New-SelfSignedCertificate -Type CodeSigningCert -Subject 'CN=AuthWire legacy CSP metadata fixture' -CertStoreLocation 'Cert:\LocalMachine\My' -Provider 'Microsoft Enhanced RSA and AES Cryptographic Provider' -KeySpec Signature -KeyExportPolicy NonExportable -NotAfter (Get-Date).AddDays(1)
    $certs+=@{Certificate=$csp;Store='Cert:\LocalMachine\My'}
    $info=Get-AuthWireSigningCertificateMetadata $csp 'Cert:\LocalMachine\My'
    Check ($info.ProviderMetadata.MachineKeySet -and -not $info.ProviderMetadata.Cng -and $info.ProviderMetadata.ProviderType -eq 24 -and $info.ProviderMetadata.KeySpec -eq 2) 'Actual legacy CSP metadata shape decoded separately'
    $public=[Security.Cryptography.X509Certificates.X509Certificate2]::new($cert.RawData)
    $info=Get-AuthWireSigningCertificateMetadata $public 'memory-public-only'
    Check (-not $info.HasPrivateKeyMetadata -and -not $info.ProviderMetadata.Available -and -not $info.ServiceKeyAccessVerified) 'Public certificate has no provider-key metadata and proves no key access'
    Check ((Get-AuthWireSigningFlags (Wrapped 64) 'flags') -eq 64 -and (Get-AuthWireSigningFlags (Wrapped -1) 'flags') -eq [uint32]::MaxValue) 'Genuine AD collections and signed bitfields normalize'
    foreach($bad in @($null,(Wrapped @()),(Wrapped @(1,2)),$true,'not-a-number','4294967296',1.5)){
        $caught=$false;try{$null=Get-AuthWireSigningFlags $bad 'fixture'}catch{$caught=$true}
        Check $caught 'Malformed or ambiguous AD integer is rejected'
    }
    Check (@(Get-AuthWireSigningStringValues $null 'empty').Count -eq 0 -and @(Get-AuthWireSigningStringValues (Wrapped @()) 'empty').Count -eq 0) 'Missing and genuinely empty AD string attributes are empty arrays'
    $authority=[pscustomobject]@{Configuration='dc.test.example\Test CA';PublishedTemplates=@('AuthWireSigning')}
    $shape=Get-AuthWireSigningTemplateShape (Template) @($authority)
    Check ($shape.ShapeCompatible -and $shape.MachineType -and $shape.CodeSigningOnly -and $shape.PublishedBy.Count -eq 1) 'Machine-only signing template format can be reviewed'
    Check (-not $shape.AutomaticallyApproved -and -not $shape.EffectiveEnrollmentRightsEvaluated -and $shape.EnrollmentAclRead -and $shape.EnrollmentAces.Count -eq 1) 'Template shape and raw enrollment ACE never imply authorization'
    foreach($case in @('user','export','archive','interactive','subject','ca','crossCa','mixedEku','mixedApplication','unpublished','smallKey')){
        $template=Template;$authorities=@($authority)
        switch($case){
            'user' {$template.flags=Wrapped 0}
            'export' {$template.'msPKI-Private-Key-Flag'=Wrapped 16}
            'archive' {$template.'msPKI-Private-Key-Flag'=Wrapped 1}
            'interactive' {$template.'msPKI-Private-Key-Flag'=Wrapped 32}
            'subject' {$template.'msPKI-Certificate-Name-Flag'=Wrapped 1}
            'ca' {$template.flags=Wrapped 192}
            'crossCa' {$template.flags=Wrapped 2112}
            'mixedEku' {$template.pKIExtendedKeyUsage=Wrapped @('1.3.6.1.5.5.7.3.3','1.3.6.1.5.5.7.3.2')}
            'mixedApplication' {$template.'msPKI-Certificate-Application-Policy'=Wrapped @('1.3.6.1.5.5.7.3.3','2.5.29.37.0')}
            'unpublished' {$authorities=@()}
            'smallKey' {$template.'msPKI-Minimal-Key-Size'=Wrapped 1024}
        }
        $shape=Get-AuthWireSigningTemplateShape $template $authorities
        Check (-not $shape.ShapeCompatible -and -not $shape.AutomaticallyApproved) ('Unsafe/inapplicable template not ready: '+$case)
    }
    $computer=[Environment]::MachineName
    $instance=[guid]'4c23eebe-0715-46d1-88ee-a2e96ad7ee46'
    $sid='S-1-5-21-111-222-333-1648'
    $global:AwSigningFixture=@{
        Signature=$true;Root='CN=Configuration,DC=test,DC=example';DirectoryFail=$false
        TemplateRows=@((Template))
        Account=[pscustomobject]@{Event='WINDOWS_CONNECTOR_BOOTSTRAP';BootstrapVersion='1.0.3';Mode='Inspect';Computer=$computer;Domain='test.example'
            InstanceId=$instance.ToString('D');ConnectorComputerGuid='0fa4143f-aae3-4bc3-9cd3-db8a1de24acd'
            Account=[pscustomobject]@{Exists=$true;Sid=$sid;Name='aw-deploy$'};ReadyForAccountPreparation=$true;Blockers=@()
            AdChanged=$false;GpoChanged=$false;CertificatesChanged=$false}
    }
    function Get-AuthenticodeSignature {[CmdletBinding()]param($FilePath)
        [pscustomobject]@{Status=$(if($global:AwSigningFixture.Signature){'Valid'}else{'HashMismatch'});SignerCertificate=[pscustomobject]@{Thumbprint=$cert.Thumbprint}}}
    function Import-Module {[CmdletBinding()]param($Name)}
    function Get-ADDomain {[CmdletBinding()]param($Server)
        [pscustomobject]@{DNSRoot='test.example';DomainSID=[Security.Principal.SecurityIdentifier]::new('S-1-5-21-111-222-333')}}
    function Get-ChildItem {[CmdletBinding()]param($Path)
        if($Path -eq 'Cert:\CurrentUser\My'){return $cert}
        if($Path -notin @('Cert:\LocalMachine\My','Cert:\CurrentUser\TrustedPublisher','Cert:\LocalMachine\TrustedPublisher')){throw 'Unexpected certificate store access'}}
    function Get-ADRootDSE {[CmdletBinding()]param($Server)
        [pscustomobject]@{configurationNamingContext=$global:AwSigningFixture.Root}}
    function Get-ADObject {[CmdletBinding()]param($Server,$SearchBase,$SearchScope,$LDAPFilter,$Properties)
        if($global:AwSigningFixture.DirectoryFail){throw 'DIRECTORY_READ_FAILURE'}
        if($SearchScope -ne 'OneLevel' -or $Server -ine ($computer+'.test.example')){throw 'Directory scope escaped'}
        if($SearchBase -like 'CN=Enrollment Services,*'){return [pscustomobject]@{Name='Test CA';dNSHostName=(Wrapped 'dc.test.example');certificateTemplates=(Wrapped 'AuthWireSigning')}}
        if($SearchBase -like 'CN=Certificate Templates,*'){return $global:AwSigningFixture.TemplateRows}
        throw 'Unexpected directory base'
    }
    $inspectionParams=@{ExpectedComputer=$computer;ExpectedDomain='test.example';InstanceId=$instance;AccountName='aw-deploy';AccountSid=$sid;BootstrapPath=$fake;PublisherThumbprint=$cert.Thumbprint}
    $result=Invoke-AuthWireSigningInspection @inspectionParams
    Check ($result.InspectionSucceeded -and $result.ShapeCompatibleTemplateCount -eq 1 -and $result.CodeSigningTemplates.Count -eq 1) 'Complete readonly inspection combines native cert metadata and simulated CA directory'
    Check (-not $result.AdChanged -and -not $result.GpoChanged -and -not $result.CertificatesChanged -and -not $result.KeyAclChanged -and -not $result.TrustStoreChanged -and -not $result.EnrollmentRequested) 'Readiness performs no AD/CA/key/trust mutations'
    Check (-not $result.ReadyForAutomatedSigning -and -not $result.ServiceKeyAccessVerified -and -not $result.ConnectorInstalled -and -not $result.CanApplyGpo -and $result.NewPublisherTrustDistributionPending) 'Inventory is not signing or deployment acceptance'
    $unrelated=Template
    $unrelated.Name='ServerAuthentication'
    $unrelated.pKIExtendedKeyUsage=Wrapped '1.3.6.1.5.5.7.3.1'
    $unrelated.'msPKI-Certificate-Application-Policy'=Wrapped '1.3.6.1.5.5.7.3.1'
    Check (@(Get-AuthWireSigningTemplateShape $unrelated @($authority)).Count -eq 0) 'Unrelated template emits no null pipeline record'
    foreach($case in @('mixed','allUnrelated','empty','allNull')){
        switch($case){
            'mixed' {$global:AwSigningFixture.TemplateRows=@($null,(Template),$unrelated,$null)}
            'allUnrelated' {$global:AwSigningFixture.TemplateRows=@($null,$unrelated)}
            'empty' {$global:AwSigningFixture.TemplateRows=@()}
            'allNull' {$global:AwSigningFixture.TemplateRows=@($null,$null)}
        }
        $inventory=Invoke-AuthWireSigningInspection @inspectionParams
        $expectedCount=$(if($case -eq 'mixed'){1}else{0})
        Check ($inventory.ToolVersion -eq '1.0.1' -and $inventory.InspectionSucceeded -and $inventory.CodeSigningTemplates.Count -eq $expectedCount -and
            $inventory.ShapeCompatibleTemplateCount -eq $expectedCount) ('Mixed/empty template discovery succeeds: '+$case)
        $roundtrip=$inventory|ConvertTo-Json -Depth 10|ConvertFrom-Json
        Check ($roundtrip.CodeSigningTemplates -is [array] -and $roundtrip.CodeSigningTemplates.Count -eq $expectedCount -and
            @($roundtrip.CodeSigningTemplates|Where-Object {$null -eq $_}).Count -eq 0) 'JSON contains a real template array without null entries'
        Check (-not $inventory.EnrollmentRequested -and -not $inventory.KeyAclChanged -and -not $inventory.CertificatesChanged -and
            -not $inventory.ReadyForAutomatedSigning) 'Zero/mixed template inventory never requests or approves a signer'
    }
    $malformed=Template
    $malformed.'msPKI-Private-Key-Flag'=Wrapped 'invalid'
    $global:AwSigningFixture.TemplateRows=@($unrelated,$malformed)
    $caught=$false
    try{$null=Invoke-AuthWireSigningInspection @inspectionParams}catch{$caught=$_.Exception.Message -like '*INVALID_INTEGER_ATTRIBUTE*'}
    Check $caught 'Malformed relevant signing template still fails rather than being hidden by null filtering'
    $global:AwSigningFixture.TemplateRows=@((Template))
    foreach($case in @('host','signature','account','root','directory')){
        $global:AwSigningFixture.Signature=$true;$global:AwSigningFixture.Account.Account.Sid=$sid;$global:AwSigningFixture.Root='CN=Configuration,DC=test,DC=example';$global:AwSigningFixture.DirectoryFail=$false
        $values=$inspectionParams.Clone()
        switch($case){
            'host' {$values.ExpectedComputer='WRONG-HOST'}
            'signature' {$global:AwSigningFixture.Signature=$false}
            'account' {$global:AwSigningFixture.Account.Account.Sid='S-1-5-21-111-222-333-1649'}
            'root' {$global:AwSigningFixture.Root=Wrapped @()}
            'directory' {$global:AwSigningFixture.DirectoryFail=$true}
        }
        $caught=$false;try{$null=Invoke-AuthWireSigningInspection @values}catch{$caught=$true}
        Check $caught ('Readonly gate rejects '+$case)
    }
    $text=[IO.File]::ReadAllText($source)
    Check (-not $text.Contains('CryptAcquireCertificatePrivateKey') -and -not $text.Contains('GetRSAPrivateKey') -and -not $text.Contains('Export-PfxCertificate') -and -not $text.Contains('Set-Acl') -and -not $text.Contains('New-SelfSignedCertificate')) 'Production reader contains no key-acquisition/export/creation or ACL-write API'
    Write-Output ('AUTHWIRE_SIGNING_READINESS_NATIVE_OK '+(@{checks=$checks;native_powershell=$PSVersionTable.PSVersion.ToString();actual_cng_and_csp_metadata_tested=$true
        real_customer_ad_ca_tested=$false;directory_calls_simulated=$true;private_key_use_tested=$false;private_keys_exported=0;fixture_certificates_created=3
        production_has_no_mutation_mode=$true}|ConvertTo-Json -Compress))
}finally{
    foreach($entry in $certs){
        Microsoft.PowerShell.Management\Remove-Item -LiteralPath ($entry.Store+'\'+$entry.Certificate.Thumbprint) -DeleteKey -Force -ErrorAction SilentlyContinue
        $entry.Certificate.Dispose()
    }
    if($null -ne $public){$public.Dispose()}
    Microsoft.PowerShell.Management\Remove-Item -LiteralPath $fake -Force -ErrorAction SilentlyContinue
    Remove-Variable AwSigningFixture -Scope Global -ErrorAction SilentlyContinue
}
