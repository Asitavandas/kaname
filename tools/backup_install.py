"""Install only the pinned private backup worker and timer; preserve live access."""
import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import stat
import subprocess
import sys
import tempfile

TARGET = Path('/opt/authwire-backup')
SERVICE = Path('/etc/systemd/system/authwire-backup.service')
TIMER = Path('/etc/systemd/system/authwire-backup.timer')
LOCK = Path('/run/kaname-lab-update.lock')
PYTHON = Path('/opt/kaname-lab/venv/bin/python')
FILES = ('scheduled_backup.py', 'offline_restore_check.py')
PHASE = 'preflight'


def service_text():
    return '''[Unit]
Description=Create and verify a private AuthWire backup
After=local-fs.target systemd-tmpfiles-setup.service

[Service]
Type=oneshot
User=root
Group=root
ExecStart=/opt/kaname-lab/venv/bin/python -I -B /opt/authwire-backup/scheduled_backup.py --keep 14
UMask=0077
Nice=15
IOSchedulingClass=idle
CPUWeight=10
IOWeight=10
NoNewPrivileges=yes
PrivateTmp=yes
PrivateDevices=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=/var/backups/authwire
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectControlGroups=yes
ProtectKernelLogs=yes
ProtectClock=yes
ProtectHostname=yes
RestrictSUIDSGID=yes
RestrictNamespaces=yes
LockPersonality=yes
RestrictRealtime=yes
RestrictAddressFamilies=AF_UNIX
CapabilityBoundingSet=CAP_DAC_READ_SEARCH
SystemCallArchitectures=native
TimeoutStartSec=600
'''


def timer_text():
    return '''[Unit]
Description=Daily private AuthWire backup

[Timer]
OnCalendar=*-*-* 03:15:00 Europe/Istanbul
RandomizedDelaySec=300
AccuracySec=30s
Persistent=yes
Unit=authwire-backup.service

[Install]
WantedBy=timers.target
'''


def trusted(path, directory=False):
    info = path.lstat()
    if (not (stat.S_ISDIR(info.st_mode) if directory else stat.S_ISREG(info.st_mode))
            or info.st_uid != 0 or info.st_mode & 0o022):
        raise ValueError('Root-owned protected installation path required')


def command(*args):
    return subprocess.run(list(args), text=True, capture_output=True, check=True, timeout=650)


def namespace(data, path):
    ns = {'__name__': 'pinned_backup_tool', '__file__': str(path)}
    exec(compile(data, str(path), 'exec'), ns); return ns


def load_package(stage, manifest_sha256):
    if not re.fullmatch('[a-f0-9]{64}', manifest_sha256): raise ValueError('Package manifest digest required')
    data = (stage / 'manifest.json').read_bytes()
    if hashlib.sha256(data).hexdigest() != manifest_sha256: raise ValueError('Package manifest differs')
    expected = json.loads(data)
    if type(expected) is not dict or set(expected) != set(FILES): raise ValueError('Unexpected package members')
    result = {}
    for name in FILES:
        value = (stage / name).read_bytes()
        if hashlib.sha256(value).hexdigest() != expected[name]: raise ValueError('Package source differs')
        compile(value, name, 'exec'); result[name] = value
    return result


def protected_snapshot(worker):
    paths = [Path('/etc/systemd/system') / name for name in worker['PRODUCT_UNITS']]
    paths += [Path('/opt/authwire-radius/lib/rlm_python3.so'),
              Path('/etc/kaname-lab/web.crt'), Path('/etc/kaname-lab/web.key'),
              Path('/var/lib/kaname-lab/secret-store.key'),
              Path('/var/lib/kaname-lab/radius/server.pem'), Path('/var/lib/kaname-lab/radius/server-key.pem'),
              Path('/opt/authwire-service-control/broker.py'),
              Path('/opt/kaname-lab/source/kaname/device_client/AuthWire-Client.ps1'),
              Path('/opt/kaname-lab/source/kaname/device_client/Install-AuthWire.ps1')]
    hashes = {str(p): worker['digest'](p) for p in paths}
    dbs = [Path('/var/lib/kaname-lab') / name for name in ('kaname.sqlite3', 'administrators.sqlite3')]
    return {'files': hashes, 'business_state': {str(p): worker['db_fingerprint'](p) for p in dbs},
            'pids': worker['pids']()}


def write_new(path, data, mode):
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, mode)
    with os.fdopen(fd, 'wb') as f: f.write(data); f.flush(); os.fsync(f.fileno())


