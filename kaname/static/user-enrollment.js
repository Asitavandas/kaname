/* User certificate management. No Windows/GPO or signer action runs on page open. */
let ueState=null,ueOffset=0,ueRequest=0,ueFlight=null,ueEditing=null,ueEditorEpoch=0;
let ueBusy=false,ueUncertain=null,ueGroupsOffset=0,ueGroupsRequest=0,ueGroupsTotal=0,ueGroupsLength=0;
const ueGroups=new Map(),ueDownloads=new Set();
const ueErrors={
 USER_DIRECTORY_NOT_READY:'Önce AD bağlantısını hazırlayın.',USER_PROFILE_NOT_FOUND:'Kullanıcı profili bulunamadı. Listeyi yenileyin.',
 USER_PROFILE_LIMIT:'En fazla 100 kullanıcı profili oluşturulabilir.',USER_INPUT_INVALID:'Profil adı, AD grubu ve süreleri kontrol edin.',
 USER_SETUP_REQUIRED:'Kullanıcı kaydı için HTTPS ve sunucuyla eşleşen DNS/sertifika yapılandırması gerekiyor.',
 USER_CERTIFICATE_UNAVAILABLE:'Sertifika kurulu, geçerli ve iptal edilmemiş olmalı. Kayıtlı durumu yenileyip kontrol edin.',USER_CERTIFICATE_NOT_FOUND:'Kullanıcı sertifikası bulunamadı.',USER_CERTIFICATE_REVOKED:'İptal edilmiş sertifika için yenileme talebi oluşturulamaz.',
 USER_CERTIFICATE_EXPIRED:'Süresi dolmuş sertifika normal kurtarma/kayıt akışıyla ele alınmalı.',
 USER_INSTALLATION_PENDING:'Sertifikanın istemci kurulum teyidi henüz gelmedi.',
 REVISION_CONFLICT:'Profil başka bir işlemde değişti. Düzenlemeleriniz korunuyor; pencereyi kapatıp güncel profili yeniden açın.'
};
function ueText(error){return ueErrors[error.code]||ueErrors[error.message]||error.message;}
function ueCurrent(generation){return generation===authGeneration&&!!can('certificates.authority');}
function ueFeedback(text,error=false){for(const id of ['ue-profile-feedback','ue-record-feedback']){$(id).textContent=text;$(id).dataset.tone=error?'error':'info';}}
function ueNode(tag,text,className){const node=document.createElement(tag);if(text!==undefined)node.textContent=String(text??'—');if(className)node.className=className;return node;}
function ueDate(value){if(!value)return '—';const date=new Date(value);return Number.isNaN(date.valueOf())?'—':date.toLocaleString('tr-TR');}
function ueControls(){
 const write=!!can('certificates.authority',true),open=$('ue-editor').open;
 $('ue-new').hidden=!write;$('ue-new').disabled=!write||ueBusy;
 for(const id of ['ue-refresh','ue-record-refresh'])$(id).disabled=ueBusy||!can('certificates.authority');
 $('ue-form').querySelectorAll('input,select,button').forEach(input=>input.disabled=!write||ueBusy||!!ueUncertain);
 for(const id of ['ue-cancel','ue-close'])$(id).disabled=ueBusy;
 $('ue-reconcile').hidden=!ueUncertain;$('ue-reconcile').disabled=ueBusy||!write;
 if(ueUncertain){$('ue-cancel').disabled=false;$('ue-close').disabled=false;}
 $('ue-group-previous').disabled=!open||!write||ueBusy||!!ueUncertain||ueGroupsOffset===0;
 $('ue-group-next').disabled=!open||!write||ueBusy||!!ueUncertain||ueGroupsOffset+ueGroupsLength>=ueGroupsTotal;
 $('ue-previous').disabled=!ueState||ueBusy||ueOffset===0;
 $('ue-next').disabled=!ueState||ueBusy||ueOffset+ueState.users.length>=ueState.total;
 document.querySelectorAll('[data-ue-mutation]').forEach(button=>button.disabled=!write||ueBusy);
}
async function loadUserEnrollment(offset=ueOffset,force=false){
 if(!can('certificates.authority'))return null;
 if(force){ueRequest++;ueFlight=null;}
 const generation=authGeneration;
 if(ueFlight?.offset===offset&&ueFlight.auth===generation)return ueFlight.promise;
 const request=++ueRequest;
 const promise=(async()=>{
  try{
   const value=await api('/api/user-admin/status?offset='+offset);
   if(request!==ueRequest||!ueCurrent(generation))return null;
   ueState=value;ueOffset=value.offset;renderUserEnrollment();return value;
  }catch(error){if(request===ueRequest&&ueCurrent(generation)&&error.code!=='SESSION_CHANGED')ueFeedback(ueText(error),true);throw error;}
  finally{if(ueFlight?.request===request)ueFlight=null;}
 })();ueFlight={offset,auth:generation,request,promise};return promise;
}
function renderUserEnrollment(){
 const profiles=$('ue-profiles');profiles.replaceChildren();
 for(const profile of ueState.profiles){
  const row=ueNode('tr');row.append(ueNode('td',profile.name));
  const group=ueNode('td',profile.group_name||ueGroups.get(profile.group_sid)||'AD güvenlik grubu');group.append(ueNode('small',profile.group_sid));row.append(group);
  row.append(ueNode('td',profile.validity_days+' gün'),ueNode('td','Bitmeden '+profile.renew_before_days+' gün önce'));
  const status=ueNode('td');status.append(ueNode('span',profile.enabled?'Açık':'Kapalı','certificate-status '+(profile.enabled?'valid':'expired')));row.append(status);
  const actions=ueNode('td');const buttons=ueNode('div',undefined,'actions');
  if(can('certificates.authority',true)){
   const edit=ueNode('button','Düzenle');edit.type='button';edit.dataset.ueMutation='';edit.addEventListener('click',()=>editUserProfile(profile));
   const download=ueNode('button','Kullanıcı paketi');download.type='button';download.dataset.ueMutation='';download.addEventListener('click',()=>downloadUserPackage(profile));buttons.append(edit,download);
  }else buttons.textContent='Salt okunur';actions.append(buttons);row.append(actions);profiles.append(row);
 }
 if(!ueState.profiles.length){const row=ueNode('tr'),cell=ueNode('td','Henüz kullanıcı profili yok. Dağıtımı açmak için önce bir pilot AD kullanıcı grubu seçin.');cell.colSpan=6;row.append(cell);profiles.append(row);}
 const readiness=$('ue-readiness');readiness.replaceChildren();
 for(const [label,ready]of [['HTTPS',ueState.https_ready],['Kullanıcı Kerberos SPN/keytab',ueState.kerberos_ready]])readiness.append(ueNode('span',label+': '+(ready?'Hazır':'Hazırlanacak')));
 const records=$('ue-records');records.replaceChildren();const names=new Map(ueState.profiles.map(p=>[p.id,p.name]));
 const labels={issued:'Kurulum teyidi bekliyor',installed:'Kurulum doğrulandı',renewal_due:'Yenileme bekleniyor',expired:'Süresi doldu',revoked:'İptal edildi'};
 for(const user of ueState.users){
  const row=ueNode('tr');row.append(ueNode('td',user.principal));const reference=ueNode('td',names.get(user.profile_id)||user.profile_id);reference.append(ueNode('small',user.serial));row.append(reference);
  const status=ueNode('td');status.append(ueNode('span',labels[user.status]||'Bilinmeyen durum','certificate-status '+(user.status==='installed'?'valid':user.status==='revoked'?'revoked':'expired')));row.append(status,ueNode('td',ueDate(user.last_seen)),ueNode('td',ueDate(user.not_after)));
  const actions=ueNode('td');if(can('certificates.authority',true)&&user.status==='installed'){const renew=ueNode('button','Şimdi yenile');renew.type='button';renew.dataset.ueMutation='';renew.addEventListener('click',()=>requestUserRenewal(user));actions.append(renew);}else actions.textContent='—';row.append(actions);records.append(row);
 }
 if(!ueState.users.length){const row=ueNode('tr'),cell=ueNode('td','Bu sayfada kullanıcı sertifika kaydı yok. İmzalı paket kullanıcı oturumunda çalıştıktan sonra kayıtlar görünür.');cell.colSpan=6;row.append(cell);records.append(row);}
 $('ue-count').textContent=ueState.total+' kullanıcı sertifikası';ueControls();
}
function openUserEnrollment(tab){
 if(!['user-profiles','user-enrollments'].includes(tab))return;
 loadUserEnrollment().catch(()=>{});
}
function closeUserProfile(force=false){if(ueBusy&&!force)return;if($('ue-editor').open)$('ue-editor').close();ueEditorEpoch++;ueGroupsRequest++;ueEditing=null;ueUncertain=null;$('ue-form').reset();$('ue-form-error').textContent='';$('ue-group-feedback').textContent='';$('ue-group').replaceChildren(ueNode('option','Grup seçin…'));$('ue-group').firstChild.value='';ueControls();}
function editUserProfile(profile=null){
 if(!can('certificates.authority',true)||ueBusy)return;
 closeUserProfile();ueEditing=profile?{...profile}:null;ueGroupsOffset=0;ueGroupsTotal=0;ueGroupsLength=0;
 $('ue-title').textContent=profile?'Kullanıcı profilini düzenle':'Kullanıcı profili oluştur';$('ue-name').value=profile?.name||'';$('ue-days').value=profile?.validity_days||90;$('ue-renew').value=profile?.renew_before_days||30;$('ue-enabled').checked=!!profile?.enabled;
 if(profile){const option=ueNode('option',profile.group_name||ueGroups.get(profile.group_sid)||profile.group_sid);option.value=profile.group_sid;$('ue-group').append(option);$('ue-group').value=profile.group_sid;}
 $('ue-editor').showModal();ueControls();$('ue-name').focus();loadUserGroups(0).catch(()=>{});
}
async function loadUserGroups(offset=0){
 if(!$('ue-editor').open||!can('certificates.authority',true)||ueBusy)return;
 const generation=authGeneration,epoch=ueEditorEpoch,request=++ueGroupsRequest,query=$('ue-group-query').value.trim();$('ue-group-feedback').textContent='AD güvenlik grupları yükleniyor…';
 try{
  const page=await api('/api/policies/groups?offset='+offset+'&q='+encodeURIComponent(query));
  if(!ueCurrent(generation)||epoch!==ueEditorEpoch||request!==ueGroupsRequest||!$('ue-editor').open)return;
  const selected=$('ue-group').value,selectedText=$('ue-group').selectedOptions[0]?.textContent;
  const placeholder=ueNode('option','Grup seçin…');placeholder.value='';$('ue-group').replaceChildren(placeholder);
  for(const group of page.items){ueGroups.set(group.sid,group.name);const option=ueNode('option',group.name+' ('+group.sam+')');option.value=group.sid;$('ue-group').append(option);}
  if(selected&&!page.items.some(g=>g.sid===selected)){const option=ueNode('option',selectedText||selected);option.value=selected;$('ue-group').append(option);}
  $('ue-group').value=selected;ueGroupsOffset=offset;ueGroupsTotal=page.total;ueGroupsLength=page.items.length;
  $('ue-group-feedback').textContent=page.total+' güvenlik grubu'+(selected?' • Seçili grup korunuyor.':' • Bir grup seçin.');ueControls();
 }catch(error){if(ueCurrent(generation)&&epoch===ueEditorEpoch&&request===ueGroupsRequest&&error.code!=='SESSION_CHANGED')$('ue-group-feedback').textContent=ueText(error);throw error;}
}
async function saveUserProfile(event){
 event.preventDefault();if(!can('certificates.authority',true)||ueBusy||ueUncertain)return;
 const days=Number($('ue-days').value),renew=Number($('ue-renew').value);
 if(!Number.isInteger(days)||days<2||days>365||!Number.isInteger(renew)||renew<1||renew>=days){$('ue-form-error').textContent='Geçerlilik 2–365 gün; yenileme aralığı 1 gün veya üzeri ve geçerlilikten kısa olmalı.';return;}
 const payload={id:ueEditing?.id||'',version:ueEditing?.version||0,name:$('ue-name').value.trim(),group_sid:$('ue-group').value,validity_days:days,renew_before_days:renew,enabled:$('ue-enabled').checked};
 if(!payload.name||!payload.group_sid){$('ue-form-error').textContent='Profil adı ve AD güvenlik grubu seçimi gerekli.';return;}
 const generation=authGeneration,epoch=ueEditorEpoch,priorIds=ueState?.profiles.map(p=>p.id)||[];ueGroupsRequest++;ueBusy=true;ueControls();$('ue-form-error').textContent='';let committed=false;
 try{
  await api('/api/user-admin/profile',payload);committed=true;
  if(!ueCurrent(generation)||epoch!==ueEditorEpoch)return;
  closeUserProfile(true);ueFeedback('Kullanıcı profili kaydedildi. Mevcut sertifikalar ve ağ erişim kuralları değişmedi.');
  try{await loadUserEnrollment(ueOffset,true);}catch(error){if(ueCurrent(generation))ueFeedback('Profil kaydedildi; liste yenilenemedi. Yenile düğmesiyle kayıtlı sonucu kontrol edin.',true);}
 }catch(error){
  if(!ueCurrent(generation)||epoch!==ueEditorEpoch||error.code==='SESSION_CHANGED')return;
  $('ue-form-error').textContent=ueText(error);
  if(!committed&&['CONNECTION_FAILED','REQUEST_TIMEOUT','STORE_UNAVAILABLE'].includes(error.code)){ueUncertain={payload,priorIds};$('ue-form-error').textContent+=' Kaydetme sonucu belirsiz; tekrar gönderilmedi. Önce kayıt sonucunu kontrol edin.';}
 }finally{if(ueCurrent(generation)){ueBusy=false;ueControls();}}
}
async function reconcileUserProfile(){
 if(!ueUncertain||ueBusy)return;const generation=authGeneration,epoch=ueEditorEpoch,attempt=ueUncertain;ueBusy=true;ueControls();
 try{
  const value=await loadUserEnrollment(ueOffset,true);if(!value||!ueCurrent(generation)||epoch!==ueEditorEpoch)return;
  const p=attempt.payload,matches=value.profiles.filter(item=>(p.id?item.id===p.id:!attempt.priorIds.includes(item.id))&&item.version===p.version+1&&['name','group_sid','validity_days','renew_before_days','enabled'].every(key=>key==='enabled'?!!item[key]===p[key]:item[key]===p[key]));
  if(matches.length===1){closeUserProfile(true);ueFeedback('Gönderilen bilgilerle eşleşen profil listede doğrulandı. İşlem yeniden gönderilmedi.');}
  else $('ue-form-error').textContent='Kaydetme sonucu kesinleştirilemedi. İşlem yeniden gönderilmedi; listeyi ve işlem geçmişini kontrol edin. Girdiğiniz bilgiler bu pencerede korunuyor.';
 }catch(error){if(ueCurrent(generation)&&epoch===ueEditorEpoch)$('ue-form-error').textContent=ueText(error);}
 finally{if(ueCurrent(generation)){ueBusy=false;ueControls();}}
}
async function downloadUserPackage(profile){
 if(!can('certificates.authority',true)||ueDownloads.has(profile.id))return;
 const generation=authGeneration,controller=new AbortController(),timer=setTimeout(()=>controller.abort(),15000);ueDownloads.add(profile.id);
 try{
  const response=await fetch('/api/user-admin/package?profile_id='+encodeURIComponent(profile.id),{credentials:'same-origin',signal:controller.signal});
  if(!ueCurrent(generation))return;
  if(!response.ok){const data=await response.json();if(response.status===401){lock();return;}throw new Error(ueErrors[data.error]||data.error||'Paket indirilemedi.');}
  const blob=await response.blob();if(!ueCurrent(generation))return;
  const url=URL.createObjectURL(blob),link=ueNode('a');link.href=url;link.download='AuthWire-User-'+profile.id+'.zip';link.click();setTimeout(()=>URL.revokeObjectURL(url),1000);
  ueFeedback('Kullanıcı paketi indirildi. Kurum kod imzasından sonra kullanıcı oturumu kapsamına dağıtılır; GPO henüz değiştirilmedi.');
 }catch(error){if(ueCurrent(generation))ueFeedback(error.name==='AbortError'?'Paket indirmesi zaman aşımına uğradı.':ueText(error),true);}
 finally{clearTimeout(timer);ueDownloads.delete(profile.id);}
}
async function requestUserRenewal(user){
 if(!can('certificates.authority',true)||ueBusy||!confirm('“'+user.principal+'” için yeni anahtar ve sertifika talebi işaretlensin mi? İstemcinin sonraki kontrolünde uygulanır; mevcut bağlantı hemen değişmez.'))return;
 const generation=authGeneration;ueBusy=true;ueControls();let committed=false;
 try{await api('/api/user-admin/renew-now',{serial:user.serial});committed=true;await loadUserEnrollment(ueOffset,true);if(ueCurrent(generation))ueFeedback('Yenileme talebi işaretlendi. Kullanıcı istemcisinin bir sonraki kontrolü bekleniyor.');}
 catch(error){if(ueCurrent(generation)&&error.code!=='SESSION_CHANGED')ueFeedback(committed?'Yenileme talebi kaydedildi; liste yenilenemedi. Yenile ile sonucu kontrol edin.':ueText(error)+' İşlem otomatik tekrar edilmedi; yeniden talep etmeden önce listeyi kontrol edin.',true);}
 finally{if(ueCurrent(generation)){ueBusy=false;ueControls();}}
}
function resetUserEnrollment(){
 ueRequest++;ueGroupsRequest++;ueFlight=null;ueState=null;ueOffset=0;ueBusy=false;ueUncertain=null;ueGroups.clear();ueDownloads.clear();closeUserProfile(true);
 for(const id of ['ue-profiles','ue-records','ue-readiness'])$(id).replaceChildren();$('ue-count').textContent='';ueFeedback('');
}
$('ue-new').addEventListener('click',()=>editUserProfile());$('ue-form').addEventListener('submit',saveUserProfile);
for(const id of ['ue-close','ue-cancel'])$(id).addEventListener('click',()=>closeUserProfile());
$('ue-editor').addEventListener('cancel',event=>{if(ueBusy)event.preventDefault();else closeUserProfile();});
$('ue-group-search').addEventListener('click',()=>loadUserGroups(0).catch(()=>{}));$('ue-group-query').addEventListener('keydown',event=>{if(event.key==='Enter'){event.preventDefault();loadUserGroups(0).catch(()=>{});}});
$('ue-group-previous').addEventListener('click',()=>loadUserGroups(Math.max(0,ueGroupsOffset-100)).catch(()=>{}));$('ue-group-next').addEventListener('click',()=>loadUserGroups(ueGroupsOffset+100).catch(()=>{}));
for(const id of ['ue-refresh','ue-record-refresh'])$(id).addEventListener('click',()=>loadUserEnrollment().then(value=>{if(value)ueFeedback('Kayıtlı durum yenilendi.');}).catch(()=>{}));
$('ue-previous').addEventListener('click',()=>loadUserEnrollment(Math.max(0,ueOffset-100)).catch(()=>{}));$('ue-next').addEventListener('click',()=>loadUserEnrollment(ueOffset+100).catch(()=>{}));
$('ue-reconcile').addEventListener('click',reconcileUserProfile);$('ue-distribution').addEventListener('click',()=>setPKITab('distribution'));
