'use strict';
let accountingPage = null, accountingLoading = false, accountingRequest = 0;
let accessDashboardRange=null;
let accessPage=null,accessLoadedKey='',accessLoading=false,accessRequest=0;
const accessReasons={POLICY_ALLOW:'Policy izin verdi',POLICY_DENY:'Policy reddetti',POLICY_CONFLICT:'Policy çakışması',NO_MATCHING_POLICY:'Eşleşen policy yok',ACCOUNT_DISABLED:'AD hesabı devre dışı',ACCOUNT_NOT_FOUND:'AD hesabı bulunamadı',DIRECTORY_UNAVAILABLE:'AD bilgisi alınamadı',DOMAIN_DEVICE_REQUIRED:'Domain bilgisayarı gerekiyor',CERTIFICATE_UNBOUND:'Sertifika kayıtlı kimliğe bağlı değil',CERTIFICATE_INACTIVE:'Sertifika kaydı etkin değil',CERTIFICATE_BINDING_CHANGED:'Sertifika kaydı değişti',TLS_CERTIFICATE_REVOKED:'İptal edilmiş sertifika',TLS_CERTIFICATE_EXPIRED:'Sertifikanın süresi dolmuş',TLS_CERTIFICATE_UNTRUSTED:'Sertifika zincirine güvenilmiyor',TLS_CERTIFICATE_PURPOSE:'Sertifika kullanım amacı uygun değil',TLS_CERTIFICATE_VERIFY_FAILED:'Sertifika doğrulanamadı',NON_EAP_REQUEST:'EAP içermeyen istek',NATIVE_ACCESS_ACCEPT:'Sunucu kabul yanıtı seçti',NATIVE_ACCESS_REJECT:'Sunucu ret yanıtı seçti; ayrıntı belirlenemedi',NATIVE_REJECT_AFTER_POLICY_ALLOW:'Policy izninden sonra EAP/TLS reddi'};
function accessFilters(){
  const q={};for(const [id,key]of [['access-result','result'],['access-nas','nas'],['access-reason','reason'],['access-query','q']])if($(id).value)q[key]=$(id).value;
  const start=$('access-from').value,end=$('access-to').value;
  if(start)q.from=new Date(start+'T00:00:00').toISOString();
  if(end){const d=new Date(end+'T00:00:00');d.setDate(d.getDate()+1);q.to=d.toISOString();}
  if(q.from&&q.to&&q.from>=q.to)throw new Error('Başlangıç tarihi bitiş tarihinden sonra olamaz.');
  if(accessDashboardRange)Object.assign(q,accessDashboardRange);
  return q;
}
function accessKey(){try{return JSON.stringify(accessFilters());}catch(_){return '';}}
function accessControls(){const fresh=!!accessPage&&accessLoadedKey===accessKey(),allowed=can('audit.events');for(const id of ['access-apply','access-reset'])$(id).disabled=!allowed||accessLoading;$('access-next').disabled=!allowed||accessLoading||!fresh||!accessPage?.has_more;$('access-export').disabled=!allowed||accessLoading||!fresh||!accessPage?.events.length;}
function resetAccessEvents(){resetAccountingSessions();accessDashboardRange=null;accessRequest++;accessPage=null;accessLoadedKey='';accessLoading=false;$('access-filters').reset();for(const id of ['access-list','access-feedback','access-storage','access-observer'])$(id).replaceChildren();accessControls();}
function accessPermissions(){
  if(!can('audit.events'))resetAccessEvents();
  accessControls();
  accountingControls();
}
function renderAccessEvents(){
  const parent=$('access-list');parent.replaceChildren();
  for(const e of accessPage.events){
    const row=document.createElement('tr'),result=auditText('td',e.response_code===2?'Kabul (Access-Accept)':'Ret (Access-Reject)');
    result.append(auditText('small',accessReasons[e.reason]||e.reason),auditText('small',e.reason));
    const identity=auditText('td',e.object_guid|| (e.tls_verified?'Sertifika doğrulandı; kayıtlı kimlik yok.':'Kimlik doğrulanmadı.'));
    if(e.identity_kind)identity.append(auditText('small',e.identity_kind==='computer'?'Bilgisayar':'Kullanıcı'));
    if(e.certificate_serial)identity.append(auditText('small','Seri: '+e.certificate_serial));
    const nas=auditText('td',e.nas_ip);if(e.calling_station)nas.append(auditText('small',e.calling_station+' · NAS bildirimi'));
    row.append(auditText('td',auditTime(e.at)),result,identity,nas,auditText('td',e.policy_id||'—'),auditText('td',e.vlan??'—'));parent.append(row);
  }
  if(!accessPage.events.length){const row=document.createElement('tr'),cell=auditText('td',accessPage.initialized?'Bu filtrelerle kayıt bulunamadı.':'Erişim kaydı henüz başlatılmamış.');cell.colSpan=6;row.append(cell);parent.append(row);}
  const s=accessPage.storage;
  $('access-storage').textContent='Toplam '+s.records+' kayıt · '+(s.database_bytes/1048576).toFixed(2)+' MB · Üst sınır '+s.max_records+' kayıt / '+(s.max_bytes/1048576)+' MB. Otomatik silme yok.'+(s.capacity_reached?' Kayıt sınırına ulaşıldı; yeni kayıtlar yazılamayabilir.':'');
  const o=accessPage.observer;
  $('access-observer').textContent=!o?'Çalışan kayıt modülü hakkında güncel gözlem yok.':!o.enabled?'Kayıt modülü başlatılamadı: '+(o.last_error_code||'Ayrıntı yok'):'Son gözlem: '+auditTime(o.at)+(o.pid?' · Süreç '+o.pid:'')+' · Bu süreçte yazılan: '+(o.committed??0)+' · Tekrar: '+(o.duplicates??0)+' · Yazılamayan: '+(o.dropped??0)+(o.last_error_code?' · Son uyarı: '+o.last_error_code:'')+'. Sayaçlar süreç yeniden başladığında sıfırlanır; kesintisiz kayıt garantisi değildir.';
  $('access-feedback').textContent=accessPage.events.length+' kayıt gösteriliyor'+(accessPage.has_more?' · Daha eski kayıtlar var.':'.');accessControls();
}
async function loadAccessEvents({next=false}={}){
  if(!can('audit.events')||accessLoading)return;
  const filters=accessFilters(),key=JSON.stringify(filters),generation=authGeneration,request=++accessRequest;
  if(next&&(!accessPage?.has_more||key!==accessLoadedKey))return;
  const query={...filters,...(next?{before:accessPage.next_before,watermark:accessPage.watermark}:{})};accessLoading=true;accessControls();$('access-feedback').textContent='Erişim kayıtları okunuyor…';
  try{
    const page=await api('/api/radius/events?'+new URLSearchParams(query));
    if(generation!==authGeneration||request!==accessRequest||!can('audit.events'))return;
    if(accessKey()!==key){$('access-feedback').textContent='Filtreler değişti. Uygula ile yeniden arayın.';return;}
    accessPage=page;accessLoadedKey=key;renderAccessEvents();
  }catch(error){if(generation===authGeneration&&request===accessRequest&&error.code!=='SESSION_CHANGED')$('access-feedback').textContent=error.code==='AUDIT_QUERY_LIMIT'?'Arama sınırı aşıldı. Tarih veya NAS filtresini daraltın.':error.code==='INVALID_INPUT'?'Filtreleri kontrol edin; NAS alanına geçerli bir IPv4 adresi yazın.':'Erişim kayıtları alınamadı. Önceki liste korunuyor; yeniden deneyin.';}
  finally{if(generation===authGeneration&&request===accessRequest){accessLoading=false;accessControls();}}
}
function exportAccessEvents(){
  if(!can('audit.events')||!accessPage||accessLoading||accessLoadedKey!==accessKey())return;
  const columns=['id','at','response_code','reason','reason_source','nas_ip','policy_id','vlan','tls_verified','certificate_serial','object_guid','identity_kind','calling_station','request_id','event_id','capture_run'];
  const header=['Kayıt ID','Zaman UTC','RADIUS yanıt kodu','Neden','Neden kaynağı','Paket kaynak NAS IP','Policy ID','Yanıttaki VLAN','TLS doğrulandı','Sertifika seri','Kayıtlı kimlik GUID','Kimlik türü','İstemci MAC (NAS bildirimi)','Paket korelasyon ID','Olay ID','Kayıt süreci'];
  const rows=[header,...accessPage.events.map(e=>columns.map(k=>e[k]))],blob=new Blob(['\uFEFF'+rows.map(r=>r.map(auditCsvCell).join(',')).join('\r\n')+'\r\n'],{type:'text/csv;charset=utf-8'}),url=URL.createObjectURL(blob),a=document.createElement('a');
  a.href=url;a.download='AuthWire-erisim-kayitlari-'+new Date().toISOString().slice(0,10)+'.csv';document.body.append(a);a.click();a.remove();setTimeout(()=>URL.revokeObjectURL(url),1000);
}
function openAccessEvents(id){if(id==='access-events')run(()=>loadAccessEvents());}
document.getElementById('access-filters').addEventListener('submit',e=>{e.preventDefault();run(()=>loadAccessEvents());});
document.getElementById('access-next').addEventListener('click',()=>run(()=>loadAccessEvents({next:true})));
document.getElementById('access-reset').addEventListener('click',()=>{if(accessLoading)return;accessDashboardRange=null;$('access-filters').reset();run(()=>loadAccessEvents());});
document.getElementById('access-export').addEventListener('click',exportAccessEvents);
for(const id of ['access-from','access-to','access-result','access-nas','access-reason','access-query'])document.getElementById(id).addEventListener('input',()=>{accessDashboardRange=null;$('access-feedback').textContent='Filtreler değişti. Uygula ile yeniden arayın.';accessControls();});


