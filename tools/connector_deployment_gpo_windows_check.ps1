# Native SID APIs plus complete GPO-preparation algorithm with AD/GPMC calls simulated.
$ErrorActionPreference='Stop'
if($env:RUNNER_ENVIRONMENT -ne 'github-hosted') {throw 'Hosted fixture only.'}
Microsoft.PowerShell.Core\Import-Module ActiveDirectory -ErrorAction Stop
$source=Join-Path $PSScriptRoot '..\windows\connector\Initialize-AuthWireDeploymentGpo.ps1'
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile($source,[ref]$tokens,[ref]$errors)
if($errors.Count){throw ($errors.Message -join '; ')}
$functions=@($ast.FindAll({param($n)$n -is [Management.Automation.Language.FunctionDefinitionAst]},$true))
. ([scriptblock]::Create(($functions|ForEach-Object{$_.Extent.Text}) -join [Environment]::NewLine))
$script:checks=0
function Check([bool]$Value,[string]$Name){if(-not $Value){throw $Name};$script:checks++}
$actualUser=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value
$user=Resolve-AuthWireDeploymentPrincipal $actualUser
Check ($user.Sid -eq $actualUser -and $user.Use -eq 1 -and $user.QualifiedName.Length -gt 0) 'Real native user SID lookup'
$group=Resolve-AuthWireDeploymentPrincipal 'S-1-5-32-544'
Check ($group.Use -eq 4 -and $group.Name.Length -gt 0) 'Real native alias SID lookup'
$auth=Resolve-AuthWireDeploymentPrincipal 'S-1-5-11'
Check ($auth.Use -eq 5) 'Real native well-known SID lookup'
Check ((Get-AuthWireGpoPrincipalType 1) -eq 'User' -and (Get-AuthWireGpoPrincipalType 9) -eq 'Computer') 'User and computer GPMC types mapped explicitly'
$caught=$false
try{$null=Get-AuthWireGpoPrincipalType 2}catch{$caught=$true}
Check $caught 'Group SID cannot be used as service identity'

