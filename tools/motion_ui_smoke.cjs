'use strict';
// Disposable local data only. No AD, RADIUS listener, service or power action.
const fs=require('node:fs'),os=require('node:os'),path=require('node:path'),assert=require('node:assert/strict');
const {spawn}=require('node:child_process');
const {chromium}=require(process.env.CODEX_PRIMARY_RUNTIME_NODE_MODULES?path.join(process.env.CODEX_PRIMARY_RUNTIME_NODE_MODULES,'playwright'):'playwright');
(async()=>{
 const root=path.resolve(__dirname,'..'),temp=fs.mkdtempSync(path.join(os.tmpdir(),'authwire-dashboard-')),python=process.env.CODEX_PRIMARY_RUNTIME_PYTHON||process.env.KANAME_PYTHON||'python3';
 const script=`import sys
from datetime import datetime,timedelta,timezone
from kaname.server import DevelopmentServer
from kaname.radius_events import initialize,append
from tests.test_radius_events import event
s=DevelopmentServer(sys.argv[1],0)
from kaname.admin import password_hash
import uuid
with s.admin.connect() as db:
 profile=db.execute("SELECT id FROM admin_profiles WHERE mode='Admin_ReadOnly'").fetchone()[0]
 db.execute('INSERT INTO admin_users VALUES (?,?,?,?,?,?,?)',(str(uuid.uuid4()),'layout-reader','layout-reader',password_hash('fixture-layout-reader-42'),profile,1,1))
initialize(s.store.root)
s.operations.network=lambda:{'radius_clients':[{'ip':'192.0.2.2','name':'SW-PILOT','access_type':'wired'},{'ip':'192.0.2.3','name':'AP-PILOT','access_type':'wireless'}],'vlans':[]}
now=datetime.now(timezone.utc)
for n in range(205):
 yes=n%3!=0
 append(s.store.root,event(n,nas_ip='192.0.2.'+str(2+n%3),at=(now-timedelta(hours=n%48,seconds=10)).isoformat(timespec='milliseconds').replace('+00:00','Z'),response_code=2 if yes else 3,reason='POLICY_ALLOW' if yes else 'POLICY_DENY',vlan=110 if yes else None))
s.services.status=lambda:{'available':True,'checked_at':now.isoformat(),'busy':False,'operations':[],'backup':{'available':True,'last_success_at':now.isoformat(),'last_run_succeeded':True,'archive_read_verified':True,'sqlite_integrity_verified':True},'services':[{'id':'radius','health':'running','active_state':'active','listener_present':True}]}
print(s.server_port,flush=True)
s.serve_forever()`;
 const child=spawn(python,['-u','-c',script,temp],{cwd:root,stdio:['ignore','pipe','pipe']});child.stderr.on('data',d=>process.stderr.write(d));let browser;
 try{
  const port=await new Promise((resolve,reject)=>{const t=setTimeout(()=>reject(Error('start timeout')),10000);child.once('error',reject);child.once('exit',c=>reject(Error('fixture exited '+c)));child.stdout.once('data',d=>{clearTimeout(t);resolve(Number(d.toString().trim()));});});
  browser=await chromium.launch({headless:true,...(process.env.KANAME_CHROMIUM?{executablePath:process.env.KANAME_CHROMIUM}:{})});
  const context=await browser.newContext({viewport:{width:1440,height:1100},timezoneId:'Europe/Istanbul'}),page=await context.newPage(),errors=[];let actions=0;
  page.on('pageerror',e=>errors.push(e.message));page.on('request',r=>{if(r.method()==='POST'&&!new URL(r.url()).pathname.startsWith('/api/auth/'))actions++;});
  async function login(name='admin',password='Kaname'){
   await page.goto('http://127.0.0.1:'+port);await page.locator('#login-user').fill(name);await page.locator('#login-password').fill(password);await page.locator('#unlock').click();await page.locator('#workspace').waitFor({state:'visible'});await page.waitForFunction(()=>!dashboardLoading&&dashboardData?.events?.total===205);
  }
  async function logout(){await page.locator('#account-toggle').click();await page.locator('#logout').click();await page.locator('#login-form').waitFor({state:'visible'});}
  const widget=id=>page.locator('[data-widget="'+id+'"]');
  await login();assert.equal(await page.locator('.dashboard-widget').count(),10);
  assert.equal(await page.locator('.dashboard-area').count(),2);assert.equal(await page.locator('.dashboard-donut-segment').count(),3);
  assert.equal(await page.locator('.dashboard-donut-svg').evaluate(svg=>{const outer=svg.getBoundingClientRect();return [...svg.querySelectorAll('.dashboard-donut-segment')].every(el=>{const b=el.getBoundingClientRect();return b.x>=outer.x&&b.y>=outer.y&&b.right<=outer.right&&b.bottom<=outer.bottom;});}),true,'donut arcs remain centered inside chart');
  assert.equal(await page.locator('.orbit-hub').evaluate(e=>getComputedStyle(e,':before').display),'none');
  await page.locator('.dashboard-point').first().focus();assert.equal(await page.locator('.dashboard-chart-tip').isVisible(),true);await page.locator('#dashboard-refresh').focus();
  const circle=page.locator('[data-nav-group=monitoring]>.nav-heading');await circle.scrollIntoViewIfNeeded();const normal=await circle.boundingBox();await circle.hover();await page.waitForTimeout(250);const grown=await circle.boundingBox();assert.ok(grown.width>normal.width+5);assert.ok(normal.width<85);
  await page.setViewportSize({width:1440,height:650});await circle.click();await page.waitForTimeout(260);const anchor=await circle.boundingBox(),menu=await page.locator('#nav-items-monitoring').boundingBox();assert.ok(menu.x>=anchor.x+anchor.width-3&&menu.x<anchor.x+anchor.width+25,'menu beside its heading');assert.ok(menu.y<=anchor.y+anchor.height&&menu.y+menu.height>=anchor.y,'menu vertically near heading');assert.ok(menu.y>=0&&menu.y+menu.height<=652);
  if(process.env.KANAME_UI_ARTIFACTS){fs.mkdirSync(process.env.KANAME_UI_ARTIFACTS,{recursive:true});await page.screenshot({path:path.join(process.env.KANAME_UI_ARTIFACTS,'motion-menu-anchored.png'),animations:'disabled'});}
  await page.keyboard.press('Escape');await page.setViewportSize({width:1440,height:1100});
  for(const id of ['accept','reject','certificates','expiring','trend','distribution','nas','density','recent','health']){await widget(id).hover();await page.waitForTimeout(40);assert.notEqual(await widget(id).locator('.widget-body').evaluate(e=>getComputedStyle(e).transform),'none');}
  await page.locator('#dashboard-layout-edit').click();assert.equal(await page.locator('.widget-handle:visible').count(),10);assert.equal(await page.locator('.widget-resize:visible').count(),10);
  const original=await page.evaluate(()=>structuredClone(dashboardLayout));
  await widget('accept').locator('.widget-handle').focus();await page.keyboard.press('ArrowRight');assert.equal(await page.locator('.dashboard-widget').nth(1).getAttribute('data-widget'),'accept');
  await widget('trend').locator('.widget-resize').focus();await page.keyboard.press('ArrowRight');await page.keyboard.press('ArrowDown');assert.deepEqual(await page.evaluate(()=>{const x=dashboardLayout.find(x=>x.id==='trend');return [x.cols,x.rows];}),[9,11]);
  // Pointer resize keeps capture while its CSS grid size changes.
  await widget('accept').scrollIntoViewIfNeeded();const resize=await widget('accept').locator('.widget-resize').boundingBox();await page.mouse.move(resize.x+12,resize.y+12);await page.mouse.down();await page.mouse.move(resize.x+112,resize.y+52,{steps:8});await page.mouse.up();assert.ok(await page.evaluate(()=>dashboardLayout.find(x=>x.id==='accept').cols)>3);assert.ok(await page.evaluate(()=>dashboardLayout.find(x=>x.id==='accept').rows)>4);
  // A pointer move changes order without triggering an underlying drill-down.
  const grip=await widget('reject').locator('.widget-handle').boundingBox(),target=await widget('expiring').boundingBox();await page.mouse.move(grip.x+25,grip.y+15);await page.mouse.down();await page.mouse.move(target.x+target.width/2,target.y+target.height/2,{steps:10});await page.mouse.up();assert.equal(await page.locator('#overview').isVisible(),true);assert.notEqual(await page.evaluate(()=>dashboardLayout[0].id),'reject');
  const edited=await page.evaluate(()=>structuredClone(dashboardLayout));await page.locator('#dashboard-layout-save').click();assert.equal(await page.locator('.widget-handle:visible').count(),0);
  const key=await page.evaluate(()=>dashboardLayoutKey()),saved=await page.evaluate(key=>JSON.parse(localStorage.getItem(key)),key);assert.deepEqual(saved,{version:1,items:edited});
  await page.reload();await page.waitForFunction(()=>!dashboardLoading&&dashboardData?.events?.total===205);assert.deepEqual(await page.evaluate(()=>dashboardLayout),edited);
  if(process.env.KANAME_UI_ARTIFACTS)await page.screenshot({path:path.join(process.env.KANAME_UI_ARTIFACTS,'motion-dashboard-custom.png'),fullPage:true,animations:'disabled'});
  await page.locator('#dashboard-layout-edit').click();await page.locator('#dashboard-layout-default').click();await page.locator('#dashboard-layout-cancel').click();assert.deepEqual(await page.evaluate(()=>dashboardLayout),edited);
  await page.locator('#dashboard-layout-edit').click();await widget('accept').locator('.widget-step').last().click();await page.evaluate(()=>{window.motionSetItem=Storage.prototype.setItem;Storage.prototype.setItem=function(){throw new DOMException('fixture storage denied','SecurityError');};});await page.locator('#dashboard-layout-save').click();assert.equal(await page.locator('#dashboard-layout-save').isVisible(),true);assert.match(await page.locator('#dashboard-layout-status').textContent(),/kaydedilemedi/);await page.evaluate(()=>{Storage.prototype.setItem=window.motionSetItem;delete window.motionSetItem;});await page.locator('#dashboard-layout-cancel').click();
  await logout();await login('layout-reader','fixture-layout-reader-42');assert.deepEqual(await page.evaluate(()=>dashboardLayout),original);assert.notEqual(await page.evaluate(()=>dashboardLayoutKey()),key);await logout();await login();assert.deepEqual(await page.evaluate(()=>dashboardLayout),edited);
  await page.evaluate(key=>localStorage.setItem(key,'{"version":1,"items":[{"id":"<script>bad</script>","cols":999999,"rows":999999}]}'),key);await page.reload();await page.waitForFunction(()=>!dashboardLoading&&dashboardData?.events?.total===205);assert.deepEqual(await page.evaluate(()=>dashboardLayout),original);
  await page.locator('#dashboard-layout-edit').click();await page.locator('#dashboard-layout-default').click();await page.locator('#dashboard-layout-save').click();
  for(const width of [390,768,1366,1920]){await page.setViewportSize({width,height:1000});await page.waitForTimeout(300);assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1),true,'layout overflow '+width);}
  await page.setViewportSize({width:390,height:844});await page.waitForTimeout(300);await page.locator('#nav-toggle').click();await page.locator('[data-nav-group=system]>.nav-heading').click();await page.waitForTimeout(250);const mobileMenu=await page.locator('#nav-items-system').boundingBox();assert.ok(mobileMenu.x>=0&&mobileMenu.x+mobileMenu.width<=392&&mobileMenu.y>=0&&mobileMenu.y+mobileMenu.height<=846);await page.keyboard.press('Escape');await page.keyboard.press('Escape');
  if(process.env.KANAME_UI_ARTIFACTS)await page.screenshot({path:path.join(process.env.KANAME_UI_ARTIFACTS,'motion-dashboard-mobile.png'),fullPage:true,animations:'disabled'});
  await page.emulateMedia({reducedMotion:'reduce'});assert.equal(await widget('accept').evaluate(e=>getComputedStyle(e).animationName),'none');
  assert.deepEqual(errors,[]);assert.equal(actions,0);console.log('AUTHWIRE_MOTION_LAYOUT_UI_OK '+JSON.stringify({anchored_menus:true,compact_hover_nodes:true,ten_moving_widgets:true,keyboard_and_pointer_reorder:true,keyboard_and_pointer_resize:true,persistence:true,per_account:true,cancel_and_reset:true,invalid_storage_rejected:true,storage_failure_visible:true,responsive:true,reduced_motion:true,server_mutations:0}));

 }finally{if(browser)await browser.close();if(child.exitCode===null){child.kill();await new Promise(r=>child.once('exit',r));}fs.rmSync(temp,{recursive:true,force:true});}
})().catch(e=>{console.error(e);process.exitCode=1;});
