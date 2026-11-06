# Operator-only VV-Client01 wired pilot. Sign with the EXISTING endpoint publisher.
# Only Ethernet0's profile and explicit reauthentication are mutable. No NIC/service restart.
param([switch]$ValidateOnly,[switch]$RestoreOnly,[ValidateRange(1,3)][int]$Cycles=3,[ValidateRange(75,660)][int]$AutoObserveSeconds=75,[switch]$NoRetry,[ValidateRange(5,90)][int]$SettleSeconds=5)
$ErrorActionPreference='Stop'
$testGuid='2db4814e-faa5-4315-bdbd-eae3a90dbe1b'
$publisher='6E74B513F766E01730719684A41B2664380CA68A'
$stage=$PSScriptRoot
if(!$stage -and $ValidateOnly){$stage=[IO.Path]::GetTempPath()}
$good=Join-Path $stage 'known-good.xml';$bad=Join-Path $stage 'wrong-root.xml'
$goodHash='5F05463E7442C34DF5D7D38173B271A3436662A0224808CB06721A4EBA5DBD4D'
$badHash='201E8C3E926C6383713740F26B32D4978A13A5BAA08878C90D19B5B4E191D018'
$managementHash='BC6693C9A013E999D72B5AC73B0174D4E2281CB7D264D5AB224E88B6B952F1BC'
$logName='Microsoft-Windows-Wired-AutoConfig/Operational'
function Read-WiredFields($Event) {
 [xml]$xml=$Event.ToXml();$fields=@{}
 foreach($entry in $xml.Event.EventData.Data){$fields[[string]$entry.Name]=[string]$entry.'#text'}
 return $fields
}
function Select-WiredEvents($InputEvents,[long]$AfterRecord,[datetime]$Since) {
 @($InputEvents|Where-Object {$_.RecordId -gt $AfterRecord -and $_.TimeCreated.ToUniversalTime() -ge $Since.ToUniversalTime()}|Where-Object {
  $f=Read-WiredFields $_
  $value=[guid]::Empty
  [guid]::TryParse([string]$f['InterfaceGuid'],[ref]$value) -and $value.ToString() -eq $testGuid
 }|Sort-Object RecordId)
}
function Test-EventIsolation {
 $at=[datetime]::UtcNow
 $events=@()
 foreach($item in @(@(100,15505,0,$testGuid),@(101,15514,0,$testGuid),@(102,15505,-1,$testGuid),@(103,15505,0,'81f67131-3254-41f0-ab6c-404249dad14d'))){
  $event=[pscustomobject]@{RecordId=[long]$item[0];Id=[int]$item[1];TimeCreated=$at.AddSeconds([int]$item[2]);RawXml=("<Event><EventData><Data Name='InterfaceGuid'>{"+$item[3]+"}</Data></EventData></Event>")}
  $event|Add-Member ScriptMethod ToXml {return $this.RawXml};$events+=,$event
 }
 $selected=@(Select-WiredEvents $events 100 $at)
 if($selected.Count -ne 1 -or $selected[0].RecordId -ne 101 -or $selected[0].Id -ne 15514){throw 'Fresh record/time/interface isolation failed'}
}
function Assert-File([string]$Path,[string]$Hash) {
 $f=Get-Item -LiteralPath $Path -Force
 if($f.PSIsContainer -or ($f.Attributes -band [IO.FileAttributes]::ReparsePoint) -or $f.Length -gt 65536 -or (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash -cne $Hash){throw 'Pinned pilot file changed'}
}
function Assert-TestAdapter {
 if($env:COMPUTERNAME -ine 'VV-CLIENT01' -or ([guid](Get-NetAdapter -Name Ethernet0).InterfaceGuid).ToString() -ne $testGuid){throw 'Exact pilot adapter required'}
}
function Invoke-Lan([string[]]$Arguments) {
 # All callers use literal Ethernet0; no wildcard or caller-supplied interface.
 $out=@(& "$env:SystemRoot\System32\netsh.exe" @Arguments 2>&1)
 if($LASTEXITCODE -ne 0){throw ('Pilot LAN command failed: '+$LASTEXITCODE)}
 return ($out|Out-String)
}
function Restore-StrictProfile {
 Assert-TestAdapter;Assert-File $good $goodHash
 $null=Invoke-Lan @('lan','add','profile',('filename='+$good),'interface=Ethernet0')
}
function Management {
 [ordered]@{Adapter=@(Get-NetAdapter -Name Ethernet1|Select-Object Name,InterfaceGuid,ifIndex,MacAddress);IPv4=@(Get-NetIPAddress -InterfaceAlias Ethernet1 -AddressFamily IPv4|Select-Object IPAddress,PrefixLength,SkipAsSource,PrefixOrigin,SuffixOrigin);IPInterface=@(Get-NetIPInterface -InterfaceAlias Ethernet1 -AddressFamily IPv4|Select-Object Dhcp,AutomaticMetric,InterfaceMetric);DNS=@(Get-DnsClientServerAddress -InterfaceAlias Ethernet1 -AddressFamily IPv4|Select-Object ServerAddresses);DefaultRoute=@(Get-NetRoute -InterfaceAlias Ethernet1 -DestinationPrefix '0.0.0.0/0'|Select-Object NextHop,RouteMetric)}|ConvertTo-Json -Depth 6 -Compress
}
function Service-Pids {
 @(Get-CimInstance Win32_Service -Filter "Name='dot3svc' OR Name='EapHost'"|Sort-Object Name|Select-Object Name,State,ProcessId)|ConvertTo-Json -Compress
}
function Guard {
 Assert-TestAdapter
 if((Management) -cne $baseline -or (Get-NetAdapter -Name Ethernet1).Status -ne 'Up'){throw 'Management baseline changed'}
 if((Service-Pids) -cne $services){throw 'Authentication service process changed'}
}
function Cursor {
 [long](Get-WinEvent -LogName $logName -MaxEvents 1 -ErrorAction Stop).RecordId
}
function Read-Events([long]$AfterRecord,[datetime]$Since) {
 if((Cursor) -lt $AfterRecord){throw 'Event log cursor reset'}
 $all=@(Get-WinEvent -LogName $logName -FilterXPath ('*[System[EventRecordID > '+$AfterRecord+']]') -MaxEvents 300 -ErrorAction SilentlyContinue)
 @(Select-WiredEvents $all $AfterRecord $Since)
}
function Wait-Result([long]$AfterRecord,[datetime]$Since,[int]$Seconds,[bool]$Negative) {
 $watch=[Diagnostics.Stopwatch]::StartNew()
 do {
  Guard
  $matches=@(Read-Events $AfterRecord $Since|Where-Object {if($Negative){$_.Id -in 15505,15514}else{$_.Id -eq 15505}})
  if($matches.Count){return $matches[0]}
  Start-Sleep -Milliseconds 750
 }while($watch.Elapsed.TotalSeconds -lt $Seconds)
 return $null
}
function Event-Facts($Event) {
 if(!$Event){return $null}
 $f=Read-WiredFields $Event
 [ordered]@{id=$Event.Id;record_id=$Event.RecordId;utc=$Event.TimeCreated.ToUniversalTime().ToString('o');connection_id=$f['ConnectionID'];error_code=$f['ErrorCode'];reason_code=$f['ReasonCode']}
}
function Save-Result {
 $tmp=Join-Path $stage 'result.tmp';$target=Join-Path $stage 'result.json'
 [IO.File]::WriteAllText($tmp,($result|ConvertTo-Json -Depth 8),(New-Object Text.UTF8Encoding($false)))
 if(Test-Path -LiteralPath $target){[IO.File]::Replace($tmp,$target,[NullString]::Value)}else{[IO.File]::Move($tmp,$target)}
}
function New-SafetyTask {
 $name='AuthWire-Ethernet0-SafetyRestore-'+[guid]::NewGuid().ToString('N')
 $action=New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -Argument ('-NoProfile -NonInteractive -ExecutionPolicy AllSigned -File "'+$PSCommandPath+'" -RestoreOnly')
 $settings=New-ScheduledTaskSettingsSet -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 1) -MultipleInstances IgnoreNew -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
 $null=Register-ScheduledTask -TaskName $name -Action $action -Trigger (New-ScheduledTaskTrigger -Once -At (Get-Date).AddSeconds([Math]::Max(240,$AutoObserveSeconds+$SettleSeconds+210))) -Principal (New-ScheduledTaskPrincipal -UserId SYSTEM -LogonType ServiceAccount -RunLevel Highest) -Settings $settings -Description 'AuthWire pilot exact Ethernet0 strict-profile safety restore'
 $scheduler=New-Object -ComObject Schedule.Service;$scheduler.Connect();$scheduler.GetFolder('\').GetTask($name).SetSecurityDescriptor('D:P(A;;GA;;;SY)(A;;GA;;;BA)',0)
 return $name
}
Test-EventIsolation
if($ValidateOnly){Write-Output 'AUTHWIRE_FRESH_EVENT_ISOLATION_OK';return}
Assert-TestAdapter
$identity=[Security.Principal.WindowsIdentity]::GetCurrent()
try{if(!([Security.Principal.WindowsPrincipal]::new($identity)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){throw 'Elevated operator required'}}finally{$identity.Dispose()}
$signature=Get-AuthenticodeSignature -LiteralPath $PSCommandPath
if($signature.Status -ne 'Valid' -or $signature.SignerCertificate.Thumbprint -cne $publisher){throw 'Existing trusted publisher signature required'}
Assert-File $good $goodHash
if($RestoreOnly){Restore-StrictProfile;Write-Output 'AUTHWIRE_STRICT_ETHERNET0_RESTORED';return}
Assert-File $bad $badHash
Assert-File (Join-Path $stage 'management-before.json') $managementHash
Assert-File (Join-Path $stage 'initial-profile.xml') $goodHash
$baseline=(Get-Content (Join-Path $stage 'management-before.json') -Raw|ConvertFrom-Json)|ConvertTo-Json -Depth 6 -Compress
$services=Service-Pids
Guard
if((Invoke-Lan @('lan','show','settings')) -notmatch 'disabled on interface "Ethernet1"'){throw 'Management 802.1X isolation missing'}
$leaf=Get-Item 'Cert:\LocalMachine\My\BD498F87BB886AE760B3FAC40AB7BB6D2AC3B987'
if(!$leaf.HasPrivateKey -or $leaf.NotAfter -le (Get-Date)){throw 'Current machine identity unavailable'}
$result=[ordered]@{event='AUTHWIRE_WIRED_RECOVERY_REPEAT';schema=1;started=[DateTime]::UtcNow.ToString('o');cycles_requested=$Cycles;settle_seconds=$SettleSeconds;automatic_observation_seconds=$AutoObserveSeconds;retry_allowed=(!$NoRetry);cycles=@();completed=$false;error=$null;service_restart_used=$false;adapter_restart_used=$false;automatic_returns=0;single_reconnect_returns=0}
$initial=Cursor;$badApplied=$false;$safety=$null
try {
 for($cycle=1;$cycle -le $Cycles;$cycle++){
  Guard
  $entry=[ordered]@{cycle=$cycle;started=[DateTime]::UtcNow.ToString('o');baseline=$null;negative=$null;restored_at=$null;automatic_success=$false;explicit_reconnects=0;return_success=$null;error=$null}
  $result.cycles+=,$entry
  $at=[DateTime]::UtcNow;$cursor=Cursor
  Write-Output ('AUTHWIRE_REPEAT_PHASE '+$cycle+' BASELINE_REAUTH')
  $null=Invoke-Lan @('lan','reconnect','interface=Ethernet0')
  $event=Wait-Result $cursor $at 35 $false
  if(!$event){throw 'Fresh baseline authentication missing'};$entry.baseline=Event-Facts $event
  $safety=New-SafetyTask
  $at=[DateTime]::UtcNow;$cursor=Cursor
  $badApplied=$true
  $null=Invoke-Lan @('lan','add','profile',('filename='+$bad),'interface=Ethernet0')
  $event=Wait-Result $cursor $at 30 $true
  $entry.negative=Event-Facts $event
  if(!$event -or $event.Id -ne 15514 -or (Read-WiredFields $event)['ErrorCode'] -ine '0x30a'){throw 'Expected wrong-root rejection missing'}
  Write-Output ('AUTHWIRE_REPEAT_PHASE '+$cycle+' WRONG_ROOT_REJECTED')
  Start-Sleep -Seconds $SettleSeconds;Guard
  $at=[DateTime]::UtcNow;$cursor=Cursor
  Restore-StrictProfile;$badApplied=$false;$entry.restored_at=$at.ToString('o')
  $event=Wait-Result $cursor $at $AutoObserveSeconds $false
  if($event){$entry.automatic_success=$true;$result.automatic_returns++}
  elseif(!$NoRetry) {
   Guard;$at=[DateTime]::UtcNow;$cursor=Cursor
   Write-Output ('AUTHWIRE_REPEAT_PHASE '+$cycle+(' ONE_REAUTH_AFTER_'+$AutoObserveSeconds+'_SECONDS'))
   $null=Invoke-Lan @('lan','reconnect','interface=Ethernet0');$entry.explicit_reconnects=1
   $event=Wait-Result $cursor $at 35 $false
   if($event){$result.single_reconnect_returns++}
  }
  $entry.return_success=Event-Facts $event
  if(!$event){throw 'Recovery did not authenticate within bounded observation'}
  $entry.finished=[DateTime]::UtcNow.ToString('o')
  Unregister-ScheduledTask -TaskName $safety -Confirm:$false;$safety=$null
  Save-Result
  Write-Output ('AUTHWIRE_REPEAT_CYCLE_ACCEPTED '+($entry|ConvertTo-Json -Depth 4 -Compress))
  Start-Sleep -Seconds 5
 }
 $result.completed=$true
}catch{
 $result.error=$_.Exception.Message
 if($result.cycles.Count){$result.cycles[-1].error=$result.error}
}finally{
 if($badApplied){try{Restore-StrictProfile;$badApplied=$false}catch{$result.restore_error=$_.Exception.Message}}
 if($safety -and !$badApplied){Unregister-ScheduledTask -TaskName $safety -Confirm:$false}
 $result.management_unchanged=((Management) -ceq $baseline)
 $result.services_unchanged=((Service-Pids) -ceq $services)
 $result.machine_identity_present=[bool](Get-Item 'Cert:\LocalMachine\My\BD498F87BB886AE760B3FAC40AB7BB6D2AC3B987' -ErrorAction SilentlyContinue)
 $result.final_lan=Invoke-Lan @('lan','show','interfaces')
 $all=@(Read-Events $initial ([datetime]$result.started))
 $all|ForEach-Object {$_.ToXml()}|Set-Content (Join-Path $stage 'wired-events.xml') -Encoding UTF8
 $result.events=@($all|ForEach-Object {Event-Facts $_})
 $result.finished=[DateTime]::UtcNow.ToString('o');Save-Result
 $result|ConvertTo-Json -Depth 8 -Compress
}
if(!$result.completed -or !$result.management_unchanged -or !$result.services_unchanged){exit 2}
