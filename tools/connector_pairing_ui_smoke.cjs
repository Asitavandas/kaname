'use strict';
// Disposable HTTPS browser fixture. No customer pairing, AD, GPO or service.
const fs=require('node:fs'),os=require('node:os'),path=require('node:path'),assert=require('node:assert/strict');
const {spawn}=require('node:child_process');
const {chromium}=require(process.env.CODEX_PRIMARY_RUNTIME_NODE_MODULES?path.join(process.env.CODEX_PRIMARY_RUNTIME_NODE_MODULES,'playwright'):'playwright');
(async()=>{
 const root=path.resolve(__dirname,'..'),temp=fs.mkdtempSync(path.join(os.tmpdir(),'authwire-connector-ui-'));
 const python=process.env.CODEX_PRIMARY_RUNTIME_PYTHON||process.env.KANAME_PYTHON||'python3';
 const source=`import json,sys,uuid
from pathlib import Path
from cryptography import x509
from cryptography.hazmat.primitives import hashes,serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from kaname.server import DevelopmentServer
from kaname.store import Store
from kaname.operations import Operations
from kaname.pki import PKIService
from kaname.connector_channel import public_key_id
from tools.linux_initialize import create_web_certificate
from tests.helpers import config
r=Path(sys.argv[1]);s=r/'state';store=Store(s);store.save(0,config=config());Operations(store)
authority=PKIService(s).initialize(b'fixture-connector-ui-password')
create_web_certificate(r,'kaname.lab.example','127.0.0.1')
key=rsa.generate_private_key(public_exponent=65537,key_size=3072);pub=key.public_key()
candidate={'instance_id':authority['instance_id'],'connector_id':str(uuid.uuid4()),'host_guid':str(uuid.uuid4()),'host_fqdn':'dc01.lab.example','service_sid':'S-1-5-21-111-222-333-1648','appliance_fqdn':'kaname.lab.example','appliance_tls_sha256':x509.load_pem_x509_certificate((r/'web.crt').read_bytes()).fingerprint(hashes.SHA256()).hex(),'public_key_pem':pub.public_bytes(serialization.Encoding.PEM,serialization.PublicFormat.SubjectPublicKeyInfo).decode()}
server=DevelopmentServer(s,0,tls_cert=r/'web.crt',tls_key=r/'web.key',public_name='kaname.lab.example')
print(json.dumps({'port':server.server_port,'candidate':candidate,'key_id':public_key_id(pub)}),flush=True)
server.serve_forever()`;
 const child=spawn(python,['-u','-c',source,temp],{cwd:root,stdio:['ignore','pipe','pipe']});let browser;const exited=new Promise(r=>child.once('exit',r));
 try{
  let stderr='';child.stderr.on('data',d=>stderr+=d);
  const fixture=await new Promise((resolve,reject)=>{let line='';const timer=setTimeout(()=>reject(Error('Fixture timeout '+stderr)),20000);child.once('error',reject);child.once('exit',code=>reject(Error('Fixture exited '+code+' '+stderr)));child.stdout.on('data',d=>{line+=d;if(line.includes('\n')){clearTimeout(timer);try{resolve(JSON.parse(line.split('\n')[0]));}catch(e){reject(e);}}});});
  browser=await chromium.launch({headless:true,...(process.env.KANAME_CHROMIUM?{executablePath:process.env.KANAME_CHROMIUM}:{})});
  const context=await browser.newContext({ignoreHTTPSErrors:true,viewport:{width:1440,height:1000}}),page=await context.newPage(),errors=[];let previews=0,applies=0;
  page.on('pageerror',e=>errors.push(e.message));page.on('request',r=>{const p=new URL(r.url()).pathname;if(r.method()==='POST'&&p==='/api/deployment/connector/preview')previews++;if(r.method()==='POST'&&p==='/api/deployment/connector/apply')applies++;});
  async function login(p,name='admin',password='Kaname'){
   await p.goto('https://127.0.0.1:'+fixture.port);await p.locator('#login-user').fill(name);await p.locator('#login-password').fill(password);await p.locator('#unlock').click();await p.locator('#workspace').waitFor({state:'visible'});await require('./ui_navigation.cjs').navigate(p,'windows-connector');await p.waitForFunction(()=>connectorReadable&&!connectorBusy);
  }
  await login(page);const baseline=await page.evaluate(()=>api('/api/state'));assert.equal(applies,0);
  // A duplicate key or nested envelope cannot replace the reviewed identity.
  await page.locator('#connector-candidate').fill('{"connector_id":"one","connector_id":"two"}');await page.locator('#connector-preview-button').click();assert.equal(previews,0);assert.match(await page.locator('#connector-feedback').textContent(),/yinelenen/);
  await page.locator('#connector-candidate').fill(JSON.stringify({PairingCandidate:fixture.candidate}));await page.locator('#connector-preview-button').click();assert.equal(previews,0);
  await page.locator('#connector-candidate').fill(JSON.stringify(fixture.candidate));await page.locator('#connector-preview-button').click();await page.waitForFunction(()=>connectorPreview!==null&&!connectorBusy);assert.equal(previews,1);assert.equal(applies,0);
  assert.equal(await page.evaluate(()=>connectorPreview.after.channel_key_sha256),fixture.key_id);
  assert.equal(await page.locator('#connector-apply').isDisabled(),true);
  await page.locator('#connector-key-confirm').fill('0'.repeat(64));assert.equal(await page.locator('#connector-apply').isDisabled(),true);
  await page.locator('#connector-key-confirm').fill(fixture.key_id);assert.equal(await page.locator('#connector-apply').isEnabled(),true);
  // Editing the candidate invalidates the preview and explicit key confirmation.
  await page.locator('#connector-candidate').fill(JSON.stringify(fixture.candidate,null,2));assert.equal(await page.locator('#connector-preview').isVisible(),false);assert.equal(await page.locator('#connector-key-confirm').inputValue(),'');
  await page.locator('#connector-preview-button').click();await page.waitForFunction(()=>connectorPreview!==null&&!connectorBusy);
  // Other state writes make the preview stale; a click cannot silently replay it.
  await page.evaluate(async()=>{const s=await api('/api/state');await api('/api/config',{expected_revision:s.revision,patch:{appliance_fqdn:s.config.appliance_fqdn}});});
  await page.locator('#connector-key-confirm').fill(fixture.key_id);await page.locator('#connector-apply').click();await page.waitForFunction(()=>!connectorBusy&&!connectorPreview);assert.equal(applies,1);assert.match(await page.locator('#connector-feedback').textContent(),/değiştirdi/);
  await page.locator('#connector-refresh').click();await page.waitForFunction(()=>connectorReadable&&!connectorBusy);await page.locator('#connector-preview-button').click();await page.waitForFunction(()=>connectorPreview!==null&&!connectorBusy);
  if(process.env.KANAME_UI_ARTIFACTS){fs.mkdirSync(process.env.KANAME_UI_ARTIFACTS,{recursive:true});await page.screenshot({path:path.join(process.env.KANAME_UI_ARTIFACTS,'connector-pairing-preview-desktop.png'),fullPage:true,animations:'disabled'});}
  await page.setViewportSize({width:390,height:844});assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1),true);await page.setViewportSize({width:1440,height:1000});
  // Commit on server, drop only the reply. Reconciliation is GET, never POST.
  await page.route('**/api/deployment/connector/apply',async route=>{await route.fetch();await route.abort('failed');},{times:1});await page.locator('#connector-key-confirm').fill(fixture.key_id.toUpperCase());await page.locator('#connector-apply').click();await page.locator('#connector-reconcile').waitFor({state:'visible'});assert.equal(applies,2);assert.equal(await page.locator('#connector-preview-button').isDisabled(),true);
  await page.locator('#connector-reconcile').click();await page.waitForFunction(()=>connectorState?.paired&&!connectorBusy&&!connectorUncertain);assert.equal(applies,2);assert.equal(await page.locator('#connector-form').isVisible(),false);assert.match(await page.locator('#connector-status').textContent(),/bağlantısı bekleniyor/);assert.equal(await page.evaluate(()=>connectorState.can_apply),false);
  const downloadPromise=page.waitForEvent('download');await page.locator('#connector-export').click();const download=await downloadPromise;await download.saveAs(path.join(temp,'binding.json'));const exported=JSON.parse(fs.readFileSync(path.join(temp,'binding.json'),'utf8'));assert.equal(exported.Format,'AuthWireConnectorBindingPublicV1');assert.equal(exported.Binding.channel_key_sha256,fixture.key_id);assert.equal(Object.keys(exported.Binding).length,9);assert.equal(JSON.stringify(exported).includes('PUBLIC KEY'),false);assert.equal(exported.BaseUrl,'https://kaname.lab.example:'+fixture.port+'/');
  const after=await page.evaluate(()=>api('/api/state'));assert.deepEqual(after.config,baseline.config);assert.deepEqual(after.policies,baseline.policies);
  // Dedicated connector readers can reach this page without certificate grants.
  await page.evaluate(async()=>{let s=await api('/api/system');await api('/api/system/profiles/save',{expected_revision:s.revision,profile:{id:'',name:'connector-read-role',mode:'Custom',grants:{'system.connectors':'read'}}});s=await api('/api/system');const p=s.profiles.find(p=>p.name==='connector-read-role');await api('/api/system/users/save',{expected_revision:s.revision,user:{id:'',username:'connector-reader',profile_id:p.id,password:'fixture-connector-reader-42',enabled:true}});});
  const rc=await browser.newContext({ignoreHTTPSErrors:true}),reader=await rc.newPage();await login(reader,'connector-reader','fixture-connector-reader-42');assert.equal(await reader.locator('#connector-form').isVisible(),false);assert.equal(await reader.locator('#connector-apply').isEnabled(),false);assert.equal(await reader.evaluate(async()=>(await fetch('/api/deployment/connector/apply',{method:'POST',headers:{'Content-Type':'application/json','X-Kaname-CSRF':csrf},body:'{}'})).status),403);await rc.close();
  // A held read after logout must not repaint the cleared public candidate/state.
  let release,entered;const held=new Promise(r=>release=r),started=new Promise(r=>entered=r);await page.route('**/api/deployment/connector',async route=>{const response=await route.fetch();entered();await held;await route.fulfill({response});},{times:1});await page.locator('#connector-refresh').click();await started;await page.locator('#account-toggle').click();await page.locator('#logout').click();await page.locator('#login').waitFor({state:'visible'});release();await page.waitForTimeout(150);assert.equal(await page.locator('#connector-summary').textContent(),'');assert.equal(await page.locator('#connector-candidate').inputValue(),'');assert.deepEqual(errors,[]);
  console.log('AUTHWIRE_CONNECTOR_PAIRING_UI_OK real_https_fixture=true duplicate_json_refused=true preview_readonly=true explicit_full_key_confirmation=true edit_invalidates=true revision_guard=true lost_reply_read_reconcile=true no_post_replay=true public_binding_export=true independent_connector_read_role=true responsive=true logout_guard=true customer_trust_or_gpo_changed=false');
 }finally{if(browser)await browser.close();if(child.exitCode===null){child.kill();await exited;}fs.rmSync(temp,{recursive:true,force:true});}
})().catch(e=>{console.error(e);process.exitCode=1;});
