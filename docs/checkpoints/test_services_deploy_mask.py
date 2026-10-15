"""Permission boundary regression for the operator's guarded deployment checkpoint.

Run as: python3 test_services_deploy_mask.py /path/to/deployment-checkpoint.py
No production paths, subprocesses or service actions are used.
"""
import ast
import os
from pathlib import Path
import runpy
import stat
import sys
import tempfile
import unittest

CHECKPOINT=Path(sys.argv.pop(1)) if len(sys.argv)>1 else Path(__file__).with_name('2026-10-15-services-deploy.py')
NAMESPACE=runpy.run_path(str(CHECKPOINT))
MASK=NAMESPACE['file_creation_mask']

class DeploymentMaskTests(unittest.TestCase):
    def setUp(self):
        self.previous=os.umask(0o027)
        self.temp=tempfile.TemporaryDirectory(prefix='authwire-mask-regression-')
        self.root=Path(self.temp.name)
    def tearDown(self):
        os.umask(self.previous)
        self.temp.cleanup()
    def test_backup_stays_private_and_restores_mask(self):
        with MASK(0o077):
            os.umask(0o077)  # Same global side effect as the real backup helper.
            target=self.root/'backup.tar.gz';target.write_bytes(b'fixture')
        self.assertEqual(stat.S_IMODE(target.stat().st_mode),0o600)
        self.assertEqual(os.umask(0o027),0o027)
    def test_source_readable_despite_restrictive_caller(self):
        os.umask(0o077)
        legacy=self.root/'legacy';legacy.mkdir(mode=0o755)
        self.assertEqual(stat.S_IMODE(legacy.stat().st_mode),0o700)
        with MASK(0o022):
            package=self.root/'kaname';package.mkdir(mode=0o755)
            target=package/'services.py';target.write_text('VALUE=1\n');target.chmod(0o644)
        self.assertEqual(stat.S_IMODE(package.stat().st_mode),0o755)
        self.assertEqual(stat.S_IMODE(target.stat().st_mode),0o644)
        self.assertEqual(os.umask(0o027),0o077)
    def test_exception_restores_original_mask(self):
        with self.assertRaisesRegex(RuntimeError,'controlled'):
            with MASK(0o077):
                os.umask(0o077)
                raise RuntimeError('controlled')
        self.assertEqual(os.umask(0o027),0o027)
    def test_backup_updater_and_installer_calls_are_scoped(self):
        tree=ast.parse(CHECKPOINT.read_text())
        scopes={}
        for node in ast.walk(tree):
            if isinstance(node,ast.With) and isinstance(node.items[0].context_expr,ast.Call):
                call=node.items[0].context_expr
                if isinstance(call.func,ast.Name) and call.func.id=='file_creation_mask':
                    scopes[call.args[0].value]=scopes.get(call.args[0].value,[])+[ast.unparse(node)]
        self.assertTrue(any("backup['main']()" in s for s in scopes[0o077]))
        self.assertTrue(any("updater['update'](STAGE, EXPECTED)" in s for s in scopes[0o022]))
        self.assertTrue(any('service_control_install.py' in s for s in scopes[0o022]))

if __name__=='__main__':unittest.main()
