"""Disposable Windows TLS/CNG -> real SQLite claim core, no production route.

The HTTP harness seeds an already leased test offer. Binding lookup and current
AD/candidate observations are explicit stubs; RSA, claim validation, single-use
SQLite transition, HTTPS and native durable local receipts are real.
"""
from datetime import datetime, timedelta, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import base64
import json
import os
from pathlib import Path
import ssl
import subprocess
import sys
import tempfile
import threading
import time
import uuid

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.x509.oid import ExtendedKeyUsageOID, NameOID
from kaname.connector_jobs import JobError
from kaname.connector_registry import decode_binding
from kaname.operations import Operations
from kaname.staging_write_jobs import StagingWriteJobs, SECTION
from kaname.store import Store
from tools.staging_write_preclaim_wire_check import main as check_wire


def main():
    if os.name != 'nt' or os.environ.get('RUNNER_ENVIRONMENT') != 'github-hosted':
        raise RuntimeError('Hosted Windows fixture only')
    with tempfile.TemporaryDirectory(prefix='aw-write-transport-') as temp:
        root = Path(temp); fqdn = 'aw-' + uuid.uuid4().hex + '.lab.example'
        private = rsa.generate_private_key(public_exponent=65537, key_size=3072)
        name = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, fqdn)])
        now = datetime.now(timezone.utc)
        cert = (x509.CertificateBuilder().subject_name(name).issuer_name(name)
            .public_key(private.public_key()).serial_number(x509.random_serial_number())
            .not_valid_before(now-timedelta(minutes=5)).not_valid_after(now+timedelta(days=1))
            .add_extension(x509.SubjectAlternativeName([x509.DNSName(fqdn)]), False)
            .add_extension(x509.BasicConstraints(ca=True, path_length=0), True)
            .add_extension(x509.ExtendedKeyUsage([ExtendedKeyUsageOID.SERVER_AUTH]), False)
            .sign(private, hashes.SHA256()))
        (root/'web.crt').write_bytes(cert.public_bytes(serialization.Encoding.PEM))
        # Only this disposable HTTPS server key is serialized. The native
        # non-exportable connector key never leaves Windows CNG.
        (root/'web.key').write_bytes(private.private_bytes(serialization.Encoding.PEM,
            serialization.PrivateFormat.PKCS8, serialization.NoEncryption()))
        store = Store(root/'state'); ops = Operations(store)
        core = object.__new__(StagingWriteJobs)
        core.store = store; core.ops = ops; core.clock = time.time
        lock = threading.Lock(); metrics = {'claims': {}, 'grants': 0, 'replay_refused': 0,
                                          'redirect_followed': 0}
        original_business = store.snapshot(); original_audit = store.audit()

        def claim(raw):
            data = json.loads((root/'core-input.json').read_text(encoding='utf-8-sig'))
            native = dict(data['binding']); native_id = native.pop('channel_key_sha256')
            binding = decode_binding(native | {'public_key_pem': data['public_key_pem']})
            assert binding.fields()[-1] == native_id
            offer = data['offer']; identity = offer['job_id']
            core._binding = lambda db: binding  # Simulated paired context only.
            core._current = lambda db, ledger, job: True  # No AD in this fixture.
            with store.connect() as db:
                db.execute('BEGIN IMMEDIATE'); ledger = core._read(db)
                if not any(j['id'] == identity for j in ledger['jobs']):
                    created = offer['target']['preview_record']['Preview']['checked_at']
                    ledger['jobs'].append({'id': identity, 'operation': offer['operation'],
                        'actor': str(uuid.uuid4()), 'scope': offer['scope_sha256'],
                        'created': created, 'deadline': offer['expires_at'],
                        'lease_id': offer['lease_id'], 'lease_until': offer['expires_at'],
                        'state': 'leased', 'intent_sha256': offer['intent_sha256'],
                        'creation_sha256': 'a'*64, 'approval_sha256': 'b'*64,
                        'target': offer['target'], 'authorized_at': 0, 'authorized_until': 0,
                        'authorization_id': '', 'claim_sha256': '', 'result': None})
                    ops._save(db, SECTION, ledger)
            metrics['claims'][identity] = metrics['claims'].get(identity, 0)+1
            reply = core.claim(raw); metrics['grants'] += 1
            try:
                core.claim(raw)
            except JobError:
                metrics['replay_refused'] += 1
            else:
                raise AssertionError('Core replay returned a second grant')
            return reply

        class Handler(BaseHTTPRequestHandler):
            protocol_version = 'HTTP/1.1'

            def log_message(self, *args):
                pass

            def do_POST(self):
                case = (root/'case.txt').read_text().strip()
                size = int(self.headers.get('Content-Length', '0'))
                assert 0 < size <= 4096
                raw = self.rfile.read(size)
                if self.path == '/must-not-follow':
                    metrics['redirect_followed'] += 1
                if case == 'slow':
                    time.sleep(6)
                if case == 'redirect':
                    self.send_response(302); self.send_header('Location', '/must-not-follow')
                    self.send_header('Content-Length', '0'); self.end_headers(); return
                body = b'{}'; status = 200; kind = 'application/json'
                if case == 'oversized': body = b'x'*4097
                elif case == 'large_poll': body = b'"'+b'x'*20000+b'"'
                elif case == 'oversized_poll': body = b'x'*32769
                elif case == 'invalid_utf8': body = b'\xff'
                elif case == 'wrong_type': kind = 'text/plain'
                elif case == 'slow_body': body = b'{}'
                elif case in {'grant_ok', 'grant_mismatch', 'grant_lost', 'grant_disk_failure'}:
                    assert self.path == '/api/connector/v1/staging-write/claim'
                    with lock:
                        reply = claim(raw)
                    if case == 'grant_lost':
                        self.close_connection = True; self.connection.shutdown(2); return
                    if case == 'grant_mismatch': reply['request_id'] = '0'*64
                    body = json.dumps(reply, separators=(',', ':')).encode('ascii')
                self.send_response(status); self.send_header('Content-Type', kind)
                # Deliberately omit Content-Length for both oversize cases to
                # exercise the streamed bound, not merely the header guard.
                if case not in {'oversized', 'oversized_poll'}:
                    self.send_header('Content-Length', str(len(body)))
                self.send_header('Connection', 'close'); self.end_headers()
                try:
                    if case == 'slow_body':
                        self.wfile.write(body[:1]); self.wfile.flush(); time.sleep(6)
                        body = body[1:]
                    self.wfile.write(body)
                except (OSError, ssl.SSLError):
                    pass
                self.close_connection = True

        server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        context.minimum_version = ssl.TLSVersion.TLSv1_2
        context.load_cert_chain(root/'web.crt', root/'web.key')
        server.socket = context.wrap_socket(server.socket, server_side=True)
        thread = threading.Thread(target=server.serve_forever, daemon=True); thread.start()
        (root/'base.json').write_text(json.dumps({'fqdn': fqdn, 'port': server.server_port,
            'pin': cert.fingerprint(hashes.SHA256()).hex()}), encoding='ascii')
        (root/'case.txt').write_text('normal', encoding='ascii')
        env = {k: v for k, v in os.environ.items() if k.upper() != 'PSMODULEPATH'}
        env['AUTHWIRE_WRITE_TRANSPORT_DIRECTORY'] = str(root)
        env['AUTHWIRE_WRITE_WIRE_OUTPUT'] = str(root/'wire.json')
        try:
            subprocess.run(['powershell.exe', '-NoProfile', '-NonInteractive', '-File',
                str(Path(__file__).with_name('staging_write_preclaim_windows_check.ps1'))],
                check=True, timeout=150, env=env)
            check_wire(root/'wire.json')
            assert metrics['grants'] == metrics['replay_refused'] == 4
            assert len(metrics['claims']) == 4 and set(metrics['claims'].values()) == {1}
            assert not metrics['redirect_followed']
            after = store.snapshot()
            assert after['config'] == original_business['config']
            assert after['policies'] == original_business['policies']
            assert after['revision'] == original_business['revision'] + 4
            audit = store.audit()
            assert len(audit) == len(original_audit) + 4
            assert all(row['event'].startswith('staging_write_authorized:') for row in audit[:4])
            with store.connect() as db:
                jobs = core._read(db)['jobs']
            assert len(jobs) == 4 and all(j['state'] == 'authorized' for j in jobs)
            print('AUTHWIRE_WRITE_TRANSPORT_WINDOWS_OK ' + json.dumps(metrics, sort_keys=True))
        finally:
            server.shutdown(); server.server_close(); thread.join(timeout=3)


if __name__ == '__main__':
    main()
