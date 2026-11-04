"""Root-only filesystem/lock/exchange fault injection; no real service operations."""
import hashlib
import errno
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

if sys.platform == 'linux':
    import fcntl
    from tools import backup_install as installer
    from tools import backup_upgrade as upgrade


@unittest.skipUnless(sys.platform == 'linux' and os.geteuid() == 0,
                     'Linux root filesystem acceptance (run under sudo in backup CI)')
class BackupUpgradeTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='authwire-upgrade-test-', dir='/root')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for attr, path in (('TARGET', 'opt/worker'), ('OPERATIONS', 'opt/operations'),
                           ('SCHEDULED', 'backups'), ('UPDATE_LOCK', 'run/update.lock'),
                           ('UNIT_ROOT', 'units')):
            value = self.root / path
            p = patch.object(upgrade, attr, value); p.start(); self.addCleanup(p.stop)
        upgrade.TARGET.mkdir(parents=True)
        upgrade.SCHEDULED.mkdir(mode=0o700)
        upgrade.UPDATE_LOCK.parent.mkdir()
        upgrade.UPDATE_LOCK.touch(mode=0o600)
        (upgrade.SCHEDULED / '.job.lock').touch(mode=0o600)
        (upgrade.SCHEDULED / 'manual.tar.gz').write_bytes(b'preserve manual fixture')
        for name in ('last-run.json', 'last-success.json'):
            path = upgrade.SCHEDULED / name
            path.write_bytes(b'{"old":"private fixture"}'); path.chmod(0o600)
        self.stage = self.root / 'stage'; self.stage.mkdir()
        old = {name: b'# old pinned source\n' for name in upgrade.FILES}
        new = {name: b'# new pinned source\n' for name in upgrade.FILES}
        for name in upgrade.FILES:
            (upgrade.TARGET / name).write_bytes(old[name])
            (self.stage / name).write_bytes(new[name])
        release = (json.dumps({name: upgrade.sha(data) for name, data in old.items()},
                              sort_keys=True, indent=2) + '\n').encode()
        (upgrade.TARGET / 'release.json').write_bytes(release)
        manifest = json.dumps({name: upgrade.sha(data) for name, data in new.items()}).encode()
        (self.stage / 'manifest.json').write_bytes(manifest)
        self.old_pin = upgrade.sha(release); self.new_pin = upgrade.sha(manifest)
        upgrade.UNIT_ROOT.mkdir()
        self.facts = {}
        for name, text in (('authwire-backup.service', installer.service_text()),
                           ('authwire-backup.timer', installer.timer_text())):
            (upgrade.UNIT_ROOT / name).write_text(text)
            self.facts[name] = dict(LoadState='loaded', FragmentPath=str(upgrade.UNIT_ROOT / name),
                                   DropInPaths='', ActiveState='inactive', SubState='dead', UnitFileState='disabled')
        self.calls = []
        p = patch.object(upgrade, 'command', side_effect=self.command); p.start(); self.addCleanup(p.stop)
        self.live = {'files': {'protected': 'original'}, 'business_state': {'db': 'stable'},
                     'pids': {'panel': '12', 'radius': '0', 'broker': '34'}}
        p = patch.object(upgrade, 'live', side_effect=lambda worker: json.loads(json.dumps(self.live)))
        p.start(); self.addCleanup(p.stop)
        self.worker = {'capture': self.capture}
        self.checker = {'check': lambda *a: {'data_restore_exercised': True}}
        p = patch.object(upgrade, 'namespace', side_effect=lambda data, path:
                         self.worker if path.name == 'scheduled_backup.py' else self.checker)
        p.start(); self.addCleanup(p.stop)
        self.before = upgrade.installed(upgrade.TARGET)
        self.archive_before = upgrade.archives()

    def command(self, *args):
        self.calls.append(args)
        if args[1] == 'show':
            return '\n'.join(k + '=' + v for k, v in self.facts[args[2]].items())
        if args[1] in ('stop', 'start') and args[2] == 'authwire-backup.timer':
            self.facts[args[2]].update(ActiveState='active' if args[1] == 'start' else 'inactive',
                                     SubState='waiting' if args[1] == 'start' else 'dead')
            return ''
        raise AssertionError('Unexpected service mutation')

    def capture(self, path, keep):
        self.assertEqual(14, keep)
        self.assertNotEqual(path, upgrade.SCHEDULED)
        archive = path / 'fixture.tar.gz'; archive.write_bytes(b'private fixture bytes')
        return {'backup': str(archive), 'sha256': upgrade.sha(archive.read_bytes())}

    def run_upgrade(self, inspect=False):
        return upgrade.perform(self.stage, self.new_pin, self.old_pin, upgrade.ACK, inspect)

    def assert_old(self):
        self.assertEqual(self.before, upgrade.installed(upgrade.TARGET))
        self.assertEqual(self.archive_before, upgrade.archives())

    def test_inspect_is_read_only_and_does_not_execute_candidate(self):
        with patch.object(upgrade, 'namespace', side_effect=AssertionError('executed')):
            result = self.run_upgrade(inspect=True)
        self.assertEqual('BACKUP_UPGRADE_REVIEW', result['event'])
        self.assertFalse(upgrade.OPERATIONS.exists()); self.assert_old()
        self.assertTrue(all(args[1] == 'show' for args in self.calls))

    def test_success_keeps_archives_status_stopped_radius_and_inactive_timer(self):
        result = self.run_upgrade()
        self.assertEqual('BACKUP_UPGRADE_SUCCESS', result['event'])
        self.assertEqual(self.archive_before, upgrade.archives())
        self.assertEqual('0', self.live['pids']['radius'])
        self.assertFalse(any(c[1] != 'show' for c in self.calls))
        operation = upgrade.OPERATIONS / result['operation']
        self.assertEqual(self.before, upgrade.installed(operation / 'exchange'))
        self.assertEqual('completed', json.loads((operation / 'terminal.json').read_text())['status'])
        upgrade.journal()

    def test_private_operator_umask_preserves_original_source_modes(self):
        old_mask = os.umask(0o077)
        try:
            self.run_upgrade()
        finally:
            os.umask(old_mask)
        installed = upgrade.installed(upgrade.TARGET)
        self.assertEqual(self.before['directory'][2], installed['directory'][2])
        for name in installed['files']:
            self.assertEqual(self.before['files'][name][3], installed['files'][name][3])

    def test_active_timer_is_stopped_and_restored_without_enable_disable(self):
        self.facts['authwire-backup.timer'].update(ActiveState='active', SubState='waiting', UnitFileState='enabled')
        self.run_upgrade()
        changes = [c[1:] for c in self.calls if c[1] != 'show']
        self.assertEqual([('stop', 'authwire-backup.timer'), ('start', 'authwire-backup.timer')], changes)

    def test_already_current_does_not_create_evidence_or_change_timer(self):
        for name in upgrade.FILES:
            (self.stage / name).write_bytes((upgrade.TARGET / name).read_bytes())
        data = (upgrade.TARGET / 'release.json').read_bytes()
        (self.stage / 'manifest.json').write_bytes(data); self.new_pin = upgrade.sha(data)
        self.assertEqual('BACKUP_UPGRADE_ALREADY_CURRENT', self.run_upgrade()['event'])
        self.assertFalse(upgrade.OPERATIONS.exists()); self.assert_old()

    def test_candidate_pin_mismatch_refused(self):
        self.new_pin = '0' * 64
        with self.assertRaises(upgrade.Refused): self.run_upgrade()
        self.assert_old()

    def test_installed_pin_mismatch_refused(self):
        self.old_pin = '0' * 64
        with self.assertRaises(upgrade.Refused): self.run_upgrade()
        self.assert_old()

    def test_unknown_installed_member_refused(self):
        (upgrade.TARGET / 'foreign').write_text('keep')
        with self.assertRaises(upgrade.Refused): self.run_upgrade()
        self.assertTrue((upgrade.TARGET / 'foreign').exists())

    def test_installed_source_tamper_refused(self):
        (upgrade.TARGET / upgrade.FILES[0]).write_text('# foreign\n')
        with self.assertRaises(upgrade.Refused): self.run_upgrade()

    def test_symlink_and_hardlink_stage_refused(self):
        path = self.stage / upgrade.FILES[0]; data = path.read_bytes()
        held = self.root / 'held'; held.write_bytes(data)
        path.unlink(); path.symlink_to(held)
        with self.assertRaises(upgrade.Refused): self.run_upgrade()
        path.unlink(); os.link(held, path)
        with self.assertRaises(upgrade.Refused): self.run_upgrade()
        self.assert_old()

    def test_world_writable_installed_file_refused(self):
        (upgrade.TARGET / upgrade.FILES[0]).chmod(0o666)
        with self.assertRaises(upgrade.Refused): self.run_upgrade()

    def test_group_writable_candidate_manifest_refused(self):
        (self.stage / 'manifest.json').chmod(0o660)
        with self.assertRaises(upgrade.Refused): self.run_upgrade()
        self.assert_old()

    def test_wrong_group_candidate_manifest_refused(self):
        try:
            os.chown(self.stage / 'manifest.json', 0, 65534)
        except OSError as error:
            if error.errno == errno.EINVAL:
                self.skipTest('Host user namespace does not map fixture group 65534')
            raise
        with self.assertRaises(upgrade.Refused): self.run_upgrade()
        self.assert_old()

    def test_duplicate_manifest_member_refused_even_with_matching_pin(self):
        data = b'{"scheduled_backup.py":"' + b'0' * 64 + b'","scheduled_backup.py":"' + b'0' * 64 + b'"}'
        (self.stage / 'manifest.json').write_bytes(data); self.new_pin = upgrade.sha(data)
        with self.assertRaises(upgrade.Refused): self.run_upgrade()

    def test_unit_dropin_refused(self):
        self.facts['authwire-backup.timer']['DropInPaths'] = '/foreign/override.conf'
        with self.assertRaises(upgrade.Refused): self.run_upgrade()
        self.assert_old()

    def test_active_backup_refused(self):
        self.facts['authwire-backup.service']['ActiveState'] = 'activating'
        with self.assertRaises(upgrade.Refused): self.run_upgrade()
        self.assert_old()

    def test_job_lock_busy_does_not_write_status(self):
        with upgrade.lock(upgrade.SCHEDULED / '.job.lock'):
            with self.assertRaises(BlockingIOError): self.run_upgrade()
        self.assert_old(); self.assertFalse(upgrade.OPERATIONS.exists())

    def test_update_lock_busy_releases_job_lock(self):
        with upgrade.lock(upgrade.UPDATE_LOCK):
            with self.assertRaises(BlockingIOError): self.run_upgrade()
        with upgrade.lock(upgrade.SCHEDULED / '.job.lock'): pass
        self.assert_old()

    def test_capture_failure_rolls_back_exact_source(self):
        self.worker['capture'] = lambda *a: (_ for _ in ()).throw(ValueError('private error'))
        result = self.run_upgrade()
        self.assertEqual('BACKUP_UPGRADE_ROLLED_BACK', result['event']); self.assert_old()
        upgrade.journal()

    def test_evidence_write_failure_does_not_skip_rollback(self):
        self.worker['capture'] = lambda *a: (_ for _ in ()).throw(ValueError('capture failed'))
        real_record = upgrade.record
        def failed(path, value):
            if path.name == 'failure.json': raise OSError('disk full')
            return real_record(path, value)
        with patch.object(upgrade, 'record', side_effect=failed):
            self.assertEqual('BACKUP_UPGRADE_ROLLED_BACK', self.run_upgrade()['event'])
        self.assert_old()

    def test_lock_is_released_before_timer_resume(self):
        self.facts['authwire-backup.timer'].update(ActiveState='active', SubState='waiting')
        real_command = self.command
        def checked(*args):
            if args[1] == 'start':
                with upgrade.lock(upgrade.SCHEDULED / '.job.lock'), upgrade.lock(upgrade.UPDATE_LOCK):
                    pass
            return real_command(*args)
        with patch.object(upgrade, 'command', side_effect=checked): self.run_upgrade()

    def test_candidate_capture_and_restore_hold_both_exclusive_locks(self):
        real_capture = self.capture
        def checked(path, keep):
            for lock in (upgrade.SCHEDULED / '.job.lock', upgrade.UPDATE_LOCK):
                with self.assertRaises(BlockingIOError):
                    with upgrade.lock(lock): pass
            return real_capture(path, keep)
        self.worker['capture'] = checked
        self.run_upgrade()

    def test_restore_failure_rolls_back_and_restores_active_timer(self):
        self.facts['authwire-backup.timer'].update(ActiveState='active', SubState='waiting')
        self.checker['check'] = lambda *a: {'data_restore_exercised': False}
        self.assertEqual('BACKUP_UPGRADE_ROLLED_BACK', self.run_upgrade()['event'])
        self.assert_old(); self.assertEqual('active', self.facts['authwire-backup.timer']['ActiveState'])

    def test_exchange_succeeded_then_fsync_failed_is_detected_and_rolled_back(self):
        real_exchange = upgrade.exchange; calls = []
        def failing(left, right):
            real_exchange(left, right); calls.append(1)
            if len(calls) == 1: raise OSError('injected post-rename fsync failure')
        with patch.object(upgrade, 'exchange', side_effect=failing):
            self.assertEqual('BACKUP_UPGRADE_ROLLED_BACK', self.run_upgrade()['event'])
        self.assertEqual(2, len(calls)); self.assert_old()

    def test_foreign_source_after_exchange_is_retained_and_blocks_next_upgrade(self):
        def foreign(path, keep):
            (upgrade.TARGET / upgrade.FILES[0]).write_text('# foreign state preserved\n')
            raise ValueError('injected')
        self.worker['capture'] = foreign
        with self.assertRaises(upgrade.RequiresReview): self.run_upgrade()
        self.assertIn('foreign', (upgrade.TARGET / upgrade.FILES[0]).read_text())
        with self.assertRaises(upgrade.RequiresReview): upgrade.journal()

    def test_changed_business_state_is_not_reverted_or_reported_successful(self):
        real_capture = self.capture
        def changed(path, keep):
            result = real_capture(path, keep); self.live['business_state']['db'] = 'new operator data'
            return result
        self.worker['capture'] = changed
        with self.assertRaises(upgrade.RequiresReview): self.run_upgrade()
        self.assertEqual('new operator data', self.live['business_state']['db'])
        self.assertEqual(self.before, upgrade.installed(upgrade.TARGET))

    def test_missing_terminal_blocks_future_operation(self):
        operation = upgrade.OPERATIONS / ('a' * 32); operation.mkdir(parents=True)
        (operation / 'intent.json').write_text('{}')
        with self.assertRaises(upgrade.RequiresReview): self.run_upgrade()
        self.assert_old()

    def test_timer_resume_failure_retains_verified_new_source_and_requires_review(self):
        self.facts['authwire-backup.timer'].update(ActiveState='active', SubState='waiting')
        real_command = self.command
        def failed(*args):
            if args[1] == 'start': raise subprocess.CalledProcessError(1, args)
            return real_command(*args)
        with patch.object(upgrade, 'command', side_effect=failed):
            with self.assertRaises(upgrade.RequiresReview): self.run_upgrade()
        self.assertNotEqual(self.before, upgrade.installed(upgrade.TARGET))
        operation, = upgrade.OPERATIONS.iterdir()
        self.assertTrue((operation / 'verified.json').exists())
        self.assertFalse((operation / 'terminal.json').exists())
        with self.assertRaises(upgrade.RequiresReview): upgrade.journal()

    def test_cli_failure_does_not_print_private_exception(self):
        import contextlib
        import io
        output = io.StringIO()
        with (patch.object(upgrade, 'perform', side_effect=upgrade.RequiresReview('SECRET fixture')),
             patch.object(sys, 'argv', ['backup_upgrade', 'inspect', '--source-dir', str(self.stage),
                                       '--manifest-sha256', self.new_pin, '--installed-release-sha256', self.old_pin]),
             contextlib.redirect_stdout(output)):
            self.assertEqual(1, upgrade.main())
        self.assertNotIn('SECRET', output.getvalue())
        self.assertTrue(json.loads(output.getvalue())['requires_review'])


if __name__ == '__main__': unittest.main()
