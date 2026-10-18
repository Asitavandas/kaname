"""Explicit, reversible activation of tested final-response history.

Does not edit policies, CA material, endpoint scripts, native modules or the
base RADIUS unit. A controlled RADIUS restart is required to load the hooks.
"""
import argparse
import ast
from contextlib import contextmanager
from datetime import datetime, timezone
import fcntl
import hashlib
import json
import os
from pathlib import Path
import pwd
import re
import shutil
import stat
import subprocess
import tempfile
import time
import uuid

SOURCE = Path('/opt/kaname-lab/source')
STATE = Path('/var/lib/kaname-lab')
PREFIX = Path('/opt/authwire-radius')
RUNTIME = Path('/run/authwire-radius')
UNIT = Path('/etc/systemd/system/authwire-radius.service')
DROPIN = Path('/etc/systemd/system/authwire-radius.service.d/30-access-history.conf')
WORKER = Path('/opt/authwire-backup/scheduled_backup.py')
RELEASE = WORKER.parent / 'release.json'
LOCK = Path('/run/kaname-lab-update.lock')
EVIDENCE_ROOT = Path('/var/backups/authwire')
ACCOUNT = 'kaname-lab'
ROOT_OWNER = 0
OLD_WORKER_SHA = 'fc1f6f3efabf8159dd9edbfab415deb547614b630261b2833c81d739086e020c'
NATIVE_SHA = '00f7b9fec04ddfd6abd3e32ea9c96fe4966ac3309a00ce0225c6c57716a147bb'
BACKUP_CHANGE = (b"VOLATILE = {'audit', 'admin_audit', 'admin_sessions'",
                 b"VOLATILE = {'audit', 'admin_audit', 'access_events', 'admin_sessions'")


class ActivationError(ValueError):
    def __init__(self, code):
        self.code = code
        super().__init__(code)


def digest(data): return hashlib.sha256(data).hexdigest()


def trusted(path):
    info = path.lstat()
    if not stat.S_ISREG(info.st_mode) or info.st_uid != ROOT_OWNER or info.st_mode & 0o022 or info.st_nlink != 1:
        raise ActivationError('UNTRUSTED_INSTALLATION_FILE')
    for parent in path.parents:
        if parent.is_symlink(): raise ActivationError('UNTRUSTED_INSTALLATION_PATH')
    return path.read_bytes()


def atomic(path, data, mode=0o644):
    fd, name = tempfile.mkstemp(prefix='.access-history-', dir=path.parent)
    try:
        with os.fdopen(fd, 'wb') as f:
            f.write(data); f.flush(); os.fsync(f.fileno()); os.fchmod(f.fileno(), mode)
        os.replace(name, path)
        directory = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY)
        try: os.fsync(directory)
        finally: os.close(directory)
    finally:
        try: os.unlink(name)
        except FileNotFoundError: pass


def command(*args, check=True, timeout=45, **kwargs):
    return subprocess.run(list(args), capture_output=True, text=True, check=check, timeout=timeout, **kwargs)


def service_pid(name):
    result = command('/usr/bin/systemctl', 'show', name, '--property=ActiveState,MainPID')
    values = dict(line.split('=', 1) for line in result.stdout.splitlines())
    if values.get('ActiveState') != 'active' or not values.get('MainPID', '').isdecimal() or int(values['MainPID']) == 0:
        raise ActivationError('ACTIVE_SERVICE_REQUIRED')
    return values['MainPID']


def generator_line(unit):
    lines = [line for line in unit.decode().splitlines() if line.startswith('ExecStartPre=')]
    if len(lines) != 1: raise ActivationError('UNEXPECTED_RADIUS_GENERATOR')
    expected = (f'ExecStartPre=/opt/kaname-lab/venv/bin/python -B -m tools.radius_runtime '
                f'--output /run/authwire-radius --prefix /opt/authwire-radius '
                f'--state-dir /var/lib/kaname-lab --listen-ip ')
    if not lines[0].startswith(expected): raise ActivationError('UNEXPECTED_RADIUS_GENERATOR')
    from ipaddress import IPv4Address
    ip = str(IPv4Address(lines[0][len(expected):]))
    return lines[0], ip


def override_text(line):
    return ('[Service]\nExecStartPre=\n' + line + ' --access-events\n').encode()


