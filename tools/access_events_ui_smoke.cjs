'use strict';
const fs=require('node:fs'),os=require('node:os'),path=require('node:path'),assert=require('node:assert/strict');
const {spawn}=require('node:child_process');
const {chromium}=require(process.env.CODEX_PRIMARY_RUNTIME_NODE_MODULES?path.join(process.env.CODEX_PRIMARY_RUNTIME_NODE_MODULES,'playwright'):'playwright');
(async()=>{
 const root=path.resolve(__dirname,'..'),temp=fs.mkdtempSync(path.join(os.tmpdir(),'authwire-access-ui-')),python=process.env.CODEX_PRIMARY_RUNTIME_PYTHON||process.env.KANAME_PYTHON||'python3';
 const script=`import sys
from kaname.server import DevelopmentServer
from kaname.radius_events import initialize,append
from tests.test_radius_events import event
s=DevelopmentServer(sys.argv[1],0)
initialize(s.store.root)
for n in range(205):
 change=dict(policy_id='-fixture') if n%2==0 else dict(response_code=3,reason='TLS_CERTIFICATE_REVOKED',reason_source='native_category',policy_id=None,vlan=None,tls_verified=False,certificate_serial=None,object_guid=None,identity_kind=None)
 append(s.store.root,event(n,**change))
print(s.server_port,flush=True)
s.serve_forever()`;
 const child=spawn(python,['-u','-c',script,temp],{cwd:root,stdio:['ignore','pipe','pipe']});let browser;
 try{
  const port=await new Promise((resolve,reject)=>{const timer=setTimeout(()=>reject(Error('Fixture start timeout')),10000);child.once('error',reject);child.once('exit',c=>reject(Error('Fixture exited '+c)));child.stdout.once('data',d=>{clearTimeout(timer);resolve(Number(d.toString().trim()));});});
  child.stderr.on('data',d=>process.stderr.write(d));
  browser=await chromium.launch({headless:true,...(process.env.KANAME_CHROMIUM?{executablePath:process.env.KANAME_CHROMIUM}:{})});
  const context=await browser.newContext({viewport:{width:1440,height:1050},timezoneId:'Europe/Istanbul',acceptDownloads:true}),page=await context.newPage(),errors=[];let serviceActions=0;
  page.on('pageerror',e=>errors.push(e.message));page.on('request',r=>{if(new URL(r.url()).pathname==='/api/services/action')serviceActions++;});
  async function login(p,name='admin',password='Kaname'){await p.goto('http://127.0.0.1:'+port);await p.locator('#login-user').fill(name);await p.locator('#login-password').fill(password);await p.locator('#unlock').click();await p.locator('#workspace').waitFor({state:'visible'});}
  async function apply(){await page.locator('#access-apply').click();await page.waitForFunction(()=>!accessLoading&&accessPage&&accessLoadedKey===accessKey());}
  await login(page);await page.locator('[data-view="access-events"]').click();await page.waitForFunction(()=>accessPage?.events.length===100);
  const ids=await page.evaluate(()=>accessPage.events.map(e=>e.id));assert.equal(ids[0],205);
  await page.locator('#access-next').click();await page.waitForFunction(()=>!accessLoading&&accessPage?.events[0]?.id===105);ids.push(...await page.evaluate(()=>accessPage.events.map(e=>e.id)));
  await page.locator('#access-next').click();await page.waitForFunction(()=>!accessLoading&&accessPage?.events[0]?.id===5);ids.push(...await page.evaluate(()=>accessPage.events.map(e=>e.id)));
  assert.deepEqual(ids,Array.from({length:205},(_,i)=>205-i));assert.equal(await page.locator('#access-next').isDisabled(),true);
  await page.locator('#access-result').selectOption('reject');await page.locator('#access-nas').fill('192.0.2.2');await page.locator('#access-reason').fill('TLS_CERTIFICATE_REVOKED');await apply();
  assert.ok(await page.evaluate(()=>accessPage.events.every(e=>e.response_code===3&&!e.tls_verified&&e.vlan===null&&e.object_guid===null)));
  assert.match(await page.locator('#access-list').textContent(),/Kimlik doğrulanmadı/);assert.match(await page.locator('#access-list').textContent(),/İptal edilmiş/);
  await page.locator('#access-reset').click();await page.waitForFunction(()=>!accessLoading&&accessPage?.events[0]?.id===205);
  await page.locator('#access-result').selectOption('accept');await page.locator('#access-from').fill('2026-10-18');await page.locator('#access-to').fill('2026-10-18');await apply();
  assert.ok(await page.evaluate(()=>accessPage.events.every(e=>e.response_code===2&&e.vlan===110)));
  const downloadEvent=page.waitForEvent('download');await page.locator('#access-export').click();const download=await downloadEvent,csv=fs.readFileSync(await download.path(),'utf8');
  assert.ok(csv.startsWith('\uFEFF'));assert.match(csv,/'-fixture/);assert.match(csv,/POLICY_ALLOW/);assert.doesNotMatch(csv,/User-Name|PRIVATE KEY|password|privileged-admin/);assert.equal(csv.trim().split('\r\n').length,101);
  await page.locator('#access-query').fill('changed');assert.equal(await page.locator('#access-export').isDisabled(),true);await apply();assert.match(await page.locator('#access-list').textContent(),/kayıt bulunamadı/);
  await page.locator('#access-reset').click();await page.waitForFunction(()=>!accessLoading&&accessPage?.events.length===100);
  await page.evaluate(async()=>{let s=await api('/api/system');await api('/api/system/profiles/save',{expected_revision:s.revision,profile:{id:'',name:'No access history',mode:'Custom',grants:{'policies.rules':'read'}}});s=await api('/api/system');const id=s.profiles.find(p=>p.name==='No access history').id;await api('/api/system/users/save',{expected_revision:s.revision,user:{id:'',username:'no-history',profile_id:id,password:'fixture-history-password-42',enabled:true}});});
  const deniedContext=await browser.newContext(),denied=await deniedContext.newPage();await login(denied,'no-history','fixture-history-password-42');
  assert.equal(await denied.locator('[data-view="access-events"]').isVisible(),false);
  assert.equal(await denied.evaluate(async()=>{const r=await fetch('/api/radius/events');return r.status;}),403);
  await page.route('**/api/radius/events*',r=>r.fulfill({status:503,json:{error:'ACCESS_HISTORY_UNAVAILABLE'}}));
  await page.locator('#access-apply').click();await page.waitForFunction(()=>!accessLoading&&document.getElementById('access-feedback').textContent.includes('alınamadı'));
  assert.equal(await page.locator('#workspace').isVisible(),true);assert.equal(await page.locator('#access-list tr').count(),100);await page.unroute('**/api/radius/events*');
  let release,seen,handled;const gate=new Promise(r=>release=r),started=new Promise(r=>seen=r),routeDone=new Promise(r=>handled=r);
  await page.route('**/api/radius/events*',async r=>{seen();await gate;await r.continue();handled();});await page.evaluate(()=>{window.accessPendingFixture=run(()=>loadAccessEvents());});await started;
  await page.locator('#logout').click();release();await routeDone;await page.evaluate(()=>window.accessPendingFixture);await page.unroute('**/api/radius/events*');
  assert.equal(await page.evaluate(()=>accessPage),null);assert.equal(await page.locator('#access-export').isDisabled(),true);
  await login(page);await page.locator('[data-view="access-events"]').click();await page.waitForFunction(()=>!!accessPage&&!accessLoading);
  if(process.env.KANAME_UI_ARTIFACTS){fs.mkdirSync(process.env.KANAME_UI_ARTIFACTS,{recursive:true});await page.screenshot({path:path.join(process.env.KANAME_UI_ARTIFACTS,'access-events-desktop.png'),fullPage:true});}
  for(const width of [390,1366,1920]){await page.setViewportSize({width,height:1000});assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1),true,'page overflow '+width);}
  assert.deepEqual(errors,[]);assert.equal(serviceActions,0);
  console.log('AUTHWIRE_ACCESS_EVENTS_UI_OK '+JSON.stringify({pagination:true,accept_reject_filters:true,unverified_identity_unknown:true,page_csv_formula_safe:true,permission_enforced:true,read_failure_keeps_session:true,logout_discards_pending_response:true,service_actions:serviceActions}));
 }finally{if(browser)await browser.close();child.kill();await new Promise(r=>child.once('exit',r));fs.rmSync(temp,{recursive:true,force:true});}
})().catch(e=>{console.error(e);process.exitCode=1;});
