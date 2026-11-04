"""Read-only local-root dev45 delivery preflight; no installation or service writes."""
import ast
from contextlib import closing
from datetime import datetime, timezone
import hashlib
import http.client
import ipaddress
import json
import os
from pathlib import Path
import re
import shutil
import sqlite3
import ssl
import stat
import subprocess
import sys

PACKAGES = {
    'AuthWire-0.14.0-dev.45-linux-source.zip': 'deb2480bfa456733b0c1983b951994b69f2f1360f78090fcc98bedc14f777cc9',
    'AuthWire-0.14.0-dev.45-backup-worker.zip': 'b19fa89af5c0f4203ce83abcf3e0f66cc717cad42095d64366d2c7cf7c6a4428',
}
UNITS = ('kaname-lab.service', 'authwire-radius.service', 'authwire-service-control.service')
ROOTS = ('/etc/kaname-lab', '/var/lib/kaname-lab', '/opt/kaname-lab/source',
         '/opt/kaname-lab/venv', '/opt/authwire-radius', '/opt/authwire-service-control',
         '/var/lib/authwire-service-control', '/opt/authwire-backup')


def sha(path):
    result = hashlib.sha256()
    with Path(path).open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            result.update(block)
    return result.hexdigest()


def services():
    result = {}
    for name in UNITS:
        output = subprocess.run(['systemctl', 'show', name, '--no-pager',
                                 '--property=ActiveState,SubState,MainPID'], check=True,
                                text=True, capture_output=True, timeout=10).stdout
        result[name] = dict(line.split('=', 1) for line in output.splitlines() if '=' in line)
    return result


def private(path, directory=False):
    value = path.lstat()
    kind = stat.S_ISDIR if directory else stat.S_ISREG
    if (not kind(value.st_mode) or value.st_uid != 0 or value.st_mode & 0o077
            or (not directory and value.st_nlink != 1) or path.resolve() != path):
        raise ValueError('Private root-owned backup path required')


def run(host, package_directory):
    if os.geteuid() != 0:
        raise ValueError('Local root required')
    host = str(ipaddress.ip_address(host))
    before = services()
    source = Path('/opt/kaname-lab/source')
    tree = ast.parse((source / 'kaname/__init__.py').read_bytes())
    version = next(n.value.value for n in tree.body if isinstance(n, ast.Assign)
                   and any(isinstance(t, ast.Name) and t.id == 'VERSION' for t in n.targets))
    context = ssl.create_default_context(cafile='/etc/kaname-lab/web.crt')
    connection = http.client.HTTPSConnection(host, 8765, context=context, timeout=5)
    try:
        connection.request('GET', '/healthz')
        response = connection.getresponse(); health = json.loads(response.read(4096))
        https_ok = (response.status == 200 and health.get('product') in ('AuthWire', 'KANAME')
                    and health.get('version') == version and health.get('device_client_sha256')
                    == sha(source / 'kaname/device_client/AuthWire-Client.ps1'))
    finally:
        connection.close()
    scheduled = Path('/var/backups/authwire/scheduled')
    private(scheduled, True)
    for name in ('last-success.json', 'last-run.json'):
        private(scheduled / name)
    success = json.loads((scheduled / 'last-success.json').read_bytes())
    latest = json.loads((scheduled / 'last-run.json').read_bytes())
    backup = Path(success['backup'])
    if (backup.parent != scheduled or not re.fullmatch(r'authwire-scheduled-\d{8}T\d{6}Z-[a-f0-9]{12}\.tar\.gz', backup.name)
            or not re.fullmatch('[a-f0-9]{64}', success['sha256'])):
        raise ValueError('Unexpected existing backup identity')
    private(backup)
    age = (datetime.now(timezone.utc) - datetime.fromisoformat(success['created_utc'])).total_seconds() / 3600
    backup_hash_ok = sha(backup) == success['sha256']
    databases = {}
    for name in ('kaname.sqlite3', 'administrators.sqlite3'):
        path = Path('/var/lib/kaname-lab') / name
        with closing(sqlite3.connect(path.as_uri() + '?mode=ro', uri=True, timeout=5)) as database:
            databases[name] = database.execute('PRAGMA quick_check').fetchall() == [('ok',)]
    packages = {name: sha(Path(package_directory) / name) == expected for name, expected in PACKAGES.items()}
    estimated = 0
    for root in ROOTS:
        if not Path(root).is_dir() or Path(root).is_symlink():
            raise ValueError('Required installed snapshot root missing or unsafe')
        for directory, dirs, files in os.walk(root, followlinks=False):
            for name in files:
                path = Path(directory) / name
                if not path.is_symlink() and path.is_file():
                    estimated += path.stat().st_size
    free = min(shutil.disk_usage('/opt/kaname-lab').free, shutil.disk_usage('/var/backups/authwire').free)
    checks = {'ubuntu_24_04': 'VERSION_ID="24.04"' in Path('/etc/os-release').read_text(),
              'python_3_12_or_newer': sys.version_info >= (3, 12), 'https_verified': https_ok,
              'backup_hash_verified': backup_hash_ok, 'backup_age_within_36_hours': 0 <= age <= 36,
              'last_backup_successful': latest.get('event') == success.get('event') == 'BACKUP_SUCCESS'
                  and success.get('producer') == 'authwire-scheduled-backup-v1',
              'database_quick_checks': all(databases.values()), 'candidate_packages_match_ci': all(packages.values()),
              'space_for_two_snapshots_and_margin': free >= estimated * 2 + 512 * 1024 * 1024,
              'product_services_preserved': services() == before}
    return {'event': 'AUTHWIRE_ROOT_PREFLIGHT', 'read_only': True, 'changes_applied': False,
            'current_version': version, 'candidate_version': '0.14.0-dev.45', 'checks': checks,
            'preflight_passed': all(checks.values()), 'services': before,
            'existing_backup_age_hours': round(age, 2), 'existing_backup_sha256': success['sha256'],
            'free_gib': round(free / 1024**3, 2), 'snapshot_source_gib': round(estimated / 1024**3, 2),
            'database_quick_checks': databases, 'candidate_package_checks': packages,
            'backup_worker_release_sha256': sha('/opt/authwire-backup/release.json'),
            'full_appliance_restore_tested': False}


if __name__ == '__main__':
    try:
        print(json.dumps(run(sys.argv[1], sys.argv[2]), sort_keys=True))
    except Exception as error:
        print(json.dumps({'event': 'AUTHWIRE_ROOT_PREFLIGHT_REFUSED', 'read_only': True,
                          'changes_applied': False, 'category': type(error).__name__}))
        raise SystemExit(1)
