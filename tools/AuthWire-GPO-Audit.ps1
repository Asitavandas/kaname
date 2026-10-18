[CmdletBinding()]
param(
    [string]$PackageDirectory = '',
    [switch]$PackageOnly,
    [string]$ExpectedUrl = 'https://kaname.vizyonveri.local:8765',
    [string]$ExpectedDomain = 'vizyonveri.local',
    [string]$ExpectedRootThumbprint = 'C789A0595ADB95A6BE4534D01B1D205F6C37DE18'
)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

function Get-AuthWireBodyHash([string]$Text, [switch]$Installer) {
    $body = ($Text -split '(?m)^# SIG # Begin signature block', 2)[0]
    $body = $body.TrimStart([char]0xfeff).Replace("`r`n", "`n").Replace("`r", "`n")
    if($Installer) {
        $m = [regex]::Match($body, '(?s)\$expectedAssets\s*=\s*@''\n(?<payload>.*?)\n''@\s*\|\s*ConvertFrom-Json')
        if(!$m.Success) { throw 'Expected signed asset map missing.' }
        $g = $m.Groups['payload']
        $body = $body.Substring(0,$g.Index) + '__AUTHWIRE_ASSET_HASHES__' + $body.Substring($g.Index+$g.Length)
    }
    $bytes = (New-Object Text.UTF8Encoding($false)).GetBytes($body.TrimEnd([char]10)+"`n")
    $h = [Security.Cryptography.SHA256]::Create()
    try { return ([BitConverter]::ToString($h.ComputeHash($bytes))).Replace('-','').ToLowerInvariant() }
    finally { $h.Dispose() }
}

function Get-AuthWireStartupAudit([string]$Directory) {
    $entries = @()
    foreach($name in @('scripts.ini','psscripts.ini')) {
        $file = Join-Path $Directory $name
        if(!(Test-Path -LiteralPath $file)) { continue }
        $section=''; $records=@{}
        foreach($line in ([IO.File]::ReadAllText($file) -split '\r?\n')) {
            if($line -match '^\s*\[(?<section>[^]]+)\]') { $section=$Matches.section; continue }
            if($section -ine 'Startup') { continue }
            if($line -match '^\s*(?<index>\d+)(?<field>CmdLine|Parameters)\s*=(?<value>.*)$') {
                $index=$Matches.index
                if(!$records.ContainsKey($index)) { $records[$index]=@{CmdLine='';Parameters=''} }
                $records[$index][$Matches.field]=$Matches.value
            }
        }
        foreach($record in $records.Values) {
            $command=$record.CmdLine+' '+$record.Parameters
            if($command -notmatch '(?i)Install-AuthWire\.ps1') { continue }
            $entries += [pscustomobject]@{Ini=$name;AllSigned=($command -match '(?i)-ExecutionPolicy\s+AllSigned\b');Bypass=($command -match '(?i)\bBypass\b')}
        }
    }
    return [pscustomobject]@{InstallEntryCount=$entries.Count;DuplicateInstallEntries=($entries.Count -gt 1);ExplicitAllSigned=(@($entries|Where-Object AllSigned).Count -eq $entries.Count -and $entries.Count -gt 0);BypassReferenced=(@($entries|Where-Object Bypass).Count -gt 0)}
}

