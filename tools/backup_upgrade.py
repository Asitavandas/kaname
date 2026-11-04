"""Pinned local backup-worker upgrade with atomic source exchange and retained evidence.

This does not update AuthWire, start RADIUS, restore a live database, or prune backups.
An interrupted/uncertain operation deliberately blocks the next upgrade.
"""
import argparse
from contextlib import contextmanager
import ctypes
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import sys
import uuid

TARGET = Path('/opt/authwire-backup')
OPERATIONS = Path('/opt/authwire-backup-upgrades')
SCHEDULED = Path('/var/backups/authwire/scheduled')
UPDATE_LOCK = Path('/run/kaname-lab-update.lock')
UNIT_ROOT = Path('/etc/systemd/system')
FILES = ('scheduled_backup.py', 'offline_restore_check.py')
UNIT_HASHES = {
    'authwire-backup.service': '4f02c3efc98d16179da972766a1106c7a715a7312db378f246f9947a87f8a254',
    'authwire-backup.timer': '33caa5d7c1da4989cb6913724860d5701dbda5ff86381b8ba68dec570f4cea49',
}
ACK = 'upgrade_observed_backup_worker_preserve_archives_and_service_state'


class Refused(ValueError):
    pass


class RequiresReview(RuntimeError):
    pass


def sha(data):
    return hashlib.sha256(data).hexdigest()


def pin(value):
    if type(value) is not str or not re.fullmatch('[a-f0-9]{64}', value):
        raise Refused('SHA256 pin required')
    return value


def pairs(items):
    result = {}
    for key, value in items:
        if key in result:
            raise Refused('Duplicate JSON member')
        result[key] = value
    return result


def decode(data):
    return json.loads(data, object_pairs_hook=pairs)


def protected(path, directory=False):
    info = path.lstat()
    kind = stat.S_ISDIR if directory else stat.S_ISREG
    if (not kind(info.st_mode) or info.st_uid != 0 or info.st_gid != 0
            or info.st_mode & 0o7022 or (not directory and info.st_nlink != 1)):
        raise Refused('Protected root-owned path required')
    return info


def parents(path):
    for parent in reversed(path.absolute().parents):
        protected(parent, True)


def read(path, limit=2 * 1024 * 1024):
    protected(path)
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW)
    with os.fdopen(fd, 'rb') as stream:
        info = os.fstat(stream.fileno())
        if (not stat.S_ISREG(info.st_mode) or info.st_uid != 0 or info.st_gid != 0
                or info.st_mode & 0o7022 or info.st_nlink != 1 or info.st_size > limit):
            raise Refused('Protected bounded regular file required')
        data = stream.read(limit + 1)
    if len(data) > limit:
        raise Refused('File exceeds bound')
    return data


def hashes(data):
    value = decode(data)
    if type(value) is not dict or set(value) != set(FILES):
        raise Refused('Unexpected package members')
    return {name: pin(value[name]) for name in FILES}


def package(stage, expected):
    parents(stage); protected(stage, True)
    if set(p.name for p in stage.iterdir()) != {*FILES, 'manifest.json'}:
        raise Refused('Unexpected stage entries')
    manifest = read(stage / 'manifest.json', 4096)
    if sha(manifest) != pin(expected):
        raise Refused('Candidate manifest pin differs')
    wanted = hashes(manifest)
    result = {}
    for name in FILES:
        data = read(stage / name)
        if sha(data) != wanted[name]:
            raise Refused('Candidate source differs')
        compile(data, name, 'exec')
        result[name] = data
    result['release.json'] = (json.dumps(wanted, sort_keys=True, indent=2) + '\n').encode()
    return result


def installed(path, expected=None):
    parents(path); info = protected(path, True)
    if set(p.name for p in path.iterdir()) != {*FILES, 'release.json'}:
        raise Refused('Unexpected installed entries')
    release = read(path / 'release.json', 4096)
    if expected is not None and sha(release) != pin(expected):
        raise Refused('Installed release pin differs')
    wanted = hashes(release)
    members = {}
    for name in (*FILES, 'release.json'):
        data = read(path / name)
        if name in wanted and sha(data) != wanted[name]:
            raise Refused('Installed source differs')
        item = protected(path / name)
        members[name] = (sha(data), item.st_dev, item.st_ino, stat.S_IMODE(item.st_mode))
    return {'release_sha256': sha(release), 'directory': (info.st_dev, info.st_ino, stat.S_IMODE(info.st_mode)),
            'files': members}


