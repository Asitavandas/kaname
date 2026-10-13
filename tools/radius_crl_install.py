"""Install the verified low-privilege CRL sync timer; preserve AuthWire state."""
import argparse
import fcntl
import json
import os
from pathlib import Path
import stat
import subprocess
import sys

ROOT = Path('/opt/kaname-lab/source')
SERVICE = Path('/etc/systemd/system/authwire-radius-crl-sync.service')
TIMER = Path('/etc/systemd/system/authwire-radius-crl-sync.timer')
RADIUS_UNIT = Path('/etc/systemd/system/authwire-radius.service')
LOCK = Path('/run/kaname-lab-update.lock')
_PHASE = 'preflight'


def service_text():
    return '''[Unit]
Description=Publish verified AuthWire CRL to active RADIUS runtime
After=authwire-radius.service
ConditionPathIsDirectory=/run/authwire-radius/ca

[Service]
Type=oneshot
User=kaname-lab
Group=kaname-lab
WorkingDirectory=/opt/kaname-lab/source
ExecStart=/opt/kaname-lab/venv/bin/python -I -B /opt/kaname-lab/source/tools/radius_crl_sync.py
UMask=0077
NoNewPrivileges=yes
PrivateTmp=yes
PrivateDevices=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=/run/authwire-radius/ca /var/lib/kaname-lab
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
RestrictAddressFamilies=AF_UNIX
CapabilityBoundingSet=
SystemCallArchitectures=native
TimeoutStartSec=30
'''


def timer_text():
    return '''[Unit]
Description=Keep active AuthWire RADIUS revocation data current

[Timer]
OnCalendar=minutely
Persistent=yes
AccuracySec=5s
Unit=authwire-radius-crl-sync.service

[Install]
WantedBy=timers.target
'''


def protected(path, directory=False):
    if path.is_symlink() or not (path.is_dir() if directory else path.is_file()):
        raise ValueError('Unsafe installed path')
    info = path.stat()
    if info.st_uid != 0 or info.st_mode & 0o022:
        raise ValueError('Protected root-owned code/unit required')


def command(*args):
    return subprocess.run(list(args), check=True, capture_output=True, timeout=60)


def active():
    return subprocess.run(['systemctl', 'is-active', '--quiet', 'authwire-radius.service'],
                          capture_output=True, timeout=10).returncode == 0


def preservation_digest():
    path = ROOT/'tools/linux_update.py'
    protected(path)
    namespace = {'__name__': 'verified_installed_update', '__file__': str(path)}
    exec(compile(path.read_bytes(), str(path), 'exec'), namespace)
    return namespace['control_digest'](Path('/var/lib/kaname-lab'))


def _install():
    global _PHASE
    for path in (ROOT, ROOT/'tools', SERVICE.parent):
        protected(path, directory=True)
    for path in (ROOT/'tools/radius_crl_sync.py', ROOT/'tools/radius_runtime.py', RADIUS_UNIT):
        protected(path)
    if 'ca_path_reload_interval = 300\n' not in (ROOT/'tools/radius_runtime.py').read_text():
        raise ValueError('Install tested X509 reload configuration first')
    if not active():
        raise ValueError('Explicitly start existing RADIUS before timer installation')
    expected = [(SERVICE, service_text()), (TIMER, timer_text())]
    for path, text in expected:
        if path.exists() or path.is_symlink():
            protected(path)
            if path.read_text() != text:
                raise ValueError('Existing sync unit differs; overwrite refused')
    before = preservation_digest()
    primary_unit = RADIUS_UNIT.read_bytes()
    created = []
    try:
        _PHASE = 'sync_units'
        for path, text in expected:
            if not path.exists():
                descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o644)
                with os.fdopen(descriptor, 'w') as handle:
                    handle.write(text)
                created.append(path)
        command('systemd-analyze', 'verify', str(SERVICE), str(TIMER))
        command('systemctl', 'daemon-reload')
        eap = Path('/run/authwire-radius/mods-enabled/eap')
        _PHASE = 'cache_reload_configuration'
        restarted = False
        if 'ca_path_reload_interval = 300\n' not in eap.read_text():
            # One initial restart enables native cache refresh. Later CRL
            # publication and cache updates never stop the process.
            command('systemctl', 'restart', 'authwire-radius.service')
            restarted = True
        if not active() or 'ca_path_reload_interval = 300\n' not in eap.read_text():
            raise ValueError('Native X509 cache refresh not active')
        _PHASE = 'first_sync'
        result = command('/usr/sbin/runuser', '-u', 'kaname-lab', '--',
                         '/opt/kaname-lab/venv/bin/python', '-I', '-B', str(ROOT/'tools/radius_crl_sync.py'))
        sync = json.loads(result.stdout)
        if sync.get('synced') is not True:
            raise ValueError('Initial CRL publication failed')
        _PHASE = 'timer_enable'
        command('systemctl', 'enable', '--now', TIMER.name)
        command('systemctl', 'is-active', '--quiet', TIMER.name)
        command('systemctl', 'is-enabled', '--quiet', TIMER.name)
        _PHASE = 'preservation_check'
        if primary_unit != RADIUS_UNIT.read_bytes() or before != preservation_digest():
            raise ValueError('Protected configuration changed')
    except Exception:
        if created:
            subprocess.run(['systemctl', 'disable', '--now', TIMER.name], capture_output=True, timeout=30)
            for path in created:
                path.unlink(missing_ok=True)
            command('systemctl', 'daemon-reload')
        raise
    return {'installed': True, 'timer_enabled': True, 'timer_active': True,
            'sync_interval_seconds': 60, 'x509_reload_interval_seconds': 300,
            'initial_radius_restart': restarted, 'radius_active': True,
            'persistent_configuration_preserved': True, 'radius_unit_preserved': True,
            'crl': sync, 'periodic_radius_restart': False}


def install():
    if os.geteuid() != 0 or sys.platform != 'linux':
        raise ValueError('Local Linux sudo required')
    descriptor = os.open(LOCK, os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW, 0o600)
    with os.fdopen(descriptor, 'r+') as lock:
        info = os.fstat(lock.fileno())
        if (not stat.S_ISREG(info.st_mode) or info.st_uid != 0 or info.st_nlink != 1
                or info.st_mode & 0o077):
            raise ValueError('Private update lock required')
        fcntl.flock(lock.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        return _install()


def main():
    argparse.ArgumentParser().parse_args()
    try:
        print(json.dumps(install()))
        return 0
    except Exception as error:
        print(json.dumps({'installed': False, 'error': 'CRL_TIMER_INSTALL_FAILED',
                          'phase': _PHASE, 'category': type(error).__name__}))
        return 1


if __name__ == '__main__':
    sys.exit(main())
