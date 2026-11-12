// Built with fixed package hashes and identity. No command or network job interface.
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Reflection;
using System.Runtime.InteropServices;
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
  const string WriteScheduler = "@@WRITE_SCHEDULER@@";
  Process worker, writeWorker; Thread watcher; EventWaitHandle stop, writeReady; Mutex single;
  IntPtr job=IntPtr.Zero;
  [StructLayout(LayoutKind.Sequential)]struct BasicLimits {
   public long ProcessTime,JobTime;public uint Flags;public UIntPtr MinWork,MaxWork;
   public uint Active;public UIntPtr Affinity;public uint Priority,Scheduling;
  }
  [StructLayout(LayoutKind.Sequential)]struct IoCounters {public ulong ReadOps,WriteOps,OtherOps,ReadBytes,WriteBytes,OtherBytes;}
  [StructLayout(LayoutKind.Sequential)]struct ExtendedLimits {
   public BasicLimits Basic;public IoCounters Io;public UIntPtr ProcessMemory,JobMemory,PeakProcess,PeakJob;
  }
  [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)]static extern IntPtr CreateJobObjectW(IntPtr security,string name);
  [DllImport("kernel32.dll",SetLastError=true)]static extern bool SetInformationJobObject(IntPtr handle,int kind,ref ExtendedLimits value,uint size);
  [DllImport("kernel32.dll",SetLastError=true)]static extern bool AssignProcessToJobObject(IntPtr handle,IntPtr process);
  [DllImport("kernel32.dll")]static extern bool CloseHandle(IntPtr handle);
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
  Process StartWorker(ProcessStartInfo info) {
   var process=Process.Start(info);
   if(AssignProcessToJobObject(job,process.Handle))return process;
   try{if(!process.HasExited)process.Kill();}finally{process.Dispose();}
   throw new InvalidOperationException("CONNECTOR_JOB_ASSIGN_FAILED");
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
   const string scriptArgs="-NoLogo -NoProfile -NonInteractive -ExecutionPolicy AllSigned -File ";
   string hostArgs=" -StopEventName \""+eventName+"\" -HostPid "+self.Id+" -HostStartedTicks "+self.StartTime.ToUniversalTime().Ticks;
   info.Arguments=scriptArgs+"\""+Path.Combine(Root,"ConnectorServiceRuntime.ps1")+"\""+hostArgs;
   info.WorkingDirectory=Root;info.UseShellExecute=false;info.CreateNoWindow=true;
   info.EnvironmentVariables["PSModulePath"]=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Windows),@"System32\WindowsPowerShell\v1.0\Modules");
   job=CreateJobObjectW(IntPtr.Zero,null);
   if(job==IntPtr.Zero)throw new InvalidOperationException("CONNECTOR_JOB_CREATE_FAILED");
   var limits=new ExtendedLimits();limits.Basic.Flags=0x2000; // KILL_ON_JOB_CLOSE, no breakaway.
   if(!SetInformationJobObject(job,9,ref limits,(uint)Marshal.SizeOf(typeof(ExtendedLimits)))){
    CloseHandle(job);job=IntPtr.Zero;throw new InvalidOperationException("CONNECTOR_JOB_LIMIT_FAILED");
   }
   try{
    worker=StartWorker(info);
    if(WriteScheduler=="enabled"){
     string writeEvent=eventName+"-Write";
     writeReady=new EventWaitHandle(false,EventResetMode.ManualReset,writeEvent,out created,eventAcl);
     if(!created)throw new InvalidOperationException("CONNECTOR_WRITE_EVENT_COLLISION");
     info.Arguments=scriptArgs+"\""+Path.Combine(Root,"ConnectorWriteServiceRuntime.ps1")+"\""+hostArgs+
      " -StartEventName \""+writeEvent+"\"";
     writeWorker=StartWorker(info);
     writeReady.Set();
    }
   }catch{
    CloseHandle(job);job=IntPtr.Zero;
    if(worker!=null)worker.Dispose();
    if(writeWorker!=null)writeWorker.Dispose();
    if(writeReady!=null)writeReady.Dispose();
    throw;
   }
   watcher=new Thread(delegate(){
    try{worker.WaitForExit();}catch{}finally{if(!stopping)Environment.Exit(20);}
   });watcher.IsBackground=true;watcher.Start();
  }
  protected override void OnStop() {
   stopping=true;RequestAdditionalTime(25000);
   try{
    var wait=Stopwatch.StartNew();
    if(stop!=null)stop.Set();
    if(worker!=null)worker.WaitForExit(20000);
    if(writeWorker!=null)writeWorker.WaitForExit(Math.Max(0,20000-(int)wait.ElapsedMilliseconds));
   }finally{
    // Kernel-enforced cleanup also covers a blocked worker or its compiler child.
    if(job!=IntPtr.Zero){CloseHandle(job);job=IntPtr.Zero;}
    if(watcher!=null)watcher.Join(3000);
    if(worker!=null){worker.Dispose();worker=null;}
    if(writeWorker!=null){writeWorker.Dispose();writeWorker=null;}
    if(writeReady!=null){writeReady.Dispose();writeReady=null;}
    if(stop!=null){stop.Dispose();stop=null;}
    if(single!=null){single.Dispose();single=null;}
   }
  }
  protected override void OnShutdown(){OnStop();}
  public static void Main(string[] args) {
   if(args.Length!=0)return;
   ServiceBase.Run(new HealthService());
  }
 }
}
