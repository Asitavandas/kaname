"""Operator-only root CRLs. No key export, online root signer or CA rotation.

Existing authorities remain unchanged. The first root CRL needs an explicit
initialization flag; subsequent refreshes retain every revocation and advance
the durable CRL number. This module does not publish or install trust assets.
"""
import argparse
from contextlib import contextmanager
from datetime import timedelta
import getpass
import hmac
import json
import os
from pathlib import Path
import sqlite3

from cryptography import x509
from cryptography.exceptions import InvalidSignature, UnsupportedAlgorithm
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.x509.oid import CRLEntryExtensionOID

from .pki import PKIError, instant, password_bytes, public_der

PEM = serialization.Encoding.PEM
TABLE = 'pki_root_crls'


def authority(root_pem, issuer_pem, now):
    root, issuer = (x509.load_pem_x509_certificate(x) for x in (root_pem, issuer_pem))
    root.verify_directly_issued_by(root)
    issuer.verify_directly_issued_by(root)
    for cert, depth in ((root, 1), (issuer, 0)):
        bc = cert.extensions.get_extension_for_class(x509.BasicConstraints)
        ku = cert.extensions.get_extension_for_class(x509.KeyUsage)
        if not bc.critical or not bc.value.ca or bc.value.path_length != depth:
            raise PKIError('INVALID_AUTHORITY')
        if not ku.critical or not ku.value.key_cert_sign or not ku.value.crl_sign:
            raise PKIError('INVALID_AUTHORITY')
        if cert is root and not cert.not_valid_before_utc <= now < cert.not_valid_after_utc:
            raise PKIError('AUTHORITY_NOT_CURRENT')
        if not isinstance(cert.public_key(), rsa.RSAPublicKey) or cert.public_key().key_size != 3072:
            raise PKIError('INVALID_AUTHORITY')
        if not isinstance(cert.signature_hash_algorithm, hashes.SHA256):
            raise PKIError('INVALID_AUTHORITY')
    return root, issuer


def validate_crl(data, root, now, *, expired_ok=False):
    if type(data) is not bytes or not 1 <= len(data) <= 4 * 1024 * 1024:
        raise PKIError('INVALID_ROOT_CRL')
    crl = x509.load_pem_x509_crl(data)
    if crl.public_bytes(PEM).strip() != data.strip():
        raise PKIError('ONE_CANONICAL_ROOT_CRL_REQUIRED')
    if crl.issuer != root.subject or not crl.is_signature_valid(root.public_key()):
        raise PKIError('ROOT_CRL_SIGNATURE_INVALID')
    if not isinstance(crl.signature_hash_algorithm, hashes.SHA256):
        raise PKIError('ROOT_CRL_DIGEST_INVALID')
    for ext in crl.extensions:
        if ext.oid in {x509.ExtensionOID.DELTA_CRL_INDICATOR, x509.ExtensionOID.ISSUING_DISTRIBUTION_POINT,
                       x509.ExtensionOID.FRESHEST_CRL} or ext.critical:
            raise PKIError('UNSUPPORTED_ROOT_CRL_SCOPE')
    number = crl.extensions.get_extension_for_class(x509.CRLNumber).value.crl_number
    if not 1 <= number < 2 ** 63:
        raise PKIError('ROOT_CRL_NUMBER_INVALID')
    aki = crl.extensions.get_extension_for_class(x509.AuthorityKeyIdentifier).value
    expected = x509.SubjectKeyIdentifier.from_public_key(root.public_key()).digest
    if aki.key_identifier != expected or aki.authority_cert_issuer is not None or aki.authority_cert_serial_number is not None:
        raise PKIError('ROOT_CRL_KEY_IDENTIFIER_INVALID')
    if crl.next_update_utc is None or crl.next_update_utc <= crl.last_update_utc or crl.last_update_utc > now:
        raise PKIError('ROOT_CRL_TIME_INVALID')
    if crl.next_update_utc > root.not_valid_after_utc or (not expired_ok and now >= crl.next_update_utc):
        raise PKIError('ROOT_CRL_NOT_CURRENT')
    seen = set()
    for entry in crl:
        if entry.serial_number in seen or entry.revocation_date_utc > crl.last_update_utc:
            raise PKIError('ROOT_CRL_ENTRY_INVALID')
        seen.add(entry.serial_number)
        for ext in entry.extensions:
            if ext.critical or ext.oid == CRLEntryExtensionOID.CERTIFICATE_ISSUER:
                raise PKIError('UNSUPPORTED_ROOT_CRL_ENTRY')
    return crl, number


