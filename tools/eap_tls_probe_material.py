"""Operator-only disposable expired/unbound credentials for a pinned pilot.

Root launches the existing service account in a private temporary directory.
The existing unattended ISSUER signs two unrelated probe keys; no root key is
opened, issuer key exported, live database written, or identity bound to AD.
The valid control has a 20-minute lifetime and no authorization binding.
Never print the resulting private bundle or retain it after the test.
"""
import argparse
from datetime import datetime, timedelta, timezone
import hashlib
import json
import os
from pathlib import Path
import pwd
import re
import sqlite3
import subprocess
import sys
import tempfile
import threading


def generate(directory, run_id):
    sys.path.insert(0, '/opt/kaname-lab/source')
    from cryptography import x509
    from cryptography.hazmat.primitives import hashes, serialization
    from cryptography.hazmat.primitives.asymmetric import rsa
    from cryptography.x509.oid import ExtendedKeyUsageOID, NameOID
    from kaname.device_enrollment import DeviceEnrollment
    from kaname.vault import Vault
    state = Path('/var/lib/kaname-lab')
    assert os.geteuid() == state.stat().st_uid and (state / 'secret-store.key').is_file()
    now = datetime.now(timezone.utc).replace(microsecond=0)
    db = sqlite3.connect('file:/var/lib/kaname-lab/kaname.sqlite3?mode=ro', uri=True)
    db.execute('PRAGMA query_only=ON')
    before = db.execute('SELECT count(*) FROM pki_certificates').fetchone()[0]
    root_pem, issuer_pem, crl = db.execute('SELECT root_cert,issuer_cert,crl FROM pki_authority WHERE id=1').fetchone()
    root, issuer = (x509.load_pem_x509_certificate(v) for v in (root_pem, issuer_pem))
    assert root.fingerprint(hashes.SHA1()).hex() == 'c789a0595adb95a6be4534d01b1d205f6c37de18'
    assert issuer.fingerprint(hashes.SHA1()).hex() == 'e981dd42a758b6c2408e211f82833f6b2ec6eed2'
    root_crl = db.execute('SELECT crl FROM pki_root_crls WHERE root_sha256=?', (root.fingerprint(hashes.SHA256()).hex(),)).fetchone()[0]
    for pem, parent in ((crl, issuer), (root_crl, root)):
        value = x509.load_pem_x509_crl(pem)
        assert value.is_signature_valid(parent.public_key()) and value.last_update_utc <= now < value.next_update_utc
    enrollment = DeviceEnrollment.__new__(DeviceEnrollment)
    enrollment.vault = Vault(state)
    enrollment.signer_lock = threading.Lock()
    enrollment.signer_cache = None
    pinned_issuer, issuer_key, _ = enrollment._issuer(db, now)
    assert pinned_issuer.fingerprint(hashes.SHA256()) == issuer.fingerprint(hashes.SHA256())
    pem_format = serialization.Encoding.PEM
    decode = lambda data: data.decode('ascii')
    bundle = {'schema': 1, 'run_id': run_id, 'servername': 'kaname.vizyonveri.local',
              'root': decode(root_pem), 'crls': [decode(crl), decode(root_crl)], 'cases': {}}
    manifest = {'event': 'AUTHWIRE_DISPOSABLE_NEGATIVE_CREDENTIALS', 'run_id': run_id,
                'live_database_read_only': True, 'root_private_key_opened': False,
                'issuer_private_key_exported': False, 'bindings_created': 0, 'certificates': {}}
    probe_key = rsa.generate_private_key(65537, 2048)

    def leaf(label, signing_parent, signing_key, before, after):
        return (x509.CertificateBuilder()
                .subject_name(x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, 'AuthWire isolated probe ' + run_id)]))
                .issuer_name(signing_parent.subject).public_key(probe_key.public_key())
                .serial_number(x509.random_serial_number()).not_valid_before(before).not_valid_after(after)
                .add_extension(x509.BasicConstraints(False, None), True)
                .add_extension(x509.KeyUsage(True, False, False, False, False, False, False, False, False), True)
                .add_extension(x509.ExtendedKeyUsage([ExtendedKeyUsageOID.CLIENT_AUTH]), False)
                .add_extension(x509.SubjectKeyIdentifier.from_public_key(probe_key.public_key()), False)
                .add_extension(x509.AuthorityKeyIdentifier.from_issuer_public_key(signing_key.public_key()), False)
                .sign(signing_key, hashes.SHA256()))

    def add(label, cert, parent):
        serial = format(cert.serial_number, 'x')
        assert db.execute('SELECT 1 FROM pki_certificates WHERE serial=?', (serial,)).fetchone() is None
        assert db.execute('SELECT 1 FROM radius_certificate_bindings WHERE serial=?', (serial,)).fetchone() is None
        bundle['cases'][label] = {'cert': decode(cert.public_bytes(pem_format) + parent.public_bytes(pem_format)),
                                 'key': decode(probe_key.private_bytes(pem_format, serialization.PrivateFormat.PKCS8, serialization.NoEncryption()))}
        manifest['certificates'][label] = {'serial': serial, 'sha256': cert.fingerprint(hashes.SHA256()).hex(),
            'not_before': cert.not_valid_before_utc.isoformat(), 'not_after': cert.not_valid_after_utc.isoformat(),
            'issuer_sha256': parent.fingerprint(hashes.SHA256()).hex(), 'bound': False}

    assert now - timedelta(hours=2) > issuer.not_valid_before_utc
    add('expired', leaf('expired', issuer, issuer_key, now - timedelta(hours=2), now - timedelta(minutes=5)), issuer)
    add('control', leaf('control', issuer, issuer_key, now - timedelta(minutes=5), now + timedelta(minutes=20)), issuer)
    rogue_key = rsa.generate_private_key(65537, 2048)
    rogue_name = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, 'AuthWire UNTRUSTED probe ' + run_id)])
    rogue = (x509.CertificateBuilder().subject_name(rogue_name).issuer_name(rogue_name)
             .public_key(rogue_key.public_key()).serial_number(x509.random_serial_number())
             .not_valid_before(now - timedelta(minutes=5)).not_valid_after(now + timedelta(hours=1))
             .add_extension(x509.BasicConstraints(True, 0), True).sign(rogue_key, hashes.SHA256()))
    add('wrong-issuer', leaf('wrong-issuer', rogue, rogue_key, now - timedelta(minutes=5), now + timedelta(minutes=20)), rogue)
    assert before == db.execute('SELECT count(*) FROM pki_certificates').fetchone()[0]
    db.close()
    directory = Path(directory)
    for filename, value in (('bundle.json', bundle), ('manifest.json', manifest)):
        with open(directory / filename, 'x', encoding='utf-8') as output:
            os.chmod(output.fileno(), 0o600)
            json.dump(value, output)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('run_id')
    parser.add_argument('--child-directory')
    args = parser.parse_args()
    assert re.fullmatch(r'20261106-negative-[0-9a-f]{16}', args.run_id)
    if args.child_directory:
        generate(args.child_directory, args.run_id)
        return
    assert os.geteuid() == 0
    service, operator = pwd.getpwnam('kaname-lab'), pwd.getpwnam('segmentiq')
    destination = Path('/home/segmentiq') / args.run_id
    if destination.exists():
        assert not destination.is_symlink() and destination.is_dir()
        assert destination.stat().st_uid == operator.pw_uid and destination.stat().st_mode & 0o077 == 0
        assert not list(destination.iterdir()), 'Existing nonempty probe output must be reviewed'
    else:
        destination.mkdir(mode=0o700)
        os.chown(destination, operator.pw_uid, operator.pw_gid)
    with tempfile.TemporaryDirectory(prefix='authwire-probe-') as temporary:
        os.chown(temporary, service.pw_uid, service.pw_gid)
        script = Path(temporary) / 'generate.py'
        script.write_bytes(Path(__file__).read_bytes())
        script.chmod(0o400); os.chown(script, service.pw_uid, service.pw_gid)
        completed = subprocess.run(['/usr/sbin/runuser', '-u', 'kaname-lab', '--', '/opt/kaname-lab/venv/bin/python3',
                        '-I', '-B', str(script), args.run_id, '--child-directory', temporary],
                       capture_output=True, timeout=30)
        if completed.returncode:
            # Trusted local exception types only; never emit bundle content.
            error = completed.stderr.decode('utf-8', errors='replace').splitlines()
            raise RuntimeError('Probe preparation refused: ' + (error[-1] if error else 'child failed'))
        for filename in ('bundle.json', 'manifest.json'):
            data = (Path(temporary) / filename).read_bytes()
            fd = os.open(destination / filename, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
            with os.fdopen(fd, 'wb') as handle:
                handle.write(data); os.fchown(handle.fileno(), operator.pw_uid, operator.pw_gid)
        manifest = json.loads((destination / 'manifest.json').read_text())
        manifest['bundle_sha256'] = hashlib.sha256((destination / 'bundle.json').read_bytes()).hexdigest()
        print(json.dumps(manifest))


if __name__ == '__main__':
    main()
