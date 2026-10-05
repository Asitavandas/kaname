# Sign with enterprise Authenticode. Deploy once as computer startup via GPO.
$ErrorActionPreference = 'Stop'
if ([Security.Principal.WindowsIdentity]::GetCurrent().User.Value -ne 'S-1-5-18') { throw 'AuthWire installation requires SYSTEM.' }
$publisher = $null
foreach($name in @('Install-AuthWire.ps1','AuthWire-Client.ps1')) {
    $signature = Get-AuthenticodeSignature (Join-Path $PSScriptRoot $name)
    if($signature.Status -ne 'Valid') { throw 'AuthWire requires valid enterprise Authenticode signatures.' }
    if(!$publisher) { $publisher = $signature.SignerCertificate.Thumbprint }
    if($signature.SignerCertificate.Thumbprint -ne $publisher) { throw 'AuthWire scripts must use the same trusted publisher.' }
}
# Package generation embeds these hashes BEFORE the operator signs this file.
# Thus the Authenticode signature covers the config and public trust assets too.
$expectedAssets = @'
__AUTHWIRE_ASSET_HASHES__
'@ | ConvertFrom-Json
$verifiedAssets = @{}
foreach($asset in $expectedAssets.PSObject.Properties) {
    if($asset.Name -notin @('config.json','root-ca.pem','issuer-ca.pem','https-trust.pem')) { throw 'Unexpected AuthWire asset.' }
    $assetFile = Join-Path $PSScriptRoot $asset.Name
    if((Get-Item $assetFile).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'AuthWire asset reparse point refused.' }
    $bytes = [IO.File]::ReadAllBytes($assetFile)
    $hash = [Security.Cryptography.SHA256]::Create()
    try { $actual = [BitConverter]::ToString($hash.ComputeHash($bytes)).Replace('-','') } finally { $hash.Dispose() }
    if($actual -ine $asset.Value) { throw 'AuthWire config/trust asset was modified after signing.' }
    $verifiedAssets[$asset.Name] = $bytes
}
$target = Join-Path $env:ProgramData 'AuthWire'
if(Test-Path $target) {
    if((Get-Item $target).Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'AuthWire reparse point refused.' }
} else { $null = New-Item $target -ItemType Directory }
# Private client state/config and pending CNG requests are not user-writable.
$acl = New-Object Security.AccessControl.DirectorySecurity
$acl.SetAccessRuleProtection($true,$false)
$acl.SetOwner((New-Object Security.Principal.SecurityIdentifier('S-1-5-32-544')))
foreach($sid in @('S-1-5-18','S-1-5-32-544')) {
    $rule = New-Object Security.AccessControl.FileSystemAccessRule((New-Object Security.Principal.SecurityIdentifier($sid)), 'FullControl', 'ContainerInherit,ObjectInherit', 'None', 'Allow')
    $acl.AddAccessRule($rule)
}
Set-Acl $target $acl
foreach($name in @('AuthWire-Client.ps1') + @($verifiedAssets.Keys)) {
    $destination = Join-Path $target $name
    if((Test-Path $destination) -and ((Get-Item $destination).Attributes -band [IO.FileAttributes]::ReparsePoint)) { throw 'AuthWire file reparse point refused.' }
    if($name -eq 'AuthWire-Client.ps1') {
        Copy-Item (Join-Path $PSScriptRoot $name) $destination -Force
        $copiedSignature = Get-AuthenticodeSignature $destination
        if($copiedSignature.Status -ne 'Valid' -or $copiedSignature.SignerCertificate.Thumbprint -ne $publisher) { throw 'Copied AuthWire client signature invalid.' }
    } else { [IO.File]::WriteAllBytes($destination, [byte[]]$verifiedAssets[$name]) }
    $fileAcl = New-Object Security.AccessControl.FileSecurity
    $fileAcl.SetAccessRuleProtection($true,$false)
    $fileAcl.SetOwner((New-Object Security.Principal.SecurityIdentifier('S-1-5-32-544')))
    foreach($sid in @('S-1-5-18','S-1-5-32-544')) {
        $fileAcl.AddAccessRule((New-Object Security.AccessControl.FileSystemAccessRule((New-Object Security.Principal.SecurityIdentifier($sid)), 'FullControl', 'Allow')))
    }
    Set-Acl $destination $fileAcl
}
foreach($entry in @(@('root-ca.pem','Root'),@('issuer-ca.pem','CA'),@('https-trust.pem','Root'))) {
    $file = Join-Path $target $entry[0]
    if(Test-Path $file) {
        $certificate = New-Object Security.Cryptography.X509Certificates.X509Certificate2($file)
        $store = New-Object Security.Cryptography.X509Certificates.X509Store($entry[1],'LocalMachine')
        try { $store.Open('ReadWrite'); $store.Add($certificate) } finally { $store.Close(); $certificate.Dispose() }
    }
}
$action = New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -Argument ('-NoProfile -NonInteractive -ExecutionPolicy AllSigned -File "'+(Join-Path $target 'AuthWire-Client.ps1')+'"')
$daily = New-ScheduledTaskTrigger -Daily -At '09:00'; $evening = New-ScheduledTaskTrigger -Daily -At '21:00'
$startup = New-ScheduledTaskTrigger -AtStartup
$network = New-CimInstance -Namespace 'Root/Microsoft/Windows/TaskScheduler' -ClassName 'MSFT_TaskEventTrigger' -ClientOnly -Property @{
    Enabled=$true
    Subscription='<QueryList><Query Id="0" Path="Microsoft-Windows-NetworkProfile/Operational"><Select Path="Microsoft-Windows-NetworkProfile/Operational">*[System[EventID=10000]]</Select></Query></QueryList>'
}
$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -RunOnlyIfNetworkAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit (New-TimeSpan -Minutes 10)
$null = Register-ScheduledTask -TaskName 'AuthWire Certificate Enrollment' -Action $action -Trigger @($daily,$evening,$startup,$network) -Principal $principal -Settings $settings -Force
Start-ScheduledTask -TaskName 'AuthWire Certificate Enrollment'
# No supplicant policy, port control or RADIUS changes in this package.
