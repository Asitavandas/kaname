import hashlib
import http.client
import json
import ssl
import tempfile
import threading
import unittest
from pathlib import Path

from kaname.server import DevelopmentServer
from kaname.admin import AdminStore
from kaname.store import Store
from tools.linux_initialize import initialize, create_web_certificate
from tools.linux_install import verified_files, hosts_with_dc, dns_name
from tools.linux_prepare import prepare
from .helpers import policy


class LinuxInstallTests(unittest.TestCase):
    def test_bootstrap_preserves_existing_configuration_policies_and_accounts(self):
        with tempfile.TemporaryDirectory() as temporary:
            initialize(temporary, 'lab.example', '192.0.2.10', 'kaname.lab.example')
            store = Store(temporary); store.save(1, policies=[policy()])
            admin = AdminStore(store); session, _ = admin.login('admin', 'Kaname'); actor = admin.authenticate(session)
            admin.change_password(actor, 'Kaname', 'fixture-new-password')
            before = store.snapshot()
            initialize(temporary, 'lab.example', '192.0.2.10', 'kaname.lab.example')
            self.assertEqual(before, store.snapshot())
            AdminStore(store).login('admin', 'fixture-new-password')
            with self.assertRaises(ValueError): initialize(temporary, 'other.example', '192.0.2.10', 'kaname.lab.example')
            self.assertEqual(before, store.snapshot())

    def test_staged_manifest_rejects_changed_files_and_symlinks(self):
        with tempfile.TemporaryDirectory() as temporary:
            destination = Path(temporary) / 'stage'
            result = prepare(Path(__file__).parents[1], destination)
            self.assertIn('kaname/server.py', verified_files(destination, result['source_digest']))
            with self.assertRaises(ValueError): verified_files(destination, '0' * 64)
            server = destination / 'kaname/server.py'; server.write_bytes(server.read_bytes() + b'\n# tampered\n')
            with self.assertRaises(ValueError): verified_files(destination, result['source_digest'])

    def test_authwire_logo_is_staged_and_tampering_is_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            source = Path(__file__).parents[1]
            destination = Path(temporary) / 'stage'
            result = prepare(source, destination)
            files = verified_files(destination, result['source_digest'])
            name = 'kaname/static/authwire-logo.png'
            self.assertEqual((source / name).read_bytes(), files[name])
            self.assertTrue(files[name].startswith(b'\x89PNG\r\n\x1a\n'))
            (destination / name).write_bytes(files[name] + b'tampered')
            with self.assertRaises(ValueError): verified_files(destination, result['source_digest'])

    def test_host_mapping_preserves_unrelated_lines_and_rejects_conflicts(self):
        original = '127.0.0.1 localhost\n192.0.2.20 other.lab.example\n'
        updated = hosts_with_dc(original, 'dc01.lab.example', '192.0.2.10')
        self.assertTrue(updated.startswith(original))
        self.assertEqual(updated, hosts_with_dc(updated, 'dc01.lab.example', '192.0.2.10'))
        with self.assertRaises(ValueError): hosts_with_dc(updated, 'dc01.lab.example', '192.0.2.11')
        for invalid in ('domain', 'evil.example\nExecStart=/bin/sh', '*.lab.example'):
            with self.assertRaises(ValueError): dns_name(invalid)


class TLSPanelTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory()
        cls.root = Path(cls.temp.name)
        create_web_certificate(cls.root, 'kaname.lab.example', '127.0.0.1')
        cls.server = DevelopmentServer(cls.root / 'state', 0, tls_cert=cls.root / 'web.crt', tls_key=cls.root / 'web.key')
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True); cls.thread.start()
        cls.context = ssl.create_default_context(cafile=str(cls.root / 'web.crt'))

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown(); cls.server.server_close(); cls.thread.join(); cls.temp.cleanup()

    def request(self, method, path, value=None, **headers):
        connection = http.client.HTTPSConnection('127.0.0.1', self.server.server_port, context=self.context, timeout=3)
        self.addCleanup(connection.close)
        headers.setdefault('Origin', f'https://127.0.0.1:{self.server.server_port}')
        headers.setdefault('Content-Type', 'application/json')
        connection.request(method, path, json.dumps(value) if value is not None else None, headers)
        response = connection.getresponse(); body = response.read()
        return response.status, body, response.getheader('Set-Cookie')

    def test_login_over_verified_tls_sets_secure_cookie(self):
        status, _, cookie = self.request('POST', '/api/auth/login', {'username': 'admin', 'password': 'Kaname'})
        self.assertEqual(200, status)
        self.assertIn('; Secure', cookie)
        self.assertIn('HttpOnly', cookie)
        self.assertIn('SameSite=Strict', cookie)

    def test_http_origin_and_foreign_host_are_rejected_over_tls(self):
        status, body, _ = self.request('POST', '/api/auth/login', {'username': 'admin', 'password': 'Kaname'}, Origin=f'http://127.0.0.1:{self.server.server_port}')
        self.assertEqual(403, status)
        self.assertIn(b'INVALID_ORIGIN', body)
        self.assertEqual(403, self.request('GET', '/', Host='evil.example')[0])

    def test_unencrypted_lan_listener_refused_before_state_initialization(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary) / 'unused'
            for host in ('192.0.2.20', '0.0.0.0'):
                with self.assertRaises(ValueError): DevelopmentServer(root, 0, listen=host)
            self.assertFalse(root.exists())

    def test_certificate_files_cannot_be_silently_replaced(self):
        before = (self.root / 'web.key').read_bytes()
        with self.assertRaises(ValueError): create_web_certificate(self.root, 'kaname.lab.example', '127.0.0.1')
        self.assertEqual(before, (self.root / 'web.key').read_bytes())