$computer=[Environment]::MachineName;$instance=[guid]'4c23eebe-0715-46d1-88ee-a2e96ad7ee46'
$protected=[guid]'e5a9ab39-3709-49cb-837a-0208d2eb3b12';$publisher='A'*40
$domainSid='S-1-5-21-111-222-333';$serviceSid=$domainSid+'-1648';$scopeSid=$domainSid+'-1647'
$fake=Join-Path $env:RUNNER_TEMP ('AuthWire-Gpo-Fixture-'+[guid]::NewGuid().ToString('N')+'.ps1')
@'
param($Mode,$ExpectedDomain,$ConnectorComputer,$InstanceId,$AccountName,$PublisherThumbprint)
if($Mode -ne 'Inspect'){throw 'Bootstrap mutation attempted.'}
$global:AwGpoFixture.Inspection|ConvertTo-Json -Depth 6
'@|Set-Content -LiteralPath $fake -Encoding UTF8
function Reset-Fixture {
    $global:AwGpoFixture=@{
        Gpo=$null;Description=$null;Permissions=@{};Creates=0;Writes=0;AllReads=0;Folders=@()
        Signature=$true;ReadFails=$false;Race=$false;ServiceUse=9;GroupCategory='Security'
        Linked=$false;Settings=$false;Owner='TEST\Domain Admins';SysvolWrite=$true
        BadSysvol=$false;ProtectedDrift=$false;FailPermission=0
        Inspection=[pscustomobject]@{Event='WINDOWS_CONNECTOR_BOOTSTRAP';BootstrapVersion='1.0.3';Mode='Inspect'
            Domain='test.example';Computer=$computer;ConnectorComputerGuid='0fa4143f-aae3-4bc3-9cd3-db8a1de24acd';InstanceId=$instance.ToString('D')
            Kds=[pscustomobject]@{Ready=$true};ReadyForAccountPreparation=$true;Blockers=@()
            Account=[pscustomobject]@{Exists=$true;Sid=$serviceSid;Name='aw-deploy$';AllowedPasswordHost=$computer}}
    }
}
function Import-Module {[CmdletBinding()]param([string]$Name)}
function Get-AuthenticodeSignature {[CmdletBinding()]param([string]$FilePath)
    [pscustomobject]@{Status=$(if($global:AwGpoFixture.Signature){'Valid'}else{'HashMismatch'});SignerCertificate=[pscustomobject]@{Thumbprint=$publisher}}
}
function Get-ADDomain {[CmdletBinding()]param([string]$Server)
    if($global:AwGpoFixture.ReadFails){throw 'DIRECTORY_READ_FAILED'}
    [pscustomobject]@{DNSRoot='test.example';DomainSID=[Security.Principal.SecurityIdentifier]::new($domainSid);NetBIOSName='TEST';DistinguishedName='DC=test,DC=example'}
}
function Get-ADGroup {[CmdletBinding()]param([string]$Identity,[string]$Server,[string[]]$Properties)
    [pscustomobject]@{Name='AuthWire-Pilot-Computers';SID=[Security.Principal.SecurityIdentifier]::new($scopeSid);GroupCategory=$global:AwGpoFixture.GroupCategory}
}
function Resolve-AuthWireDeploymentPrincipal {param([string]$Sid)
    if($Sid -eq $serviceSid){return [pscustomobject]@{Sid=$Sid;Name='aw-deploy$';Domain='TEST';QualifiedName='TEST\aw-deploy$';Use=$global:AwGpoFixture.ServiceUse}}
    if($Sid -eq $scopeSid){return [pscustomobject]@{Sid=$Sid;Name='AuthWire-Pilot-Computers';Domain='TEST';QualifiedName='TEST\AuthWire-Pilot-Computers';Use=2}}
    if($Sid -eq 'S-1-5-11'){return [pscustomobject]@{Sid=$Sid;Name='Authenticated Users';Domain='NT AUTHORITY';QualifiedName='NT AUTHORITY\Authenticated Users';Use=5}}
    throw 'UNEXPECTED_FIXTURE_SID'
}
function Resolve-AuthWireDeploymentOwnerSid {param([string]$Name)
    if($Name -eq 'TEST\Domain Admins'){return ($domainSid+'-512')}
    return $serviceSid
}
function Get-GPO {[CmdletBinding()]param([switch]$All,[guid]$Guid,[string]$Domain,[string]$Server)
    if($All){
        $global:AwGpoFixture.AllReads++
        if($global:AwGpoFixture.Race -and $global:AwGpoFixture.AllReads -gt 1){
            return [pscustomobject]@{Id=[guid]::NewGuid();DisplayName='AuthWire-Managed-Deployment-4c23eebe';Owner='TEST\Domain Admins'}
        }
        if($null -ne $global:AwGpoFixture.Gpo){return $global:AwGpoFixture.Gpo}
        return
    }
    throw 'Unexpected Get-GPO query'
}
function New-GPO {[CmdletBinding()]param([string]$Name,[string]$Comment,[string]$Domain,[string]$Server)
    if($Name -ne 'AuthWire-Managed-Deployment-4c23eebe' -or $Domain -ne 'test.example'){throw 'Create scope escaped'}
    $global:AwGpoFixture.Creates++
    $global:AwGpoFixture.Description=$Comment
    $global:AwGpoFixture.Gpo=[pscustomobject]@{Id=[guid]::NewGuid();DisplayName=$Name;Owner=$global:AwGpoFixture.Owner}
    $global:AwGpoFixture.Permissions=@{'S-1-5-11'='GpoApply';($domainSid+'-512')='GpoEditDeleteModifySecurity';'S-1-5-18'='GpoEditDeleteModifySecurity'}
    return $global:AwGpoFixture.Gpo
}
function Get-GPOReport {[CmdletBinding()]param([guid]$Guid,[string]$Domain,[string]$Server,[string]$ReportType)
    $time=[datetime]::UtcNow.ToString('o')
    if($Guid -eq $protected){
        $extra=$(if($global:AwGpoFixture.ProtectedDrift -and $global:AwGpoFixture.Creates -gt 0){'<RegistryChanged/>'}else{''})
        return ('<GPO><ReadTime>'+ $time +'</ReadTime><Computer><ExtensionData><Name>Public Key</Name>'+ $extra +'</ExtensionData></Computer><User/><LinksTo><SOMPath>test.example</SOMPath></LinksTo></GPO>')
    }
    if($null -eq $global:AwGpoFixture.Gpo -or $Guid -ne $global:AwGpoFixture.Gpo.Id){throw 'Unexpected report target'}
    $settings=$(if($global:AwGpoFixture.Settings){'<ExtensionData><Name>Registry</Name></ExtensionData>'}else{''})
    $links=$(if($global:AwGpoFixture.Linked){'<LinksTo><SOMPath>test.example</SOMPath></LinksTo>'}else{''})
    return ('<GPO><ReadTime>'+$time+'</ReadTime><Computer>'+$settings+'</Computer><User/>'+$links+'</GPO>')
}
function Get-ADObject {[CmdletBinding()]param([string]$Identity,[string]$Server,[string[]]$Properties)
    if($null -eq $global:AwGpoFixture.Gpo -or $Identity -ine ('CN={'+$global:AwGpoFixture.Gpo.Id.ToString('D')+'},CN=Policies,CN=System,DC=test,DC=example')){throw 'Unexpected GPC read'}
    $description=New-Object Microsoft.ActiveDirectory.Management.ADPropertyValueCollection
    $null=$description.Add($global:AwGpoFixture.Description)
    $path='\\test.example\SYSVOL\test.example\Policies\{'+$global:AwGpoFixture.Gpo.Id.ToString('D')+'}'
    if($global:AwGpoFixture.BadSysvol){$path='\\unapproved.example\share'}
    [pscustomobject]@{ObjectClass='groupPolicyContainer';description=$description;gPCFileSysPath=$path}
}
function Get-GPPermission {[CmdletBinding()]param([guid]$Guid,[switch]$All,[string]$Domain,[string]$Server)
    $perms=$(if($Guid -eq $protected){@{'S-1-5-11'='GpoRead';($domainSid+'-512')='GpoEditDeleteModifySecurity'}}else{$global:AwGpoFixture.Permissions})
    foreach($sid in $perms.Keys){[pscustomobject]@{Trustee=[pscustomobject]@{Sid=[Security.Principal.SecurityIdentifier]::new($sid)};Permission=$perms[$sid]}}
}
function Set-GPPermission {[CmdletBinding()]param([guid]$Guid,[string]$TargetName,[string]$TargetType,[string]$PermissionLevel,[switch]$Replace,[string]$Domain,[string]$Server)
    if($Guid -eq $protected -or $Guid -ne $global:AwGpoFixture.Gpo.Id){throw 'Protected or unrelated GPO mutation attempted'}
    $global:AwGpoFixture.Writes++
    if($global:AwGpoFixture.FailPermission -eq $global:AwGpoFixture.Writes){throw 'SIMULATED_GPMC_FAILURE'}
    switch($TargetName){
        'NT AUTHORITY\Authenticated Users' {if(-not $Replace -or $PermissionLevel -ne 'GpoRead' -or $TargetType -ne 'Group'){throw 'Broad authenticated permission'};$sid='S-1-5-11'}
        'TEST\AuthWire-Pilot-Computers' {if($PermissionLevel -ne 'GpoApply' -or $TargetType -ne 'Group'){throw 'Scope permission escaped'};$sid=$scopeSid}
        'TEST\aw-deploy$' {if($PermissionLevel -ne 'GpoEdit' -or $TargetType -ne (Get-AuthWireGpoPrincipalType $global:AwGpoFixture.ServiceUse)){throw 'Service permission escaped'};$sid=$serviceSid}
        default {throw 'Unknown permission target'}
    }
    $global:AwGpoFixture.Permissions[$sid]=$PermissionLevel
}
function Get-Acl {[CmdletBinding()]param([string]$LiteralPath)
    $acl=New-Object Security.AccessControl.DirectorySecurity
    $acl.SetOwner([Security.Principal.SecurityIdentifier]::new($domainSid+'-512'))
    $acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new([Security.Principal.SecurityIdentifier]::new($domainSid+'-512'),[Security.AccessControl.FileSystemRights]::FullControl,[Security.AccessControl.AccessControlType]::Allow))
    if($LiteralPath -notlike ('*{'+$protected.ToString('D')+'}') -and $global:AwGpoFixture.Permissions.ContainsKey($serviceSid) -and $global:AwGpoFixture.SysvolWrite){
        $rights=[Security.AccessControl.FileSystemRights]::ReadAndExecute -bor [Security.AccessControl.FileSystemRights]::Write
        $acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new([Security.Principal.SecurityIdentifier]::new($serviceSid),$rights,[Security.AccessControl.AccessControlType]::Allow))
    }
    return $acl
}
function Run-Fixture([string]$Mode='Inspect'){
    Invoke-AuthWireDeploymentGpoPreparation -Mode $Mode -ExpectedComputer $computer -ExpectedDomain 'test.example' -InstanceId $instance `
        -AccountSid $serviceSid -ScopeGroupSid $scopeSid -ScopeGroupName 'AuthWire-Pilot-Computers' -ProtectedGpoId $protected -BootstrapPath $fake -PublisherThumbprint $publisher
}
function Expect-Blocked([string]$Code){
    $caught=$false;try{$null=Run-Fixture 'PrepareGpo'}catch{if($_.Exception.Message -notlike ('*'+$Code+'*')){throw};$caught=$true}
    Check $caught ('Blocked '+$Code)
    Check ($global:AwGpoFixture.Creates -eq 0 -and $global:AwGpoFixture.Writes -eq 0) 'Blocked preflight performs no AD/GPO writes'
}
function Track-Receipt($r){if($null -ne $r.ReceiptPath){$script:folders += Split-Path -Parent $r.ReceiptPath}}
$script:folders=@()
try{
    Reset-Fixture;$r=Run-Fixture
    Check ($r.ReadyForPrepare -and -not $r.GpoExists -and -not $r.AdChanged -and -not $r.GpoChanged -and $global:AwGpoFixture.Creates -eq 0) 'Default inspect reads only and previews absent managed GPO'
    Reset-Fixture;$global:AwGpoFixture.Signature=$false;Expect-Blocked 'BOOTSTRAP_SIGNATURE_INVALID'
    Reset-Fixture;$global:AwGpoFixture.Inspection.Blockers=@('BAD_OWNER');Expect-Blocked 'OWNED_SERVICE_ACCOUNT_REQUIRED'
    Reset-Fixture;$global:AwGpoFixture.ReadFails=$true;Expect-Blocked 'DIRECTORY_READ_FAILED'
    Reset-Fixture;$global:AwGpoFixture.GroupCategory='Distribution';Expect-Blocked 'SECURITY_SCOPE_GROUP_MISMATCH'
    Reset-Fixture;$global:AwGpoFixture.ServiceUse=2;Expect-Blocked 'SERVICE_SID_TYPE_UNSUPPORTED'
    Reset-Fixture;$global:AwGpoFixture.Race=$true;Expect-Blocked 'GPO_APPEARED_REINSPECT_DO_NOT_CREATE'
    foreach($use in @(1,9)){
        Reset-Fixture;$global:AwGpoFixture.ServiceUse=$use
        $r=Run-Fixture 'PrepareGpo';Track-Receipt $r
        Check ($r.GpoCreated -and $r.GpoState.MetadataComplete -and $global:AwGpoFixture.Creates -eq 1 -and $global:AwGpoFixture.Writes -eq 3) 'One owned GPO and exactly three bounded permission changes'
        Check (-not $r.GpoLinked -and -not $r.SettingsApplied -and -not $r.ServiceWriteAccessVerified -and -not $r.ConnectorInstalled -and -not $r.CanApplyGpo -and $r.ProtectedTrustPreserved) 'Prepared metadata never implies linking, execution or real service write'
        $saved=Get-Content -LiteralPath $r.ReceiptPath -Raw|ConvertFrom-Json
        Check ($saved.Phase -eq 'verified_unlinked' -and $saved.GpoId -eq $r.GpoState.Id) 'Receipt binds created GUID and verified stage'
        $folderAcl=Microsoft.PowerShell.Security\Get-Acl -LiteralPath (Split-Path -Parent $r.ReceiptPath)
        Check $folderAcl.AreAccessRulesProtected 'Preparation receipt inheritance protected'
        $second=Run-Fixture 'PrepareGpo'
        Check (-not $second.GpoCreated -and -not $second.AdChanged -and $global:AwGpoFixture.Creates -eq 1 -and $global:AwGpoFixture.Writes -eq 3) 'Matching complete setup is a no-op'
    }
    foreach($bad in @('marker','linked','settings','owner','path','partial','otherApply')){
        Reset-Fixture;$r=Run-Fixture 'PrepareGpo';Track-Receipt $r
        switch($bad){
            'marker' {$global:AwGpoFixture.Description='Customer GPO'}
            'linked' {$global:AwGpoFixture.Linked=$true}
            'settings' {$global:AwGpoFixture.Settings=$true}
            'owner' {$global:AwGpoFixture.Gpo.Owner='TEST\aw-deploy$'}
            'path' {$global:AwGpoFixture.BadSysvol=$true}
            'partial' {$global:AwGpoFixture.Permissions[$serviceSid]='GpoEditDeleteModifySecurity'}
            'otherApply' {$global:AwGpoFixture.Permissions[$domainSid+'-513']='GpoApply'}
        }
        $before=$global:AwGpoFixture.Writes;$caught=$false
        try{$null=Run-Fixture 'PrepareGpo'}catch{$caught=$true}
        Check ($caught -and $global:AwGpoFixture.Writes -eq $before -and $global:AwGpoFixture.Creates -eq 1) ('Existing drift not repaired or adopted: '+$bad)
    }
    Reset-Fixture;$global:AwGpoFixture.FailPermission=2
    $caught=$false
    try{$null=Run-Fixture 'PrepareGpo'}catch{Check ($_.Exception.Message -like '*RESULT_REQUIRES_REINSPECTION*') 'Partial failure points to protected receipt';$caught=$true}
    Check ($caught -and $global:AwGpoFixture.Creates -eq 1 -and -not $global:AwGpoFixture.Linked) 'Permission failure leaves a single unlinked GPO and never deletes/recreates it'
    $state=Run-Fixture
    Check (-not $state.ReadyForPrepare -and $state.Blockers -contains 'OWNED_GPO_INCOMPLETE_REVIEW_REQUIRED') 'Partial setup inspect remains blocked for review'
    $text=[IO.File]::ReadAllText($source)
    Check (-not $text.Contains('New-GPLink') -and -not $text.Contains('Remove-GPO') -and -not $text.Contains('Add-ADGroupMember')) 'No linking, deletion or membership write APIs'
    Write-Output ('AUTHWIRE_DEPLOYMENT_GPO_PREPARATION_OK '+(@{checks=$checks;native_powershell=$PSVersionTable.PSVersion.ToString();native_sid_lookup_tested=$true;ad_gpmc_calls_mocked=$true;real_gpo_created=$false;real_service_write_tested=$false;customer_state_used=$false}|ConvertTo-Json -Compress))
}finally{
    foreach($folder in $script:folders){Remove-Item -LiteralPath $folder -Recurse -Force -ErrorAction SilentlyContinue}
    Remove-Item -LiteralPath $fake -Force -ErrorAction SilentlyContinue
    Remove-Variable AwGpoFixture -Scope Global -ErrorAction SilentlyContinue
}