def stored(db, root, now, *, expired_ok=False):
    if not db.execute("SELECT 1 FROM sqlite_master WHERE type='table' AND name=?", (TABLE,)).fetchone():
        return None
    fingerprint = root.fingerprint(hashes.SHA256()).hex()
    row = db.execute('SELECT crl,number FROM pki_root_crls WHERE root_sha256=?', (fingerprint,)).fetchone()
    if row is None:
        return None
    crl, number = validate_crl(row[0], root, now, expired_ok=expired_ok)
    if type(row[1]) is not int or row[1] != number:
        raise PKIError('ROOT_CRL_LEDGER_MISMATCH')
    return crl, number


def enforce_if_present(db, root, issuer, now):
    """Legacy absence is explicit; a published stale/revoked state fails closed."""
    current = stored(db, root, now)
    if current and current[0].get_revoked_certificate_by_serial_number(issuer.serial_number):
        raise PKIError('ISSUER_REVOKED_BY_ROOT')


class RootCRLService:
    def __init__(self, state):
        self.path = Path(state).absolute() / 'kaname.sqlite3'
        for path in (self.path, *self.path.parents):
            if path.is_symlink():
                raise PKIError('UNSAFE_STATE_PATH')
        if not self.path.is_file() or self.path.stat().st_nlink != 1:
            raise PKIError('EXISTING_STATE_REQUIRED')
        if os.name == 'posix':
            info, parent = self.path.stat(), self.path.parent.stat()
            if info.st_uid != parent.st_uid or info.st_uid not in {0, os.geteuid()} and os.geteuid() != 0:
                raise PKIError('STATE_OWNER_MISMATCH')
            if info.st_mode & 0o077 or parent.st_mode & 0o077:
                raise PKIError('UNSAFE_STATE_PERMISSIONS')

    @contextmanager
    def connect(self, write=False):
        db = sqlite3.connect(self.path.as_uri() + ('?mode=rw' if write else '?mode=ro'), uri=True, timeout=3)
        try:
            db.execute('BEGIN IMMEDIATE' if write else 'BEGIN')
            yield db
            if write: db.commit()
        finally:
            db.close()

    @staticmethod
    def _authority(db, now):
        row = db.execute('SELECT root_cert,issuer_cert FROM pki_authority WHERE id=1').fetchone()
        if row is None: raise PKIError('AUTHORITY_MISSING')
        return authority(*row, now)

    def status(self, *, now=None):
        now = instant(now)
        with self.connect() as db:
            root, issuer = self._authority(db, now)
            result = {'root_sha256': root.fingerprint(hashes.SHA256()).hex(),
                      'root_crl_present': False, 'automatic_distribution_managed_by_this_tool': False}
            current = stored(db, root, now, expired_ok=True)
            if current:
                crl, number = current
                result.update(root_crl_present=True, crl_number=number,
                              current=now < crl.next_update_utc, next_update=crl.next_update_utc.isoformat(),
                              issuer_revoked=crl.get_revoked_certificate_by_serial_number(issuer.serial_number) is not None)
            return result

    def refresh(self, password, expected_root_sha256, *, initialize=False, days=30, now=None):
        password_bytes(password)
        if type(initialize) is not bool:
            raise PKIError('ROOT_CRL_INITIALIZATION_FLAG_INVALID')
        if type(days) is not int or not 1 <= days <= 365:
            raise PKIError('ROOT_CRL_DAYS_INVALID')
        now = instant(now)
        with self.connect(write=True) as db:
            root, issuer = self._authority(db, now)
            fingerprint = root.fingerprint(hashes.SHA256()).hex()
            if type(expected_root_sha256) is not str or not hmac.compare_digest(fingerprint, expected_root_sha256):
                raise PKIError('ROOT_IDENTITY_MISMATCH')
            previous = stored(db, root, now, expired_ok=True)
            if bool(previous) == bool(initialize):
                raise PKIError('FIRST_ROOT_CRL_REQUIRES_EXPLICIT_INITIALIZATION' if previous is None else 'ROOT_CRL_ALREADY_INITIALIZED')
            encrypted = db.execute('SELECT root_key FROM pki_authority WHERE id=1').fetchone()[0]
            key = serialization.load_pem_private_key(encrypted, password)
            if not isinstance(key, rsa.RSAPrivateKey) or public_der(key.public_key()) != public_der(root.public_key()):
                raise PKIError('ROOT_KEY_MISMATCH')
            end = min(now + timedelta(days=days), root.not_valid_after_utc)
            if previous and previous[0].next_update_utc > end:
                raise PKIError('ROOT_CRL_VALIDITY_WOULD_REGRESS')
            number = previous[1] + 1 if previous else 1
            if number >= 2 ** 63: raise PKIError('ROOT_CRL_NUMBER_EXHAUSTED')
            builder = (x509.CertificateRevocationListBuilder().issuer_name(root.subject)
                       .last_update(now).next_update(end)
                       .add_extension(x509.CRLNumber(number), critical=False)
                       .add_extension(x509.AuthorityKeyIdentifier.from_issuer_public_key(root.public_key()), critical=False))
            if previous:
                for entry in previous[0]: builder = builder.add_revoked_certificate(entry)
            pem = builder.sign(key, hashes.SHA256()).public_bytes(PEM)
            validate_crl(pem, root, now)
            db.execute('CREATE TABLE IF NOT EXISTS pki_root_crls (root_sha256 TEXT PRIMARY KEY, crl BLOB NOT NULL, number INTEGER NOT NULL CHECK(number>0))')
            db.execute('INSERT INTO pki_root_crls VALUES (?,?,?) ON CONFLICT(root_sha256) DO UPDATE SET crl=excluded.crl,number=excluded.number', (fingerprint, pem, number))
            revision = db.execute('SELECT revision FROM state WHERE id=1').fetchone()[0]
            db.execute('INSERT INTO audit(event,revision) VALUES (?,?)', ('pki_root_crl_refreshed:' + fingerprint + ':' + str(number), revision))
            return pem

    def export(self, *, now=None):
        now = instant(now)
        with self.connect() as db:
            root, issuer = self._authority(db, now)
            current = stored(db, root, now)
            if current is None: raise PKIError('ROOT_CRL_MISSING')
            return current[0].public_bytes(PEM)


