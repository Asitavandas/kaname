import hashlib
import os
from pathlib import Path
import shutil
import sqlite3
import subprocess
import sys
import tempfile
import threading
from types import SimpleNamespace
import unittest
from datetime import timedelta

from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa

from kaname.pki import PKIError, PKIService, instant, public_der
from kaname.root_crl import RootCRLService, enforce_if_present, validate_crl, write_public_new
from .helpers import config
from .test_pki import PASSWORD, csr

PEM = serialization.Encoding.PEM


class RootCRLTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.base = tempfile.TemporaryDirectory(); cls.now = instant()
        cls.pki = PKIService(cls.base.name)
        cls.pki.store.save(0, config=config()); cls.pki.initialize(PASSWORD, now=cls.now)
        cls.leaf_key = rsa.generate_private_key(65537, 2048)
        cls.leaf = cls.pki.issue_radius(csr(cls.leaf_key), PASSWORD, now=cls.now)
        with cls.pki.store.connect() as db:
            row = db.execute('SELECT root_cert,issuer_cert,root_key,issuer_key FROM pki_authority').fetchone()
        cls.root, cls.issuer = (x509.load_pem_x509_certificate(x) for x in row[:2])
        cls.root_key, cls.issuer_key = (serialization.load_pem_private_key(x, PASSWORD) for x in row[2:])
        cls.fingerprint = cls.root.fingerprint(hashes.SHA256()).hex()

    @classmethod
    def tearDownClass(cls): cls.base.cleanup()

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name) / 'kaname.sqlite3'
        shutil.copyfile(Path(self.base.name) / 'kaname.sqlite3', self.path); self.path.chmod(0o600)
        self.service = RootCRLService(self.temp.name)

    def db(self): return sqlite3.connect(self.path)
    def digest(self): return hashlib.sha256(self.path.read_bytes()).hexdigest()
    def refresh(self, **kw):
        return self.service.refresh(PASSWORD, self.fingerprint, now=self.now, **kw)

    def signed(self, *, signer=None, issuer=None, entries=(), extra=(), at=None, days=30, number=1):
        key=signer or self.root_key; cert=issuer or self.root; at=at or self.now
        b=(x509.CertificateRevocationListBuilder().issuer_name(cert.subject).last_update(at)
           .next_update(at+timedelta(days=days)).add_extension(x509.CRLNumber(number),False)
           .add_extension(x509.AuthorityKeyIdentifier.from_issuer_public_key(key.public_key()),False))
        for serial in entries:
            b=b.add_revoked_certificate(x509.RevokedCertificateBuilder().serial_number(serial)
               .revocation_date(at-timedelta(seconds=1)).add_extension(x509.CRLReason(x509.ReasonFlags.key_compromise),False).build())
        for ext, critical in extra: b=b.add_extension(ext, critical)
        return b.sign(key,hashes.SHA256()).public_bytes(PEM)

    def set_ledger(self, data, number=1):
        with self.db() as db:
            db.execute('CREATE TABLE IF NOT EXISTS pki_root_crls(root_sha256 TEXT PRIMARY KEY,crl BLOB,number INTEGER)')
            db.execute('INSERT OR REPLACE INTO pki_root_crls VALUES (?,?,?)',(self.fingerprint,data,number))

    def test_status_is_read_only_and_explicitly_missing(self):
        before=self.digest(); status=self.service.status(now=self.now)
        self.assertFalse(status['root_crl_present']); self.assertEqual(self.digest(),before)

    def test_first_refresh_requires_initialization(self):
        before=self.digest()
        with self.assertRaises(PKIError): self.refresh()
        self.assertEqual(self.digest(),before)

    def test_signature_identity_and_ca_bytes_preserved(self):
        with self.db() as db: before=db.execute('SELECT * FROM pki_authority').fetchone()
        data=self.refresh(initialize=True); crl,n=validate_crl(data,self.root,self.now)
        self.assertEqual(n,1); self.assertTrue(crl.is_signature_valid(self.root.public_key()))
        with self.db() as db:
            self.assertEqual(db.execute('SELECT * FROM pki_authority').fetchone(),before)
            self.assertEqual(db.execute("SELECT count(*) FROM audit WHERE event LIKE 'pki_root_crl_refreshed:%'").fetchone()[0],1)
        self.assertEqual(data,self.service.export(now=self.now))
        self.assertNotIn(b'PRIVATE KEY',data)

    def test_bad_password_leaves_no_schema_or_audit(self):
        before=self.digest()
        with self.assertRaises(ValueError): self.service.refresh(b'wrong-fixture-password',self.fingerprint,initialize=True,now=self.now)
        self.assertEqual(before,self.digest())

    def test_wrong_appliance_pin_leaves_state_unchanged(self):
        before=self.digest()
        with self.assertRaises(PKIError): self.service.refresh(PASSWORD,'0'*64,initialize=True,now=self.now)
        self.assertEqual(before,self.digest())

    def test_monotonic_refresh_and_no_reset(self):
        self.refresh(initialize=True)
        with self.assertRaises(PKIError): self.refresh(initialize=True)
        data=self.service.refresh(PASSWORD,self.fingerprint,now=self.now+timedelta(days=1))
        self.assertEqual(validate_crl(data,self.root,self.now+timedelta(days=1))[1],2)

    def test_refresh_preserves_revoked_entries_and_dates(self):
        previous=self.signed(entries=(self.issuer.serial_number,12345))
        self.set_ledger(previous)
        data=self.service.refresh(PASSWORD,self.fingerprint,now=self.now+timedelta(days=1))
        old=x509.load_pem_x509_crl(previous); new=x509.load_pem_x509_crl(data)
        def values(crl):
            return [(x.serial_number,x.revocation_date_utc,x.extensions.get_extension_for_class(x509.CRLReason).value.reason) for x in crl]
        self.assertEqual(values(old),values(new))

    def test_audit_failure_rolls_back_crl_and_schema(self):
        with self.db() as db: db.execute("CREATE TRIGGER fail_root_audit BEFORE INSERT ON audit BEGIN SELECT RAISE(ABORT,'test audit'); END")
        before=self.digest()
        with self.assertRaises(sqlite3.Error): self.refresh(initialize=True)
        self.assertEqual(before,self.digest())

    def test_ledger_number_mismatch_rejected(self):
        self.set_ledger(self.signed(),2)
        with self.assertRaises(PKIError): self.service.status(now=self.now)
        with self.assertRaises(PKIError): self.refresh()

    def test_issuer_signed_list_cannot_replace_root_list(self):
        with self.assertRaises(PKIError): validate_crl(self.signed(signer=self.issuer_key,issuer=self.issuer),self.root,self.now)

    def test_wrong_key_signature_rejected(self):
        key=rsa.generate_private_key(65537,2048)
        with self.assertRaises(PKIError): validate_crl(self.signed(signer=key),self.root,self.now)

    def test_future_and_expired_lists_rejected(self):
        for at in (self.now+timedelta(seconds=1),self.now-timedelta(days=31)):
            with self.subTest(at=at),self.assertRaises(PKIError): validate_crl(self.signed(at=at),self.root,self.now)

    def test_delta_partitioned_and_critical_lists_rejected(self):
        cases=[(x509.DeltaCRLIndicator(1),True),
               (x509.IssuingDistributionPoint(None,None,False,True,None,False,False),True),
               (x509.UnrecognizedExtension(x509.ObjectIdentifier('1.2.3.4'),b'fixture'),True)]
        for ext in cases:
            with self.subTest(ext=ext),self.assertRaises(PKIError): validate_crl(self.signed(extra=(ext,)),self.root,self.now)

    def test_duplicate_revocations_rejected(self):
        with self.assertRaises(PKIError): validate_crl(self.signed(entries=(123,123)),self.root,self.now)

    def test_multiple_crls_rejected(self):
        one=self.signed()
        with self.assertRaises(PKIError): validate_crl(one+one,self.root,self.now)

    def test_missing_legacy_list_does_not_change_existing_signing(self):
        service=PKIService(self.temp.name)
        self.assertTrue(service.issue_radius(csr(self.leaf_key),PASSWORD,now=self.now))

    def test_published_stale_list_blocks_signing_but_can_be_refreshed(self):
        self.set_ledger(self.signed(at=self.now-timedelta(days=31)))
        with self.assertRaises(PKIError): PKIService(self.temp.name).issue_radius(csr(self.leaf_key),PASSWORD,now=self.now)
        self.assertTrue(self.refresh())

    def test_revoked_issuer_blocks_issuance_and_is_not_cleared(self):
        self.set_ledger(self.signed(entries=(self.issuer.serial_number,)))
        with self.assertRaises(PKIError): PKIService(self.temp.name).issue_radius(csr(self.leaf_key),PASSWORD,now=self.now)
        self.refresh()
        self.assertTrue(self.service.status(now=self.now)['issuer_revoked'])

    def test_validity_cannot_go_backwards(self):
        self.set_ledger(self.signed(days=90))
        with self.assertRaises(PKIError): self.refresh()

    def test_unattended_cached_key_does_not_bypass_new_root_revocation(self):
        from kaname.device_enrollment import DeviceEnrollment
        from kaname.enrollment import EnrollmentError
        self.refresh(initialize=True)
        with self.db() as db:
            db.execute('CREATE TABLE device_signer(id INTEGER PRIMARY KEY,issuer_sha256 TEXT,key_sealed BLOB)')
            db.execute('INSERT INTO device_signer VALUES (1,?,?)',(self.issuer.fingerprint(hashes.SHA256()).hex(),b'fixture sealed'))
        service=object.__new__(DeviceEnrollment)
        key_pem=self.issuer_key.private_bytes(PEM,serialization.PrivateFormat.PKCS8,serialization.NoEncryption()).decode()
        service.vault=SimpleNamespace(_key=lambda:b'fixture-only-vault-key',open=lambda purpose,data:key_pem)
        service.signer_lock=threading.Lock();service.signer_cache=None
        with self.db() as db: self.assertEqual(service._issuer(db,self.now)[0],self.issuer)
        self.assertIsNotNone(service.signer_cache)
        self.set_ledger(self.signed(entries=(self.issuer.serial_number,)))
        with self.db() as db,self.assertRaises(EnrollmentError): service._issuer(db,self.now)

    def test_no_overwrite_or_link_export(self):
        p=Path(self.temp.name)/'root-crl.pem';p.write_bytes(b'original')
        with self.assertRaises(FileExistsError): write_public_new(p,b'new')
        self.assertEqual(p.read_bytes(),b'original')
        if hasattr(os,'symlink'):
            link=Path(self.temp.name)/'link.pem'
            try:link.symlink_to(p)
            except OSError:return
            with self.assertRaises(PKIError):write_public_new(link,b'new')

    def test_noninteractive_cli_refuses_password_input(self):
        r=subprocess.run([sys.executable,'-m','kaname.root_crl','--state-dir',self.temp.name,'refresh','--expected-root-sha256',self.fingerprint,'--initialize-first-crl'],input=b'not-a-real-password\n',capture_output=True,timeout=5)
        self.assertNotEqual(r.returncode,0);self.assertNotIn(b'not-a-real-password',r.stdout+r.stderr)
        self.assertFalse(self.service.status(now=self.now)['root_crl_present'])

    @unittest.skipUnless(shutil.which('openssl'),'OpenSSL required')
    def test_full_chain_needs_both_crls_and_revoked_issuer_fails(self):
        root=self.temp.name+'/root.pem';issuer=self.temp.name+'/issuer.pem';leaf=self.temp.name+'/leaf.pem';crls=self.temp.name+'/crls.pem'
        Path(root).write_bytes(self.root.public_bytes(PEM));Path(issuer).write_bytes(self.issuer.public_bytes(PEM));Path(leaf).write_bytes(self.leaf)
        issuer_crl=self.pki.public_bundle()['issuer-crl.pem']
        command=['openssl','verify','-crl_check_all','-CAfile',root,'-untrusted',issuer,'-CRLfile',crls,leaf]
        Path(crls).write_bytes(issuer_crl)
        self.assertNotEqual(subprocess.run(command,capture_output=True,timeout=5).returncode,0)
        Path(crls).write_bytes(issuer_crl+self.refresh(initialize=True))
        self.assertEqual(subprocess.run(command,capture_output=True,timeout=5).returncode,0)
        Path(crls).write_bytes(issuer_crl+self.signed(entries=(self.issuer.serial_number,)))
        r=subprocess.run(command,capture_output=True,timeout=5)
        self.assertNotEqual(r.returncode,0);self.assertIn(b'certificate revoked',r.stderr)