function Invoke-AuthWireGpoAudit {
    param([string]$Directory,[switch]$OnlyPackage,[string]$Url,[string]$Domain,[string]$RootThumbprint)
    $gpoInfo=$null
    if(!$OnlyPackage) {
        $machine=Get-CimInstance Win32_ComputerSystem
        if($machine.DomainRole -lt 4) { throw 'Run the domain audit on a domain controller.' }
        Import-Module GroupPolicy -ErrorAction Stop
        $gpo=Get-GPO -Name 'AuthWire-Pilot-Trust' -Domain $Domain
        $gpoId='{'+$gpo.Id.ToString()+'}'
        if(!$Directory) { $Directory=Join-Path $env:SystemRoot ('SYSVOL\sysvol\'+$Domain+'\Policies\'+$gpoId+'\Machine\Scripts\Startup') }
        $gpoInfo=[ordered]@{Name=$gpo.DisplayName;Id=$gpo.Id.ToString();Status=$gpo.GpoStatus.ToString();ApplyTrustees=@(Get-GPPermission -Guid $gpo.Id -All -Domain $Domain | Where-Object Permission -eq 'GpoApply' | ForEach-Object {$_.Trustee.Name})}
    }
    if(!$Directory -or !(Test-Path -LiteralPath $Directory -PathType Container)) { throw 'Package directory missing.' }
    $directoryItem=Get-Item -LiteralPath $Directory
    if($directoryItem.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Package directory reparse point refused.' }
    $checks=[ordered]@{}; $scripts=@(); $publishers=@(); $installerText=''
    foreach($name in @('Install-AuthWire.ps1','AuthWire-Client.ps1')) {
        $file=Join-Path $Directory $name; $item=Get-Item -LiteralPath $file
        if($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Package script reparse point refused.' }
        $signature=Get-AuthenticodeSignature -LiteralPath $file
        $eku=@($signature.SignerCertificate.Extensions | Where-Object {$_.Oid.Value -eq '2.5.29.37'} | ForEach-Object {$_.EnhancedKeyUsages} | ForEach-Object {$_.Value})
        $text=[IO.File]::ReadAllText($file)
        $bodyHash=Get-AuthWireBodyHash -Text $text -Installer:($name -eq 'Install-AuthWire.ps1')
        $expected=if($name -eq 'AuthWire-Client.ps1') {'86081b41e7072c055cf3a0364f688914b5f66def91ab44273cdcea50e26f5b15'} else {'ec7c99c5162258585735f0cd5c43e57d54fba9e042187c36695cb62d5c81f84e'}
        $publisher=if($signature.SignerCertificate) {$signature.SignerCertificate.Thumbprint} else {''}
        $scripts += [pscustomobject]@{Name=$name;SignatureStatus=$signature.Status.ToString();CodeSigningEku=($eku -contains '1.3.6.1.5.5.7.3.3');SourceBodyMatches=($bodyHash -eq $expected);FileSha256=(Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLowerInvariant();PublisherThumbprint=$publisher}
        $publishers += $publisher
        if($name -eq 'Install-AuthWire.ps1') {$installerText=$text.Replace("`r`n","`n").Replace("`r","`n")}
    }
    $checks.ValidScriptSignatures=(@($scripts|Where-Object {$_.SignatureStatus -ne 'Valid'}).Count -eq 0)
    $checks.SameCodeSigningPublisher=($publishers[0] -ne '' -and $publishers[0] -eq $publishers[1])
    $checks.CodeSigningEku=(@($scripts|Where-Object {!$_.CodeSigningEku}).Count -eq 0)
    $checks.CurrentClientAndInstallerBodies=(@($scripts|Where-Object {!$_.SourceBodyMatches}).Count -eq 0)
    $m=[regex]::Match($installerText, '(?s)\$expectedAssets\s*=\s*@''\n(?<payload>.*?)\n''@\s*\|\s*ConvertFrom-Json')
    if(!$m.Success) { throw 'Signed asset map missing.' }
    $assets=$m.Groups['payload'].Value|ConvertFrom-Json
    $assetResults=@()
    foreach($asset in $assets.PSObject.Properties) {
        if($asset.Name -notin @('config.json','root-ca.pem','issuer-ca.pem','https-trust.pem') -or $asset.Value -notmatch '^[a-fA-F0-9]{64}$') { throw 'Unexpected asset map.' }
        $file=Join-Path $Directory $asset.Name; $item=Get-Item -LiteralPath $file
        if($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Package asset reparse point refused.' }
        $assetResults += [pscustomobject]@{Name=$asset.Name;MatchesSignedInstaller=((Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash -ieq $asset.Value)}
    }
    $checks.RequiredAssetsPresent=(@('config.json','root-ca.pem','issuer-ca.pem')|Where-Object {$_ -notin @($assetResults.Name)}).Count -eq 0
    $checks.AssetsMatchSignedInstaller=(@($assetResults|Where-Object {!$_.MatchesSignedInstaller}).Count -eq 0)
    $config=Get-Content -LiteralPath (Join-Path $Directory 'config.json') -Raw|ConvertFrom-Json
    $checks.ExpectedHttpsUrl=($config.url -ceq $Url)
    $checks.ExpectedDomain=($config.domain -ieq $Domain)
    $checks.ExpectedHttpSpn=($config.spn -ceq ('HTTP/'+([uri]$Url).DnsSafeHost))
    $rootCert=New-Object Security.Cryptography.X509Certificates.X509Certificate2((Join-Path $Directory 'root-ca.pem'))
    $checks.ExpectedRootCa=($rootCert.Thumbprint -ieq $RootThumbprint)
    $broadWrites=@()
    foreach($item in @($directoryItem)+@(Get-ChildItem -LiteralPath $Directory -File)) {
        if($item.Attributes -band [IO.FileAttributes]::ReparsePoint) { throw 'Package permission reparse point refused.' }
        foreach($ace in (Get-Acl -LiteralPath $item.FullName).Access) {
            if($ace.AccessControlType -ne 'Allow') {continue}
            $sid=$ace.IdentityReference.Translate([Security.Principal.SecurityIdentifier]).Value
            $broad=($sid -in @('S-1-1-0','S-1-5-11','S-1-5-32-545') -or $sid -match '-513$')
            $writeMask=[Security.AccessControl.FileSystemRights]::Write -bor [Security.AccessControl.FileSystemRights]::Delete -bor [Security.AccessControl.FileSystemRights]::DeleteSubdirectoriesAndFiles -bor [Security.AccessControl.FileSystemRights]::ChangePermissions -bor [Security.AccessControl.FileSystemRights]::TakeOwnership
            if($broad -and ($ace.FileSystemRights -band $writeMask)) {$broadWrites += $sid}
        }
    }
    $checks.NoBroadPackageWritePermission=($broadWrites.Count -eq 0)
    $machineScripts=Split-Path $Directory -Parent
    $startup=Get-AuthWireStartupAudit -Directory $machineScripts
    return [pscustomobject]@{event='GPO_READONLY_AUDIT';Computer=$env:COMPUTERNAME;Gpo=$gpoInfo;PackageChecks=$checks;PackageChecksPassed=(@($checks.Values|Where-Object {!$_}).Count -eq 0);Scripts=$scripts;Assets=$assetResults;Startup=$startup;WindowsClientChanged=$false;GpoChanged=$false;TrustStoreChanged=$false;ClientApplicationAccepted=$false}
}

if($MyInvocation.InvocationName -ne '.') {
    try { Invoke-AuthWireGpoAudit -Directory $PackageDirectory -OnlyPackage:$PackageOnly -Url $ExpectedUrl -Domain $ExpectedDomain -RootThumbprint $ExpectedRootThumbprint | ConvertTo-Json -Depth 7 }
    catch { [pscustomobject]@{event='GPO_AUDIT_FAILED';Category=$_.Exception.GetType().Name;GpoChanged=$false;WindowsClientChanged=$false}|ConvertTo-Json;exit 1 }
}
