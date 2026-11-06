"""Public CRLs never unlock a signer or mutate the appliance database."""
import base64
import hashlib
from datetime import timedelta
from pathlib import Path
import shutil
import sqlite3
import tempfile
import unittest
from unittest.mock import patch

from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization

from kaname.crl_distribution import public_crls
from kaname.pki import PKIError, PKIService, instant
from kaname.root_crl import RootCRLService
from .helpers import config
from .test_pki import PASSWORD
from .test_enrollment_http import EnrollmentHTTPTests


class CRLDistributionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.base = tempfile.TemporaryDirectory(); cls.now = instant()
        pki = PKIService(cls.base.name); pki.store.save(0, config=config()); pki.initialize(PASSWORD, now=cls.now)
        with pki.store.connect() as db:
            row = db.execute('SELECT root_cert,issuer_cert,root_key FROM pki_authority').fetchone()
        cls.root, cls.issuer = (x509.load_pem_x509_certificate(x) for x in row[:2])
        cls.root_key = serialization.load_pem_private_key(row[2], PASSWORD)
        RootCRLService(cls.base.name).refresh(PASSWORD, cls.root.fingerprint(hashes.SHA256()).hex(), initialize=True, now=cls.now)

    @classmethod
    def tearDownClass(cls): cls.base.cleanup()

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name)/'kaname.sqlite3'
        shutil.copyfile(Path(self.base.name)/'kaname.sqlite3', self.path); self.path.chmod(0o600)

    def update(self, sql, args=()):
        with sqlite3.connect(self.path) as db: db.execute(sql, args)

    def test_both_signed_public_crls_without_state_or_key_access(self):
        before = hashlib.sha256(self.path.read_bytes()).hexdigest()
        queries = []
        original = sqlite3.connect
        def traced(*a, **kw):
            self.assertTrue(a[0].endswith('?mode=ro')); self.assertTrue(kw['uri'])
            db = original(*a, **kw); db.set_trace_callback(queries.append); return db
        with patch('kaname.root_crl.sqlite3.connect', traced):
            result = public_crls(self.temp.name, now=self.now)
        self.assertEqual({'version','root_crl','issuer_crl'}, set(result))
        for name, signer in (('root_crl',self.root),('issuer_crl',self.issuer)):
            crl = x509.load_der_x509_crl(base64.b64decode(result[name], validate=True))
            self.assertTrue(crl.is_signature_valid(signer.public_key()))
        self.assertEqual(before, hashlib.sha256(self.path.read_bytes()).hexdigest())
        self.assertFalse(any('_key' in q or 'UPDATE' in q or 'CREATE' in q for q in queries))

    def test_absent_root_is_not_silently_created(self):
        self.update('DROP TABLE pki_root_crls')
        before = self.path.read_bytes()
        with self.assertRaises(PKIError): public_crls(self.temp.name, now=self.now)
        self.assertEqual(before, self.path.read_bytes())

    def test_expired_lists_are_not_published(self):
        with self.assertRaises(PKIError): public_crls(self.temp.name, now=self.now+timedelta(days=2))
        # Root has its own 30-day validity, independent of the short issuer CRL.
        self.update('UPDATE pki_authority SET crl=(SELECT crl FROM pki_root_crls)')
        with self.assertRaises(PKIError): public_crls(self.temp.name, now=self.now)

    def test_ledger_mismatch_and_malformed_signature_fail_closed(self):
        self.update('UPDATE pki_authority SET crl_number=crl_number+1')
        with self.assertRaises(PKIError): public_crls(self.temp.name, now=self.now)
        self.update('UPDATE pki_authority SET crl=?',(b'not a CRL',))
        with self.assertRaises(ValueError): public_crls(self.temp.name, now=self.now)

    def test_revoked_issuer_never_publishes_partial_bundle(self):
        crl=(x509.CertificateRevocationListBuilder().issuer_name(self.root.subject).last_update(self.now)
             .next_update(self.now+timedelta(days=10)).add_extension(x509.CRLNumber(2),False)
             .add_extension(x509.AuthorityKeyIdentifier.from_issuer_public_key(self.root_key.public_key()),False)
             .add_revoked_certificate(x509.RevokedCertificateBuilder().serial_number(self.issuer.serial_number).revocation_date(self.now).build())
             .sign(self.root_key,hashes.SHA256()))
        self.update('UPDATE pki_root_crls SET crl=?,number=2',(crl.public_bytes(serialization.Encoding.PEM),))
        with self.assertRaises(PKIError): public_crls(self.temp.name, now=self.now)


class CRLDistributionHTTPTests(EnrollmentHTTPTests):
    def test_machine_public_endpoint_has_no_administrator_session_requirement(self):
        from kaname.root_crl import RootCRLService
        service = RootCRLService(self.server.store.root)
        service.refresh(b'fixture-http-enrollment-12345',service.status()['root_sha256'],initialize=True)
        status, value, cookie = self.request('GET','/api/public/crls')
        self.assertEqual(200,status); self.assertIsNone(cookie)
        self.assertEqual({'version','root_crl','issuer_crl'},set(value))
        self.assertNotIn('PRIVATE KEY',str(value))
        self.assertEqual(401,self.request('GET','/api/pki/public?name=issuer-crl.pem')[0])

    def test_public_route_tls_host_query_and_fixed_error(self):
        for suffix in ('?name=root_key','?','?version=1'):
            self.assertEqual(400,self.request('GET','/api/public/crls'+suffix)[0])
        self.assertEqual(403,self.request('GET','/api/public/crls',headers={'Host':'untrusted.example'})[0])
        with patch.object(self.server,'tls',False):
            self.assertEqual(403,self.request('GET','/api/public/crls')[0])
        with patch('kaname.crl_distribution.public_crls',side_effect=ValueError('secret database detail')):
            status,body,_=self.request('GET','/api/public/crls')
        self.assertEqual(503,status);self.assertEqual({'error':'CRL_UNAVAILABLE'},body)
