import http.client
import json
import secrets
import tempfile
import threading
import unittest

from kaname.pki import PKIService
from kaname.server import DevelopmentServer
from .helpers import config


class PublicPKIHTTPTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory()
        cls.pki = PKIService(cls.temp.name)
        cls.pki.store.save(0, config=config())
        cls.passphrase = b'fixture-http-passphrase-123'
        cls.pki.initialize(cls.passphrase)
        cls.token = secrets.token_hex(32)
        cls.server = DevelopmentServer(cls.temp.name, 0, token=cls.token)
        cls.thread = threading.Thread(target=cls.server.serve_forever, daemon=True); cls.thread.start()

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown(); cls.server.server_close(); cls.thread.join(); cls.temp.cleanup()

    def request(self, path='/api/state', method='GET', auth=True):
        connection = http.client.HTTPConnection('127.0.0.1', self.server.server_port, timeout=3)
        self.addCleanup(connection.close)
        headers = {'Origin': f'http://127.0.0.1:{self.server.server_port}'}
        if auth: headers['Authorization'] = 'Bearer ' + self.token
        connection.request(method, path, headers=headers)
        response = connection.getresponse()
        return response.status, response.read()

    def test_initialized_ca_is_shown_as_local_lab_only(self):
        status, body = self.request()
        data = json.loads(body)
        self.assertEqual(status, 200)
        self.assertTrue(data['pki_public']['initialized'])
        self.assertEqual(data['pki_public']['mode'], 'local-lab')
        self.assertFalse(data['pki_public']['radius_connected'])
        self.assertFalse(data['pki_public']['client_enrollment_enabled'])
        self.assertFalse(data['runtime_ready'])

    def test_public_ca_metadata_requires_token(self):
        self.assertEqual(self.request(auth=False)[0], 401)

    def test_private_keys_and_passphrase_are_not_exposed(self):
        body = self.request()[1]
        self.assertNotIn(b'PRIVATE KEY', body)
        self.assertNotIn(self.passphrase, body)
        self.assertNotIn(b'issuer_key', body)
        self.assertNotIn(b'root_key', body)

    def test_no_http_client_enrollment_route(self):
        self.assertEqual(self.request('/api/pki/enroll-client', 'POST')[0], 404)

    def test_ca_creation_does_not_make_runtime_ready(self):
        status, body = self.request('/readyz')
        self.assertEqual(status, 503); self.assertFalse(json.loads(body)['ready'])
