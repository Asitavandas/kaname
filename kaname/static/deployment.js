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
 const promise=(async()=>{try{const value=await api('/api/deployment/status?offset='+offset+'&q='+encodeURIComponent(q));if(generation!==authGeneration||request!==depRequest||!can('certificates.authority'))return null;depState=value;depOffset=offset;value.groups.forEach(g=>depGroups.set(g.sid,g.name));renderDeployment();return value;}catch(error){if(generation===authGeneration&&request===depRequest)depFeedback(depError(error),true);throw error;}finally{if(request===depRequest)depFlight=null;}})();depFlight=promise;return promise;
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
  if(p.trust.ready)box.append(depNode('p','Güvenilen kök: '+p.trust.root_thumbprint.toUpperCase()));
  p.artifact_blockers.forEach(code=>box.append(depNode('p',depBlockers[code]||code)));
  box.append(depNode('p','GPO uygulaması: Windows yönetim bağlantısının kurulması bekleniyor. Hedef sayıları kurulum teyidi değildir.'));$('dep-preview').hidden=false;$('dep-preview').scrollIntoView({block:'nearest',behavior:'smooth'});
 }catch(error){if(generation===authGeneration)depFeedback(depError(error),true);}finally{if(generation===authGeneration){depBusy=false;deploymentControls();}}
}
async function downloadDeployment(){
 if(depBusy||!depPreview?.can_export_profiles||!can('certificates.authority',true))return;const generation=authGeneration,p=depPreview;depBusy=true;deploymentControls();
 try{const value=await api('/api/deployment/package',{expected_revision:p.revision,id:p.id,version:p.version,preview_hash:p.preview_hash});if(generation!==authGeneration)return;const bytes=Uint8Array.from(atob(value.content_base64),c=>c.charCodeAt(0));const url=URL.createObjectURL(new Blob([bytes],{type:'application/zip'}));depURLs.add(url);const a=document.createElement('a');a.href=url;a.download=value.name;a.click();setTimeout(()=>{URL.revokeObjectURL(url);depURLs.delete(url);},1000);}
 catch(error){if(generation===authGeneration){depPreview=null;depFeedback(depError(error),true);}}finally{if(generation===authGeneration){depBusy=false;deploymentControls();}}
}
function resetDeployment(){depRequest++;depFlight=null;depState=null;depBusy=false;depUncertain=false;depUncertainDraft=null;depEditing=null;depPreview=null;depOffset=0;depGroups.clear();for(const url of depURLs)URL.revokeObjectURL(url);depURLs.clear();$('dep-editor').close();$('dep-form').reset();$('dep-list').replaceChildren();$('dep-preview-summary').replaceChildren();$('dep-preview').hidden=true;depFeedback('');}
$('dep-new').addEventListener('click',()=>editDeployment());$('dep-form').addEventListener('submit',saveDeployment);$('dep-refresh').addEventListener('click',()=>loadDeployment(depOffset,true).catch(()=>{}));
for(const id of ['dep-close','dep-cancel'])$(id).addEventListener('click',()=>{if(!depBusy)$('dep-editor').close();});$('dep-editor').addEventListener('cancel',event=>{if(depBusy)event.preventDefault();});
$('dep-mode').addEventListener('change',deploymentControls);$('dep-wireless').addEventListener('change',deploymentControls);
$('dep-machine-profile').addEventListener('change',()=>{const p=depState.machine_profiles.find(p=>p.id===$('dep-machine-profile').value);if(p)depSelect('dep-group',depState.groups,p.group_sid);});
$('dep-group-search').addEventListener('click',()=>loadDeployment(0,true).catch(()=>{}));$('dep-group-query').addEventListener('keydown',event=>{if(event.key==='Enter'){event.preventDefault();loadDeployment(0,true).catch(()=>{});}});
$('dep-group-prev').addEventListener('click',()=>loadDeployment(Math.max(0,depOffset-100),true).catch(()=>{}));$('dep-group-next').addEventListener('click',()=>loadDeployment(depOffset+100,true).catch(()=>{}));
$('dep-download').addEventListener('click',downloadDeployment);$('dep-preview-close').addEventListener('click',()=>{$('dep-preview').hidden=true;});
$('dep-reconcile').addEventListener('click',async()=>{if(depBusy)return;const generation=authGeneration;try{const value=await loadDeployment(depOffset,true);if(!value||generation!==authGeneration)return;const p=value.plans.find(p=>p.id===depEditing?.id);if(p&&depUncertainDraft&&p.version===depUncertainDraft.version+1&&Object.keys(depUncertainDraft).every(k=>k==='version'||p[k]===depUncertainDraft[k])){$('dep-editor').close();depUncertain=false;depUncertainDraft=null;depFeedback('Planın kaydedildiği doğrulandı. GPO veya cihaz ayarı uygulanmadı.');}else $('dep-form-error').textContent='Kayıt henüz bulunamadı. İstek tekrarlanmadı; pencereyi kapatıp Yenile ile kontrol edin.';deploymentControls();}catch(error){if(generation===authGeneration)$('dep-form-error').textContent=depError(error);}});
