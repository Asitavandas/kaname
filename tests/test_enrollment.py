"""Synthetic identities only; failures must leave certificate/binding/audit atomic."""
import importlib.util
import json
import shutil
import tempfile
import types
import unittest
import uuid
from pathlib import Path
from unittest.mock import patch

from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec, rsa
from cryptography.x509.oid import ExtendedKeyUsageOID, NameOID

from kaname.directory import DirectoryError
from kaname.directory_linux import authenticate_linux_user
from kaname.directory_linux_helper import Reader, verify_ticket_identity
from kaname.enrollment import EnrollmentError, EnrollmentService, client_csr
from kaname.operations import Operations
from kaname.pki import PKIError, PKIService
from kaname.radius import CertificateReference, DirectoryUnavailable, TLSAuthorization
from kaname.radius_registry import CertificateRegistry
from kaname.store import Store
from tools.client_request import create
from .helpers import config, policy
from .ldap_fixture import LDAPFixture
from .test_directory import connection
from .test_radius_live import GUID, SID, GROUP, PRIMARY, attributes, live_account

PASSWORD = b'fixture-enrollment-passphrase-123'


def request(key=None, *, extension=None, subject='Forged administrator name'):
    key = key or ec.generate_private_key(ec.SECP256R1())
    builder = x509.CertificateSigningRequestBuilder().subject_name(x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, subject)]))
    if extension is not None: builder = builder.add_extension(extension, critical=False)
    return builder.sign(key, hashes.SHA256()).public_bytes(serialization.Encoding.PEM)


class EnrollmentTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.baseline = tempfile.TemporaryDirectory()
        store = Store(cls.baseline.name); store.save(0, config=config())
        ops = Operations(store)
        ops.save_directory(1, connection() | {'search_base': '', 'sync_minutes': 15, 'check_minutes': 5, 'automatic_sync': False})
        PKIService(cls.baseline.name).initialize(PASSWORD)

    @classmethod
    def tearDownClass(cls): cls.baseline.cleanup()

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        shutil.copytree(self.baseline.name, self.temp.name, dirs_exist_ok=True)
        self.store = Store(self.temp.name); self.operations = Operations(self.store)
        self.account = live_account(kind='user')
        self.seen = []
        def authenticate(credentials, cfg):
            self.seen.append(credentials)
            self.assertEqual('user-only-fixture-password', credentials['password'])
            self.assertEqual('alice@lab.example', credentials['username'])
            return self.account
        self.service = EnrollmentService(self.operations, authenticator=authenticate,
            directory=types.SimpleNamespace(lookup=lambda *args: self.account))
        self.revision = self.store.snapshot()['revision']
        self.key = ec.generate_private_key(ec.SECP256R1())
        self.csr = request(self.key)

    def issue(self, **changes):
        args = dict(csr_pem=self.csr, username='alice@lab.example', credential='user-only-fixture-password',
            ca_password=PASSWORD, expected_revision=self.revision)
        return self.service.issue_user(**(args | changes))

    def count(self, table):
        with self.store.connect() as db: return db.execute('SELECT count(*) FROM ' + table).fetchone()[0]

    def test_certificate_and_live_identity_binding_survive_restart(self):
        result = self.issue()
        cert = x509.load_pem_x509_certificate(result['certificate'].encode())
        self.assertNotIn('Forged', cert.subject.rfc4514_string())
        self.assertEqual([ExtendedKeyUsageOID.CLIENT_AUTH], list(cert.extensions.get_extension_for_class(x509.ExtendedKeyUsage).value))
        with self.assertRaises(x509.ExtensionNotFound): cert.extensions.get_extension_for_class(x509.SubjectAlternativeName)
        self.assertEqual('', self.seen[0]['password'])
        issuer = x509.load_pem_x509_certificate(self.service.pki.public_bundle()['issuer-ca.pem'])
        cert.verify_directly_issued_by(issuer)
        ref = CertificateReference(issuer.fingerprint(hashes.SHA256()).hex(), result['serial'])
        binding = CertificateRegistry(Store(self.temp.name)).lookup(ref)
        self.assertEqual((GUID, SID, 'user'), (binding.object_guid, binding.sid, binding.kind))
        self.assertEqual(1, self.count('pki_certificates'))
        self.assertEqual(1, self.count('radius_certificate_bindings'))
        encoded = json.dumps(result) + json.dumps(self.store.audit())
        self.assertNotIn('user-only-fixture-password', encoded)
        self.assertNotIn(PASSWORD.decode(), encoded)
        self.assertNotIn('PRIVATE KEY', encoded)

    def test_signed_crl_and_registry_deny_revoked_user(self):
        result = self.issue()
        issuer = x509.load_pem_x509_certificate(self.service.pki.public_bundle()['issuer-ca.pem'])
        ref = CertificateReference(issuer.fingerprint(hashes.SHA256()).hex(), result['serial'])
        registry = CertificateRegistry(self.store)
        p = policy(constraints={'eap_methods': ['EAP-TLS'], 'require_domain_device': False},
                   conditions={'group_sids': [GROUP], 'access_types': ['wired'], 'nas_ips': []})
        engine = TLSAuthorization([p], registry=registry, directory=self.service.directory)
        self.assertEqual('allow', engine.authorize(ref, nas_ip='127.0.0.1', access_type='wired').action)
        machine_policy = policy()
        self.assertEqual('deny', TLSAuthorization([machine_policy], registry=registry, directory=self.service.directory).authorize(ref, nas_ip='127.0.0.1', access_type='wired').action)
        self.service.pki.revoke(result['serial'], PASSWORD)
        self.assertIsNone(registry.lookup(ref))
        self.assertEqual('deny', engine.authorize(ref, nas_ip='127.0.0.1', access_type='wired').action)
        crl = x509.load_pem_x509_crl(self.service.pki.public_bundle()['issuer-crl.pem'])
        self.assertTrue(crl.is_signature_valid(issuer.public_key()))
        self.assertEqual(int(result['serial'], 16), list(crl)[0].serial_number)

    def test_csr_and_public_key_reuse_rejected_before_second_auth(self):
        self.issue()
        for data in (self.csr, self.csr + b'\n', request(self.key,subject='Another name')):
            with self.assertRaises(EnrollmentError) as error: self.issue(csr_pem=data)
            self.assertEqual('CSR_ALREADY_USED', error.exception.code)
        self.assertEqual(1, len(self.seen))
        self.assertEqual(1, self.count('pki_certificates'))

    def test_authentication_failure_and_restart_cooldown_preserve_no_issuance(self):
        self.service.authenticator = lambda *args: (_ for _ in ()).throw(DirectoryError('AD_CREDENTIALS_REJECTED'))
        with self.assertRaises(EnrollmentError) as error: self.issue()
        self.assertEqual('ENROLLMENT_AUTHENTICATION_FAILED', error.exception.code)
        restarted = EnrollmentService(self.operations, authenticator=lambda *args: self.fail('Cooldown bypass'))
        with self.assertRaises(EnrollmentError) as error:
            restarted.issue_user(self.csr, 'alice@lab.example', 'fixture', PASSWORD, expected_revision=self.revision)
        self.assertEqual('ENROLLMENT_RETRY_LATER', error.exception.code)
        self.assertEqual(0, self.count('pki_certificates'))

    def test_wrong_ca_password_does_not_contact_ad(self):
        with self.assertRaises(PKIError): self.issue(ca_password=b'wrong-fixture-passphrase')
        self.assertEqual([], self.seen)

    def test_user_proof_cannot_issue_for_machine_foreign_or_disabled_account(self):
        for account in (live_account(), live_account(kind='user', enabled=False), live_account(kind='user', domain='other.example')):
            with self.subTest(account=account):
                with self.store.connect() as db: db.execute('DELETE FROM pki_enrollment_rate')
                self.account = account
                with self.assertRaises(EnrollmentError): self.issue()
        self.assertEqual(0, self.count('radius_certificate_bindings'))

    def test_live_lookup_deleted_disabled_mismatched_or_unavailable_rejects(self):
        for account in (None, live_account(kind='user', enabled=False), live_account(kind='user', sid='S-1-5-21-1-2-3-1002')):
            with self.store.connect() as db: db.execute('DELETE FROM pki_enrollment_rate')
            self.service.directory = types.SimpleNamespace(lookup=lambda *args: account)
            with self.assertRaises(EnrollmentError): self.issue()
        with self.store.connect() as db: db.execute('DELETE FROM pki_enrollment_rate')
        self.service.directory = types.SimpleNamespace(lookup=lambda *args: (_ for _ in ()).throw(DirectoryUnavailable()))
        with self.assertRaises(EnrollmentError) as error: self.issue()
        self.assertEqual('ENROLLMENT_DIRECTORY_UNAVAILABLE', error.exception.code)
        self.assertEqual(0, self.count('pki_certificates'))

    def test_concurrent_config_change_and_audit_failure_rollback_everything(self):
        def change(*args):
            self.store.save(self.revision, config=config())
            return self.account
        self.service.directory = types.SimpleNamespace(lookup=change)
        with self.assertRaises(EnrollmentError): self.issue()
        self.assertEqual(0, self.count('pki_certificates'))
        self.revision = self.store.snapshot()['revision']
        self.service.directory = types.SimpleNamespace(lookup=lambda *args: self.account)
        with self.store.connect() as db:
            db.execute('DELETE FROM pki_enrollment_rate')
            db.execute("CREATE TRIGGER fixture_fail BEFORE INSERT ON audit BEGIN SELECT RAISE(ABORT,'fixture'); END")
        import sqlite3
        with self.assertRaises(sqlite3.IntegrityError): self.issue()
        for table in ('pki_certificates','radius_certificate_bindings','pki_client_keys'): self.assertEqual(0, self.count(table))

    def test_san_ca_eku_bad_key_and_multiple_csr_are_rejected(self):
        for extension in (x509.SubjectAlternativeName([x509.DNSName('evil.lab.example')]), x509.BasicConstraints(True, 0), x509.ExtendedKeyUsage([ExtendedKeyUsageOID.SERVER_AUTH])):
            with self.assertRaises(EnrollmentError): client_csr(request(extension=extension))
        for data in (self.csr * 2, b'bad', request(rsa.generate_private_key(65537, 1024)), request(ec.generate_private_key(ec.SECP521R1()))):
            with self.assertRaises(EnrollmentError): client_csr(data)

    def test_unsupported_principal_formats_do_not_contact_kdc(self):
        for username in ('alice@other.example','Administrator/host@lab.example','PC01$@lab.example','-bad@lab.example','alice)(objectClass=*)@lab.example'):
            with self.assertRaises(EnrollmentError): self.issue(username=username)
        self.assertEqual([], self.seen)

    def test_readonly_list_does_not_create_ca_or_keys(self):
        with tempfile.TemporaryDirectory() as directory:
            store = Store(directory)
            self.assertEqual([], EnrollmentService.certificates(store)['items'])
            with store.connect() as db:
                self.assertFalse(db.execute("SELECT 1 FROM sqlite_master WHERE name='pki_authority'").fetchone())

    def test_endpoint_key_encrypted_and_never_overwritten(self):
        folder = Path(self.temp.name) / 'endpoint'
        create(folder, PASSWORD)
        key = (folder / 'client-key.pem').read_bytes()
        self.assertTrue(key.startswith(b'-----BEGIN ENCRYPTED PRIVATE KEY-----'))
        client_csr((folder / 'client-request.pem').read_bytes())
        with self.assertRaises(FileExistsError): create(folder, PASSWORD)
        self.assertEqual(key, (folder / 'client-key.pem').read_bytes())


