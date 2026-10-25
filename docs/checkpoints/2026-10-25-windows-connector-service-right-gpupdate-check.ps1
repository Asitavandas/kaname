# DC01 elevated operator: reapplies existing Computer Group Policy and compares readonly LSA service-right snapshots. Not a readonly overall step; does not edit GPO definitions or re-grant rights.
$ErrorActionPreference = 'Stop'
if ($env:COMPUTERNAME -ine 'DC01') { throw 'DC01 uzerinde calistirilmali' }
$awFolder = 'C:\ProgramData\AuthWire-SigningTemplate-b05c01482d03415897d290ccde085a37'
$awRightsTool = Join-Path $env:TEMP 'AuthWire-Service-Right-Prepare-v1.ps1'
$awPublisher = '6E74B513F766E01730719684A41B2664380CA68A'
$awSignature = Get-AuthenticodeSignature -FilePath $awRightsTool
if ($awSignature.Status.ToString() -ne 'Valid' -or $awSignature.SignerCertificate.Thumbprint -ne $awPublisher) {
    throw 'Hak kontrol aracinin imzasi dogrulanamadi'
}
$awRightsParameters = @{
    Mode = 'Inspect'
    ExpectedComputer = 'DC01'
    ExpectedDomain = 'vizyonveri.local'
    InstanceId = '4c23eebe-0715-46d1-88ee-a2e96ad7ee46'
    AccountName = 'aw-deploy'
    AccountSid = 'S-1-5-21-34256453-3348971241-2809240126-1648'
    BootstrapPath = Join-Path $env:TEMP 'AuthWire-Windows-Bootstrap-v1-r4.ps1'
    PublisherThumbprint = $awPublisher
}
$awBefore = & $awRightsTool @awRightsParameters | ConvertFrom-Json
$awBefore | ConvertTo-Json -Depth 6 |
    Set-Content -LiteralPath (Join-Path $awFolder 'service-right-before-gpupdate.json') -Encoding UTF8
if (-not $awBefore.DirectServiceRightAssigned -or @($awBefore.DenyAssignedSids).Count -ne 0) {
    throw 'Baslangic hizmet haklari inceleme gerektiriyor'
}

& "$env:SystemRoot\System32\gpupdate.exe" /target:computer /force |
    Tee-Object -FilePath (Join-Path $awFolder 'computer-gpupdate.log')
$awGpExit = $LASTEXITCODE

$awAfter = & $awRightsTool @awRightsParameters | ConvertFrom-Json
$awAfter | ConvertTo-Json -Depth 6 |
    Set-Content -LiteralPath (Join-Path $awFolder 'service-right-after-gpupdate.json') -Encoding UTF8
$awRemovedAllow = @($awBefore.AllowAssignedSids | Where-Object { $awAfter.AllowAssignedSids -notcontains $_ })
$awResult = [pscustomobject]@{
    Event = 'WINDOWS_CONNECTOR_SERVICE_RIGHT_AFTER_GPUPDATE'
    GpupdateExitCode = $awGpExit
    DirectServiceRightStillAssigned = $awAfter.DirectServiceRightAssigned
    BeforeAllowEntriesPreserved = ($awRemovedAllow.Count -eq 0)
    DenyAssignedSids = @($awAfter.DenyAssignedSids)
    RemovedAllowSids = $awRemovedAllow
    AllowAssignedSidsAfter = @($awAfter.AllowAssignedSids)
    InspectionAddedRights = ($awBefore.AddedNow -or $awAfter.AddedNow)
    GpoDefinitionsChangedByThisCommand = $false
}
$awResult | ConvertTo-Json -Depth 6
$awResult | ConvertTo-Json -Depth 6 |
    Set-Content -LiteralPath (Join-Path $awFolder 'service-right-gpupdate-check.json') -Encoding UTF8
