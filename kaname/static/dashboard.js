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
function resetDashboard(){dashboardResetLayoutSession();dashboardRequest++;clearTimeout(dashboardTimer);dashboardLoading=false;dashboardData=null;for(const id of ['dashboard-accept','dashboard-reject','dashboard-certificates','dashboard-expiring'])$(id).textContent='—';for(const id of ['dashboard-trend','dashboard-donut','dashboard-types','dashboard-nas','dashboard-heatmap','dashboard-recent','dashboard-alerts'])$(id).replaceChildren();$('dashboard-alerts').hidden=true;$('dashboard-feedback').textContent='';$('dashboard-updated').textContent='Henüz yenilenmedi';$('dashboard-period').value='7d';renderDashboardBackup(null);}
function openDashboard(id){dashboardLayoutHydrate();clearTimeout(dashboardTimer);document.querySelector('.notice').hidden=id==='overview';if(id==='overview')loadDashboard();}
function dashSVG(tag,attrs={}){const e=document.createElementNS('http://www.w3.org/2000/svg',tag);for(const [key,value]of Object.entries(attrs))e.setAttribute(key,String(value));return e;}
function dashboardTip(host,title,detail,x=50,y=10){
 let tip=host.querySelector('.dashboard-chart-tip');if(!tip){tip=dashText('div','','dashboard-chart-tip');tip.setAttribute('role','status');host.append(tip);}
 tip.replaceChildren(dashText('strong',title),dashText('span',detail));tip.style.left=Math.max(35,Math.min(65,x))+'%';tip.style.top=Math.max(5,Math.min(75,y))+'%';tip.hidden=false;
}
function renderDashboardTrend(events){
 const host=$('dashboard-trend');host.replaceChildren();
 if(!events?.available){dashEmpty('dashboard-trend',can('audit.events')?'Erişim verileri alınamadı.':'Bu verilere erişim yetkiniz yok.');return;}
 if(!events.total){dashEmpty('dashboard-trend','Seçilen dönemde kayıtlı yanıt yok.');return;}
 const rows=events.series,svg=dashSVG('svg',{viewBox:'0 0 740 250',role:'img','aria-label':'Kabul ve ret yanıtlarının zaman içindeki dağılımı'}),max=Math.max(1,...rows.map(r=>Math.max(r.accept,r.reject))),left=44,width=670,base=205,height=175;
 const defs=dashSVG('defs');for(const [id,color]of [['accept','#1D4D73'],['reject','#D96B52']]){const gradient=dashSVG('linearGradient',{id:'dashboard-fill-'+id,x1:0,y1:0,x2:0,y2:1});gradient.append(dashSVG('stop',{offset:'0%','stop-color':color,'stop-opacity':'.32'}),dashSVG('stop',{offset:'100%','stop-color':color,'stop-opacity':'.015'}));defs.append(gradient);}svg.append(defs);
 for(let i=0;i<=4;i++){const y=base-i*height/4;svg.append(dashSVG('line',{x1:left,x2:724,y1:y,y2:y,stroke:'#DFE7EE','stroke-dasharray':'3 5'}));const label=dashSVG('text',{x:34,y:y+4,'text-anchor':'end',fill:'#697D8F','font-size':10});label.textContent=String(Math.round(max*i/4));svg.append(label);}
 const x=i=>left+(rows.length===1?width/2:width*i/(rows.length-1)),y=n=>base-n/max*height;
 for(const [key,color]of [['accept','#1D4D73'],['reject','#D96B52']]){
  const line=rows.map((row,i)=>(i?'L':'M')+x(i)+' '+y(row[key])).join(' '),area=line+' L'+x(rows.length-1)+' '+base+' L'+x(0)+' '+base+' Z';
  svg.append(dashSVG('path',{d:area,fill:'url(#dashboard-fill-'+key+')',class:'dashboard-area'}),dashSVG('path',{d:line,fill:'none',stroke:color,'stroke-width':3.2,'stroke-linejoin':'round','stroke-linecap':'round',class:'dashboard-line'}));
 }
 const guide=dashSVG('line',{x1:0,x2:0,y1:15,y2:base,stroke:'#83A6C1','stroke-dasharray':'4 4',class:'dashboard-crosshair',visibility:'hidden'});svg.append(guide);
 rows.forEach((row,i)=>{
  const date=new Date(row.at).toLocaleString('tr-TR',{timeZone:'Europe/Istanbul'}),group=dashSVG('g',{tabindex:0,role:'img','aria-label':date+': '+row.accept+' kabul, '+row.reject+' ret',class:'dashboard-point'}),step=rows.length>1?width/(rows.length-1):width;
  group.append(dashSVG('rect',{x:x(i)-Math.min(22,step/2),y:10,width:Math.min(44,step),height:height+25,fill:'transparent'}));
  for(const [key,color]of [['accept','#1D4D73'],['reject','#D96B52']])group.append(dashSVG('circle',{cx:x(i),cy:y(row[key]),r:4,fill:'white',stroke:color,'stroke-width':2}));
  const reveal=()=>{guide.setAttribute('x1',x(i));guide.setAttribute('x2',x(i));guide.setAttribute('visibility','visible');dashboardTip(host,date,dashboardNumber(row.accept)+' kabul · '+dashboardNumber(row.reject)+' ret',x(i)/740*100,8);};
  const hide=()=>{guide.setAttribute('visibility','hidden');host.querySelector('.dashboard-chart-tip')?.setAttribute('hidden','');};
  group.addEventListener('pointerenter',reveal);group.addEventListener('focus',reveal);group.addEventListener('pointerleave',hide);group.addEventListener('blur',hide);svg.append(group);
  if(i===0||i===rows.length-1||i%Math.max(1,Math.floor(rows.length/5))===0){const label=dashSVG('text',{x:x(i),y:233,'text-anchor':'middle',fill:'#697D8F','font-size':10});label.textContent=new Date(row.at).toLocaleString('tr-TR',dashboardData.period==='24h'?{timeZone:'Europe/Istanbul',hour:'2-digit',minute:'2-digit'}:{timeZone:'Europe/Istanbul',day:'2-digit',month:'short'});svg.append(label);}
 });
 host.append(svg);$('dashboard-trend-summary').textContent=dashboardNumber(events.accept)+' kabul · '+dashboardNumber(events.reject)+' ret · '+(events.accept/events.total*100).toFixed(1)+'% kabul oranı';
}
function renderDashboardTypes(events){
 const host=$('dashboard-donut');host.replaceChildren();$('dashboard-types').replaceChildren();
 if(!events?.available||!events.total){dashEmpty('dashboard-donut',events?.available?'Dağılım için kayıt yok.':'Dağılım bilgisi alınamadı.');return;}
 const names={wired:'Kablolu',wireless:'Kablosuz',unknown:'Türü belirlenemedi'},colors={wired:'#1D4D73',wireless:'#68A9CF',unknown:'#AAB9C6'},svg=dashSVG('svg',{viewBox:'0 0 240 240',role:'img','aria-label':'Kablolu ve kablosuz kayıtlı doğrulama dağılımı',class:'dashboard-donut-svg'}),radius=83,circumference=2*Math.PI*radius;
 svg.append(dashSVG('circle',{cx:120,cy:120,r:radius,fill:'none',stroke:'#EDF3F7','stroke-width':25}));
 const number=dashSVG('text',{x:120,y:116,'text-anchor':'middle',class:'donut-number'}),caption=dashSVG('text',{x:120,y:140,'text-anchor':'middle',class:'donut-caption'});
 const restore=()=>{number.textContent=dashboardNumber(events.total);caption.textContent='kayıtlı yanıt';};let start=0;
 for(const row of events.access_types){
  const line=dashText('div','','dashboard-type-row'),dot=document.createElement('i');dot.style.background=colors[row.type];line.append(dot,dashText('span',names[row.type]),dashText('strong',dashboardNumber(row.count)));$('dashboard-types').append(line);
  if(!row.count)continue;const length=row.count/events.total*circumference,segment=dashSVG('circle',{cx:120,cy:120,r:radius,fill:'none',stroke:colors[row.type],'stroke-width':25,'stroke-dasharray':Math.max(0,length-2.2)+' '+(circumference-Math.max(0,length-2.2)),'stroke-dashoffset':-start,transform:'rotate(-90 120 120)',tabindex:0,role:'img','aria-label':names[row.type]+': '+row.count+' yanıt',class:'dashboard-donut-segment'});
  const reveal=()=>{number.textContent=dashboardNumber(row.count);caption.textContent=names[row.type]+' · %'+(row.count/events.total*100).toFixed(1);line.classList.add('is-highlighted');};
  const hide=()=>{restore();line.classList.remove('is-highlighted');};segment.addEventListener('pointerenter',reveal);segment.addEventListener('focus',reveal);segment.addEventListener('pointerleave',hide);segment.addEventListener('blur',hide);line.addEventListener('pointerenter',()=>{reveal();segment.classList.add('is-highlighted');});line.addEventListener('pointerleave',()=>{hide();segment.classList.remove('is-highlighted');});svg.append(segment);start+=length;
 }
 restore();svg.append(number,caption);host.append(svg);
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
 for(let day=0;day<7;day++){grid.append(dashText('small',['Pzt','Sal','Çar','Per','Cum','Cmt','Paz'][day]));for(let hour=0;hour<24;hour++){const n=lookup.get(day+':'+hour)||0,cell=document.createElement('span');cell.className='dashboard-heat-cell';cell.tabIndex=0;cell.style.setProperty('--cell-delay',(day*12+hour*4)+'ms');cell.dataset.level=n?String(Math.max(1,Math.ceil(n/max*4))):'0';cell.title=['Pazartesi','Salı','Çarşamba','Perşembe','Cuma','Cumartesi','Pazar'][day]+' '+String(hour).padStart(2,'0')+':00 · '+n+' yanıt';grid.append(cell);}}host.append(grid);
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
 $('dashboard-canvas').classList.remove('data-refreshed');void $('dashboard-canvas').offsetWidth;$('dashboard-canvas').classList.add('data-refreshed');
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

// Personal layout stores geometry only, never authentication or dashboard data.
const dashboardWidgetDefinitions=[
 ['accept','Kabul edilen doğrulama','#dashboard-accept-card',3,4],
 ['reject','Reddedilen doğrulama','#dashboard-reject-card',3,4],
 ['certificates','Geçerli cihaz sertifikası','#dashboard-cert-card',3,4],
 ['expiring','Yakında dolacak sertifika','#dashboard-expiring-card',3,4],
 ['trend','Kimlik doğrulama trafiği','.dashboard-trend',8,10],
 ['distribution','Erişim dağılımı','.dashboard-distribution',4,10],
 ['nas','Switch / AP hareketliliği','.dashboard-nas',6,9],
 ['density','Haftanın erişim ritmi','.dashboard-density',6,9],
 ['recent','Son erişim denemeleri','.dashboard-recent',8,14],
 ['health','Sistem sağlığı','.dashboard-health',4,14]
];
let dashboardLayout=[],dashboardSavedLayout=[],dashboardLayoutAccount=null,dashboardEditing=false,dashboardGesture=null,dashboardColumns=12,dashboardTiltFrame=0;
const dashboardDefaultLayout=()=>dashboardWidgetDefinitions.map(([id,_title,_selector,cols,rows])=>({id,cols,rows}));
function dashboardLayoutKey(){return 'authwire.dashboard.layout.v1.'+encodeURIComponent(session?.user?.id||'');}
function dashboardReadLayout(value){
 if(!value||value.version!==1||!Array.isArray(value.items)||value.items.length!==dashboardWidgetDefinitions.length)return null;
 const allowed=new Set(dashboardWidgetDefinitions.map(x=>x[0])),seen=new Set();
 for(const row of value.items){if(!row||Object.keys(row).sort().join(',')!=='cols,id,rows'||!allowed.has(row.id)||seen.has(row.id)||!Number.isInteger(row.cols)||row.cols<3||row.cols>12||!Number.isInteger(row.rows)||row.rows<4||row.rows>24)return null;seen.add(row.id);}
 return value.items.map(({id,cols,rows})=>({id,cols,rows}));
}
function dashboardAnnounce(text){$('dashboard-layout-status').textContent=text;}
function dashboardLayoutHydrate(){
 const account=session?.user?.id;if(!account||dashboardLayoutAccount===account)return;
 dashboardLayoutAccount=account;dashboardEditing=false;let layout=null;
 try{const raw=localStorage.getItem(dashboardLayoutKey())||'null';if(raw.length<=8000)layout=dashboardReadLayout(JSON.parse(raw));}catch(_){}
 dashboardSavedLayout=layout||dashboardDefaultLayout();dashboardLayout=structuredClone(dashboardSavedLayout);dashboardApplyLayout();dashboardLayoutControls();
}
function dashboardApplyLayout(){
 const canvas=$('dashboard-canvas');if(!canvas)return;
 for(const item of dashboardLayout){const widget=canvas.querySelector('[data-widget="'+item.id+'"]');if(!widget)continue;widget.style.setProperty('--widget-cols',dashboardColumns===6&&item.cols>3?6:Math.min(item.cols,dashboardColumns));widget.style.setProperty('--widget-rows',item.rows);widget.dataset.size=item.cols;if(canvas.children[dashboardLayout.indexOf(item)]!==widget)canvas.insertBefore(widget,canvas.children[dashboardLayout.indexOf(item)]||null);}
}
function dashboardLayoutControls(){
 const canvas=$('dashboard-canvas');canvas.classList.toggle('is-editing',dashboardEditing);$('dashboard-layout-edit').hidden=dashboardEditing;$('dashboard-layout-edit').setAttribute('aria-pressed',String(dashboardEditing));
 for(const action of ['save','cancel','default'])$('dashboard-layout-'+action).hidden=!dashboardEditing;
 $('dashboard-layout-hint').textContent=dashboardEditing?'Başlıktan sürükleyin; sağ alt köşeden boyutlandırın. Ok tuşlarıyla da düzenleyebilirsiniz.':'Düzeniniz bu tarayıcıda, hesabınız için saklanır.';
 for(const button of canvas.querySelectorAll('.widget-handle,.widget-resize,.widget-step'))button.hidden=!dashboardEditing;
}
function dashboardEditLayout(){if(!session)return;dashboardLayoutHydrate();dashboardEditing=true;dashboardLayoutControls();dashboardAnnounce('Düzenleme açık. Taşıma ve boyutlandırma tutamaçları hazır.');}
function dashboardCancelLayout(){dashboardFinishGesture(false);dashboardLayout=structuredClone(dashboardSavedLayout);dashboardEditing=false;dashboardApplyLayout();dashboardLayoutControls();dashboardAnnounce('Kaydedilmemiş düzen değişiklikleri geri alındı.');}
function dashboardSaveLayout(){
 if(!session)return;dashboardFinishGesture(false);
 try{localStorage.setItem(dashboardLayoutKey(),JSON.stringify({version:1,items:dashboardLayout}));}
 catch(_){dashboardAnnounce('Düzen kaydedilemedi. Tarayıcı depolama ayarlarını kontrol edin.');message('Düzen bu tarayıcıya kaydedilemedi. Değişiklikler ekranda korunuyor.','error');return;}
 dashboardSavedLayout=structuredClone(dashboardLayout);dashboardEditing=false;dashboardLayoutControls();dashboardAnnounce('Dashboard düzeniniz kaydedildi.');message('Dashboard düzeniniz kaydedildi.');
}
function dashboardResetLayoutSession(){
 dashboardFinishGesture(false);dashboardEditing=false;dashboardLayoutAccount=null;dashboardLayout=dashboardDefaultLayout();dashboardSavedLayout=structuredClone(dashboardLayout);dashboardApplyLayout();dashboardLayoutControls();
}
function dashboardMoveWidget(id,offset){
 const index=dashboardLayout.findIndex(x=>x.id===id),next=Math.max(0,Math.min(dashboardLayout.length-1,index+offset));if(index===next)return;
 const [item]=dashboardLayout.splice(index,1);dashboardLayout.splice(next,0,item);dashboardApplyLayout();
 const title=dashboardWidgetDefinitions.find(x=>x[0]===id)[1];dashboardAnnounce(title+' yeni konum: '+(next+1));
}
function dashboardResizeWidget(id,cols,rows){const item=dashboardLayout.find(x=>x.id===id);if(!item)return;item.cols=Math.max(3,Math.min(12,cols));item.rows=Math.max(4,Math.min(24,rows));dashboardApplyLayout();}
function dashboardGestureStart(event,id,type){
 if(!dashboardEditing||event.button!==0)return;event.preventDefault();dashboardFinishGesture(false);
 const canvas=$('dashboard-canvas'),widget=canvas.querySelector('[data-widget="'+id+'"]'),item=dashboardLayout.find(x=>x.id===id);
 dashboardGesture={id,type,pointer:event.pointerId,startX:event.clientX,startY:event.clientY,cols:item.cols,rows:item.rows,before:structuredClone(dashboardLayout),target:null,moved:false,handle:event.currentTarget};
 event.currentTarget.setPointerCapture(event.pointerId);widget.classList.add('widget-engaged');canvas.classList.add('has-gesture');
}
function dashboardGestureMove(event){
 const gesture=dashboardGesture;if(!gesture||event.pointerId!==gesture.pointer)return;event.preventDefault();
 const dx=event.clientX-gesture.startX,dy=event.clientY-gesture.startY;if(!gesture.moved&&Math.hypot(dx,dy)<5)return;gesture.moved=true;
 if(gesture.type==='resize'){
  const unit=($('dashboard-canvas').clientWidth+16)/dashboardColumns;
  dashboardResizeWidget(gesture.id,dashboardColumns===1?gesture.cols:gesture.cols+Math.round(dx/unit),gesture.rows+Math.round(dy/40));
 }else{
  let ghost=$('dashboard-drag-ghost');if(!ghost){ghost=dashText('div',dashboardWidgetDefinitions.find(x=>x[0]===gesture.id)[1],'dashboard-drag-ghost');ghost.id='dashboard-drag-ghost';document.body.append(ghost);}
  ghost.style.left=event.clientX+15+'px';ghost.style.top=event.clientY+12+'px';
  const target=document.elementFromPoint(event.clientX,event.clientY)?.closest('.dashboard-widget');
  for(const row of document.querySelectorAll('.dashboard-drop-target'))row.classList.remove('dashboard-drop-target');
  gesture.target=target&&target.dataset.widget!==gesture.id?target.dataset.widget:null;if(gesture.target)target.classList.add('dashboard-drop-target');
  if(event.clientY<70)window.scrollBy(0,-18);else if(event.clientY>innerHeight-65)window.scrollBy(0,18);
 }
}
function dashboardFinishGesture(commit=true){
 const gesture=dashboardGesture;if(!gesture)return;dashboardGesture=null;
 if(commit&&gesture.type==='move'&&gesture.moved&&gesture.target){
  const from=dashboardLayout.findIndex(x=>x.id===gesture.id),to=dashboardLayout.findIndex(x=>x.id===gesture.target),[item]=dashboardLayout.splice(from,1);dashboardLayout.splice(to,0,item);dashboardApplyLayout();dashboardAnnounce('Kartın yeri değişti. Kalıcı olması için Kaydet seçin.');
 }else if(!commit){dashboardLayout=gesture.before;dashboardApplyLayout();}
 if(gesture.handle.hasPointerCapture?.(gesture.pointer))gesture.handle.releasePointerCapture(gesture.pointer);
 $('dashboard-drag-ghost')?.remove();$('dashboard-canvas')?.classList.remove('has-gesture');document.querySelectorAll('.widget-engaged,.dashboard-drop-target').forEach(x=>x.classList.remove('widget-engaged','dashboard-drop-target'));
}
function dashboardLayoutInit(){
 const canvas=dashText('div','','dashboard-canvas');canvas.id='dashboard-canvas';
 const stats=document.querySelector('.dashboard-stats'),grid=document.querySelector('.dashboard-grid');stats.before(canvas);
 for(const [id,title,selector]of dashboardWidgetDefinitions){
  const content=document.querySelector(selector),widget=dashText('div','','dashboard-widget');widget.dataset.widget=id;
  const controls=dashText('div','','widget-controls'),handle=dashText('button','','widget-handle');handle.type='button';handle.setAttribute('aria-label',title+' kartını taşı');handle.title='Sürükleyin veya ok tuşlarıyla taşıyın';handle.append(dashText('span','⠿'),dashText('span',title));
  handle.addEventListener('pointerdown',e=>dashboardGestureStart(e,id,'move'));handle.addEventListener('keydown',event=>{if(!dashboardEditing)return;const delta={ArrowLeft:-1,ArrowUp:-1,ArrowRight:1,ArrowDown:1,Home:-20,End:20}[event.key];if(delta!==undefined){event.preventDefault();dashboardMoveWidget(id,delta);handle.focus();}});controls.append(handle);
  for(const [label,delta,icon]of [['Önceye taşı',-1,'‹'],['Sonraya taşı',1,'›']]){const b=dashText('button',icon,'widget-step');b.type='button';b.setAttribute('aria-label',title+' '+label.toLocaleLowerCase('tr'));b.title=label;b.addEventListener('click',()=>dashboardMoveWidget(id,delta));controls.append(b);}
  const body=dashText('div','','widget-body');body.append(content);
  const resize=dashText('button','◢','widget-resize');resize.type='button';resize.setAttribute('aria-label',title+' kartını boyutlandır');resize.title='Sürükleyin; ok tuşlarıyla genişlik ve yüksekliği değiştirin';resize.addEventListener('pointerdown',e=>dashboardGestureStart(e,id,'resize'));
  resize.addEventListener('keydown',event=>{if(!dashboardEditing||!['ArrowLeft','ArrowRight','ArrowUp','ArrowDown'].includes(event.key))return;event.preventDefault();const item=dashboardLayout.find(x=>x.id===id);dashboardResizeWidget(id,item.cols+(event.key==='ArrowRight'?1:event.key==='ArrowLeft'?-1:0),item.rows+(event.key==='ArrowDown'?1:event.key==='ArrowUp'?-1:0));dashboardAnnounce(title+' boyutu değişti.');resize.focus();});
  widget.append(controls,body,resize);canvas.append(widget);
 }
 stats.remove();grid.remove();dashboardLayout=dashboardDefaultLayout();dashboardSavedLayout=structuredClone(dashboardLayout);dashboardApplyLayout();dashboardLayoutControls();
 const resize=new ResizeObserver(entries=>{const width=entries[0].contentRect.width,next=width<570?1:width<970?6:12;if(next!==dashboardColumns){dashboardColumns=next;canvas.style.setProperty('--canvas-cols',next);canvas.dataset.columns=next;dashboardApplyLayout();}});resize.observe(canvas);
 canvas.addEventListener('pointermove',event=>{
  if(dashboardGesture){dashboardGestureMove(event);return;}if(dashboardEditing||matchMedia('(prefers-reduced-motion:reduce)').matches||event.pointerType==='touch')return;
  const widget=event.target.closest('.dashboard-widget');if(!widget||dashboardTiltFrame)return;
  dashboardTiltFrame=requestAnimationFrame(()=>{dashboardTiltFrame=0;const rect=widget.getBoundingClientRect(),x=Math.max(0,Math.min(1,(event.clientX-rect.left)/rect.width)),y=Math.max(0,Math.min(1,(event.clientY-rect.top)/rect.height));widget.style.setProperty('--tilt-x',(0.5-y)*2+'deg');widget.style.setProperty('--tilt-y',(x-0.5)*2+'deg');widget.style.setProperty('--glow-x',x*100+'%');widget.style.setProperty('--glow-y',y*100+'%');});
 });
 canvas.addEventListener('pointerout',event=>{const widget=event.target.closest('.dashboard-widget');if(widget&&!widget.contains(event.relatedTarget)){widget.style.setProperty('--tilt-x','0deg');widget.style.setProperty('--tilt-y','0deg');}});
 canvas.addEventListener('pointerup',()=>dashboardFinishGesture(true));canvas.addEventListener('pointercancel',()=>dashboardFinishGesture(false));canvas.addEventListener('lostpointercapture',()=>{if(dashboardGesture)dashboardFinishGesture(false);});
 document.addEventListener('keydown',event=>{if(event.key==='Escape'&&dashboardGesture){event.preventDefault();dashboardFinishGesture(false);}});
 $('dashboard-layout-edit').addEventListener('click',dashboardEditLayout);$('dashboard-layout-cancel').addEventListener('click',dashboardCancelLayout);$('dashboard-layout-save').addEventListener('click',dashboardSaveLayout);
 $('dashboard-layout-default').addEventListener('click',()=>{dashboardFinishGesture(false);dashboardLayout=dashboardDefaultLayout();dashboardApplyLayout();dashboardAnnounce('Varsayılan düzen hazır. Uygulamak için Kaydet seçin.');});
 document.addEventListener('visibilitychange',()=>{if(document.hidden)dashboardFinishGesture(false);});
}
dashboardLayoutInit();
