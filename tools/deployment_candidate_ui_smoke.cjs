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
   window.can=(resource,write)=>!write||window.allowWrite;window.rows=[];window.recordCalls=0;
   window.api=async(path,value)=>{
    if(path==='/api/deployment/candidates')return {revision:10,candidates:window.rows,can_apply:false};
    if(path==='/api/deployment/candidates/preview')return {id:value.registration_id,plan_id:'<img src=x onerror=alert(1)>',plan_version:1,gpo_id:'gpo',manifest_sha256:'abc',preview_hash:'a'.repeat(64)};
    if(path==='/api/deployment/candidates/record'){
     window.recordCalls++;window.rows=[{id:value.registration_id,plan_id:'plan',plan_version:1,state:'operator_reported',manifest_sha256:'abc'}];
     throw Object.assign(new Error('lost response'),{status:0});
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
