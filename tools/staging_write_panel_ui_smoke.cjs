// Browser contract checks; API/worker replies are explicit fixtures, no AD.
const {chromium}=require('playwright');
const fs=require('node:fs');
const assert=require('node:assert/strict');
(async()=>{
 const browser=await chromium.launch({headless:true,executablePath:process.env.KANAME_CHROMIUM||undefined});
 let checks=0;
 const html=fs.readFileSync('kaname/static/index.html','utf8').replace(/<script\b[^>]*>[\s\S]*?<\/script>/g,'').replace(/<link\b[^>]*>/g,'');
 async function fixture(mode='stage'){
  const page=await browser.newPage();const errors=[];page.on('pageerror',e=>errors.push(String(e)));
  await page.route('https://filesystem.fixture.test/**',r=>r.fulfill({contentType:'text/html',body:html}));await page.goto('https://filesystem.fixture.test/');
  await page.evaluate(mode=>{
   for(const e of document.querySelectorAll('[hidden]'))e.hidden=false;
   window.$=id=>document.getElementById(id);window.authGeneration=1;window.allowWrite=true;window.can=(r,w)=>!w||allowWrite;
   const candidate='11111111-1111-4111-8111-111111111111',gpo='22222222-2222-4222-8222-222222222222',stageId='33333333-3333-4333-8333-333333333333';
   window.rows=[{id:candidate,plan_id:'plan',plan_version:1,gpo_id:gpo,artifact_kind:'combined_machine_v1',state:'content_verified',content_verified:true,manifest_sha256:'b'.repeat(64),staging_preview_verified:true,staging_preview_fresh:true,staging_preview_sha256:'a'.repeat(64),staging_preview:{relative_destination:'Machine/owned',files:[],file_count:20,total_bytes:100,checked_at:Math.floor(Date.now()/1000)}}];
   window.writeState={revision:10,source_only:false,approval_enabled:true,write_authorization_enabled:true,execution_adapter_available:true,can_apply_gpo:false,jobs:[],panel_workflow:{format:'AuthWireFilesystemPanelV1',enabled:true,gpo_id:gpo,worker_ready:true,rollback_targets:[],can_apply_gpo:false}};
   if(mode==='rollback'){writeState.jobs=[{id:stageId,operation:'combined.filesystem.stage.v1',state:'completed',authorization_issued:true,peer_reported_outcome:'staged'}];writeState.panel_workflow.rollback_targets=[{stage_job_id:stageId,candidate_id:candidate,staging_preview_sha256:'a'.repeat(64)}];}
   window.reviews=[];window.creates=[];window.loseCreate=false;window.holdReview=false;window.statusReads=0;
   window.api=async(path,v)=>{
    if(path==='/api/deployment/candidates')return {revision:10,candidates:rows};
    if(path==='/api/deployment/staging-write'){statusReads++;return structuredClone(writeState);}
    if(path==='/api/deployment/staging-write/review'){
     reviews.push(structuredClone(v));const reply={job_id:v.job_id,operation:v.operation,revision:v.expected_revision,read_only:false,review_only:false,can_apply_gpo:false,review_hash:'c'.repeat(64),target:{scope_target:{candidate_id:v.candidate_id,gpo_id:gpo,target_count:3},preview_record:{PreviewSha256:v.staging_preview_sha256,Preview:{file_count:20,total_bytes:100}},stage_receipt:v.stage_job_id?{stage_job_id:v.stage_job_id}:null}};
     if(window.badReview)reply.target.scope_target.gpo_id='99999999-9999-4999-8999-999999999999';
     if(holdReview)return new Promise(resolve=>window.releaseReview=()=>resolve(reply));return reply;
    }
    if(path==='/api/deployment/staging-write/create'){
     creates.push(structuredClone(v));writeState.jobs.unshift({id:v.job_id,operation:v.operation,state:'queued',authorization_issued:false});
     if(loseCreate)throw Object.assign(new Error('lost ACK'),{status:0});return {job_id:v.job_id,recorded:true,state:'queued',can_apply_gpo:false};
    }
    throw Error('Unexpected API route '+path);
   };
  },mode);
  await page.addScriptTag({content:fs.readFileSync('kaname/static/deployment.js','utf8')});
  await page.addScriptTag({content:fs.readFileSync('kaname/static/staging-write-panel.js','utf8')});
  await page.evaluate(()=>loadCandidateStatus());
  assert(await page.evaluate(()=>AuthWireFilesystemPanel.accepts(writeState)), 'explicit fixture contract must validate');
  return {page,errors};
 }
 try{
  {
   const {page,errors}=await fixture();await page.getByRole('button',{name:'Paket dosyalarını hazırlamayı önizle',exact:true}).click();
   const send=page.getByRole('button',{name:'Onayla ve gönder',exact:true});await send.waitFor();assert(await send.isDisabled());
   assert.equal(await page.evaluate(()=>creates.length),0);await page.getByRole('checkbox',{name:'Bu paket dosyası işlemini onaylıyorum.',exact:true}).check();await send.click();
   await page.waitForFunction(()=>creates.length===1&&document.querySelector('#dep-candidate-list').textContent.includes('Görev kayıtlı'));
   const request=await page.evaluate(()=>creates[0]);assert.equal(request.acknowledge,'create_owned_version_directory');assert.equal(request.stage_job_id,'');assert.equal(request.review_hash,'c'.repeat(64));assert.deepEqual(errors,[]);checks+=5;await page.close();
  }
  {
   const {page,errors}=await fixture('rollback');assert(await page.getByRole('button',{name:'Paket dosyalarını hazırlamayı önizle',exact:true}).isDisabled());
   await page.getByRole('button',{name:'Hazırlanan paketi geri almayı önizle',exact:true}).click();await page.getByRole('checkbox',{name:'Bu paket dosyası işlemini onaylıyorum.',exact:true}).check();await page.getByRole('button',{name:'Onayla ve gönder',exact:true}).click();
   await page.waitForFunction(()=>creates.length===1);const v=await page.evaluate(()=>creates[0]);assert.equal(v.operation,'combined.filesystem.rollback.v1');assert.equal(v.stage_job_id,'33333333-3333-4333-8333-333333333333');assert.equal(v.acknowledge,'delete_owned_version_directory');assert.deepEqual(errors,[]);checks+=5;await page.close();
  }
  {
   const {page,errors}=await fixture();await page.evaluate(()=>loseCreate=true);await page.getByRole('button',{name:'Paket dosyalarını hazırlamayı önizle',exact:true}).click();await page.getByRole('checkbox',{name:'Bu paket dosyası işlemini onaylıyorum.',exact:true}).check();await page.getByRole('button',{name:'Onayla ve gönder',exact:true}).click();
   await page.waitForFunction(()=>creates.length===1&&document.querySelector('#dep-candidate-list').textContent.includes('İstek tekrar gönderilmedi'));
   assert.equal(await page.evaluate(()=>creates.length),1);assert.equal(await page.getByRole('button',{name:'Onayla ve gönder',exact:true}).count(),0);assert.deepEqual(errors,[]);checks+=3;await page.close();
  }
  {
   const {page,errors}=await fixture();await page.evaluate(()=>{delete writeState.panel_workflow;return loadCandidateStatus();});assert.equal(await page.getByRole('button',{name:'Paket dosyalarını hazırlamayı önizle',exact:true}).count(),0);assert.equal(await page.evaluate(()=>creates.length),0);
   await page.evaluate(()=>{Object.assign(writeState,{source_only:true,approval_enabled:false,write_authorization_enabled:false,execution_adapter_available:false});return loadCandidateStatus();});assert.match(await page.locator('#dep-candidate-list').textContent(),/onayı kapalı/);assert.deepEqual(errors,[]);checks+=4;await page.close();
  }
  {
   const {page,errors}=await fixture();await page.evaluate(()=>{writeState.panel_workflow.worker_ready=false;return loadCandidateStatus();});assert(await page.getByRole('button',{name:'Paket dosyalarını hazırlamayı önizle',exact:true}).isDisabled());
   await page.evaluate(()=>{writeState.panel_workflow.worker_ready=true;allowWrite=false;return loadCandidateStatus();});assert(await page.getByRole('button',{name:'Paket dosyalarını hazırlamayı önizle',exact:true}).isDisabled());assert.equal(await page.evaluate(()=>creates.length),0);assert.deepEqual(errors,[]);checks+=4;await page.close();
  }
  {
   const {page,errors}=await fixture();await page.evaluate(()=>badReview=true);await page.getByRole('button',{name:'Paket dosyalarını hazırlamayı önizle',exact:true}).click();await page.waitForFunction(()=>document.querySelector('#dep-candidate-list').textContent.includes('önizlemesi doğrulanamadı'));assert.equal(await page.getByRole('button',{name:'Onayla ve gönder',exact:true}).count(),0);assert.equal(await page.evaluate(()=>creates.length),0);assert.deepEqual(errors,[]);checks+=3;await page.close();
  }
  {
   const {page,errors}=await fixture();await page.evaluate(()=>holdReview=true);await page.getByRole('button',{name:'Paket dosyalarını hazırlamayı önizle',exact:true}).click();await page.waitForFunction(()=>!!window.releaseReview);await page.evaluate(()=>{authGeneration++;resetCandidateRegistration();releaseReview();});await page.waitForTimeout(50);assert.equal(await page.getByRole('button',{name:'Onayla ve gönder',exact:true}).count(),0);assert.equal(await page.evaluate(()=>creates.length),0);assert.deepEqual(errors,[]);checks+=3;await page.close();
  }
  console.log('AUTHWIRE_FILESYSTEM_PANEL_UI_OK '+JSON.stringify({checks,customer_network:false,gpo_activation:false}));
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exitCode=1;});
