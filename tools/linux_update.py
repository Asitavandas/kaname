"""Local sudo lab upgrade: verified source, stopped-state backup, code rollback.

Preserves existing service, HTTPS identity, administrators, AD secrets and CA.
No packages, DNS, firewall, network devices or RADIUS listeners are changed.
"""
import argparse
import hashlib
import http.client
import json
import os
import re
import shutil
import sqlite3
import ssl
import subprocess
import sys
import tempfile
import time
import uuid
from pathlib import Path, PurePosixPath

PRODUCT = Path('/opt/kaname-lab')
STATE = Path('/var/lib/kaname-lab')
SETTINGS = Path('/etc/kaname-lab')
UNIT = Path('/etc/systemd/system/kaname-lab.service')
_PHASE = 'preflight'


def verified_files(source, expected):
    if not re.fullmatch(r'[0-9a-f]{64}', expected):
        raise ValueError('Expected source digest is required')
    manifest_path = source / 'LINUX_SOURCE_MANIFEST.json'
    if manifest_path.is_symlink() or not manifest_path.is_file() or manifest_path.stat().st_size > 200000:
        raise ValueError('Invalid manifest')
    manifest_bytes = manifest_path.read_bytes()
    if hashlib.sha256(manifest_bytes).hexdigest() != expected:
        raise ValueError('Source manifest changed; nothing installed')
    manifest = json.loads(manifest_bytes)
    if set(manifest) != {'artifact', 'files'} or manifest['artifact'] != 'kaname-linux-lab-source' or type(manifest['files']) is not dict:
        raise ValueError('Invalid source artifact')
    result = {}
    for name, digest in manifest['files'].items():
        relative = PurePosixPath(name)
        if relative.is_absolute() or '..' in relative.parts or not relative.parts or '\\' in name or relative.as_posix() != name:
            raise ValueError('Unsafe source path')
        if relative.parts[0] not in {'kaname', 'tools', 'tests', 'pyproject.toml'}:
            raise ValueError('Unexpected source root')
        path = source
        for part in relative.parts:
            path = path / part
            if path.is_symlink():
                raise ValueError('Source symlink refused')
        if not path.is_file() or path.stat().st_size > 2_000_000:
            raise ValueError('Invalid source file')
        data = path.read_bytes()
        if hashlib.sha256(data).hexdigest() != digest:
            raise ValueError('Source file changed; nothing installed')
        result[name] = data
    if not {'kaname/server.py', 'kaname/__main__.py', 'tools/linux_install.py', 'tools/linux_initialize.py'} <= set(result):
        raise ValueError('Incomplete source')
    return result


def safe_tree(root, *, owner=None):
    if root.is_symlink() or not root.is_dir():
        raise ValueError('Unsafe installed directory')
    for path in [root, *root.rglob('*')]:
        if path.is_symlink() or (not path.is_dir() and not path.is_file()):
            raise ValueError('Unsafe installed path')
        if owner is not None and (path.stat().st_uid != owner or path.stat().st_mode & 0o022):
            raise ValueError('Installed code must be root owned and not writable by others')


def control_digest(root):
    """Read-only local comparison; no rows or password hashes are printed."""
    import hashlib
    result = []
    for name, queries in [('kaname.sqlite3', ['SELECT * FROM state ORDER BY id',
            "SELECT name,payload FROM runtime_settings ORDER BY name"]),
            ('administrators.sqlite3', ['SELECT * FROM admin_users ORDER BY id', 'SELECT * FROM admin_profiles ORDER BY id'])]:
        path = root / name
        with sqlite3.connect(path.as_uri() + '?mode=ro', uri=True) as db:
            for query in queries:
                try: result.append(db.execute(query).fetchall())
                except sqlite3.OperationalError:
                    if 'runtime_settings' not in query: raise
                    result.append([])
    vault = root / 'secret-store.key'
    if vault.exists(): result.append(hashlib.sha256(vault.read_bytes()).hexdigest())
    with sqlite3.connect((root/'kaname.sqlite3').as_uri()+'?mode=ro',uri=True) as db:
        if db.execute("SELECT 1 FROM sqlite_master WHERE name='pki_authority'").fetchone():
            row=db.execute('SELECT root_cert,root_key,issuer_cert,issuer_key FROM pki_authority WHERE id=1').fetchone()
            result.append([hashlib.sha256(value).hexdigest() for value in row] if row else [])
    return hashlib.sha256(json.dumps(result, sort_keys=True).encode()).hexdigest()


def command(*args, cwd=None):
    return subprocess.run(list(args), check=True, capture_output=True, timeout=90, cwd=cwd)


def health(listen, version):
    context = ssl.create_default_context(cafile=str(SETTINGS / 'web.crt'))
    connection = http.client.HTTPSConnection(listen, 8765, context=context, timeout=3)
    try:
        connection.request('GET', '/healthz')
        response = connection.getresponse()
        value = json.loads(response.read(4096))
        return response.status == 200 and value.get('product') == 'KANAME' and value.get('version') == version
    finally: connection.close()


