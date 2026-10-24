# Hosted disposable USER fixture. Synthetic AD/transport, real user CNG/certreq,
# signed package, CurrentUser stores, state recovery and interactive task definition.
$ErrorActionPreference='Stop'
if($env:RUNNER_ENVIRONMENT -ne 'github-hosted'){throw 'Disposable hosted runner required.'}
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$fixture=Join-Path $env:RUNNER_TEMP ('authwire-user-ci-'+[guid]::NewGuid().ToString('N'))
$null=New-Item $fixture -ItemType Directory;$null=New-Item (Join-Path $fixture 'USER_CLIENT_FIXTURE_ONLY') -ItemType File
$signer=$null;$target=$null;$taskName=$null;$trust=@();$createdContainers=@();$createdThumbs=@()
function Check([bool]$Condition,[string]$Message){if(!$Condition){throw $Message}}
function Read-State([string]$Name){return Get-Content -LiteralPath (Join-Path $target $Name) -Raw|ConvertFrom-Json}
function Write-State([string]$Name,$Value){[IO.File]::WriteAllText((Join-Path $target $Name),($Value|ConvertTo-Json -Depth 8),(New-Object Text.UTF8Encoding($false)))}
function Force-Due {
    if(Test-Path (Join-Path $target 'retry.json')){$r=Read-State 'retry.json';$r.next_attempt=[DateTimeOffset]::UtcNow.AddSeconds(-1).ToString('o');Write-State 'retry.json' $r}
    if(Test-Path (Join-Path $target 'installed.json')){$i=Read-State 'installed.json';$i.next_check=[DateTimeOffset]::UtcNow.AddSeconds(-1).ToString('o');Write-State 'installed.json' $i}
}
function Fixture-Call([string]$Step){$output=& python -m tools.user_client_fixture --root $fixture --step $Step;if($LASTEXITCODE -ne 0){throw ('User issuer fixture failed: '+$Step)};return ($output|ConvertFrom-Json)}
try {
    Write-Host 'USER_CI_STAGE prepare'
    Set-Location $repo
    $ready=Fixture-Call 'prepare';$profile=$ready.profile_id;$package=Join-Path $fixture 'package'
    Write-Host 'USER_CI_STAGE signing'
    $signer=New-SelfSignedCertificate -Type CodeSigningCert -Subject ('CN=AuthWire User CI '+[guid]::NewGuid()) -CertStoreLocation Cert:\CurrentUser\My
    foreach($storeName in @('Root','TrustedPublisher')){$store=New-Object Security.Cryptography.X509Certificates.X509Store($storeName,'LocalMachine');try{$store.Open('ReadWrite');$store.Add((New-Object Security.Cryptography.X509Certificates.X509Certificate2(,$signer.RawData)))}finally{$store.Close()};$trust+=@{store=$storeName;thumbprint=$signer.Thumbprint}}
    foreach($name in @('root-ca.pem','https-trust.pem')) {
        $cert=New-Object Security.Cryptography.X509Certificates.X509Certificate2((Join-Path $package $name))
        $store=New-Object Security.Cryptography.X509Certificates.X509Store('Root','LocalMachine')
        try {$store.Open('ReadWrite');$store.Add($cert);$trust+=@{store='Root';thumbprint=$cert.Thumbprint}}finally{$store.Close();$cert.Dispose()}
    }
    Write-Host 'USER_CI_STAGE package-signatures'
    foreach($name in @('AuthWire-User-Client.ps1','Install-AuthWire-User.ps1')) {
        $source=Join-Path $package $name;$tokens=$null;$errors=$null
        $null=[Management.Automation.Language.Parser]::ParseFile($source,[ref]$tokens,[ref]$errors);Check ($errors.Count -eq 0) ('Windows PowerShell parse failed: '+($errors|Out-String))
        Check ((Set-AuthenticodeSignature $source $signer -HashAlgorithm SHA256).Status -eq 'Valid') 'User package signing failed.'
    }
    $production=Join-Path $fixture 'production-user-client.ps1';Copy-Item (Join-Path $package 'AuthWire-User-Client.ps1') $production
    # Signed no-network task child; production state/CNG path is tested below
    # with only its Kerberos/HTTP transport replaced in this fixture process.
    $stub=@'
$ErrorActionPreference='Stop'
$sid=[Security.Principal.WindowsIdentity]::GetCurrent().User.Value
if($sid -notmatch '^S-1-5-21-'){throw 'Expected user token.'}
$file=Join-Path $PSScriptRoot 'ci-task-result.json'
$count=if(Test-Path $file){[int](Get-Content $file -Raw|ConvertFrom-Json).count+1}else{1}
[IO.File]::WriteAllText($file,(@{sid=$sid;count=$count}|ConvertTo-Json -Compress))
exit 0
'@
    [IO.File]::WriteAllText((Join-Path $package 'AuthWire-User-Client.ps1'),$stub,(New-Object Text.UTF8Encoding($true)))
    Check ((Set-AuthenticodeSignature (Join-Path $package 'AuthWire-User-Client.ps1') $signer -HashAlgorithm SHA256).Status -eq 'Valid') 'Stub signature failed.'
    Write-Host 'USER_CI_STAGE install-and-interactive-task'
    & (Join-Path $package 'Install-AuthWire-User.ps1')
    if($LASTEXITCODE -and $LASTEXITCODE -ne 0){throw 'User installer failed.'}
    . (Join-Path $package 'Install-AuthWire-User.ps1') -ValidateOnly
    $target=Get-AuthWireUserTarget $profile;$sid=Get-AuthWireUserContext;$taskName='AuthWire User Enrollment '+$sid+' '+$profile
    $task=Get-ScheduledTask -TaskName $taskName;$xml=[xml](Export-ScheduledTask -TaskName $taskName)
    Check ([string]$task.Principal.LogonType -eq 'Interactive') 'User task must use the logged-in user token.'
    Check ([string]$task.Principal.RunLevel -eq 'Limited') 'User task must not elevate.'
    Check ($xml.Task.Triggers.CalendarTrigger.Repetition.Interval -eq 'PT5M') 'Persistent user poll missing.'
    Check ($xml.Task.Actions.Exec.Arguments -match 'ExecutionPolicy AllSigned') 'User task must require AllSigned.'
    $limit=(Get-Date).AddSeconds(35)
    do {Start-Sleep -Milliseconds 250;$taskResult=Join-Path $target 'ci-task-result.json'}while(!(Test-Path $taskResult) -and (Get-Date) -lt $limit)
    Check (Test-Path $taskResult) 'Interactive user task did not execute on hosted session.'
    Check ((Get-Content $taskResult -Raw|ConvertFrom-Json).sid -eq $sid) 'Task ran under the wrong SID.'
    Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue;Unregister-ScheduledTask -TaskName $taskName -Confirm:$false;$taskName=$null
    Copy-Item $production (Join-Path $target 'AuthWire-User-Client.ps1') -Force
    . (Join-Path $target 'AuthWire-User-Client.ps1') -ValidateOnly
    $approved=Assert-AuthWireUserPackage $target;$config=$approved.config
    $tokens=$null;$errors=$null;$ast=[Management.Automation.Language.Parser]::ParseFile($production,[ref]$tokens,[ref]$errors)
    $main=@($ast.EndBlock.Statements|Where-Object {$_ -is [Management.Automation.Language.FunctionDefinitionAst] -and $_.Name -eq 'Invoke-AuthWireUserEnrollment'})
    Check ($main.Count -eq 1) 'Unexpected production main function.'
    $body=$main[0].Extent.Text;$needle='New-Object AuthWireUserSspi($Config.spn)';Check ([regex]::Matches($body,[regex]::Escape($needle)).Count -eq 2) 'Unexpected session boundary.'
    . ([scriptblock]::Create($body.Replace($needle,'New-AuthWireUserFixtureSession')))
    function New-AuthWireUserFixtureSession {$s=New-Object PSObject;$s|Add-Member ScriptMethod Start {return ,([byte[]]@(1))};$s|Add-Member ScriptMethod Finish {param($token)};$s|Add-Member ScriptMethod Dispose {};return $s}
    $script:mode='normal';$script:lost=$false;$script:calls=0
    function Post-AuthWireUserJson($Path,$Data){$script:calls++;if($script:mode -eq 'offline'){throw 'Synthetic offline session.'};Check ($Path -eq '/api/user/session') 'Unexpected unprotected user route.';return @{id='synthetic-user-session';token=''}}
    function Protected-AuthWireUserPost($Path,$Data) {
        $script:calls++;$request=Join-Path $fixture 'request.json';$response=Join-Path $fixture 'response.json'
        [IO.File]::WriteAllText($request,(@{path=$Path;body=$Data}|ConvertTo-Json -Depth 8 -Compress),(New-Object Text.UTF8Encoding($false)))
        $null=& python -m tools.user_client_fixture --root $fixture --step call --request $request --response $response
        if($LASTEXITCODE -ne 0){throw 'User fixture call failed.'}
        $answer=Get-Content $response -Raw|ConvertFrom-Json
        if($answer.fixture_error){$script:awUserServerError=[string]$answer.fixture_error;throw 'Synthetic issuer rejected request.'}
        if($script:mode -eq 'lose-issue' -and $Path -eq '/api/user/issue' -and !$script:lost){$script:lost=$true;throw 'Synthetic response lost after committed issuance.'}
        return $answer
    }
    Write-Host 'USER_CI_STAGE native-enrollment'
    $machineBefore=@(Get-ChildItem Cert:\LocalMachine\My|Where-Object {$_.Subject -like 'CN=AuthWire*'}|Select-Object -ExpandProperty Thumbprint)
    Check ((Invoke-AuthWireUserEnrollment $target $config -NoJitter) -eq 0) 'Native user enrollment failed.'
    $first=Read-State 'installed.json';$createdContainers+=$first.container;$createdThumbs+=$first.thumbprint
    $leaf=Get-Item ('Cert:\CurrentUser\My\'+$first.thumbprint);Check $leaf.HasPrivateKey 'User leaf has no private key.'
    $key=[Security.Cryptography.CngKey]::Open($first.container,[Security.Cryptography.CngProvider]::MicrosoftSoftwareKeyStorageProvider,[Security.Cryptography.CngKeyOpenOptions]::None)
    try {
        Check (!$key.IsMachineKey) 'User key was created in machine scope.';Check ($key.ExportPolicy -eq [Security.Cryptography.CngExportPolicies]::None) 'User key export is allowed.'
        $rsa=New-Object Security.Cryptography.RSACng($key);try{$export=$false;try{$null=$rsa.ExportParameters($true);$export=$true}catch [Security.Cryptography.CryptographicException]{};Check (!$export) 'User private key exported.'}finally{$rsa.Dispose()}
    }finally{$key.Dispose()}
    Write-Host 'USER_CI_STAGE native-renewal'
    $null=Fixture-Call 'renew';Force-Due
    Check ((Invoke-AuthWireUserEnrollment $target $config -NoJitter) -eq 0) 'Native user renewal failed.'
    $second=Read-State 'installed.json';$createdContainers+=$second.container;$createdThumbs+=$second.thumbprint
    Check ($second.serial -ne $first.serial -and $second.key_hash -cne $first.key_hash) 'Renewal did not rotate the user key.'
    Check (Test-Path ('Cert:\CurrentUser\My\'+$first.thumbprint)) 'Old user leaf removed too early.'
    Write-Host 'USER_CI_STAGE offline-recovery'
    $script:mode='offline';Force-Due
    Check ((Invoke-AuthWireUserEnrollment $target $config -NoJitter) -eq 1) 'Offline user request did not persist retry.'
    $beforeCalls=$script:calls;Check ((Invoke-AuthWireUserEnrollment $target $config -NoJitter) -eq 0) 'Not-due poll failed.';Check ($beforeCalls -eq $script:calls) 'Backoff did not suppress network calls.'
    $script:mode='normal';Force-Due;Check ((Invoke-AuthWireUserEnrollment $target $config -NoJitter) -eq 0) 'User receipt recovery failed.'
    Check (!(Test-Path (Join-Path $target 'retry.json'))) 'Retry was not cleared.';Check ((Read-State 'status.json').state -eq 'installed') 'Stale retry status remained.'
    Write-Host 'USER_CI_STAGE lost-issuance'
    $null=Fixture-Call 'renew';Force-Due;$script:mode='lose-issue';$script:lost=$false
    Check ((Invoke-AuthWireUserEnrollment $target $config -NoJitter) -eq 1) 'Committed/lost issuance did not fail locally.'
    $pending=Read-State 'pending.json';$createdContainers+=$pending.container
    Check ((Read-State 'installed.json').serial -eq $second.serial) 'Failure replaced the working user certificate.'
    $script:mode='normal';Force-Due;Check ((Invoke-AuthWireUserEnrollment $target $config -NoJitter) -eq 0) 'Idempotent user recovery failed.'
    $third=Read-State 'installed.json';$createdContainers+=$third.container;$createdThumbs+=$third.thumbprint
    Check ($third.container -ceq $pending.container) 'Recovery generated a different pending key.'
    $facts=Fixture-Call 'status';Check ($facts.users.Count -eq 3 -and $facts.machine_issuances -eq 0 -and @($facts.csr_counts|Where-Object {$_ -ne 1}).Count -eq 0) 'Duplicate user issuance or machine-state mutation.'
    # Actual old-user certificate/CNG deletion, with current user leaf preserved.
    $record=Read-State 'installed.json';foreach($old in $record.previous){$old.remove_at=[DateTimeOffset]::UtcNow.AddSeconds(-1).ToString('o')};Write-State 'installed.json' $record
    Check ((Invoke-AuthWireUserEnrollment $target $config -NoJitter) -eq 0) 'User predecessor cleanup failed.'
    Check (!(Test-Path ('Cert:\CurrentUser\My\'+$first.thumbprint))) 'Old leaf was not cleaned.'
    Check (![Security.Cryptography.CngKey]::Exists($first.container,[Security.Cryptography.CngProvider]::MicrosoftSoftwareKeyStorageProvider,[Security.Cryptography.CngKeyOpenOptions]::None)) 'Old CNG key was not cleaned.'
    Check (Test-Path ('Cert:\CurrentUser\My\'+$third.thumbprint)) 'Current leaf was removed.'
    # A second, ordinary local user cannot open the first user's CNG name,
    # and can create an own non-exportable user key/task without elevation.
    Write-Host 'USER_CI_STAGE standard-user-isolation'
    $probe=Join-Path $fixture 'standard-user';$null=New-Item $probe -ItemType Directory
    $accountName='AWUCI'+[guid]::NewGuid().ToString('N').Substring(0,10)
    $password=[guid]::NewGuid().ToString('N')+'!aA1'
    $localUser=New-LocalUser -Name $accountName -Password (ConvertTo-SecureString $password -AsPlainText -Force) -AccountNeverExpires
    $group=Get-LocalGroup -SID 'S-1-5-32-545';Add-LocalGroupMember -Group $group.Name -Member $accountName
    foreach($path in @($fixture,$probe)) {
        $acl=Get-Acl $path;$rights=if($path -eq $probe){'Modify'}else{'ReadAndExecute'}
        $acl.AddAccessRule((New-Object Security.AccessControl.FileSystemAccessRule($localUser.SID,$rights,'ContainerInherit,ObjectInherit','None','Allow')));Set-Acl $path $acl
    }
    Export-Certificate -Cert $signer -FilePath (Join-Path $probe 'publisher.cer')|Out-Null
    Copy-Item $production (Join-Path $probe 'client.ps1');Copy-Item (Join-Path $target 'Install-AuthWire-User.ps1') (Join-Path $probe 'installer.ps1')
    $childCode=@'
$ErrorActionPreference='Stop'
$probe='__PROBE__'
# Public fixture publisher is already trusted in LocalMachine by the parent.
. (Join-Path $probe 'client.ps1') -ValidateOnly
. (Join-Path $probe 'installer.ps1') -ValidateOnly
$sid=Get-AuthWireUserContext
$principal=New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if($principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){throw 'Standard fixture unexpectedly elevated.'}
$provider=[Security.Cryptography.CngProvider]::MicrosoftSoftwareKeyStorageProvider
$foreign=$false;try{$k=[Security.Cryptography.CngKey]::Open('__FOREIGN__',$provider,[Security.Cryptography.CngKeyOpenOptions]::None);$k.Dispose();$foreign=$true}catch [Security.Cryptography.CryptographicException]{}
if($foreign){throw 'Foreign user CNG key opened.'}
$parameters=New-Object Security.Cryptography.CngKeyCreationParameters;$parameters.Provider=$provider;$parameters.ExportPolicy=[Security.Cryptography.CngExportPolicies]::None
$name='AuthWire-User-Standard-CI-'+[guid]::NewGuid().ToString('N')
$key=[Security.Cryptography.CngKey]::Create([Security.Cryptography.CngAlgorithm]::Rsa,$name,$parameters)
$taskName='AuthWire User Standard CI '+[guid]::NewGuid().ToString('N')
try {
 if($key.IsMachineKey -or $key.ExportPolicy -ne [Security.Cryptography.CngExportPolicies]::None){throw 'Invalid standard user key.'}
 $xml=Get-AuthWireUserTaskXml $sid (Join-Path $probe 'installer.ps1')
 $null=Register-ScheduledTask -TaskName $taskName -Xml $xml
 $task=Get-ScheduledTask -TaskName $taskName
 if([string]$task.Principal.LogonType -ne 'Interactive' -or [string]$task.Principal.RunLevel -ne 'Limited'){throw 'Standard user task scope mismatch.'}
 [IO.File]::WriteAllText((Join-Path $probe 'result.json'),(@{nonadmin=$true;foreign_key_rejected=$true;own_key_user_scope=$true;own_task_registered=$true}|ConvertTo-Json -Compress))
}finally{Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue;$key.Delete();$key.Dispose()}
'@
    $childCode=$childCode.Replace('__PROBE__',$probe.Replace("'","''")).Replace('__FOREIGN__',$third.container)
    $encoded=[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($childCode))
    $credential=New-Object Management.Automation.PSCredential(($env:COMPUTERNAME+'\'+$accountName),(ConvertTo-SecureString $password -AsPlainText -Force))
    try {
        Start-Service seclogon
        $process=Start-Process -FilePath (Join-Path ([Environment]::GetFolderPath('System')) 'WindowsPowerShell\v1.0\powershell.exe') -Credential $credential -LoadUserProfile -ArgumentList ('-NoProfile -NonInteractive -ExecutionPolicy AllSigned -EncodedCommand '+$encoded) -PassThru -RedirectStandardOutput (Join-Path $probe 'stdout.txt') -RedirectStandardError (Join-Path $probe 'stderr.txt')
        if(!$process.WaitForExit(90000)){try{$process.Kill()}catch{};throw 'Standard-user native fixture timed out.'}
        $process.Refresh()
        if($process.ExitCode -ne 0){throw ('Standard user native fixture failed: '+(Get-Content (Join-Path $probe 'stderr.txt') -Raw))}
        $ordinary=Get-Content (Join-Path $probe 'result.json') -Raw|ConvertFrom-Json;Check ($ordinary.nonadmin -and $ordinary.foreign_key_rejected -and $ordinary.own_task_registered) 'Standard user isolation incomplete.'
    } finally {Remove-LocalUser -Name $accountName -ErrorAction SilentlyContinue;$password=$null;$credential=$null}
    $original=[IO.File]::ReadAllBytes((Join-Path $target 'config.json'));[IO.File]::AppendAllText((Join-Path $target 'config.json'),' ')
    $rejected=$false;try{$null=Assert-AuthWireUserPackage $target}catch{$rejected=$true}finally{[IO.File]::WriteAllBytes((Join-Path $target 'config.json'),$original)}
    Check $rejected 'Signed user asset tampering was accepted.'
    $record=Read-State 'installed.json';$record.owner_sid='S-1-5-21-1-2-3-9999';Write-State 'installed.json' $record
    Check ((Invoke-AuthWireUserEnrollment $target $config -NoJitter) -eq 1) 'Foreign user state was accepted.'
    $record.owner_sid=$sid;Write-State 'installed.json' $record
    $machineAfter=@(Get-ChildItem Cert:\LocalMachine\My|Where-Object {$_.Subject -like 'CN=AuthWire*'}|Select-Object -ExpandProperty Thumbprint)
    Check (($machineBefore -join ',') -ceq ($machineAfter -join ',')) 'Machine certificate store changed.'
    Write-Output 'AUTHWIRE_USER_WINDOWS_OK native_current_user_cng=true nonexportable=true signed_package=true interactive_limited_task=true renewal_new_key=true retry_idempotence=true cleanup=true machine_store_preserved=true standard_user_isolation=true synthetic_transport_only=true'
} finally {
    if($taskName){Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue}
    if($target -and (Test-Path $target)) {
        foreach($file in @('installed.json','pending.json')){if(Test-Path (Join-Path $target $file)){try{$state=Read-State $file;$createdContainers+=$state.container;$createdThumbs+=$state.thumbprint;foreach($old in @($state.previous)){$createdContainers+=$old.container;$createdThumbs+=$old.thumbprint}}catch{}}}
    }
    foreach($thumb in @($createdThumbs|Where-Object {$_}|Select-Object -Unique)){Remove-Item ('Cert:\CurrentUser\My\'+$thumb) -ErrorAction SilentlyContinue}
    foreach($container in @($createdContainers|Where-Object {$_}|Select-Object -Unique)){try{$key=[Security.Cryptography.CngKey]::Open($container,[Security.Cryptography.CngProvider]::MicrosoftSoftwareKeyStorageProvider,[Security.Cryptography.CngKeyOpenOptions]::None);$key.Delete();$key.Dispose()}catch{}}
    if($target -and (Test-Path $target)) {
        foreach($storeName in @('Root','CA')){foreach($name in @('root-ca.pem','issuer-ca.pem','https-trust.pem')){if(Test-Path (Join-Path $target $name)){$c=New-Object Security.Cryptography.X509Certificates.X509Certificate2((Join-Path $target $name));Remove-Item ('Cert:\CurrentUser\'+$storeName+'\'+$c.Thumbprint) -ErrorAction SilentlyContinue;$c.Dispose()}}}
        Remove-Item $target -Recurse -Force -ErrorAction SilentlyContinue
    }
    foreach($t in $trust){Remove-Item ('Cert:\LocalMachine\'+$t.store+'\'+$t.thumbprint) -ErrorAction SilentlyContinue}
    if($signer){Remove-Item ('Cert:\CurrentUser\My\'+$signer.Thumbprint) -ErrorAction SilentlyContinue;$signer.Dispose()}
    Remove-Item $fixture -Recurse -Force -ErrorAction SilentlyContinue
}
