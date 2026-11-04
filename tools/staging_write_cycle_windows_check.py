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
from types import SimpleNamespace

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.x509.oid import ExtendedKeyUsageOID, NameOID
from kaname.connector_jobs import JobError
from kaname.connector_registry import decode_binding
from kaname.operations import Operations
from kaname.staging_write_jobs import StagingWriteJobs, SECTION, STAGE, ROLLBACK, ACK
from kaname.store import Store


def main():
    if os.name != 'nt' or os.environ.get('RUNNER_ENVIRONMENT') != 'github-hosted':
        raise RuntimeError('Hosted Windows fixture only')
    grant_mode = os.environ.get('AUTHWIRE_ROLLBACK_AUTHORIZATION_CHECK') == '1'
    execution_mode = os.environ.get('AUTHWIRE_ROLLBACK_EXECUTION_CHECK') == '1'
    lifecycle_mode = os.environ.get('AUTHWIRE_WRITE_LIFECYCLE_CHECK') == '1'
    history_mode = os.environ.get('AUTHWIRE_WRITE_HISTORY_CHECK') == '1'
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
        prepared_key = None
        prepared_case = None

        def setup_case(allow_prepare=True):
            nonlocal prepared_key, prepared_case
            mode_file = root/'rollback-mode.json'
            input_raw = (root/'input.json').read_bytes()
            mode_raw = mode_file.read_bytes() if mode_file.exists() else b''
            current_key = (input_raw, mode_raw)
            if current_key == prepared_key:
                return prepared_case
            if not allow_prepare:
                raise AssertionError('Fixture queue must be prepared before product HTTP')
            data = json.loads(input_raw.decode('utf-8-sig'))
            native = dict(data['binding']); kid = native.pop('channel_key_sha256')
            binding = decode_binding(native | {'public_key_pem': data['public_key_pem']})
            assert binding.fields()[-1] == kid
            core._binding = lambda db: binding
            # Stage positive AD/current lookup is a stub; rollback uses the
            # real original-result/current-target checks with only AD stubbed.
            core._current = lambda db, ledger, job: (True if job['operation'] == STAGE
                else StagingWriteJobs._current(core, db, ledger, job))
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
            if grant_mode and mode_file.exists():
                mode = json.loads(mode_raw.decode('utf-8-sig'))
                assert mode['stage_job_id'] == identity
                target = offer['target']['scope_target']
                def current_target(db, candidate_id):
                    assert candidate_id == target['candidate_id']
                    return target  # Explicit positive AD/candidate observation.
                core.previews = SimpleNamespace(_target=current_target)
                with store.connect() as db:
                    ledger = core._read(db)
                if mode['case'] != 'lc_idle' and not any(j['id'] == mode['job_id'] for j in ledger['jobs']):
                    req = {'expected_revision': store.snapshot()['revision'],
                        'job_id': mode['job_id'], 'operation': ROLLBACK,
                        'candidate_id': target['candidate_id'],
                        'staging_preview_sha256': offer['target']['preview_record']['PreviewSha256'],
                        'stage_job_id': identity, 'acknowledge': ACK[ROLLBACK]}
                    review = core.review(req, mode['actor'])
                    core.create(req | {'review_hash': review['review_hash']}, mode['actor'])
                prepared_case = (data | {'case': mode['case']}, mode['job_id'])
                prepared_key = current_key
                return prepared_case
            # Before the mode file exists this is the original stage, even if
            # the outer case describes a later rollback transport failure.
            prepared_case = ((data | {'case': 'success'} if grant_mode else data), identity)
            prepared_key = current_key
            return prepared_case

        # Queue creation/AD fixture registration is test setup, not POLL work.
        # Finish it before creating the actual signed request. The handler still
        # runs the unchanged production core inside its original HTTP deadline.
        prepare_stop = threading.Event()
        def prepare_cases():
            seen = ''
            while not prepare_stop.wait(0.02):
                request_file = root/'prepare-request.txt'
                if not request_file.exists():
                    continue
                try:
                    token = request_file.read_text(encoding='ascii')
                except OSError:
                    continue
                if len(token) != 32 or any(c not in '0123456789abcdef' for c in token) or token == seen:
                    continue
                try:
                    with lock:
                        setup_case()
                    (root/'prepare-ready.tmp').write_text(token, encoding='ascii')
                    (root/'prepare-ready.tmp').replace(root/'prepare-ready.txt')
                    seen = token
                except Exception as error:
                    print('FIXTURE_PREPARE_FAILURE '+type(error).__name__, flush=True)
                    (root/'prepare-failed.tmp').write_text(token, encoding='ascii')
                    (root/'prepare-failed.tmp').replace(root/'prepare-failed.txt')
                    seen = token
        preparer = threading.Thread(target=prepare_cases, daemon=True)
        preparer.start()

        class Handler(BaseHTTPRequestHandler):
            protocol_version = 'HTTP/1.1'

            def log_message(self, *args):
                pass

            def do_POST(self):
                observed_start = time.monotonic()
                try:
                    size = int(self.headers.get('Content-Length', '0')); assert 0 < size <= 4096
                    raw = self.rfile.read(size)
                    with lock:
                        data, identity = setup_case(allow_prepare=False)
                        case = data['case']
                        if self.path == '/api/connector/v1/staging-write/poll':
                            metrics['polls'][identity] = metrics['polls'].get(identity, 0)+1
                            reply = core.poll(raw)
                            if case in {'poll_lost', 'lc_lost_poll'}:
                                self.close_connection = True; self.connection.shutdown(2); return
                            if case in {'poll_bad', 'lc_bad_poll'}: reply['request_id'] = '0'*64
                        elif self.path == '/api/connector/v1/staging-write/claim':
                            metrics['claims'][identity] = metrics['claims'].get(identity, 0)+1
                            reply = core.claim(raw)
                            if case in {'lost_grant', 'rollback_lost_grant', 'lc_lost_claim'}:
                                self.close_connection = True; self.connection.shutdown(2); return
                            if case == 'rollback_bad_grant':
                                reply['operation'] = STAGE
                        elif self.path == '/api/connector/v1/staging-write/result':
                            metrics['results'][identity] = metrics['results'].get(identity, 0)+1
                            body = json.loads(base64.b64decode(json.loads(raw)['payload']))
                            metrics['bodies'].setdefault(identity, []).append(body)
                            reply = core.complete(raw)
                            if case in {'lost_ack', 'rb_execute_lost_ack', 'lc_lost_ack'} and metrics['results'][identity] == 1:
                                self.close_connection = True; self.connection.shutdown(2); return
                        else:
                            raise AssertionError('Unexpected route')
                    body = json.dumps(reply, separators=(',', ':')).encode('ascii')
                    if lifecycle_mode:
                        print('LIFECYCLE_FIXTURE_HTTP_READY ' + json.dumps({
                            'kind': self.path.rsplit('/', 1)[-1],
                            'elapsed_ms': round((time.monotonic()-observed_start)*1000),
                            'reply_bytes': len(body)}, sort_keys=True), flush=True)
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
                # Nine independent rollback cases include real signed child/SMB
                # setup and teardown. This is the outer fixture budget only;
                # production HTTP/grant/reader/child deadlines stay unchanged.
                check=True, timeout=1320 if execution_mode else (1100 if lifecycle_mode else 650), env=env)
            native = json.loads((root/'native-summary.json').read_text(encoding='utf-8-sig'))
            if history_mode:
                assert len(native['outcomes']) == 4 and not metrics['errors']
                assert len(metrics['polls']) == 7 and sorted(metrics['polls'].values()) == [1]*5+[2, 3]
                assert len(metrics['claims']) == 5 and set(metrics['claims'].values()) == {1}
                assert len(metrics['results']) == 5 and set(metrics['results'].values()) == {1}
                with store.connect() as db:
                    jobs = core._read(db)['jobs']
                assert len(jobs) == 6
                assert sum(j['operation'] == STAGE and j['state'] == 'completed' for j in jobs) == 4
                assert sum(j['operation'] == ROLLBACK and j['state'] == 'requires_review' for j in jobs) == 1
                assert sum(j['operation'] == ROLLBACK and j['state'] == 'leased' for j in jobs) == 1
                after = store.snapshot()
                assert after['revision'] == original['revision']+12
                assert len(store.audit()) == len(original_audit)+12
                assert after['config'] == original['config'] and after['policies'] == original['policies']
                print('AUTHWIRE_WRITE_HISTORY_WINDOWS_OK ' + json.dumps({
                    'native_checks': native['checks'], 'cases': 4,
                    'real_cng_ntfs_archives': 2, 'archived_cycles': 128,
                    'synthetic_signed_idle_records': 251,
                    'actual_core_poll_requests': 10, 'claim_requests': 5, 'result_requests': 5,
                    'interrupted_copy_preserves_64_active_originals': True,
                    'foreign_child_partial_retirement_requires_review': True,
                    'positive_ad_content_service_identity_simulated': True,
                    'actual_machine_reboot_tested': False,
                    'active_worker_registered': False, 'customer_changed': False}, sort_keys=True))
                return
            if lifecycle_mode:
                assert len(native['outcomes']) == 8 and not metrics['errors']
                assert len(metrics['polls']) == 15 and sorted(metrics['polls'].values()) == [1]*14+[2]
                assert len(metrics['claims']) == 12 and set(metrics['claims'].values()) == {1}
                assert len(metrics['results']) == 11 and sorted(metrics['results'].values()) == [1]*10+[2]
                assert all(all(b == bodies[0] for b in bodies) for bodies in metrics['bodies'].values())
                with store.connect() as db:
                    jobs = core._read(db)['jobs']
                assert len(jobs) == 14
                assert sum(j['operation'] == STAGE and j['state'] == 'completed' and j['result']['outcome'] == 'staged' for j in jobs) == 8
                assert sum(j['operation'] == ROLLBACK and j['state'] == 'completed' and j['result']['outcome'] == 'rolled_back' for j in jobs) == 2
                assert sum(j['operation'] == ROLLBACK and j['state'] == 'requires_review' for j in jobs) == 1
                assert sum(j['operation'] == ROLLBACK and j['state'] == 'authorized' for j in jobs) == 1
                assert sum(j['operation'] == ROLLBACK and j['state'] == 'leased' for j in jobs) == 2
                after = store.snapshot()
                assert len(store.audit()) == len(original_audit)+29
                assert after['revision'] == original['revision']+29
                assert after['config'] == original['config'] and after['policies'] == original['policies']
                print('AUTHWIRE_WRITE_LIFECYCLE_WINDOWS_OK ' + json.dumps({
                    'native_checks': native['checks'], 'cases': 8,
                    'actual_cng_tls_sqlite_signed_child_smb': True,
                    'poll_requests': 16, 'claim_requests': 12,
                    'result_requests': 12, 'result_transitions': 11,
                    'actual_core_rollback_review_create': True,
                    'saved_grant_restart_boundary_simulated': True,
                    'actual_machine_reboot_tested': False,
                    'positive_ad_content_service_identity_simulated': True,
                    'active_worker_registered': False, 'customer_changed': False}, sort_keys=True))
                return
            if execution_mode:
                assert len(native['outcomes']) == 9 and not metrics['errors']
                assert len(metrics['polls']) == len(metrics['claims']) == len(metrics['results']) == 18
                assert set(metrics['polls'].values()) == set(metrics['claims'].values()) == {1}
                assert sorted(metrics['results'].values()) == [1]*17+[2]
                assert all(all(b == bodies[0] for b in bodies) for bodies in metrics['bodies'].values())
                with store.connect() as db:
                    jobs = core._read(db)['jobs']
                assert len(jobs) == 18
                assert sum(j['operation'] == STAGE and j['state'] == 'completed' and j['result']['outcome'] == 'staged' for j in jobs) == 9
                assert sum(j['operation'] == ROLLBACK and j['state'] == 'completed' and j['result']['outcome'] == 'rolled_back' for j in jobs) == 2
                assert sum(j['operation'] == ROLLBACK and j['state'] == 'requires_review' for j in jobs) == 7
                after = store.snapshot()
                assert len(store.audit()) == len(original_audit)+45
                assert after['revision'] == original['revision']+45
                assert after['config'] == original['config'] and after['policies'] == original['policies']
                print('AUTHWIRE_ROLLBACK_EXECUTION_WINDOWS_OK ' + json.dumps({
                    'native_checks': native['checks'], 'cases': 9,
                    'actual_separate_review_create_poll_claim_result': True,
                    'rollback_claims': 9, 'rollback_result_transitions': 9,
                    'rollback_result_requests': 10, 'verified_rollback_successes': 2,
                    'unconfirmed_review_results': 7,
                    'actual_cng_tls_sqlite_signed_child_smb_delete': True,
                    'positive_ad_content_service_identity_simulated': True,
                    'production_routes_registered': False, 'customer_changed': False}, sort_keys=True))
                return
            if grant_mode:
                assert len(native['outcomes']) == 8 and not metrics['errors']
                assert len(metrics['polls']) == 16 and set(metrics['polls'].values()) == {1}
                assert len(metrics['claims']) == 15 and set(metrics['claims'].values()) == {1}
                assert len(metrics['results']) == 8 and set(metrics['results'].values()) == {1}
                with store.connect() as db:
                    jobs = core._read(db)['jobs']
                assert len(jobs) == 16
                assert sum(j['operation'] == STAGE and j['state'] == 'completed' and j['result']['outcome'] == 'staged' for j in jobs) == 8
                assert sum(j['operation'] == ROLLBACK and j['state'] == 'authorized' for j in jobs) == 7
                assert sum(j['operation'] == ROLLBACK and j['state'] == 'leased' for j in jobs) == 1
                assert len(store.audit()) == len(original_audit)+31
                after = store.snapshot()
                assert after['revision'] == original['revision']+31
                assert after['config'] == original['config'] and after['policies'] == original['policies']
                print('AUTHWIRE_ROLLBACK_AUTHORIZATION_WINDOWS_OK ' + json.dumps({
                    'native_checks': native['checks'], 'cases': 8,
                    'actual_separate_review_create_poll_claim': True,
                    'rollback_claims': 7, 'rollback_results': 0,
                    'actual_cng_tls_sqlite_signed_reader_smb': True,
                    'positive_ad_content_service_identity_simulated': True,
                    'files_deleted': False, 'production_routes_registered': False,
                    'customer_changed': False}, sort_keys=True))
                return
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
        except subprocess.CalledProcessError:
            # Safe fixture diagnostics only: no proof, URL, payload or key data.
            print('AUTHWIRE_WRITE_CORE_FAILURE_COUNTS ' + json.dumps({
                'polls': sum(metrics['polls'].values()),
                'claims': sum(metrics['claims'].values()),
                'results': sum(metrics['results'].values()),
                'errors': metrics['errors']}, sort_keys=True), flush=True)
            raise
        finally:
            prepare_stop.set(); preparer.join(timeout=3)
            server.shutdown(); server.server_close(); thread.join(timeout=3)


if __name__ == '__main__':
    main()

