'use strict';
const fs=require('node:fs'),os=require('node:os'),path=require('node:path'),assert=require('node:assert/strict');
const {spawn,spawnSync}=require('node:child_process');
const {chromium}=require(process.env.CODEX_PRIMARY_RUNTIME_NODE_MODULES?path.join(process.env.CODEX_PRIMARY_RUNTIME_NODE_MODULES,'playwright'):'playwright');
(async()=>{
 const root=path.resolve(__dirname,'..'),temp=fs.mkdtempSync(path.join(os.tmpdir(),'authwire-audit-ui-')),python=process.env.CODEX_PRIMARY_RUNTIME_PYTHON||process.env.KANAME_PYTHON||'python3';
 const script=`import sys,json
from kaname.server import DevelopmentServer
s=DevelopmentServer(sys.argv[1],0)
with s.store.connect() as db:
 db.executemany("INSERT INTO audit(event,revision,at) VALUES (?,7,?)", [('config_saved','2026-10-18T10:00:00.000Z')]*233)
 db.execute("INSERT INTO audit(event,revision,at) VALUES (?,7,?)", ('service_action_requested:'+json.dumps(dict(actor='=SUM(1,2)',service='radius',action='restart',request_id='fixture-request',password='never-export-this')), '2026-10-17T21:00:00.000Z'))
 db.execute("INSERT INTO audit(event,revision,at) VALUES (?,7,?)", ('pki_certificate_revoked:deadbeef:actor:operator', '2026-10-17T20:59:59.999Z'))
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
  async function apply(){await page.locator('#audit-apply').click();await page.waitForFunction(()=>!auditLoading&&auditPage&&auditLoadedKey===auditKey());}
  await login(page);await page.locator('[data-view="audit"]').click();await page.waitForFunction(()=>auditPage?.events.length===100);
  assert.equal(await page.evaluate(()=>auditPage.events[0].id),235);assert.match(await page.locator('#audit-storage').textContent(),/235 kayıt/);
  const firstIds=await page.evaluate(()=>auditPage.events.map(e=>e.id));
  const add=spawnSync(python,['-c','import sqlite3,sys;db=sqlite3.connect(sys.argv[1]);db.execute("INSERT INTO audit(event,revision) VALUES (\'config_saved\',8)");db.commit();db.close()',path.join(temp,'kaname.sqlite3')],{encoding:'utf8'});assert.equal(add.status,0,add.stderr);
  await page.locator('#audit-next').click();await page.waitForFunction(()=>!auditLoading&&auditPage?.events[0]?.id===135);const secondIds=await page.evaluate(()=>auditPage.events.map(e=>e.id));
  await page.locator('#audit-next').click();await page.waitForFunction(()=>!auditLoading&&auditPage?.events[0]?.id===35);const thirdIds=await page.evaluate(()=>auditPage.events.map(e=>e.id));
  assert.deepEqual([...firstIds,...secondIds,...thirdIds],Array.from({length:235},(_,i)=>235-i));assert.equal(await page.locator('#audit-next').isDisabled(),true);
  await page.locator('#audit-from').fill('2026-10-18');await page.locator('#audit-to').fill('2026-10-18');await page.locator('#audit-query').fill('fixture-request');await apply();
  assert.equal(await page.evaluate(()=>auditPage.events.length),1);assert.equal(await page.evaluate(()=>auditPage.events[0].id),234);
  const downloadEvent=page.waitForEvent('download');await page.locator('#audit-export').click();const download=await downloadEvent,csv=fs.readFileSync(await download.path(),'utf8');
  assert.ok(csv.startsWith('\uFEFF'));assert.match(csv,/'=SUM\(1,2\)/);assert.match(csv,/service_action_requested/);assert.doesNotMatch(csv,/never-export-this|PRIVATE KEY/);assert.equal(csv.trim().split('\r\n').length,2);
  await page.locator('#audit-query').fill('deadbeef');assert.equal(await page.locator('#audit-export').isDisabled(),true);await apply();assert.match(await page.locator('#audit-list').textContent(),/kayıt bulunamadı/);
  await page.locator('#audit-reset').click();await page.waitForFunction(()=>!auditLoading&&auditPage?.events[0]?.id===236);
  await page.locator('#audit-source').selectOption('administrators');await apply();assert.ok(await page.locator('#audit-list').textContent().then(t=>t.includes('admin_login')));
  await page.locator('#audit-source').selectOption('application');await apply();
  // Actual API profile/account boundaries; no customer directory or service calls.
  await page.evaluate(async()=>{let s=await api('/api/system');await api('/api/system/profiles/save',{expected_revision:s.revision,profile:{id:'',name:'Audit reader',mode:'Custom',grants:{'audit.events':'read'}}});s=await api('/api/system');const id=s.profiles.find(p=>p.name==='Audit reader').id;await api('/api/system/users/save',{expected_revision:s.revision,user:{id:'',username:'audit-reader',profile_id:id,password:'fixture-audit-password-42',enabled:true}});});
  const reader=await context.newPage();await login(reader,'audit-reader','fixture-audit-password-42');await reader.locator('[data-view="audit"]').click();await reader.waitForFunction(()=>auditPage?.events.length>0);
  assert.equal(await reader.locator('#audit-source option[value="administrators"]').isDisabled(),true);
  assert.equal(await reader.evaluate(async()=>{const r=await fetch('/api/audit/history?source=administrators');return r.status;}),403);
  assert.equal(await reader.locator('#audit-export').isEnabled(),true);
  // Local list failure preserves the authenticated workspace and existing data.
  await page.route('**/api/audit/history*',r=>r.fulfill({status:503,json:{error:'AUDIT_QUERY_LIMIT'}}));await page.locator('#audit-apply').click();await page.waitForFunction(()=>!auditLoading&&document.getElementById('audit-feedback').textContent.includes('daraltın'));
  assert.equal(await page.locator('#workspace').isVisible(),true);await page.unroute('**/api/audit/history*');
  // Response from the old login cannot restore cached records or permit export.
  let release,seen;const gate=new Promise(r=>release=r),started=new Promise(r=>seen=r);
  await page.route('**/api/audit/history*',async r=>{seen();await gate;await r.continue();});
  await page.locator('#audit-apply').click();await started;await page.locator('#logout').click();release();await page.unroute('**/api/audit/history*');
  await page.locator('#login-form').waitFor({state:'visible'});assert.equal(await page.evaluate(()=>auditPage),null);assert.equal(await page.locator('#audit-export').isDisabled(),true);
  await login(page);await page.locator('[data-view="audit"]').click();await page.waitForFunction(()=>!!auditPage&&!auditLoading);
  if(process.env.KANAME_UI_ARTIFACTS){fs.mkdirSync(process.env.KANAME_UI_ARTIFACTS,{recursive:true});await page.screenshot({path:path.join(process.env.KANAME_UI_ARTIFACTS,'audit-desktop.png'),fullPage:true});}
  for(const width of [390,1366,1920]){await page.setViewportSize({width,height:1000});assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1),true,'page overflow '+width);}
  assert.deepEqual(errors,[]);assert.equal(serviceActions,0);
  console.log('AUTHWIRE_AUDIT_UI_OK '+JSON.stringify({pagination_with_new_writes:true,local_date_edges:true,page_csv_formula_safe:true,admin_source_permission_enforced:true,read_failure_keeps_session:true,logout_discards_pending_response:true,service_actions:serviceActions}));
 }finally{if(browser)await browser.close();child.kill();await new Promise(r=>child.once('exit',r));fs.rmSync(temp,{recursive:true,force:true});}
})().catch(e=>{console.error(e);process.exitCode=1;});
