/* Preparation only: no GPO or endpoint write can be issued by this screen. */
let depState=null,depBusy=false,depRequest=0,depFlight=null,depEditing=null,depRevision=0,depUncertain=false,depUncertainDraft=null,depPreview=null,depOffset=0;
const depGroups=new Map(),depURLs=new Set();
const depKinds={machine:'Bilgisayar',user:'Kullanıcı',machineOrUser:'Bilgisayar + kullanıcı'};
const depErrors={DEPLOYMENT_NETWORK_REQUIRED:'Ethernet veya Wi-Fi seçin.',DEPLOYMENT_SSID_REQUIRED:'Wi-Fi adını girin.',DEPLOYMENT_DIRECTORY_REQUIRED:'Önce AD bağlantısını hazırlayın.',DEPLOYMENT_GROUP_NOT_FOUND:'AD güvenlik grubu bulunamadı; listeyi yenileyin.',DEPLOYMENT_PROFILE_REQUIRED:'Kimlik türüne uygun sertifika profilini seçin.',DEPLOYMENT_MACHINE_GROUP_MISMATCH:'Bilgisayar hedefi ile bilgisayar sertifika profilinin grubu aynı olmalı.',DEPLOYMENT_PREVIEW_STALE:'Önizlemeden sonra bir bilgi değişti. Yeniden önizleyin.',DEPLOYMENT_ARTIFACT_NOT_READY:'Önizlemedeki eksikleri tamamlayın.',DEPLOYMENT_PLAN_NOT_FOUND:'Plan bulunamadı.',DEPLOYMENT_HTTPS_REQUIRED:'İndirme için HTTPS bağlantısı gerekir.',REVISION_CONFLICT:'Başka bir işlem bilgileri değiştirdi. Taslağınız korunuyor; güncel planı yeniden açın.'};
const depBlockers={PLAN_DEPENDENCY_CHANGED:'Hedef veya sertifika profili değişmiş.',DOMAIN_CHANGED:'AD etki alanı değişmiş.',ENROLLMENT_PROFILE_NOT_ENABLED:'Gerekli sertifika profili kapalı veya bulunamıyor.',MEMBERSHIP_UNAVAILABLE:'AD üyelik önizlemesi henüz hazır değil.',NO_ENABLED_TARGETS:'Etkin hedef hesap bulunamadı.',UNRESOLVED_MEMBERS:'AD grubunda çözümlenemeyen üyeler var.',RADIUS_SERVER_TRUST_NOT_READY:'RADIUS sunucu adı / sertifika zinciri geçerli değil veya henüz hazır değil.'};
function depError(error){return depErrors[error.code]||error.message;}
function depNode(tag,text){const n=document.createElement(tag);if(text!==undefined)n.textContent=String(text??'—');return n;}
function depFeedback(text,error=false){$('dep-feedback').textContent=text;$('dep-feedback').dataset.tone=error?'error':'info';}
function deploymentControls(){
 candidateControls();
 const read=!!can('certificates.authority'),write=!!can('certificates.authority',true);
 $('dep-new').hidden=!write;$('dep-new').disabled=depBusy||!write;$('dep-refresh').disabled=depBusy||!read;
 $('dep-form').querySelectorAll('input,select,button').forEach(x=>x.disabled=depBusy||!write||depUncertain);
 for(const id of ['dep-cancel','dep-close'])$(id).disabled=depBusy;
 $('dep-reconcile').hidden=!depUncertain;$('dep-reconcile').disabled=depBusy||!read;
 if(!depBusy&&!depUncertain&&write){$('dep-machine-profile').disabled=$('dep-mode').value==='user';$('dep-user-profile').disabled=$('dep-mode').value==='machine';$('dep-ssid').disabled=!$('dep-wireless').checked;}
 $('dep-group-prev').disabled=depBusy||depUncertain||!write||depOffset===0;$('dep-group-next').disabled=depBusy||depUncertain||!write||!depState||depOffset+depState.groups.length>=depState.total;
 document.querySelectorAll('[data-dep-write]').forEach(x=>x.disabled=depBusy||!write);document.querySelectorAll('[data-dep-preview]').forEach(x=>x.disabled=depBusy||!read);
 $('dep-download').hidden=!write;$('dep-download').disabled=depBusy||!depPreview?.can_export_profiles||!write;
}
function depSelect(id,items,selected){const select=$(id);select.replaceChildren(new Option('Seçin',''));for(const item of items)select.append(new Option(item.name,item.id||item.sid));if(selected&&!items.some(x=>(x.id||x.sid)===selected))select.append(new Option(depGroups.get(selected)||selected,selected));select.value=selected||'';}
async function loadDeployment(offset=depOffset,force=false){
 if(!can('certificates.authority'))return null;
 if(depFlight&&!force)return depFlight;
 const generation=authGeneration,request=++depRequest,q=$('dep-group-query').value;
 const promise=(async()=>{try{const value=await api('/api/deployment/status?offset='+offset+'&q='+encodeURIComponent(q));if(generation!==authGeneration||request!==depRequest||!can('certificates.authority'))return null;depState=value;depOffset=offset;value.groups.forEach(g=>depGroups.set(g.sid,g.name));renderDeployment();loadCandidateStatus();return value;}catch(error){if(generation===authGeneration&&request===depRequest)depFeedback(depError(error),true);throw error;}finally{if(request===depRequest)depFlight=null;}})();depFlight=promise;return promise;
}
function renderDeployment(){
 const list=$('dep-list');list.replaceChildren();
 for(const p of depState.plans){const row=depNode('tr');row.append(depNode('td',p.name),depNode('td',p.computer_group_name||p.computer_group_sid),depNode('td',depKinds[p.auth_mode]),depNode('td','v'+p.version));const actions=depNode('td');if(can('certificates.authority',true)){const edit=depNode('button','Düzenle');edit.type='button';edit.dataset.depWrite='';edit.addEventListener('click',()=>editDeployment(p));actions.append(edit);}const preview=depNode('button','Önizle');preview.type='button';preview.dataset.depPreview='';preview.disabled=depBusy;preview.addEventListener('click',()=>previewDeployment(p));actions.append(preview);row.append(actions);list.append(row);}
 if(!depState.plans.length){const row=depNode('tr'),cell=depNode('td','Henüz dağıtım planı yok.');cell.colSpan=5;row.append(cell);list.append(row);}
 if($('dep-editor').open){const selected=$('dep-group').value;depSelect('dep-group',depState.groups,selected);}
 deploymentControls();
}
async function editDeployment(plan=null){
 if(depBusy||!can('certificates.authority',true))return;
 try{const value=await loadDeployment(0,true);if(!value)return;depEditing=plan?{...plan}:null;depRevision=value.revision;depUncertain=false;depUncertainDraft=null;$('dep-form').reset();$('dep-form-error').textContent='';
  $('dep-name').value=plan?.name||'';$('dep-mode').value=plan?.auth_mode||'machine';$('dep-wired').checked=plan?.wired??true;$('dep-wireless').checked=plan?.wireless??false;$('dep-ssid').value=plan?.ssid||'';$('dep-server').value=plan?.server_name||value.server_name;
  depSelect('dep-group',value.groups,plan?.computer_group_sid);depSelect('dep-machine-profile',value.machine_profiles,plan?.machine_profile_id);depSelect('dep-user-profile',value.user_profiles,plan?.user_profile_id);
  if(!depEditing)depEditing={id:crypto.randomUUID(),version:0};$('dep-title').textContent=plan?'Dağıtım planını düzenle':'Yeni Windows dağıtımı';$('dep-editor').showModal();deploymentControls();$('dep-name').focus();
 }catch(error){depFeedback(depError(error),true);}
}
function depDraft(){return {id:depEditing.id,version:depEditing.version,name:$('dep-name').value.trim(),computer_group_sid:$('dep-group').value,machine_profile_id:$('dep-mode').value==='user'?'':$('dep-machine-profile').value,user_profile_id:$('dep-mode').value==='machine'?'':$('dep-user-profile').value,wired:$('dep-wired').checked,wireless:$('dep-wireless').checked,ssid:$('dep-wireless').checked?$('dep-ssid').value:'',auth_mode:$('dep-mode').value,server_name:$('dep-server').value.trim()};}
async function saveDeployment(event){
 event.preventDefault();if(depBusy||depUncertain||!can('certificates.authority',true))return;
 const generation=authGeneration,draft=depDraft();let committed=false;depBusy=true;depRequest++;depFlight=null;deploymentControls();$('dep-form-error').textContent='';
 try{await api('/api/deployment/save',{expected_revision:depRevision,plan:draft});committed=true;if(generation!==authGeneration)return;$('dep-editor').close();depPreview=null;$('dep-preview').hidden=true;await loadDeployment(depOffset,true);if(generation===authGeneration)depFeedback('Plan kaydedildi. GPO veya cihaz ayarı uygulanmadı.');}
 catch(error){if(generation!==authGeneration)return;if(committed){depFeedback('Plan kaydedildi; liste okunamadı. Yenile ile kayıtlı sonucu kontrol edin.',true);}else if(!error.status||error.status>=500){depUncertain=true;depUncertainDraft=draft;$('dep-form-error').textContent='Kayıt yanıtı alınamadı. İşlem tekrarlanmadı; önce kayıt sonucunu kontrol edin.';}else $('dep-form-error').textContent=depError(error);}
 finally{if(generation===authGeneration){depBusy=false;deploymentControls();}}
}
async function previewDeployment(plan){
 if(depBusy||!can('certificates.authority'))return;const generation=authGeneration;depBusy=true;deploymentControls();
 try{const p=await api('/api/deployment/preview',{expected_revision:depState.revision,id:plan.id,version:plan.version});if(generation!==authGeneration)return;depPreview=p;const box=$('dep-preview-summary');box.replaceChildren();
  box.append(depNode('p',plan.name+' · v'+plan.version),depNode('p','Bilgisayar hedefi: '+(p.computer_targets.available?p.computer_targets.enabled+' etkin / '+p.computer_targets.count+' toplam':'Üyelik bilgisi yok')));
  if(p.user_targets)box.append(depNode('p','Kullanıcı sertifika hedefi: '+(p.user_targets.available?p.user_targets.enabled+' etkin / '+p.user_targets.count+' toplam':'Üyelik bilgisi yok')));
  box.append(depNode('p','AD okuma zamanı: '+(p.catalog_synced_at||'—')),depNode('p','RADIUS sunucusu: '+p.plan.server_name));
  box.append(depNode('p','Kimlik doğrulama: '+depKinds[p.plan.auth_mode]),depNode('p','Ağ profilleri: '+[p.plan.wired?'Ethernet':'',p.plan.wireless?'Wi-Fi · '+p.plan.ssid:''].filter(Boolean).join(' + ')));
  for(const profile of p.enrollment_profiles)box.append(depNode('p',(profile.id===p.plan.machine_profile_id?'Bilgisayar':'Kullanıcı')+' sertifikası: '+profile.name+' · v'+profile.version));
  if(p.trust.ready)box.append(depNode('p','Güvenilen kök: '+p.trust.root_thumbprint.toUpperCase()));
  p.artifact_blockers.forEach(code=>box.append(depNode('p',depBlockers[code]||code)));
  box.append(depNode('p','GPO uygulaması henüz etkin değil. Hedef sayıları kurulum teyidi değildir.'));$('dep-preview').hidden=false;$('dep-preview').scrollIntoView({block:'nearest',behavior:'smooth'});
 }catch(error){if(generation===authGeneration)depFeedback(depError(error),true);}finally{if(generation===authGeneration){depBusy=false;deploymentControls();}}
}
async function downloadDeployment(){
 if(depBusy||!depPreview?.can_export_profiles||!can('certificates.authority',true))return;const generation=authGeneration,p=depPreview;depBusy=true;deploymentControls();
 try{const value=await api('/api/deployment/package',{expected_revision:p.revision,id:p.id,version:p.version,preview_hash:p.preview_hash});if(generation!==authGeneration)return;const bytes=Uint8Array.from(atob(value.content_base64),c=>c.charCodeAt(0));const url=URL.createObjectURL(new Blob([bytes],{type:'application/zip'}));depURLs.add(url);const a=document.createElement('a');a.href=url;a.download=value.name;a.click();setTimeout(()=>{URL.revokeObjectURL(url);depURLs.delete(url);},1000);}
 catch(error){if(generation===authGeneration){depPreview=null;depFeedback(depError(error),true);}}finally{if(generation===authGeneration){depBusy=false;deploymentControls();}}
}
function resetDeployment(){resetCandidateRegistration();depRequest++;depFlight=null;depState=null;depBusy=false;depUncertain=false;depUncertainDraft=null;depEditing=null;depPreview=null;depOffset=0;depGroups.clear();for(const url of depURLs)URL.revokeObjectURL(url);depURLs.clear();$('dep-editor').close();$('dep-form').reset();$('dep-list').replaceChildren();$('dep-preview-summary').replaceChildren();$('dep-preview').hidden=true;depFeedback('');}
$('dep-new').addEventListener('click',()=>editDeployment());$('dep-form').addEventListener('submit',saveDeployment);$('dep-refresh').addEventListener('click',()=>loadDeployment(depOffset,true).catch(()=>{}));
for(const id of ['dep-close','dep-cancel'])$(id).addEventListener('click',()=>{if(!depBusy)$('dep-editor').close();});$('dep-editor').addEventListener('cancel',event=>{if(depBusy)event.preventDefault();});
$('dep-mode').addEventListener('change',deploymentControls);$('dep-wireless').addEventListener('change',deploymentControls);
$('dep-machine-profile').addEventListener('change',()=>{const p=depState.machine_profiles.find(p=>p.id===$('dep-machine-profile').value);if(p)depSelect('dep-group',depState.groups,p.group_sid);});
$('dep-group-search').addEventListener('click',()=>loadDeployment(0,true).catch(()=>{}));$('dep-group-query').addEventListener('keydown',event=>{if(event.key==='Enter'){event.preventDefault();loadDeployment(0,true).catch(()=>{});}});
$('dep-group-prev').addEventListener('click',()=>loadDeployment(Math.max(0,depOffset-100),true).catch(()=>{}));$('dep-group-next').addEventListener('click',()=>loadDeployment(depOffset+100,true).catch(()=>{}));
$('dep-download').addEventListener('click',downloadDeployment);$('dep-preview-close').addEventListener('click',()=>{$('dep-preview').hidden=true;});
$('dep-reconcile').addEventListener('click',async()=>{if(depBusy)return;const generation=authGeneration;try{const value=await loadDeployment(depOffset,true);if(!value||generation!==authGeneration)return;const p=value.plans.find(p=>p.id===depEditing?.id);if(p&&depUncertainDraft&&p.version===depUncertainDraft.version+1&&Object.keys(depUncertainDraft).every(k=>k==='version'||p[k]===depUncertainDraft[k])){$('dep-editor').close();depUncertain=false;depUncertainDraft=null;depFeedback('Planın kaydedildiği doğrulandı. GPO veya cihaz ayarı uygulanmadı.');}else $('dep-form-error').textContent='Kayıt henüz bulunamadı. İstek tekrarlanmadı; pencereyi kapatıp Yenile ile kontrol edin.';deploymentControls();}catch(error){if(generation===authGeneration)$('dep-form-error').textContent=depError(error);}});

