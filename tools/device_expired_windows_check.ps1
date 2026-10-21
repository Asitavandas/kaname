# Disposable hosted Windows runner only; synthetic AD, no network/server/customer state.
$ErrorActionPreference='Stop'
if($env:GITHUB_ACTIONS -ne 'true' -or $env:RUNNER_ENVIRONMENT -ne 'github-hosted') {throw 'Disposable hosted CI required.'}
$repo=(Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$source=Join-Path $repo 'kaname\device_client\AuthWire-Client.ps1'
. $source -ValidateOnly
$root=Join-Path $env:TEMP ('authwire-ci-expired-'+[guid]::NewGuid().ToString('N'))
$null=New-Item $root -ItemType Directory
$acl=New-Object Security.AccessControl.DirectorySecurity
$acl.SetAccessRuleProtection($true,$false)
foreach($sid in @('S-1-5-18','S-1-5-32-544')) {
    $rule=New-Object Security.AccessControl.FileSystemAccessRule((New-Object Security.Principal.SecurityIdentifier($sid)),'FullControl','ContainerInherit,ObjectInherit','None','Allow')
    $acl.AddAccessRule($rule)
}
Set-Acl -LiteralPath $root -AclObject $acl
foreach($marker in @('CI_FIXTURE_ONLY','EXPIRED_RECOVERY_FIXTURE_ONLY')) {$null=New-Item (Join-Path $root $marker) -ItemType File}
$python=(Get-Command python -ErrorAction Stop).Source
[IO.File]::WriteAllText((Join-Path $root 'python-path.txt'),$python)
[IO.File]::WriteAllText((Join-Path $root 'repository-path.txt'),$repo)
$taskName='AuthWire Expired CI '+[guid]::NewGuid().ToString('N')
$oldContainer='AuthWire-CI-Expired-'+[guid]::NewGuid()
$fixtureTrust=@();$oldKey=$null;$oldPrivate=$null;$signer=$null;$sentinel=$null;$bridgeProcess=$null
function Wait-FixtureTask {
    $before=(Get-ScheduledTaskInfo -TaskName $taskName).LastRunTime
    Start-ScheduledTask -TaskName $taskName
    $deadline=(Get-Date).AddMinutes(3)
    do {
        Start-Sleep -Milliseconds 300
        $info=Get-ScheduledTaskInfo -TaskName $taskName
        $task=Get-ScheduledTask -TaskName $taskName
        if($info.LastRunTime -gt $before -and $task.State -eq 'Ready') {return $info.LastTaskResult}
    } while((Get-Date) -lt $deadline)
    throw 'Native expired fixture task timed out.'
}
try {
    # Guard the narrow recovery predicate and changed-state refusal first.
    $guard=Join-Path $root 'guards';$null=New-Item $guard -ItemType Directory
    $pending=@{container='fixture-key-reference';csr='fixture-public-csr'}
    $guardFile=Join-Path $guard 'pending.json'
    [IO.File]::WriteAllText($guardFile,($pending|ConvertTo-Json))
    $guardHash=(Get-FileHash $guardFile).Hash
    foreach($case in @(@('session','DEVICE_CERTIFICATE_EXPIRED'),@('issue','DEVICE_CERTIFICATE_REVOKED'),@('issue','DEVICE_BUSY'),@('issue',''))) {
        if(Move-AuthWireExpiredPending $guard $case[0] $case[1] $pending) {throw 'Non-expiry failure changed pending state.'}
        if((Get-FileHash $guardFile).Hash -ne $guardHash) {throw 'Pending bytes changed without exact expiry predicate.'}
    }
    $refused=$false
    try {$null=Move-AuthWireExpiredPending $guard 'issue' 'DEVICE_CERTIFICATE_EXPIRED' @{container='different';csr='fixture-public-csr'}} catch {$refused=$true}
    if(!$refused -or (Get-FileHash $guardFile).Hash -ne $guardHash) {throw 'Changed pending identity was not preserved/refused.'}

    $sentinel=New-SelfSignedCertificate -Subject ('CN=AuthWire CI Preserve '+[guid]::NewGuid()) -CertStoreLocation Cert:\LocalMachine\My -Provider 'Microsoft Software Key Storage Provider' -KeyExportPolicy NonExportable
    $inf=@"
[Version]
Signature="`$Windows NT`$"
[NewRequest]
Subject="CN=AuthWire computer request"
KeyAlgorithm=RSA
KeyLength=2048
HashAlgorithm=sha256
Exportable=FALSE
MachineKeySet=TRUE
ProviderName="Microsoft Software Key Storage Provider"
KeyContainer="$oldContainer"
RequestType=PKCS10
SuppressDefaults=TRUE
"@
    [IO.File]::WriteAllText((Join-Path $root 'request.inf'),$inf,[Text.Encoding]::ASCII)
    & "$env:SystemRoot\System32\certreq.exe" -new -machine -q -f (Join-Path $root 'request.inf') (Join-Path $root 'request.pem') | Out-Null
    if($LASTEXITCODE -ne 0) {throw 'Native seed CSR failed.'}
    $csr=(Get-Content (Join-Path $root 'request.pem') -Raw).Replace('BEGIN NEW CERTIFICATE REQUEST','BEGIN CERTIFICATE REQUEST').Replace('END NEW CERTIFICATE REQUEST','END CERTIFICATE REQUEST')
    [IO.File]::WriteAllText((Join-Path $root 'request.pem'),$csr,[Text.Encoding]::ASCII)
    & $python -m tools.device_fixture --root $root --step challenge
    if($LASTEXITCODE -ne 0) {throw 'Fixture seed challenge failed.'}
    $challenge=Get-Content (Join-Path $root 'challenge.json') -Raw|ConvertFrom-Json
    $oldKey=[Security.Cryptography.CngKey]::Open($oldContainer,[Security.Cryptography.CngProvider]::MicrosoftSoftwareKeyStorageProvider,[Security.Cryptography.CngKeyOpenOptions]::MachineKey)
    $oldPrivate=New-Object Security.Cryptography.RSACng($oldKey)
    $proof=$oldPrivate.SignData([Convert]::FromBase64String($challenge.payload),[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1)
    [IO.File]::WriteAllText((Join-Path $root 'proof.txt'),[Convert]::ToBase64String($proof))
    & $python -m tools.device_fixture --root $root --step issue
    if($LASTEXITCODE -ne 0) {throw 'Fixture seed issue failed.'}
    & $python -m tools.device_expired_fixture --root $root --step expire
    if($LASTEXITCODE -ne 0) {throw 'Fixture backdated certificate seed failed.'}
    $seed=Get-Content (Join-Path $root 'issued.json') -Raw|ConvertFrom-Json
    [IO.File]::WriteAllText((Join-Path $root 'pending.json'),(@{container=$oldContainer;csr=$csr}|ConvertTo-Json),(New-Object Text.UTF8Encoding($false)))
    $pendingHash=(Get-FileHash (Join-Path $root 'pending.json')).Hash
    foreach($entry in @(@('root-ca.pem','Root'),@('issuer-ca.pem','CA'))) {
        $ca=New-Object Security.Cryptography.X509Certificates.X509Certificate2((Join-Path $root $entry[0]))
        $store=New-Object Security.Cryptography.X509Certificates.X509Store($entry[1],'LocalMachine')
        try {$store.Open('ReadWrite');$store.Add($ca)} finally {$store.Close()}
        $fixtureTrust+=@{store=$entry[1];thumbprint=$ca.Thumbprint};$ca.Dispose()
    }
    $signer=New-SelfSignedCertificate -Type CodeSigningCert -Subject ('CN=AuthWire Expired Fixture '+[guid]::NewGuid()) -CertStoreLocation Cert:\LocalMachine\My -KeyExportPolicy NonExportable -HashAlgorithm SHA256
    foreach($storeName in @('Root','TrustedPublisher')) {
        $store=New-Object Security.Cryptography.X509Certificates.X509Store($storeName,'LocalMachine')
        try {$store.Open('ReadWrite');$store.Add($signer)} finally {$store.Close()}
        $fixtureTrust+=@{store=$storeName;thumbprint=$signer.Thumbprint}
    }
    $signedSource=Join-Path $root 'AuthWire-Client.ps1'
    $harness=Join-Path $root 'expired-harness.ps1'
    Copy-Item $source $signedSource
    Copy-Item (Join-Path $PSScriptRoot 'device_expired_client_harness.ps1') $harness
    foreach($path in @($signedSource,$harness)) {
        $signature=Set-AuthenticodeSignature -FilePath $path -Certificate $signer -HashAlgorithm SHA256
        if($signature.Status -ne 'Valid') {throw 'Fixture signing failed.'}
    }
    $action=New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -Argument ('-NoProfile -NonInteractive -ExecutionPolicy AllSigned -File "'+$harness+'" -FixtureRoot "'+$root+'" -ClientSource "'+$signedSource+'"')
    $principal=New-ScheduledTaskPrincipal -UserId SYSTEM -LogonType ServiceAccount -RunLevel Highest
    $settings=New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 3)
    $null=Register-ScheduledTask -TaskName $taskName -Action $action -Principal $principal -Settings $settings
    # The fixture issuer remains in its DPAPI owner account. Never decrypt its
    # user-scoped vault under the SYSTEM client or weaken vault protection.
    $bridgeProcess=Start-Process -FilePath $python -ArgumentList @('-m','tools.device_expired_fixture','--root',('"'+$root+'"'),'--step','serve') -WorkingDirectory $repo -PassThru -WindowStyle Hidden -RedirectStandardOutput (Join-Path $root 'bridge-out.txt') -RedirectStandardError (Join-Path $root 'bridge-error.txt')
    $bridgeDeadline=(Get-Date).AddSeconds(30)
    while(!(Test-Path (Join-Path $root 'bridge-ready')) -and !$bridgeProcess.HasExited -and (Get-Date) -lt $bridgeDeadline) {Start-Sleep -Milliseconds 100}
    if(!(Test-Path (Join-Path $root 'bridge-ready'))) {throw 'Private fixture issuer bridge did not start.'}
    if((Wait-FixtureTask) -ne 1) {throw 'Expected actual client failure on expired pending issuance.'}
    $status=Get-Content (Join-Path $root 'status.json') -Raw|ConvertFrom-Json
    $retry=Get-Content (Join-Path $root 'retry.json') -Raw|ConvertFrom-Json
    if($status.server_error -ne 'DEVICE_CERTIFICATE_EXPIRED' -or !$status.expired_pending_archived -or $status.recovery_error) {
        $diagnostic=@{stage=$status.stage;server_error=$status.server_error;recovery_error=$status.recovery_error;archived=$status.expired_pending_archived;pending_exists=(Test-Path (Join-Path $root 'pending.json'))}
        Write-Output ('EXPIRED_FIXTURE_FAILURE '+($diagnostic|ConvertTo-Json -Compress))
        throw 'Client did not archive expired pending state.'
    }
    $archive=Join-Path (Join-Path $root 'expired-pending') $retry.expired_pending_archive
    if((Test-Path (Join-Path $root 'pending.json')) -or (Get-FileHash $archive).Hash -ne $pendingHash) {throw 'Pending request archive differs or old request still active.'}
    $retained=[Security.Cryptography.CngKey]::Open($oldContainer,[Security.Cryptography.CngProvider]::MicrosoftSoftwareKeyStorageProvider,[Security.Cryptography.CngKeyOpenOptions]::MachineKey)
    try {if($retained.ExportPolicy -ne [Security.Cryptography.CngExportPolicies]::None) {throw 'Archived pending key became exportable.'}} finally {$retained.Dispose()}
    # Only this disposable fixture skips backoff; real automatic deadlines have
    # a separate native SYSTEM test and already passed customer field acceptance.
    Remove-Item (Join-Path $root 'retry.json')
    if((Wait-FixtureTask) -ne 0) {throw 'Fresh authenticated fixture retry did not recover.'}
    $installed=Get-Content (Join-Path $root 'installed.json') -Raw|ConvertFrom-Json
    if($installed.container -eq $oldContainer -or $installed.serial -eq $seed.serial) {throw 'Expired key/issuance was reused.'}
    $current=Get-Item ('Cert:\LocalMachine\My\'+$installed.thumbprint)
    if(!$current.HasPrivateKey) {throw 'Recovered native leaf has no private key.'}
    if((Test-Path (Join-Path $root 'pending.json')) -or (Test-Path (Join-Path $root 'retry.json'))) {throw 'Recovery state survived successful installation.'}
    $after=(& $python -m tools.device_expired_fixture --root $root --step inspect|Out-String)|ConvertFrom-Json
    if($LASTEXITCODE -ne 0 -or @($after.issuances).Count -ne 2 -or @($after.issuances|Where-Object installed_at).Count -ne 1 -or $after.issuances[0].csr_sha256 -eq $after.issuances[1].csr_sha256) {throw 'Expected one expired and one fresh installed CSR.'}
    if(!(Get-Item ('Cert:\LocalMachine\My\'+$sentinel.Thumbprint)).HasPrivateKey) {throw 'Unrelated existing certificate/key changed.'}
    Write-Output ('AUTHWIRE_EXPIRED_RECOVERY_NATIVE_OK '+(@{run_as_system=$true;production_main_ast=$true;kerberos_transport='synthetic';actual_cng_certreq_chain_receipt=$true;expired_pending_rejected=$true;old_pending_archived_identically=$true;old_key_retained_nonexportable=$true;new_key_and_csr=$true;new_leaf_installed=$true;unrelated_identity_preserved=$true;system_clock_changed=$false;customer_state_used=$false;real_deadline_wait=$false}|ConvertTo-Json -Compress))
} finally {
    $task=Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    if($task) {Stop-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue;Unregister-ScheduledTask -TaskName $taskName -Confirm:$false}
    if($bridgeProcess -and !$bridgeProcess.HasExited) {
        [IO.File]::WriteAllText((Join-Path $root 'bridge-stop'),'stop')
        if(!$bridgeProcess.WaitForExit(5000)) {Stop-Process -Id $bridgeProcess.Id -Force}
    }
    $containers=@($oldContainer)
    foreach($name in @('installed.json','pending.json')) {
        $path=Join-Path $root $name
        if(Test-Path $path) {
            $state=Get-Content $path -Raw|ConvertFrom-Json
            if($state.container) {$containers+=$state.container}
            if($state.thumbprint) {Remove-Item ('Cert:\LocalMachine\My\'+$state.thumbprint) -ErrorAction SilentlyContinue}
        }
    }
    if($oldPrivate) {$oldPrivate.Dispose()}
    if($oldKey) {$oldKey.Dispose()}
    foreach($container in @($containers|Select-Object -Unique)) {
        try {$key=[Security.Cryptography.CngKey]::Open($container,[Security.Cryptography.CngProvider]::MicrosoftSoftwareKeyStorageProvider,[Security.Cryptography.CngKeyOpenOptions]::MachineKey);$key.Delete();$key.Dispose()} catch {}
    }
    if($sentinel) {
        $private=[Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($sentinel)
        try {$private.Key.Delete()} finally {$private.Dispose()}
        Remove-Item ('Cert:\LocalMachine\My\'+$sentinel.Thumbprint) -ErrorAction SilentlyContinue
    }
    foreach($entry in $fixtureTrust) {Remove-Item ('Cert:\LocalMachine\'+$entry.store+'\'+$entry.thumbprint) -ErrorAction SilentlyContinue}
    if($signer) {
        $private=[Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($signer)
        try {$private.Key.Delete()} finally {$private.Dispose()}
        Remove-Item ('Cert:\LocalMachine\My\'+$signer.Thumbprint) -ErrorAction SilentlyContinue
    }
    Remove-Item $root -Recurse -Force
}
