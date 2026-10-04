import os
import tempfile
import unittest
from pathlib import Path

from tools.linux_update import safe_tree, quarantine_caches


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
