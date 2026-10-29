# Fixed stage runner only. Assign the child to a kill-on-close Windows job
# BEFORE releasing its one-use gate. No live worker registration here.
Set-StrictMode -Version 2
function Initialize-AuthWireStageProcess {
 if('AuthWire.Connector.StageProcessV1' -as [type]){return}
 Add-Type -TypeDefinition @'
using System;
using System.ComponentModel;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using Microsoft.Win32.SafeHandles;
namespace AuthWire.Connector {
 public sealed class StageProcessResultV1 {public bool TimedOut,Truncated;public int ExitCode,ProcessId;public long ProcessStartedTicks;public string Output;}
 public static class StageProcessV1 {
  [StructLayout(LayoutKind.Sequential)] struct Basic {public long ProcessTime,JobTime;public uint Flags;public UIntPtr MinWorking,MaxWorking;public uint Active;public UIntPtr Affinity;public uint Priority,Scheduling;}
  [StructLayout(LayoutKind.Sequential)] struct Io {public ulong ReadOps,WriteOps,OtherOps,ReadBytes,WriteBytes,OtherBytes;}
  [StructLayout(LayoutKind.Sequential)] struct Extended {public Basic Basic;public Io Io;public UIntPtr ProcessMemory,JobMemory,PeakProcessMemory,PeakJobMemory;}
  [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern SafeFileHandle CreateJobObject(IntPtr security,string name);
  [DllImport("kernel32.dll",SetLastError=true)] static extern bool SetInformationJobObject(SafeFileHandle job,int kind,ref Extended info,uint size);
  [DllImport("kernel32.dll",SetLastError=true)] static extern bool AssignProcessToJobObject(SafeFileHandle job,IntPtr process);
  [DllImport("kernel32.dll",SetLastError=true)] static extern bool TerminateJobObject(SafeFileHandle job,uint code);
  public static StageProcessResultV1 Run(string exe,string arguments,int milliseconds,EventWaitHandle gate,Action<int,long> beforeRelease){
   if(milliseconds<100||milliseconds>15000||gate==null||beforeRelease==null)throw new ArgumentException("STAGE_PROCESS_BUDGET_REJECTED");
   var result=new StageProcessResultV1();var output=new StringBuilder();var error=new StringBuilder();object sync=new object();var watch=Stopwatch.StartNew();
   using(var job=CreateJobObject(IntPtr.Zero,null)){
    if(job.IsInvalid)throw new Win32Exception(Marshal.GetLastWin32Error());
    var info=new Extended();info.Basic.Flags=0x2000; // JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE
    if(!SetInformationJobObject(job,9,ref info,(uint)Marshal.SizeOf(typeof(Extended))))throw new Win32Exception(Marshal.GetLastWin32Error());
    using(var p=new Process()){
     p.StartInfo=new ProcessStartInfo(exe,arguments){UseShellExecute=false,CreateNoWindow=true,RedirectStandardOutput=true,RedirectStandardError=true};
     p.Start();
     try{
      // The trusted fixed child cannot write before consuming its gate.
      // Assignment failure or parent death before release never grants entry.
      if(!AssignProcessToJobObject(job,p.Handle))throw new Win32Exception(Marshal.GetLastWin32Error());
      result.ProcessId=p.Id;result.ProcessStartedTicks=p.StartTime.ToUniversalTime().Ticks;
      var stdout=System.Threading.Tasks.Task.Factory.StartNew(()=>Drain(p.StandardOutput,output,8192,sync,result));
      var stderr=System.Threading.Tasks.Task.Factory.StartNew(()=>Drain(p.StandardError,error,2048,sync,result));
      beforeRelease(result.ProcessId,result.ProcessStartedTicks);
      int remaining=milliseconds-(int)watch.ElapsedMilliseconds;
      if(remaining<1)throw new InvalidOperationException("STAGE_PROCESS_START_TIMEOUT");
      gate.Set();
      if(!p.WaitForExit(remaining)){
       result.TimedOut=true;
       if(!TerminateJobObject(job,20))throw new Win32Exception(Marshal.GetLastWin32Error());
       if(!p.WaitForExit(3000))throw new InvalidOperationException("STAGE_JOB_NOT_TERMINATED");
      }
      if(!System.Threading.Tasks.Task.WaitAll(new[]{stdout,stderr},3000))throw new InvalidOperationException("STAGE_DRAIN_TIMEOUT");
      result.ExitCode=p.ExitCode;
      lock(sync){result.Output=output.ToString();if(error.Length>0)result.ExitCode=20;}
      return result;
     }finally{
      // Also close descendants on ordinary return or metadata/write failure.
      TerminateJobObject(job,20);
      try{if(!p.HasExited)p.Kill();}catch(InvalidOperationException){}
     }
    }
   }
  }
  static void Drain(System.IO.StreamReader reader,StringBuilder buffer,int limit,object sync,StageProcessResultV1 result){
   var chars=new char[256];int n;while((n=reader.Read(chars,0,chars.Length))>0){lock(sync){if(buffer.Length+n>limit)result.Truncated=true;else buffer.Append(chars,0,n);}}
  }
 }
}
'@
}
