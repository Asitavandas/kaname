'use strict';
// Actual panel/API in a temporary directory. No customer AD, PKI or service action.
const fs=require('node:fs'),os=require('node:os'),path=require('node:path'),assert=require('node:assert/strict');
const {spawn,spawnSync}=require('node:child_process');
const {chromium}=require(process.env.CODEX_PRIMARY_RUNTIME_NODE_MODULES?path.join(process.env.CODEX_PRIMARY_RUNTIME_NODE_MODULES,'playwright'):'playwright');
(async()=>{
 const root=path.resolve(__dirname,'..'),temp=fs.mkdtempSync(path.join(os.tmpdir(),'authwire-setup-ui-'));
 const python=process.env.CODEX_PRIMARY_RUNTIME_PYTHON||process.env.KANAME_PYTHON||'python3';
 const child=spawn(python,['-u','-c','import sys;from kaname.server import DevelopmentServer;s=DevelopmentServer(sys.argv[1],0);print(s.server_port,flush=True);s.serve_forever()',temp],{cwd:root,stdio:['ignore','pipe','pipe']});
 let browser;
 try{
  const port=await new Promise((resolve,reject)=>{const timer=setTimeout(()=>reject(Error('Fixture start timeout')),10000);child.once('error',reject);child.once('exit',c=>reject(Error('Fixture exited '+c)));child.stdout.once('data',d=>{clearTimeout(timer);resolve(Number(d.toString().trim()));});});
  child.stderr.on('data',d=>process.stderr.write(d));
  browser=await chromium.launch({headless:true,...(process.env.KANAME_CHROMIUM?{executablePath:process.env.KANAME_CHROMIUM}:{})});
  const page=await browser.newPage({viewport:{width:1440,height:1000}}),errors=[],posts=[],cases=[];
  page.on('pageerror',e=>errors.push(e.message));
  let health='running',available=true,serviceActions=0;
  await page.route('**/api/services',r=>r.fulfill(available?{json:{available:true,checked_at:new Date().toISOString(),services:[{id:'radius',health,listener_present:health==='running'}],operations:[],busy:false}}:{status:503,json:{error:'SERVICE_CONTROL_UNAVAILABLE'}}));
  page.on('request',r=>{if(new URL(r.url()).pathname==='/api/config'&&r.method()==='POST')posts.push(r.postDataJSON());if(new URL(r.url()).pathname==='/api/services/action')serviceActions++;});
  async function login(p,name='admin',password='Kaname'){
   await p.goto('http://127.0.0.1:'+port);await p.locator('#login-user').fill(name);await p.locator('#login-password').fill(password);await p.locator('#unlock').click();await p.locator('#workspace').waitFor({state:'visible'});
  }
  async function editFqdn(value){await page.locator('[data-view="setup"]').click();await page.locator('[data-step="0"]').click();await page.locator('#fqdn').fill(value);await page.locator('[data-step="3"]').click();}
  async function reload(){page.once('dialog',d=>d.accept());await page.locator('#setup-reload').click();await page.waitForFunction(()=>!setupAwaitingRead&&setupBaseRevision===state.revision&&!setupHasEdits());}
  function protectedSecrets(){
   const result=spawnSync(python,['-I','-B','-c','import sqlite3,hashlib,sys;db=sqlite3.connect(sys.argv[1]+"?mode=ro",uri=True);print(hashlib.sha256(repr(db.execute("SELECT name,ciphertext FROM protected_secrets ORDER BY name").fetchall()).encode()).hexdigest());db.close()',new URL('file://'+path.join(temp,'kaname.sqlite3')).href],{encoding:'utf8'});
   assert.equal(result.status,0,result.stderr);return result.stdout.trim();
  }
  await login(page);
  await page.waitForFunction(()=>document.getElementById('overview-radius-health').textContent==='Çalışıyor');
  assert.equal(await page.locator('.notice').textContent().then(t=>t.includes('henüz uygulanmıyor')),false);
  health='listener-missing';await page.locator('#overview-radius-refresh').click();await page.waitForFunction(()=>document.getElementById('overview-radius-health').dataset.status==='error');
  available=false;await page.locator('#overview-radius-refresh').click();await page.waitForFunction(()=>document.getElementById('overview-radius-health').textContent==='Bilgi alınamadı');
  assert.equal(await page.locator('#workspace').isVisible(),true);available=true;health='running';cases.push('service-summary-is-read-only-and-outage-does-not-lock-panel');

  await page.locator('[data-view="setup"]').click();await page.locator('#fqdn').fill('authwire.lab.example');
  await page.locator('[data-step="1"]').click();await page.locator('#domain').fill('lab.example');await page.locator('#dc').fill('192.0.2.10');
  await page.locator('[data-step="2"]').click();await page.locator('#clients').fill('broken row');
  await page.locator('[data-step="3"]').click();assert.equal(await page.locator('#save').isDisabled(),true);assert.equal(posts.length,0);
  assert.match(await page.locator('#setup-feedback').textContent(),/ad,IP/);
  await page.locator('[data-step="2"]').click();await page.locator('#clients').fill('SW-FIX,192.0.2.20\nAP-FIX,192.0.2.21');await page.locator('[data-step="3"]').click();
  assert.equal(posts.length,0);assert.match(await page.locator('#setup-changes').textContent(),/authwire.lab.example/);
  await page.locator('#save').click();await page.waitForFunction(()=>!setupSaving&&setupBaseRevision===1);
  assert.equal(posts.length,1);assert.equal(await page.locator('#save').isDisabled(),true);cases.push('initial-review-does-not-write-invalid-input-is-contained');

  await page.evaluate(async()=>{await api('/api/network/radius',{expected_revision:state.revision,radius_clients:[{name:'SW-FIX',ip:'192.0.2.20',access_type:'wired',secret:'fixture-wired-secret-1234'},{name:'AP-FIX',ip:'192.0.2.21',access_type:'wireless',secret:'fixture-wireless-secret-1234'}],authentication_port:1812,accounting_port:1813});await refresh();});
  const secretsBefore=protectedSecrets();
  const networkBefore=await page.evaluate(async()=>{const n=await api('/api/network');delete n.revision;return n;});
  await page.locator('[data-step="2"]').click();assert.equal(await page.locator('#clients').isEditable(),false);
  await editFqdn('authwire-new.lab.example');assert.equal(await page.locator('#save').isDisabled(),true);
  await page.locator('#setup-ack').check();assert.equal(await page.locator('#save').isDisabled(),false);
  let release,seen;const gate=new Promise(r=>release=r),started=new Promise(r=>seen=r);
  await page.route('**/api/config',async r=>{seen();await gate;await r.continue();});
  await page.evaluate(()=>{void run(saveSetup);void run(saveSetup);});await started;
  assert.equal(posts.length,2);assert.deepEqual(Object.keys(posts.at(-1).patch),['appliance_fqdn']);assert.equal(await page.locator('#save').isDisabled(),true);
  release();await page.waitForFunction(()=>!setupSaving&&setupBase?.appliance_fqdn==='authwire-new.lab.example');await page.unroute('**/api/config');
  assert.equal(protectedSecrets(),secretsBefore);
  const networkAfter=await page.evaluate(async()=>{const n=await api('/api/network');delete n.revision;return n;});assert.deepEqual(networkAfter,networkBefore);
  cases.push('review-ack-single-write-preserves-radius-types-and-sealed-secrets');

  await editFqdn('pending.lab.example');
  await page.evaluate(async()=>{await api('/api/config',{expected_revision:state.revision,patch:{dc_ips:['192.0.2.11']}});await pollState();});
  assert.match(await page.locator('#setup-feedback').textContent(),/başka bir kayıt/);assert.equal(await page.locator('#save').isDisabled(),true);
  assert.equal(await page.locator('#fqdn').inputValue(),'pending.lab.example');const noStalePost=posts.length;
  await page.evaluate(()=>run(saveSetup));assert.equal(posts.length,noStalePost);await reload();assert.equal(await page.locator('#dc').inputValue(),'192.0.2.11');
  cases.push('background-poll-does-not-rebase-and-overwrite-dirty-form');

  await editFqdn('late-conflict.lab.example');await page.locator('#setup-ack').check();
  await page.evaluate(()=>api('/api/config',{expected_revision:state.revision,patch:{dc_ips:['192.0.2.12']}}));
  const beforeConflict=posts.length;await page.locator('#save').click();
  await page.waitForFunction(()=>!setupSaving&&state.revision!==setupBaseRevision);
  assert.equal(posts.length,beforeConflict+1);assert.equal(await page.locator('#fqdn').inputValue(),'late-conflict.lab.example');await reload();
  cases.push('server-revision-conflict-preserves-edits-without-replay');

  await editFqdn('committed.lab.example');await page.locator('#setup-ack').check();
  let failRead=true;
  await page.route('**/api/state',r=>failRead?(failRead=false,r.fulfill({status:503,json:{error:'STORE_UNAVAILABLE'}})):r.continue());
  const beforeReadFailure=posts.length;await page.locator('#save').click();await page.waitForFunction(()=>!setupSaving&&setupAwaitingRead);
  assert.match(await page.locator('#message').textContent(),/Ayarlar kaydedildi/);
  await page.evaluate(()=>run(saveSetup));assert.equal(posts.length,beforeReadFailure+1);await reload();await page.unroute('**/api/state');
  assert.equal(await page.locator('#fqdn').inputValue(),'committed.lab.example');cases.push('committed-write-read-failure-reconciles-without-resubmit');

  await editFqdn('unknown-outcome.lab.example');await page.locator('#setup-ack').check();
  await page.route('**/api/config',r=>r.abort('failed'));const beforeAbort=posts.length;
  await page.locator('#save').click();await page.waitForFunction(()=>!setupSaving&&setupAwaitingRead);
  await page.evaluate(()=>run(saveSetup));assert.equal(posts.length,beforeAbort+1);await page.unroute('**/api/config');await reload();
  cases.push('unknown-post-outcome-requires-read-before-new-save');

  // Narrow real account: setup product read only, no service status or AD scope.
  await page.evaluate(async()=>{
   let s=await api('/api/system');await api('/api/system/profiles/save',{expected_revision:s.revision,profile:{id:'',name:'Setup reader fixture',mode:'Custom',grants:{'setup.product':'read'}}});
   s=await api('/api/system');const id=s.profiles.find(x=>x.name==='Setup reader fixture').id;
   await api('/api/system/users/save',{expected_revision:s.revision,user:{id:'',username:'setup-reader',profile_id:id,password:'fixture-reader-password-42',enabled:true}});
  });
  const context=await browser.newContext(),reader=await context.newPage();reader.on('pageerror',e=>errors.push(e.message));let forbiddenReads=0;
  reader.on('request',r=>{if(new URL(r.url()).pathname==='/api/services')forbiddenReads++;});
  await login(reader,'setup-reader','fixture-reader-password-42');await reader.locator('[data-view="setup"]').click();await reader.locator('[data-step="3"]').click();
  assert.equal(await reader.locator('#save').isVisible(),false);assert.equal(await reader.locator('#fqdn').isDisabled(),true);
  assert.equal(await reader.locator('#review').textContent().then(t=>t.includes('ad_domain')),false);
  assert.equal(await reader.locator('#overview-radius-row').isVisible(),false);assert.equal(forbiddenReads,0);
  await context.close();cases.push('narrow-read-only-account-keeps-field-and-service-boundaries');

  await page.locator('[data-view="setup"]').click();await page.locator('[data-step="3"]').click();
  if(process.env.KANAME_UI_ARTIFACTS){fs.mkdirSync(process.env.KANAME_UI_ARTIFACTS,{recursive:true});await page.screenshot({path:path.join(process.env.KANAME_UI_ARTIFACTS,'setup-review.png'),fullPage:true});}
  for(const width of [390,1366,1920]){await page.setViewportSize({width,height:900});assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=window.innerWidth),true,'Setup fits '+width);}
  assert.equal(protectedSecrets(),secretsBefore);assert.equal(serviceActions,0);assert.deepEqual(errors,[]);
  console.log('AUTHWIRE_SETUP_UI_OK '+JSON.stringify({cases,service_actions:0,protected_radius_secrets_preserved:true}));
 }finally{if(browser)await browser.close();child.kill();fs.rmSync(temp,{recursive:true,force:true});}
})().catch(error=>{console.error(error);process.exitCode=1;});
