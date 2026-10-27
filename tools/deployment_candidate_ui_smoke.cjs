// Browser-only receipt presentation and lost-response safety. No customer network.
const { chromium } = require('playwright');
const fs = require('node:fs');
const assert = require('node:assert/strict');
(async()=>{
 const browser=await chromium.launch({headless:true,...(process.env.KANAME_CHROMIUM?{executablePath:process.env.KANAME_CHROMIUM}:{})});
 try{
  const page=await browser.newPage();const errors=[];page.on('pageerror',e=>errors.push(String(e)));
  const html=fs.readFileSync('kaname/static/index.html','utf8').replace(/<script\b[^>]*>[\s\S]*?<\/script>/g,'').replace(/<link\b[^>]*>/g,'');
  // The production panel is HTTPS; randomUUID is a secure-context API.
  await page.route('https://candidate.fixture.test/**',route=>route.fulfill({contentType:'text/html',body:html}));
  await page.goto('https://candidate.fixture.test/');
  await page.evaluate(()=>{
   for(const e of document.querySelectorAll('[hidden]'))e.hidden=false;
   window.$=id=>document.getElementById(id);window.authGeneration=1;window.allowWrite=true;
   window.can=(resource,write)=>!write||window.allowWrite;window.rows=[];window.recordCalls=0;window.verifyCalls=0;window.workerReady=false;window.verifyJobs=[];
   window.api=async(path,value)=>{
    if(path==='/api/deployment/candidates')return {revision:10,candidates:window.rows,can_apply:false,verification_worker_ready:window.workerReady,verification_jobs:window.verifyJobs};
    if(path==='/api/deployment/candidates/preview')return {id:value.registration_id,plan_id:'<img src=x onerror=alert(1)>',plan_version:1,gpo_id:'gpo',manifest_sha256:'abc',preview_hash:'a'.repeat(64)};
    if(path==='/api/deployment/candidates/record'){
     window.recordCalls++;window.rows=[{id:value.registration_id,plan_id:'plan',plan_version:1,state:'operator_reported',manifest_sha256:'abc'}];
     throw Object.assign(new Error('lost response'),{status:0});
    }
    if(path==='/api/deployment/candidates/verify/preview')return {...value,target:{candidate_id:value.candidate_id,manifest_sha256:'abc'},read_only:true,can_apply:false,preview_hash:'a'.repeat(64)};
    if(path==='/api/deployment/candidates/verify/create'){
     window.verifyCalls++;window.verifyJobs=[{id:value.job_id,candidate_id:value.candidate_id,state:'queued',outcome:null}];
     throw Object.assign(new Error('lost verify response'),{status:0});
    }
    throw new Error('Unexpected route '+path);
   };
  });
  await page.addScriptTag({content:fs.readFileSync('kaname/static/deployment.js','utf8')});
  await page.evaluate(()=>candidateControls());
  await page.locator('#dep-candidate-open').click();
  await page.locator('#dep-candidate-json').fill('{"opaque":"operator receipt"}');
  await page.locator('#dep-candidate-save').click();
  await page.waitForFunction(()=>document.getElementById('dep-candidate-save').textContent==='Kaydet');
  assert.equal(await page.locator('#dep-candidate-preview img').count(),0);
  assert.match(await page.locator('#dep-candidate-preview').textContent(),/yalnız|Yalnız/);
  await page.locator('#dep-candidate-save').click();
  await page.waitForFunction(()=>!document.getElementById('dep-candidate-dialog').open);
  assert.equal(await page.evaluate(()=>window.recordCalls),1);
  assert.match(await page.locator('#dep-candidate-feedback').textContent(),/tamamlandığı doğrulandı/);
  assert.match(await page.locator('#dep-candidate-list').textContent(),/Connector doğrulaması bekleniyor/);
  assert.equal(await page.getByRole('button',{name:'Doğrulamayı önizle',exact:true}).isDisabled(),true);
  await page.evaluate(()=>{window.workerReady=true;return loadCandidateStatus();});
  await page.getByRole('button',{name:'Doğrulamayı önizle',exact:true}).click();
  await page.getByRole('button',{name:'Doğrulamayı gönder',exact:true}).waitFor();
  await page.evaluate(()=>loadCandidateStatus());
  assert.equal(await page.getByRole('button',{name:'Doğrulamayı önizle',exact:true}).isDisabled(),false);
  assert.equal(await page.getByRole('button',{name:'Doğrulamayı gönder',exact:true}).count(),0);
  await page.getByRole('button',{name:'Doğrulamayı önizle',exact:true}).click();
  await page.getByRole('button',{name:'Doğrulamayı gönder',exact:true}).click();
  await page.waitForFunction(()=>window.verifyCalls===1&&document.getElementById('dep-candidate-list').textContent.includes('bağlantı bekliyor'));
  assert.equal(await page.evaluate(()=>window.verifyCalls),1);
  assert.equal(await page.getByRole('button',{name:'Doğrulamayı önizle',exact:true}).isDisabled(),true);
  await page.evaluate(()=>{window.rows[0].state='content_verified';window.rows[0].content_verified=true;window.verifyJobs[0].state='completed';window.verifyJobs[0].outcome='content_verified';return loadCandidateStatus();});
  assert.match(await page.locator('#dep-candidate-list').textContent(),/GPO ve dağıtım kontrolü bekleniyor/);
  await page.locator('#dep-candidate-open').click();
  await page.locator('#dep-candidate-json').fill('private draft');
  await page.evaluate(()=>{authGeneration++;resetCandidateRegistration();});
  assert.equal(await page.locator('#dep-candidate-json').inputValue(),'');
  assert.equal(await page.locator('#dep-candidate-dialog').evaluate(e=>e.open),false);
  await page.evaluate(()=>{window.allowWrite=false;candidateControls();});
  assert.equal(await page.locator('#dep-candidate-open').isVisible(),false);
  assert.equal(errors.length,0,errors.join('\n'));
  console.log('AUTHWIRE_CANDIDATE_RECEIPT_UI_OK: preview, safe text, one write, lost-response GET reconciliation, reset and roles');
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exit(1);});
