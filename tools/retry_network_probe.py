"""Operator-only VV06 HTTPS failure probe with kernel-bounded nft set lifetime.

This diagnostic is not installed into AuthWire or run by its services. It never
changes persistent firewall configuration, application data, or service state.
"""
from datetime import datetime, timedelta, timezone
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import socket
import subprocess
import time
import uuid

NFT = '/usr/sbin/nft'
CLIENT = '10.10.110.4'
SERVER = '10.35.50.246'
PORT = 8765
DURATION = 180
PREFIX = 'aw_retry_probe_'
PROTECTED = (
    '/opt/kaname-lab/source/kaname/__init__.py',
    '/opt/kaname-lab/source/kaname/device_client/AuthWire-Client.ps1',
    '/opt/kaname-lab/source/kaname/device_client/Install-AuthWire.ps1',
    '/etc/systemd/system/authwire-radius.service',
    '/etc/systemd/system/authwire-service-control.service',
    '/opt/authwire-radius/lib/rlm_python3.so',
    '/etc/kaname-lab/web.crt', '/etc/kaname-lab/web.key',
    '/var/lib/kaname-lab/radius/server.pem',
    '/var/lib/kaname-lab/radius/server-key.pem',
)


def command(args, **kwargs):
    return subprocess.run(args, text=True, capture_output=True, timeout=10, **kwargs)


def table_name(value):
    if not re.fullmatch(PREFIX + r'[0-9a-f]{12}', value):
        raise ValueError('PROBE_TABLE_NAME_INVALID')
    return value


def rules(name, duration=DURATION):
    table_name(name)
    if type(duration) is not int or not 1 <= duration <= DURATION:
        raise ValueError('PROBE_DURATION_INVALID')
    return (
        f'add table inet {name}\n'
        f'add set inet {name} blocked {{ type ipv4_addr; flags timeout; timeout {duration}s; gc-interval 1s; }}\n'
        f'add chain inet {name} input {{ type filter hook input priority -50; policy accept; }}\n'
        f'add rule inet {name} input ip saddr @blocked ip daddr {SERVER} tcp dport {PORT} counter reject with tcp reset\n'
        f'add element inet {name} blocked {{ {CLIENT} timeout {duration}s }}\n'
    )


def tables():
    r = command([NFT, '-j', 'list', 'tables'], check=True)
    return json.loads(r.stdout)['nftables']


def create(name, duration=DURATION):
    batch = rules(name, duration)
    if any(item.get('table', {}).get('name', '').startswith(PREFIX) for item in tables()):
        raise ValueError('EXISTING_PROBE_REFUSED')
    command([NFT, '--check', '-f', '-'], input=batch, check=True)
    # One netlink batch: a parser failure cannot install a partial probe.
    command([NFT, '-f', '-'], input=batch, check=True)


def view(name):
    r = command([NFT, '-j', 'list', 'table', 'inet', table_name(name)], check=True)
    return json.loads(r.stdout)


def hits(name):
    return sum(expr.get('counter', {}).get('packets', 0)
               for item in view(name)['nftables']
               for expr in item.get('rule', {}).get('expr', []))


def remove(name):
    table_name(name)
    existing = command([NFT, 'list', 'table', 'inet', name])
    if existing.returncode:
        # A missing table is safe, but a general query failure is not success.
        if any(item.get('table', {}).get('name') == name for item in tables()):
            raise RuntimeError('PROBE_QUERY_FAILED')
        return
    command([NFT, 'delete', 'table', 'inet', name], check=True)
    if any(item.get('table', {}).get('name') == name for item in tables()):
        raise RuntimeError('PROBE_REMOVAL_FAILED')


def snapshot():
    files = {}
    for name in PROTECTED:
        p = Path(name)
        if p.is_symlink() or not p.is_file():
            raise ValueError('PROTECTED_PATH_UNAVAILABLE')
        files[name] = hashlib.sha256(p.read_bytes()).hexdigest()
    pids = {}
    for name in ('kaname-lab.service', 'authwire-radius.service', 'authwire-service-control.service'):
        command(['/usr/bin/systemctl', 'is-active', '--quiet', name], check=True)
        pid = command(['/usr/bin/systemctl', 'show', name, '--property=MainPID', '--value'], check=True).stdout.strip()
        if not pid.isdecimal() or int(pid) == 0:
            raise ValueError('PRODUCT_PROCESS_UNAVAILABLE')
        pids[name] = pid
    return {'files': files, 'pids': pids}


def emit(event, **data):
    print(json.dumps({'event': event, **data}), flush=True)


def main():
    if os.geteuid() != 0 or socket.gethostname() != 'segmentiq':
        raise ValueError('EXPECTED_ROOT_AND_HOST_REQUIRED')
    addresses = json.loads(command(['/usr/sbin/ip', '-j', '-4', 'address', 'show', 'dev', 'ens33'], check=True).stdout)
    if SERVER not in {a.get('local') for i in addresses for a in i.get('addr_info', [])}:
        raise ValueError('EXPECTED_SERVER_ADDRESS_REQUIRED')
    before = snapshot()
    name = PREFIX + uuid.uuid4().hex[:12]
    installed = False
    interrupted = False
    count = 0

    def interrupt(signum, frame):
        raise KeyboardInterrupt()

    signal.signal(signal.SIGTERM, interrupt)
    signal.signal(signal.SIGHUP, interrupt)
    try:
        create(name)
        installed = True
        deadline = time.monotonic() + DURATION
        emit('RETRY_PROBE_READY', client=CLIENT, server=SERVER, tcp_port=PORT,
             duration_seconds=DURATION, kernel_expiry=True, table=name,
             expires_utc=(datetime.now(timezone.utc) + timedelta(seconds=DURATION)).isoformat(),
             radius_pid=before['pids']['authwire-radius.service'],
             radius_udp_1812_not_matched=True)
        while True:
            remaining = deadline - time.monotonic()
            if remaining <= 0:
                break
            time.sleep(min(1, remaining))
        count = hits(name)
    except KeyboardInterrupt:
        interrupted = True
    finally:
        # If interrupted during create, the UUID identifies only this probe.
        # Even SIGKILL cannot extend the kernel's one-time element timeout.
        if installed:
            try:
                count = hits(name)
            finally:
                remove(name)
        else:
            remove(name)
    after = snapshot()
    preserved = before == after
    emit('RETRY_PROBE_REMOVED', table=name, removed=True, interrupted=interrupted,
         matched_packets=count, protected_files_preserved=before['files'] == after['files'],
         product_processes_preserved=before['pids'] == after['pids'])
    if not preserved:
        raise RuntimeError('PRODUCT_PRESERVATION_CHANGED')


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        emit('RETRY_PROBE_FAILED', category=type(error).__name__)
        raise SystemExit(1)
