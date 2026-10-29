"""Real HTTPS administrator reviews; execution stays unconditionally closed."""
import json
import sqlite3
import time
import unittest
import uuid
from unittest.mock import patch

from kaname.server import Handler
from kaname.staging_write_jobs import StagingWriteJobs, SECTION, STAGE, ROLLBACK, ACK
from . import test_staging_preview_jobs_http as hf
from . import test_staging_write_jobs as wf

ROOT = '/api/deployment/staging-write'


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
        self.jobs = StagingWriteJobs(self.engine)
        self.release = str(uuid.uuid4())
        self.now = int(time.time())
        # Internal signed fixture readiness only: there is no HTTP write poll.
        self.jobs.poll(wf.StagingWriteJobTests.proof(self))
        return {'expected_revision': self.store.snapshot()['revision'], 'job_id': str(uuid.uuid4()),
                'operation': STAGE, 'candidate_id': offer['target']['candidate_id'],
                'stage_job_id': '', 'staging_preview_sha256': result['preview_sha256'],
                'acknowledge': ACK[STAGE]}

    def ledger(self):
        with self.store.connect() as db:
            return db.execute('SELECT payload FROM runtime_settings WHERE name=?', (SECTION,)).fetchall()

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