def _update(source, digest):
    global _PHASE
    _PHASE = 'preflight'
    import pwd
    if os.geteuid() != 0 or sys.platform != 'linux':
        raise ValueError('Local Linux sudo required')
    if 'ID=ubuntu' not in Path('/etc/os-release').read_text() or 'VERSION_ID="24.04"' not in Path('/etc/os-release').read_text():
        raise ValueError('Ubuntu 24.04 required')
    # This launcher is stdlib-only; never import mutable runner Python as root.
    _PHASE = 'source_verification'
    files = verified_files(source, digest)
    _PHASE = 'installed_layout'
    if PRODUCT.is_symlink() or not PRODUCT.is_dir() or PRODUCT.stat().st_uid != 0 or PRODUCT.stat().st_mode & 0o022:
        raise ValueError('Root-owned product directory required')
    # A standard venv contains interpreter symlinks; validate mutable source
    # separately rather than rejecting legitimate system Python links.
    _PHASE = 'source_layout'
    safe_tree(PRODUCT/'source', owner=0)
    _PHASE = 'settings_layout'
    safe_tree(SETTINGS)
    identity = pwd.getpwnam('kaname-lab')
    _PHASE = 'state_layout'
    safe_tree(STATE)
    if STATE.stat().st_uid != identity.pw_uid or STATE.stat().st_mode & 0o077:
        raise ValueError('Private installed state required')
    _PHASE = 'service_layout'
    if UNIT.is_symlink() or not UNIT.is_file() or UNIT.stat().st_uid != 0 or UNIT.stat().st_mode & 0o022:
        raise ValueError('Trusted installed service required')
    text = UNIT.read_text()
    listen = re.findall(r'--listen ([0-9.]+) --port 8765', text)
    if len(listen) != 1 or 'User=kaname-lab\n' not in text or 'WorkingDirectory=/opt/kaname-lab/source\n' not in text:
        raise ValueError('Existing lab service layout required')
    import ipaddress
    listen = str(ipaddress.IPv4Address(listen[0]))
    _PHASE = 'version_layout'
    version = re.findall(rb'VERSION = "([0-9A-Za-z.\-]+)"', files['kaname/__init__.py'])
    if len(version) != 1:
        raise ValueError('Source version missing')
    version = version[0].decode('ascii')
    _PHASE = 'service_status'
    active = subprocess.run(['systemctl','is-active','--quiet','kaname-lab.service'], timeout=10).returncode == 0
    if not active:
        raise ValueError('Start or repair the existing panel before upgrading')
    with tempfile.TemporaryDirectory(prefix='source-next-', dir=PRODUCT) as temporary:
        candidate = Path(temporary); candidate.chmod(0o755)
        for name, data in files.items():
            target = candidate / name
            target.parent.mkdir(parents=True, exist_ok=True, mode=0o755)
            target.write_bytes(data); target.chmod(0o644)
        _PHASE = 'dependency_import'
        command('/usr/sbin/runuser','-u','kaname-lab','--',str(PRODUCT/'venv/bin/python'),'-B','-c',
            'import sys;sys.path.insert(0,sys.argv[1]);import kaname.enrollment;import kaname.server',str(candidate),cwd=PRODUCT)
        _PHASE = 'backup_prepare'
        backup = PRODUCT / 'backups' / ('upgrade-' + uuid.uuid4().hex)
        backup.parent.mkdir(mode=0o700, exist_ok=True); backup.mkdir(mode=0o700)
        _PHASE = 'service_stop'
        command('systemctl','stop','kaname-lab.service')
        swapped = False
        try:
            _PHASE = 'state_backup'
            before = control_digest(STATE)
            shutil.copytree(STATE, backup/'state'); (backup/'state').chmod(0o700)
            shutil.copytree(SETTINGS, backup/'settings'); (backup/'settings').chmod(0o700)
            shutil.copy2(UNIT, backup/'kaname-lab.service')
            _PHASE = 'code_swap'
            os.rename(PRODUCT/'source',backup/'source')
            try: os.rename(candidate, PRODUCT/'source')
            except Exception:
                os.rename(backup/'source',PRODUCT/'source'); raise
            swapped = True
            _PHASE = 'service_start'
            command('systemctl','start','kaname-lab.service')
            _PHASE = 'https_health'
            for _ in range(30):
                try:
                    if health(listen, version): break
                except (OSError, ValueError): pass
                time.sleep(0.5)
            else: raise ValueError('Updated HTTPS health check failed')
            _PHASE = 'preservation_check'
            if control_digest(STATE) != before:
                raise ValueError('Configuration/administrator preservation check failed')
        except Exception:
            if swapped:
                command('systemctl','stop','kaname-lab.service')
                os.rename(PRODUCT/'source', backup/'failed-source')
                os.rename(backup/'source', PRODUCT/'source')
            # Additive database changes remain backward compatible; never erase
            # any new operator/AD changes by silently restoring an old database.
            command('systemctl','start','kaname-lab.service')
            raise
    return {'updated': True, 'version':version, 'https_verified':True, 'backup_created':True,
            'configuration_preserved':True, 'administrators_preserved':True,
            'radius_started':False, 'windows_changed':False}


def update(source, digest):
    import fcntl
    if os.geteuid() != 0:
        raise ValueError('Local sudo required')
    descriptor = os.open('/run/kaname-lab-update.lock', os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW, 0o600)
    with os.fdopen(descriptor, 'r+') as lock:
        stat = os.fstat(lock.fileno())
        if stat.st_uid != 0 or stat.st_nlink != 1 or stat.st_mode & 0o077:
            raise ValueError('Private root-owned upgrade lock required')
        fcntl.flock(lock.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        return _update(source, digest)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--source-digest', required=True)
    args = parser.parse_args()
    try:
        print(json.dumps(update(Path(__file__).resolve().parent.parent, args.source_digest)))
        return 0
    except Exception as error:
        print(json.dumps({'updated':False,'error':'LAB_UPDATE_FAILED','stage':_PHASE,'category':type(error).__name__,'check':'sudo/source digest/Ubuntu/existing service; prior code retained or rolled back'}))
        return 1


if __name__ == '__main__':
    sys.exit(main())
