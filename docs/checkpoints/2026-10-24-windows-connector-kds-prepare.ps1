# One-time AD prerequisite. Creates a KDS root only when none is visible.
# Normal propagation allowance: never backdate, delete keys or emit key material.
$awHostInfo = Get-CimInstance Win32_ComputerSystem -ErrorAction Stop
if ($env:COMPUTERNAME -ne 'DC01' -or $awHostInfo.Domain -ne 'vizyonveri.local' -or
    -not $awHostInfo.PartOfDomain -or $awHostInfo.DomainRole -lt 4) {
    throw 'Bu hazirlik DC01 / vizyonveri.local uzerinde calistirilmali.'
}
$awDc = 'dc01.vizyonveri.local'
$awConfiguration = (Get-ADRootDSE -Server $awDc -ErrorAction Stop).configurationNamingContext
$awKdsQuery = @{
    Server = $awDc
    SearchBase = $awConfiguration
    LDAPFilter = '(objectClass=msKds-ProvRootKey)'
    Properties = @('whenCreated')
    ErrorAction = 'Stop'
}
$awBefore = @(Get-ADObject @awKdsQuery)
$awCreated = $false
if ($awBefore.Count -eq 0) {
    Add-KdsRootKey -EffectiveImmediately -ErrorAction Stop | Out-Null
    $awCreated = $true
}
$awAfter = @(Get-ADObject @awKdsQuery)
if ($awAfter.Count -eq 0) {
    throw 'KDS sonucu dogrulanamadi. Olusturma komutunu tekrarlamayin; yalniz metadata kontrol sonucunu paylasin.'
}
$awCheckAfter = @($awAfter | ForEach-Object {
    $_.whenCreated.ToUniversalTime().AddHours(10)
} | Sort-Object)[0]
[pscustomobject]@{
    Event = 'WINDOWS_CONNECTOR_KDS_PREPARED'
    Computer = $env:COMPUTERNAME
    Created = $awCreated
    RootKeyObjectsVisible = $awAfter.Count
    RootKeys = @($awAfter | Select-Object Name,
        @{Name='CreatedUtc';Expression={$_.whenCreated.ToUniversalTime().ToString('o')}})
    ConservativeCheckAfterUtc = $awCheckAfter.ToString('o')
    ConservativeCheckAfterLocal = $awCheckAfter.ToLocalTime().ToString('o')
    GmsaReadinessVerified = $false
    AdChanged = $awCreated
    GpoChanged = $false
    CertificatesChanged = $false
    KeyMaterialExported = $false
} | ConvertTo-Json -Depth 5
