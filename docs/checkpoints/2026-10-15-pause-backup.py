#!/usr/bin/env python3
"""Create a private, live AuthWire checkpoint without changing services."""
import datetime
import hashlib
import json
import os
from pathlib import Path
import shutil
import sqlite3
import subprocess
import tarfile
import tempfile

ROOTS = [Path('/etc/kaname-lab'), Path('/var/lib/kaname-lab'),
         Path('/opt/kaname-lab/source'), Path('/opt/kaname-lab/venv'),
         Path('/opt/authwire-radius')]
UNIT_NAMES = ['kaname-lab.service', 'authwire-radius.service',
              'authwire-radius-crl-sync.service', 'authwire-radius-crl-sync.timer']

def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as f:
        for block in iter(lambda: f.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()

def inventory(roots):
    result = {}
    for root in roots:
        for p in ([root] if root.is_file() else sorted(root.rglob('*'))):
            if '__pycache__' in p.parts or p.name.endswith(('-wal','-shm','-journal')):
                continue
            if p.is_symlink():
                result[str(p)] = ['link', os.readlink(p)]
            elif p.is_file() and not p.name.endswith(('.sqlite3','.sqlite','.db')):
                result[str(p)] = ['file', digest(p), p.stat().st_mode & 0o777]
    return result

def db_copy(src, dst):
    dst.parent.mkdir(parents=True, exist_ok=True)
    with sqlite3.connect(src.as_uri() + '?mode=ro', uri=True, timeout=30) as reader:
        with sqlite3.connect(dst) as writer:
            reader.backup(writer)
            if writer.execute('PRAGMA integrity_check').fetchone()[0] != 'ok':
                raise RuntimeError('Backup database integrity failed')
    metadata = src.stat()
    os.chmod(dst, metadata.st_mode & 0o777)
    if os.geteuid() == 0:
        os.chown(dst, metadata.st_uid, metadata.st_gid)

def main():
    if os.geteuid() != 0:
        raise RuntimeError('Run with sudo')
    os.umask(0o077)
    for root in ROOTS:
        if not root.is_dir() or root.is_symlink():
            raise RuntimeError('Expected installed directory missing or unsafe')
    target = Path('/var/backups/authwire')
    if target.is_symlink():
        raise RuntimeError('Unsafe backup path')
    target.mkdir(mode=0o700, exist_ok=True)
    if target.stat().st_uid != 0 or target.stat().st_mode & 0o077:
        raise RuntimeError('Private root-owned backup directory required')
    stamp = datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    units = [Path('/etc/systemd/system') / n for n in UNIT_NAMES]
    units += [Path('/etc/systemd/system') / (n + '.d') for n in UNIT_NAMES]
    extras = [p for p in units if p.exists()]
    roots = ROOTS + extras
    dbs = sorted(p for root in ROOTS[:2] for p in root.rglob('*')
                 if p.is_file() and not p.is_symlink()
                 and p.name.endswith(('.sqlite3','.sqlite','.db')))
    if not any(p.name == 'kaname.sqlite3' for p in dbs):
        raise RuntimeError('Expected AuthWire database missing')
    estimated = sum(p.stat().st_size for r in ROOTS for p in r.rglob('*')
                    if p.is_file() and not p.is_symlink())
    if shutil.disk_usage(target).free < estimated * 2 + 256 * 1024 * 1024:
        raise RuntimeError('Insufficient free backup space')
    pid_before = subprocess.check_output(['systemctl','show','authwire-radius.service',
                                         '--property=MainPID','--value'], text=True).strip()
    with tempfile.TemporaryDirectory(prefix='.pause-', dir=target) as temp:
        work = Path(temp)
        stable = False
        for attempt in range(3):
            snap = work / ('db-' + str(attempt))
            before = inventory(roots)
            for db in dbs:
                db_copy(db, snap / str(db).lstrip('/'))
            archive = work / 'checkpoint.tar.gz'
            def filter_entry(info):
                name = info.name
                if '__pycache__' in Path(name).parts or name.endswith(('-wal','-shm','-journal')):
                    return None
                if any(name == str(db).lstrip('/') for db in dbs):
                    return None
                return info
            with tarfile.open(archive, 'w:gz', dereference=False) as tar:
                for root in roots:
                    tar.add(root, arcname=str(root).lstrip('/'), filter=filter_entry)
                for db in dbs:
                    tar.add(snap / str(db).lstrip('/'), arcname=str(db).lstrip('/'))
            after = inventory(roots)
            db_stable = True
            for db in dbs:
                second = work / ('check-' + str(attempt)) / str(db).lstrip('/')
                db_copy(db, second)
                db_stable &= digest(second) == digest(snap / str(db).lstrip('/'))
            if before == after and db_stable:
                stable = True
                break
        if not stable:
            raise RuntimeError('Live state changed during capture; no checkpoint published')
        with tarfile.open(archive, 'r:gz') as tar:
            # Read every file to EOF to verify the compressed archive as well.
            count = 0
            for member in tar:
                if member.isfile():
                    f = tar.extractfile(member)
                    for _ in iter(lambda: f.read(1024 * 1024), b''):
                        pass
                    count += 1
        final = target / ('authwire-pause-' + stamp + '.tar.gz')
        if final.exists():
            raise RuntimeError('Backup name already exists')
        os.chmod(archive, 0o600)
        os.rename(archive, final)
        checksum = digest(final)
        manifest = {'created_utc':stamp,'sha256':checksum,'files':count,
                    'databases':len(dbs),'live_state_stable':True,
                    'services_stopped':False,'restore_tested':False}
        final.with_suffix(final.suffix + '.json').write_text(json.dumps(manifest,indent=2)+'\n')
        os.sync()
        pid_after = subprocess.check_output(['systemctl','show','authwire-radius.service',
                                            '--property=MainPID','--value'], text=True).strip()
        print(json.dumps({'event':'PAUSE_BACKUP_CREATED','backup':str(final),
                          'sha256':checksum,'archive_read_verified':True,
                          'sqlite_integrity_verified':True,'live_state_stable':True,
                          'radius_process_preserved':pid_before==pid_after,
                          'restore_tested':False}))

if __name__ == '__main__':
    try:
        main()
    except Exception as exc:
        print(json.dumps({'event':'PAUSE_BACKUP_FAILED','category':type(exc).__name__,
                          'detail':str(exc)}))
        raise SystemExit(1)
