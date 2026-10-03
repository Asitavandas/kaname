import copy
import http.client
import json
import os
import subprocess
import tempfile
import threading
import unittest
from pathlib import Path
from unittest.mock import patch

from kaname.directory import DirectoryError, decode_helper_response, read_windows_directory, validate_catalog, validate_connection
from kaname.models import ValidationError
from kaname.server import DevelopmentServer
from kaname.store import Store, ConflictError
from .helpers import config
from .ldap_fixture import LDAPFixture


def catalog():
    return {'domain': 'lab.example', 'dc_fqdn': 'dc01.lab.example', 'transport': 'kerberos-sign-seal',
            'users': [{'guid': '00000000-0000-0000-0000-000000000001', 'sid': 'S-1-5-21-1-2-3-1000', 'sam': 'alice', 'name': 'Alice', 'enabled': False}],
            'groups': [{'guid': '00000000-0000-0000-0000-000000000002', 'sid': 'S-1-5-21-1-2-3-1100', 'sam': 'Access', 'name': '<script>alert(1)</script>'}],
            'computers': []}


def connection():
    return {'dc_fqdn': 'dc01.lab.example', 'username': 'administrator@lab.example', 'password': 'SECRET_CREDENTIAL_SENTINEL'}


class DirectoryModelTests(unittest.TestCase):
    def test_connection_domain_and_upn(self):
        self.assertEqual('lab.example', validate_connection(connection(), config())['domain'])

    def test_helper_failure_returns_only_known_stage_and_reason(self):
        value = {'error': 'AD_SEARCH_FAILED', 'stage': 'groups_decode', 'reason': 'VALUE_CONVERSION', 'message': connection()['password']}
        with self.assertRaises(DirectoryError) as caught:
            decode_helper_response(json.dumps(value).encode(), 1, 'lab.example', 'dc01.lab.example')
        self.assertEqual({'stage': 'groups_decode', 'reason': 'VALUE_CONVERSION'}, caught.exception.diagnostic)
        self.assertNotIn(connection()['password'], str(caught.exception))
        for stage, reason in [('private-DN', 'secret-message'), ({'secret': 1}, ['secret'])]:
            value.update(stage=stage, reason=reason)
            with self.assertRaises(DirectoryError) as caught:
                decode_helper_response(json.dumps(value).encode(), 1, 'lab.example', 'dc01.lab.example')
            self.assertIsNone(caught.exception.diagnostic)

    def test_helper_success_and_invalid_output_are_separated(self):
        self.assertEqual(catalog(), decode_helper_response(json.dumps(catalog()).encode(), 0, 'lab.example', 'dc01.lab.example'))
        for output in [b'private exception text', b'null', b'{}']:
            with self.assertRaises(DirectoryError) as caught:
                decode_helper_response(output, 1, 'lab.example', 'dc01.lab.example')
            self.assertIn(caught.exception.code, {'AD_INVALID_RESPONSE', 'AD_SEARCH_FAILED'})
            self.assertIsNone(caught.exception.diagnostic)

    def test_foreign_host_rejected(self):
        c = connection(); c['dc_fqdn'] = 'dc01.attacker.example'
        with self.assertRaises(ValidationError): validate_connection(c, config())

    def test_ip_host_rejected(self):
        c = connection(); c['dc_fqdn'] = '192.0.2.10'
        with self.assertRaises(ValidationError): validate_connection(c, config())

    def test_foreign_upn_rejected(self):
        c = connection(); c['username'] = 'admin@foreign.example'
        with self.assertRaises(ValidationError): validate_connection(c, config())

    def test_null_password_and_extra_fields_rejected(self):
        for extra in [{'password': '\0'}, {'port': 389}, {'allow_insecure': True}]:
            with self.assertRaises(ValidationError): validate_connection({**connection(), **extra}, config())

    def test_unprotected_catalog_rejected(self):
        c = catalog(); c['transport'] = 'plain-ldap'
        with self.assertRaises(ValidationError): validate_catalog(c)

    def test_catalog_secrets_rejected(self):
        c = catalog(); c['password'] = 'secret'
        with self.assertRaises(ValidationError): validate_catalog(c)

    def test_duplicate_identity_rejected(self):
        c = catalog(); c['groups'].append(copy.deepcopy(c['groups'][0]))
        with self.assertRaises(ValidationError): validate_catalog(c)

    def test_group_builtin_sid_supported(self):
        c = catalog(); c['groups'][0]['sid'] = 'S-1-5-32-544'
        self.assertEqual('S-1-5-32-544', validate_catalog(c)['groups'][0]['sid'])

    def test_wrong_server_and_domain_response_rejected(self):
        with self.assertRaises(ValidationError): validate_catalog(catalog(), 'wrong.example')
        with self.assertRaises(ValidationError): validate_catalog(catalog(), dc_fqdn='dc02.lab.example')

    def test_disabled_flag_must_be_boolean(self):
        c = catalog(); c['users'][0]['enabled'] = 'false'
        with self.assertRaises(ValidationError): validate_catalog(c)

    @unittest.skipIf(os.name == 'nt', 'Linux-only fail-closed platform check')
    def test_linux_backend_does_not_fall_back_to_plain_ldap(self):
        with self.assertRaises(DirectoryError) as exc: read_windows_directory(connection(), config())
        self.assertEqual('AD_PLATFORM_UNSUPPORTED', exc.exception.code)

    @unittest.skipUnless(os.name == 'nt', 'Windows .NET adapter self test')
    def test_windows_helper_constructs_protected_ldap_without_network(self):
        executable = Path(os.environ['SystemRoot']) / 'System32/WindowsPowerShell/v1.0/powershell.exe'
        script = Path(__file__).parents[1] / 'kaname/directory_windows.ps1'
        result = subprocess.run([str(executable), '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', str(script), '-SelfTest'], capture_output=True, timeout=15)
        self.assertEqual(0, result.returncode, 'Windows adapter self-test failed (no AD network call)')
        self.assertEqual({'self_test': 'passed', 'transport': 'kerberos-sign-seal', 'network_called': False}, json.loads(result.stdout.decode('utf-8-sig')))

    def run_ldap_fixture(self, mode):
        executable = Path(os.environ['SystemRoot']) / 'System32/WindowsPowerShell/v1.0/powershell.exe'
        script = Path(__file__).parents[1] / 'kaname/directory_windows.ps1'
        with LDAPFixture(mode) as fixture:
            result = subprocess.run([str(executable), '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', str(script), '-SelfTest', '-FixturePort', str(fixture.port)], capture_output=True, timeout=25)
            value = json.loads(result.stdout.decode('utf-8-sig'))
            self.assertEqual([], fixture.errors)
            if fixture.searches:
                self.assertTrue(all(fixture.domain_scope_controls), 'Every LDAP page must carry a critical domain-scope control')
            return result.returncode, value

    @unittest.skipUnless(os.name == 'nt', 'Windows .NET LDAP wire fixture')
    def test_windows_ldap_query_decoding_and_paging_on_loopback(self):
        code, value = self.run_ldap_fixture('ad-referrals')
        self.assertEqual(0, code, str(value))
        self.assertEqual({'self_test': 'passed', 'fixture': 'paged-ldap', 'external_network_called': False, 'counts': {'users': 2, 'groups': 1, 'computers': 1}}, value)

    @unittest.skipUnless(os.name == 'nt', 'Windows .NET LDAP wire fixture')
    def test_windows_ldap_repeated_cookie_is_rejected(self):
        code, value = self.run_ldap_fixture('repeat')
        self.assertEqual(1, code)
        self.assertEqual('users_page', value['stage'])

    @unittest.skipUnless(os.name == 'nt', 'Windows .NET LDAP wire fixture')
    def test_windows_ldap_missing_page_control_is_rejected(self):
        code, value = self.run_ldap_fixture('missing')
        self.assertEqual(1, code)
        self.assertEqual('users_page', value['stage'])

    @unittest.skipUnless(os.name == 'nt', 'Windows .NET LDAP wire fixture')
    def test_windows_ldap_search_referral_is_rejected(self):
        code, value = self.run_ldap_fixture('referral')
        self.assertEqual(1, code)
        self.assertEqual('users_search', value['stage'])
        self.assertEqual('REFERRAL_RETURNED', value['reason'])


class DirectoryStoreTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.store = Store(self.temp.name)
        self.store.save(0, config=config())

    def test_sync_preserves_config_revision_and_emits_audit(self):
        before = self.store.snapshot()
        status = self.store.save_directory(1, catalog())
        self.assertEqual(before, self.store.snapshot())
        self.assertTrue(status['catalog_available'])
        self.assertFalse(status['runtime_auth_ready'])
        self.assertEqual('directory_synced', self.store.audit()[0]['event'])
        self.assertFalse(self.store.directory_page('users')['items'][0]['enabled'])

    def test_conflict_preserves_existing_catalog(self):
        self.store.save_directory(1, catalog())
        before = self.store.directory_catalog()
        with self.assertRaises(ConflictError): self.store.save_directory(0, catalog())
        self.assertEqual(before, self.store.directory_catalog())

    def test_domain_change_hides_old_catalog(self):
        self.store.save_directory(1, catalog())
        c = config(); c['ad_domain'] = 'new.example'
        self.store.save(1, config=c)
        self.assertFalse(self.store.directory_status()['catalog_available'])
        self.assertEqual([], self.store.directory_page('groups')['items'])

    def test_pagination_and_case_insensitive_search(self):
        self.store.save_directory(1, catalog())
        self.assertEqual(1, self.store.directory_page('users', query='ALICE')['total'])
        self.assertEqual([], self.store.directory_page('users', offset=1)['items'])
        with self.assertRaises(ValueError): self.store.directory_page('users', offset=-1)

    def test_unknown_fields_never_persist(self):
        c = catalog(); c['users'][0]['password'] = connection()['password']
        with self.assertRaises(ValidationError): self.store.save_directory(1, c)
        self.assertFalse(self.store.directory_status()['catalog_available'])
        self.assertNotIn(connection()['password'].encode(), self.store.path.read_bytes())

    def test_audit_failure_rolls_back_catalog(self):
        with self.store.connect() as db:
            db.execute("CREATE TRIGGER deny_directory_audit BEFORE INSERT ON audit WHEN NEW.event='directory_synced' BEGIN SELECT RAISE(ABORT,'reject'); END")
        import sqlite3
        with self.assertRaises(sqlite3.Error): self.store.save_directory(1, catalog())
        self.assertFalse(self.store.directory_status()['catalog_available'])


class DirectoryHTTPTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.server = DevelopmentServer(self.temp.name, port=0)
        self.server.store.save(0, config=config())
        self.server.directory_reader = lambda value, config: catalog()
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True); self.thread.start()
        self.addCleanup(self.close)

    def close(self):
        self.server.shutdown(); self.server.server_close(); self.thread.join()

    def call(self, method, path, value=None, authenticated=True, origin=True):
        headers = {'Content-Type': 'application/json'}
        if authenticated: headers['Authorization'] = 'Bearer ' + self.server.token
        if origin: headers['Origin'] = f'http://127.0.0.1:{self.server.server_port}'
        client = http.client.HTTPConnection('127.0.0.1', self.server.server_port, timeout=5)
        try:
            client.request(method, path, body=json.dumps(value) if value is not None else None, headers=headers)
            response = client.getresponse(); return response.status, json.loads(response.read())
        finally:
            client.close()

    def sync(self):
        return self.call('POST', '/api/directory/sync', {'expected_revision': 1, 'connection': connection()})

    def test_sync_and_catalog_are_authenticated(self):
        self.assertEqual(401, self.call('POST', '/api/directory/sync', {}, authenticated=False)[0])
        self.assertEqual(401, self.call('GET', '/api/directory/catalog', authenticated=False)[0])
        self.assertEqual(403, self.call('POST', '/api/directory/sync', {}, origin=False)[0])

    def test_success_preserves_state_and_never_stores_credentials(self):
        status, result = self.sync()
        self.assertEqual(200, status)
        self.assertFalse(result['credentials_saved']); self.assertFalse(result['network_enforced'])
        self.assertEqual(1, self.server.store.snapshot()['revision'])
        self.assertNotIn(connection()['password'].encode(), self.server.store.path.read_bytes())
        self.assertEqual(1, self.call('GET', '/api/directory/catalog?kind=groups')[1]['total'])
        self.assertFalse(self.call('GET', '/api/state')[1]['runtime_ready'])

    def test_failed_read_preserves_catalog(self):
        self.sync(); before = self.server.store.directory_catalog()
        self.server.directory_next_attempt = 0
        def fail(*_): raise DirectoryError('AD_CREDENTIALS_REJECTED')
        self.server.directory_reader = fail
        status, result = self.sync()
        self.assertEqual(503, status); self.assertEqual('AD_CREDENTIALS_REJECTED', result['error'])
        self.assertEqual(before, self.server.store.directory_catalog())

    def test_query_diagnostic_does_not_disclose_credentials_or_catalog(self):
        def fail(*_): raise DirectoryError('AD_SEARCH_FAILED', 'groups_decode', 'VALUE_CONVERSION')
        self.server.directory_reader = fail
        status, result = self.sync()
        self.assertEqual(503, status)
        self.assertEqual({'error': 'AD_SEARCH_FAILED', 'diagnostic': {'stage': 'groups_decode', 'reason': 'VALUE_CONVERSION'}}, result)
        self.assertNotIn(connection()['password'], json.dumps(result))
        self.assertFalse(self.server.store.directory_status()['catalog_available'])

    def test_concurrent_and_repeated_bind_are_limited(self):
        self.server.directory_lock.acquire()
        self.assertEqual(429, self.sync()[0]); self.server.directory_lock.release()
        self.assertEqual(200, self.sync()[0]); self.assertEqual(429, self.sync()[0])

    def test_catalog_query_rejects_unbounded_or_unknown_parameters(self):
        for query in ['offset=-1', 'kind=keys', 'q=a&q=b', 'secret=x']:
            self.assertEqual(400, self.call('GET', '/api/directory/catalog?' + query)[0])

    def test_changed_config_during_read_prevents_import(self):
        def change(value, current):
            c = config(); c['ad_domain'] = 'new.example'
            self.server.store.save(1, config=c)
            return catalog()
        self.server.directory_reader = change
        self.assertEqual(409, self.sync()[0])
        self.assertFalse(self.server.store.directory_status()['catalog_available'])
