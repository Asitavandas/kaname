# Bounded package-only transition. No AD/GPO/trust/key/credential mutation.
Set-StrictMode -Version 2
function Initialize-AuthWireUpgradeNative {
 Initialize-AuthWirePermanentServiceControl
 if('AuthWire.Connector.UpgradeMarkerV1' -as [type]){return}
 Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Text.RegularExpressions;
namespace AuthWire.Connector {
 public static class UpgradeMarkerV1 {
  [StructLayout(LayoutKind.Sequential,CharSet=CharSet.Unicode)]struct Description {public string Text;}
  [DllImport("advapi32.dll",CharSet=CharSet.Unicode,SetLastError=true)]static extern IntPtr OpenSCManagerW(string a,string b,uint access);
  [DllImport("advapi32.dll",CharSet=CharSet.Unicode,SetLastError=true)]static extern IntPtr OpenServiceW(IntPtr manager,string name,uint access);
  [DllImport("advapi32.dll",SetLastError=true)]static extern bool QueryServiceConfig2W(IntPtr service,uint level,IntPtr data,uint size,out uint needed);
  [DllImport("advapi32.dll",SetLastError=true)]static extern bool ChangeServiceConfig2W(IntPtr service,uint level,IntPtr data);
  [DllImport("advapi32.dll")]static extern bool CloseServiceHandle(IntPtr h);
  public static void Replace(string name,string before,string after){
   if(!Regex.IsMatch(name??"",@"\AAuthWireConnector-[0-9a-f]{32}\z")||before==after||before.Length>512||after.Length>512)throw new ArgumentException("Owned marker transition required");
   IntPtr scm=IntPtr.Zero,h=IntPtr.Zero,p=IntPtr.Zero,q=IntPtr.Zero;
   try{
    scm=OpenSCManagerW(null,null,1);if(scm==IntPtr.Zero)throw new Win32Exception(Marshal.GetLastWin32Error());
    h=OpenServiceW(scm,name,3);if(h==IntPtr.Zero)throw new Win32Exception(Marshal.GetLastWin32Error());
    uint size;QueryServiceConfig2W(h,1,IntPtr.Zero,0,out size);if(size< IntPtr.Size||size>4096)throw new InvalidOperationException("Marker bounds");
    p=Marshal.AllocHGlobal((int)size);if(!QueryServiceConfig2W(h,1,p,size,out size))throw new Win32Exception(Marshal.GetLastWin32Error());
    string actual=((Description)Marshal.PtrToStructure(p,typeof(Description))).Text;
    if(!String.Equals(actual,before,StringComparison.Ordinal))throw new InvalidOperationException("Marker changed");
    q=Marshal.AllocHGlobal(Marshal.SizeOf(typeof(Description)));Marshal.StructureToPtr(new Description{Text=after},q,false);
    if(!ChangeServiceConfig2W(h,1,q))throw new Win32Exception(Marshal.GetLastWin32Error());
   }finally{if(q!=IntPtr.Zero){Marshal.DestroyStructure(q,typeof(Description));Marshal.FreeHGlobal(q);}if(p!=IntPtr.Zero)Marshal.FreeHGlobal(p);if(h!=IntPtr.Zero)CloseServiceHandle(h);if(scm!=IntPtr.Zero)CloseServiceHandle(scm);}
  }
 }
}
'@
}
function Get-AuthWireUpgradeTreeHash {
 param([string]$Root)
 Assert-AuthWireChannelPath $Root
 $rows=@()
 foreach($p in @((Get-Item -LiteralPath $Root -Force))+@(Get-ChildItem -LiteralPath $Root -Recurse -Force)){
  Assert-AuthWireChannelPath $p.FullName
  $relative=$p.FullName.Substring($Root.Length).TrimStart('\')
  if($relative -ceq 'state' -or $relative.StartsWith('state\',[StringComparison]::Ordinal)){continue}
  $acl=Get-Acl -LiteralPath $p.FullName
  $hash=if($p.PSIsContainer){'directory'}else{(Get-FileHash -LiteralPath $p.FullName -Algorithm SHA256).Hash}
  $rows+=($relative+'|'+$hash+'|'+$acl.Sddl)
 }
 $sha=[Security.Cryptography.SHA256]::Create()
 try{return ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes((@($rows|Sort-Object -CaseSensitive) -join "`n"))))).Replace('-','')}
 finally{$sha.Dispose()}
}
function Assert-AuthWireUpgradePrivate {
 param([string]$Path,[switch]$Directory)
 Assert-AuthWireChannelPath $Path
 $flags=if($Directory){'OICI'}else{''}
 $expected='O:BAG:BAD:P(A;'+$flags+';FA;;;SY)(A;'+$flags+';FA;;;BA)'
 if(-not (Compare-AuthWireSigningKeyAcl $expected (Get-Acl -LiteralPath $Path).Sddl).AclEquivalent){throw 'CONNECTOR_UPGRADE_PRIVATE_PATH_REQUIRED'}
}
function Write-AuthWireUpgradeJournal {
 param([string]$Path,[hashtable]$Record,[string]$Phase)
 $Record.Phase=$Phase
 Write-AuthWireChannelReceipt -Path $Path -Value $Record
 $acl=[Security.AccessControl.FileSecurity]::new();$acl.SetSecurityDescriptorSddlForm('O:BAG:BAD:P(A;;FA;;;SY)(A;;FA;;;BA)')
 Set-Acl -LiteralPath $Path -AclObject $acl
 Assert-AuthWireUpgradePrivate $Path
}
function Get-AuthWireUpgradeService {
 param($Config,[switch]$AllowOtherMarker,[string]$OtherMarker)
 $s=Get-CimInstance Win32_Service -Filter ("Name='"+$Config.ServiceName+"'")
 if(-not $s){throw 'CONNECTOR_SERVICE_NOT_INSTALLED'}
 $account=[string]$s.StartName;if($account.StartsWith('.\')){$account=[Environment]::MachineName+$account.Substring(1)}
 $resolved=[Security.Principal.NTAccount]::new($account).Translate([Security.Principal.SecurityIdentifier]).Value
 if($resolved -cne $Config.Binding.service_sid){throw 'CONNECTOR_UPGRADE_ACCOUNT_SID_CHANGED'}
 $marker=Get-AuthWireServiceMarker $Config
 $reg=Get-ItemProperty -LiteralPath ('HKLM:\SYSTEM\CurrentControlSet\Services\'+$Config.ServiceName)
 if($s.PathName -cne ('"'+(Join-Path $Config.RootPath 'AuthWireConnector.exe')+'"') -or $account -ine $Config.AccountName -or
  ($s.Description -cne $marker -and (-not $AllowOtherMarker -or $s.Description -cne $OtherMarker)) -or
  $s.StartMode -cne 'Auto' -or -not $reg.PSObject.Properties['DelayedAutoStart'] -or $reg.DelayedAutoStart -ne 1 -or
  -not [AuthWire.Connector.PermanentServiceV1]::RecoveryMatches($Config.ServiceName)){throw 'CONNECTOR_UPGRADE_SERVICE_MISMATCH'}
 return $s
}
function Stop-AuthWireUpgradeService {
 param([string]$Name)
 $s=[System.ServiceProcess.ServiceController]::new($Name)
 try{if($s.Status -ne [System.ServiceProcess.ServiceControllerStatus]::Stopped){$s.Stop();$s.WaitForStatus([System.ServiceProcess.ServiceControllerStatus]::Stopped,[TimeSpan]::FromSeconds(35))}}finally{$s.Dispose()}
}
function Start-AuthWireUpgradeService {
 param([string]$Name)
 $s=[System.ServiceProcess.ServiceController]::new($Name)
 try{$s.Start();$s.WaitForStatus([System.ServiceProcess.ServiceControllerStatus]::Running,[TimeSpan]::FromSeconds(35))}finally{$s.Dispose()}
}
function Wait-AuthWireUpgradeHealth {
 param($Config,[DateTimeOffset]$Since,[switch]$RequireProbe,[switch]$RequireCandidate,[switch]$RequireScope,[switch]$RequireCombined)
 $end=[DateTimeOffset]::UtcNow.AddSeconds(50)
 do{
  try{
   $s=Get-AuthWireUpgradeService $Config
   $p=Join-Path $Config.RootPath 'state\status.json'
   if($s.State -ceq 'Running' -and (Test-Path -LiteralPath $p) -and (Get-Item -LiteralPath $p).Length -le 16384){
    $v=Get-Content -LiteralPath $p -Raw|ConvertFrom-Json
    $pidValue=[int]$v.WorkerPid;$worker=Get-CimInstance Win32_Process -Filter ('ProcessId='+$pidValue)
    if($v.ReleaseId -ceq $Config.ReleaseId -and $v.ServiceName -ceq $Config.ServiceName -and $v.RuntimeSid -ceq $Config.Binding.service_sid -and
     $v.Healthy -ceq $true -and $v.CanApply -ceq $false -and $v.DirectorySyncReady -ceq $false -and $v.KerberosReady -ceq $false -and
     [DateTimeOffset]::Parse($v.CheckedUtc) -ge $Since -and [DateTimeOffset]::Parse($v.LastSuccessUtc) -ge $Since -and $worker -and
     (Invoke-CimMethod -InputObject $worker -MethodName GetOwnerSid).Sid -ceq $Config.Binding.service_sid -and
     (-not $RequireProbe -or ($v.PSObject.Properties['ProbeChannelVerified'] -and $v.ProbeChannelVerified -ceq $true)) -and
     (-not $RequireCandidate -or ($v.PSObject.Properties['CandidateChannelVerified'] -and $v.CandidateChannelVerified -is [bool] -and $v.CandidateChannelVerified)) -and
     (-not $RequireScope -or ($v.PSObject.Properties['ScopeChannelVerified'] -and $v.ScopeChannelVerified -is [bool] -and $v.ScopeChannelVerified)) -and
     (-not $RequireCombined -or ($v.PSObject.Properties['CombinedChannelVerified'] -and $v.CombinedChannelVerified -is [bool] -and $v.CombinedChannelVerified))){return}
   }
  }catch{}
  Start-Sleep -Milliseconds 500
 }while([DateTimeOffset]::UtcNow -lt $end)
 throw 'CONNECTOR_UPGRADE_FRESH_HEALTH_FAILED'
}
function Copy-AuthWireUpgradeAdmin {
 param([string]$Destination,[string]$Source,[string]$Publisher)
 $security=[Security.AccessControl.DirectorySecurity]::new();$security.SetSecurityDescriptorSddlForm('O:BAG:BAD:P(A;OICI;FA;;;SY)(A;OICI;FA;;;BA)')
 $null=[IO.Directory]::CreateDirectory($Destination,$security)
 foreach($file in @('Install-AuthWireConnectorService.ps1','ConnectorServicePackage.ps1','ConnectorServiceControl.ps1','Initialize-AuthWireConnectorChannelKey.ps1','ConnectorChannelKey.ps1','ConnectorChannelTypes.ps1','Compare-AuthWireSigningKeyAcl.ps1','New-AuthWireConnectorHealthProof.ps1')){
  $p=Join-Path $Source $file;$sig=Get-AuthenticodeSignature -FilePath $p
  if($sig.Status.ToString() -cne 'Valid' -or $sig.SignerCertificate.Thumbprint -cne $Publisher){throw 'CONNECTOR_UPGRADE_SOURCE_SIGNATURE_REJECTED'}
  $target=Join-Path $Destination $file;Copy-Item -LiteralPath $p -Destination $target
  $acl=[Security.AccessControl.FileSecurity]::new();$acl.SetSecurityDescriptorSddlForm('O:BAG:BAD:P(A;;FA;;;SY)(A;;FA;;;BA)');Set-Acl -LiteralPath $target -AclObject $acl
 }
}
function Restore-AuthWireUpgrade {
 param([hashtable]$Record,[string]$Journal,[string]$Publisher)
 $old=$Record.OldConfig;$new=$Record.NewConfig;$root=$old.RootPath;$stage=$root+'.candidate-'+([guid]$new.ReleaseId).ToString('N');$archive=$root+'.previous-'+([guid]$old.ReleaseId).ToString('N')
 $null=Get-AuthWireUpgradeService $old -AllowOtherMarker -OtherMarker (Get-AuthWireServiceMarker $new)
 Assert-AuthWireServiceChannelKey $old
 if(Test-Path -LiteralPath $archive){
  $a=Get-AuthWireServicePackage $archive $Publisher -Staged -AllowLegacy
  if($a.ReleaseId -cne $old.ReleaseId -or (Get-AuthWireUpgradeTreeHash $archive) -cne $Record.OldTree){throw 'CONNECTOR_UPGRADE_ROLLBACK_ARCHIVE_CHANGED'}
  if(Test-Path -LiteralPath $root){
   $active=Get-AuthWireServicePackage $root $Publisher
   if($active.ReleaseId -cne $new.ReleaseId -or (Get-AuthWireUpgradeTreeHash $root) -cne $Record.NewTree -or (Test-Path -LiteralPath $stage)){throw 'CONNECTOR_UPGRADE_ROLLBACK_CURRENT_CHANGED'}
  }
 }else{
  $a=Get-AuthWireServicePackage $root $Publisher -AllowLegacy
  if($a.ReleaseId -cne $old.ReleaseId -or (Get-AuthWireUpgradeTreeHash $root) -cne $Record.OldTree){throw 'CONNECTOR_UPGRADE_ROLLBACK_SOURCE_CHANGED'}
 }
 Write-AuthWireUpgradeJournal $Journal $Record 'rolling_back'
 Stop-AuthWireUpgradeService $old.ServiceName
 if(Test-Path -LiteralPath $archive){
  if(Test-Path -LiteralPath $root){[IO.Directory]::Move($root,$stage)}
  [IO.Directory]::Move($archive,$root)
 }
 $s=Get-AuthWireUpgradeService $old -AllowOtherMarker -OtherMarker (Get-AuthWireServiceMarker $new)
 if($s.Description -cne (Get-AuthWireServiceMarker $old)){[AuthWire.Connector.UpgradeMarkerV1]::Replace($old.ServiceName,(Get-AuthWireServiceMarker $new),(Get-AuthWireServiceMarker $old))}
 $since=[DateTimeOffset]::UtcNow;Start-AuthWireUpgradeService $old.ServiceName
 Wait-AuthWireUpgradeHealth $old $since
 Write-AuthWireUpgradeJournal $Journal $Record 'rolled_back'
}
function Invoke-AuthWireServiceUpgradeCore {
 param([ValidateSet('Inspect','Prepare','Apply','Rollback')][string]$Mode='Inspect',[guid]$ConnectorId,[guid]$ExpectedCurrentRelease,[guid]$NewReleaseId,[string]$PublisherThumbprint,[string]$SourceDirectory=$PSScriptRoot)
 Assert-AuthWireServiceAdmin;Initialize-AuthWireUpgradeNative
 if($ConnectorId -eq [guid]::Empty -or $ExpectedCurrentRelease -eq [guid]::Empty -or $NewReleaseId -eq [guid]::Empty -or $ExpectedCurrentRelease -eq $NewReleaseId){throw 'CONNECTOR_UPGRADE_RELEASE_REJECTED'}
 $root=Join-Path $env:ProgramW6432 ('AuthWire-Connector-'+$ConnectorId.ToString('N'))
 $stage=$root+'.candidate-'+$NewReleaseId.ToString('N');$archive=$root+'.previous-'+$ExpectedCurrentRelease.ToString('N')
 $private=Join-Path $env:ProgramData ('AuthWire-ConnectorUpgrade-'+$ConnectorId.ToString('N')+'-'+$NewReleaseId.ToString('N'));$journal=Join-Path $private 'upgrade.json'
 $mutexAcl=[Security.AccessControl.MutexSecurity]::new();$mutexAcl.SetSecurityDescriptorSddlForm('D:P(A;;GA;;;SY)(A;;GA;;;BA)')
 $created=$false;$mutex=[Threading.Mutex]::new($false,('Global\AuthWireConnectorUpgrade-'+$ConnectorId.ToString('N')),[ref]$created,$mutexAcl);$held=$false
 try{
  try{$held=$mutex.WaitOne(0)}catch [Threading.AbandonedMutexException]{$held=$true}
  if(-not $held){throw 'CONNECTOR_UPGRADE_BUSY'}
  $record=$null
  if(Test-Path -LiteralPath $private){Assert-AuthWireUpgradePrivate $private -Directory}
  if(Test-Path -LiteralPath $journal){
   Assert-AuthWireUpgradePrivate $journal
   if((Get-Item -LiteralPath $journal).Length -gt 65536){throw 'CONNECTOR_UPGRADE_JOURNAL_REJECTED'}
   $v=Get-Content -LiteralPath $journal -Raw|ConvertFrom-Json
   if($v.Format -ne 1 -or $v.ConnectorId -cne $ConnectorId.ToString('D') -or $v.OldConfig.ReleaseId -cne $ExpectedCurrentRelease.ToString('D') -or $v.NewConfig.ReleaseId -cne $NewReleaseId.ToString('D')){throw 'CONNECTOR_UPGRADE_JOURNAL_REJECTED'}
   Assert-AuthWireServiceConfig $v.OldConfig;Assert-AuthWireServiceConfig $v.NewConfig
   if($v.OldConfig.RootPath -cne $root -or $v.NewConfig.RootPath -cne $root -or $v.OldConfig.PublisherThumbprint -cne $PublisherThumbprint -or $v.NewConfig.PublisherThumbprint -cne $PublisherThumbprint){throw 'CONNECTOR_UPGRADE_JOURNAL_REJECTED'}
   $copy=$v.NewConfig|ConvertTo-Json -Depth 6|ConvertFrom-Json;$copy.ReleaseId=$v.OldConfig.ReleaseId
   if(($copy|ConvertTo-Json -Depth 6 -Compress) -cne ($v.OldConfig|ConvertTo-Json -Depth 6 -Compress)){throw 'CONNECTOR_UPGRADE_CONFIG_CHANGED'}
   $record=@{};foreach($p in $v.PSObject.Properties){$record[$p.Name]=$p.Value}
  }
  if($Mode -eq 'Rollback'){
   if(-not $record -or $record.Phase -notin @('stopping','stopped','archiving','archived','activating','activated','marker','starting','applied','rolling_back','rolled_back')){throw 'CONNECTOR_UPGRADE_ROLLBACK_REQUIRES_REVIEW'}
   Restore-AuthWireUpgrade $record $journal $PublisherThumbprint
  }else{
   $old=Get-AuthWireServicePackage $root $PublisherThumbprint -AllowLegacy
   if($old.ReleaseId -cne $ExpectedCurrentRelease.ToString('D')){throw 'CONNECTOR_UPGRADE_CURRENT_RELEASE_CHANGED'}
   Assert-AuthWireServiceChannelKey $old
   $s=Get-AuthWireUpgradeService $old
   if($s.State -cne 'Running'){throw 'CONNECTOR_UPGRADE_RUNNING_SERVICE_REQUIRED'}
   if($record -and $record.Phase -notin @('prepared','rolled_back')){throw 'CONNECTOR_UPGRADE_INTERRUPTED_REQUIRES_ROLLBACK_REVIEW'}
   $new=$old|ConvertTo-Json -Depth 6|ConvertFrom-Json;$new.ReleaseId=$NewReleaseId.ToString('D')
   if($Mode -eq 'Prepare' -and -not $record){
    if((Test-Path -LiteralPath $stage) -or (Test-Path -LiteralPath $archive) -or (Test-Path -LiteralPath $private)){throw 'CONNECTOR_UPGRADE_PATH_EXISTS_REQUIRES_REVIEW'}
    $security=[Security.AccessControl.DirectorySecurity]::new();$security.SetSecurityDescriptorSddlForm('O:BAG:BAD:P(A;OICI;FA;;;SY)(A;OICI;FA;;;BA)');$null=[IO.Directory]::CreateDirectory($private,$security)
    $record=@{Format=1;ConnectorId=$ConnectorId.ToString('D');OldConfig=$old;NewConfig=$new;OldTree=(Get-AuthWireUpgradeTreeHash $root);NewTree='';Phase='building'}
    Write-AuthWireUpgradeJournal $journal $record 'building'
    $publisher=Get-Item -LiteralPath ('Cert:\LocalMachine\My\'+$PublisherThumbprint)
    $null=New-AuthWireServicePackageCore $new $publisher $SourceDirectory -BuildPath $stage
    Copy-AuthWireUpgradeAdmin (Join-Path $stage 'admin') $SourceDirectory $PublisherThumbprint
    $null=Get-AuthWireServicePackage $stage $PublisherThumbprint -Staged
    $record.NewTree=Get-AuthWireUpgradeTreeHash $stage
    Write-AuthWireUpgradeJournal $journal $record 'prepared'
   }
   if($record){
    if((Get-AuthWireUpgradeTreeHash $root) -cne $record.OldTree){throw 'CONNECTOR_UPGRADE_CURRENT_SOURCE_CHANGED'}
    $c=Get-AuthWireServicePackage $stage $PublisherThumbprint -Staged
    if(($c|ConvertTo-Json -Depth 6 -Compress) -cne ($record.NewConfig|ConvertTo-Json -Depth 6 -Compress) -or (Get-AuthWireUpgradeTreeHash $stage) -cne $record.NewTree){throw 'CONNECTOR_UPGRADE_CANDIDATE_CHANGED'}
   }
   if($Mode -eq 'Apply'){
    if(-not $record -or (Test-Path -LiteralPath $archive)){throw 'CONNECTOR_UPGRADE_PREPARATION_REQUIRED'}
    try{
     Write-AuthWireUpgradeJournal $journal $record 'stopping';Stop-AuthWireUpgradeService $old.ServiceName
     Write-AuthWireUpgradeJournal $journal $record 'stopped'
     if((Get-AuthWireUpgradeTreeHash $root) -cne $record.OldTree -or (Get-AuthWireUpgradeTreeHash $stage) -cne $record.NewTree){throw 'CONNECTOR_UPGRADE_SOURCE_CHANGED_AFTER_STOP'}
     Assert-AuthWireServiceChannelKey $old;$null=Get-AuthWireUpgradeService $old
     Write-AuthWireUpgradeJournal $journal $record 'archiving';[IO.Directory]::Move($root,$archive);Write-AuthWireUpgradeJournal $journal $record 'archived'
     Write-AuthWireUpgradeJournal $journal $record 'activating';[IO.Directory]::Move($stage,$root);Write-AuthWireUpgradeJournal $journal $record 'activated'
     Write-AuthWireUpgradeJournal $journal $record 'marker';[AuthWire.Connector.UpgradeMarkerV1]::Replace($old.ServiceName,(Get-AuthWireServiceMarker $old),(Get-AuthWireServiceMarker $new))
     $since=[DateTimeOffset]::UtcNow;Write-AuthWireUpgradeJournal $journal $record 'starting';Start-AuthWireUpgradeService $new.ServiceName
     Wait-AuthWireUpgradeHealth $new $since -RequireProbe -RequireCandidate -RequireScope -RequireCombined
     $null=Get-AuthWireServicePackage $root $PublisherThumbprint;Assert-AuthWireServiceChannelKey $new
     Write-AuthWireUpgradeJournal $journal $record 'applied'
    }catch{
     try{Restore-AuthWireUpgrade $record $journal $PublisherThumbprint}catch{throw ('CONNECTOR_UPGRADE_ROLLBACK_REQUIRES_REVIEW:'+ $journal+':'+$_.Exception.Message)}
     throw ('CONNECTOR_UPGRADE_FAILED_OLD_RELEASE_RESTORED:'+ $journal)
    }
   }
  }
  [pscustomobject]@{Event='WINDOWS_CONNECTOR_SERVICE_UPGRADE';Mode=$Mode;ConnectorId=$ConnectorId.ToString('D');PreviousReleaseId=$ExpectedCurrentRelease.ToString('D');NewReleaseId=$NewReleaseId.ToString('D');Phase=$(if($record){$record.Phase}else{'not_prepared'});JournalPath=$(if($record){$journal}else{$null});CandidatePath=$stage;ArchivePath=$archive;PackagePrepared=($null -ne $record);ExistingAccountPreserved=$true;PairingPreserved=$true;ChannelKeyPreserved=$true;ServicesCreated=$false;ServiceTransitioned=($Mode -in @('Apply','Rollback'));CanApplyGpo=$false;AdChanged=$false;GpoChanged=$false;KeyAclChanged=$false;TrustStoreChanged=$false;SecretsExported=$false}
 }finally{if($held){$mutex.ReleaseMutex()};$mutex.Dispose()}
}
