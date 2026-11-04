"""Write-ledger comparison must preserve authority and full snapshot bytes."""
import copy
import json
from pathlib import Path
import sqlite3
import sys
import tempfile
import unittest

if sys.platform == 'linux':
    from tools import scheduled_backup as worker

SECTION = 'windows_staging_write_jobs'
RELEASE = '00000000-0000-4000-8000-000000000001'


@unittest.skipUnless(sys.platform == 'linux', 'Linux backup comparison')
class WriteBackupProjectionTests(unittest.TestCase):
    def value(self):
        return {'format': 1, 'jobs': [], 'polls': [{'id': 'a' * 64, 'until': 1800000060}],
                'last_poll': {'scope': 'b' * 64, 'at': 1800000000, 'release_id': RELEASE}}

    def test_transport_churn_and_null_last_poll_preserve_comparison(self):
        original = self.value()
        changed = original | {'polls': [], 'last_poll': None}
        self.assertEqual(worker.stable_runtime_payload(SECTION, json.dumps(original)),
                         worker.stable_runtime_payload(SECTION, json.dumps(changed)))

    def test_invalid_or_unknown_transport_keeps_exact_raw_guard(self):
        base = self.value()
        bad = [base | {'format': True}, base | {'format': 1.0},
               base | {'jobs': {}}, base | {'unknown': 'keep'},
               base | {'polls': [base['polls'][0]] * 2},
               base | {'polls': [base['polls'][0]] * 129},
               base | {'polls': [{'id': 'A' * 64, 'until': 1800000060}]},
               base | {'polls': [{'id': 'a' * 64, 'until': True}]},
               base | {'polls': [{'id': 'a' * 64, 'until': 1.0}]},
               base | {'polls': [{'id': 'a' * 64, 'until': 0}]},
               base | {'polls': [{'id': 'a' * 64, 'until': 2**40}]},
               base | {'polls': [base['polls'][0] | {'extra': 'keep'}]}]
        for change in ({'at': True}, {'at': 0}, {'at': 2**40}, {'scope': 'bad'},
                       {'release_id': 'AAAAAAAA-AAAA-4AAA-8AAA-AAAAAAAAAAAA'}, {'release_id': '0' * 32},
                       {'release_id': '00000000-0000-0000-0000-000000000000'},
                       {'extra': 'keep'}):
            bad.append(base | {'last_poll': base['last_poll'] | change})
        bad.append(base | {'last_poll': {'scope': 'b' * 64, 'at': 1800000000}})
        for value in bad:
            raw = json.dumps(value, indent=2)
            with self.subTest(value=value):
                self.assertEqual(raw, worker.stable_runtime_payload(SECTION, raw))
        raw = json.dumps(base)
        duplicate = raw.replace('"format": 1', '"format": 1, "format": 1')
        nested_duplicate = raw.replace('"at": 1800000000', '"at": 1800000000, "at": 1800000000')
        for bad_raw in (duplicate, nested_duplicate, '{bad', raw + ' trailing',
                        raw.replace('1800000060', 'NaN'), raw.replace('1800000060', '1e999')):
            self.assertEqual(bad_raw, worker.stable_runtime_payload(SECTION, bad_raw))
        self.assertEqual(raw, worker.stable_runtime_payload(SECTION + '_unknown', raw))

    def test_full_jobs_and_future_fields_are_retained_without_authorizing_them(self):
        value = self.value()
        # Deliberately opaque data: backup comparison must not interpret, filter
        # or bless a job. The actual write engine validates authorization.
        value['jobs'] = [{'id': 'opaque', 'target': {'preview': 'keep'},
                          'authorization_id': 'keep', 'claim_sha256': 'keep',
                          'result': {'outcome': 'requires_review', 'evidence': 'keep'},
                          'future_field': {'nested': [True, None, 'keep']}}]
        raw = json.dumps(value)
        projected = worker.stable_runtime_payload(SECTION, raw)
        self.assertEqual(value['jobs'], json.loads(projected)['jobs'])
        changed = copy.deepcopy(value)
        changed['jobs'][0]['future_field']['nested'].append('changed')
        self.assertNotEqual(projected, worker.stable_runtime_payload(SECTION, json.dumps(changed)))

    def test_write_size_bound_matches_one_megabyte_ledger(self):
        value = self.value()
        value['jobs'] = [{'opaque': 'x' * 150000}]
        raw = json.dumps(value)
        self.assertNotEqual(raw, worker.stable_runtime_payload(SECTION, raw))
        oversized = raw + ' ' * (1048577 - len(raw))
        self.assertEqual(oversized, worker.stable_runtime_payload(SECTION, oversized))
        self.assertEqual(raw, worker.stable_runtime_payload('windows_candidate_verify_jobs', raw))


