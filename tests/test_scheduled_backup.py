"""Real SQLite/archives, live-read changes, bounded retention and install rollback."""
from contextlib import redirect_stdout
import hashlib
import io
import json
import os
from pathlib import Path
import runpy
import shutil
import sqlite3
import subprocess
import sys
import tarfile
import tempfile
import unittest
from unittest.mock import patch

if sys.platform == 'linux':
    from tools import scheduled_backup as worker
    from tools import backup_install as installer


@unittest.skipUnless(sys.platform == 'linux', 'Linux backup worker')
class ScheduledBackupTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        p = patch.object(worker, 'BASE', self.root); p.start(); self.addCleanup(p.stop)
        p = patch.object(worker, 'pids', return_value={'panel': '1', 'radius': '2', 'broker': '3'})
        p.start(); self.addCleanup(p.stop)
        for name in worker.ROOT_NAMES: (self.root / name).mkdir(parents=True)
        (self.root / 'run').mkdir()
        (self.root / 'run/kaname-lab-update.lock').touch(mode=0o600)
        tmpfiles = self.root / 'etc/tmpfiles.d/authwire-service-control.conf'
        tmpfiles.parent.mkdir(); tmpfiles.write_text('f /run/kaname-lab-update.lock 0600 root root -\n')
        for unit in worker.UNITS:
            path = self.root / 'etc/systemd/system' / unit
            path.parent.mkdir(parents=True, exist_ok=True); path.write_text('[Service]\nType=oneshot\n')
        for name in ('kaname.sqlite3', 'administrators.sqlite3'):
            with sqlite3.connect(self.db(name)) as db:
                db.executescript('''CREATE TABLE business(id PRIMARY KEY,value);
                    INSERT INTO business VALUES (1,'fixture private policy');
                    CREATE TABLE admin_sessions(id PRIMARY KEY,last_seen);
                    INSERT INTO admin_sessions VALUES (1,0);
                    CREATE TABLE runtime_settings(name PRIMARY KEY,payload);
                    INSERT INTO runtime_settings VALUES ('directory_health','old');''')
        self.key = self.root / 'var/lib/kaname-lab/secret-store.key'
        self.key.write_bytes(b'fixture private key never print'); self.key.chmod(0o600)
        (self.root / 'opt/kaname-lab/venv/python').symlink_to('/usr/bin/python3')
        drop = self.root / 'etc/systemd/system/authwire-radius.service.d/override.conf'
        drop.parent.mkdir(); drop.write_text('[Service]\nPrivateTmp=yes\n'); drop.chmod(0o640)
        self.target = worker.prepare_directory()

    def db(self, name='kaname.sqlite3'): return self.root / 'var/lib/kaname-lab' / name
    def archives(self): return list(self.target.glob('authwire-scheduled-*.tar.gz'))

    def test_real_backup_verifies_bytes_database_metadata_and_keeps_services(self):
        result = worker.run()
        self.assertEqual('BACKUP_SUCCESS', result['event'])
        self.assertTrue(result['service_processes_preserved'])
        self.assertFalse(result['data_restore_exercised'])
        self.assertEqual(0o600, Path(result['backup']).stat().st_mode & 0o777)
        self.assertEqual(0o700, self.target.stat().st_mode & 0o777)
        with tarfile.open(result['backup']) as archive:
            self.assertEqual(self.key.read_bytes(), archive.extractfile('var/lib/kaname-lab/secret-store.key').read())
            drop = archive.getmember('etc/systemd/system/authwire-radius.service.d/override.conf')
            self.assertEqual(0o640, drop.mode)
            self.assertTrue(archive.getmember('opt/kaname-lab/venv/python').issym())
            copy = self.root / 'restored.sqlite3'
            copy.write_bytes(archive.extractfile('var/lib/kaname-lab/kaname.sqlite3').read())
        with sqlite3.connect(copy) as db:
            self.assertEqual('fixture private policy', db.execute('SELECT value FROM business').fetchone()[0])
            self.assertEqual([('ok',)], db.execute('PRAGMA integrity_check').fetchall())
        self.assertEqual('BACKUP_SUCCESS', json.loads((self.target / 'last-run.json').read_text())['event'])
        self.assertFalse(any(p.name.startswith('.capture-') for p in self.target.iterdir()))
        self.assertNotIn('fixture private', json.dumps(result))

    def test_user_profiles_issuances_are_business_data_but_challenges_rates_are_volatile(self):
        with sqlite3.connect(self.db()) as db:
            for table in ('user_enrollment_profiles','user_enrollment_issuances','user_enrollment_challenges','user_enrollment_rate'):
                db.execute('CREATE TABLE '+table+' (id PRIMARY KEY,value)')
                db.execute('INSERT INTO '+table+' VALUES (1,?)',('original',))
        before=worker.db_fingerprint(self.db())
        with sqlite3.connect(self.db()) as db:
            for table in ('user_enrollment_challenges','user_enrollment_rate'):
                db.execute('UPDATE '+table+' SET value=?',('activity',))
        self.assertEqual(before,worker.db_fingerprint(self.db()))
        for table in ('user_enrollment_profiles','user_enrollment_issuances'):
            with sqlite3.connect(self.db()) as db:db.execute('UPDATE '+table+' SET value=?',('changed',))
            self.assertNotEqual(before,worker.db_fingerprint(self.db()))
            with sqlite3.connect(self.db()) as db:db.execute('UPDATE '+table+' SET value=?',('original',))

    def test_open_wal_database_is_copied_through_sqlite_backup(self):
        db = sqlite3.connect(self.db()); self.addCleanup(db.close)
        db.execute('PRAGMA journal_mode=WAL')
        db.execute("UPDATE business SET value='committed in WAL'"); db.commit()
        result = worker.run()
        with tarfile.open(result['backup']) as archive:
            names = archive.getnames()
            self.assertFalse(any(n.endswith(('-wal', '-shm')) for n in names))
            copy = self.root / 'wal-copy.sqlite3'
            copy.write_bytes(archive.extractfile('var/lib/kaname-lab/kaname.sqlite3').read())
        with sqlite3.connect(copy) as reader:
            self.assertEqual('committed in WAL', reader.execute('SELECT value FROM business').fetchone()[0])

    def test_session_and_health_activity_does_not_make_business_snapshot_fail(self):
        original = worker.inventory; calls = 0
        def changing(items):
            nonlocal calls
            result = original(items); calls += 1
            with sqlite3.connect(self.db()) as db:
                db.execute('UPDATE admin_sessions SET last_seen=?', (calls,))
                db.execute("UPDATE runtime_settings SET payload=? WHERE name='directory_health'", (str(calls),))
            return result
        with patch.object(worker, 'inventory', side_effect=changing): result = worker.run()
        self.assertTrue(result['business_state_stable'])

    def test_access_history_writes_do_not_break_backup_and_committed_rows_are_in_archive(self):
        from kaname.radius_events import initialize, append
        from tests.test_radius_events import event
        state = self.root / 'var/lib/kaname-lab'
        path = initialize(state); append(state, event())
        original = worker.inventory; calls = 0
        def changing(items):
            nonlocal calls
            result = original(items); calls += 1
            append(state, event(calls + 10))
            return result
        with patch.object(worker, 'inventory', side_effect=changing): result = worker.run()
        self.assertTrue(result['business_state_stable'])
        with tarfile.open(result['backup']) as archive:
            copy = self.root / 'access-copy.sqlite3'
            copy.write_bytes(archive.extractfile('var/lib/kaname-lab/radius-events/access.sqlite3').read())
        with sqlite3.connect(copy) as db:
            self.assertGreaterEqual(db.execute('SELECT count(*) FROM access_events').fetchone()[0], 1)
            self.assertEqual([('ok',)], db.execute('PRAGMA integrity_check').fetchall())

    def test_business_mutation_retries_then_fails_without_publishing_or_pruning(self):
        manual = self.target.parent / 'authwire-pause-manual.tar.gz'; manual.write_bytes(b'keep')
        original = worker.inventory; calls = 0
        def changing(items):
            nonlocal calls
            result = original(items); calls += 1
            if calls >= 3:
                with sqlite3.connect(self.db()) as db: db.execute('UPDATE business SET value=?', (str(calls),))
            return result
        with patch.object(worker, 'inventory', side_effect=changing), self.assertRaisesRegex(ValueError, 'Business state'):
            worker.run()
        self.assertEqual([], self.archives()); self.assertEqual(b'keep', manual.read_bytes())
        record = json.loads((self.target / 'last-run.json').read_text())
        self.assertEqual('capture', record['phase']); self.assertFalse(record['previous_backups_pruned'])

    def test_product_process_change_refuses_publication(self):
        with patch.object(worker, 'pids', side_effect=[{'panel': '1'}, {'panel': '2'}]), self.assertRaisesRegex(ValueError, 'process changed'):
            worker.run()
        self.assertEqual([], self.archives())

    def test_failed_archive_verification_keeps_last_success_and_old_backups(self):
        success = worker.run(); previous = (self.target / 'last-success.json').read_bytes()
        with patch.object(worker, 'verify_archive', side_effect=ValueError('bad bytes')), self.assertRaises(ValueError): worker.run()
        self.assertEqual(previous, (self.target / 'last-success.json').read_bytes())
        self.assertTrue(Path(success['backup']).exists()); self.assertEqual(1, len(self.archives()))

    def test_disk_shortage_publishes_no_archive(self):
        with patch.object(worker.shutil, 'disk_usage', return_value=shutil._ntuple_diskusage(10, 9, 1)), self.assertRaises(OSError): worker.run()
        self.assertEqual([], self.archives())

    def test_foreign_key_violation_is_refused(self):
        with sqlite3.connect(self.db()) as db:
            db.executescript('CREATE TABLE parent(id PRIMARY KEY);CREATE TABLE child(id REFERENCES parent(id));INSERT INTO child VALUES(99);')
        with self.assertRaisesRegex(ValueError, 'foreign-key'): worker.run()
        self.assertEqual([], self.archives())

    def managed(self, number):
        p = self.target / ('authwire-scheduled-202610%02dT031500Z-' % number + 'a' * 12 + '.tar.gz')
        p.write_bytes(b'backup ' + str(number).encode()); p.chmod(0o600)
        manifest = Path(str(p) + '.json')
        worker.atomic_json(manifest, {'producer': worker.PRODUCER, 'event': 'BACKUP_SUCCESS', 'backup': str(p), 'sha256': worker.digest(p)})
        return p

    def test_retention_only_prunes_own_verified_archives_and_keeps_manual_unknown(self):
        old = [self.managed(i) for i in range(1, 5)]
        manual = self.target.parent / 'authwire-pause-20200101.tar.gz'; manual.write_bytes(b'manual')
        unknown = self.target / 'operator-archive.tar.gz'; unknown.write_bytes(b'unknown')
        orphan = self.target / ('authwire-scheduled-20261001T031500Z-' + 'b' * 12 + '.tar.gz'); orphan.write_bytes(b'orphan')
        self.assertEqual(2, worker.retention(self.target, 2))
        self.assertEqual([False, False, True, True], [p.exists() for p in old])
        self.assertTrue(manual.exists() and unknown.exists() and orphan.exists())

    def test_corrupt_retention_candidate_aborts_entire_deletion_plan(self):
        old = [self.managed(i) for i in range(1, 5)]; old[1].write_bytes(b'changed')
        with self.assertRaisesRegex(ValueError, 'integrity mismatch'): worker.retention(self.target, 2)
        self.assertTrue(all(p.exists() for p in old))

    def test_symlink_backup_target_and_status_are_refused(self):
        (self.target / 'last-run.json').symlink_to(self.key)
        with self.assertRaises(ValueError): worker.atomic_json(self.target / 'last-run.json', {})
        self.assertEqual(b'fixture private key never print', self.key.read_bytes())
        shutil.rmtree(self.target); self.target.symlink_to(self.root / 'var/lib/kaname-lab')
        with self.assertRaises(ValueError): worker.prepare_directory()

    def test_update_lock_blocks_capture_and_records_coordination_failure(self):
        with worker.locked(self.root / 'run/kaname-lab-update.lock'):
            with self.assertRaises(BlockingIOError): worker.run()
        self.assertEqual([], self.archives())
        self.assertEqual('coordination', json.loads((self.target / 'last-run.json').read_text())['phase'])

    def test_parallel_job_does_not_overwrite_another_jobs_status(self):
        worker.atomic_json(self.target / 'last-run.json', {'event': 'active'})
        with worker.locked(self.target / '.job.lock', create=True), self.assertRaises(BlockingIOError): worker.run()
        self.assertEqual({'event': 'active'}, json.loads((self.target / 'last-run.json').read_text()))

    def test_invalid_retention_is_rejected_before_work(self):
        for keep in (0, 1, 91, True):
            with self.assertRaises(ValueError): worker.run(keep)
        self.assertEqual([], self.archives())


