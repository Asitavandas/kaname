"""Pinned UI-only update with a fresh managed backup and persisted preservation proof."""
from contextlib import contextmanager
from datetime import datetime, timezone
import ast
import hashlib
import http.client
import json
import os
from pathlib import Path
import pwd
import sqlite3
import ssl
import statistics
import subprocess
import time
import uuid

STAGE = Path('/home/kaname-runner/kaname-stage-397fa3d390e2')
EXPECTED = 'd1aba96d059717843d6c3a7e0881047f2a37918cf533eb84386e05d99244bbae'
RELEASE = '397fa3d390e20e04bb33dd1803a795fb3ba402bd'
ROOT = Path('/opt/kaname-lab/source')
STATE = Path('/var/lib/kaname-lab')
PHASE = 'preflight'
UPDATER = {}
EVIDENCE = None
ALLOWED = {'kaname/__init__.py', 'kaname/static/app.js', 'kaname/static/services.js',
           'kaname/static/index.html', 'kaname/static/styles.css'}
APPLICATION_DATA = {STATE / 'secret-store.key', STATE / 'radius/server.pem', STATE / 'radius/server-key.pem'}

class GuardError(ValueError):
    def __init__(self, code):
        self.code = code
        super().__init__(code)

def emit(event, **values): print(json.dumps({'event': event, **values}), flush=True)
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()

@contextmanager
def file_creation_mask(mask):
    previous = os.umask(mask)
    try: yield
    finally: os.umask(previous)

def trusted(path):
    info = path.lstat()
    if path.is_symlink() or not path.is_file() or info.st_uid != 0 or info.st_mode & 0o022:
        raise ValueError('Root-owned installed file required')
    return path.read_bytes()

def preserved_file(path):
    if path not in APPLICATION_DATA: return trusted(path)
    account = pwd.getpwnam('kaname-lab')
    info = path.lstat()
    # Vault._key requires the service account itself to own this private key.
    # RADIUS material may have been initialized by root or the service account.
    owners = {account.pw_uid} if path == STATE / 'secret-store.key' else {0, account.pw_uid}
    if path.is_symlink() or not path.is_file() or info.st_uid not in owners or info.st_mode & 0o077:
        raise GuardError('APPLICATION_DATA_OWNER_OR_MODE_INVALID')
    return path.read_bytes()

def load_pinned(path, digest):
    data = trusted(path)
    if hashlib.sha256(data).hexdigest() != digest: raise ValueError('Installed helper changed')
    namespace = {'__name__': 'pinned_panel_update_helper', '__file__': str(path)}
    exec(compile(data, str(path), 'exec'), namespace)
    return namespace

def active_pids():
    result = {}
    for unit in ('authwire-radius.service', 'authwire-service-control.service'):
        subprocess.run(['/usr/bin/systemctl', 'is-active', '--quiet', unit], check=True, timeout=10)
        value = subprocess.check_output(['/usr/bin/systemctl', 'show', unit, '--property=MainPID', '--value'], text=True, timeout=10).strip()
        if not value.isdecimal() or int(value) == 0: raise ValueError('Active pilot service required')
        result[unit] = value
    return result

def snapshot(worker):
    units = ('kaname-lab.service', 'authwire-radius.service', 'authwire-service-control.service',
             'authwire-radius-crl-sync.service', 'authwire-radius-crl-sync.timer',
             'authwire-backup.service', 'authwire-backup.timer')
    paths = [Path('/etc/systemd/system') / n for n in units]
    for unit in tuple(paths):
        drop = Path(str(unit) + '.d')
        if drop.exists():
            if drop.is_symlink() or not drop.is_dir(): raise ValueError('Unsafe unit override')
            paths.extend(p for p in sorted(drop.rglob('*')) if not p.is_dir())
    paths += [Path(p) for p in (
        '/etc/tmpfiles.d/authwire-service-control.conf',
        '/opt/authwire-radius/lib/rlm_python3.so', '/opt/authwire-service-control/broker.py',
        '/opt/authwire-backup/scheduled_backup.py', '/opt/authwire-backup/offline_restore_check.py',
        '/opt/authwire-backup/release.json', '/etc/kaname-lab/web.crt', '/etc/kaname-lab/web.key',
        '/var/lib/kaname-lab/secret-store.key', '/var/lib/kaname-lab/radius/server.pem',
        '/var/lib/kaname-lab/radius/server-key.pem',
        '/opt/kaname-lab/source/kaname/device_client/AuthWire-Client.ps1',
        '/opt/kaname-lab/source/kaname/device_client/Install-AuthWire.ps1')]
    files = {}
    for p in paths:
        data = preserved_file(p); info = p.stat()
        files[str(p)] = [hashlib.sha256(data).hexdigest(), info.st_mode & 0o777, info.st_uid, info.st_gid]
    timers = {}
    for unit in ('authwire-radius-crl-sync.timer', 'authwire-backup.timer'):
        values = subprocess.check_output(['/usr/bin/systemctl', 'show', unit, '--property=ActiveState,UnitFileState'], text=True, timeout=10).splitlines()
        if set(values) != {'ActiveState=active', 'UnitFileState=enabled'}: raise ValueError('Active enabled timer required')
        timers[unit] = sorted(values)
    return {'files': files, 'pids': active_pids(), 'timers': timers,
            'business_state': {n: worker['db_fingerprint'](STATE / n) for n in ('kaname.sqlite3', 'administrators.sqlite3')}}

