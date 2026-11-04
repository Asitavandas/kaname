"""Actual backup installer/oneshot on a disposable hosted VM with fixture-only PKI."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import sqlite3
import subprocess
import sys
import tarfile
import tempfile
import time

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
from tools import backup_upgrade as upgrader
from tools import scheduled_backup as worker


def command(*args):
    return subprocess.run(list(args), check=True, text=True, capture_output=True, timeout=90)


def private_package_file(path, data):
    """Do not inherit hosted /opt default ACL masks for a trusted root stage."""
    path.write_bytes(data)
    os.chown(path, 0, 0)
    path.chmod(0o600)


def main():
    if os.geteuid() != 0 or os.environ.get('RUNNER_ENVIRONMENT') != 'github-hosted':
        raise ValueError('Disposable GitHub-hosted root fixture required')
    dirs = [Path('/etc/kaname-lab'), Path('/var/lib/kaname-lab'), Path('/opt/kaname-lab'),
            Path('/opt/authwire-radius'), Path('/opt/authwire-service-control'),
            Path('/var/lib/authwire-service-control'), Path('/opt/authwire-backup'), Path('/var/backups/authwire'),
            Path('/opt/authwire-backup-upgrades'), Path('/opt/authwire-backup-upgrade-package')]
    units = [Path('/etc/systemd/system') / name for name in worker.UNITS]
    extra = [Path('/run/kaname-lab-update.lock'), Path('/etc/tmpfiles.d/authwire-service-control.conf')]
    fixture_timer = Path('/etc/systemd/system/authwire-backup-fixture.timer')
    extra.append(fixture_timer)
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
            for name in installer.FILES:
                original = (source / 'tests/fixtures/scheduled_backup_dev44.py'
                            if name == 'scheduled_backup.py' else source / 'tools' / name)
                shutil.copy2(original, stage / name)
            manifest = json.dumps({n: worker.digest(stage / n) for n in installer.FILES}).encode()
            (stage / 'manifest.json').write_bytes(manifest)
            expected = hashlib.sha256(manifest).hexdigest()
            result = installer.install(stage, expected)
            assert result['verified'] and result['initial_data_restore']['data_restore_exercised']
            assert result['product_processes_preserved'] and worker.pids() == before
            command('systemctl', 'stop', installer.TIMER.name)
            # Exercise a real timer firing the same hardened worker, without advancing time.
            deadline = time.monotonic() + 20
            while command('systemctl', 'show', installer.SERVICE.name, '--property=ActiveState', '--value').stdout.strip() == 'activating':
                if time.monotonic() >= deadline: raise ValueError('Fixture worker did not finish')
                time.sleep(0.1)
            last_success = Path('/var/backups/authwire/scheduled/last-success.json')
            previous_backup = json.loads(last_success.read_text())['backup']
            fixture_timer.write_text('[Timer]\nOnActiveSec=1s\nAccuracySec=1s\nUnit=authwire-backup.service\n')
            command('systemctl', 'daemon-reload'); command('systemctl', 'start', fixture_timer.name)
            deadline = time.monotonic() + 20
            while json.loads(last_success.read_text())['backup'] == previous_backup:
                if time.monotonic() >= deadline: raise ValueError('Fixture timer did not publish backup')
                time.sleep(0.1)
            command('systemctl', 'stop', fixture_timer.name)
            # A real read-only systemd sandbox must also capture committed WAL bytes.
            db = sqlite3.connect(state / 'administrators.sqlite3')
            try:
                db.execute('PRAGMA journal_mode=WAL')
                db.execute('INSERT INTO admin_login_rate(id,started,attempts) VALUES (1,1,17)')
                db.commit()
                command('systemctl', 'start', installer.SERVICE.name)
                wal_record = json.loads(last_success.read_text())
                with tarfile.open(wal_record['backup']) as tar, tempfile.TemporaryDirectory() as copied:
                    copied_db = Path(copied) / 'admin.sqlite3'
                    copied_db.write_bytes(tar.extractfile('var/lib/kaname-lab/administrators.sqlite3').read())
                    with sqlite3.connect(copied_db) as reader:
                        assert reader.execute('SELECT attempts FROM admin_login_rate').fetchone()[0] == 17
            finally: db.close()
            # Exercise the separate source upgrader against real root paths,
            # real systemd state and real encrypted fixture data. A deliberately
            # stopped RADIUS must remain stopped throughout both upgrade modes.
            command('systemctl', 'stop', 'authwire-radius.service')
            stopped = worker.pids()
            assert stopped['authwire-radius.service'] == '0'
            assert all(stopped[n] == before[n] for n in before if n != 'authwire-radius.service')
            before = stopped
            upgrade_stage = Path('/opt/authwire-backup-upgrade-package')
            upgrade_stage.mkdir(mode=0o700)
            for timer_active in (False, True):
                if timer_active: command('systemctl', 'start', installer.TIMER.name)
                installed_release = worker.digest(installer.TARGET / 'release.json')
                for name in installer.FILES:
                    data = (source / 'tools' / name).read_bytes()
                    if timer_active: data += b'\n# disposable second-upgrade fixture\n'
                    private_package_file(upgrade_stage / name, data)
                manifest = json.dumps({n: worker.digest(upgrade_stage / n) for n in installer.FILES}).encode()
                private_package_file(upgrade_stage / 'manifest.json', manifest)
                package_pin = hashlib.sha256(manifest).hexdigest()
                reviewed = upgrader.perform(upgrade_stage, package_pin, installed_release, inspect=True)
                assert reviewed['event'] == 'BACKUP_UPGRADE_REVIEW' and not reviewed['live_update_applied']
                outcome = upgrader.perform(upgrade_stage, package_pin, installed_release, upgrader.ACK)
                assert outcome['event'] == 'BACKUP_UPGRADE_SUCCESS' and outcome['timer_state_restored']
                assert worker.pids() == before
                active = command('systemctl', 'show', installer.TIMER.name, '--property=ActiveState', '--value').stdout.strip()
                assert active == ('active' if timer_active else 'inactive')
                command('systemctl', 'stop', installer.TIMER.name)
                # Root maintenance capture is separate from this real hardened
                # unit execution: the upgraded source must pass both.
                command('systemctl', 'start', installer.SERVICE.name)
                record = json.loads(last_success.read_text())
                assert record['event'] == 'BACKUP_SUCCESS' and worker.pids() == before
            # A real maintenance capture followed by a pinned checker failure
            # must restore only old source and preserve all scheduled records.
            installed_release = worker.digest(installer.TARGET / 'release.json')
            checker = upgrade_stage / 'offline_restore_check.py'
            private_package_file(checker, checker.read_bytes() + b'\ndef check(*args):\n    raise ValueError("disposable restore refusal")\n')
            manifest = json.dumps({n: worker.digest(upgrade_stage / n) for n in installer.FILES}).encode()
            private_package_file(upgrade_stage / 'manifest.json', manifest)
            refused = upgrader.perform(upgrade_stage, hashlib.sha256(manifest).hexdigest(), installed_release, upgrader.ACK)
            assert refused['event'] == 'BACKUP_UPGRADE_ROLLED_BACK'
            assert worker.digest(installer.TARGET / 'release.json') == installed_release and worker.pids() == before
            upgrader.journal()
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
                              'real_timer_trigger_verified': True,
                              'real_sqlite_and_fixture_pki_restore': True, 'foreign_uid_state_read': True,
                              'wal_snapshot_verified': True, 'failure_recorded': True,
                              'atomic_upgrade_and_isolated_restore_verified': True,
                              'frozen_dev44_worker_upgraded': True,
                              'restore_failure_source_rollback_verified': True,
                              'upgraded_real_hardened_service_verified': True,
                              'active_and_inactive_timer_states_preserved': True,
                              'stopped_radius_preserved_during_upgrade': True,
                              'product_fixture_processes_preserved': True, 'customer_data_used': False}))
    finally:
        subprocess.run(['systemctl', 'stop', fixture_timer.name], capture_output=True, timeout=30)
        subprocess.run(['systemctl', 'disable', '--now', installer.TIMER.name], capture_output=True, timeout=30)
        subprocess.run(['systemctl', 'stop', *worker.UNITS], capture_output=True, timeout=30)
        for path in units + extra: path.unlink(missing_ok=True)
        subprocess.run(['systemctl', 'daemon-reload'], capture_output=True, timeout=30)
        for p in dirs + [Path('/var/lib/authwire-restore-checks')]:
            if p.exists(): shutil.rmtree(p)
        os.chown(opt, opt_info.st_uid, opt_info.st_gid); opt.chmod(opt_info.st_mode & 0o7777)


if __name__ == '__main__': main()

