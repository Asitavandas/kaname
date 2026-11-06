"""Replace only an expired disposable probe bundle with a fresh UNTRUSTED CA.

Uses the prior public CA/CRL material. Never opens a real CA signing key or
production database, imports trust, or writes outside the private probe folder.
"""
import argparse
from datetime import datetime, timedelta, timezone
import hashlib
import json
import os
from pathlib import Path
import re
from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.x509.oid import ExtendedKeyUsageOID, NameOID


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('directory', type=Path)
    parser.add_argument('expected_sha256')
    args = parser.parse_args()
    folder = args.directory
    assert re.fullmatch(r'20261106-negative-[0-9a-f]{16}', folder.name)
    assert folder.parent == Path('/home/segmentiq')
    assert folder.is_dir() and not folder.is_symlink() and folder.stat().st_uid == os.getuid()
    assert folder.stat().st_mode & 0o077 == 0
    target = folder / 'bundle.json'
    assert not target.is_symlink() and target.stat().st_mode & 0o077 == 0
    prior = target.read_bytes()
    assert hashlib.sha256(prior).hexdigest() == args.expected_sha256
    old = json.loads(prior)
    assert old['run_id'] == folder.name and old['servername'] == 'kaname.vizyonveri.local'
    now = datetime.now(timezone.utc).replace(microsecond=0)
    root = x509.load_pem_x509_certificate(old['root'].encode())
    issuer = x509.load_pem_x509_certificates(old['cases']['expired']['cert'].encode())[1]
    assert root.fingerprint(hashes.SHA1()).hex() == 'c789a0595adb95a6be4534d01b1d205f6c37de18'
    assert issuer.fingerprint(hashes.SHA1()).hex() == 'e981dd42a758b6c2408e211f82833f6b2ec6eed2'
    for pem, parent in zip(old['crls'], (issuer, root)):
        crl = x509.load_pem_x509_crl(pem.encode())
        assert crl.is_signature_valid(parent.public_key()) and crl.last_update_utc <= now < crl.next_update_utc
    ca_key, key = rsa.generate_private_key(65537, 2048), rsa.generate_private_key(65537, 2048)
    ca_name = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, 'AuthWire isolated UNTRUSTED CA')])
    ca = (x509.CertificateBuilder().subject_name(ca_name).issuer_name(ca_name).public_key(ca_key.public_key())
          .serial_number(x509.random_serial_number()).not_valid_before(now-timedelta(minutes=5)).not_valid_after(now+timedelta(hours=1))
          .add_extension(x509.BasicConstraints(True, 0), True)
          .add_extension(x509.KeyUsage(True, False, False, False, False, True, True, False, False), True)
          .sign(ca_key, hashes.SHA256()))
    cert = (x509.CertificateBuilder().subject_name(x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, 'AuthWire isolated probe '+folder.name)]))
            .issuer_name(ca.subject).public_key(key.public_key()).serial_number(x509.random_serial_number())
            .not_valid_before(now-timedelta(minutes=5)).not_valid_after(now+timedelta(minutes=20))
            .add_extension(x509.BasicConstraints(False, None), True)
            .add_extension(x509.KeyUsage(True, False, False, False, False, False, False, False, False), True)
            .add_extension(x509.ExtendedKeyUsage([ExtendedKeyUsageOID.CLIENT_AUTH]), False)
            .add_extension(x509.SubjectKeyIdentifier.from_public_key(key.public_key()), False)
            .add_extension(x509.AuthorityKeyIdentifier.from_issuer_public_key(ca_key.public_key()), False)
            .sign(ca_key, hashes.SHA256()))
    pem = serialization.Encoding.PEM
    fresh = {**old, 'cases': {'wrong-issuer': {'cert': (cert.public_bytes(pem)+ca.public_bytes(pem)).decode(),
             'key': key.private_bytes(pem, serialization.PrivateFormat.PKCS8, serialization.NoEncryption()).decode()}}}
    manifest = {'event': 'AUTHWIRE_FRESH_UNTRUSTED_PROBE', 'run_id': folder.name,
                'serial': format(cert.serial_number, 'x'), 'sha256': cert.fingerprint(hashes.SHA256()).hex(),
                'not_after': cert.not_valid_after_utc.isoformat(), 'real_ca_keys_opened': False,
                'production_database_opened': False, 'trust_imported': False}
    before_manifest = folder/'manifest.json'
    archive = folder/'manifest-expired.json'
    if not archive.exists():
        with open(archive, 'x') as f:
            os.chmod(f.fileno(), 0o600); f.write(before_manifest.read_text())
    for filename, value in (('bundle.json', fresh), ('manifest.json', manifest)):
        temporary = folder/(filename+'.new')
        with open(temporary, 'x') as f:
            os.chmod(f.fileno(), 0o600); json.dump(value, f)
        os.replace(temporary, folder/filename)
    manifest['bundle_sha256'] = hashlib.sha256(target.read_bytes()).hexdigest()
    print(json.dumps(manifest))


if __name__ == '__main__':
    main()
