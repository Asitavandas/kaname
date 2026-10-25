& {
    $ErrorActionPreference = 'Stop'
    if ($env:COMPUTERNAME -ine 'DC01') { throw 'Bu komut DC01 uzerinde calistirilmali.' }
    Import-Module ActiveDirectory
    Import-Module GroupPolicy

    $awReceiptPath = 'C:\ProgramData\AuthWire-GpoPreparation-6394ceadf50a4dc29f13787be5822806\gpo-preparation.json'
    $awReceipt = Get-Content -LiteralPath $awReceiptPath -Raw | ConvertFrom-Json
    $awId = [guid]$awReceipt.GpoId
    if ($awId -eq [guid]::Empty -or $awId -eq [guid]'e5a9ab39-3709-49cb-837a-0208d2eb3b12') {
        throw 'GPO kimligi kontrol edilmeli; islem durduruldu.'
    }

    $awDomain = 'vizyonveri.local'
    $awServer = 'dc01.vizyonveri.local'
    $awGpo = Get-GPO -Guid $awId -Domain $awDomain -Server $awServer
    if ($awGpo.DisplayName -cne 'AuthWire-Managed-Deployment-4c23eebe') {
        throw 'Beklenmeyen GPO adi; islem durduruldu.'
    }
    $awDn = 'CN={' + $awId.ToString('D') + '},CN=Policies,CN=System,DC=vizyonveri,DC=local'
    $awObject = Get-ADObject -Identity $awDn -Server $awServer -Properties description,gPCFileSysPath
    $awExpected = 'AuthWireDeployment:v1;instance=4c23eebe-0715-46d1-88ee-a2e96ad7ee46;host=0fa4143f-aae3-4bc3-9cd3-db8a1de24acd;service=S-1-5-21-34256453-3348971241-2809240126-1648;scope=S-1-5-21-34256453-3348971241-2809240126-1647'

    $awDescriptionProperty = $awGpo.PSObject.Properties['Description']
    $awGpoDescription = $null
    if ($null -ne $awDescriptionProperty) { $awGpoDescription = $awDescriptionProperty.Value }
    $awAdDescriptions = @(foreach ($awValue in $awObject.description) {
        if ($null -ne $awValue) { [string]$awValue }
    })
    $awAdDescriptionType = $null
    if ($null -ne $awObject.description) {
        $awAdDescriptionType = $awObject.description.GetType().FullName
    }

    [pscustomobject]@{
        Event                 = 'WINDOWS_CONNECTOR_GPO_MARKER_READONLY'
        Computer              = $env:COMPUTERNAME
        ReceiptPhase          = $awReceipt.Phase
        ReceiptGpoId          = $awReceipt.GpoId
        ReceiptMarker         = $awReceipt.Marker
        ExpectedMarker        = $awExpected
        GpoName               = $awGpo.DisplayName
        GpoOwner              = $awGpo.Owner
        ObjectClass           = [string]$awObject.ObjectClass
        GpoDescription        = $awGpoDescription
        GpoDescriptionMatches = ([string]$awGpoDescription -ceq $awExpected)
        AdDescriptionType     = $awAdDescriptionType
        AdDescriptionValues   = $awAdDescriptions
        AdDescriptionMatches  = ($awAdDescriptions.Count -eq 1 -and $awAdDescriptions[0] -ceq $awExpected)
        SysvolPath            = @($awObject.gPCFileSysPath)
        Permissions           = @(Get-GPPermission -Guid $awId -All -Domain $awDomain -Server $awServer |
            ForEach-Object { [pscustomobject]@{ Trustee = $_.Trustee.Name; Sid = $_.Trustee.Sid.Value; Permission = $_.Permission.ToString() } })
        AdChanged             = $false
        GpoChanged            = $false
    } | ConvertTo-Json -Depth 6
}
