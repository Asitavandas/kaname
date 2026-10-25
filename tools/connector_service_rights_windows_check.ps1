# Native read-only LSA API checks on an isolated GitHub-hosted Windows VM.
$ErrorActionPreference = 'Stop'
if ($env:RUNNER_ENVIRONMENT -ne 'github-hosted') { throw 'Hosted fixture only.' }
$source = Join-Path $PSScriptRoot '..\windows\connector\Get-AuthWireServiceRights.ps1'
$tokens = $null; $errors = $null
$null = [Management.Automation.Language.Parser]::ParseFile($source,[ref]$tokens,[ref]$errors)
if ($errors.Count) { throw ($errors.Message -join '; ') }
$script:checks = 0
function Check([bool]$Condition,[string]$Name) {
    if (-not $Condition) { throw $Name }
    $script:checks++
}
$sid = 'S-1-5-21-111-222-333-1234'
$result = & $source -ExpectedComputer ([Environment]::MachineName) -AccountSid $sid | ConvertFrom-Json
Check ($result.Event -eq 'WINDOWS_CONNECTOR_SERVICE_RIGHTS_LSA_READONLY' -and $result.ReadSucceeded) 'Real LSA read succeeds'
Check (-not $result.PolicyChanged -and -not $result.AdChanged -and -not $result.ServicesCreated -and -not $result.SecretsExported) 'Read-only result never reports writes or secrets'
Check (-not $result.ServiceLogonVerified -and -not $result.EffectiveServiceRightVerified -and -not $result.GroupEvaluationPerformed) 'Assignment read does not claim effective rights or service logon'
Check (-not $result.DirectAllowAssigned -and -not $result.DirectDenyAssigned) 'Absent fixture SID never gets granted or denied by the probe'
foreach ($entry in @($result.AllowAssignedSids) + @($result.DenyAssignedSids)) {
    Check ([System.Security.Principal.SecurityIdentifier]::new($entry).Value -eq $entry) 'Kernel assignment is a valid SID'
}
$second = & $source -ExpectedComputer ([Environment]::MachineName) -AccountSid $sid | ConvertFrom-Json
Check $second.ReadSucceeded 'Repeated inspection reuses the in-memory reader'
$caught = $false
try { $null = & $source -ExpectedComputer 'WRONG-HOST' -AccountSid $sid } catch {
    if ($_.Exception.Message -notlike '*LOCAL_COMPUTER_MISMATCH*') { throw }
    $caught = $true
}
Check $caught 'Wrong host fails before policy access'
$caught = $false
try { $null = & $source -ExpectedComputer ([Environment]::MachineName) -AccountSid 'not-a-sid' } catch { $caught = $true }
Check $caught 'Invalid SID rejected before policy access'
$caught = $false
try { $null = [AuthWire.Connector.LocalRightsReaderV1]::Read('AuthWireNonexistentUserRight') } catch {
    $e = $_.Exception
    while ($null -ne $e.InnerException) { $e = $e.InnerException }
    Check ($e -is [System.ComponentModel.Win32Exception] -and $e.NativeErrorCode -eq 1313) 'Native invalid-right failure preserved as Win32 error'
    $caught = $true
}
Check $caught 'Native query failure is never returned as an empty assignment list'

$text = [IO.File]::ReadAllText($source)
$native = @([regex]::Matches($text, 'extern\s+uint\s+(Lsa\w+)\(') | ForEach-Object { $_.Groups[1].Value })
Check (($native | Sort-Object) -join ',' -eq 'LsaClose,LsaEnumerateAccountsWithUserRight,LsaFreeMemory,LsaNtStatusToWinError,LsaOpenPolicy') 'Native imports limited to five policy read/cleanup functions'
Check ($text.Contains('0x00000801') -and -not $text.Contains('LsaAddAccountRights') -and -not $text.Contains('LsaRemoveAccountRights')) 'No policy write access or write APIs'
Write-Output ('AUTHWIRE_LSA_RIGHTS_NATIVE_OK ' + (@{
    checks=$checks; native_powershell=$PSVersionTable.PSVersion.ToString()
    real_local_lsa_read=$true; real_ad_tested=$false
    customer_state_used=$false; policy_writes=0; services_created=0
    group_evaluation_tested=$false; service_logon_tested=$false
} | ConvertTo-Json -Compress))
