'use strict';
// Disposable local HTTP fixture: no live RADIUS, policies, CA, or directory calls.
const fs=require('node:fs'),os=require('node:os'),path=require('node:path'),assert=require('node:assert/strict');
const {spawn}=require('node:child_process');
const {chromium}=require(process.env.CODEX_PRIMARY_RUNTIME_NODE_MODULES?path.join(process.env.CODEX_PRIMARY_RUNTIME_NODE_MODULES,'playwright'):'playwright');
(async()=>{
 const root=path.resolve(__dirname,'..'),temp=fs.mkdtempSync(path.join(os.tmpdir(),'authwire-policy-ui-'));
 const python=process.env.CODEX_PRIMARY_RUNTIME_PYTHON||process.env.KANAME_PYTHON||'python3';
 const script=`import sys
from kaname.server import DevelopmentServer
from tests.helpers import config,policy
s=DevelopmentServer(sys.argv[1],0)
s.store.save(0,config=config())
group=['S-1-5-21-10-20-30-40']
wired=policy(id='wired',name='Pilot Kablolu',vlan=110,conditions=dict(group_sids=group,access_types=['wired'],nas_ips=['192.0.2.2']))
wireless=policy(id='wireless',name='Pilot Kablosuz',vlan=140,conditions=dict(group_sids=group,access_types=['wireless'],nas_ips=['192.0.2.52']))
s.store.save(1,policies=[wired,wireless])
from tests.test_membership import computer_membership_catalog
s.store.save_directory(2,computer_membership_catalog())
print(s.server_port,flush=True)
s.serve_forever()`;
 const child=spawn(python,['-u','-c',script,temp],{cwd:root,stdio:['ignore','pipe','pipe']});let browser;
 const exited=new Promise(resolve=>child.once('exit',resolve));
 try{
  let stderr='';child.stderr.on('data',d=>stderr+=d);
  const port=await new Promise((resolve,reject)=>{const timer=setTimeout(()=>reject(Error('Fixture start timeout '+stderr)),15000);child.once('error',reject);child.once('exit',c=>reject(Error('Fixture exited '+c+' '+stderr)));child.stdout.once('data',d=>{clearTimeout(timer);resolve(Number(d.toString().trim()));});});
  browser=await chromium.launch({headless:true,...(process.env.KANAME_CHROMIUM?{executablePath:process.env.KANAME_CHROMIUM}:{})});
  const context=await browser.newContext({viewport:{width:1440,height:1050}}),page=await context.newPage(),errors=[];
  let writes=0;page.on('pageerror',e=>errors.push(e.message));page.on('request',r=>{if(r.method()==='POST'&&new URL(r.url()).pathname==='/api/policies')writes++;});
  const row=id=>page.locator('[data-policy-id="'+id+'"]'),toggle=id=>row(id).locator('[data-policy-toggle]');
  async function login(p,name='admin',password='Kaname'){
   await p.goto('http://127.0.0.1:'+port);await p.locator('#login-user').fill(name);await p.locator('#login-password').fill(password);await p.locator('#unlock').click();await p.locator('#workspace').waitFor({state:'visible'});
  }
  async function policiesView(){await require('./ui_navigation.cjs').navigate(page,'policies');await page.waitForFunction(()=>networkState!==null&&!networkLoading);}
  const snapshot=()=>page.evaluate(()=>api('/api/state'));
  const save=value=>page.evaluate(value=>api('/api/policies',{expected_revision:value.revision,policies:value.policies}),value);
  async function selectRow(id){if(await row(id).locator('.policy-action-row').isHidden())await row(id).locator('.policy-summary').click();}
  async function clickToggle(id,enabled){await selectRow(id);await toggle(id).click();await page.waitForFunction(({id,enabled})=>!policySaving&&state.policies.find(p=>p.id===id)?.enabled===enabled,{id,enabled});}
  async function decision(access_type){return page.evaluate(async access_type=>(await api('/api/simulate',{authenticated:true,directory_available:true,account_enabled:true,domain_device:true,group_sids:['S-1-5-21-10-20-30-40'],access_type,nas_ip:access_type==='wired'?'192.0.2.2':'192.0.2.52',eap_method:'EAP-TLS'})).decision,access_type);}
  await login(page);await policiesView();
  assert.match(await page.locator('#panel-version').textContent(),/0\.14\.0-dev\.19/);
  const original=await snapshot();assert.equal((await decision('wireless')).vlan,140);
  assert.deepEqual(await page.locator('#policy-list th').allTextContents(),['Kural Adı','Erişim Türü','Kullanıcı/Grup','VLAN','Karar','Durum']);
  const toolbar=await page.locator('.policy-toolbar').boundingBox(),create=await page.locator('#new-policy').boundingBox(),search=await page.locator('#policy-query').boundingBox();
  assert.ok(create.x+create.width<search.x&&Math.abs(create.y+create.height/2-search.y-search.height/2)<3,'Create button must sit immediately left of search');
  assert.ok(search.width<=340&&search.width<toolbar.width*.6,'Search stays compact on desktop');
  assert.equal(await page.locator('.policy-action-row:visible').count(),0);
  await selectRow('wireless');
  assert.deepEqual(await row('wireless').locator('.policy-action-row button').allTextContents(),['Düzenle','Devre dışı bırak','Sil']);
  assert.equal(await row('wireless').locator('.policy-summary').evaluate(el=>el.nextElementSibling.classList.contains('policy-action-row')),true);
  await selectRow('wired');assert.equal(await row('wireless').locator('.policy-action-row').isHidden(),true);assert.equal(await page.locator('.policy-action-row:visible').count(),1);
  await row('wired').locator('.policy-summary').focus();await page.keyboard.press('Escape');assert.equal(await page.locator('.policy-action-row:visible').count(),0);
  await page.keyboard.press('Enter');assert.equal(await row('wired').locator('.policy-action-row').isVisible(),true);
  const columns=await row('wired').locator('.policy-summary td').evaluateAll(cells=>cells.map(el=>({x:el.getBoundingClientRect().x,width:el.getBoundingClientRect().width})));
  const headings=await page.locator('#policy-list th').evaluateAll(cells=>cells.map(el=>({x:el.getBoundingClientRect().x,width:el.getBoundingClientRect().width})));
  headings.forEach((h,i)=>assert.ok(Math.abs(h.x-columns[i].x)<1&&Math.abs(h.width-columns[i].width)<1,'Each value must align with its heading'));
  for(const [query,id]of [['140','wireless'],['kablosuz','wireless'],['Pilot Kablolu','wired']]){await page.locator('#policy-query').fill(query);assert.equal(await page.locator('[data-policy-id]').count(),1);assert.equal(await row(id).count(),1);}
  await page.locator('#policy-query').fill('no-policy-matches');assert.equal(await page.locator('[data-policy-id]').count(),0);assert.equal(await page.locator('#policy-list th').count(),6);assert.match(await page.locator('.policy-empty').textContent(),/eşleşen kural bulunamadı/);
  await page.locator('#policy-query').fill('');assert.equal(await page.locator('[data-policy-id]').count(),2);assert.equal(writes,0);assert.deepEqual((await snapshot()).policies,original.policies);
  await page.locator('#new-policy').click();await page.locator('#policy-editor').waitFor({state:'visible'});assert.equal(await page.locator('#policy-editor').evaluate(el=>el.open),true);assert.equal(await page.locator('#policy-name').inputValue(),'');await page.locator('#cancel-policy').click();
  if(process.env.KANAME_UI_ARTIFACTS){fs.mkdirSync(process.env.KANAME_UI_ARTIFACTS,{recursive:true});await selectRow('wireless');await page.screenshot({path:path.join(process.env.KANAME_UI_ARTIFACTS,'policy-table-desktop.png'),fullPage:true,animations:'disabled'});await page.setViewportSize({width:390,height:844});assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));await page.screenshot({path:path.join(process.env.KANAME_UI_ARTIFACTS,'policy-table-mobile.png'),fullPage:true,animations:'disabled'});await page.setViewportSize({width:1440,height:1050});}

  await clickToggle('wireless',false);
  let current=await snapshot();assert.deepEqual(current.policies,original.policies.map(p=>p.id==='wireless'?{...p,enabled:false}:p));assert.deepEqual(current.config,original.config);
  assert.match(await row('wireless').textContent(),/VLAN 140.*Devre dışı/);assert.equal((await decision('wireless')).reason,'NO_MATCHING_POLICY');assert.equal((await decision('wired')).vlan,110);
  await page.reload();await page.locator('#workspace').waitFor({state:'visible'});await policiesView();assert.equal(await toggle('wireless').textContent(),'Etkinleştir');
  // Editing a disabled rule must not silently enable it or lose its VLAN/selectors.
  await selectRow('wireless');await row('wireless').getByRole('button',{name:'Düzenle',exact:true}).click();await page.waitForFunction(()=>!networkLoading&&document.getElementById('policy-vlan').value==='140'&&policySelected.size===1);
  assert.equal(await toggle('wired').isDisabled(),true);await page.locator('#add-policy').click();await page.waitForFunction(()=>!policySaving&&editingPolicy==='');
  assert.deepEqual((await snapshot()).policies.find(p=>p.id==='wireless'),{...original.policies.find(p=>p.id==='wireless'),enabled:false});
  await clickToggle('wireless',true);assert.equal((await decision('wireless')).vlan,140);
  // Hold a real save, double click through the DOM, and assert exactly one POST.
  let release,seen;const gate=new Promise(r=>release=r),arrived=new Promise(r=>seen=r);const count=writes;
  await page.route('**/api/policies',async route=>{seen();await gate;await route.continue();});
  await toggle('wireless').click();await arrived;assert.equal(await page.locator('#add-policy').isDisabled(),true);assert.equal(await toggle('wired').isDisabled(),true);
  await toggle('wireless').evaluate(b=>{b.click();b.click();});release();await page.waitForFunction(()=>!policySaving&&!state.policies.find(p=>p.id==='wireless').enabled);await page.unroute('**/api/policies');assert.equal(writes,count+1);
  await clickToggle('wireless',true);
  // A failed POST is never replayed; the row remains at the persisted state.
  const beforeFailure=await snapshot(),failureCount=writes;
  await page.route('**/api/policies',r=>r.fulfill({status:503,json:{error:'STORE_BUSY'}}));await toggle('wireless').click();await page.waitForFunction(()=>!policySaving&&document.getElementById('message').dataset.tone==='error');await page.unroute('**/api/policies');
  assert.equal(writes,failureCount+1);assert.deepEqual((await snapshot()).policies,beforeFailure.policies);assert.equal(await toggle('wireless').textContent(),'Devre dışı bırak');
  // Another administrator's newer save wins. A stale toggle cannot overwrite it.
  current=await snapshot();current.policies[0].name='Concurrent wired edit';await save(current);
  await toggle('wireless').click();await page.waitForFunction(()=>!policySaving&&state.policies[0].name==='Concurrent wired edit');assert.equal((await snapshot()).policies.find(p=>p.id==='wireless').enabled,true);
  // Re-enabling a conflicting disabled rule returns 409 and changes nothing.
  current=await snapshot();const conflict={...current.policies.find(p=>p.id==='wireless'),id:'conflict',name:'Conflicting wireless',enabled:false,vlan:110};current.policies.push(conflict);await save(current);await page.evaluate(()=>refresh());
  const beforeConflict=await snapshot();await selectRow('conflict');await toggle('conflict').click();await page.waitForFunction(()=>!policySaving&&!document.getElementById('conflict-alert').hidden);
  assert.deepEqual((await snapshot()).policies,beforeConflict.policies);assert.equal((await snapshot()).revision,beforeConflict.revision);assert.equal(await toggle('conflict').textContent(),'Etkinleştir');
  // Existing server-side write and CSRF boundaries also protect the new control.
  assert.equal(await page.evaluate(async()=>{const s=await api('/api/state');return (await fetch('/api/policies',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({expected_revision:s.revision,policies:s.policies})})).status;}),403);
  await page.evaluate(async()=>{let s=await api('/api/system');await api('/api/system/users/save',{expected_revision:s.revision,user:{id:'',username:'reader',profile_id:s.profiles.find(p=>p.mode==='Admin_ReadOnly').id,password:'fixture-policy-read-42',enabled:true}});});
  const readerContext=await browser.newContext(),reader=await readerContext.newPage();await login(reader,'reader','fixture-policy-read-42');await require('./ui_navigation.cjs').navigate(reader,'policies');await reader.waitForFunction(()=>networkState!==null&&!networkLoading);
  assert.equal(await reader.locator('[data-policy-toggle]').count(),0);assert.equal(await reader.locator('[data-policy-id="wireless"] .object-status').textContent(),'Etkin');
  assert.equal(await reader.evaluate(async()=>{const s=await api('/api/state');return (await fetch('/api/policies',{method:'POST',headers:{'Content-Type':'application/json','X-Kaname-CSRF':csrf},body:JSON.stringify({expected_revision:s.revision,policies:s.policies.map(p=>({...p,enabled:false}))})})).status;}),403);
  assert.deepEqual((await snapshot()).policies,beforeConflict.policies);
  // Real modal saves, typed multi-selection, cancellation and failure recovery.
  assert.equal(await row('wired').locator('.policy-summary td').nth(0).locator('.object-status').count(),0);
  assert.equal(await row('wired').locator('.policy-summary td').nth(5).textContent(),'Etkin');
  await page.locator('#new-policy').click();await page.locator('#policy-editor').waitFor({state:'visible'});
  assert.deepEqual(await page.locator('.rule-fields>label').allTextContents(),['Kural Adı','Erişim Türü','Kullanıcı/Grup','VLAN','Karar','Etkin/Devre Dışı']);
  await page.locator('#policy-name').fill('Selected computers');await page.locator('#policy-access').selectOption('wireless');await page.locator('#policy-vlan').selectOption('140');await page.locator('#policy-enabled').selectOption('false');
  await page.locator('#policy-kind').selectOption('computer');await page.locator('#policy-target-results input').first().waitFor();
  const modalBox=await page.locator('#policy-editor').boundingBox(),pickerBox=await page.locator('#policy-picker').boundingBox();assert.ok(pickerBox.x>modalBox.x&&pickerBox.width<modalBox.width*.9,'Picker leaves part of the modal visible');
  await page.locator('#policy-target-results input').nth(0).check();await page.locator('#policy-target-results input').nth(1).check();
  await page.locator('#policy-target-query').fill('LAB-PC01');await page.locator('#policy-target-search').click();await page.waitForFunction(()=>!policyTargetBusy);assert.equal(await page.locator('#policy-target-results input').count(),1);assert.equal(await page.locator('#policy-target-results input').isChecked(),true);
  if(process.env.KANAME_UI_ARTIFACTS)await page.screenshot({path:path.join(process.env.KANAME_UI_ARTIFACTS,'policy-identity-picker.png'),animations:'disabled'});
  await page.locator('#policy-picker-done').click();assert.equal(await page.locator('#policy-picker').isHidden(),true);assert.equal(await page.locator('#policy-selected button').count(),2);
  await page.locator('#policy-kind').selectOption('user');await page.locator('#policy-target-results input').first().waitFor();await page.locator('#policy-target-results input').first().check();await page.keyboard.press('Escape');assert.equal(await page.locator('#policy-selected button').count(),2);
  if(process.env.KANAME_UI_ARTIFACTS)await page.screenshot({path:path.join(process.env.KANAME_UI_ARTIFACTS,'policy-modal.png'),animations:'disabled'});
  const saveCount=writes;await page.locator('#add-policy').click();await page.waitForFunction(()=>!policySaving&&!document.getElementById('policy-editor').open);assert.equal(writes,saveCount+1);
  const added=(await snapshot()).policies.find(p=>p.name==='Selected computers');assert.equal(added.enabled,false);assert.deepEqual(added.conditions.access_types,['wireless']);assert.equal(added.conditions.group_sids.length,2);assert.equal(added.vlan,140);
  await page.reload();await page.locator('#workspace').waitFor({state:'visible'});await policiesView();assert.match(await row(added.id).locator('.policy-summary td').nth(2).textContent(),/LAB-PC01/);
  await selectRow(added.id);await row(added.id).getByRole('button',{name:'Düzenle',exact:true}).click();await page.locator('#policy-editor').waitFor({state:'visible'});assert.equal(await page.locator('#policy-selected button').count(),2);
  await page.route('**/api/policies',r=>r.fulfill({status:503,json:{error:'STORE_BUSY'}}));await page.locator('#add-policy').click();await page.waitForFunction(()=>!policySaving&&document.getElementById('policy-form-error').textContent.length>0);assert.equal(await page.locator('#policy-editor').isVisible(),true);assert.equal(await page.locator('#policy-selected button').count(),2);await page.unroute('**/api/policies');await page.locator('#cancel-policy').click();
  await page.locator('#new-policy').click();await page.locator('#policy-editor').waitFor({state:'visible'});await page.locator('#policy-kind').selectOption('group');await page.locator('#policy-target-results input').first().waitFor();await page.locator('#policy-target-results input').first().check();await page.locator('#policy-picker-done').click();assert.equal(await page.locator('#policy-selected button').count(),1);await page.keyboard.press('Escape');assert.equal(await page.locator('#policy-editor').isHidden(),true);
  assert.deepEqual((await snapshot()).policies.find(p=>p.id===added.id),added);
  // Delete is confirmed, revision-bound, and never erases a concurrent edit.
  await selectRow(added.id);await row(added.id).getByRole('button',{name:'Sil',exact:true}).click();assert.match(await page.locator('#delete-policy-description').textContent(),/Selected computers/);const beforeCancel=writes;await page.locator('#delete-policy-confirm button[value="cancel"]').click();assert.equal(writes,beforeCancel);assert.ok((await snapshot()).policies.some(p=>p.id===added.id));
  await row(added.id).getByRole('button',{name:'Sil',exact:true}).click();const concurrent=await snapshot();concurrent.policies.find(p=>p.id==='wired').name='Newer rule name';await save(concurrent);await page.locator('#delete-policy-submit').click();await page.waitForFunction(()=>!policySaving&&state.policies.find(p=>p.id==='wired').name==='Newer rule name');assert.ok((await snapshot()).policies.some(p=>p.id===added.id));
  const beforeDelete=await snapshot();await selectRow(added.id);await row(added.id).getByRole('button',{name:'Sil',exact:true}).click();await page.locator('#delete-policy-submit').click();await page.waitForFunction(()=>!policySaving&&!state.policies.some(p=>p.name==='Selected computers'));assert.deepEqual((await snapshot()).policies,beforeDelete.policies.filter(p=>p.id!==added.id));
  for(const width of [390,1366,1920]){await page.setViewportSize({width,height:1050});assert.ok(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth));}
  if(process.env.KANAME_UI_ARTIFACTS){fs.mkdirSync(process.env.KANAME_UI_ARTIFACTS,{recursive:true});await page.screenshot({path:path.join(process.env.KANAME_UI_ARTIFACTS,'policy-toggle.png'),fullPage:true,animations:'disabled'});}
  assert.deepEqual(errors,[]);console.log('Policy UI: aligned columns, compact search, row menus, keyboard selection, read-only filtering, new-rule button, persistence, preserved VLAN/selectors, disabled evaluation, editing, single POST, failures, stale revision, activation conflict, RBAC, CSRF and responsive layout passed.');
 }finally{if(browser)await browser.close();if(child.exitCode===null){child.kill();await exited;}fs.rmSync(temp,{recursive:true,force:true});}
})().catch(e=>{console.error(e);process.exitCode=1;});