def source_check(files):
    # Existing authentication/server/client code must be byte-identical. Only the
    # four reviewed static assets and the version module may differ in kaname/.
    for name, data in files.items():
        if name.startswith('kaname/') and name not in ALLOWED and trusted(ROOT / name) != data:
            raise ValueError('Protected application source differs')
    for path in (ROOT / 'kaname').rglob('*'):
        if '__pycache__' in path.parts or path.suffix == '.pyc' or path.is_dir(): continue
        name = path.relative_to(ROOT).as_posix()
        if name not in ALLOWED and name not in files: raise ValueError('Protected source would be removed')
    if sha(ROOT / 'kaname/device_client/AuthWire-Client.ps1') != '86081b41e7072c055cf3a0364f688914b5f66def91ab44273cdcea50e26f5b15':
        raise ValueError('Windows client changed')
    version_tree = ast.parse(files['kaname/__init__.py'])
    versions = [ast.literal_eval(n.value) for n in version_tree.body if isinstance(n, ast.Assign)
                and any(isinstance(t, ast.Name) and t.id == 'VERSION' for t in n.targets)]
    if versions != ['0.14.0-dev.7']:
        raise ValueError('Unexpected candidate version')

def measure(label):
    token = (STATE / 'access-token').read_text().strip()
    context = ssl.create_default_context(cafile='/etc/kaname-lab/web.crt')
    results = []
    for path in ('/api/auth/session', '/api/state', '/api/pki/certificates?offset=0', '/api/network', '/api/services'):
        codes, times = [], []
        for attempt in range(3):
            connection = http.client.HTTPSConnection('10.35.50.246', 8765, context=context, timeout=20, source_address=('127.0.0.1', 0))
            started = time.monotonic()
            try:
                connection.request('GET', path, headers={'Authorization': 'Bearer ' + token})
                response = connection.getresponse(); response.read(); codes.append(response.status)
            finally: connection.close()
            times.append(round((time.monotonic() - started) * 1000, 1))
        results.append({'path': path, 'statuses': codes, 'median_ms': statistics.median(times), 'max_ms': max(times)})
    emit('PANEL_READ_CHECK', phase=label, authenticated=True, loopback=True, results=results)
    if not all(c == 200 for row in results for c in row['statuses']): raise ValueError('Panel read check failed')

def fresh_backup(worker, target):
    old = target / 'last-success.json'
    old_data = old.read_bytes() if old.exists() else None
    subprocess.run(['/usr/bin/systemctl', 'start', 'authwire-backup.service'], check=True, timeout=650, capture_output=True)
    worker['private'](old)
    data = old.read_bytes()
    if data == old_data: raise ValueError('Fresh backup evidence required')
    record = json.loads(data)
    if record.get('producer') != worker['PRODUCER'] or record.get('event') != 'BACKUP_SUCCESS': raise ValueError('Fresh backup failed')
    for key in ('archive_read_verified', 'file_bytes_and_metadata_verified', 'sqlite_integrity_verified', 'business_state_stable', 'service_processes_preserved'):
        if record.get(key) is not True: raise ValueError('Backup acceptance missing')
    archive = Path(record['backup'])
    if archive.parent != target or not worker['NAME'].fullmatch(archive.name): raise ValueError('Unexpected backup location')
    worker['private'](archive)
    if sha(archive) != record['sha256']: raise ValueError('Backup digest differs')
    emit('PANEL_FRESH_BACKUP', backup=str(archive), sha256=record['sha256'], archive_read_verified=True,
         sqlite_integrity_verified=True, service_processes_preserved=True, data_restore_exercised=False)
    return {'backup': str(archive), 'sha256': record['sha256']}

