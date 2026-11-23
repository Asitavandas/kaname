#Requires -Version 5.1
# One fresh AD stage + independent rollback, performed by the installed worker.
$ErrorActionPreference='Stop';$ProgressPreference='SilentlyContinue';Set-StrictMode -Version 2
$root=$PSScriptRoot;$out=Join-Path $root 'output-v2';$cred=$null;$session=$null;$csrf=$null;$key=$null;$rsa=$null
$started=Join-Path $out 'run-started.json'
if(Test-Path -LiteralPath $started){throw 'FIELD_ALREADY_STARTED_READ_EXISTING_RESULT'}
$stageId='';$rollbackId='';$previewId='';$phase='preflight'
try{
 $active='C:\Program Files\AuthWire-Connector-4c23eebe071546d188eea2e96ad7ee46'
 $c=Get-Content -LiteralPath (Join-Path $active 'service.json') -Raw|ConvertFrom-Json
 if($c.ReleaseId -cne 'd539aa00-4acf-4b22-a952-4b24d57e0cde' -or $c.WritePilotPort -ne 18765){throw 'FIELD_RELEASE_CHANGED'}
 . (Join-Path $active 'Test-AuthWireDeploymentCandidate.ps1') -LibraryOnly
 foreach($name in @('Compare-AuthWireSigningKeyAcl.ps1','ConnectorChannelTypes.ps1','ConnectorChannelKey.ps1','Invoke-AuthWireStagingPreviewJob.ps1','New-AuthWireConnectorHealthProof.ps1','Invoke-AuthWireConnectorProbeJob.ps1','Invoke-AuthWireCandidateJob.ps1','DeploymentScope.ps1','Invoke-AuthWireScopeJob.ps1','CombinedCandidateContent.ps1','Invoke-AuthWireCombinedJob.ps1','CombinedDeploymentScope.ps1','SysvolInventory.ps1','CombinedStagingPreview.ps1','StagingFilesystem.ps1','StagingWritePreclaim.ps1','StagingWriteTransport.ps1','StagingWriteConsumption.ps1')){. (Join-Path $active $name)}
 Initialize-AuthWireChannelTypes
 Assert-AuthWireWriteServiceConfigFields $c
 $b=@{};foreach($p in $c.Binding.PSObject.Properties){$b[$p.Name]=$p.Value}
 $identity=[Security.Principal.WindowsIdentity]::GetCurrent();try{if($identity.User.Value -cne $b.service_sid -or ([Security.Principal.WindowsPrincipal]::new($identity)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)){throw 'FIELD_NONADMIN_IDENTITY_REQUIRED'}}finally{$identity.Dispose()}
 Initialize-AuthWireStagingFilesystemTypes
 $key=[Security.Cryptography.CngKey]::Open($c.KeyName,[Security.Cryptography.CngProvider]::MicrosoftSoftwareKeyStorageProvider,[Security.Cryptography.CngKeyOpenOptions]::MachineKey)
 $rsa=[Security.Cryptography.RSACng]::new($key)
 $keyPath=Join-Path (Join-Path $env:ProgramData 'Microsoft\Crypto\Keys') $key.UniqueName
 if(-not (Compare-AuthWireSigningKeyAcl $c.ExpectedKeySddl (Get-Acl -LiteralPath $keyPath).Sddl).AclEquivalent){throw 'FIELD_KEY_ACL_CHANGED'}
 $journal=Get-AuthWireStagingWriteJournalRoot $b
 if(Test-Path -LiteralPath (Join-Path $journal 'gpo-8c6808fd-a382-4bf2-9c9c-d9e1d46082a3.json')){throw 'FIELD_EXISTING_GPO_LOCK'}
 Write-AuthWireStagingJournal $started ([pscustomobject]@{release=$c.ReleaseId;at=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds();old_jobs_replayed=$false;execution='installed_worker_only'})
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
public static class G01FieldAdminResumeV1 {
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
     if(response.StatusCode!=System.Net.HttpStatusCode.OK){
 string text=response.Content.ReadAsStringAsync().GetAwaiter().GetResult();
 var match=System.Text.RegularExpressions.Regex.Match(text,@"""error""\s*:\s*""([A-Z][A-Z0-9_]{1,110})""");
 throw new InvalidOperationException("HTTP_"+((int)response.StatusCode).ToString()+"_"+(match.Success?match.Groups[1].Value:"UNCLASSIFIED"));
}
     string cookie="";IEnumerable<string> values;if(response.Headers.TryGetValues("Set-Cookie",out values))cookie=String.Join(";",values);
     using(var abort=stop.Token.Register(()=>response.Dispose()))
     using(var stream=response.Content.ReadAsStreamAsync().GetAwaiter().GetResult())
     using(var bytes=new MemoryStream()){
      byte[] buffer=new byte[1024];int n;
      while((n=stream.ReadAsync(buffer,0,buffer.Length,stop.Token).GetAwaiter().GetResult())>0){bytes.Write(buffer,0,n);if(bytes.Length>262144)throw new InvalidOperationException("RECOVERY_HTTP_LIMIT");}
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
 $reply=[G01FieldAdminResumeV1]::Request($base,$b.appliance_tls_sha256,'/api/auth/login',(ConvertTo-AuthWireWriteJson @{username=$cred.username;password=$cred.password}),$null,$null)
 $user=$reply[0]|ConvertFrom-Json
 $match=[regex]::Match($reply[1],'kaname_session=([A-Za-z0-9_-]{43})(?:;|$)')
 if(-not $match.Success -or $user.user.id -cne $cred.user_id){throw 'FIELD_OPERATOR_CHANGED'}
 $token=$match.Groups[1].Value;$csrfToken=$user.csrf
 function Invoke-Admin([string]$Path,$Value){
  $json=if($null -eq $Value){$null}else{ConvertTo-AuthWireWriteJson $Value}
  $r=[G01FieldAdminResumeV1]::Request($base,$b.appliance_tls_sha256,$Path,$json,$token,$csrfToken)
  return ($r[0]|ConvertFrom-Json)
 }
 function Wait-WriteJob([string]$Id,[string]$ExpectedOutcome){
  $timer=[Diagnostics.Stopwatch]::StartNew()
  do{
   $state=Invoke-Admin '/api/deployment/staging-write' $null
   $rows=@($state.jobs|Where-Object {$_.id -ceq $Id})
   if($rows.Count -ne 1){throw 'FIELD_JOB_NOT_FOUND'}
   if($rows[0].state -cin @('completed','requires_review')){
    Write-AuthWireStagingJournal (Join-Path $out ($ExpectedOutcome+'-server.json')) $state
    if($rows[0].state -cne 'completed' -or $rows[0].peer_reported_outcome -cne $ExpectedOutcome){throw 'FIELD_WORKER_REQUIRES_REVIEW'}
    return $state
   }
   Start-Sleep -Seconds 1
  }while($timer.Elapsed.TotalSeconds -lt 125)
  throw 'FIELD_WORKER_RESULT_PENDING_READ_EXISTING_JOB'
 }
 $catalog=Invoke-Admin '/api/deployment/candidates' $null
 $candidateId='2e2723bd-9987-4734-9fae-2433193d8e6c'
 $rows=@($catalog.candidates|Where-Object {$_.id -ceq $candidateId})
 if($rows.Count -ne 1 -or $rows[0].gpo_id -cne '8c6808fd-a382-4bf2-9c9c-d9e1d46082a3'){throw 'FIELD_CANDIDATE_SCOPE_CHANGED'}
 $phase='fresh_preview'
 # Resume the uncreated request ID. Never recreate a completed preview/test.
 $previous=Get-Content -LiteralPath 'C:\ProgramData\AuthWire-G01-StageField-e357-20261122\output\preview-intent.json' -Raw|ConvertFrom-Json
 if($previous.job_id -cne '29b4c0b1-74b5-46d9-af67-7b85d6210b98'){throw 'FIELD_PREVIOUS_INTENT_CHANGED'}
 $previewId=$previous.job_id
 if(@($catalog.staging_preview_jobs|Where-Object {$_.id -ceq $previewId}).Count){throw 'FIELD_PREVIEW_ALREADY_CREATED_INSPECT_EXISTING'}
 # The main read-only worker uses the panel endpoint; this isolated write-pilot
 # queue needs its own signed preview reader admission and fresh result.
 $admit=Invoke-AuthWireStagingPreviewJob $base $b $rsa $c.ReleaseId
 if($admit.JobCompleted){throw 'FIELD_UNEXPECTED_PRIOR_PREVIEW_REQUIRES_REVIEW'}
 Write-AuthWireStagingJournal (Join-Path $out 'preview-reader-admitted.json') $admit
 $request=[pscustomobject]@{expected_revision=$catalog.revision;job_id=$previewId;operation='combined.staging.preview.v1';candidate_id=$candidateId}
 Write-AuthWireStagingJournal (Join-Path $out 'preview-intent.json') $request
 $review=Invoke-Admin '/api/deployment/candidates/staging-preview/preview' $request
 $request|Add-Member NoteProperty preview_hash $review.preview_hash
 $phase='preview_create'
 $created=Invoke-Admin '/api/deployment/candidates/staging-preview/create' $request
 $phase='preview_read'
 $read=Invoke-AuthWireStagingPreviewJob $base $b $rsa $c.ReleaseId
 Write-AuthWireStagingJournal (Join-Path $out 'preview-reader-result.json') $read
 if(-not $read.JobCompleted -or $read.JobId -cne $previewId -or $read.Reason -cne 'OK'){throw 'FIELD_FRESH_PREVIEW_READER_NOT_VERIFIED'}
 $timer=[Diagnostics.Stopwatch]::StartNew()
 do{
  $catalog=Invoke-Admin '/api/deployment/candidates' $null
  $previews=@($catalog.staging_preview_jobs|Where-Object {$_.id -ceq $previewId})
  if($previews.Count -eq 1 -and $previews[0].state -ceq 'completed'){break}
  Start-Sleep -Seconds 1
 }while($timer.Elapsed.TotalSeconds -lt 70)
 if($previews.Count -ne 1 -or $previews[0].outcome -cne 'staging_preview_verified'){throw 'FIELD_FRESH_PREVIEW_NOT_VERIFIED'}
 $candidate=@($catalog.candidates|Where-Object {$_.id -ceq $candidateId})[0]
 if($candidate.staging_preview_fresh -ne $true -or $candidate.staging_preview.file_count -ne 20 -or $candidate.staging_preview.baseline_inventory_sha256 -cne 'b694d3170907045f688ddb7490933815f29eeff21b4e682b795487233ffebec6'){throw 'FIELD_FRESH_PREVIEW_SCOPE_CHANGED'}
 $baseline=$candidate.staging_preview.baseline_inventory_sha256;$previewHash=$candidate.staging_preview_sha256
 Write-AuthWireStagingJournal (Join-Path $out 'fresh-preview.json') ([pscustomobject]@{job_id=$previewId;preview=$candidate.staging_preview;preview_sha256=$previewHash})
 $phase='stage'
 $state=Invoke-Admin '/api/deployment/staging-write' $null
 $stageId=[guid]::NewGuid().ToString('D')
 $request=[pscustomobject]@{expected_revision=$state.revision;job_id=$stageId;operation='combined.filesystem.stage.v1';candidate_id=$candidateId;stage_job_id='';staging_preview_sha256=$previewHash;acknowledge='create_owned_version_directory'}
 Write-AuthWireStagingJournal (Join-Path $out 'stage-intent.json') $request
 $review=Invoke-Admin '/api/deployment/staging-write/review' $request
 $request|Add-Member NoteProperty review_hash $review.review_hash
 $created=Invoke-Admin '/api/deployment/staging-write/create' $request
 $state=Wait-WriteJob $stageId 'staged'
 $phase='rollback'
 $rollbackId=[guid]::NewGuid().ToString('D')
 $request=[pscustomobject]@{expected_revision=$state.revision;job_id=$rollbackId;operation='combined.filesystem.rollback.v1';candidate_id=$candidateId;stage_job_id=$stageId;staging_preview_sha256=$previewHash;acknowledge='delete_owned_version_directory'}
 Write-AuthWireStagingJournal (Join-Path $out 'rollback-intent.json') $request
 $review=Invoke-Admin '/api/deployment/staging-write/review' $request
 $request|Add-Member NoteProperty review_hash $review.review_hash
 $created=Invoke-Admin '/api/deployment/staging-write/create' $request
 $final=Wait-WriteJob $rollbackId 'rolled_back'
 $phase='baseline'
 $offer=(Read-AuthWireStagingJournal (Join-Path (Join-Path $journal $stageId) 'offer.json')).offer
 $target=$offer.target.scope_target
 Import-Module ActiveDirectory -ErrorAction Stop
 $pdc=[string](Get-ADDomain -Identity $target.domain -Server $target.domain -ErrorAction Stop).PDCEmulator
 $inventory=Get-AuthWireSysvolInventory (Get-AuthWireWriteGpoPath $pdc $target)
 if($inventory.Sha256 -cne $baseline){throw 'FIELD_BASELINE_NOT_RESTORED'}
 Write-AuthWireStagingJournal (Join-Path $out 'result.json') ([pscustomobject]@{status='passed';preview_id=$previewId;stage_id=$stageId;rollback_id=$rollbackId;baseline_inventory_sha256=$baseline;restored_inventory_sha256=$inventory.Sha256;file_count=$candidate.staging_preview.file_count;total_bytes=$candidate.staging_preview.total_bytes;revision=$final.revision;release=$c.ReleaseId;can_apply_gpo=$false;old_job_replayed=$false;execution='installed_worker';at=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()})
}catch{
 $m=$_.Exception.GetBaseException().Message
 $code=if($m -cmatch '\A[A-Z][A-Z0-9_]{1,90}\z'){$m}else{'FIELD_RUNNER_FAILED'}
 $failure=[pscustomobject]@{status='requires_review';code=$code;phase=$phase;preview_id=$previewId;stage_id=$stageId;rollback_id=$rollbackId;line=$_.InvocationInfo.ScriptLineNumber;error_type=$_.Exception.GetBaseException().GetType().FullName;stack=$_.ScriptStackTrace;at=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()}
 [IO.File]::WriteAllText((Join-Path $out 'failure.json'),($failure|ConvertTo-Json -Compress),[Text.UTF8Encoding]::new($false))
 exit 1
}

finally{if($rsa){$rsa.Dispose()};if($key){$key.Dispose()}}
