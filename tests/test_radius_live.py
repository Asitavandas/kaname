"""Live AD/registry boundary tests; no customer AD or endpoint enrollment."""
import importlib.util
import json
import os
import tempfile
import types
import unittest
import uuid
from datetime import datetime, timedelta, timezone
from unittest.mock import patch

from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.x509.oid import ExtendedKeyUsageOID, NameOID

from kaname.directory import DirectoryError
from kaname.directory_linux import decode_account_response, lookup_linux_account
from kaname.directory_linux_helper import Reader
from kaname.operations import Operations
from kaname.radius import (CertificateBinding, CertificateReference, CurrentDirectoryAccount,
                          DirectoryUnavailable, TLSAuthorization)
from kaname.radius_directory import LiveDirectory
from kaname.radius_registry import CertificateRegistry
from kaname.store import Store
from .helpers import config, policy
from .ldap_fixture import LDAPFixture, sid
from .test_directory import connection

DOMAIN = 'lab.example'
GUID = str(uuid.UUID(int=1001))
SID = 'S-1-5-21-1-2-3-1001'
GROUP = 'S-1-5-21-1-2-3-1100'
PRIMARY = 'S-1-5-21-1-2-3-513'


def live_account(**changes):
    value = dict(domain=DOMAIN, object_guid=GUID, sid=SID, kind='computer', enabled=True,
                 security_group_sids=frozenset({PRIMARY, GROUP}))
    return CurrentDirectoryAccount(**(value | changes))


def attributes(**changes):
    value = {'objectguid': [uuid.UUID(GUID).bytes_le], 'objectsid': [sid(21, 1, 2, 3, 1001)],
             'objectclass': [b'top', b'user', b'computer'], 'useraccountcontrol': [b'4096'],
             'msds-user-account-control-computed': [b'0'], 'accountexpires': [b'0'],
             'primarygroupid': [b'513'], 'tokengroups': [sid(21, 1, 2, 3, 513), sid(21, 1, 2, 3, 1100)]}
    return value | changes


class LiveAccountParserTests(unittest.TestCase):
    def reader(self, attrs=None, *, rows=1):
        ldap = types.SimpleNamespace(SCOPE_BASE=0, SCOPE_SUBTREE=2)
        reader = Reader(None, ldap, None)
        dn = 'CN=Client,DC=lab,DC=example'
        calls = []
        def search(base, scope, filter_value, requested):
            calls.append((base, scope, filter_value, requested))
            return [(dn, attrs or attributes())] * rows, []
        reader.search = search
        return reader, calls

    def test_guid_filter_is_binary_escaped_and_tokens_are_base_read(self):
        reader, calls = self.reader()
        row = reader.account(DOMAIN, GUID)
        self.assertEqual(sorted([GROUP, PRIMARY]), row['security_group_sids'])
        self.assertEqual([2, 0], [x[1] for x in calls])
        escaped = ''.join('\\' + format(x, '02x') for x in uuid.UUID(GUID).bytes_le)
        self.assertIn('(objectGUID=' + escaped + ')', calls[0][2])
        self.assertNotIn('tokenGroups', calls[0][3])
        self.assertIn('tokenGroups', calls[1][3])

    def test_deleted_duplicate_changed_guid_or_foreign_dn_are_rejected(self):
        reader, _ = self.reader(rows=0)
        self.assertIsNone(reader.account(DOMAIN, GUID))
        reader, _ = self.reader(rows=2)
        with self.assertRaises(DirectoryError): reader.account(DOMAIN, GUID)
        reader, _ = self.reader(attributes(objectguid=[uuid.UUID(int=1002).bytes_le]))
        with self.assertRaises(DirectoryError): reader.account(DOMAIN, GUID)
        reader, _ = self.reader()
        reader.search = lambda *args: ([('CN=Client,DC=other,DC=example', attributes())], [])
        with self.assertRaises(DirectoryError): reader.account(DOMAIN, GUID)

    def test_disabled_locked_and_expired_accounts_have_no_access(self):
        for change in ({'useraccountcontrol': [b'4098']}, {'msds-user-account-control-computed': [b'16']},
                       {'accountexpires': [b'1']}):
            reader, _ = self.reader(attributes(**change))
            self.assertFalse(reader.account(DOMAIN, GUID)['enabled'])
        for expires in (b'0', b'9223372036854775807'):
            reader, _ = self.reader(attributes(accountexpires=[expires]))
            self.assertTrue(reader.account(DOMAIN, GUID)['enabled'])

    def test_missing_partial_duplicate_oversized_and_bad_binary_tokens_reject(self):
        cases = [attributes(tokengroups=[]), attributes(tokengroups=[b'bad']),
                 attributes(tokengroups=[sid(21, 1, 2, 3, 513)] * 2),
                 attributes(tokengroups=[sid(21, 1, 2, 3, x) for x in range(257)]),
                 attributes(tokengroups=[sid(21, 1, 2, 3, 1100)]),
                 attributes(**{'tokengroups;range=0-1': [sid(21, 1, 2, 3, 513)]})]
        missing = attributes(); del missing['tokengroups']; cases.append(missing)
        for row in cases:
            with self.subTest(row=row):
                reader, _ = self.reader(row)
                with self.assertRaises(DirectoryError): reader.account(DOMAIN, GUID)

    def test_account_classes_flags_and_required_fields_are_strict(self):
        for changes in ({'objectclass': [b'group']}, {'useraccountcontrol': [b'2048']},
                        {'useraccountcontrol': [b'0']}, {'accountexpires': [b'-1']},
                        {'msds-user-account-control-computed': []}, {'primarygroupid': [b'x']}):
            reader, _ = self.reader(attributes(**changes))
            with self.assertRaises(DirectoryError): reader.account(DOMAIN, GUID)

    def test_helper_response_enforces_guid_domain_and_no_duplicate_groups(self):
        row = dict(domain=DOMAIN, object_guid=GUID, sid=SID, kind='computer', enabled=True,
                   security_group_sids=[PRIMARY, GROUP])
        request = {'domain': DOMAIN, 'dc_fqdn': 'dc01.lab.example'}
        payload = request | {'account': row}
        self.assertEqual(live_account(), decode_account_response(json.dumps(payload).encode(), 0, request, GUID))
        self.assertIsNone(decode_account_response(json.dumps(request | {'account': None}).encode(), 0, request, GUID))
        for bad in (payload | {'domain': 'other.example'}, payload | {'account': row | {'object_guid': str(uuid.UUID(int=1002))}},
                    payload | {'account': row | {'security_group_sids': [PRIMARY, PRIMARY]}}):
            with self.assertRaises(DirectoryError): decode_account_response(json.dumps(bad).encode(), 0, request, GUID)
        with self.assertRaises(DirectoryError) as error:
            decode_account_response(b'{"error":"AD_CREDENTIALS_REJECTED"}', 1, request, GUID)
        self.assertEqual('AD_CREDENTIALS_REJECTED', error.exception.code)


class LiveProviderTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.store = Store(self.temp.name); self.store.save(0, config=config())
        self.operations = Operations(self.store)
        self.operations.save_directory(1, connection() | {'search_base': '', 'sync_minutes': 15, 'check_minutes': 5, 'automatic_sync': False})

    def test_fresh_lookup_observes_removed_groups_and_never_calls_catalog(self):
        rows = [live_account(), live_account(security_group_sids=frozenset({PRIMARY})), None]
        passwords = []
        def reader(credentials, config_value, guid):
            passwords.append(credentials['password'])
            return rows.pop(0)
        service = LiveDirectory(self.operations, reader=reader)
        with patch.object(self.store, 'directory_catalog', side_effect=AssertionError('No display fallback')):
            self.assertIn(GROUP, service.lookup(DOMAIN, GUID).security_group_sids)
            self.assertNotIn(GROUP, service.lookup(DOMAIN, GUID).security_group_sids)
            self.assertIsNone(service.lookup(DOMAIN, GUID))
        self.assertEqual(3, len(passwords))

    def test_busy_wrong_domain_bad_result_and_concurrent_config_fail_closed(self):
        def changing(*args):
            current = self.store.snapshot()
            self.store.save(current['revision'], config=current['config'])
            return live_account()
        for reader in (lambda *args: {'enabled': True}, changing):
            with self.assertRaises(DirectoryUnavailable): LiveDirectory(self.operations, reader=reader).lookup(DOMAIN, GUID)
        reader = lambda *args: self.fail('Must not authenticate')
        service = LiveDirectory(self.operations, reader=reader)
        with self.assertRaises(DirectoryUnavailable): service.lookup('other.example', GUID)
        service.lock.acquire()
        with self.assertRaises(DirectoryUnavailable): service.lookup(DOMAIN, GUID)
        service.lock.release()

    def test_credential_rejection_pause_survives_new_provider_and_save_clears(self):
        calls = []
        def rejected(*args):
            calls.append(1); raise DirectoryError('AD_CREDENTIALS_REJECTED')
        for _ in range(2):
            with self.assertRaises(DirectoryUnavailable): LiveDirectory(self.operations, reader=rejected).lookup(DOMAIN, GUID)
        self.assertEqual(1, len(calls))
        self.assertEqual('AD_CREDENTIALS_REJECTED', self.operations.health()['error'])
        self.operations.save_directory(self.store.snapshot()['revision'], connection() | {'search_base': '', 'sync_minutes': 15, 'check_minutes': 5, 'automatic_sync': False})
        self.assertEqual(live_account(), LiveDirectory(self.operations, reader=lambda *args: live_account()).lookup(DOMAIN, GUID))

    def test_timeout_rejects_and_credentials_are_cleared(self):
        seen = []
        def failing(credentials, *_):
            seen.append(credentials); raise DirectoryError('AD_TIMEOUT')
        service = LiveDirectory(self.operations, reader=failing)
        for _ in range(2):
            with self.assertRaises(DirectoryUnavailable): service.lookup(DOMAIN, GUID)
        self.assertEqual(1, len(seen))
        self.assertEqual('', seen[0]['password'])

    def test_local_diagnostic_outputs_only_summary_and_uses_live_reader(self):
        from tools.linux_authorization_check import check
        from .test_directory import catalog
        self.store.save_directory(self.store.snapshot()['revision'], catalog())
        seen = []
        def reader(credentials, config_value, guid):
            seen.append(guid)
            return live_account(object_guid=guid)
        result = check(self.operations, reader)
        self.assertTrue(result['checked'])
        self.assertEqual(2, result['security_group_count'])
        self.assertFalse(result['panel_updated'])
        self.assertFalse(result['catalog_used_for_authorization'])
        encoded = json.dumps(result)
        for private in (connection()['password'], connection()['username'], seen[0], SID, GROUP):
            self.assertNotIn(private, encoded)

    @unittest.skipUnless(os.name == 'posix', 'POSIX helper')
    def test_actual_wrapper_uses_guid_mode_and_existing_private_kerberos_boundary(self):
        payload = {'domain': DOMAIN, 'dc_fqdn': 'dc01.lab.example', 'account': {
            'domain': DOMAIN, 'object_guid': GUID, 'sid': SID, 'kind': 'computer', 'enabled': True,
            'security_group_sids': [PRIMARY, GROUP]}}
        seen = []
        def communicate(data, timeout):
            seen.append(json.loads(data)); return json.dumps(payload).encode(), None
        process = types.SimpleNamespace(communicate=communicate, returncode=0)
        with patch('kaname.directory_linux.socket.getaddrinfo', return_value=[(0, 0, 0, '', ('192.0.2.10', 389))]), patch('kaname.directory_linux.subprocess.Popen', return_value=process):
            self.assertEqual(live_account(), lookup_linux_account(connection(), config(), GUID))
        self.assertEqual(GUID, seen[0]['object_guid'])


class PersistentBindingTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.key = rsa.generate_private_key(65537, 2048)
        subject = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, 'Fixture issuer')])
        now = datetime.now(timezone.utc)
        cls.issuer = (x509.CertificateBuilder().subject_name(subject).issuer_name(subject)
                      .public_key(cls.key.public_key()).serial_number(100)
                      .not_valid_before(now - timedelta(days=1)).not_valid_after(now + timedelta(days=10))
                      .add_extension(x509.BasicConstraints(True, 0), True).sign(cls.key, hashes.SHA256()))
        cls.reference = CertificateReference(cls.issuer.fingerprint(hashes.SHA256()).hex(), '12ab')
        cls.cert = (x509.CertificateBuilder().subject_name(subject).issuer_name(subject)
                    .public_key(cls.key.public_key()).serial_number(int('12ab', 16))
                    .not_valid_before(now - timedelta(days=1)).not_valid_after(now + timedelta(days=1))
                    .add_extension(x509.BasicConstraints(False, None), True)
                    .add_extension(x509.ExtendedKeyUsage([ExtendedKeyUsageOID.CLIENT_AUTH]), False)
                    .add_extension(x509.KeyUsage(True, False, True, False, False, False, False, False, False), True)
                    .sign(cls.key, hashes.SHA256()))

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.store = Store(self.temp.name)
        with self.store.connect() as db:
            db.executescript('''CREATE TABLE pki_authority(id INTEGER PRIMARY KEY,issuer_cert BLOB);
                CREATE TABLE pki_certificates(serial TEXT PRIMARY KEY,certificate BLOB,revoked_at TEXT);
                CREATE TABLE radius_certificate_bindings(issuer_sha256 TEXT,serial TEXT,domain TEXT,object_guid TEXT,
                sid TEXT,kind TEXT,active INTEGER,PRIMARY KEY(issuer_sha256,serial));''')
            db.execute('INSERT INTO pki_authority VALUES (1,?)', (self.issuer.public_bytes(serialization.Encoding.PEM),))
            db.execute('INSERT INTO pki_certificates VALUES (?,?,NULL)', (self.reference.serial, self.cert.public_bytes(serialization.Encoding.PEM)))
            db.execute('INSERT INTO radius_certificate_bindings VALUES (?,?,?,?,?,?,?)',
                       (self.reference.issuer_sha256, self.reference.serial, DOMAIN, GUID, SID, 'computer', 1))

    def test_binding_survives_restart_and_is_verified_before_live_policy(self):
        for _ in range(2):
            registry = CertificateRegistry(Store(self.temp.name))
            binding = registry.lookup(self.reference)
            self.assertEqual(CertificateBinding(self.reference, DOMAIN, GUID, SID, 'computer'), binding)
            p = policy(conditions={'group_sids': [GROUP], 'access_types': ['wired'], 'nas_ips': ['127.0.0.1']})
            directory = types.SimpleNamespace(lookup=lambda *args: live_account())
            self.assertEqual('allow', TLSAuthorization([p], registry=registry, directory=directory).authorize(
                self.reference, nas_ip='127.0.0.1', access_type='wired').action)

    def test_revoked_unbound_foreign_issuer_and_corrupt_certificate_reject(self):
        registry = CertificateRegistry(self.store)
        self.assertIsNone(registry.lookup(CertificateReference('a' * 64, self.reference.serial)))
        self.assertIsNone(registry.lookup(CertificateReference(self.reference.issuer_sha256, '12ac')))
        with self.store.connect() as db: db.execute("UPDATE pki_certificates SET revoked_at='fixture'")
        self.assertIsNone(registry.lookup(self.reference))
        with self.store.connect() as db: db.execute("UPDATE pki_certificates SET revoked_at=NULL,certificate=?", (b'corrupt',))
        self.assertIsNone(registry.lookup(self.reference))

    def test_inactive_or_absent_registry_never_allows(self):
        with self.store.connect() as db: db.execute('UPDATE radius_certificate_bindings SET active=0')
        b = CertificateRegistry(self.store).lookup(self.reference)
        self.assertFalse(b.active)
        with self.store.connect() as db: db.execute('DROP TABLE radius_certificate_bindings')
        self.assertIsNone(CertificateRegistry(self.store).lookup(self.reference))

    def test_revocation_during_live_ad_query_cannot_accept_old_binding(self):
        p = policy(conditions={'group_sids': [GROUP], 'access_types': ['wired'], 'nas_ips': ['127.0.0.1']})
        def lookup(*args):
            with self.store.connect() as db: db.execute("UPDATE pki_certificates SET revoked_at='fixture'")
            return live_account()
        service = TLSAuthorization([p], registry=CertificateRegistry(self.store),
                                   directory=types.SimpleNamespace(lookup=lookup))
        result = service.authorize(self.reference, nas_ip='127.0.0.1', access_type='wired')
        self.assertEqual('deny', result.action)
        self.assertEqual('CERTIFICATE_BINDING_CHANGED', result.reason)


