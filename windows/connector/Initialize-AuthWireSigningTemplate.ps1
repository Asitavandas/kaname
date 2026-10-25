#Requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('Inspect','PrepareTemplate')][string]$Mode='Inspect',
    [Parameter(Mandatory=$true)][string]$ExpectedComputer,
    [Parameter(Mandatory=$true)][string]$ExpectedDomain,
    [Parameter(Mandatory=$true)][guid]$InstanceId,
    [string]$AccountName='aw-deploy',
    [Parameter(Mandatory=$true)][string]$AccountSid,
    [Parameter(Mandatory=$true)][ValidatePattern('^[A-Za-z0-9][A-Za-z0-9-]{0,63}$')][string]$SourceTemplateName,
    [Parameter(Mandatory=$true)][ValidatePattern('^[A-Za-z0-9][A-Za-z0-9 ._-]{0,127}$')][string]$ExpectedCaName,
    [Parameter(Mandatory=$true)][string]$BootstrapPath,
    [Parameter(Mandatory=$true)][string]$ReadinessToolPath,
    [Parameter(Mandatory=$true)][ValidatePattern('^[A-Fa-f0-9]{40}$')][string]$PublisherThumbprint
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version 2

function Get-AuthWireTemplateProperties {
    @('displayName','flags','revision','pKICriticalExtensions','pKIDefaultCSPs','pKIDefaultKeySpec','pKIExpirationPeriod',
      'pKIOverlapPeriod','pKIExtendedKeyUsage','pKIKeyUsage','msPKI-RA-Signature','msPKI-RA-Application-Policies',
      'msPKI-Template-Schema-Version','msPKI-Template-Minor-Revision','msPKI-Minimal-Key-Size','msPKI-Private-Key-Flag',
      'msPKI-Enrollment-Flag','msPKI-Certificate-Name-Flag','msPKI-Certificate-Application-Policy','msPKI-Cert-Template-OID','nTSecurityDescriptor')
}
function Get-AuthWireTemplateValues {
    param($Value)
    @(foreach($entry in $Value){if($null -ne $entry){[string]$entry}})
}
function Get-AuthWireTemplateSingle {
    param($Value,[string]$Name)
    $items=@(Get-AuthWireTemplateValues $Value)
    if($items.Count -ne 1 -or [string]::IsNullOrWhiteSpace($items[0])) {throw ('TEMPLATE_ATTRIBUTE_SCALAR_REQUIRED:'+ $Name)}
    return $items[0]
}
function Get-AuthWireTemplateBinary {
    param($Value,[string]$Name)
    if($Value -is [byte[]]) {return ,$Value}
    $items=@(foreach($entry in $Value){,$entry})
    if($items.Count -ne 1 -or $items[0] -isnot [byte[]]) {throw ('TEMPLATE_ATTRIBUTE_BINARY_REQUIRED:'+ $Name)}
    return ,$items[0]
}
function Get-AuthWireTemplateAclCanonical {
    param([DirectoryServices.ActiveDirectorySecurity]$Security)
    [pscustomobject][ordered]@{
        Owner=$Security.GetOwner([Security.Principal.SecurityIdentifier]).Value
        Group=$Security.GetGroup([Security.Principal.SecurityIdentifier]).Value
        Protected=$Security.AreAccessRulesProtected
        Rules=@($Security.GetAccessRules($true,$true,[Security.Principal.SecurityIdentifier])|ForEach-Object {
            [pscustomobject][ordered]@{Sid=$_.IdentityReference.Value;Type=$_.AccessControlType.ToString();Rights=[long]$_.ActiveDirectoryRights
                ObjectType=$_.ObjectType.ToString('D');InheritedObjectType=$_.InheritedObjectType.ToString('D')
                Inheritance=$_.InheritanceType.ToString();Propagation=$_.PropagationFlags.ToString();Inherited=$_.IsInherited}
        }|Sort-Object Sid,Type,Rights,ObjectType,InheritedObjectType,Inheritance,Propagation,Inherited)
    }
}
function New-AuthWireSigningTemplateAcl {
    param([string]$DomainSid,[string]$MachineSid,[switch]$OidOnly)
    $security=New-Object DirectoryServices.ActiveDirectorySecurity
    $owner=[Security.Principal.SecurityIdentifier]::new($DomainSid+'-512')
    $security.SetOwner($owner);$security.SetGroup($owner);$security.SetAccessRuleProtection($true,$false)
    foreach($sid in @($owner.Value,'S-1-5-18')) {
        $security.AddAccessRule([DirectoryServices.ActiveDirectoryAccessRule]::new([Security.Principal.SecurityIdentifier]::new($sid),
            [DirectoryServices.ActiveDirectoryRights]::GenericAll,[Security.AccessControl.AccessControlType]::Allow))
    }
    $security.AddAccessRule([DirectoryServices.ActiveDirectoryAccessRule]::new([Security.Principal.SecurityIdentifier]::new('S-1-5-11'),
        [DirectoryServices.ActiveDirectoryRights]::GenericRead,[Security.AccessControl.AccessControlType]::Allow))
    if(-not $OidOnly) {
        $security.AddAccessRule([DirectoryServices.ActiveDirectoryAccessRule]::new([Security.Principal.SecurityIdentifier]::new($MachineSid),
            [DirectoryServices.ActiveDirectoryRights]::ExtendedRight,[Security.AccessControl.AccessControlType]::Allow,
            [guid]'0e10c968-78fb-11d2-90d4-00c04f79dc55'))
    }
    return $security
}
function Get-AuthWireTemplateDigest {
    param($Value)
    $json=ConvertTo-Json -InputObject $Value -Depth 10 -Compress
    $sha=[Security.Cryptography.SHA256]::Create()
    try{return ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($json)))).Replace('-','').ToLowerInvariant()}
    finally{$sha.Dispose()}
}
function Get-AuthWireTemplateAttributeSnapshot {
    param($Object,[string[]]$Properties)
    $snapshot=[ordered]@{}
    foreach($name in @($Properties|Sort-Object)) {
        $value=$Object.$name
        if($value -is [DirectoryServices.ActiveDirectorySecurity]) {$snapshot[$name]=Get-AuthWireTemplateAclCanonical $value}
        elseif($value -is [byte[]]) {$snapshot[$name]=[Convert]::ToBase64String($value)}
        else {
            $snapshot[$name]=@(foreach($entry in $value) {
                if($entry -is [byte[]]) {[Convert]::ToBase64String($entry)} elseif($null -ne $entry){[string]$entry}
            }|Sort-Object)
        }
    }
    return [pscustomobject]$snapshot
}
function Get-AuthWireSigningTemplatePlan {
    param([guid]$InstanceId,[guid]$HostGuid,[string]$DomainSid,[string]$ServiceSid,[string]$MachineSid,
        [string]$PkiBase,[string]$ForestOidPrefix)
    if($InstanceId -eq [guid]::Empty -or $HostGuid -eq [guid]::Empty -or
        $ForestOidPrefix -notmatch '^1\.3\.6\.1\.4\.1\.311\.21\.8(?:\.[0-9]+)+$') {throw 'FOREST_OID_OR_INSTANCE_METADATA_INVALID'}
    foreach($sid in @($ServiceSid,$MachineSid)) {
        $parsed=[Security.Principal.SecurityIdentifier]::new($sid)
        if($null -eq $parsed.AccountDomainSid -or $parsed.AccountDomainSid.Value -ne $DomainSid){throw 'SIGNING_PLAN_SID_SCOPE_MISMATCH'}
    }
    if($ServiceSid -eq $MachineSid){throw 'SERVICE_AND_ENROLLING_MACHINE_MUST_DIFFER'}
    $suffix=$InstanceId.ToString('N').Substring(0,8)
    $name='AuthWireConnectorCodeSigning-'+$suffix
    $oidName='AuthWireConnectorSigningOID-'+$suffix
    $sha=[Security.Cryptography.SHA256]::Create()
    try{$digest=$sha.ComputeHash([Text.Encoding]::UTF8.GetBytes('AuthWireSigningTemplate:v1|'+$InstanceId.ToString('D')+'|'+$HostGuid.ToString('D')+'|'+$ServiceSid))}
    finally{$sha.Dispose()}
    $oid=$ForestOidPrefix
    for($i=0;$i -lt 4;$i++){$oid+='.'+[BitConverter]::ToUInt32($digest,$i*4).ToString([Globalization.CultureInfo]::InvariantCulture)}
    $grave=[char]96
    $algorithm=(@('msPKI-Asymmetric-Algorithm','PZPWSTR','RSA','msPKI-Hash-Algorithm','PZPWSTR','SHA256','msPKI-Key-Usage','DWORD','2') -join $grave)+$grave
    $templateSecurity=New-AuthWireSigningTemplateAcl $DomainSid $MachineSid
    $oidSecurity=New-AuthWireSigningTemplateAcl $DomainSid $MachineSid -OidOnly
    $attributes=[ordered]@{
        displayName=('AuthWire Connector Code Signing ['+$suffix+']');flags=64;revision=100
        pKICriticalExtensions=@('2.5.29.15');pKIDefaultCSPs=@('1,Microsoft Software Key Storage Provider');pKIDefaultKeySpec=2
        pKIExpirationPeriod=[BitConverter]::GetBytes(-[timespan]::FromDays(365).Ticks)
        pKIOverlapPeriod=[BitConverter]::GetBytes(-[timespan]::FromDays(30).Ticks)
        pKIExtendedKeyUsage=@('1.3.6.1.5.5.7.3.3');pKIKeyUsage=[byte[]]@(128,0)
        'msPKI-RA-Signature'=0;'msPKI-RA-Application-Policies'=@($algorithm)
        'msPKI-Template-Schema-Version'=3;'msPKI-Template-Minor-Revision'=0;'msPKI-Minimal-Key-Size'=3072
        'msPKI-Private-Key-Flag'=0;'msPKI-Enrollment-Flag'=0;'msPKI-Certificate-Name-Flag'=268435456
        'msPKI-Certificate-Application-Policy'=@('1.3.6.1.5.5.7.3.3');'msPKI-Cert-Template-OID'=$oid
        nTSecurityDescriptor=$templateSecurity.GetSecurityDescriptorBinaryForm()
    }
    $oidAttributes=[ordered]@{displayName=('AuthWire Connector Code Signing OID ['+$suffix+']');flags=1
        'msPKI-Cert-Template-OID'=$oid;nTSecurityDescriptor=$oidSecurity.GetSecurityDescriptorBinaryForm()}
    [pscustomobject]@{Name=$name;OidName=$oidName;Oid=$oid;TemplateDn=('CN='+$name+',CN=Certificate Templates,'+$PkiBase)
        OidDn=('CN='+$oidName+',CN=OID,'+$PkiBase);Attributes=$attributes;OidAttributes=$oidAttributes
        TemplateAcl=(Get-AuthWireTemplateAclCanonical $templateSecurity);OidAcl=(Get-AuthWireTemplateAclCanonical $oidSecurity)
        MachineEnrollmentSid=$MachineSid;ServiceSid=$ServiceSid;Published=$false}
}
function New-AuthWireDirectoryAddRequest {
    param([string]$Dn,[string]$Class,$Attributes)
    Add-Type -AssemblyName System.DirectoryServices.Protocols
    $request=[DirectoryServices.Protocols.AddRequest]::new()
    $request.DistinguishedName=$Dn
    if($Dn -notmatch '^CN=(AuthWireConnector(?:CodeSigning|SigningOID)-[a-f0-9]{8}),'){throw 'OWNED_SIGNING_OBJECT_DN_REQUIRED'}
    $cn=[DirectoryServices.Protocols.DirectoryAttribute]::new()
    $cn.Name='cn';$null=$cn.Add([string]$Matches[1]);$null=$request.Attributes.Add($cn)
    $classAttribute=[DirectoryServices.Protocols.DirectoryAttribute]::new()
    $classAttribute.Name='objectClass';$null=$classAttribute.Add('top');$null=$classAttribute.Add($Class)
    $null=$request.Attributes.Add($classAttribute)
    foreach($name in $Attributes.Keys) {
        $attribute=[DirectoryServices.Protocols.DirectoryAttribute]::new();$attribute.Name=$name
        $value=$Attributes[$name]
        if($value -is [byte[]]) {$null=$attribute.Add([byte[]]$value)}
        else {foreach($entry in $value){$null=$attribute.Add([string]$entry)}}
        $null=$request.Attributes.Add($attribute)
    }
    return $request
}
function Add-AuthWireSigningDirectoryObject {
    param([string]$Server,[string]$Dn,[string]$Class,$Attributes)
    $request=New-AuthWireDirectoryAddRequest $Dn $Class $Attributes
    $connection=[DirectoryServices.Protocols.LdapConnection]::new([DirectoryServices.Protocols.LdapDirectoryIdentifier]::new($Server,389,$false,$false))
    try{
        $connection.AuthType=[DirectoryServices.Protocols.AuthType]::Kerberos
        $connection.Timeout=[timespan]::FromSeconds(10);$connection.SessionOptions.ProtocolVersion=3
        $connection.SessionOptions.Signing=$true;$connection.SessionOptions.Sealing=$true
        $connection.SessionOptions.ReferralChasing=[DirectoryServices.Protocols.ReferralChasingOptions]::None
        $connection.Bind();$null=$connection.SendRequest($request)
    }finally{$connection.Dispose()}
}
function Find-AuthWireSigningObject {
    param([string]$Base,[string]$Name,[string]$Server,[string[]]$Properties)
    $found=@(Get-ADObject -Server $Server -SearchBase $Base -SearchScope OneLevel -LDAPFilter ('(cn='+$Name+')') -Properties $Properties -ErrorAction Stop)
    if($found.Count -gt 1){throw 'SIGNING_OBJECT_NAME_AMBIGUOUS'}
    if($found.Count -eq 1){return $found[0]}
}
function Assert-AuthWireSigningObject {
    param($Object,[string]$Class,$Attributes)
    if($null -eq $Object -or $Object.ObjectClass -ine $Class -or [guid]$Object.ObjectGUID -eq [guid]::Empty){throw 'SIGNING_OBJECT_READBACK_IDENTITY_INVALID'}
    foreach($name in $Attributes.Keys) {
        $expected=$Attributes[$name]
        if($name -eq 'nTSecurityDescriptor') {
            $security=New-Object DirectoryServices.ActiveDirectorySecurity;$security.SetSecurityDescriptorBinaryForm($expected)
            if((Get-AuthWireTemplateDigest (Get-AuthWireTemplateAclCanonical $security)) -cne
                (Get-AuthWireTemplateDigest (Get-AuthWireTemplateAclCanonical $Object.nTSecurityDescriptor))) {throw 'SIGNING_OBJECT_ACL_MISMATCH'}
        }elseif($expected -is [byte[]]){
            if([Convert]::ToBase64String((Get-AuthWireTemplateBinary $Object.$name $name)) -cne [Convert]::ToBase64String($expected)){throw ('SIGNING_OBJECT_ATTRIBUTE_MISMATCH:'+ $name)}
        }else{
            $left=@(Get-AuthWireTemplateValues $Object.$name|Sort-Object);$right=@(Get-AuthWireTemplateValues $expected|Sort-Object)
            if((ConvertTo-Json -InputObject $left -Compress) -cne (ConvertTo-Json -InputObject $right -Compress)){throw ('SIGNING_OBJECT_ATTRIBUTE_MISMATCH:'+ $name)}
        }
    }
}
function Write-AuthWireSigningTemplateReceipt {
    param([string]$Path,$Value)
    $Value|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $Path -Encoding UTF8
}
function Invoke-AuthWireSigningTemplatePreparation {
    param([string]$Mode,[string]$ExpectedComputer,[string]$ExpectedDomain,[guid]$InstanceId,[string]$AccountName,
        [string]$AccountSid,[string]$SourceTemplateName,[string]$ExpectedCaName,[string]$BootstrapPath,
        [string]$ReadinessToolPath,[string]$PublisherThumbprint)
    if(-not [Environment]::Is64BitProcess -or [Environment]::MachineName -ine $ExpectedComputer){throw 'LOCAL_64_BIT_COMPUTER_REQUIRED'}
    if($Mode -notin @('Inspect','PrepareTemplate') -or $SourceTemplateName -notmatch '^[A-Za-z0-9][A-Za-z0-9-]{0,63}$' -or
        $ExpectedCaName -notmatch '^[A-Za-z0-9][A-Za-z0-9 ._-]{0,127}$'){throw 'TEMPLATE_INPUT_INVALID'}
    foreach($path in @($BootstrapPath,$ReadinessToolPath)){
        $signature=Get-AuthenticodeSignature -FilePath $path
        if($signature.Status.ToString() -ne 'Valid' -or $signature.SignerCertificate.Thumbprint -ine $PublisherThumbprint){throw 'SIGNED_INSPECTION_TOOLS_REQUIRED'}
    }
    $common=@{ExpectedComputer=$ExpectedComputer;ExpectedDomain=$ExpectedDomain;InstanceId=$InstanceId;AccountName=$AccountName
        AccountSid=$AccountSid;BootstrapPath=$BootstrapPath;PublisherThumbprint=$PublisherThumbprint}
    $inspection=& $ReadinessToolPath -Mode Inspect @common|ConvertFrom-Json
    if($inspection.Event -ne 'WINDOWS_CONNECTOR_SIGNING_READONLY_PREFLIGHT' -or $inspection.ToolVersion -ne '1.0.1' -or -not $inspection.InspectionSucceeded -or
        $inspection.Computer -ine $ExpectedComputer -or $inspection.Domain -ine $ExpectedDomain -or $inspection.InstanceId -ine $InstanceId.ToString('D') -or
        $inspection.ServiceSid -ne $AccountSid -or $inspection.AdChanged -or $inspection.GpoChanged -or $inspection.CertificatesChanged -or
        $inspection.KeyAclChanged -or $inspection.TrustStoreChanged -or $inspection.EnrollmentRequested){throw 'READONLY_SIGNING_INSPECTION_REQUIRED'}
    $authorities=@($inspection.EnterpriseAuthorities|Where-Object {$null -ne $_ -and $_.Name -ceq $ExpectedCaName})
    $sources=@($inspection.CodeSigningTemplates|Where-Object {$null -ne $_ -and $_.Name -ceq $SourceTemplateName -and $_.CodeSigningOnly})
    if($authorities.Count -ne 1 -or $sources.Count -ne 1 -or $authorities[0].PublishedTemplates -notcontains $SourceTemplateName){throw 'EXPLICIT_PUBLISHED_SOURCE_AND_CA_REQUIRED'}
    Import-Module ActiveDirectory -ErrorAction Stop
    $server=$ExpectedComputer+'.'+$ExpectedDomain
    $domain=Get-ADDomain -Server $server -ErrorAction Stop
    $serviceSid=[Security.Principal.SecurityIdentifier]::new($AccountSid)
    if($domain.DNSRoot -ine $ExpectedDomain -or $serviceSid.AccountDomainSid.Value -ne $domain.DomainSID.Value){throw 'TEMPLATE_DOMAIN_SCOPE_MISMATCH'}
    $computer=Get-ADComputer -Identity $ExpectedComputer -Server $server -Properties dNSHostName,SID -ErrorAction Stop
    if($computer.DNSHostName -ine $server){throw 'CONNECTOR_MACHINE_DNS_MISMATCH'}
    $hostGuid=[guid]$computer.ObjectGUID
    $expectedMarker='AuthWireDeploymentSigner:v1;instance='+$InstanceId.ToString('D')+';host='+$hostGuid.ToString('D')+';service='+$AccountSid
    if($inspection.ProposedOwnershipMarker -cne $expectedMarker){throw 'CONNECTOR_MACHINE_GUID_MISMATCH'}
    $root=Get-ADRootDSE -Server $server -ErrorAction Stop
    $configuration=Get-AuthWireTemplateSingle $root.configurationNamingContext 'configurationNamingContext'
    $pki='CN=Public Key Services,CN=Services,'+$configuration
    $oidBase='CN=OID,'+$pki;$templateBase='CN=Certificate Templates,'+$pki
    $oidRoot=Get-ADObject -Identity $oidBase -Server $server -Properties msPKI-Cert-Template-OID -ErrorAction Stop
    $prefix=Get-AuthWireTemplateSingle $oidRoot.'msPKI-Cert-Template-OID' 'forestOIDPrefix'
    $plan=Get-AuthWireSigningTemplatePlan $InstanceId $hostGuid $domain.DomainSID.Value $AccountSid $computer.SID.Value $pki $prefix
    if($sources[0].DistinguishedName -ine ('CN='+$SourceTemplateName+','+$templateBase)){throw 'SOURCE_TEMPLATE_SCOPE_MISMATCH'}
    $source=Get-ADObject -Identity $sources[0].DistinguishedName -Server $server -Properties (Get-AuthWireTemplateProperties) -ErrorAction Stop
    if($source.ObjectClass -ine 'pKICertificateTemplate' -or [guid]$source.ObjectGUID -eq [guid]::Empty){throw 'SOURCE_TEMPLATE_IDENTITY_INVALID'}
    $caBase='CN=Enrollment Services,'+$pki
    $ca=Find-AuthWireSigningObject $caBase $ExpectedCaName $server @('certificateTemplates','dNSHostName','nTSecurityDescriptor')
    if($null -eq $ca -or $ca.ObjectClass -ine 'pKIEnrollmentService' -or
        (Get-AuthWireTemplateSingle $ca.dNSHostName 'CA host') -ine $authorities[0].Host){throw 'CA_DIRECTORY_IDENTITY_INVALID'}
    $sourceBefore=Get-AuthWireTemplateDigest (Get-AuthWireTemplateAttributeSnapshot $source (Get-AuthWireTemplateProperties))
    $caBefore=Get-AuthWireTemplateDigest (Get-AuthWireTemplateAttributeSnapshot $ca @('certificateTemplates','dNSHostName','nTSecurityDescriptor'))
    $existing=Find-AuthWireSigningObject $templateBase $plan.Name $server (Get-AuthWireTemplateProperties)
    $oidObject=Find-AuthWireSigningObject $oidBase $plan.OidName $server @('displayName','flags','msPKI-Cert-Template-OID','nTSecurityDescriptor')
    $collisions=@(Get-ADObject -Server $server -SearchBase $pki -SearchScope Subtree -LDAPFilter ('(msPKI-Cert-Template-OID='+$plan.Oid+')') -ErrorAction Stop)
    if($null -ne $existing -or $null -ne $oidObject -or $collisions.Count -ne 0){throw 'SIGNING_TEMPLATE_OR_OID_ALREADY_EXISTS_REVIEW_REQUIRED'}
    if(@(Get-AuthWireTemplateValues $ca.certificateTemplates) -contains $plan.Name){throw 'SIGNING_TEMPLATE_ALREADY_PUBLISHED'}
    $receipt=$null;$created=$false
    if($Mode -eq 'PrepareTemplate'){
        $folder=Join-Path ([Environment]::GetFolderPath('CommonApplicationData')) ('AuthWire-SigningTemplate-'+[guid]::NewGuid().ToString('N'))
        $security=New-Object Security.AccessControl.DirectorySecurity
        $security.SetSecurityDescriptorSddlForm('D:P(A;OICI;FA;;;SY)(A;OICI;FA;;;BA)')
        $null=[IO.Directory]::CreateDirectory($folder,$security)
        $receipt=Join-Path $folder 'template-preparation.json'
        $record=[ordered]@{Version=1;InstanceId=$InstanceId.ToString('D');HostGuid=$hostGuid.ToString('D');ServiceSid=$AccountSid
            MachineSid=$computer.SID.Value;TemplateName=$plan.Name;TemplateDn=$plan.TemplateDn;Oid=$plan.Oid;OidDn=$plan.OidDn
            SourceGuid=([guid]$source.ObjectGUID).ToString('D');SourceHash=$sourceBefore;CaGuid=([guid]$ca.ObjectGUID).ToString('D');CaHash=$caBefore
            Phase='before_create';OidObjectGuid=$null;TemplateGuid=$null;CreatedUtc=[datetime]::UtcNow.ToString('o')}
        Write-AuthWireSigningTemplateReceipt $receipt $record
        try{
            # Re-read both names and protected objects before the first bounded create.
            if($null -ne (Find-AuthWireSigningObject $templateBase $plan.Name $server (Get-AuthWireTemplateProperties)) -or
                $null -ne (Find-AuthWireSigningObject $oidBase $plan.OidName $server @('displayName'))){throw 'SIGNING_OBJECT_APPEARED_REINSPECT'}
            $sourceNow=Get-ADObject -Identity $source.ObjectGUID -Server $server -Properties (Get-AuthWireTemplateProperties) -ErrorAction Stop
            $caNow=Get-ADObject -Identity $ca.ObjectGUID -Server $server -Properties certificateTemplates,dNSHostName,nTSecurityDescriptor -ErrorAction Stop
            if((Get-AuthWireTemplateDigest (Get-AuthWireTemplateAttributeSnapshot $sourceNow (Get-AuthWireTemplateProperties))) -cne $sourceBefore -or
                (Get-AuthWireTemplateDigest (Get-AuthWireTemplateAttributeSnapshot $caNow @('certificateTemplates','dNSHostName','nTSecurityDescriptor'))) -cne $caBefore){throw 'SOURCE_TEMPLATE_OR_CA_CHANGED_REVIEW_REQUIRED'}
            Add-AuthWireSigningDirectoryObject $server $plan.OidDn 'msPKI-Enterprise-Oid' $plan.OidAttributes
            $oidObject=Get-ADObject -Identity $plan.OidDn -Server $server -Properties displayName,flags,msPKI-Cert-Template-OID,nTSecurityDescriptor -ErrorAction Stop
            Assert-AuthWireSigningObject $oidObject 'msPKI-Enterprise-Oid' $plan.OidAttributes
            $record.OidObjectGuid=([guid]$oidObject.ObjectGUID).ToString('D');$record.Phase='oid_created'
            Write-AuthWireSigningTemplateReceipt $receipt $record
            Add-AuthWireSigningDirectoryObject $server $plan.TemplateDn 'pKICertificateTemplate' $plan.Attributes
            $existing=Get-ADObject -Identity $plan.TemplateDn -Server $server -Properties (Get-AuthWireTemplateProperties) -ErrorAction Stop
            Assert-AuthWireSigningObject $existing 'pKICertificateTemplate' $plan.Attributes
            $record.TemplateGuid=([guid]$existing.ObjectGUID).ToString('D');$record.Phase='template_created_unpublished'
            Write-AuthWireSigningTemplateReceipt $receipt $record
            $created=$true
        }catch{throw ('SIGNING_TEMPLATE_PREPARATION_REQUIRES_REINSPECTION:'+ $receipt+':'+$_.Exception.Message)}
    }
    $sourceAfter=Get-ADObject -Identity $source.ObjectGUID -Server $server -Properties (Get-AuthWireTemplateProperties) -ErrorAction Stop
    $caAfter=Get-ADObject -Identity $ca.ObjectGUID -Server $server -Properties certificateTemplates,dNSHostName,nTSecurityDescriptor -ErrorAction Stop
    if((Get-AuthWireTemplateDigest (Get-AuthWireTemplateAttributeSnapshot $sourceAfter (Get-AuthWireTemplateProperties))) -cne $sourceBefore -or
        (Get-AuthWireTemplateDigest (Get-AuthWireTemplateAttributeSnapshot $caAfter @('certificateTemplates','dNSHostName','nTSecurityDescriptor'))) -cne $caBefore){throw 'SOURCE_TEMPLATE_OR_CA_CHANGED_REVIEW_REQUIRED'}
    if($created){$record.Phase='verified_unpublished';Write-AuthWireSigningTemplateReceipt $receipt $record}
    [pscustomobject]@{
        Event='WINDOWS_CONNECTOR_SIGNING_TEMPLATE_PREPARATION';ToolVersion='1.0.0';Mode=$Mode;Computer=$ExpectedComputer;Domain=$ExpectedDomain
        InstanceId=$InstanceId.ToString('D');ServiceSid=$AccountSid;MachineEnrollmentSid=$computer.SID.Value
        ProposedTemplateName=$plan.Name;ProposedTemplateDn=$plan.TemplateDn;ProposedOid=$plan.Oid;Ca=$authorities[0].Configuration
        SchemaVersion=3;Provider='Microsoft Software Key Storage Provider';Algorithm='RSA';MinimumKeySize=3072;HashAlgorithm='SHA256'
        CodeSigningOnly=$true;ExportableKeyAllowed=$false;RequesterSuppliesSubject=$false;MachineType=$true
        ProposedTemplateAcl=$plan.TemplateAcl;ReadyForPrepare=$true;TemplateCreated=$created;TemplatePublished=$false
        SourceTemplatePreserved=$true;CaConfigurationPreserved=$true;ReceiptPath=$receipt
        AdChanged=$created;CaChanged=$false;GpoChanged=$false;CertificatesChanged=$false;KeyAclChanged=$false;TrustStoreChanged=$false
        EnrollmentRequested=$false;ServiceKeyAccessVerified=$false;ConnectorInstalled=$false;CanApplyGpo=$false
    }
}
$parameters=@{Mode=$Mode;ExpectedComputer=$ExpectedComputer;ExpectedDomain=$ExpectedDomain;InstanceId=$InstanceId;AccountName=$AccountName
    AccountSid=$AccountSid;SourceTemplateName=$SourceTemplateName;ExpectedCaName=$ExpectedCaName;BootstrapPath=$BootstrapPath
    ReadinessToolPath=$ReadinessToolPath;PublisherThumbprint=$PublisherThumbprint}
Invoke-AuthWireSigningTemplatePreparation @parameters|ConvertTo-Json -Depth 10
