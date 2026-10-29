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
   window.stagingReady=false;window.stagingJobs=[];window.stagingCalls=0;window.scopeReady=false;window.scopeJobs=[];window.combinedScopeJobs=[];window.combinedScopeReady=false;window.combinedScopeCalls=0;window.combinedJobs=[];window.combinedReady=false;window.combinedCalls=0;window.scopeCalls=0;
   window.api=async(path,value)=>{
    if(path==='/api/deployment/staging-write'){
     if(window.writeStatusDelay)return new Promise(resolve=>window.releaseWriteStatus=resolve);
     if(window.writeStatusError)throw new Error('status unavailable');
     return window.writeStatus||{approval_enabled:false,write_authorization_enabled:false,execution_adapter_available:false,can_apply_gpo:false,jobs:[]};
    }
    if(path.includes('/staging-write/')&&path.endsWith('/create'))throw Error('UI must never submit write approvals');
    if(path==='/api/deployment/candidates')return {revision:10,candidates:window.rows,can_apply:false,verification_worker_ready:window.workerReady,verification_jobs:window.verifyJobs,scope_worker_ready:window.scopeReady,scope_verification_jobs:window.scopeJobs,combined_verification_jobs:window.combinedJobs,combined_scope_worker_ready:window.combinedScopeReady,combined_scope_verification_jobs:window.combinedScopeJobs,combined_worker_ready:window.combinedReady,staging_preview_worker_ready:window.stagingReady,staging_preview_jobs:window.stagingJobs};
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
    if(path==='/api/deployment/candidates/staging-preview/preview')return {job_id:value.job_id,operation:value.operation,preview_hash:'f'.repeat(64),read_only:true,can_apply:false,target:{candidate_id:value.candidate_id,manifest_sha256:'abc',draft_sha256:'d'.repeat(64),network_candidate_id:'network-fixture',machine_profile_version:3,target_count:200,target_sids_sha256:'b'.repeat(64),content_result_sha256:'c'.repeat(64)}};
    if(path==='/api/deployment/candidates/staging-preview/create'){
     window.stagingCalls++;window.stagingJobs=[{id:value.job_id,candidate_id:value.candidate_id,state:'queued',outcome:null}];throw Object.assign(new Error('lost staging preview response'),{status:0});
    }
    if(path==='/api/deployment/candidates/combined-scope/preview')return {job_id:value.job_id,operation:value.operation,preview_hash:'e'.repeat(64),read_only:true,can_apply:false,target:{candidate_id:value.candidate_id,manifest_sha256:'abc',draft_sha256:'d'.repeat(64),network_candidate_id:'network-fixture',machine_profile_version:3,target_count:200,target_sids_sha256:'b'.repeat(64),content_result_sha256:'c'.repeat(64)}};
    if(path==='/api/deployment/candidates/combined-scope/create'){
     window.combinedScopeCalls++;window.combinedScopeJobs=[{id:value.job_id,candidate_id:value.candidate_id,state:'queued',outcome:null}];throw Object.assign(new Error('lost combined scope response'),{status:0});
    }
    if(path==='/api/deployment/candidates/combined/preview')return {...value,target:{candidate_id:value.candidate_id,manifest_sha256:'abc',draft_sha256:'d'.repeat(64),network_candidate_id:'network-fixture',machine_profile_version:3},read_only:true,can_apply:false,preview_hash:'a'.repeat(64)};
    if(path==='/api/deployment/candidates/combined/create'){
     window.combinedCalls++;window.combinedJobs=[{id:value.job_id,candidate_id:value.candidate_id,state:'queued',outcome:null}];
     throw Object.assign(new Error('lost combined response'),{status:0});
    }
    if(path==='/api/deployment/candidates/scope/preview')return {...value,target:{candidate_id:value.candidate_id,manifest_sha256:'abc',target_count:2,target_sids_sha256:'b'.repeat(64)},read_only:true,can_apply:false,preview_hash:'a'.repeat(64)};
    if(path==='/api/deployment/candidates/scope/create'){
     window.scopeCalls++;window.scopeJobs=[{id:value.job_id,candidate_id:value.candidate_id,state:'queued',outcome:null}];
     throw Object.assign(new Error('lost scope response'),{status:0});
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
  assert.equal(await page.getByRole('button',{name:'AD/GPO kontrolünü önizle',exact:true}).isDisabled(),true);
  await page.evaluate(()=>{window.scopeReady=true;return loadCandidateStatus();});
  await page.getByRole('button',{name:'AD/GPO kontrolünü önizle',exact:true}).click();
  assert.match(await page.locator('#dep-candidate-list').textContent(),/Hedef bilgisayar sayısı: 2/);
  assert.match(await page.locator('#dep-candidate-list').textContent(),/GPO veya cihaz ayarı uygulanmaz/);
  await page.getByRole('button',{name:'AD/GPO kontrolünü gönder',exact:true}).click();
  await page.waitForFunction(()=>window.scopeCalls===1&&document.getElementById('dep-candidate-list').textContent.includes('AD/GPO kontrol görevi bekleniyor'));
  assert.equal(await page.evaluate(()=>window.scopeCalls),1);
  assert.equal(await page.getByRole('button',{name:'AD/GPO kontrolünü önizle',exact:true}).isDisabled(),true);
  await page.evaluate(()=>{window.scopeJobs[0].state='completed';window.scopeJobs[0].outcome='scope_snapshot_verified';Object.assign(window.rows[0],{scope_snapshot_verified:true,scope_snapshot_fresh:true,scope_checked_at:Math.floor(Date.now()/1000)});return loadCandidateStatus();});
  assert.match(await page.locator('#dep-candidate-list').textContent(),/AD hedefleri ve GPO okuma kontrolü başarılı/);
  assert.match(await page.locator('#dep-candidate-list').textContent(),/Dağıtım henüz uygulanmadı/);
  await page.evaluate(()=>{window.rows[0].scope_snapshot_fresh=false;return loadCandidateStatus();});
  assert.match(await page.locator('#dep-candidate-list').textContent(),/güncel kontrol gerekiyor/);
  await page.evaluate(()=>{Object.assign(window.rows[0],{scope_snapshot_verified:false,scope_snapshot_fresh:false,scope_reason:'DIRECTORY_SCOPE_CHANGED'});return loadCandidateStatus();});
  assert.match(await page.locator('#dep-candidate-list').textContent(),/DIRECTORY_SCOPE_CHANGED/);
  assert.doesNotMatch(await page.locator('#dep-candidate-list').textContent(),/AD hedefleri ve GPO okuma kontrolü başarılı/);
  await page.evaluate(()=>{window.rows.push({...window.rows[0],id:'combined-fixture',artifact_kind:'combined_machine_v1',state:'operator_reported',content_verified:false,scope_snapshot_verified:false,scope_snapshot_fresh:false,scope_reason:null,draft_sha256:'d'.repeat(64),content_verification_available:true,network_candidate_id:'network-fixture'});return loadCandidateStatus();});
  const combined=page.locator('#dep-candidate-list article').filter({hasText:' · Birleşik paket'});
  assert.match(await combined.textContent(),/Birleşik paket/);
  assert.match(await combined.textContent(),/Bu kontrol cihazlara dağıtım başlatmaz/);
  assert.equal(await combined.getByRole('button',{name:'Doğrulamayı önizle',exact:true}).isDisabled(),true);
  assert.equal(await combined.getByRole('button',{name:'AD/GPO kontrolünü önizle',exact:true}).isDisabled(),true);
  await page.evaluate(()=>{window.combinedReady=true;return loadCandidateStatus();});
  await combined.getByRole('button',{name:'Doğrulamayı önizle',exact:true}).click();
  assert.match(await combined.textContent(),/Bilgisayar sertifika profili sürümü: 3/);
  await combined.getByRole('button',{name:'Doğrulamayı gönder',exact:true}).click();
  await page.waitForFunction(()=>window.combinedCalls===1&&document.getElementById('dep-candidate-list').textContent.includes('Doğrulama görevi bağlantı bekliyor'));
  assert.equal(await page.evaluate(()=>window.combinedCalls),1);
  await page.evaluate(()=>{window.combinedJobs[0].state='completed';window.combinedJobs[0].outcome='combined_content_verified';window.rows[1].content_verified=true;return loadCandidateStatus();});
  assert.match(await combined.textContent(),/İmza ve içerik Connector tarafından doğrulandı/);
  await page.evaluate(()=>{window.combinedScopeReady=true;return loadCandidateStatus();});
  await combined.getByRole('button',{name:'AD/GPO kontrolünü önizle',exact:true}).click();
  assert.match(await combined.textContent(),/SYSVOL dosyaları salt okunur/);
  await combined.getByRole('button',{name:'AD/GPO kontrolünü gönder',exact:true}).click();
  await page.waitForFunction(()=>window.combinedScopeCalls===1&&document.getElementById('dep-candidate-list').textContent.includes('AD/GPO kontrol görevi bekleniyor'));
  assert.equal(await page.evaluate(()=>window.combinedScopeCalls),1);
  await page.evaluate(()=>{window.combinedScopeJobs[0].state='completed';window.combinedScopeJobs[0].outcome='combined_scope_snapshot_verified';Object.assign(window.rows[1],{scope_snapshot_verified:true,scope_snapshot_fresh:true,scope_checked_at:Math.floor(Date.now()/1000)});return loadCandidateStatus();});
  assert.match(await combined.textContent(),/AD hedefleri ve GPO okuma kontrolü başarılı/);


  await page.evaluate(()=>{window.allowWrite=true;window.stagingReady=true;window.rows[1].content_verified=true;window.rows[1].state='content_verified';return loadCandidateStatus();});
  await page.getByRole('button',{name:'Paket hazırlığını önizle',exact:true}).click();
  assert.match(await page.locator('#dep-candidate-list').textContent(),/SYSVOL dosyası yazılmayacak/);
  await page.getByRole('button',{name:'Hazırlık önizlemesini gönder',exact:true}).click();
  await page.waitForFunction(()=>window.stagingCalls===1&&document.getElementById('dep-candidate-list').textContent.includes('önizleme sonucu bekleniyor'));
  assert.equal(await page.evaluate(()=>window.stagingCalls),1);
  assert.equal(await page.getByRole('button',{name:'Paket hazırlığını önizle',exact:true}).isDisabled(),true);
  await page.evaluate(()=>{
   window.stagingJobs[0].state='completed';window.stagingJobs[0].outcome='staging_preview_verified';
   Object.assign(window.rows[1],{staging_preview_verified:true,staging_preview_fresh:true,staging_preview_sha256:'f'.repeat(64),staging_preview:{relative_destination:'Machine/AuthWire-fixture-v1-abc',file_count:20,total_bytes:620,checked_at:Math.floor(Date.now()/1000),files:Array.from({length:20},(_,i)=>({Path:i===0?'<img src=x onerror=alert(1)>':'file-'+i,Size:31,Sha256:'a'.repeat(64)}))}});
   return loadCandidateStatus();
  });
  assert.match(await page.locator('#dep-candidate-list').textContent(),/Önerilen klasör: Machine/);
  assert.match(await page.locator('#dep-candidate-list').textContent(),/SYSVOL dosyası yazılmadı/);
  assert.equal(await page.locator('#dep-candidate-list table tr').count(),21);
  assert.equal(await page.locator('#dep-candidate-list img').count(),0);
  await page.evaluate(()=>{window.rows[1].staging_preview_fresh=false;window.allowWrite=false;return loadCandidateStatus();});
  assert.match(await page.locator('#dep-candidate-list').textContent(),/güncel kontrol gerekiyor/);
  assert.equal(await page.getByRole('button',{name:'Paket hazırlığını önizle',exact:true}).count(),0);
  await page.evaluate(()=>{
   window.writeStatus={approval_enabled:false,write_authorization_enabled:false,execution_adapter_available:false,can_apply_gpo:false,jobs:[
    {id:'<img src=x onerror=alert(1)>',operation:'combined.filesystem.stage.v1',state:'requires_review'},
    {id:'reported',operation:'combined.filesystem.rollback.v1',state:'completed'},
    {id:'grant',operation:'combined.filesystem.stage.v1',state:'authorized'}]};
   return loadCandidateStatus();
  });
  assert.match(await page.locator('#dep-candidate-list').textContent(),/sonuç|Sonuç/);
  assert.match(await page.locator('#dep-candidate-list').textContent(),/İşlemi tekrar başlatmayın/);
  assert.match(await page.locator('#dep-candidate-list').textContent(),/bağımsız disk kabulü anlamına gelmez/);
  assert.match(await page.locator('#dep-candidate-list').textContent(),/Yetki verilmiş; dosya sonucu henüz doğrulanmadı/);
  assert.equal(await page.locator('#dep-candidate-list img').count(),0);
  assert.equal(await page.getByRole('button',{name:'Paket dosyalarını yaz',exact:true}).count(),0);
  await page.evaluate(()=>{window.savedWriteJobs=window.writeStatus.jobs;window.writeStatus.jobs=[null];return loadCandidateStatus();});
  assert.match(await page.locator('#dep-candidate-list').textContent(),/İşlem durumu alınamadı/);
  await page.evaluate(()=>window.writeStatus.jobs=window.savedWriteJobs);
  for(const change of ['approval_enabled','write_authorization_enabled','execution_adapter_available','can_apply_gpo']){
   await page.evaluate(key=>{window.writeStatus[key]=true;return loadCandidateStatus();},change);
   assert.match(await page.locator('#dep-candidate-list').textContent(),/İşlem durumu alınamadı/);
   await page.evaluate(key=>window.writeStatus[key]=false,change);
  }
  await page.evaluate(()=>{window.writeStatusError=true;return loadCandidateStatus();});
  assert.match(await page.locator('#dep-candidate-list').textContent(),/mevcut görevlerin sonucu hakkında karar vermeyin/);
  assert.match(await page.locator('#dep-candidate-list').textContent(),/Önerilen klasör: Machine/);
  await page.evaluate(()=>{window.writeStatusError=false;window.writeStatusDelay=true;window.pendingWriteLoad=loadCandidateStatus();});
  await page.waitForFunction(()=>typeof window.releaseWriteStatus==='function');
  assert.match(await page.locator('#dep-candidate-list').textContent(),/Önerilen klasör: Machine/);
  assert.match(await page.locator('#dep-candidate-list').textContent(),/durumu kontrol ediliyor/);
  await page.evaluate(async()=>{window.oldWriteReply=window.releaseWriteStatus;window.writeStatusDelay=false;await loadCandidateStatus();window.oldWriteReply({...window.writeStatus,jobs:[{id:'obsolete-response-marker',operation:'combined.filesystem.stage.v1',state:'authorized'}]});});
  assert.doesNotMatch(await page.locator('#dep-candidate-list').textContent(),/obsolete-response-marker/);
  await page.evaluate(()=>{window.writeStatusDelay=true;window.releaseWriteStatus=null;return loadCandidateStatus();});
  await page.waitForFunction(()=>typeof window.releaseWriteStatus==='function');
  await page.evaluate(async()=>{authGeneration++;resetCandidateRegistration();window.releaseWriteStatus(window.writeStatus);await window.pendingWriteLoad;window.writeStatusDelay=false;});
  assert.equal(await page.locator('#dep-candidate-list').textContent(),'');
  await page.evaluate(()=>{window.allowWrite=true;candidateControls();});
  await page.locator('#dep-candidate-open').click();
  await page.locator('#dep-candidate-json').fill('private draft');
  await page.evaluate(()=>{authGeneration++;resetCandidateRegistration();});
  assert.equal(await page.locator('#dep-candidate-json').inputValue(),'');
  assert.equal(await page.locator('#dep-candidate-dialog').evaluate(e=>e.open),false);
  await page.evaluate(()=>{window.allowWrite=false;candidateControls();});
  assert.equal(await page.locator('#dep-candidate-open').isVisible(),false);
  assert.equal(errors.length,0,errors.join('\n'));
  console.log('AUTHWIRE_CANDIDATE_RECEIPT_UI_OK: content and scope separation, capability gating, lost-response reconciliation, snapshot expiry/rejection, reset and roles');
 }finally{await browser.close();}
})().catch(e=>{console.error(e);process.exit(1);});

