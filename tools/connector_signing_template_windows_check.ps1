$ErrorActionPreference='Stop'
Set-StrictMode -Version 2
if($env:RUNNER_ENVIRONMENT -ne 'github-hosted'){throw 'Hosted fixture only.'}
Import-Module ActiveDirectory
Add-Type -AssemblyName System.DirectoryServices.Protocols
$source=Join-Path $PSScriptRoot '..\windows\connector\Initialize-AuthWireSigningTemplate.ps1'
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile($source,[ref]$tokens,[ref]$errors)
if($errors.Count){throw ($errors.Message -join '; ')}
$defs=@($ast.EndBlock.Statements|Where-Object {$_ -is [Management.Automation.Language.FunctionDefinitionAst]})
. ([scriptblock]::Create(($defs|ForEach-Object {$_.Extent.Text}) -join [Environment]::NewLine))
$script:checks=0
function Check([bool]$Value,[string]$Name){if(-not $Value){throw $Name};$script:checks++}
$script:fixtureComputer=[Environment]::MachineName;$instance=[guid]'4c23eebe-0715-46d1-88ee-a2e96ad7ee46';$hostGuid=[guid]'0fa4143f-aae3-4bc3-9cd3-db8a1de24acd'
$domainSid='S-1-5-21-111-222-333';$serviceSid=$domainSid+'-1648';$machineSid=$domainSid+'-1001';$publisher='A'*40
$pki='CN=Public Key Services,CN=Services,CN=Configuration,DC=test,DC=example'
$prefix='1.3.6.1.4.1.311.21.8.100.200.300.400.500.1'
$plan=Get-AuthWireSigningTemplatePlan $instance $hostGuid $domainSid $serviceSid $machineSid $pki $prefix
Check ($plan.Name -eq 'AuthWireConnectorCodeSigning-4c23eebe' -and $plan.TemplateDn -eq ('CN='+$plan.Name+',CN=Certificate Templates,'+$pki)) 'Template name and DN are instance bounded'
$repeat=Get-AuthWireSigningTemplatePlan $instance $hostGuid $domainSid $serviceSid $machineSid $pki $prefix
Check ($plan.Oid -eq $repeat.Oid -and $plan.Oid.StartsWith($prefix+'.')) 'OID is deterministic below the forest-specific prefix'
Check ($plan.Attributes.'msPKI-Template-Schema-Version' -eq 3 -and $plan.Attributes.flags -eq 64 -and $plan.Attributes.'msPKI-Minimal-Key-Size' -eq 3072) 'Machine CNG template schema and key length bounded'
Check ($plan.Attributes.'msPKI-Private-Key-Flag' -eq 0 -and $plan.Attributes.'msPKI-Enrollment-Flag' -eq 0 -and $plan.Attributes.'msPKI-Certificate-Name-Flag' -eq 268435456) 'No export/archive/UI/subject supply/auto-enrollment flags'
Check (@($plan.Attributes.pKIExtendedKeyUsage).Count -eq 1 -and $plan.Attributes.pKIExtendedKeyUsage[0] -eq '1.3.6.1.5.5.7.3.3' -and @($plan.Attributes.'msPKI-Certificate-Application-Policy').Count -eq 1) 'Only code signing EKU and application policy'
Check ([BitConverter]::ToInt64($plan.Attributes.pKIExpirationPeriod,0) -eq -[timespan]::FromDays(365).Ticks -and [BitConverter]::ToInt64($plan.Attributes.pKIOverlapPeriod,0) -eq -[timespan]::FromDays(30).Ticks) 'Validity/renewal windows are negative AD intervals'
Check ($plan.Attributes.'msPKI-RA-Application-Policies'[0].Contains('SHA256') -and $plan.Attributes.'msPKI-RA-Application-Policies'[0].Contains('RSA')) 'CNG algorithm property triplets are explicit'
$acl=$plan.TemplateAcl
$enroll=@($acl.Rules|Where-Object {($_.Rights -band 256) -ne 0 -and $_.ObjectType -eq '0e10c968-78fb-11d2-90d4-00c04f79dc55'})
Check ($acl.Protected -and $acl.Owner -eq ($domainSid+'-512') -and $enroll.Count -eq 1 -and $enroll[0].Sid -eq $machineSid) 'Only exact enrolling machine receives explicit Enroll'
Check (@($acl.Rules|Where-Object Sid -eq $serviceSid).Count -eq 0 -and @($acl.Rules|Where-Object {$_.Sid -eq 'S-1-5-11' -and ($_.Rights -band 256) -ne 0}).Count -eq 0) 'Service and broad authenticated users receive no enrollment/control grant'
$request=New-AuthWireDirectoryAddRequest $plan.TemplateDn 'pKICertificateTemplate' $plan.Attributes
$cn=@($request.Attributes|Where-Object Name -eq 'cn')
$sd=@($request.Attributes|Where-Object Name -eq 'nTSecurityDescriptor')
$ku=@($request.Attributes|Where-Object Name -eq 'pKIKeyUsage')
Check ($request -is [DirectoryServices.Protocols.AddRequest] -and $request.DistinguishedName -eq $plan.TemplateDn -and $sd.Count -eq 1 -and $sd[0].Count -eq 1 -and $sd[0][0] -is [byte[]]) 'Real LDAP AddRequest includes atomic binary security descriptor'
Check ($ku.Count -eq 1 -and $ku[0].Count -eq 1 -and [Convert]::ToBase64String($ku[0][0]) -eq 'gAA=') 'Binary key usage remains one binary value'
Check ($cn.Count -eq 1 -and $cn[0][0] -eq $plan.Name) 'LDAP request explicitly includes the owned CN naming attribute'
foreach($case in @('root','instance','host','serviceScope','sameSid')){
    $values=@{InstanceId=$instance;HostGuid=$hostGuid;DomainSid=$domainSid;ServiceSid=$serviceSid;MachineSid=$machineSid;PkiBase=$pki;ForestOidPrefix=$prefix}
    switch($case){
        'root' {$values.ForestOidPrefix='1.2.3'}
        'instance' {$values.InstanceId=[guid]::Empty}
        'host' {$values.HostGuid=[guid]::Empty}
        'serviceScope' {$values.ServiceSid='S-1-5-21-999-222-333-1648'}
        'sameSid' {$values.MachineSid=$serviceSid}
    }
    $caught=$false;try{$null=Get-AuthWireSigningTemplatePlan @values}catch{$caught=$true}
    Check $caught ('Plan rejects '+$case)
}
function Wrap($Value){
    $c=New-Object Microsoft.ActiveDirectory.Management.ADPropertyValueCollection
    foreach($v in $Value){$null=$c.Add($v)}
    return ,$c
}
function Make-Object([string]$Class,[string]$Name,[string]$Dn,$Attributes){
    $obj=[ordered]@{ObjectClass=$Class;ObjectGUID=[guid]::NewGuid();Name=$Name;DistinguishedName=$Dn}
    foreach($key in $Attributes.Keys){
        $value=$Attributes[$key]
        if($key -eq 'nTSecurityDescriptor'){
            $security=New-Object DirectoryServices.ActiveDirectorySecurity;$security.SetSecurityDescriptorBinaryForm($value);$obj[$key]=$security
        }elseif($value -is [byte[]]){$obj[$key]=$value}
        else{$obj[$key]=Wrap $value}
    }
    return [pscustomobject]$obj
}
$fake=Join-Path $env:RUNNER_TEMP ('AuthWire-Template-Readiness-'+[guid]::NewGuid().ToString('N')+'.ps1')
@'
param($Mode,$ExpectedComputer,$ExpectedDomain,$InstanceId,$AccountName,$AccountSid,$BootstrapPath,$PublisherThumbprint)
if($Mode -ne 'Inspect'){throw 'Readiness mutation attempted'}
$global:AwTemplateFixture.Inspection|ConvertTo-Json -Depth 8
'@|Set-Content -LiteralPath $fake -Encoding UTF8
$script:folders=@()
function Reset-Fixture {
    $sourceObject=Make-Object 'pKICertificateTemplate' 'AuthWireGPOCodeSigning' ('CN=AuthWireGPOCodeSigning,CN=Certificate Templates,'+$pki) $plan.Attributes
    $sourceObject.flags=Wrap 0
    $caSecurity=New-Object DirectoryServices.ActiveDirectorySecurity
    $caSecurity.SetOwner([Security.Principal.SecurityIdentifier]::new($domainSid+'-512'))
    $caSecurity.SetGroup([Security.Principal.SecurityIdentifier]::new($domainSid+'-512'))
    $caSecurity.AddAccessRule([DirectoryServices.ActiveDirectoryAccessRule]::new([Security.Principal.SecurityIdentifier]::new($domainSid+'-512'),[DirectoryServices.ActiveDirectoryRights]::GenericAll,[Security.AccessControl.AccessControlType]::Allow))
    $global:AwTemplateFixture=@{Creates=0;Signature=$true;Objects=@{};Source=$sourceObject;FailCreate=0;SourceDrift=$false;CaDrift=$false;AllReads=0
        Ca=[pscustomobject]@{ObjectClass='pKIEnrollmentService';ObjectGUID=[guid]::NewGuid();Name='Test CA';certificateTemplates=(Wrap 'AuthWireGPOCodeSigning');dNSHostName=(Wrap 'ca.test.example');nTSecurityDescriptor=$caSecurity}
        Inspection=[pscustomobject]@{Event='WINDOWS_CONNECTOR_SIGNING_READONLY_PREFLIGHT';ToolVersion='1.0.1';InspectionSucceeded=$true
            Computer=$script:fixtureComputer;Domain='test.example';InstanceId=$instance.ToString('D');ServiceSid=$serviceSid
            AdChanged=$false;GpoChanged=$false;CertificatesChanged=$false;KeyAclChanged=$false;TrustStoreChanged=$false;EnrollmentRequested=$false
            EnterpriseAuthorities=@([pscustomobject]@{Name='Test CA';Host='ca.test.example';Configuration='ca.test.example\Test CA';PublishedTemplates=@('AuthWireGPOCodeSigning')})
            CodeSigningTemplates=@([pscustomobject]@{Name='AuthWireGPOCodeSigning';CodeSigningOnly=$true;DistinguishedName=$sourceObject.DistinguishedName})
            ProposedOwnershipMarker=('AuthWireDeploymentSigner:v1;instance='+$instance.ToString('D')+';host='+$hostGuid.ToString('D')+';service='+$serviceSid)}
    }
}
function Get-AuthenticodeSignature {[CmdletBinding()]param($FilePath)
    [pscustomobject]@{Status=$(if($global:AwTemplateFixture.Signature){'Valid'}else{'HashMismatch'});SignerCertificate=[pscustomobject]@{Thumbprint=$publisher}}}
