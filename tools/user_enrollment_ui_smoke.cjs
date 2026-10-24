'use strict';
// Actual HTTPS/profile/package/renewal APIs with disposable CA + synthetic AD seed.
const fs=require('node:fs'),os=require('node:os'),path=require('node:path'),assert=require('node:assert/strict');
const {spawn}=require('node:child_process');
const {chromium}=require(process.env.CODEX_PRIMARY_RUNTIME_NODE_MODULES?path.join(process.env.CODEX_PRIMARY_RUNTIME_NODE_MODULES,'playwright'):'playwright');
(async()=>{
 const root=path.resolve(__dirname,'..'),temp=fs.mkdtempSync(path.join(os.tmpdir(),'authwire-user-ui-'));
 const python=process.env.CODEX_PRIMARY_RUNTIME_PYTHON||process.env.KANAME_PYTHON||'python3';
 const script=`import sys,base64
from pathlib import Path
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives import hashes
from kaname.server import DevelopmentServer
from tools.linux_initialize import create_web_certificate
from tests.helpers import config
from tests.test_membership import membership_catalog
from tests.test_directory import connection
from tests.test_enrollment import PASSWORD,request
from tests.test_radius_live import GROUP,live_account
from kaname.pki import PKIService
from kaname.device_enrollment import DeviceEnrollment
from kaname.user_enrollment import UserEnrollment
r=Path(sys.argv[1]);create_web_certificate(r,'authwire.lab.example','127.0.0.1')
s=DevelopmentServer(r/'state',0,tls_cert=r/'web.crt',tls_key=r/'web.key',public_name='authwire.lab.example')
s.store.save(0,config=config());s.operations.save_directory(1,connection()|{'search_base':'','sync_minutes':15,'check_minutes':5,'automatic_sync':False});s.store.save_directory(2,membership_catalog())
PKIService(r/'state').initialize(PASSWORD);d=DeviceEnrollment(s.operations);d.unlock_signer(PASSWORD,'browser-fixture');u=UserEnrollment(d,resolver=lambda *a,**kw:live_account(kind='user'))
p=u.save_profile({'id':'','version':0,'name':'Kullanıcı pilotu','group_sid':GROUP,'validity_days':90,'renew_before_days':30,'enabled':True},'fixture')
k=ec.generate_private_key(ec.SECP256R1());csr=request(k).decode();c=u.challenge('Alice@LAB.EXAMPLE',{'profile_id':p['id'],'csr':csr});issued=u.issue('Alice@LAB.EXAMPLE',{'challenge_id':c['challenge_id'],'csr':csr,'proof':base64.b64encode(k.sign(base64.b64decode(c['payload']),ec.ECDSA(hashes.SHA256()))).decode()});u.receipt('Alice@LAB.EXAMPLE',{'serial':issued['serial'],'proof':base64.b64encode(k.sign(base64.b64decode(issued['receipt_payload']),ec.ECDSA(hashes.SHA256()))).decode()})
print(s.server_port,flush=True);s.serve_forever()`;
 const child=spawn(python,['-u','-c',script,temp],{cwd:root,stdio:['ignore','pipe','pipe']});let browser,page,log='';child.stderr.on('data',d=>log+=d);
 try{
  const port=await new Promise((resolve,reject)=>{const timer=setTimeout(()=>reject(Error('Startup timeout '+log)),15000);child.once('error',reject);child.once('exit',c=>reject(Error('Fixture exit '+c+' '+log)));child.stdout.once('data',d=>{clearTimeout(timer);resolve(Number(d.toString().trim()));});});
  browser=await chromium.launch({headless:true,...(process.env.KANAME_CHROMIUM?{executablePath:process.env.KANAME_CHROMIUM}:{})});
  const context=await browser.newContext({ignoreHTTPSErrors:true,viewport:{width:1440,height:1000}}),errors=[];page=await context.newPage();page.on('pageerror',e=>errors.push(e.message));
  async function login(p,user='admin',password='Kaname'){await p.goto('https://127.0.0.1:'+port);await p.locator('#login-user').fill(user);await p.locator('#login-password').fill(password);await p.locator('#unlock').click();await p.locator('#workspace').waitFor({state:'visible'});}
  await login(page);const baseline=await page.evaluate(async()=>({state:await api('/api/state'),devices:await api('/api/device-admin/status')}));
  await require('./ui_navigation.cjs').navigate(page,'certificates');await page.locator('#pki-tab-user-profiles').click();
  await page.waitForFunction(()=>document.querySelector('#ue-profiles').textContent.includes('Kullanıcı pilotu'));
  assert.equal(await page.locator('#ue-profiles tr').count(),1);
  // No implicit activation/creation on open. Explicit group selection and off default.
  await page.locator('#ue-new').click();await page.locator('#ue-group option').nth(1).waitFor({state:'attached'});
  assert.equal(await page.locator('#ue-enabled').isChecked(),false);assert.equal(await page.locator('#ue-group').inputValue(),'');
  await page.locator('#ue-name').fill('Yeni kullanıcı profili');await page.locator('#ue-group').selectOption({index:1});await page.locator('#ue-days').fill('120');await page.locator('#ue-renew').fill('120');
  let profilePosts=0;page.on('request',r=>{if(new URL(r.url()).pathname==='/api/user-admin/profile'&&r.method()==='POST')profilePosts++;});
  await page.locator('#ue-save').click();assert.match(await page.locator('#ue-form-error').textContent(),/geçerlilikten kısa/);assert.equal(profilePosts,0);
  await page.locator('#ue-renew').fill('20');await page.locator('#ue-enabled').check();await page.locator('#ue-save').dblclick();await page.locator('#ue-editor').waitFor({state:'hidden'});assert.equal(profilePosts,1);
  await page.waitForFunction(()=>document.querySelector('#ue-profiles').textContent.includes('Yeni kullanıcı profili'));
  assert.match(await page.locator('#ue-profiles').textContent(),/120 gün/);
  const created=await page.evaluate(async()=>(await api('/api/user-admin/status')).profiles.find(p=>p.name==='Yeni kullanıcı profili'));
  const row=()=>page.locator('#ue-profiles tr').filter({hasText:'Yeni kullanıcı profili'});
  await row().getByRole('button',{name:'Düzenle',exact:true}).click();assert.equal(await page.locator('#ue-days').inputValue(),'120');
  const selected=await page.locator('#ue-group').inputValue();await page.locator('#ue-group-query').fill('no-such-group-fixture');await page.locator('#ue-group-search').click();await page.waitForFunction(()=>document.querySelector('#ue-group-feedback').textContent.startsWith('0 güvenlik grubu'));assert.equal(await page.locator('#ue-group').inputValue(),selected);
  await page.locator('#ue-enabled').uncheck();await page.locator('#ue-save').click();await page.locator('#ue-editor').waitFor({state:'hidden'});await page.waitForFunction(()=>Array.from(document.querySelectorAll('#ue-profiles tr')).find(r=>r.textContent.includes('Yeni kullanıcı profili'))?.textContent.includes('Kapalı'));
  const download=page.waitForEvent('download');await row().getByRole('button',{name:'Kullanıcı paketi',exact:true}).click();const zip=await download;assert.equal(zip.suggestedFilename(),'AuthWire-User-'+created.id+'.zip');
  // Stale revision must preserve form and cannot overwrite another admin's edit.
  await row().getByRole('button',{name:'Düzenle',exact:true}).click();await page.locator('#ue-name').fill('Korunan taslak');
  await page.evaluate(async id=>{const p=(await api('/api/user-admin/status')).profiles.find(p=>p.id===id);delete p.domain;delete p.group_name;p.enabled=!!p.enabled;p.name='Başka yönetici';await api('/api/user-admin/profile',p);},created.id);
  await page.locator('#ue-save').click();await page.waitForFunction(()=>document.querySelector('#ue-form-error').textContent.includes('başka bir işlemde değişti'));assert.equal(await page.locator('#ue-name').inputValue(),'Korunan taslak');await page.locator('#ue-cancel').click();
  // A committed write with a lost reply is never automatically replayed.
  await page.locator('#ue-new').click();await page.locator('#ue-group option').nth(1).waitFor({state:'attached'});await page.locator('#ue-name').fill('Kaybolan yanıt');await page.locator('#ue-group').selectOption({index:1});
  await page.route('**/api/user-admin/profile',async route=>{await route.fetch();await route.abort('failed');},{times:1});const beforePosts=profilePosts;
  await page.locator('#ue-save').click();await page.locator('#ue-reconcile').waitFor({state:'visible'});assert.equal(profilePosts,beforePosts+1);assert.equal(await page.locator('#ue-save').isDisabled(),true);
  await page.locator('#ue-reconcile').click();await page.locator('#ue-editor').waitFor({state:'hidden'});assert.equal(profilePosts,beforePosts+1);assert.equal(await page.locator('#ue-profiles tr').filter({hasText:'Kaybolan yanıt'}).count(),1);
  // Optional read failure retains the list and signed-in session.
  const oldList=await page.locator('#ue-profiles').textContent();await page.route('**/api/user-admin/status*',route=>route.fulfill({status:503,contentType:'application/json',body:'{"error":"STORE_UNAVAILABLE"}'}),{times:1});await page.locator('#ue-refresh').click();await page.waitForFunction(()=>document.querySelector('#ue-profile-feedback').dataset.tone==='error');assert.equal(await page.locator('#ue-profiles').textContent(),oldList);assert.equal(await page.locator('#workspace').isVisible(),true);
  // Actual renewal marking, existing leaf remains in registry; no network action.
  await page.locator('#pki-tab-user-enrollments').click();await page.waitForFunction(()=>document.querySelector('#ue-records').textContent.toLowerCase().includes('alice@lab.example'));
  assert.match(await page.locator('#ue-records').textContent(),/Kurulum doğrulandı/);page.once('dialog',d=>d.accept());await page.locator('#ue-records').getByRole('button',{name:'Şimdi yenile'}).click();await page.waitForFunction(()=>document.querySelector('#ue-records').textContent.includes('Yenileme bekleniyor'));
  const after=await page.evaluate(async()=>({state:await api('/api/state'),devices:await api('/api/device-admin/status')}));assert.deepEqual(after.state.config,baseline.state.config);assert.deepEqual(after.state.policies,baseline.state.policies);assert.deepEqual(after.devices,baseline.devices);
  // Certificate read role: visible records, no profile/package/renewal writes.
  await page.evaluate(async()=>{let s=await api('/api/system');await api('/api/system/profiles/save',{expected_revision:s.revision,profile:{id:'',name:'Certificate reader fixture',mode:'Custom',grants:{'certificates.authority':'read'}}});s=await api('/api/system');const id=s.profiles.find(p=>p.name==='Certificate reader fixture').id;await api('/api/system/users/save',{expected_revision:s.revision,user:{id:'',username:'user-cert-reader',profile_id:id,password:'fixture-user-reader-password',enabled:true}});});
  const readerContext=await browser.newContext({ignoreHTTPSErrors:true,viewport:{width:1440,height:1000}}),reader=await readerContext.newPage();reader.on('pageerror',e=>errors.push(e.message));await login(reader,'user-cert-reader','fixture-user-reader-password');await require('./ui_navigation.cjs').navigate(reader,'certificates');await reader.locator('#pki-tab-user-profiles').click();await reader.waitForFunction(()=>document.querySelector('#ue-profiles').textContent.includes('Kaybolan yanıt'));assert.equal(await reader.locator('#ue-new').isVisible(),false);assert.equal(await reader.locator('#ue-profiles button').count(),0);await reader.locator('#pki-tab-user-enrollments').click();await reader.waitForFunction(()=>document.querySelector('#ue-records').textContent.toLowerCase().includes('alice'));assert.equal(await reader.locator('#ue-records button').count(),0);
  await readerContext.close();
  const artifacts=process.env.KANAME_UI_ARTIFACTS;
  await page.locator('#pki-tab-user-profiles').click();await page.locator('#ue-new').click();await page.locator('#ue-name').fill('Pazartesi kullanıcı pilotu');
  if(artifacts){fs.mkdirSync(artifacts,{recursive:true});await page.screenshot({path:path.join(artifacts,'user-profile-desktop.png'),fullPage:true,animations:'disabled'});}
  await page.locator('#ue-cancel').click();await page.setViewportSize({width:390,height:844});
  if(artifacts){await page.screenshot({path:path.join(artifacts,'user-profiles-mobile.png'),fullPage:true,animations:'disabled'});}
  assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1),true);
  // Slow response after logout cannot repopulate profile/record data.
  await page.setViewportSize({width:1440,height:1000});let release;const held=new Promise(r=>release=r);let entered;const started=new Promise(r=>entered=r);
  await page.route('**/api/user-admin/status*',async route=>{const reply=await route.fetch();entered();await held;await route.fulfill({response:reply});},{times:1});
  await page.locator('#ue-refresh').click();await started;await page.locator('#account-toggle').click();await page.locator('#logout').click();await page.locator('#login').waitFor({state:'visible'});release();await page.waitForTimeout(150);
  assert.equal(await page.locator('#ue-profiles').textContent(),'');assert.equal(await page.locator('#ue-records').textContent(),'');assert.deepEqual(errors,[]);
  console.log('AUTHWIRE_USER_ENROLLMENT_UI_OK '+JSON.stringify({actual_https_profile_save:true,off_default:true,explicit_group:true,validation_no_post:true,single_write:true,profile_disable_not_revoke:true,selected_group_preserved:true,package_download:true,stale_revision_preserves_form:true,lost_reply_reconciled_without_replay:true,read_failure_keeps_session:true,renewal_pending_not_instant:true,read_only_role:true,logout_discards_pending:true,mobile:true,machine_profiles_and_policies_preserved:true,live_ad_or_gpo:false}));
 }catch(error){if(page){console.error('USER_PANEL_FAILURE_STATE',await page.evaluate(()=>({feedback:document.querySelector('#ue-profile-feedback').textContent,form:document.querySelector('#ue-form-error').textContent,records:document.querySelector('#ue-records').textContent})).catch(()=>null));if(process.env.KANAME_UI_ARTIFACTS){fs.mkdirSync(process.env.KANAME_UI_ARTIFACTS,{recursive:true});await page.screenshot({path:path.join(process.env.KANAME_UI_ARTIFACTS,'user-panel-failure.png'),fullPage:true}).catch(()=>{});}}throw error;}finally{if(browser)await browser.close();child.kill();fs.rmSync(temp,{recursive:true,force:true});}
})().catch(e=>{console.error(e);process.exitCode=1;});
