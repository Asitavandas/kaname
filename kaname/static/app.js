'use strict';
let token = '', state = null, step = 0, directoryOffset = 0;
const $ = id => document.getElementById(id);
function message(value) { $('message').textContent = value; }
async function api(path, data) {
  const response = await fetch(path, {method: data === undefined ? 'GET' : 'POST', headers: {'Authorization': 'Bearer ' + token, 'Content-Type': 'application/json'}, body: data === undefined ? undefined : JSON.stringify(data)});
  const value = await response.json();
  const errors = {AD_PLATFORM_UNSUPPORTED:'Bu geliştirme sürümünün AD okuyucusu Windows laboratuvarında çalışır.',AD_DNS_FAILED:'DC DNS adı çözümlenemedi. DNS ayarını ve DC adını kontrol edin.',AD_DC_IP_MISMATCH:'DC DNS adresi, Kurulum ekranında kaydettiğiniz DC IP adresleriyle eşleşmiyor.',AD_BIND_FAILED:'AD bağlantısı kurulamadı. DNS, saat, Kerberos erişimi ve kullanıcı bilgilerini kontrol edin.',AD_CREDENTIALS_REJECTED:'AD kullanıcı bilgilerini kabul etmedi. Tekrar denemeden önce bilgileri kontrol edin.',AD_TIMEOUT:'AD yanıtı zaman aşımına uğradı.',AD_RETRY_LATER:'Tekrar denemeden önce 10 saniye bekleyin.',AD_QUERY_BUSY:'Bir AD okuması devam ediyor.',AD_DOMAIN_MISMATCH:'Bağlanılan DC, kaydedilmiş domaine ait değil.',AD_DIRECTORY_LIMIT:'Dizin bu geliştirme sürümünün okuma sınırını aşıyor. Önceki liste korundu.',CONFIG_REQUIRED:'Önce Kurulum ekranından domain ve DC IP adreslerini kaydedin.'};
  if (!response.ok) throw new Error(value.error === 'REVISION_CONFLICT' ? 'Başka bir kayıt yapıldı. Sayfayı yenileyip tekrar deneyin.' : errors[value.error] || 'İşlem tamamlanamadı: ' + value.error);
  return value;
}
function config() {
  return {appliance_fqdn: $('fqdn').value.trim(), ad_domain: $('domain').value.trim(), dc_ips: $('dc').value.split(',').map(x => x.trim()).filter(Boolean), access_modes: ['wired','wireless'].filter(x => $(x).checked), radius_clients: $('clients').value.split('\n').filter(x => x.trim()).map(line => { const parts = line.split(','); if (parts.length !== 2) throw new Error('Her istemci satırı ad,IP biçiminde olmalı.'); return {name:parts[0].trim(), ip:parts[1].trim()}; })};
}
function showStep(number) {
  step = Math.max(0, Math.min(3, number));
  document.querySelectorAll('[data-page]').forEach(x => x.hidden = Number(x.dataset.page) !== step);
  document.querySelectorAll('[data-step]').forEach(x => x.classList.toggle('active', Number(x.dataset.step) === step));
  $('back').disabled = step === 0; $('next').hidden = step === 3; $('save').hidden = step !== 3;
  if (step === 3) $('review').textContent = JSON.stringify(config(), null, 2);
}
function renderPolicies() {
  const parent = $('policy-list'); parent.replaceChildren();
  if (!state.policies.length) parent.textContent = 'Henüz politika yok. Varsayılan karar: reddet.';
  state.policies.forEach((policy,index) => {
    const row = document.createElement('div'); row.className = 'policy-row';
    const label = document.createElement('span'); label.textContent = `${index+1}. ${policy.name} • ${policy.action === 'allow' ? 'İzin' : 'Ret'} • ${policy.enabled ? 'Etkin' : 'Kapalı'}${policy.vlan ? ' • VLAN '+policy.vlan : ''}`;
    const actions = document.createElement('div'); actions.className = 'actions';
    for (const [title, change] of [['↑',() => {if(index>0)[state.policies[index-1],state.policies[index]]=[state.policies[index],state.policies[index-1]];}],['↓',() => {if(index<state.policies.length-1)[state.policies[index+1],state.policies[index]]=[state.policies[index],state.policies[index+1]];}],['Aç/Kapat',() => policy.enabled=!policy.enabled],['Sil',() => state.policies.splice(index,1)]]) {
      const button = document.createElement('button'); button.textContent=title;
      button.addEventListener('click', () => run(async () => {change();await savePolicies();})); actions.append(button);
    }
    row.append(label,actions); parent.append(row);
  });
}
function renderPKI() {
  const info=state.pki_public, parent=$('pki-info'); parent.replaceChildren();
  $('pki-summary').textContent=info?.initialized ? 'CA oluşturuldu' : 'Hazırlanacak';
  if(!info?.initialized){parent.textContent='Bu kurulum için henüz CA oluşturulmadı.';return;}
  const rows=[['Kurulum kimliği',info.instance_id],['Çalışma durumu','Yerel geliştirme CA • İstemci kaydı kapalı'],['CRL sürümü',String(info.crl_number)]];
  for(const [kind,label] of [['root','Root CA'],['issuer','İmzalayan CA']]) {
    rows.push([label+' SHA256 parmak izi',info[kind].fingerprint_sha256],[label+' son geçerlilik',info[kind].not_after]);
  }
  for(const [label,value] of rows){const row=document.createElement('p');const title=document.createElement('strong');title.textContent=label+': ';const detail=document.createElement('span');detail.textContent=value;row.append(title,detail);parent.append(row);}
}
async function refresh() {
  state=await api('/api/state'); $('revision').textContent='Taslak sürümü '+state.revision;
  renderPolicies();renderPKI();renderDirectoryStatus();
  const events=await api('/api/audit'); $('audit-list').replaceChildren();
  events.events.forEach(event => {const p=document.createElement('p'); p.textContent=`${event.at} • ${event.event} • Sürüm ${event.revision}`;$('audit-list').append(p);});
}
async function savePolicies(){ await api('/api/policies',{expected_revision:state.revision,policies:state.policies});await refresh();message('Politikalar kaydedildi. Ağda uygulanmadı.'); }
async function run(fn){try{await fn();}catch(error){message(error.message);if(token&&state){try{await refresh();}catch(_) {}}}}
$('unlock').addEventListener('click',()=>run(async()=>{token=$('token').value.trim();await refresh();$('token').value='';$('login').hidden=true;$('workspace').hidden=false;if(state.config){const c=state.config;$('fqdn').value=c.appliance_fqdn;$('domain').value=c.ad_domain;$('dc').value=c.dc_ips.join(', ');$('clients').value=c.radius_clients.map(x=>x.name+','+x.ip).join('\n');$('wired').checked=c.access_modes.includes('wired');$('wireless').checked=c.access_modes.includes('wireless');}message('Yerel geliştirme paneli açıldı.');}));
document.querySelectorAll('[data-view]').forEach(button=>button.addEventListener('click',()=>{document.querySelectorAll('.view').forEach(x=>x.hidden=x.id!==button.dataset.view);document.querySelectorAll('[data-view]').forEach(x=>x.classList.toggle('selected',x===button));}));
document.querySelectorAll('[data-view]').forEach(button=>button.addEventListener('click',()=>{if(button.dataset.view!=='directory')$('ad-password').value='';else run(()=>loadDirectory());}));
document.querySelectorAll('[data-step]').forEach(x=>x.addEventListener('click',()=>run(()=>showStep(Number(x.dataset.step)))));
$('back').addEventListener('click',()=>run(()=>showStep(step-1)));$('next').addEventListener('click',()=>run(()=>showStep(step+1)));
$('save').addEventListener('click',()=>run(async()=>{await api('/api/config',{expected_revision:state.revision,config:config()});await refresh();message('Kurulum taslağı kaydedildi. AD veya ağ ayarı uygulanmadı.');}));
$('refresh-pki').addEventListener('click',()=>run(async()=>{await refresh();message('Sertifika otoritesinin açık bilgileri güncellendi.');}));
$('add-policy').addEventListener('click',()=>run(async()=>{const action=$('policy-action').value;state.policies.push({id:crypto.randomUUID(),name:$('policy-name').value.trim(),enabled:true,conditions:{group_sids:$('policy-group').value.trim()?[$('policy-group').value.trim()]:[],access_types:['wired','wireless'],nas_ips:[]},constraints:{eap_methods:['EAP-TLS'],require_domain_device:true},action,vlan:action==='allow'?Number($('policy-vlan').value):null});await savePolicies();}));
$('run-simulation').addEventListener('click',()=>run(async()=>{const scenario=$('scenario').value;const data={authenticated:true,directory_available:scenario!=='offline',account_enabled:scenario!=='disabled',domain_device:scenario!=='outside',group_sids:$('sim-group').value.trim()?[$('sim-group').value.trim()]:[],access_type:'wired',nas_ip:state.config?.radius_clients[0]?.ip||'192.0.2.2',eap_method:scenario==='wrong-eap'?'PEAP-MSCHAPV2':'EAP-TLS'};const result=await api('/api/simulate',data);$('result').textContent='YALNIZ SİMÜLASYON • Ağda uygulanmaz\n\n'+JSON.stringify(result,null,2);}));
showStep(0);

