"""Actual file/lock changes with controlled service faults; no host service calls."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile
import types
import unittest
from unittest.mock import patch

if os.name == 'posix':
    from tools import radius_events_install as installer


@unittest.skipUnless(os.name == 'posix', 'Linux-only activation')
class EventActivationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        for name, value in {'SOURCE': 'source', 'STATE': 'state', 'PREFIX': 'native', 'RUNTIME': 'runtime',
                            'UNIT': 'units/authwire-radius.service', 'DROPIN': 'units/authwire-radius.service.d/30-access-history.conf',
                            'WORKER': 'backup/scheduled_backup.py', 'RELEASE': 'backup/release.json',
                            'LOCK': 'run/update.lock', 'EVIDENCE_ROOT': 'evidence'}.items():
            p = patch.object(installer, name, self.root / value); p.start(); self.addCleanup(p.stop)
        self.owner = os.geteuid()
        p = patch.object(installer, 'ROOT_OWNER', self.owner); p.start(); self.addCleanup(p.stop)
        p = patch.object(installer.os, 'geteuid', return_value=0); p.start(); self.addCleanup(p.stop)
        for path in (installer.UNIT, installer.WORKER, installer.RELEASE, installer.LOCK,
                     installer.SOURCE / 'tools/scheduled_backup.py', installer.PREFIX / 'lib/rlm_python3.so'):
            path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
        self.base = (b'[Unit]\nDescription=fixture\n[Service]\nUser=kaname-lab\n'
                     b'ExecStartPre=/opt/kaname-lab/venv/bin/python -B -m tools.radius_runtime '
                     b'--output /run/authwire-radius --prefix /opt/authwire-radius '
                     b'--state-dir /var/lib/kaname-lab --listen-ip 192.0.2.10\n'
                     b'ProtectSystem=strict\nNoNewPrivileges=yes\n')
        installer.UNIT.write_bytes(self.base); installer.LOCK.touch(mode=0o600)
        self.old = installer.BACKUP_CHANGE[0] + b", 'fixture'}\n"
        self.new = self.old.replace(*installer.BACKUP_CHANGE, 1)
        installer.WORKER.write_bytes(self.old); installer.WORKER.chmod(0o600)
        (installer.SOURCE / 'tools/scheduled_backup.py').write_bytes(self.new)
        native = installer.PREFIX / 'lib/rlm_python3.so'; native.write_bytes(b'unchanged native')
        checker = installer.WORKER.parent / 'offline_restore_check.py'; checker.write_bytes(b'unchanged checker')
        self.release = json.dumps({'scheduled_backup.py': installer.digest(self.old),
                                   'offline_restore_check.py': installer.digest(checker.read_bytes())}).encode()
        installer.RELEASE.write_bytes(self.release)
        for name, value in [('OLD_WORKER_SHA', installer.digest(self.old)), ('NATIVE_SHA', installer.digest(native.read_bytes()))]:
            p = patch.object(installer, name, value); p.start(); self.addCleanup(p.stop)
        self.calls = []
        self.preflight = patch.object(installer, 'native_preflight', return_value=1812).start()
        self.addCleanup(patch.stopall)
        patch.object(installer, 'service_pid', side_effect=lambda name: '77' if 'radius' in name else '99').start()
        patch.object(installer, 'listener', return_value='88').start()
        self.cmd = patch.object(installer, 'command', side_effect=self.command).start()

    def command(self, *args, **kwargs):
        self.calls.append(args); return types.SimpleNamespace(stdout='', returncode=0)

    def test_native_parse_precedes_changes_and_only_radius_restarts(self):
        def preflight(ip):
            self.assertEqual(self.old, installer.WORKER.read_bytes())
            self.assertFalse(installer.DROPIN.exists()); return 1812
        self.preflight.side_effect = preflight
        result = installer.activate()
        self.assertTrue(result['verified']); self.assertTrue(result['radius_restarted'])
        self.assertEqual(self.new, installer.WORKER.read_bytes()); self.assertEqual(self.base, installer.UNIT.read_bytes())
        self.assertIn(b'--access-events', installer.DROPIN.read_bytes())
        self.assertEqual(0o600, installer.WORKER.stat().st_mode & 0o777)
        self.assertEqual([('/usr/bin/systemctl', 'daemon-reload'),
                          ('/usr/bin/systemctl', 'restart', 'authwire-radius.service')], self.calls)
        self.assertTrue((Path(result['evidence']) / 'finished.json').exists())

    def test_pinned_worker_migration_adds_only_user_and_access_volatility(self):
        for already_access in (False, True):
            old = installer.BACKUP_CHANGE[0] + b", 'device_challenges', 'device_rate', 'fixture'}\n"
            if already_access: old=old.replace(*installer.BACKUP_CHANGE,1)
            new=old.replace(*installer.BACKUP_CHANGE,1).replace(*installer.USER_BACKUP_CHANGE,1)
            installer.WORKER.write_bytes(old)
            (installer.SOURCE/'tools/scheduled_backup.py').write_bytes(new)
            checker=installer.WORKER.parent/'offline_restore_check.py'
            installer.RELEASE.write_text(json.dumps({'scheduled_backup.py':installer.digest(old),'offline_restore_check.py':installer.digest(checker.read_bytes())}))
            key='ACCESS_WORKER_SHA' if already_access else 'OLD_WORKER_SHA'
            with patch.object(installer,key,installer.digest(old)):
                result=installer.activate()
            self.assertTrue(result['verified']);self.assertEqual(new,installer.WORKER.read_bytes())

    def test_bad_native_preflight_never_changes_worker_unit_or_running_service(self):
        self.preflight.side_effect = ValueError('native rejected')
        with self.assertRaises(ValueError): installer.activate()
        self.assertEqual(self.old, installer.WORKER.read_bytes()); self.assertFalse(installer.DROPIN.exists())
        self.assertEqual([], self.calls)

    def test_failed_restart_restores_before_files_and_starts_original_generator(self):
        failures = 0
        def command(*args, **kwargs):
            nonlocal failures
            self.command(*args, **kwargs)
            if 'restart' in args:
                failures += 1
                if failures == 1: raise subprocess.CalledProcessError(1, args)
            return types.SimpleNamespace(stdout='', returncode=0)
        self.cmd.side_effect = command
        with self.assertRaises(subprocess.CalledProcessError): installer.activate()
        self.assertEqual(2, failures); self.assertFalse(installer.DROPIN.exists())
        self.assertEqual(self.old, installer.WORKER.read_bytes()); self.assertEqual(self.release, installer.RELEASE.read_bytes())
        self.assertEqual(self.base, installer.UNIT.read_bytes()); self.assertEqual(0o600, installer.WORKER.stat().st_mode & 0o777)
        evidence = next(installer.EVIDENCE_ROOT.glob('access-history-*'))
        self.assertTrue(json.loads((evidence / 'rollback.json').read_text())['restored'])

    def test_unknown_override_and_unreviewed_backup_change_are_refused(self):
        installer.DROPIN.parent.mkdir(); installer.DROPIN.write_text('[Service]\nCustom=yes\n')
        with self.assertRaisesRegex(ValueError, 'UNEXPECTED_ACCESS_HISTORY_OVERRIDE'): installer.activate()
        installer.DROPIN.unlink()
        (installer.SOURCE / 'tools/scheduled_backup.py').write_bytes(self.new + b'# extra unreviewed change')
        with self.assertRaisesRegex(ValueError, 'UNEXPECTED_BACKUP_WORKER_CHANGE'): installer.activate()
        self.assertEqual([], self.calls)


if __name__ == '__main__': unittest.main()
