param([Parameter(Mandatory=$true)][string]$Root)
$ErrorActionPreference = 'Stop'
$reportFile = Join-Path $env:RUNNER_TEMP ('kaname-report-' + $env:GITHUB_RUN_ID + '-' + $env:GITHUB_RUN_ATTEMPT + '.json')
$scriptFile = Join-Path $PSScriptRoot 'windows_diagnose.py'
$venvPython = Join-Path $Root '.venv\Scripts\python.exe'
Write-Output ('Runner: ' + $env:RUNNER_NAME)
Write-Output ('Run: ' + $env:GITHUB_SERVER_URL + '/' + $env:GITHUB_REPOSITORY + '/actions/runs/' + $env:GITHUB_RUN_ID)
if (Test-Path -LiteralPath $venvPython -PathType Leaf) {
    & $venvPython -I $scriptFile --root $Root --output $reportFile
    if ($LASTEXITCODE -ne 0) { throw 'KANAME diagnostic interpreter failed. Local state was not changed.' }
} elseif (Get-Command py -ErrorAction SilentlyContinue) {
    & py -3.12 -I $scriptFile --root $Root --output $reportFile
    if ($LASTEXITCODE -ne 0) { throw 'Python 3.12 is unavailable or the diagnostic failed. Local state was not changed.' }
} else {
    $minimal = @{schema_version=1; root_exists=(Test-Path -LiteralPath $Root -PathType Container); python_unavailable=$true; secrets_exported=$false}
    $minimal | ConvertTo-Json | Set-Content -LiteralPath $reportFile -Encoding UTF8
    Write-Output 'KANAME_REPORT_BEGIN'
    $minimal | ConvertTo-Json
    Write-Output 'KANAME_REPORT_END'
}
if (-not (Test-Path -LiteralPath $reportFile -PathType Leaf)) { throw 'Diagnostic report was not created.' }
Write-Output 'Read-only inspection complete. No KANAME settings, CA keys, firewall or services were changed.'
