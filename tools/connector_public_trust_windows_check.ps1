#Requires -Version 5.1
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0
$path = Join-Path $PSScriptRoot '..\docs\checkpoints\2026-10-26-dc01-connector-trust.ps1'
$tokens = $null
$errors = $null
$ast = [Management.Automation.Language.Parser]::ParseFile($path, [ref]$tokens, [ref]$errors)
if ($errors.Count -ne 0) { throw ($errors | Out-String) }
# Load only definitions. The customer-host entry point is never invoked.
$functions = @($ast.FindAll({param($node) $node -is [Management.Automation.Language.FunctionDefinitionAst]}, $true))
foreach ($definition in $functions) { . ([scriptblock]::Create($definition.Extent.Text)) }
$compile = @($ast.FindAll({param($node) $node -is [Management.Automation.Language.CommandAst] -and $node.GetCommandName() -eq 'Add-Type'}, $true))
if ($compile.Count -ne 1) { throw 'Expected exactly one TLS diagnostic compiler invocation.' }
. ([scriptblock]::Create($compile[0].Extent.Text))
$script:checks = 0
function Assert-Check([bool]$Condition, [string]$Name) {
    if (-not $Condition) { throw ('FAILED: ' + $Name) }
    $script:checks++
    Write-Host ('PASS: ' + $Name)
}
function Expect-Refusal([scriptblock]$Operation, [string]$Name) {
    $refused = $false
    try { $null = & $Operation } catch { $refused = $true }
    Assert-Check $refused $Name
}
function Remove-FixtureTrust($Certificate, [string]$Name) {
    if ($null -eq $Certificate) { return }
    $store = [Security.Cryptography.X509Certificates.X509Store]::new($Name, 'LocalMachine')
    try { $store.Open('ReadWrite'); $store.Remove($Certificate) } finally { $store.Close() }
}
$web = $null
$signer = $null
$receipt = $null
$rootBefore = @(Get-AuthWirePublicTrustSnapshot 'Root')
$publisherBefore = @(Get-AuthWirePublicTrustSnapshot 'TrustedPublisher')
try {
    $dns = 'aw-trust-' + [guid]::NewGuid().ToString('N') + '.example.test'
    $web = New-SelfSignedCertificate -Type Custom -DnsName $dns -KeyAlgorithm RSA -KeyLength 2048 `
        -KeyExportPolicy NonExportable -CertStoreLocation 'Cert:\CurrentUser\My' `
        -TextExtension @('2.5.29.19={critical}{text}ca=false','2.5.29.37={text}1.3.6.1.5.5.7.3.1') `
        -NotAfter (Get-Date).AddDays(1)
    $signer = New-SelfSignedCertificate -Type CodeSigningCert -Subject ('CN=' + $dns) -KeyAlgorithm RSA `
        -KeyLength 2048 -KeyExportPolicy NonExportable -CertStoreLocation 'Cert:\CurrentUser\My' -NotAfter (Get-Date).AddDays(1)
    $webHash = Get-AuthWirePublicCertificateHash $web
    $signerHash = Get-AuthWirePublicCertificateHash $signer
    Expect-Refusal { Add-AuthWireExactPublicTrust $web 'Root' ('0' * 64) } 'wrong SHA256 cannot add trust'
    Expect-Refusal { Add-AuthWireExactPublicTrust $web 'TrustedPublisher' $webHash } 'TLS certificate cannot become a publisher'
    Expect-Refusal { Add-AuthWireExactPublicTrust $signer 'Root' $signerHash } 'code signer cannot become a root'
    Expect-Refusal { Add-AuthWireExactPublicTrust $web 'My' $webHash } 'other stores refused'
    Assert-Check (@(Compare-Object $rootBefore @(Get-AuthWirePublicTrustSnapshot 'Root')).Count -eq 0) 'refusals preserve machine roots'
    Assert-Check (@(Compare-Object $publisherBefore @(Get-AuthWirePublicTrustSnapshot 'TrustedPublisher')).Count -eq 0) 'refusals preserve publishers'
    $chain = [Security.Cryptography.X509Certificates.X509Chain]::new($true)
    try {
        $chain.ChainPolicy.RevocationMode = 'Online'
        $chain.ChainPolicy.RevocationFlag = 'ExcludeRoot'
        $null = $chain.ChainPolicy.ApplicationPolicy.Add([Security.Cryptography.Oid]::new('1.3.6.1.5.5.7.3.1'))
        Assert-Check (-not $chain.Build($web)) 'fixture self-signed endpoint initially untrusted'
    } finally { $chain.Dispose() }
    Assert-Check (Add-AuthWireExactPublicTrust $web 'Root' $webHash) 'exact TLS public certificate added'
    Assert-Check (-not (Add-AuthWireExactPublicTrust $web 'Root' $webHash)) 'TLS trust repeat is a no-op'
    $chain = [Security.Cryptography.X509Certificates.X509Chain]::new($true)
    try {
        $chain.ChainPolicy.RevocationMode = 'Online'
        $chain.ChainPolicy.RevocationFlag = 'ExcludeRoot'
        $null = $chain.ChainPolicy.ApplicationPolicy.Add([Security.Cryptography.Oid]::new('1.3.6.1.5.5.7.3.1'))
        Assert-Check ($chain.Build($web)) 'native machine chain trusts explicit non-CA self-signed endpoint'
    } finally { $chain.Dispose() }
    Assert-Check (Add-AuthWireExactPublicTrust $signer 'TrustedPublisher' $signerHash) 'exact public publisher added'
    Assert-Check (-not (Add-AuthWireExactPublicTrust $signer 'TrustedPublisher' $signerHash)) 'publisher repeat is a no-op'
    Assert-Check (-not (Get-Item ('Cert:\LocalMachine\Root\' + $web.Thumbprint)).HasPrivateKey) 'root entry contains no private key'
    Assert-Check (-not (Get-Item ('Cert:\LocalMachine\TrustedPublisher\' + $signer.Thumbprint)).HasPrivateKey) 'publisher entry contains no private key'
    Assert-Check ($web.HasPrivateKey -and $signer.HasPrivateKey) 'original personal keys remain present'
    $rootAfter = @(Get-AuthWirePublicTrustSnapshot 'Root')
    $publisherAfter = @(Get-AuthWirePublicTrustSnapshot 'TrustedPublisher')
    $rootDiff = @(Compare-Object $rootBefore $rootAfter)
    $publisherDiff = @(Compare-Object $publisherBefore $publisherAfter)
    Assert-Check ($rootDiff.Count -eq 1 -and $rootDiff[0].SideIndicator -eq '=>' -and $rootDiff[0].InputObject -ceq $webHash) 'only selected root certificate added'
    Assert-Check ($publisherDiff.Count -eq 1 -and $publisherDiff[0].SideIndicator -eq '=>' -and $publisherDiff[0].InputObject -ceq $signerHash) 'only selected publisher added'
    $receipt = New-AuthWireTrustReceiptDirectory
    $acl = Get-Acl -LiteralPath $receipt
    Assert-Check ($acl.AreAccessRulesProtected) 'receipt inheritance is protected'
    $rules = @($acl.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier]))
    Assert-Check ($rules.Count -eq 2 -and @($rules | Where-Object { $_.IdentityReference.Value -notin @('S-1-5-18','S-1-5-32-544') }).Count -eq 0) 'receipt restricted to SYSTEM and Administrators'
} finally {
    Remove-FixtureTrust $web 'Root'
    Remove-FixtureTrust $signer 'TrustedPublisher'
    foreach ($cert in @($web,$signer)) {
        if ($null -ne $cert) { Remove-Item -LiteralPath ('Cert:\CurrentUser\My\' + $cert.Thumbprint) -DeleteKey -Force }
    }
    if ($null -ne $receipt) { Remove-Item -LiteralPath $receipt -Force }
}
Assert-Check (@(Compare-Object $rootBefore @(Get-AuthWirePublicTrustSnapshot 'Root')).Count -eq 0) 'fixture root cleaned up'
Assert-Check (@(Compare-Object $publisherBefore @(Get-AuthWirePublicTrustSnapshot 'TrustedPublisher')).Count -eq 0) 'fixture publisher cleaned up'
[pscustomobject]@{ Event='WINDOWS_PUBLIC_TRUST_CHECKS'; Checks=$script:checks; CustomerEntryPointExecuted=$false; FixtureCleanupVerified=$true } | ConvertTo-Json
