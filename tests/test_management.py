"""Approved 0.7 behavior, encrypted secrets, sync failures and conflict rollback."""
import copy
import http.client
import itertools
import json
import os
import tempfile
import threading
import unittest
from unittest.mock import patch

from kaname.directory import DirectoryError, validate_search_base
from kaname.models import ValidationError
from kaname.operations import Operations
from kaname.policy import PolicyConflictError, evaluate, policy_conflicts
from kaname.server import DevelopmentServer
from kaname.store import Store, ConflictError
from kaname.vault import Vault, VaultError
from .helpers import config, identity, policy
from .test_directory import catalog, connection
from .test_membership import membership_catalog


def settings(**changes):
    result = {**connection(), 'search_base': '', 'sync_minutes': 15, 'check_minutes': 5, 'automatic_sync': True}
    result.update(changes)
    return result


def network(**changes):
    result = {'vlans': [{'id': 120, 'name': 'Corporate', 'description': ''}],
              'radius_clients': [{'name': 'SW1', 'ip': '192.0.2.2', 'secret': 'RADIUS_SECRET_SENTINEL_42'}],
              'authentication_port': 1812, 'accounting_port': 1813}
    result.update(changes)
    return result


class ConflictTests(unittest.TestCase):
    def test_every_permutation_has_the_same_conflicting_decision(self):
        rows = [policy(id='a'), policy(id='b', vlan=33), policy(id='c', action='deny', vlan=None)]
        for ordering in itertools.permutations(rows):
            self.assertEqual('POLICY_CONFLICT', evaluate(list(ordering), identity()).reason)

    def test_equivalent_rules_coalesce_with_stable_policy_id(self):
        rows = [policy(id='z'), policy(id='a')]
        self.assertEqual(evaluate(rows, identity()), evaluate(rows[::-1], identity()))
        self.assertEqual('a', evaluate(rows, identity()).policy_id)
        self.assertEqual([], policy_conflicts(rows))

    def test_distinct_access_or_nas_does_not_overlap(self):
        left, right = policy(), policy(id='b', vlan=33)
        left['conditions']['access_types'] = ['wired']; right['conditions']['access_types'] = ['wireless']
        self.assertEqual([], policy_conflicts([left, right]))
        left['conditions']['access_types'] = []; right['conditions']['access_types'] = []
        left['conditions']['nas_ips'] = ['192.0.2.2']; right['conditions']['nas_ips'] = ['192.0.2.3']
        self.assertEqual([], policy_conflicts([left, right]))

    def test_catalog_nested_and_primary_overlap_blocks_save(self):
        c = membership_catalog()
        left, right = policy(), policy(id='b', vlan=33)
        left['conditions']['group_sids'] = [c['groups'][0]['sid']]
        right['conditions']['group_sids'] = [c['groups'][-1]['sid']]
        self.assertTrue(policy_conflicts([left, right], c))

    def test_unrelated_groups_allowed_but_future_overlap_denies(self):
        left, right = policy(), policy(id='b', vlan=33)
        right['conditions']['group_sids'] = ['S-1-5-21-1-2-3-2000']
        self.assertEqual([], policy_conflicts([left, right]))
        groups = frozenset(left['conditions']['group_sids'] + right['conditions']['group_sids'])
        self.assertEqual('POLICY_CONFLICT', evaluate([left, right], identity(group_sids=groups)).reason)

    def test_failed_conflict_save_does_not_change_revision_or_audit(self):
        with tempfile.TemporaryDirectory() as root:
            store = Store(root); store.save(0, policies=[policy()])
            before, audit = store.snapshot(), store.audit()
            with self.assertRaises(PolicyConflictError):
                store.save(1, policies=[policy(), policy(id='conflict', vlan=33)])
            self.assertEqual(before, store.snapshot()); self.assertEqual(audit, store.audit())

    def test_legacy_disabled_policy_remains_disabled(self):
        with tempfile.TemporaryDirectory() as root:
            store = Store(root); store.save(0, policies=[policy(enabled=False), policy(id='b', vlan=33)])
            self.assertFalse(Store(root).snapshot()['policies'][0]['enabled'])
            self.assertEqual(33, evaluate(store.snapshot()['policies'], identity()).vlan)


