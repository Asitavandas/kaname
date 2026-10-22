'use strict';
let dashboardData=null,dashboardRequest=0,dashboardTimer=0,dashboardLoading=false;
const dashboardNumber=value=>Number(value||0).toLocaleString('tr-TR');
function dashText(tag,text,className=''){const e=document.createElement(tag);e.textContent=text;if(className)e.className=className;return e;}
function dashEmpty(id,text){$(id).replaceChildren(dashText('p',text,'dashboard-empty'));}
function dashboardVisible(){return !!session&&!$('overview').hidden&&!document.hidden;}
function dashboardPermissions(){
 for(const [id,permission]of [['dashboard-accept-card','audit.events'],['dashboard-reject-card','audit.events'],['dashboard-all-events','audit.events'],['dashboard-cert-card','certificates.authority'],['dashboard-expiring-card','certificates.authority']])$(id).disabled=!can(permission);
 $('dashboard-crl-row').hidden=!can('certificates.authority');
 if(!can('system.services'))renderDashboardBackup(null);
 if(dashboardData&&((dashboardData.events&&!can('audit.events'))||(dashboardData.certificates&&!can('certificates.authority'))))resetDashboard();
}
function resetDashboard(){dashboardRequest++;clearTimeout(dashboardTimer);dashboardLoading=false;dashboardData=null;for(const id of ['dashboard-accept','dashboard-reject','dashboard-certificates','dashboard-expiring'])$(id).textContent='—';for(const id of ['dashboard-trend','dashboard-donut','dashboard-types','dashboard-nas','dashboard-heatmap','dashboard-recent','dashboard-alerts'])$(id).replaceChildren();$('dashboard-alerts').hidden=true;$('dashboard-feedback').textContent='';$('dashboard-updated').textContent='Henüz yenilenmedi';$('dashboard-period').value='7d';renderDashboardBackup(null);}
function openDashboard(id){clearTimeout(dashboardTimer);document.querySelector('.notice').hidden=id==='overview';if(id==='overview')loadDashboard();}
function dashSVG(tag,attrs={}){const e=document.createElementNS('http://www.w3.org/2000/svg',tag);for(const [key,value]of Object.entries(attrs))e.setAttribute(key,String(value));return e;}
function renderDashboardTrend(events){
 const host=$('dashboard-trend');host.replaceChildren();
 if(!events?.available){dashEmpty('dashboard-trend',can('audit.events')?'Erişim verileri alınamadı.':'Bu verilere erişim yetkiniz yok.');return;}
 const rows=events.series;if(!events.total){dashEmpty('dashboard-trend','Seçilen dönemde kayıtlı yanıt yok.');return;}
 const svg=dashSVG('svg',{viewBox:'0 0 740 220',role:'img','aria-label':'Kabul ve ret yanıtlarının zaman içindeki dağılımı'}),max=Math.max(1,...rows.map(r=>r.accept+r.reject)),left=42,width=680,base=180;
 for(let i=0;i<=4;i++){const y=base-i*38;svg.append(dashSVG('line',{x1:left,x2:728,y1:y,y2:y,stroke:'#DDD1BD','stroke-dasharray':'3 5'}));const label=dashSVG('text',{x:32,y:y+4,'text-anchor':'end',fill:'#655E52','font-size':10});label.textContent=String(Math.round(max*i/4));svg.append(label);}
 const step=width/rows.length,bar=Math.max(3,Math.min(26,step*.55));
 rows.forEach((row,i)=>{const x=left+step*i+(step-bar)/2,yes=row.accept/max*152,no=row.reject/max*152;const g=dashSVG('g');const title=dashSVG('title');title.textContent=new Date(row.at).toLocaleString('tr-TR',{timeZone:'Europe/Istanbul'})+': '+row.accept+' kabul, '+row.reject+' ret';g.append(title,dashSVG('rect',{x,y:base-yes,width:bar,height:yes,rx:2,fill:'#1D4D73'}),dashSVG('rect',{x,y:base-yes-no,width:bar,height:no,rx:2,fill:'#D96B52'}));svg.append(g);
 if(i===0||i===rows.length-1||i%Math.max(1,Math.floor(rows.length/5))===0){const t=dashSVG('text',{x:x+bar/2,y:205,'text-anchor':'middle',fill:'#655E52','font-size':10});t.textContent=new Date(row.at).toLocaleString('tr-TR',dashboardData.period==='24h'?{timeZone:'Europe/Istanbul',hour:'2-digit',minute:'2-digit'}:{timeZone:'Europe/Istanbul',day:'2-digit',month:'short'});svg.append(t);}});
 host.append(svg);$('dashboard-trend-summary').textContent=dashboardNumber(events.accept)+' kabul · '+dashboardNumber(events.reject)+' ret · '+(events.total?(events.accept/events.total*100).toFixed(1):'0')+'% kabul oranı';
}
function renderDashboardTypes(events){
 $('dashboard-donut').replaceChildren();$('dashboard-types').replaceChildren();
 if(!events?.available||!events.total){dashEmpty('dashboard-donut',events?.available?'Dağılım için kayıt yok.':'Dağılım bilgisi alınamadı.');return;}
 const names={wired:'Kablolu',wireless:'Kablosuz',unknown:'Türü belirlenemedi'},colors={wired:'#1D4D73',wireless:'#68A9CF',unknown:'#C8BDA8'},ring=document.createElement('div');ring.className='dashboard-ring';let start=0;const segments=[];
 for(const row of events.access_types){const end=start+row.count/events.total*100;segments.push(colors[row.type]+' '+start+'% '+end+'%');start=end;const line=dashText('div','', 'dashboard-type-row'),dot=document.createElement('i');dot.style.background=colors[row.type];line.append(dot,dashText('span',names[row.type]),dashText('strong',dashboardNumber(row.count)));$('dashboard-types').append(line);}
 ring.style.background='conic-gradient('+segments.join(',')+')';const center=dashText('div','','dashboard-ring-center');center.append(dashText('strong',dashboardNumber(events.total)),dashText('small','kayıtlı yanıt'));ring.append(center);$('dashboard-donut').append(ring);
}
function dashboardAccess(result='',nas=''){
 if(!can('audit.events')||accessLoading)return;
 $('access-filters').reset();$('access-result').value=result;$('access-nas').value=nas;
 accessDashboardRange=dashboardData?.events?.available?{from:dashboardData.from,to:dashboardData.to,watermark:String(dashboardData.events.watermark??0)}:null;
 // Keep precise rolling interval and snapshot for drill-down, not just dates.
 if(accessDashboardRange){$('access-from').value=new Intl.DateTimeFormat('en-CA',{timeZone:'Europe/Istanbul',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date(accessDashboardRange.from));$('access-to').value=new Intl.DateTimeFormat('en-CA',{timeZone:'Europe/Istanbul',year:'numeric',month:'2-digit',day:'2-digit'}).format(new Date(accessDashboardRange.to));}
 showView('access-events');
}
function renderDashboardNAS(events){
 const host=$('dashboard-nas');host.replaceChildren();
 if(!events?.available||!events.total){dashEmpty('dashboard-nas',events?.available?'Bu dönemde switch / AP kaydı yok.':'Switch / AP verileri alınamadı.');return;}
 const top=events.nas.slice(0,6),max=Math.max(...top.map(r=>r.count));
 for(const row of top){const button=dashText('button','','dashboard-nas-row');button.type='button';const label=dashText('span','','dashboard-nas-label');label.append(dashText('strong',row.name),dashText('small',row.name===row.ip?'NAS kaynak IP':row.ip));const track=dashText('span','','dashboard-bar-track'),fill=document.createElement('i');fill.style.width=(row.count/max*100)+'%';track.append(fill);button.append(label,track,dashText('b',dashboardNumber(row.count)));button.addEventListener('click',()=>dashboardAccess('',row.ip));host.append(button);}
}
function renderDashboardHeat(events){
 const host=$('dashboard-heatmap');host.replaceChildren();if(!events?.available||!events.total){dashEmpty('dashboard-heatmap',events?.available?'Yoğunluk haritası için kayıt yok.':'Yoğunluk bilgisi alınamadı.');return;}
 const rows=events.heatmap,max=Math.max(1,...rows.map(r=>r.count)),lookup=new Map(rows.map(r=>[r.day+':'+r.hour,r.count])),grid=dashText('div','','dashboard-heat-grid');grid.append(dashText('span',''));
 for(let hour=0;hour<24;hour++)grid.append(dashText('small',hour%4===0?String(hour).padStart(2,'0'):''));
 for(let day=0;day<7;day++){grid.append(dashText('small',['Pzt','Sal','Çar','Per','Cum','Cmt','Paz'][day]));for(let hour=0;hour<24;hour++){const n=lookup.get(day+':'+hour)||0,cell=document.createElement('span');cell.className='dashboard-heat-cell';cell.dataset.level=n?String(Math.max(1,Math.ceil(n/max*4))):'0';cell.title=['Pazartesi','Salı','Çarşamba','Perşembe','Cuma','Cumartesi','Pazar'][day]+' '+String(hour).padStart(2,'0')+':00 · '+n+' yanıt';grid.append(cell);}}host.append(grid);
}
function renderDashboardRecent(events){
 const host=$('dashboard-recent');host.replaceChildren();
 for(const row of events?.recent||[]){const tr=document.createElement('tr'),nas=events.nas.find(n=>n.ip===row.nas_ip),policy=state?.policies?.find(p=>p.id===row.policy_id),decision=dashText('td','');const badge=dashText('span',row.response_code===2?'Kabul':'Ret','dashboard-decision '+(row.response_code===2?'accept':'reject'));decision.append(badge,dashText('small',accessReasons[row.reason]||row.reason));tr.append(dashText('td',new Date(row.at).toLocaleString('tr-TR',{timeZone:'Europe/Istanbul',day:'2-digit',month:'2-digit',hour:'2-digit',minute:'2-digit',second:'2-digit'})),dashText('td',row.object_guid||row.calling_station||'Doğrulanmış kimlik yok'),dashText('td',nas?.name||row.nas_ip),dashText('td',policy?.name||row.policy_id||'—'),dashText('td',row.vlan??'—'),decision);host.append(tr);}
 if(!events?.recent?.length){const tr=document.createElement('tr'),td=dashText('td',events?.available?'Seçilen dönemde kayıt yok.':can('audit.events')?'Erişim kayıtları alınamadı.':'Erişim kayıtlarını görüntüleme yetkiniz yok.');td.colSpan=6;tr.append(td);host.append(tr);}
}
function renderDashboard(){
 const e=dashboardData?.events,c=dashboardData?.certificates;
 $('dashboard-accept').textContent=e?.available?dashboardNumber(e.accept):'—';$('dashboard-reject').textContent=e?.available?dashboardNumber(e.reject):'—';$('dashboard-certificates').textContent=c?.available?dashboardNumber(c.valid_computers):'—';$('dashboard-expiring').textContent=c?.available?dashboardNumber(c.expiring_computers):'—';$('dashboard-total').textContent=e?.available?dashboardNumber(e.total)+' yanıt':'Veri yok';$('dashboard-trend-summary').textContent='';
 renderDashboardTrend(e);renderDashboardTypes(e);renderDashboardNAS(e);renderDashboardHeat(e);renderDashboardRecent(e);
 const crl=c?.crl,badge=$('dashboard-crl');badge.textContent=crl?(crl.current&&crl.signature_valid?'Güncel':'Kontrol gerekli'):'Bilgi alınamadı';badge.dataset.status=crl?(crl.current&&crl.signature_valid?'ready':'error'):'pending';$('dashboard-crl-detail').textContent=crl?'Çalışan CRL son geçerlilik: '+new Date(crl.next_update).toLocaleString('tr-TR',{timeZone:'Europe/Istanbul'}):'Çalışan iptal listesi bu oturumda doğrulanamadı.';
 const alerts=$('dashboard-alerts');alerts.replaceChildren();
 if(c?.available&&c.expiring_computers){const b=dashText('button',c.expiring_computers+' cihaz sertifikasının süresi 30 gün içinde doluyor. İncele →');b.type='button';b.addEventListener('click',()=>dashboardCertificates(true));alerts.append(b);}
 if(crl&&(!crl.current||!crl.signature_valid))alerts.append(dashText('p','CRL güncelliği veya imzası kontrol edilmeli.'));
 if(e?.observer&&(!e.observer.enabled||e.observer.dropped>0))alerts.append(dashText('p','Erişim kayıt modülünde uyarı var. Erişim kayıtlarındaki gözlem ayrıntılarını kontrol edin.'));
 alerts.hidden=!alerts.childElementCount;dashboardPermissions();
 $('dashboard-updated').textContent='Son okuma: '+new Date(dashboardData.checked_at).toLocaleString('tr-TR',{timeZone:'Europe/Istanbul'});
}
function dashboardCertificates(expiring=false){if(!can('certificates.authority'))return;showView('certificates');setPKITab('users');$('pki-search').value='';message(expiring?'Sertifika listesinde son geçerlilik tarihlerini kontrol edin. Dashboard sayacı tüm kayıtlı cihaz sertifikalarını kapsar; liste sayfalıdır.':'Geçerli cihaz sertifikaları: sertifika listesinden tarih ve durum ayrıntılarını inceleyin.');}
async function loadDashboard(){
 if(!session||dashboardLoading||$('overview').hidden)return;
 const allowed=can('audit.events')||can('certificates.authority');if(!allowed){dashboardData={checked_at:new Date().toISOString()};renderDashboard();$('dashboard-feedback').textContent='Grafik ve sertifika özetleri için görüntüleme yetkisi gerekiyor.';return;}
 const request=++dashboardRequest,generation=authGeneration,period=$('dashboard-period').value;dashboardLoading=true;$('dashboard-refresh').disabled=true;$('dashboard-feedback').textContent='Özet okunuyor…';
 try{const value=await api('/api/dashboard?period='+encodeURIComponent(period));if(generation!==authGeneration||request!==dashboardRequest)return;dashboardData=value;renderDashboard();$('dashboard-feedback').textContent=[value.events&&!value.events.available?'Erişim özeti alınamadı.':'',value.certificates&&!value.certificates.available?'Sertifika özeti alınamadı.':''].filter(Boolean).join(' ')||'Kayıtlı veriler · '+(value.period==='24h'?'Son 24 saat':value.period==='7d'?'Son 7 gün':'Son 30 gün')+' · Saat dilimi: İstanbul';}
 catch(error){if(generation!==authGeneration||request!==dashboardRequest)return;dashboardData={checked_at:new Date().toISOString()};renderDashboard();$('dashboard-feedback').textContent='Dashboard verileri alınamadı. Yenile ile tekrar deneyin.';}
 finally{if(generation===authGeneration&&request===dashboardRequest){dashboardLoading=false;$('dashboard-refresh').disabled=false;if(dashboardVisible())dashboardTimer=setTimeout(loadDashboard,60000);}}
}
$('dashboard-refresh').addEventListener('click',()=>{clearTimeout(dashboardTimer);loadDashboard();loadRadiusOverview();});
$('dashboard-period').addEventListener('change',()=>{dashboardRequest++;dashboardLoading=false;clearTimeout(dashboardTimer);loadDashboard();});
$('dashboard-accept-card').addEventListener('click',()=>dashboardAccess('accept'));$('dashboard-reject-card').addEventListener('click',()=>dashboardAccess('reject'));$('dashboard-all-events').addEventListener('click',()=>dashboardAccess());$('dashboard-cert-card').addEventListener('click',()=>dashboardCertificates());$('dashboard-expiring-card').addEventListener('click',()=>dashboardCertificates(true));
document.addEventListener('visibilitychange',()=>{clearTimeout(dashboardTimer);if(dashboardVisible())loadDashboard();});

function renderDashboardBackup(value){
 const badge=$('dashboard-backup'),detail=$('dashboard-backup-detail');
 if(!can('system.services')){badge.textContent='Yetki yok';badge.dataset.status='pending';detail.textContent='Servis görüntüleme yetkisi gerekiyor.';return;}
 const at=Date.parse(value?.last_success_at),age=Date.now()-at;
 if(!value?.available||!Number.isFinite(at)){badge.textContent='Bilgi alınamadı';badge.dataset.status='pending';detail.textContent='Son yedek durum kaydı okunamadı.';return;}
 const okay=value.last_run_succeeded&&value.archive_read_verified&&value.sqlite_integrity_verified&&age>=-300000&&age<=36*3600000;
 badge.textContent=okay?'Başarılı':'Kontrol gerekli';badge.dataset.status=okay?'ready':'error';detail.textContent='Son başarılı yedek: '+new Date(at).toLocaleString('tr-TR',{timeZone:'Europe/Istanbul'})+(value.last_run_succeeded?' · Son çalışma başarılı.':' · Son çalışma başarısız.')+' Durum kaydıdır; sunucu dışı kopya ve tam açılış geri yükleme testi anlamına gelmez.';
}
