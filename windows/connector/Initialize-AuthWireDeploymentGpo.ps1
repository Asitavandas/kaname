#Requires -Version 5.1
[CmdletBinding()]
param(
    [ValidateSet('Inspect','PrepareGpo','ResumeGpo')][string]$Mode='Inspect',
    [string]$PreparationReceiptPath,
    [guid]$ExpectedGpoId=[guid]::Empty,
    [Parameter(Mandatory=$true)][ValidatePattern('^[A-Za-z0-9][A-Za-z0-9-]{0,14}$')][string]$ExpectedComputer,
    [Parameter(Mandatory=$true)][string]$ExpectedDomain,
    [Parameter(Mandatory=$true)][guid]$InstanceId,
    [ValidatePattern('^[A-Za-z][A-Za-z0-9-]{0,14}$')][string]$AccountName='aw-deploy',
    [Parameter(Mandatory=$true)][ValidatePattern('^S-1-5-21-(\d+-){3}\d+$')][string]$AccountSid,
    [Parameter(Mandatory=$true)][ValidatePattern('^S-1-5-21-(\d+-){3}\d+$')][string]$ScopeGroupSid,
    [Parameter(Mandatory=$true)][string]$ScopeGroupName,
    [Parameter(Mandatory=$true)][guid]$ProtectedGpoId,
    [Parameter(Mandatory=$true)][string]$BootstrapPath,
    [Parameter(Mandatory=$true)][ValidatePattern('^[A-Fa-f0-9]{40}$')][string]$PublisherThumbprint
)

