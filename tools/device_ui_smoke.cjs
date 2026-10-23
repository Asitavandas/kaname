'use strict';
// HTTPS + real profile/CA APIs, isolated directory catalog; no customer AD.
const fs=require('node:fs'),os=require('node:os'),path=require('node:path'),assert=require('node:assert/strict');
const {spawn}=require('node:child_process');
const {chromium}=require(process.env.CODEX_PRIMARY_RUNTIME_NODE_MODULES?path.join(process.env.CODEX_PRIMARY_RUNTIME_NODE_MODULES,'playwright'):'playwright');
(async()=>{
 const root=path.resolve(__dirname,'..'),temp=fs.mkdtempSync(path.join(os.tmpdir(),'authwire-device-ui-'));
 const python=process.env.CODEX_PRIMARY_RUNTIME_PYTHON||process.env.KANAME_PYTHON||'python3';
 const script='import sys;from pathlib import Path;from kaname.server import DevelopmentServer;from tools.linux_initialize import create_web_certificate;from tests.helpers import config;from tests.test_membership import membership_catalog;from kaname.pki import PKIService;r=Path(sys.argv[1]);create_web_certificate(r,"authwire.lab.example","127.0.0.1");s=DevelopmentServer(r/"state",0,tls_cert=r/"web.crt",tls_key=r/"web.key",public_name="authwire.lab.example");s.store.save(0,config=config());s.store.save_directory(1,membership_catalog());PKIService(r/"state").initialize(b"fixture-browser-device-passphrase");print(s.server_port,flush=True);s.serve_forever()';
 const child=spawn(python,['-u','-c',script,temp],{cwd:root,stdio:['ignore','pipe','pipe']});let browser;let log='';child.stderr.on('data',data=>log+=data);
 try {
  const port=await new Promise((resolve,reject)=>{const timer=setTimeout(()=>reject(new Error('Fixture startup timeout '+log)),15000);child.once('error',reject);child.once('exit',code=>reject(new Error('Fixture exit '+code+' '+log)));child.stdout.once('data',data=>{clearTimeout(timer);resolve(Number(data.toString().trim()));});});
  browser=await chromium.launch({headless:true,...(process.env.KANAME_CHROMIUM?{executablePath:process.env.KANAME_CHROMIUM}:{})});
  // Trust override belongs ONLY to this disposable Playwright fixture.
  const page=await browser.newPage({ignoreHTTPSErrors:true,viewport:{width:1440,height:1000}}),errors=[];page.on('pageerror',error=>errors.push(error.message));
  await page.goto(`https://127.0.0.1:${port}`);await page.locator('#login-user').fill('admin');await page.locator('#login-password').fill('Kaname');await page.locator('#unlock').click();await page.locator('#workspace').waitFor({state:'visible'});
  await require('./ui_navigation.cjs').navigate(page,'certificates');await page.locator('#device-new-profile').click();
  await page.locator('#device-profile-group option').first().waitFor({state:'attached'});
  await page.locator('#device-profile-name').fill('Pilot bilgisayarları');await page.locator('#device-profile-days').fill('120');await page.locator('#device-profile-renew').fill('20');
  await page.locator('#device-profile-save').click();await page.waitForFunction(()=>document.querySelector('#device-profile-list').textContent.includes('Pilot bilgisayarları'));
  assert.match(await page.locator('#device-profile-list').textContent(),/120 gün geçerli.*20 gün önce yenile.*Kayıt durduruldu/);
  await page.locator('#device-profile-list button').filter({hasText:'Düzenle'}).click();assert.equal(await page.locator('#device-profile-days').inputValue(),'120');await page.locator('#device-profile-cancel').click();
  const download=page.waitForEvent('download');await page.locator('#device-profile-list button').filter({hasText:'GPO paketi'}).click();const artifact=await download;assert.match(artifact.suggestedFilename(),/^AuthWire-GPO-/);
  await page.locator('#pki-tab-distribution').click();assert.match(await page.locator('#device-readiness').textContent(),/Kerberos SPN\/keytab — Hazırlanacak/);
  await page.locator('#device-signer-password').fill('fixture-browser-device-passphrase');await page.locator('#device-signer-enable').click();await page.waitForFunction(()=>Array.from(document.querySelectorAll('#device-readiness p')).some(p=>p.textContent==='✓ Otomatik imzalayıcı — Hazır'));assert.equal(await page.locator('#device-signer-password').inputValue(),'');
  await page.locator('#device-signer-disable').click();await page.waitForFunction(()=>document.querySelector('#device-readiness').textContent.includes('Otomatik imzalayıcı — Hazırlanacak'));
  await page.locator('#pki-tab-devices').click();assert.match(await page.locator('#device-list').textContent(),/Henüz cihaz kaydı yok/);
  const artifacts=process.env.KANAME_UI_ARTIFACTS;if(artifacts){fs.mkdirSync(artifacts,{recursive:true});await page.locator('#pki-tab-bulk').click();await page.screenshot({path:path.join(artifacts,'bulk-profiles-desktop.png'),fullPage:true,animations:'disabled'});await page.locator('#pki-tab-distribution').click();await page.screenshot({path:path.join(artifacts,'bulk-distribution-desktop.png'),fullPage:true,animations:'disabled'});await page.setViewportSize({width:390,height:844});await page.screenshot({path:path.join(artifacts,'bulk-distribution-mobile.png'),fullPage:true,animations:'disabled'});assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1),true);}
  await page.locator('#account-toggle').click();await page.locator('#logout').click();await page.locator('#login').waitFor({state:'visible'});assert.equal(await page.locator('#device-signer-password').inputValue(),'');assert.equal(await page.locator('#device-profile-list').textContent(),'');assert.deepEqual(errors,[]);console.log('AuthWire profile, GPO download, signer controls, mobile layout and logout passed.');
 } finally {if(browser)await browser.close();child.kill();fs.rmSync(temp,{recursive:true,force:true});}
})().catch(error=>{console.error(error);process.exitCode=1;});
