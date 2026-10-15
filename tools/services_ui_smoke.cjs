'use strict';
// Browser fixture contains no customer connection or real service control.
const fs=require('node:fs'),os=require('node:os'),path=require('node:path'),assert=require('node:assert/strict');
const {spawn}=require('node:child_process');
const {chromium}=require(process.env.CODEX_PRIMARY_RUNTIME_NODE_MODULES?path.join(process.env.CODEX_PRIMARY_RUNTIME_NODE_MODULES,'playwright'):'playwright');
(async()=>{
 const root=path.resolve(__dirname,'..'),temp=fs.mkdtempSync(path.join(os.tmpdir(),'authwire-services-ui-'));
 const python=process.env.CODEX_PRIMARY_RUNTIME_PYTHON||process.env.KANAME_PYTHON||'python3';
 const setup='import sys;from kaname.server import DevelopmentServer;s=DevelopmentServer(sys.argv[1],0);print(s.server_port,flush=True);s.serve_forever()';
 const child=spawn(python,['-u','-c',setup,temp],{cwd:root,stdio:['ignore','pipe','pipe']});let browser;
 try{
  const port=await new Promise((resolve,reject)=>{const timer=setTimeout(()=>reject(Error('Fixture startup timeout')),10000);child.once('error',reject);child.stdout.once('data',d=>{clearTimeout(timer);resolve(Number(d.toString().trim()));});child.stderr.on('data',d=>process.stderr.write(d));});
  browser=await chromium.launch({headless:true,...(process.env.KANAME_CHROMIUM?{executablePath:process.env.KANAME_CHROMIUM}:{})});
  const page=await browser.newPage({viewport:{width:1440,height:1000}}),errors=[];page.on('pageerror',e=>errors.push(e.message));
  const names={radius:'authwire-radius.service',panel:'kaname-lab.service','crl-sync':'authwire-radius-crl-sync.service','crl-timer':'authwire-radius-crl-sync.timer'};
  const services=Object.keys(names).map(id=>({id,unit:names[id],installed:true,active_state:id==='crl-sync'?'inactive':'active',health:id==='crl-sync'?'idle':'running',enabled:id==='crl-sync'?'static':'enabled',memory_bytes:12345678,cpu_seconds:2,uptime_seconds:7200,last_result:'success',actions:id==='radius'?['start','stop','restart']:id==='crl-sync'?['sync']:id==='crl-timer'?['start','stop']:[]}));
  let ops=[],posts=0,unavailable=false,hold=false,reader=false;
  await page.route('**/api/services',async route=>{
    if(unavailable)return route.fulfill({status:503,json:{error:'SERVICE_CONTROL_UNAVAILABLE'}});
    return route.fulfill({json:{available:true,checked_at:new Date().toISOString(),services,busy:hold,operations:ops}});
  });
  await page.route('**/api/services/action',async route=>{
    posts++;const value=route.request().postDataJSON();assert.equal(value.confirmed,true);assert.equal(value.service,'radius');
    ops=[{id:value.request_id,service:value.service,action:value.action,actor:'operator<img src=x>',created_at:new Date().toISOString(),state:'running'}];hold=true;
    await route.fulfill({status:202,json:{operation:ops[0]}});
  });
  await page.goto('http://127.0.0.1:'+port);await page.locator('#login-user').fill('admin');await page.locator('#login-password').fill('Kaname');await page.locator('#unlock').click();await page.locator('#workspace').waitFor({state:'visible'});
  await page.locator('[data-view="services"]').click();await page.locator('#services-list tr').first().waitFor();
  assert.equal(await page.locator('#services-list tr').count(),4);assert.match(await page.locator('#services-list').textContent(),/Bekliyor · Son çalışma başarılı/);
  await page.locator('#services-restart').click();await page.locator('#services-confirm').waitFor({state:'visible'});
  assert.match(await page.locator('#services-confirm-impact').textContent(),/kimlik doğrulamaları/);
  await page.locator('#services-confirm button[value="cancel"]').click();assert.equal(posts,0);
  await page.locator('#services-restart').click();await page.locator('#services-confirm-submit').click();await page.waitForFunction(()=>servicesState?.busy===true);
  assert.equal(posts,1);assert.equal(await page.locator('#services-restart').isDisabled(),true);
  ops[0].state='succeeded';hold=false;await page.locator('#services-refresh').click();await page.waitForFunction(()=>servicesState?.operations[0]?.state==='succeeded'&&!servicesSending);
  assert.equal(await page.locator('#services-operations img').count(),0);
  await page.locator('#services-selection').selectOption('panel');assert.equal(await page.locator('#services-stop').isVisible(),false);assert.equal(await page.locator('#services-restart').isVisible(),false);
  // Read-only view retains rows but offers no enabled mutation.
  await page.evaluate(()=>{session.permissions['system.services']='read';servicesButtons();});await page.locator('#services-selection').selectOption('radius');assert.equal(await page.locator('#services-restart').isDisabled(),true);
  await page.evaluate(()=>{session.permissions['system.services']='write';servicesButtons();});
  if(process.env.KANAME_UI_ARTIFACTS){fs.mkdirSync(process.env.KANAME_UI_ARTIFACTS,{recursive:true});await page.screenshot({path:path.join(process.env.KANAME_UI_ARTIFACTS,'services.png'),fullPage:true});}
  for(const width of [390,1366,1920]){await page.setViewportSize({width,height:900});assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=window.innerWidth),true,'fits '+width);}
  unavailable=true;await page.locator('#services-refresh').click();await page.waitForFunction(()=>document.querySelector('#services-feedback').textContent.includes('kullanılamıyor'));
  assert.equal(await page.locator('#workspace').isVisible(),true);await page.locator('[data-view="overview"]').click();assert.equal(await page.locator('#overview').isVisible(),true);
  await page.locator('#logout').click();await page.locator('#login').waitFor({state:'visible'});assert.equal(await page.locator('#services-list').textContent(),'');assert.equal(await page.locator('#services-operations').textContent(),'');
  assert.deepEqual(errors,[]);console.log('AUTHWIRE_SERVICES_UI_OK');
 }finally{if(browser)await browser.close();child.kill();fs.rmSync(temp,{recursive:true,force:true});}
})().catch(e=>{console.error(e);process.exitCode=1;});
