/* Explicit pilot filesystem approvals. No GPO activation or automatic replay. */
(() => {
 const guid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
 const hash=/^[0-9a-f]{64}$/;
 const stage='combined.filesystem.stage.v1',rollback='combined.filesystem.rollback.v1';
 let busy=false,sending=false,ticket=0,pending=null;
 const exact=(v,keys)=>v&&typeof v==='object'&&!Array.isArray(v)&&Object.keys(v).length===keys.length&&keys.every(k=>Object.hasOwn(v,k));
 function accepts(s){
  const p=s?.panel_workflow;
  return s?.source_only===false&&s.approval_enabled===true&&s.write_authorization_enabled===true&&s.execution_adapter_available===true&&s.can_apply_gpo===false&&Number.isSafeInteger(s.revision)&&s.revision>=0&&
   exact(p,['format','enabled','gpo_id','worker_ready','rollback_targets','can_apply_gpo'])&&p.format==='AuthWireFilesystemPanelV1'&&p.enabled===true&&guid.test(p.gpo_id)&&typeof p.worker_ready==='boolean'&&p.can_apply_gpo===false&&Array.isArray(p.rollback_targets)&&p.rollback_targets.length<=32&&
   p.rollback_targets.every(r=>exact(r,['stage_job_id','candidate_id','staging_preview_sha256'])&&guid.test(r.stage_job_id)&&guid.test(r.candidate_id)&&hash.test(r.staging_preview_sha256));
 }
 function controls(){document.querySelectorAll('[data-filesystem-action]').forEach(b=>b.disabled=busy||!!pending||!candidateAccess(true)||b.dataset.unavailable==='true');}
 function reset(){ticket++;busy=sending=false;pending=null;}
 function invalidate(){ticket++;}
 function feedback(box,text){let n=box.querySelector('[data-filesystem-feedback]');if(!n){n=depNode('p');n.dataset.filesystemFeedback='';n.setAttribute('role','status');box.append(n);}n.textContent=text;}
 function button(text,fn,unavailable=false){const b=depNode('button',text);b.type='button';b.dataset.filesystemAction='';b.dataset.unavailable=String(unavailable);b.addEventListener('click',fn);return b;}
 function still(g,t){return authGeneration===g&&ticket===t&&candidateAccess(true);}
 function render(box,status,rows){
  if(!accepts(status))return;
  if(pending&&pending.generation!==authGeneration)pending=null;
  if(pending){
   const p=pending,found=status.jobs.find(j=>j.id===p.intent.job_id&&j.operation===p.intent.operation);
   if(found){pending=null;feedback(box,'Görevin kaydedildiği doğrulandı. İstek tekrar gönderilmedi.');}
   else{
    feedback(box,'Gönderme sonucu belirsiz. Yeni işlem açmadan mevcut görev kontrol edilmeli.');
    const check=depNode('button','Görev sonucunu kontrol et');check.type='button';box.append(check);
    check.addEventListener('click',async()=>{if(busy||!candidateAccess())return;const g=authGeneration;busy=true;check.disabled=true;try{const value=await api('/api/deployment/staging-write');if(g!==authGeneration||pending!==p)return;if(!accepts(value)||value.panel_workflow.gpo_id!==p.gpo)throw Error('Görev durumu doğrulanamadı.');const j=value.jobs.find(j=>j.id===p.intent.job_id&&j.operation===p.intent.operation);if(j){pending=null;feedback(box,'Görevin kaydedildiği doğrulandı. İstek tekrar gönderilmedi.');}else feedback(box,'Görev kaydı henüz bulunamadı. İstek tekrar gönderilmedi.');}catch(e){if(g===authGeneration)feedback(box,e.message);}finally{if(g===authGeneration){busy=false;check.disabled=false;controls();}}});
    controls();return;
   }
  }
  const p=status.panel_workflow,blocked=status.jobs.some(j=>['queued','leased','authorized'].includes(j.state));
  box.append(depNode('p','Bu onay yalnız paket dosyalarını kapsar. GPO bağlantısı ve uç yapılandırması etkinleştirilmez.'));
  if(!p.worker_ready)box.append(depNode('p','Yazıcıdan güncel bağlantı bekleniyor. İşlem gönderilemez.'));
  for(const row of rows.filter(r=>r.artifact_kind==='combined_machine_v1'&&r.gpo_id===p.gpo_id)){
   const fresh=row.staging_preview_verified===true&&row.staging_preview_fresh===true&&hash.test(row.staging_preview_sha256);
   box.append(button('Paket dosyalarını hazırlamayı önizle',()=>review(box,status,row.id,'',row.staging_preview_sha256,stage),!p.worker_ready||blocked||p.rollback_targets.length>0||!fresh));
   if(!fresh)box.append(depNode('p','Dosya hazırlama için güncel paket hazırlığı önizlemesi gerekli.'));
  }
  for(const r of p.rollback_targets){
   box.append(button('Hazırlanan paketi geri almayı önizle',()=>review(box,status,r.candidate_id,r.stage_job_id,r.staging_preview_sha256,rollback),!p.worker_ready||blocked));
  }
  controls();
 }
 async function review(box,status,candidate,origin,preview,operation){
  if(busy||pending||!candidateAccess(true)||!accepts(status)||!status.panel_workflow.worker_ready)return;
  if(!guid.test(candidate)||!hash.test(preview)||(operation===rollback&&!guid.test(origin)))return;
  const g=authGeneration,t=++ticket;
  const intent={expected_revision:status.revision,job_id:crypto.randomUUID(),operation,candidate_id:candidate,staging_preview_sha256:preview,stage_job_id:origin,acknowledge:operation===stage?'create_owned_version_directory':'delete_owned_version_directory'};
  busy=true;controls();
  try{
   const p=await api('/api/deployment/staging-write/review',intent);if(!still(g,t))return;
   const target=p.target,scope=target?.scope_target;
   if(p.job_id!==intent.job_id||p.operation!==operation||p.revision!==intent.expected_revision||p.can_apply_gpo!==false||p.review_only!==false||p.read_only!==false||!hash.test(p.review_hash)||scope?.candidate_id!==candidate||scope.gpo_id!==status.panel_workflow.gpo_id||target?.preview_record?.PreviewSha256!==preview||
      (operation===rollback?target.stage_receipt?.stage_job_id!==origin:target.stage_receipt!==null))throw Error('İşlem önizlemesi doğrulanamadı.');
   box.querySelectorAll('[data-filesystem-review]').forEach(n=>n.remove());
   const form=depNode('div');form.dataset.filesystemReview='';form.append(depNode('strong',operation===stage?'Paket dosyası hazırlama onayı':'Paket dosyası geri alma onayı'),depNode('p','GPO: '+scope.gpo_id),depNode('p','Dosya sayısı: '+target.preview_record.Preview.file_count+' · Hedef bilgisayar: '+scope.target_count),depNode('p','Bu işlem GPO’yu uçlarda etkinleştirmez.'));
   const label=depNode('label'),consent=depNode('input');consent.type='checkbox';label.append(consent,document.createTextNode(' Bu paket dosyası işlemini onaylıyorum.'));form.append(label);
   const send=depNode('button','Onayla ve gönder'),cancel=depNode('button','Vazgeç');send.type=cancel.type='button';send.disabled=true;form.append(send,cancel);box.append(form);
   consent.addEventListener('change',()=>send.disabled=!consent.checked||busy||!still(g,t));
   cancel.addEventListener('click',()=>{if(sending)return;ticket++;form.remove();});
   send.addEventListener('click',async()=>{
    if(!consent.checked||busy||pending||!still(g,t))return;
    busy=sending=true;send.disabled=cancel.disabled=consent.disabled=true;controls();
    const memo={intent,generation:g,gpo:scope.gpo_id};pending=memo;
    try{
     const result=await api('/api/deployment/staging-write/create',{...intent,review_hash:p.review_hash});if(!still(g,t))return;
     if(result.job_id!==intent.job_id||result.recorded!==true||result.can_apply_gpo!==false||!['queued','leased','authorized','completed','requires_review','expired','obsolete'].includes(result.state))throw Error('Görev makbuzu doğrulanamadı.');
     pending=null;form.remove();feedback(box,'Görev kaydedildi. Yürütme sonucu henüz doğrulanmadı; Yenile ile kontrol edin.');
    }catch(e){if(g===authGeneration)feedback(box,'Gönderme sonucu belirsiz. İstek tekrar gönderilmeyecek; mevcut görev kontrol edilecek.');}
    finally{if(g===authGeneration&&t===ticket){busy=sending=false;controls();await loadCandidateStatus();}}
   });
  }catch(e){if(still(g,t))feedback(box,candidateError(e));}
  finally{if(g===authGeneration&&t===ticket){busy=false;controls();}}
 }
 window.AuthWireFilesystemPanel={accepts,render,controls,reset,invalidate,get sending(){return sending;},get busy(){return busy;}};
})();
