import importlib.util
import io
import json
import os
import subprocess
import tempfile
import types
import unittest
import uuid
from pathlib import Path
from unittest.mock import patch

from kaname.directory import DirectoryError
from kaname.directory_linux import read_linux_directory
from kaname.directory_linux_helper import Reader, protected_connection, sid_from_bytes
from .helpers import config
from .test_directory import catalog, connection
from .ldap_fixture import LDAPFixture, sid


class LinuxProtectionTests(unittest.TestCase):
    def test_binary_sid_checks_length_revision_and_endianness(self):
        self.assertEqual('S-1-5-21-1-2-3-500', sid_from_bytes(sid(21, 1, 2, 3, 500)))
        for value in (b'', b'\x02\x00' + b'\x00' * 6, sid(21, 1)[:-1], sid(21, 1) + b'x'):
            with self.assertRaises(DirectoryError): sid_from_bytes(value)

    def protected_fixture(self, strength):
        options, calls = {}, []
        session = types.SimpleNamespace(set_option=lambda key, value: options.update({key: value}),
                    sasl_interactive_bind_s=lambda who, auth: calls.append((who, auth)),
                    get_option=lambda key: strength, unbind_s=lambda: calls.append('unbind'))
        names = ('OPT_PROTOCOL_VERSION', 'OPT_REFERRALS', 'OPT_NETWORK_TIMEOUT', 'OPT_TIMEOUT',
                 'OPT_X_SASL_NOCANON', 'OPT_X_SASL_SECPROPS', 'OPT_X_SASL_SSF')
        ldap = types.SimpleNamespace(**{name: name for name in names}, initialize=lambda url: session)
        return ldap, session, options, calls

    def test_authentication_requires_sealing_and_has_no_simple_bind_path(self):
        ldap, session, options, calls = self.protected_fixture(256)
        sasl = types.SimpleNamespace(gssapi=lambda: 'fixture-gssapi')
        self.assertIs(session, protected_connection(ldap, sasl, 'dc01.lab.example'))
        self.assertEqual([('', 'fixture-gssapi')], calls)
        self.assertEqual('minssf=56,maxssf=256,noplain,noanonymous', options['OPT_X_SASL_SECPROPS'])
        self.assertEqual(0, options['OPT_REFERRALS'])
        for strength in (0, 1, 55):
            ldap, _, _, calls = self.protected_fixture(strength)
            with self.assertRaises(DirectoryError) as caught:
                protected_connection(ldap, sasl, 'dc01.lab.example')
            self.assertEqual('AD_PROTECTION_REQUIRED', caught.exception.code)
            self.assertIn('unbind', calls)

    @unittest.skipUnless(os.name == 'posix', 'POSIX subprocess isolation')
    def test_dns_allowlist_checked_before_authentication(self):
        with patch('kaname.directory_linux.socket.getaddrinfo', return_value=[(0, 0, 0, '', ('192.0.2.99', 389))]), patch('kaname.directory_linux.subprocess.Popen') as popen:
            with self.assertRaises(DirectoryError) as caught: read_linux_directory(connection(), config())
            self.assertEqual('AD_DC_IP_MISMATCH', caught.exception.code)
            popen.assert_not_called()

    @unittest.skipUnless(os.name == 'posix', 'POSIX subprocess isolation')
    def test_password_only_in_stdin_and_ticket_directory_removed(self):
        seen = {}
        def communicate(data, timeout):
            request = json.loads(data)
            directory = Path(request['cache_dir'])
            seen.update(directory=directory, request=request)
            self.assertEqual(0, directory.stat().st_mode & 0o077)
            (directory / 'ticket').write_text('fixture-ticket')
            return json.dumps(catalog()).encode(), None
        process = types.SimpleNamespace(communicate=communicate, returncode=0)
        with patch('kaname.directory_linux.socket.getaddrinfo', return_value=[(0, 0, 0, '', ('192.0.2.10', 389))]), patch('kaname.directory_linux.subprocess.Popen', return_value=process) as popen:
            self.assertEqual(catalog(), read_linux_directory(connection(), config()))
        self.assertFalse(seen['directory'].exists())
        args, kwargs = popen.call_args
        self.assertNotIn(connection()['password'], str(args) + str(kwargs))
        self.assertTrue(kwargs['start_new_session'])

    @unittest.skipUnless(os.name == 'posix', 'POSIX subprocess isolation')
    def test_helper_timeout_kills_process_group_and_cleans_ticket_directory(self):
        seen = {}
        def first(data, timeout):
            seen['directory'] = Path(json.loads(data)['cache_dir'])
            (seen['directory'] / 'ticket').write_text('fixture-only')
            raise subprocess.TimeoutExpired('helper', timeout)
        process = types.SimpleNamespace(pid=999999)
        calls = 0
        def communicate(data=None, timeout=None):
            nonlocal calls
            calls += 1
            if calls == 1: return first(data, timeout)
            return b'', None
        process.communicate = communicate
        with patch('kaname.directory_linux.socket.getaddrinfo', return_value=[(0, 0, 0, '', ('192.0.2.10', 389))]), patch('kaname.directory_linux.subprocess.Popen', return_value=process), patch('kaname.directory_linux.os.killpg') as kill:
            with self.assertRaises(DirectoryError) as caught: read_linux_directory(connection(), config())
            self.assertEqual('AD_TIMEOUT', caught.exception.code)
            self.assertEqual(999999, kill.call_args.args[0])
        self.assertFalse(seen['directory'].exists())

    def test_multi_ou_unicode_request_is_not_truncated_at_old_stdin_limit(self):
        from kaname.directory_linux_helper import main
        scope = '\n'.join('OU=' + ('Ş' * 1800) + str(i) + ',DC=lab,DC=example' for i in range(16))
        request = connection() | {'search_base': scope}
        payload = json.dumps(request, ensure_ascii=True).encode()
        self.assertGreater(len(payload), 32768)
        with patch('kaname.directory_linux_helper.sys.stdin', types.SimpleNamespace(buffer=io.BytesIO(payload))), patch('kaname.directory_linux_helper.sys.stdout', io.StringIO()), patch('kaname.directory_linux_helper.run', return_value={'probe': 'ok'}) as run:
            self.assertEqual(0, main())
            self.assertEqual(scope, run.call_args.args[0]['search_base'])
        with patch('kaname.directory_linux_helper.sys.stdin', types.SimpleNamespace(buffer=io.BytesIO(b' ' * 262145))), patch('kaname.directory_linux_helper.sys.stdout', new_callable=io.StringIO) as output, patch('kaname.directory_linux_helper.run') as run:
            self.assertEqual(1, main())
            self.assertEqual('AD_INPUT_INVALID', json.loads(output.getvalue())['error'])
            run.assert_not_called()


