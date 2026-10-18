import hashlib
import http.client
import json
from pathlib import Path
import sqlite3
import tempfile
import threading
from types import SimpleNamespace
import unittest
from unittest.mock import patch

from kaname.audit import history, parse, AuditQueryLimit
from kaname.store import Store
from kaname.server import DevelopmentServer


class AuditTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.store = Store(self.temp.name); self.admin = SimpleNamespace(path=Path(self.temp.name) / 'administrators.sqlite3')

    def add(self, event='config_saved', at='2026-10-18T10:00:00.000Z'):
        with self.store.connect() as db: db.execute('INSERT INTO audit(event,revision,at) VALUES (?,7,?)', (event, at))

    def test_keyset_snapshot_does_not_skip_or_repeat_during_new_writes(self):
        for n in range(205): self.add()
        first = history(self.store, self.admin, {})
        self.assertEqual(list(range(205, 105, -1)), [r['id'] for r in first['events']])
        self.add('new_after_snapshot')
        second = history(self.store, self.admin, {'before': ['106'], 'watermark': [str(first['watermark'])]})
        third = history(self.store, self.admin, {'before': [str(second['next_before'])], 'watermark': [str(first['watermark'])]})
        self.assertEqual(list(range(205, 0, -1)), [r['id'] for p in (first, second, third) for r in p['events']])
        self.assertFalse(third['has_more']); self.assertIsNone(third['next_before'])

    def test_empty_watermark_zero_and_no_future_inclusion(self):
        page = history(self.store, self.admin, {}); self.assertEqual(0, page['watermark'])
        self.add(); self.assertEqual([], history(self.store, self.admin, {'watermark': ['0']})['events'])

    def test_timezone_date_edges_event_family_and_literal_search(self):
        self.add('device_certificate_issued:abcdef', '2026-10-17T21:00:00.000Z')
        self.add('device_certificate_issued:123abc', '2026-10-18T21:00:00.000Z')
        q = {'from': ['2026-10-18T00:00:00+03:00'], 'to': ['2026-10-19T00:00:00+03:00'], 'event': ['device_certificate_issued'], 'q': ['ABC']}
        self.assertEqual('abcdef', history(self.store, self.admin, q)['events'][0]['reference'])
        self.assertEqual(1, len(history(self.store, self.admin, q)['events']))
        q['q'] = ["%' OR 1=1 --"]
        self.assertEqual([], history(self.store, self.admin, q)['events'])

    def test_invalid_or_ambiguous_filters_are_refused(self):
        for q in ({'unknown': ['x']}, {'event': ['%']}, {'before': ['-1']}, {'before': ['0']}, {'before': ['01']},
                  {'watermark': [str(2**63)]}, {'q': ['x\n']}, {'q': ['x' * 129]}, {'source': ['bad']},
                  {'from': ['2026-10-18T00:00:00']}, {'from': ['bad']}, {'event': ['a', 'b']},
                  {'from': ['2026-10-19T00:00:00Z'], 'to': ['2026-10-18T00:00:00Z']}):
            with self.subTest(q=q), self.assertRaises(ValueError): parse(q)

    def test_service_intent_is_projected_and_never_becomes_completion_or_auth(self):
        self.add('service_action_requested:' + json.dumps({'actor': 'operator', 'service': 'radius', 'action': 'restart', 'request_id': 'fixture-id', 'password': 'must-not-escape'}))
        page = history(self.store, self.admin, {})
        self.assertNotIn('must-not-escape', json.dumps(page)); self.assertEqual('operator', page['events'][0]['actor'])
        self.assertFalse(page['coverage']['service_requests_are_completion_proof'])
        self.assertFalse(page['coverage']['radius_decisions']); self.assertFalse(page['coverage']['accounting_sessions'])
        self.assertIsNone(page['events'][0]['reference'])

    def test_legacy_unknown_actor_remains_unknown_and_private_keys_never_selected(self):
        self.add('config_saved'); self.add('pki_certificate_revoked:abc:actor:operator')
        with self.store.connect() as db: db.execute('CREATE TABLE fixture_secret (password TEXT)'); db.execute('INSERT INTO fixture_secret VALUES (?)', ('never-export-this',))
        page = history(self.store, self.admin, {})
        self.assertEqual('operator', page['events'][0]['actor']); self.assertIsNone(page['events'][1]['actor'])
        self.assertNotIn('never-export-this', json.dumps(page)); self.assertTrue(page['storage']['append_only']); self.assertFalse(page['storage']['automatic_deletion'])

    def test_reads_preserve_database_bytes_schema_and_append_only_guards(self):
        self.add(); before = hashlib.sha256(self.store.path.read_bytes()).digest()
        history(self.store, self.admin, {})
        self.assertEqual(before, hashlib.sha256(self.store.path.read_bytes()).digest())
        with self.store.connect() as db:
            for sql in ('DELETE FROM audit', "UPDATE audit SET event='forged'"):
                with self.assertRaises(sqlite3.IntegrityError): db.execute(sql)

    def test_administrator_source_is_separate_and_permission_checked_before_open(self):
        with self.assertRaises(PermissionError): history(self.store, self.admin, {'source': ['administrators']})
        self.assertFalse(self.admin.path.exists())
        with sqlite3.connect(self.admin.path) as db:
            db.execute('CREATE TABLE admin_audit(id INTEGER PRIMARY KEY,event TEXT,actor_id TEXT,target_id TEXT,at TEXT)')
            db.execute("INSERT INTO admin_audit VALUES (1,'admin_login','actor-id','target-id','2026-10-18T10:00:00.000Z')")
            db.execute('CREATE TABLE admin_sessions(secret TEXT)'); db.execute("INSERT INTO admin_sessions VALUES ('private-cookie')")
        p = history(self.store, self.admin, {'source': ['administrators']}, administrators=True)
        self.assertEqual('actor-id', p['events'][0]['actor']); self.assertNotIn('private-cookie', json.dumps(p))
        self.assertEqual(['application'], history(self.store, self.admin, {})['sources'])

    def test_slow_scan_is_bounded(self):
        with self.store.connect() as db:
            db.executemany('INSERT INTO audit(event,revision) VALUES (?,1)', [('config_saved',)] * 500)
        with patch('kaname.audit.time.monotonic', side_effect=[0] + [4] * 100):
            with self.assertRaises(AuditQueryLimit): history(self.store, self.admin, {'q': ['no-match']})


class AuditHTTPTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory(); cls.server = DevelopmentServer(cls.temp.name, 0)
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True); cls.thread.start()

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown(); cls.server.server_close(); cls.thread.join(); cls.temp.cleanup()

    def request(self, path, token=True):
        conn = http.client.HTTPConnection('127.0.0.1', self.server.server_port, timeout=5)
        try:
            conn.request('GET', path, headers={'Authorization': 'Bearer ' + self.server.token} if token else {})
            r = conn.getresponse(); return r.status, json.loads(r.read()), dict(r.headers)
        finally: conn.close()

    def test_guarded_get_and_no_store(self):
        self.assertEqual(401, self.request('/api/audit/history', False)[0])
        code, data, headers = self.request('/api/audit/history')
        self.assertEqual(200, code); self.assertEqual('no-store', headers['Cache-Control']); self.assertIn('events', data)

    def test_duplicate_query_and_invalid_range_fail_cleanly(self):
        for suffix in ('?source=application&source=administrators', '?before=NaN', '?event=bad%25'):
            self.assertEqual(400, self.request('/api/audit/history' + suffix)[0])

    def test_legacy_audit_endpoint_remains_compatible(self):
        code, data, _ = self.request('/api/audit'); self.assertEqual(200, code); self.assertEqual({'events'}, set(data))
