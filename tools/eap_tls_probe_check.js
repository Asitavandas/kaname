'use strict';
// Full TLS over fragmented/replayed EAP; disposable local CA only.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const net = require('node:net');
const tls = require('node:tls');
const { execFileSync } = require('node:child_process');
const { EapTlsPeer, eap, parseEap, FragmentReceiver, fragmentFlight } = require('./eap_tls_probe');
const delay = ms => new Promise(r => setTimeout(r, ms));
const fixtureSource = `
import sys
from pathlib import Path
from datetime import datetime,timedelta,timezone
from cryptography import x509
from cryptography.hazmat.primitives import hashes,serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.x509.oid import NameOID,ExtendedKeyUsageOID
p=Path(sys.argv[1]);now=datetime.now(timezone.utc)
def key():return rsa.generate_private_key(65537,2048)
def name(v):return x509.Name([x509.NameAttribute(NameOID.COMMON_NAME,v)])
def cert(k,subject,issuer,ik,ca=False,expired=False,server=False):
 b=x509.CertificateBuilder().subject_name(name(subject)).issuer_name(issuer).public_key(k.public_key()).serial_number(x509.random_serial_number()).not_valid_before(now-timedelta(days=2)).not_valid_after(now+timedelta(days=1) if not expired else now-timedelta(days=1)).add_extension(x509.BasicConstraints(ca,None if ca else None),True)
 if not ca:b=b.add_extension(x509.ExtendedKeyUsage([ExtendedKeyUsageOID.SERVER_AUTH if server else ExtendedKeyUsageOID.CLIENT_AUTH]),False)
 if server:b=b.add_extension(x509.SubjectAlternativeName([x509.DNSName('probe.example.test')]),False)
 return b.sign(ik,hashes.SHA256())
def save(n,k,c):
 (p/(n+'.pem')).write_bytes(c.public_bytes(serialization.Encoding.PEM))
 (p/(n+'-key.pem')).write_bytes(k.private_bytes(serialization.Encoding.PEM,serialization.PrivateFormat.PKCS8,serialization.NoEncryption()))
rk=key();root=cert(rk,'root',name('root'),rk,ca=True);save('root',rk,root)
uk=key();untrusted=cert(uk,'untrusted',name('untrusted'),uk,ca=True);save('untrusted',uk,untrusted)
for n in ('server','valid','expired','rogue'):
 k=key();other=n=='rogue';c=cert(k,n,untrusted.subject if other else root.subject,uk if other else rk,expired=n=='expired',server=n=='server');save(n,k,c)
`;
async function scenario(directory, name, wrongServer = false) {
  const read = n => fs.readFileSync(path.join(directory, n));
  let accepted = false, serverError = null;
  const server = tls.createServer({ cert: read('server.pem'), key: read('server-key.pem'), ca: read('root.pem'),
    requestCert: true, rejectUnauthorized: true, minVersion: 'TLSv1.2', maxVersion: 'TLSv1.2' }, socket => { accepted = socket.authorized; });
  server.on('tlsClientError', (error, socket) => { serverError = socket.authorizationError || error.code; });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  const wire = net.connect(server.address().port, '127.0.0.1');
  const outgoing = []; wire.on('data', b => outgoing.push(b)); wire.on('error', () => {});
  const peer = new EapTlsPeer({ cert: read(name + '.pem'), key: read(name + '-key.pem'), ca: read('root.pem'),
    servername: wrongServer ? 'wrong.example.test' : 'probe.example.test', identity: 'AuthWire-isolated-probe', fragmentSize: 128 });
  let id = 0, clientFlights = 0;
  const receiver = new FragmentReceiver();
  async function request(type, body) {
    const packet = eap(1, ++id % 256, type, body);
    const response = await peer.request(packet);
    const repeated = await peer.request(packet); assert.deepEqual(response, repeated, 'Replay response differs');
    const result = parseEap(response); assert.equal(result.id, packet[1]); return result;
  }
  async function transmitClient(first) {
    let response = first;
    for (let i = 0; i < 100; i++) {
      const flight = receiver.receive(response.data);
      if (flight !== null) { if (flight.length) { wire.write(flight); clientFlights++; } return; }
      response = await request(13, Buffer.from([0]));
    }
    throw new Error('Client fragment bound');
  }
  try {
    assert.equal((await request(1, Buffer.from('identity?'))).type, 1);
    await transmitClient(await request(13, Buffer.from([0x20])));
    for (let turn = 0; turn < 80; turn++) {
      for (let i = 0; i < 30 && outgoing.length === 0 && !serverError && !accepted; i++) await delay(10);
      await delay(10);
      const flight = Buffer.concat(outgoing.splice(0));
      if (flight.length) {
        const fragments = fragmentFlight(flight, 128);
        for (let i = 0; i < fragments.length; i++) {
          const response = await request(13, fragments[i]);
          if (i < fragments.length - 1) assert.deepEqual(response.data, Buffer.from([0]));
          else await transmitClient(response);
        }
      }
      await delay(10);
      if ((accepted && peer.facts.tls_established) || serverError || peer.facts.tls_error) break;
    }
    const terminal = accepted && peer.facts.tls_established ? 3 : 4;
    await peer.request(eap(terminal, id));
    if (name === 'valid' && !wrongServer) {
      assert(accepted && peer.facts.server_authorized && peer.facts.client_certificate_sent);
    } else {
      if (wrongServer) { assert(!peer.facts.tls_established && !peer.facts.server_authorized); assert.equal(peer.facts.tls_error.code, 'ERR_TLS_CERT_ALTNAME_INVALID'); }
      else {
        assert(!accepted, 'Invalid credential accepted');
        assert(peer.facts.client_certificate_sent, 'Invalid client certificate never reached TLS');
        assert(serverError, 'No authoritative TLS rejection');
        if (name === 'expired') assert.match(serverError, /EXPIRED/, JSON.stringify({serverError, facts:peer.facts}));
        else assert.match(serverError, /ISSUER|SELF_SIGNED|VERIFY|TRUSTED/);
      }
    }
    assert(peer.facts.duplicates > 5 && clientFlights > 1);
    return { case: wrongServer ? 'wrong-server-name' : name, server_accepted: accepted, server_error: serverError,
      ...peer.facts };
  } finally { peer.close(); wire.destroy(); await new Promise(resolve => server.close(resolve)); }
}
(async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'authwire-eap-probe-'));
  try {
    execFileSync(process.env.PYTHON || 'python', ['-c', fixtureSource, dir], { stdio: 'pipe' });
    const results = [];
    for (const name of ['valid', 'expired', 'rogue']) results.push(await scenario(dir, name));
    results.push(await scenario(dir, 'valid', true));
    // Explicitly reject malformed EAP lengths and fragment overlap/overflow.
    const peer = new EapTlsPeer({ identity: 'fixture' });
    await assert.rejects(peer.request(Buffer.from([1, 1, 0, 100, 13, 32])));
    assert.throws(() => new FragmentReceiver().receive(Buffer.from([0x80, 0, 1, 0, 1])));
    const receiver = new FragmentReceiver();
    assert.equal(receiver.receive(Buffer.from([0xc0, 0, 0, 0, 2, 1])), null);
    assert.throws(() => receiver.receive(Buffer.from([0x80, 0, 0, 0, 2, 2])));
    console.log(JSON.stringify({ event: 'AUTHWIRE_EAP_TLS_PROBE_TRANSPORT_CHECK', results }));
  } finally { fs.rmSync(dir, { recursive: true, force: true }); }
})().catch(error => { console.error(error); process.exitCode = 1; });