def command(*args):
    return subprocess.run(args, check=True, text=True, capture_output=True, timeout=30).stdout


def unit(name):
    path = UNIT_ROOT / name
    parents(path)
    if sha(read(path, 16384)) != UNIT_HASHES[name]:
        raise Refused('Backup unit differs')
    output = command('systemctl', 'show', name, '--no-pager',
                     '--property=LoadState,FragmentPath,DropInPaths,ActiveState,SubState,UnitFileState')
    value = dict(line.split('=', 1) for line in output.splitlines() if '=' in line)
    if (value.get('LoadState') != 'loaded' or value.get('FragmentPath') != str(path)
            or value.get('DropInPaths') != '' or value.get('UnitFileState') not in ('enabled', 'disabled', 'static')):
        raise Refused('Unexpected effective backup unit')
    allowed = ('active', 'inactive') if name.endswith('.timer') else ('inactive', 'failed')
    if value.get('ActiveState') not in allowed:
        raise Refused('Backup unit is busy or transitional')
    return value


def units():
    return {name: unit(name) for name in UNIT_HASHES}


@contextmanager
def lock(path):
    parents(path); protected(path)
    fd = os.open(path, os.O_RDWR | os.O_NOFOLLOW)
    try:
        info = os.fstat(fd)
        if (not stat.S_ISREG(info.st_mode) or info.st_uid or info.st_gid
                or info.st_nlink != 1 or stat.S_IMODE(info.st_mode) != 0o600):
            raise Refused('Private coordination lock required')
        fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        yield
    finally:
        os.close(fd)


def sync(path):
    fd = os.open(path, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)


def write(path, data, mode=0o600):
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, mode)
    with os.fdopen(fd, 'wb') as stream:
        os.fchmod(stream.fileno(), mode)
        stream.write(data); stream.flush(); os.fsync(stream.fileno())
    sync(path.parent)


def record(path, value):
    write(path, (json.dumps(value, sort_keys=True, indent=2) + '\n').encode())


def exchange(left, right):
    """Atomic Linux exchange; never leave TARGET absent, including on fsync failure."""
    libc = ctypes.CDLL(None, use_errno=True)
    fn = libc.renameat2
    fn.argtypes = (ctypes.c_int, ctypes.c_char_p, ctypes.c_int, ctypes.c_char_p, ctypes.c_uint)
    fn.restype = ctypes.c_int
    descriptors = []
    try:
        for path in (left.parent, right.parent):
            descriptors.append(os.open(path, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW))
        if fn(descriptors[0], os.fsencode(left.name), descriptors[1], os.fsencode(right.name), 2):
            raise OSError(ctypes.get_errno(), 'Atomic directory exchange failed')
        for fd in descriptors:
            os.fsync(fd)
    finally:
        for fd in descriptors:
            os.close(fd)


def archives():
    """Observe existing scheduled files without reading huge archive payloads."""
    parents(SCHEDULED); protected(SCHEDULED, True)
    result = {}
    def visit(path, depth):
        if depth > 8 or len(result) >= 10000:
            raise Refused('Scheduled inventory exceeds bound')
        item = path.lstat()
        if not (stat.S_ISREG(item.st_mode) or stat.S_ISDIR(item.st_mode) or stat.S_ISLNK(item.st_mode)):
            raise Refused('Unexpected scheduled inventory entry')
        value = [item.st_dev, item.st_ino, item.st_uid, item.st_gid, item.st_mode,
                 item.st_size, item.st_mtime_ns, item.st_ctime_ns]
        if stat.S_ISLNK(item.st_mode):
            value.append(os.readlink(path))
        elif stat.S_ISREG(item.st_mode) and path.name in ('last-run.json', 'last-success.json'):
            value.append(sha(read(path, 1024 * 1024)))
        result[str(path.relative_to(SCHEDULED))] = value
        if stat.S_ISDIR(item.st_mode):
            for child in path.iterdir():
                visit(child, depth + 1)
    visit(SCHEDULED, 0)
    return result


def namespace(data, path):
    value = {'__name__': 'pinned_backup_upgrade_tool', '__file__': str(path)}
    exec(compile(data, str(path), 'exec'), value)
    return value


