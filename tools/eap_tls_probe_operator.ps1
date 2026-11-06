# Exact VV-Client01 pilot only. Sign with existing publisher before execution.
param([ValidateSet('Check','Run','Link','Restore')][string]$Mode='Check',[ValidateSet('expired','wrong-issuer','control','transport')][string]$Case='transport')
$ErrorActionPreference='Stop'
$stage=$PSScriptRoot;$guid='2db4814e-faa5-4315-bdbd-eae3a90dbe1b';$publisher='6E74B513F766E01730719684A41B2664380CA68A'
$base='C:\ProgramData\AuthWire-Pilot\20261105-3061f09f71e146c6a281fecce2ebd1ee'
$good=Join-Path $base 'wired-repeat-20261106-b\known-good.xml'
$pins=@{} # Deployment pins are inserted before enterprise signing.
function Exact-Adapter {
 if($env:COMPUTERNAME -ine 'VV-CLIENT01' -or ([guid](Get-NetAdapter Ethernet0).InterfaceGuid).ToString() -ne $guid){throw 'Exact pilot adapter required'}
 if((Get-NetAdapter Ethernet1).Status -ne 'Up'){throw 'Management adapter unavailable'}
}
function Pinned($p,$h){$f=Get-Item -LiteralPath $p;if($f.PSIsContainer -or ($f.Attributes -band [IO.FileAttributes]::ReparsePoint) -or (Get-FileHash $p).Hash -ine $h){throw 'Pinned diagnostic asset changed'}}
function Lan([string[]]$a){$o=@(& "$env:SystemRoot\System32\netsh.exe" @a 2>&1);if($LASTEXITCODE -ne 0){throw 'Exact Ethernet0 LAN operation failed'};return ($o|Out-String)}
function Management {
 [ordered]@{Adapter=@(Get-NetAdapter -Name Ethernet1|Select-Object Name,InterfaceGuid,ifIndex,MacAddress);IPv4=@(Get-NetIPAddress -InterfaceAlias Ethernet1 -AddressFamily IPv4|Select-Object IPAddress,PrefixLength,SkipAsSource,PrefixOrigin,SuffixOrigin);IPInterface=@(Get-NetIPInterface -InterfaceAlias Ethernet1 -AddressFamily IPv4|Select-Object Dhcp,AutomaticMetric,InterfaceMetric);DNS=@(Get-DnsClientServerAddress -InterfaceAlias Ethernet1 -AddressFamily IPv4|Select-Object ServerAddresses);DefaultRoute=@(Get-NetRoute -InterfaceAlias Ethernet1 -DestinationPrefix '0.0.0.0/0'|Select-Object NextHop,RouteMetric)}|ConvertTo-Json -Depth 6 -Compress
}
function Services {@(Get-CimInstance Win32_Service -Filter "Name='dot3svc' OR Name='EapHost'"|Sort-Object Name|Select-Object Name,State,ProcessId)|ConvertTo-Json -Compress}
function Restore {
 Exact-Adapter;Pinned $good '5F05463E7442C34DF5D7D38173B271A3436662A0224808CB06721A4EBA5DBD4D'
 $null=Lan @('lan','set','autoconfig','enabled=yes','interface=Ethernet0')
 $null=Lan @('lan','add','profile',('filename='+$good),'interface=Ethernet0')
}
Exact-Adapter
$sig=Get-AuthenticodeSignature -LiteralPath $PSCommandPath
if($sig.Status -ne 'Valid' -or $sig.SignerCertificate.Thumbprint -cne $publisher){throw 'Existing trusted enterprise publisher required'}
if($Mode -eq 'Restore'){Restore;'AUTHWIRE_ETHERNET0_AUTOCONFIG_AND_STRICT_PROFILE_RESTORED';return}
if($pins.Count -ne 3){throw 'Deployment asset pins required'}
foreach($name in $pins.Keys){Pinned (Join-Path $stage $name) $pins[$name]}
if($Mode -in @('Check','Link')){
 if((Get-AuthenticodeSignature 'C:\Windows\System32\Npcap\wpcap.dll').Status -ne 'Valid'){throw 'Npcap signature invalid'}
 Add-Type -TypeDefinition @'
using System;using System.Text;using System.Runtime.InteropServices;using System.Diagnostics;using System.Threading;using System.Threading.Tasks;
public static class AuthWireEapLink {
 [StructLayout(LayoutKind.Sequential)]struct Bpf {public uint len;public IntPtr p;}
 [StructLayout(LayoutKind.Sequential)]struct Header {public int sec,usec;public uint caplen,len;}
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode)]static extern bool SetDllDirectory(string p);
 const string D=@"C:\Windows\System32\Npcap\wpcap.dll";
 [DllImport(D,CallingConvention=CallingConvention.Cdecl)]static extern IntPtr pcap_open_live(string d,int snap,int promisc,int timeout,StringBuilder err);
 [DllImport(D,CallingConvention=CallingConvention.Cdecl)]static extern int pcap_compile(IntPtr p,ref Bpf b,string f,int opt,uint mask);
 [DllImport(D,CallingConvention=CallingConvention.Cdecl)]static extern int pcap_setfilter(IntPtr p,ref Bpf b);
 [DllImport(D,CallingConvention=CallingConvention.Cdecl)]static extern void pcap_freecode(ref Bpf b);
 [DllImport(D,CallingConvention=CallingConvention.Cdecl)]static extern int pcap_setnonblock(IntPtr p,int v,StringBuilder e);
 [DllImport(D,CallingConvention=CallingConvention.Cdecl)]static extern int pcap_next_ex(IntPtr p,out IntPtr h,out IntPtr d);
 [DllImport(D,CallingConvention=CallingConvention.Cdecl)]static extern int pcap_sendpacket(IntPtr p,byte[] b,int n);
 [DllImport(D,CallingConvention=CallingConvention.Cdecl)]static extern void pcap_close(IntPtr p);
 public static bool ValidSend(byte[] b){
  if(b.Length<60||b.Length>1500||b[12]!=0x88||b[13]!=0x8e||(b[14]!=1&&b[14]!=2))return false;
  if(BitConverter.ToString(b,6,6)!="00-50-56-9B-7D-E3")return false;
  string dst=BitConverter.ToString(b,0,6);
  if(dst!="01-80-C2-00-00-03")return false;
  int n=(b[16]<<8)|b[17];if(b.Length!=Math.Max(60,18+n))return false;
  for(int i=18+n;i<b.Length;i++)if(b[i]!=0)return false;
  if(b[15]==1)return n==0 && dst=="01-80-C2-00-00-03";
  return b[15]==0 && n>=5 && b[18]==2 && ((b[20]<<8)|b[21])==n && (b[22]==1||b[22]==3||b[22]==13);
 }
 public static void Run(){
  SetDllDirectory(@"C:\Windows\System32\Npcap");StringBuilder err=new StringBuilder(512);
  IntPtr p=pcap_open_live(@"\Device\NPF_{2DB4814E-FAA5-4315-BDBD-EAE3A90DBE1B}",8192,0,100,err);
  if(p==IntPtr.Zero)throw new Exception("Exact Ethernet0 Npcap open failed");
  try{
   Bpf f=new Bpf();if(pcap_compile(p,ref f,"ether proto 0x888e and ether host 00:50:56:9b:7d:e3",1,0xffffffff)!=0)throw new Exception("Filter compile failed");
   try{if(pcap_setfilter(p,ref f)!=0)throw new Exception("Filter failed");}finally{pcap_freecode(ref f);}
   if(pcap_setnonblock(p,1,err)!=0)throw new Exception("Nonblock failed");
   Stopwatch timer=Stopwatch.StartNew();int sent=0,received=0;Task<string> input=Task.Run(()=>Console.ReadLine());
   Console.WriteLine("AUTHWIRE_EAPOL_LINK_READY");
   while(timer.Elapsed.TotalSeconds<55 && sent<250 && received<1000){
    if(input.IsCompleted){string line=input.Result;if(line==null||line=="STOP")break;
     if(line.Length>2100)throw new Exception("Send size bound");byte[] frame=Convert.FromBase64String(line);
     if(!ValidSend(frame))throw new Exception("Only exact Ethernet0 EAP responses allowed");
     if(pcap_sendpacket(p,frame,frame.Length)!=0)throw new Exception("EAP transmit failed");sent++;Console.WriteLine("AUTHWIRE_EAPOL_TX");input=Task.Run(()=>Console.ReadLine());
    }
    IntPtr hp,dp;int rc=pcap_next_ex(p,out hp,out dp);if(rc==0){Thread.Sleep(5);continue;}if(rc<0)throw new Exception("Capture failed");
    Header h=(Header)Marshal.PtrToStructure(hp,typeof(Header));if(h.caplen<18||h.caplen>8192)continue;
    byte[] b=new byte[h.caplen];Marshal.Copy(dp,b,0,b.Length);Console.WriteLine(Convert.ToBase64String(b));received++;
   }
  }finally{pcap_close(p);}
 }
}
'@
 if($Mode -eq 'Link'){[AuthWireEapLink]::Run();return}
 $bad=New-Object byte[] 64
 if([AuthWireEapLink]::ValidSend($bad)){throw 'Malformed frame accepted'}
 $start=New-Object byte[] 60
 [byte[]]$dst=1,128,194,0,0,3;[byte[]]$src=0,80,86,155,125,227
 $dst.CopyTo($start,0);$src.CopyTo($start,6);$start[12]=136;$start[13]=142;$start[14]=1;$start[15]=1
 if(![AuthWireEapLink]::ValidSend($start)){throw 'Bounded padded EAPOL start refused'}
 $reply=[byte[]]$start.Clone();$reply[15]=0;$reply[17]=6;$reply[18]=2;$reply[19]=9;$reply[21]=6;$reply[22]=13
 if(![AuthWireEapLink]::ValidSend($reply)){throw 'PAE multicast response refused'}
 [byte[]]$unicast=100,232,129,52,99,97;$unicast.CopyTo($reply,0)
 if([AuthWireEapLink]::ValidSend($reply)){throw 'Unicast response regression'}
 'AUTHWIRE_EXPLICIT_EAP_LINK_CHECK_OK';return
}
$baseline=(Get-Content (Join-Path $base 'management-before.json') -Raw|ConvertFrom-Json)|ConvertTo-Json -Depth 6 -Compress
$services=Services
if((Management) -cne $baseline){throw 'Management baseline changed'}
$settings=Lan @('lan','show','settings')
if($settings -notmatch 'disabled on interface "Ethernet1"' -or $settings -notmatch 'enabled on interface "Ethernet0"'){throw 'Unexpected per-interface authentication state'}
$safety='AuthWire-Ethernet0-CertProbeRestore-'+[guid]::NewGuid().ToString('N')
$action=New-ScheduledTaskAction -Execute "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe" -Argument ('-NoProfile -NonInteractive -ExecutionPolicy AllSigned -File "'+$PSCommandPath+'" -Mode Restore')
$null=Register-ScheduledTask -TaskName $safety -Action $action -Trigger (New-ScheduledTaskTrigger -Once -At (Get-Date).AddSeconds(360)) -Principal (New-ScheduledTaskPrincipal -UserId SYSTEM -LogonType ServiceAccount -RunLevel Highest) -Settings (New-ScheduledTaskSettingsSet -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 1))
$scheduler=New-Object -ComObject Schedule.Service;$scheduler.Connect();$scheduler.GetFolder('\').GetTask($safety).SetSecurityDescriptor('D:P(A;;GA;;;SY)(A;;GA;;;BA)',0)
$result=[ordered]@{event='AUTHWIRE_EXPLICIT_CERTIFICATE_PILOT';case=$Case;started=[datetime]::UtcNow.ToString('o');probe=$null;error=$null;restore_authenticated=$false}
try{
 $null=Lan @('lan','set','autoconfig','enabled=no','interface=Ethernet0')
 Start-Sleep -Seconds 65
 if((Management) -cne $baseline -or (Services) -cne $services){throw 'Baseline guard failed'}
 $lines=@(& node.exe (Join-Path $stage 'eap_tls_probe_windows.js') $Case)
 if($lines.Count -ne 1){throw 'Expected one bounded probe result'}
 $result.probe=$lines[0]|ConvertFrom-Json
 if($LASTEXITCODE -ne 0){throw 'Explicit certificate probe incomplete'}
}catch{$result.error=$_.Exception.Message}finally{
 Restore;Start-Sleep -Seconds 65
 $cursor=[long](Get-WinEvent -LogName 'Microsoft-Windows-Wired-AutoConfig/Operational' -MaxEvents 1).RecordId
 $null=Lan @('lan','reconnect','interface=Ethernet0')
 $watch=[Diagnostics.Stopwatch]::StartNew()
 do{
  $event=Get-WinEvent -LogName 'Microsoft-Windows-Wired-AutoConfig/Operational' -FilterXPath ('*[System[(EventRecordID > '+$cursor+') and (EventID=15505)]]') -MaxEvents 5 -ErrorAction SilentlyContinue|Where-Object {$_.ToXml() -match $guid}|Select-Object -First 1
  if($event){$result.restore_authenticated=$true;$result.restored_record_id=$event.RecordId;break}
  Start-Sleep -Milliseconds 750
 }while($watch.Elapsed.TotalSeconds -lt 35)
 $result.management_unchanged=((Management) -ceq $baseline);$result.services_unchanged=((Services) -ceq $services)
 $result.finished=[datetime]::UtcNow.ToString('o');$result.final_lan=Lan @('lan','show','interfaces')
 if($result.restore_authenticated){Unregister-ScheduledTask -TaskName $safety -Confirm:$false}
 [IO.File]::WriteAllText((Join-Path $stage ($Case+'-result.json')),($result|ConvertTo-Json -Depth 7),(New-Object Text.UTF8Encoding($false)))
 $result|ConvertTo-Json -Depth 7 -Compress
}
if($result.error -or !$result.restore_authenticated -or !$result.management_unchanged -or !$result.services_unchanged){exit 2}
