# Fixed scope queue and bounded, AllSigned read-only child. No GPO executor.
Set-StrictMode -Version 2
function Initialize-AuthWireScopeProcess {
 if('AuthWire.Connector.ScopeProcessV1' -as [type]){return}
 Add-Type -TypeDefinition @'
using System;
using System.Diagnostics;
using System.Text;
using System.Threading;
namespace AuthWire.Connector {
 public sealed class ScopeReadResultV1 {public bool TimedOut,Truncated;public int ExitCode;public string Output;}
 public static class ScopeProcessV1 {
  public static ScopeReadResultV1 Run(string executable,string arguments,int milliseconds){
   if(milliseconds<100||milliseconds>35000)throw new ArgumentException("READ_BUDGET_REJECTED");
   var result=new ScopeReadResultV1();var output=new StringBuilder();var error=new StringBuilder();object gate=new object();
   using(var p=new Process()){
    p.StartInfo=new ProcessStartInfo(executable,arguments){UseShellExecute=false,CreateNoWindow=true,RedirectStandardOutput=true,RedirectStandardError=true};
    p.Start();
    var stdout=System.Threading.Tasks.Task.Factory.StartNew(()=>Drain(p.StandardOutput,output,8192,gate,result));
    var stderr=System.Threading.Tasks.Task.Factory.StartNew(()=>Drain(p.StandardError,error,2048,gate,result));
    if(!p.WaitForExit(milliseconds)){result.TimedOut=true;try{p.Kill();}catch(InvalidOperationException){}if(!p.WaitForExit(3000))throw new InvalidOperationException("READ_CHILD_NOT_TERMINATED");}
    if(!System.Threading.Tasks.Task.WaitAll(new[]{stdout,stderr},3000))throw new InvalidOperationException("READ_DRAIN_TIMEOUT");
    result.ExitCode=p.ExitCode;lock(gate){result.Output=output.ToString();if(error.Length>0)result.ExitCode=20;}
    return result;
   }
  }
  static void Drain(System.IO.StreamReader reader,StringBuilder buffer,int limit,object gate,ScopeReadResultV1 result){
   var chars=new char[256];int n;while((n=reader.Read(chars,0,chars.Length))>0){lock(gate){if(buffer.Length+n>limit)result.Truncated=true;else buffer.Append(chars,0,n);}}
  }
 }
}
'@
}
function Get-AuthWireScopeTargetHash($Target){
 Assert-AuthWireScopeTarget $Target
 $v=[ordered]@{};foreach($n in @('approval_sha256','candidate_id','dependency_sha256','gpo_id','manifest_sha256','plan_id','plan_version','target_count','target_sids_sha256')){$v[$n]=$Target.$n}
 return (Get-AuthWireJobHash ([Text.UTF8Encoding]::new($false,$true).GetBytes(($v|ConvertTo-Json -Compress))))
}
function Get-AuthWireScopeIntent([string]$Scope,[string]$Id,[string]$Hash){
 return (Get-AuthWireJobHash ([Text.Encoding]::ASCII.GetBytes("AuthWireDeploymentScopeIntentV1`n"+$Scope+"`n"+$Id+"`n"+$Hash+"`n")))
}
function New-AuthWireScopeProof([hashtable]$Binding,[Security.Cryptography.RSACng]$Key,[ValidateSet('POLL','RESULT')][string]$Kind,[hashtable]$Payload){
 $h=New-AuthWireConnectorPollProof -Binding $Binding -ChannelKey $Key
 $f=[Text.Encoding]::ASCII.GetString([Convert]::FromBase64String($h.frame)).Split([char]10)
 $path=if($Kind -ceq 'POLL'){'/api/connector/v1/scope/poll'}else{'/api/connector/v1/scope/result'}
 $bytes=[Text.UTF8Encoding]::new($false,$true).GetBytes(($Payload|ConvertTo-Json -Compress))
 if($bytes.Length -gt 1024){throw 'SCOPE_PAYLOAD_REJECTED'}
 $raw=[Text.Encoding]::ASCII.GetBytes(((@('AUTHWIRE-SCOPE-JOB-'+$Kind+'-V1')+@($f[1..13])+@((Get-AuthWireJobHash $bytes),'POST',$path)) -join "`n")+"`n")
 $sig=$Key.SignData($raw,[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pkcs1)
 return @{frame=[Convert]::ToBase64String($raw);signature=[Convert]::ToBase64String($sig);payload=[Convert]::ToBase64String($bytes)}
}
function Invoke-AuthWireScopeReader($Target,[int]$BudgetMs){
 Initialize-AuthWireScopeProcess
 $path=Join-Path $PSScriptRoot 'Read-AuthWireDeploymentScope.ps1'
 $exe=Join-Path ([Environment]::GetFolderPath('Windows')) 'System32\WindowsPowerShell\v1.0\powershell.exe'
 $payload=[Convert]::ToBase64String([Text.UTF8Encoding]::new($false,$true).GetBytes(($Target|ConvertTo-Json -Compress)))
 return [AuthWire.Connector.ScopeProcessV1]::Run($exe,('-NoLogo -NoProfile -NonInteractive -ExecutionPolicy AllSigned -File "'+$path+'" -RequestBase64 '+$payload),$BudgetMs)
}
function Invoke-AuthWireScopeJob {
 param([string]$BaseUrl,[hashtable]$Binding,[Security.Cryptography.RSACng]$ChannelKey,[string]$PackageReleaseId)
 if(-not (Test-AuthWireJobGuid $PackageReleaseId)){throw 'SCOPE_RELEASE_REJECTED'}
 $p=New-AuthWireScopeProof $Binding $ChannelKey POLL @{capability='deployment.scope.verify.v1';release_id=$PackageReleaseId}
 $request=[Text.Encoding]::ASCII.GetString([Convert]::FromBase64String($p.frame)).Split([char]10)[10]
 $raw=[AuthWire.Connector.ChannelTypesV1]::Post($BaseUrl,$Binding.appliance_fqdn,$Binding.appliance_tls_sha256,'/api/connector/v1/scope/poll',($p|ConvertTo-Json -Compress))
 $offer=ConvertFrom-AuthWireCandidateJson ([Text.Encoding]::UTF8.GetBytes($raw))
 Assert-AuthWireCandidateFields $offer @('format','request_id','scope_sha256','job_id','operation','lease_id','intent_sha256','expires_at','target','read_only','can_apply')
 $scope=Get-AuthWireJobScope $Binding
 if($offer.format -isnot [int] -or $offer.format -ne 1 -or $offer.request_id -cne $request -or $offer.scope_sha256 -cne $scope -or $offer.read_only -isnot [bool] -or -not $offer.read_only -or $offer.can_apply -isnot [bool] -or $offer.can_apply){throw 'SCOPE_REPLY_REJECTED'}
 if($offer.job_id -ceq ''){
  if($offer.operation -cne '' -or $offer.lease_id -cne '' -or $offer.intent_sha256 -cne '' -or $offer.expires_at -isnot [int] -or $offer.expires_at -ne 0 -or $null -ne $offer.target){throw 'SCOPE_REPLY_REJECTED'}
  return [pscustomobject]@{ChannelVerified=$true;JobCompleted=$false;JobId='';Reason=''}
 }
 Assert-AuthWireScopeTarget $offer.target
 $hash=Get-AuthWireScopeTargetHash $offer.target;$now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
 if(-not (Test-AuthWireJobGuid $offer.job_id) -or $offer.operation -cne 'deployment.scope.verify.v1' -or $offer.lease_id -isnot [string] -or $offer.lease_id -cnotmatch '\A[0-9a-f]{64}\z' -or $offer.intent_sha256 -cne (Get-AuthWireScopeIntent $scope $offer.job_id $hash) -or ($offer.expires_at -isnot [int] -and $offer.expires_at -isnot [long]) -or $offer.expires_at -le $now+5 -or $offer.expires_at -gt $now+95){throw 'SCOPE_REPLY_REJECTED'}
 $reason='READ_FAILED';$checks=@();$observations=Get-AuthWireJobHash ([Text.Encoding]::ASCII.GetBytes('AuthWireScopeReadFailureV1:READ_FAILED'))
 try{
  $r=Invoke-AuthWireScopeReader $offer.target ([int][Math]::Min(30000,($offer.expires_at-$now-5)*1000))
  if($r.TimedOut){$reason='READ_TIMEOUT'}
  elseif(-not $r.Truncated -and $r.ExitCode -eq 0){
   $v=ConvertFrom-AuthWireCandidateJson ([Text.UTF8Encoding]::new($false,$true).GetBytes($r.Output))
   Assert-AuthWireCandidateFields $v @('checked_at','checks','reason','observations_sha256')
   if($v.checked_at -isnot [int] -and $v.checked_at -isnot [long]){throw 'SCOPE_READ_RESULT_REJECTED'}
   if($v.checked_at -lt $now -or $v.checked_at -gt [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() -or $v.reason -cnotin @('OK','CONTENT_REJECTED','DIRECTORY_SCOPE_CHANGED','GPO_SCOPE_CHANGED','READ_FAILED') -or $v.observations_sha256 -isnot [string] -or $v.observations_sha256 -cnotmatch '\A[0-9a-f]{64}\z' -or $v.checks -isnot [array]){throw 'SCOPE_READ_RESULT_REJECTED'}
   $expected=@('content','directory','gpo_identity','gpo_permissions','gpo_unlinked','gpo_empty','sysvol_root_acl')
   if(($v.reason -ceq 'OK' -and ($v.checks -join ';') -cne ($expected -join ';')) -or ($v.reason -cne 'OK' -and $v.checks.Count -ne 0)){throw 'SCOPE_READ_RESULT_REJECTED'}
   $reason=$v.reason;$checks=$v.checks;$observations=$v.observations_sha256
  }
 }catch{$reason='READ_FAILED';$checks=@()}
 $now=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds();if($now -ge $offer.expires_at){throw 'SCOPE_LEASE_EXPIRED'}
 if($reason -cne 'OK'){$checks=@();$observations=Get-AuthWireJobHash ([Text.Encoding]::ASCII.GetBytes('AuthWireScopeReadFailureV1:'+$reason))}
 $outcome=if($reason -ceq 'OK'){'scope_snapshot_verified'}else{'scope_snapshot_rejected'}
 $p=New-AuthWireScopeProof $Binding $ChannelKey RESULT @{job_id=$offer.job_id;lease_id=$offer.lease_id;intent_sha256=$offer.intent_sha256;outcome=$outcome;release_id=$PackageReleaseId;target_sha256=$hash;checked_at=$now;checks=@($checks);reason=$reason;observations_sha256=$observations}
 $request=[Text.Encoding]::ASCII.GetString([Convert]::FromBase64String($p.frame)).Split([char]10)[10]
 $raw=[AuthWire.Connector.ChannelTypesV1]::Post($BaseUrl,$Binding.appliance_fqdn,$Binding.appliance_tls_sha256,'/api/connector/v1/scope/result',($p|ConvertTo-Json -Compress))
 if(-not [AuthWire.Connector.ChannelTypesV1]::JobReceipt($raw)){throw 'SCOPE_RECEIPT_REJECTED'}
 $r=$raw|ConvertFrom-Json
 if($r.format -isnot [int] -or $r.format -ne 1 -or $r.request_id -cne $request -or $r.job_id -cne $offer.job_id -or $r.result_recorded -isnot [bool] -or -not $r.result_recorded -or $r.read_only -isnot [bool] -or -not $r.read_only -or $r.can_apply -isnot [bool] -or $r.can_apply){throw 'SCOPE_RECEIPT_REJECTED'}
 return [pscustomobject]@{ChannelVerified=$true;JobCompleted=$true;JobId=$offer.job_id;Reason=$reason}
}
