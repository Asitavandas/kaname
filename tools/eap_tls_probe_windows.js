'use strict';
const fs = require('node:fs');
const path = require('node:path');
const { spawn } = require('node:child_process');
const readline = require('node:readline');
const assert = require('node:assert/strict');
const crypto = require('node:crypto');
const { EapTlsPeer, parseEap, wiredFrame } = require('./eap_tls_probe');
const directory = __dirname;
const name = process.argv[2]; assert(['expired', 'wrong-issuer', 'control', 'transport'].includes(name));
const config = JSON.parse(fs.readFileSync(path.join(directory, 'probe-config.json')));
assert.equal(config.schema, 1); assert.equal(config.run_id, path.basename(directory));
assert.equal(config.servername, 'kaname.vizyonveri.local');
assert(typeof config.identity === 'string' && /^[A-Za-z0-9/-]{1,100}$/.test(config.identity));
let bundle = null, credential = null;
if (name !== 'transport') {
  const data = fs.readFileSync(path.join(directory, 'bundle.json'));
  assert.equal(crypto.createHash('sha256').update(data).digest('hex'), config.bundle_sha256, 'Private credential hash');
  bundle = JSON.parse(data); assert.equal(bundle.run_id, config.run_id);
  assert.equal(bundle.servername, config.servername); credential = bundle.cases[name]; assert(credential);
}
const peer = new EapTlsPeer(name === 'transport' ? { identity: config.identity } :
  { ...credential, ca: bundle.root, crl: bundle.crls, servername: config.servername, identity: config.identity });
const client = Buffer.from('0050569b7de3', 'hex'), nas = Buffer.from('64e881346361', 'hex');
const multicast = Buffer.from('0180c2000003', 'hex');
const child = spawn('C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe',
  ['-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'AllSigned', '-File', path.join(directory, 'operator.ps1'), '-Mode', 'Link'],
  { windowsHide: true, stdio: ['pipe', 'pipe', 'pipe'] });
let settled = false, started = false, received = false, starts = 0, timer, deadline, version = 1;
let tlsStartReceived = false;
const linkFacts = { transmitted: 0, observed_outgoing: 0, received_versions: [], last_request_type: null };
function send(type, body = Buffer.alloc(0)) {
  const frame = wiredFrame(type, body, version); child.stdin.write(frame.toString('base64') + '\n');
}
function finish(error) {
  if (settled) return; settled = true; clearInterval(timer); clearTimeout(deadline);
  peer.close(); child.stdin.end('STOP\n');
  const result = { event: 'AUTHWIRE_EXPLICIT_CERTIFICATE_EAP_PROBE', case: name, run_id: config.run_id,
    started, eapol_starts: starts, tls_start_received: tlsStartReceived, link: linkFacts, utc: new Date().toISOString(), error: error ? String(error.message || error) : null, ...peer.facts };
  // No raw TLS, certificate keys, packet bodies, or credentials in output.
  console.log(JSON.stringify(result));
  const accepted = name === 'transport' ? tlsStartReceived : peer.facts.terminal === 'failure' && peer.facts.client_certificate_sent;
  process.exitCode = !error && accepted ? 0 : 2;
  setTimeout(() => { if (child.exitCode === null) child.kill(); }, 1500).unref();
}
let queue = Promise.resolve();
readline.createInterface({ input: child.stdout }).on('line', line => {
  queue = queue.then(async () => {
    if (settled) return;
    if (line === 'AUTHWIRE_EAPOL_TX') { linkFacts.transmitted++; return; }
    if (line === 'AUTHWIRE_EAPOL_LINK_READY') {
      assert(!started); started = true;
      const start = () => { if (!received && starts < 5) { starts++; send(1); } };
      start(); timer = setInterval(start, 3000); return;
    }
    assert(/^[A-Za-z0-9+/=]+$/.test(line) && line.length <= 9000, 'Link protocol output');
    const frame = Buffer.from(line, 'base64');
    if (frame.length >= 18 && frame.subarray(6, 12).equals(client)) { linkFacts.observed_outgoing++; return; }
    if (frame.length < 22 || !frame.subarray(6, 12).equals(nas) || frame.readUInt16BE(12) !== 0x888e || frame[15] !== 0) return;
    if (!frame.subarray(0, 6).equals(client) && !frame.subarray(0, 6).equals(multicast)) return;
    const size = frame.readUInt16BE(16); assert(size >= 4 && size <= frame.length - 18);
    assert([1, 2].includes(frame[14]), 'Unsupported EAPOL version'); version = frame[14];
    if (!linkFacts.received_versions.includes(version)) linkFacts.received_versions.push(version);
    linkFacts.last_request_type = frame.length >= 23 ? frame[22] : null;
    received = true;
    const packet = frame.subarray(18, size + 18), parsed = parseEap(packet);
    if (name === 'transport' && parsed.code === 1 && parsed.type === 13 && parsed.data.length === 1 && parsed.data[0] === 0x20) {
      tlsStartReceived = true; finish(); return;
    }
    const response = await peer.request(packet);
    if (response) send(0, response);
    if (peer.facts.terminal) finish();
  }).catch(finish);
});
child.stderr.on('data', () => finish(new Error('Signed EAPOL link failed')));
child.on('error', finish); child.on('exit', code => { if (!settled) finish(new Error('EAPOL link exited ' + code)); });
deadline = setTimeout(() => finish(new Error('Bounded EAP probe timeout')), 45000);