def live(worker):
    paths = [Path('/etc/systemd/system') / name for name in worker['PRODUCT_UNITS']]
    paths += [Path(name) for name in (
        '/opt/authwire-radius/lib/rlm_python3.so', '/etc/kaname-lab/web.crt', '/etc/kaname-lab/web.key',
        '/var/lib/kaname-lab/secret-store.key', '/var/lib/kaname-lab/radius/server.pem',
        '/var/lib/kaname-lab/radius/server-key.pem', '/opt/authwire-service-control/broker.py',
        '/opt/kaname-lab/source/kaname/device_client/AuthWire-Client.ps1',
        '/opt/kaname-lab/source/kaname/device_client/Install-AuthWire.ps1')]
    return {'files': {str(p): worker['digest'](p) for p in paths},
            'business_state': {name: worker['db_fingerprint'](Path('/var/lib/kaname-lab') / name)
                               for name in ('kaname.sqlite3', 'administrators.sqlite3')},
            'pids': worker['pids']()}


def journal():
    if not OPERATIONS.exists() and not OPERATIONS.is_symlink():
        return
    parents(OPERATIONS); protected(OPERATIONS, True)
    entries = list(OPERATIONS.iterdir())
    if len(entries) >= 64:
        raise RequiresReview('Operation evidence limit reached; review required')
    for path in entries:
        protected(path, True)
        if not re.fullmatch('[a-f0-9]{32}', path.name):
            raise RequiresReview('Unknown operation evidence')
        try:
            intent = decode(read(path / 'intent.json', 16384))
            terminal = decode(read(path / 'terminal.json', 16384))
        except Exception as error:
            raise RequiresReview('Incomplete or uncertain prior operation') from error
        if (type(intent) is not dict or type(terminal) is not dict
                or intent.get('operation') != path.name or terminal.get('operation') != path.name
                or terminal.get('status') not in ('completed', 'rolled_back')
                or terminal.get('from') != intent.get('from') or terminal.get('to') != intent.get('to')):
            raise RequiresReview('Incomplete or uncertain prior operation')
        pin(intent['from']); pin(intent['to'])


def restore_timer(before):
    current = units()
    timer = 'authwire-backup.timer'
    if current == before:
        return
    for name in UNIT_HASHES:
        # Only our active->inactive timer transition may differ.
        expected = dict(before[name])
        if name == timer and before[name]['ActiveState'] == 'active':
            expected['ActiveState'] = 'inactive'; expected['SubState'] = 'dead'
        if current[name] != expected:
            raise RequiresReview('Backup unit state drifted')
    if before[timer]['ActiveState'] == 'active':
        command('systemctl', 'start', timer)
        if unit(timer) != before[timer]:
            raise RequiresReview('Timer state was not restored')


