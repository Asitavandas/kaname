"""Actual HTTPS/session projection checks using the existing isolated fixtures."""
import http.client
import unittest
import uuid

from . import test_staging_write_admin_http as protocol_fixture


class PanelHTTPTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        protocol_fixture.StagingWriteAdminHTTPTests.setUpClass()

    @classmethod
    def tearDownClass(cls):
        protocol_fixture.StagingWriteAdminHTTPTests.tearDownClass()

    def setUp(self):
        self.f = protocol_fixture.StagingWriteAdminHTTPTests('runTest')
        self.addCleanup(self.f.doCleanups)
        self.f.setUp()

    def enable_fixture_pilot(self):
        value = self.f.ready()
        with self.f.store.connect() as db:
            target = self.f.jobs.previews._target(db, value['candidate_id'])
        self.f.server.staging_write_pilot_gpo_id = target['gpo_id']
        return target['gpo_id']

    def test_general_server_keeps_read_only_contract_and_create_closed(self):
        before = self.f.store.snapshot()
        code, result, _ = self.f.request('GET', '/api/deployment/staging-write', headers=self.f.headers)
        self.assertEqual(200, code)
        self.assertFalse(result['panel_workflow']['enabled'])
        self.assertFalse(result['approval_enabled'])
        self.assertFalse(result['can_apply_gpo'])
        self.assertEqual(409, self.f.request('POST', '/api/deployment/staging-write/create', {}, self.f.headers)[0])
        self.assertEqual(before, self.f.store.snapshot())

    def test_explicit_pilot_exposes_only_matching_scope_and_current_readiness(self):
        gpo = self.enable_fixture_pilot()
        before = self.f.ledger()
        code, result, _ = self.f.request('GET', '/api/deployment/staging-write', headers=self.f.headers)
        self.assertEqual(200, code)
        self.assertTrue(result['approval_enabled'])
        self.assertTrue(result['panel_workflow']['enabled'])
        self.assertTrue(result['panel_workflow']['worker_ready'])
        self.assertEqual(gpo, result['panel_workflow']['gpo_id'])
        self.assertFalse(result['panel_workflow']['can_apply_gpo'])
        self.assertEqual(before, self.f.ledger())

    def test_panel_status_and_review_retain_both_permissions_and_real_session(self):
        self.enable_fixture_pilot()
        for grants in ({'certificates.authority': 'read'}, {'system.connectors': 'read'}):
            headers, _ = self.f.user('panel-'+uuid.uuid4().hex[:8], grants)
            self.assertEqual(403, self.f.request('GET', '/api/deployment/staging-write', headers=headers)[0])
        reader, _ = self.f.user('reader-'+uuid.uuid4().hex[:8],
                                {'certificates.authority': 'read', 'system.connectors': 'read'})
        self.assertEqual(200, self.f.request('GET', '/api/deployment/staging-write', headers=reader)[0])
        self.assertEqual(403, self.f.request('POST', '/api/deployment/staging-write/review', {}, reader)[0])
        self.assertEqual(401, self.f.request('GET', '/api/deployment/staging-write')[0])
        self.assertEqual(403, self.f.request('POST', '/api/deployment/staging-write/review', {},
                                           self.f.headers | {'X-Kaname-CSRF': 'wrong'})[0])

    def test_new_panel_asset_is_served_as_script(self):
        conn = http.client.HTTPSConnection('127.0.0.1', self.f.server.server_port,
                                           context=self.f.context, timeout=5)
        try:
            conn.request('GET', '/staging-write-panel.js', headers=self.f.headers)
            response = conn.getresponse()
            self.assertEqual(200, response.status)
            self.assertIn('javascript', response.getheader('Content-Type'))
            self.assertIn(b'AuthWireFilesystemPanel', response.read())
        finally:
            conn.close()


if __name__ == '__main__':
    unittest.main()
