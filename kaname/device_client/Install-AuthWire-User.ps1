# Sign both user scripts with the enterprise Authenticode publisher.
# Run as a User Configuration logon script; never SYSTEM or elevated service.
param([switch]$RunClient,[switch]$ValidateOnly)
$ErrorActionPreference='Stop'
function Get-AuthWireUserContext {
    $identity=[Security.Principal.WindowsIdentity]::GetCurrent()
    try {
        $sid=$identity.User.Value
        if($sid -notmatch '^S-1-5-21-(?:[0-9]+-){3}[0-9]+$' -or $identity.IsSystem -or $identity.Name.EndsWith('$')) { throw 'A signed-in user context is required.' }
        return $sid
    } finally { $identity.Dispose() }
}
function Assert-AuthWireUserPath([string]$Path) {
    $item=[IO.Path]::GetFullPath($Path)
    while($item) {
        if((Test-Path -LiteralPath $item) -and ((Get-Item -LiteralPath $item -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'User enrollment reparse point refused.' }
        $parent=[IO.Directory]::GetParent($item)
        $item=if($parent){$parent.FullName}else{$null}
    }
}
function Get-AuthWireUserTarget([string]$Profile) {
    if($Profile -cnotmatch '^[0-9a-f]{8}-(?:[0-9a-f]{4}-){3}[0-9a-f]{12}$') { throw 'Invalid user profile identifier.' }
    return Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) ('AuthWire\UserEnrollment\'+$Profile)
}
function Initialize-AuthWireUserDirectory([string]$Directory,[string]$Profile,[string]$Sid) {
    $expected=Get-AuthWireUserTarget $Profile
    if([IO.Path]::GetFullPath($Directory).TrimEnd('\') -ine [IO.Path]::GetFullPath($expected).TrimEnd('\')) { throw 'User enrollment directory mismatch.' }
    Assert-AuthWireUserPath $Directory
    $null=[IO.Directory]::CreateDirectory($Directory)
    $acl=New-Object Security.AccessControl.DirectorySecurity
    $acl.SetAccessRuleProtection($true,$false)
    $acl.SetOwner((New-Object Security.Principal.SecurityIdentifier($Sid)))
    foreach($principal in @($Sid,'S-1-5-18','S-1-5-32-544')) {
        $acl.AddAccessRule((New-Object Security.AccessControl.FileSystemAccessRule((New-Object Security.Principal.SecurityIdentifier($principal)),'FullControl','ContainerInherit,ObjectInherit','None','Allow')))
    }
    Set-Acl -LiteralPath $Directory -AclObject $acl
}
function Get-AuthWireUserHash([byte[]]$Bytes) {
    $hash=[Security.Cryptography.SHA256]::Create()
    try { return [BitConverter]::ToString($hash.ComputeHash($Bytes)).Replace('-','').ToLowerInvariant() } finally { $hash.Dispose() }
}
function Assert-AuthWireUserPackage([string]$Directory) {
    Assert-AuthWireUserPath $Directory
    $publisher=$null
    foreach($name in @('Install-AuthWire-User.ps1','AuthWire-User-Client.ps1')) {
        $signature=Get-AuthenticodeSignature (Join-Path $Directory $name)
        if($signature.Status -ne 'Valid') { throw 'Valid enterprise Authenticode signatures are required.' }
        if(!$publisher){$publisher=$signature.SignerCertificate.Thumbprint}
        if($signature.SignerCertificate.Thumbprint -ne $publisher) { throw 'User scripts must have the same trusted publisher.' }
    }
    $expected=@'
__AUTHWIRE_USER_ASSET_HASHES__
'@ | ConvertFrom-Json
    $verified=@{}
    foreach($asset in $expected.PSObject.Properties) {
        if($asset.Name -notin @('config.json','root-ca.pem','issuer-ca.pem','https-trust.pem')) { throw 'Unexpected user package asset.' }
        $file=Join-Path $Directory $asset.Name;Assert-AuthWireUserPath $file
        $bytes=[IO.File]::ReadAllBytes($file)
        if((Get-AuthWireUserHash $bytes) -ine $asset.Value) { throw 'Signed user package asset was changed.' }
        $verified[$asset.Name]=$bytes
    }
    foreach($required in @('config.json','root-ca.pem','issuer-ca.pem')) { if(!$verified.ContainsKey($required)){throw 'Incomplete user package.'} }
    $config=[Text.Encoding]::UTF8.GetString($verified['config.json'])|ConvertFrom-Json
    $uri=[Uri]$config.url
    if($config.kind -cne 'user' -or $uri.Scheme -ne 'https' -or $uri.HostNameType -ne [UriHostNameType]::Dns -or $config.spn -cne ('HTTP/'+$uri.DnsSafeHost) -or $uri.AbsolutePath -ne '/' -or $uri.Query -or $uri.Fragment -or $uri.UserInfo -or $config.url.EndsWith('/') -or $config.tls_sha256 -cnotmatch '^[0-9a-f]{64}$') { throw 'Invalid user HTTPS/SPN configuration.' }
    $null=Get-AuthWireUserTarget $config.profile_id
    return @{config=$config;assets=$verified;publisher=$publisher}
}
function Get-AuthWireUserTaskXml([string]$Sid,[string]$Launcher) {
    $boundary=(Get-Date).Date.ToString('yyyy-MM-ddTHH:mm:ss')
    $exe=[Security.SecurityElement]::Escape((Join-Path ([Environment]::GetFolderPath('System')) 'WindowsPowerShell\v1.0\powershell.exe'))
    $arguments=[Security.SecurityElement]::Escape('-NoProfile -NonInteractive -ExecutionPolicy AllSigned -File "'+$Launcher+'" -RunClient')
    return @"
<Task version="1.3" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
<RegistrationInfo><Author>$Sid</Author><Description>AuthWire managed user certificate enrollment</Description></RegistrationInfo>
<Triggers><LogonTrigger><Enabled>true</Enabled><UserId>$Sid</UserId></LogonTrigger><CalendarTrigger><Repetition><Interval>PT5M</Interval><Duration>P1D</Duration><StopAtDurationEnd>false</StopAtDurationEnd></Repetition><StartBoundary>$boundary</StartBoundary><Enabled>true</Enabled><ScheduleByDay><DaysInterval>1</DaysInterval></ScheduleByDay></CalendarTrigger></Triggers>
<Principals><Principal id="User"><UserId>$Sid</UserId><LogonType>InteractiveToken</LogonType><RunLevel>LeastPrivilege</RunLevel></Principal></Principals>
<Settings><MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy><DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries><StopIfGoingOnBatteries>false</StopIfGoingOnBatteries><StartWhenAvailable>true</StartWhenAvailable><RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable><Enabled>true</Enabled><ExecutionTimeLimit>PT8M</ExecutionTimeLimit></Settings>
<Actions Context="User"><Exec><Command>$exe</Command><Arguments>$arguments</Arguments></Exec></Actions>
</Task>
"@
}
if($ValidateOnly){return}
$sid=Get-AuthWireUserContext
$package=Assert-AuthWireUserPackage $PSScriptRoot
$target=Get-AuthWireUserTarget $package.config.profile_id
$taskName='AuthWire User Enrollment '+$sid+' '+$package.config.profile_id
if($RunClient) {
    if([IO.Path]::GetFullPath($PSScriptRoot).TrimEnd('\') -ine [IO.Path]::GetFullPath($target).TrimEnd('\')){throw 'User launcher requires its installed directory.'}
    $arguments='-NoProfile -NonInteractive -ExecutionPolicy AllSigned -File "'+(Join-Path $target 'AuthWire-User-Client.ps1')+'"'
    $child=Start-Process -FilePath (Join-Path ([Environment]::GetFolderPath('System')) 'WindowsPowerShell\v1.0\powershell.exe') -ArgumentList $arguments -WindowStyle Hidden -Wait -PassThru
    $child.Refresh();exit ([int]$child.ExitCode)
}
Initialize-AuthWireUserDirectory $target $package.config.profile_id $sid
$lock=[IO.File]::Open((Join-Path $target 'run.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
try {
    foreach($name in @('AuthWire-User-Client.ps1','Install-AuthWire-User.ps1')+@($package.assets.Keys)) {
        $destination=Join-Path $target $name;Assert-AuthWireUserPath $destination
        if($package.assets.ContainsKey($name)){[IO.File]::WriteAllBytes($destination,[byte[]]$package.assets[$name])}
        elseif([IO.Path]::GetFullPath((Join-Path $PSScriptRoot $name)) -ine [IO.Path]::GetFullPath($destination)){Copy-Item -LiteralPath (Join-Path $PSScriptRoot $name) -Destination $destination -Force}
    }
    $null=Assert-AuthWireUserPackage $target
    foreach($entry in @(@('root-ca.pem','Root'),@('issuer-ca.pem','CA'),@('https-trust.pem','Root'))) {
        $file=Join-Path $target $entry[0]
        if(Test-Path -LiteralPath $file){$cert=New-Object Security.Cryptography.X509Certificates.X509Certificate2($file);$store=New-Object Security.Cryptography.X509Certificates.X509Store($entry[1],'CurrentUser');try{$store.Open('ReadWrite');$store.Add($cert)}finally{$store.Close();$cert.Dispose()}}
    }
    $existing=Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if($existing -and ($existing.Description -ne 'AuthWire managed user certificate enrollment' -or $existing.Principal.UserId -notin @($sid,[Security.Principal.WindowsIdentity]::GetCurrent().Name))){throw 'Unexpected existing user enrollment task.'}
    $xml=Get-AuthWireUserTaskXml $sid (Join-Path $target 'Install-AuthWire-User.ps1')
    $null=Register-ScheduledTask -TaskName $taskName -Xml $xml -Force
    $scheduler=New-Object -ComObject 'Schedule.Service';$scheduler.Connect()
    $scheduler.GetFolder('\').GetTask($taskName).SetSecurityDescriptor(('D:P(A;;GA;;;SY)(A;;GA;;;BA)(A;;GA;;;'+$sid+')'),0)
} finally {$lock.Dispose()}
$task=Get-ScheduledTask -TaskName $taskName
if($task.State -notin @('Running','Queued')){Start-ScheduledTask -TaskName $taskName}
Write-Output 'AuthWire user enrollment installed. Runs only in this signed-in user context.'
