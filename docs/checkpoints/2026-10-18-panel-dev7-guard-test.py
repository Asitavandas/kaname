"""Disposable files with simulated UID metadata; no customer state is accessed."""
import os
from pathlib import Path
import runpy
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

SCRIPT = Path(__file__).with_name('2026-10-18-panel-dev7-fix.py')

class OwnershipGuards(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name); self.state = self.root / 'state'; self.state.mkdir()
        self.key = self.state / 'secret-store.key'; self.radius = self.state / 'radius/server.pem'
        self.radius.parent.mkdir(); self.code = self.root / 'code.py'; self.uid = 999
        self.ns = runpy.run_path(str(SCRIPT), run_name='guard_test')
        self.read = self.ns['preserved_file']; self.read.__globals__.update(
            STATE=self.state, APPLICATION_DATA={self.key, self.radius, self.state / 'radius/server-key.pem'})
        self.account = patch('pwd.getpwnam', return_value=SimpleNamespace(pw_uid=self.uid))
        self.account.start(); self.addCleanup(self.account.stop)
        self.owners = {}; original = Path.lstat
        def simulated_owner(path, *args, **kwargs):
            actual = original(path, *args, **kwargs); values = list(actual)
            values[4] = self.owners.get(path, actual.st_uid)
            return os.stat_result(values)
        self.metadata = patch.object(Path, 'lstat', simulated_owner)
        self.metadata.start(); self.addCleanup(self.metadata.stop)

    def write(self, path, uid, mode=0o600):
        path.write_bytes(b'non-secret-disposable-fixture'); self.owners[path] = uid; path.chmod(mode)

    def test_service_owned_private_vault_is_accepted_without_chown(self):
        self.write(self.key, self.uid); before = self.key.stat()
        self.assertEqual(self.read(self.key), b'non-secret-disposable-fixture')
        self.assertEqual(self.key.stat().st_uid, before.st_uid)
        self.assertEqual(self.key.stat().st_mode, before.st_mode)

    def test_root_owned_or_unrelated_owner_vault_is_refused(self):
        for uid in (0, self.uid + 1):
            self.write(self.key, uid)
            with self.assertRaises(self.ns['GuardError']): self.read(self.key)

    def test_group_readable_application_private_key_is_refused(self):
        self.write(self.key, self.uid, 0o640)
        with self.assertRaises(self.ns['GuardError']): self.read(self.key)

    def test_application_data_symlink_is_refused(self):
        self.write(self.radius, self.uid); self.key.symlink_to(self.radius)
        with self.assertRaises(self.ns['GuardError']): self.read(self.key)

    def test_root_and_service_owned_private_radius_are_accepted(self):
        for uid in (0, self.uid):
            self.write(self.radius, uid); self.assertTrue(self.read(self.radius))
        self.write(self.radius, self.uid + 1)
        with self.assertRaises(self.ns['GuardError']): self.read(self.radius)

    def test_code_still_requires_root_and_no_group_write(self):
        self.write(self.code, self.uid, 0o644)
        with self.assertRaises(ValueError): self.read(self.code)
        self.write(self.code, 0, 0o664)
        with self.assertRaises(ValueError): self.read(self.code)
        self.write(self.code, 0, 0o644); self.assertTrue(self.read(self.code))

if __name__ == '__main__': unittest.main(verbosity=2)
