#Requires -Version 5.1
$ErrorActionPreference='Stop';Set-StrictMode -Version 2
$root=$PSScriptRoot;$out=Join-Path $root 'output-stage-r3-20261122';$rsa=$null;$key=$null;$session=$null;$csrf=$null;$cred=$null
try{
 $active='C:\Program Files\AuthWire-Connector-4c23eebe071546d188eea2e96ad7ee46'
 $c=Get-Content -LiteralPath (Join-Path $active 'service.json') -Raw|ConvertFrom-Json
 if($c.ReleaseId -cne 'd3b84b6a-fe17-4d43-8a85-e3cc094550cf'){throw 'RECOVERY_RELEASE_CHANGED'}
 . (Join-Path $active 'Test-AuthWireDeploymentCandidate.ps1') -LibraryOnly
 foreach($file in @('Compare-AuthWireSigningKeyAcl.ps1','ConnectorChannelTypes.ps1','ConnectorChannelKey.ps1','New-AuthWireConnectorHealthProof.ps1','Invoke-AuthWireConnectorProbeJob.ps1','Invoke-AuthWireCandidateJob.ps1','DeploymentScope.ps1','Invoke-AuthWireScopeJob.ps1','CombinedCandidateContent.ps1','Invoke-AuthWireCombinedJob.ps1','CombinedDeploymentScope.ps1','Invoke-AuthWireCombinedScopeJob.ps1','SysvolInventory.ps1','CombinedStagingPreview.ps1','Invoke-AuthWireStagingPreviewJob.ps1','StagingFilesystem.ps1','StagingWritePreclaim.ps1','StagingWriteTransport.ps1','StagingWriteConsumption.ps1','StagingWriteProcess.ps1','StagingWriteExecution.ps1','StagingWriteResult.ps1','StagingWriteCycle.ps1','StagingRollbackEvidence.ps1','StagingRollbackAuthorization.ps1','StagingRollbackExecution.ps1','StagingRollbackResult.ps1','StagingWritePollRecord.ps1','StagingWriteLifecycle.ps1')){. (Join-Path $active $file)}
 Assert-AuthWireWriteServiceConfigFields $c
 $b=@{};foreach($p in $c.Binding.PSObject.Properties){$b[$p.Name]=$p.Value}
 $identity=[Security.Principal.WindowsIdentity]::GetCurrent();try{if($identity.User.Value -cne $b.service_sid){throw 'RECOVERY_IDENTITY_CHANGED'}}finally{$identity.Dispose()}
 $key=[Security.Cryptography.CngKey]::Open($c.KeyName,[Security.Cryptography.CngProvider]::MicrosoftSoftwareKeyStorageProvider,[Security.Cryptography.CngKeyOpenOptions]::MachineKey)
 $rsa=[Security.Cryptography.RSACng]::new($key)
 $keyPath=Join-Path (Join-Path $env:ProgramData 'Microsoft\Crypto\Keys') $key.UniqueName
 if(-not (Compare-AuthWireSigningKeyAcl $c.ExpectedKeySddl (Get-Acl -LiteralPath $keyPath).Sddl).AclEquivalent){throw 'RECOVERY_KEY_ACL_CHANGED'}
 Initialize-AuthWireStagingFilesystemTypes
 Initialize-AuthWireChannelTypes
 Initialize-AuthWireWriteTransportTypes
 $journal=Get-AuthWireStagingWriteJournalRoot $b
 if(Test-Path -LiteralPath (Join-Path $out 'stage-intent.json')){throw 'STAGE_ALREADY_STARTED_READ_EXISTING_RESULT'}
 if(Test-Path -LiteralPath (Join-Path $out 'preview-intent.json')){throw 'PREVIEW_ALREADY_STARTED_READ_EXISTING_RESULT'}
 $resumePreview=$false
 $committed=Read-AuthWireStagingJournal (Join-Path $journal 'write-lifecycle\history-archives\000001\committed.json')
 if($committed.archive_sha256 -cne '80e287150e7257d3e0b860d032a4565d0b4349908349b8d76af10af86ebe661a'){throw 'ARCHIVE_REQUIRED_BEFORE_STAGE'}
 if(Test-Path -LiteralPath (Join-Path $journal 'gpo-8c6808fd-a382-4bf2-9c9c-d9e1d46082a3.json')){throw 'GPO_LOCK_ALREADY_PRESENT'}
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
  if(path!="/api/auth/login"&&path!="/api/deployment/staging-write"&&path!="/api/deployment/candidates"&&path!="/api/deployment/candidates/staging-preview/preview"&&path!="/api/deployment/candidates/staging-preview/create"&&path!="/api/deployment/staging-write/review"&&path!="/api/deployment/staging-write/create")throw new InvalidOperationException("RECOVERY_PATH_REJECTED");
  Uri root=new Uri(url);if(root.Scheme!="https"||root.AbsolutePath!="/"||root.UserInfo!=""||root.Query!=""||root.Fragment!="")throw new InvalidOperationException("RECOVERY_URL_REJECTED");
  using(var h=new HttpClientHandler()){
   h.SslProtocols=SslProtocols.Tls12;h.UseProxy=false;h.AllowAutoRedirect=false;h.UseCookies=false;h.UseDefaultCredentials=false;h.CheckCertificateRevocationList=true;
   h.ServerCertificateCustomValidationCallback=(message,cert,chain,errors)=>{
    if(errors!=SslPolicyErrors.None||cert==null)return false;
    using(var s=SHA256.Create())return BitConverter.ToString(s.ComputeHash(cert.RawData)).Replace("-","").ToLowerInvariant()==pin;
   };
   using(var c=new HttpClient(h))
   using(var stop=new CancellationTokenSource(5000))
   using(var request=new HttpRequestMessage((path=="/api/deployment/staging-write"||path=="/api/deployment/candidates")?HttpMethod.Get:HttpMethod.Post,new Uri(root,path))){
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
 $cred=Get-Content -LiteralPath (Join-Path $root 'operator-stage-r3.json') -Raw|ConvertFrom-Json
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
 function Wait-FieldJob([string]$Id){
  $watch=[Diagnostics.Stopwatch]::StartNew()
  do{
   $status=Invoke-Admin '/api/deployment/staging-write' $null
   $job=@($status.jobs|Where-Object {$_.id -ceq $Id})
   if($job.Count -ne 1){throw 'FIELD_JOB_NOT_FOUND'}
   if($job[0].state -cin @('completed','requires_review','expired','obsolete')){
    return [pscustomobject]@{Phase=if($job[0].state -ceq 'completed'){'result_recorded'}else{'requires_review'};JobId=$Id;Outcome=$job[0].peer_reported_outcome;ResultRecorded=($null -ne $job[0].peer_reported_outcome);CanApplyGpo=$false;ArtifactExecuted=$false}
   }
   Start-Sleep -Seconds 1
  }while($watch.Elapsed.TotalSeconds -lt 150)
  throw 'FIELD_JOB_WAIT_TIMEOUT'
 }
 $ready=Invoke-AuthWireStagingPreviewJob $base $b $rsa $c.ReleaseId
 if($ready.JobCompleted){throw 'UNEXPECTED_PREVIEW_JOB_DURING_READINESS'}
 $catalog=Invoke-Admin '/api/deployment/candidates' $null
 $candidateId='2e2723bd-9987-4734-9fae-2433193d8e6c'
 $candidate=@($catalog.candidates|Where-Object {$_.id -ceq $candidateId})
 if($candidate.Count -ne 1 -or $candidate[0].gpo_id -cne '8c6808fd-a382-4bf2-9c9c-d9e1d46082a3'){throw 'CANDIDATE_SCOPE_CHANGED'}
 $previewId=if($resumePreview){(Read-AuthWireStagingJournal (Join-Path $out 'preview-intent.json')).job_id}else{[guid]::NewGuid().ToString('D')}
 if(@($catalog.staging_preview_jobs|Where-Object {$_.id -ceq $previewId}).Count){throw 'PREVIEW_ALREADY_EXISTS_READ_RESULT'}
 $request=[pscustomobject]@{expected_revision=$catalog.revision;job_id=$previewId;operation='combined.staging.preview.v1';candidate_id=$candidateId}
 if(-not $resumePreview){Write-AuthWireStagingJournal (Join-Path $out 'preview-intent.json') $request}
 $review=Invoke-Admin '/api/deployment/candidates/staging-preview/preview' $request
 $request|Add-Member NoteProperty preview_hash $review.preview_hash
 $created=Invoke-Admin '/api/deployment/candidates/staging-preview/create' $request
 $native=Invoke-AuthWireStagingPreviewJob $base $b $rsa $c.ReleaseId
 $wait=[Diagnostics.Stopwatch]::StartNew()
 do{
  $catalog=Invoke-Admin '/api/deployment/candidates' $null
  $previewJob=@($catalog.staging_preview_jobs|Where-Object {$_.id -ceq $previewId})
  if($previewJob.Count -eq 1 -and $previewJob[0].state -ceq 'completed'){break}
  Start-Sleep -Milliseconds 500
 }while($wait.Elapsed.TotalSeconds -lt 40)
 if($previewJob.Count -ne 1 -or $previewJob[0].outcome -cne 'staging_preview_verified'){throw 'FRESH_PREVIEW_NOT_VERIFIED'}
 $candidate=@($catalog.candidates|Where-Object {$_.id -ceq $candidateId})[0]
 if($candidate.staging_preview_fresh -ne $true -or $candidate.staging_preview.file_count -ne 20){throw 'FRESH_PREVIEW_SCOPE_CHANGED'}
 $baseline=$candidate.staging_preview.baseline_inventory_sha256;$previewHash=$candidate.staging_preview_sha256
 Write-AuthWireStagingJournal (Join-Path $out 'fresh-preview.json') ([pscustomobject]@{job_id=$previewId;preview=$candidate.staging_preview;preview_sha256=$previewHash})
 $state=Invoke-Admin '/api/deployment/staging-write' $null
 $stageId=[guid]::NewGuid().ToString('D')
 $request=[pscustomobject]@{expected_revision=$state.revision;job_id=$stageId;operation='combined.filesystem.stage.v1';candidate_id=$candidateId;stage_job_id='';staging_preview_sha256=$previewHash;acknowledge='create_owned_version_directory'}
 Write-AuthWireStagingJournal (Join-Path $out 'stage-intent.json') $request
 $review=Invoke-Admin '/api/deployment/staging-write/review' $request
 $request|Add-Member NoteProperty review_hash $review.review_hash
 $created=Invoke-Admin '/api/deployment/staging-write/create' $request
 $stage=Wait-FieldJob $stageId
 Write-AuthWireStagingJournal (Join-Path $out 'stage-observation.json') $stage
 if($stage.Phase -cne 'result_recorded' -or $stage.Outcome -cne 'staged' -or $stage.JobId -cne $stageId){throw 'FIELD_STAGE_NOT_CONFIRMED'}
 $state=Invoke-Admin '/api/deployment/staging-write' $null
 Write-AuthWireStagingJournal (Join-Path $out 'stage-accepted.json') $state
 $rollbackId=[guid]::NewGuid().ToString('D')
 $request=[pscustomobject]@{expected_revision=$state.revision;job_id=$rollbackId;operation='combined.filesystem.rollback.v1';candidate_id=$candidateId;stage_job_id=$stageId;staging_preview_sha256=$previewHash;acknowledge='delete_owned_version_directory'}
 Write-AuthWireStagingJournal (Join-Path $out 'rollback-intent.json') $request
 $review=Invoke-Admin '/api/deployment/staging-write/review' $request
 $request|Add-Member NoteProperty review_hash $review.review_hash
 $created=Invoke-Admin '/api/deployment/staging-write/create' $request
 $rollback=Wait-FieldJob $rollbackId
 Write-AuthWireStagingJournal (Join-Path $out 'rollback-observation.json') $rollback
 if($rollback.Phase -cne 'result_recorded' -or $rollback.Outcome -cne 'rolled_back' -or $rollback.JobId -cne $rollbackId){throw 'FIELD_ROLLBACK_NOT_CONFIRMED'}
 $offer=(Read-AuthWireStagingJournal (Join-Path (Join-Path $journal $stageId) 'offer.json')).offer
 $target=$offer.target.scope_target
 Import-Module ActiveDirectory -ErrorAction Stop
 $pdc=[string](Get-ADDomain -Identity $target.domain -Server $target.domain -ErrorAction Stop).PDCEmulator
 $inventory=Get-AuthWireSysvolInventory (Get-AuthWireWriteGpoPath $pdc $target)
 if($inventory.Sha256 -cne $baseline){throw 'FIELD_BASELINE_NOT_RESTORED'}
 $stageLocal=Read-AuthWireWriteResultOutbox $journal $stageId $b $c.ReleaseId $rsa
 $rollbackLocal=Read-AuthWireRollbackResultOutbox $journal $rollbackId $b $c.ReleaseId $rsa
 if($stageLocal.body.outcome -cne 'staged' -or $rollbackLocal.body.outcome -cne 'rolled_back'){throw 'NATIVE_LOCAL_RESULTS_NOT_VERIFIED'}
 $final=Invoke-Admin '/api/deployment/staging-write' $null
 Write-AuthWireStagingJournal (Join-Path $out 'stage-rollback-result.json') ([pscustomobject]@{status='passed';native_stage_body_sha256=$stageLocal.body_sha256;native_rollback_body_sha256=$rollbackLocal.body_sha256;automatic_service_worker=$true;preview_id=$previewId;stage_id=$stageId;rollback_id=$rollbackId;baseline_inventory_sha256=$baseline;restored_inventory_sha256=$inventory.Sha256;file_count=$candidate.staging_preview.file_count;total_bytes=$candidate.staging_preview.total_bytes;revision=$final.revision;release=$c.ReleaseId;can_apply_gpo=$false;old_job_replayed=$false;at=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()})
}catch{
 $m=$_.Exception.GetBaseException().Message
 if($cred -and $cred.password){$m=$m.Replace($cred.password,'[redacted]')}
 if($m.Length -gt 1200){$m=$m.Substring(0,1200)}
 [IO.File]::WriteAllText((Join-Path $out 'stage-rollback-failure.json'),(@{status='requires_review';code=$m;line=$_.InvocationInfo.ScriptLineNumber;stack=$_.ScriptStackTrace;at=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()}|ConvertTo-Json -Compress),[Text.UTF8Encoding]::new($false))
 exit 1
}finally{if($rsa){$rsa.Dispose()};if($key){$key.Dispose()}}