def write_public_new(path, data):
    path = Path(path).absolute()
    for item in (path, *path.parents):
        if item.is_symlink(): raise PKIError('UNSAFE_EXPORT_PATH')
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, 'O_NOFOLLOW', 0), 0o600)
    with os.fdopen(fd, 'wb') as f:
        f.write(data); f.flush(); os.fsync(f.fileno())


def main():
    parser = argparse.ArgumentParser(description='Operator-only signed root CRL; never exports private keys')
    parser.add_argument('--state-dir', required=True)
    commands = parser.add_subparsers(dest='command', required=True)
    commands.add_parser('status')
    export = commands.add_parser('export'); export.add_argument('--output', required=True)
    refresh = commands.add_parser('refresh')
    refresh.add_argument('--expected-root-sha256', required=True)
    refresh.add_argument('--initialize-first-crl', action='store_true')
    refresh.add_argument('--days', type=int, default=30)
    args = parser.parse_args()
    try:
        service = RootCRLService(args.state_dir)
        if args.command == 'refresh':
            if not __import__('sys').stdin.isatty(): raise PKIError('INTERACTIVE_PASSPHRASE_REQUIRED')
            password = getpass.getpass('CA passphrase (not the Linux login password): ').encode('utf-8')
            try:
                service.refresh(password, args.expected_root_sha256, initialize=args.initialize_first_crl, days=args.days)
            finally: password = None
        elif args.command == 'export':
            write_public_new(args.output, service.export())
        print(json.dumps(service.status(), sort_keys=True))
    except (ValueError, TypeError, sqlite3.Error, OSError, x509.ExtensionNotFound,
            InvalidSignature, UnsupportedAlgorithm):
        # No tracebacks, database bytes or entered passphrases on the operator channel.
        parser.exit(1, 'Root CRL operation failed; state was not reset. Check CA identity, passphrase, dates and export path.\n')


if __name__ == '__main__': main()
