"""Private scheduled AuthWire snapshots. No service or live database writes."""
from contextlib import closing, contextmanager
from datetime import datetime, timezone
import argparse
import fcntl
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import sqlite3
import stat
import subprocess
import tarfile
import tempfile
import time
import uuid

BASE = Path('/')
PRODUCER = 'authwire-scheduled-backup-v1'
KEEP = 14
ROOT_NAMES = ('etc/kaname-lab', 'var/lib/kaname-lab', 'opt/kaname-lab/source',
              'opt/kaname-lab/venv', 'opt/authwire-radius', 'opt/authwire-service-control',
              'var/lib/authwire-service-control', 'opt/authwire-backup')
UNITS = ('kaname-lab.service', 'authwire-radius.service', 'authwire-service-control.service',
         'authwire-radius-crl-sync.service', 'authwire-radius-crl-sync.timer',
         'authwire-backup.service', 'authwire-backup.timer')
PRODUCT_UNITS = UNITS[:3]
VOLATILE = {'audit', 'admin_audit', 'access_events', 'admin_sessions', 'admin_login_rate',
            'user_enrollment_challenges', 'user_enrollment_rate', 'device_challenges', 'device_rate', 'pki_enrollment_rate', 'directory_catalog', 'sqlite_sequence'}
NAME = re.compile(r'authwire-scheduled-\d{8}T\d{6}Z-[0-9a-f]{12}\.tar\.gz')


def at(name): return BASE / name
def utc(): return datetime.now(timezone.utc).isoformat()
def digest(path):
    h = hashlib.sha256()
    with Path(path).open('rb') as f:
        for block in iter(lambda: f.read(1024 * 1024), b''): h.update(block)
    return h.hexdigest()


def private(path, directory=False):
    info = Path(path).lstat()
    if (not (stat.S_ISDIR(info.st_mode) if directory else stat.S_ISREG(info.st_mode))
            or info.st_uid != os.geteuid() or info.st_mode & 0o077):
        raise ValueError('Private backup path required')


def prepare_directory():
    parent = at('var/backups/authwire')
    # Refuse symlinks in every existing ancestor, including a redirected mount path.
    for p in (parent, *parent.parents):
        if p.is_symlink(): raise ValueError('Backup ancestor symlink refused')
    parent.mkdir(mode=0o700, parents=True, exist_ok=True); private(parent, True)
    target = parent / 'scheduled'
    target.mkdir(mode=0o700, exist_ok=True); private(target, True)
    return target


def atomic_json(path, value):
    if path.exists() or path.is_symlink(): private(path)
    fd, temp = tempfile.mkstemp(prefix='.json-', dir=path.parent)
    try:
        with os.fdopen(fd, 'w') as f:
            json.dump(value, f, sort_keys=True, indent=2); f.write('\n'); f.flush(); os.fsync(f.fileno())
        os.replace(temp, path)
        directory = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY)
        try: os.fsync(directory)
        finally: os.close(directory)
    finally:
        Path(temp).unlink(missing_ok=True)


@contextmanager
def locked(path, shared=False, create=False):
    flags = os.O_RDONLY if shared else os.O_RDWR
    fd = os.open(path, flags | os.O_NOFOLLOW | (os.O_CREAT if create else 0), 0o600)
    try:
        private(path)
        fcntl.flock(fd, (fcntl.LOCK_SH if shared else fcntl.LOCK_EX) | fcntl.LOCK_NB)
        yield
    finally: os.close(fd)


def roots():
    result = [at(n) for n in ROOT_NAMES]
    for root in result:
        if root.is_symlink() or not root.is_dir(): raise ValueError('Installed backup root missing or unsafe')
    for name in UNITS:
        unit = at('etc/systemd/system') / name
        if unit.is_symlink() or not unit.is_file(): raise ValueError('Installed unit missing or unsafe')
        result.append(unit)
        drop = Path(str(unit) + '.d')
        if drop.exists() or drop.is_symlink():
            if drop.is_symlink() or not drop.is_dir(): raise ValueError('Unit drop-in symlink refused')
            result.append(drop)
    support = at('etc/tmpfiles.d/authwire-service-control.conf')
    if support.is_symlink() or not support.is_file(): raise ValueError('Boot-time shared lock setup required')
    result.append(support)
    return result