class SelfIdentityTests(unittest.TestCase):
    def test_ticket_cache_principal_mismatch_absence_duplicate_and_wrong_realm_reject(self):
        env={'KRB5CCNAME':'FILE:/private-fixture/cache'}
        for output in (b'no principal',b'Default principal: bob@LAB.EXAMPLE\n',
                b'Default principal: alice@OTHER.EXAMPLE\n',b'Default principal: alice@LAB.EXAMPLE\n'*2,
                b'Default principal: alice@LAB.EXAMPLE\n'+b'x'*16384):
            with patch('kaname.directory_linux_helper.subprocess.run',return_value=types.SimpleNamespace(returncode=0,stdout=output)):
                with self.assertRaises(DirectoryError): verify_ticket_identity(env,'alice@LAB.EXAMPLE')
        with patch('kaname.directory_linux_helper.subprocess.run',return_value=types.SimpleNamespace(returncode=0,stdout=b'Default principal: alice@LAB.EXAMPLE\n')):
            verify_ticket_identity(env,'alice@LAB.EXAMPLE')

    def test_whoami_sid_or_netbios_account_must_match_current_domain_identity(self):
        connection=types.SimpleNamespace(whoami_s=lambda:'u:LAB\\alice')
        reader=Reader(connection,types.SimpleNamespace(SCOPE_SUBTREE=2),None)
        def search(base,*args):
            if base.startswith('CN=Partitions,'):
                return [('CN=LAB,CN=Partitions,CN=Configuration,DC=lab,DC=example',{'ncname':[b'DC=lab,DC=example'],'netbiosname':[b'LAB']})],[]
            return [('CN=Alice,DC=lab,DC=example',{'objectguid':[uuid.UUID(GUID).bytes_le],'samaccountname':[b'alice']})],[]
        reader.search=search
        reader.account=lambda *args: {'kind':'user','enabled':True,'sid':SID}
        self.assertEqual(SID,reader.authenticated_user('lab.example','alice','CN=Configuration,DC=lab,DC=example')['sid'])
        for response in ('','u:FOREIGN\\alice','u:LAB\\bob','dn:CN=Alice,DC=lab,DC=example','u:S-1-5-21-1-2-3-1002'):
            connection.whoami_s=lambda:response
            with self.assertRaises(DirectoryError): reader.authenticated_user('lab.example','alice','CN=Configuration,DC=lab,DC=example')
    def test_authenticated_name_resolves_guid_then_live_account(self):
        reader = Reader(types.SimpleNamespace(whoami_s=lambda:'u:'+SID), types.SimpleNamespace(SCOPE_SUBTREE=2), None)
        calls = []
        def search(*args):
            calls.append(args)
            return [('CN=Alice,DC=lab,DC=example', {'objectguid': [uuid.UUID(GUID).bytes_le], 'samaccountname': [b'alice']})], []
        reader.search = search
        reader.account = lambda *args: {'kind':'user','enabled':True,'object_guid':GUID,'sid':SID}
        self.assertEqual(GUID, reader.authenticated_user('lab.example', 'alice')['object_guid'])
        self.assertIn('(sAMAccountName=alice)', calls[0][2])
        for row in (None, {'kind':'computer','enabled':True}, {'kind':'user','enabled':False}):
            reader.account = lambda *args: row
            with self.assertRaises(DirectoryError): reader.authenticated_user('lab.example', 'alice')

    def test_real_wrapper_uses_self_mode_and_never_accepts_requested_guid(self):
        account = live_account(kind='user')
        payload = {'domain': account.domain, 'dc_fqdn':'dc01.lab.example', 'account': account.__dict__ | {'security_group_sids':list(account.security_group_sids)}}
        process = types.SimpleNamespace(returncode=0, communicate=lambda *args, **kwargs:(json.dumps(payload).encode(), b''))
        seen = []
        def popen(*args, **kwargs):
            def communicate(body, **kw): seen.append(json.loads(body)); return json.dumps(payload).encode(), b''
            process.communicate = communicate
            return process
        with patch('kaname.directory_linux.socket.getaddrinfo', return_value=[(2,1,6,'',('192.0.2.10',389))]), patch('kaname.directory_linux.subprocess.Popen', side_effect=popen):
            result = authenticate_linux_user(connection() | {'username':'alice@lab.example'}, config())
        self.assertEqual(account, result)
        self.assertTrue(seen[0]['authenticate_self'])
        self.assertNotIn('object_guid', seen[0])


@unittest.skipUnless(importlib.util.find_spec('ldap'), 'Native LDAP in Linux CI')
class NativeSelfIdentityTests(unittest.TestCase):
    def test_native_authenticated_identity_then_base_tokens(self):
        import ldap
        from ldap.controls.simple import ValueLessRequestControl
        from ldap.controls.libldap import SimplePagedResultsControl
        with LDAPFixture('account-user') as fixture:
            session = ldap.initialize('ldap://127.0.0.1:' + str(fixture.port)); session.simple_bind_s('', '')
            try:
                reader = Reader(session, ldap, (ValueLessRequestControl, SimplePagedResultsControl))
                result = reader.authenticated_user('fixture.invalid','alice')
                self.assertEqual('user', result['kind'])
                self.assertEqual([2,2,0], [x[1] for x in fixture.search_records])
                self.assertEqual([], fixture.errors)
            finally: session.unbind_s()