class OperationsTests(unittest.TestCase):
    @unittest.skipUnless(os.name == 'nt', 'Windows protected .NET LDAP scoped wire fixture')
    def test_windows_scoped_groups_include_nested_and_outside_ou_primary_users(self):
        import subprocess
        from pathlib import Path
        from .ldap_fixture import LDAPFixture
        executable = Path(os.environ['SystemRoot']) / 'System32/WindowsPowerShell/v1.0/powershell.exe'
        script = Path(__file__).parents[1] / 'kaname/directory_windows.ps1'
        with LDAPFixture('scoped') as fixture:
            result = subprocess.run([str(executable), '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'Bypass', '-File', str(script), '-SelfTest', '-FixturePort', str(fixture.port), '-ScopedFixture'], capture_output=True, timeout=25)
            value = json.loads(result.stdout.decode('utf-8-sig'))
            self.assertEqual(0, result.returncode, str(value))
            self.assertEqual('scoped-ldap', value['fixture'])
            self.assertEqual({'users': 2, 'groups': 2, 'computers': 0}, value['counts'])
            self.assertTrue(all(fixture.domain_scope_controls))
            self.assertIn(('OU=Network,DC=fixture,DC=invalid', 2), fixture.search_records)
            self.assertIn(('CN=Alice,OU=Users,DC=fixture,DC=invalid', 0), fixture.search_records)
            self.assertEqual([], fixture.errors)

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.store = Store(self.temp.name); self.store.save(0, config=config())
        self.ops = Operations(self.store)

    def test_network_defaults_and_legacy_vlan_preservation(self):
        self.store.save(1, policies=[policy()])
        n = self.ops.network()
        self.assertEqual((1812, 1813), (n['authentication_port'], n['accounting_port']))
        self.assertEqual(120, n['vlans'][0]['id']); self.assertFalse(n['radius_clients'][0]['secret_saved'])

    def test_network_secret_is_encrypted_and_reveal_is_explicit(self):
        self.ops.save_network(1, network())
        self.assertNotIn('RADIUS_SECRET_SENTINEL_42', json.dumps(self.ops.network()))
        self.assertNotIn(b'RADIUS_SECRET_SENTINEL_42', self.store.path.read_bytes())
        self.assertEqual('RADIUS_SECRET_SENTINEL_42', Operations(Store(self.temp.name)).radius_secret('192.0.2.2'))
        self.assertEqual('radius_secret_viewed', self.store.audit()[0]['event'])

    def test_wrong_purpose_or_tampered_cipher_cannot_decrypt(self):
        v = Vault(self.temp.name); encrypted = v.seal('one', 'a private value')
        for purpose, cipher in [('two', encrypted), ('one', encrypted[:-1] + bytes([encrypted[-1] ^ 1]))]:
            with self.assertRaises(VaultError): v.open(purpose, cipher)

    def test_saved_password_survives_restart_without_public_plaintext(self):
        self.ops.save_directory(1, settings())
        self.assertTrue(self.ops.directory()['credentials_saved'])
        self.assertNotIn(connection()['password'], json.dumps(self.ops.directory()))
        self.assertNotIn(connection()['password'].encode(), self.store.path.read_bytes())
        self.assertEqual(connection()['password'], Operations(Store(self.temp.name)).directory_connection()['password'])
        self.assertNotIn(connection()['password'], json.dumps(self.store.audit()))

    def test_blank_password_keeps_saved_password_but_account_change_requires_one(self):
        self.ops.save_directory(1, settings())
        self.ops.save_directory(2, settings(password='', sync_minutes=20))
        self.assertEqual(connection()['password'], self.ops.directory_connection()['password'])
        with self.assertRaises(ValidationError): self.ops.save_directory(3, settings(password='', username='other@lab.example'))
        self.assertEqual(3, self.store.snapshot()['revision'])

    def test_foreign_domain_cannot_reuse_saved_credentials(self):
        self.ops.save_directory(1, settings())
        c = config(); c['ad_domain'] = 'other.example'; self.store.save(2, config=c)
        self.assertFalse(self.ops.directory()['credentials_saved'])
        with self.assertRaises(ValidationError): self.ops.directory_connection()

    def test_network_audit_failure_rolls_back_cipher_and_config(self):
        with self.store.connect() as db:
            db.execute("CREATE TRIGGER block_network BEFORE INSERT ON audit WHEN NEW.event='network_saved' BEGIN SELECT RAISE(ABORT,'fixture'); END")
        import sqlite3
        with self.assertRaises(sqlite3.Error): self.ops.save_network(1, network())
        self.assertEqual(1, self.store.snapshot()['revision'])
        self.assertFalse(self.ops.network()['radius_clients'][0]['secret_saved'])

    def test_in_use_vlan_and_unknown_assignment_are_rejected(self):
        self.ops.save_network(1, network()); self.store.save(2, policies=[policy()])
        with self.assertRaises(ValidationError): self.ops.save_network(3, network(vlans=[]))
        with self.assertRaises(ValidationError): self.store.save(3, policies=[policy(vlan=33)])
        self.assertEqual(3, self.store.snapshot()['revision'])

    def test_ports_are_independently_configurable_and_must_be_distinct(self):
        self.ops.save_network(1, network(authentication_port=2812))
        self.assertEqual(2812, self.ops.network()['authentication_port'])
        self.assertEqual(1813, self.ops.network()['accounting_port'])
        with self.assertRaises(ValidationError): self.ops.save_network(2, network(accounting_port=1812))
        with self.assertRaises(ValidationError): self.ops.save_network(2, network(authentication_port=True))

    def test_source_ip_removal_discards_its_secret(self):
        self.ops.save_network(1, network())
        self.ops.save_network(2, network(radius_clients=[]))
        with self.assertRaises(ValidationError): self.ops.radius_secret('192.0.2.2')

    def test_scope_is_dn_not_injectable_ldap_and_bound_to_domain(self):
        self.assertEqual('', validate_search_base('', 'lab.example'))
        self.assertEqual('OU=Network,DC=lab,DC=example', validate_search_base('ou=Network,dc=lab,dc=example', 'lab.example'))
        self.assertEqual('CN=A\\, B,OU=Network,DC=lab,DC=example', validate_search_base('CN=A\\, B,OU=Network,DC=lab,DC=example', 'lab.example'))
        for value in ['OU=Network,DC=other,DC=example', '(objectClass=*)', 'OU=X,DC=child,DC=lab,DC=example', 'CN=A+OU=B,DC=lab,DC=example', 'OU=A\0,DC=lab,DC=example']:
            with self.subTest(value=value), self.assertRaises(ValidationError): validate_search_base(value, 'lab.example')


class SyncAndHTTPTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.server = DevelopmentServer(self.temp.name, 0); self.server.daemon_threads = False
        self.server.store.save(0, config=config())
        self.server.directory_reader = lambda value, c: catalog()
        self.server.directory_health_reader = lambda value, c: {'probe': 'ok'}
        self.server.operations.save_directory(1, settings())
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True); self.thread.start()
        self.addCleanup(self.close)

    def close(self):
        self.server.shutdown(); self.server.server_close(); self.thread.join()

    def test_bad_credentials_pause_periodic_attempts_across_restart_until_saved(self):
        self.server.directory_sync.stop.set()
        calls = []
        def rejected(value, config):
            calls.append(1)
            raise DirectoryError('AD_CREDENTIALS_REJECTED')
        self.server.directory_health_reader = rejected
        scheduler = self.server.directory_sync
        scheduler.settings_key = tuple(sorted(self.server.operations.directory().items()))
        scheduler.next_sync = float('inf')
        scheduler.next_check = -1
        with self.assertRaises(DirectoryError): scheduler.tick()
        self.assertEqual(1, len(calls))
        for _ in range(5):
            scheduler.next_check = -1; self.server.directory_next_attempt = 0
            scheduler.tick()
        self.assertEqual(1, len(calls))
        self.assertEqual('AD_CREDENTIALS_REJECTED', Operations(Store(self.temp.name)).health()['error'])
        revision = self.server.store.snapshot()['revision']
        self.server.operations.save_directory(revision, settings())
        self.server.directory_health_reader = lambda value, config: calls.append(1) or {'probe': 'ok'}
        scheduler.tick()
        self.assertEqual(2, len(calls))
        self.assertEqual('connected', self.server.operations.health()['state'])

    def call(self, method, path, value=None, token=True):
        h = {'Content-Type': 'application/json', 'Origin': f'http://127.0.0.1:{self.server.server_port}'}
        if token: h['Authorization'] = 'Bearer ' + self.server.token
        c = http.client.HTTPConnection('127.0.0.1', self.server.server_port, timeout=8)
        try:
            c.request(method, path, body=json.dumps(value) if value is not None else None, headers=h)
            response = c.getresponse(); return response.status, json.loads(response.read())
        finally: c.close()

    def test_manual_sync_uses_saved_password_and_scope(self):
        observed = []
        def reader(value, config): observed.append(dict(value)); return catalog()
        self.server.directory_reader = reader
        code, result = self.call('POST', '/api/directory/sync', {'expected_revision': 2})
        self.assertEqual(200, code); self.assertTrue(result['credentials_saved'])
        self.assertEqual(connection()['password'], observed[0]['password'])
        self.assertEqual('', observed[0]['search_base'])
        self.assertEqual('connected', self.call('GET', '/api/state')[1]['directory_health']['state'])

    def test_successful_sync_adds_and_deletes_users(self):
        manager = self.server.directory_sync
        manager.read(2); first = self.server.store.directory_catalog()
        self.server.directory_next_attempt = 0
        c = catalog(); c['users'][0]['name'] = 'New user'; c['users'][0]['guid'] = '00000000-0000-0000-0000-000000000003'; c['users'][0]['sid'] = 'S-1-5-21-1-2-3-1001'
        self.server.directory_reader = lambda *_: c; manager.read(2)
        self.assertNotEqual(first['users'], self.server.store.directory_catalog()['users'])
        self.assertEqual('New user', self.server.store.directory_page('users')['items'][0]['name'])

    def test_failure_preserves_last_good_catalog_and_sets_alert_then_recovers(self):
        manager = self.server.directory_sync; manager.read(2); before = self.server.store.directory_catalog()
        self.server.directory_next_attempt = 0
        def fail(*_): raise DirectoryError('AD_CREDENTIALS_REJECTED')
        self.server.directory_reader = fail
        self.assertEqual(503, self.call('POST', '/api/directory/sync', {'expected_revision': 2})[0])
        self.assertEqual(before, self.server.store.directory_catalog())
        self.assertEqual('AD_CREDENTIALS_REJECTED', self.call('GET', '/api/state')[1]['directory_health']['error'])
        self.server.directory_next_attempt = 0; self.server.directory_reader = lambda *_: catalog(); manager.read(2)
        self.assertEqual('connected', self.server.operations.health()['state'])

    def test_periodic_probe_and_sync_follow_independent_intervals(self):
        manager = self.server.directory_sync
        # Stop the real scheduler; drive deterministic monotonic deadlines.
        manager.close(); manager.tick(100)
        self.assertEqual((1000, 400), (manager.next_sync, manager.next_check))
        with patch.object(manager, 'read') as read:
            manager.tick(399); read.assert_not_called()
            manager.tick(400); read.assert_called_once_with(2, probe=True)
            read.reset_mock(); manager.tick(1000); read.assert_called_once_with(2, probe=False)

    def test_filter_or_credentials_change_during_read_does_not_replace_catalog(self):
        def change(value, config):
            self.server.operations.save_directory(2, settings(search_base='OU=Other,DC=lab,DC=example'))
            return catalog()
        self.server.directory_reader = change
        self.assertEqual(409, self.call('POST', '/api/directory/sync', {'expected_revision': 2})[0])
        self.assertFalse(self.server.store.directory_status()['catalog_available'])
        self.assertEqual('pending', self.server.operations.health()['state'])

    def test_invalid_partial_read_preserves_snapshot(self):
        self.server.directory_sync.read(2); before = self.server.store.directory_catalog()
        self.server.directory_next_attempt = 0
        self.server.directory_reader = lambda *_: {'users': []}
        self.assertEqual(503, self.call('POST', '/api/directory/sync', {'expected_revision': 2})[0])
        self.assertEqual(before, self.server.store.directory_catalog())
        self.assertEqual('AD_INVALID_RESPONSE', self.server.operations.health()['error'])

    def test_conflict_http_contains_names_and_does_not_save(self):
        self.server.store.save(2, policies=[policy()]); before = self.server.store.snapshot()
        code, value = self.call('POST', '/api/policies', {'expected_revision': 3, 'policies': [policy(), policy(id='b', name='Other', vlan=33)]})
        self.assertEqual(409, code); self.assertEqual('POLICY_CONFLICT', value['error'])
        self.assertEqual(['Corporate', 'Other'], value['conflicts'][0]['policy_names'])
        self.assertEqual(before, self.server.store.snapshot())

    def test_new_endpoints_require_authentication(self):
        for path in ['/api/network', '/api/directory/settings', '/api/policies/groups']:
            self.assertEqual(401, self.call('GET', path, token=False)[0])
        for path in ['/api/network/secret/reveal', '/api/network/secret/generate', '/api/network/vlans', '/api/directory/settings']:
            self.assertEqual(401, self.call('POST', path, {}, token=False)[0])