// Operator receipts remain separate from authenticated worker attestation.
let candidateRows=[],candidateBusy=false,candidateTicket=0,candidatePreview=null,candidateRequest=null,candidateUncertain=false;
function candidateAccess(write=false){return can('certificates.authority',write)&&can('system.connectors',write);}
function candidateControls(){
 const read=candidateAccess(),write=candidateAccess(true);
 $('dep-candidates').hidden=!read;$('dep-candidate-open').hidden=!write;
 $('dep-candidate-open').disabled=candidateBusy||candidateVerifyBusy||!write;$('dep-candidate-refresh').disabled=candidateBusy||candidateVerifyBusy||!read;
 $('dep-candidate-json').disabled=candidateBusy||candidateUncertain||!write;
 $('dep-candidate-save').disabled=candidateBusy||candidateUncertain||!write;
 for(const id of ['dep-candidate-close','dep-candidate-cancel'])$(id).disabled=candidateBusy;
}
function resetCandidateRegistration(){
 candidateVerifyTicket++;candidateVerifyBusy=false;candidateVerifySending=false;candidateVerifyUncertain=null;
 candidateTicket++;candidateRows=[];candidateBusy=false;candidatePreview=null;candidateRequest=null;candidateUncertain=false;
 $('dep-candidate-dialog').close();$('dep-candidate-json').value='';$('dep-candidate-list').replaceChildren();
 $('dep-candidate-preview').replaceChildren();$('dep-candidate-error').textContent='';$('dep-candidate-feedback').textContent='';candidateControls();
}
async function loadCandidateStatus(){
 if(!candidateAccess()||candidateVerifySending)return null;
 if(candidateVerifyBusy){candidateVerifyTicket++;candidateVerifyBusy=false;}
 const generation=authGeneration,ticket=++candidateTicket;
 try{const value=await api('/api/deployment/candidates');if(generation!==authGeneration||ticket!==candidateTicket||!candidateAccess())return null;
  candidateRows=value.candidates;const box=$('dep-candidate-list');box.replaceChildren();
  if(candidateVerifyUncertain&&[...(value.verification_jobs||[]),...(value.scope_verification_jobs||[])].some(j=>j.id===candidateVerifyUncertain))candidateVerifyUncertain=null;
  for(const row of candidateRows){const item=depNode('article');const plan=depState?.plans.find(p=>p.id===row.plan_id);
   const job=value.verification_jobs?.find(j=>j.candidate_id===row.id);
   const text=row.state==='outdated'?'Plan veya bağlantı bilgisi değişmiş; yeniden hazırlık gerekiyor.':row.content_verified?'İmza ve içerik Connector tarafından doğrulandı. GPO ve dağıtım kontrolü bekleniyor.':job?.outcome==='content_rejected'?'Connector imza veya içerik doğrulamasını reddetti.':job?.state==='queued'?'Doğrulama görevi bağlantı bekliyor.':job?.state==='leased'?'Connector doğruluyor; sonuç bekleniyor.':'Operatör sonucu kaydedildi. Connector doğrulaması bekleniyor.';
   item.append(depNode('strong',(plan?.name||row.plan_id)+' · v'+row.plan_version),depNode('p',text),depNode('p','Manifest SHA256: '+row.manifest_sha256));
   const scopeJob=value.scope_verification_jobs?.find(j=>j.candidate_id===row.id);
   if(row.scope_snapshot_verified){
    item.append(depNode('p',row.scope_snapshot_fresh?'AD hedefleri ve GPO okuma kontrolü başarılı. Dağıtım henüz uygulanmadı.':'Önceki AD/GPO okuması başarılıydı; güncel kontrol gerekiyor.'));
    if(Number.isInteger(row.scope_checked_at))item.append(depNode('p','AD/GPO kontrol zamanı: '+new Date(row.scope_checked_at*1000).toLocaleString('tr-TR')));
   }else if(row.scope_reason)item.append(depNode('p','AD/GPO kontrolü tamamlanamadı: '+row.scope_reason));
   else if(['queued','leased'].includes(scopeJob?.state))item.append(depNode('p','AD/GPO kontrol görevi bekleniyor.'));
   if(candidateAccess(true)){
    const button=depNode('button','Doğrulamayı önizle');button.type='button';
    button.disabled=candidateVerifyBusy||!!candidateVerifyUncertain||!value.verification_worker_ready||row.state==='outdated'||['queued','leased'].includes(job?.state);
    button.addEventListener('click',()=>previewCandidateVerify(row,value.revision,item));item.append(button);
    if(!value.verification_worker_ready)item.append(depNode('p','Bu görev için Connector güncellemesi ve güncel bağlantı gerekli.'));
    const scopeButton=depNode('button','AD/GPO kontrolünü önizle');scopeButton.type='button';
    scopeButton.disabled=candidateVerifyBusy||!!candidateVerifyUncertain||!value.scope_worker_ready||!row.content_verified||row.state==='outdated'||['queued','leased'].includes(scopeJob?.state);
    scopeButton.addEventListener('click',()=>previewCandidateVerify(row,value.revision,item,'scope'));item.append(scopeButton);
    if(!value.scope_worker_ready)item.append(depNode('p','AD/GPO kontrolü için Windows Connector güncellemesi ve güncel bağlantı gerekli.'));
   }
   box.append(item);}
  if(!candidateRows.length)box.append(depNode('p','Henüz hazırlık sonucu kaydedilmedi.'));candidateControls();return value;
 }catch(error){if(generation===authGeneration&&ticket===candidateTicket)$('dep-candidate-feedback').textContent=error.code||error.message;return null;}
}
let candidateVerifyBusy=false,candidateVerifySending=false,candidateVerifyUncertain=null,candidateVerifyTicket=0;
async function previewCandidateVerify(row,revision,item,kind='verify'){
 if(!['verify','scope'].includes(kind)||candidateVerifyBusy||candidateVerifyUncertain||!candidateAccess(true))return;
 const isScope=kind==='scope',route=isScope?'/api/deployment/candidates/scope/':'/api/deployment/candidates/verify/';
 const generation=authGeneration,ticket=++candidateVerifyTicket;
 const intent={expected_revision:revision,candidate_id:row.id,job_id:crypto.randomUUID(),operation:isScope?'deployment.scope.verify.v1':'candidate.verify.v1'};
 candidateVerifyBusy=true;candidateControls();item.querySelectorAll('button').forEach(b=>b.disabled=true);
 try{
  const p=await api(route+'preview',intent);
  if(generation!==authGeneration||ticket!==candidateVerifyTicket||!candidateAccess(true))return;
  if(p.job_id!==intent.job_id||p.operation!==intent.operation||p.target?.candidate_id!==row.id||p.target?.manifest_sha256!==row.manifest_sha256||p.read_only!==true||p.can_apply!==false||!/^[a-f0-9]{64}$/.test(p.preview_hash))throw Error('Doğrulama önizlemesi doğrulanamadı.');
  if(isScope&&(!Number.isInteger(p.target.target_count)||p.target.target_count<1||p.target.target_count>512||!/^[a-f0-9]{64}$/.test(p.target.target_sids_sha256)))throw Error('AD/GPO hedefleri doğrulanamadı.');
  const box=depNode('div');box.append(depNode('p',isScope?'Connector yalnız canlı AD hedeflerini ve yönetilen GPO kimliğini, izinlerini ve bağlantı durumunu okuyacak. GPO veya cihaz ayarı uygulanmaz.':'Yalnız mevcut adayın imzası ve içeriği okunacak. GPO veya cihaz ayarı uygulanmaz.'));
  if(isScope)box.append(depNode('p','Hedef bilgisayar sayısı: '+p.target.target_count));
  const send=depNode('button',isScope?'AD/GPO kontrolünü gönder':'Doğrulamayı gönder'),cancel=depNode('button','Vazgeç');send.type=cancel.type='button';box.append(send,cancel);item.append(box);
  cancel.addEventListener('click',()=>{if(candidateVerifyBusy){candidateVerifyBusy=false;candidateVerifyTicket++;loadCandidateStatus();}});
  send.addEventListener('click',async()=>{
   if(generation!==authGeneration||ticket!==candidateVerifyTicket||!candidateAccess(true))return;
   send.disabled=cancel.disabled=true;candidateVerifySending=true;candidateVerifyTicket++;
   try{
    const r=await api(route+'create',{...intent,preview_hash:p.preview_hash});
    if(generation!==authGeneration)return;
    if(r.job_id!==intent.job_id||r.recorded!==true||r.can_apply!==false)throw Error('Görev yanıtı doğrulanamadı.');
    $('dep-candidate-feedback').textContent=isScope?'AD/GPO kontrol görevi kaydedildi. Sonucu görmek için Yenile düğmesini kullanın.':'Doğrulama görevi kaydedildi. Sonucu görmek için Yenile düğmesini kullanın.';
   }catch(error){if(generation!==authGeneration)return;
    if(!error.status||error.status>=500){candidateVerifyUncertain=intent.job_id;$('dep-candidate-feedback').textContent='Gönderim sonucu alınamadı. İstek tekrarlanmadı; Yenile ile kontrol edin.';}
    else $('dep-candidate-feedback').textContent=error.code||error.message;
   }finally{if(generation===authGeneration){candidateVerifyBusy=false;candidateVerifySending=false;await loadCandidateStatus();}}
  },{once:true});
 }catch(error){if(generation===authGeneration){candidateVerifyBusy=false;$('dep-candidate-feedback').textContent=error.code||error.message;await loadCandidateStatus();}}
}
$('dep-candidate-refresh').addEventListener('click',()=>loadCandidateStatus());
$('dep-candidate-open').addEventListener('click',async()=>{
 if(candidateBusy||!candidateAccess(true))return;const value=await loadCandidateStatus();if(!value||!candidateAccess(true))return;
 candidateRequest={expected_revision:value.revision,registration_id:crypto.randomUUID(),receipt_json:''};candidatePreview=null;candidateUncertain=false;
 $('dep-candidate-json').value='';$('dep-candidate-preview').replaceChildren();$('dep-candidate-error').textContent='';$('dep-candidate-save').textContent='Önizle';$('dep-candidate-dialog').showModal();candidateControls();
});
for(const id of ['dep-candidate-close','dep-candidate-cancel'])$(id).addEventListener('click',()=>{if(!candidateBusy)$('dep-candidate-dialog').close();});
$('dep-candidate-dialog').addEventListener('cancel',event=>{if(candidateBusy)event.preventDefault();});
$('dep-candidate-json').addEventListener('input',()=>{candidatePreview=null;$('dep-candidate-preview').replaceChildren();$('dep-candidate-save').textContent='Önizle';});
$('dep-candidate-form').addEventListener('submit',async event=>{
 event.preventDefault();if(candidateBusy||candidateUncertain||!candidateRequest||!candidateAccess(true))return;
 const generation=authGeneration,recording=!!candidatePreview;candidateBusy=true;candidateControls();$('dep-candidate-error').textContent='';
 try{
  if(!recording){candidateRequest.receipt_json=$('dep-candidate-json').value;const preview=await api('/api/deployment/candidates/preview',candidateRequest);
   if(generation!==authGeneration||!candidateAccess(true))return;candidatePreview=preview;
   const box=$('dep-candidate-preview');box.replaceChildren(depNode('p','Plan: '+preview.plan_id+' · v'+preview.plan_version),depNode('p','GPO: '+preview.gpo_id),depNode('p','Manifest: '+preview.manifest_sha256),depNode('p','Yalnız operatör bildirimi kaydedilecek. Connector doğrulaması veya GPO uygulaması yapılmaz.'));$('dep-candidate-save').textContent='Kaydet';
  }else{const result=await api('/api/deployment/candidates/record',{...candidateRequest,preview_hash:candidatePreview.preview_hash});
   if(generation!==authGeneration)return;$('dep-candidate-dialog').close();await loadCandidateStatus();if(generation===authGeneration)$('dep-candidate-feedback').textContent='Hazırlık sonucu kaydedildi. Connector doğrulaması bekleniyor.';
  }
 }catch(error){if(generation!==authGeneration)return;
  if(recording&&(!error.status||error.status>=500)){candidateUncertain=true;const status=await loadCandidateStatus();if(generation!==authGeneration)return;
   if(status?.candidates.some(r=>r.id===candidateRequest.registration_id)){$('dep-candidate-dialog').close();$('dep-candidate-feedback').textContent='Kaydın tamamlandığı doğrulandı. GPO uygulanmadı.';}
   else $('dep-candidate-error').textContent='Kayıt yanıtı alınamadı. İşlem tekrarlanmadı; pencereyi kapatıp Yenile ile sonucu kontrol edin.';
  }else{candidatePreview=null;$('dep-candidate-save').textContent='Önizle';$('dep-candidate-error').textContent=error.code||error.message;}
 }finally{if(generation===authGeneration){candidateBusy=false;candidateControls();}}
});

