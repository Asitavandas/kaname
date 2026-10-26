"""Actual verified HTTPS job routes and interactive administrator boundaries."""
import http.client
import json
import time
import unittest
from unittest.mock import patch
import uuid

from kaname.connector_jobs import SECTION, OPERATION, POLL_PATH, RESULT_PATH
from kaname.server import Handler
from . import test_connector_registry_http as http_fixture
from . import test_connector_jobs as proof_fixture


class ConnectorJobHTTPTests(unittest.TestCase):
    setUpClass = classmethod(http_fixture.ConnectorRegistryHTTPTests.setUpClass.__func__)
    tearDownClass = classmethod(http_fixture.ConnectorRegistryHTTPTests.tearDownClass.__func__)
    request = http_fixture.ConnectorRegistryHTTPTests.request
    login = http_fixture.ConnectorRegistryHTTPTests.login
    close = http_fixture.ConnectorRegistryHTTPTests.close
    intent = http_fixture.ConnectorRegistryHTTPTests.intent
    prepare = http_fixture.ConnectorRegistryHTTPTests.prepare
    user = http_fixture.ConnectorRegistryHTTPTests.user
    proof = proof_fixture.ConnectorJobTests.proof
    result = proof_fixture.ConnectorJobTests.result

    def setUp(self):
        http_fixture.ConnectorRegistryHTTPTests.setUp(self)
        value = self.prepare(self.intent())
        self.assertEqual(200, self.request('POST', '/api/deployment/connector/apply', value, self.headers)[0])
        self.now = int(time.time())
        self.assertEqual(200, self.request('GET', '/api/deployment/connector/jobs', headers=self.headers)[0])
        self.jobs = self.server.connector_jobs

    def binding(self):
        with self.server.store.connect() as db:
            return self.jobs._binding(db)

    def peer(self, path, raw, headers=None):
        conn = http.client.HTTPSConnection('127.0.0.1', self.server.server_port, context=self.context, timeout=8)
        try:
            conn.request('POST', path, raw, {'Content-Type':'application/json', **(headers or {})})
            response = conn.getresponse(); return response.status, json.loads(response.read())
        finally:
            conn.close()

    def job_intent(self):
        return {'expected_revision':self.server.store.snapshot()['revision'], 'job_id':str(uuid.uuid4()), 'operation':OPERATION}

    def create_job(self):
        value = self.job_intent()
        code, preview, _ = self.request('POST', '/api/deployment/connector/jobs/preview', value, self.headers)
        self.assertEqual(200, code, preview)
        body = value | {'preview_hash':preview['preview_hash']}
        code, result, _ = self.request('POST', '/api/deployment/connector/jobs/create', body, self.headers)
        self.assertEqual(200, code, result)
        return body

    def test_real_https_job_poll_result_status_and_lost_reply_reconciliation(self):
        before = self.server.store.snapshot(); body = self.create_job()
        self.assertEqual(200, self.request('POST', '/api/deployment/connector/jobs/create', body, self.headers)[0])
        code, offer = self.peer(POLL_PATH, self.proof()); self.assertEqual(200, code, offer)
        raw = self.proof('RESULT', self.result(offer))
        self.assertEqual(200, self.peer(RESULT_PATH, raw)[0])
        self.assertEqual(200, self.peer(RESULT_PATH, raw)[0])
        code, status, _ = self.request('GET', '/api/deployment/connector/jobs', headers=self.headers)
        self.assertEqual(200, code); self.assertEqual('completed', status['jobs'][0]['state'])
        self.assertTrue(status['worker_probe_ready']); self.assertFalse(status['can_apply'])
        self.assertEqual(before['config'], self.server.store.snapshot()['config'])
        self.assertEqual(before['policies'], self.server.store.snapshot()['policies'])

    def test_unauthenticated_reader_csrf_origin_host_and_maintenance_cannot_enqueue(self):
        value = self.job_intent()
        self.assertEqual(401, self.request('GET', '/api/deployment/connector/jobs')[0])
        reader, _ = self.user('job-reader')
        self.assertEqual(200, self.request('GET', '/api/deployment/connector/jobs', headers=reader)[0])
        for endpoint in ('preview', 'create'):
            path = '/api/deployment/connector/jobs/' + endpoint
            self.assertEqual(403, self.request('POST', path, value, reader)[0])
            for headers in (self.headers | {'X-Kaname-CSRF':'bad'}, self.headers | {'Origin':'https://evil.example'},
                            self.headers | {'Host':'evil.example'}, {'Authorization':'Bearer '+self.server.token}):
                self.assertEqual(403, self.request('POST', path, value, headers)[0])
        self.assertEqual([], self.jobs.status()['jobs'])

    def test_principal_demoted_after_body_read_cannot_create_job(self):
        connector, profile = self.user('job-operator', {'system.connectors':'write'})
        value = self.job_intent()
        code, preview, _ = self.request('POST', '/api/deployment/connector/jobs/preview', value, connector)
        self.assertEqual(200, code)
        original = Handler.read_body
        def demote(handler):
            result = original(handler)
            with self.server.admin.connect() as db:
                db.execute('UPDATE admin_profiles SET grants=? WHERE id=?', ('{}', profile))
            return result
        with patch.object(Handler, 'read_body', demote):
            self.assertEqual(403, self.request('POST', '/api/deployment/connector/jobs/create', value | {'preview_hash':preview['preview_hash']}, connector)[0])
        self.assertEqual([], self.jobs.status()['jobs'])

    def test_peer_routes_reject_browser_headers_invalid_proof_and_wrong_purpose(self):
        self.create_job()
        for headers in ({'Origin':'https://127.0.0.1'}, {'Cookie':'x=y'}, {'Authorization':'Bearer '+self.server.token}, {'Host':'evil.example'}):
            self.assertEqual(403, self.peer(POLL_PATH, self.proof(), headers)[0])
        for path, proof in [(POLL_PATH,b'{}'), (RESULT_PATH,self.proof()), (POLL_PATH,self.proof(private=self.other))]:
            code, error = self.peer(path, proof)
            self.assertEqual((403, 'CONNECTOR_REQUEST_REJECTED'), (code,error['error']))
        self.assertEqual('queued', self.jobs.status()['jobs'][0]['state'])

    def test_unknown_commands_and_query_parameters_cannot_broaden_scope(self):
        for value in (self.job_intent() | {'operation':'gpo.apply'}, self.job_intent() | {'command':'whoami'}):
            self.assertEqual(400, self.request('POST','/api/deployment/connector/jobs/preview',value,self.headers)[0])
        for query in ('?x=1','?'):
            self.assertEqual(400,self.request('GET','/api/deployment/connector/jobs'+query,headers=self.headers)[0])
        self.assertEqual(403,self.peer('/api/connector/v1/jobs/execute',b'{}')[0])

    def test_corrupt_job_store_is_unavailable_without_leaking_contents(self):
        with self.server.store.connect() as db:
            db.execute('INSERT INTO runtime_settings VALUES (?,?)',(SECTION,'{"secret":"DO_NOT_ECHO"}'))
        code, result, _ = self.request('GET','/api/deployment/connector/jobs',headers=self.headers)
        self.assertEqual((503,'CONNECTOR_JOB_STORE_INVALID'),(code,result['error']))
        self.assertNotIn('DO_NOT_ECHO',json.dumps(result))


if __name__ == '__main__': unittest.main()