@unittest.skipUnless(sys.platform == 'linux', 'Linux backup installer')
class BackupInstallerTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup); self.root = Path(self.temp.name)
        self.stage = self.root / 'stage'; self.stage.mkdir()
        self.package = {'scheduled_backup.py': b'# worker\n', 'offline_restore_check.py': b'# checker\n'}
        for name, data in self.package.items(): (self.stage / name).write_bytes(data)
        self.manifest = json.dumps({n: hashlib.sha256(d).hexdigest() for n, d in self.package.items()}).encode()
        (self.stage / 'manifest.json').write_bytes(self.manifest)
        self.expected = hashlib.sha256(self.manifest).hexdigest()
        self.target = self.root / 'opt/backup'; self.target.parent.mkdir()
        self.service = self.root / 'units/authwire-backup.service'; self.service.parent.mkdir()
        self.timer = self.service.with_suffix('.timer'); self.backups = self.root / 'backups'; self.backups.mkdir(mode=0o700)
        self.lock = self.root / 'lock'; self.calls = []
        for name, value in [('TARGET', self.target), ('SERVICE', self.service), ('TIMER', self.timer), ('LOCK', self.lock), ('PYTHON', Path('/usr/bin/python3'))]:
            p = patch.object(installer, name, value); p.start(); self.addCleanup(p.stop)
        for name, value in [('trusted', None), ('protected_snapshot', {'pids': {'panel': '1'}, 'business': 'same'})]:
            p = patch.object(installer, name, return_value=value); p.start(); self.addCleanup(p.stop)
        p = patch.object(installer.os, 'geteuid', return_value=0); p.start(); self.addCleanup(p.stop)
        original_read = Path.read_text
        def read(path, *args, **kwargs):
            if str(path) == '/etc/tmpfiles.d/authwire-service-control.conf': return 'f /run/kaname-lab-update.lock 0600 root root -\n'
            return original_read(path, *args, **kwargs)
        p = patch.object(Path, 'read_text', read); p.start(); self.addCleanup(p.stop)
        self.work = {'prepare_directory': lambda: self.backups, 'PRODUCER': worker.PRODUCER, 'NAME': worker.NAME,
                     'KEEP': 14, 'atomic_json': lambda path, value: path.write_text(json.dumps(value)), 'utc': worker.utc}
        def ns(data, path): return self.work if path.name == 'scheduled_backup.py' else {'check': lambda *args: {'data_restore_exercised': True}}
        p = patch.object(installer, 'namespace', side_effect=ns); p.start(); self.addCleanup(p.stop)

    def command(self, *args):
        self.calls.append(args)
        if args[:3] == ('systemctl', 'start', self.service.name):
            name = 'authwire-scheduled-20261018T031500Z-' + 'a' * 12 + '.tar.gz'
            (self.backups / 'last-run.json').write_text(json.dumps({'event': 'BACKUP_SUCCESS', 'producer': worker.PRODUCER,
                'backup': str(self.backups / name), 'sha256': '0' * 64}))
        return subprocess.CompletedProcess(args, 0, '')

    def install(self, command=None):
        with patch.object(installer, 'command', side_effect=command or self.command): return installer.install(self.stage, self.expected)

    def test_source_pins_are_enforced_before_install(self):
        with self.assertRaisesRegex(ValueError, 'manifest differs'): installer.load_package(self.stage, '0' * 64)
        (self.stage / 'scheduled_backup.py').write_bytes(b'# modified')
        with self.assertRaisesRegex(ValueError, 'source differs'): installer.load_package(self.stage, self.expected)
        self.assertFalse(self.target.exists())

    def test_operator_entrypoint_matches_the_reviewed_installer_and_payload(self):
        root = Path(__file__).parents[1]
        ns = runpy.run_path(str(root / 'docs/checkpoints/2026-10-18-scheduled-backup-access-history.py'))
        self.assertEqual(ns['INSTALLER_SHA'], hashlib.sha256((root / 'tools/backup_install.py').read_bytes()).hexdigest())
        files = {n: hashlib.sha256((root / 'tools' / n).read_bytes()).hexdigest() for n in installer.FILES}
        # Historical access-history installer pins its pre-hotfix worker.
        files['scheduled_backup.py'] = '83de9cb66df58b5f0a12c18c6526731e9697023f268a12c7b566ba6efbda77b0'
        manifest = json.dumps(files, sort_keys=True, indent=2) + '\n'
        self.assertEqual(ns['MANIFEST_SHA'], hashlib.sha256(manifest.encode()).hexdigest())

    def test_hardened_timer_first_backup_restore_then_enable_preserves_product(self):
        result = self.install()
        self.assertTrue(result['verified']); self.assertFalse(result['off_host_copy_configured'])
        self.assertTrue((self.backups / 'install-before.json').exists())
        self.assertTrue(all(json.loads((self.backups / 'install-preservation.json').read_text())['checks'].values()))
        self.assertIn('ProtectSystem=strict\n', self.service.read_text())
        self.assertIn('CapabilityBoundingSet=CAP_DAC_READ_SEARCH\n', self.service.read_text())
        self.assertIn('03:15:00 Europe/Istanbul', self.timer.read_text())
        self.assertIn(('systemctl', 'start', 'authwire-backup.service'), self.calls)
        self.assertFalse(any('authwire-radius.service' in c for c in self.calls))
        self.assertFalse(any('kaname-lab.service' in c for c in self.calls))

    def test_unknown_existing_unit_refused_without_changes(self):
        self.service.write_text('operator custom unit')
        with self.assertRaisesRegex(ValueError, 'unit differs'): self.install()
        self.assertFalse(self.target.exists()); self.assertEqual([], self.calls)

    def test_failed_first_backup_rolls_back_only_new_feature(self):
        def fail(*args):
            if args[:2] == ('systemctl', 'start'): raise subprocess.CalledProcessError(1, args)
            return self.command(*args)
        with patch.object(installer.subprocess, 'run') as sub, self.assertRaises(subprocess.CalledProcessError): self.install(fail)
        self.assertFalse(self.target.exists() or self.service.exists() or self.timer.exists())
        self.assertTrue(self.backups.exists())
        self.assertTrue(all('authwire-radius.service' not in str(c) and 'kaname-lab.service' not in str(c) for c in sub.call_args_list))

    def test_restore_failure_does_not_enable_timer(self):
        def ns(data, path):
            if path.name == 'scheduled_backup.py': return self.work
            def fail(*args): raise ValueError('restore refused')
            return {'check': fail}
        with patch.object(installer, 'namespace', side_effect=ns), patch.object(installer.subprocess, 'run'), self.assertRaises(ValueError): self.install()
        self.assertFalse(any(c[:3] == ('systemctl', 'enable', '--now') for c in self.calls))


if __name__ == '__main__': unittest.main()
