"""Publish a verified current CRL into the running RADIUS CA directory.

Runs as the existing service user. Never signs certificates, changes persistent
state, edits trust anchors, relaxes validation, or restarts the RADIUS process.
The generated EAP configuration refreshes its X509 store every 300 seconds.
"""
import argparse
from datetime import datetime, timezone
import fcntl
import json
import os
from pathlib import Path
import sqlite3
import stat
import sys
import tempfile

from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.x509.oid import ExtensionOID

STATE = Path('/var/lib/kaname-lab')
CA = Path('/run/authwire-radius/ca')


def protected(path, directory=False):
    if path.is_symlink() or not (path.is_dir() if directory else path.is_file()):
        raise ValueError('Unsafe CRL path')
    info = path.stat()
    if info.st_uid != os.geteuid() or info.st_mode & 0o022:
        raise ValueError('Protected service-owned CRL path required')


def validate_authority(root, issuer, now):
    root.verify_directly_issued_by(root)
    issuer.verify_directly_issued_by(root)
    for cert, length in ((root, 1), (issuer, 0)):
        constraints = cert.extensions.get_extension_for_class(x509.BasicConstraints)
        usage = cert.extensions.get_extension_for_class(x509.KeyUsage)
        if (not cert.not_valid_before_utc <= now < cert.not_valid_after_utc
                or not constraints.critical or not constraints.value.ca
                or constraints.value.path_length != length
                or not usage.critical or not usage.value.key_cert_sign or not usage.value.crl_sign
                or not isinstance(cert.public_key(), rsa.RSAPublicKey)
                or cert.public_key().key_size != 3072
                or not isinstance(cert.signature_hash_algorithm, hashes.SHA256)):
            raise ValueError('Invalid pinned authority')


def validate_crl(raw, issuer, now, fresh):
    crl = x509.load_pem_x509_crl(raw)
    number = crl.extensions.get_extension_for_oid(ExtensionOID.CRL_NUMBER).value.crl_number
    if (not crl.is_signature_valid(issuer.public_key()) or crl.issuer != issuer.subject
            or crl.last_update_utc > now or crl.next_update_utc <= crl.last_update_utc
            or number < 1 or not isinstance(crl.signature_hash_algorithm, hashes.SHA256)
            or (fresh and now >= crl.next_update_utc)):
        raise ValueError('Invalid CRL signature, number or validity')
    return crl, number


def _sync(state, ca, now):
    target = ca/'issuer-crl.pem'
    for name in ('root-ca.pem', 'issuer-ca.pem', 'issuer-crl.pem'):
        protected(ca/name)
    database = state/'kaname.sqlite3'
    protected(state, directory=True)
    protected(database)
    with sqlite3.connect(database.as_uri()+'?mode=ro', uri=True, timeout=3) as db:
        db.execute('BEGIN')
        row = db.execute('SELECT root_cert,issuer_cert,crl,crl_number FROM pki_authority WHERE id=1').fetchone()
    if row is None:
        raise ValueError('Authority missing')
    root, issuer = (x509.load_pem_x509_certificate(raw) for raw in row[:2])
    validate_authority(root, issuer, now)
    for name, expected in (('root-ca.pem', root), ('issuer-ca.pem', issuer)):
        actual = x509.load_pem_x509_certificate((ca/name).read_bytes())
        if actual.fingerprint(hashes.SHA256()) != expected.fingerprint(hashes.SHA256()):
            raise ValueError('Runtime trust anchors differ; manual rotation required')
    current, number = validate_crl(row[2], issuer, now, True)
    previous, old_number = validate_crl(target.read_bytes(), issuer, now, False)
    if type(row[3]) is not int or number != row[3]:
        raise ValueError('Database CRL number mismatch')
    if (number < old_number or current.last_update_utc < previous.last_update_utc
            or not {r.serial_number for r in previous}.issubset({r.serial_number for r in current})):
        raise ValueError('CRL rollback or removed revocation refused')
    fingerprint = current.fingerprint(hashes.SHA256()).hex()
    if current.fingerprint(hashes.SHA256()) == previous.fingerprint(hashes.SHA256()):
        return {'synced': True, 'changed': False, 'number': number,
                'next_update': current.next_update_utc.isoformat(), 'crl_sha256': fingerprint,
                'radius_restarted': False, 'persistent_state_changed': False}
    if number == old_number:
        raise ValueError('Different CRLs share a number')
    descriptor, name = tempfile.mkstemp(prefix='.issuer-crl-', dir=ca)
    temporary = Path(name)
    try:
        with os.fdopen(descriptor, 'wb') as handle:
            handle.write(current.public_bytes(serialization.Encoding.PEM))
            handle.flush()
            os.fsync(handle.fileno())
            os.fchmod(handle.fileno(), 0o600)
        # Existing openssl-rehash link keeps pointing at this canonical path.
        os.replace(temporary, target)
        directory = os.open(ca, os.O_RDONLY | os.O_DIRECTORY)
        try:
            os.fsync(directory)
        finally:
            os.close(directory)
    finally:
        temporary.unlink(missing_ok=True)
    return {'synced': True, 'changed': True, 'number': number,
            'next_update': current.next_update_utc.isoformat(), 'crl_sha256': fingerprint,
            'radius_restarted': False, 'persistent_state_changed': False}


def sync(state=STATE, ca=CA, *, now=None):
    state, ca = Path(state).absolute(), Path(ca).absolute()
    # The timer condition skips a stopped service. Do not recreate its runtime.
    protected(ca.parent, directory=True)
    protected(ca, directory=True)
    now = now or datetime.now(timezone.utc)
    if now.tzinfo is None:
        raise ValueError('UTC-aware clock required')
    descriptor = os.open(ca/'.crl-sync.lock', os.O_RDWR | os.O_CREAT | os.O_NOFOLLOW, 0o600)
    with os.fdopen(descriptor, 'r+') as lock:
        info = os.fstat(lock.fileno())
        if (not stat.S_ISREG(info.st_mode) or info.st_uid != os.geteuid()
                or info.st_nlink != 1 or info.st_mode & 0o077):
            raise ValueError('Private service CRL lock required')
        fcntl.flock(lock.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
        return _sync(state, ca, now)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--state-dir', default=str(STATE))
    parser.add_argument('--ca-dir', default=str(CA))
    args = parser.parse_args()
    try:
        print(json.dumps(sync(args.state_dir, args.ca_dir)))
        return 0
    except Exception as error:
        print(json.dumps({'synced': False, 'error': 'CRL_SYNC_REFUSED',
                          'category': type(error).__name__}))
        return 1


if __name__ == '__main__':
    sys.exit(main())
