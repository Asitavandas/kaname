'use strict';
// Actual HTTPS preparation/save/preview/archive. No GPO or customer AD operation.
const fs=require('node:fs'),os=require('node:os'),path=require('node:path'),assert=require('node:assert/strict');
const {spawn}=require('node:child_process');
const {chromium}=require(process.env.CODEX_PRIMARY_RUNTIME_NODE_MODULES?path.join(process.env.CODEX_PRIMARY_RUNTIME_NODE_MODULES,'playwright'):'playwright');
(async()=>{
 const root=path.resolve(__dirname,'..'),temp=fs.mkdtempSync(path.join(os.tmpdir(),'authwire-deployment-ui-'));
 const python=process.env.CODEX_PRIMARY_RUNTIME_PYTHON||process.env.KANAME_PYTHON||'python3';
 const script=`import sys
from pathlib import Path
from kaname.server import DevelopmentServer
from kaname.store import Store
from kaname.operations import Operations
from kaname.pki import PKIService
from kaname.device_enrollment import DeviceEnrollment
from kaname.user_enrollment import UserEnrollment
from tools.radius_initialize import initialize
from tools.linux_initialize import create_web_certificate
from tests.helpers import config
from tests.test_membership import computer_membership_catalog
from tests.test_enrollment import PASSWORD
r=Path(sys.argv[1]);state=r/'state';store=Store(state);store.save(0,config=config());catalog=computer_membership_catalog();catalog['groups'][0]['unresolved_members']=0;catalog['users'][0]['enabled']=True;store.save_directory(store.snapshot()['revision'],catalog)
PKIService(state).initialize(PASSWORD);initialize(state,PASSWORD);devices=DeviceEnrollment(Operations(store));users=UserEnrollment(devices)
fields=dict(id='',version=0,name='Computer fixture',group_sid=catalog['groups'][0]['sid'],validity_days=90,renew_before_days=30,enabled=True)
devices.save_profile(fields,'fixture');fields['name']='User fixture';users.save_profile(fields,'fixture')
create_web_certificate(r,'kaname.lab.example','127.0.0.1');s=DevelopmentServer(state,0,tls_cert=r/'web.crt',tls_key=r/'web.key',public_name='kaname.lab.example');print(s.server_port,flush=True);s.serve_forever()`;
 const child=spawn(python,['-u','-c',script,temp],{cwd:root,stdio:['ignore','pipe','pipe']});let browser;
 const exited=new Promise(resolve=>child.once('exit',resolve));
 try{
  let stderr='';child.stderr.on('data',d=>stderr+=d);
  const port=await new Promise((resolve,reject)=>{const timer=setTimeout(()=>reject(Error('Fixture start timeout '+stderr)),20000);child.once('error',reject);child.once('exit',c=>reject(Error('Fixture exited '+c+' '+stderr)));child.stdout.once('data',d=>{clearTimeout(timer);resolve(Number(d.toString().trim()));});});
  browser=await chromium.launch({headless:true,...(process.env.KANAME_CHROMIUM?{executablePath:process.env.KANAME_CHROMIUM}:{})});
  const context=await browser.newContext({ignoreHTTPSErrors:true,viewport:{width:1440,height:1100}}),page=await context.newPage(),errors=[];let posts=0;
  page.on('pageerror',e=>errors.push(e.message));page.on('request',r=>{if(r.method()==='POST'&&new URL(r.url()).pathname==='/api/deployment/save')posts++;});
  async function login(p,name='admin',password='Kaname'){await p.goto('https://127.0.0.1:'+port);await p.locator('#login-user').fill(name);await p.locator('#login-password').fill(password);await p.locator('#unlock').click();await p.locator('#workspace').waitFor({state:'visible'});await require('./ui_navigation.cjs').navigate(p,'certificates');await p.locator('#pki-tab-distribution').click();await p.waitForFunction(()=>depState!==null);}
  await login(page);const baseline=await page.evaluate(()=>api('/api/state'));assert.equal(posts,0);
  await page.locator('#dep-new').click();await page.locator('#dep-editor').waitFor({state:'visible'});await page.locator('#dep-name').fill('Pilot <img src=x onerror=alert(1)>');await page.locator('#dep-mode').selectOption('machineOrUser');await page.locator('#dep-machine-profile').selectOption({index:1});await page.locator('#dep-user-profile').selectOption({index:1});await page.locator('#dep-wireless').check();await page.locator('#dep-ssid').fill('VV_802.1X');
  const selected=await page.locator('#dep-group').inputValue();await page.locator('#dep-group-query').fill('no-match');await page.locator('#dep-group-search').click();await page.waitForFunction(()=>depState.total===0);assert.equal(await page.locator('#dep-group').inputValue(),selected);
  if(process.env.KANAME_UI_ARTIFACTS){fs.mkdirSync(process.env.KANAME_UI_ARTIFACTS,{recursive:true});await page.screenshot({path:path.join(process.env.KANAME_UI_ARTIFACTS,'deployment-editor-desktop.png'),fullPage:true,animations:'disabled'});}
  await page.locator('#dep-save').click();await page.locator('#dep-editor').waitFor({state:'hidden'});await page.waitForFunction(()=>!depBusy&&depState.plans.length===1);assert.equal(posts,1);assert.equal(await page.locator('#dep-list img').count(),0);
  await page.locator('#dep-list').getByRole('button',{name:'Önizle',exact:true}).click();await page.waitForFunction(()=>depPreview!==null&&!depBusy);assert.equal(await page.evaluate(()=>depPreview.computer_targets.enabled),1);assert.equal(await page.evaluate(()=>depPreview.user_targets.enabled),1);assert.equal(await page.evaluate(()=>depPreview.can_apply),false);
  const downloadPromise=page.waitForEvent('download');await page.locator('#dep-download').click();const download=await downloadPromise;assert.equal(download.suggestedFilename(),'AuthWire-Network-Profiles.zip');await download.saveAs(path.join(temp,'profiles.zip'));assert.ok(fs.statSync(path.join(temp,'profiles.zip')).size>1000);
  // Lost save reply is reconciled by a read; the stable UUID prevents duplicates.
  await page.locator('#dep-new').click();await page.locator('#dep-editor').waitFor({state:'visible'});await page.locator('#dep-name').fill('Lost reply fixture');await page.locator('#dep-machine-profile').selectOption({index:1});
  await page.route('**/api/deployment/save',async route=>{await route.fetch();await route.abort('failed');},{times:1});const before=posts;await page.locator('#dep-save').click();await page.locator('#dep-reconcile').waitFor({state:'visible'});assert.equal(posts,before+1);assert.equal(await page.locator('#dep-save').isDisabled(),true);await page.locator('#dep-reconcile').click();await page.locator('#dep-editor').waitFor({state:'hidden'});assert.equal(posts,before+1);assert.equal(await page.locator('#dep-list tr').count(),2);
  // A stale editor may not overwrite another administrator's change.
  await page.locator('#dep-list tr').first().getByRole('button',{name:'Düzenle',exact:true}).click();await page.locator('#dep-editor').waitFor({state:'visible'});await page.locator('#dep-name').fill('Keep draft');
  await page.evaluate(async()=>{const fields=['id','version','name','computer_group_sid','machine_profile_id','user_profile_id','wired','wireless','ssid','auth_mode','server_name'];const s=await api('/api/deployment/status');const plan=Object.fromEntries(fields.map(k=>[k,s.plans[0][k]]));plan.name='Concurrent version';await api('/api/deployment/save',{expected_revision:s.revision,plan});});
  await page.locator('#dep-save').click();await page.waitForFunction(()=>document.getElementById('dep-form-error').textContent.includes('Başka bir işlem'));assert.equal(await page.locator('#dep-name').inputValue(),'Keep draft');await page.locator('#dep-cancel').click();
  const after=await page.evaluate(()=>api('/api/state'));assert.deepEqual(after.config,baseline.config);assert.deepEqual(after.policies,baseline.policies);
  await page.evaluate(async()=>{const s=await api('/api/system');await api('/api/system/users/save',{expected_revision:s.revision,user:{id:'',username:'reader',profile_id:s.profiles.find(p=>p.mode==='Admin_ReadOnly').id,password:'fixture-deployment-reader-42',enabled:true}});});
  const rc=await browser.newContext({ignoreHTTPSErrors:true}),reader=await rc.newPage();await login(reader,'reader','fixture-deployment-reader-42');assert.equal(await reader.locator('#dep-new').isVisible(),false);assert.equal(await reader.locator('[data-dep-write]').count(),0);assert.equal(await reader.evaluate(async()=>(await fetch('/api/deployment/save',{method:'POST',headers:{'Content-Type':'application/json','X-Kaname-CSRF':csrf},body:'{}'})).status),403);await rc.close();
  await page.locator('#dep-refresh').click();await page.waitForFunction(()=>depState.plans.some(p=>p.name==='Concurrent version'));await page.locator('#dep-list tr').first().getByRole('button',{name:'Önizle',exact:true}).click();await page.waitForFunction(()=>!depBusy);
  if(process.env.KANAME_UI_ARTIFACTS){await page.screenshot({path:path.join(process.env.KANAME_UI_ARTIFACTS,'deployment-preview-desktop.png'),fullPage:true,animations:'disabled'});await page.setViewportSize({width:390,height:844});await page.screenshot({path:path.join(process.env.KANAME_UI_ARTIFACTS,'deployment-preview-mobile.png'),fullPage:true,animations:'disabled'});}
  assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1),true);
  await page.setViewportSize({width:1440,height:1100});let release,entered;const held=new Promise(r=>release=r),started=new Promise(r=>entered=r);await page.route('**/api/deployment/status*',async route=>{const response=await route.fetch();entered();await held;await route.fulfill({response});},{times:1});await page.locator('#dep-refresh').click();await started;await page.locator('#account-toggle').click();await page.locator('#logout').click();await page.locator('#login').waitFor({state:'visible'});release();await page.waitForTimeout(150);assert.equal(await page.locator('#dep-list').textContent(),'');assert.deepEqual(errors,[]);
  console.log('AUTHWIRE_DEPLOYMENT_UI_OK real_https=true versioned_save=true separate_targets=true public_profile_archive=true lost_reply_no_replay=true stale_editor_guard=true read_role=true responsive=true logout_guard=true gpo_or_endpoint_changed=false');
 }finally{if(browser)await browser.close();if(child.exitCode===null){child.kill();await exited;}fs.rmSync(temp,{recursive:true,force:true});}
})().catch(e=>{console.error(e);process.exitCode=1;});
