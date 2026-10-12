"""Reproduce panel stop propagation only on disposable GitHub-hosted systemd."""
import json
import os
from pathlib import Path
import subprocess
import sys

from tools.radius_install import unit_text
from tools.radius_unit_update import migrate_unit


def command(*args):
    return subprocess.run(list(args), check=True, capture_output=True, timeout=30)


def active(name):
    return subprocess.run(['systemctl', 'is-active', '--quiet', name],
                          capture_output=True, timeout=10).returncode == 0


def pid(name):
    return command('systemctl', 'show', name, '--property=MainPID', '--value').stdout.strip()


def main():
    if (os.geteuid() != 0 or sys.platform != 'linux'
            or os.environ.get('RUNNER_ENVIRONMENT') != 'github-hosted'):
        raise ValueError('Disposable hosted Linux runner required')
    panel = 'authwire-panel-lifecycle-fixture-'+str(os.getpid())+'.service'
    radius = 'authwire-radius-lifecycle-fixture-'+str(os.getpid())+'.service'
    root = Path('/etc/systemd/system')
    paths = [root/panel, root/radius]
    if any(path.exists() or path.is_symlink() for path in paths):
        raise ValueError('Fixture unit name already exists')
    old = unit_text('192.0.2.20').replace('Wants=network-online.target kaname-lab.service\n',
        'Wants=network-online.target\nRequires=kaname-lab.service\n')
    new, changed = migrate_unit(old)
    assert changed
    def fixture(text):
        # Use sleep processes, never native RADIUS, certificates or customer state.
        return text.split('[Service]\n', 1)[0].replace('kaname-lab.service', panel) + \
            '[Service]\nType=simple\nExecStart=/usr/bin/sleep infinity\n'
    try:
        paths[0].write_text('[Unit]\nDescription=Disposable AuthWire panel process\n'
                            '[Service]\nType=simple\nExecStart=/usr/bin/sleep infinity\n')
        paths[1].write_text(fixture(old))
        command('systemctl', 'daemon-reload')
        command('systemctl', 'start', radius)
        assert active(panel) and active(radius)
        command('systemctl', 'stop', panel)
        assert not active(radius), 'Old Requires regression was not reproduced'
        paths[1].write_text(fixture(new))
        command('systemctl', 'daemon-reload')
        command('systemctl', 'start', radius)
        before = pid(radius)
        assert before not in (b'', b'0') and active(panel) and active(radius)
        command('systemctl', 'stop', panel)
        assert active(radius) and pid(radius) == before
        command('systemctl', 'start', panel)
        command('systemctl', 'restart', panel)
        assert active(radius) and pid(radius) == before
        print(json.dumps({'systemd_lifecycle_fixture': 'passed', 'old_failure_reproduced': True,
            'panel_stop_preserves_radius_pid': True, 'panel_restart_preserves_radius_pid': True,
            'real_radius_started': False, 'customer_state_used': False}))
    finally:
        subprocess.run(['systemctl', 'stop', radius, panel], capture_output=True, timeout=30)
        for path in paths:
            path.unlink(missing_ok=True)
        command('systemctl', 'daemon-reload')


if __name__ == '__main__':
    main()
