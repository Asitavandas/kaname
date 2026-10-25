& {
    $ErrorActionPreference = 'Stop'
    if ($env:COMPUTERNAME -ine 'DC01') { throw 'Bu kontrol DC01 uzerinde calistirilmali.' }
    Import-Module GroupPolicy

    $awId = [guid]'e5a9ab39-3709-49cb-837a-0208d2eb3b12'
    $awDomain = 'vizyonveri.local'
    $awServer = 'dc01.vizyonveri.local'
    $awGpo = Get-GPO -Guid $awId -Domain $awDomain -Server $awServer
    if ($awGpo.DisplayName -ne 'AuthWire-Pilot-Trust') { throw 'Beklenen pilot GPO eslesmedi.' }
    [xml]$awReport = Get-GPOReport -Guid $awId -Domain $awDomain -Server $awServer -ReportType Xml
    $awRoot = '\\dc01.vizyonveri.local\SYSVOL\vizyonveri.local\Policies\{' + $awId.ToString('D') + '}'

    [pscustomobject]@{
        Event = 'WINDOWS_CONNECTOR_GPO_SCOPE_READONLY'
        Computer = $env:COMPUTERNAME
        Gpo = $awGpo.DisplayName
        Id = $awId.ToString('D')
        Owner = [string]$awGpo.Owner
        Status = $awGpo.GpoStatus.ToString()
        ComputerSections = @($awReport.SelectNodes("/*[local-name()='GPO']/*[local-name()='Computer']/*[local-name()='ExtensionData']/*[local-name()='Name']") | ForEach-Object { $_.InnerText })
        UserSections = @($awReport.SelectNodes("/*[local-name()='GPO']/*[local-name()='User']/*[local-name()='ExtensionData']/*[local-name()='Name']") | ForEach-Object { $_.InnerText })
        LinkedPaths = @($awReport.SelectNodes("/*[local-name()='GPO']/*[local-name()='LinksTo']/*[local-name()='SOMPath']") | ForEach-Object { $_.InnerText })
        Permissions = @(Get-GPPermission -Guid $awId -All -Domain $awDomain -Server $awServer |
            Select-Object @{Name='Trustee';Expression={$_.Trustee.Name}},@{Name='Permission';Expression={$_.Permission.ToString()}})
        Sysvol = @(
            foreach ($awPath in @($awRoot,(Join-Path $awRoot 'Machine\Scripts\Startup'))) {
                if (-not (Test-Path -LiteralPath $awPath -PathType Container)) {
                    [pscustomobject]@{Path=$awPath;Exists=$false}
                    continue
                }
                $awAcl = Get-Acl -LiteralPath $awPath
                [pscustomobject]@{
                    Path = $awPath
                    Exists = $true
                    OwnerSid = $awAcl.GetOwner([System.Security.Principal.SecurityIdentifier]).Value
                    InheritanceProtected = $awAcl.AreAccessRulesProtected
                    Rules = @(
                        foreach ($awRule in $awAcl.GetAccessRules($true,$true,[System.Security.Principal.SecurityIdentifier])) {
                            [pscustomobject]@{
                                Sid = $awRule.IdentityReference.Value
                                Type = $awRule.AccessControlType.ToString()
                                Rights = $awRule.FileSystemRights.ToString()
                                Inherited = $awRule.IsInherited
                                Inheritance = $awRule.InheritanceFlags.ToString()
                                Propagation = $awRule.PropagationFlags.ToString()
                            }
                        }
                    )
                }
            }
        )
        AdChanged = $false
        GpoChanged = $false
        PermissionsChanged = $false
    } | ConvertTo-Json -Depth 8
}
