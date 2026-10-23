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
initialize(s.store.root)
s.operations.network=lambda:{'radius_clients':[{'ip':'192.0.2.2','name':'SW-PILOT','access_type':'wired'},{'ip':'192.0.2.3','name':'AP-PILOT','access_type':'wireless'}],'vlans':[]}
now=datetime.now(timezone.utc)
for n in range(205):
 yes=n%3!=0
 append(s.store.root,event(n,nas_ip='192.0.2.'+str(2+n%3),at=(now-timedelta(hours=n%48,seconds=10)).isoformat(timespec='milliseconds').replace('+00:00','Z'),response_code=2 if yes else 3,reason='POLICY_ALLOW' if yes else 'POLICY_DENY',vlan=110 if yes else None))
s.services.status=lambda:{'available':True,'checked_at':now.isoformat(),'busy':False,'operations':[],'backup':{'available':True,'last_success_at':now.isoformat(),'last_run_succeeded':True,'archive_read_verified':True,'sqlite_integrity_verified':True},'services':[{'id':'radius','health':'running','active_state':'active','listener_present':True}]}
print(s.server_port,flush=True)
s.serve_forever()`;
 const child=spawn(python,['-u','-c',script,temp],{cwd:root,stdio:['ignore','pipe','pipe']});let browser;
 try{
  const port=await new Promise((resolve,reject)=>{const t=setTimeout(()=>reject(Error('start timeout')),10000);child.once('error',reject);child.once('exit',c=>reject(Error('fixture exited '+c)));child.stdout.once('data',d=>{clearTimeout(t);resolve(Number(d.toString().trim()));});});child.stderr.on('data',d=>process.stderr.write(d));
  browser=await chromium.launch({headless:true,...(process.env.KANAME_CHROMIUM?{executablePath:process.env.KANAME_CHROMIUM}:{})});
  const context=await browser.newContext({viewport:{width:1440,height:1100},timezoneId:'Europe/Istanbul'}),page=await context.newPage(),errors=[];let actions=0;
  page.on('pageerror',e=>errors.push(e.message));page.on('request',r=>{if(r.method()==='POST'&&/services\/action|power\/action/.test(r.url()))actions++;});
  await page.goto('http://127.0.0.1:'+port);await page.locator('#login-user').fill('admin');await page.locator('#login-password').fill('Kaname');await page.locator('#unlock').click();await page.locator('#workspace').waitFor({state:'visible'});await page.waitForFunction(()=>!dashboardLoading&&dashboardData?.events?.total===205);
  assert.equal(await page.locator('#dashboard-accept').textContent(),'136');assert.equal(await page.locator('#dashboard-reject').textContent(),'69');assert.equal(await page.locator('#dashboard-recent tr').count(),8);assert.equal(await page.locator('#dashboard-nas button').count(),3);
  assert.match(await page.locator('#dashboard-types').textContent(),/Türü belirlenemedi/);await page.waitForFunction(()=>document.querySelector('#dashboard-backup').textContent==='Başarılı');
  await page.locator('#dashboard-reject-card').click();await page.waitForFunction(()=>!accessLoading&&accessPage?.events?.length===69);assert.equal(await page.locator('#access-result').inputValue(),'reject');assert.ok(await page.evaluate(()=>accessPage.events.every(e=>e.response_code===3)));assert.equal(await page.evaluate(()=>accessDashboardRange.watermark),'205');
  await require('./ui_navigation.cjs').navigate(page,'overview');await page.waitForFunction(()=>!dashboardLoading&&dashboardData?.events?.total===205);await page.locator('#dashboard-period').selectOption('24h');await page.waitForFunction(()=>!dashboardLoading&&dashboardData?.period==='24h');assert.ok(await page.evaluate(()=>dashboardData.events.total<205));
  assert.deepEqual(await page.locator('#dashboard-period option').evaluateAll(xs=>xs.map(x=>[x.value,x.textContent])),[['1h','Son 1 saat'],['24h','Son 24 saat'],['7d','Son 7 gün'],['30d','Son 1 ay'],['6m','Son 6 ay'],['1y','Son 1 yıl']]);
  for(const period of ['1h','6m','1y']){await page.locator('#dashboard-period').selectOption(period);await page.waitForFunction(period=>!dashboardLoading&&dashboardData?.period===period,period);assert.equal(await page.evaluate(()=>dashboardData.events.available),true);assert.equal(await page.evaluate(()=>dashboardData.events.series.reduce((n,r)=>n+r.accept+r.reject,0)),await page.evaluate(()=>dashboardData.events.total));if(period==='1h')assert.ok(await page.locator('#dashboard-trend svg text').allTextContents().then(xs=>xs.some(x=>/\d{2}:\d{2}/.test(x))));}
  await page.locator('#dashboard-period').selectOption('7d');await page.waitForFunction(()=>!dashboardLoading&&dashboardData?.period==='7d');await page.evaluate(()=>message(''));
  const colors=await page.locator('.dashboard-stat').evaluateAll(xs=>xs.map(x=>{const s=getComputedStyle(x);return [s.backgroundColor,s.color,getComputedStyle(x.querySelector('strong')).color];}));assert.equal(colors.length,4);for(const color of colors)assert.deepEqual(color,['rgb(29, 77, 115)','rgb(255, 255, 255)','rgb(255, 255, 255)']);
  assert.equal(await page.locator('.dashboard-panel,.dashboard-stat').evaluateAll(xs=>xs.every(x=>{const s=getComputedStyle(x);return !(s.borderTopWidth==='3px'&&s.borderTopColor==='rgb(181, 52, 107)');})),true);
  assert.equal(await page.locator('.dashboard-heat-cell[data-level="4"]').first().evaluate(e=>getComputedStyle(e).backgroundColor),'rgb(181, 52, 107)');
  const header=await page.locator('main>header').boundingBox(),account=await page.locator('#account-toggle').boundingBox();assert.ok(header.height<=66,'compact header');assert.ok(header.y+header.height-account.y-account.height<=14,'divider immediately below account control');

  if(process.env.KANAME_UI_ARTIFACTS){fs.mkdirSync(process.env.KANAME_UI_ARTIFACTS,{recursive:true});await page.screenshot({path:path.join(process.env.KANAME_UI_ARTIFACTS,'dashboard-analytics-desktop.png'),fullPage:true,animations:'disabled'});}
  for(const width of [390,1366,1920]){await page.setViewportSize({width,height:1000});assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1),true,'overflow '+width);if(width===390&&process.env.KANAME_UI_ARTIFACTS)await page.screenshot({path:path.join(process.env.KANAME_UI_ARTIFACTS,'dashboard-analytics-mobile.png'),fullPage:true,animations:'disabled'});}
  await page.setViewportSize({width:1440,height:1100});await page.route('**/api/dashboard*',r=>r.fulfill({status:503,json:{error:'STORE_BUSY'}}));await page.locator('#dashboard-refresh').click();await page.waitForFunction(()=>!dashboardLoading&&document.querySelector('#dashboard-feedback').textContent.includes('alınamadı'));assert.equal(await page.locator('#workspace').isVisible(),true);assert.equal(await page.locator('#dashboard-accept').textContent(),'—');await page.unroute('**/api/dashboard*');
  await page.locator('#dashboard-refresh').click();await page.waitForFunction(()=>!dashboardLoading&&dashboardData?.events?.total===205);
  let release,seen;const gate=new Promise(r=>release=r),started=new Promise(r=>seen=r);await page.route('**/api/dashboard*',async r=>{seen();await gate;await r.continue();});await page.evaluate(()=>{window.dashboardFixturePending=loadDashboard();});await started;await page.locator('#account-toggle').click();await page.locator('#logout').click();release();await page.evaluate(()=>window.dashboardFixturePending);assert.equal(await page.evaluate(()=>dashboardData),null);assert.equal(await page.locator('#dashboard-accept').textContent(),'—');assert.deepEqual(errors,[]);assert.equal(actions,0);
  console.log('AUTHWIRE_DASHBOARD_UI_OK '+JSON.stringify({full_aggregate:true,filtered_snapshot_drilldown:true,time_filter:true,six_periods:true,unified_navy_stats:true,no_pink_top_borders:true,pink_heatmap:true,compact_header:true,responsive:true,read_failure_preserves_session:true,logout_discards_pending:true,actions_executed:actions}));
 }finally{if(browser)await browser.close();child.kill();await new Promise(r=>child.once('exit',r));fs.rmSync(temp,{recursive:true,force:true});}
})().catch(e=>{console.error(e);process.exitCode=1;});
