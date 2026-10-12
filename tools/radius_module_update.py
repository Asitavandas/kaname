"""Verified, atomic backport of the pinned native Python module; rollback on failure.

No application state, CA, certificates, policies, unit settings or other native
binaries are changed. The existing RADIUS service is restored to its prior state.
This launcher is stdlib-only and never imports runner-owned application code.
"""
import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import stat
import subprocess
import sys
import tempfile

PRODUCT = Path('/opt/authwire-radius')
UNIT = Path('/etc/systemd/system/authwire-radius.service')
BACKUPS = Path('/var/backups/authwire-radius-native')
LOCK = Path('/run/kaname-lab-update.lock')
MODULE = 'lib/rlm_python3.so'
MANIFEST = 'RADIUS_RUNTIME_MANIFEST.json'
COMMIT = '9071ea041b9172e52eabbba91619afaf3a238795'
PATCHES = ['58bafac6e5d4eb098d533cc0e7fe2fd41a73d213']
_PHASE = 'preflight'


def platform_check():
    if os.geteuid() != 0 or sys.platform != 'linux':
        raise ValueError('Local Linux sudo required')
    release = Path('/etc/os-release').read_text()
    if 'ID=ubuntu' not in release or 'VERSION_ID="24.04"' not in release:
        raise ValueError('Ubuntu 24.04 required')


def protected(path, *, directory=False):
    if path.is_symlink() or not (path.is_dir() if directory else path.is_file()):
        raise ValueError('Unsafe installed path')
    identity = path.stat()
    if identity.st_uid != 0 or identity.st_mode & 0o022:
        raise ValueError('Installed path must be protected and root owned')


def staged_module(source, digest):
    if not re.fullmatch(r'[0-9a-f]{64}', digest):
        raise ValueError('Expected runtime digest required')
    source = Path(source)
    for path in (source, source/'lib', source/MANIFEST, source/MODULE):
        if path.is_symlink():
            raise ValueError('Staged symlink refused')
    path = source/MANIFEST
    if not path.is_file() or path.stat().st_size > 2_000_000:
        raise ValueError('Invalid staged manifest')
    raw = path.read_bytes()
    if hashlib.sha256(raw).hexdigest() != digest:
        raise ValueError('Runtime manifest changed')
    manifest = json.loads(raw)
    if (set(manifest) != {'artifact','upstream_commit','upstream_patches','files'}
            or manifest['artifact'] != 'authwire-freeradius-runtime'
            or manifest['upstream_commit'] != COMMIT or manifest['upstream_patches'] != PATCHES
            or type(manifest['files']) is not dict):
        raise ValueError('Unexpected patched runtime')
    row = manifest['files'].get(MODULE)
    if (type(row) is not dict or set(row) != {'sha256','mode'}
            or type(row['mode']) is not int or row['mode'] != 0o755
            or not re.fullmatch(r'[0-9a-f]{64}', row['sha256'])):
        raise ValueError('Invalid patched module metadata')
    path = source/MODULE
    if not path.is_file() or path.stat().st_size > 20_000_000:
        raise ValueError('Invalid patched module file')
    data = path.read_bytes()
    if not data.startswith(b'\x7fELF') or hashlib.sha256(data).hexdigest() != row['sha256']:
        raise ValueError('Patched module changed')
    return data, row


def command(*args, env=None):
    return subprocess.run(list(args), check=True, capture_output=True, timeout=35, env=env)


def active():
    return subprocess.run(['/usr/bin/systemctl','is-active','--quiet','authwire-radius.service'],
                          capture_output=True, timeout=10).returncode == 0


def atomic(path, data, mode):
    descriptor, name = tempfile.mkstemp(prefix='.authwire-native-', dir=path.parent)
    temporary = Path(name)
    try:
        with os.fdopen(descriptor, 'wb') as handle:
            handle.write(data)
            handle.flush()
            os.fsync(handle.fileno())
            os.fchmod(handle.fileno(), mode)
        os.replace(temporary, path)
    finally:
        temporary.unlink(missing_ok=True)