// Interactive panel pairing only. The server owns authorization and the binding.
let connectorState=null,connectorBusy=false,connectorPreview=null,connectorUncertain=null,connectorTicket=0,connectorReadable=false;
const connectorURLs=new Set();
const connectorFields=['instance_id','connector_id','host_guid','host_fqdn','service_sid','appliance_fqdn','appliance_tls_sha256','public_key_pem'];
const connectorErrors={CONNECTOR_ALREADY_PAIRED:'Bir Windows bağlantısı zaten eşleştirilmiş. Durumu yenileyin.',CONNECTOR_CONTEXT_NOT_READY:'AuthWire adı, domain veya HTTPS sertifikası hazır değil.',CONNECTOR_SCOPE_MISMATCH:'Bu genel anahtar adayı bu AuthWire kurulumu veya domain ile eşleşmiyor.',CONNECTOR_BINDING_INVALID:'Bağlantı kimliklerini ve genel anahtarı kontrol edin.',CONNECTOR_KEY_INVALID:'Geçerli bir Connector RSA genel anahtarı gerekli.',CONNECTOR_KEY_CONFIRMATION_REQUIRED:'DC01 çıktısındaki KeySha256 değerini eksiksiz karşılaştırın.',CONNECTOR_PREVIEW_STALE:'Bilgiler değişmiş. Durumu yenileyip yeniden önizleyin.',REVISION_CONFLICT:'Başka bir işlem bilgileri değiştirdi. Durumu yenileyip yeniden önizleyin.',CONNECTOR_PANEL_SESSION_REQUIRED:'Bu işlem için panel kullanıcı oturumu gerekli.',CONNECTOR_HTTPS_REQUIRED:'Eşleştirme için HTTPS bağlantısı gerekli.',CONNECTOR_INPUT_INVALID:'Eşleştirme adayı okunamadı.'};
function connectorFeedback(text,error=false){$('connector-feedback').textContent=text;$('connector-feedback').dataset.tone=error?'error':'info';}
function connectorError(error){return connectorErrors[error.code]||error.message||'Eşleştirme tamamlanamadı.';}
// Candidate JSON is a flat string-only object. Parse its grammar explicitly so
// duplicate keys cannot silently replace a key/identity before server preview.
function connectorParseCandidate(raw){
 if(typeof raw!=='string'||raw.length>16384)throw Error('Genel anahtar adayı en fazla 16 KB olabilir.');
 let p=0;const value=Object.create(null),seen=new Set();
 const ws=()=>{while(p<raw.length&&/[\t\n\r ]/.test(raw[p]))p++;};
 function string(){ws();if(raw[p]!=='"')throw Error('Aday, yalnız metin alanları içeren bir JSON nesnesi olmalı.');const start=p++;let escape=false;while(p<raw.length){const c=raw[p++];if(escape){escape=false;continue;}if(c==='\\'){escape=true;continue;}if(c==='"')return JSON.parse(raw.slice(start,p));}throw Error('JSON metni tamamlanmamış.');}
 ws();if(raw[p++]!=='{')throw Error('PairingCandidate JSON nesnesini yapıştırın.');ws();
 if(raw[p]!=='}')for(;;){const key=string();if(!connectorFields.includes(key)||seen.has(key))throw Error('Adayda eksik, yinelenen veya tanınmayan alan var.');seen.add(key);ws();if(raw[p++]!==':')throw Error('JSON alanı okunamadı.');value[key]=string();ws();if(raw[p]!==',')break;p++;}
 if(raw[p++]!=='}')throw Error('JSON nesnesi tamamlanmamış.');ws();if(p!==raw.length||seen.size!==connectorFields.length)throw Error('PairingCandidate içindeki sekiz alanı eksiksiz yapıştırın.');
 return value;
}
function connectorClearPreview(){connectorPreview=null;$('connector-preview').hidden=true;$('connector-preview-summary').replaceChildren();$('connector-key-confirm').value='';}
function resetConnector(){connectorTicket++;connectorState=null;connectorBusy=false;connectorReadable=false;connectorUncertain=null;connectorClearPreview();$('connector-candidate').value='';$('connector-summary').replaceChildren();$('connector-status').textContent='';connectorFeedback('');for(const url of connectorURLs)URL.revokeObjectURL(url);connectorURLs.clear();$('connector-form').hidden=true;resetConnectorJobs();}
function connectorPermissions(){
 const read=!!can('system.connectors'),write=!!can('system.connectors',true);
 if(!read){resetConnector();return;}
 if(!write&&(connectorPreview||$('connector-candidate').value)){connectorTicket++;connectorBusy=false;connectorClearPreview();$('connector-candidate').value='';}
 $('connector-refresh').disabled=connectorBusy||!read;
 $('connector-form').hidden=!write||!!connectorState?.paired;
 $('connector-candidate').disabled=connectorBusy||!write||!!connectorUncertain;
 $('connector-preview-button').disabled=connectorBusy||!connectorReadable||!write||!!connectorUncertain||!$('connector-candidate').value.trim();
 $('connector-key-confirm').disabled=connectorBusy||!write||!!connectorUncertain;
 const key=$('connector-key-confirm').value.trim().toLowerCase();
 $('connector-apply').disabled=connectorBusy||!write||!!connectorUncertain||!connectorPreview||key!==connectorPreview.after.channel_key_sha256;
 $('connector-reconcile').hidden=!connectorUncertain;$('connector-reconcile').disabled=connectorBusy||!read;
 $('connector-export').hidden=!connectorState?.paired||!connectorState?.scope_matches;
 $('connector-export').disabled=connectorBusy||!read;
 connectorJobPermissions();
}
function connectorRow(parent,title,value){const line=depNode('p');line.append(depNode('strong',title+': '),depNode('span',value));parent.append(line);}
function renderConnector(){
 const s=connectorState,box=$('connector-summary');box.replaceChildren();if(!s)return;
 $('connector-status').textContent=!s.paired?'Henüz eşleştirilmedi.':!s.scope_matches?'Eşleştirme kapsamı değişmiş; inceleme gerekli.':s.online?'Connector bağlantı kanalı çevrimiçi.':'Eşleştirildi. Connector bağlantısı bekleniyor.';
 if(s.binding){connectorRow(box,'Windows sunucusu',s.binding.host_fqdn);connectorRow(box,'Anahtar kimliği (KeySha256)',s.binding.channel_key_sha256);connectorRow(box,'Eşleştirme sürümü',s.binding.generation);}
 connectorPermissions();
}
function connectorSameBinding(binding,expected){return !!binding&&['instance_id','connector_id','host_guid','host_fqdn','service_sid','appliance_fqdn','appliance_tls_sha256','generation','channel_key_sha256'].every(k=>binding[k]===expected[k]);}
function connectorReadMatches(s,expected){return !!s?.paired&&!!s.scope_matches&&connectorSameBinding(s.binding,expected);}
function connectorFinished(){connectorUncertain=null;connectorClearPreview();$('connector-candidate').value='';connectorFeedback('Windows bağlantısı eşleştirildi. Servis bağlantısı ayrıca doğrulanacak.');}
async function loadConnector(){
 if(connectorBusy||!can('system.connectors'))return;
 const generation=authGeneration,ticket=++connectorTicket;connectorBusy=true;connectorReadable=false;connectorClearPreview();connectorPermissions();
 try{const s=await api('/api/deployment/connector');if(generation!==authGeneration||ticket!==connectorTicket||!can('system.connectors'))return;connectorState=s;connectorReadable=true;if(connectorUncertain){if(connectorReadMatches(s,connectorUncertain.after))connectorFinished();else connectorFeedback('Kayıt sonucu henüz doğrulanamadı. Eşleştirme isteği tekrarlanmadı; güncel durumu inceleyin.',true);}renderConnector();if(s.paired&&s.scope_matches)await loadConnectorJobs();}
 catch(error){if(generation===authGeneration&&ticket===connectorTicket)connectorFeedback(connectorError(error),true);}
 finally{if(generation===authGeneration&&ticket===connectorTicket){connectorBusy=false;connectorPermissions();}}
}
function openConnector(view){if(view==='windows-connector')loadConnector();}
async function previewConnector(event){
 event.preventDefault();if(connectorBusy||connectorUncertain||!connectorReadable||connectorState?.paired||!can('system.connectors',true))return;
 let candidate;const raw=$('connector-candidate').value;try{candidate=connectorParseCandidate(raw);}catch(error){connectorClearPreview();connectorFeedback(error.message,true);connectorPermissions();return;}
 const generation=authGeneration,ticket=++connectorTicket,intent={expected_revision:connectorState.revision,operation:'pair',candidate};connectorClearPreview();connectorBusy=true;connectorPermissions();connectorFeedback('');
 try{const p=await api('/api/deployment/connector/preview',intent);if(generation!==authGeneration||ticket!==connectorTicket||!can('system.connectors',true))return;
  if(raw!==$('connector-candidate').value)throw Error('Aday değişmiş. Yeniden önizleyin.');
  if(p.operation!=='pair'||p.revision!==intent.expected_revision||typeof p.preview_hash!=='string'||!/^[a-f0-9]{64}$/.test(p.preview_hash)||!p.after||!Number.isInteger(p.after.generation)||p.after.generation<1||!/^[a-f0-9]{64}$/.test(p.after.channel_key_sha256)||!connectorFields.filter(k=>k!=='public_key_pem').every(k=>p.after[k]===candidate[k])||p.can_apply_gpo!==false)throw Error('Sunucunun eşleştirme önizlemesi doğrulanamadı.');
  connectorPreview={...p,intent,raw};const box=$('connector-preview-summary');box.replaceChildren();connectorRow(box,'Windows sunucusu',p.after.host_fqdn);connectorRow(box,'AuthWire sunucusu',p.after.appliance_fqdn);connectorRow(box,'Connector kimliği',p.after.connector_id);connectorRow(box,'Anahtar kimliği (KeySha256)',p.after.channel_key_sha256);$('connector-preview').hidden=false;$('connector-key-confirm').focus();
 }catch(error){if(generation===authGeneration&&ticket===connectorTicket)connectorFeedback(connectorError(error),true);}
 finally{if(generation===authGeneration&&ticket===connectorTicket){connectorBusy=false;connectorPermissions();}}
}
async function applyConnector(){
 const p=connectorPreview,key=$('connector-key-confirm').value.trim().toLowerCase();
 if(connectorBusy||connectorUncertain||!p||!can('system.connectors',true)||p.raw!==$('connector-candidate').value||key!==p.after.channel_key_sha256)return;
 const generation=authGeneration,ticket=++connectorTicket;connectorBusy=true;connectorPermissions();connectorFeedback('');let committed=false;
 try{const applied=await api('/api/deployment/connector/apply',{...p.intent,preview_hash:p.preview_hash,confirmed_key_sha256:key});committed=true;
  if(generation!==authGeneration||ticket!==connectorTicket||!can('system.connectors',true))return;
  if(!connectorSameBinding(applied.binding,p.after)||applied.runtime_applied!==false||applied.ad_changed!==false||applied.gpo_changed!==false)throw Error('Eşleştirme yanıtı okunamadı. Kayıt sonucunu kontrol edin.');
  const s=await api('/api/deployment/connector');if(generation!==authGeneration||ticket!==connectorTicket||!can('system.connectors'))return;connectorState=s;connectorReadable=true;
  if(!connectorReadMatches(s,p.after))throw Error('Güncel eşleştirme önizlemeyle aynı değil. Kayıt sonucunu kontrol edin.');
  connectorFinished();renderConnector();
 }catch(error){if(generation!==authGeneration||ticket!==connectorTicket)return;if(committed||!error.status||error.status>=500){connectorUncertain={after:p.after};connectorFeedback('Eşleştirme sonucu kesinleştirilemedi. İstek tekrarlanmadı; Kayıt sonucunu kontrol et düğmesini kullanın.',true);}else{connectorClearPreview();connectorReadable=false;connectorFeedback(connectorError(error),true);}}
 finally{if(generation===authGeneration&&ticket===connectorTicket){connectorBusy=false;connectorPermissions();}}
}
function exportConnectorBinding(){
 const b=connectorState?.binding;if(!can('system.connectors')||!connectorState?.paired||!connectorState?.scope_matches||connectorBusy)return;
 const fields=['instance_id','connector_id','generation','host_guid','host_fqdn','service_sid','appliance_fqdn','appliance_tls_sha256','channel_key_sha256'];
 const base=new URL(location.origin);base.hostname=b.appliance_fqdn;
 const value={Format:'AuthWireConnectorBindingPublicV1',BaseUrl:base.href,Binding:Object.fromEntries(fields.map(k=>[k,b[k]])),Domain:b.domain};
 const url=URL.createObjectURL(new Blob([JSON.stringify(value,null,2)+'\n'],{type:'application/json'}));connectorURLs.add(url);const a=document.createElement('a');a.href=url;a.download='AuthWire-Connector-Binding.json';a.click();setTimeout(()=>{URL.revokeObjectURL(url);connectorURLs.delete(url);},1000);
}
$('connector-form').addEventListener('submit',previewConnector);$('connector-refresh').addEventListener('click',loadConnector);$('connector-reconcile').addEventListener('click',loadConnector);$('connector-apply').addEventListener('click',applyConnector);$('connector-export').addEventListener('click',exportConnectorBinding);
$('connector-candidate').addEventListener('input',()=>{if(!connectorBusy){connectorClearPreview();connectorFeedback('');}connectorPermissions();});$('connector-key-confirm').addEventListener('input',connectorPermissions);

