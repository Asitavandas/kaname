# Isolated transaction engine. NOT installed, dot-sourced or exposed by the live worker.
# A future authenticated adapter must derive paths, revalidate AD/PDC/GPO/signatures,
# and authorize the exact fresh preview. A hash parameter is NOT authentication.
Set-StrictMode -Version 2

function Initialize-AuthWireStagingFilesystemTypes {
 if('AuthWire.Staging.TreeLeaseV1' -as [type]){return}
 Add-Type -TypeDefinition @'
using System;
using System.IO;
using System.Collections.Generic;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Security.AccessControl;
using System.Security.Cryptography;
using Microsoft.Win32.SafeHandles;
namespace AuthWire.Staging {
 public sealed class RowV1 {
  public string Path,Kind,Sha256,Sddl,Identity;
  public long Size;
 }
 public sealed class TreeLeaseV1 : IDisposable {
  [StructLayout(LayoutKind.Sequential)] struct Info {
   public uint Attributes; public System.Runtime.InteropServices.ComTypes.FILETIME C,A,W;
   public uint Volume,High,Low,Links,IndexHigh,IndexLow;
  }
  [StructLayout(LayoutKind.Sequential)] struct Disposition { public byte Delete; }
  [StructLayout(LayoutKind.Sequential,CharSet=CharSet.Unicode)] struct StreamInfo {
   public long Size; [MarshalAs(UnmanagedType.ByValTStr,SizeConst=296)] public string Name;
  }
  [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern SafeFileHandle CreateFile(string p,uint access,uint share,IntPtr sa,uint mode,uint flags,IntPtr template);
  [DllImport("kernel32.dll",SetLastError=true)] static extern bool GetFileInformationByHandle(SafeFileHandle h,out Info i);
  [DllImport("kernel32.dll",SetLastError=true)] static extern bool DeviceIoControl(SafeFileHandle h,uint code,IntPtr input,uint inputSize,byte[] output,uint outputSize,out uint returned,IntPtr overlap);
  [DllImport("kernel32.dll",SetLastError=true)] static extern bool SetFileInformationByHandle(SafeFileHandle h,int c,ref Disposition d,uint size);
  [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern bool CreateDirectory(string p,IntPtr sa);
  [DllImport("advapi32.dll",SetLastError=true)] static extern uint GetSecurityInfo(SafeFileHandle h,int kind,uint flags,out IntPtr owner,out IntPtr group,out IntPtr dacl,out IntPtr sacl,out IntPtr sd);
  [DllImport("advapi32.dll")] static extern uint GetSecurityDescriptorLength(IntPtr sd);
  [DllImport("kernel32.dll")] static extern IntPtr LocalFree(IntPtr p);
  [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern IntPtr FindFirstStreamW(string p,int level,out StreamInfo data,uint flags);
  [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern bool FindNextStreamW(IntPtr h,out StreamInfo data);
  [DllImport("kernel32.dll")] static extern bool FindClose(IntPtr h);
  sealed class Entry { public SafeFileHandle H; public RowV1 R; public bool Delete; }
  readonly List<Entry> entries=new List<Entry>();
  public readonly List<RowV1> Rows=new List<RowV1>();
  long bytes;
  static void Fail(string code){throw new InvalidOperationException(code);}
  static void NativeFail(){throw new Win32Exception(Marshal.GetLastWin32Error());}
  static string Sddl(SafeFileHandle h){
   IntPtr o,g,d,s,sd;uint code=GetSecurityInfo(h,1,7,out o,out g,out d,out s,out sd);
   if(code!=0)throw new Win32Exception((int)code);
   try{var b=new byte[GetSecurityDescriptorLength(sd)];Marshal.Copy(sd,b,0,b.Length);return new RawSecurityDescriptor(b,0).GetSddlForm(AccessControlSections.Owner|AccessControlSections.Group|AccessControlSections.Access);}
   finally{LocalFree(sd);}
  }
  static void NoStreams(string path){
   StreamInfo info;IntPtr h=FindFirstStreamW(path,0,out info,0);
   if(h==new IntPtr(-1)){if(Marshal.GetLastWin32Error()==38)return;NativeFail();}
   try{do{if(info.Name!="::$DATA")Fail("STAGING_ALTERNATE_STREAM_REJECTED");}while(FindNextStreamW(h,out info));if(Marshal.GetLastWin32Error()!=38)NativeFail();}
   finally{FindClose(h);}
  }
  Entry Open(string path,string relative,bool dir,bool delete,bool record){
   // Do not share file writes or renames. Directory handles pin ancestors.
   uint access=0x20080u|(dir?0u:0x80000000u)|(delete?0x10000u:0u);
   var h=CreateFile(path,access,dir?3u:1u,IntPtr.Zero,3,0x02200000,IntPtr.Zero);
   if(h.IsInvalid){h.Dispose();NativeFail();}
   try{
    Info i;if(!GetFileInformationByHandle(h,out i))NativeFail();
    if((i.Attributes&0x400)!=0 || ((i.Attributes&16)!=0)!=dir)Fail("STAGING_REPARSE_OR_KIND_REJECTED");
    if(!dir && i.Links!=1)Fail("STAGING_HARDLINK_REJECTED");
    if(record || !dir)NoStreams(path);
    long size=dir?0:((long)i.High<<32)|i.Low;
    if(!dir&&(size<1||size>1048576))Fail("STAGING_FILE_LIMIT");
    string hash="";
    if(!dir){
     using(var alias=new SafeFileHandle(h.DangerousGetHandle(),false))
     using(var fs=new FileStream(alias,FileAccess.Read))
     using(var sha=SHA256.Create()){hash=BitConverter.ToString(sha.ComputeHash(fs)).Replace("-","").ToLowerInvariant();}
    }
    var row=new RowV1{Path=relative,Kind=dir?"directory":"file",Size=size,Sha256=hash,Sddl=Sddl(h),Identity=i.Volume.ToString("x8")+":"+i.IndexHigh.ToString("x8")+i.IndexLow.ToString("x8")};
    var e=new Entry{H=h,R=row,Delete=delete};entries.Add(e);
    if(record){Rows.Add(row);bytes+=size;if(Rows.Count>32||bytes>4194304)Fail("STAGING_TREE_LIMIT");}
    return e;
   }catch{h.Dispose();throw;}
  }
  public void PinAncestors(string path){
   string full=System.IO.Path.GetFullPath(path);
   if(!String.Equals(full,path,StringComparison.OrdinalIgnoreCase)||full.Length>2000||full.StartsWith(@"\\?\")||full.StartsWith(@"\\.\"))Fail("STAGING_PATH_REJECTED");
   var parts=new Stack<string>();string cur=full;string root=System.IO.Path.GetPathRoot(full);
   while(cur!=null){parts.Push(cur);if(String.Equals(cur.TrimEnd('\\'),root.TrimEnd('\\'),StringComparison.OrdinalIgnoreCase))break;string next=System.IO.Path.GetDirectoryName(cur);if(next==cur)break;cur=next;}
   while(parts.Count>0)Open(parts.Pop(),"",true,false,false);
  }
  Info PinSysvolJunction(string part,string target){
   var h=CreateFile(part,0x20080u,1u,IntPtr.Zero,3,0x02200000,IntPtr.Zero);
    if(h.IsInvalid){h.Dispose();NativeFail();}
    try{
     Info i;if(!GetFileInformationByHandle(h,out i))NativeFail();
     if((i.Attributes&0x410)!=0x410)Fail("STAGING_SYSVOL_JUNCTION_REQUIRED");
     var b=new byte[16384];uint n;
     if(!DeviceIoControl(h,0x900A8u,IntPtr.Zero,0,b,(uint)b.Length,out n,IntPtr.Zero))NativeFail();
     if(n<16||BitConverter.ToUInt32(b,0)!=0xA0000003u||BitConverter.ToUInt16(b,4)+8!=n)Fail("STAGING_SYSVOL_JUNCTION_REJECTED");
     int at=BitConverter.ToUInt16(b,8),size=BitConverter.ToUInt16(b,10),printAt=BitConverter.ToUInt16(b,12),printSize=BitConverter.ToUInt16(b,14);
     if((at|size|printAt|printSize)%2!=0||size<8||16+at+size>n||16+printAt+printSize>n)Fail("STAGING_SYSVOL_JUNCTION_REJECTED");
     var utf=new System.Text.UnicodeEncoding(false,false,true);
     string substitute=utf.GetString(b,16+at,size),print=utf.GetString(b,16+printAt,printSize);
     if(!String.Equals(substitute,@"\??\"+target,StringComparison.OrdinalIgnoreCase)||
        (printSize!=0&&!String.Equals(print,target,StringComparison.OrdinalIgnoreCase)))Fail("STAGING_SYSVOL_TARGET_REJECTED");
     entries.Add(new Entry{H=h,R=new RowV1{Path="",Kind="directory"},Delete=false});h=null;
    }finally{if(h!=null)h.Dispose();}
   Info result;if(!GetFileInformationByHandle(entries[entries.Count-1].H,out result))NativeFail();return result;
  }
  // Trusted local-PDC adapter only. The caller supplies an independently
  // derived, fixed local SYSVOL target, never a value from a job/request.
  // Pin local AND SMB junction handles (without write/delete sharing) and the local
  // physical target; prove that following SMB reaches that same NTFS object.
  // Generic PinAncestors and every descendant still reject all reparse points.
  public void PinLocalSysvolAncestors(string path,string anchor,string localAnchor,string localTarget){
   string full=System.IO.Path.GetFullPath(path),link=System.IO.Path.GetFullPath(anchor),local=System.IO.Path.GetFullPath(localAnchor),target=System.IO.Path.GetFullPath(localTarget);
   if(!String.Equals(full,path,StringComparison.OrdinalIgnoreCase)||!String.Equals(link,anchor,StringComparison.OrdinalIgnoreCase)||
      !String.Equals(target,localTarget,StringComparison.OrdinalIgnoreCase)||!String.Equals(local,localAnchor,StringComparison.OrdinalIgnoreCase)||full.Length>2000||link.Length>2000||target.Length>2000||local.Length>2000||
      !link.StartsWith(@"\\")||link.StartsWith(@"\\?\")||link.StartsWith(@"\\.\")||
      target.StartsWith(@"\\")||local.StartsWith(@"\\")||System.IO.Path.GetPathRoot(target).Length!=3||System.IO.Path.GetPathRoot(local).Length!=3||
      !(String.Equals(full,link,StringComparison.OrdinalIgnoreCase)||full.StartsWith(link+"\\",StringComparison.OrdinalIgnoreCase)))Fail("STAGING_SYSVOL_ANCHOR_REJECTED");
   PinAncestors(target);
   Info expected;if(!GetFileInformationByHandle(entries[entries.Count-1].H,out expected))NativeFail();
   PinAncestors(System.IO.Path.GetDirectoryName(local));
   Info localLink=PinSysvolJunction(local,target);
   var parts=new Stack<string>();string cur=full,root=System.IO.Path.GetPathRoot(full);
   while(cur!=null){parts.Push(cur);if(String.Equals(cur.TrimEnd('\\'),root.TrimEnd('\\'),StringComparison.OrdinalIgnoreCase))break;string next=System.IO.Path.GetDirectoryName(cur);if(next==cur)break;cur=next;}
   bool seen=false;
   while(parts.Count>0){
    string part=parts.Pop();
    if(!String.Equals(part,link,StringComparison.OrdinalIgnoreCase)){Open(part,"",true,false,false);continue;}
    seen=true;
    Info remoteLink=PinSysvolJunction(part,target);
    if(remoteLink.Volume!=localLink.Volume||remoteLink.IndexHigh!=localLink.IndexHigh||remoteLink.IndexLow!=localLink.IndexLow)Fail("STAGING_SYSVOL_JUNCTION_IDENTITY_REJECTED");
    var followed=CreateFile(part,0x20080u,3u,IntPtr.Zero,3,0x02000000,IntPtr.Zero);
    if(followed.IsInvalid){followed.Dispose();NativeFail();}
    try{
     Info actual;if(!GetFileInformationByHandle(followed,out actual))NativeFail();
     if((actual.Attributes&0x410)!=0x10||actual.Volume!=expected.Volume||actual.IndexHigh!=expected.IndexHigh||actual.IndexLow!=expected.IndexLow)Fail("STAGING_SYSVOL_IDENTITY_REJECTED");
     entries.Add(new Entry{H=followed,R=new RowV1{Path="",Kind="directory"},Delete=false});followed=null;
    }finally{if(followed!=null)followed.Dispose();}
   }
   if(!seen)Fail("STAGING_SYSVOL_ANCHOR_REJECTED");
  }
  void Walk(string path,string relative,bool delete,int depth){
   if(depth>3)Fail("STAGING_DEPTH_LIMIT");
   Open(path,relative,true,delete,true);
   foreach(string child in Directory.EnumerateFileSystemEntries(path)){
    string name=System.IO.Path.GetFileName(child);
    if(name.Length>180||name.Contains(":")||name.EndsWith(".")||name.EndsWith(" "))Fail("STAGING_PATH_REJECTED");
    string rel=relative.Length==0?name:relative+"/"+name;
    bool dir=(File.GetAttributes(child)&FileAttributes.Directory)!=0;
    if(dir)Walk(child,rel,delete,depth+1);else Open(child,rel,false,delete,true);
   }
  }
  public static TreeLeaseV1 Tree(string path,bool delete){
   var v=new TreeLeaseV1();try{v.Walk(path,"",delete,0);v.Rows.Sort((a,b)=>StringComparer.Ordinal.Compare(a.Path,b.Path));return v;}catch{v.Dispose();throw;}
  }
  public void PinFile(string path){Open(path,"",false,false,false);}
  public static TreeLeaseV1 OwnedLockFile(string path){
   var v=new TreeLeaseV1();try{v.Open(path,"lock",false,true,true);return v;}catch{v.Dispose();throw;}
  }
  public void PinDirectory(string path){Open(path,"",true,false,false);NoStreams(path);}
  // Read through the already held lease; no second pathname open can replace
  // the bytes between reviewed ownership and a local history archive copy.
  public byte[] ReadOwnedBytes(string relative){
   foreach(var e in entries){
    if(e.R.Path!=relative || e.R.Kind!="file")continue;
    if(!e.Delete || e.R.Size<1 || e.R.Size>65536)Fail("STAGING_ARCHIVE_LEASE_REQUIRED");
    var data=new byte[(int)e.R.Size];
    using(var alias=new SafeFileHandle(e.H.DangerousGetHandle(),false))
    using(var fs=new FileStream(alias,FileAccess.Read)){
     fs.Position=0;int at=0;
     while(at<data.Length){int n=fs.Read(data,at,data.Length-at);if(n==0)Fail("STAGING_ARCHIVE_READ_FAILED");at+=n;}
     if(fs.ReadByte()!=-1)Fail("STAGING_ARCHIVE_READ_FAILED");
    }
    using(var sha=SHA256.Create()){
     if(BitConverter.ToString(sha.ComputeHash(data)).Replace("-","").ToLowerInvariant()!=e.R.Sha256)Fail("STAGING_ARCHIVE_BYTES_CHANGED");
    }
    return data;
   }
   Fail("STAGING_ARCHIVE_FILE_REJECTED");return null;
  }
  public static void CreateNewDirectory(string path){if(!CreateDirectory(path,IntPtr.Zero))NativeFail();}
  public static void AssertRollbackDeadline(long notAfter,long startedAt,long startedTicks){
   // UTC bounds the original grant; monotonic time prevents a clock setback
   // from restarting its budget. Zero/omitted/unbounded rollback is forbidden.
   long now=DateTimeOffset.UtcNow.ToUnixTimeSeconds();
   long ticks=System.Diagnostics.Stopwatch.GetTimestamp();
   if(startedAt<=0 || notAfter<=startedAt || notAfter-startedAt>30 ||
      startedTicks<=0 || ticks<startedTicks || now<startedAt || now>=notAfter ||
      (ticks-startedTicks)/(double)System.Diagnostics.Stopwatch.Frequency>=notAfter-startedAt)
    Fail("STAGING_ROLLBACK_AUTHORIZATION_EXPIRED");
  }
  public void DeleteOwnedTreeBefore(long notAfter,long startedAt,long startedTicks){
   // All rows were compared with the complete ownership journal before this call.
   // No recursive delete or pathname delete is used. Added foreign children make
   // a directory delete fail; they are never traversed or removed.
   AssertRollbackDeadline(notAfter,startedAt,startedTicks);
   var ordered=new List<Entry>(entries);ordered.Sort((a,b)=>{int x=b.R.Path.Length.CompareTo(a.R.Path.Length);return x!=0?x:StringComparer.Ordinal.Compare(b.R.Path,a.R.Path);});
   // Validate every lease BEFORE the first deletion, then stop initiating
   // mutations as soon as either clock bound fails. An in-flight SMB operation
   // may still finish later; this is not a hard I/O cancellation guarantee.
   foreach(var e in ordered){if(!e.Delete)Fail("STAGING_DELETE_LEASE_REQUIRED");}
   foreach(var e in ordered){
    AssertRollbackDeadline(notAfter,startedAt,startedTicks);
    var d=new Disposition{Delete=1};if(!SetFileInformationByHandle(e.H,4,ref d,1))NativeFail();e.H.Dispose();
    AssertRollbackDeadline(notAfter,startedAt,startedTicks);
   }
  }
  public void Dispose(){for(int i=entries.Count-1;i>=0;i--)entries[i].H.Dispose();entries.Clear();}
 }
}
'@
}

function Add-AuthWireStagingGpoPins($Pins,[string]$Path,[string]$GpoRoot){
 # The canonical UNC root was independently derived from fresh AD/PDC/GPO
 # observations. Only a Connector running on THAT PDC may handle its standard
 # domain junction; custom locations/remote PDCs keep the existing rejection.
 $pattern='\A\\\\(?<pdc>[a-z0-9][a-z0-9.-]{0,252})\\SYSVOL\\(?<domain>[a-z0-9][a-z0-9.-]{0,252})\\Policies\\\{[0-9a-f-]{36}\}\z'
 $m=[regex]::Match($GpoRoot,$pattern,[Text.RegularExpressions.RegexOptions]::CultureInvariant)
 if(-not $m.Success){$Pins.PinAncestors($Path);return}
 if($Path -cne $GpoRoot -and -not $Path.StartsWith($GpoRoot+'\',[StringComparison]::Ordinal)){throw 'STAGING_GPO_PIN_BOUNDARY_REJECTED'}
 $anchor='\\'+$m.Groups['pdc'].Value+'\SYSVOL\'+$m.Groups['domain'].Value
 # This observation cannot authorize a race: generic pinning rejects a new
 # reparse point, and the special pin verifies the held reparse object again.
 if(-not (([IO.File]::GetAttributes($anchor)) -band [IO.FileAttributes]::ReparsePoint)){$Pins.PinAncestors($Path);return}
 $local=[Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties()
 $fqdn=($local.HostName+'.'+$local.DomainName).ToLowerInvariant()
 if($local.DomainName.ToLowerInvariant() -cne $m.Groups['domain'].Value -or $fqdn -cne $m.Groups['pdc'].Value){throw 'STAGING_LOCAL_PDC_REQUIRED'}
 $target=Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::Windows)) 'SYSVOL\domain'
 $localAnchor=Join-Path ([Environment]::GetFolderPath([Environment+SpecialFolder]::Windows)) ('SYSVOL\sysvol\'+$m.Groups['domain'].Value)
 $Pins.PinLocalSysvolAncestors($Path,$anchor,$localAnchor,$target)
}

function Get-AuthWireStagingFilesystemRows($Lease){
 return @(foreach($r in $Lease.Rows){[pscustomobject][ordered]@{Path=$r.Path;Kind=$r.Kind;Size=[long]$r.Size;Sha256=$r.Sha256;Sddl=$r.Sddl;Identity=$r.Identity}})
}
function Get-AuthWireStagingFilesystemDigest($Rows){
 return (Get-AuthWireScopeDataHash @($Rows))
}
function Assert-AuthWireStagingJournalRoot([string]$Path){
 # Caller provisions this LOCAL directory. Never weaken an existing ACL.
 $null=Assert-AuthWireCandidatePath $Path
 $item=Get-Item -LiteralPath $Path -Force -ErrorAction Stop
 if(-not $item.PSIsContainer){throw 'STAGING_JOURNAL_ROOT_REQUIRED'}
 $identity=[Security.Principal.WindowsIdentity]::GetCurrent()
 try{$sid=$identity.User.Value}finally{$identity.Dispose()}
 $acl=Get-Acl -LiteralPath $Path -ErrorAction Stop
 if(-not $acl.AreAccessRulesProtected -or $acl.GetOwner([Security.Principal.SecurityIdentifier]).Value -cnotin @($sid,'S-1-5-18','S-1-5-32-544')){throw 'STAGING_JOURNAL_ACL_REJECTED'}
 foreach($ace in $acl.GetAccessRules($true,$true,[Security.Principal.SecurityIdentifier])){
  if($ace.AccessControlType -ne 'Allow' -or $ace.IdentityReference.Value -cnotin @($sid,'S-1-5-18','S-1-5-32-544')){throw 'STAGING_JOURNAL_ACL_REJECTED'}
 }
}
function Write-AuthWireStagingJournal([string]$Path,$Value){
 $bytes=[Text.UTF8Encoding]::new($false,$true).GetBytes(($Value|ConvertTo-Json -Depth 12 -Compress))
 if($bytes.Length -gt 65536){throw 'STAGING_JOURNAL_LIMIT'}
 $s=[IO.File]::Open($Path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
 try{$s.Write($bytes,0,$bytes.Length);$s.Flush($true)}finally{$s.Dispose()}
}
function Read-AuthWireStagingJournal([string]$Path){
 return (ConvertFrom-AuthWireCandidateJson (Read-AuthWireCandidateBytes $Path 65536))
}
function Assert-AuthWireStagingFilesystemContext($Target,$PreviewRecord,[string]$ApprovedPreviewSha256,[string]$GpoRoot,[string]$ProtectedGpoId){
 Assert-AuthWireCombinedScopeTarget $Target
 Assert-AuthWireCandidateGuid $ProtectedGpoId
 if($Target.gpo_id -ceq $ProtectedGpoId -or [IO.Path]::GetFileName($GpoRoot) -cne ('{'+$Target.gpo_id+'}')){throw 'STAGING_GPO_BOUNDARY_REJECTED'}
 Assert-AuthWireCandidateFields $PreviewRecord @('Preview','PreviewSha256')
 $p=$PreviewRecord.Preview
 if($ApprovedPreviewSha256 -cnotmatch '\A[0-9a-f]{64}\z' -or $PreviewRecord.PreviewSha256 -cne $ApprovedPreviewSha256 -or (Get-AuthWireScopeDataHash $p) -cne $ApprovedPreviewSha256){throw 'STAGING_APPROVAL_HASH_REQUIRED'}
 $now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
 if($p.checked_at -gt $now -or $p.expires_at -le $now -or $p.expires_at-$p.checked_at -ne 90){throw 'STAGING_PREVIEW_EXPIRED'}
 $relative='Machine/AuthWire-'+([guid]$Target.plan_id).ToString('N')+'-v'+$Target.plan_version+'-'+$Target.manifest_sha256
 if($p.relative_destination -cne $relative -or $p.scope_target_sha256 -cne (Get-AuthWireCombinedScopeTargetHash $Target)){throw 'STAGING_TARGET_CHANGED'}
 return $relative
}
function Assert-AuthWireStagingWriteDeadline([long]$NotAfter,[long]$StartedAt,$Timer){
 # Zero is retained only for the historical low-level fixture interface.
 # The authorized stage adapter always supplies the original grant expiry.
 if($NotAfter -eq 0){return}
 $now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
 if($NotAfter -le $StartedAt -or $now -lt $StartedAt -or $now -ge $NotAfter -or $Timer.ElapsedMilliseconds -ge ($NotAfter-$StartedAt)*1000){throw 'STAGING_AUTHORIZATION_EXPIRED'}
}
function Invoke-AuthWireStagingFilesystemStage {
 [CmdletBinding()]
 param($Target,$PreviewRecord,[string]$ApprovedPreviewSha256,[string]$SourceRoot,[string]$GpoRoot,[string]$JournalRoot,[string]$OperationId,[string]$ProtectedGpoId,[long]$NotAfter=0)
 # Low-level engine for a trusted future adapter. These paths must NEVER be
 # forwarded from a network request. This function does not authorize AD writes.
 Initialize-AuthWireStagingFilesystemTypes
 Assert-AuthWireCandidateGuid $OperationId
 $relative=Assert-AuthWireStagingFilesystemContext $Target $PreviewRecord $ApprovedPreviewSha256 $GpoRoot $ProtectedGpoId
 Assert-AuthWireStagingJournalRoot $JournalRoot
 $clockStart=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds();$writeClock=[Diagnostics.Stopwatch]::StartNew()
 Assert-AuthWireStagingWriteDeadline $NotAfter $clockStart $writeClock
 $pins=[AuthWire.Staging.TreeLeaseV1]::new();$source=$null;$staged=$null;$journalPins=$null
 try{
  Add-AuthWireStagingGpoPins $pins $GpoRoot $GpoRoot;Add-AuthWireStagingGpoPins $pins ([IO.Path]::Combine($GpoRoot,'Machine')) $GpoRoot
  $pins.PinAncestors($SourceRoot);$pins.PinAncestors($JournalRoot)
  $source=[AuthWire.Staging.TreeLeaseV1]::Tree($SourceRoot,$false)
  $sourceRows=Get-AuthWireStagingFilesystemRows $source
  $sourceFiles=@(foreach($r in $sourceRows|Where-Object Kind -eq 'file'){[pscustomobject][ordered]@{Path=$r.Path;Size=[long]$r.Size;Sha256=$r.Sha256;Sddl=$r.Sddl}})
  if(@($sourceRows|Where-Object Kind -eq 'directory').Count -ne 3 -or @($sourceRows|Where-Object {$_.Kind -ceq 'directory' -and $_.Path -cnotin @('','enrollment','network')}).Count){throw 'STAGING_SOURCE_TREE_REJECTED'}
  $baseline=Get-AuthWireSysvolInventory $GpoRoot
  $recomputed=New-AuthWireCombinedStagingPlanCore $Target $sourceFiles $baseline $PreviewRecord.Preview.scope_observations_sha256 $PreviewRecord.Preview.checked_at
  if($recomputed.PreviewSha256 -cne $ApprovedPreviewSha256){throw 'STAGING_PREVIEW_CHANGED'}
  $destination=[IO.Path]::Combine($GpoRoot,$relative.Replace('/','\'))
  if(Test-Path -LiteralPath $destination){throw 'STAGING_DESTINATION_EXISTS'}
  $journal=Join-Path $JournalRoot $OperationId
  Assert-AuthWireStagingWriteDeadline $NotAfter $clockStart $writeClock
  [AuthWire.Staging.TreeLeaseV1]::CreateNewDirectory($journal)
  $journalPins=[AuthWire.Staging.TreeLeaseV1]::new();$journalPins.PinAncestors($journal)
  $intent=[pscustomobject][ordered]@{format='AuthWireFilesystemIntentV1';operation_id=$OperationId;preview_sha256=$ApprovedPreviewSha256;target_sha256=(Get-AuthWireCombinedScopeTargetHash $Target);gpo_root=$GpoRoot;relative_destination=$relative;baseline_sha256=$baseline.Sha256;protected_gpo_id=$ProtectedGpoId}
  Write-AuthWireStagingJournal (Join-Path $journal 'intent.json') $intent
  # Recheck expiry immediately before creating anything in the GPO tree.
  $null=Assert-AuthWireStagingFilesystemContext $Target $PreviewRecord $ApprovedPreviewSha256 $GpoRoot $ProtectedGpoId
  if((Get-AuthWireSysvolInventory $GpoRoot).Sha256 -cne $baseline.Sha256){throw 'STAGING_BASELINE_CHANGED'}
  Assert-AuthWireStagingWriteDeadline $NotAfter $clockStart $writeClock
  [AuthWire.Staging.TreeLeaseV1]::CreateNewDirectory($destination)
  Add-AuthWireStagingGpoPins $pins $destination $GpoRoot
  foreach($d in @('enrollment','network')){Assert-AuthWireStagingWriteDeadline $NotAfter $clockStart $writeClock;[AuthWire.Staging.TreeLeaseV1]::CreateNewDirectory(([IO.Path]::Combine($destination,$d)));Add-AuthWireStagingGpoPins $pins ([IO.Path]::Combine($destination,$d)) $GpoRoot}
  foreach($r in $PreviewRecord.Preview.files){
   Assert-AuthWireStagingWriteDeadline $NotAfter $clockStart $writeClock
   $from=[IO.Path]::Combine($SourceRoot,$r.Path.Replace('/','\'));$to=[IO.Path]::Combine($destination,$r.Path.Replace('/','\'))
   $bytes=[IO.File]::ReadAllBytes($from)
   if($bytes.Length -ne $r.Size -or (Get-AuthWireCandidateHash $bytes) -cne $r.Sha256){throw 'STAGING_SOURCE_CHANGED'}
   Assert-AuthWireStagingWriteDeadline $NotAfter $clockStart $writeClock
   $stream=[IO.File]::Open($to,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
   try{$stream.Write($bytes,0,$bytes.Length);$stream.Flush($true)}finally{$stream.Dispose()}
   Assert-AuthWireStagingWriteDeadline $NotAfter $clockStart $writeClock
  }
  $staged=[AuthWire.Staging.TreeLeaseV1]::Tree($destination,$false)
  $rows=Get-AuthWireStagingFilesystemRows $staged
  if($rows.Count -ne 23){throw 'STAGING_POSTCHECK_REQUIRES_REVIEW'}
  foreach($r in $PreviewRecord.Preview.files){$found=@($rows|Where-Object {$_.Path -ceq $r.Path -and $_.Kind -ceq 'file'});if($found.Count -ne 1 -or $found[0].Size -ne $r.Size -or $found[0].Sha256 -cne $r.Sha256){throw 'STAGING_POSTCHECK_REQUIRES_REVIEW'}}
  $all=Get-AuthWireSysvolInventory $GpoRoot
  $outside=@($all.Entries|Where-Object {$_.Path -cne $relative -and -not $_.Path.StartsWith($relative+'/',[StringComparison]::Ordinal)})
  if((Get-AuthWireScopeDataHash $outside) -cne $baseline.Sha256){throw 'STAGING_OUTSIDE_CHANGED_REQUIRES_REVIEW'}
  $complete=[pscustomobject][ordered]@{format='AuthWireFilesystemCompleteV1';operation_id=$OperationId;intent_sha256=(Get-AuthWireScopeDataHash $intent);tree_sha256=(Get-AuthWireStagingFilesystemDigest $rows);tree=$rows;baseline=$baseline.Entries}
  Assert-AuthWireStagingWriteDeadline $NotAfter $clockStart $writeClock
  Write-AuthWireStagingJournal (Join-Path $journal 'complete.json') $complete
  Assert-AuthWireStagingWriteDeadline $NotAfter $clockStart $writeClock
  return [pscustomobject]@{Phase='staged';OperationId=$OperationId;RelativeDestination=$relative;FileCount=20;CanApplyGpo=$false;JournalPath=$journal}
 }finally{if($staged){$staged.Dispose()};if($source){$source.Dispose()};if($journalPins){$journalPins.Dispose()};$pins.Dispose()}
 # Interrupted/failed transactions leave intent and any partial tree for review.
 # Never guess ownership or recursively clean an incomplete transaction.
}
function Invoke-AuthWireStagingFilesystemRollback {
 [CmdletBinding()]
 param([string]$GpoRoot,[string]$JournalRoot,[string]$OperationId,[string]$ApprovedCompleteSha256,[long]$NotAfter)
 # This trusted engine requires a positive original deadline on EVERY call.
 # It does not mint/renew a grant or authenticate the caller. The separate
 # rollback CLAIM/consumption/child/RESULT adapter is still unavailable.
 $clockStart=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds();$startedTicks=[Diagnostics.Stopwatch]::GetTimestamp()
 Initialize-AuthWireStagingFilesystemTypes
 [AuthWire.Staging.TreeLeaseV1]::AssertRollbackDeadline($NotAfter,$clockStart,$startedTicks)
 Assert-AuthWireCandidateGuid $OperationId
 Assert-AuthWireStagingJournalRoot $JournalRoot
 $pins=[AuthWire.Staging.TreeLeaseV1]::new();$owned=$null
 try{
  Add-AuthWireStagingGpoPins $pins $GpoRoot $GpoRoot;Add-AuthWireStagingGpoPins $pins ([IO.Path]::Combine($GpoRoot,'Machine')) $GpoRoot;$pins.PinAncestors($JournalRoot)
  $journal=Join-Path $JournalRoot $OperationId;$pins.PinAncestors($journal)
  foreach($n in @('intent.json','complete.json')){$pins.PinFile((Join-Path $journal $n))}
  if(Test-Path -LiteralPath (Join-Path $journal 'rolled-back.json')){throw 'STAGING_ROLLBACK_ALREADY_RECORDED'}
  if(Test-Path -LiteralPath (Join-Path $journal 'rollback-started.json')){throw 'STAGING_ROLLBACK_INCOMPLETE_REQUIRES_REVIEW'}
  $intent=Read-AuthWireStagingJournal (Join-Path $journal 'intent.json');$complete=Read-AuthWireStagingJournal (Join-Path $journal 'complete.json')
  Assert-AuthWireCandidateFields $intent @('format','operation_id','preview_sha256','target_sha256','gpo_root','relative_destination','baseline_sha256','protected_gpo_id')
  Assert-AuthWireCandidateFields $complete @('format','operation_id','intent_sha256','tree_sha256','tree','baseline')
  $relative=$intent.relative_destination
  if($intent.format -cne 'AuthWireFilesystemIntentV1' -or $complete.format -cne 'AuthWireFilesystemCompleteV1' -or $intent.operation_id -cne $OperationId -or $complete.operation_id -cne $OperationId -or $intent.gpo_root -cne $GpoRoot -or $relative -cnotmatch '\AMachine/AuthWire-[0-9a-f]{32}-v[1-9][0-9]{0,5}-[0-9a-f]{64}\z'){throw 'STAGING_JOURNAL_REJECTED'}
  if($ApprovedCompleteSha256 -cnotmatch '\A[0-9a-f]{64}\z' -or (Get-AuthWireScopeDataHash $complete) -cne $ApprovedCompleteSha256 -or (Get-AuthWireScopeDataHash $intent) -cne $complete.intent_sha256 -or (Get-AuthWireStagingFilesystemDigest $complete.tree) -cne $complete.tree_sha256 -or (Get-AuthWireScopeDataHash @($complete.baseline)) -cne $intent.baseline_sha256){throw 'STAGING_ROLLBACK_APPROVAL_REQUIRED'}
  $all=Get-AuthWireSysvolInventory $GpoRoot
  $outside=@($all.Entries|Where-Object {$_.Path -cne $relative -and -not $_.Path.StartsWith($relative+'/',[StringComparison]::Ordinal)})
  if((Get-AuthWireScopeDataHash $outside) -cne $intent.baseline_sha256){throw 'STAGING_OUTSIDE_DRIFT_REJECTED'}
  $owned=[AuthWire.Staging.TreeLeaseV1]::Tree(([IO.Path]::Combine($GpoRoot,$relative.Replace('/','\'))),$true)
  $rows=Get-AuthWireStagingFilesystemRows $owned
  if((Get-AuthWireStagingFilesystemDigest $rows) -cne $complete.tree_sha256){throw 'STAGING_ROLLBACK_DRIFT_REJECTED'}
  [AuthWire.Staging.TreeLeaseV1]::AssertRollbackDeadline($NotAfter,$clockStart,$startedTicks)
  Write-AuthWireStagingJournal (Join-Path $journal 'rollback-started.json') ([pscustomobject]@{format='AuthWireFilesystemRollbackIntentV2';operation_id=$OperationId;complete_sha256=$ApprovedCompleteSha256;started_at=$clockStart;expires_at=$NotAfter})
  # Even a marker flush that consumes the remaining grant must not delete.
  # Once written, this marker prevents every automatic replay, including an
  # otherwise valid new deadline. Partial/expired outcomes require review.
  [AuthWire.Staging.TreeLeaseV1]::AssertRollbackDeadline($NotAfter,$clockStart,$startedTicks)
  $owned.DeleteOwnedTreeBefore($NotAfter,$clockStart,$startedTicks);$owned.Dispose();$owned=$null
  [AuthWire.Staging.TreeLeaseV1]::AssertRollbackDeadline($NotAfter,$clockStart,$startedTicks)
  if((Get-AuthWireSysvolInventory $GpoRoot).Sha256 -cne $intent.baseline_sha256){throw 'STAGING_ROLLBACK_POSTCHECK_REQUIRES_REVIEW'}
  [AuthWire.Staging.TreeLeaseV1]::AssertRollbackDeadline($NotAfter,$clockStart,$startedTicks)
  Write-AuthWireStagingJournal (Join-Path $journal 'rolled-back.json') ([pscustomobject]@{format='AuthWireFilesystemRollbackV1';operation_id=$OperationId;complete_sha256=$ApprovedCompleteSha256;baseline_restored=$true})
  [AuthWire.Staging.TreeLeaseV1]::AssertRollbackDeadline($NotAfter,$clockStart,$startedTicks)
  return [pscustomobject]@{Phase='rolled_back';OperationId=$OperationId;BaselineRestored=$true;CanApplyGpo=$false}
 }finally{if($owned){$owned.Dispose()};$pins.Dispose()}
}