def main():
    global PHASE, UPDATER, EVIDENCE
    if os.geteuid() != 0: raise ValueError('Local sudo required')
    PHASE = 'preflight_helpers'
    UPDATER = load_pinned(ROOT / 'tools/linux_update.py', 'd168067e31160bb064db7faadd796ec79fe0dff27f1933fec25090faab57d0fe')
    worker = load_pinned(Path('/opt/authwire-backup/scheduled_backup.py'), 'fc1f6f3efabf8159dd9edbfab415deb547614b630261b2833c81d739086e020c')
    PHASE = 'preflight_manifest'; files = UPDATER['verified_files'](STAGE, EXPECTED)
    PHASE = 'preflight_sources'; source_check(files)
    PHASE = 'preflight_preservation'; before = snapshot(worker)
    PHASE = 'preflight_evidence'; target = worker['prepare_directory']()
    EVIDENCE = target / ('panel-update-dev7-' + datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ') + '-' + uuid.uuid4().hex[:8])
    EVIDENCE.mkdir(mode=0o700)
    worker['atomic_json'](EVIDENCE / 'before.json', {'release': RELEASE, 'manifest': EXPECTED, 'checked_utc': worker['utc'](), 'snapshot': before})
    emit('PANEL_PREFLIGHT', protected_authentication_source_identical=True, radius_active=True,
         service_pids=before['pids'], baseline_persisted=True, evidence=str(EVIDENCE))
    PHASE = 'baseline_read_checks'; measure('before')
    PHASE = 'fresh_data_backup'; backup = fresh_backup(worker, target)
    if snapshot(worker) != before: raise ValueError('State changed during preparation; update refused')
    PHASE = 'panel_source_update'
    same = all((ROOT / n).is_file() and not (ROOT / n).is_symlink() and (ROOT / n).read_bytes() == b for n, b in files.items())
    with file_creation_mask(0o022): updated = {'already_current': True} if same else UPDATER['update'](STAGE, EXPECTED)
    emit('PANEL_UPDATED', **updated)
    PHASE = 'preservation_after'
    after = snapshot(worker)
    checks = {key: before[key] == after.get(key) for key in before}
    worker['atomic_json'](EVIDENCE / 'preservation.json', {'release': RELEASE, 'backup': backup, 'checked_utc': worker['utc'](), 'checks': checks, 'after': after})
    emit('PANEL_PRESERVATION', checks=checks, baseline_persisted=True)
    if not all(checks.values()): raise ValueError('Protected state changed; evidence retained, no blind data rollback')
    source_check(files)
    if any(trusted(ROOT / n) != b for n, b in files.items()): raise ValueError('Installed source differs from tested candidate')
    PHASE = 'panel_read_checks_after'; measure('after')
    worker['atomic_json'](EVIDENCE / 'finished.json', {'verified': True, 'version': '0.14.0-dev.7', 'checked_utc': worker['utc'](), 'release': RELEASE})
    os.sync()
    emit('PANEL_DEPLOY_FINISHED', verified=True, version='0.14.0-dev.7', radius_process_preserved=True,
         broker_process_preserved=True, protected_state_preserved=True, backup_timer_preserved=True,
         windows_changed=False, policy_changed=False, certificates_changed=False,
         original_preflight_snapshot_persisted=True, operator_browser_acceptance_pending=True)

if __name__ == '__main__':
    try: main()
    except Exception as error:
        emit('PANEL_DEPLOY_FAILED', phase=PHASE, category=type(error).__name__,
             guard_code=getattr(error, 'code', None),
             updater_stage=UPDATER.get('_PHASE') if PHASE == 'panel_source_update' else None,
             evidence=str(EVIDENCE) if EVIDENCE else None,
             sqlite_code=getattr(error, 'sqlite_errorcode', None) if isinstance(error, sqlite3.Error) else None,
             exit_code=error.returncode if isinstance(error, subprocess.CalledProcessError) else None)
        raise SystemExit(1)
