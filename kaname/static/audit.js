'use strict';
let auditPage=null,auditQuery=null,auditLoading=false,auditRequest=0,auditLoadedKey='';
const auditNames={config_saved:'Temel ayarlar kaydedildi',policies_saved:'Erişim kuralları kaydedildi',network_saved:'Ağ ayarları kaydedildi',directory_connection_saved:'LDAP bağlantısı kaydedildi',directory_synced:'Dizin okundu',directory_health_error:'Dizin bağlantı hatası',directory_health_restored:'Dizin bağlantısı düzeldi',radius_secret_viewed:'RADIUS shared secret görüntülendi',service_action_requested:'Servis işlemi talep edildi',device_profile_saved:'Sertifika profili kaydedildi',device_certificate_issued:'Cihaz sertifikası üretildi',device_certificate_installed:'Sertifika kurulumu onaylandı',device_certificate_superseded:'Önceki sertifika değiştirildi',device_renewal_requested:'Yenileme talep edildi',pki_certificate_revoked:'Sertifika iptal edildi',pki_certificate_archived:'Sertifika arşivlendi',pki_crl_refreshed:'İptal listesi yenilendi',device_crl_refreshed:'Cihaz iptal listesi yenilendi',admin_login:'Panel girişi başarılı',admin_user_saved:'Panel hesabı kaydedildi',admin_profile_saved:'Yetki profili kaydedildi',admin_user_deleted:'Panel hesabı silindi',admin_profile_deleted:'Yetki profili silindi',admin_password_changed:'Panel parolası değiştirildi'};
function auditText(tag,value){const e=document.createElement(tag);e.textContent=value;return e;}
function auditFilters(){
  const q={source:$('audit-source').value};
  for(const [id,key]of [['audit-event','event'],['audit-query','q']])if($(id).value)q[key]=$(id).value;
  const start=$('audit-from').value,end=$('audit-to').value;
  if(start)q.from=new Date(start+'T00:00:00').toISOString();
  if(end){const d=new Date(end+'T00:00:00');d.setDate(d.getDate()+1);q.to=d.toISOString();}
  if(q.from&&q.to&&q.from>=q.to)throw new Error('Başlangıç tarihi bitiş tarihinden sonra olamaz.');
  return q;
}
function auditKey(){try{return JSON.stringify(auditFilters());}catch(_){return '';}}
function auditControls(){
  const allowed=can('audit.events'),fresh=!!auditPage&&auditKey()===auditLoadedKey;
  $('audit-reset').disabled=!allowed||auditLoading;$('audit-apply').disabled=!allowed||auditLoading;$('audit-next').disabled=!allowed||auditLoading||!fresh||!auditPage?.has_more;
  $('audit-export').disabled=!allowed||auditLoading||!fresh||!auditPage?.events.length;
}
function resetAudit(){auditRequest++;auditPage=null;auditQuery=null;auditLoading=false;auditLoadedKey='';$('audit-filters').reset();$('audit-list').replaceChildren();$('audit-storage').textContent='';$('audit-feedback').textContent='';auditControls();}
function auditPermissions(){
  const option=$('audit-source').querySelector('[value="administrators"]');option.hidden=option.disabled=!can('system.administrators');
  if(!can('audit.events')){if(auditPage)resetAudit();}
  else if(!can('system.administrators')&&($('audit-source').value==='administrators'||auditPage?.source==='administrators'))resetAudit();
  auditControls();
}
function auditTime(value){const n=Date.parse(value);return Number.isFinite(n)?new Date(n).toLocaleString('tr-TR'):value||'—';}
function renderAudit(){
  const parent=$('audit-list');parent.replaceChildren();
  for(const event of auditPage.events){
    const row=document.createElement('tr');
    const name=auditText('td',auditNames[event.event]||'Kayıtlı işlem');name.append(auditText('small',event.event));
    if(event.service)name.append(auditText('small',event.service+' · '+event.action+' · Talep kaydı; sonuç Servisler ekranındadır.'));
    row.append(auditText('td',auditTime(event.at)),name,auditText('td',event.actor||'Kaydedilmemiş'),auditText('td',event.reference||event.target||event.request_id||'—'),auditText('td',event.revision??'—'));parent.append(row);
  }
  if(!auditPage.events.length){const cell=auditText('td','Bu filtrelerle kayıt bulunamadı.');cell.colSpan=5;const row=document.createElement('tr');row.append(cell);parent.append(row);}
  const s=auditPage.storage;
  $('audit-storage').textContent='Bu kaynakta toplam '+s.records+' kayıt · İlk: '+auditTime(s.oldest)+' · Son: '+auditTime(s.newest)+' · Veritabanı: '+(s.database_bytes/1048576).toFixed(2)+' MB (diğer veriler dahil). Kayıtlar silinmez; otomatik temizleme tanımlı değildir.';
  $('audit-feedback').textContent=auditPage.events.length+' kayıt gösteriliyor'+(auditPage.has_more?' · Daha eski kayıtlar var.':'.')+' CSV yalnız bu sayfadaki kayıtları içerir.';
  auditControls();
}
async function loadAuditHistory({next=false,background=false}={}){
  if(!can('audit.events')||background&&$('audit').hidden)return;
  if(auditLoading)return;
  const filters=auditFilters(),key=JSON.stringify(filters),generation=authGeneration,request=++auditRequest;
  if(next&&(!auditPage?.has_more||key!==auditLoadedKey))return;
  const query={...filters,...(next?{before:auditPage.next_before,watermark:auditPage.watermark}:{})};
  auditLoading=true;auditControls();$('audit-feedback').textContent='Kayıtlar okunuyor…';
  try{
    const page=await api('/api/audit/history?'+new URLSearchParams(query));
    if(request!==auditRequest||generation!==authGeneration||!can('audit.events')||page.source==='administrators'&&!can('system.administrators'))return;
    if(auditKey()!==key){$('audit-feedback').textContent='Filtreler değişti. Uygula ile güncel aramayı çalıştırın.';return;}
    auditPage=page;auditQuery=query;auditLoadedKey=key;renderAudit();
  }catch(error){if(generation===authGeneration&&request===auditRequest&&error.code!=='SESSION_CHANGED')$('audit-feedback').textContent=error.code==='AUDIT_QUERY_LIMIT'?'Arama sınırı aşıldı. Tarih veya olay filtresini daraltın.':error.code==='INVALID_INPUT'?'Filtreleri kontrol edin. Olay kodunda küçük harf, rakam ve alt çizgi kullanın.':'Kayıtlar alınamadı. Önceki liste korunuyor; yeniden deneyin.';}
  finally{if(generation===authGeneration&&request===auditRequest){auditLoading=false;auditControls();}}
}
function auditCsvCell(value){let v=String(value??'');if(/^[\s\uFEFF]*[=+\-@]/u.test(v)||/^[\t\r\n]/.test(v))v="'"+v;return '"'+v.replaceAll('"','""')+'"';}
function exportAuditPage(){
  if(!can('audit.events')||!auditPage||auditKey()!==auditLoadedKey||auditLoading||auditPage.source==='administrators'&&!can('system.administrators'))return;
  const rows=[['Kaynak','Kayıt ID','Zaman UTC','Olay','İşlem yapan','Hedef','Referans','Sürüm','Servis','Eylem','Talep ID'],...auditPage.events.map(e=>[e.source,e.id,e.at,e.event,e.actor,e.target,e.reference,e.revision,e.service,e.action,e.request_id])];
  const blob=new Blob(['\uFEFF'+rows.map(r=>r.map(auditCsvCell).join(',')).join('\r\n')+'\r\n'],{type:'text/csv;charset=utf-8'}),url=URL.createObjectURL(blob),a=document.createElement('a');
  a.href=url;a.download='AuthWire-islem-gecmisi-'+auditPage.source+'-'+new Date().toISOString().slice(0,10)+'.csv';document.body.append(a);a.click();a.remove();setTimeout(()=>URL.revokeObjectURL(url),1000);
}
function openAudit(id){if(id==='audit')run(()=>loadAuditHistory());}
document.getElementById('audit-filters').addEventListener('submit',e=>{e.preventDefault();run(()=>loadAuditHistory());});
document.getElementById('audit-next').addEventListener('click',()=>run(()=>loadAuditHistory({next:true})));
document.getElementById('audit-reset').addEventListener('click',()=>{if(auditLoading)return;$('audit-filters').reset();run(()=>loadAuditHistory());});
document.getElementById('audit-export').addEventListener('click',exportAuditPage);
for(const id of ['audit-source','audit-event','audit-query','audit-from','audit-to'])document.getElementById(id).addEventListener('input',()=>{$('audit-feedback').textContent='Filtreler değişti. Uygula ile aramayı çalıştırın.';auditControls();});
