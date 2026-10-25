& "$env:SystemRoot\System32\certreq.exe" -new -?
& "$env:SystemRoot\System32\certreq.exe" -submit -?
& "$env:SystemRoot\System32\certreq.exe" -accept -?

$awPath = 'C:\ProgramData\AuthWire-SigningTemplate-b05c01482d03415897d290ccde085a37\machine-enrollment-attempt.json'
$awRecord = Get-Content -LiteralPath $awPath -Raw | ConvertFrom-Json
$awNew = @(Get-ChildItem Cert:\LocalMachine\My | Where-Object {
    $awRecord.BeforeThumbprints -notcontains $_.Thumbprint
})
[pscustomobject]@{
    Phase = $awRecord.Phase
    ExitCode = $awRecord.ExitCode
    NewMachineCertificateCount = $awNew.Count
} | Format-List
$awNew | Select-Object Subject, Thumbprint, HasPrivateKey | Format-List
