'use strict';
const fs=require('node:fs'),os=require('node:os'),path=require('node:path'),assert=require('node:assert/strict');
const {spawn}=require('node:child_process');
const {chromium}=require(process.env.CODEX_PRIMARY_RUNTIME_NODE_MODULES?path.join(process.env.CODEX_PRIMARY_RUNTIME_NODE_MODULES,'playwright'):'playwright');
(async()=>{
 const root=path.resolve(__dirname,'..'),temp=fs.mkdtempSync(path.join(os.tmpdir(),'authwire-local-groups-ui-'));
 const python=process.env.CODEX_PRIMARY_RUNTIME_PYTHON||process.env.KANAME_PYTHON||'python3';
 const script=`import sys,uuid
from kaname.server import DevelopmentServer
from tests.helpers import config
from tests.test_membership import membership_catalog
s=DevelopmentServer(sys.argv[1],0);s.store.save(0,config=config())
s.operations.save_network(1,dict(vlans=[dict(id=50,name='Pilot 50',description=''),dict(id=60,name='Pilot 60',description='')],radius_clients=[],authentication_port=1812,accounting_port=1813))
c=membership_catalog();c['users'][0]['enabled']=True
for i in range(110):
 c['users'].append(dict(guid=str(uuid.UUID(int=10000+i)),sid='S-1-5-21-1-2-3-'+str(2000+i),name='Extra User '+str(i),sam='extra'+str(i),enabled=True,primary_group_unresolved=True))
s.store.save_directory(2,c)
print(s.server_port,flush=True);s.serve_forever()`;
 const child=spawn(python,['-u','-c',script,temp],{cwd:root,stdio:['ignore','pipe','pipe']});let browser;const exited=new Promise(r=>child.once('exit',r));
 try{
  let stderr='';child.stderr.on('data',d=>stderr+=d);
  const port=await new Promise((resolve,reject)=>{const timer=setTimeout(()=>reject(Error('Group fixture timeout '+stderr)),15000);child.once('error',reject);child.once('exit',c=>reject(Error('Fixture exit '+c+' '+stderr)));child.stdout.once('data',d=>{clearTimeout(timer);resolve(Number(d.toString().trim()));});});
  browser=await chromium.launch({headless:true,...(process.env.KANAME_CHROMIUM?{executablePath:process.env.KANAME_CHROMIUM}:{})});
  const context=await browser.newContext({viewport:{width:1440,height:1100}}),page=await context.newPage(),errors=[];let writes=0;
  page.on('pageerror',e=>errors.push(e.message));page.on('request',r=>{if(r.method()==='POST'&&new URL(r.url()).pathname.startsWith('/api/access-groups/'))writes++;});page.on('dialog',d=>d.accept());
  async function login(p,name='admin',password='Kaname'){await p.goto('http://127.0.0.1:'+port);await p.locator('#login-user').fill(name);await p.locator('#login-password').fill(password);await p.locator('#unlock').click();await p.locator('#workspace').waitFor({state:'visible'});}
  const nav=id=>require('./ui_navigation.cjs').navigate(page,id);
  async function ready(){await page.waitForFunction(()=>!accessGroupBusy&&accessGroupPage!==null);}
  async function newGroup(name){await page.locator('#access-group-new').click();await page.locator('#access-group-editor').waitFor({state:'visible'});await page.locator('#access-group-name').fill(name);}
  async function picker(){await page.locator('#access-group-pick').click();await page.waitForFunction(()=>!accessMemberBusy&&accessMemberTotal>0);}
  const account=name=>page.locator('#access-group-member-list label').filter({has:page.locator('strong',{hasText:new RegExp('^'+name+'$')})}).locator('input');
  async function saveGroup(){await page.locator('#access-group-save').click();await page.locator('#access-group-editor').waitFor({state:'hidden'});await ready();}
  async function groupRow(name){return page.locator('#access-group-list tbody tr').filter({has:page.getByRole('button',{name,exact:true})});}
  await login(page);await nav('identities');await ready();
  const initial=await page.evaluate(()=>api('/api/directory/catalog?kind=users'));
  await newGroup('VLAN50 Users');await picker();await account('Alice').check();
  await page.locator('#access-group-member-next').click();await page.waitForFunction(()=>!accessMemberBusy&&accessMemberOffset===100);
  await page.locator('#access-group-member-list input').first().check();
  await page.locator('#access-group-member-previous').click();await page.waitForFunction(()=>!accessMemberBusy&&accessMemberOffset===0);assert.equal(await account('Alice').isChecked(),true);
  await page.locator('#access-group-picker-done').click();assert.equal(await page.locator('#access-group-selected button').count(),2);await saveGroup();
  assert.equal((await page.evaluate(()=>accessGroupPage.items[0])).member_count,2);
  const alpha=await page.evaluate(()=>accessGroupPage.items[0].id);
  await page.reload();await page.locator('#workspace').waitFor({state:'visible'});await nav('identities');await ready();assert.equal((await page.evaluate(()=>accessGroupPage.items[0])).member_count,2);
  await newGroup('VLAN60 Users');await picker();await account('Alice').check();await page.locator('#access-group-picker-done').click();
  await page.locator('#access-group-save').click();await page.locator('#access-group-error').filter({hasText:'VLAN50 Users'}).waitFor();await page.waitForFunction(()=>!accessGroupBusy);assert.equal(await page.locator('#access-group-editor').isVisible(),true);assert.equal(await page.evaluate(()=>accessGroupPage.items.length),1);
  await page.locator('#access-group-selected button').filter({hasText:'Alice'}).click();await picker();await account('Bob').check();await page.locator('#access-group-picker-done').click();await saveGroup();
  assert.equal(await page.evaluate(()=>accessGroupPage.items.length),2);
  await nav('policies');await page.waitForFunction(()=>networkState!==null&&!networkLoading);await page.locator('#new-policy').click();await page.locator('#policy-editor').waitFor({state:'visible'});
  await page.locator('#policy-name').fill('Local group VLAN50');await page.locator('#policy-vlan').selectOption('50');await page.locator('#policy-kind').selectOption('local_group');await page.waitForFunction(()=>!policyTargetBusy&&policyTargetTotal===2);
  await page.locator('#policy-target-results label').filter({hasText:'VLAN50 Users'}).locator('input').check();await page.locator('#policy-picker-done').click();await page.locator('#add-policy').click();await page.locator('#policy-editor').waitFor({state:'hidden'});await page.waitForFunction(()=>!policySaving);
  const saved=await page.evaluate(()=>state.policies[0]);assert.deepEqual(saved.conditions.local_group_ids,[alpha]);assert.deepEqual(saved.conditions.group_sids,[]);assert.equal(saved.constraints.require_domain_device,false);assert.equal(saved.vlan,50);
  assert.match(await page.locator('#policy-list').textContent(),/VLAN50 Users/);
  // Existing rule edits retain the local selector rather than becoming wildcard.
  await page.locator('.policy-summary').click();await page.locator('.policy-action-row').getByRole('button',{name:'Düzenle',exact:true}).click();await page.locator('#policy-editor').waitFor({state:'visible'});assert.match(await page.locator('#policy-selected').textContent(),/VLAN50 Users/);await page.locator('#policy-name').fill('Local group renamed rule');await page.locator('#add-policy').click();await page.locator('#policy-editor').waitFor({state:'hidden'});await page.waitForFunction(()=>!policySaving);
  assert.deepEqual(await page.evaluate(()=>state.policies[0].conditions.local_group_ids),[alpha]);
  await nav('identities');await ready();await (await groupRow('VLAN50 Users')).getByRole('button',{name:'Sil',exact:true}).click();await page.locator('#message').filter({hasText:'bir kuralda'}).waitFor();await ready();assert.equal(await page.evaluate(()=>accessGroupPage.items.length),2);
  // Explicit old-group removal is required before the same account can move.
  await (await groupRow('VLAN50 Users')).getByRole('button',{name:'Düzenle',exact:true}).click();await page.locator('#access-group-editor').waitFor({state:'visible'});await page.locator('#access-group-selected button').filter({hasText:'Alice'}).click();await saveGroup();
  await (await groupRow('VLAN60 Users')).getByRole('button',{name:'Düzenle',exact:true}).click();await page.locator('#access-group-editor').waitFor({state:'visible'});await picker();await account('Alice').check();await page.locator('#access-group-picker-done').click();await saveGroup();
  const current=await page.evaluate(()=>api('/api/directory/catalog?kind=users'));assert.deepEqual(current,initial);
  // Render untrusted group names strictly as text, including the rule picker.
  const evil='<img src=x onerror="window.groupXss=true">';await newGroup(evil);await saveGroup();assert.equal(await page.evaluate(()=>window.groupXss),undefined);assert.equal(await page.locator('#access-group-list img').count(),0);
  const system=await page.evaluate(()=>api('/api/system')),profile=system.profiles.find(x=>x.mode==='Admin_ReadOnly');
  await page.evaluate(async({revision,profile})=>api('/api/system/users/save',{expected_revision:revision,user:{id:'',username:'reader',profile_id:profile,password:'GroupReadOnlyPassword42',enabled:true}}),{revision:system.revision,profile:profile.id});
  const reader=await context.newPage();await login(reader,'reader','GroupReadOnlyPassword42');await require('./ui_navigation.cjs').navigate(reader,'identities');await reader.waitForFunction(()=>accessGroupPage?.items.length===3);assert.equal(await reader.locator('#access-group-new').isHidden(),true);await reader.getByRole('button',{name:'VLAN50 Users',exact:true}).click();await reader.locator('#access-group-editor').waitFor({state:'visible'});assert.equal(await reader.locator('#access-group-save').isHidden(),true);assert.equal(await reader.locator('#access-group-pick').isDisabled(),true);
  const rejected=await reader.evaluate(async()=>{try{await api('/api/access-groups/delete',{expected_revision:accessGroupPage.revision,id:accessGroupPage.items[0].id});return false;}catch(error){return error.status===403;}});assert.equal(rejected,true);await reader.close();
  const artifact=process.env.KANAME_UI_ARTIFACTS||'ui-artifacts';fs.mkdirSync(artifact,{recursive:true});await page.screenshot({path:path.join(artifact,'access-groups-desktop.png'),fullPage:true});
  await page.setViewportSize({width:390,height:844});assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1));await newGroup('Mobile draft');await picker();await page.screenshot({path:path.join(artifact,'access-groups-mobile-picker.png'),fullPage:true});await page.keyboard.press('Escape');assert.equal(await page.locator('#access-group-picker').isHidden(),true);await page.keyboard.press('Escape');
  assert.deepEqual(errors,[]);assert.ok(writes>=7);
  console.log('AUTHWIRE_ACCESS_GROUPS_UI_OK '+JSON.stringify({group_crud:true,member_pagination:true,reload_persistence:true,duplicate_blocked_with_old_group:true,explicit_remove_then_move:true,policy_selector_persisted:true,in_use_delete_blocked:true,ad_membership_unchanged:true,readonly_enforced:true,xss_safe:true,mobile_picker:true}));
 }finally{if(browser)await browser.close();child.kill();await exited;fs.rmSync(temp,{recursive:true,force:true});}
})().catch(e=>{console.error(e);process.exitCode=1;});
