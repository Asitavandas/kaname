"""Real native activation/failed-start recovery on disposable hosted CI only."""
import hashlib
import hmac
import json
import os
from pathlib import Path
import pwd
import secrets
import shutil
import socket
import sqlite3
import subprocess
import sys
import time
from unittest.mock import patch

from tools import radius_events_install as install
from tools.radius_install import unit_text
from tools.radius_native_check import response


def command(*args, **kwargs):
    return subprocess.run(list(args), capture_output=True, check=True, timeout=60, **kwargs)


def probe(port):
    secret = b'RADIUS_SECRET_SENTINEL_42'  # Disposable fixture client only.
    name = b'never-promote-this-outer-identity'
    attrs = bytes((1, len(name) + 2)) + name + bytes((80, 18)) + bytes(16)
    request = bytes((1, 42)) + (20 + len(attrs)).to_bytes(2, 'big') + secrets.token_bytes(16) + attrs
    request = request[:-16] + hmac.digest(secret, request, 'md5')
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.settimeout(5); sock.sendto(request, ('127.0.0.1', port)); packet = sock.recv(4096)
    code, attributes = response(packet, request, secret)
    if code != 3 or any(k in attributes for k in (64, 65, 81)): raise AssertionError('Non-EAP fixture was not rejected')


def main():
    if (os.geteuid() != 0 or sys.platform != 'linux' or
            os.environ.get('RUNNER_ENVIRONMENT') != 'github-hosted'):
        raise ValueError('Disposable hosted Linux runner required')
    # Hosted sudo can inherit a group-writable umask. Model the production
    # root-owned installation without relaxing its file-trust checks.
    os.umask(0o022)
    prefix = Path(os.environ['AUTHWIRE_RADIUS_PREFIX']).resolve()
    repo = Path(__file__).resolve().parents[1]
    roots = [Path('/opt/kaname-lab'), install.PREFIX, install.STATE, install.WORKER.parent,
             install.EVIDENCE_ROOT, install.DROPIN.parent]
    units = [install.UNIT, Path('/etc/systemd/system/authwire-service-control.service'),
             Path('/etc/systemd/system/kaname-lab.service')]
    if any(p.exists() or p.is_symlink() for p in roots + units + [install.LOCK]):
        raise ValueError('Fixture installation paths already exist')
    try:
        account = pwd.getpwnam(install.ACCOUNT)
    except KeyError:
        command('/usr/sbin/useradd', '--system', '--user-group', '--no-create-home', '--shell', '/usr/sbin/nologin', install.ACCOUNT)
        account = pwd.getpwnam(install.ACCOUNT)
    names = [p.name for p in units]
    try:
        install.SOURCE.mkdir(parents=True)
        for name in ('kaname', 'tools', 'tests'):
            shutil.copytree(repo / name, install.SOURCE / name, ignore=shutil.ignore_patterns('__pycache__', '*.pyc'))
        command(sys.executable, '-m', 'venv', '--system-site-packages', '/opt/kaname-lab/venv')
        shutil.copytree(prefix, install.PREFIX)
        install.STATE.mkdir(mode=0o700, parents=True); os.chown(install.STATE, account.pw_uid, account.pw_gid)
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
            sock.bind(('127.0.0.1', 0)); port = sock.getsockname()[1]
        script = '''import secrets
from kaname.store import Store
from kaname.operations import Operations
from kaname.pki import PKIService
from tools.radius_initialize import initialize
from tests.helpers import config
from tests.test_radius_production import network
s=Store('/var/lib/kaname-lab');s.save(0,config=config())
n=network();n['radius_clients'][0]['ip']='127.0.0.1';n['authentication_port']=PORT
Operations(s).save_network(s.snapshot()['revision'],n)
password=secrets.token_hex(24).encode();PKIService(s.root).initialize(password);initialize(s.root,password,30)
'''.replace('PORT', str(port))
        env = dict(os.environ, PYTHONPATH=str(install.SOURCE), PYTHONNOUSERSITE='1', PYTHONDONTWRITEBYTECODE='1')
        command('/usr/sbin/runuser', '-u', install.ACCOUNT, '--', '/opt/kaname-lab/venv/bin/python', '-B', '-c', script,
                cwd=install.SOURCE, env=env)
        candidate = (repo / 'tools/scheduled_backup.py').read_bytes()
        original_worker = candidate.replace(install.BACKUP_CHANGE[1], install.BACKUP_CHANGE[0], 1)
        assert install.digest(original_worker) == install.OLD_WORKER_SHA
        install.WORKER.parent.mkdir(mode=0o755)
        install.atomic(install.WORKER, original_worker)
        checker = install.WORKER.parent / 'offline_restore_check.py'
        install.atomic(checker, (repo / 'tools/offline_restore_check.py').read_bytes())
        old_release = (json.dumps({'scheduled_backup.py': install.digest(original_worker),
                                  'offline_restore_check.py': install.digest(checker.read_bytes())}, sort_keys=True, indent=2) + '\n').encode()
        install.atomic(install.RELEASE, old_release)
        install.LOCK.touch(mode=0o600)
        base = unit_text('127.0.0.1').encode(); install.atomic(install.UNIT, base)
        for unit in units[1:]: install.atomic(unit, b'[Service]\nType=simple\nExecStart=/usr/bin/sleep infinity\n')
        for path in (install.WORKER, checker, install.RELEASE):
            info = path.lstat()
            assert (info.st_uid, info.st_mode & 0o777, info.st_nlink) == (0, 0o644, 1), (str(path), info)
        command('systemctl', 'daemon-reload'); command('systemctl', 'start', *names)
        before = install.service_pid('authwire-radius.service'); panel_pid = install.service_pid('kaname-lab.service')
        install.listener('127.0.0.1', port, observer_required=False)
        probe(port)
        # CI build paths can differ from the pinned customer's native ELF hash.
        # Pin this disposable test's existing module; the production constant is
        # unchanged, and both before/after bytes must still be identical.
        native_sha = install.digest((install.PREFIX / 'lib/rlm_python3.so').read_bytes())
        with patch.object(install, 'NATIVE_SHA', native_sha):
            result = install.activate()
            assert result['verified'] and result['radius_pid_after'] != before
            probe(port)
            with sqlite3.connect(install.STATE / 'radius-events/access.sqlite3') as db:
                rows = db.execute('SELECT response_code,reason,tls_verified,object_guid,vlan FROM access_events').fetchall()
                assert rows == [(3, 'NON_EAP_REQUEST', 0, None, None)]
            assert install.service_pid('kaname-lab.service') == panel_pid
            assert install.UNIT.read_bytes() == base
            effective = command('systemctl', 'show', 'authwire-radius.service',
                                '--property=ProtectSystem,NoNewPrivileges,User', text=True).stdout
            assert set(effective.splitlines()) == {'ProtectSystem=strict', 'NoNewPrivileges=yes', 'User=kaname-lab'}
            # Restore the fixture's no-observer baseline, then cause an actual
            # ExecStartPre failure after a successful native configuration check.
            install.DROPIN.unlink(); install.atomic(install.WORKER, original_worker); install.atomic(install.RELEASE, old_release)
            command('systemctl', 'daemon-reload'); command('systemctl', 'restart', 'authwire-radius.service')
            normal_override = install.override_text
            with patch.object(install, 'override_text', side_effect=lambda line: normal_override(line).replace(
                    b' --access-events', b' --invalid-fixture-option')):
                try: install.activate()
                except subprocess.CalledProcessError: pass
                else: raise AssertionError('Failed-start rollback was not exercised')
            assert not install.DROPIN.exists()
            assert install.WORKER.read_bytes() == original_worker and install.RELEASE.read_bytes() == old_release
            assert install.service_pid('authwire-radius.service') != '0'
            assert install.service_pid('kaname-lab.service') == panel_pid
            probe(port)
            assert b'module = kaname.radius_adapter' in (install.RUNTIME / 'mods-enabled/python3').read_bytes()
        print(json.dumps({'native_access_history_systemd': 'passed', 'loopback_only': True,
                          'actual_native_restart': True, 'observer_wrote_final_reject': True,
                          'effective_hardening_preserved': True, 'real_failed_start_rolled_back': True,
                          'original_authorizer_restored': True, 'customer_state_used': False}))
    finally:
        subprocess.run(['systemctl', 'stop', *names], capture_output=True, timeout=30)
        for unit in units: unit.unlink(missing_ok=True)
        install.DROPIN.unlink(missing_ok=True)
        subprocess.run(['systemctl', 'daemon-reload'], capture_output=True, timeout=30)


if __name__ == '__main__': main()
