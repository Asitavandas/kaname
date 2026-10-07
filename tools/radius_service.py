"""Explicit local control for the AuthWire production RADIUS service."""
import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

from kaname.operations import Operations
from kaname.store import Store


STATE = Path('/var/lib/kaname-lab')
UNIT = Path('/etc/systemd/system/authwire-radius.service')
RUNTIME = Path('/opt/authwire-radius')


def command(*args, check=True):
    return subprocess.run(list(args), check=check, capture_output=True, text=True, timeout=30)


def status():
    active = command('systemctl', 'is-active', '--quiet', 'authwire-radius.service', check=False).returncode == 0
    enabled = command('systemctl', 'is-enabled', '--quiet', 'authwire-radius.service', check=False).returncode == 0
    network = Operations(Store(STATE)).network()
    return {'installed': UNIT.is_file() and RUNTIME.is_dir(), 'active': active, 'enabled': enabled,
            'authentication_port': network['authentication_port'], 'accounting_enabled': False,
            'firewall_managed': False}


def _preflight():
    if os.geteuid() != 0 or sys.platform != 'linux':
        raise ValueError('Local Linux sudo required')
    if UNIT.is_symlink() or not UNIT.is_file() or UNIT.stat().st_uid != 0 or UNIT.stat().st_mode & 0o022:
        raise ValueError('Trusted AuthWire RADIUS service unit required')
    if RUNTIME.is_symlink() or not RUNTIME.is_dir() or RUNTIME.stat().st_uid != 0 or RUNTIME.stat().st_mode & 0o022:
        raise ValueError('Trusted AuthWire RADIUS runtime required')
    if command('systemctl', 'is-active', '--quiet', 'kaname-lab.service', check=False).returncode != 0:
        raise ValueError('AuthWire panel service must be active')
    store = Store(STATE)
    operations = Operations(store)
    network = operations.network()
    if not network['radius_clients'] or any(not c.get('secret_saved') for c in network['radius_clients']):
        raise ValueError('Every RADIUS client requires a saved shared secret')
    if any(c.get('access_type') not in {'wired', 'wireless'} for c in network['radius_clients']):
        raise ValueError('Every RADIUS client requires a trusted access type')
    directory = operations.directory()
    if not directory['credentials_saved']:
        raise ValueError('Saved AD read-only credentials are required')
    health = operations.health()
    if health.get('state') != 'connected':
        raise ValueError('AD connection health must be connected before RADIUS enable')
    with store.connect() as db:
        tables = {row[0] for row in db.execute("SELECT name FROM sqlite_master WHERE type='table'")}
        if 'radius_certificate_bindings' not in tables:
            raise ValueError('Certificate binding registry is not initialized')
        bound = db.execute('''SELECT count(*) FROM radius_certificate_bindings b
            JOIN pki_certificates c ON c.serial=b.serial
            WHERE b.active=1 AND c.revoked_at IS NULL''').fetchone()[0]
    if bound < 1:
        raise ValueError('At least one active enrolled device certificate is required')
    server_key = STATE / 'radius/server-key.pem'
    server_cert = STATE / 'radius/server.pem'
    if server_key.is_symlink() or server_cert.is_symlink() or not server_key.is_file() or not server_cert.is_file():
        raise ValueError('RADIUS server certificate is not initialized')
    unit = UNIT.read_text()
    listen = re.findall(r'--listen-ip ([0-9.]+)', unit)
    if len(listen) != 1:
        raise ValueError('RADIUS listen IP missing from service unit')
    return listen[0], network['authentication_port']


def _listener_present(ip, port):
    result = command('/usr/bin/ss', '-H', '-lun', check=False)
    if result.returncode != 0:
        return False
    expected = f'{ip}:{port}'
    return any(expected in line.split() for line in result.stdout.splitlines())


def enable():
    listen_ip, port = _preflight()
    if command('systemctl', 'is-enabled', '--quiet', 'authwire-radius.service', check=False).returncode == 0:
        raise ValueError('RADIUS service is already enabled')
    command('systemctl', 'start', 'authwire-radius.service')
    try:
        deadline = time.monotonic() + 15
        while time.monotonic() < deadline:
            if command('systemctl', 'is-active', '--quiet', 'authwire-radius.service', check=False).returncode != 0:
                time.sleep(0.25)
                continue
            if _listener_present(listen_ip, port):
                break
            time.sleep(0.25)
        else:
            raise ValueError('RADIUS service did not expose the expected UDP listener')
        command('systemctl', 'enable', 'authwire-radius.service')
        if command('systemctl', 'is-enabled', '--quiet', 'authwire-radius.service', check=False).returncode != 0:
            raise ValueError('RADIUS service could not be enabled for boot')
    except Exception:
        command('systemctl', 'disable', '--now', 'authwire-radius.service', check=False)
        raise
    return {'enabled': True, 'active': True, 'listen_ip': listen_ip,
            'authentication_port': port, 'accounting_enabled': False,
            'firewall_changed': False, 'network_devices_changed': False}


def disable():
    if os.geteuid() != 0 or sys.platform != 'linux':
        raise ValueError('Local Linux sudo required')
    command('systemctl', 'disable', '--now', 'authwire-radius.service', check=False)
    result = status()
    if result['active'] or result['enabled']:
        raise ValueError('RADIUS service did not fully disable')
    return result | {'disabled': True}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=['status', 'enable', 'disable'])
    args = parser.parse_args()
    try:
        result = {'status': status(), 'enable': enable, 'disable': disable}[args.action]
        if callable(result):
            result = result()
        print(json.dumps(result))
        return 0
    except Exception as error:
        print(json.dumps({'ok': False, 'error': 'RADIUS_SERVICE_ACTION_FAILED',
                          'category': type(error).__name__, 'check': str(error)}))
        return 1


if __name__ == '__main__':
    sys.exit(main())
