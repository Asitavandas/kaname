"""Production RADIUS adapter/runtime boundaries; no LAN listener is started."""
import os
import subprocess
import tempfile
import types
import unittest
from pathlib import Path
from unittest.mock import patch

from kaname.operations import Operations
from kaname.policy import Decision
from kaname.radius_adapter import client_context, decision_for_pairs, scalar
from kaname.store import Store
from kaname.pki import PKIService
from tools.radius_initialize import initialize
from tools.radius_runtime import generate
from tools.radius_prepare import prepare
from tools.radius_install import verified_runtime, unit_text
from .helpers import config, policy


PASSWORD = b'authwire-radius-fixture-password'


def network(access_type='wired'):
    return {
        'vlans': [{'id': 120, 'name': 'Corporate', 'description': ''}],
        'radius_clients': [{
            'name': 'SW1', 'ip': '192.0.2.2', 'access_type': access_type,
            'secret': 'RADIUS_SECRET_SENTINEL_42'
        }],
        'authentication_port': 1812,
        'accounting_port': 1813,
    }


class AdapterTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.store = Store(self.temp.name)
        self.store.save(0, config=config())
        self.store.save(self.store.snapshot()['revision'], policies=[policy()])
        self.ops = Operations(self.store)
        self.ops.save_network(self.store.snapshot()['revision'], network('wireless'))
        PKIService(self.temp.name).initialize(PASSWORD)

    def test_scalar_and_source_registration_are_strict(self):
        self.assertEqual('abc', scalar([('X', '"abc"')], 'X'))
        for pairs in ([], [('X', 'a'), ('X', 'b')], [('X', 'bad\\value')]):
            with self.assertRaises(ValueError):
                scalar(pairs, 'X')
        self.assertEqual('wireless', client_context(self.ops, '192.0.2.2'))
        with self.assertRaises(ValueError):
            client_context(self.ops, '192.0.2.99')

    def test_packet_source_not_claimed_nas_ip_drives_policy_context(self):
        observed = {}
        class Authorization:
            def __init__(self, policies, **kwargs):
                self.policies = policies
            def authorize(self, reference, *, nas_ip, access_type):
                observed['nas_ip'] = nas_ip
                observed['access_type'] = access_type
                observed['serial'] = reference.serial
                return Decision('deny', 'FIXTURE')

        pairs = [
            ('Packet-Src-IP-Address', '192.0.2.2'),
            ('NAS-IP-Address', '203.0.113.77'),
            ('TLS-Client-Cert-Serial', '12ab'),
        ]
        with patch('kaname.radius_adapter.TLSAuthorization', Authorization):
            result = decision_for_pairs(
                pairs, state=Path(self.temp.name),
                directory_factory=lambda operations: types.SimpleNamespace())
        self.assertEqual('deny', result.action)
        self.assertEqual('192.0.2.2', observed['nas_ip'])
        self.assertEqual('wireless', observed['access_type'])
        self.assertEqual('12ab', observed['serial'])


@unittest.skipUnless(os.name == 'posix', 'POSIX runtime permissions and openssl')
class RuntimeTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.state = self.root / 'state'
        self.store = Store(self.state)
        self.store.save(0, config=config())
        self.store.save(self.store.snapshot()['revision'], policies=[policy()])
        self.ops = Operations(self.store)
        self.ops.save_network(self.store.snapshot()['revision'], network())
        PKIService(self.state).initialize(PASSWORD)
        self.radius = initialize(self.state, PASSWORD, 30)

        self.prefix = self.root / 'prefix'
        (self.prefix / 'share/freeradius').mkdir(parents=True)
        (self.prefix / 'share/freeradius/dictionary').write_text('# fixture\n')
        (self.prefix / 'sbin').mkdir()
        (self.prefix / 'sbin/radiusd').write_text('fixture\n')
        (self.prefix / 'sbin/radiusd').chmod(0o755)
        (self.prefix / 'lib').mkdir()
        (self.prefix / 'lib/rlm_python3.so').write_bytes(b'fixture')

        self.runtime = self.root / 'runtime'
        self.runtime.mkdir(mode=0o700)

    def test_server_key_is_private_and_overwrite_is_refused(self):
        key = self.state / 'radius/server-key.pem'
        self.assertEqual(0, key.stat().st_mode & 0o077)
        self.assertTrue(self.radius['serial'])
        with self.assertRaises(ValueError):
            initialize(self.state, PASSWORD, 30)

    def test_staged_runtime_manifest_and_unit_bind_are_deterministic(self):
        staged = self.root / 'staged'
        result = prepare(self.prefix, staged)
        files, raw = verified_runtime(staged, result['runtime_digest'])
        self.assertIn('sbin/radiusd', files)
        self.assertTrue(raw)
        unit = unit_text('192.0.2.20')
        self.assertIn('--listen-ip 192.0.2.20', unit)
        self.assertNotIn('--listen-ip 0.0.0.0', unit)
        (staged / 'sbin/radiusd').write_bytes(b'tampered')
        with self.assertRaises(ValueError):
            verified_runtime(staged, result['runtime_digest'])

    def test_runtime_contains_secret_only_ephemerally_and_materializes_packet_source(self):
        before = list(self.store.audit())
        result = generate(self.runtime, self.prefix, self.state)
        self.assertEqual(1812, result['authentication_port'])
        self.assertFalse(result['accounting_enabled'])
        clients = (self.runtime / 'clients.conf').read_text()
        self.assertIn('RADIUS_SECRET_SENTINEL_42', clients)
        self.assertNotIn(b'RADIUS_SECRET_SENTINEL_42', self.store.path.read_bytes())
        self.assertEqual(before, self.store.audit())
        site = (self.runtime / 'sites-enabled/authwire').read_text()
        self.assertIn('Packet-Src-IP-Address := "%{Packet-Src-IP-Address}"', site)
        module = (self.runtime / 'mods-enabled/python3').read_text()
        self.assertIn('module = kaname.radius_adapter', module)
        self.assertEqual(0, (self.runtime / 'clients.conf').stat().st_mode & 0o077)

    def test_native_freeradius_accepts_generated_production_config_when_prefix_is_supplied(self):
        prefix = os.environ.get('AUTHWIRE_RADIUS_PREFIX')
        if not prefix:
            self.skipTest('Pinned FreeRADIUS prefix not supplied')
        runtime = self.root / 'native-runtime'
        runtime.mkdir(mode=0o700)
        generate(runtime, Path(prefix), self.state)
        env = dict(os.environ)
        env['LD_LIBRARY_PATH'] = str(Path(prefix) / 'lib')
        result = subprocess.run(
            [str(Path(prefix) / 'sbin/radiusd'), '-XC', '-d', str(runtime)],
            env=env, capture_output=True, text=True, timeout=20)
        if result.returncode != 0:
            safe = '\n'.join(line for line in (result.stdout + result.stderr).splitlines()
                             if 'secret' not in line.lower() and 'password' not in line.lower())
            self.fail('Generated production FreeRADIUS config rejected:\n' + safe[-4000:])


if __name__ == '__main__':
    unittest.main()
