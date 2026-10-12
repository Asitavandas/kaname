"""Panel/RADIUS lifecycle dependency migration, preservation and rollback."""
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from tools import radius_unit_update as updater
from tools.radius_install import unit_text


class UnitMigrationTests(unittest.TestCase):
    def old_unit(self):
        return unit_text('192.0.2.20').replace('Wants=network-online.target kaname-lab.service\n',
             'Wants=network-online.target\nRequires=kaname-lab.service\n')

    def test_only_stop_dependency_changes_and_startup_order_remains(self):
        old = self.old_unit()
        new, changed = updater.migrate_unit(old)
        self.assertTrue(changed)
        self.assertEqual(old.replace('Requires=kaname-lab.service\n', 'Wants=kaname-lab.service\n'), new)
        self.assertIn('After=network-online.target kaname-lab.service\n', new)
        self.assertEqual(old.split('[Service]\n')[1], new.split('[Service]\n')[1])
        self.assertEqual((new, False), updater.migrate_unit(new))

    def test_new_installer_unit_is_already_independent(self):
        new = unit_text('192.0.2.20')
        self.assertNotIn('Requires=kaname-lab.service', new)
        self.assertEqual((new, False), updater.migrate_unit(new))

    def test_additional_stop_dependency_and_ambiguous_unit_are_refused(self):
        old = self.old_unit()
        for value in (old.replace('Requires=kaname-lab.service', 'Requires=kaname-lab.service other.service'),
                      old.replace('[Unit]\n', '[Unit]\nPartOf=other.service\n'),
                      old.replace('[Unit]\n', '[Unit]\nBindsTo=other.service\n'),
                      old.replace('After=network-online.target kaname-lab.service', 'After=other.service'),
                      old + '[Unit]\n'):
            with self.subTest(value=value[:60]), self.assertRaises(ValueError):
                updater.migrate_unit(value)


class UnitUpdateTests(unittest.TestCase):
    old_unit = UnitMigrationTests.old_unit
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.unit = self.root/'authwire-radius.service'
        self.unit.write_text(self.old_unit())
        self.unit.chmod(0o644)
        self.calls = []
        self.running = True
        for name, value in (('UNIT', self.unit), ('BACKUPS', self.root/'backups')):
            p = patch.object(updater, name, value);p.start();self.addCleanup(p.stop)
        p = patch.object(updater, 'protected');p.start();self.addCleanup(p.stop)

    def command(self, *args):
        self.calls.append(args)
        if '--property=MainPID' in args:
            return subprocess.CompletedProcess(args, 0, b'1234\n')
        if args[:2] == ('systemctl', 'start'):
            self.running = True
        return subprocess.CompletedProcess(args, 0, b'')

    def update(self, start=False, command=None):
        with patch.object(updater, 'command', side_effect=command or self.command), \
             patch.object(updater, 'active', side_effect=lambda: self.running):
            return updater._update(start)

    def test_active_service_stays_on_same_pid_without_stop_or_restart(self):
        before = self.unit.read_text()
        result = self.update()
        self.assertTrue(result['running_process_preserved'])
        self.assertFalse(result['radius_started'])
        self.assertEqual(before, next((self.root/'backups').glob('*.service')).read_text())
        self.assertFalse(any(call[:2] in (('systemctl', 'stop'), ('systemctl', 'restart'),
                                         ('systemctl', 'start')) for call in self.calls))

    def test_inactive_service_remains_inactive_unless_explicitly_restored(self):
        self.running = False
        result = self.update()
        self.assertFalse(result['service_active'])
        result = self.update(start=True)
        self.assertTrue(result['service_active'])
        self.assertTrue(result['radius_started'])

    def test_reload_failure_rolls_unit_back_without_touching_authentication(self):
        original = self.unit.read_bytes()
        failed = False
        def command(*args):
            nonlocal failed
            if args == ('systemctl', 'daemon-reload') and not failed:
                failed = True
                raise subprocess.CalledProcessError(1, args)
            return self.command(*args)
        with self.assertRaises(subprocess.CalledProcessError): self.update(command=command)
        self.assertEqual(original, self.unit.read_bytes())
        self.assertTrue(self.running)

    def test_unit_overrides_are_rejected_before_any_change(self):
        before = self.unit.read_bytes()
        with patch.object(updater, 'command', return_value=subprocess.CompletedProcess([], 0, b'/fixture/override.conf')):
            with self.assertRaises(ValueError): updater._update()
        self.assertEqual(before, self.unit.read_bytes())
        self.assertFalse((self.root/'backups').exists())

    def test_effective_stop_dependency_after_reload_rolls_back(self):
        original = self.unit.read_bytes()
        def command(*args):
            if '--property=Requires,BindsTo,PartOf' in args:
                return subprocess.CompletedProcess(args, 0, b'kaname-lab.service')
            return self.command(*args)
        with self.assertRaises(ValueError): self.update(command=command)
        self.assertEqual(original, self.unit.read_bytes())


if __name__ == '__main__':
    unittest.main()
