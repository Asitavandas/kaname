import hashlib
import json
import tempfile
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

from kaname.server import DevelopmentServer
from tools.windows_diagnose import database_facts, diagnose, get_json, read_token


class WindowsDiagnosticTests(unittest.TestCase):
    def test_missing_installation_does_not_create_it(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder) / 'missing'
            facts, snapshot = database_facts(root)
            self.assertFalse(facts['exists'])
            self.assertIsNone(snapshot)
            self.assertIsNone(read_token(root))
            self.assertFalse(root.exists())

    def test_report_preserves_state_and_redacts_secrets(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / 'kaname').mkdir()
            (root / 'kaname' / '__init__.py').write_text('VERSION = "0.2.0-dev.1"\n')
            server = DevelopmentServer(root / 'kaname-state', port=0)
            config = {'appliance_fqdn': 'hidden-radius.example', 'ad_domain': 'hidden-domain.example',
                      'dc_ips': ['192.0.2.10'], 'radius_clients': [], 'access_modes': ['wired']}
            server.store.save(0, config=config)
            with server.store.connect() as db:
                db.execute('CREATE TABLE pki_authority (id INTEGER, root_key BLOB, public_data TEXT, crl_number INTEGER)')
                metadata = {'initialized': True, 'mode': 'local-encrypted', 'instance_id': 'test-instance',
                            'root': dict.fromkeys(('serial', 'fingerprint_sha256', 'not_before', 'not_after'), 'public'),
                            'issuer': dict.fromkeys(('serial', 'fingerprint_sha256', 'not_before', 'not_after'), 'public')}
                db.execute('INSERT INTO pki_authority VALUES (1, ?, ?, 1)', (b'PRIVATE_CA_KEY_SENTINEL', json.dumps(metadata)))
            before = hashlib.sha256(server.store.path.read_bytes()).hexdigest()
            thread = threading.Thread(target=server.serve_forever, daemon=True)
            thread.start()
            try:
                report = diagnose(root, port=server.server_port)
            finally:
                server.shutdown()
                server.server_close()
                thread.join()
            serialized = json.dumps(report)
            for hidden in [server.token, 'hidden-radius.example', 'hidden-domain.example', 'PRIVATE_CA_KEY_SENTINEL']:
                self.assertNotIn(hidden, serialized)
            self.assertTrue(report['access_token_valid'])
            self.assertTrue(report['database']['config_saved'])
            self.assertTrue(report['database']['ca_initialized'])
            self.assertTrue(report['panel']['matches_local_state'])
            self.assertTrue(report['panel']['disabled_account_simulation_passed'])
            self.assertEqual(before, hashlib.sha256(server.store.path.read_bytes()).hexdigest())
            self.assertEqual(1, server.store.snapshot()['revision'])

    def test_redirect_never_forwards_token(self):
        paths = []
        class Redirect(BaseHTTPRequestHandler):
            def do_GET(self):
                paths.append(self.path)
                self.send_response(302)
                self.send_header('Location', '/token-collector')
                self.end_headers()
            def log_message(self, *args):
                pass
        with ThreadingHTTPServer(('127.0.0.1', 0), Redirect) as server:
            thread = threading.Thread(target=server.serve_forever, daemon=True)
            thread.start()
            try:
                status, payload = get_json('/api/state', token='a' * 64, port=server.server_port)
            finally:
                server.shutdown()
                thread.join()
        self.assertEqual(302, status)
        self.assertIsNone(payload)
        self.assertEqual(['/api/state'], paths)

    def test_invalid_database_is_reported_without_input_data(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            state = root / 'kaname-state'
            state.mkdir()
            path = state / 'kaname.sqlite3'
            content = b'PASSWORD_SENTINEL_NOT_A_DATABASE'
            path.write_bytes(content)
            facts, snapshot = database_facts(root)
            self.assertEqual('DATABASE_OR_SCHEMA_INVALID', facts['read_error'])
            self.assertIsNone(snapshot)
            self.assertNotIn('PASSWORD_SENTINEL', json.dumps(facts))
            self.assertEqual(content, path.read_bytes())

    def test_invalid_token_is_never_returned(self):
        with tempfile.TemporaryDirectory() as folder:
            root = Path(folder)
            (root / 'kaname-state').mkdir()
            (root / 'kaname-state' / 'access-token').write_text('NOT_A_VALID_TOKEN')
            self.assertIsNone(read_token(root))
