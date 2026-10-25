# Operator on DC01; reviewed bounded administration command using documented additive certutil operation.
# Not claimed as live-tested until operator returns publication result. No certificate request or key changes.
$ErrorActionPreference = 'Stop'
Import-Module ActiveDirectory
if ($env:COMPUTERNAME -ine 'DC01') { throw 'Bu komut DC01 uzerinde calistirilmali' }

$awName = 'AuthWireConnectorCodeSigning-4c23eebe'
$awServer = 'dc01.vizyonveri.local'
$awReceiptPath = 'C:\ProgramData\AuthWire-SigningTemplate-b05c01482d03415897d290ccde085a37\template-preparation.json'
$awReceipt = Get-Content -LiteralPath $awReceiptPath -Raw | ConvertFrom-Json
if ($awReceipt.Phase -ne 'verified_unpublished' -or $awReceipt.TemplateName -ne $awName -or $awReceipt.InstanceId -ne '4c23eebe-0715-46d1-88ee-a2e96ad7ee46') {
    throw 'Hazirlik kaydi beklenen durumda degil'
}
$awTemplate = Get-ADObject -Identity ([guid]$awReceipt.TemplateGuid) -Server $awServer -Properties msPKI-Cert-Template-OID
if ($awTemplate.Name -ne $awName -or [string]$awTemplate.'msPKI-Cert-Template-OID' -ne $awReceipt.Oid) {
    throw 'Sablon kimligi eslesmedi'
}
$awCa = Get-ADObject -Identity ([guid]$awReceipt.CaGuid) -Server $awServer -Properties certificateTemplates,dNSHostName
if ($awCa.Name -ne 'vizyonveri-DC01-CA' -or [string]$awCa.dNSHostName -ine $awServer) { throw 'CA kimligi eslesmedi' }
$awBefore = @($awCa.certificateTemplates | ForEach-Object { [string]$_ })
$awAdded = $awBefore -notcontains $awName
if ($awAdded) {
    & "$env:SystemRoot\System32\certutil.exe" -config 'dc01.vizyonveri.local\vizyonveri-DC01-CA' -SetCATemplates "+$awName"
    if ($LASTEXITCODE -ne 0) { throw 'Yayimlama basarisiz; komutu tekrar calistirmadan ciktiyi paylasin' }
}
$awAfter = @((Get-ADObject -Identity $awCa.ObjectGUID -Server $awServer -Properties certificateTemplates).certificateTemplates | ForEach-Object { [string]$_ })
$awMissing = @($awBefore | Where-Object { $awAfter -notcontains $_ })
if ($awAfter -notcontains $awName -or $awMissing.Count -ne 0) { throw 'Yayimlama sonrasi liste kontrolu basarisiz' }

[pscustomobject]@{
    Event = 'WINDOWS_CONNECTOR_TEMPLATE_PUBLICATION'
    TemplateName = $awName
    PublishedNow = $awAdded
    TemplatePublished = ($awAfter -contains $awName)
    ExistingTemplatesPreserved = ($awMissing.Count -eq 0)
    EnrollmentRequested = $false
    CertificatesChanged = $false
} | ConvertTo-Json
