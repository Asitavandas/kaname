"""Locally verify one live AD security-token lookup using saved panel settings.

The root launcher verifies/stages generic code, then drops to kaname-lab. It
does not upgrade/restart the panel, install packages or activate RADIUS.
No credential, AD object name, GUID, SID or address is printed.
"""
import argparse
import json
import os
import subprocess
import sys
import tempfile
from pathlib import Path

STATE = Path('/var/lib/kaname-lab')
PYTHON = Path('/opt/kaname-lab/venv/bin/python')


def check(operations, reader=None):
    from kaname.radius_directory import LiveDirectory
    catalog = operations.store.directory_catalog()
    if not catalog:
        return {'checked': False, 'error': 'CATALOG_REQUIRED'}
    candidates = catalog['computers'] or catalog['users']
    if not candidates:
        return {'checked': False, 'error': 'ACCOUNT_REQUIRED'}
    provider = LiveDirectory(operations, **({'reader': reader} if reader else {}))
    account = provider.lookup(catalog['domain'], candidates[0]['guid'])
    return {'checked': True, 'account_found': account is not None,
            'account_enabled': account.enabled if account else False,
            'account_kind': account.kind if account else None,
            'security_group_count': len(account.security_group_sids) if account else 0,
            'authorization_source': 'live-kerberos-tokenGroups',
            'catalog_used_for_authorization': False, 'radius_started': False,
            'panel_updated': False}


def worker():
    import pwd
    from kaname.operations import Operations
    from kaname.store import Store
    if os.geteuid() != pwd.getpwnam('kaname-lab').pw_uid:
        raise ValueError('Service identity required')
    if not STATE.is_dir() or not (STATE / 'kaname.sqlite3').is_file():
        raise ValueError('Installed state required')
    return check(Operations(Store(STATE)))


def launch(digest):
    import pwd
    if os.geteuid() != 0:
        raise ValueError('One-time local sudo required')
    source = Path(__file__).resolve().parent.parent
    sys.path.insert(0, str(source))
    from tools.linux_install import verified_files
    files = verified_files(source, digest)
    if not PYTHON.is_file() or not (STATE / 'kaname.sqlite3').is_file():
        raise ValueError('Existing Linux installation required')
    identity = pwd.getpwnam('kaname-lab')
    with tempfile.TemporaryDirectory(prefix='kaname-authorization-', dir='/run') as temporary:
        root = Path(temporary); root.chmod(0o755)
        for name, data in files.items():
            target = root / name
            target.parent.mkdir(parents=True, exist_ok=True, mode=0o755)
            target.write_bytes(data); target.chmod(0o644)
        tickets = root / 'tickets'; tickets.mkdir(mode=0o700)
        os.chown(tickets, identity.pw_uid, identity.pw_gid)
        result = subprocess.run(['/usr/sbin/runuser', '-u', 'kaname-lab', '--', str(PYTHON),
            '-B', str(root / 'tools/linux_authorization_check.py'), '--worker'],
            cwd=root, env={'PATH': '/usr/bin:/bin', 'TMPDIR': str(tickets), 'LC_ALL': 'C.UTF-8'},
            capture_output=True, timeout=90, check=False)
        if result.returncode or len(result.stdout) > 4096:
            raise ValueError('Live authorization check failed')
        value = json.loads(result.stdout)
        if type(value) is not dict or value.get('checked') is not True:
            raise ValueError('Live authorization check failed')
        return value


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--source-digest')
    parser.add_argument('--worker', action='store_true', help=argparse.SUPPRESS)
    args = parser.parse_args()
    try:
        if args.worker:
            sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
            value = worker()
        else:
            if args.source_digest is None:
                raise ValueError('Verified source digest required')
            value = launch(args.source_digest)
        print(json.dumps(value)); return 0 if value.get('checked') else 1
    except Exception:
        print('{"checked":false,"error":"LIVE_AUTHORIZATION_CHECK_FAILED"}'); return 1


if __name__ == '__main__':
    sys.exit(main())