@unittest.skipUnless(sys.platform == 'linux', 'Linux backup with real RSA/SQLite ledger')
class WriteBackupProductionContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        from tests.test_staging_write_jobs import StagingWriteJobTests
        cls.fixture_class = StagingWriteJobTests
        cls.fixture_class.setUpClass()

    @classmethod
    def tearDownClass(cls):
        cls.fixture_class.tearDownClass()

    def setUp(self):
        self.fixture = self.fixture_class(methodName='runTest')
        self.addCleanup(self.fixture.doCleanups)
        self.fixture.setUp()
        with self.fixture.store.connect() as db:
            self.database = Path(db.execute('PRAGMA database_list').fetchone()[2])

    def fingerprint(self):
        return worker.db_fingerprint(self.database)

    def payload(self):
        with self.fixture.store.connect() as db:
            return db.execute('SELECT payload FROM runtime_settings WHERE name=?', (SECTION,)).fetchone()[0]

    def test_actual_signed_idle_polls_and_sqlite_copy_keep_replay_evidence(self):
        from kaname.connector_jobs import JobError
        f = self.fixture
        f.jobs.poll(f.proof())
        before = self.fingerprint()
        old_raw = self.payload()
        f.now += 1
        proof = f.proof()
        f.jobs.poll(proof)
        raw = self.payload()
        self.assertNotEqual(old_raw, raw)
        self.assertEqual(before, self.fingerprint())
        with tempfile.TemporaryDirectory() as root:
            copied = Path(root) / 'snapshot.sqlite3'
            worker.copy_database(self.database, copied)
            self.assertEqual(before, worker.db_fingerprint(copied))
            with sqlite3.connect(copied) as db:
                saved = db.execute('SELECT payload FROM runtime_settings WHERE name=?', (SECTION,)).fetchone()[0]
                self.assertEqual(raw, saved)
                self.assertEqual(2, len(json.loads(saved)['polls']))
                self.assertEqual([('ok',)], db.execute('PRAGMA integrity_check').fetchall())
        with self.assertRaisesRegex(JobError, 'POLL_REPLAY'):
            f.jobs.poll(proof)
        self.assertEqual(raw, self.payload())

    def test_real_stage_and_rollback_transitions_never_disappear_from_comparison(self):
        from kaname.staging_write_jobs import ROLLBACK
        f = self.fixture
        f.jobs.poll(f.proof())
        before = self.fingerprint()
        f.enqueue()
        queued = self.fingerprint()
        self.assertNotEqual(before, queued)
        stage = f.jobs.poll(f.proof())
        leased = self.fingerprint()
        self.assertNotEqual(queued, leased)
        grant = f.authorize(stage)
        authorized = self.fingerprint()
        self.assertNotEqual(leased, authorized)
        f.jobs.complete(f.proof('RESULT', f.result(stage, grant)))
        completed = self.fingerprint()
        self.assertNotEqual(authorized, completed)
        f.now += 1
        f.jobs.poll(f.proof())
        self.assertEqual(completed, self.fingerprint())
        f.enqueue(f.value(ROLLBACK, stage['job_id']))
        rollback_queued = self.fingerprint()
        self.assertNotEqual(completed, rollback_queued)
        rollback = f.jobs.poll(f.proof())
        rollback_leased = self.fingerprint()
        self.assertNotEqual(rollback_queued, rollback_leased)
        grant = f.authorize(rollback)
        rollback_authorized = self.fingerprint()
        self.assertNotEqual(rollback_leased, rollback_authorized)
        f.jobs.complete(f.proof('RESULT', f.result(rollback, grant)))
        rolled_back = self.fingerprint()
        self.assertNotEqual(rollback_authorized, rolled_back)
        f.now += 1
        f.jobs.poll(f.proof())
        self.assertEqual(rolled_back, self.fingerprint())
        raw = self.payload()
        value = json.loads(raw)
        projected = worker.stable_runtime_payload(SECTION, raw)
        self.assertEqual(value['jobs'], json.loads(projected)['jobs'])
        for index, job in enumerate(value['jobs']):
            for name in job:
                changed = copy.deepcopy(value)
                del changed['jobs'][index][name]
                with self.subTest(operation=job['operation'], field=name):
                    self.assertNotEqual(projected, worker.stable_runtime_payload(SECTION, json.dumps(changed)))
            changed = copy.deepcopy(value)
            changed['jobs'][index]['result']['journal_sha256'] = '0' * 64
            self.assertNotEqual(projected, worker.stable_runtime_payload(SECTION, json.dumps(changed)))
            changed = copy.deepcopy(value)
            changed['jobs'][index]['target']['scope_target']['gpo_id'] = RELEASE
            self.assertNotEqual(projected, worker.stable_runtime_payload(SECTION, json.dumps(changed)))