@unittest.skipUnless(importlib.util.find_spec('ldap'), 'Native LDAP Linux CI')
class NativeLiveAccountTests(unittest.TestCase):
    def test_native_guid_and_base_tokengroups_queries_observe_changes(self):
        import ldap
        from ldap.controls.simple import ValueLessRequestControl
        from ldap.controls.libldap import SimplePagedResultsControl
        with LDAPFixture('account-valid') as fixture:
            session = ldap.initialize('ldap://127.0.0.1:' + str(fixture.port))
            session.set_option(ldap.OPT_REFERRALS, 0)
            session.simple_bind_s('', '')  # Anonymous only in loopback test.
            try:
                reader = Reader(session, ldap, (ValueLessRequestControl, SimplePagedResultsControl))
                self.assertIn(GROUP, reader.account('fixture.invalid', GUID)['security_group_sids'])
                fixture.mode = 'account-group-removed'
                self.assertNotIn(GROUP, reader.account('fixture.invalid', GUID)['security_group_sids'])
                fixture.mode = 'account-disabled'
                self.assertFalse(reader.account('fixture.invalid', GUID)['enabled'])
                fixture.mode = 'account-incomplete'
                with self.assertRaises(DirectoryError): reader.account('fixture.invalid', GUID)
                fixture.mode = 'account-deleted'
                self.assertIsNone(reader.account('fixture.invalid', GUID))
                self.assertTrue(all(fixture.domain_scope_controls))
                self.assertEqual([2, 0] * 4 + [2], [x[1] for x in fixture.search_records])
                self.assertEqual([], fixture.errors)
            finally: session.unbind_s()
