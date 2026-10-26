# Disposable native fixture: synthetic CA/profile data, no AD/GPO or endpoint imports.
param([Parameter(Mandatory=$true)][string]$FixtureDirectory)
$ErrorActionPreference='Stop'
Set-StrictMode -Version 2
if($env:RUNNER_ENVIRONMENT -ne 'github-hosted'){throw 'Hosted fixture only'}
Import-Module (Join-Path $PSHOME 'Modules\Microsoft.PowerShell.Security\Microsoft.PowerShell.Security.psd1') -ErrorAction Stop
$source=Join-Path $PSScriptRoot '..\windows\connector\New-AuthWireDeploymentCandidate.ps1'
$tokens=$null;$errors=$null;$ast=[Management.Automation.Language.Parser]::ParseFile($source,[ref]$tokens,[ref]$errors)
if($errors.Count){throw ($errors.Message -join '; ')}
$definitions=@($ast.EndBlock.Statements|Where-Object{$_ -is [Management.Automation.Language.FunctionDefinitionAst]})
. ([scriptblock]::Create(($definitions|ForEach-Object{$_.Extent.Text}) -join [Environment]::NewLine))
$script:checks=0
function Check([bool]$Value,[string]$Name){if(-not $Value){throw $Name};$script:checks++}
function Reject([scriptblock]$Action,[string]$Name){$caught=$false;try{& $Action}catch{$caught=$true;Write-Host ('EXPECTED_REJECTION '+$Name+': '+$_.Exception.Message)};Check $caught $Name}
$signer=$null;$public=$null;$roots=$null;$publishers=$null;$parent=$null;$keyBefore=$null
try{
 $signer=New-SelfSignedCertificate -Type CodeSigningCert -Subject 'CN=AuthWire candidate isolated fixture' -CertStoreLocation 'Cert:\LocalMachine\My' -Provider 'Microsoft Software Key Storage Provider' -KeyLength 3072 -HashAlgorithm SHA256 -KeyUsage DigitalSignature -KeyUsageProperty Sign -KeyExportPolicy NonExportable -NotAfter (Get-Date).AddDays(1)
 $public=[Security.Cryptography.X509Certificates.X509Certificate2]::new($signer.RawData)
 $roots=[Security.Cryptography.X509Certificates.X509Store]::new('Root','LocalMachine');$roots.Open('ReadWrite');$roots.Add($public)
 $publishers=[Security.Cryptography.X509Certificates.X509Store]::new('TrustedPublisher','LocalMachine');$publishers.Open('ReadWrite');$publishers.Add($public)
 $key=[Security.Cryptography.X509Certificates.RSACertificateExtensions]::GetRSAPrivateKey($signer)
 try{$keyPath=Join-Path (Join-Path $env:ProgramData 'Microsoft\Crypto\Keys') $key.Key.UniqueName;$keyBefore=(Get-Acl -LiteralPath $keyPath).Sddl}finally{$key.Dispose()}
 $a=Get-Content -LiteralPath (Join-Path $FixtureDirectory 'approval.json') -Raw|ConvertFrom-Json
 $a.publisher_thumbprint=$signer.Thumbprint
 $approvalPath=Join-Path $FixtureDirectory 'live-approval.json';[IO.File]::WriteAllText($approvalPath,($a|ConvertTo-Json -Depth 5),[Text.UTF8Encoding]::new($false))
 $pin=(Get-FileHash -LiteralPath $approvalPath -Algorithm SHA256).Hash.ToLowerInvariant()
 $zipPath=Join-Path $FixtureDirectory 'good.zip';$zipBefore=(Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash
 $receipt=Read-AuthWireCandidateApproval $approvalPath $pin
 Check ($receipt.Value.plan_id -ceq $a.plan_id) 'Typed approval parsed with exact external hash'
 Reject {Read-AuthWireCandidateApproval $approvalPath ('0'*64)} 'Changed approval rejected'
 Reject {ConvertFrom-AuthWireCandidateJson ([Text.Encoding]::UTF8.GetBytes('{"x":1,"x":2}'))} 'Duplicate JSON key rejected'
 Reject {ConvertFrom-AuthWireCandidateJson ([Text.Encoding]::UTF8.GetBytes('{"x":1,"X":2}'))} 'Case-folded JSON key rejected'
 Reject {ConvertFrom-AuthWireCandidateJson ([Text.Encoding]::UTF8.GetBytes('{"x":NaN}'))} 'Non-JSON number rejected'
 Reject {ConvertFrom-AuthWireCandidateJson ([Text.Encoding]::UTF8.GetBytes('{"x":1,}'))} 'Trailing JSON comma rejected'
 $network=Read-AuthWireNetworkCandidate $zipPath $a
 Check ($network.TargetCount -eq 2 -and $network.PlanId -ceq $a.plan_id) 'Real server-generated wired and Wi-Fi XML plus CA signatures accepted'
 foreach($case in @('extra','duplicate','oversized','xml_no_validation','xml_wrong_server','xml_extra','xml_dtd','typed_boolean','duplicate_json','bad_ca','bad_manifest')){
  $changed=$a|ConvertTo-Json|ConvertFrom-Json;$changedPath=Join-Path $FixtureDirectory ($case+'.zip')
  $changed.zip_sha256=(Get-FileHash -LiteralPath $changedPath -Algorithm SHA256).Hash.ToLowerInvariant()
  Reject {Read-AuthWireNetworkCandidate $changedPath $changed} ('Candidate rejects '+$case+' even when outer ZIP hash matches')
 }
 foreach($field in @('plan_id','plan_version','preview_hash','machine_profile_id','machine_profile_version','group_sid','domain','server_name','ssid','root_thumbprint')){
  $changed=$a|ConvertTo-Json|ConvertFrom-Json
  switch($field){
   'plan_version'{$changed.$field++}
   'machine_profile_version'{$changed.$field++}
   'plan_id'{$changed.$field=[guid]::NewGuid().ToString('D')}
   'machine_profile_id'{$changed.$field=[guid]::NewGuid().ToString('D')}
   'group_sid'{$changed.$field='S-1-5-21-111-222-333-1999'}
   'root_thumbprint'{$changed.$field='B'*40}
   'preview_hash'{$changed.$field='2'*64}
   default{$changed.$field='different.fixture.example'}
  }
  Reject {Read-AuthWireNetworkCandidate $zipPath $changed} ('Different approved '+$field+' cannot be signed')
 }
 $parent=Join-Path $env:ProgramData ('AuthWire-DeploymentCandidates-'+([guid]$a.connector_id).ToString('N'))
 Check (-not (Test-Path -LiteralPath $parent)) 'New isolated candidate root absent'
 $sig=Set-AuthenticodeSignature -LiteralPath $source -Certificate $signer -HashAlgorithm SHA256
 Check ($sig.Status.ToString() -ceq 'Valid') 'Production entry signed for fresh AllSigned process'
 $fresh=& "$PSHOME\powershell.exe" -NoProfile -NonInteractive -ExecutionPolicy AllSigned -File $source -Mode Inspect -NetworkProfileZip $zipPath -ApprovalPath $approvalPath -ExpectedApprovalSha256 $pin
 Check ($LASTEXITCODE -eq 0) ('Fresh AllSigned inspection succeeds: '+($fresh -join ' '))
 $result=($fresh -join "`n")|ConvertFrom-Json
 Check ($result.ReadyForPrepare -and -not $result.PrivateKeyOpened -and -not $result.CandidateExists -and -not (Test-Path -LiteralPath $parent)) 'Inspect performs no private-key open or candidate write'
 $result=Invoke-AuthWireDeploymentCandidate Prepare $zipPath $approvalPath $pin
 Check ($result.PreparedNow -and $result.SignatureVerified -and -not $result.CanApplyGpo -and -not $result.ArtifactExecuted) 'Actual non-exportable machine key signs a non-executable candidate manifest'
 Check (-not $result.AdChanged -and -not $result.GpoChanged -and -not $result.EndpointChanged -and -not $result.KeyAclChanged -and -not $result.SecretsExported) 'Preparation result declares its bounded local effects'
 $target=$result.CandidatePath;$manifestPath=Join-Path $target 'AuthWire-Candidate-Manifest.ps1'
 $manifestBytes=[IO.File]::ReadAllBytes($manifestPath);$manifestHash=$result.ManifestSha256
 Check ((Get-AuthenticodeSignature -LiteralPath $manifestPath).Status.ToString() -ceq 'Valid') 'Independent native Authenticode verification passes'
 Check ((Get-ChildItem -LiteralPath $target -Force).Count -eq 3) 'Only ZIP, pinned approval and signed data manifest retained'
 $again=Invoke-AuthWireDeploymentCandidate Prepare $zipPath $approvalPath $pin
 Check (-not $again.PreparedNow -and $again.ManifestSha256 -ceq $manifestHash) 'Repeated Prepare verifies and retains original bytes'
 $verify=Invoke-AuthWireDeploymentCandidate Verify $zipPath $approvalPath $pin
 Check ($verify.SignatureVerified -and -not $verify.PreparedNow) 'Verify does not re-sign or execute candidate'
 $extra=Join-Path $target 'extra.ps1';[IO.File]::WriteAllText($extra,'whoami')
 Reject {Invoke-AuthWireDeploymentCandidate Verify $zipPath $approvalPath $pin} 'Unexpected candidate file rejected'
 Remove-Item -LiteralPath $extra -Force
 $storedZip=Join-Path $target 'network-profiles.zip';$originalZip=[IO.File]::ReadAllBytes($storedZip);[IO.File]::WriteAllBytes($storedZip,[byte[]]@(1,2,3))
 Reject {Invoke-AuthWireDeploymentCandidate Prepare $zipPath $approvalPath $pin} 'Existing damaged candidate is never overwritten'
 [IO.File]::WriteAllBytes($storedZip,$originalZip)
 [IO.File]::WriteAllText($manifestPath,"Write-Output 'never execute'`r`n",[Text.UTF8Encoding]::new($false))
 $null=Set-AuthenticodeSignature -LiteralPath $manifestPath -Certificate $signer -HashAlgorithm SHA256
 Reject {Invoke-AuthWireDeploymentCandidate Verify $zipPath $approvalPath $pin} 'Even validly signed executable content is rejected as candidate manifest'
 [IO.File]::WriteAllBytes($manifestPath,$manifestBytes)
 $acl=Get-Acl -LiteralPath $storedZip;$acl.AddAccessRule([Security.AccessControl.FileSystemAccessRule]::new([Security.Principal.SecurityIdentifier]::new('S-1-1-0'),[Security.AccessControl.FileSystemRights]::Read,[Security.AccessControl.AccessControlType]::Allow));Set-Acl -LiteralPath $storedZip -AclObject $acl
 Reject {Invoke-AuthWireDeploymentCandidate Verify $zipPath $approvalPath $pin} 'Broadened candidate ACL rejected'
 Set-AuthWireCandidateAcl $storedZip $a.service_sid
 $link=Join-Path $FixtureDirectory 'candidate-junction';$null=New-Item -ItemType Junction -Path $link -Target $target
 try{Reject {Read-AuthWireCandidateBytes (Join-Path $link 'network-profiles.zip') 262144} 'Reparse-point input rejected'}finally{[IO.Directory]::Delete($link)}
 Check ((Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash -ceq $zipBefore -and (Get-Acl -LiteralPath $keyPath).Sddl -ceq $keyBefore) 'Input package and machine signing-key ACL preserved'
 $null=Invoke-AuthWireDeploymentCandidate Verify $zipPath $approvalPath $pin
 # Parse the exact customer wrapper but never execute its DC01-only main.
 $deliveryPath=Join-Path $PSScriptRoot '..\docs\checkpoints\2026-10-26-dc01-deployment-candidate.ps1'
 $deliveryText=[IO.File]::ReadAllText($deliveryPath);$tokens=$null;$errors=$null
 $deliveryAst=[Management.Automation.Language.Parser]::ParseFile($deliveryPath,[ref]$tokens,[ref]$errors)
 Check ($errors.Count -eq 0) 'Exact DC01 wrapper parses in native Windows PowerShell 5.1'
 foreach($f in $deliveryAst.FindAll({param($n)$n -is [Management.Automation.Language.FunctionDefinitionAst]},$false)){. ([scriptblock]::Create($f.Extent.Text))}
 $reviewedSources=@{}
 $map=[regex]::Match($deliveryText,'(?s)\$reviewedSources=@\{(.*?)\r?\n\}').Groups[1].Value
 foreach($match in [regex]::Matches($map,"'([^']+)'='([a-f0-9]{64})'")){$reviewedSources[$match.Groups[1].Value]=$match.Groups[2].Value}
 $encoded=[regex]::Match($deliveryText,"\`$embeddedSources='([^']+)'").Groups[1].Value
 $archivePin=[regex]::Match($deliveryText,"\`$archiveSha256='([^']+)'").Groups[1].Value
 $archiveBytes=[Convert]::FromBase64String($encoded)
 $sourceBytes=Read-AuthWireReviewedSourceBytes $archiveBytes $archivePin
 Check ($sourceBytes.Count -eq 1 -and $reviewedSources['New-AuthWireDeploymentCandidate.ps1'] -ceq (Get-AuthWireDeliveryBodyHash ([IO.File]::ReadAllText($source)))) 'Wrapper embeds the exact tested production helper and no other signer payload'
 $approvalAssignment=@($deliveryAst.EndBlock.Statements|Where-Object{$_ -is [Management.Automation.Language.AssignmentStatementAst] -and $_.Left.Extent.Text -ceq '$approvalJson'})
 $approvalLiterals=@($approvalAssignment[0].Right.FindAll({param($n)$n -is [Management.Automation.Language.StringConstantExpressionAst]},$true))
 if($approvalLiterals.Count -ne 1){throw 'Expected exactly one approval string literal'}
 $literal=$approvalLiterals[0].Value
 $approvalPin=[regex]::Match($deliveryText,"\`$approvalSha256='([^']+)'").Groups[1].Value
 Check ((Get-AuthWireDeliveryHash ([Text.UTF8Encoding]::new($false,$true).GetBytes($literal.Replace("`r`n","`n")+"`n"))) -ceq $approvalPin) 'Exact wrapper approval here-string has the intended canonical hash'
 $deliveryApproval=ConvertFrom-AuthWireCandidateJson ([Text.Encoding]::UTF8.GetBytes($literal))
 Check ($deliveryApproval.plan_id -ceq '524653f5-1359-46f5-84a5-46355bb82aff' -and $deliveryApproval.zip_sha256 -ceq '528a793a637e2a8bdd30808acf7a624b83b125419d1ef1c8077249955a146e38' -and $deliveryApproval.gpo_id -ceq '8c6808fd-a382-4bf2-9c9c-d9e1d46082a3' -and $deliveryApproval.gpo_id -cne $deliveryApproval.protected_gpo_id) 'Wrapper binds the accepted operator ZIP and owned GPO, never the protected trust GPO'
 Reject {Read-AuthWireReviewedSourceBytes $archiveBytes ('0'*64)} 'Changed embedded source archive rejected'
 $deliveryFolder=Join-Path $FixtureDirectory 'signed-delivery'
 New-AuthWireSignedDelivery $sourceBytes $deliveryFolder $signer
 Assert-AuthWireSignedDelivery $deliveryFolder $signer.Thumbprint
 Check ((Get-AuthenticodeSignature -LiteralPath (Join-Path $deliveryFolder 'New-AuthWireDeploymentCandidate.ps1')).Status.ToString() -ceq 'Valid') 'Exact wrapper delivery helpers actually sign and verify the tested source'
 Reject {New-AuthWireSignedDelivery $sourceBytes $deliveryFolder $signer} 'Existing reviewed source delivery is never overwritten'
 Reject {Assert-AuthWireSignedDelivery $deliveryFolder ('0'*40)} 'Different source publisher rejected'
 Reject {Assert-AuthWireCandidateDeliveryHost} 'DC01 wrapper refuses hosted machine before AD lookup or preparation'
 Check ((Get-Acl -LiteralPath $keyPath).Sddl -ceq $keyBefore) 'Customer wrapper source signing preserves the fixture machine key ACL'
 $text=[IO.File]::ReadAllText($source)
 Check (-not $text.Contains('Set-GP') -and -not $text.Contains('New-GP') -and -not $text.Contains('Set-AD') -and -not $text.Contains('netsh') -and -not $text.Contains('Export-Pfx') -and -not $text.Contains('Start-Service')) 'No AD/GPO/profile import, service or private-key export capability'
 Write-Output ('AUTHWIRE_DEPLOYMENT_CANDIDATE_NATIVE_OK '+(@{checks=$checks;native_powershell=$PSVersionTable.PSVersion.ToString();actual_machine_cng_signing=$true;actual_authenticode_verification=$true;fresh_allsigned_inspection=$true;fixture_ca_trust_store_modified_only_for_test=$true;customer_ad_used=$false;customer_gmsa_used=$false;gpo_changed=$false;endpoint_profiles_imported=$false;artifact_executed=$false;can_apply_gpo=$false}|ConvertTo-Json -Compress))
}finally{
 if($parent -and (Test-Path -LiteralPath $parent)){Remove-Item -LiteralPath $parent -Recurse -Force}
 if($publishers){if($public){$publishers.Remove($public)};$publishers.Dispose()}
 if($roots){if($public){$roots.Remove($public)};$roots.Dispose()}
 if($signer){Remove-Item -LiteralPath ('Cert:\LocalMachine\My\'+$signer.Thumbprint) -DeleteKey -Force -ErrorAction SilentlyContinue;$signer.Dispose()}
 if($public){$public.Dispose()}
}
