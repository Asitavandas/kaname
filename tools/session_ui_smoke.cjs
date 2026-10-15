'use strict';
// Fault injection against a disposable panel; never logs real credentials or cookies.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {spawn} = require('node:child_process');
const {chromium} = require(process.env.CODEX_PRIMARY_RUNTIME_NODE_MODULES ? path.join(process.env.CODEX_PRIMARY_RUNTIME_NODE_MODULES,'playwright') : 'playwright');

(async()=>{
  const root=path.resolve(__dirname,'..');
  const temp=fs.mkdtempSync(path.join(os.tmpdir(),'authwire-session-ui-'));
  const python=process.env.CODEX_PRIMARY_RUNTIME_PYTHON||process.env.KANAME_PYTHON||'python3';
  const child=spawn(python,['-u','-c','import sys; from kaname.server import DevelopmentServer; s=DevelopmentServer(sys.argv[1],0); print(s.server_port,flush=True); s.serve_forever()',temp],{cwd:root,stdio:['ignore','pipe','pipe']});
  let browser;
  const cases=[];
  try{
    const port=await new Promise((resolve,reject)=>{
      const timer=setTimeout(()=>reject(new Error('Fixture startup timed out')),10000);
      child.once('error',error=>{clearTimeout(timer);reject(error);});
      child.once('exit',code=>{clearTimeout(timer);reject(new Error('Fixture exited '+code));});
      child.stdout.once('data',data=>{clearTimeout(timer);resolve(Number(data.toString().trim()));});
    });
    browser=await chromium.launch({headless:true,...(process.env.KANAME_CHROMIUM?{executablePath:process.env.KANAME_CHROMIUM}:{})});
    async function fresh(){
      const context=await browser.newContext();const page=await context.newPage();
      const errors=[];page.on('pageerror',error=>errors.push(error.message));
      await page.goto(`http://127.0.0.1:${port}`);
      await page.locator('#unlock').waitFor({state:'visible'});
      await page.waitForFunction(()=>!document.getElementById('unlock').disabled);
      return {context,page,errors};
    }
    async function login(page){
      await page.locator('#login-user').fill('admin');await page.locator('#login-password').fill('Kaname');
      await page.locator('#unlock').click();
    }
    async function passed(name,fixture){
      assert.deepEqual(fixture.errors,[],name+' must not throw a browser error');
      cases.push(name);await fixture.context.close();
    }

    // The HTML itself conceals credentials while an existing cookie is checked.
    {
      const f=await fresh();await login(f.page);await f.page.locator('#workspace').waitFor({state:'visible'});
      let release,started;
      const gate=new Promise(resolve=>release=resolve),seen=new Promise(resolve=>started=resolve);
      await f.page.route('**/api/auth/session',async route=>{started();await gate;await route.continue();});
      await f.page.reload({waitUntil:'domcontentloaded'});await seen;
      assert.equal(await f.page.locator('#login-form').isVisible(),false);
      assert.equal(await f.page.locator('#panel-loading').isVisible(),true);
      assert.equal(await f.page.locator('#workspace').isVisible(),false);
      release();await f.page.locator('#workspace').waitFor({state:'visible'});
      assert.equal(await f.page.locator('#login').isVisible(),false);
      await passed('reload-hides-credentials-until-session-check-completes',f);
    }
    // Only positively classified SQLite contention is retried, with a fixed bound.
    {
      const f=await fresh();await login(f.page);await f.page.locator('#workspace').waitFor({state:'visible'});
      let reads=0;
      await f.page.route('**/api/fixture-busy',route=>{reads++;return route.fulfill(reads<3?{status:503,json:{error:'STORE_BUSY'}}:{status:200,json:{recovered:true}});});
      assert.equal(await f.page.evaluate(()=>api('/api/fixture-busy').then(v=>v.recovered)),true);
      assert.equal(reads,3);
      let persistent=0;
      await f.page.route('**/api/fixture-busy-persistent',route=>{persistent++;return route.fulfill({status:503,json:{error:'STORE_BUSY'}});});
      assert.equal(await f.page.evaluate(()=>api('/api/fixture-busy-persistent').then(()=>null,e=>e.code)),'STORE_BUSY');
      assert.equal(persistent,3);assert.equal(await f.page.locator('#workspace').isVisible(),true);
      let writes=0;
      await f.page.route('**/api/fixture-busy-write',route=>{writes++;return route.fulfill({status:503,json:{error:'STORE_BUSY'}});});
      assert.equal(await f.page.evaluate(()=>api('/api/fixture-busy-write',{value:1}).then(()=>null,e=>e.code)),'STORE_BUSY');
      assert.equal(writes,1);
      await passed('sqlite-busy-reads-bounded-recovery-writes-never-replayed',f);
    }
    // A successful password check followed by one failed state read must be recoverable.
    {
      const f=await fresh();let reads=0,logins=0;
      f.page.on('request',r=>{if(new URL(r.url()).pathname==='/api/auth/login')logins++;});
      await f.page.route('**/api/state',route=>++reads===1?route.fulfill({status:503,json:{error:'STORE_UNAVAILABLE'}}):route.continue());
      await login(f.page);await f.page.locator('#panel-recovery').waitFor({state:'visible'});
      assert.equal(logins,1);assert.equal(reads,1);
      assert.equal(await f.page.locator('#login-form').isVisible(),false);
      assert.match(await f.page.locator('#panel-recovery-message').textContent(),/Girişiniz doğrulandı/);
      await f.page.locator('#panel-retry').click();await f.page.locator('#workspace').waitFor({state:'visible'});
      assert.equal(logins,1,'recovery must reuse the valid session');
      await passed('login-state-failure-recovers-without-second-password',f);
    }
    // F5 with a valid session and a transient data error must not demand credentials.
    {
      const f=await fresh();await login(f.page);await f.page.locator('#workspace').waitFor({state:'visible'});
      let failed=false;
      await f.page.route('**/api/state',route=>{if(!failed){failed=true;return route.fulfill({status:503,json:{error:'STORE_UNAVAILABLE'}});}return route.continue();});
      await f.page.reload();await f.page.locator('#panel-recovery').waitFor({state:'visible'});
      await f.page.locator('#panel-retry').click();await f.page.locator('#workspace').waitFor({state:'visible'});
      await passed('reload-retains-valid-session-after-transient-error',f);
    }
    // Optional audit/group outages must not block the workspace after valid login.
    {
      const f=await fresh();
      await f.page.route('**/api/audit',route=>route.fulfill({status:503,json:{error:'STORE_UNAVAILABLE'}}));
      await f.page.route('**/api/policies/groups?*',route=>route.fulfill({status:503,json:{error:'STORE_UNAVAILABLE'}}));
      await login(f.page);await f.page.locator('#workspace').waitFor({state:'visible'});
      await f.page.waitForFunction(()=>document.getElementById('message').textContent.length>0);
      assert.equal(await f.page.locator('#login').isVisible(),false);
      assert.equal(await f.page.locator('#panel-recovery').isVisible(),false);
      await passed('optional-list-outage-does-not-log-out',f);
    }
    // Repeated submit events while login is pending produce exactly one password POST.
    {
      const f=await fresh();let posts=0,release;
      const gate=new Promise(resolve=>release=resolve);
      await f.page.route('**/api/auth/login',async route=>{posts++;await gate;await route.continue();});
      await f.page.locator('#login-user').fill('admin');await f.page.locator('#login-password').fill('Kaname');
      await f.page.evaluate(()=>{const form=document.getElementById('login-form');form.requestSubmit();form.requestSubmit();});
      await f.page.waitForFunction(()=>document.getElementById('unlock').disabled);
      // Give the browser event loop a turn without a timing-dependent sleep.
      await f.page.evaluate(()=>new Promise(resolve=>requestAnimationFrame(resolve)));
      assert.equal(posts,1);release();await f.page.locator('#workspace').waitFor({state:'visible'});
      await passed('repeated-login-submit-is-single-flight',f);
    }
    // An obsolete 401 must not close a newer, successfully authenticated session.
    {
      const f=await fresh();await login(f.page);await f.page.locator('#workspace').waitFor({state:'visible'});
      let release,started;
      const gate=new Promise(resolve=>release=resolve),seen=new Promise(resolve=>started=resolve);
      await f.page.route('**/api/auth/session?obsolete',async route=>{started();await gate;await route.fulfill({status:401,json:{error:'UNAUTHORIZED'}});});
      await f.page.evaluate(()=>{window.oldRequest=api('/api/auth/session?obsolete').then(()=>null,error=>error.code);});
      await seen;const before=await f.page.evaluate(()=>csrf);
      await f.page.evaluate(()=>{document.getElementById('login-user').value='admin';document.getElementById('login-password').value='Kaname';document.getElementById('login-form').requestSubmit();});
      await f.page.waitForFunction(old=>csrf!==old,before);
      release();assert.equal(await f.page.evaluate(()=>window.oldRequest),'SESSION_CHANGED');
      assert.equal(await f.page.locator('#workspace').isVisible(),true);
      await passed('stale-unauthorized-response-cannot-close-new-session',f);
    }
    // Slow polling has one state read regardless of concurrent ticks.
    {
      const f=await fresh();await login(f.page);await f.page.locator('#workspace').waitFor({state:'visible'});
      let reads=0,release,started;
      const gate=new Promise(resolve=>release=resolve),seen=new Promise(resolve=>started=resolve);
      await f.page.route('**/api/state',async route=>{reads++;started();await gate;await route.continue();});
      await f.page.evaluate(()=>{window.polls=Promise.all(Array.from({length:8},()=>pollState()));});
      await seen;assert.equal(reads,1);release();await f.page.evaluate(()=>window.polls);
      await passed('slow-background-poll-is-single-flight',f);
    }
    // A hanging read ends with a bounded timeout and retains the authenticated UI.
    {
      const f=await fresh();await login(f.page);await f.page.locator('#workspace').waitFor({state:'visible'});
      await f.page.clock.install();let started;
      const seen=new Promise(resolve=>started=resolve);
      await f.page.route('**/api/fixture-hang',()=>{started();});
      await f.page.evaluate(()=>{window.hanging=api('/api/fixture-hang').then(()=>null,error=>error.code);});
      await seen;await f.page.clock.fastForward(15001);
      assert.equal(await f.page.evaluate(()=>window.hanging),'REQUEST_TIMEOUT');
      assert.equal(await f.page.locator('#workspace').isVisible(),true);
      await passed('hanging-read-times-out-without-password-reset',f);
    }
    // Failure of a write is reported once: no automatic retry or refresh request storm.
    {
      const f=await fresh();await login(f.page);await f.page.locator('#workspace').waitFor({state:'visible'});
      let writes=0,reads=0;
      await f.page.route('**/api/fixture-write',route=>{writes++;return route.fulfill({status:503,json:{error:'STORE_UNAVAILABLE'}});});
      f.page.on('request',r=>{if(['/api/auth/session','/api/state'].includes(new URL(r.url()).pathname))reads++;});
      await f.page.evaluate(()=>run(()=>api('/api/fixture-write',{fixture:true})));
      assert.equal(writes,1);assert.equal(reads,0);
      assert.equal(await f.page.locator('#workspace').isVisible(),true);
      await passed('failed-write-is-not-retried-or-refreshed',f);
    }
    // Genuine current-session expiration still closes the protected workspace.
    {
      const f=await fresh();await login(f.page);await f.page.locator('#workspace').waitFor({state:'visible'});
      await f.page.route('**/api/fixture-expired',route=>route.fulfill({status:401,json:{error:'UNAUTHORIZED'}}));
      assert.equal(await f.page.evaluate(()=>api('/api/fixture-expired').then(()=>null,error=>error.code)),'UNAUTHORIZED');
      await f.page.locator('#login-form').waitFor({state:'visible'});
      assert.equal(await f.page.locator('#workspace').isVisible(),false);
      await passed('real-expiration-still-requires-login',f);
    }
    console.log(JSON.stringify({panel_session_checks_passed:true,cases,fixture_only:true}));
  }finally{
    if(browser)await browser.close();child.kill('SIGTERM');
    await new Promise(resolve=>{if(child.exitCode!==null)return resolve();child.once('exit',resolve);setTimeout(()=>{child.kill('SIGKILL');resolve();},3000).unref();});
    fs.rmSync(temp,{recursive:true,force:true});
  }
})().catch(error=>{console.error(error.message);process.exitCode=1;});
