'use strict';
// Disposable AD catalog; this test never contacts the customer's domain or services.
const fs=require('node:fs'),os=require('node:os'),path=require('node:path'),assert=require('node:assert/strict'),{spawn}=require('node:child_process');
const {chromium}=require(process.env.CODEX_PRIMARY_RUNTIME_NODE_MODULES?path.join(process.env.CODEX_PRIMARY_RUNTIME_NODE_MODULES,'playwright'):'playwright');
const {navigate}=require('./ui_navigation.cjs');
(async()=>{
 const root=path.resolve(__dirname,'..'),temp=fs.mkdtempSync(path.join(os.tmpdir(),'authwire-central-')),python=process.env.CODEX_PRIMARY_RUNTIME_PYTHON||'python3';
 const script=`import sys
from kaname.server import DevelopmentServer
from tests.helpers import config
from tests.test_membership import computer_membership_catalog
s=DevelopmentServer(sys.argv[1],0)
s.store.save(0,config=config())
v=computer_membership_catalog()
for n in range(101):v['users'].append({'guid':'00000001-0000-0000-0000-%012d'%n,'sid':'S-1-5-21-1-2-3-%d'%(5000+n),'sam':'user%03d'%n,'name':'Test User %03d'%n,'enabled':True,'primary_group_unresolved':True})
s.store.save_directory(1,v)
print(s.server_port,flush=True)
s.serve_forever()`;
 const child=spawn(python,['-u','-c',script,temp],{cwd:root,stdio:['ignore','pipe','pipe']});let browser;
 try{
  const port=await new Promise((resolve,reject)=>{const timer=setTimeout(()=>reject(Error('fixture startup timeout')),10000);child.once('exit',code=>reject(Error('fixture exit '+code)));child.stdout.once('data',d=>{clearTimeout(timer);resolve(Number(d.toString().trim()));});child.stderr.on('data',d=>process.stderr.write(d));});
  browser=await chromium.launch({headless:true,...(process.env.KANAME_CHROMIUM?{executablePath:process.env.KANAME_CHROMIUM}:{})});
  const page=await browser.newPage({viewport:{width:1440,height:1000}}),errors=[];let writes=0;
  page.on('pageerror',e=>errors.push(e.message));page.on('request',r=>{if(r.method()==='POST'&&!r.url().includes('/api/auth/login'))writes++;});
  await page.goto('http://127.0.0.1:'+port);await page.locator('#login-user').fill('admin');await page.locator('#login-password').fill('Kaname');await page.locator('#unlock').click();await page.locator('#workspace').waitFor({state:'visible'});
  assert.equal(await page.locator('.orbit-node:visible').count(),6);
  const expanded=await page.locator('main').boundingBox();await page.locator('#nav-toggle').click();await page.waitForFunction(()=>document.querySelector('#sidebar').inert);await page.waitForTimeout(280);const collapsed=await page.locator('main').boundingBox();assert.ok(collapsed.width>expanded.width+200);assert.equal(await page.locator('#nav-toggle').getAttribute('aria-expanded'),'false');
  await page.reload();await page.locator('#workspace').waitFor({state:'visible'});assert.equal(await page.locator('#nav-toggle').getAttribute('aria-expanded'),'false');await page.locator('#nav-toggle').click();
  await page.locator('[data-nav-group=access]>.nav-heading').click();assert.equal(await page.locator('#nav-items-access').isVisible(),true);await page.keyboard.press('Escape');assert.equal(await page.locator('#nav-items-access').isVisible(),false);assert.equal(await page.locator('#nav-toggle').getAttribute('aria-expanded'),'true');
  await navigate(page,'identities');await page.waitForFunction(()=>document.querySelectorAll('#directory-users-list tbody tr').length===100);
  assert.deepEqual(await page.locator('#directory-users-list th').allTextContents(),['Ad soyad','Hesap adı','Hesap durumu','SID','İşlem']);
  await page.locator('#directory-users-next').click();await page.waitForFunction(()=>document.querySelectorAll('#directory-users-list tbody tr').length===3);assert.match(await page.locator('#directory-users-count').textContent(),/101–103/);
  await page.locator('#directory-users-query').fill('Alice');await page.locator('#directory-users-search').click();await page.waitForFunction(()=>document.querySelectorAll('#directory-users-list tbody tr').length===1);assert.match(await page.locator('#directory-users-list').textContent(),/Devre dışı/);await page.locator('#directory-users-list .identity-name').click();await page.locator('#directory-detail').waitFor({state:'visible'});await page.locator('#detail-close').click();
  await page.locator('#identity-tab-groups').click();assert.match(await page.locator('#directory-groups-list').textContent(),/<script>alert\(1\)<\/script>/);assert.equal(await page.locator('#directory-groups-list script').count(),0);assert.equal(await page.locator('#directory-groups-list tbody tr').filter({hasText:'Department'}).getByRole('button',{name:'Kuralda kullan'}).count(),0);
  await page.locator('#identity-tab-computers').click();assert.equal(await page.locator('#directory-computers-list tbody tr').count(),6);assert.equal(await page.locator('#directory-computers-list th').first().textContent(),'Bilgisayar adı');
  if(process.env.KANAME_UI_ARTIFACTS){fs.mkdirSync(process.env.KANAME_UI_ARTIFACTS,{recursive:true});await page.screenshot({path:path.join(process.env.KANAME_UI_ARTIFACTS,'central-computers-desktop.png'),fullPage:true});}
  for(const width of [390,768,1366,1920]){await page.setViewportSize({width,height:900});await page.waitForTimeout(280);assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1),true,'viewport overflow '+width+' '+JSON.stringify(await page.evaluate(()=>[...document.querySelectorAll('body *')].filter(e=>!e.closest('[hidden]')&&e.getBoundingClientRect().right>innerWidth+1).slice(0,12).map(e=>[e.tagName,e.id,e.className,e.getBoundingClientRect().right]))));}
  await page.setViewportSize({width:390,height:844});await page.locator('#nav-toggle').click();assert.equal(await page.locator('#nav-scrim').isVisible(),true);await navigate(page,'policies');assert.equal(await page.locator('#nav-toggle').getAttribute('aria-expanded'),'false');assert.equal(await page.locator('#policies').isVisible(),true);
  await navigate(page,'identities');await page.locator('#identity-tab-computers').click();if(process.env.KANAME_UI_ARTIFACTS)await page.screenshot({path:path.join(process.env.KANAME_UI_ARTIFACTS,'central-computers-mobile.png'),fullPage:true});
  assert.equal(writes,0);assert.deepEqual(errors,[]);console.log('AUTHWIRE_CENTRAL_UI_OK '+JSON.stringify({slide_and_persist:true,submenu_keyboard:true,identity_tables:true,search_pagination:true,membership_details:true,xss_safe:true,responsive:true,mutation_requests:writes}));
 }finally{if(browser)await browser.close();if(child.exitCode===null){child.kill();await new Promise(resolve=>child.once('exit',resolve));}fs.rmSync(temp,{recursive:true,force:true});}
})().catch(e=>{console.error(e);process.exitCode=1;});
