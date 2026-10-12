"""Native patch update integrity, preservation, idempotence and rollback."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from tools import radius_module_update as updater


class ModuleUpgradeTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.product = self.root/'installed'
        self.stage = self.root/'stage'
        self.unit = self.root/'radius.service'
        self.unit.write_text('trusted fixture unit')
        self.old = b'\x7fELFold-native-module'
        self.new = b'\x7fELFpatched-native-module'
        for root, data in ((self.product, self.old), (self.stage, self.new)):
            (root/'lib').mkdir(parents=True)
            (root/updater.MODULE).write_bytes(data)
            (root/updater.MODULE).chmod(0o755)
            manifest = {'artifact':'authwire-freeradius-runtime','upstream_commit':updater.COMMIT,
                        'files':{updater.MODULE:{'sha256':hashlib.sha256(data).hexdigest(),'mode':0o755},
                                 'share/unchanged':{'sha256':'0'*64,'mode':0o644}}}
            if root == self.stage:
                manifest['upstream_patches'] = updater.PATCHES
            (root/updater.MANIFEST).write_bytes(json.dumps(manifest).encode())
        self.raw = (self.product/updater.MANIFEST).read_bytes()
        self.digest = hashlib.sha256((self.stage/updater.MANIFEST).read_bytes()).hexdigest()
        self.calls = []
        self.running = True
        for name,value in (('PRODUCT',self.product),('UNIT',self.unit),('BACKUPS',self.root/'backups')):
            patcher = patch.object(updater,name,value)
            patcher.start();self.addCleanup(patcher.stop)
        patcher = patch.object(updater,'protected')
        patcher.start();self.addCleanup(patcher.stop)

    def command(self, *args, **kwargs):
        self.calls.append(args)
        if args[0].endswith('systemctl'):
            self.running = args[1]=='start'
        return subprocess.CompletedProcess(args,0,b'',b'')

    def update(self, command=None):
        with patch.object(updater,'command',side_effect=command or self.command), \
             patch.object(updater,'active',side_effect=lambda:self.running):
            return updater._update(self.stage,self.digest)

    def test_verified_patch_preserves_other_manifest_entries_and_unit(self):
        result = self.update()
        self.assertTrue(result['native_module_updated'])
        self.assertTrue(self.running)
        self.assertEqual(self.new,(self.product/updater.MODULE).read_bytes())
        manifest=json.loads((self.product/updater.MANIFEST).read_bytes())
        self.assertEqual(updater.PATCHES,manifest['upstream_patches'])
        self.assertEqual({'sha256':'0'*64,'mode':0o644},manifest['files']['share/unchanged'])
        self.assertEqual('trusted fixture unit',self.unit.read_text())
        self.assertEqual(self.old,next((self.root/'backups').glob('*/rlm_python3.so')).read_bytes())

    def test_failed_new_start_restores_module_manifest_and_prior_service(self):
        starts=0
        def command(*args,**kwargs):
            nonlocal starts
            if args[1:2]==('start',):
                starts+=1
                if starts==1:
                    raise subprocess.CalledProcessError(1,args)
            return self.command(*args,**kwargs)
        with self.assertRaises(subprocess.CalledProcessError):self.update(command)
        self.assertEqual(self.old,(self.product/updater.MODULE).read_bytes())
        self.assertEqual(self.raw,(self.product/updater.MANIFEST).read_bytes())
        self.assertTrue(self.running)

    def test_tampered_stage_is_rejected_before_service_stop(self):
        (self.stage/updater.MODULE).write_bytes(b'\x7fELFtampered')
        with self.assertRaises(ValueError):self.update()
        self.assertEqual([],self.calls)
        self.assertEqual(self.old,(self.product/updater.MODULE).read_bytes())

    def test_tampered_installed_module_is_rejected(self):
        (self.product/updater.MODULE).write_bytes(b'changed')
        with self.assertRaises(ValueError):self.update()
        self.assertEqual([],self.calls)

    def test_same_patch_is_idempotent_and_inactive_service_stays_inactive(self):
        self.running=False
        first=self.update()
        self.assertFalse(first['service_active'])
        self.assertFalse(self.running)
        calls=list(self.calls)
        second=self.update()
        self.assertTrue(second['already_current'])
        self.assertFalse(second['native_module_updated'])
        self.assertEqual(calls,self.calls)

    def test_stage_symlink_and_unpatched_manifest_are_rejected(self):
        target=self.stage/updater.MODULE
        target.unlink();target.symlink_to(self.product/updater.MODULE)
        with self.assertRaises(ValueError):updater.staged_module(self.stage,self.digest)
        target.unlink();target.write_bytes(self.new)
        raw=json.loads((self.stage/updater.MANIFEST).read_bytes());raw.pop('upstream_patches')
        data=json.dumps(raw).encode();(self.stage/updater.MANIFEST).write_bytes(data)
        with self.assertRaises(ValueError):updater.staged_module(self.stage,hashlib.sha256(data).hexdigest())


class ProtectedLayoutTests(unittest.TestCase):
    def test_writable_file_and_symlink_are_refused(self):
        with tempfile.TemporaryDirectory() as folder:
            path=Path(folder)/'module';path.write_text('fixture');path.chmod(0o666)
            with self.assertRaises(ValueError):updater.protected(path)
            link=Path(folder)/'link';link.symlink_to(path)
            with self.assertRaises(ValueError):updater.protected(link)


if __name__=='__main__':
    unittest.main()