def _update(source, digest):
    global _PHASE
    _PHASE = 'staged_module_verification'
    data, row = staged_module(source, digest)
    _PHASE = 'installed_module_verification'
    for path in (PRODUCT.parent, PRODUCT, PRODUCT/'lib'):
        protected(path, directory=True)
    target, manifest_path = PRODUCT/MODULE, PRODUCT/MANIFEST
    for path in (target, manifest_path, UNIT):
        protected(path)
    if manifest_path.stat().st_size > 2_000_000:
        raise ValueError('Installed manifest too large')
    old_raw, old_data = manifest_path.read_bytes(), target.read_bytes()
    old = json.loads(old_raw)
    if (set(old) not in ({'artifact','upstream_commit','files'},
                        {'artifact','upstream_commit','upstream_patches','files'})
            or old['artifact'] != 'authwire-freeradius-runtime'
            or old['upstream_commit'] != COMMIT or old.get('upstream_patches',[]) not in ([],PATCHES)
            or type(old['files']) is not dict):
        raise ValueError('Unexpected installed runtime')
    old_row = old['files'].get(MODULE)
    if (type(old_row) is not dict or set(old_row) != {'sha256','mode'}
            or old_row['mode'] != stat.S_IMODE(target.stat().st_mode)
            or old_row['sha256'] != hashlib.sha256(old_data).hexdigest()):
        raise ValueError('Installed module differs from its manifest')
    was_active = active()
    if old_data == data and old.get('upstream_patches') == PATCHES:
        return {'updated': True, 'native_module_updated': False, 'already_current': True,
                'service_active': was_active, 'upstream_patch': PATCHES[0]}
    _PHASE = 'backup'
    protected(BACKUPS.parent, directory=True)
    BACKUPS.mkdir(mode=0o700, parents=False, exist_ok=True)
    protected(BACKUPS, directory=True)
    if BACKUPS.stat().st_mode & 0o077:
        raise ValueError('Private native backup directory required')
    backup = Path(tempfile.mkdtemp(prefix='python3-', dir=BACKUPS))
    (backup/'rlm_python3.so').write_bytes(old_data)
    (backup/MANIFEST).write_bytes(old_raw)
    for path in backup.iterdir():
        path.chmod(0o600)
    descriptor, candidate_name = tempfile.mkstemp(prefix='.authwire-native-candidate-', dir=target.parent)
    candidate = Path(candidate_name)
    stopped = swapped = False
    try:
        with os.fdopen(descriptor, 'wb') as handle:
            handle.write(data)
            handle.flush()
            os.fsync(handle.fileno())
            os.fchmod(handle.fileno(), row['mode'])
        _PHASE = 'dependency_check'
        result = command('/usr/bin/ldd', str(candidate), env={
            'PATH':'/usr/sbin:/usr/bin:/sbin:/bin', 'LD_LIBRARY_PATH':str(PRODUCT/'lib')})
        if b'not found' in result.stdout or b'not found' in result.stderr:
            raise ValueError('Patched module dependency missing')
        _PHASE = 'service_stop'
        command('/usr/bin/systemctl','stop','authwire-radius.service')
        stopped = True
        _PHASE = 'module_swap'
        os.replace(candidate, target)
        swapped = True
        old['files'][MODULE] = row
        old['upstream_patches'] = PATCHES
        atomic(manifest_path, json.dumps(old, sort_keys=True, separators=(',',':')).encode(), 0o644)
        _PHASE = 'service_restore'
        if was_active:
            command('/usr/bin/systemctl','start','authwire-radius.service')
            if not active():
                raise RuntimeError('Updated service did not start')
    except BaseException:
        _PHASE = 'rollback'
        if swapped:
            command('/usr/bin/systemctl','stop','authwire-radius.service')
            atomic(target, old_data, old_row['mode'])
            atomic(manifest_path, old_raw, 0o644)
        if stopped and was_active:
            command('/usr/bin/systemctl','start','authwire-radius.service')
        raise
    finally:
        candidate.unlink(missing_ok=True)
    return {'updated': True, 'native_module_updated': True, 'backup_created': True,
            'service_active': was_active, 'upstream_commit': COMMIT,
            'upstream_patch': PATCHES[0], 'module_sha256': row['sha256'],
            'configuration_changed': False, 'certificates_changed': False,
            'policy_changed': False, 'windows_changed': False}


def update(source, digest):
    platform_check()
    descriptor = os.open(LOCK, os.O_RDWR|os.O_CREAT|os.O_NOFOLLOW, 0o600)
    with os.fdopen(descriptor, 'r+') as lock:
        identity = os.fstat(lock.fileno())
        if (not stat.S_ISREG(identity.st_mode) or identity.st_uid != 0
                or identity.st_nlink != 1 or identity.st_mode & 0o077):
            raise ValueError('Private root-owned update lock required')
        fcntl.flock(lock.fileno(), fcntl.LOCK_EX|fcntl.LOCK_NB)
        return _update(source, digest)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--runtime-source', required=True)
    parser.add_argument('--runtime-digest', required=True)
    args = parser.parse_args()
    def interrupted(signum, frame):
        raise InterruptedError('Native update interrupted')
    signal.signal(signal.SIGTERM, interrupted)
    try:
        print(json.dumps(update(args.runtime_source, args.runtime_digest)))
        return 0
    except Exception as error:
        print(json.dumps({'updated': False, 'error':'NATIVE_MODULE_UPDATE_FAILED',
                          'stage':_PHASE, 'category':type(error).__name__}))
        return 1


if __name__ == '__main__':
    sys.exit(main())