// Read-only probe tasks. An uncertain create is reconciled only by GET/id.
let connectorJobsState=null,connectorJobBusy=false,connectorJobTicket=0,connectorJobPreview=null,connectorJobUncertain=null;
function connectorJobFeedback(text){$('connector-job-feedback').textContent=text;}
function resetConnectorJobs(){connectorJobTicket++;connectorJobsState=null;connectorJobBusy=false;connectorJobPreview=null;connectorJobUncertain=null;$('connector-jobs').hidden=true;$('connector-job-list').replaceChildren();$('connector-job-preview').hidden=true;$('connector-job-capability').textContent='';connectorJobFeedback('');}
function connectorJobPermissions(){
 const read=!!can('system.connectors'),write=!!can('system.connectors',true),paired=!!connectorState?.paired&&!!connectorState?.scope_matches;
 $('connector-jobs').hidden=!read||!paired;
 if(!write&&connectorJobPreview){connectorJobTicket++;connectorJobPreview=null;connectorJobBusy=false;}
 $('connector-job-preview').hidden=!write||!connectorJobPreview;
 $('connector-job-preview-button').hidden=!write;
 $('connector-job-preview-button').disabled=connectorBusy||connectorJobBusy||!!connectorJobUncertain||!paired||!connectorJobsState;
 $('connector-job-create').disabled=connectorBusy||connectorJobBusy||!write||!connectorJobPreview||!!connectorJobUncertain;
 $('connector-job-cancel').disabled=connectorJobBusy;
 $('connector-job-refresh').disabled=connectorJobBusy||!read;
}
function renderConnectorJobs(){
 const s=connectorJobsState,box=$('connector-job-list');box.replaceChildren();if(!s)return;
 $('connector-job-capability').textContent=s.worker_probe_ready?'Salt okunur görev kanalı hazır.':'Connector görev desteği henüz doğrulanmadı. Gönderilen test görevi bağlantı bekleyebilir.';
 const names={queued:'Bağlantı bekliyor',leased:'Sonuç bekleniyor',completed:'Tamamlandı',expired:'Süresi doldu',obsolete:'Eşleştirme değişti'};
 for(const j of s.jobs){const row=depNode('tr');row.append(depNode('td',new Date(j.created_at*1000).toLocaleString()),depNode('td',j.id),depNode('td','Bağlantı testi'),depNode('td',names[j.state]||'Bilinmiyor'),depNode('td',j.result?.release_id||'—'));box.append(row);}
 if(!s.jobs.length){const row=depNode('tr'),cell=depNode('td','Henüz görev oluşturulmadı.');cell.colSpan=5;row.append(cell);box.append(row);}
 connectorJobPermissions();
}
async function loadConnectorJobs(){
 if(connectorJobBusy||!can('system.connectors')||!connectorState?.paired||!connectorState?.scope_matches)return;
 const generation=authGeneration,ticket=++connectorJobTicket;connectorJobBusy=true;connectorJobPreview=null;connectorJobPermissions();
 try{const s=await api('/api/deployment/connector/jobs');if(generation!==authGeneration||ticket!==connectorJobTicket||!can('system.connectors'))return;
  if(s.probe_only!==true||s.can_apply!==false||!Array.isArray(s.jobs))throw Error('Görev durumu doğrulanamadı.');
  connectorJobsState=s;
  if(connectorJobUncertain){if(s.jobs.some(j=>j.id===connectorJobUncertain)){connectorJobUncertain=null;connectorJobFeedback('Test görevinin kaydedildiği doğrulandı.');}else connectorJobFeedback('Görev kaydı henüz doğrulanamadı. Gönderme isteği tekrarlanmadı; durumu yenileyin.');}
  renderConnectorJobs();
 }catch(error){if(generation===authGeneration&&ticket===connectorJobTicket)connectorJobFeedback(error.message||'Görevler okunamadı.');}
 finally{if(generation===authGeneration&&ticket===connectorJobTicket){connectorJobBusy=false;connectorJobPermissions();}}
}
async function previewConnectorJob(){
 if(connectorJobBusy||connectorBusy||connectorJobUncertain||!connectorJobsState||!can('system.connectors',true))return;
 const generation=authGeneration,ticket=++connectorJobTicket,intent={expected_revision:connectorJobsState.revision,job_id:crypto.randomUUID(),operation:'connector.probe'};
 connectorJobBusy=true;connectorJobPreview=null;connectorJobFeedback('');connectorJobPermissions();
 try{const p=await api('/api/deployment/connector/jobs/preview',intent);if(generation!==authGeneration||ticket!==connectorJobTicket||!can('system.connectors',true))return;
  if(p.job_id!==intent.job_id||p.operation!=='connector.probe'||p.read_only!==true||p.gpo_changed!==false||p.can_apply!==false||!/^[a-f0-9]{64}$/.test(p.preview_hash))throw Error('Görev önizlemesi doğrulanamadı.');
  connectorJobPreview={intent,preview_hash:p.preview_hash};
 }catch(error){if(generation===authGeneration&&ticket===connectorJobTicket)connectorJobFeedback(error.code==='REVISION_CONFLICT'?'Bilgiler değişmiş. Görev durumunu yenileyip yeniden önizleyin.':error.message||'Görev önizlenemedi.');}
 finally{if(generation===authGeneration&&ticket===connectorJobTicket){connectorJobBusy=false;connectorJobPermissions();}}
}
async function createConnectorJob(){
 const p=connectorJobPreview;if(!p||connectorJobBusy||connectorBusy||connectorJobUncertain||!can('system.connectors',true))return;
 const generation=authGeneration,ticket=++connectorJobTicket;connectorJobBusy=true;connectorJobPermissions();
 try{const r=await api('/api/deployment/connector/jobs/create',{...p.intent,preview_hash:p.preview_hash});if(generation!==authGeneration||ticket!==connectorJobTicket||!can('system.connectors',true))return;
  if(r.job_id!==p.intent.job_id||r.recorded!==true||r.read_only!==true||r.gpo_changed!==false)throw Error('Görev kaydı doğrulanamadı.');
  connectorJobFeedback('Test görevi kaydedildi. Sonucu görmek için görev durumunu yenileyin.');connectorJobPreview=null;
 }catch(error){if(generation!==authGeneration||ticket!==connectorJobTicket)return;if(!error.status||error.status>=500){connectorJobUncertain=p.intent.job_id;connectorJobFeedback('Gönderim sonucu kesinleşmedi. İstek tekrarlanmadı; görev durumunu yenileyin.');}else connectorJobFeedback(error.message||'Görev oluşturulamadı.');connectorJobPreview=null;}
 finally{if(generation===authGeneration&&ticket===connectorJobTicket){connectorJobBusy=false;connectorJobPermissions();}}
 if(generation===authGeneration&&ticket===connectorJobTicket&&!connectorJobUncertain)await loadConnectorJobs();
}
$('connector-job-refresh').addEventListener('click',loadConnectorJobs);
$('connector-job-preview-button').addEventListener('click',previewConnectorJob);
$('connector-job-create').addEventListener('click',createConnectorJob);
$('connector-job-cancel').addEventListener('click',()=>{if(!connectorJobBusy){connectorJobPreview=null;connectorJobPermissions();}});
