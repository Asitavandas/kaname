# Disposable fixture only. All certs, trust and key properties belong to this test.
param([Parameter(Mandatory=$true)][string]$FixtureDirectory)
$ErrorActionPreference='Stop';Set-StrictMode -Version 2
if($env:RUNNER_ENVIRONMENT -ne 'github-hosted'){throw 'Hosted fixture only'}
Import-Module (Join-Path $PSHOME 'Modules\Microsoft.PowerShell.Security\Microsoft.PowerShell.Security.psd1') -ErrorAction Stop
function Import-Functions([string]$Path){
 $t=$null;$e=$null;$ast=[Management.Automation.Language.Parser]::ParseFile($Path,[ref]$t,[ref]$e)
 if($e.Count){throw ($e.Message -join '; ')}
 foreach($f in $ast.EndBlock.Statements|Where-Object{$_ -is [Management.Automation.Language.FunctionDefinitionAst]}){. ([scriptblock]::Create('function global:'+$f.Name+$f.Extent.Text.Substring(('function '+$f.Name).Length)))}
}
foreach($n in @('New-AuthWireDeploymentCandidate.ps1','Get-AuthWireMachineSignerMetadata.ps1','New-AuthWireCombinedCandidate.ps1')){Import-Functions (Join-Path $PSScriptRoot ('../windows/connector/'+$n))}
$script:checks=0
function Check([bool]$Value,[string]$Name){if(-not $Value){throw $Name};$script:checks++;Write-Host ('PASS '+$Name)}
function Reject([scriptblock]$Action,[string]$CheckName){$caught=$false;try{& $Action}catch{$caught=$true;Write-Host ('EXPECTED '+$CheckName+': '+$_.Exception.Message)};Check $caught $CheckName}
$cert=$null;$public=$null;$roots=$null;$publishers=$null;$markerKey=$null;$parent=$null
try{
 $delivery=Join-Path $PSScriptRoot '../docs/checkpoints/2026-10-28-dc01-combined-candidate.ps1'
 $dt=$null;$de=$null;$null=[Management.Automation.Language.Parser]::ParseFile($delivery,[ref]$dt,[ref]$de)
 Check ($de.Count -eq 0) 'Fixed operator delivery parses in Windows PowerShell 5.1'
 $pins=Get-Content -LiteralPath (Join-Path $FixtureDirectory 'pins.json') -Raw|ConvertFrom-Json
 $draft=Join-Path $FixtureDirectory 'draft.zip'
 foreach($name in @('traversal','large','content','apply')){Reject {Read-AuthWireCombinedDraft (Join-Path $FixtureDirectory ($name+'.zip')) $pins.$name} ('Reject '+$name)}
 Reject {Read-AuthWireCombinedDraft $draft ('0'*64)} 'Wrong outer hash'
 $d=Read-AuthWireCombinedDraft $draft $pins.draft
 Check ($d.Files.Count -eq 18) 'Complete public draft accepted'
 $template=Join-Path $FixtureDirectory 'reviewed-installer.ps1'
 $templateSource=Join-Path $PSScriptRoot '../kaname/device_client/Install-AuthWire.ps1'
 [IO.File]::WriteAllText($template,[IO.File]::ReadAllText($templateSource).Replace("`r`n","`n"),[Text.UTF8Encoding]::new($false))
 $templateHash=(Get-FileHash -LiteralPath $template -Algorithm SHA256).Hash.ToLowerInvariant()
 Reject {New-AuthWireCombinedInstaller ([IO.File]::ReadAllBytes($template)) ('0'*64) $d.Files} 'Unreviewed template rejected'
 $cert=New-SelfSignedCertificate -Type CodeSigningCert -Subject 'CN=AuthWire combined isolated fixture' -CertStoreLocation 'Cert:\LocalMachine\My' -Provider 'Microsoft Software Key Storage Provider' -KeyLength 3072 -HashAlgorithm SHA256 -KeyUsage DigitalSignature -KeyUsageProperty Sign -KeyExportPolicy NonExportable -NotAfter (Get-Date).AddDays(1)
 $public=[Security.Cryptography.X509Certificates.X509Certificate2]::new($cert.RawData)
 $roots=[Security.Cryptography.X509Certificates.X509Store]::new('Root','LocalMachine');$roots.Open('ReadWrite');$roots.Add($public)
 $publishers=[Security.Cryptography.X509Certificates.X509Store]::new('TrustedPublisher','LocalMachine');$publishers.Open('ReadWrite');$publishers.Add($public)
 $metadata=Get-AuthWireNamedMachineKeyMetadata $cert
 $markerKey=[Security.Cryptography.CngKey]::Open($metadata.Native.KeyName,[Security.Cryptography.CngProvider]::MicrosoftSoftwareKeyStorageProvider,[Security.Cryptography.CngKeyOpenOptions]::MachineKey)
 $options=[Security.Cryptography.CngPropertyOptions]::CustomProperty -bor [Security.Cryptography.CngPropertyOptions]::Persist
 $markerKey.SetProperty([Security.Cryptography.CngProperty]::new('CLR IsEphemeral',[byte[]]@(1),$options))
 $parent=Join-Path $env:ProgramData ('AuthWire-CombinedCandidates-'+[guid]::NewGuid().ToString('N'))
 $callParameters=@{DraftZip=$draft;ExpectedDraftSha256=$pins.draft;InstallerTemplatePath=$template;ExpectedInstallerTemplateSha256=$templateHash;PublisherThumbprint=$cert.Thumbprint;ServiceSid='S-1-5-21-1-2-3-1648';ExpectedKeyName=$metadata.Native.KeyName;ExpectedUniqueName=$metadata.Native.UniqueName;ExpectedKeySddl=$metadata.KeySddl;OutputParent=$parent}
 Reject {Invoke-AuthWireCombinedCandidate @callParameters -Mode ''} 'Empty mode never prepares'
 $bad=$callParameters.Clone();$bad.ExpectedKeyName='wrong';Reject {Invoke-AuthWireCombinedCandidate @bad -Mode Prepare} 'Wrong persisted key binding'
 $inspect=Invoke-AuthWireCombinedCandidate @callParameters -Mode Inspect
 Check ($inspect.ReadyForPrepare -and -not (Test-Path -LiteralPath $parent)) 'Inspect creates no candidate directory'
 $before=Get-AuthWireCombinedSignerSnapshot $cert $metadata.Native.KeyName $metadata.Native.UniqueName $metadata.KeySddl
 $prepared=Invoke-AuthWireCombinedCandidate @callParameters -Mode Prepare
 Check ($prepared.PreparedNow -and $prepared.SignaturesVerified -eq 3 -and $prepared.SignerSnapshotPreserved) 'Three actual Authenticode signatures verified with CLR marker 01'
 Check (-not $prepared.CanStage -and -not $prepared.CanApplyGpo -and -not $prepared.ArtifactExecuted -and -not $prepared.AdChanged -and -not $prepared.ServicesChanged) 'No apply, execution or infrastructure change claim'
 Check ((Get-AuthWireCombinedSignerSnapshot $cert $metadata.Native.KeyName $metadata.Native.UniqueName $metadata.KeySddl) -ceq $before) 'Native key, marker, certificate and ACL preserved'
 Check ((Get-FileHash -LiteralPath $draft -Algorithm SHA256).Hash.ToLowerInvariant() -ceq $pins.draft) 'Original input ZIP unchanged'
 # Read-only verifier uses only public inputs; no signer access or signing API.
 Import-Functions (Join-Path $PSScriptRoot '../windows/connector/Test-AuthWireCombinedContent.ps1')
 $verifyParameters=@{ConnectorId=([guid]::ParseExact($parent.Substring($parent.Length-32),'N')).ToString('D');PlanId=$prepared.PlanId;PlanVersion=$prepared.PlanVersion;DraftSha256=$prepared.DraftSha256;ManifestSha256=$prepared.ManifestSha256;PublisherThumbprint=$cert.Thumbprint;ServiceSid=$callParameters.ServiceSid}
 $savedSnapshotFunction=(Get-Item Function:Get-AuthWireCombinedSignerSnapshot).ScriptBlock
 try{
  function global:Get-AuthWireCombinedSignerSnapshot {throw 'PRIVATE_SIGNER_ACCESS_FORBIDDEN'}
  function global:Set-AuthenticodeSignature {throw 'SIGNING_FORBIDDEN'}
  $readonly=Test-AuthWireCombinedContent @verifyParameters
  Check ($readonly.ContentVerified -and $readonly.SignaturesVerified -eq 3 -and -not $readonly.PrivateKeyOpened -and -not $readonly.CanStage) 'Public-only verifier succeeds while private/signing functions are denied'
  $badPin=$verifyParameters.Clone();$badPin.ManifestSha256='0'*64
  Reject {Test-AuthWireCombinedContent @badPin} 'Readonly wrong manifest pin rejected'
  Reject {Test-AuthWireServiceCombinedContent @verifyParameters} 'Administrator cannot claim service SID proof'
 }finally{Set-Item Function:global:Get-AuthWireCombinedSignerSnapshot $savedSnapshotFunction;Remove-Item Function:global:Set-AuthenticodeSignature}
 $result=Invoke-AuthWireCombinedCandidate @callParameters -Mode Verify
 Check ($result.ManifestSha256 -ceq $prepared.ManifestSha256) 'Independent Verify accepts prepared directory'
 $again=Invoke-AuthWireCombinedCandidate @callParameters -Mode Prepare
 Check (-not $again.PreparedNow -and $again.ManifestSha256 -ceq $prepared.ManifestSha256) 'Repeated Prepare verifies, never overwrites or resigns'
 $client=Join-Path $prepared.CandidatePath 'enrollment/AuthWire-Client.ps1';$bytes=[IO.File]::ReadAllBytes($client)
 try{[IO.File]::AppendAllText($client,"`r`n# changed");Reject {Invoke-AuthWireCombinedCandidate @callParameters -Mode Verify} 'Changed signed client rejected'}finally{[IO.File]::WriteAllBytes($client,$bytes)}
 $extra=Join-Path $prepared.CandidatePath 'extra.txt'
 try{[IO.File]::WriteAllText($extra,'bad');Reject {Invoke-AuthWireCombinedCandidate @callParameters -Mode Verify} 'Unknown file rejected'}finally{Remove-Item -LiteralPath $extra -Force}
 $manifest=Join-Path $prepared.CandidatePath 'AuthWire-Combined-Manifest.ps1'
 $t=$null;$e=$null;$ast=[Management.Automation.Language.Parser]::ParseFile($manifest,[ref]$t,[ref]$e)
 Check (-not $e.Count -and -not $ast.EndBlock.Statements.Count) 'Signed manifest is comment-only and never executed'
 Check ((Get-AuthWireNamedMachineKeyMetadata $cert).Native.ClrEphemeralMarkerHex -ceq '01') 'Persisted CLR marker remains 01 after all tests'
 [pscustomobject]@{Event='COMBINED_SIGNED_CANDIDATE_NATIVE_FIXTURE';Checks=$checks;CustomerEnvironmentChanged=$false}|ConvertTo-Json
}finally{
 if($parent -and (Test-Path -LiteralPath $parent)){Remove-Item -LiteralPath $parent -Recurse -Force}
 if($publishers){if($public){$publishers.Remove($public)};$publishers.Dispose()}
 if($roots){if($public){$roots.Remove($public)};$roots.Dispose()}
 if($public){$public.Dispose()}
 if($markerKey){$markerKey.Delete();$markerKey.Dispose()}
 if($cert){Remove-Item -LiteralPath ('Cert:\LocalMachine\My\'+$cert.Thumbprint) -Force;$cert.Dispose()}
}