def perform(stage, manifest_sha256, installed_release_sha256, acknowledgment=None, inspect=False):
    if sys.platform != 'linux' or os.geteuid() != 0:
        raise Refused('Local Linux root execution required')
    candidate = package(stage, manifest_sha256)
    old = installed(TARGET, pin(installed_release_sha256))
    journal()
    before_units = units()
    result = {'event': 'BACKUP_UPGRADE_REVIEW', 'from': old['release_sha256'],
              'to': sha(candidate['release.json']), 'live_update_applied': False}
    if inspect:
        return result
    if acknowledgment != ACK:
        raise Refused('Explicit local upgrade acknowledgment required')
    if result['from'] == result['to']:
        return {**result, 'event': 'BACKUP_UPGRADE_ALREADY_CURRENT'}
    worker = namespace(candidate['scheduled_backup.py'], TARGET / 'scheduled_backup.py')
    checker = namespace(candidate['offline_restore_check.py'], TARGET / 'offline_restore_check.py')
    operation = None
    outcome = None
    failure = None
    phase = 'preflight'
    # Match worker.run lock order. A busy worker causes refusal without status writes.
    with lock(SCHEDULED / '.job.lock'), lock(UPDATE_LOCK):
        if installed(TARGET) != old or units() != before_units:
            raise Refused('Preflight state changed')
        journal()
        parents(OPERATIONS)
        if not OPERATIONS.exists():
            OPERATIONS.mkdir(mode=0o700); sync(OPERATIONS.parent)
        protected(OPERATIONS, True)
        if OPERATIONS.stat().st_dev != TARGET.stat().st_dev:
            raise Refused('Atomic source exchange requires the same filesystem')
        operation = OPERATIONS / uuid.uuid4().hex
        operation.mkdir(mode=0o700); sync(OPERATIONS)
        result['operation'] = operation.name
        record(operation / 'intent.json', result)
        staged = operation / 'exchange'
        staged.mkdir(mode=old['directory'][2])
        staged.chmod(old['directory'][2])
        for name, data in candidate.items():
            write(staged / name, data, old['files'][name][3])
        new = installed(staged)
        before_live = live(worker)
        before_archives = archives()
        record(operation / 'before.json', {'live': before_live, 'scheduled': before_archives,
                                           'units': before_units, 'old': old, 'new': new})
        try:
            phase = 'timer_pause'
            if before_units['authwire-backup.timer']['ActiveState'] == 'active':
                command('systemctl', 'stop', 'authwire-backup.timer')
            if installed(TARGET) != old or installed(staged) != new:
                raise Refused('Source changed before exchange')
            # Check the timer transition before changing any source.
            current = units()
            expected = {name: dict(value) for name, value in before_units.items()}
            if expected['authwire-backup.timer']['ActiveState'] == 'active':
                expected['authwire-backup.timer'].update(ActiveState='inactive', SubState='dead')
            if current != expected:
                raise RequiresReview('Backup unit state drifted')
            phase = 'source_exchange'
            exchange(TARGET, staged)
            if installed(TARGET) != new or installed(staged) != old:
                raise RequiresReview('Exchange identity differs')
            probe = operation / 'probe'; probe.mkdir(mode=0o700)
            phase = 'maintenance_capture'
            backup = worker['capture'](probe, 14)
            phase = 'isolated_restore'
            restored = checker['check'](Path(backup['backup']), backup['sha256'], operation / 'restore')
            if restored.get('data_restore_exercised') is not True:
                raise Refused('Isolated data restore not verified')
            phase = 'preservation'
            if (installed(TARGET) != new or installed(staged) != old
                    or live(worker) != before_live or archives() != before_archives):
                raise RequiresReview('Protected state changed')
            record(operation / 'verified.json', {'operation': operation.name,
                   'backup_sha256': backup['sha256'], 'isolated_data_restore_verified': True,
                   'scheduled_archives_and_status_preserved': True, 'product_state_and_pids_preserved': True,
                   'full_appliance_boot_restore_tested': False, 'live_hardened_service_tested': False})
            outcome = 'completed'
        except Exception as original:
            failure = {'phase': phase, 'category': type(original).__name__}
            try:
                record(operation / 'failure.json', failure)
            except OSError:
                # An evidence write failure (for example ENOSPC) must not skip
                # source rollback. A missing terminal still blocks the next run.
                pass
            # Re-observe identities even if rename succeeded but fsync raised.
            try:
                active, retained = installed(TARGET), installed(staged)
                if active == new and retained == old:
                    exchange(TARGET, staged)
                elif active != old or retained != new:
                    raise RequiresReview('Unknown source state; no automatic overwrite')
                if (installed(TARGET) != old or installed(staged) != new
                        or live(worker) != before_live or archives() != before_archives):
                    raise RequiresReview('Rollback preservation not verified')
                outcome = 'rolled_back'
            except Exception as error:
                raise RequiresReview('Rollback requires local review; evidence retained') from error
    # Release coordination locks before resuming the original timer. A normal
    # scheduled catch-up may now legitimately change scheduled status/archive files.
    try:
        restore_timer(before_units)
        record(operation / 'terminal.json', {'operation': operation.name, 'status': outcome,
                                            'from': result['from'], 'to': result['to'], 'failure': failure})
    except Exception as error:
        raise RequiresReview('Source evidence retained; timer/finalization requires review') from error
    return {**result, 'event': 'BACKUP_UPGRADE_SUCCESS' if outcome == 'completed' else 'BACKUP_UPGRADE_ROLLED_BACK',
            'live_update_applied': outcome == 'completed', 'timer_state_restored': True,
            'requires_review': False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=('inspect', 'upgrade'))
    parser.add_argument('--source-dir', type=Path, required=True)
    parser.add_argument('--manifest-sha256', required=True)
    parser.add_argument('--installed-release-sha256', required=True)
    parser.add_argument('--acknowledgment')
    args = parser.parse_args()
    try:
        result = perform(args.source_dir, args.manifest_sha256, args.installed_release_sha256,
                         args.acknowledgment, args.action == 'inspect')
        print(json.dumps(result))
        return 0 if result['event'] != 'BACKUP_UPGRADE_ROLLED_BACK' else 2
    except Exception as error:
        review = isinstance(error, RequiresReview)
        try:
            journal()
        except Exception:
            review = True
        print(json.dumps({'event': 'BACKUP_UPGRADE_REFUSED', 'category': type(error).__name__,
                          'requires_review': review}))
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