def install(stage, manifest_sha256):
    global PHASE
    if sys.platform != 'linux' or os.geteuid() != 0: raise ValueError('Local sudo required')
    package = load_package(stage, manifest_sha256)
    worker = namespace(package['scheduled_backup.py'], TARGET / 'scheduled_backup.py')
    checker = namespace(package['offline_restore_check.py'], TARGET / 'offline_restore_check.py')
    for path in (TARGET.parent, SERVICE.parent): trusted(path, True)
    tmpfiles = Path('/etc/tmpfiles.d/authwire-service-control.conf')
    trusted(tmpfiles)
    if tmpfiles.read_text() != 'f /run/kaname-lab-update.lock 0600 root root -\n':
        raise ValueError('Existing boot-time shared lock setup differs')
    if not PYTHON.is_file(): raise ValueError('Existing AuthWire Python required')
    before = protected_snapshot(worker)
    if any(p == '0' for p in before['pids'].values()): raise ValueError('Pilot services must be active before installation')
    units = [(SERVICE, service_text().encode()), (TIMER, timer_text().encode())]
    release = json.dumps({name: hashlib.sha256(data).hexdigest() for name, data in package.items()}, sort_keys=True, indent=2).encode() + b'\n'
    all_files = {**package, 'release.json': release}
    existing = TARGET.exists() or TARGET.is_symlink()
    if existing:
        trusted(TARGET, True)
        if set(p.name for p in TARGET.iterdir()) != set(all_files): raise ValueError('Existing backup installation differs')
        for name, data in all_files.items():
            trusted(TARGET / name)
            if (TARGET / name).read_bytes() != data: raise ValueError('Existing backup source differs')
    for path, data in units:
        if path.exists() or path.is_symlink():
            trusted(path)
            if path.read_bytes() != data: raise ValueError('Existing backup unit differs')
    created = []; new_target = False
    descriptor = os.open(LOCK, os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
    try:
        trusted(LOCK); fcntl.flock(descriptor, fcntl.LOCK_EX | fcntl.LOCK_NB)
        PHASE = 'new_feature_files'
        target = worker['prepare_directory']()
        if not existing:
            TARGET.mkdir(mode=0o755); new_target = True
            for name, data in all_files.items(): write_new(TARGET / name, data, 0o644)
        for path, data in units:
            if not path.exists(): write_new(path, data, 0o644); created.append(path)
        command('systemd-analyze', 'verify', str(SERVICE), str(TIMER))
        command('systemd-analyze', 'calendar', '*-*-* 03:15:00 Europe/Istanbul')
        command('systemctl', 'daemon-reload')
        # The worker uses a shared update lock. Release our installation lock first.
        fcntl.flock(descriptor, fcntl.LOCK_UN)
        PHASE = 'first_backup'
        command('systemctl', 'start', SERVICE.name)
        record = json.loads((target / 'last-run.json').read_text())
        if record.get('event') != 'BACKUP_SUCCESS' or record.get('producer') != worker['PRODUCER']:
            raise ValueError('First backup did not pass')
        archive = Path(record['backup'])
        if archive.parent != target or not worker['NAME'].fullmatch(archive.name): raise ValueError('Unexpected first backup path')
        PHASE = 'initial_data_restore'
        evidence = checker['check'](archive, record['sha256'], Path('/var/lib/authwire-restore-checks'))
        worker['atomic_json'](target / 'initial-restore-check.json', {**evidence, 'backup': str(archive), 'checked_utc': worker['utc']()})
        PHASE = 'preservation_before_enable'
        if protected_snapshot(worker) != before: raise ValueError('Protected live state or processes changed')
        PHASE = 'timer_enable'
        command('systemctl', 'enable', '--now', TIMER.name)
        command('systemctl', 'is-enabled', '--quiet', TIMER.name)
        command('systemctl', 'is-active', '--quiet', TIMER.name)
        if protected_snapshot(worker) != before: raise ValueError('Protected live state or processes changed')
        return {'event': 'BACKUP_TIMER_INSTALLED', 'verified': True, 'timer_enabled': True,
                'timer_active': True, 'timezone': 'Europe/Istanbul', 'daily_time': '03:15',
                'maximum_random_delay_seconds': 300, 'keep_successful': worker['KEEP'],
                'first_backup': record, 'initial_data_restore': evidence,
                'protected_state_preserved': True, 'product_processes_preserved': True,
                'manual_backups_changed': False, 'off_host_copy_configured': False}
    except Exception:
        # Undo only this feature's new installation; never touch an existing product unit/data.
        if created:
            subprocess.run(['systemctl', 'disable', '--now', TIMER.name], capture_output=True, timeout=30)
            for path in created: path.unlink(missing_ok=True)
            subprocess.run(['systemctl', 'daemon-reload'], capture_output=True, timeout=30)
        if new_target: shutil.rmtree(TARGET)
        raise
    finally: os.close(descriptor)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-dir', type=Path, required=True)
    parser.add_argument('--manifest-sha256', required=True)
    args = parser.parse_args()
    try:
        print(json.dumps(install(args.source_dir, args.manifest_sha256))); return 0
    except Exception as error:
        print(json.dumps({'event': 'BACKUP_INSTALL_FAILED', 'phase': PHASE, 'category': type(error).__name__,
                          'exit_code': getattr(error, 'returncode', None)})); return 1


if __name__ == '__main__': raise SystemExit(main())