@unittest.skipUnless(importlib.util.find_spec('ldap'), 'Native python-ldap installed in Linux adapter CI')
class NativeLinuxLDAPTests(unittest.TestCase):
    def test_native_sasl_security_option_api_without_network(self):
        import ldap
        native = ldap.initialize('ldap://dc01.example.invalid:389')
        native.set_option(ldap.OPT_X_SASL_NOCANON, 1)
        native.set_option(ldap.OPT_X_SASL_SECPROPS, 'minssf=56,maxssf=256,noplain,noanonymous')
        self.assertTrue(native.get_option(ldap.OPT_X_SASL_NOCANON))
        native.set_option(ldap.OPT_X_SASL_NOCANON, 0)
        self.assertFalse(native.get_option(ldap.OPT_X_SASL_NOCANON))
        self.assertGreaterEqual(native.get_option(ldap.OPT_X_SASL_SSF_MIN), 56)

    def fixture_reader(self, mode):
        import ldap
        from ldap.controls.simple import ValueLessRequestControl
        from ldap.controls.libldap import SimplePagedResultsControl
        fixture = LDAPFixture(mode); fixture.__enter__(); self.addCleanup(fixture.__exit__, None, None, None)
        native = ldap.initialize('ldap://127.0.0.1:' + str(fixture.port))
        native.set_option(ldap.OPT_REFERRALS, 0)
        native.set_option(ldap.OPT_NETWORK_TIMEOUT, 3)
        # Anonymous binding is confined to this local parser fixture. Runtime
        # protected_connection never exposes this fixture authentication mode.
        native.simple_bind_s('', '')
        self.addCleanup(native.unbind_s)
        return Reader(native, ldap, (ValueLessRequestControl, SimplePagedResultsControl)), fixture

    def test_native_paged_catalog_binary_ids_and_critical_domain_scope(self):
        reader, fixture = self.fixture_reader('ad-referrals')
        value = reader.catalog('fixture.invalid', 'dc01.fixture.invalid')
        self.assertEqual((2, 1, 1), tuple(len(value[x]) for x in ('users', 'groups', 'computers')))
        self.assertFalse(value['users'][0]['enabled'])
        self.assertTrue(all(fixture.domain_scope_controls))
        self.assertEqual(1, value['groups'][0]['unresolved_members'])
        self.assertEqual(2, len(value['memberships']))

    def test_repeated_missing_cookies_and_referrals_are_rejected(self):
        for mode in ('repeat', 'missing', 'referral'):
            with self.subTest(mode=mode):
                reader, _ = self.fixture_reader(mode)
                with self.assertRaises(DirectoryError): reader.catalog('fixture.invalid', 'dc01.fixture.invalid')

    def test_native_range_memberships_and_corrupt_ranges(self):
        for mode in ('range-normal', 'range-large', 'range-missing', 'range-repeat', 'range-duplicate'):
            with self.subTest(mode=mode):
                reader, fixture = self.fixture_reader(mode)
                if mode in ('range-normal', 'range-large'):
                    value = reader.catalog('fixture.invalid', 'dc01.fixture.invalid')
                    self.assertEqual(2, len(value['memberships']))
                else:
                    with self.assertRaises(DirectoryError): reader.catalog('fixture.invalid', 'dc01.fixture.invalid')
                self.assertTrue(all(fixture.domain_scope_controls))

    def test_native_scoped_catalog_excludes_outside_nested_and_primary_members(self):
        reader, fixture = self.fixture_reader('ou-scoped')
        value = reader.catalog('fixture.invalid', 'dc01.fixture.invalid', 'OU=Network,DC=fixture,DC=invalid')
        self.assertEqual((1, 1, 1), tuple(len(value[x]) for x in ('users', 'groups', 'computers')))
        self.assertEqual(1, len(value['memberships']))
        self.assertEqual(2, value['groups'][0]['unresolved_members'])
        self.assertTrue(all(fixture.domain_scope_controls))
        self.assertEqual({'OU=Network,DC=fixture,DC=invalid'}, {base for base, _ in fixture.search_records})

    def test_native_multiple_ous_include_union_and_resolve_names(self):
        reader, fixture = self.fixture_reader('ou-scoped')
        value = reader.catalog('fixture.invalid', 'dc01.fixture.invalid', 'Network\nOU=Other')
        self.assertEqual((1, 2, 1), tuple(len(value[x]) for x in ('users', 'groups', 'computers')))
        self.assertEqual(2, len(value['memberships']))
        self.assertEqual(1, value['groups'][0]['unresolved_members'])
        self.assertNotIn(('CN=Alice,OU=Users,DC=fixture,DC=invalid', 0), fixture.search_records)
        self.assertTrue(all(fixture.domain_scope_controls))

    def test_native_missing_ambiguous_and_partial_scopes_fail_closed(self):
        for scope, code in [('Missing', 'AD_SCOPE_NOT_FOUND'), ('Ambiguous', 'AD_SCOPE_AMBIGUOUS'),
                            ('OU=Missing', 'AD_SCOPE_NOT_FOUND'), ('Network\nMissing', 'AD_SCOPE_NOT_FOUND')]:
            with self.subTest(scope=scope):
                reader, fixture = self.fixture_reader('ou-scoped')
                with self.assertRaises(DirectoryError) as caught:
                    reader.catalog('fixture.invalid', 'dc01.fixture.invalid', scope)
                self.assertEqual(code, caught.exception.code)
                self.assertNotIn(('CN=Alice,OU=Users,DC=fixture,DC=invalid', 0), fixture.search_records)

    def test_native_overlapping_scopes_are_read_once_and_root_is_explicit(self):
        reader, fixture = self.fixture_reader('ou-scoped')
        value = reader.catalog('fixture.invalid', 'dc01.fixture.invalid', 'Network\nOU=Network,DC=fixture,DC=invalid')
        self.assertEqual(1, len(value['users']))
        self.assertEqual(3, sum(scope == 2 and base.startswith('OU=Network,') for base, scope in fixture.search_records))
        reader, fixture = self.fixture_reader('ou-scoped')
        value = reader.catalog('fixture.invalid', 'dc01.fixture.invalid', 'Network\nDC=fixture,DC=invalid')
        self.assertEqual(3, len(value['users']))
        self.assertIn('primary', {edge['type'] for edge in value['memberships']})
