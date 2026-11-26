"""Panel projection against actual SQLite/RSA ledger fixtures; no AD writes."""
import json
import unittest
import uuid
from unittest.mock import patch

from kaname.staging_write_jobs import StagingWriteJobs, ROLLBACK
from kaname.connector_jobs import JobError
from kaname.staging_write_panel import describe
from . import test_staging_write_jobs as ledger_fixtures


class PanelProjectionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        ledger_fixtures.StagingWriteJobTests.setUpClass()

    @classmethod
    def tearDownClass(cls):
        ledger_fixtures.StagingWriteJobTests.tearDownClass()

    def setUp(self):
        self.f = ledger_fixtures.StagingWriteJobTests('runTest')
        self.addCleanup(self.f.doCleanups)
        self.f.setUp()
        with self.f.store.connect() as db:
            self.gpo = self.f.jobs.previews._target(db, self.f.identity)['gpo_id']
        self.f.jobs = StagingWriteJobs(self.f.engine, pilot_gpo_id=self.gpo,
                                      wall_clock=lambda: self.f.now)

    def view(self):
        return describe(self.f.jobs, self.f.jobs.status(), self.gpo)

    def test_default_and_mismatched_server_scope_remain_closed(self):
        for pilot in (None, str(uuid.uuid4())):
            p = describe(self.f.jobs, self.f.jobs.status(), pilot)
            self.assertFalse(p['enabled'])
            self.assertIsNone(p['gpo_id'])
            self.assertEqual([], p['rollback_targets'])

    def test_readiness_is_current_same_binding_poll_only(self):
        self.assertFalse(self.view()['worker_ready'])
        self.f.jobs.poll(self.f.proof())
        self.assertTrue(self.view()['worker_ready'])
        self.f.now += 90
        self.assertFalse(self.view()['worker_ready'])

    def test_missing_pairing_disables_panel_but_corrupt_store_is_not_hidden(self):
        status = self.f.jobs.status()
        with patch.object(self.f.jobs, '_binding', side_effect=JobError('CONNECTOR_NOT_PAIRED')):
            self.assertFalse(describe(self.f.jobs, status, self.gpo)['enabled'])
        with patch.object(self.f.jobs, '_binding', side_effect=JobError('CONNECTOR_STORE_INVALID')):
            with self.assertRaises(JobError):
                describe(self.f.jobs, status, self.gpo)

    def test_completed_stage_projects_only_public_rollback_identity(self):
        stage, _, _ = self.f.finish_stage()
        p = self.view()
        self.assertEqual([{'stage_job_id': stage['job_id'], 'candidate_id': self.f.identity,
                           'staging_preview_sha256': self.f.preview_result['preview_sha256']}],
                         p['rollback_targets'])
        self.assertFalse(p['can_apply_gpo'])
        for secret in ('authorization_id', 'lease_id', 'public_key_pem', 'grant'):
            self.assertNotIn(secret, json.dumps(p))

    def test_successful_separate_rollback_removes_old_stage_action(self):
        stage, _, _ = self.f.finish_stage()
        self.f.enqueue(self.f.value(ROLLBACK, stage['job_id']))
        offer = self.f.jobs.poll(self.f.proof())
        auth = self.f.authorize(offer)
        self.f.jobs.complete(self.f.proof('RESULT', self.f.result(offer, auth)))
        self.assertEqual([], self.view()['rollback_targets'])

    def test_unknown_stage_never_becomes_rollback_action(self):
        offer = self.f.offer()
        auth = self.f.authorize(offer)
        result = self.f.result(offer, auth, outcome='requires_review', reason='OUTCOME_UNKNOWN',
                               filesystem_effects='unconfirmed', journal_sha256='', tree_sha256='')
        self.f.jobs.complete(self.f.proof('RESULT', result))
        self.assertEqual([], self.view()['rollback_targets'])

    def test_revision_changed_between_status_and_projection_fails_closed(self):
        stale = self.f.jobs.status()
        self.f.enqueue()
        self.assertFalse(describe(self.f.jobs, stale, self.gpo)['enabled'])

    def test_projection_is_read_only_even_with_authorized_job(self):
        self.f.authorize(self.f.offer())
        before = self.f.store.snapshot()
        audit = self.f.store.audit()
        with self.f.store.connect() as db:
            rows = db.execute('SELECT name,payload FROM runtime_settings ORDER BY name').fetchall()
        self.assertEqual([], self.view()['rollback_targets'])
        self.assertEqual(before, self.f.store.snapshot())
        self.assertEqual(audit, self.f.store.audit())
        with self.f.store.connect() as db:
            self.assertEqual(rows, db.execute('SELECT name,payload FROM runtime_settings ORDER BY name').fetchall())


if __name__ == '__main__':
    unittest.main()
