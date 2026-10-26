"""Real SQLite, binding, RSA and durable probe lifecycle; no AD/GPO calls."""
import base64
import concurrent.futures
import copy
import json
import secrets
import sqlite3
from unittest.mock import patch
import unittest
import uuid

from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import padding

from kaname.connector_jobs import ConnectorJobs, JobError, SECTION, OPERATION, POLL_PATH, RESULT_PATH, scope_id
from kaname.connector_registry import decode_binding, ConnectorRegistry
from kaname.store import ConflictError
from . import test_connector_registry as registry_fixtures


class ConnectorJobTests(unittest.TestCase):
    setUpClass = classmethod(registry_fixtures.ConnectorRegistryTests.setUpClass.__func__)
    tearDownClass = classmethod(registry_fixtures.ConnectorRegistryTests.tearDownClass.__func__)
    context = registry_fixtures.ConnectorRegistryTests.context
    pem = staticmethod(registry_fixtures.ConnectorRegistryTests.pem)
    intent = registry_fixtures.ConnectorRegistryTests.intent
    prepare = registry_fixtures.ConnectorRegistryTests.prepare
    pair = registry_fixtures.ConnectorRegistryTests.pair

    def setUp(self):
        registry_fixtures.ConnectorRegistryTests.setUp(self)
        self.now = 1800000000
        self.pair()
        self.jobs = ConnectorJobs(self.registry, wall_clock=lambda: self.now)

    def binding(self):
        with self.store.connect() as db:
            return decode_binding(self.registry._read(db)['binding'])

    def request(self, **changes):
        return {'expected_revision': self.store.snapshot()['revision'], 'job_id': str(uuid.uuid4()), 'operation': OPERATION} | changes

    def create(self, value=None):
        v = value or self.request()
        return self.jobs.create(v | {'preview_hash': self.jobs.preview(v)['preview_hash']}, self.actor)

    def proof(self, kind='POLL', body=None, *, binding=None, private=None, changes=None, payload=None):
        binding = binding or self.binding()
        raw = payload if payload is not None else json.dumps(body or {}, separators=(',', ':')).encode()
        from kaname.connector_jobs import sha
        fields = ['AUTHWIRE-CONNECTOR-JOB-' + kind + '-V1'] + binding.fields() + [
            secrets.token_hex(32), secrets.token_hex(32), str(self.now), str(self.now + 60), sha(raw), 'POST',
            POLL_PATH if kind == 'POLL' else RESULT_PATH]
        for index, value in (changes or {}).items():
            fields[index] = value
        frame = ('\n'.join(fields) + '\n').encode('ascii')
        signature = (private or self.private).sign(frame, padding.PKCS1v15(), hashes.SHA256())
        return json.dumps({'frame': base64.b64encode(frame).decode(), 'signature': base64.b64encode(signature).decode(),
                           'payload': base64.b64encode(raw).decode()}).encode()

    def result(self, offer, **changes):
        return {'job_id': offer['job_id'], 'lease_id': offer['lease_id'], 'intent_sha256': offer['intent_sha256'],
                'outcome': 'probe_completed', 'release_id': str(uuid.uuid4())} | changes

    def raw_store(self):
        with self.store.connect() as db:
            row = db.execute('SELECT payload FROM runtime_settings WHERE name=?', (SECTION,)).fetchone()
            return row[0] if row else None

    def test_read_preview_and_empty_status_create_no_storage(self):
        before, audit = self.store.snapshot(), self.store.audit()
        self.assertFalse(self.jobs.status()['worker_probe_ready'])
        preview = self.jobs.preview(self.request())
        self.assertTrue(preview['read_only']); self.assertFalse(preview['can_apply'])
        self.assertIsNone(self.raw_store())
        self.assertEqual((before, audit), (self.store.snapshot(), self.store.audit()))

    def test_probe_roundtrip_cannot_claim_gpo_or_directory_authority(self):
        before = self.store.snapshot(); job = self.create()
        offer = self.jobs.poll(self.proof())
        self.assertEqual(job['job_id'], offer['job_id'])
        self.assertTrue(offer['read_only']); self.assertFalse(offer['can_apply'])
        body = self.result(offer)
        receipt = self.jobs.complete(self.proof('RESULT', body))
        self.assertTrue(receipt['result_recorded'])
        status = self.jobs.status(); self.assertEqual('completed', status['jobs'][0]['state'])
        self.assertTrue(status['worker_probe_ready']); self.assertFalse(status['can_apply'])
        self.assertEqual(body, status['jobs'][0]['result'])
        self.assertEqual(before['config'], self.store.snapshot()['config'])
        self.assertEqual(before['policies'], self.store.snapshot()['policies'])
        self.assertEqual('', self.jobs.poll(self.proof())['job_id'])

    def test_create_lost_reply_reuses_id_without_requeue_or_second_audit(self):
        v = self.request(); value = v | {'preview_hash': self.jobs.preview(v)['preview_hash']}
        first = self.jobs.create(value, self.actor); audit = self.store.audit()
        self.assertEqual(first, self.jobs.create(value, self.actor))
        self.assertEqual(audit, self.store.audit())
        offer = self.jobs.poll(self.proof()); self.jobs.complete(self.proof('RESULT', self.result(offer)))
        self.assertEqual('completed', self.jobs.create(value, self.actor)['state'])
        self.assertEqual('', self.jobs.poll(self.proof())['job_id'])

    def test_job_id_cannot_change_owner_or_request(self):
        v = self.request(); value = v | {'preview_hash': self.jobs.preview(v)['preview_hash']}
        self.jobs.create(value, self.actor)
        for change, actor in [({}, str(uuid.uuid4())), ({'preview_hash': '0'*64}, self.actor)]:
            with self.assertRaisesRegex(JobError, 'ID_CONFLICT'):
                self.jobs.create(value | change, actor)

    def test_duplicate_result_is_idempotent_across_restart(self):
        self.create(); offer = self.jobs.poll(self.proof()); body = self.result(offer)
        raw = self.proof('RESULT', body)
        self.jobs.complete(raw); audit = self.store.audit()
        restarted = ConnectorJobs(ConnectorRegistry(self.ops, self.cert), wall_clock=lambda: self.now)
        self.assertTrue(restarted.complete(raw)['result_recorded'])
        self.assertTrue(restarted.complete(self.proof('RESULT', body))['result_recorded'])
        self.assertEqual(audit, self.store.audit())
        self.assertEqual('', restarted.poll(self.proof())['job_id'])

    def test_conflicting_result_cannot_replace_accepted_result(self):
        self.create(); offer = self.jobs.poll(self.proof()); body = self.result(offer)
        self.jobs.complete(self.proof('RESULT', body)); before = self.raw_store()
        with self.assertRaisesRegex(JobError, 'RESULT_CONFLICT'):
            self.jobs.complete(self.proof('RESULT', body | {'release_id': str(uuid.uuid4())}))
        self.assertEqual(before, self.raw_store())

    def test_poll_replay_rejected_durably_without_new_lease(self):
        self.create(); raw = self.proof(); offer = self.jobs.poll(raw); before = self.raw_store()
        restarted = ConnectorJobs(self.registry, wall_clock=lambda: self.now)
        with self.assertRaises(JobError): restarted.poll(raw)
        self.assertEqual(before, self.raw_store())
        again = restarted.poll(self.proof())
        self.assertEqual(offer['lease_id'], again['lease_id'])

    def test_parallel_poll_and_results_have_one_lease_and_completion(self):
        self.create(); requests = [self.proof() for _ in range(6)]
        with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
            offers = list(pool.map(self.jobs.poll, requests))
        self.assertEqual(1, len({o['lease_id'] for o in offers}))
        body = self.result(offers[0]); results = [self.proof('RESULT', body) for _ in range(6)]
        with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
            receipts = list(pool.map(self.jobs.complete, results))
        self.assertTrue(all(r['result_recorded'] for r in receipts))
        self.assertEqual(1, sum(a['event'].startswith('connector_probe_completed:') for a in self.store.audit()))

    def test_wrong_key_purpose_binding_method_or_payload_has_no_write(self):
        self.create(); before = self.raw_store()
        for raw in [self.proof(private=self.other), self.proof(changes={0:'AUTHWIRE-CONNECTOR-POLL-V1'}),
                    self.proof(changes={3:'2'}), self.proof(changes={15:'GET'}),
                    self.proof(changes={16:RESULT_PATH}), self.proof(body={'command':'whoami'}),
                    self.proof(changes={14:'0'*64})]:
            with self.subTest(raw=raw[:12]), self.assertRaises(JobError): self.jobs.poll(raw)
        self.assertEqual(before, self.raw_store())

    def test_duplicate_json_noncanonical_base64_and_oversize_rejected(self):
        self.create(); before = self.raw_store(); good = json.loads(self.proof())
        bad = json.dumps(good).replace('"frame":', '"frame":"bad","frame":').encode()
        for raw in [bad, self.proof(payload=b'{"x":1,"x":2}'), b'{}', b'x'*4097,
                    json.dumps(good | {'signature': good['signature']+'\n'}).encode(),
                    json.dumps(good | {'extra': 1}).encode()]:
            with self.assertRaises(JobError): self.jobs.poll(raw)
        self.assertEqual(before, self.raw_store())

    def test_expired_and_future_proof_rejected(self):
        raw = self.proof(); self.now += 60
        with self.assertRaises(JobError): self.jobs.poll(raw)
        raw = self.proof(); self.now -= 6
        with self.assertRaises(JobError): self.jobs.poll(raw)

    def test_unclaimed_job_expires_and_rollback_clock_does_not_execute(self):
        self.create(); self.now -= 6
        self.assertEqual('', self.jobs.poll(self.proof())['job_id'])
        self.now += 306
        self.assertEqual('', self.jobs.poll(self.proof())['job_id'])
        self.assertEqual('expired', self.jobs.status()['jobs'][0]['state'])

    def test_expired_lease_is_not_reassigned_or_completed(self):
        self.create(); offer = self.jobs.poll(self.proof()); self.now += 90
        self.assertEqual('', self.jobs.poll(self.proof())['job_id'])
        with self.assertRaises(JobError): self.jobs.complete(self.proof('RESULT', self.result(offer)))

    def test_unknown_gpo_command_and_authority_overclaim_are_refused(self):
        for change in [{'operation':'gpo.apply'}, {'command':'powershell'}, {'gpo_id':str(uuid.uuid4())}]:
            with self.assertRaises(ValueError): self.jobs.preview(self.request() | change)
        self.create(); offer = self.jobs.poll(self.proof()); body = self.result(offer)
        for change in [{'can_apply':True}, {'gpo_changed':True}, {'outcome':'gpo_applied'}, {'release_id':None}]:
            with self.assertRaises(JobError): self.jobs.complete(self.proof('RESULT', body | change))

    def test_old_preview_and_same_revision_rotation_are_refused(self):
        v = self.request(); p = self.jobs.preview(v)
        with self.assertRaisesRegex(JobError, 'PREVIEW_STALE'):
            self.jobs.create(v | {'preview_hash':'0'*64}, self.actor)
        self.registry.apply(self.prepare(self.intent('rotate', self.candidate | {'public_key_pem': self.pem(self.other)})), self.actor)
        with self.assertRaises(ConflictError): self.jobs.create(v | {'preview_hash':p['preview_hash']}, self.actor)

    def test_rotation_revocation_and_context_change_reject_queued_peer_work(self):
        self.create(); binding = self.binding(); offer = self.jobs.poll(self.proof())
        raw = self.proof('RESULT', self.result(offer), binding=binding)
        self.registry.apply(self.prepare(self.intent('revoke')), self.actor)
        with self.assertRaises(JobError): self.jobs.poll(self.proof(binding=binding))
        with self.assertRaises(JobError): self.jobs.complete(raw)
        self.assertEqual('obsolete', self.jobs.status()['jobs'][0]['state'])

    def test_live_tls_context_change_blocks_jobs_without_changing_job_store(self):
        self.create(); before = self.raw_store(); self.registry.web_certificate = b'not a cert'
        with self.assertRaises(ValueError): self.jobs.poll(self.proof())
        self.assertEqual(before, self.raw_store())

    def test_queued_records_and_poll_replay_cache_survive_new_engine(self):
        job = self.create(); restarted = ConnectorJobs(self.registry, wall_clock=lambda: self.now)
        self.assertEqual(job['job_id'], restarted.poll(self.proof())['job_id'])

    def test_active_job_and_total_ledger_limits_fail_closed(self):
        for _ in range(4): self.create()
        with self.assertRaisesRegex(JobError, 'BUSY'): self.create()
        self.now += 301
        for _ in range(28):
            self.create(); self.now += 301
        with self.assertRaisesRegex(JobError, 'LIMIT'): self.create()
        self.assertEqual(32, len(self.jobs.status()['jobs']))

    def test_corrupt_store_fails_closed_without_repair(self):
        with self.store.connect() as db:
            db.execute('INSERT INTO runtime_settings VALUES (?,?)', (SECTION, '{"format":1,"jobs":"bad"}'))
        before = self.raw_store()
        for action in [self.jobs.status, lambda:self.jobs.poll(self.proof()), lambda:self.create()]:
            with self.assertRaisesRegex(JobError, 'STORE_INVALID'): action()
        self.assertEqual(before, self.raw_store())

    def test_audit_failure_rolls_back_create_and_completion(self):
        value = self.request(); payload = value | {'preview_hash': self.jobs.preview(value)['preview_hash']}
        before = self.store.snapshot()
        with patch.object(self.ops, '_audit', side_effect=sqlite3.OperationalError('fixture audit unavailable')):
            with self.assertRaises(sqlite3.Error): self.jobs.create(payload, self.actor)
        self.assertIsNone(self.raw_store()); self.assertEqual(before, self.store.snapshot())
        self.jobs.create(payload, self.actor); offer = self.jobs.poll(self.proof()); old = self.raw_store()
        with patch.object(self.ops, '_audit', side_effect=sqlite3.OperationalError('fixture audit unavailable')):
            with self.assertRaises(sqlite3.Error): self.jobs.complete(self.proof('RESULT', self.result(offer)))
        self.assertEqual(old, self.raw_store()); self.assertEqual('leased', self.jobs.status()['jobs'][0]['state'])

    def test_binding_corruption_is_not_silently_reported_as_disconnected(self):
        from kaname.connector_registry import SECTION as PAIRING, RegistryError
        with self.store.connect() as db:
            db.execute('UPDATE runtime_settings SET payload=? WHERE name=?', ('{}', PAIRING))
        with self.assertRaisesRegex(RegistryError, 'STORE_INVALID'): self.jobs.status()

    def test_non_utf8_outer_proof_and_payload_are_rejected(self):
        raw = self.proof()
        with self.assertRaises(JobError): self.jobs.poll(raw.decode().encode('utf-16'))
        with self.assertRaises(JobError): self.jobs.poll(self.proof(payload='{}'.encode('utf-16')))

    def test_worker_ready_expires_without_changing_job_state(self):
        self.jobs.poll(self.proof()); self.assertTrue(self.jobs.status()['worker_probe_ready'])
        self.now += 90
        self.assertFalse(self.jobs.status()['worker_probe_ready'])

    def test_poll_cache_is_bounded_and_expiry_releases_capacity(self):
        self.jobs.poll(self.proof())
        with self.store.connect() as db:
            v = self.jobs._read(db)
            v['polls'] = [{'id': format(i, '064x'), 'until': self.now + 60} for i in range(128)]
            self.ops._save(db, SECTION, v)
        with self.assertRaisesRegex(JobError, 'BUSY'): self.jobs.poll(self.proof())
        self.now += 60
        self.assertEqual('', self.jobs.poll(self.proof())['job_id'])


if __name__ == '__main__': unittest.main()