@contextmanager
def update_lock():
    trusted(LOCK)
    with LOCK.open('rb') as lock:
        fcntl.flock(lock.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        yield


def native_preflight(ip):
    """Generate/parse as the actual unprivileged account; no listener/AD call."""
    account = pwd.getpwnam(ACCOUNT)
    venv = '/opt/kaname-lab/venv/bin/python'
    env = {'PATH': '/usr/sbin:/usr/bin:/sbin:/bin', 'PYTHONNOUSERSITE': '1',
           'PYTHONDONTWRITEBYTECODE': '1', 'LD_LIBRARY_PATH': str(PREFIX / 'lib'),
           'PYTHONPATH': str(SOURCE) + ':/opt/kaname-lab/venv/lib/python3.12/site-packages'}
    with tempfile.TemporaryDirectory(prefix='authwire-access-check-', dir='/run') as temp:
        directory = Path(temp); os.chown(directory, account.pw_uid, account.pw_gid)
        result = command('/usr/sbin/runuser', '-u', ACCOUNT, '--', venv, '-B', '-m', 'tools.radius_runtime',
                         '--output', temp, '--prefix', str(PREFIX), '--state-dir', str(STATE),
                         '--listen-ip', ip, '--access-events', cwd=SOURCE, env=env)
        generated = ast.literal_eval(result.stdout)
        if generated.get('access_events_enabled') is not True:
            raise ActivationError('ACCESS_HISTORY_STARTUP_FAILED')
        command('/usr/sbin/runuser', '-u', ACCOUNT, '--', str(PREFIX / 'sbin/radiusd'), '-XC',
                '-D', str(PREFIX / 'share/freeradius'), '-d', temp, cwd=SOURCE, env=env)
        return generated['authentication_port']


def listener(ip, port, *, observer_required=True):
    # This helper runs as root, while status ownership is deliberately the app's.
    deadline = time.monotonic() + 20
    while time.monotonic() < deadline:
        try:
            pid = service_pid('authwire-radius.service')
            enabled = True
            if observer_required:
                status = RUNTIME / 'observer-status.json'
                info = status.lstat(); account = pwd.getpwnam(ACCOUNT)
                if (not stat.S_ISREG(info.st_mode) or info.st_uid != account.pw_uid or info.st_mode & 0o077
                        or info.st_size > 2048): raise ActivationError('OBSERVER_STATUS_INVALID')
                enabled = json.loads(status.read_text()).get('enabled') is True
            sockets = command('/usr/bin/ss', '-H', '-lun').stdout
            if enabled and any(ip + ':' + str(port) in line.split() for line in sockets.splitlines()):
                return pid
        except (ValueError, OSError, subprocess.SubprocessError): pass
        time.sleep(0.25)
    raise ActivationError('ACCESS_HISTORY_LISTENER_NOT_VERIFIED')


def _restore(path, before, after, mode=0o644):
    current = trusted(path) if path.exists() or path.is_symlink() else None
    if current not in (before, after): raise ActivationError('ROLLBACK_FILE_CHANGED_EXTERNALLY')
    if before is None:
        if current is not None: path.unlink()
    elif current != before: atomic(path, before, mode)


def activate():
    if os.geteuid() != 0: raise ActivationError('LOCAL_SUDO_REQUIRED')
    with update_lock():
        base = trusted(UNIT); line, ip = generator_line(base); drop = override_text(line)
        before_drop = trusted(DROPIN) if DROPIN.exists() or DROPIN.is_symlink() else None
        drop_mode = stat.S_IMODE(DROPIN.stat().st_mode) if before_drop is not None else 0o644
        if before_drop is not None and before_drop != drop: raise ActivationError('UNEXPECTED_ACCESS_HISTORY_OVERRIDE')
        if DROPIN.parent.exists():
            info = DROPIN.parent.lstat()
            if not stat.S_ISDIR(info.st_mode) or info.st_uid != ROOT_OWNER or info.st_mode & 0o022:
                raise ActivationError('UNTRUSTED_OVERRIDE_DIRECTORY')
            for other in DROPIN.parent.glob('*.conf'):
                if other != DROPIN and re.search(rb'^\s*ExecStartPre\s*=', trusted(other), re.M):
                    raise ActivationError('EXISTING_GENERATOR_OVERRIDE')
        native = trusted(PREFIX / 'lib/rlm_python3.so')
        if digest(native) != NATIVE_SHA: raise ActivationError('NATIVE_MODULE_CHANGED')
        before_pid = service_pid('authwire-radius.service')
        broker_pid = service_pid('authwire-service-control.service')
        old_worker = trusted(WORKER); old_release = trusted(RELEASE)
        worker_mode, release_mode = stat.S_IMODE(WORKER.stat().st_mode), stat.S_IMODE(RELEASE.stat().st_mode)
        candidate = trusted(SOURCE / 'tools/scheduled_backup.py'); new_sha = digest(candidate)
        release = json.loads(old_release)
        if (set(release) != {'scheduled_backup.py', 'offline_restore_check.py'} or
                release['scheduled_backup.py'] != digest(old_worker) or
                release['offline_restore_check.py'] != digest(trusted(WORKER.parent / 'offline_restore_check.py'))):
            raise ActivationError('BACKUP_RELEASE_DIFFERS')
        if old_worker != candidate and (digest(old_worker) != OLD_WORKER_SHA or old_worker.replace(*BACKUP_CHANGE, 1) != candidate):
            raise ActivationError('UNEXPECTED_BACKUP_WORKER_CHANGE')
        release['scheduled_backup.py'] = new_sha
        new_release = (json.dumps(release, sort_keys=True, indent=2) + '\n').encode()
        port = native_preflight(ip)
        EVIDENCE_ROOT.mkdir(mode=0o700, parents=True, exist_ok=True)
        info = EVIDENCE_ROOT.lstat()
        if not stat.S_ISDIR(info.st_mode) or info.st_uid != ROOT_OWNER or info.st_mode & 0o077:
            raise ActivationError('PRIVATE_EVIDENCE_DIRECTORY_REQUIRED')
        evidence = EVIDENCE_ROOT / ('access-history-' + datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ') + '-' + uuid.uuid4().hex[:8])
        evidence.mkdir(mode=0o700)
        atomic(evidence / 'backup-worker-before.py', old_worker, 0o600)
        atomic(evidence / 'backup-release-before.json', old_release, 0o600)
        if before_drop is not None: atomic(evidence / 'override-before.conf', before_drop, 0o600)
        writes = restarted = False
        try:
            writes = True
            if old_worker != candidate: atomic(WORKER, candidate, worker_mode)
            if old_release != new_release: atomic(RELEASE, new_release, release_mode)
            DROPIN.parent.mkdir(mode=0o755, exist_ok=True)
            if before_drop != drop: atomic(DROPIN, drop, drop_mode)
            # The base unit and all hardening remain unchanged. Only the
            # pre-start generator receives the explicit observation flag.
            command('/usr/bin/systemctl', 'daemon-reload')
            restarted = True
            command('/usr/bin/systemctl', 'restart', 'authwire-radius.service')
            after_pid = listener(ip, port)
            if trusted(UNIT) != base or trusted(PREFIX / 'lib/rlm_python3.so') != native:
                raise ActivationError('PROTECTED_RADIUS_FILE_CHANGED')
            if service_pid('authwire-service-control.service') != broker_pid:
                raise ActivationError('BROKER_PROCESS_CHANGED')
            result = {'event': 'ACCESS_HISTORY_ACTIVATED', 'verified': True, 'radius_active': True,
                      'radius_restarted': True, 'radius_pid_before': before_pid, 'radius_pid_after': after_pid,
                      'base_unit_preserved': True, 'native_module_preserved': True, 'broker_process_preserved': True,
                      'backup_worker_compatibility_updated': old_worker != candidate,
                      'policy_changed': False, 'certificates_changed': False, 'windows_changed': False,
                      'evidence': str(evidence), 'real_endpoint_acceptance_pending': True}
            atomic(evidence / 'finished.json', (json.dumps(result) + '\n').encode(), 0o600)
            return result
        except Exception:
            restored = False
            if writes:
                _restore(DROPIN, before_drop, drop, drop_mode)
                _restore(WORKER, old_worker, candidate, worker_mode)
                _restore(RELEASE, old_release, new_release, release_mode)
                command('/usr/bin/systemctl', 'daemon-reload')
                if restarted:
                    command('/usr/bin/systemctl', 'restart', 'authwire-radius.service')
                    listener(ip, port, observer_required=before_drop is not None)
                restored = True
            atomic(evidence / 'rollback.json', (json.dumps({'restored': restored, 'radius_restart_attempted': restarted}) + '\n').encode(), 0o600)
            raise


def main():
    parser = argparse.ArgumentParser(description=__doc__); parser.parse_args()
    try: print(json.dumps(activate())); return 0
    except Exception as error:
        # No native config/SQLite/secret/raw subprocess output is printed.
        print(json.dumps({'event': 'ACCESS_HISTORY_ACTIVATION_FAILED', 'category': type(error).__name__, 'guard_code': getattr(error, 'code', None)})); return 1


if __name__ == '__main__': raise SystemExit(main())
