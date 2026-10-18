"""Actual backup installer/oneshot on a disposable hosted VM with fixture-only PKI."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import sqlite3
import subprocess
import sys
import tempfile

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import ec
from kaname.admin import AdminStore
from kaname.device_enrollment import DeviceEnrollment
from kaname.enrollment import EnrollmentService
from kaname.operations import Operations
from kaname.pki import PKIService
from tests.helpers import config
from tests.test_pki import PASSWORD, csr
from tools import backup_install as installer
from tools import scheduled_backup as worker


def command(*args):
    return subprocess.run(list(args), check=True, text=True, capture_output=True, timeout=90)


def main():
    if os.geteuid() != 0 or os.environ.get('RUNNER_ENVIRONMENT') != 'github-hosted':
        raise ValueError('Disposable GitHub-hosted root fixture required')
    dirs = [Path('/etc/kaname-lab'), Path('/var/lib/kaname-lab'), Path('/opt/kaname-lab'),
            Path('/opt/authwire-radius'), Path('/opt/authwire-service-control'),
            Path('/var/lib/authwire-service-control'), Path('/opt/authwire-backup'), Path('/var/backups/authwire')]
    units = [Path('/etc/systemd/system') / name for name in worker.UNITS]
    extra = [Path('/run/kaname-lab-update.lock'), Path('/etc/tmpfiles.d/authwire-service-control.conf')]
    if any(p.exists() or p.is_symlink() for p in dirs + units + extra):
        raise ValueError('Existing installation or lock refused on disposable fixture')
    source = Path(__file__).resolve().parents[1]
    # Hosted images may grant the runner write access to /opt. Emulate the
    # protected appliance parent instead of weakening the actual installer.
    opt = Path('/opt'); opt_info = opt.stat()
    try:
        os.chown(opt, 0, 0); opt.chmod(0o755)
        for name in worker.ROOT_NAMES:
            if name != 'opt/authwire-backup': Path('/' + name).mkdir(parents=True)
        pki = PKIService('/var/lib/kaname-lab'); pki.store.save(0, config=config()); pki.initialize(PASSWORD)
        AdminStore(pki.store); operations = Operations(pki.store); EnrollmentService(operations)
        device = DeviceEnrollment(operations); device.unlock_signer(PASSWORD, 'disposable-fixture')
        key = ec.generate_private_key(ec.SECP256R1()); cert = pki.issue_radius(csr(key), PASSWORD)
        private = key.private_bytes(serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8, serialization.NoEncryption())
        for certpath, keypath in [('/etc/kaname-lab/web.crt', '/etc/kaname-lab/web.key'),
                                  ('/var/lib/kaname-lab/radius/server.pem', '/var/lib/kaname-lab/radius/server-key.pem')]:
            for name, data in [(certpath, cert), (keypath, private)]:
                p = Path(name); p.parent.mkdir(parents=True, exist_ok=True); p.write_bytes(data); p.chmod(0o600)
        Path('/opt/kaname-lab/venv/bin').mkdir()
        Path('/opt/kaname-lab/venv/bin/python').symlink_to(sys.executable)
        for name in ('AuthWire-Client.ps1', 'Install-AuthWire.ps1'):
            target = Path('/opt/kaname-lab/source/kaname/device_client') / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source / 'kaname/device_client' / name, target)
        native = Path('/opt/authwire-radius/lib/rlm_python3.so'); native.parent.mkdir(); native.write_bytes(b'fixture bytes, never executed')
        Path('/opt/authwire-service-control/broker.py').write_text('# fixture bytes, never executed\n')
        extra[1].write_text('f /run/kaname-lab-update.lock 0600 root root -\n')
        # Real backup capability must read state owned by a different uid.
        state = Path('/var/lib/kaname-lab')
        for p in [state, *state.rglob('*')]: os.chown(p, 65534, 65534)
        state.chmod(0o700)
        for path in units[:3]: path.write_text('[Service]\nExecStart=/usr/bin/sleep infinity\n')
        units[3].write_text('[Service]\nType=oneshot\nExecStart=/usr/bin/true\n')
        units[4].write_text('[Timer]\nOnActiveSec=1h\nUnit=authwire-radius-crl-sync.service\n')
        command('systemctl', 'daemon-reload')
        command('systemctl', 'start', *worker.PRODUCT_UNITS)
        before = worker.pids()
        with tempfile.TemporaryDirectory(prefix='backup-package-') as tmp:
            stage = Path(tmp)
            for name in installer.FILES: shutil.copy2(source / 'tools' / name, stage / name)
            manifest = json.dumps({n: worker.digest(stage / n) for n in installer.FILES}).encode()
            (stage / 'manifest.json').write_bytes(manifest)
            expected = hashlib.sha256(manifest).hexdigest()
            result = installer.install(stage, expected)
            assert result['verified'] and result['initial_data_restore']['data_restore_exercised']
            assert result['product_processes_preserved'] and worker.pids() == before
            command('systemctl', 'stop', installer.TIMER.name)
            # A real read-only systemd sandbox must also capture committed WAL bytes.
            db = sqlite3.connect(state / 'administrators.sqlite3')
            try:
                db.execute('PRAGMA journal_mode=WAL')
                db.execute('UPDATE admin_sessions SET last_seen=last_seen')
                db.commit()
                command('systemctl', 'start', installer.SERVICE.name)
            finally: db.close()
            latest = json.loads(Path('/var/backups/authwire/scheduled/last-run.json').read_text())
            assert latest['event'] == 'BACKUP_SUCCESS'
            previous = Path('/var/backups/authwire/scheduled/last-success.json').read_bytes()
            # A missing required runtime forces a recorded failure without product stop actions.
            secret = state / 'secret-store.key'; original = secret.read_bytes()
            try:
                Path('/opt/authwire-radius').rename('/opt/authwire-radius-held')
                failed = subprocess.run(['systemctl', 'start', installer.SERVICE.name], capture_output=True, timeout=90)
                assert failed.returncode != 0
            finally:
                Path('/opt/authwire-radius-held').rename('/opt/authwire-radius')
            record = json.loads(Path('/var/backups/authwire/scheduled/last-run.json').read_text())
            assert record['event'] == 'BACKUP_FAILED' and not record['previous_backups_pruned']
            assert previous == Path('/var/backups/authwire/scheduled/last-success.json').read_bytes()
            assert secret.read_bytes() == original and worker.pids() == before
            print(json.dumps({'event': 'BACKUP_SYSTEMD_FIXTURE_OK', 'real_hardened_service': True,
                              'real_sqlite_and_fixture_pki_restore': True, 'foreign_uid_state_read': True,
                              'wal_snapshot_verified': True, 'failure_recorded': True,
                              'product_fixture_processes_preserved': True, 'customer_data_used': False}))
    finally:
        subprocess.run(['systemctl', 'disable', '--now', installer.TIMER.name], capture_output=True, timeout=30)
        subprocess.run(['systemctl', 'stop', *worker.UNITS], capture_output=True, timeout=30)
        for path in units + extra: path.unlink(missing_ok=True)
        subprocess.run(['systemctl', 'daemon-reload'], capture_output=True, timeout=30)
        for p in dirs + [Path('/var/lib/authwire-restore-checks')]:
            if p.exists(): shutil.rmtree(p)
        os.chown(opt, opt_info.st_uid, opt_info.st_gid); opt.chmod(opt_info.st_mode & 0o7777)


if __name__ == '__main__': main()
