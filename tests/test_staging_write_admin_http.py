"""Real HTTPS administrator reviews and isolated pilot job delivery."""
import json
from pathlib import Path
import tempfile
import sqlite3
import time
import unittest
import uuid
from unittest.mock import patch

from kaname.connector_registry import digest
from kaname.server import DevelopmentServer, Handler
from kaname.staging_write_jobs import (StagingWriteJobs, SECTION, STAGE, ROLLBACK, ACK,
                                     RELEASE_APPROVAL, POLL_PATH, CLAIM_PATH, RESULT_PATH)
from . import test_staging_preview_jobs_http as hf
from . import test_staging_write_jobs as wf

ROOT = '/api/deployment/staging-write'
RECONCILE = ROOT + '/reconciliation'


class StagingWriteAdminHTTPTests(unittest.TestCase):
    setUpClass = classmethod(hf.StagingPreviewHTTPTests.setUpClass.__func__)
    tearDownClass = classmethod(hf.StagingPreviewHTTPTests.tearDownClass.__func__)
    request = hf.StagingPreviewHTTPTests.request
    login = hf.StagingPreviewHTTPTests.login
    close = hf.StagingPreviewHTTPTests.close
    intent = hf.StagingPreviewHTTPTests.intent
    prepare = hf.StagingPreviewHTTPTests.prepare
    user = hf.StagingPreviewHTTPTests.user
    body = hf.StagingPreviewHTTPTests.body
    peer = hf.StagingPreviewHTTPTests.peer
    binding = hf.StagingPreviewHTTPTests.binding
    proof = hf.StagingPreviewHTTPTests.proof
    job_request = hf.StagingPreviewHTTPTests.job_request
    result = hf.StagingPreviewHTTPTests.result
    create = hf.StagingPreviewHTTPTests.create

    def setUp(self):
        hf.StagingPreviewHTTPTests.setUp(self)

    def ready(self):
        from kaname.staging_preview_jobs import RESULT_PATH
        offer = self.create(); result = self.result(offer)
        self.assertEqual(200, self.peer(RESULT_PATH, self.proof('RESULT', result))[0])
        self.preview_result = result
        self.release = str(uuid.uuid4())
        self.now = int(time.time())
        self.jobs = StagingWriteJobs(self.engine, wall_clock=lambda: self.now)
        # Internal signed fixture readiness only: there is no HTTP write poll.
        self.jobs.poll(wf.StagingWriteJobTests.proof(self))
        return {'expected_revision': self.store.snapshot()['revision'], 'job_id': str(uuid.uuid4()),
                'operation': STAGE, 'candidate_id': offer['target']['candidate_id'],
                'stage_job_id': '', 'staging_preview_sha256': result['preview_sha256'],
                'acknowledge': ACK[STAGE]}

    def ledger(self):
        with self.store.connect() as db:
            return db.execute('SELECT payload FROM runtime_settings WHERE name=?', (SECTION,)).fetchall()

    def reconciliation_case(self):
        value = self.ready()
        self.jobs.create(value | {'review_hash': self.jobs.review(value, self.actor)['review_hash']}, self.actor)
        offer = self.jobs.poll(wf.StagingWriteJobTests.proof(self))
        claim = wf.StagingWriteJobTests.claim_body(self, offer)
        grant = self.jobs.claim(wf.StagingWriteJobTests.proof(self, 'CLAIM', claim))
        body = wf.StagingWriteJobTests.result(self, offer, grant)
        evidence = {name: offer[name] for name in ('job_id', 'scope_sha256', 'intent_sha256')}
        evidence.update(result_body_sha256=digest(body), accepted_ack=False)
        request = {'expected_revision': self.store.snapshot()['revision'], 'evidence': evidence,
                   'decision': 'keep_under_review'}
        return request, body

    def test_reconciliation_requires_explicit_actor_bound_approval_and_preserves_job(self):
        value, body = self.reconciliation_case()
        before = self.ledger(); audit = self.store.audit()
        code, review, _ = self.request('POST', RECONCILE+'/review', value, self.headers)
        self.assertEqual(200, code, review)
        self.assertEqual('server_result_missing', review['comparison'])
        self.assertTrue(review['review_only'])
        self.assertEqual(audit, self.store.audit())
        approve = value | {'review_hash': review['review_hash'], 'acknowledge': 'record_reconciliation_decision'}
        second, _ = self.user('reconcile-second', {'certificates.authority':'write', 'system.connectors':'write'})
        self.assertEqual(409, self.request('POST', RECONCILE+'/record', approve, second)[0])
        self.assertEqual(400, self.request('POST', RECONCILE+'/record', approve | {'acknowledge':''}, self.headers)[0])
        for _ in range(2):
            code, receipt, _ = self.request('POST', RECONCILE+'/record', approve, self.headers)
            self.assertEqual(200, code, receipt)
            self.assertTrue(receipt['decision_recorded'])
            self.assertEqual(value['expected_revision']+1, receipt['revision'])
            self.assertFalse(receipt['can_apply_gpo'])
        self.assertEqual(before, self.ledger())
        self.assertEqual(len(audit)+1, len(self.store.audit()))

        self.assertIn(':keep_under_review:', self.store.audit()[0]['event'])
        self.assertEqual('authorized', self.jobs.status()['jobs'][0]['state'])

        self.jobs.complete(wf.StagingWriteJobTests.proof(self, 'RESULT', body))
        value.update(expected_revision=self.store.snapshot()['revision'], decision='acknowledge_saved_result')
        code, review, _ = self.request('POST', RECONCILE+'/review', value, self.headers)
        self.assertEqual(200, code, review)
        self.assertEqual('result_matches_ack_missing', review['comparison'])
        before = self.ledger()
        approve = value | {'review_hash': review['review_hash'], 'acknowledge': 'record_reconciliation_decision'}
        code, receipt, _ = self.request('POST', RECONCILE+'/record', approve, self.headers)
        self.assertEqual(200, code, receipt)
        self.assertEqual(before, self.ledger())
        self.assertEqual('completed', self.jobs.status()['jobs'][0]['state'])

    def test_reconciliation_stale_or_conflicting_evidence_remains_in_review(self):
        value, body = self.reconciliation_case()
        self.assertEqual(409, self.request('POST', RECONCILE+'/review',
            value | {'decision':'acknowledge_saved_result'}, self.headers)[0])
        review = self.request('POST', RECONCILE+'/review', value, self.headers)[1]
        self.jobs.complete(wf.StagingWriteJobTests.proof(self, 'RESULT', body))
        audit = self.store.audit()
        approve = value | {'review_hash': review['review_hash'], 'acknowledge': 'record_reconciliation_decision'}
        self.assertEqual(409, self.request('POST', RECONCILE+'/record', approve, self.headers)[0])
        changed = value | {'expected_revision': self.store.snapshot()['revision'],
            'evidence': value['evidence'] | {'result_body_sha256':'0'*64}}
        code, review, _ = self.request('POST', RECONCILE+'/review', changed, self.headers)
        self.assertEqual(200, code, review)
        self.assertEqual('result_conflict', review['comparison'])
        self.assertEqual(409, self.request('POST', RECONCILE+'/review',
            changed | {'decision':'acknowledge_saved_result'}, self.headers)[0])
        self.assertEqual(audit, self.store.audit())

    def test_reconciliation_rechecks_both_permissions_and_session(self):
        for suffix in ('/review', '/record'):
            self.assertEqual(401, self.request('POST', RECONCILE+suffix, {})[0])
            self.assertEqual(403, self.request('POST', RECONCILE+suffix, {},
                self.headers | {'X-Kaname-CSRF':'bad'})[0])
            for grant in ('certificates.authority', 'system.connectors'):
                headers, _ = self.user('reconcile-'+uuid.uuid4().hex[:8], {grant:'write'})
                self.assertEqual(403, self.request('POST', RECONCILE+suffix, {}, headers)[0])

    def test_stage_lock_release_approval_requires_audited_refusal_and_exact_evidence(self):
        value = self.ready()
        self.jobs.create(value | {'review_hash': self.jobs.review(value, self.actor)['review_hash']}, self.actor)
        offer = self.jobs.poll(wf.StagingWriteJobTests.proof(self))
        body = wf.StagingWriteJobTests.result(self, offer, outcome='refused_before_authorization',
            reason='PREFLIGHT_FAILED', filesystem_effects='none', journal_sha256='', tree_sha256='')
        self.jobs.complete(wf.StagingWriteJobTests.proof(self, 'RESULT', body))
        evidence = {name: offer[name] for name in ('job_id', 'scope_sha256', 'intent_sha256')}
        evidence.update(result_body_sha256=digest(body), accepted_ack=True)
        lock = {name: evidence[name] for name in ('job_id', 'scope_sha256', 'intent_sha256', 'result_body_sha256')}
        lock.update(format='AuthWireRefusedStageLockEvidenceV1', slot='000001',
            gpo_id=offer['target']['scope_target']['gpo_id'], accepted_ack_sha256='a'*64, completion_sha256='b'*64,
            lock_sha256=digest({'format': 'AuthWireWriteGpoLockV1', 'job_id': offer['job_id'],
                                'intent_sha256': offer['intent_sha256']}))
        revision = self.store.snapshot()['revision']
        prior = {'expected_revision': revision, 'evidence': evidence, 'decision': 'acknowledge_saved_result'}
        code, review, _ = self.request('POST', RECONCILE+'/review', prior, self.headers)
        self.assertEqual(200, code, review)
        release = prior | {'decision': RELEASE_APPROVAL,
            'stage_lock_evidence': lock,
            'reconciliation_receipt': {'revision': revision+1, 'review_hash': review['review_hash']}}
        self.assertEqual(400, self.request('POST', RECONCILE+'/review', release, self.headers)[0])
        code, receipt, _ = self.request('POST', RECONCILE+'/record', prior | {
            'review_hash': review['review_hash'], 'acknowledge': 'record_reconciliation_decision'}, self.headers)
        self.assertEqual(200, code, receipt)
        release['expected_revision'] = receipt['revision']
        for invalid in (
            {key: field for key, field in release.items() if key != 'stage_lock_evidence'},
            release | {'stage_lock_evidence': lock | {'slot': '000000'}},
            release | {'stage_lock_evidence': lock | {'accepted_ack_sha256': 'bad'}},
            prior | {'stage_lock_evidence': lock},
        ):
            self.assertEqual(400, self.request('POST', RECONCILE+'/review', invalid, self.headers)[0])
        for changed in (
            release | {'evidence': evidence | {'accepted_ack': False}},
            release | {'evidence': evidence | {'result_body_sha256': '0'*64}},
            release | {'stage_lock_evidence': lock | {'gpo_id': str(uuid.uuid4())}},
            release | {'stage_lock_evidence': lock | {'scope_sha256': '0'*64}},
            release | {'stage_lock_evidence': lock | {'lock_sha256': '0'*64}},
        ):
            self.assertEqual(409, self.request('POST', RECONCILE+'/review', changed, self.headers)[0])
        second, _ = self.user('release-second', {'certificates.authority':'write', 'system.connectors':'write'})
        self.assertEqual(400, self.request('POST', RECONCILE+'/review', release, second)[0])
        code, review, _ = self.request('POST', RECONCILE+'/review', release, self.headers)
        self.assertEqual(200, code, review)
        self.assertEqual(offer['target']['scope_target']['gpo_id'], review['gpo_id'])
        self.assertEqual(digest(lock), review['stage_lock_evidence_sha256'])
        approval = release | {'review_hash': review['review_hash'],
                              'acknowledge': 'record_stage_lock_release_approval'}
        self.assertEqual(400, self.request('POST', RECONCILE+'/record',
            approval | {'acknowledge': 'record_reconciliation_decision'}, self.headers)[0])
        before = self.ledger(); audit = self.store.audit()
        for field in ('accepted_ack_sha256', 'completion_sha256'):
            code, error, _ = self.request('POST', RECONCILE+'/record',
                approval | {'stage_lock_evidence': lock | {field: '0'*64}}, self.headers)
            self.assertEqual((409, 'STAGING_WRITE_RECONCILIATION_REVIEW_CHANGED'), (code, error['error']))
        self.assertEqual(audit, self.store.audit())
        for _ in range(2):
            code, recorded, _ = self.request('POST', RECONCILE+'/record', approval, self.headers)
            self.assertEqual(200, code, recorded)
            self.assertEqual(RELEASE_APPROVAL, recorded['decision'])
            self.assertEqual(receipt['revision']+1, recorded['revision'])
            self.assertEqual(digest(lock), recorded['stage_lock_evidence_sha256'])
            self.assertFalse(recorded['can_apply_gpo'])
        self.assertEqual(before, self.ledger())
        self.assertEqual(len(audit)+1, len(self.store.audit()))

        verify_path = RECONCILE+'/verify-lock-release'
        verify = {'approval': approval, 'approval_revision': recorded['revision']}
        saved_audit = self.store.audit()
        saved_state = self.store.snapshot()
        code, verified, _ = self.request('POST', verify_path, verify, self.headers)
        self.assertEqual(200, code, verified)
        self.assertTrue(verified['approval_verified'])
        self.assertTrue(verified['review_only'])
        self.assertFalse(verified['write_authorization_enabled'])
        self.assertEqual(digest(lock), verified['stage_lock_evidence_sha256'])
        self.assertEqual(offer['job_id'], verified['job_id'])
        self.assertEqual(lock['gpo_id'], verified['gpo_id'])
        self.assertEqual(recorded['revision'], verified['approval_revision'])
        for payload, headers in (
            (verify, second),
            (verify | {'approval': approval | {'review_hash': '0'*64}}, self.headers),
            (verify | {'approval': approval | {'stage_lock_evidence': lock | {'completion_sha256': '0'*64}}}, self.headers),
        ):
            code, error, _ = self.request('POST', verify_path, payload, headers)
            self.assertEqual((409, 'STAGING_WRITE_RELEASE_APPROVAL_CONFLICT'), (code, error['error']))
        self.assertEqual(400, self.request('POST', verify_path,
            verify | {'approval_revision': receipt['revision']}, self.headers)[0])
        self.assertEqual(403, self.request('POST', verify_path, verify, self.headers | {'X-Kaname-CSRF':'bad'})[0])
        self.assertEqual(saved_audit, self.store.audit())
        self.assertEqual(saved_state, self.store.snapshot())
        self.assertEqual(before, self.ledger())

        # A more recent pending stage for this GPO makes the old approval unusable.
        next_job = value | {'job_id': str(uuid.uuid4()), 'expected_revision': saved_state['revision']}
        self.jobs.create(next_job | {'review_hash': self.jobs.review(next_job, self.actor)['review_hash']}, self.actor)
        code, error, _ = self.request('POST', verify_path, verify, self.headers)
        self.assertEqual((409, 'STAGING_WRITE_GPO_BUSY'), (code, error['error']))

    def test_review_binds_real_actor_and_is_readonly_create_never_enqueues(self):
        value = self.ready(); before = self.ledger(); audit = self.store.audit()
        code, review, _ = self.request('POST', ROOT+'/review', value, self.headers)
        self.assertEqual(200, code, review)
        actor = self.request('GET', '/api/auth/session', headers=self.headers)[1]
        self.assertEqual(actor['user']['id'], review['actor'])
        self.assertTrue(review['review_only']); self.assertFalse(review['approval_enabled'])
        self.assertEqual(value['staging_preview_sha256'], review['target']['preview_record']['PreviewSha256'])
        self.assertEqual(20, len(review['target']['preview_record']['Preview']['files']))
        for _ in range(2):
            code, result, _ = self.request('POST', ROOT+'/create', value|{'review_hash': review['review_hash']}, self.headers)
            self.assertEqual((409, 'STAGING_WRITE_EXECUTION_UNAVAILABLE'), (code, result['error']))
        self.assertEqual(before, self.ledger()); self.assertEqual(audit, self.store.audit())
        self.assertEqual([], self.jobs.status()['jobs'])

    def test_status_does_not_create_ledger_or_expose_authorization_secrets(self):
        self.assertEqual([], self.ledger()); before = self.store.snapshot()
        code, result, _ = self.request('GET', ROOT, headers=self.headers)
        self.assertEqual(200, code, result)
        self.assertEqual([], result['jobs']); self.assertFalse(result['approval_enabled'])
        self.assertFalse(result['write_authorization_enabled']); self.assertFalse(result['can_apply_gpo'])
        self.assertEqual([], self.ledger()); self.assertEqual(before, self.store.snapshot())
        for field in ('authorization_id', 'lease_id', 'claim_sha256', 'public_key_pem'):
            self.assertNotIn(field, json.dumps(result))

    def test_status_exposes_typed_refusal_reason_without_secrets_or_write_authority(self):
        value = self.ready()
        self.jobs.create(value | {'review_hash': self.jobs.review(value, self.actor)['review_hash']}, self.actor)
        offer = self.jobs.poll(wf.StagingWriteJobTests.proof(self))
        body = wf.StagingWriteJobTests.result(self, offer,
            outcome='refused_before_authorization', reason='PREFLIGHT_FAILED',
            filesystem_effects='none', journal_sha256='', tree_sha256='')
        proof = wf.StagingWriteJobTests.proof(self, 'RESULT', body)
        self.jobs.complete(proof)
        before = self.ledger(); audit = self.store.audit()
        code, result, _ = self.request('GET', ROOT, headers=self.headers)
        self.assertEqual(200, code, result)
        job = result['jobs'][0]
        self.assertEqual('completed', job['state'])
        self.assertEqual('refused_before_authorization', job['peer_reported_outcome'])
        self.assertEqual('PREFLIGHT_FAILED', job['peer_reported_reason'])
        self.assertEqual('none', job['peer_reported_filesystem_effects'])
        self.assertEqual(body['checked_at'], job['peer_reported_checked_at'])
        self.assertFalse(job['authorization_issued'])
        self.assertFalse(job['customer_filesystem_attested'])
        self.assertFalse(result['approval_enabled'])
        self.assertEqual(before, self.ledger()); self.assertEqual(audit, self.store.audit())
        for secret in (offer['lease_id'], offer['intent_sha256'], 'public_key_pem'):
            self.assertNotIn(secret, json.dumps(result))

    def test_reader_can_only_read_both_permissions_and_session_required(self):
        self.assertEqual(401, self.request('GET', ROOT)[0])
        reader, _ = self.user('write-reader', {'certificates.authority':'read', 'system.connectors':'read'})
        self.assertEqual(200, self.request('GET', ROOT, headers=reader)[0])
        for grants in ({'certificates.authority':'write'}, {'system.connectors':'write'},
                       {'certificates.authority':'read', 'system.connectors':'write'}):
            h, _ = self.user('write-'+uuid.uuid4().hex[:8], grants)
            for suffix in ('/review', '/create'):
                self.assertEqual(403, self.request('POST', ROOT+suffix, {}, h)[0])
        for suffix in ('/review', '/create'):
            self.assertEqual(403, self.request('POST', ROOT+suffix, {}, reader)[0])
        h = {'Authorization':'Bearer '+self.server.token}
        self.assertEqual(403, self.request('GET', ROOT, headers=h)[0])
        self.assertEqual(403, self.request('POST', ROOT+'/review', {}, h)[0])

    def test_origin_csrf_host_tls_and_missing_session_refuse_before_review(self):
        for suffix in ('/review', '/create'):
            self.assertEqual(401, self.request('POST', ROOT+suffix, {})[0])
            for change in ({'X-Kaname-CSRF':'bad'}, {'Origin':'https://evil.example'},
                           {'Origin':''}, {'Host':'evil.example'}):
                self.assertEqual(403, self.request('POST', ROOT+suffix, {}, self.headers|change)[0])
        with patch.object(self.server, 'tls', False):
            for method, suffix in (('GET',''), ('POST','/review'), ('POST','/create')):
                self.assertEqual(403, self.request(method, ROOT+suffix, {} if method=='POST' else None, self.headers)[0])

    def test_live_demotion_disabled_user_and_version_change_after_body_read(self):
        for resource in ('certificates.authority', 'system.connectors'):
            h, profile = self.user('operator-'+uuid.uuid4().hex[:8],
                {'certificates.authority':'write', 'system.connectors':'write'})
            original = Handler.read_body
            def demote(handler):
                value = original(handler)
                with self.server.admin.connect() as db:
                    db.execute('UPDATE admin_profiles SET grants=? WHERE id=?', (json.dumps({resource:'write'}), profile))
                return value
            for suffix in ('/review', '/create'):
                with patch.object(Handler, 'read_body', demote):
                    self.assertEqual(403, self.request('POST', ROOT+suffix, {}, h)[0])
        for change in ('enabled=0', 'version=version+1'):
            h, _ = self.user('version-'+uuid.uuid4().hex[:8],
                {'certificates.authority':'write', 'system.connectors':'write'})
            identity = self.request('GET','/api/auth/session', headers=h)[1]['user']['id']
            def invalidate(handler):
                value = original(handler)
                with self.server.admin.connect() as db:
                    db.execute('UPDATE admin_users SET '+change+' WHERE id=?', (identity,))
                return value
            with patch.object(Handler, 'read_body', invalidate):
                self.assertEqual(401, self.request('POST', ROOT+'/review', {}, h)[0])

    def test_current_revision_preview_actor_ack_and_scope_are_not_client_overrides(self):
        value = self.ready()
        h, _ = self.user('second-operator', {'certificates.authority':'write','system.connectors':'write'})
        first = self.request('POST', ROOT+'/review', value, self.headers)[1]
        code, second, _ = self.request('POST', ROOT+'/review', value, h)
        self.assertEqual(200, code, second); self.assertNotEqual(first['review_hash'], second['review_hash'])
        for change in ({'actor':first['actor']}, {'path':'C:\\Windows'}, {'command':'whoami'},
                       {'acknowledge':ACK[ROLLBACK]}, {'staging_preview_sha256':'f'*64},
                       {'candidate_id':str(uuid.uuid4())}, {'operation':'gpo.apply'}):
            self.assertIn(self.request('POST', ROOT+'/review', value|change, self.headers)[0], (400,409))
        code, error, _ = self.request('POST', ROOT+'/review', value|{'expected_revision':value['expected_revision']-1}, self.headers)
        self.assertEqual((409,'REVISION_CONFLICT'), (code,error['error']))
        self.data['catalog']['members'].append('scope changed')
        self.assertNotEqual(200, self.request('POST', ROOT+'/review', value, self.headers)[0])

    def test_logout_expiry_idle_and_csrf_change_during_body_read_invalidate_session(self):
        original=Handler.read_body
        for change in ('DELETE FROM admin_sessions', 'UPDATE admin_sessions SET expires=0',
                       'UPDATE admin_sessions SET last_seen=0', "UPDATE admin_sessions SET csrf='changed'"):
            for suffix in ('/review','/create'):
                h=self.login()
                def expire(handler):
                    value=original(handler)
                    with self.server.admin.connect() as db:
                        db.execute(change)
                    return value
                with patch.object(Handler,'read_body',expire):
                    self.assertEqual(401,self.request('POST',ROOT+suffix,{},h)[0])

    def test_store_corruption_is_safe_and_peer_or_execute_routes_do_not_exist(self):
        with self.store.connect() as db:
            db.execute('INSERT INTO runtime_settings VALUES (?,?)', (SECTION,'{"secret":"do-not-echo"}'))
        code, error, _ = self.request('GET', ROOT, headers=self.headers)
        self.assertEqual((503,'STAGING_WRITE_STORE_INVALID'), (code,error['error']))
        self.assertNotIn('do-not-echo', json.dumps(error))
        for suffix in ('?x=1','?','?a=1&a=2'):
            self.assertEqual(400, self.request('GET', ROOT+suffix, headers=self.headers)[0])
        for path in (ROOT+'/apply', ROOT+'/execute', ROOT+'/review?x=1',
                     '/api/connector/v1/staging-write/poll', '/api/connector/v1/staging-write/claim',
                     '/api/connector/v1/staging-write/result'):
            self.assertEqual(404, self.request('POST', path, {}, self.headers)[0])

    def test_probe_requires_explicit_loopback_https(self):
        for options in ({'staging_write_probe':True},
                        {'staging_write_probe':True, 'listen':'192.0.2.1', 'tls_cert':'cert', 'tls_key':'key'},
                        {'staging_write_probe':'true'}):
            with self.assertRaisesRegex(ValueError, 'loopback HTTPS'):
                DevelopmentServer(self.store.root, 0, **options)

    def test_authenticated_probe_never_leases_a_queued_job(self):
        value = self.ready()
        self.jobs.create(value | {'review_hash': self.jobs.review(value, self.actor)['review_hash']}, self.actor)
        with self.store.connect() as db:
            before = self.jobs._read(db)
        self.now = int(time.time())
        proof = wf.StagingWriteJobTests.proof(self)
        self.assertEqual(404, self.request('POST', POLL_PATH, {}, self.headers)[0])
        with patch.object(self.server, 'staging_write_probe', True):
            self.assertEqual(403, self.peer(POLL_PATH, proof, {'Cookie':'session=x'})[0])
            wrong_key = wf.StagingWriteJobTests.proof(self, private=self.other)
            self.assertEqual(403, self.peer(POLL_PATH, wrong_key)[0])
            code, reply = self.peer(POLL_PATH, proof)
            self.assertEqual(200, code, reply)
            self.assertEqual(('', '', '', '', 0, None, False, False), tuple(reply[key] for key in
                ('job_id', 'operation', 'lease_id', 'intent_sha256', 'expires_at', 'target', 'write_authorized', 'can_apply_gpo')))
            self.assertEqual(403, self.peer(POLL_PATH, proof)[0])
            for path in (CLAIM_PATH, RESULT_PATH, POLL_PATH+'?x=1'):
                self.assertEqual(404, self.request('POST', path, {}, self.headers)[0])
        with self.store.connect() as db:
            after = self.jobs._read(db)
        self.assertEqual(before['last_poll'], after['last_poll'])
        self.assertEqual(before['jobs'], after['jobs'])
        self.assertEqual('queued', after['jobs'][0]['state'])

    def test_pilot_mode_requires_exclusive_loopback_tls_and_canonical_scope(self):
        pilot = str(uuid.uuid4())
        for options in ({'staging_write_pilot_gpo_id': pilot},
                        {'staging_write_pilot_gpo_id': pilot, 'listen':'192.0.2.1',
                         'tls_cert':'cert', 'tls_key':'key'},
                        {'staging_write_pilot_gpo_id': 'invalid', 'tls_cert':'cert', 'tls_key':'key'},
                        {'staging_write_pilot_gpo_id': pilot, 'staging_write_probe':True,
                         'tls_cert':'cert', 'tls_key':'key'}):
            with self.subTest(options=options), self.assertRaisesRegex(ValueError, 'loopback HTTPS'):
                DevelopmentServer(self.store.root, 0, **options)
        tls = Path(self.base.name)
        with tempfile.TemporaryDirectory() as directory:
            with DevelopmentServer(Path(directory), 0, tls_cert=tls/'web.crt', tls_key=tls/'web.key',
                                   staging_write_pilot_gpo_id=pilot) as server:
                self.assertEqual(pilot, server.staging_write_pilot_gpo_id)
                self.assertTrue(server.tls)
                self.assertEqual('127.0.0.1', server.server_address[0])

    def test_pilot_https_create_stage_and_rollback_use_signed_peer_and_separate_approval(self):
        value = self.ready()
        target = self.jobs.review(value, self.actor)['target']
        pilot = target['scope_target']['gpo_id']
        self.server.staging_write_pilot_gpo_id = str(uuid.uuid4())
        code, result, _ = self.request('POST', ROOT+'/review', value, self.headers)
        self.assertEqual((409, 'STAGING_WRITE_PILOT_SCOPE_CHANGED'), (code, result['error']))
        self.assertEqual([], self.jobs.status()['jobs'])

        self.server.staging_write_pilot_gpo_id = pilot
        self.assertEqual(403, self.peer(POLL_PATH, wf.StagingWriteJobTests.proof(self),
                                       {'Cookie':'session=x'})[0])
        self.assertEqual(403, self.peer(POLL_PATH, wf.StagingWriteJobTests.proof(self, private=self.other))[0])
        self.assertEqual(200, self.peer(POLL_PATH, wf.StagingWriteJobTests.proof(self))[0])

        def review_and_create(request):
            code, review, _ = self.request('POST', ROOT+'/review', request, self.headers)
            self.assertEqual(200, code, review)
            self.assertFalse(review['review_only'])
            self.assertFalse(review['can_apply_gpo'])
            self.assertTrue(review['approval_enabled'])
            body = request | {'review_hash': review['review_hash']}
            code, denied, _ = self.request('POST', ROOT+'/create', body,
                                            self.headers | {'X-Kaname-CSRF':'invalid'})
            self.assertEqual(403, code, denied)
            code, queued, _ = self.request('POST', ROOT+'/create', body, self.headers)
            self.assertEqual(200, code, queued)
            self.assertEqual('queued', queued['state'])
            return body

        def run_peer(request, outcome):
            self.now = int(time.time())
            code, offer = self.peer(POLL_PATH, wf.StagingWriteJobTests.proof(self))
            self.assertEqual(200, code, offer)
            self.assertEqual(request['job_id'], offer['job_id'])
            self.assertFalse(offer['write_authorized'])
            claim = wf.StagingWriteJobTests.claim_body(self, offer)
            raw = wf.StagingWriteJobTests.proof(self, 'CLAIM', claim)
            code, grant = self.peer(CLAIM_PATH, raw)
            self.assertEqual(200, code, grant)
            self.assertTrue(grant['write_authorized'])
            self.assertFalse(grant['can_apply_gpo'])
            self.assertEqual(403, self.peer(CLAIM_PATH, raw)[0])
            result = wf.StagingWriteJobTests.result(self, offer, grant)
            self.assertEqual(outcome, result['outcome'])
            for _ in range(2):
                code, saved = self.peer(RESULT_PATH, wf.StagingWriteJobTests.proof(self, 'RESULT', result))
                self.assertEqual(200, code, saved)
                self.assertTrue(saved['result_recorded'])

        review_and_create(value)
        run_peer(value, 'staged')
        rollback = value | {'job_id':str(uuid.uuid4()), 'operation':ROLLBACK,
                            'stage_job_id':value['job_id'], 'acknowledge':ACK[ROLLBACK],
                            'expected_revision':self.store.snapshot()['revision']}
        review_and_create(rollback)
        run_peer(rollback, 'rolled_back')
        code, status, _ = self.request('GET', ROOT, headers=self.headers)
        self.assertEqual(200, code, status)
        self.assertFalse(status['can_apply_gpo'])
        self.assertTrue(all(not j['customer_filesystem_attested'] for j in status['jobs']))
        for path in (ROOT+'/apply', ROOT+'/execute'):
            self.assertEqual(404, self.request('POST', path, {}, self.headers)[0])
        self.assertEqual(['rolled_back', 'staged'], [j['peer_reported_outcome'] for j in status['jobs']])

    def test_json_limits_duplicate_keys_and_wrong_content_type(self):
        # Reject the declared oversized body before uploading it (TLS may close
        # early, so sending 256KiB here races the correct server rejection).
        self.assertEqual(413, self.request('POST', ROOT+'/review', {}, self.headers|{'Content-Length':'262145'})[0])
        self.assertEqual(415, self.request('POST', ROOT+'/review', {}, self.headers|{'Content-Type':'text/plain'})[0])
        import http.client
        conn = http.client.HTTPSConnection('127.0.0.1', self.server.server_port, context=self.context, timeout=8)
        try:
            conn.request('POST', ROOT+'/review', '{"operation":"x","operation":"y"}',
                {'Content-Type':'application/json', 'Origin':f'https://127.0.0.1:{self.server.server_port}', **self.headers})
            response=conn.getresponse(); self.assertEqual(400, response.status); response.read()
        finally:
            conn.close()

    def test_expired_preview_and_missing_worker_do_not_create_authority(self):
        value = self.ready()
        self.jobs.clock = lambda: self.now+91
        with patch('kaname.staging_write_jobs.StagingWriteJobs', return_value=self.jobs):
            code, result, _ = self.request('POST', ROOT+'/review', value, self.headers)
        self.assertEqual((409,'STAGING_WRITE_WORKER_NOT_READY'), (code,result['error']))
        with self.store.connect() as db:
            ledger=self.jobs._read(db); ledger['last_poll']['at']=self.now+91
            self.jobs.ops._save(db, SECTION, ledger)
        with patch('kaname.staging_write_jobs.StagingWriteJobs', return_value=self.jobs):
            code,result,_=self.request('POST',ROOT+'/review',value,self.headers)
        self.assertEqual((409,'STAGING_WRITE_PREVIEW_EXPIRED'),(code,result['error']))
        self.jobs.clock = lambda: self.now
        with self.store.connect() as db:
            ledger=self.jobs._read(db); ledger['last_poll']=None
            self.jobs.ops._save(db, SECTION, ledger)
        self.assertEqual(409, self.request('POST', ROOT+'/review', value, self.headers)[0])
        self.assertEqual([], self.jobs.status()['jobs'])

    def test_status_preserves_unknown_outcome_without_exposing_grants(self):
        value = self.ready()
        actor = self.request('GET', '/api/auth/session', headers=self.headers)[1]['user']['id']
        review=self.jobs.review(value,actor)
        self.jobs.create(value|{'review_hash':review['review_hash']},actor)
        offer=self.jobs.poll(wf.StagingWriteJobTests.proof(self))
        claim=wf.StagingWriteJobTests.claim_body(self,offer)
        authorization=self.jobs.claim(wf.StagingWriteJobTests.proof(self,'CLAIM',claim))
        self.jobs.clock=lambda:self.now+31
        before=self.ledger()
        with patch('kaname.staging_write_jobs.StagingWriteJobs',return_value=self.jobs):
            code,status,_=self.request('GET',ROOT,headers=self.headers)
        self.assertEqual(200,code,status)
        self.assertEqual('requires_review',status['jobs'][0]['state'])
        self.assertTrue(status['jobs'][0]['authorization_issued'])
        self.assertFalse(status['jobs'][0]['customer_filesystem_attested'])
        self.assertNotIn(authorization['authorization_id'],json.dumps(status))
        self.assertEqual(before,self.ledger())

    def test_busy_error_does_not_disclose_database_details(self):
        error=sqlite3.OperationalError('private-db-detail'); error.sqlite_errorcode=sqlite3.SQLITE_BUSY
        with patch.object(self.store,'connect',side_effect=error):
            with self.assertLogs('authwire.panel',level='WARNING') as logs:
                code,result,_=self.request('GET',ROOT,headers=self.headers)
        self.assertEqual((503,'STORE_BUSY'),(code,result['error']))
        self.assertNotIn('private-db-detail',str(logs.output)+json.dumps(result))