function accountingControls(){
  const allowed = can('audit.events') && !accountingLoading;
  $('accounting-refresh').disabled = !allowed;
  $('accounting-next').disabled = !allowed || !accountingPage?.has_more;
}

function resetAccountingSessions(){
  accountingRequest++;
  accountingPage = null;
  accountingLoading = false;
  $('accounting-sessions').open = false;
  $('accounting-list').replaceChildren();
  $('accounting-feedback').textContent = '';
  accountingControls();
}

function renderAccountingSessions(page){
  const body = $('accounting-list');
  body.replaceChildren();
  for(const session of page.sessions){
    const row = document.createElement('tr');
    const nas = auditText('td', session.nas_ip);
    if(session.nas_port)nas.append(auditText('small', 'Port ' + session.nas_port));
    if(session.calling_station)nas.append(auditText('small', session.calling_station));
    row.append(auditText('td', session.session_id), nas,
      auditText('td', auditTime(session.started_at)), auditText('td', auditTime(session.last_at)),
      auditText('td', session.stopped_at ? auditTime(session.stopped_at) : 'Stop bekleniyor'),
      auditText('td', session.session_time ?? '—'),
      auditText('td', (session.input_bytes ?? '—') + ' / ' + (session.output_bytes ?? '—')));
    body.append(row);
  }
  $('accounting-feedback').textContent = !page.initialized ? 'Accounting kaydı henüz başlatılmamış.' :
    !page.sessions.length ? 'Accounting oturumu bulunamadı.' :
    page.sessions.length + ' oturum gösteriliyor.';
}