def excluded(path):
    return '__pycache__' in path.parts or path.name.endswith(('-wal', '-shm', '-journal'))


def inventory(items):
    files, dbs = {}, []
    for root in items:
        for p in ([root] if root.is_file() else [root, *sorted(root.rglob('*'))]):
            if excluded(p): continue
            info = p.lstat(); name = p.relative_to(BASE).as_posix()
            common = [info.st_mode & 0o777, info.st_uid, info.st_gid]
            if stat.S_ISLNK(info.st_mode): files[name] = ['link', os.readlink(p), *common]
            elif stat.S_ISDIR(info.st_mode): files[name] = ['directory', None, *common]
            elif stat.S_ISREG(info.st_mode):
                if p.name.endswith(('.sqlite3', '.sqlite', '.db')):
                    dbs.append(p); files[name] = ['database', None, *common]
                else: files[name] = ['file', digest(p), *common]
            else: raise ValueError('Special live file refused')
    required = {at('var/lib/kaname-lab/kaname.sqlite3'), at('var/lib/kaname-lab/administrators.sqlite3')}
    if not required <= set(dbs): raise ValueError('Required application databases missing')
    return files, sorted(dbs)


POLL_SECTIONS = frozenset(('windows_connector_probe_jobs', 'windows_candidate_verify_jobs',
                           'windows_deployment_scope_jobs', 'windows_combined_verify_jobs', 'windows_combined_scope_jobs'))


def stable_runtime_payload(name, payload):
    """Ignore only validated transport polling metadata, never jobs/results.

    This projection affects comparison only. SQLite backup still copies the
    entire original row, including replay IDs and last_poll. Unknown/malformed
    structures retain their exact original bytes in the stability guard.
    """
    if name not in POLL_SECTIONS or type(payload) is not str or len(payload) > 100000:
        return payload
    def unique(pairs):
        result = {}
        for key, value in pairs:
            if key in result: raise ValueError('Duplicate JSON key')
            result[key] = value
        return result
    def constant(value):
        raise ValueError('Non-finite JSON')
    def number(value):
        return type(value) is int and 0 < value < 2**40
    def hexdigest(value):
        return type(value) is str and re.fullmatch('[a-f0-9]{64}', value) is not None
    try:
        v = json.loads(payload, object_pairs_hook=unique, parse_constant=constant)
        if type(v) is not dict or set(v) != {'format','jobs','polls','last_poll'}:
            return payload
        if type(v['format']) is not int or v['format'] != 1 or type(v['jobs']) is not list:
            return payload
        if type(v['polls']) is not list or len(v['polls']) > 128:
            return payload
        for poll in v['polls']:
            if type(poll) is not dict or set(poll) != {'id','until'} or not hexdigest(poll['id']) or not number(poll['until']):
                return payload
        last = v['last_poll']
        if last is not None:
            last_keys = {'scope', 'at'}
            if name != 'windows_connector_probe_jobs':
                last_keys.add('release_id')
            if type(last) is not dict or set(last) != last_keys or not hexdigest(last['scope']) or not number(last['at']):
                return payload
            if 'release_id' in last_keys:
                release = last['release_id']
                if type(release) is not str or str(uuid.UUID(release)) != release or uuid.UUID(release).int == 0:
                    return payload
        return json.dumps({'format':v['format'], 'jobs':v['jobs']}, sort_keys=True,
                          separators=(',',':'), allow_nan=False)
    except (ValueError, TypeError, KeyError, RecursionError):
        return payload


