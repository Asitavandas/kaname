# Hosted SCM/NTFS/AllSigned fixture. No customer AD, GPO, endpoint or domain account.
param([Parameter(Mandatory=$true)][string]$FixtureDirectory)
$ErrorActionPreference='Stop';Set-StrictMode -Version 2
if($env:RUNNER_ENVIRONMENT -ne 'github-hosted'){throw 'Hosted fixture only'}
Import-Module (Join-Path $PSHOME 'Modules\Microsoft.PowerShell.Security\Microsoft.PowerShell.Security.psd1') -ErrorAction Stop
function LoadFunctions([string]$Path){
 $t=$null;$e=$null;$a=[Management.Automation.Language.Parser]::ParseFile($Path,[ref]$t,[ref]$e)
 if($e.Count){throw ($e.Message -join '; ')}
 return (@($a.EndBlock.Statements|Where-Object{$_ -is [Management.Automation.Language.FunctionDefinitionAst]}|ForEach-Object{$_.Extent.Text}) -join "`n")
}
$old=Join-Path $PSScriptRoot '..\windows\connector\New-AuthWireDeploymentCandidate.ps1'
$helper=Join-Path $PSScriptRoot '..\windows\connector\Test-AuthWireDeploymentCandidate.ps1'
$probe=Join-Path $PSScriptRoot '..\windows\connector\Test-AuthWireCandidateService.ps1'
. ([scriptblock]::Create((LoadFunctions $old)))
. $probe
$checks=0
function Check([bool]$Value,[string]$Name){if(-not $Value){throw $Name};$script:checks++}
function Reject([scriptblock]$Action,[string]$Name){$caught=$false;try{& $Action}catch{$caught=$true};Check $caught $Name}
function TreeState([string]$Root){
 return (@((Get-Item -LiteralPath $Root);(Get-ChildItem -LiteralPath $Root -Recurse -Force))|ForEach-Object{[pscustomobject]@{Path=$_.FullName;Acl=(Get-Acl -LiteralPath $_.FullName).Sddl;Hash=$(if(-not $_.PSIsContainer){(Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash}else{''})}}|ConvertTo-Json -Compress)
}
$signer=$null;$pub=$null;$roots=$null;$trusted=$null;$parent=$null
try{
 $signer=New-SelfSignedCertificate -Type CodeSigningCert -Subject 'CN=AuthWire readonly service fixture' -CertStoreLocation 'Cert:\LocalMachine\My' -Provider 'Microsoft Software Key Storage Provider' -KeyLength 3072 -HashAlgorithm SHA256 -KeyUsage DigitalSignature -KeyUsageProperty Sign -KeyExportPolicy NonExportable -NotAfter (Get-Date).AddDays(1)
 $pub=[Security.Cryptography.X509Certificates.X509Certificate2]::new($signer.RawData)
 $roots=[Security.Cryptography.X509Certificates.X509Store]::new('Root','LocalMachine');$roots.Open('ReadWrite');$roots.Add($pub)
 $trusted=[Security.Cryptography.X509Certificates.X509Store]::new('TrustedPublisher','LocalMachine');$trusted.Open('ReadWrite');$trusted.Add($pub)
 $k=[Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($signer)
 try{$kp=Join-Path (Join-Path $env:ProgramData 'Microsoft\Crypto\Keys') $k.Key.UniqueName;$keyAcl=(Get-Acl -LiteralPath $kp).Sddl}finally{$k.Dispose()}
 $name='AuthWireLogonProbe-'+[guid]::NewGuid().ToString('N')
 $h=[Security.Cryptography.SHA1]::Create()
 try{$digest=$h.ComputeHash([Text.Encoding]::Unicode.GetBytes($name.ToUpperInvariant()))}finally{$h.Dispose()}
 $sid='S-1-5-80-'+((0..4|ForEach-Object{[BitConverter]::ToUInt32($digest,$_ * 4)}) -join '-')
 $a=Get-Content -LiteralPath (Join-Path $FixtureDirectory 'approval.json') -Raw|ConvertFrom-Json
 $a.service_sid=$sid;$a.publisher_thumbprint=$signer.Thumbprint
 $parent=Join-Path $env:ProgramData ('AuthWire-DeploymentCandidates-'+([guid]$a.connector_id).ToString('N'))
 $target=Join-Path $parent (([guid]$a.plan_id).ToString('N')+'-v'+$a.plan_version+'-'+$a.preview_hash)
 Check (-not (Test-Path -LiteralPath $parent)) 'Isolated candidate root absent'
 $null=New-Item -ItemType Directory -Path $parent;Set-AuthWireCandidateAcl $parent $sid -Directory
 $null=New-Item -ItemType Directory -Path $target;Set-AuthWireCandidateAcl $target $sid -Directory
 $approval=Join-Path $target 'approval.json';[IO.File]::WriteAllText($approval,($a|ConvertTo-Json -Depth 6),[Text.UTF8Encoding]::new($false));Set-AuthWireCandidateAcl $approval $sid
 $approvalHash=(Get-FileHash -LiteralPath $approval -Algorithm SHA256).Hash.ToLowerInvariant()
 $zip=Join-Path $target 'network-profiles.zip';Copy-Item -LiteralPath (Join-Path $FixtureDirectory 'good.zip') -Destination $zip;Set-AuthWireCandidateAcl $zip $sid
 $manifest=Join-Path $target 'AuthWire-Candidate-Manifest.ps1';[IO.File]::WriteAllText($manifest,(Get-AuthWireCandidateManifestText $a $approvalHash),[Text.UTF8Encoding]::new($false))
 $s=Set-AuthenticodeSignature -LiteralPath $manifest -Certificate $signer -HashAlgorithm SHA256;Check ($s.Status.ToString() -ceq 'Valid') 'Candidate data manifest has real Authenticode signature'
 Set-AuthWireCandidateAcl $manifest $sid
 foreach($p in @($helper,$probe)){$s=Set-AuthenticodeSignature -LiteralPath $p -Certificate $signer -HashAlgorithm SHA256;Check ($s.Status.ToString() -ceq 'Valid') 'Reviewed service code is signed'}
 $pins=@{ConnectorId=$a.connector_id;PlanId=$a.plan_id;PlanVersion=$a.plan_version;PreviewHash=$a.preview_hash;GpoId=$a.gpo_id;ProtectedGpoId=$a.protected_gpo_id;ServiceSid=$sid;PublisherThumbprint=$signer.Thumbprint;ApprovalSha256=$approvalHash;ManifestSha256=(Get-FileHash -LiteralPath $manifest -Algorithm SHA256).Hash.ToLowerInvariant()}
 # An administrator cannot masquerade as a successful non-admin runtime verifier.
 Reject {& $helper @pins} 'Administrator invocation is rejected as a runtime service result'
 $before=TreeState $parent
 $r=Invoke-AuthWireServiceProbeCore -RuntimeAccount ('NT SERVICE\'+$name) -ExpectedSid $sid -PublisherThumbprint $signer.Thumbprint -Pins $pins -ServiceName $name
 Write-Host ($r|ConvertTo-Json -Depth 6)
 Check ($r.ProbeVerified -and $r.CandidateVerified -and $r.ServiceLogonVerified -and $r.RuntimeSid -ceq $sid) 'Actual non-admin SCM token verifies the candidate'
 Check ($r.TemporaryServiceRemoved -and $r.TemporaryBinaryRemoved -and $r.TemporaryVerifierRemoved -and $r.TemporaryResultDirectoryRemoved -and $r.CleanupErrors.Count -eq 0) 'All temporary runtime artifacts removed'
 Check (-not $r.CanApplyGpo -and -not $r.ArtifactExecuted -and -not $r.PrivateKeyOpenedByVerifier -and -not $r.GpoStateChecked -and -not $r.DirectoryFreshnessChecked) 'No signing, execution or AD/GPO freshness claim'
 Check ((TreeState $parent) -ceq $before -and (Get-Acl -LiteralPath $kp).Sddl -ceq $keyAcl) 'Candidate bytes/ACL and signing-key ACL unchanged'
 $bad=$pins.Clone();$bad.Command='whoami'
 Reject {Invoke-AuthWireServiceProbeCore -RuntimeAccount ('NT SERVICE\'+$name) -ExpectedSid $sid -PublisherThumbprint $signer.Thumbprint -Pins $bad -ServiceName $name} 'No command field accepted'
 $bad=$pins.Clone();$bad.ServiceSid='S-1-5-18'
 Reject {Invoke-AuthWireServiceProbeCore -RuntimeAccount ('NT SERVICE\'+$name) -ExpectedSid $sid -PublisherThumbprint $signer.Thumbprint -Pins $bad -ServiceName $name} 'Cross-account pin rejected before SCM creation'
 # Reusing the same random service name is allowed only after exact cleanup.
 $bad=$pins.Clone();$bad.ManifestSha256='0'*64
 $r=Invoke-AuthWireServiceProbeCore -RuntimeAccount ('NT SERVICE\'+$name) -ExpectedSid $sid -PublisherThumbprint $signer.Thumbprint -Pins $bad -ServiceName $name
 Check ($r.ServiceLogonVerified -and -not $r.ProbeVerified -and -not $r.CandidateVerified -and $r.TemporaryServiceRemoved) 'Wrong manifest pin cannot pass under a valid service token'
 $bytes=[IO.File]::ReadAllBytes($zip);[IO.File]::WriteAllBytes($zip,[byte[]]@(1,2,3))
 $r=Invoke-AuthWireServiceProbeCore -RuntimeAccount ('NT SERVICE\'+$name) -ExpectedSid $sid -PublisherThumbprint $signer.Thumbprint -Pins $pins -ServiceName $name
 Check (-not $r.ProbeVerified -and -not $r.CandidateVerified -and $r.TemporaryServiceRemoved) 'Damaged ZIP rejected by actual non-admin runtime'
 [IO.File]::WriteAllBytes($zip,$bytes)
 $extra=Join-Path $target 'unexpected.ps1';[IO.File]::WriteAllText($extra,'never execute')
 $r=Invoke-AuthWireServiceProbeCore -RuntimeAccount ('NT SERVICE\'+$name) -ExpectedSid $sid -PublisherThumbprint $signer.Thumbprint -Pins $pins -ServiceName $name
 Check (-not $r.ProbeVerified -and -not $r.CandidateVerified -and $r.TemporaryServiceRemoved) 'Unexpected candidate content fails closed'
 Remove-Item -LiteralPath $extra -Force
 Check ((TreeState $parent) -ceq $before -and (Get-Acl -LiteralPath $kp).Sddl -ceq $keyAcl) 'Negative probes preserve candidate and private-key ACL'
 # The delivered DC01 wrapper is parsed and its exact embedded helper bytes
 # are exercised here. Its DC01-only main is never run on the hosted runner.
 $delivery=Join-Path $PSScriptRoot '..\docs\checkpoints\2026-10-27-dc01-candidate-readonly-service.ps1'
 $dt=[IO.File]::ReadAllText($delivery);$tt=$null;$ee=$null
 $da=[Management.Automation.Language.Parser]::ParseFile($delivery,[ref]$tt,[ref]$ee)
 Check ($ee.Count -eq 0) 'Exact DC01 delivery parses in native Windows PowerShell 5.1'
 . ([scriptblock]::Create((LoadFunctions $delivery)))
 $reviewedSources=@{}
 $map=[regex]::Match($dt,'(?s)\$reviewedSources=@\{(.*?)\r?\n\}').Groups[1].Value
 foreach($m in [regex]::Matches($map,"'([^']+)'='([a-f0-9]{64})'")){$reviewedSources[$m.Groups[1].Value]=$m.Groups[2].Value}
 $encoded=[regex]::Match($dt,"\`$embeddedSources='([^']+)'").Groups[1].Value
 $archiveHash=[regex]::Match($dt,"\`$archiveSha256='([a-f0-9]{64})'").Groups[1].Value
 $sources=Read-AuthWireReviewedSourceBytes ([Convert]::FromBase64String($encoded)) $archiveHash
 Check ($sources.Count -eq 2 -and $reviewedSources.Count -eq 2) 'Delivery contains exactly the two reviewed helpers'
 foreach($n in $sources.Keys){Check ((Get-AuthWireDeliveryBodyHash ([IO.File]::ReadAllText((Join-Path (Split-Path -Parent $helper) $n)))) -ceq $reviewedSources[$n]) 'Embedded delivery bytes match the production helper bodies'}
 Reject {Read-AuthWireReviewedSourceBytes ([Convert]::FromBase64String($encoded)) ('0'*64)} 'Changed delivery archive rejected'
 $signedDelivery=Join-Path $FixtureDirectory 'source-delivery'
 New-AuthWireSignedDelivery $sources $signedDelivery $signer
 Assert-AuthWireSignedDelivery $signedDelivery $signer.Thumbprint
 Check $true 'Exact two-helper source delivery signs and checks actual bytes and ACL'
 Reject {Assert-AuthWireCandidateDeliveryHost} 'Customer delivery refuses fixture host before AD lookup or source changes'
 $same=@{ServicePid=1;ServiceAccount='fixed';KeyAcl='fixed';Files=@{item=@{hash='a';sddl='b'}}}
 Check (Test-AuthWireCandidateSnapshotSame $same $same) 'Preservation comparison accepts unchanged context'
 $different=@{ServicePid=2;ServiceAccount='fixed';KeyAcl='fixed';Files=$same.Files}
 Check (-not (Test-AuthWireCandidateSnapshotSame $same $different)) 'Preservation comparison rejects a permanent service restart'
 [pscustomobject]@{Event='WINDOWS_CANDIDATE_READONLY_NATIVE_FIXTURE';Checks=$checks;RealNonAdminScm=$true;CandidateExecuted=$false;CustomerAdTested=$false;GmsaTested=$false}|ConvertTo-Json
}finally{
 if($parent -and (Test-Path -LiteralPath $parent)){Remove-Item -LiteralPath $parent -Recurse -Force}
 if($trusted){if($pub){$trusted.Remove($pub)};$trusted.Dispose()};if($roots){if($pub){$roots.Remove($pub)};$roots.Dispose()}
 if($signer){Remove-Item -LiteralPath ('Cert:\LocalMachine\My\'+$signer.Thumbprint) -DeleteKey -Force -ErrorAction SilentlyContinue;$signer.Dispose()};if($pub){$pub.Dispose()}
}
