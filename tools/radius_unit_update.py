"""Remove panel stop propagation without altering RADIUS authentication settings."""
import argparse
import fcntl
import json
import os
from pathlib import Path
import stat
import subprocess
import sys
import tempfile

UNIT = Path('/etc/systemd/system/authwire-radius.service')
BACKUPS = Path('/var/backups/authwire-radius-unit')
LOCK = Path('/run/kaname-lab-update.lock')
_PHASE = 'preflight'


def migrate_unit(text):
    if len(text) > 32768 or text.count('[Unit]\n') != 1 or text.count('[Service]\n') != 1:
        raise ValueError('Unexpected RADIUS unit layout')
    header = text.split('[Unit]\n', 1)[1].split('[Service]\n', 1)[0]
    fields = {}
    for line in header.splitlines():
        if '=' in line and not line.lstrip().startswith(('#', ';')):
            name, value = line.split('=', 1)
            fields.setdefault(name, []).extend(value.split())
    if fields.get('BindsTo') or fields.get('PartOf'):
        raise ValueError('Additional RADIUS stop dependency refused')
    if fields.get('After') != ['network-online.target', 'kaname-lab.service']:
        raise ValueError('Unexpected RADIUS startup order')
    required = fields.get('Requires', [])
    if not required:
        if set(fields.get('Wants', [])) != {'network-online.target', 'kaname-lab.service'}:
            raise ValueError('Unexpected RADIUS startup dependencies')
        return text, False
    if required != ['kaname-lab.service'] or fields.get('Wants') != ['network-online.target']:
        raise ValueError('Unexpected RADIUS stop dependency')
    if text.count('Requires=kaname-lab.service\n') != 1:
        raise ValueError('Ambiguous RADIUS dependency line')
    return text.replace('Requires=kaname-lab.service\n', 'Wants=kaname-lab.service\n', 1), True


def protected(path, directory=False):
    if path.is_symlink() or not (path.is_dir() if directory else path.is_file()):
        raise ValueError('Unsafe installed path')
    identity = path.stat()
    if identity.st_uid != 0 or identity.st_mode & 0o022:
        raise ValueError('Root-owned protected path required')


def command(*args):
    return subprocess.run(list(args), check=True, capture_output=True, timeout=30)


def active():
    result = subprocess.run(['systemctl', 'is-active', '--quiet', 'authwire-radius.service'],
                            capture_output=True, timeout=10)
    if result.returncode not in (0, 3, 4):
        raise ValueError('RADIUS state could not be read')
    return result.returncode == 0


def pid():
    value = command('systemctl', 'show', 'authwire-radius.service',
                    '--property=MainPID', '--value').stdout.decode().strip()
    if not value.isdecimal() or int(value) == 0:
        raise ValueError('RADIUS process not present')
    return value


def atomic(data, mode):
    descriptor, name = tempfile.mkstemp(prefix='.authwire-unit-', dir=UNIT.parent)
    temporary = Path(name)
    try:
        with os.fdopen(descriptor, 'wb') as handle:
            handle.write(data)
            handle.flush()
            os.fsync(handle.fileno())
            os.fchmod(handle.fileno(), mode)
        os.replace(temporary, UNIT)
    finally:
        temporary.unlink(missing_ok=True)


def _update(start_if_inactive=False):
    global _PHASE
    protected(UNIT.parent, directory=True)
    protected(UNIT)
    old = UNIT.read_bytes()
    new, changed = migrate_unit(old.decode())
    if command('systemctl', 'show', 'authwire-radius.service',
               '--property=DropInPaths', '--value').stdout.strip():
        raise ValueError('RADIUS unit overrides require separate review')
    was_active = active()
    previous_pid = pid() if was_active else None
    backup_created = False
    if changed:
        _PHASE = 'backup'
        protected(BACKUPS.parent, directory=True)
        BACKUPS.mkdir(mode=0o700, exist_ok=True)
        protected(BACKUPS, directory=True)
        if BACKUPS.stat().st_mode & 0o077:
            raise ValueError('Private unit backup directory required')
        descriptor, name = tempfile.mkstemp(prefix='radius-', suffix='.service', dir=BACKUPS)
        with os.fdopen(descriptor, 'wb') as handle:
            handle.write(old)
        backup_created = True
        mode = stat.S_IMODE(UNIT.stat().st_mode)
        try:
            _PHASE = 'unit_update'
            atomic(new.encode(), mode)
            command('systemd-analyze', 'verify', str(UNIT))
            command('systemctl', 'daemon-reload')
            _PHASE = 'dependency_check'
            dependencies = command('systemctl', 'show', 'authwire-radius.service',
                                   '--property=Requires,BindsTo,PartOf', '--value').stdout.decode().split()
            if 'kaname-lab.service' in dependencies:
                raise ValueError('Panel stop propagation is still present')
            if was_active and (not active() or pid() != previous_pid):
                raise ValueError('Running RADIUS process changed')
        except BaseException:
            atomic(old, mode)
            command('systemctl', 'daemon-reload')
            raise
    _PHASE = 'service_restore'
    started = False
    if start_if_inactive and not active():
        command('systemctl', 'start', 'authwire-radius.service')
        started = True
        if not active():
            raise ValueError('RADIUS service did not start')
        pid()
    return {'updated': True, 'unit_changed': changed, 'backup_created': backup_created,
            'panel_stop_dependency_removed': True, 'radius_started': started,
            'service_active': active(),
            'running_process_preserved': True if was_active else None,
            'configuration_changed': False, 'certificates_changed': False,
            'policy_changed': False, 'native_module_changed': False, 'windows_changed': False}


def update(start_if_inactive=False):
    if os.geteuid() != 0 or sys.platform != 'linux':
        raise ValueError('Local Linux sudo required')
    descriptor = os.open(LOCK, os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW, 0o600)
    with os.fdopen(descriptor, 'r+') as handle:
        identity = os.fstat(handle.fileno())
        if (not stat.S_ISREG(identity.st_mode) or identity.st_uid != 0 or identity.st_nlink != 1
                or identity.st_mode & 0o077):
            raise ValueError('Private upgrade lock required')
        fcntl.flock(handle.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        return _update(start_if_inactive)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--start-if-inactive', action='store_true')
    args = parser.parse_args()
    try:
        print(json.dumps(update(args.start_if_inactive)))
        return 0
    except Exception as error:
        print(json.dumps({'updated': False, 'error': 'RADIUS_UNIT_UPDATE_FAILED',
                          'phase': _PHASE, 'category': type(error).__name__}))
        return 1


if __name__ == '__main__':
    sys.exit(main())
