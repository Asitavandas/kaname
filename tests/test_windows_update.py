import hashlib
import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import Mock, patch

from kaname.store import Store
from tools import windows_update as update
from .helpers import config


class WindowsUpgradeTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name) / 'installed'; self.source = Path(self.temp.name) / 'staged'
        for root in (self.root, self.source):
            (root / 'kaname').mkdir(parents=True)
            (root / 'tools').mkdir()
        old = self.root / 'kaname/__init__.py'; old.write_text('VERSION = "0.2.0-dev.1"\n')
        new = self.source / 'kaname/__init__.py'; new.write_text('VERSION = "0.3.0-dev.1"\n')
        baseline = self.source / 'tools/windows_baseline.json'
        baseline.write_text(json.dumps({'files': {'kaname/__init__.py': update.digest(old)}}))
        (self.source / 'tools/windows_release.json').write_text(json.dumps({'version': '0.3.0-dev.1', 'files': {
            'kaname/__init__.py': update.digest(new), 'tools/windows_baseline.json': update.digest(baseline)}}))
        self.store = Store(self.root / 'kaname-state')
        self.store.save(0, config=config())
        (self.root / 'kaname-state/access-token').write_text('a' * 64)
        self.active = {**self.store.snapshot(), 'product': 'KANAME', 'version': '0.2.0-dev.1'}
        self.child = Mock(pid=999); self.child.poll.return_value = None
        self.patches = [patch.object(update, 'WINDOWS', True), patch.object(update, 'get_json', return_value=(200, self.active)),
                        patch.object(update, 'checked_panel_pid', return_value=123), patch.object(update.os, 'kill'),
                        patch.object(update.time, 'sleep'), patch.object(update, 'start_panel', return_value=self.child)]
        self.mocks = [p.start() for p in self.patches]
        for p in self.patches: self.addCleanup(p.stop)

    def test_upgrade_preserves_state_token_and_keeps_local_backup(self):
        before = self.store.snapshot()
        with patch.object(update, 'wait_panel', return_value={'directory_public': {'runtime_auth_ready': False}}):
            result = update.upgrade(self.root, self.source)
        self.assertTrue(result['updated']); self.assertTrue(result['token_preserved'])
        self.assertEqual(before, self.store.snapshot())
        self.assertEqual('a' * 64, (self.root / 'kaname-state/access-token').read_text())
        self.assertIn('0.3.0-dev.1', (self.root / 'kaname/__init__.py').read_text())
        self.assertEqual(1, len(list((self.root / '.kaname-upgrades').glob('*/state.sqlite3'))))
        self.mocks[3].assert_called_once_with(123, update.signal.SIGTERM)

    def test_local_source_edit_refuses_before_stopping_panel(self):
        local = self.root / 'kaname/__init__.py'; local.write_text('USER EDIT\n')
        with self.assertRaisesRegex(ValueError, 'Local source changes'):
            update.upgrade(self.root, self.source)
        self.mocks[3].assert_not_called()
        self.assertEqual('USER EDIT\n', local.read_text())

    def test_previous_release_upgrade_preserves_user_state(self):
        installed = self.root / 'kaname/__init__.py'
        installed.write_text('VERSION = "0.3.0-dev.1"\n')
        previous = self.source / 'tools/windows_previous_release.json'
        previous.write_text(json.dumps({'files': {'kaname/__init__.py': update.digest(installed)}}))
        release_path = self.source / 'tools/windows_release.json'
        release = json.loads(release_path.read_text()); release['files']['tools/windows_previous_release.json'] = update.digest(previous)
        release_path.write_text(json.dumps(release))
        with patch.object(update, 'wait_panel', return_value={'directory_public': {'runtime_auth_ready': False}}):
            self.assertTrue(update.upgrade(self.root, self.source)['updated'])
        self.assertEqual(1, self.store.snapshot()['revision'])

    def test_upgrade_preserves_and_backs_up_catalog_and_administrator_accounts(self):
        from kaname.admin import AdminStore
        from .test_directory import catalog
        self.store.save_directory(1, catalog())
        admins = AdminStore(self.store)
        before = update.snapshot(self.root)
        with patch.object(update, 'wait_panel', return_value={'directory_public': {'runtime_auth_ready': False}}):
            result = update.upgrade(self.root, self.source)
        self.assertEqual(before, update.snapshot(self.root))
        self.assertTrue(result['directory_catalog_preserved'])
        self.assertTrue(result['panel_accounts_preserved'])
        backups = list((self.root / '.kaname-upgrades').glob('*/administrators.sqlite3'))
        self.assertEqual(1, len(backups))
        import sqlite3
        with sqlite3.connect(backups[0]) as backup:
            self.assertEqual('ok', backup.execute('PRAGMA integrity_check').fetchone()[0])
            with admins.connect() as original:
                for table in ('admin_meta', 'admin_users', 'admin_profiles'):
                    self.assertEqual([tuple(r) for r in original.execute('SELECT * FROM ' + table + ' ORDER BY id')], backup.execute('SELECT * FROM ' + table + ' ORDER BY id').fetchall())

    def test_previous_release_manifest_is_digest_checked(self):
        previous = self.source / 'tools/windows_previous_release.json'
        previous.write_text(json.dumps({'files': {'kaname/__init__.py': 'untrusted'}}))
        with self.assertRaisesRegex(ValueError, 'Previous release digest mismatch'):
            update.upgrade(self.root, self.source)
        self.mocks[3].assert_not_called()

    def test_health_failure_rolls_back_source_and_preserves_current_data(self):
        before = self.store.snapshot()
        with patch.object(update, 'wait_panel', side_effect=[ValueError('health failed'), self.active]):
            with self.assertRaisesRegex(ValueError, 'previous source restored'):
                update.upgrade(self.root, self.source)
        self.assertIn('0.2.0-dev.1', (self.root / 'kaname/__init__.py').read_text())
        self.assertEqual(before, self.store.snapshot())
        self.assertFalse((self.root / 'tools/windows_release.json').exists())
        self.assertEqual(2, self.mocks[5].call_count)
        self.child.terminate.assert_called_once()

    def test_backup_failure_after_stop_restarts_old_panel(self):
        with patch.object(update, 'snapshot', side_effect=[update.snapshot(self.root), OSError('backup failed')]), patch.object(update, 'wait_panel', return_value=self.active):
            with self.assertRaisesRegex(ValueError, 'previous source restored'):
                update.upgrade(self.root, self.source)
        self.mocks[5].assert_called_once()
        self.assertIn('0.2.0-dev.1', (self.root / 'kaname/__init__.py').read_text())

    def test_wrong_panel_data_refuses_before_stopping(self):
        self.active['revision'] = 500
        with self.assertRaisesRegex(ValueError, 'does not match'):
            update.upgrade(self.root, self.source)
        self.mocks[3].assert_not_called()

    def test_source_path_cannot_touch_state_or_escape_root(self):
        for name in ['kaname-state/access-token', '../README.md', '/etc/passwd', 'C:/Windows/file']:
            with self.assertRaises(ValueError): update.protected_path(self.root, name)

    def test_windows_base_interpreter_requires_correct_module_and_owner(self):
        facts = {'pid': 42, 'exe_matches_virtualenv': False, 'exe_matches_base': True, 'module_matches': True, 'owner_matches': True}
        result = Mock(returncode=0, stdout=json.dumps(facts).encode())
        # Stop the upgrade-level mock; test the actual process validation logic.
        self.patches[2].stop()
        with patch.dict(update.os.environ, {'SystemRoot': 'C:/Windows'}), patch.object(update.subprocess, 'run', return_value=result):
            self.assertEqual(42, update.checked_panel_pid(Path('C:/venv/python.exe')))
            facts['owner_matches'] = False; result.stdout = json.dumps(facts).encode()
            with self.assertRaises(ValueError): update.checked_panel_pid(Path('C:/venv/python.exe'))
            facts['owner_matches'] = True; facts['module_matches'] = False; result.stdout = json.dumps(facts).encode()
            with self.assertRaises(ValueError): update.checked_panel_pid(Path('C:/venv/python.exe'))

    def test_started_panel_does_not_inherit_github_tokens(self):
        original = self.mocks[5]
        self.patches[5].stop()
        with patch.dict(update.os.environ, {'GITHUB_TOKEN': 'SECRET_GITHUB', 'ACTIONS_RUNTIME_TOKEN': 'SECRET_RUNTIME', 'AD_PASSWORD': 'SECRET_AD'}), patch.object(update.subprocess, 'DETACHED_PROCESS', 8, create=True), patch.object(update.subprocess, 'CREATE_NEW_PROCESS_GROUP', 512, create=True), patch.object(update.subprocess, 'Popen', return_value=Mock(pid=900)) as start:
            update.start_panel(self.root, self.root / '.venv/Scripts/python.exe')
        env = start.call_args.kwargs['env']
        self.assertNotIn('GITHUB_TOKEN', env); self.assertNotIn('ACTIONS_RUNTIME_TOKEN', env); self.assertNotIn('AD_PASSWORD', env)
