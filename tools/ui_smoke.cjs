'use strict';
// Development-only browser verification; does not contact AD or a network device.
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const {spawn} = require('node:child_process');
const assert = require('node:assert/strict');
const {chromium} = require(process.env.CODEX_PRIMARY_RUNTIME_NODE_MODULES ? path.join(process.env.CODEX_PRIMARY_RUNTIME_NODE_MODULES, 'playwright') : 'playwright');

(async () => {
  const root = path.resolve(__dirname, '..');
  const temp = fs.mkdtempSync(path.join(os.tmpdir(), 'kaname-ui-'));
  const python = process.env.CODEX_PRIMARY_RUNTIME_PYTHON || process.env.KANAME_PYTHON || 'python3';
  // Port 0 is accepted by DevelopmentServer; production CLI intentionally rejects it.
  // Directory fixture is confined to this disposable test server; no real AD.
  const child = spawn(python, ['-u', '-c', 'import sys; from kaname.server import DevelopmentServer; from tests.test_directory import catalog; s=DevelopmentServer(sys.argv[1],0); s.directory_reader=lambda v,c:{**catalog(),"domain":c["ad_domain"],"dc_fqdn":v["dc_fqdn"]}; original=s.store.directory_status; s.store.directory_status=lambda:{**original(),"windows_reader_available":True}; print(s.server_port,flush=True); s.serve_forever()', temp], {cwd: root, stdio:['ignore','pipe','pipe']});
  let browser;
  try {
    const port = await new Promise((resolve,reject) => {
      const timer=setTimeout(()=>reject(new Error('Local server startup timed out')),10000);
      child.once('error',err=>{clearTimeout(timer);reject(err);});
      child.once('exit',code=>{clearTimeout(timer);reject(new Error('Local server exited: '+code));});
      child.stdout.once('data',data=>{clearTimeout(timer);resolve(Number(data.toString().trim()));});
    });
    assert.ok(Number.isInteger(port) && port>0);
    browser=await chromium.launch({headless:true,...(process.env.KANAME_CHROMIUM ? {executablePath:process.env.KANAME_CHROMIUM} : {})});
    const page=await browser.newPage({viewport:{width:1440,height:1000}});
    const errors=[];
    page.on('pageerror',err=>errors.push(err.message));
    await page.goto(`http://127.0.0.1:${port}`);
    await page.locator('#token').fill(fs.readFileSync(path.join(temp,'access-token'),'utf8').trim());
    await page.locator('#unlock').click();
    await page.locator('#workspace').waitFor({state:'visible'});
    await page.locator('#fqdn').fill('kaname.kurum.example');
    await page.locator('#next').click();
    await page.locator('#domain').fill('kurum.example');
    await page.locator('#dc').fill('192.0.2.10, 192.0.2.11');
    await page.locator('#next').click();
    await page.locator('#clients').fill('SW-LAB,192.0.2.2\nAP-LAB,192.0.2.3');
    await page.locator('#next').click();
    assert.match(await page.locator('#review').textContent(),/kurum.example/);
    await page.locator('#save').click();
    await page.waitForFunction(()=>document.querySelector('#revision').textContent.includes('1'));
    await page.locator('[data-view="policies"]').click();
    await page.locator('summary').click();
    const sid='S-1-5-21-100-200-300-400';
    await page.locator('#policy-group').fill(sid);
    await page.locator('#add-policy').click();
    await page.waitForFunction(()=>document.querySelectorAll('.policy-row').length===1);
    await page.locator('[data-view="simulate"]').click();
    await page.locator('#sim-group').fill(sid);
    await page.locator('#run-simulation').click();
    await page.waitForFunction(()=>document.querySelector('#result').textContent.includes('POLICY_ALLOW'));
    assert.match(await page.locator('#result').textContent(),/"network_enforced": false/);
    await page.locator('#scenario').selectOption('outside');
    await page.locator('#run-simulation').click();
    await page.waitForFunction(()=>document.querySelector('#result').textContent.includes('DOMAIN_DEVICE_REQUIRED'));
    await page.locator('[data-view="audit"]').click();
    assert.match(await page.locator('#audit-list').textContent(),/config_saved/);
    assert.match(await page.locator('#audit-list').textContent(),/policies_saved/);
    await page.locator('[data-view="certificates"]').click();
    assert.match(await page.locator('#pki-info').textContent(),/henüz CA oluşturulmadı/);
    await page.locator('[data-view="directory"]').click();
    assert.equal(await page.locator('#ad-domain').inputValue(),'kurum.example');
    await page.locator('#ad-host').fill('dc01.kurum.example');
    await page.locator('#ad-user').fill('administrator@kurum.example');
    const fixturePassword='UI_FIXTURE_PASSWORD_NOT_REAL';
    await page.locator('#ad-password').fill(fixturePassword);
    await page.locator('#directory-sync').click();
    await page.waitForFunction(()=>document.querySelector('#directory-status').textContent.includes('1 grup'));
    assert.equal(await page.locator('#ad-password').inputValue(),'');
    assert.match(await page.locator('#directory-list').textContent(),/<script>alert\(1\)<\/script>/);
    assert.equal(await page.locator('#directory-list script').count(),0);
    assert.ok(!fs.readFileSync(path.join(temp,'kaname.sqlite3')).includes(fixturePassword));
    await page.locator('#directory-list button').click();
    assert.equal(await page.locator('#policy-group').inputValue(),'S-1-5-21-1-2-3-1100');
    await page.reload();
    await page.locator('#token').fill(fs.readFileSync(path.join(temp,'access-token'),'utf8').trim());
    await page.locator('#unlock').click();
    await page.locator('#workspace').waitFor({state:'visible'});
    assert.equal(await page.locator('#fqdn').inputValue(),'kaname.kurum.example');
    assert.equal(await page.locator('#token').inputValue(),'');
    await page.locator('[data-view="policies"]').click();
    assert.equal(await page.locator('.policy-row').count(),1);
    if(process.env.KANAME_SCREENSHOT)await page.screenshot({path:process.env.KANAME_SCREENSHOT,fullPage:true});
    assert.deepEqual(errors,[]);
    console.log('PASS: login, draft, policy, simulation, audit, persistence, directory fixture import, password removal, XSS-safe rendering and group selection. No real AD was contacted.');
  } finally {
    if(browser)await browser.close();
    child.kill();
    if(child.exitCode===null)await new Promise(resolve=>child.once('exit',resolve));
    fs.rmSync(temp,{recursive:true,force:true});
  }
})().catch(error=>{console.error(error.message);process.exitCode=1;});
