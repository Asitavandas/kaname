#Requires -Version 5.1
$ErrorActionPreference='Stop'
Set-StrictMode -Version 2
Add-Type -AssemblyName System.IO.Compression
$path=Join-Path $PSScriptRoot '..\docs\checkpoints\2026-10-26-dc01-channel-prepare.ps1'
$text=[IO.File]::ReadAllText($path);$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile($path,[ref]$tokens,[ref]$errors)
if($errors.Count){throw ($errors|Out-String)}
# Load only function definitions. Never execute the customer's entry point.
foreach($definition in @($ast.FindAll({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst]},$true))){. ([scriptblock]::Create($definition.Extent.Text))}
$reviewedSources=@{}
$manifest=[regex]::Match($text,'(?s)\$reviewedSources=@\{(.*?)\r?\n\}').Groups[1].Value
foreach($m in [regex]::Matches($manifest,"'([^']+)'='([a-f0-9]{64})'")){$reviewedSources[$m.Groups[1].Value]=$m.Groups[2].Value}
$payload=[regex]::Match($text,"\`$embeddedSources='([^']+)'").Groups[1].Value
$expected=[regex]::Match($text,"\`$archiveSha256='([^']+)'").Groups[1].Value
$bytes=[Convert]::FromBase64String($payload)
$script:checks=0
function Assert-Check([bool]$Condition,[string]$Name){if(-not $Condition){throw ('FAILED: '+$Name)};$script:checks++;Write-Host ('PASS: '+$Name)}
function Expect-Refusal([scriptblock]$Operation,[string]$Name){$refused=$false;try{$null=& $Operation}catch{$refused=$true};Assert-Check $refused $Name}
function New-TestArchive([hashtable]$Files,[string]$RenameFrom='',[string]$RenameTo='', [switch]$Duplicate){
 $memory=[IO.MemoryStream]::new();$zip=[IO.Compression.ZipArchive]::new($memory,[IO.Compression.ZipArchiveMode]::Create,$true)
 try{
  foreach($name in @($Files.Keys|Sort-Object)){
   $entryName=$name;if($name -ceq $RenameFrom){$entryName=$RenameTo}
   if($Duplicate -and $name -cne @($Files.Keys|Sort-Object)[0]){$entryName=@($Files.Keys|Sort-Object)[0]}
   $entry=$zip.CreateEntry($entryName);$s=$entry.Open();try{$s.Write($Files[$name],0,$Files[$name].Length)}finally{$s.Dispose()}
  }
 }finally{$zip.Dispose()}
 try{return ,$memory.ToArray()}finally{$memory.Dispose()}
}
function Remove-TestTrust($Certificate,[string]$Store){
 if($null -eq $Certificate){return}
 $s=[Security.Cryptography.X509Certificates.X509Store]::new($Store,'LocalMachine')
 try{$s.Open('ReadWrite');$s.Remove($Certificate)}finally{$s.Close()}
}
Assert-Check ($reviewedSources.Count -eq 13) 'fixed thirteen-file allowlist parsed'
$sources=Read-AuthWireReviewedSourceBytes $bytes $expected
Assert-Check ($sources.Count -eq 13) 'real embedded archive accepted'
foreach($name in $reviewedSources.Keys){
 $sourcePath=Join-Path (Join-Path $PSScriptRoot '..\windows\connector') $name
 Assert-Check ((Get-AuthWireDeliveryBodyHash ([IO.File]::ReadAllText($sourcePath))) -ceq $reviewedSources[$name]) ('archive matches reviewed repo source '+$name)
}
Expect-Refusal {Read-AuthWireReviewedSourceBytes $bytes ('0'*64)} 'changed container digest refused'
$changed=[hashtable]$sources.Clone();$first=@($sources.Keys|Sort-Object)[0]
$changed[$first]=[Text.Encoding]::UTF8.GetBytes('unreviewed code')
$bad=New-TestArchive $changed
Expect-Refusal {Read-AuthWireReviewedSourceBytes $bad (Get-AuthWireDeliveryHash $bad)} 'changed source refused even with matching container digest'
$bad=New-TestArchive $sources $first ('../'+$first)
Expect-Refusal {Read-AuthWireReviewedSourceBytes $bad (Get-AuthWireDeliveryHash $bad)} 'traversal member refused'
$bad=New-TestArchive $sources $first $first.ToUpperInvariant()
Expect-Refusal {Read-AuthWireReviewedSourceBytes $bad (Get-AuthWireDeliveryHash $bad)} 'wrong-case member refused'
$bad=New-TestArchive $sources -Duplicate
Expect-Refusal {Read-AuthWireReviewedSourceBytes $bad (Get-AuthWireDeliveryHash $bad)} 'duplicate members refused'
$large=[hashtable]$sources.Clone();$large[$first]=New-Object byte[] 131073
$bad=New-TestArchive $large
Expect-Refusal {Read-AuthWireReviewedSourceBytes $bad (Get-AuthWireDeliveryHash $bad)} 'oversized expanded source refused'
$extra=[hashtable]$sources.Clone();$extra['extra.ps1']=[Text.Encoding]::UTF8.GetBytes('extra')
$bad=New-TestArchive $extra
Expect-Refusal {Read-AuthWireReviewedSourceBytes $bad (Get-AuthWireDeliveryHash $bad)} 'extra source refused'
$certificate=$null;$directory=Join-Path $env:ProgramData ('AuthWire-DeliveryFixture-'+[guid]::NewGuid().ToString('N'))
$rejectedDirectory=$directory+'-rejected'
$keyAcl=$null;$keyPath=$null
try{
 $certificate=New-SelfSignedCertificate -Type CodeSigningCert -Subject ('CN=AuthWire source fixture '+[guid]::NewGuid().ToString('N')) -KeyAlgorithm RSA -KeyLength 3072 -Provider 'Microsoft Software Key Storage Provider' -KeyExportPolicy NonExportable -CertStoreLocation 'Cert:\LocalMachine\My' -NotAfter (Get-Date).AddDays(1)
 foreach($name in @('Root','TrustedPublisher')){
  $public=[Security.Cryptography.X509Certificates.X509Certificate2]::new($certificate.RawData)
  $s=[Security.Cryptography.X509Certificates.X509Store]::new($name,'LocalMachine')
  try{$s.Open('ReadWrite');$s.Add($public)}finally{$s.Close();$public.Dispose()}
 }
 $rsa=[Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($certificate)
 try{
  $keyPath=Join-Path (Join-Path $env:ProgramData 'Microsoft\Crypto\Keys') $rsa.Key.UniqueName
  $keyAcl=(Get-Acl -LiteralPath $keyPath).Sddl
  Assert-Check ([int]$rsa.Key.ExportPolicy -eq 0) 'fixture signer private key is non-exportable'
 }finally{$rsa.Dispose()}
 Expect-Refusal {New-AuthWireSignedDelivery $changed $rejectedDirectory $certificate} 'unreviewed signing input refused before output'
 Assert-Check (-not (Test-Path -LiteralPath $rejectedDirectory)) 'rejected input creates no directory'
 New-AuthWireSignedDelivery $sources $directory $certificate
 Assert-AuthWireSignedDelivery $directory $certificate.Thumbprint
 Assert-Check $true 'actual thirteen-source delivery signed and verified'
 $snap=@{};foreach($name in $reviewedSources.Keys){$snap[$name]=Get-AuthWireDeliveryHash ([IO.File]::ReadAllBytes((Join-Path $directory $name)))}
 Assert-Check (@(Get-ChildItem -LiteralPath $directory).Count -eq 13) 'only thirteen reviewed files written'
 $signed=@(Get-ChildItem -LiteralPath $directory -Filter '*.ps1')
 Assert-Check ($signed.Count -eq 12) 'all twelve PowerShell sources carry valid signatures'
 Expect-Refusal {New-AuthWireSignedDelivery $sources $directory $certificate} 'existing source directory never overwritten'
 Assert-AuthWireSignedDelivery $directory $certificate.Thumbprint
 foreach($name in $reviewedSources.Keys){if((Get-AuthWireDeliveryHash ([IO.File]::ReadAllBytes((Join-Path $directory $name)))) -cne $snap[$name]){throw 'Source changed during inspection'}}
 Assert-Check $true 'inspection and duplicate refusal preserve all signed bytes'
 Expect-Refusal {Assert-AuthWireSignedDelivery $directory ('0'*40)} 'foreign publisher refused'
 $target=Join-Path $directory $first;$original=[IO.File]::ReadAllBytes($target)
 try{[IO.File]::AppendAllText($target,"`n# tampered`n");Expect-Refusal {Assert-AuthWireSignedDelivery $directory $certificate.Thumbprint} 'tampered signed source refused'}finally{[IO.File]::WriteAllBytes($target,$original)}
 $acl=Get-Acl -LiteralPath $directory
 $weak=Get-Acl -LiteralPath $directory
 $null=$weak.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new([Security.Principal.SecurityIdentifier]::new('S-1-5-32-545'),'Read','None','None','Allow'))
 try{Set-Acl -LiteralPath $directory -AclObject $weak;Expect-Refusal {Assert-AuthWireSignedDelivery $directory $certificate.Thumbprint} 'foreign directory ACL entry refused'}finally{Set-Acl -LiteralPath $directory -AclObject $acl}
 Assert-Check ((Get-Acl -LiteralPath $keyPath).Sddl -ceq $keyAcl) 'existing code-signing key ACL unchanged'
 Assert-AuthWireSignedDelivery $directory $certificate.Thumbprint
}finally{
 if(Test-Path -LiteralPath $directory){Remove-Item -LiteralPath $directory -Recurse -Force}
 if(Test-Path -LiteralPath $rejectedDirectory){Remove-Item -LiteralPath $rejectedDirectory -Recurse -Force}
 Remove-TestTrust $certificate 'Root';Remove-TestTrust $certificate 'TrustedPublisher'
 if($null -ne $certificate){Remove-Item -LiteralPath ('Cert:\LocalMachine\My\'+$certificate.Thumbprint) -DeleteKey -Force}
}
Assert-Check (-not (Test-Path -LiteralPath $directory)) 'fixture source directory cleaned up'
[pscustomobject]@{Event='WINDOWS_REVIEWED_SOURCE_DELIVERY_CHECKS';Checks=$script:checks;CustomerEntryPointExecuted=$false;CustomerChannelKeyCreated=$false;FixtureCleanupVerified=$true}|ConvertTo-Json
