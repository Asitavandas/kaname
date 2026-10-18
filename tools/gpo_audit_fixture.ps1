$ErrorActionPreference='Stop'
if($env:RUNNER_ENVIRONMENT -ne 'github-hosted') { throw 'Disposable GitHub-hosted Windows fixture only.' }
. (Join-Path $PSScriptRoot 'AuthWire-GPO-Audit.ps1')
$root=Join-Path $env:RUNNER_TEMP ('authwire-gpo-audit-'+[guid]::NewGuid())
$folder=Join-Path $root 'Machine\Scripts\Startup'
$null=New-Item $folder -ItemType Directory -Force
$certificate=$null
try {
    $certificate=New-SelfSignedCertificate -Type CodeSigningCert -Subject 'CN=AuthWire GPO Readonly Audit Fixture' -CertStoreLocation Cert:\CurrentUser\My
    foreach($name in @('Root','TrustedPublisher')) {
        $store=New-Object Security.Cryptography.X509Certificates.X509Store($name,'CurrentUser')
        $store.Open('ReadWrite');$store.Add($certificate);$store.Close()
    }
    $pem="-----BEGIN CERTIFICATE-----`r`n"+[Convert]::ToBase64String($certificate.RawData,[Base64FormattingOptions]::InsertLineBreaks)+"`r`n-----END CERTIFICATE-----`r`n"
    [IO.File]::WriteAllText((Join-Path $folder 'root-ca.pem'),$pem)
    [IO.File]::WriteAllText((Join-Path $folder 'issuer-ca.pem'),$pem)
    $config=@{url='https://kaname.vizyonveri.local:8765';spn='HTTP/kaname.vizyonveri.local';domain='vizyonveri.local';profile_id='fixture'}|ConvertTo-Json
    [IO.File]::WriteAllText((Join-Path $folder 'config.json'),$config)
    $hashes=[ordered]@{}
    foreach($name in @('config.json','root-ca.pem','issuer-ca.pem')) {$hashes[$name]=(Get-FileHash (Join-Path $folder $name)).Hash.ToLowerInvariant()}
    $map=$hashes|ConvertTo-Json -Compress
    $source=Join-Path (Split-Path $PSScriptRoot -Parent) 'kaname\device_client'
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
    $result=Audit
    if(!$result.PackageChecksPassed) {throw ('Valid signed fixture rejected: '+($result.PackageChecks|ConvertTo-Json -Compress))}
    if($result.Startup.InstallEntryCount -ne 1 -or !$result.Startup.ExplicitAllSigned) {throw 'Startup parsing failed.'}
    if($result.GpoChanged -or $result.WindowsClientChanged) {throw 'Audit mutation claim invalid.'}
    $before=(Get-FileHash (Join-Path $folder 'AuthWire-Client.ps1')).Hash
    $null=Audit
    if($before -ne (Get-FileHash (Join-Path $folder 'AuthWire-Client.ps1')).Hash) {throw 'Audit changed script.'}
    [IO.File]::AppendAllText((Join-Path $folder 'config.json'),' ')
    $tampered=Audit
    if($tampered.PackageChecks.AssetsMatchSignedInstaller) {throw 'Tampered asset accepted.'}
    [IO.File]::WriteAllText((Join-Path $folder 'config.json'),$config)
    [IO.File]::AppendAllText($ini,"1CmdLine=powershell.exe`r`n1Parameters=-ExecutionPolicy Bypass -File Install-AuthWire.ps1`r`n",[Text.Encoding]::Unicode)
    $duplicate=Audit
    if(!$duplicate.Startup.DuplicateInstallEntries -or !$duplicate.Startup.BypassReferenced) {throw 'Duplicate or bypass not reported.'}
    $acl.AddAccessRule((New-Object Security.AccessControl.FileSystemAccessRule((New-Object Security.Principal.SecurityIdentifier('S-1-1-0')),'Write','ContainerInherit,ObjectInherit','None','Allow')))
    Set-Acl $folder $acl
    if((Audit).PackageChecks.NoBroadPackageWritePermission) {throw 'Broad package write accepted.'}
    Write-Output 'AUTHWIRE_GPO_READONLY_AUDIT_FIXTURE_OK'
} finally {
    if($certificate) {
        foreach($name in @('Root','TrustedPublisher')) {
            $store=New-Object Security.Cryptography.X509Certificates.X509Store($name,'CurrentUser')
            $store.Open('ReadWrite');$store.Remove($certificate);$store.Close()
        }
        Remove-Item ('Cert:\CurrentUser\My\'+$certificate.Thumbprint) -Force -ErrorAction SilentlyContinue
    }
    Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue
}