def db_fingerprint(path):
    """Only known transient/cache tables are excluded from the stability guard.

    All tables, including sessions/audit, are still copied with SQLite backup.
    """
    with closing(sqlite3.connect(path.as_uri() + '?mode=ro', uri=True, timeout=3)) as db:
        db.execute('BEGIN')
        schema = db.execute("SELECT type,name,tbl_name,sql FROM sqlite_master WHERE name NOT LIKE 'sqlite_%' ORDER BY type,name").fetchall()
        h = hashlib.sha256(repr(schema).encode())
        for (name,) in db.execute("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name"):
            if name in VOLATILE: continue
            quoted = '"' + name.replace('"', '""') + '"'
            where = " WHERE name<>'directory_health'" if name == 'runtime_settings' else ''
            rows = db.execute('SELECT * FROM ' + quoted + where).fetchall()
            if name == 'runtime_settings':
                rows = [(r[0], stable_runtime_payload(r[0], r[1]), *r[2:]) for r in rows]
            h.update(name.encode()); h.update(repr(sorted(rows, key=repr)).encode())
        return h.hexdigest()


def copy_database(source, target):
    deadline = time.monotonic() + 30
    def progress(status, remaining, total):
        if time.monotonic() > deadline: raise TimeoutError('Database snapshot deadline exceeded')
    with closing(sqlite3.connect(source.as_uri() + '?mode=ro', uri=True, timeout=3)) as reader, \
         closing(sqlite3.connect(target)) as writer:
        reader.backup(writer, pages=256, progress=progress, sleep=0.05)
        if writer.execute('PRAGMA integrity_check').fetchall() != [('ok',)]: raise ValueError('Database integrity check failed')
        if writer.execute('PRAGMA foreign_key_check').fetchall(): raise ValueError('Database foreign-key check failed')
    target.chmod(0o600)


def pids():
    result = {}
    for unit in PRODUCT_UNITS:
        p = subprocess.run(['systemctl', 'show', unit, '--property=MainPID', '--value'],
                           text=True, capture_output=True, check=True, timeout=10)
        result[unit] = p.stdout.strip()
        if not result[unit].isdigit(): raise ValueError('Unexpected product PID response')
    return result


def verify_archive(archive, expected):
    seen = set(); count = 0
    with tarfile.open(archive, 'r:gz') as tar:
        for member in tar:
            name = member.name
            if name not in expected or name in seen: raise ValueError('Unexpected archive member')
            seen.add(name); kind, value, mode, uid, gid = expected[name]
            if (member.mode, member.uid, member.gid) != (mode, uid, gid): raise ValueError('Archived metadata differs')
            if kind in ('file', 'database'):
                if not member.isfile(): raise ValueError('Archived file kind differs')
                h = hashlib.sha256()
                with tar.extractfile(member) as f:
                    for block in iter(lambda: f.read(1024 * 1024), b''): h.update(block)
                if h.hexdigest() != value: raise ValueError('Archived bytes differ')
                count += 1
            elif kind == 'link':
                if not member.issym() or member.linkname != value: raise ValueError('Archived link differs')
            elif not member.isdir(): raise ValueError('Archived directory differs')
    if seen != set(expected): raise ValueError('Archive member missing')
    return count


