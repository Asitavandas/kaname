// Built with fixed package hashes and identity. No command or network job interface.
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Security.AccessControl;
using System.Security.Cryptography;
using System.Security.Principal;
using System.ServiceProcess;
using System.Threading;

namespace AuthWire.Connector {
 public sealed class HealthService : ServiceBase {
  const string Name = "@@NAME@@", Sid = "@@SID@@", Root = @"@@ROOT@@";
  static readonly Dictionary<string,string> Files = new Dictionary<string,string> {
@@HASHES@@
  };
  Process worker; Thread watcher; EventWaitHandle stop; Mutex single;
  volatile bool stopping;
  HealthService() { ServiceName=Name; AutoLog=false; CanStop=true; CanShutdown=true; }
  static void PathGuard(string path) {
   for(string p=Path.GetFullPath(path);p!=null;p=Path.GetDirectoryName(p))
    if((Directory.Exists(p)||File.Exists(p))&&(File.GetAttributes(p)&FileAttributes.ReparsePoint)!=0)
     throw new InvalidOperationException("CONNECTOR_REPARSE_REJECTED");
  }
  static void ReadOnlyAcl(string path,bool directory) {
   PathGuard(path);
   FileSystemSecurity acl=directory?(FileSystemSecurity)Directory.GetAccessControl(path):File.GetAccessControl(path);
   string owner=acl.GetOwner(typeof(SecurityIdentifier)).Value;
   if((owner!="S-1-5-18"&&owner!="S-1-5-32-544")||!acl.AreAccessRulesProtected)
    throw new InvalidOperationException("CONNECTOR_PACKAGE_OWNER_REJECTED");
   var seen=new HashSet<string>();
   foreach(FileSystemAccessRule rule in acl.GetAccessRules(true,true,typeof(SecurityIdentifier))) {
    string who=rule.IdentityReference.Value;
    int expected=who==Sid?(directory?1179817:1179785):2032127;
    if((who!=Sid&&who!="S-1-5-18"&&who!="S-1-5-32-544")||!seen.Add(who)||
       rule.AccessControlType!=AccessControlType.Allow||(int)rule.FileSystemRights!=expected||rule.IsInherited)
     throw new InvalidOperationException("CONNECTOR_PACKAGE_ACL_REJECTED");
   }
   if(seen.Count!=3)throw new InvalidOperationException("CONNECTOR_PACKAGE_ACL_REJECTED");
  }
  static void PackageGuard() {
   if(!String.Equals(Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location),Root,StringComparison.OrdinalIgnoreCase))
    throw new InvalidOperationException("CONNECTOR_PACKAGE_LOCATION_REJECTED");
   ReadOnlyAcl(Root,true);
   foreach(var pair in Files) {
    string path=Path.Combine(Root,pair.Key);ReadOnlyAcl(path,false);
    using(var sha=SHA256.Create())using(var file=File.OpenRead(path))
     if(BitConverter.ToString(sha.ComputeHash(file)).Replace("-","").ToLowerInvariant()!=pair.Value)
      throw new InvalidOperationException("CONNECTOR_PACKAGE_HASH_REJECTED");
   }
  }
  protected override void OnStart(string[] args) {
   if(args.Length!=0||!Environment.Is64BitProcess)throw new InvalidOperationException("CONNECTOR_START_ARGUMENTS_REJECTED");
   using(var identity=WindowsIdentity.GetCurrent()) {
    bool service=false;foreach(var g in identity.Groups)if(g.Value=="S-1-5-6")service=true;
    if(identity.User.Value!=Sid||!identity.IsAuthenticated||!service)
     throw new InvalidOperationException("CONNECTOR_SERVICE_IDENTITY_REJECTED");
   }
   PackageGuard();
   bool created;
   var mutexAcl=new MutexSecurity();
   mutexAcl.AddAccessRule(new MutexAccessRule(new SecurityIdentifier(Sid),MutexRights.FullControl,AccessControlType.Allow));
   single=new Mutex(false,@"Global\"+Name,out created,mutexAcl);
   if(!created)throw new InvalidOperationException("CONNECTOR_DUPLICATE_PROCESS");
   string eventName=@"Local\"+Name+"-"+Guid.NewGuid().ToString("N");
   var eventAcl=new EventWaitHandleSecurity();
   eventAcl.AddAccessRule(new EventWaitHandleAccessRule(new SecurityIdentifier(Sid),EventWaitHandleRights.FullControl,AccessControlType.Allow));
   stop=new EventWaitHandle(false,EventResetMode.ManualReset,eventName,out created,eventAcl);
   if(!created)throw new InvalidOperationException("CONNECTOR_STOP_EVENT_COLLISION");
   string powershell=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Windows),@"System32\WindowsPowerShell\v1.0\powershell.exe");
   PathGuard(powershell);
   var info=new ProcessStartInfo(powershell);
   var self=Process.GetCurrentProcess();
   info.Arguments="-NoLogo -NoProfile -NonInteractive -ExecutionPolicy AllSigned -File \""+Path.Combine(Root,"ConnectorServiceRuntime.ps1")+"\" -StopEventName \""+eventName+"\" -HostPid "+self.Id+" -HostStartedTicks "+self.StartTime.ToUniversalTime().Ticks;
   info.WorkingDirectory=Root;info.UseShellExecute=false;info.CreateNoWindow=true;
   info.EnvironmentVariables["PSModulePath"]=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Windows),@"System32\WindowsPowerShell\v1.0\Modules");
   worker=Process.Start(info);
   watcher=new Thread(delegate(){
    worker.WaitForExit();if(!stopping)Environment.Exit(20);
   });watcher.IsBackground=true;watcher.Start();
  }
  protected override void OnStop() {
   stopping=true;RequestAdditionalTime(25000);
   if(stop!=null)stop.Set();
   if(worker!=null) {
    if(!worker.WaitForExit(20000)){worker.Kill();worker.WaitForExit(3000);}
    if(watcher!=null)watcher.Join(3000);worker.Dispose();worker=null;
   }
   if(stop!=null){stop.Dispose();stop=null;}
   if(single!=null){single.Dispose();single=null;}
  }
  protected override void OnShutdown(){OnStop();}
  public static void Main(string[] args) {
   if(args.Length!=0)return;
   ServiceBase.Run(new HealthService());
  }
 }
}
