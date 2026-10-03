'use strict';
let token = '', state = null, step = 0;
const $ = id => document.getElementById(id);
function message(value) { $('message').textContent = value; }
async function api(path, data) {
  const response = await fetch(path, {method: data === undefined ? 'GET' : 'POST', headers: {'Authorization': 'Bearer ' + token, 'Content-Type': 'application/json'}, body: data === undefined ? undefined : JSON.stringify(data)});
  const value = await response.json();
  if (!response.ok) throw new Error(value.error === 'REVISION_CONFLICT' ? 'Başka bir kayıt yapıldı. Sayfayı yenileyip tekrar deneyin.' : 'İşlem tamamlanamadı: ' + value.error);
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
  renderPolicies();renderPKI();
  const events=await api('/api/audit'); $('audit-list').replaceChildren();
  events.events.forEach(event => {const p=document.createElement('p'); p.textContent=`${event.at} • ${event.event} • Sürüm ${event.revision}`;$('audit-list').append(p);});
}
async function savePolicies(){ await api('/api/policies',{expected_revision:state.revision,policies:state.policies});await refresh();message('Politikalar kaydedildi. Ağda uygulanmadı.'); }
async function run(fn){try{await fn();}catch(error){message(error.message);if(token&&state){try{await refresh();}catch(_) {}}}}
$('unlock').addEventListener('click',()=>run(async()=>{token=$('token').value.trim();await refresh();$('token').value='';$('login').hidden=true;$('workspace').hidden=false;if(state.config){const c=state.config;$('fqdn').value=c.appliance_fqdn;$('domain').value=c.ad_domain;$('dc').value=c.dc_ips.join(', ');$('clients').value=c.radius_clients.map(x=>x.name+','+x.ip).join('\n');$('wired').checked=c.access_modes.includes('wired');$('wireless').checked=c.access_modes.includes('wireless');}message('Yerel geliştirme paneli açıldı.');}));
document.querySelectorAll('[data-view]').forEach(button=>button.addEventListener('click',()=>{document.querySelectorAll('.view').forEach(x=>x.hidden=x.id!==button.dataset.view);document.querySelectorAll('[data-view]').forEach(x=>x.classList.toggle('selected',x===button));}));
document.querySelectorAll('[data-step]').forEach(x=>x.addEventListener('click',()=>run(()=>showStep(Number(x.dataset.step)))));
$('back').addEventListener('click',()=>run(()=>showStep(step-1)));$('next').addEventListener('click',()=>run(()=>showStep(step+1)));
$('save').addEventListener('click',()=>run(async()=>{await api('/api/config',{expected_revision:state.revision,config:config()});await refresh();message('Kurulum taslağı kaydedildi. AD veya ağ ayarı uygulanmadı.');}));
$('refresh-pki').addEventListener('click',()=>run(async()=>{await refresh();message('Sertifika otoritesinin açık bilgileri güncellendi.');}));
$('add-policy').addEventListener('click',()=>run(async()=>{const action=$('policy-action').value;state.policies.push({id:crypto.randomUUID(),name:$('policy-name').value.trim(),enabled:true,conditions:{group_sids:$('policy-group').value.trim()?[$('policy-group').value.trim()]:[],access_types:['wired','wireless'],nas_ips:[]},constraints:{eap_methods:['EAP-TLS'],require_domain_device:true},action,vlan:action==='allow'?Number($('policy-vlan').value):null});await savePolicies();}));
$('run-simulation').addEventListener('click',()=>run(async()=>{const scenario=$('scenario').value;const data={authenticated:true,directory_available:scenario!=='offline',account_enabled:scenario!=='disabled',domain_device:scenario!=='outside',group_sids:$('sim-group').value.trim()?[$('sim-group').value.trim()]:[],access_type:'wired',nas_ip:state.config?.radius_clients[0]?.ip||'192.0.2.2',eap_method:scenario==='wrong-eap'?'PEAP-MSCHAPV2':'EAP-TLS'};const result=await api('/api/simulate',data);$('result').textContent='YALNIZ SİMÜLASYON • Ağda uygulanmaz\n\n'+JSON.stringify(result,null,2);}));
showStep(0);