function Resolve-AuthWireDeploymentPrincipal {
    param([string]$Sid)
    if(-not ('AuthWire.Connector.DeploymentPrincipalLookupV1' -as [type])) {
        Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Security.Principal;
using System.Text;
namespace AuthWire.Connector {
    public sealed class DeploymentPrincipalInfo {
        public string Sid, Name, Domain, QualifiedName;
        public int Use;
    }
    public static class DeploymentPrincipalLookupV1 {
        [DllImport("advapi32.dll", CharSet=CharSet.Unicode, ExactSpelling=true, SetLastError=true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool LookupAccountSidW(string system, byte[] sid, StringBuilder name, ref uint nameSize,
            StringBuilder domain, ref uint domainSize, out int use);
        public static DeploymentPrincipalInfo Resolve(string sidValue) {
            SecurityIdentifier sid = new SecurityIdentifier(sidValue);
            byte[] raw = new byte[sid.BinaryLength]; sid.GetBinaryForm(raw, 0);
            uint nameSize=0, domainSize=0; int use;
            bool first = LookupAccountSidW(null, raw, null, ref nameSize, null, ref domainSize, out use);
            int error = Marshal.GetLastWin32Error();
            if (!first && error != 122) throw new Win32Exception(error, "LookupAccountSid");
            if (nameSize == 0 || nameSize > 1024 || domainSize > 1024) throw new InvalidOperationException("SID lookup buffer shape.");
            StringBuilder name = new StringBuilder((int)nameSize);
            StringBuilder domain = new StringBuilder((int)Math.Max(domainSize,1));
            if (!LookupAccountSidW(null, raw, name, ref nameSize, domain, ref domainSize, out use))
                throw new Win32Exception(Marshal.GetLastWin32Error(), "LookupAccountSid");
            DeploymentPrincipalInfo result = new DeploymentPrincipalInfo();
            result.Sid=sid.Value; result.Name=name.ToString(); result.Domain=domain.ToString(); result.Use=use;
            result.QualifiedName=(result.Domain.Length==0?"":result.Domain+"\\")+result.Name;
            return result;
        }
    }
}
'@
    }
    return [AuthWire.Connector.DeploymentPrincipalLookupV1]::Resolve($Sid)
}
function Get-AuthWireGpoPrincipalType {
    param([int]$Use)
    if($Use -eq 1) { return 'User' }
    if($Use -eq 9) { return 'Computer' }
    throw 'SERVICE_SID_TYPE_UNSUPPORTED'
}
function Get-AuthWireGpoPermissionRows {
    param([guid]$Id,[string]$Domain,[string]$Server)
    @(Get-GPPermission -Guid $Id -All -Domain $Domain -Server $Server -ErrorAction Stop |
        ForEach-Object { [pscustomobject]@{Sid=$_.Trustee.Sid.Value;Permission=$_.Permission.ToString()} })
}
function Get-AuthWireGpoDocument {
    param([guid]$Id,[string]$Domain,[string]$Server)
    $text=Get-GPOReport -Guid $Id -Domain $Domain -Server $Server -ReportType Xml -ErrorAction Stop
    if($text.IndexOf('<!DOCTYPE',[StringComparison]::OrdinalIgnoreCase) -ge 0) { throw 'GPO_REPORT_DTD_REJECTED' }
    $doc=New-Object System.Xml.XmlDocument
    $doc.XmlResolver=$null
    $doc.LoadXml($text)
    if($null -eq $doc.SelectSingleNode("/*[local-name()='GPO']")) { throw 'GPO_REPORT_SHAPE_INVALID' }
    return ,$doc
}
function Get-AuthWireGpoRoot {
    param([guid]$Id,[string]$Domain,[string]$Server)
    return ('\\' + $Server + '\SYSVOL\' + $Domain + '\Policies\{' + $Id.ToString('D') + '}')
}
function Get-AuthWireProtectedGpoHash {
    param([guid]$Id,[string]$Domain,[string]$Server)
    $doc=Get-AuthWireGpoDocument $Id $Domain $Server
    foreach($node in @($doc.SelectNodes("//*[local-name()='ReadTime']"))) { $null=$node.ParentNode.RemoveChild($node) }
    $permissions=@(Get-AuthWireGpoPermissionRows $Id $Domain $Server | Sort-Object Sid,Permission)
    $acl=Get-Acl -LiteralPath (Get-AuthWireGpoRoot $Id $Domain $Server) -ErrorAction Stop
    $content=$doc.OuterXml + ($permissions | ConvertTo-Json -Compress) + $acl.GetSecurityDescriptorSddlForm([Security.AccessControl.AccessControlSections]::All)
    $hasher=[Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($hasher.ComputeHash([Text.Encoding]::UTF8.GetBytes($content)))).Replace('-','').ToLowerInvariant() }
    finally { $hasher.Dispose() }
}
function Resolve-AuthWireDeploymentOwnerSid {
    param([string]$Name)
    return [Security.Principal.NTAccount]::new($Name).Translate([Security.Principal.SecurityIdentifier]).Value
}
function Get-AuthWireOwnedGpoState {
    param($Gpo,[string]$Marker,[string]$Domain,[string]$Server,[string]$DomainDn,
        [string]$OwnerSid,[string]$ServiceSid,[string]$ScopeSid,[guid]$ProtectedId)
    if($Gpo.Id -eq $ProtectedId) { throw 'PROTECTED_TRUST_GPO_CANNOT_BE_MANAGED' }
    $id=[guid]$Gpo.Id
    $dn='CN={' + $id.ToString('D') + '},CN=Policies,CN=System,' + $DomainDn
    $gpc=Get-ADObject -Identity $dn -Server $Server -Properties gPCFileSysPath -ErrorAction Stop
    # New-GPO -Comment is exposed by GPMC as Gpo.Description, not LDAP description.
    # Re-read by GUID so a cached New-GPO/Get-GPO -All object cannot hide later drift.
    $current=Get-GPO -Guid $id -Domain $Domain -Server $Server -ErrorAction Stop
    if([guid]$current.Id -ne $id -or $current.DisplayName -cne $Gpo.DisplayName) { throw 'GPO_IDENTITY_READBACK_MISMATCH' }
    if($gpc.ObjectClass -ne 'groupPolicyContainer') { throw 'GPO_OBJECT_CLASS_MISMATCH' }
    $description=$current.PSObject.Properties['Description']
    if($null -eq $description -or $description.Value -isnot [string] -or $description.Value -cne $Marker) { throw 'GPO_OWNERSHIP_MARKER_MISMATCH' }
    $paths=@(foreach($v in $gpc.gPCFileSysPath){[string]$v})
    $expectedPath=Get-AuthWireGpoRoot $id $Domain $Domain
    if($paths.Count -ne 1 -or $paths[0].TrimEnd('\') -ine $expectedPath) { throw 'GPO_SYSVOL_LOCATION_MISMATCH' }
    $actualOwner=Resolve-AuthWireDeploymentOwnerSid ([string]$current.Owner)
    if($actualOwner -ne $OwnerSid) { throw 'GPO_ADMINISTRATIVE_OWNER_MISMATCH' }
    $doc=Get-AuthWireGpoDocument $id $Domain $Server
    $linked=($doc.SelectNodes("/*[local-name()='GPO']/*[local-name()='LinksTo']").Count -ne 0)
    $settings=($doc.SelectNodes("/*[local-name()='GPO']/*[local-name()='Computer' or local-name()='User']/*[local-name()='ExtensionData']").Count -ne 0)
    if($linked -or $settings) { throw 'GPO_ALREADY_LINKED_OR_CONTAINS_SETTINGS' }
    $rows=@(Get-AuthWireGpoPermissionRows $id $Domain $Server)
    $service=@($rows | Where-Object Sid -eq $ServiceSid)
    $scope=@($rows | Where-Object Sid -eq $ScopeSid)
    $authenticated=@($rows | Where-Object Sid -eq 'S-1-5-11')
    $otherApply=@($rows | Where-Object {$_.Permission -eq 'GpoApply' -and $_.Sid -ne $ScopeSid})
    $custom=@($rows | Where-Object Permission -eq 'GpoCustom')
    $acl=Get-Acl -LiteralPath (Get-AuthWireGpoRoot $id $Domain $Server) -ErrorAction Stop
    $write=$false; $administrative=$false; $directDeny=$false
    foreach($rule in $acl.GetAccessRules($true,$true,[Security.Principal.SecurityIdentifier])) {
        if($rule.IdentityReference.Value -ne $ServiceSid) { continue }
        if($rule.AccessControlType.ToString() -eq 'Deny') { $directDeny=$true; continue }
        if(($rule.PropagationFlags -band [Security.AccessControl.PropagationFlags]::InheritOnly) -ne 0) { continue }
        if(($rule.FileSystemRights -band [Security.AccessControl.FileSystemRights]::Write) -eq [Security.AccessControl.FileSystemRights]::Write) {$write=$true}
        if(($rule.FileSystemRights -band ([Security.AccessControl.FileSystemRights]::ChangePermissions -bor [Security.AccessControl.FileSystemRights]::TakeOwnership)) -ne 0) {$administrative=$true}
    }
    $complete=($service.Count -eq 1 -and $service[0].Permission -eq 'GpoEdit' -and
        $scope.Count -eq 1 -and $scope[0].Permission -eq 'GpoApply' -and
        $authenticated.Count -eq 1 -and $authenticated[0].Permission -eq 'GpoRead' -and
        $otherApply.Count -eq 0 -and $custom.Count -eq 0 -and $write -and -not $administrative -and -not $directDeny)
    [pscustomobject]@{Id=$id.ToString('D');Name=$Gpo.DisplayName;OwnerSid=$actualOwner;Linked=$linked;ContainsSettings=$settings
        Permissions=$rows;SysvolServiceWriteMetadata=$write;SysvolServiceAdministrativeRights=$administrative;SysvolServiceDeny=$directDeny;MetadataComplete=$complete}
}
function Write-AuthWireGpoReceipt {
    param([string]$Path,$Value)
    $Value | ConvertTo-Json -Depth 7 | Set-Content -LiteralPath $Path -Encoding UTF8
}
function Read-AuthWireGpoResumeReceipt {
    param([string]$Path,[guid]$ExpectedId,[guid]$InstanceId,[string]$Name,[string]$Marker,
        [guid]$ProtectedId,[string]$ProtectedHash,[string]$OwnerSid)
    if([string]::IsNullOrWhiteSpace($Path) -or $ExpectedId -eq [guid]::Empty -or $ExpectedId -eq $ProtectedId) { throw 'EXPLICIT_RECEIPT_AND_GPO_ID_REQUIRED' }
    $root=[IO.Path]::GetFullPath([Environment]::GetFolderPath('CommonApplicationData')).TrimEnd('\')
    $full=[IO.Path]::GetFullPath($Path)
    $pattern='^' + [regex]::Escape($root) + '\\AuthWire-GpoPreparation-[a-fA-F0-9]{32}\\gpo-preparation\.json$'
    if($full -notmatch $pattern) { throw 'GPO_RECEIPT_PATH_INVALID' }
    $folder=Split-Path -Parent $full
    foreach($itemPath in @($folder,$full)) {
        $item=Get-Item -LiteralPath $itemPath -Force -ErrorAction Stop
        if(($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0) { throw 'GPO_RECEIPT_REPARSE_POINT_REJECTED' }
        if($itemPath -eq $full -and ($item.PSIsContainer -or $item.Length -gt 1048576)) { throw 'GPO_RECEIPT_FILE_INVALID' }
        $acl=Microsoft.PowerShell.Security\Get-Acl -LiteralPath $itemPath -ErrorAction Stop
        if($itemPath -eq $folder -and -not $acl.AreAccessRulesProtected) { throw 'GPO_RECEIPT_DIRECTORY_NOT_PROTECTED' }
        $currentSid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value
        $fileOwner=$acl.GetOwner([Security.Principal.SecurityIdentifier]).Value
        if($fileOwner -notin @('S-1-5-18','S-1-5-32-544',$OwnerSid,$currentSid)) { throw 'GPO_RECEIPT_OWNER_UNEXPECTED' }
        $mutation=[Security.AccessControl.FileSystemRights]::Write -bor [Security.AccessControl.FileSystemRights]::Delete -bor
            [Security.AccessControl.FileSystemRights]::DeleteSubdirectoriesAndFiles -bor [Security.AccessControl.FileSystemRights]::ChangePermissions -bor
            [Security.AccessControl.FileSystemRights]::TakeOwnership
        foreach($rule in $acl.GetAccessRules($true,$true,[Security.Principal.SecurityIdentifier])) {
            if($rule.AccessControlType.ToString() -eq 'Allow' -and ($rule.FileSystemRights -band $mutation) -ne 0 -and
                $rule.IdentityReference.Value -notin @('S-1-5-18','S-1-5-32-544')) { throw 'GPO_RECEIPT_WRITABLE_BY_OTHER_PRINCIPAL' }
        }
    }
    $record=Get-Content -LiteralPath $full -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    if($record.Version -ne 1 -or [guid]$record.InstanceId -ne $InstanceId -or [guid]$record.GpoId -ne $ExpectedId -or
        $record.Name -cne $Name -or $record.Marker -cne $Marker -or [guid]$record.ProtectedGpoId -ne $ProtectedId -or
        $record.ProtectedHash -cne $ProtectedHash) { throw 'GPO_RECEIPT_BINDING_OR_PROTECTED_BASELINE_MISMATCH' }
    if($record.Phase -notin @('created_unlinked','verified_unlinked')) { throw 'GPO_RECEIPT_PHASE_REQUIRES_REVIEW' }
    return $record
}
function Test-AuthWireGpoResumePermissions {
    param($State,[string]$DomainSid,[string]$ServiceSid,[string]$ScopeSid)
    # Only the initial creation failure is resumable. Partial permission stages require review.
    if(@($State.Permissions | Where-Object {$_.Sid -in @($ServiceSid,$ScopeSid)}).Count -ne 0) { throw 'GPO_RESUME_TARGET_PERMISSIONS_UNEXPECTED' }
    $authenticated=@($State.Permissions | Where-Object Sid -eq 'S-1-5-11')
    if($authenticated.Count -ne 1 -or $authenticated[0].Permission -ne 'GpoApply') { throw 'GPO_RESUME_INITIAL_SCOPE_UNEXPECTED' }
    foreach($row in $State.Permissions) {
        if($row.Sid -eq 'S-1-5-11' -and $row.Permission -eq 'GpoApply') { continue }
        if($row.Sid -in @(($DomainSid+'-512'),($DomainSid+'-519'),'S-1-5-18') -and $row.Permission -eq 'GpoEditDeleteModifySecurity') { continue }
        if($row.Sid -eq 'S-1-5-9' -and $row.Permission -eq 'GpoRead') { continue }
        throw 'GPO_RESUME_INITIAL_DELEGATION_REQUIRES_REVIEW'
    }
    if($State.SysvolServiceWriteMetadata -or $State.SysvolServiceAdministrativeRights -or $State.SysvolServiceDeny) { throw 'GPO_RESUME_SERVICE_SYSVOL_ACCESS_UNEXPECTED' }
}
function Invoke-AuthWireDeploymentGpoPreparation {
    [CmdletBinding()]
    param(
        [ValidateSet('Inspect','PrepareGpo','ResumeGpo')][string]$Mode='Inspect',
        [string]$PreparationReceiptPath,[guid]$ExpectedGpoId=[guid]::Empty,
        [string]$ExpectedComputer,[string]$ExpectedDomain,[guid]$InstanceId,
        [ValidatePattern('^[A-Za-z][A-Za-z0-9-]{0,14}$')][string]$AccountName='aw-deploy',
        [string]$AccountSid,[string]$ScopeGroupSid,[string]$ScopeGroupName,[guid]$ProtectedGpoId,
        [string]$BootstrapPath,[string]$PublisherThumbprint
    )
    $ErrorActionPreference='Stop'
    Set-StrictMode -Version 2
    if(-not [Environment]::Is64BitProcess -or [Environment]::MachineName -ine $ExpectedComputer) { throw 'LOCAL_COMPUTER_MISMATCH' }
    if($InstanceId -eq [guid]::Empty -or $ProtectedGpoId -eq [guid]::Empty) { throw 'INSTALLATION_AND_PROTECTED_GPO_IDS_REQUIRED' }
    $resumeRequested=($Mode -eq 'ResumeGpo' -or -not [string]::IsNullOrWhiteSpace($PreparationReceiptPath) -or $ExpectedGpoId -ne [guid]::Empty)
    if($resumeRequested -and ($Mode -eq 'PrepareGpo' -or [string]::IsNullOrWhiteSpace($PreparationReceiptPath) -or $ExpectedGpoId -eq [guid]::Empty)) { throw 'EXPLICIT_RECEIPT_AND_GPO_ID_REQUIRED' }
    $sid=[Security.Principal.SecurityIdentifier]::new($AccountSid)
    $scopeSid=[Security.Principal.SecurityIdentifier]::new($ScopeGroupSid)
    if($sid.Value -eq $scopeSid.Value) { throw 'DISTINCT_SERVICE_AND_SCOPE_REQUIRED' }
    $signature=Get-AuthenticodeSignature -FilePath $BootstrapPath
    if($signature.Status.ToString() -ne 'Valid' -or $signature.SignerCertificate.Thumbprint -ine $PublisherThumbprint) { throw 'BOOTSTRAP_SIGNATURE_INVALID' }
    $account=& $BootstrapPath -Mode Inspect -ExpectedDomain $ExpectedDomain -ConnectorComputer $ExpectedComputer -InstanceId $InstanceId -AccountName $AccountName -PublisherThumbprint $PublisherThumbprint | ConvertFrom-Json
    if($account.Event -ne 'WINDOWS_CONNECTOR_BOOTSTRAP' -or $account.BootstrapVersion -ne '1.0.3' -or $account.Mode -ne 'Inspect' -or
        $account.Domain -ine $ExpectedDomain -or $account.Computer -ine $ExpectedComputer -or $account.InstanceId -ine $InstanceId.ToString('D') -or
        -not $account.Kds.Ready -or -not $account.ReadyForAccountPreparation -or @($account.Blockers).Count -ne 0 -or
        -not $account.Account.Exists -or $account.Account.Sid -ne $sid.Value -or $account.Account.Name -ine ($AccountName+'$') -or
        $account.Account.AllowedPasswordHost -ine $ExpectedComputer) { throw 'OWNED_SERVICE_ACCOUNT_REQUIRED' }
    $hostGuid=[guid]$account.ConnectorComputerGuid
    if($hostGuid -eq [guid]::Empty) { throw 'CONNECTOR_COMPUTER_GUID_REQUIRED' }
    Import-Module ActiveDirectory -ErrorAction Stop
    Import-Module GroupPolicy -ErrorAction Stop
    $server=$ExpectedComputer + '.' + $ExpectedDomain
    $domain=Get-ADDomain -Server $server -ErrorAction Stop
    if($domain.DNSRoot -ine $ExpectedDomain -or $sid.AccountDomainSid.Value -ne $domain.DomainSID.Value -or
        $scopeSid.AccountDomainSid.Value -ne $domain.DomainSID.Value) { throw 'DOMAIN_OR_SID_SCOPE_MISMATCH' }
    $scope=Get-ADGroup -Identity $scopeSid.Value -Server $server -Properties GroupCategory -ErrorAction Stop
    if($scope.SID.Value -ne $scopeSid.Value -or $scope.Name -ine $ScopeGroupName -or $scope.GroupCategory.ToString() -ne 'Security') { throw 'SECURITY_SCOPE_GROUP_MISMATCH' }
    $principal=Resolve-AuthWireDeploymentPrincipal $sid.Value
    if($principal.Sid -ne $sid.Value -or $principal.Name -ine ($AccountName+'$') -or $principal.Domain -ine $domain.NetBIOSName) { throw 'SERVICE_PRINCIPAL_RESOLUTION_MISMATCH' }
    $principalType=Get-AuthWireGpoPrincipalType $principal.Use
    $scopePrincipal=Resolve-AuthWireDeploymentPrincipal $scopeSid.Value
    $authenticated=Resolve-AuthWireDeploymentPrincipal 'S-1-5-11'
    $name='AuthWire-Managed-Deployment-' + $InstanceId.ToString('N').Substring(0,8)
    $marker='AuthWireDeployment:v1;instance=' + $InstanceId.ToString('D') + ';host=' + $hostGuid.ToString('D') + ';service=' + $sid.Value + ';scope=' + $scopeSid.Value
    $ownerSid=$domain.DomainSID.Value + '-512'
    $protectedHash=Get-AuthWireProtectedGpoHash $ProtectedGpoId $ExpectedDomain $server
    $candidates=@(Get-GPO -All -Domain $ExpectedDomain -Server $server -ErrorAction Stop | Where-Object DisplayName -ieq $name)
    if($candidates.Count -gt 1) { throw 'MANAGED_GPO_NAME_AMBIGUOUS' }
    $state=$null; $created=$false; $resumed=$false; $permissionsChanged=$false; $receipt=$null; $blockers=@(); $readyForResume=$false
    if($candidates.Count -eq 1) {
        $state=Get-AuthWireOwnedGpoState $candidates[0] $marker $ExpectedDomain $server $domain.DistinguishedName $ownerSid $sid.Value $scopeSid.Value $ProtectedGpoId
        if(-not $state.MetadataComplete) { $blockers += 'OWNED_GPO_INCOMPLETE_REVIEW_REQUIRED' }
    }
    if($resumeRequested) {
        $record=Read-AuthWireGpoResumeReceipt $PreparationReceiptPath $ExpectedGpoId $InstanceId $name $marker $ProtectedGpoId $protectedHash $ownerSid
        if($null -eq $state -or [guid]$state.Id -ne $ExpectedGpoId) { throw 'GPO_RESUME_OBJECT_MISSING_OR_DIFFERENT' }
        if($record.Phase -eq 'verified_unlinked') {
            if(-not $state.MetadataComplete) { throw 'GPO_RESUME_VERIFIED_STATE_DRIFTED' }
        } else {
            Test-AuthWireGpoResumePermissions $state $domain.DomainSID.Value $sid.Value $scopeSid.Value
        }
        $receipt=[IO.Path]::GetFullPath($PreparationReceiptPath)
        $readyForResume=$true
    }
    if($Mode -eq 'PrepareGpo') {
        if($blockers.Count -ne 0) { throw ($blockers -join ',') }
        if($null -eq $state) {
            $raced=@(Get-GPO -All -Domain $ExpectedDomain -Server $server -ErrorAction Stop | Where-Object DisplayName -ieq $name)
            if($raced.Count -ne 0) { throw 'GPO_APPEARED_REINSPECT_DO_NOT_CREATE' }
            $folder=Join-Path ([Environment]::GetFolderPath('CommonApplicationData')) ('AuthWire-GpoPreparation-' + [guid]::NewGuid().ToString('N'))
            if(Test-Path -LiteralPath $folder) { throw 'EVIDENCE_PATH_ALREADY_EXISTS' }
            $security=New-Object Security.AccessControl.DirectorySecurity
            $security.SetSecurityDescriptorSddlForm('D:P(A;OICI;FA;;;SY)(A;OICI;FA;;;BA)')
            $null=[IO.Directory]::CreateDirectory($folder,$security)
            $receipt=Join-Path $folder 'gpo-preparation.json'
            $record=[ordered]@{Version=1;InstanceId=$InstanceId.ToString('D');Name=$name;Marker=$marker;ProtectedGpoId=$ProtectedGpoId.ToString('D')
                ProtectedHash=$protectedHash;Phase='before_create';GpoId=$null;CreatedUtc=[datetime]::UtcNow.ToString('o')}
            Write-AuthWireGpoReceipt $receipt $record
            try {
                $new=@(New-GPO -Name $name -Comment $marker -Domain $ExpectedDomain -Server $server -ErrorAction Stop)
                if($new.Count -ne 1 -or $null -eq $new[0].Id -or [guid]$new[0].Id -eq [guid]::Empty -or $new[0].Id -eq $ProtectedGpoId) { throw 'GPO_CREATE_OUTCOME_UNKNOWN_REINSPECT' }
                $created=$true
                $record.GpoId=([guid]$new[0].Id).ToString('D');$record.Phase='created_unlinked'
                Write-AuthWireGpoReceipt $receipt $record
                $null=Get-AuthWireOwnedGpoState $new[0] $marker $ExpectedDomain $server $domain.DistinguishedName $ownerSid $sid.Value $scopeSid.Value $ProtectedGpoId
                $null=Set-GPPermission -Guid $new[0].Id -TargetName $authenticated.QualifiedName -TargetType Group -PermissionLevel GpoRead -Replace -Domain $ExpectedDomain -Server $server -ErrorAction Stop
                $record.Phase='authenticated_read_only';Write-AuthWireGpoReceipt $receipt $record
                $null=Set-GPPermission -Guid $new[0].Id -TargetName $scopePrincipal.QualifiedName -TargetType Group -PermissionLevel GpoApply -Domain $ExpectedDomain -Server $server -ErrorAction Stop
                $record.Phase='pilot_scope_only';Write-AuthWireGpoReceipt $receipt $record
                $null=Set-GPPermission -Guid $new[0].Id -TargetName $principal.QualifiedName -TargetType $principalType -PermissionLevel GpoEdit -Domain $ExpectedDomain -Server $server -ErrorAction Stop
                $permissionsChanged=$true
                $record.Phase='service_edit_only';Write-AuthWireGpoReceipt $receipt $record
                $state=Get-AuthWireOwnedGpoState $new[0] $marker $ExpectedDomain $server $domain.DistinguishedName $ownerSid $sid.Value $scopeSid.Value $ProtectedGpoId
                if(-not $state.MetadataComplete) { throw 'GPO_METADATA_POSTCHECK_FAILED' }
                if((Get-AuthWireProtectedGpoHash $ProtectedGpoId $ExpectedDomain $server) -ne $protectedHash) { throw 'PROTECTED_TRUST_GPO_CHANGED_REVIEW_REQUIRED' }
                $record.Phase='verified_unlinked';$record['State']=$state
                Write-AuthWireGpoReceipt $receipt $record
            } catch { throw ('GPO_PREPARATION_RESULT_REQUIRES_REINSPECTION:' + $receipt + ':' + $_.Exception.Message) }
        }
    }
    if($Mode -eq 'ResumeGpo' -and $record.Phase -eq 'created_unlinked') {
        try {
            # Repeat all live identity/state checks immediately before changing the pinned GUID.
            $state=Get-AuthWireOwnedGpoState $candidates[0] $marker $ExpectedDomain $server $domain.DistinguishedName $ownerSid $sid.Value $scopeSid.Value $ProtectedGpoId
            Test-AuthWireGpoResumePermissions $state $domain.DomainSID.Value $sid.Value $scopeSid.Value
            if((Get-AuthWireProtectedGpoHash $ProtectedGpoId $ExpectedDomain $server) -ne $record.ProtectedHash) { throw 'PROTECTED_TRUST_GPO_CHANGED_REVIEW_REQUIRED' }
            $record | Add-Member -NotePropertyName ResumeStartedUtc -NotePropertyValue ([datetime]::UtcNow.ToString('o')) -Force
            $record | Add-Member -NotePropertyName ResumeToolVersion -NotePropertyValue '1.0.1' -Force
            Write-AuthWireGpoReceipt $receipt $record
            $null=Set-GPPermission -Guid $ExpectedGpoId -TargetName $authenticated.QualifiedName -TargetType Group -PermissionLevel GpoRead -Replace -Domain $ExpectedDomain -Server $server -ErrorAction Stop
            $permissionsChanged=$true
            $record.Phase='authenticated_read_only';Write-AuthWireGpoReceipt $receipt $record
            $null=Set-GPPermission -Guid $ExpectedGpoId -TargetName $scopePrincipal.QualifiedName -TargetType Group -PermissionLevel GpoApply -Domain $ExpectedDomain -Server $server -ErrorAction Stop
            $record.Phase='pilot_scope_only';Write-AuthWireGpoReceipt $receipt $record
            $null=Set-GPPermission -Guid $ExpectedGpoId -TargetName $principal.QualifiedName -TargetType $principalType -PermissionLevel GpoEdit -Domain $ExpectedDomain -Server $server -ErrorAction Stop
            $record.Phase='service_edit_only';Write-AuthWireGpoReceipt $receipt $record
            $state=Get-AuthWireOwnedGpoState $candidates[0] $marker $ExpectedDomain $server $domain.DistinguishedName $ownerSid $sid.Value $scopeSid.Value $ProtectedGpoId
            if(-not $state.MetadataComplete) { throw 'GPO_METADATA_POSTCHECK_FAILED' }
            if((Get-AuthWireProtectedGpoHash $ProtectedGpoId $ExpectedDomain $server) -ne $record.ProtectedHash) { throw 'PROTECTED_TRUST_GPO_CHANGED_REVIEW_REQUIRED' }
            $record.Phase='verified_unlinked'
            $record | Add-Member -NotePropertyName State -NotePropertyValue $state -Force
            Write-AuthWireGpoReceipt $receipt $record
            $resumed=$true; $blockers=@()
        } catch { throw ('GPO_PREPARATION_RESULT_REQUIRES_REINSPECTION:' + $receipt + ':' + $_.Exception.Message) }
    }
    if((Get-AuthWireProtectedGpoHash $ProtectedGpoId $ExpectedDomain $server) -ne $protectedHash) { throw 'PROTECTED_TRUST_GPO_CHANGED_REVIEW_REQUIRED' }
    [pscustomobject]@{
        Event='WINDOWS_CONNECTOR_DEPLOYMENT_GPO_PREPARATION';ToolVersion='1.0.1';Mode=$Mode;Computer=$ExpectedComputer;Domain=$ExpectedDomain
        ProposedGpoName=$name;InstanceId=$InstanceId.ToString('D');ServiceAccount=$principal.QualifiedName;ServiceSid=$sid.Value;ServiceTargetType=$principalType
        ScopeGroup=$scope.Name;ScopeGroupSid=$scopeSid.Value;ScopeGroupApplyOnly=$true;ProtectedTrustGpoId=$ProtectedGpoId.ToString('D');ProtectedTrustPreserved=$true
        GpoExists=($null -ne $state);GpoCreated=$created;GpoResumed=$resumed;GpoState=$state;OwnershipMarker=$marker;Blockers=$blockers;ReadyForPrepare=($blockers.Count -eq 0);ReadyForResume=$readyForResume
        ReceiptPath=$receipt;AdChanged=($created -or $permissionsChanged);GpoChanged=($created -or $permissionsChanged);GpoLinked=$false;SettingsApplied=$false
        ServiceWriteAccessVerified=$false;SigningKeyAccessVerified=$false;ConnectorInstalled=$false;CanApplyGpo=$false
    }
}

Invoke-AuthWireDeploymentGpoPreparation -Mode $Mode -ExpectedComputer $ExpectedComputer -ExpectedDomain $ExpectedDomain `
    -PreparationReceiptPath $PreparationReceiptPath -ExpectedGpoId $ExpectedGpoId `
    -InstanceId $InstanceId -AccountName $AccountName -AccountSid $AccountSid -ScopeGroupSid $ScopeGroupSid `
    -ScopeGroupName $ScopeGroupName -ProtectedGpoId $ProtectedGpoId -BootstrapPath $BootstrapPath `
    -PublisherThumbprint $PublisherThumbprint | ConvertTo-Json -Depth 8

