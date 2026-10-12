"""Install the tested FreeRADIUS runtime and a disabled AuthWire systemd unit.

This does not initialize the RADIUS server certificate, enable the unit, start a
listener, alter firewall rules, or change network devices.
"""
import argparse
import hashlib
import ipaddress
import json
import os
from pathlib import Path, PurePosixPath
import pwd
import re
import shutil
import stat
import subprocess
import sys
import tempfile


PRODUCT = Path('/opt/authwire-radius')
UNIT = Path('/etc/systemd/system/authwire-radius.service')
PANEL_UNIT = Path('/etc/systemd/system/kaname-lab.service')
ACCOUNT = 'kaname-lab'
EXPECTED_COMMIT = '9071ea041b9172e52eabbba91619afaf3a238795'
EXPECTED_PATCHES = ['58bafac6e5d4eb098d533cc0e7fe2fd41a73d213']


def verified_runtime(source, expected_digest):
    source = Path(source)
    if not re.fullmatch(r'[0-9a-f]{64}', expected_digest):
        raise ValueError('Expected RADIUS runtime digest required')
    manifest_path = source / 'RADIUS_RUNTIME_MANIFEST.json'
    if source.is_symlink() or not source.is_dir() or manifest_path.is_symlink() or not manifest_path.is_file():
        raise ValueError('Invalid RADIUS runtime stage')
    raw = manifest_path.read_bytes()
    if hashlib.sha256(raw).hexdigest() != expected_digest:
        raise ValueError('RADIUS runtime manifest changed')
    manifest = json.loads(raw)
    if set(manifest) != {'artifact', 'upstream_commit', 'upstream_patches', 'files'} or manifest['artifact'] != 'authwire-freeradius-runtime':
        raise ValueError('Invalid RADIUS runtime manifest')
    if (manifest['upstream_commit'] != EXPECTED_COMMIT or manifest['upstream_patches'] != EXPECTED_PATCHES
            or type(manifest['files']) is not dict):
        raise ValueError('Unexpected FreeRADIUS source revision')
    files = {}
    for name, metadata in manifest['files'].items():
        relative = PurePosixPath(name)
        if (relative.is_absolute() or '..' in relative.parts or not relative.parts or
                relative.parts[0] not in {'lib', 'sbin', 'share'} or relative.as_posix() != name):
            raise ValueError('Unsafe RADIUS runtime path')
        if type(metadata) is not dict or set(metadata) != {'sha256', 'mode'}:
            raise ValueError('Invalid RADIUS runtime metadata')
        mode = metadata['mode']
        if type(mode) is not int or mode < 0 or mode > 0o777 or mode & 0o022:
            raise ValueError('Writable RADIUS runtime artifact refused')
        path = source / name
        if path.is_symlink() or not path.is_file() or path.stat().st_size > 100_000_000:
            raise ValueError('Invalid staged RADIUS file')
        data = path.read_bytes()
        if hashlib.sha256(data).hexdigest() != metadata['sha256']:
            raise ValueError('Staged RADIUS file changed')
        files[name] = (data, mode)
    for required in ('sbin/radiusd', 'share/freeradius/dictionary'):
        if required not in files:
            raise ValueError('Incomplete RADIUS runtime')
    if len([name for name in files if name.endswith('/rlm_python3.so') or name == 'lib/rlm_python3.so']) != 1:
        raise ValueError('Exactly one rlm_python3 module required')
    return files, raw


def unit_text(listen_ip):
    return f'''[Unit]
Description=AuthWire EAP-TLS RADIUS authentication service
After=network-online.target kaname-lab.service
Wants=network-online.target kaname-lab.service

[Service]
Type=simple
User=kaname-lab
Group=kaname-lab
WorkingDirectory=/opt/kaname-lab/source
Environment=PYTHONUNBUFFERED=1
Environment=PYTHONDONTWRITEBYTECODE=1
Environment=PYTHONPATH=/opt/kaname-lab/source:/opt/kaname-lab/venv/lib/python3.12/site-packages
Environment=LD_LIBRARY_PATH=/opt/authwire-radius/lib
RuntimeDirectory=authwire-radius
RuntimeDirectoryMode=0700
ExecStartPre=/opt/kaname-lab/venv/bin/python -B -m tools.radius_runtime --output /run/authwire-radius --prefix /opt/authwire-radius --state-dir /var/lib/kaname-lab --listen-ip {listen_ip}
ExecStart=/opt/authwire-radius/sbin/radiusd -f -D /opt/authwire-radius/share/freeradius -d /run/authwire-radius
Restart=on-failure
RestartSec=5
TimeoutStopSec=20
UMask=0077
NoNewPrivileges=yes
PrivateTmp=yes
PrivateDevices=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=/var/lib/kaname-lab /run/authwire-radius
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectControlGroups=yes
ProtectKernelLogs=yes
ProtectClock=yes
ProtectHostname=yes
RestrictSUIDSGID=yes
RestrictNamespaces=yes
LockPersonality=yes
RestrictRealtime=yes
RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6
CapabilityBoundingSet=
SystemCallArchitectures=native
TasksMax=256
LimitNOFILE=4096

[Install]
WantedBy=multi-user.target
'''


