'use strict';
let servicesState=null,servicesLoading=false,servicesSending=false,servicesTimer=0,servicesGeneration=0,servicesPending=null;
let radiusOverviewRequest=0,radiusOverviewLoading=false;
const serviceNames={system:'Sunucu',radius:'RADIUS',panel:'ΛuthWire paneli','crl-sync':'CRL senkronizasyonu','crl-timer':'CRL zamanlayıcısı'};
const serviceActions={reboot:'Yeniden başlat',poweroff:'Kapat',start:'Başlat',stop:'Durdur',restart:'Yeniden başlat',sync:'Şimdi senkronize et'};
const serviceHealth={running:'Çalışıyor',idle:'Bekliyor · Son çalışma başarılı',inactive:'Durduruldu',failed:'Hata','not-installed':'Kurulu değil','listener-missing':'UDP dinleyicisi bulunamadı',activating:'Başlatılıyor',deactivating:'Durduruluyor',unknown:'Bilinmiyor'};
const serviceErrors={SERVICE_CONTROL_UNAVAILABLE:'Servis yönetim bağlantısı kullanılamıyor. Kurulum veya yardımcı servis durumunu kontrol edin.',SERVICE_BUSY:'Başka bir servis işlemi devam ediyor.',RADIUS_NOT_RUNNING:'RADIUS durdurulmuş. CRL senkronizasyonu RADIUS’u başlatmaz.',SERVICE_COMMAND_FAILED:'Servis komutu tamamlanamadı.',SERVICE_VERIFICATION_FAILED:'Servisin beklenen duruma geldiği doğrulanamadı.',BOOT_SETTING_CHANGED:'Servisin açılış ayarı değişmiş; kontrol gerekli.',AUDIT_UNAVAILABLE:'Servis işlem kaydı yazılamadı.',OUTCOME_UNKNOWN:'Yönetim servisi yeniden başlamış. İşlem sonucu bilinmiyor; güncel durumu kontrol edin.'};
function resetServices(){servicesGeneration++;radiusOverviewRequest++;radiusOverviewLoading=false;renderRadiusOverview(null);clearTimeout(servicesTimer);servicesState=null;servicesPending=null;servicesLoading=false;servicesSending=false;const dialog=document.getElementById('services-confirm');if(dialog?.open)dialog.close('cancel');for(const id of ['services-list','services-operations','services-selection'])document.getElementById(id)?.replaceChildren();if(document.getElementById('services-feedback'))document.getElementById('services-feedback').textContent='';}
function servicesVisible(){return !!session&&!$('services').hidden&&can('system.services');}
function openServices(id){clearTimeout(servicesTimer);if(id==='services'&&can('system.services'))loadServices();if(id==='overview')loadRadiusOverview();}
function radiusOverviewPermissions(){$('overview-radius-row').hidden=!can('system.services');$('overview-radius-refresh').disabled=radiusOverviewLoading;}
function renderRadiusOverview(value){
  const badge=$('overview-radius-health'),detail=$('overview-radius-detail');
  const radius=value?.available===true&&Array.isArray(value.services)?value.services.find(s=>s.id==='radius'):null;
  badge.textContent=radius?(serviceHealth[radius.health]||'Bilinmiyor'):'Bilgi alınamadı';
  badge.dataset.status=radius?.health==='running'?'ready':['failed','listener-missing'].includes(radius?.health)?'error':'pending';
  if(radius){const time=Date.parse(value.checked_at);detail.textContent=(radius.listener_present===true?'UDP dinleyicisi doğrulandı. ':'')+'Son kontrol: '+(Number.isFinite(time)?new Date(time).toLocaleString('tr-TR'):'Zaman bilgisi yok')+'. Bu gösterge servis durumudur.';}
  else detail.textContent='Servis bilgisi alınamadı. Servisler ekranından durumu kontrol edebilirsiniz.';
  radiusOverviewPermissions();
}
async function loadRadiusOverview(){
  if(!can('system.services')||radiusOverviewLoading)return;
  const generation=authGeneration,request=++radiusOverviewRequest;radiusOverviewLoading=true;
  $('overview-radius-health').textContent='Kontrol ediliyor';$('overview-radius-detail').textContent='RADIUS servis durumu okunuyor.';radiusOverviewPermissions();
  try{const value=await api('/api/services');if(generation===authGeneration&&request===radiusOverviewRequest&&can('system.services'))renderRadiusOverview(value);}
  catch(error){if(generation===authGeneration&&request===radiusOverviewRequest&&can('system.services'))renderRadiusOverview(null);}
  finally{if(generation===authGeneration&&request===radiusOverviewRequest){radiusOverviewLoading=false;radiusOverviewPermissions();}}
}
function serviceText(tag,text){const e=document.createElement(tag);e.textContent=text;return e;}
function servicesButtons(){
  const selected=servicesState?.services.find(s=>s.id===$('services-selection').value);
  for(const action of ['start','stop','restart','sync']){
    const button=$('services-'+action),allowed=selected?.actions.includes(action);
    button.hidden=!allowed;button.disabled=!allowed||!can('system.services',true)||servicesSending||servicesState?.busy===true;
    if(selected&&((action==='start'&&selected.active_state==='active')||(action==='stop'&&selected.active_state==='inactive')))button.disabled=true;
    if(action==='sync'&&servicesState?.services.find(s=>s.id==='radius')?.active_state!=='active')button.disabled=true;
  }
  $('services-refresh').disabled=servicesLoading;
}
function renderServices(){
  const select=$('services-selection'),previous=select.value;
  select.replaceChildren();$('services-list').replaceChildren();$('services-operations').replaceChildren();
  for(const s of servicesState?.services||[]){
    const option=serviceText('option',serviceNames[s.id]||s.id);option.value=s.id;select.append(option);
    const row=document.createElement('tr');row.dataset.service=s.id;
    const name=document.createElement('td');name.append(serviceText('strong',serviceNames[s.id]||s.id),serviceText('small',s.unit));
    if(s.last_trigger)name.append(serviceText('small','Son çalışma: '+s.last_trigger));
    if(s.next_trigger)name.append(serviceText('small','Sonraki çalışma: '+s.next_trigger));
    const status=document.createElement('td'),badge=serviceText('span',serviceHealth[s.health]||s.health);badge.className='health-badge';badge.dataset.serviceHealth=s.health;status.append(badge);
    if(s.last_result&&s.last_result!=='success')status.append(serviceText('small','Son sonuç: '+s.last_result));
    row.append(name,status,serviceText('td',s.memory_bytes==null?'—':(s.memory_bytes/1048576).toFixed(1)+' MB'),serviceText('td',s.cpu_seconds==null?'—':s.cpu_seconds.toFixed(1)+' sn'),serviceText('td',s.uptime_seconds==null?'—':Math.floor(s.uptime_seconds/3600)+' sa '+Math.floor((s.uptime_seconds%3600)/60)+' dk'),serviceText('td',({enabled:'Etkin',disabled:'Kapalı',static:'Görevle'}[s.enabled]||s.enabled)));
    $('services-list').append(row);
  }
  if([...select.options].some(o=>o.value===previous))select.value=previous;
  for(const op of servicesState?.operations||[]){
    const line=serviceText('p',(serviceNames[op.service]||op.service)+' · '+(serviceActions[op.action]||op.action)+' · '+({scheduled:'Sistem işlemi planlandı','boot-observed':'Yeni sistem açılışı gözlendi',queued:'Sırada',running:'Devam ediyor',succeeded:'Başarılı',failed:'Başarısız',interrupted:'Sonuç bilinmiyor'}[op.state]||op.state)+' · '+op.actor+' · '+new Date(op.created_at).toLocaleString('tr-TR'));
    if(op.error)line.append(serviceText('small',serviceErrors[op.error]||'İşlem tamamlanamadı.'));$('services-operations').append(line);
  }
  if(!servicesState?.operations.length)$('services-operations').append(serviceText('p','Henüz kayıtlı servis işlemi yok.'));
  servicesButtons();
}
async function loadServices(){
  if(servicesLoading||!servicesVisible())return;
  servicesLoading=true;servicesButtons();const generation=servicesGeneration;
  try{
    const value=await api('/api/services');if(generation!==servicesGeneration||!session)return;
    servicesState=value;renderServices();
    const op=servicesPending&&value.operations.find(x=>x.id===servicesPending.request_id);
    if(op&&['succeeded','failed','interrupted'].includes(op.state)){servicesPending=null;servicesSending=false;}
    $('services-feedback').textContent=value.busy?'Servis işlemi devam ediyor. Sonuç otomatik kontrol ediliyor.':'Son kontrol: '+new Date(value.checked_at).toLocaleTimeString('tr-TR');
  }catch(error){
    if(generation!==servicesGeneration||!session)return;
    servicesState=null;renderServices();$('services-feedback').textContent=serviceErrors[error.code]||error.message;
  }finally{
    if(generation===servicesGeneration){servicesLoading=false;servicesButtons();if(servicesVisible())servicesTimer=setTimeout(loadServices,servicesSending||servicesState?.busy?2000:10000);}
  }
}
function confirmService(action){
  if(!can('system.services',true)||servicesSending||servicesState?.busy)return;
  const service=$('services-selection').value,s=servicesState?.services.find(x=>x.id===service);
  if(!s?.actions.includes(action))return;
  $('services-confirm-title').textContent=(serviceNames[service]||service)+' · '+serviceActions[action];
  $('services-confirm-impact').textContent=service==='radius'?(action==='stop'?'Yeni 802.1X kimlik doğrulamaları duracaktır. Mevcut bağlantılar switch/AP yeniden doğrulama davranışına göre etkilenebilir.':'RADIUS işlemi sırasında yeni kimlik doğrulamaları geçici olarak etkilenebilir.'):service==='crl-timer'?(action==='stop'?'İptal listesinin periyodik yayını duracaktır. Zamanlayıcı kapalı bırakılırsa sertifika iptallerinin uygulanması etkilenebilir.':'İptal listesinin periyodik yayını yeniden başlayacaktır.'):'İptal listesi şimdi senkronize edilecek. RADIUS yeniden başlatılmayacak.';
  $('services-confirm').dataset.service=service;$('services-confirm').dataset.action=action;$('services-confirm').showModal();
}
async function sendServiceAction(service,action){
  if(!can('system.services',true)||servicesSending)return;
  const generation=servicesGeneration;servicesSending=true;
  servicesPending={service,action,confirmed:true,request_id:crypto.randomUUID()};servicesButtons();
  try{
    await api('/api/services/action',servicesPending);
    if(generation!==servicesGeneration)return;
    $('services-feedback').textContent='İşlem alındı; sonucu kontrol ediliyor.';
  }catch(error){
    if(generation!==servicesGeneration)return;
    $('services-feedback').textContent=serviceErrors[error.code]||error.message;
    // Never resend a timed-out mutation. Inspect the recorded operation instead.
    servicesSending=false;
  }finally{
    if(generation===servicesGeneration){clearTimeout(servicesTimer);servicesButtons();await loadServices();}
  }
}
document.addEventListener('DOMContentLoaded',()=>{
  $('services-refresh').addEventListener('click',()=>{clearTimeout(servicesTimer);loadServices();});
  $('services-selection').addEventListener('change',servicesButtons);
  for(const action of ['start','stop','restart','sync'])$('services-'+action).addEventListener('click',()=>confirmService(action));
  $('services-confirm').addEventListener('close',()=>{const d=$('services-confirm');if(d.returnValue==='confirm')sendServiceAction(d.dataset.service,d.dataset.action);});
});

document.getElementById('overview-radius-refresh').addEventListener('click',loadRadiusOverview);
