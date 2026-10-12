import os
import tempfile
import unittest
import json
from unittest.mock import patch
from pathlib import Path

from tools.linux_update import safe_tree, quarantine_caches, health, radius_unit_upgrade, radius_process_guard


class RebrandHealthTests(unittest.TestCase):
    def checked(self, product, version='fixture-version', client_sha256='fixture-client'):
        with patch('tools.linux_update.ssl.create_default_context'), patch('tools.linux_update.http.client.HTTPSConnection') as connect:
            response = connect.return_value.getresponse.return_value
            response.status = 200
            response.read.return_value = json.dumps({'product': product, 'version': version,
                'device_client_sha256': client_sha256}).encode()
            return health('127.0.0.1', 'fixture-version', 'fixture-client')

    def test_old_and_new_identity_allow_upgrade_and_rollback(self):
        for name in ('KANAME', 'AuthWire'):
            with self.subTest(name=name): self.assertTrue(self.checked(name))

    def test_rebrand_does_not_accept_another_product_or_wrong_version(self):
        self.assertFalse(self.checked('Another'))
        self.assertFalse(self.checked('AuthWire', 'wrong-version'))
        self.assertFalse(self.checked('AuthWire', client_sha256='stale-client'))


@unittest.skipUnless(os.name=='posix','POSIX source permissions')
class SourceUpgradeGuardTests(unittest.TestCase):
    def test_writable_code_cannot_use_bytecode_exception(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d)/'source';root.mkdir(mode=0o755)
            code=root/'server.py';code.write_text('trusted source');code.chmod(0o666)
            with self.assertRaises(ValueError):safe_tree(root,owner=os.getuid(),quarantine_bytecode=True)

    def test_legacy_cache_is_detached_without_following_its_contents(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d)/'source';root.mkdir(mode=0o755)
            code=root/'server.py';code.write_text('trusted source');code.chmod(0o644)
            cache=root/'__pycache__';cache.mkdir();cache.chmod(0o777)
            target=Path(d)/'outside.txt';target.write_text('outside fixture')
            (cache/'untrusted.pyc').symlink_to(target)
            safe_tree(root,owner=os.getuid(),quarantine_bytecode=True)
            backup=Path(d)/'backup'
            self.assertEqual(1,quarantine_caches(root,backup,owner=os.getuid()))
            self.assertFalse(cache.exists())
            self.assertEqual('trusted source',code.read_text())
            self.assertTrue((backup/'bytecode/__pycache__/untrusted.pyc').is_symlink())
            self.assertEqual('outside fixture',target.read_text())
            safe_tree(root,owner=os.getuid())

    def test_cache_directory_symlink_is_rejected(self):
        with tempfile.TemporaryDirectory() as d:
            root=Path(d)/'source';root.mkdir(mode=0o755)
            elsewhere=Path(d)/'elsewhere';elsewhere.mkdir()
            (root/'__pycache__').symlink_to(elsewhere,target_is_directory=True)
            with self.assertRaises(ValueError):safe_tree(root,owner=os.getuid(),quarantine_bytecode=True)


class RadiusUnitMigrationTests(unittest.TestCase):
    def test_legacy_execstart_gets_explicit_dictionary_directory(self):
        old = 'ExecStart=/opt/authwire-radius/sbin/radiusd -f -d /run/authwire-radius\n'
        updated, changed = radius_unit_upgrade('[Service]\n' + old)
        self.assertTrue(changed)
        self.assertIn(' -D /opt/authwire-radius/share/freeradius -d /run/authwire-radius', updated)

    def test_current_execstart_is_idempotent_and_unknown_layout_is_rejected(self):
        current = ('[Service]\nExecStart=/opt/authwire-radius/sbin/radiusd -f '
                   '-D /opt/authwire-radius/share/freeradius -d /run/authwire-radius\n')
        updated, changed = radius_unit_upgrade(current)
        self.assertFalse(changed)
        self.assertEqual(current, updated)
        with self.assertRaises(ValueError):
            radius_unit_upgrade('[Service]\nExecStart=/custom/radiusd\n')


class RadiusStopPropagationGuardTests(unittest.TestCase):
    def test_effective_requires_bindsto_and_partof_refuse_active_panel_update(self):
        import subprocess
        for field in ('Requires', 'BindsTo', 'PartOf'):
            with self.subTest(field=field), \
                 patch('tools.linux_update.subprocess.run', return_value=subprocess.CompletedProcess([], 0)), \
                 patch('tools.linux_update.command', return_value=subprocess.CompletedProcess([], 0, b'kaname-lab.service\n')) as command:
                with self.assertRaisesRegex(ValueError, 'stop dependency'):
                    radius_process_guard()
                self.assertEqual(1, command.call_count)
                self.assertIn('--property=Requires,BindsTo,PartOf', command.call_args.args)

    def test_wants_after_does_not_block_running_radius(self):
        import subprocess
        with patch('tools.linux_update.subprocess.run', return_value=subprocess.CompletedProcess([], 0)), \
             patch('tools.linux_update.command', side_effect=[
                 subprocess.CompletedProcess([], 0, b'system.slice sysinit.target\n'),
                 subprocess.CompletedProcess([], 0, b'1234\n')]):
            self.assertEqual('1234', radius_process_guard())

    def test_inactive_or_absent_radius_is_not_started(self):
        import subprocess
        for code in (3, 4):
            with self.subTest(code=code), \
                 patch('tools.linux_update.subprocess.run', return_value=subprocess.CompletedProcess([], code)), \
                 patch('tools.linux_update.command') as command:
                self.assertIsNone(radius_process_guard())
                command.assert_not_called()

    def test_unknown_service_status_or_invalid_active_pid_refuses_update(self):
        import subprocess
        with patch('tools.linux_update.subprocess.run', return_value=subprocess.CompletedProcess([], 1)):
            with self.assertRaises(ValueError): radius_process_guard()
        for pid in (b'0\n', b'unknown\n'):
            with patch('tools.linux_update.subprocess.run', return_value=subprocess.CompletedProcess([], 0)), \
                 patch('tools.linux_update.command', side_effect=[subprocess.CompletedProcess([], 0, b''),
                     subprocess.CompletedProcess([], 0, pid)]):
                with self.assertRaises(ValueError): radius_process_guard()
