& {
    $ErrorActionPreference = 'Stop'
    $awTool = Join-Path $env:TEMP 'AuthWire-Deployment-GPO-Bootstrap-v1.ps1'
    $awPublisher = '6E74B513F766E01730719684A41B2664380CA68A'
    $awSignature = Get-AuthenticodeSignature -FilePath $awTool
    if ($awSignature.Status.ToString() -ne 'Valid' -or
        $awSignature.SignerCertificate.Thumbprint -ine $awPublisher) {
        throw 'Hazirlik betiginin kurumsal imzasi dogrulanamadi.'
    }

    & $awTool -Mode PrepareGpo `
        -ExpectedComputer 'DC01' -ExpectedDomain 'vizyonveri.local' `
        -InstanceId '4c23eebe-0715-46d1-88ee-a2e96ad7ee46' `
        -AccountName 'aw-deploy' `
        -AccountSid 'S-1-5-21-34256453-3348971241-2809240126-1648' `
        -ScopeGroupSid 'S-1-5-21-34256453-3348971241-2809240126-1647' `
        -ScopeGroupName 'AuthWire-Pilot-Computers' `
        -ProtectedGpoId 'e5a9ab39-3709-49cb-837a-0208d2eb3b12' `
        -BootstrapPath (Join-Path $env:TEMP 'AuthWire-Windows-Bootstrap-v1-r4.ps1') `
        -PublisherThumbprint $awPublisher
}
