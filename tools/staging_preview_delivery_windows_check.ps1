# Native WinPS5.1 exact delivery signing and previous full-package compatibility.
# Disposable hosted files/certificates/key only. No service creation or customer AD.
$ErrorActionPreference='Stop';Set-StrictMode -Version 2
if($env:RUNNER_ENVIRONMENT -cne 'github-hosted'){throw 'HOSTED_FIXTURE_ONLY'}
Add-Type -AssemblyName System.IO.Compression
$repo=Split-Path $PSScriptRoot -Parent
$source=Join-Path $repo 'windows\connector'
$newScript=Join-Path $repo 'docs\checkpoints\2026-10-28-dc01-staging-preview-worker-upgrade.ps1'
$oldScript=Join-Path $repo 'docs\checkpoints\2026-10-28-dc01-sysvol-unc-fix.ps1'
$script:checks=0
function Check($v,[string]$name){if(-not $v){throw ('DELIVERY_FIXTURE:'+ $name)};$script:checks++}
function Reject([scriptblock]$action,[string]$name){$failed=$false;try{& $action|Out-Null}catch{$failed=$true};Check $failed $name}
function Read-Literal($node){$v=@($node.FindAll({param($n)$n -is [Management.Automation.Language.StringConstantExpressionAst]},$true));if($v.Count -ne 1){throw 'LITERAL_REQUIRED'};return $v[0].Value}
function Read-DeliveryAst([string]$path){
 $tokens=$null;$errors=$null;$ast=[Management.Automation.Language.Parser]::ParseFile($path,[ref]$tokens,[ref]$errors)
 Check ($errors.Count -eq 0) 'entry point native parser'
 $assignments=@{};foreach($a in $ast.FindAll({param($n)$n -is [Management.Automation.Language.AssignmentStatementAst] -and $n.Left -is [Management.Automation.Language.VariableExpressionAst]},$false)){$assignments[$a.Left.VariablePath.UserPath]=$a.Right}
 $table=$assignments['reviewedSources'].Find({param($n)$n -is [Management.Automation.Language.HashtableAst]},$true)
 $pins=@{};foreach($pair in $table.KeyValuePairs){$pins[$pair.Item1.Value]=Read-Literal $pair.Item2}
 return [pscustomobject]@{Ast=$ast;Pins=$pins;Bytes=[Convert]::FromBase64String((Read-Literal $assignments['embeddedSources']));Hash=(Read-Literal $assignments['archiveSha256'])}
}
$new=Read-DeliveryAst $newScript;$old=Read-DeliveryAst $oldScript
$oldFunctions=@{};foreach($f in $old.Ast.FindAll({param($n)$n -is [Management.Automation.Language.FunctionDefinitionAst]},$false)){$oldFunctions[$f.Name]=$f.Extent.Text}
$newFunctions=@($new.Ast.FindAll({param($n)$n -is [Management.Automation.Language.FunctionDefinitionAst]},$false))
Check ($newFunctions.Count -eq $oldFunctions.Count) 'same reviewed wrapper helper set'
foreach($f in $newFunctions){Check ($oldFunctions.ContainsKey($f.Name) -and $oldFunctions[$f.Name] -ceq $f.Extent.Text) 'signer, archive and ACL helpers preserved';. ([scriptblock]::Create($f.Extent.Text))}
$reviewedSources=$new.Pins
$unpacked=Read-AuthWireReviewedSourceBytes $new.Bytes $new.Hash
Check ($unpacked.Count -eq 28) 'exact twenty-eight-file delivery'
foreach($name in $unpacked.Keys){Check ((Get-AuthWireDeliveryBodyHash ([IO.File]::ReadAllText((Join-Path $source $name)))) -ceq $reviewedSources[$name]) 'every current reviewed source body matches'}
Reject {Read-AuthWireReviewedSourceBytes $new.Bytes ('0'*64)} 'incorrect archive digest refused'
$work=Join-Path $env:TEMP ('aw-preview-delivery-'+[guid]::NewGuid().ToString('N'))
$publisher=$null;$public=$null;$roots=$null;$publishers=$null;$keyName=$null;$keyRoot=$null;$packageRoot=$null;$candidateRoot=$null
try{
 $null=New-Item -ItemType Directory -Path $work
 $publisher=New-SelfSignedCertificate -Type CodeSigningCert -Subject ('CN=AuthWire disposable preview delivery '+[guid]::NewGuid().ToString('N')) -CertStoreLocation 'Cert:\LocalMachine\My' -Provider 'Microsoft Software Key Storage Provider' -KeyLength 3072 -HashAlgorithm SHA256 -KeyUsage DigitalSignature -KeyUsageProperty Sign -KeyExportPolicy NonExportable -NotAfter (Get-Date).AddDays(1)
 $public=[Security.Cryptography.X509Certificates.X509Certificate2]::new($publisher.RawData)
 $roots=[Security.Cryptography.X509Certificates.X509Store]::new('Root','LocalMachine');$roots.Open('ReadWrite');$roots.Add($public)
 $publishers=[Security.Cryptography.X509Certificates.X509Store]::new('TrustedPublisher','LocalMachine');$publishers.Open('ReadWrite');$publishers.Add($public)
 $meta=Get-AuthWireNamedMachineKeyMetadata $publisher
 Check ($meta.NamedKeyOpened -and -not $meta.OpenError) 'native persisted signing metadata readable'
 $before=Get-AuthWireDeliverySignerSnapshot $publisher $meta.Native.KeyName $meta.Native.UniqueName $meta.KeySddl
 $bad=@{};foreach($n in $unpacked.Keys){$bad[$n]=$unpacked[$n]};$name=@($bad.Keys)[0];$bad[$name]=$bad[$name]+[byte[]]@(1)
 $badPath=Join-Path $work 'refused'
 Reject {New-AuthWireSignedDelivery $bad $badPath $publisher} 'unreviewed bytes refused before signing'
 Check (-not (Test-Path -LiteralPath $badPath)) 'rejected source creates no delivery directory'
 $newDirectory=Join-Path $work 'new-source';New-AuthWireSignedDelivery $unpacked $newDirectory $publisher
 Assert-AuthWireSignedDelivery $newDirectory $publisher.Thumbprint
 Check $true 'all new fixed sources sign with protected administrator ACLs'
 Reject {New-AuthWireSignedDelivery $unpacked $newDirectory $publisher} 'existing delivery not overwritten'
 $file=Join-Path $newDirectory 'Read-AuthWireCombinedStagingPreview.ps1';$saved=[IO.File]::ReadAllBytes($file)
 try{[IO.File]::AppendAllText($file,"`r`n# changed");Reject {Assert-AuthWireSignedDelivery $newDirectory $publisher.Thumbprint} 'signed source drift refused'}finally{[IO.File]::WriteAllBytes($file,$saved)}
 $reviewedSources=$old.Pins;$oldBytes=Read-AuthWireReviewedSourceBytes $old.Bytes $old.Hash
 $oldDirectory=Join-Path $work 'old-source';New-AuthWireSignedDelivery $oldBytes $oldDirectory $publisher
 foreach($n in @('Compare-AuthWireSigningKeyAcl.ps1','ConnectorChannelTypes.ps1','ConnectorChannelKey.ps1','New-AuthWireConnectorHealthProof.ps1','ConnectorServicePackage.ps1')){. (Join-Path $oldDirectory $n)}
 $connector=[guid]::NewGuid().ToString('D');$id=([guid]$connector).ToString('N');$sid='S-1-5-21-111-222-333-1648'
 $b=@{instance_id=[guid]::NewGuid().ToString('D');connector_id=$connector;host_guid=[guid]::NewGuid().ToString('D');host_fqdn=([Environment]::MachineName.ToLowerInvariant()+'.lab.example');service_sid=$sid;appliance_fqdn='appliance.lab.example';appliance_tls_sha256=('a'*64)}
 $keyRoot=Join-Path $env:ProgramData ('AuthWire-Connector-'+$id)
 if(Test-Path -LiteralPath $keyRoot){$keyRoot=$null;throw 'FIXTURE_KEY_COLLISION'}
 $prepared=Initialize-AuthWireChannelKeyCore -Mode PrepareKey -Directory $keyRoot -BaseBinding $b
 $keyName=$prepared.KeyName;$b.generation=1;$b.channel_key_sha256=$prepared.KeySha256
 $receipt=Get-Content -LiteralPath $prepared.ReceiptPath -Raw|ConvertFrom-Json
 $packageRoot=Join-Path $env:ProgramW6432 ('AuthWire-Connector-'+$id)
 if(Test-Path -LiteralPath $packageRoot){$packageRoot=$null;throw 'FIXTURE_PACKAGE_COLLISION'}
 $c=@{Version=1;ReleaseId=[guid]::NewGuid().ToString('D');ServiceName=('AuthWireConnector-'+$id);AccountName=([Environment]::MachineName+'\awfixture');PublisherThumbprint=$publisher.Thumbprint;BaseUrl='https://appliance.lab.example:8765/';Binding=$b;KeyName=$keyName;ExpectedKeySddl=$receipt.ExpectedKeySddl;RootPath=$packageRoot}|ConvertTo-Json -Depth 6|ConvertFrom-Json
 $built=New-AuthWireServicePackageCore -Config $c -Publisher $publisher -SourceDirectory $oldDirectory
 Check ($built.PackagePrepared -and -not $built.ServiceCreated -and -not $built.ServiceStarted) 'genuine previous full package built without service'
 . (Join-Path $newDirectory 'ConnectorServicePackage.ps1')
 $previous=Get-AuthWireServicePackage $packageRoot $publisher.Thumbprint -AllowLegacy
 Check ($previous.ReleaseId -ceq $c.ReleaseId -and $previous.KeyName -ceq $keyName) 'current-generation cf742 source set accepted by new legacy map'
 Reject {Get-AuthWireServicePackage $packageRoot $publisher.Thumbprint} 'old full package cannot claim the new preview capability'
 $oldFile=Join-Path $packageRoot 'ConnectorServiceRuntime.ps1';$oldSaved=[IO.File]::ReadAllBytes($oldFile)
 try{[IO.File]::AppendAllText($oldFile,"`r`n# changed");Reject {Get-AuthWireServicePackage $packageRoot $publisher.Thumbprint -AllowLegacy} 'previous package drift refused'}finally{[IO.File]::WriteAllBytes($oldFile,$oldSaved)}
 $next=$c|ConvertTo-Json -Depth 6|ConvertFrom-Json;$next.ReleaseId=[guid]::NewGuid().ToString('D')
 $candidateRoot=$packageRoot+'.candidate-'+([guid]$next.ReleaseId).ToString('N')
 $built=New-AuthWireServicePackageCore -Config $next -Publisher $publisher -SourceDirectory $newDirectory -BuildPath $candidateRoot
 $candidate=Get-AuthWireServicePackage $candidateRoot $publisher.Thumbprint -Staged
 Check ($built.PackagePrepared -and -not $built.ServiceCreated -and -not $built.ServiceStarted -and $candidate.KeyName -ceq $keyName) 'new staged package preserves existing channel key without starting service'
 foreach($n in @('SysvolInventory.ps1','CombinedStagingPreview.ps1','Invoke-AuthWireStagingPreviewJob.ps1','Read-AuthWireCombinedStagingPreview.ps1')){Check (Test-Path -LiteralPath (Join-Path $candidateRoot $n)) 'new fixed preview dependency staged'}
 $after=Get-AuthWireDeliverySignerSnapshot $publisher $meta.Native.KeyName $meta.Native.UniqueName $meta.KeySddl
 Check (($before|ConvertTo-Json -Depth 6 -Compress) -ceq ($after|ConvertTo-Json -Depth 6 -Compress)) 'signer binding, non-export policy, ACL and CLR marker preserved'
 $exe=Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
 $out=@(& $exe -NoLogo -NoProfile -NonInteractive -File $newScript -Mode Inspect)
 $result=($out -join "`n")|ConvertFrom-Json
 Check ($LASTEXITCODE -eq 0 -and $result.Error -ceq 'EXPECTED_ELEVATED_DC01_X64_REQUIRED' -and -not $result.ChangesMayBePartial) 'customer entry point rejects other hosts before mutations'
 Write-Host ('AUTHWIRE_STAGING_DELIVERY_WINDOWS_OK checks='+$script:checks+' source_files=28 previous_full_package_verified=true signer_preserved=true services_created=false customer_ad_tested=false')
}finally{
 foreach($path in @($candidateRoot,$packageRoot,$keyRoot,$work)){if($path -and (Test-Path -LiteralPath $path)){Remove-Item -LiteralPath $path -Recurse -Force}}
 if($keyName -and [Security.Cryptography.CngKey]::Exists($keyName,[Security.Cryptography.CngProvider]::MicrosoftSoftwareKeyStorageProvider,[Security.Cryptography.CngKeyOpenOptions]::MachineKey)){$k=[Security.Cryptography.CngKey]::Open($keyName,[Security.Cryptography.CngProvider]::MicrosoftSoftwareKeyStorageProvider,[Security.Cryptography.CngKeyOpenOptions]::MachineKey);$k.Delete();$k.Dispose()}
 if($publishers){if($public){$publishers.Remove($public)};$publishers.Dispose()}
 if($roots){if($public){$roots.Remove($public)};$roots.Dispose()}
 if($publisher){Remove-Item -LiteralPath ('Cert:\LocalMachine\My\'+$publisher.Thumbprint) -DeleteKey -Force;$publisher.Dispose()};if($public){$public.Dispose()}
}