function renderDirectoryStatus() {
  const d=state.directory_public;
  $('ad-domain').value=state.config?.ad_domain||'';
  $('directory-summary').textContent=d?.catalog_available?'Dizin kaydı mevcut':'Bağlantı bekliyor';
  $('directory-sync').disabled=!d?.windows_reader_available||!state.config;
  $('directory-status').textContent=d?.catalog_available ? `Son okuma: ${d.synced_at} • ${d.counts.users} kullanıcı • ${d.counts.groups} grup • ${d.counts.computers} bilgisayar` : d?.windows_reader_available ? 'Bağlantı bilgilerini girerek dizini okuyabilirsiniz.' : 'AD bağlantısı için Windows laboratuvarındaki paneli kullanın.';
  if(d?.dc_fqdn&&!$('ad-host').value)$('ad-host').value=d.dc_fqdn;
}
async function loadDirectory() {
  const kind=$('directory-kind').value, query=$('directory-query').value.trim();
  const page=await api('/api/directory/catalog?kind='+encodeURIComponent(kind)+'&offset='+directoryOffset+'&q='+encodeURIComponent(query));
  const parent=$('directory-list');parent.replaceChildren();
  for(const object of page.items){
    const row=document.createElement('div');row.className='policy-row';
    const label=document.createElement('span');label.textContent=object.name+' • '+object.sam+' • '+object.sid+(object.enabled===false?' • Kapalı hesap':'');row.append(label);
    if(kind==='groups'){
      const choose=document.createElement('button');choose.textContent='Politikada kullan';
      choose.addEventListener('click',()=>{$('policy-group').value=object.sid;document.querySelector('[data-view="policies"]').click();document.querySelector('#policies details').open=true;message('Grup seçildi. Politika adını ve VLAN’ı kontrol ederek kaydedin.');});row.append(choose);
    }
    parent.append(row);
  }
  if(!page.items.length)parent.textContent=page.catalog_available?'Bu aramada sonuç yok.':'Henüz AD dizini okunmadı.';
  $('directory-count').textContent=`${page.total} sonuç • ${page.items.length?directoryOffset+1:0}–${directoryOffset+page.items.length}`;
  $('directory-previous').disabled=directoryOffset===0;
  $('directory-next').disabled=directoryOffset+page.items.length>=page.total;
}
$('directory-sync').addEventListener('click',()=>run(async()=>{
  const button=$('directory-sync');button.disabled=true;
  const connection={dc_fqdn:$('ad-host').value.trim(),username:$('ad-user').value.trim(),password:$('ad-password').value};
  $('ad-password').value='';message('AD bağlantısı kuruluyor; dizin okunuyor…');
  try {await api('/api/directory/sync',{expected_revision:state.revision,connection});await refresh();directoryOffset=0;await loadDirectory();message('Kullanıcılar, bilgisayarlar ve güvenlik grupları alındı. Parola kaydedilmedi.');}
  finally {connection.password='';button.disabled=!state?.directory_public?.windows_reader_available||!state?.config;}
}));
for(const id of ['directory-search','directory-kind'])$(id).addEventListener(id==='directory-kind'?'change':'click',()=>run(async()=>{directoryOffset=0;await loadDirectory();}));
$('directory-previous').addEventListener('click',()=>run(async()=>{directoryOffset=Math.max(0,directoryOffset-100);await loadDirectory();}));
$('directory-next').addEventListener('click',()=>run(async()=>{directoryOffset+=100;await loadDirectory();}));