def install(source, digest):
    if os.geteuid() != 0 or sys.platform != 'linux':
        raise ValueError('Local Linux sudo required')
    if 'ID=ubuntu' not in Path('/etc/os-release').read_text() or 'VERSION_ID="24.04"' not in Path('/etc/os-release').read_text():
        raise ValueError('Ubuntu 24.04 required')
    pwd.getpwnam(ACCOUNT)
    if PANEL_UNIT.is_symlink() or not PANEL_UNIT.is_file() or PANEL_UNIT.stat().st_uid != 0 or PANEL_UNIT.stat().st_mode & 0o022:
        raise ValueError('Trusted AuthWire panel service required')
    panel_text = PANEL_UNIT.read_text()
    listen = re.findall(r'--listen ([0-9.]+) --port 8765', panel_text)
    if len(listen) != 1:
        raise ValueError('AuthWire panel listen address not found')
    listen_ip = str(ipaddress.IPv4Address(listen[0]))
    if ipaddress.ip_address(listen_ip).is_unspecified or ipaddress.ip_address(listen_ip).is_multicast:
        raise ValueError('Unsafe AuthWire panel listen address')
    if PRODUCT.exists() or PRODUCT.is_symlink() or UNIT.exists() or UNIT.is_symlink():
        raise ValueError('Existing AuthWire RADIUS installation found; automatic overwrite refused')
    files, manifest = verified_runtime(source, digest)

    parent = PRODUCT.parent
    with tempfile.TemporaryDirectory(prefix='authwire-radius-', dir=parent) as temporary:
        candidate = Path(temporary) / 'runtime'
        candidate.mkdir(mode=0o755)
        for name, (data, mode) in files.items():
            target = candidate / name
            target.parent.mkdir(parents=True, exist_ok=True, mode=0o755)
            target.write_bytes(data)
            target.chmod(mode)
        (candidate / 'RADIUS_RUNTIME_MANIFEST.json').write_bytes(manifest)
        (candidate / 'RADIUS_RUNTIME_MANIFEST.json').chmod(0o644)
        # Refuse a runtime that cannot load its external shared libraries.
        env = dict(os.environ); env['LD_LIBRARY_PATH'] = str(candidate / 'lib')
        check = subprocess.run(['ldd', str(candidate / 'sbin/radiusd')], env=env, capture_output=True, text=True, timeout=15)
        if check.returncode != 0 or 'not found' in check.stdout or 'not found' in check.stderr:
            raise ValueError('FreeRADIUS runtime dependency missing on this Ubuntu host')
        os.rename(candidate, PRODUCT)

    try:
        descriptor = os.open(UNIT, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o644)
        with os.fdopen(descriptor, 'w') as handle:
            handle.write(unit_text(listen_ip))
        subprocess.run(['systemd-analyze', 'verify', str(UNIT)], check=True, capture_output=True, timeout=20)
        subprocess.run(['systemctl', 'daemon-reload'], check=True, capture_output=True, timeout=20)
        subprocess.run(['systemctl', 'disable', 'authwire-radius.service'], capture_output=True, timeout=20)
    except Exception:
        if UNIT.exists():
            UNIT.unlink()
        if PRODUCT.exists():
            shutil.rmtree(PRODUCT)
        subprocess.run(['systemctl', 'daemon-reload'], capture_output=True, timeout=20)
        raise
    enabled = subprocess.run(['systemctl', 'is-enabled', '--quiet', 'authwire-radius.service'], timeout=10).returncode == 0
    active = subprocess.run(['systemctl', 'is-active', '--quiet', 'authwire-radius.service'], timeout=10).returncode == 0
    if enabled or active:
        raise ValueError('RADIUS service unexpectedly enabled or active')
    return {'installed': True, 'upstream_commit': EXPECTED_COMMIT, 'upstream_patches': EXPECTED_PATCHES,
            'runtime_digest': digest,
            'service_enabled': False, 'service_started': False, 'listen_ip': listen_ip, 'firewall_changed': False,
            'network_devices_changed': False}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--runtime-source', required=True)
    parser.add_argument('--runtime-digest', required=True)
    args = parser.parse_args()
    try:
        print(json.dumps(install(args.runtime_source, args.runtime_digest)))
        return 0
    except Exception as error:
        print(json.dumps({'installed': False, 'error': 'RADIUS_INSTALL_FAILED',
                          'category': type(error).__name__, 'check': str(error)}))
        return 1


if __name__ == '__main__':
    sys.exit(main())

