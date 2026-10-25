# Operator on elevated Windows PowerShell on DC01. One recorded native certreq enrollment attempt.
# No claim of live success until output received. Existing Admin signer, client packages and key ACL unchanged.
$ErrorActionPreference = 'Stop'
if ($env:COMPUTERNAME -ine 'DC01') { throw 'DC01 uzerinde calistirilmali' }
$awFolder = 'C:\ProgramData\AuthWire-SigningTemplate-b05c01482d03415897d290ccde085a37'
$awAttemptPath = Join-Path $awFolder 'machine-enrollment-attempt.json'
if (Test-Path -LiteralPath $awAttemptPath) { throw 'Onceki istek kaydi mevcut; yeniden istemeden ciktiyi paylasin' }

$awBefore = @(Get-ChildItem Cert:\LocalMachine\My | ForEach-Object { $_.Thumbprint })
$awAttempt = [ordered]@{
    Version = 1
    Computer = 'DC01'
    Template = 'AuthWireConnectorCodeSigning-4c23eebe'
    Ca = 'dc01.vizyonveri.local\vizyonveri-DC01-CA'
    StartedUtc = [datetime]::UtcNow.ToString('o')
    Phase = 'before_enroll'
    BeforeThumbprints = $awBefore
    ExitCode = $null
    IssuedThumbprint = $null
}
$awBytes = [Text.Encoding]::UTF8.GetBytes(($awAttempt | ConvertTo-Json -Depth 4))
$awFile = [IO.File]::Open($awAttemptPath, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
try { $awFile.Write($awBytes, 0, $awBytes.Length) } finally { $awFile.Dispose() }

& "$env:SystemRoot\System32\certreq.exe" -enroll -machine -AdminForceMachine -q -config 'dc01.vizyonveri.local\vizyonveri-DC01-CA' 'AuthWireConnectorCodeSigning-4c23eebe'
$awAttempt.ExitCode = $LASTEXITCODE
$awAttempt.Phase = 'enroll_returned'
$awAttempt | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $awAttemptPath -Encoding UTF8
if ($awAttempt.ExitCode -ne 0) { throw 'Sertifika istegi tamamlanamadi; komutu tekrarlamadan tum ciktiyi paylasin' }

$awNew = @(Get-ChildItem Cert:\LocalMachine\My | Where-Object { $awBefore -notcontains $_.Thumbprint })
if ($awNew.Count -ne 1 -or -not $awNew[0].HasPrivateKey) { throw 'Sertifika sonucu ayrica incelenmeli; komutu tekrarlamayin' }
$awAttempt.IssuedThumbprint = $awNew[0].Thumbprint
$awAttempt.Phase = 'certificate_installed_candidate'
$awAttempt | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $awAttemptPath -Encoding UTF8

$awNew | Select-Object Subject, Issuer, Thumbprint, SerialNumber, HasPrivateKey, NotBefore, NotAfter | Format-List
Write-Output ("Islem kaydi: " + $awAttemptPath)
