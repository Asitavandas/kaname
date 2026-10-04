import http.client
import json
import ssl
import tempfile
import threading
import unittest
from pathlib import Path
from unittest.mock import patch

from kaname.server import DevelopmentServer
from kaname.pki import PKIService
from tools.linux_initialize import create_web_certificate
from .helpers import config


class EnrollmentHTTPTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory(); root = Path(cls.temp.name)
        create_web_certificate(root,'kaname.lab.example','127.0.0.1')
        cls.server = DevelopmentServer(root/'state',0,tls_cert=root/'web.crt',tls_key=root/'web.key')
        cls.server.store.save(0,config=config())
        PKIService(root/'state').initialize(b'fixture-http-enrollment-12345')
        cls.context = ssl.create_default_context(cafile=str(root/'web.crt'))
        cls.thread = threading.Thread(target=cls.server.serve_forever,daemon=True); cls.thread.start()

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown(); cls.server.server_close(); cls.thread.join(); cls.temp.cleanup()

    def request(self,method,path,value=None,headers=None):
        connection = http.client.HTTPSConnection('127.0.0.1',self.server.server_port,context=self.context,timeout=8)
        self.addCleanup(connection.close)
        connection.request(method,path,json.dumps(value) if value is not None else None,
            {'Content-Type':'application/json','Origin':f'https://127.0.0.1:{self.server.server_port}',**(headers or {})})
        response = connection.getresponse()
        return response.status,json.loads(response.read()),response.getheader('Set-Cookie')

    def login(self,name='admin',password='Kaname'):
        status,actor,cookie = self.request('POST','/api/auth/login',{'username':name,'password':password})
        self.assertEqual(200,status)
        return {'Cookie':cookie.split(';')[0],'X-Kaname-CSRF':actor['csrf']}

    def test_unauthorized_cannot_read_ca_or_enroll(self):
        self.assertEqual(401,self.request('GET','/api/pki/public?name=root-ca.pem')[0])
        self.assertEqual(401,self.request('POST','/api/pki/enroll-user',{})[0])

    def test_enrollment_requires_csrf_and_certificates_write(self):
        headers=self.login()
        self.assertEqual(403,self.request('POST','/api/pki/enroll-user',{}, {'Cookie':headers['Cookie']})[0])
        with patch('kaname.server.permits',return_value=False):
            self.assertEqual(403,self.request('POST','/api/pki/enroll-user',{},headers)[0])

    def test_https_only_no_plaintext_override_for_maintenance(self):
        headers=self.login()
        with patch.object(self.server,'tls',False):
            status,body,_=self.request('POST','/api/pki/enroll-user',{},headers)
        self.assertEqual(403,status);self.assertEqual('PKI_HTTPS_REQUIRED',body['error'])

    def test_public_exports_do_not_expose_private_keys_or_allow_arbitrary_names(self):
        headers=self.login()
        for name in ('root-ca.pem','issuer-ca.pem','issuer-crl.pem'):
            status,body,_=self.request('GET','/api/pki/public?name='+name,headers=headers)
            self.assertEqual(200,status);self.assertNotIn('PRIVATE KEY',json.dumps(body))
        self.assertEqual(400,self.request('GET','/api/pki/public?name=issuer_key',headers=headers)[0])

    def test_no_caller_supplied_guid_or_sid_for_enrollment(self):
        headers=self.login()
        status,body,_=self.request('POST','/api/pki/enroll-user',{'ca_password':'fixture-http-enrollment-12345','object_guid':'forged','sid':'forged'},headers)
        self.assertEqual(400,status);self.assertEqual('INVALID_INPUT',body['error'])

    def test_no_ca_reset_and_unknown_certificate_return_safe_errors(self):
        headers=self.login()
        status,body,_=self.request('POST','/api/pki/initialize',{'ca_password':'fixture-http-enrollment-12345','confirm':'fixture-http-enrollment-12345'},headers)
        self.assertEqual(400,status);self.assertEqual('PKI_OPERATION_FAILED',body['error'])
        self.assertEqual(404,self.request('GET','/api/pki/certificate?serial=123',headers=headers)[0])
        status,body,_=self.request('GET','/api/pki/certificates',headers=headers)
        self.assertEqual(200,status);self.assertEqual([],body['items'])

    def test_parallel_issuance_gate_rejects_without_ca_unlock(self):
        headers=self.login();self.server.enrollment_lock.acquire()
        try:
            status,body,_=self.request('POST','/api/pki/enroll-user',{},headers)
            self.assertEqual(429,status);self.assertEqual('ENROLLMENT_BUSY',body['error'])
        finally:self.server.enrollment_lock.release()

    def test_successful_https_issue_uses_real_signer_and_persistent_registry(self):
        import types
        from kaname.enrollment import EnrollmentService
        from kaname.operations import Operations
        from kaname.radius import CertificateReference
        from kaname.radius_registry import CertificateRegistry
        from cryptography import x509
        from cryptography.hazmat.primitives import hashes
        from .test_directory import connection
        from .test_radius_live import live_account
        from .test_enrollment import request
        ops=self.server.operations
        revision=self.server.store.snapshot()['revision']
        ops.save_directory(revision,connection()|{'search_base':'','sync_minutes':15,'check_minutes':5,'automatic_sync':False})
        account=live_account(kind='user')
        service=EnrollmentService(ops,authenticator=lambda *args:account,directory=types.SimpleNamespace(lookup=lambda *args:account))
        value={'csr':request().decode(),'username':'alice@lab.example','password':'fixture-user-password',
            'ca_password':'fixture-http-enrollment-12345','expected_revision':self.server.store.snapshot()['revision'],'days':30}
        with patch('kaname.enrollment.EnrollmentService',return_value=service):
            status,body,_=self.request('POST','/api/pki/enroll-user',value,self.login())
        self.assertEqual(200,status)
        for secret in ('fixture-user-password','fixture-http-enrollment-12345','PRIVATE KEY'):
            self.assertNotIn(secret,json.dumps(body))
        issuer=x509.load_pem_x509_certificate(service.pki.public_bundle()['issuer-ca.pem'])
        ref=CertificateReference(issuer.fingerprint(hashes.SHA256()).hex(),body['serial'])
        self.assertEqual('user',CertificateRegistry(self.server.store).lookup(ref).kind)
        status,download,_=self.request('GET','/api/pki/certificate?serial='+body['serial'],headers=self.login())
        self.assertEqual(200,status);self.assertEqual(body['certificate'],download['pem'])