async function loadAccountingSessions(next = false){
  if(!can('audit.events') || accountingLoading || (next && !accountingPage?.has_more))return;
  const request = ++accountingRequest, generation = authGeneration;
  const active = () => request === accountingRequest && generation === authGeneration && can('audit.events');
  const query = next ? '?' + new URLSearchParams({
    before:accountingPage.next_before, watermark:accountingPage.watermark}) : '';
  accountingLoading = true;
  accountingControls();
  $('accounting-feedback').textContent = 'Accounting oturumları okunuyor…';
  try{
    const page = await api('/api/radius/accounting/sessions' + query);
    if(!active())return;
    accountingPage = page;
    renderAccountingSessions(page);
  }catch(error){
    if(active() && error.code !== 'SESSION_CHANGED'){
      $('accounting-feedback').textContent = 'Accounting oturumları alınamadı. Yeniden deneyin.';
    }
  }finally{
    if(active()){
      accountingLoading = false;
      accountingControls();
    }
  }
}

document.getElementById('accounting-sessions').addEventListener('toggle',()=>{
  if($('accounting-sessions').open && !accountingPage)run(()=>loadAccountingSessions());
});
document.getElementById('accounting-refresh').addEventListener('click',()=>run(()=>loadAccountingSessions()));
document.getElementById('accounting-next').addEventListener('click',()=>run(()=>loadAccountingSessions(true)));
