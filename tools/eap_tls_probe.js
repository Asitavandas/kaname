'use strict';
// Operator diagnostic: explicit disposable certificate, strict server TLS.
// No Windows certificate-store selection, trust changes, or traffic logging.
const tls = require('node:tls');
const crypto = require('node:crypto');
const { Duplex } = require('node:stream');
const assert = require('node:assert/strict');
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));

class TlsPipe extends Duplex {
  constructor() { super(); this.out = []; }
  _read() {}
  _write(data, _, callback) { this.out.push(Buffer.from(data)); callback(); }
  drainFlight() { const b = Buffer.concat(this.out); this.out.length = 0; return b; }
}
function eap(code, id, type, data = Buffer.alloc(0)) {
  const b = Buffer.alloc(type === undefined ? 4 : 5 + data.length);
  b[0] = code; b[1] = id; b.writeUInt16BE(b.length, 2);
  if (type !== undefined) { b[4] = type; data.copy(b, 5); }
  return b;
}
function parseEap(b) {
  assert(b.length >= 4 && b.readUInt16BE(2) === b.length && b.length <= 8192, 'EAP length');
  assert([1, 2, 3, 4].includes(b[0]), 'EAP code');
  if (b[0] <= 2) assert(b.length >= 5, 'EAP type missing');
  else assert(b.length === 4, 'Terminal EAP payload');
  return { code: b[0], id: b[1], type: b[4], data: b.subarray(5) };
}
class FragmentReceiver {
  constructor() { this.pending = []; this.expected = null; }
  receive(data) {
    assert(data.length >= 1, 'TLS flags missing');
    const flags = data[0]; assert((flags & 0x3f) === 0, 'TLS reserved/start flags');
    let offset = 1;
    if (flags & 0x80) {
      assert(this.expected === null && this.pending.length === 0 && data.length >= 5, 'TLS length overlap');
      this.expected = data.readUInt32BE(1); offset = 5;
      assert(this.expected > 0 && this.expected <= 65536, 'TLS flight bound');
    }
    const body = data.subarray(offset);
    assert(body.length > 0 || !(flags & 0xc0), 'Empty fragment');
    this.pending.push(body);
    const size = this.pending.reduce((n, b) => n + b.length, 0);
    assert(size <= 65536 && (this.expected === null || size <= this.expected), 'TLS flight overflow');
    if (flags & 0x40) { assert(this.expected !== null && size < this.expected, 'TLS fragment length'); return null; }
    assert(this.expected === null || size === this.expected, 'Incomplete TLS flight');
    const result = Buffer.concat(this.pending); this.pending = []; this.expected = null; return result;
  }
}
function fragmentFlight(data, limit = 900) {
  assert(data.length <= 65536 && limit >= 128 && limit <= 1200);
  if (!data.length) return [Buffer.from([0])];
  const result = [];
  for (let offset = 0; offset < data.length; offset += limit) {
    const more = offset + limit < data.length;
    const first = offset === 0 && more;
    const header = Buffer.alloc(first ? 5 : 1); header[0] = (first ? 0x80 : 0) | (more ? 0x40 : 0);
    if (first) header.writeUInt32BE(data.length, 1);
    result.push(Buffer.concat([header, data.subarray(offset, offset + limit)]));
  }
  return result;
}
class CertificateObserver {
  constructor() { this.records = Buffer.alloc(0); this.handshakes = Buffer.alloc(0); this.encrypted = false; this.leaf = null; }
  feed(data) {
    this.records = Buffer.concat([this.records, data]);
    while (this.records.length >= 5) {
      const size = this.records.readUInt16BE(3); assert(size <= 18432, 'TLS record bound');
      if (this.records.length < size + 5) break;
      const kind = this.records[0], body = this.records.subarray(5, size + 5);
      this.records = this.records.subarray(size + 5);
      if (kind === 20) this.encrypted = true;
      if (kind !== 22 || this.encrypted) continue;
      this.handshakes = Buffer.concat([this.handshakes, body]);
      while (this.handshakes.length >= 4) {
        const length = this.handshakes.readUIntBE(1, 3); assert(length <= 65536, 'TLS handshake bound');
        if (this.handshakes.length < length + 4) break;
        const type = this.handshakes[0], message = this.handshakes.subarray(4, length + 4);
        this.handshakes = this.handshakes.subarray(length + 4);
        if (type === 11 && message.length > 6) {
          assert(message.readUIntBE(0, 3) === message.length - 3, 'TLS certificate chain length');
          const leafSize = message.readUIntBE(3, 3); assert(leafSize > 0 && leafSize <= message.length - 6);
          this.leaf = new crypto.X509Certificate(message.subarray(6, 6 + leafSize)).fingerprint256;
        }
      }
    }
  }
}
class EapTlsPeer {
  constructor(options) {
    this.options = options; this.receiver = new FragmentReceiver(); this.observer = new CertificateObserver();
    this.cache = new Map(); this.fragments = []; this.pipe = null; this.socket = null;
    this.facts = { requests: 0, duplicates: 0, tls_error: null, tls_established: false, server_authorized: false, terminal: null, client_certificate_sent: false };
  }
  async flight() {
    for (let i = 0; i < 30 && this.pipe.out.length === 0 && !this.facts.tls_error; i++) await delay(10);
    await delay(10);
    const data = this.pipe.drainFlight(); this.observer.feed(data);
    if (this.observer.leaf) {
      assert.equal(this.observer.leaf, new crypto.X509Certificate(this.options.cert).fingerprint256, 'Wrong client leaf transmitted');
      this.facts.client_certificate_sent = true;
    }
    this.fragments = fragmentFlight(data, this.options.fragmentSize || 900);
    return this.fragments.shift();
  }
  async request(packet) {
    const request = parseEap(packet);
    if (request.code === 3 || request.code === 4) {
      this.facts.terminal = request.code === 3 ? 'success' : 'failure';
      return null;
    }
    assert(request.code === 1 && ++this.facts.requests <= 200, 'Request bound');
    const key = crypto.createHash('sha256').update(packet).digest('hex');
    if (this.cache.has(key)) { this.facts.duplicates++; return this.cache.get(key); }
    let response;
    if (request.type === 1) response = eap(2, request.id, 1, Buffer.from(this.options.identity));
    else if (request.type !== 13) response = eap(2, request.id, 3, Buffer.from([13]));
    else {
      assert(request.data.length >= 1, 'TLS request flags');
      let body;
      if (request.data[0] === 0x20) {
        assert(request.data.length === 1 && !this.pipe, 'Repeated TLS start');
        this.pipe = new TlsPipe();
        this.socket = tls.connect({ socket: this.pipe, cert: this.options.cert, key: this.options.key,
          ca: this.options.ca, ...(this.options.crl ? { crl: this.options.crl } : {}),
          servername: this.options.servername, rejectUnauthorized: true, minVersion: 'TLSv1.2', maxVersion: 'TLSv1.2' });
        this.socket.on('error', error => { this.facts.tls_error = { code: error.code, reason: error.reason || null }; });
        this.socket.on('secureConnect', () => { this.facts.tls_established = true; this.facts.server_authorized = this.socket.authorized; });
        body = await this.flight();
      } else {
        assert(this.pipe, 'TLS request before start');
        if (this.fragments.length) {
          assert(request.data.length === 1 && request.data[0] === 0, 'Outbound fragment needs ACK');
          body = this.fragments.shift();
        } else {
          const data = this.receiver.receive(request.data);
          if (data === null) body = Buffer.from([0]);
          else { if (data.length) this.pipe.push(data); body = await this.flight(); }
        }
      }
      response = eap(2, request.id, 13, body);
    }
    this.cache.set(key, response); return response;
  }
  close() { if (this.socket) this.socket.destroy(); if (this.pipe) this.pipe.destroy(); }
}
function wiredFrame(type, body = Buffer.alloc(0), version = 1) {
  assert([0, 1].includes(type) && [1, 2].includes(version), 'Bounded wired EAPOL mode');
  if (type === 1) assert.equal(body.length, 0, 'EAPOL-Start payload');
  else { const packet = parseEap(body); assert(packet.code === 2 && [1, 3, 13].includes(packet.type), 'Only supplicant responses'); }
  const frame = Buffer.alloc(Math.max(60, 18 + body.length)); assert(frame.length <= 1500);
  // Match the successful native Windows wired captures: ALL responses use PAE.
  Buffer.from('0180c2000003', 'hex').copy(frame, 0);
  Buffer.from('0050569b7de3', 'hex').copy(frame, 6);
  frame.writeUInt16BE(0x888e, 12); frame[14] = version; frame[15] = type;
  frame.writeUInt16BE(body.length, 16); body.copy(frame, 18); return frame;
}
module.exports = { EapTlsPeer, TlsPipe, eap, parseEap, FragmentReceiver, fragmentFlight, CertificateObserver, wiredFrame };
