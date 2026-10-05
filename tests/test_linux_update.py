import os
import tempfile
import unittest
import json
from unittest.mock import patch
from pathlib import Path

from tools.linux_update import safe_tree, quarantine_caches, health


class RebrandHealthTests(unittest.TestCase):
    def checked(self, product, version='fixture-version'):
        with patch('tools.linux_update.ssl.create_default_context'), patch('tools.linux_update.http.client.HTTPSConnection') as connect:
            response = connect.return_value.getresponse.return_value
            response.status = 200
            response.read.return_value = json.dumps({'product': product, 'version': version}).encode()
            return health('127.0.0.1', 'fixture-version')

    def test_old_and_new_identity_allow_upgrade_and_rollback(self):
        for name in ('KANAME', 'AuthWire'):
            with self.subTest(name=name): self.assertTrue(self.checked(name))

    def test_rebrand_does_not_accept_another_product_or_wrong_version(self):
        self.assertFalse(self.checked('Another'))
        self.assertFalse(self.checked('AuthWire', 'wrong-version'))


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
