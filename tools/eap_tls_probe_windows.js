'use strict';
const fs = require('node:fs');
const path = require('node:path');
const { spawn } = require('node:child_process');
const readline = require('node:readline');
const assert = require('node:assert/strict');
const { EapTlsPeer } = require('./eap_tls_probe');
const directory = __dirname;
const name = process.argv[2]; assert(['expired', 'wrong-issuer', 'control'].includes(name));
const bundle = JSON.parse(fs.readFileSync(path.join(directory, 'bundle.json')));
assert.equal(bundle.schema, 1); assert.equal(bundle.servername, 'kaname.vizyonveri.local');
const credential = bundle.cases[name]; assert(credential);
const peer = new EapTlsPeer({ ...credential, ca: bundle.root, crl: bundle.crls,
  servername: bundle.servername, identity: 'AuthWire-negative-' + name + '-' + bundle.run_id });
const client = Buffer.from('0050569b7de3', 'hex'), nas = Buffer.from('64e881346361', 'hex');
const multicast = Buffer.from('0180c2000003', 'hex');
const child = spawn('C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe',
  ['-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'AllSigned', '-File', path.join(directory, 'operator.ps1'), '-Mode', 'Link'],
  { windowsHide: true, stdio: ['pipe', 'pipe', 'pipe'] });
let settled = false, started = false, received = false, starts = 0, timer, deadline;
function send(type, body = Buffer.alloc(0)) {
  const frame = Buffer.alloc(18 + body.length);
  (type === 1 ? multicast : nas).copy(frame, 0); client.copy(frame, 6);
  frame.writeUInt16BE(0x888e, 12); frame[14] = 2; frame[15] = type;
  frame.writeUInt16BE(body.length, 16); body.copy(frame, 18);
  assert(frame.length <= 1500); child.stdin.write(frame.toString('base64') + '\n');
}
function finish(error) {
  if (settled) return; settled = true; clearInterval(timer); clearTimeout(deadline);
  peer.close(); child.stdin.end('STOP\n');
  const result = { event: 'AUTHWIRE_EXPLICIT_CERTIFICATE_EAP_PROBE', case: name, run_id: bundle.run_id,
    started, eapol_starts: starts, utc: new Date().toISOString(), error: error ? String(error.message || error) : null, ...peer.facts };
  // No raw TLS, certificate keys, packet bodies, or credentials in output.
  console.log(JSON.stringify(result));
  process.exitCode = error || peer.facts.terminal !== 'failure' || !peer.facts.client_certificate_sent ? 2 : 0;
  setTimeout(() => { if (child.exitCode === null) child.kill(); }, 1500).unref();
}
let queue = Promise.resolve();
readline.createInterface({ input: child.stdout }).on('line', line => {
  queue = queue.then(async () => {
    if (settled) return;
    if (line === 'AUTHWIRE_EAPOL_LINK_READY') {
      assert(!started); started = true;
      const start = () => { if (!received && starts < 5) { starts++; send(1); } };
      start(); timer = setInterval(start, 3000); return;
    }
    assert(/^[A-Za-z0-9+/=]+$/.test(line) && line.length <= 9000, 'Link protocol output');
    const frame = Buffer.from(line, 'base64');
    if (frame.length < 22 || !frame.subarray(6, 12).equals(nas) || frame.readUInt16BE(12) !== 0x888e || frame[15] !== 0) return;
    if (!frame.subarray(0, 6).equals(client) && !frame.subarray(0, 6).equals(multicast)) return;
    const size = frame.readUInt16BE(16); assert(size >= 4 && size <= frame.length - 18);
    received = true;
    const response = await peer.request(frame.subarray(18, size + 18));
    if (response) send(0, response);
    if (peer.facts.terminal) finish();
  }).catch(finish);
});
child.stderr.on('data', () => finish(new Error('Signed EAPOL link failed')));
child.on('error', finish); child.on('exit', code => { if (!settled) finish(new Error('EAPOL link exited ' + code)); });
deadline = setTimeout(() => finish(new Error('Bounded EAP probe timeout')), 45000);
