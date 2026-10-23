'use strict';
// Disposable fixture only; no customer directory or device connections.
const fs=require('node:fs'),os=require('node:os'),path=require('node:path'),assert=require('node:assert/strict');
const {spawn}=require('node:child_process');
const {chromium}=require(process.env.CODEX_PRIMARY_RUNTIME_NODE_MODULES?path.join(process.env.CODEX_PRIMARY_RUNTIME_NODE_MODULES,'playwright'):'playwright');
(async()=>{
  const root=path.resolve(__dirname,'..'),temp=fs.mkdtempSync(path.join(os.tmpdir(),'authwire-planning-'));
  const python=process.env.CODEX_PRIMARY_RUNTIME_PYTHON||process.env.KANAME_PYTHON||'python3';
  const setup='import sys; from kaname.server import DevelopmentServer; from tests.helpers import config,policy; from tests.test_membership import computer_membership_catalog; s=DevelopmentServer(sys.argv[1],0); s.store.save(0,config=config()); s.store.save(1,policies=[policy()]); s.store.save_directory(2,computer_membership_catalog()); print(s.server_port,flush=True); s.serve_forever()';
  const child=spawn(python,['-u','-c',setup,temp],{cwd:root,stdio:['ignore','pipe','pipe']});let browser;
  try{
    const port=await new Promise((resolve,reject)=>{const timer=setTimeout(()=>reject(new Error('Fixture startup timeout')),10000);child.once('error',reject);child.stdout.once('data',d=>{clearTimeout(timer);resolve(Number(d.toString().trim()));});child.stderr.on('data',d=>process.stderr.write(d));});
    browser=await chromium.launch({headless:true,...(process.env.KANAME_CHROMIUM?{executablePath:process.env.KANAME_CHROMIUM}:{})});
    const page=await browser.newPage({viewport:{width:1440,height:1000}}),errors=[];page.on('pageerror',e=>errors.push(e.message));
    await page.goto('http://127.0.0.1:'+port);await page.locator('#login-user').fill('admin');await page.locator('#login-password').fill('Kaname');await page.locator('#unlock').click();await page.locator('#workspace').waitFor({state:'visible'});
    await require('./ui_navigation.cjs').navigate(page,'network-devices');await page.waitForFunction(()=>inventory!==null);
    await page.locator('#inventory-editor summary').click();await page.locator('#inventory-name').fill('<script>switch</script>');await page.locator('#inventory-vendor').fill('Cisco');await page.locator('#inventory-model').fill('C9300');await page.locator('#inventory-ip').fill('192.0.2.20');
    assert.equal(await page.locator('#inventory-connection').isDisabled(),true);
    await page.locator('#inventory-save').click();await page.waitForFunction(()=>inventory?.items.length===1&&!planningBusy);
    assert.equal(await page.locator('#inventory-list script').count(),0);
    assert.match(await page.locator('#inventory-list').textContent(),/Manual/);
    await page.locator('#inventory-list').getByRole('button',{name:'Düzenle'}).click();await page.locator('#inventory-name').fill('SW-01');await page.locator('#inventory-mode').selectOption('managed');await page.locator('#inventory-connection').selectOption('cloud');await page.locator('#inventory-save').click();await page.waitForFunction(()=>inventory?.items[0]?.management_mode==='managed'&&!planningBusy);
    await page.locator('#inventory-mode-filter').selectOption('manual');assert.match(await page.locator('#inventory-count').textContent(),/^0 \/ 1/);await page.locator('#inventory-mode-filter').selectOption('');
    if(process.env.KANAME_UI_ARTIFACTS){fs.mkdirSync(process.env.KANAME_UI_ARTIFACTS,{recursive:true});await page.screenshot({path:path.join(process.env.KANAME_UI_ARTIFACTS,'network-devices.png'),fullPage:true});}
    await require('./ui_navigation.cjs').navigate(page,'policies');await page.waitForFunction(()=>networkState!==null);
    assert.equal(await page.locator('#draft-editor,#draft-list,#draft-form').count(),0);
    assert.equal(await page.getByText('Yeni gelişmiş kural taslağı',{exact:true}).count(),0);
    await page.reload();await page.locator('#workspace').waitFor({state:'visible'});
    await require('./ui_navigation.cjs').navigate(page,'network-devices');await page.waitForFunction(()=>inventory?.items.length===1);
    assert.equal(await page.locator('#inventory-list').textContent().then(x=>x.includes('SW-01')),true);
    for(const width of [390,1366,1920]){await page.setViewportSize({width,height:900});assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=window.innerWidth),true,'Page fits '+width);}
    await page.locator('#account-toggle').click();await page.locator('#logout').click();await page.locator('#login').waitFor({state:'visible'});assert.equal(await page.locator('#inventory-list').textContent(),'');
    assert.deepEqual(errors,[]);console.log('AUTHWIRE_PLANNING_UI_OK');
  }finally{if(browser)await browser.close();child.kill();fs.rmSync(temp,{recursive:true,force:true});}
})().catch(e=>{console.error(e);process.exitCode=1;});