function Import-Module {[CmdletBinding()]param($Name)}
function Get-ADDomain {[CmdletBinding()]param($Server)
    [pscustomobject]@{DNSRoot='test.example';DomainSID=[Security.Principal.SecurityIdentifier]::new($domainSid)}}
function Get-ADComputer {[CmdletBinding()]param($Identity,$Server,$Properties)
    [pscustomobject]@{ObjectGUID=$hostGuid;DNSHostName=($script:fixtureComputer+'.test.example');SID=[Security.Principal.SecurityIdentifier]::new($machineSid)}}
function Get-ADRootDSE {[CmdletBinding()]param($Server)
    [pscustomobject]@{configurationNamingContext=(Wrap 'CN=Configuration,DC=test,DC=example')}}
function Get-ADObject {[CmdletBinding()]param($Identity,$Server,$Properties,$SearchBase,$SearchScope,$LDAPFilter)
    if($Server -ine ($script:fixtureComputer+'.test.example')){throw 'Server scope escaped'}
    if($null -ne $Identity){
        if([string]$Identity -ieq ('CN=OID,'+$pki)){return [pscustomobject]@{'msPKI-Cert-Template-OID'=(Wrap $prefix)}}
        if([string]$Identity -ieq $global:AwTemplateFixture.Source.DistinguishedName){return $global:AwTemplateFixture.Source}
        if([string]$Identity -ieq $global:AwTemplateFixture.Source.ObjectGUID.ToString('D')){
            if($global:AwTemplateFixture.SourceDrift){$global:AwTemplateFixture.Source.flags=Wrap 999}
            return $global:AwTemplateFixture.Source
        }
        if([string]$Identity -ieq $global:AwTemplateFixture.Ca.ObjectGUID.ToString('D')){
            if($global:AwTemplateFixture.CaDrift){$global:AwTemplateFixture.Ca.certificateTemplates=Wrap @('AuthWireGPOCodeSigning','Other')}
            return $global:AwTemplateFixture.Ca
        }
        if($global:AwTemplateFixture.Objects.ContainsKey([string]$Identity)){return $global:AwTemplateFixture.Objects[[string]$Identity]}
        throw 'Unexpected object identity'
    }
    if($SearchBase -ieq ('CN=Enrollment Services,'+$pki) -and $LDAPFilter -eq '(cn=Test CA)'){return $global:AwTemplateFixture.Ca}
    if($SearchScope -eq 'Subtree'){
        return @($global:AwTemplateFixture.Objects.Values|Where-Object {[string]$_.'msPKI-Cert-Template-OID' -eq $plan.Oid})
    }
    if($SearchBase -in @(('CN=Certificate Templates,'+$pki),('CN=OID,'+$pki))){
        foreach($obj in $global:AwTemplateFixture.Objects.Values){if($LDAPFilter -eq ('(cn='+$obj.Name+')')){return $obj}}
        return
    }
    throw 'Unexpected directory search'
}
function Add-AuthWireSigningDirectoryObject {
    param($Server,$Dn,$Class,$Attributes)
    if($Server -ine ($script:fixtureComputer+'.test.example') -or $Dn -notin @($plan.OidDn,$plan.TemplateDn)){throw 'Create escaped owned names'}
    $global:AwTemplateFixture.Creates++
    if($global:AwTemplateFixture.FailCreate -eq $global:AwTemplateFixture.Creates){throw 'SIMULATED_CREATE_FAILURE'}
    $request=New-AuthWireDirectoryAddRequest $Dn $Class $Attributes
    if($request.DistinguishedName -ne $Dn){throw 'Wrong LDAP create DN'}
    $name=$(if($Dn -eq $plan.OidDn){$plan.OidName}else{$plan.Name})
    $global:AwTemplateFixture.Objects[$Dn]=Make-Object $Class $name $Dn $Attributes
}
function Run-Fixture([string]$Mode='Inspect'){
    Invoke-AuthWireSigningTemplatePreparation -Mode $Mode -ExpectedComputer $script:fixtureComputer -ExpectedDomain 'test.example' -InstanceId $instance -AccountName 'aw-deploy' -AccountSid $serviceSid -SourceTemplateName 'AuthWireGPOCodeSigning' -ExpectedCaName 'Test CA' -BootstrapPath $fake -ReadinessToolPath $fake -PublisherThumbprint $publisher
}
try{
    Reset-Fixture;$preview=Run-Fixture
    Check ($preview.ReadyForPrepare -and -not $preview.AdChanged -and -not $preview.TemplateCreated -and -not $preview.TemplatePublished -and $global:AwTemplateFixture.Creates -eq 0) 'Default inspect is readonly with no publication or object writes'
    Check ($preview.MachineEnrollmentSid -eq $machineSid -and -not $preview.EnrollmentRequested -and -not $preview.ServiceKeyAccessVerified -and -not $preview.CanApplyGpo) 'Preview never implies issuer/key/deployment acceptance'
    $result=Run-Fixture 'PrepareTemplate';$script:folders+=Split-Path -Parent $result.ReceiptPath
    Check ($result.TemplateCreated -and $result.AdChanged -and -not $result.CaChanged -and -not $result.TemplatePublished -and $global:AwTemplateFixture.Creates -eq 2) 'Exactly two atomic owned AD objects created, never published'
    Check ($result.SourceTemplatePreserved -and $result.CaConfigurationPreserved -and -not $result.CertificatesChanged -and -not $result.KeyAclChanged -and -not $result.TrustStoreChanged) 'Protected source template/CA and certificate/trust state preserved'
    $saved=Get-Content -LiteralPath $result.ReceiptPath -Raw|ConvertFrom-Json
    Check ($saved.Phase -eq 'verified_unpublished' -and $null -ne $saved.TemplateGuid -and $null -ne $saved.OidObjectGuid -and $saved.MachineSid -eq $machineSid) 'Receipt records both created GUIDs and enrolling identity'
    $caught=$false;try{$null=Run-Fixture 'PrepareTemplate'}catch{$caught=$_.Exception.Message -eq 'SIGNING_TEMPLATE_OR_OID_ALREADY_EXISTS_REVIEW_REQUIRED'}
    Check ($caught -and $global:AwTemplateFixture.Creates -eq 2) 'Repeat refuses adoption, deletion or duplicate creation'
    foreach($case in @('signature','source','host','sourceDrift','caDrift','existing')){
        Reset-Fixture
        switch($case){
            'signature' {$global:AwTemplateFixture.Signature=$false}
            'source' {$global:AwTemplateFixture.Inspection.CodeSigningTemplates[0].CodeSigningOnly=$false}
            'host' {$global:AwTemplateFixture.Inspection.ProposedOwnershipMarker='foreign'}
            'sourceDrift' {$global:AwTemplateFixture.SourceDrift=$true}
            'caDrift' {$global:AwTemplateFixture.CaDrift=$true}
            'existing' {$global:AwTemplateFixture.Objects[$plan.TemplateDn]=Make-Object 'pKICertificateTemplate' $plan.Name $plan.TemplateDn $plan.Attributes}
        }
        $caught=$false;try{$null=Run-Fixture 'PrepareTemplate'}catch{$caught=$true}
        Check ($caught -and $global:AwTemplateFixture.Creates -eq 0) ('Guard refuses all writes: '+$case)
    }
    Reset-Fixture;$global:AwTemplateFixture.FailCreate=2
    $caught=$false
    try{$null=Run-Fixture 'PrepareTemplate'}catch{
        $caught=$_.Exception.Message -like '*REQUIRES_REINSPECTION*'
        $match=[regex]::Match($_.Exception.Message,'REQUIRES_REINSPECTION:(?<path>[A-Za-z]:\\.*\\template-preparation\.json):')
        if($match.Success){$script:folders+=Split-Path -Parent $match.Groups['path'].Value}
    }
    Check ($caught -and $global:AwTemplateFixture.Objects.Count -eq 1 -and $global:AwTemplateFixture.Creates -eq 2) 'Partial create retains bounded OID and protected receipt, never deletes/retries'
    $text=[IO.File]::ReadAllText($source)
    Check (-not $text.Contains('Set-ADObject') -and -not $text.Contains('Remove-ADObject') -and -not $text.Contains('certreq') -and -not $text.Contains('Set-CATemplate')) 'No existing-object mutation, certificate request, publication or delete APIs'
    Write-Output ('AUTHWIRE_SIGNING_TEMPLATE_NATIVE_OK '+(@{checks=$checks;native_powershell=$PSVersionTable.PSVersion.ToString();genuine_ad_collections_and_security=$true
        real_ldap_add_requests_built=$true;real_ad_ca_tested=$false;directory_writes_simulated=$true;real_certificates_requested=0}|ConvertTo-Json -Compress))
}finally{
    foreach($folder in $script:folders){if(Test-Path -LiteralPath $folder){Remove-Item -LiteralPath $folder -Recurse -Force}}
    Remove-Item -LiteralPath $fake -Force -ErrorAction SilentlyContinue
    Remove-Variable AwTemplateFixture -Scope Global -ErrorAction SilentlyContinue
}
