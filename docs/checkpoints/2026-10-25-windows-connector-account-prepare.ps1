# Run on DC01 as the authorized administrator. Creates only the scoped gMSA if absent.
& {
    $ErrorActionPreference = 'Stop'
    $awSetup = Join-Path $env:TEMP 'AuthWire-Windows-Bootstrap-v1-r2.ps1'
    if (-not (Test-Path -LiteralPath $awSetup)) { throw 'Hazirlik dosyasi bulunamadi.' }
    $awPublisher = '6E74B513F766E01730719684A41B2664380CA68A'
    $awSignature = Get-AuthenticodeSignature -FilePath $awSetup
    if ($awSignature.Status.ToString() -ne 'Valid' -or $awSignature.SignerCertificate.Thumbprint -ine $awPublisher) {
        throw 'Dosyanin kurumsal imzasi dogrulanamadi.'
    }
    & $awSetup -Mode PrepareAccount -ExpectedDomain 'vizyonveri.local' -ConnectorComputer 'DC01' -InstanceId '4c23eebe-0715-46d1-88ee-a2e96ad7ee46' -AccountName 'aw-deploy' -GpoId 'e5a9ab39-3709-49cb-837a-0208d2eb3b12' -PublisherThumbprint $awPublisher
}
