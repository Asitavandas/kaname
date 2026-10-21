$ErrorActionPreference='Stop'
if($env:RUNNER_ENVIRONMENT -ne 'github-hosted') { throw 'Disposable GitHub-hosted Windows fixture only.' }
. (Join-Path $PSScriptRoot 'AuthWire-GPO-Audit.ps1')
$root=Join-Path $env:RUNNER_TEMP ('authwire-gpo-audit-'+[guid]::NewGuid())
$folder=Join-Path $root 'Machine\Scripts\Startup'
$null=New-Item $folder -ItemType Directory -Force
$certificate=$null
try {
    Write-Output 'GPO_FIXTURE_CREATE_SIGNER'
    $certificate=New-SelfSignedCertificate -Type CodeSigningCert -Subject 'CN=AuthWire GPO Readonly Audit Fixture' -CertStoreLocation Cert:\CurrentUser\My
    Write-Output 'GPO_FIXTURE_INSTALL_PUBLIC_TRUST'
    foreach($name in @('Root','TrustedPublisher')) {
        $store=New-Object Security.Cryptography.X509Certificates.X509Store($name,'LocalMachine')
        $store.Open('ReadWrite');$store.Add((New-Object Security.Cryptography.X509Certificates.X509Certificate2(,$certificate.RawData)));$store.Close()
    }
    $pem="-----BEGIN CERTIFICATE-----`r`n"+[Convert]::ToBase64String($certificate.RawData,[Base64FormattingOptions]::InsertLineBreaks)+"`r`n-----END CERTIFICATE-----`r`n"
    [IO.File]::WriteAllText((Join-Path $folder 'root-ca.pem'),$pem)
    [IO.File]::WriteAllText((Join-Path $folder 'issuer-ca.pem'),$pem)
    $config=@{url='https://kaname.vizyonveri.local:8765';spn='HTTP/kaname.vizyonveri.local';domain='vizyonveri.local';profile_id='00000000-0000-4000-8000-000000000001';tls_sha256='a58838b95510f759943e5f1b7fefe29e227960a5c1171b5ebc6d5089df47a76d'}|ConvertTo-Json
    [IO.File]::WriteAllText((Join-Path $folder 'config.json'),$config)
    $hashes=[ordered]@{}
    foreach($name in @('config.json','root-ca.pem','issuer-ca.pem')) {$hashes[$name]=(Get-FileHash (Join-Path $folder $name)).Hash.ToLowerInvariant()}
    $map=$hashes|ConvertTo-Json -Compress
    $source=Join-Path (Split-Path $PSScriptRoot -Parent) 'kaname\device_client'
    Write-Output 'GPO_FIXTURE_SIGN_PACKAGE'
    foreach($name in @('AuthWire-Client.ps1','Install-AuthWire.ps1')) {
        $body=[IO.File]::ReadAllText((Join-Path $source $name)).Replace('__AUTHWIRE_ASSET_HASHES__',$map)
        [IO.File]::WriteAllText((Join-Path $folder $name),$body,(New-Object Text.UTF8Encoding($true)))
        $signed=Set-AuthenticodeSignature -FilePath (Join-Path $folder $name) -Certificate $certificate -HashAlgorithm SHA256
        if($signed.Status -ne 'Valid') {throw 'Fixture signature not valid.'}
    }
    # Everyone read access is legitimate; it must not be mistaken for write.
    $acl=New-Object Security.AccessControl.DirectorySecurity
    $acl.SetAccessRuleProtection($true,$false)
    $current=[Security.Principal.WindowsIdentity]::GetCurrent().User
    $acl.SetOwner($current)
    foreach($sid in @($current.Value,'S-1-5-18','S-1-5-32-544')) {$acl.AddAccessRule((New-Object Security.AccessControl.FileSystemAccessRule((New-Object Security.Principal.SecurityIdentifier($sid)),'FullControl','ContainerInherit,ObjectInherit','None','Allow')))}
    $acl.AddAccessRule((New-Object Security.AccessControl.FileSystemAccessRule((New-Object Security.Principal.SecurityIdentifier('S-1-1-0')),'ReadAndExecute','ContainerInherit,ObjectInherit','None','Allow')))
    Set-Acl $folder $acl
    $ini=Join-Path (Split-Path $folder -Parent) 'scripts.ini'
    [IO.File]::WriteAllText($ini,"[Startup]`r`n0CmdLine=powershell.exe`r`n0Parameters=-NoProfile -ExecutionPolicy AllSigned -File Install-AuthWire.ps1`r`n",[Text.Encoding]::Unicode)
    function Audit {Invoke-AuthWireGpoAudit -Directory $folder -OnlyPackage -Url 'https://kaname.vizyonveri.local:8765' -Domain 'vizyonveri.local' -RootThumbprint $certificate.Thumbprint}

    # Update only the accepted old signed client; installer and signed assets stay exact.
    . (Join-Path (Split-Path $PSScriptRoot -Parent) 'docs\checkpoints\2026-10-21-sysvol-client-update.ps1')
    $oldTemplate=[IO.File]::ReadAllText((Join-Path (Split-Path $PSScriptRoot -Parent) 'docs\checkpoints\2026-10-19-authwire-client-dev11.ps1'))
    if((Get-AuthWireBodyHash $oldTemplate) -ne $script:awOldHash) {throw 'Previous accepted client pin differs.'}
    $installer=Join-Path $folder 'AuthWire-Client.ps1'
    function Set-OldFixture {
        [IO.File]::WriteAllText($installer,$oldTemplate.Replace('__AUTHWIRE_ASSET_HASHES__',$map),(New-Object Text.UTF8Encoding($true)))
        if((Set-AuthenticodeSignature $installer $certificate -HashAlgorithm SHA256).Status -ne 'Valid') {throw 'Old client fixture signature invalid.'}
    }
    Set-OldFixture
    $oldSnapshot=Get-AwPackageSnapshot $folder
    $oldFileHash=(Get-FileHash $installer).Hash
    $backup=Join-Path $root 'update-backup'
    $changed=Update-AwPilotClient $folder $certificate $backup $certificate.Thumbprint
    if(!$changed.verified -or !$changed.updated) {throw 'Protected update did not complete.'}
    if((Get-FileHash (Join-Path $backup 'AuthWire-Client.before.ps1')).Hash -ne $oldFileHash) {throw 'Original signed backup differs.'}
    Assert-AwPackagePreserved $oldSnapshot (Get-AwPackageSnapshot $folder)
    $newHash=(Get-FileHash $installer).Hash
    $repeat=Update-AwPilotClient $folder $certificate (Join-Path $root 'idempotent-unused') $certificate.Thumbprint
    if($repeat.updated -or !$repeat.already_current -or (Get-FileHash $installer).Hash -ne $newHash) {throw 'Idempotent update changed bytes.'}
    Write-Output 'GPO_CLIENT_UPDATE_REAL_AUTHENTICODE_ASSETS_ACL_AND_IDEMPOTENCE_OK'

    [IO.File]::AppendAllText((Join-Path $folder 'config.json'),' ')
    $tamperBefore=Get-AwPackageSnapshot $folder
    $rejected=$false
    try {$null=Update-AwPilotClient $folder $certificate (Join-Path $root 'tamper-unused') $certificate.Thumbprint} catch {$rejected=$true}
    if(!$rejected) {throw 'Modified signed asset accepted.'}
    Assert-AwPackagePreserved $tamperBefore (Get-AwPackageSnapshot $folder) -IncludeClient
    [IO.File]::WriteAllText((Join-Path $folder 'config.json'),$config)
    $rejected=$false
    try {Test-AwPilotPackage $folder $script:awNewHash '0000' $certificate.Thumbprint} catch {$rejected=$true}
    if(!$rejected) {throw 'Unexpected publisher accepted.'}
    Write-Output 'GPO_UPDATE_ASSET_AND_PUBLISHER_REJECTION_OK'

    Set-OldFixture
    $rollbackBefore=Get-AwPackageSnapshot $folder
    $script:awValidAudit=(Get-Item Function:\Test-AwPilotPackage).ScriptBlock
    function Test-AwPilotPackage($Directory,$Hash,$Publisher,$Root) {
        & $script:awValidAudit $Directory $Hash $Publisher $Root
        if($Hash -eq $script:awNewHash) {throw 'Injected post-replace acceptance failure.'}
    }
    $rejected=$false
    try {$null=Update-AwPilotClient $folder $certificate (Join-Path $root 'rollback-backup') $certificate.Thumbprint} catch {$rejected=$true}
    if(!$rejected) {throw 'Injected post-replace failure did not stop update.'}
    Assert-AwPackagePreserved $rollbackBefore (Get-AwPackageSnapshot $folder) -IncludeClient
    Set-Item Function:\Test-AwPilotPackage -Value $script:awValidAudit
    Write-Output 'GPO_UPDATE_POST_FAILURE_ROLLBACK_OK'
    $null=Update-AwPilotClient $folder $certificate (Join-Path $root 'final-backup') $certificate.Thumbprint

    Write-Output 'GPO_FIXTURE_AUDIT_VALID_PACKAGE'
    $result=Audit
    if(!$result.PackageChecksPassed) {throw ('Valid signed fixture rejected: '+($result.PackageChecks|ConvertTo-Json -Compress))}
    if($result.Startup.InstallEntryCount -ne 1 -or !$result.Startup.ExplicitAllSigned) {throw 'Startup parsing failed.'}
    if($result.GpoChanged -or $result.WindowsClientChanged) {throw 'Audit mutation claim invalid.'}
    $before=(Get-FileHash (Join-Path $folder 'AuthWire-Client.ps1')).Hash
    $null=Audit
    if($before -ne (Get-FileHash (Join-Path $folder 'AuthWire-Client.ps1')).Hash) {throw 'Audit changed script.'}
    [IO.File]::AppendAllText((Join-Path $folder 'config.json'),' ')
    Write-Output 'GPO_FIXTURE_AUDIT_TAMPER'
    $tampered=Audit
    if($tampered.PackageChecks.AssetsMatchSignedInstaller) {throw 'Tampered asset accepted.'}
    [IO.File]::WriteAllText((Join-Path $folder 'config.json'),$config)
    [IO.File]::AppendAllText($ini,"1CmdLine=powershell.exe`r`n1Parameters=-ExecutionPolicy Bypass -File Install-AuthWire.ps1`r`n",[Text.Encoding]::Unicode)
    Write-Output 'GPO_FIXTURE_AUDIT_DUPLICATE'
    $duplicate=Audit
    if(!$duplicate.Startup.DuplicateInstallEntries -or !$duplicate.Startup.BypassReferenced) {throw 'Duplicate or bypass not reported.'}
    $acl.AddAccessRule((New-Object Security.AccessControl.FileSystemAccessRule((New-Object Security.Principal.SecurityIdentifier('S-1-1-0')),'Write','ContainerInherit,ObjectInherit','None','Allow')))
    Set-Acl $folder $acl
    if((Audit).PackageChecks.NoBroadPackageWritePermission) {throw 'Broad package write accepted.'}
    Write-Output 'AUTHWIRE_GPO_EXPIRED_CLIENT_UPDATE_FIXTURE_OK'
} finally {
    if($certificate) {
        foreach($name in @('Root','TrustedPublisher')) {
            $store=New-Object Security.Cryptography.X509Certificates.X509Store($name,'LocalMachine')
            $store.Open('ReadWrite');$store.Remove($certificate);$store.Close()
        }
        Remove-Item ('Cert:\CurrentUser\My\'+$certificate.Thumbprint) -Force -ErrorAction SilentlyContinue
    }
    Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue
}