def capture(target, keep):
    items = roots(); first, dbs = inventory(items)
    estimate = sum((BASE / n).stat().st_size for n, v in first.items() if v[0] in ('file', 'database'))
    if shutil.disk_usage(target).free < estimate * 2 + 512 * 1024 * 1024: raise OSError('Insufficient backup space')
    before_pids = pids()
    with tempfile.TemporaryDirectory(prefix='.capture-', dir=target) as temp:
        work = Path(temp)
        for attempt in range(3):
            before, current_dbs = inventory(items)
            if dbs != current_dbs: raise ValueError('Database set changed during backup')
            control = {str(p): db_fingerprint(p) for p in dbs}
            expected = {n: list(v) for n, v in before.items()}
            copies = {}
            for index, db in enumerate(dbs):
                copy = work / ('db-' + str(index)); copy_database(db, copy); copies[db] = copy
                expected[db.relative_to(BASE).as_posix()][1] = digest(copy)
            copied = {str(p): db_fingerprint(copies[p]) for p in dbs}
            archive = work / 'snapshot.tar.gz'
            with tarfile.open(archive, 'w:gz', dereference=False) as tar:
                for name, value in expected.items():
                    source = copies.get(BASE / name, BASE / name)
                    entry = tar.gettarinfo(str(source), arcname=name)
                    entry.mode, entry.uid, entry.gid = value[2:]
                    if value[0] in ('file', 'database'):
                        # Record distinct files, never tar hard-link aliases.
                        entry.type = tarfile.REGTYPE; entry.linkname = ''; entry.size = source.stat().st_size
                        with source.open('rb') as f: tar.addfile(entry, f)
                    else: tar.addfile(entry)
            after, after_dbs = inventory(items)
            current = {str(p): db_fingerprint(p) for p in dbs}
            if before == after and dbs == after_dbs and control == copied == current: break
        else: raise ValueError('Business state changed during capture')
        files = verify_archive(archive, expected)
        if pids() != before_pids: raise ValueError('Product process changed during backup')
        name = 'authwire-scheduled-' + datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ') + '-' + uuid.uuid4().hex[:12] + '.tar.gz'
        final = target / name
        archive.chmod(0o600)
        with archive.open('rb') as f: os.fsync(f.fileno())
        # UUID name, no replacement of an existing archive or link.
        os.link(archive, final, follow_symlinks=False)
        record = {'producer': PRODUCER, 'event': 'BACKUP_SUCCESS', 'created_utc': utc(),
                  'backup': str(final), 'sha256': digest(final), 'files': files, 'databases': len(dbs),
                  'archive_read_verified': True, 'file_bytes_and_metadata_verified': True,
                  'sqlite_integrity_verified': True, 'business_state_stable': True,
                  'service_processes_preserved': True, 'services_stopped': False,
                  'data_restore_exercised': False, 'full_appliance_boot_restore_tested': False,
                  'keep_successful': keep}
        atomic_json(Path(str(final) + '.json'), record)
    return record


def retention(target, keep):
    if type(keep) is not int or not 2 <= keep <= 90: raise ValueError('Invalid successful backup retention')
    candidates = []
    for archive in sorted(target.iterdir(), reverse=True):
        if not NAME.fullmatch(archive.name): continue
        manifest = Path(str(archive) + '.json')
        if not manifest.exists() or manifest.is_symlink(): continue
        private(archive); private(manifest)
        value = json.loads(manifest.read_text())
        if value.get('producer') != PRODUCER or value.get('event') != 'BACKUP_SUCCESS' or value.get('backup') != str(archive): continue
        if not re.fullmatch('[a-f0-9]{64}', value.get('sha256', '')): continue
        candidates.append((archive, manifest, value))
    old = candidates[keep:]
    # Validate the whole deletion plan before removing any managed archive.
    for archive, manifest, value in old:
        if digest(archive) != value['sha256']: raise ValueError('Retention archive integrity mismatch')
    for archive, manifest, value in old:
        archive.unlink(); manifest.unlink()
    return len(old)


def run(keep=KEEP):
    if type(keep) is not int or not 2 <= keep <= 90: raise ValueError('Invalid successful backup retention')
    target = prepare_directory()
    # A second run must not overwrite the active run's status or prune its files.
    with locked(target / '.job.lock', create=True):
        phase = 'coordination'
        try:
            with locked(at('run/kaname-lab-update.lock'), shared=True):
                phase = 'capture'
                record = capture(target, keep)
                phase = 'retention'
                record['pruned_managed_backups'] = retention(target, keep)
            atomic_json(target / 'last-success.json', record)
            atomic_json(target / 'last-run.json', record)
            return record
        except Exception as error:
            record = {'producer': PRODUCER, 'event': 'BACKUP_FAILED', 'checked_utc': utc(),
                      'phase': phase, 'category': type(error).__name__,
                      'previous_backups_pruned': False if phase != 'retention' else None}
            atomic_json(target / 'last-run.json', record)
            raise


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--keep', type=int, default=KEEP)
    args = parser.parse_args()
    try:
        if os.geteuid() != 0: raise ValueError('Local root execution required')
        print(json.dumps(run(args.keep))); return 0
    except Exception as error:
        print(json.dumps({'event': 'BACKUP_FAILED', 'category': type(error).__name__})); return 1


if __name__ == '__main__': raise SystemExit(main())
