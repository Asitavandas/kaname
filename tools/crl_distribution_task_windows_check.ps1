# Real signed SYSTEM task; disposable hosted runner only, never customer hosts.
$ErrorActionPreference='Stop'
if($env:RUNNER_ENVIRONMENT -ne 'github-hosted') { throw 'Hosted fixture only.' }
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot '..\kaname\device_client\Install-AuthWire.ps1'),[ref]$tokens,[ref]$errors)
if($errors.Count) { throw 'Installer parse failed.' }
$fn=$ast.Find({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Set-AuthWireCrlTask'},$true)
if(!$fn) { throw 'Production CRL scheduler missing.' }; . ([scriptblock]::Create($fn.Extent.Text))
$id=[guid]::NewGuid().ToString('N');$dir=Join-Path $env:RUNNER_TEMP ('authwire-crl-task-'+$id)
$name='AuthWire-CI-CRL-'+$id;$signer=$null
try {
 $null=New-Item -ItemType Directory -Path $dir
 $acl=New-Object Security.AccessControl.DirectorySecurity
 $acl.SetSecurityDescriptorSddlForm('O:BAG:BAD:P(A;OICI;FA;;;SY)(A;OICI;FA;;;BA)');Set-Acl $dir $acl
 $signer=New-SelfSignedCertificate -Type CodeSigningCert -Subject ('CN=AuthWire CRL Task '+$id) -CertStoreLocation Cert:\CurrentUser\My
 foreach($storeName in @('Root','TrustedPublisher')) {
  $store=New-Object Security.Cryptography.X509Certificates.X509Store($storeName,'LocalMachine')
  try {$store.Open('ReadWrite');$store.Add((New-Object Security.Cryptography.X509Certificates.X509Certificate2(,$signer.RawData)))} finally {$store.Close()}
 }
 $stub=@'
param([switch]$RefreshCrl)
$ErrorActionPreference='Stop'
if(!$RefreshCrl -or [Security.Principal.WindowsIdentity]::GetCurrent().User.Value -ne 'S-1-5-18') { throw 'Exact CRL SYSTEM mode required.' }
[IO.File]::WriteAllText((Join-Path $PSScriptRoot 'ran.txt'),[DateTimeOffset]::UtcNow.ToString('o'))
'@
 $file=Join-Path $dir 'Install-AuthWire.ps1';[IO.File]::WriteAllText($file,$stub,(New-Object Text.UTF8Encoding($true)))
 if((Set-AuthenticodeSignature $file $signer -HashAlgorithm SHA256).Status -ne 'Valid') { throw 'Fixture signing failed.' }
 [IO.File]::WriteAllText((Join-Path $dir 'retry.json'),(@{next_attempt=[DateTimeOffset]::UtcNow.AddHours(12).ToString('o')}|ConvertTo-Json))
 $retry=(Get-FileHash (Join-Path $dir 'retry.json')).Hash
 Set-AuthWireCrlTask $dir $name -StartNow
 $limit=(Get-Date).AddSeconds(40)
 do {Start-Sleep -Milliseconds 250;$task=Get-ScheduledTask $name;$info=Get-ScheduledTaskInfo $name} while((!(Test-Path (Join-Path $dir 'ran.txt')) -or $task.State -eq 'Running') -and (Get-Date) -lt $limit)
 if(!(Test-Path (Join-Path $dir 'ran.txt')) -or $info.LastTaskResult -ne 0) { throw 'Signed CRL SYSTEM task did not complete.' }
 if((Get-FileHash (Join-Path $dir 'retry.json')).Hash -cne $retry) { throw 'Enrollment retry changed.' }
 [xml]$xml=Export-ScheduledTask $name
 $schedule=[ordered]@{interval=[string]$xml.Task.Triggers.TimeTrigger.Repetition.Interval;boot=@($task.Triggers|Where-Object {$_.CimClass.CimClassName -eq 'MSFT_TaskBootTrigger'}).Count;multiple=[string]$xml.Task.Settings.MultipleInstancesPolicy;limit=[string]$xml.Task.Settings.ExecutionTimeLimit;catch_up=[string]$xml.Task.Settings.StartWhenAvailable;network=[string]$xml.Task.Settings.RunOnlyIfNetworkAvailable}
 if([Xml.XmlConvert]::ToTimeSpan($schedule.interval) -ne [TimeSpan]::FromHours(2) -or $schedule.boot -ne 1 -or $schedule.multiple -cne 'IgnoreNew' -or [Xml.XmlConvert]::ToTimeSpan($schedule.limit) -ne [TimeSpan]::FromMinutes(3) -or $schedule.catch_up -cne 'true' -or $schedule.network -cne 'true') { $schedule|ConvertTo-Json -Compress|Write-Output;throw 'CRL schedule policy mismatch.' }
 Set-AuthWireCrlTask $dir $name
 $scheduler=New-Object -ComObject Schedule.Service;$scheduler.Connect()
 $sddl=$scheduler.GetFolder('\').GetTask($name).GetSecurityDescriptor(4)
 if($sddl -notmatch 'SY' -or $sddl -notmatch 'BA' -or $sddl -match ';;;(?:BU|WD|AU)\)') { throw 'Task ACL widened.' }
 [pscustomobject]@{event='AUTHWIRE_CRL_SIGNED_SYSTEM_TASK';passed=$true;interval='PT2H';enrollment_backoff_preserved=$true}|ConvertTo-Json -Compress
} finally {
 if(Get-ScheduledTask $name -ErrorAction SilentlyContinue) {Stop-ScheduledTask $name -ErrorAction SilentlyContinue;Unregister-ScheduledTask $name -Confirm:$false}
 if($signer) {foreach($storeName in @('Root','TrustedPublisher')) {Remove-Item ('Cert:\LocalMachine\'+$storeName+'\'+$signer.Thumbprint) -Force -ErrorAction SilentlyContinue};Remove-Item ('Cert:\CurrentUser\My\'+$signer.Thumbprint) -DeleteKey -Force -ErrorAction SilentlyContinue}
 if(Test-Path $dir) {Remove-Item $dir -Recurse -Force}
}
