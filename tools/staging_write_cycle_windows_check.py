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
        lock = threading.Lock()
        metrics = {'polls': {}, 'claims': {}, 'results': {}, 'bodies': {}, 'errors': []}
        original = store.snapshot(); original_audit = store.audit()

        def setup_case():
            data = json.loads((root/'input.json').read_text(encoding='utf-8-sig'))
            native = dict(data['binding']); kid = native.pop('channel_key_sha256')
            binding = decode_binding(native | {'public_key_pem': data['public_key_pem']})
            assert binding.fields()[-1] == kid
            core._binding = lambda db: binding
            core._current = lambda db, ledger, job: True  # Explicit AD/current-target stub.
            offer = data['offer']; identity = offer['job_id']
            with store.connect() as db:
                db.execute('BEGIN IMMEDIATE'); ledger = core._read(db)
                if data['case'] != 'idle' and not any(j['id'] == identity for j in ledger['jobs']):
                    created = offer['target']['preview_record']['Preview']['checked_at']
                    ledger['jobs'].append({'id': identity, 'operation': offer['operation'],
                        'actor': str(uuid.uuid4()), 'scope': offer['scope_sha256'],
                        'created': created, 'deadline': offer['expires_at'],
                        'lease_id': '', 'lease_until': 0, 'state': 'queued',
                        'intent_sha256': offer['intent_sha256'], 'creation_sha256': 'a'*64,
                        'approval_sha256': 'b'*64, 'target': offer['target'],
                        'authorized_at': 0, 'authorized_until': 0,
                        'authorization_id': '', 'claim_sha256': '', 'result': None})
                    ops._save(db, SECTION, ledger)
            return data, identity

        class Handler(BaseHTTPRequestHandler):
            protocol_version = 'HTTP/1.1'

            def log_message(self, *args):
                pass

            def do_POST(self):
                try:
                    size = int(self.headers.get('Content-Length', '0')); assert 0 < size <= 4096
                    raw = self.rfile.read(size)
                    with lock:
                        data, identity = setup_case()
                        case = data['case']
                        if self.path == '/api/connector/v1/staging-write/poll':
                            metrics['polls'][identity] = metrics['polls'].get(identity, 0)+1
                            reply = core.poll(raw)
                            if case == 'poll_lost':
                                self.close_connection = True; self.connection.shutdown(2); return
                            if case == 'poll_bad': reply['request_id'] = '0'*64
                        elif self.path == '/api/connector/v1/staging-write/claim':
                            metrics['claims'][identity] = metrics['claims'].get(identity, 0)+1
                            reply = core.claim(raw)
                            if case == 'lost_grant':
                                self.close_connection = True; self.connection.shutdown(2); return
                        elif self.path == '/api/connector/v1/staging-write/result':
                            metrics['results'][identity] = metrics['results'].get(identity, 0)+1
                            body = json.loads(base64.b64decode(json.loads(raw)['payload']))
                            metrics['bodies'].setdefault(identity, []).append(body)
                            reply = core.complete(raw)
                            if case == 'lost_ack' and metrics['results'][identity] == 1:
                                self.close_connection = True; self.connection.shutdown(2); return
                        else:
                            raise AssertionError('Unexpected route')
                    body = json.dumps(reply, separators=(',', ':')).encode('ascii')
                    self.send_response(200); self.send_header('Content-Type', 'application/json')
                    self.send_header('Content-Length', str(len(body))); self.send_header('Connection', 'close')
                    self.end_headers(); self.wfile.write(body); self.close_connection = True
                except Exception as error:
                    metrics['errors'].append(type(error).__name__)
                    raise

        server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        context.minimum_version = ssl.TLSVersion.TLSv1_2
        context.load_cert_chain(root/'web.crt', root/'web.key')
        server.socket = context.wrap_socket(server.socket, server_side=True)
        thread = threading.Thread(target=server.serve_forever, daemon=True); thread.start()
        (root/'base.json').write_text(json.dumps({'fqdn': fqdn, 'port': server.server_port,
            'pin': cert.fingerprint(hashes.SHA256()).hex()}), encoding='ascii')
        env = {k: v for k, v in os.environ.items() if k.upper() != 'PSMODULEPATH'}
        env['AUTHWIRE_WRITE_CYCLE_DIRECTORY'] = str(root)
        try:
            subprocess.run(['powershell.exe', '-NoProfile', '-NonInteractive', '-File',
                str(Path(__file__).with_name('staging_write_execution_windows_check.ps1'))],
                check=True, timeout=650, env=env)
            native = json.loads((root/'native-summary.json').read_text(encoding='utf-8-sig'))
            assert len(native['outcomes']) == 13 and not metrics['errors']
            assert len(metrics['polls']) == 13 and set(metrics['polls'].values()) == {1}
            assert len(metrics['claims']) == 10 and set(metrics['claims'].values()) == {1}
            assert len(metrics['results']) == 9 and sorted(metrics['results'].values()) == [1]*8+[2]
            for identity, bodies in metrics['bodies'].items():
                assert all(b == bodies[0] for b in bodies)
            with store.connect() as db:
                jobs = core._read(db)['jobs']
            assert len(jobs) == 12
            assert sum(j['state'] == 'completed' and j['result']['outcome'] == 'staged' for j in jobs) == 2
            assert sum(j['state'] == 'requires_review' for j in jobs) == 7
            assert sum(j['state'] == 'authorized' for j in jobs) == 1
            assert sum(j['state'] == 'leased' for j in jobs) == 2
            assert len(store.audit()) == len(original_audit)+19
            after = store.snapshot()
            assert after['config'] == original['config'] and after['policies'] == original['policies']
            # Only audit transitions advance the business revision. Queued
            # fixture seeding and POLL bookkeeping do not advance it.
            assert after['revision'] == original['revision']+19
            print('AUTHWIRE_WRITE_CYCLE_WINDOWS_OK ' + json.dumps({
                'native_checks': native['checks'], 'cases': 13, 'original_polls': 13,
                'original_claims': 10, 'result_requests': 10, 'result_transitions': 9,
                'actual_cng_tls_sqlite_signed_child_smb': True,
                'queued_jobs_and_ad_context_simulated': True,
                'production_routes_registered': False, 'customer_changed': False}, sort_keys=True))
        finally:
            server.shutdown(); server.server_close(); thread.join(timeout=3)


if __name__ == '__main__':
    main()
