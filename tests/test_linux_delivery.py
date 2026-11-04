"""Real Git/blob, deterministic archive and existing installer-manifest acceptance."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
import zipfile

from tools import package_linux_delivery as delivery
from tools import linux_update


class LinuxDeliveryTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name); self.source = self.root / 'repository'; self.source.mkdir()
        for name in delivery.REQUIRED:
            path = self.source / name; path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(b'# fixture source, never executed\n')
        (self.source / 'kaname/__init__.py').write_text('VERSION = "9.8.7-dev.6"\n')
        (self.source / 'pyproject.toml').write_text('[project]\nversion="9.8.7.dev6"\n')
        self.extra = self.source / 'kaname/static/example.js'; self.extra.parent.mkdir()
        self.extra.write_text('/* fixture unicode: İzmir */\n')
        self.git('init', '-q'); self.commit()

    def git(self, *args):
        return subprocess.run(['git', '-C', str(self.source), *args], capture_output=True,
                              check=True, timeout=30).stdout.decode().strip()

    def commit(self):
        self.git('add', '.')
        self.git('-c', 'user.name=AuthWire fixture', '-c', 'user.email=fixture@example.invalid',
                 '-c', 'commit.gpgSign=false', 'commit', '-qm', 'Fixture source')
        self.sha = self.git('rev-parse', 'HEAD')

    def build(self, name='delivery'):
        return delivery.build(self.source, self.root / name, self.sha)

    def test_reproducible_bundles_and_existing_linux_manifest_consumer(self):
        first = self.build('first'); second = self.build('second')
        self.assertEqual(first, second)
        self.assertEqual('9.8.7-dev.6', first['version'])
        self.assertEqual(self.sha, first['source_commit']); self.assertFalse(first['live_install_applied'])
        for path in (self.root / 'first').iterdir():
            self.assertEqual(path.read_bytes(), (self.root / 'second' / path.name).read_bytes())
        panel_name = next(n for n in first['packages'] if n.endswith('-linux-source.zip'))
        with zipfile.ZipFile(self.root / 'first' / panel_name) as archive:
            archive.extractall(self.root / 'extracted')
        accepted = linux_update.verified_files(self.root / 'extracted/linux-source',
                                              first['linux_source_manifest_sha256'])
        self.assertEqual(set(delivery.REQUIRED) | {'kaname/static/example.js'}, set(accepted))
        self.assertEqual(self.extra.read_bytes(), accepted['kaname/static/example.js'])
        sums = (self.root / 'first/SHA256SUMS').read_text().splitlines()
        for line in sums:
            expected, name = line.split('  ', 1)
            self.assertEqual(expected, delivery.digest((self.root / 'first' / name).read_bytes()))

    def test_worker_bundle_has_exact_pinned_package_and_separate_upgrader(self):
        value = self.build(); name = next(n for n in value['packages'] if n.endswith('-backup-worker.zip'))
        with zipfile.ZipFile(self.root / 'delivery' / name) as archive:
            self.assertEqual({'backup-worker/scheduled_backup.py', 'backup-worker/offline_restore_check.py',
                              'backup-worker/manifest.json', 'backup-upgrade/backup_upgrade.py'}, set(archive.namelist()))
            manifest = archive.read('backup-worker/manifest.json')
            self.assertEqual(value['backup_worker_manifest_sha256'], delivery.digest(manifest))
            for member, expected in json.loads(manifest).items():
                self.assertEqual(expected, delivery.digest(archive.read('backup-worker/' + member)))
            self.assertEqual(value['backup_upgrade_tool_sha256'], delivery.digest(archive.read('backup-upgrade/backup_upgrade.py')))

    def test_wrong_expected_commit_refused_before_output(self):
        with self.assertRaises(ValueError): delivery.build(self.source, self.root / 'delivery', '0' * 40)
        self.assertFalse((self.root / 'delivery').exists())

    def test_dirty_tracked_worktree_and_staged_change_refused(self):
        self.extra.write_text('changed')
        with self.assertRaises(ValueError): self.build()
        self.git('add', '.')
        with self.assertRaises(ValueError): self.build()

    def test_untracked_ignored_state_is_not_silently_packaged_or_ignored(self):
        (self.source / '.gitignore').write_text('*.key\n'); self.commit()
        (self.source / 'kaname/private.key').write_text('fixture secret never publish')
        with self.assertRaises(ValueError): self.build()
        self.assertFalse((self.root / 'delivery').exists())

    def test_tracked_secret_and_database_refused(self):
        path = self.source / 'kaname/state.sqlite3'; path.write_bytes(b'fixture state')
        self.commit()
        with self.assertRaises(ValueError): self.build()

    @unittest.skipIf(sys.platform == 'win32', 'POSIX symlink fixture')
    def test_committed_symlink_refused(self):
        self.extra.unlink(); self.extra.symlink_to('../server.py'); self.commit()
        with self.assertRaises(ValueError): self.build()

    def test_version_mismatch_refused(self):
        (self.source / 'pyproject.toml').write_text('[project]\nversion="9.8.7.dev5"\n'); self.commit()
        with self.assertRaises(ValueError): self.build()

    def test_missing_required_source_refused(self):
        self.extra.unlink(); (self.source / 'tools/backup_upgrade.py').unlink(); self.commit()
        with self.assertRaises(ValueError): self.build()

    def test_destination_refuses_overwrite(self):
        self.build(); before = (self.root / 'delivery/DELIVERY.json').read_bytes()
        with self.assertRaises(ValueError): self.build()
        self.assertEqual(before, (self.root / 'delivery/DELIVERY.json').read_bytes())

    def test_python_caches_are_excluded_without_changing_output(self):
        before = self.build('before')
        cache = self.source / 'kaname/__pycache__'; cache.mkdir()
        (cache / 'fixture.pyc').write_bytes(b'disposable cache')
        self.assertEqual(before, self.build('after'))

    def test_build_does_not_execute_version_module(self):
        path = self.source / 'kaname/__init__.py'
        path.write_text('VERSION="9.8.7-dev.6"\nraise RuntimeError("must not execute")\n'); self.commit()
        self.assertEqual('9.8.7-dev.6', self.build()['version'])


if __name__ == '__main__': unittest.main()
