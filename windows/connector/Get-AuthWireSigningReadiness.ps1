#Requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('Inspect')][string]$Mode='Inspect',
    [Parameter(Mandatory=$true)][string]$ExpectedComputer,
    [Parameter(Mandatory=$true)][string]$ExpectedDomain,
    [Parameter(Mandatory=$true)][guid]$InstanceId,
    [string]$AccountName='aw-deploy',
    [Parameter(Mandatory=$true)][string]$AccountSid,
    [Parameter(Mandatory=$true)][string]$BootstrapPath,
    [Parameter(Mandatory=$true)][ValidatePattern('^[A-Fa-f0-9]{40}$')][string]$PublisherThumbprint
)
$ErrorActionPreference='Stop'
Set-StrictMode -Version 2

function Initialize-AuthWireSigningMetadataReader {
    if(-not ('AuthWire.Connector.SigningMetadataV1' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Security.Cryptography.X509Certificates;
using System.Text;
namespace AuthWire.Connector {
    public sealed class KeyProviderMetadata {
        public bool Available, MachineKeySet, Cng;
        public string Provider, ContainerNameSha256;
        public uint ProviderType, Flags, KeySpec;
    }
    public static class SigningMetadataV1 {
        [StructLayout(LayoutKind.Sequential)]
        private struct KeyProviderInfo {
            public IntPtr Container, Provider;
            public uint ProviderType, Flags, ParameterCount;
            public IntPtr Parameters;
            public uint KeySpec;
        }
        [DllImport("crypt32.dll",ExactSpelling=true,SetLastError=true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool CertGetCertificateContextProperty(IntPtr context,uint property,IntPtr data,ref uint length);
        public static KeyProviderMetadata Read(X509Certificate2 certificate) {
            if(certificate==null)throw new ArgumentNullException("certificate");
            KeyProviderMetadata result=new KeyProviderMetadata();
            uint length=0;
            if(!CertGetCertificateContextProperty(certificate.Handle,2,IntPtr.Zero,ref length)) {
                int error=Marshal.GetLastWin32Error();
                if(unchecked((uint)error)==0x80092004) return result; // CRYPT_E_NOT_FOUND.
                throw new Win32Exception(error,"Read certificate provider metadata");
            }
            if(length<Marshal.SizeOf(typeof(KeyProviderInfo)) || length>65536)throw new InvalidOperationException("PROVIDER_METADATA_SIZE_INVALID");
            IntPtr buffer=Marshal.AllocHGlobal((int)length);
            try {
                if(!CertGetCertificateContextProperty(certificate.Handle,2,buffer,ref length))
                    throw new Win32Exception(Marshal.GetLastWin32Error(),"Read certificate provider metadata");
                KeyProviderInfo info=(KeyProviderInfo)Marshal.PtrToStructure(buffer,typeof(KeyProviderInfo));
                string container=Marshal.PtrToStringUni(info.Container);
                result.Provider=Marshal.PtrToStringUni(info.Provider);
                result.ProviderType=info.ProviderType;result.Flags=info.Flags;result.KeySpec=info.KeySpec;
                result.MachineKeySet=(info.Flags&0x20)!=0;
                result.Cng=(info.ProviderType==0 && info.KeySpec==0xffffffff);
                if(container!=null)using(SHA256 sha=SHA256.Create())
                    result.ContainerNameSha256=BitConverter.ToString(sha.ComputeHash(Encoding.UTF8.GetBytes(container))).Replace("-","").ToLowerInvariant();
                result.Available=true;
                return result;
            } finally {Marshal.FreeHGlobal(buffer);GC.KeepAlive(certificate);}
        }
    }
}
'@
    }
}
function Get-AuthWireSigningStringValues {
    param($Value,[string]$Name)
    @(foreach($entry in $Value) {
        if($null -eq $entry -or $entry -isnot [string] -or [string]::IsNullOrWhiteSpace($entry)) {throw ('INVALID_STRING_ATTRIBUTE:'+ $Name)}
        $entry
    })
}
function Get-AuthWireSigningFlags {
    param($Value,[string]$Name)
    if($null -eq $Value) {throw ('MISSING_INTEGER_ATTRIBUTE:'+ $Name)}
    $values=@(foreach($entry in $Value){$entry})
    if($values.Count -ne 1) {throw ('AMBIGUOUS_INTEGER_ATTRIBUTE:'+ $Name)}
    $entry=$values[0]
    if($entry -is [bool] -or $entry -is [array]) {throw ('INVALID_INTEGER_ATTRIBUTE:'+ $Name)}
    $code=[Type]::GetTypeCode($entry.GetType())
    if($entry -isnot [string] -and $code -notin @([TypeCode]::Byte,[TypeCode]::SByte,[TypeCode]::Int16,[TypeCode]::UInt16,[TypeCode]::Int32,[TypeCode]::UInt32,[TypeCode]::Int64,[TypeCode]::UInt64)) {throw ('INVALID_INTEGER_ATTRIBUTE:'+ $Name)}
    $number=[long]0
    if(-not [long]::TryParse([string]$entry,[Globalization.NumberStyles]::AllowLeadingSign,[Globalization.CultureInfo]::InvariantCulture,[ref]$number) -or
        $number -lt -2147483648 -or $number -gt 4294967295) {throw ('INVALID_INTEGER_ATTRIBUTE:'+ $Name)}
    return [uint32]($number -band [long]4294967295)
}
function Get-AuthWireSigningCertificateMetadata {
    param([Security.Cryptography.X509Certificates.X509Certificate2]$Certificate,[string]$Store)
    Initialize-AuthWireSigningMetadataReader
    $extensions=@($Certificate.Extensions|Where-Object {$_.Oid.Value -eq '2.5.29.37'})
    $eku=@();$ekuState='missing'
    if($extensions.Count -eq 1) {
        try {
            $decoded=[Security.Cryptography.X509Certificates.X509EnhancedKeyUsageExtension]::new($extensions[0],$extensions[0].Critical)
            $eku=@($decoded.EnhancedKeyUsages|ForEach-Object {$_.Value})
            if($eku.Count -eq 0){throw 'EMPTY_EKU'}
            $ekuState='valid'
        } catch {$ekuState='invalid'}
    } elseif($extensions.Count -gt 1){$ekuState='invalid'}
    $key=[AuthWire.Connector.SigningMetadataV1]::Read($Certificate)
    [pscustomobject]@{
        Store=$Store;Subject=$Certificate.Subject;Issuer=$Certificate.Issuer;Thumbprint=$Certificate.Thumbprint
        FriendlyName=$Certificate.FriendlyName;NotBeforeUtc=$Certificate.NotBefore.ToUniversalTime().ToString('o')
        NotAfterUtc=$Certificate.NotAfter.ToUniversalTime().ToString('o')
        CurrentlyValid=($Certificate.NotBefore.ToUniversalTime() -le [datetime]::UtcNow -and $Certificate.NotAfter.ToUniversalTime() -gt [datetime]::UtcNow)
        HasPrivateKeyMetadata=[bool]$Certificate.HasPrivateKey;EkuState=$ekuState;Eku=$eku
        CodeSigningEku=($ekuState -eq 'valid' -and $eku -contains '1.3.6.1.5.5.7.3.3')
        CodeSigningOnly=($ekuState -eq 'valid' -and $eku.Count -eq 1 -and $eku[0] -eq '1.3.6.1.5.5.7.3.3')
        ProviderMetadata=$key;PrivateKeyUseTested=$false;ServiceKeyAccessVerified=$false
    }
}
function Get-AuthWireSigningTemplateShape {
    param($Template,$Authorities)
    $eku=@(Get-AuthWireSigningStringValues $Template.pKIExtendedKeyUsage 'pKIExtendedKeyUsage')
    $application=@(Get-AuthWireSigningStringValues $Template.'msPKI-Certificate-Application-Policy' 'msPKI-Certificate-Application-Policy')
    if($eku -notcontains '1.3.6.1.5.5.7.3.3' -and $application -notcontains '1.3.6.1.5.5.7.3.3') {return $null}
    $flags=Get-AuthWireSigningFlags $Template.flags 'flags'
    $private=Get-AuthWireSigningFlags $Template.'msPKI-Private-Key-Flag' 'msPKI-Private-Key-Flag'
    $nameFlags=Get-AuthWireSigningFlags $Template.'msPKI-Certificate-Name-Flag' 'msPKI-Certificate-Name-Flag'
    $enrollFlags=Get-AuthWireSigningFlags $Template.'msPKI-Enrollment-Flag' 'msPKI-Enrollment-Flag'
    $schema=Get-AuthWireSigningFlags $Template.'msPKI-Template-Schema-Version' 'msPKI-Template-Schema-Version'
    $minimum=Get-AuthWireSigningFlags $Template.'msPKI-Minimal-Key-Size' 'msPKI-Minimal-Key-Size'
    $only=($eku.Count -eq 1 -and $eku[0] -eq '1.3.6.1.5.5.7.3.3' -and
        ($application.Count -eq 0 -or ($application.Count -eq 1 -and $application[0] -eq '1.3.6.1.5.5.7.3.3')))
    $published=@($Authorities|Where-Object {$_.PublishedTemplates -icontains $Template.Name}|ForEach-Object {$_.Configuration})
    $acl=$Template.nTSecurityDescriptor
    $aces=@()
    if($null -ne $acl) {
        $aces=@($acl.GetAccessRules($true,$true,[Security.Principal.SecurityIdentifier])|Where-Object {
            ([long]$_.ActiveDirectoryRights -band 256) -ne 0 -and $_.ObjectType -in @([guid]::Empty,[guid]'0e10c968-78fb-11d2-90d4-00c04f79dc55',[guid]'a05b8cc2-17bc-4802-a710-e7c15ab866a2')
        }|ForEach-Object {
            [pscustomobject]@{Sid=$_.IdentityReference.Value;Type=$_.AccessControlType.ToString();Rights=$_.ActiveDirectoryRights.ToString()
                ObjectType=$_.ObjectType.ToString('D');Inherited=$_.IsInherited;Propagation=$_.PropagationFlags.ToString()}
        })
    }
    [pscustomobject]@{
        Name=[string]$Template.Name;DisplayName=[string]$Template.DisplayName;DistinguishedName=[string]$Template.DistinguishedName
        SchemaVersion=$schema;Flags=$flags;PrivateKeyFlags=$private;CertificateNameFlags=$nameFlags;EnrollmentFlags=$enrollFlags
        Eku=$eku;ApplicationPolicies=$application;CodeSigningOnly=$only
        MachineType=(($flags -band 64) -ne 0);CaOrCrossCa=(($flags -band 2176) -ne 0)
        ExportableKeyAllowed=(($private -band 16) -ne 0);PrivateKeyArchivalRequired=(($private -band 1) -ne 0)
        InteractiveKeyProtectionRequired=(($private -band 32) -ne 0);EnrolleeSuppliesSubject=(($nameFlags -band 1) -ne 0)
        ManagerApprovalRequired=(($enrollFlags -band 2) -ne 0);MinimumKeySize=$minimum
        Providers=@(Get-AuthWireSigningStringValues $Template.pKIDefaultCSPs 'pKIDefaultCSPs');PublishedBy=$published
        EnrollmentAclRead=($null -ne $acl);EnrollmentAces=$aces;EffectiveEnrollmentRightsEvaluated=$false
        ShapeCompatible=($only -and ($flags -band 64) -ne 0 -and ($flags -band 2176) -eq 0 -and
            ($private -band 49) -eq 0 -and ($nameFlags -band 1) -eq 0 -and $minimum -ge 2048 -and $published.Count -gt 0)
        AutomaticallyApproved=$false
    }
}
function Invoke-AuthWireSigningInspection {
    param([string]$ExpectedComputer,[string]$ExpectedDomain,[guid]$InstanceId,[string]$AccountName,[string]$AccountSid,
        [string]$BootstrapPath,[string]$PublisherThumbprint)
    if(-not [Environment]::Is64BitProcess) {throw 'POWERSHELL_64_BIT_REQUIRED'}
    if([Environment]::MachineName -ine $ExpectedComputer) {throw 'LOCAL_COMPUTER_MISMATCH'}
    if($InstanceId -eq [guid]::Empty) {throw 'INSTANCE_ID_REQUIRED'}
    $sid=[Security.Principal.SecurityIdentifier]::new($AccountSid)
    if($null -eq $sid.AccountDomainSid){throw 'DOMAIN_SERVICE_SID_REQUIRED'}
    $signature=Get-AuthenticodeSignature -FilePath $BootstrapPath
    if($signature.Status.ToString() -ne 'Valid' -or $signature.SignerCertificate.Thumbprint -ine $PublisherThumbprint) {throw 'BOOTSTRAP_SIGNATURE_INVALID'}
    $account=& $BootstrapPath -Mode Inspect -ExpectedDomain $ExpectedDomain -ConnectorComputer $ExpectedComputer -InstanceId $InstanceId -AccountName $AccountName -PublisherThumbprint $PublisherThumbprint|ConvertFrom-Json
    if($account.Event -ne 'WINDOWS_CONNECTOR_BOOTSTRAP' -or $account.BootstrapVersion -ne '1.0.3' -or $account.Mode -ne 'Inspect' -or
        $account.Computer -ine $ExpectedComputer -or $account.Domain -ine $ExpectedDomain -or $account.InstanceId -ine $InstanceId.ToString('D') -or
        $account.Account.Sid -ne $sid.Value -or $account.Account.Name -ine ($AccountName+'$') -or -not $account.Account.Exists -or
        -not $account.ReadyForAccountPreparation -or @($account.Blockers).Count -ne 0 -or $account.AdChanged -or $account.GpoChanged -or $account.CertificatesChanged) {throw 'OWNED_SERVICE_ACCOUNT_REQUIRED'}
    $hostId=[guid]$account.ConnectorComputerGuid
    if($hostId -eq [guid]::Empty){throw 'CONNECTOR_HOST_GUID_REQUIRED'}
    Import-Module ActiveDirectory -ErrorAction Stop
    $server=$ExpectedComputer+'.'+$ExpectedDomain
    $domain=Get-ADDomain -Server $server -ErrorAction Stop
    if($domain.DNSRoot -ine $ExpectedDomain -or $domain.DomainSID.Value -ne $sid.AccountDomainSid.Value){throw 'DOMAIN_OR_SID_SCOPE_MISMATCH'}
    $publishers=@(foreach($store in @('Cert:\CurrentUser\My','Cert:\LocalMachine\My')) {
        foreach($cert in @(Get-ChildItem -Path $store -ErrorAction Stop|Where-Object Thumbprint -ieq $PublisherThumbprint)) {
            Get-AuthWireSigningCertificateMetadata $cert $store
        }
    })
    if(@($publishers|Where-Object {$_.Store -eq 'Cert:\CurrentUser\My' -and $_.CurrentlyValid -and $_.CodeSigningEku -and $_.HasPrivateKeyMetadata}).Count -ne 1) {throw 'CURRENT_CORPORATE_PUBLISHER_REQUIRED'}
    $marker='AuthWireDeploymentSigner:v1;instance='+$InstanceId.ToString('D')+';host='+$hostId.ToString('D')+';service='+$sid.Value
    $owned=@(Get-ChildItem -Path 'Cert:\LocalMachine\My' -ErrorAction Stop|Where-Object {$_.FriendlyName -ceq $marker}|ForEach-Object {
        Get-AuthWireSigningCertificateMetadata $_ 'Cert:\LocalMachine\My'
    })
    $root=Get-ADRootDSE -Server $server -ErrorAction Stop
    $configuration=@(Get-AuthWireSigningStringValues $root.configurationNamingContext 'configurationNamingContext')
    if($configuration.Count -ne 1){throw 'CONFIGURATION_NAMING_CONTEXT_REQUIRED'}
    $pki='CN=Public Key Services,CN=Services,'+$configuration[0]
    $authorities=@(Get-ADObject -Server $server -SearchBase ('CN=Enrollment Services,'+$pki) -SearchScope OneLevel -LDAPFilter '(objectClass=pKIEnrollmentService)' -Properties displayName,dNSHostName,certificateTemplates -ErrorAction Stop|ForEach-Object {
        $hosts=@(Get-AuthWireSigningStringValues $_.dNSHostName 'dNSHostName')
        if($hosts.Count -ne 1){throw 'CA_HOST_METADATA_INVALID'}
        [pscustomobject]@{Name=[string]$_.Name;Host=$hosts[0];Configuration=($hosts[0]+'\'+[string]$_.Name)
            PublishedTemplates=@(Get-AuthWireSigningStringValues $_.certificateTemplates 'certificateTemplates')}
    })
    $properties=@('displayName','flags','pKIExtendedKeyUsage','msPKI-Certificate-Application-Policy','msPKI-Private-Key-Flag',
        'msPKI-Certificate-Name-Flag','msPKI-Enrollment-Flag','msPKI-Template-Schema-Version','msPKI-Minimal-Key-Size','pKIDefaultCSPs','nTSecurityDescriptor')
    $templates=@(Get-ADObject -Server $server -SearchBase ('CN=Certificate Templates,'+$pki) -SearchScope OneLevel -LDAPFilter '(objectClass=pKICertificateTemplate)' -Properties $properties -ErrorAction Stop|ForEach-Object {
        Get-AuthWireSigningTemplateShape $_ $authorities
    })
    $trust=@(foreach($store in @('Cert:\CurrentUser\TrustedPublisher','Cert:\LocalMachine\TrustedPublisher')) {
        [pscustomobject]@{Store=$store;CurrentPublisherPresent=(@(Get-ChildItem -Path $store -ErrorAction Stop|Where-Object Thumbprint -ieq $PublisherThumbprint).Count -gt 0)}
    })
    [pscustomobject]@{
        Event='WINDOWS_CONNECTOR_SIGNING_READONLY_PREFLIGHT';ToolVersion='1.0.0';Mode='Inspect';Computer=$ExpectedComputer;Domain=$ExpectedDomain
        InstanceId=$InstanceId.ToString('D');ServiceSid=$sid.Value;CurrentPublisher=$publishers;CurrentPublisherTrust=$trust
        ProposedServiceSignerStore='Cert:\LocalMachine\My';ProposedOwnershipMarker=$marker;ExistingMarkedMachineCertificates=$owned
        EnterpriseAuthorities=$authorities;CodeSigningTemplates=$templates;ShapeCompatibleTemplateCount=@($templates|Where-Object ShapeCompatible).Count
        InspectionSucceeded=$true;TemplateSelected=$false;EnrollmentRequested=$false;ServiceKeyAccessVerified=$false
        NewPublisherTrustDistributionPending=$true;ReadyForAutomatedSigning=$false
        AdChanged=$false;GpoChanged=$false;CertificatesChanged=$false;KeyAclChanged=$false;TrustStoreChanged=$false
        PrivateKeyUseTested=$false;SecretsExported=$false;ConnectorInstalled=$false;CanApplyGpo=$false
    }
}
Invoke-AuthWireSigningInspection -ExpectedComputer $ExpectedComputer -ExpectedDomain $ExpectedDomain -InstanceId $InstanceId -AccountName $AccountName -AccountSid $AccountSid -BootstrapPath $BootstrapPath -PublisherThumbprint $PublisherThumbprint|ConvertTo-Json -Depth 10
