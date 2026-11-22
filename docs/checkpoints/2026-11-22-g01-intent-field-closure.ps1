#Requires -Version 5.1
$ErrorActionPreference='Stop';Set-StrictMode -Version 2
$root=$PSScriptRoot;$out=Join-Path $root 'output-intent-closure-20261122';$rsa=$null;$key=$null;$session=$null;$csrf=$null;$cred=$null
try{
 $active='C:\Program Files\AuthWire-Connector-4c23eebe071546d188eea2e96ad7ee46'
 $c=Get-Content -LiteralPath (Join-Path $active 'service.json') -Raw|ConvertFrom-Json
 if($c.ReleaseId -cne 'd3b84b6a-fe17-4d43-8a85-e3cc094550cf'){throw 'RECOVERY_RELEASE_CHANGED'}
 . (Join-Path $active 'Test-AuthWireDeploymentCandidate.ps1') -LibraryOnly
 foreach($file in @('Compare-AuthWireSigningKeyAcl.ps1','ConnectorChannelTypes.ps1','ConnectorChannelKey.ps1','New-AuthWireConnectorHealthProof.ps1','Invoke-AuthWireConnectorProbeJob.ps1','Invoke-AuthWireCandidateJob.ps1','DeploymentScope.ps1','Invoke-AuthWireScopeJob.ps1','CombinedCandidateContent.ps1','Invoke-AuthWireCombinedJob.ps1','CombinedDeploymentScope.ps1','Invoke-AuthWireCombinedScopeJob.ps1','SysvolInventory.ps1','CombinedStagingPreview.ps1','StagingFilesystem.ps1','StagingWritePreclaim.ps1','StagingWriteTransport.ps1','StagingWriteConsumption.ps1','StagingWriteProcess.ps1','StagingWriteExecution.ps1','StagingWriteResult.ps1','StagingWriteCycle.ps1','StagingRollbackEvidence.ps1','StagingRollbackAuthorization.ps1','StagingRollbackExecution.ps1','StagingRollbackResult.ps1','StagingWritePollRecord.ps1','StagingWriteLifecycle.ps1')){. (Join-Path $active $file)}
 Assert-AuthWireWriteServiceConfigFields $c
 $b=@{};foreach($p in $c.Binding.PSObject.Properties){$b[$p.Name]=$p.Value}
 $identity=[Security.Principal.WindowsIdentity]::GetCurrent();try{if($identity.User.Value -cne $b.service_sid){throw 'RECOVERY_IDENTITY_CHANGED'}}finally{$identity.Dispose()}
 $key=[Security.Cryptography.CngKey]::Open($c.KeyName,[Security.Cryptography.CngProvider]::MicrosoftSoftwareKeyStorageProvider,[Security.Cryptography.CngKeyOpenOptions]::MachineKey)
 $rsa=[Security.Cryptography.RSACng]::new($key)
 $keyPath=Join-Path (Join-Path $env:ProgramData 'Microsoft\Crypto\Keys') $key.UniqueName
 if(-not (Compare-AuthWireSigningKeyAcl $c.ExpectedKeySddl (Get-Acl -LiteralPath $keyPath).Sddl).AclEquivalent){throw 'RECOVERY_KEY_ACL_CHANGED'}
 Initialize-AuthWireStagingFilesystemTypes;Initialize-AuthWireChannelTypes;Initialize-AuthWireWriteTransportTypes
 $journal=Get-AuthWireStagingWriteJournalRoot $b;$id='733fc751-202d-448a-af68-0bea09c2aeb4'
 if(Test-Path -LiteralPath (Join-Path $out 'result.json')){throw 'READ_EXISTING_CLOSURE_RESULT'}
 $job=Join-Path $journal $id
 if(Test-Path -LiteralPath (Join-Path $job 'consumed-stage-closed.json')){throw 'READ_EXISTING_SIGNED_CLOSURE'}
 $original=@{};foreach($n in @('filesystem-intent.json','grant-consumed.json','result-outbox.json')){$original[$n]=(Get-FileHash -LiteralPath (Join-Path $job $n)).Hash}
 $local=Get-AuthWireWriteReconciliationReview $journal $b $rsa
 if($local.Phase -cne 'completion_verified' -or $local.JobId -cne $id -or $local.StageConsumption.Phase -cne 'expired_intent_without_engine_journal'){throw 'RECOVERY_CASE_CHANGED'}
 Add-Type -AssemblyName System.Net.Http
 Add-Type -ReferencedAssemblies @('System.dll','System.Core.dll',[Net.Http.HttpClientHandler].Assembly.Location) -TypeDefinition @'
using System;
using System.Net.Http;
using System.Net.Security;
using System.Security.Authentication;
using System.Security.Cryptography;
using System.Text;
using System.Collections.Generic;
using System.IO;
using System.Threading;
public static class G01RecoveryAdminV1 {
 public static string[] Request(string url,string pin,string path,string json,string session,string csrf){
  if(path!="/api/auth/login"&&path!="/api/deployment/staging-write"&&path!="/api/deployment/staging-write/reconciliation/review"&&path!="/api/deployment/staging-write/reconciliation/record")throw new InvalidOperationException("RECOVERY_PATH_REJECTED");
  Uri root=new Uri(url);if(root.Scheme!="https"||root.AbsolutePath!="/"||root.UserInfo!=""||root.Query!=""||root.Fragment!="")throw new InvalidOperationException("RECOVERY_URL_REJECTED");
  using(var h=new HttpClientHandler()){
   h.SslProtocols=SslProtocols.Tls12;h.UseProxy=false;h.AllowAutoRedirect=false;h.UseCookies=false;h.UseDefaultCredentials=false;h.CheckCertificateRevocationList=true;
   h.ServerCertificateCustomValidationCallback=(message,cert,chain,errors)=>{
    if(errors!=SslPolicyErrors.None||cert==null)return false;
    using(var s=SHA256.Create())return BitConverter.ToString(s.ComputeHash(cert.RawData)).Replace("-","").ToLowerInvariant()==pin;
   };
   using(var c=new HttpClient(h))
   using(var stop=new CancellationTokenSource(5000))
   using(var request=new HttpRequestMessage(path=="/api/deployment/staging-write"?HttpMethod.Get:HttpMethod.Post,new Uri(root,path))){
    c.Timeout=TimeSpan.FromSeconds(5);request.Headers.Add("Origin",root.GetLeftPart(UriPartial.Authority));
    if(!String.IsNullOrEmpty(session)){request.Headers.Add("Cookie","kaname_session="+session);request.Headers.Add("X-Kaname-CSRF",csrf);}
    if(request.Method==HttpMethod.Post)request.Content=new StringContent(json,Encoding.UTF8,"application/json");
    using(var response=c.SendAsync(request,HttpCompletionOption.ResponseHeadersRead,stop.Token).GetAwaiter().GetResult()){
     if(response.StatusCode!=System.Net.HttpStatusCode.OK)throw new InvalidOperationException("RECOVERY_HTTP_"+((int)response.StatusCode).ToString());
     string cookie="";IEnumerable<string> values;if(response.Headers.TryGetValues("Set-Cookie",out values))cookie=String.Join(";",values);
     using(var abort=stop.Token.Register(()=>response.Dispose()))
     using(var stream=response.Content.ReadAsStreamAsync().GetAwaiter().GetResult())
     using(var bytes=new MemoryStream()){
      byte[] buffer=new byte[1024];int n;
      while((n=stream.ReadAsync(buffer,0,buffer.Length,stop.Token).GetAwaiter().GetResult())>0){bytes.Write(buffer,0,n);if(bytes.Length>32768)throw new InvalidOperationException("RECOVERY_HTTP_LIMIT");}
      return new[]{new UTF8Encoding(false,true).GetString(bytes.ToArray()),cookie};
     }
    }
   }
  }
 }
}
'@
 $base=Get-AuthWireWriteTransportBaseUrl $c
 $cred=Get-Content -LiteralPath (Join-Path $root 'operator.json') -Raw|ConvertFrom-Json
 $reply=[G01RecoveryAdminV1]::Request($base,$b.appliance_tls_sha256,'/api/auth/login',(ConvertTo-AuthWireWriteJson @{username=$cred.username;password=$cred.password}),$null,$null)
 $user=ConvertFrom-AuthWireCandidateJson ([Text.UTF8Encoding]::new($false,$true).GetBytes($reply[0]))
 $match=[regex]::Match($reply[1],'kaname_session=([A-Za-z0-9_-]{43})(?:;|$)')
 if(-not $match.Success -or $user.user.id -cne $cred.user_id){throw 'RECOVERY_OPERATOR_CHANGED'}
 $token=$match.Groups[1].Value;$csrfToken=$user.csrf
 function Invoke-Admin([string]$Path,$Value){
  $json=if($null -eq $Value){$null}else{ConvertTo-AuthWireWriteJson $Value}
  $r=[G01RecoveryAdminV1]::Request($base,$b.appliance_tls_sha256,$Path,$json,$token,$csrfToken)
  return (ConvertFrom-AuthWireCandidateJson ([Text.UTF8Encoding]::new($false,$true).GetBytes($r[0])))
 }
 $state=Invoke-Admin '/api/deployment/staging-write' $null
 $prior=[pscustomobject]@{expected_revision=$state.revision;evidence=$local.Evidence;decision='keep_under_review'}
 $review=Invoke-Admin '/api/deployment/staging-write/reconciliation/review' $prior
 $prior|Add-Member NoteProperty review_hash $review.review_hash
 $prior|Add-Member NoteProperty acknowledge 'record_reconciliation_decision'
 $kept=Invoke-Admin '/api/deployment/staging-write/reconciliation/record' $prior
 $proof=Get-AuthWireConsumedStageRecoveryEvidence $journal $id $b $rsa $c.PublisherThumbprint $c.BaseUrl
 if($proof.Body.format -cne 'AuthWireStageIntentRecoveryEvidenceV1' -or $proof.Body.filesystem_intent_sha256 -cne 'e6dbd0f90b41b14f88e06f2046717199bf48b4738ab835ce815132b231585838' -or $proof.Body.filesystem_operation_id -cne 'ecb37ea6-6a3c-de54-5234-1ce7d6d3867f'){throw 'INTENT_PROOF_SCOPE_CHANGED'}
 $approval=[pscustomobject]@{expected_revision=$kept.revision;evidence=$local.Evidence;decision='approve_consumed_stage_lock_release';reconciliation_receipt=[pscustomobject]@{revision=$kept.revision;review_hash=$review.review_hash};consumed_stage_proof=$proof}
 $review=Invoke-Admin '/api/deployment/staging-write/reconciliation/review' $approval
 $approval|Add-Member NoteProperty review_hash $review.review_hash
 $approval|Add-Member NoteProperty acknowledge 'record_consumed_stage_lock_release_approval'
 $approved=Invoke-Admin '/api/deployment/staging-write/reconciliation/record' $approval
 $request=[pscustomobject]@{approval=$approval;approval_revision=$approved.revision}
 $session=ConvertTo-SecureString $token -AsPlainText -Force;$csrf=ConvertTo-SecureString $csrfToken -AsPlainText -Force
 $closed=Complete-AuthWireConsumedStageLocalClosure $journal $id $b $rsa $c.PublisherThumbprint $base $request $session $csrf $c.BaseUrl
 $accepted=Send-AuthWireConsumedStageClosure $b $base $request $closed $session $csrf
 $after=Get-AuthWireWriteReconciliationReview $journal $b $rsa
 if($closed.Body.format -cne 'AuthWireStageIntentClosureV1' -or $after.Phase -cne 'closed_without_engine_journal'){throw 'INTENT_CLOSURE_NOT_CONFIRMED'}
 foreach($n in $original.Keys){if((Get-FileHash -LiteralPath (Join-Path $job $n)).Hash -cne $original[$n]){throw 'ORIGINAL_EVIDENCE_CHANGED'}}
 $facts=[pscustomobject]@{status='closed';job_id=$id;gpo_id=$closed.Body.gpo_id;closure_revision=$accepted.closure_revision;closure_sha256=$accepted.closure_sha256;local_phase=$after.Phase;original_result_preserved=$true;original_filesystem_intent_preserved=$true;original_grant_preserved=$true;closure_kind=$closed.Body.format;can_apply_gpo=$false;closed_at=$closed.Body.closed_at;runtime_sid=$b.service_sid}
 Write-AuthWireStagingJournal (Join-Path $out 'result.json') $facts
}catch{
 $message=$_.Exception.GetBaseException().Message
 if($null -ne $cred){$message=$message.Replace($cred.password,'[redacted]')};if($message.Length -gt 1500){$message=$message.Substring(0,1500)}
 [IO.File]::WriteAllText((Join-Path $out 'failure-final.json'),(@{status='requires_review';code=$message;line=$_.InvocationInfo.ScriptLineNumber;at=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()}|ConvertTo-Json -Compress),[Text.UTF8Encoding]::new($false))
 exit 1
}finally{if($session){$session.Dispose()};if($csrf){$csrf.Dispose()};if($rsa){$rsa.Dispose()};if($key){$key.Dispose()}}

