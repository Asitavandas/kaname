# DC01 elevated operator command. Same pinned CSR, one recorded Submit. Live result pending; no automatic Accept or resubmit.
$ErrorActionPreference = 'Stop'
if ($env:COMPUTERNAME -ine 'DC01') { throw 'DC01 uzerinde calistirilmali' }
$awFolder = 'C:\ProgramData\AuthWire-SigningTemplate-b05c01482d03415897d290ccde085a37'
$awReq = Join-Path $awFolder 'machine-signing-v2.req'
$awCer = Join-Path $awFolder 'machine-signing-v2.cer'
$awState = Join-Path $awFolder 'machine-signing-v2-submit.json'
$awLog = Join-Path $awFolder 'machine-signing-v2-submit.log'
$awHash = 'D07E3800345AFD62E8423B5E720047BDA3670CBDB1644153BDBD90BDEC689BDE'

if ((Get-FileHash -LiteralPath $awReq -Algorithm SHA256).Hash -ne $awHash) {
    throw 'Istek dosyasinin ozeti eslesmedi'
}
if ((Test-Path -LiteralPath $awState) -or (Test-Path -LiteralPath $awCer) -or (Test-Path -LiteralPath $awLog)) {
    throw 'Onceki gonderim kaydi mevcut; yeniden gondermeden ciktiyi paylasin'
}
$awSubmit = [ordered]@{
    StartedUtc = [datetime]::UtcNow.ToString('o')
    RequestSha256 = $awHash
    Ca = 'dc01.vizyonveri.local\vizyonveri-DC01-CA'
    Phase = 'before_submit'
    ExitCode = $null
    CertificateFileExists = $false
}
$awBytes = [Text.Encoding]::UTF8.GetBytes(($awSubmit | ConvertTo-Json))
$awFile = [IO.File]::Open($awState, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
try { $awFile.Write($awBytes, 0, $awBytes.Length) } finally { $awFile.Dispose() }

& "$env:SystemRoot\System32\certreq.exe" -submit -AdminForceMachine -q -config 'dc01.vizyonveri.local\vizyonveri-DC01-CA' $awReq $awCer | Tee-Object -FilePath $awLog
$awSubmit.ExitCode = $LASTEXITCODE
$awSubmit.Phase = 'submit_returned'
$awSubmit.CertificateFileExists = Test-Path -LiteralPath $awCer
$awSubmit | ConvertTo-Json | Set-Content -LiteralPath $awState -Encoding UTF8

[pscustomobject]@{
    Event = 'WINDOWS_CONNECTOR_MACHINE_CSR_SUBMIT_RETURNED'
    ExitCode = $awSubmit.ExitCode
    CertificateFileExists = $awSubmit.CertificateFileExists
    CertificateFile = $awCer
    SubmissionRecord = $awState
    SubmissionLog = $awLog
} | ConvertTo-Json
