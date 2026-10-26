function Initialize-AuthWirePermanentServiceControl {
 # A clean Windows PowerShell session need not have loaded this assembly.
 # Load it before even the cached native helper can return.
 Add-Type -AssemblyName System.ServiceProcess -ErrorAction Stop
 if('AuthWire.Connector.PermanentServiceV1' -as [type]){return}
 Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Text.RegularExpressions;
namespace AuthWire.Connector {
 public static class PermanentServiceV1 {
  [StructLayout(LayoutKind.Sequential,CharSet=CharSet.Unicode)]struct Description {public string Text;}
  [StructLayout(LayoutKind.Sequential)]struct Delayed { [MarshalAs(UnmanagedType.Bool)] public bool Enabled; }
  [StructLayout(LayoutKind.Sequential)]struct Action {public uint Type,Delay;}
  [StructLayout(LayoutKind.Sequential,CharSet=CharSet.Unicode)]struct Failures {public uint Reset;public string Reboot,Command;public uint Count;public IntPtr Actions;}
  [DllImport("advapi32.dll",CharSet=CharSet.Unicode,SetLastError=true)]static extern IntPtr OpenSCManagerW(string machine,string database,uint access);
  [DllImport("advapi32.dll",CharSet=CharSet.Unicode,SetLastError=true)]static extern IntPtr CreateServiceW(IntPtr manager,string name,string display,uint access,uint type,uint start,uint error,string binary,string group,IntPtr tag,string depends,string account,string password);
  [DllImport("advapi32.dll",CharSet=CharSet.Unicode,SetLastError=true)]static extern IntPtr OpenServiceW(IntPtr manager,string name,uint access);
  [DllImport("advapi32.dll",SetLastError=true)]static extern bool ChangeServiceConfig2W(IntPtr service,uint level,IntPtr data);
  [DllImport("advapi32.dll",SetLastError=true)]static extern bool QueryServiceConfig2W(IntPtr service,uint level,IntPtr data,uint size,out uint needed);
  [DllImport("advapi32.dll",CharSet=CharSet.Unicode,SetLastError=true)]static extern bool ConvertStringSecurityDescriptorToSecurityDescriptorW(string text,uint revision,out IntPtr result,out uint size);
  [DllImport("advapi32.dll",SetLastError=true)]static extern bool SetServiceObjectSecurity(IntPtr service,uint info,IntPtr descriptor);
  [DllImport("advapi32.dll",SetLastError=true)]static extern bool DeleteService(IntPtr service);
  [DllImport("advapi32.dll")]static extern bool CloseServiceHandle(IntPtr service);
  [DllImport("kernel32.dll")]static extern IntPtr LocalFree(IntPtr memory);
  static void Name(string name){if(!Regex.IsMatch(name??"",@"\AAuthWireConnector-[0-9a-f]{32}\z"))throw new ArgumentException("Owned Connector service required");}
  static void Check(bool ok){if(!ok)throw new Win32Exception(Marshal.GetLastWin32Error());}
  static void Config<T>(IntPtr h,uint level,T value) {
   IntPtr p=Marshal.AllocHGlobal(Marshal.SizeOf(typeof(T)));
   try{Marshal.StructureToPtr(value,p,false);Check(ChangeServiceConfig2W(h,level,p));}
   finally{Marshal.DestroyStructure(p,typeof(T));Marshal.FreeHGlobal(p);}
  }
  public static void Create(string name,string binary,string account,string marker,string sid) {
   Name(name);IntPtr scm=IntPtr.Zero,h=IntPtr.Zero,actions=IntPtr.Zero,sd=IntPtr.Zero;
   try{
    scm=OpenSCManagerW(null,null,3);if(scm==IntPtr.Zero)throw new Win32Exception(Marshal.GetLastWin32Error());
    // Explicit managed account and NULL password. Never retrieves or persists its password.
    h=CreateServiceW(scm,name,name,0xF01FF,0x10,2,1,binary,null,IntPtr.Zero,null,account,null);
    if(h==IntPtr.Zero)throw new Win32Exception(Marshal.GetLastWin32Error());
    Config(h,1,new Description{Text=marker});Config(h,3,new Delayed{Enabled=true});
    actions=Marshal.AllocHGlobal(24);
    Marshal.StructureToPtr(new Action{Type=1,Delay=60000},actions,false);
    Marshal.StructureToPtr(new Action{Type=1,Delay=60000},IntPtr.Add(actions,8),false);
    Marshal.StructureToPtr(new Action{Type=0,Delay=0},IntPtr.Add(actions,16),false);
    Config(h,2,new Failures{Reset=86400,Reboot=null,Command=null,Count=3,Actions=actions});
    uint size;Check(ConvertStringSecurityDescriptorToSecurityDescriptorW("D:P(A;;GA;;;SY)(A;;GA;;;BA)(A;;0x20084;;;"+sid+")",1,out sd,out size));
    Check(SetServiceObjectSecurity(h,4,sd));
   }catch{
    // Only the newly created, still-unstarted handle is eligible for cleanup.
    if(h!=IntPtr.Zero)DeleteService(h);throw;
   }finally{if(sd!=IntPtr.Zero)LocalFree(sd);if(actions!=IntPtr.Zero)Marshal.FreeHGlobal(actions);if(h!=IntPtr.Zero)CloseServiceHandle(h);if(scm!=IntPtr.Zero)CloseServiceHandle(scm);}
  }
  public static void Remove(string name){
   Name(name);IntPtr scm=OpenSCManagerW(null,null,1),h=IntPtr.Zero;
   if(scm==IntPtr.Zero)throw new Win32Exception(Marshal.GetLastWin32Error());
   try{h=OpenServiceW(scm,name,0x10000);if(h==IntPtr.Zero)throw new Win32Exception(Marshal.GetLastWin32Error());Check(DeleteService(h));}
   finally{if(h!=IntPtr.Zero)CloseServiceHandle(h);CloseServiceHandle(scm);}
  }
  public static bool RecoveryMatches(string name){
   Name(name);IntPtr scm=OpenSCManagerW(null,null,1),h=IntPtr.Zero,p=IntPtr.Zero;
   if(scm==IntPtr.Zero)throw new Win32Exception(Marshal.GetLastWin32Error());
   try{
    h=OpenServiceW(scm,name,1);if(h==IntPtr.Zero)throw new Win32Exception(Marshal.GetLastWin32Error());
    uint size;QueryServiceConfig2W(h,2,IntPtr.Zero,0,out size);
    if(size<Marshal.SizeOf(typeof(Failures))||size>8192)return false;
    p=Marshal.AllocHGlobal((int)size);Check(QueryServiceConfig2W(h,2,p,size,out size));
    var f=(Failures)Marshal.PtrToStructure(p,typeof(Failures));
    if(f.Reset!=86400||!String.IsNullOrEmpty(f.Reboot)||!String.IsNullOrEmpty(f.Command)||f.Count!=3||f.Actions==IntPtr.Zero)return false;
    for(int i=0;i<3;i++){
     var a=(Action)Marshal.PtrToStructure(IntPtr.Add(f.Actions,i*8),typeof(Action));
     if(a.Type!=(i<2?1u:0u)||a.Delay!=(i<2?60000u:0u))return false;
    }
    return true;
   }finally{if(p!=IntPtr.Zero)Marshal.FreeHGlobal(p);if(h!=IntPtr.Zero)CloseServiceHandle(h);CloseServiceHandle(scm);}
  }
 }
}
'@
}
function Get-AuthWireServiceMarker {
 param($Config)
 'AuthWireConnectorService:v1;connector='+$Config.Binding.connector_id+';release='+$Config.ReleaseId+';sid='+$Config.Binding.service_sid
}
function Invoke-AuthWireServiceControlCore {
 param([ValidateSet('Inspect','Install','Start','Stop','Remove')][string]$Mode='Inspect',
  [string]$RootPath,[string]$ExpectedPublisher)
 Assert-AuthWireServiceAdmin
 $c=Get-AuthWireServicePackage $RootPath $ExpectedPublisher
 $name=$c.ServiceName;$binary='"'+(Join-Path $RootPath 'AuthWireConnector.exe')+'"'
 $current=Get-CimInstance Win32_Service -Filter ("Name='"+$name+"'")
 $currentAccount=if($current){[string]$current.StartName}else{''}
 if($currentAccount.StartsWith('.\')){$currentAccount=[Environment]::MachineName+$currentAccount.Substring(1)}
 if($current -and ($current.PathName -cne $binary -or $currentAccount -ine $c.AccountName -or $current.Description -cne (Get-AuthWireServiceMarker $c))){throw 'CONNECTOR_EXISTING_SERVICE_MISMATCH'}
 Initialize-AuthWirePermanentServiceControl
 if($current -and $Mode -in @('Install','Start')){
  $reg=Get-ItemProperty -LiteralPath ('HKLM:\SYSTEM\CurrentControlSet\Services\'+$name)
  if($current.StartMode -ne 'Auto' -or -not $reg.PSObject.Properties['DelayedAutoStart'] -or $reg.DelayedAutoStart -ne 1 -or -not [AuthWire.Connector.PermanentServiceV1]::RecoveryMatches($name)){throw 'CONNECTOR_SERVICE_RECOVERY_POLICY_MISMATCH'}
 }
 $created=$false
 if($Mode -eq 'Install' -and -not $current){
  Initialize-AuthWirePermanentServiceControl
  [AuthWire.Connector.PermanentServiceV1]::Create($name,$binary,$c.AccountName,(Get-AuthWireServiceMarker $c),$c.Binding.service_sid)
  $created=$true
 }
 if($Mode -in @('Start','Stop','Remove')){
  if(-not $current){throw 'CONNECTOR_SERVICE_NOT_INSTALLED'}
  $service=[System.ServiceProcess.ServiceController]::new($name)
  try{
   if($Mode -eq 'Start'){
    if($service.Status -ne [System.ServiceProcess.ServiceControllerStatus]::Running){$service.Start();$service.WaitForStatus([System.ServiceProcess.ServiceControllerStatus]::Running,[TimeSpan]::FromSeconds(30))}
   }else{
    if($service.Status -ne [System.ServiceProcess.ServiceControllerStatus]::Stopped){$service.Stop();$service.WaitForStatus([System.ServiceProcess.ServiceControllerStatus]::Stopped,[TimeSpan]::FromSeconds(30))}
    if($Mode -eq 'Remove'){Initialize-AuthWirePermanentServiceControl;[AuthWire.Connector.PermanentServiceV1]::Remove($name)}
   }
  }finally{$service.Dispose()}
 }
 $after=Get-CimInstance Win32_Service -Filter ("Name='"+$name+"'")
 [pscustomobject]@{Event='WINDOWS_CONNECTOR_SERVICE_CONTROL';Mode=$Mode;ServiceName=$name;ServiceCreated=$created;ServiceInstalled=($null -ne $after);ServiceState=$(if($after){$after.State}else{'Absent'});ReleaseId=$c.ReleaseId;CanApplyGpo=$false;AdChanged=$false;GpoChanged=$false;LogonRightsChanged=$false;KeyAclChanged=$false;SecretsExported=$false;PackageAndKeyRemoved=$false}
}
