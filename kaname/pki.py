"""Local lab PKI: encrypted CA hierarchy, server CSR signing and signed CRL.

No client enrollment or network authorization is exposed. Operator CLI actions
are distinct from future AD-authenticated enrollment. This is not an appliance
key vault, HTTPS server or EAP implementation.
"""
import argparse
import getpass
import hmac
import json
import os
import re
import sqlite3
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path

from cryptography import x509
from cryptography.exceptions import InvalidSignature, UnsupportedAlgorithm
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec, rsa
from cryptography.x509.oid import ExtendedKeyUsageOID, NameOID

from .models import ValidationError, dns_name, integer
from .store import Store

PEM = serialization.Encoding.PEM
REASONS = {'key_compromise': x509.ReasonFlags.key_compromise,
           'superseded': x509.ReasonFlags.superseded,
           'cessation_of_operation': x509.ReasonFlags.cessation_of_operation}


class PKIError(ValueError):
    pass


def instant(value=None):
    if value is None:
        value = datetime.now(timezone.utc)
    if not isinstance(value, datetime) or value.tzinfo is None or value.utcoffset() != timedelta(0):
        raise PKIError('An aware UTC timestamp is required')
    return value.replace(microsecond=0)


def password_bytes(value):
    if type(value) is not bytes or not 16 <= len(value) <= 128:
        raise PKIError('CA passphrase must contain 16 to 128 UTF-8 bytes')
    return value


def private_pem(key, password):
    return key.private_bytes(PEM, serialization.PrivateFormat.PKCS8,
                             serialization.BestAvailableEncryption(password_bytes(password)))


def public_der(key):
    return key.public_bytes(serialization.Encoding.DER, serialization.PublicFormat.SubjectPublicKeyInfo)


def ca_usage():
    return x509.KeyUsage(True, False, False, False, False, True, True, False, False)


def make_ca(subject, key, issuer, issuer_key, now, days, path_length):
    parent_end = now + timedelta(days=days) if issuer is None else issuer.not_valid_after_utc
    return (x509.CertificateBuilder().subject_name(subject)
            .issuer_name(subject if issuer is None else issuer.subject)
            .public_key(key.public_key()).serial_number(x509.random_serial_number())
            .not_valid_before(now - timedelta(minutes=5))
            .not_valid_after(min(now + timedelta(days=days), parent_end))
            .add_extension(x509.BasicConstraints(ca=True, path_length=path_length), critical=True)
            .add_extension(ca_usage(), critical=True)
            .add_extension(x509.SubjectKeyIdentifier.from_public_key(key.public_key()), critical=False)
            .add_extension(x509.AuthorityKeyIdentifier.from_issuer_public_key(issuer_key.public_key()), critical=False)
            .sign(issuer_key, hashes.SHA256()))


def describe(cert):
    return {'serial': format(cert.serial_number, 'x'),
            'fingerprint_sha256': cert.fingerprint(hashes.SHA256()).hex(),
            'not_before': cert.not_valid_before_utc.isoformat(),
            'not_after': cert.not_valid_after_utc.isoformat()}


def validate_csr(data, fqdn):
    if type(data) is not bytes or not 1 <= len(data) <= 65536:
        raise PKIError('CSR size or type is invalid')
    if not re.fullmatch(rb'-----BEGIN CERTIFICATE REQUEST-----\s+[A-Za-z0-9+/=\r\n]+-----END CERTIFICATE REQUEST-----\s*', data):
        raise PKIError('One PEM CSR is required')
    try:
        csr = x509.load_pem_x509_csr(data)
        if not csr.is_signature_valid or not isinstance(csr.signature_hash_algorithm, (hashes.SHA256, hashes.SHA384, hashes.SHA512)):
            raise PKIError('CSR signature or digest is invalid')
        key = csr.public_key()
        if isinstance(key, rsa.RSAPublicKey):
            if not 2048 <= key.key_size <= 4096 or key.public_numbers().e != 65537:
                raise PKIError('RSA CSR key parameters are not allowed')
        elif isinstance(key, ec.EllipticCurvePublicKey):
            if not isinstance(key.curve, (ec.SECP256R1, ec.SECP384R1)):
                raise PKIError('EC CSR curve is not allowed')
        else:
            raise PKIError('CSR public key algorithm is not allowed')
        extensions = list(csr.extensions)
        if len(extensions) != 1 or not isinstance(extensions[0].value, x509.SubjectAlternativeName):
            raise PKIError('Only an exact DNS SAN may be requested')
        names = list(extensions[0].value)
        if len(names) != 1 or not isinstance(names[0], x509.DNSName) or names[0].value != fqdn:
            raise PKIError('CSR SAN does not match the configured appliance DNS name')
        return csr
    except (ValueError, TypeError, InvalidSignature, UnsupportedAlgorithm, x509.DuplicateExtension, x509.UnsupportedGeneralNameType) as exc:
        raise PKIError('CSR validation failed') from exc


class PKIService:
    def __init__(self, root):
        self.store = Store(root)
        with self.store.connect() as db:
            db.executescript('''
            CREATE TABLE IF NOT EXISTS pki_authority (
                id INTEGER PRIMARY KEY CHECK(id=1), instance_id TEXT NOT NULL,
                root_cert BLOB NOT NULL, root_key BLOB NOT NULL,
                issuer_cert BLOB NOT NULL, issuer_key BLOB NOT NULL,
                public_data TEXT NOT NULL, crl BLOB NOT NULL, crl_number INTEGER NOT NULL
            );
            CREATE TABLE IF NOT EXISTS pki_certificates (
                serial TEXT PRIMARY KEY, certificate BLOB NOT NULL,
                revoked_at TEXT, reason TEXT,
                CHECK((revoked_at IS NULL AND reason IS NULL) OR (revoked_at IS NOT NULL AND reason IS NOT NULL))
            );
            ''')

    def _audit(self, db, event, actor=None):
        if actor is not None:
            if type(actor) is not str or not re.fullmatch(r'[A-Za-z0-9_-]{1,64}', actor):
                raise PKIError('Invalid operator identity')
            event += ':actor:' + actor
        revision = db.execute('SELECT revision FROM state WHERE id=1').fetchone()[0]
        db.execute('INSERT INTO audit(event,revision) VALUES (?,?)', (event, revision))

    def initialize(self, password, *, now=None, actor=None):
        password_bytes(password)
        now = instant(now)
        # Check before expensive key generation; transaction also checks races.
        with self.store.connect() as db:
            if db.execute('SELECT 1 FROM pki_authority').fetchone():
                raise PKIError('CA already exists; existing keys were not replaced')
        instance = str(uuid.uuid4())
        root_key = rsa.generate_private_key(65537, 3072)
        issuer_key = rsa.generate_private_key(65537, 3072)
        suffix = instance[:8]
        root = make_ca(x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, 'KANAME Root ' + suffix)]),
                       root_key, None, root_key, now, 3650, 1)
        issuer = make_ca(x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, 'KANAME Issuer ' + suffix)]),
                         issuer_key, root, root_key, now, 1095, 0)
        data = {'initialized': True, 'mode': 'local-lab', 'instance_id': instance,
                'root': describe(root), 'issuer': describe(issuer),
                'client_enrollment_enabled': False, 'radius_connected': False}
        crl = self._build_crl(issuer, issuer_key, [], 1, now)
        with self.store.connect() as db:
            db.execute('BEGIN IMMEDIATE')
            if db.execute('SELECT 1 FROM pki_authority').fetchone():
                raise PKIError('CA already exists; existing keys were not replaced')
            db.execute('INSERT INTO pki_authority VALUES (1,?,?,?,?,?,?,?,?)',
                       (instance, root.public_bytes(PEM), private_pem(root_key, password),
                        issuer.public_bytes(PEM), private_pem(issuer_key, password),
                        json.dumps(data), crl.public_bytes(PEM), 1))
            self._audit(db, 'pki_ca_initialized', actor)
        return data

    def _authority(self, db, password, now):
        password_bytes(password)
        row = db.execute('SELECT root_cert,issuer_cert,issuer_key,crl_number,crl FROM pki_authority WHERE id=1').fetchone()
        if row is None:
            raise PKIError('CA has not been initialized')
        try:
            root, issuer = (x509.load_pem_x509_certificate(row[i]) for i in (0, 1))
            key = serialization.load_pem_private_key(row[2], password)
            root.verify_directly_issued_by(root)
            issuer.verify_directly_issued_by(root)
            if public_der(key.public_key()) != public_der(issuer.public_key()):
                raise PKIError('CA key and certificate do not match')
            for cert, length in ((root, 1), (issuer, 0)):
                constraints = cert.extensions.get_extension_for_class(x509.BasicConstraints)
                usage = cert.extensions.get_extension_for_class(x509.KeyUsage)
                if not constraints.critical or not constraints.value.ca or constraints.value.path_length != length:
                    raise PKIError('Invalid CA constraints')
                if not usage.critical or not usage.value.key_cert_sign or not usage.value.crl_sign:
                    raise PKIError('Invalid CA key usage')
                if not cert.not_valid_before_utc <= now < cert.not_valid_after_utc:
                    raise PKIError('CA certificate is not currently valid')
                if not isinstance(cert.public_key(), rsa.RSAPublicKey) or cert.public_key().key_size != 3072:
                    raise PKIError('Invalid CA public key')
                if not isinstance(cert.signature_hash_algorithm, hashes.SHA256):
                    raise PKIError('Invalid CA signature algorithm')
            crl = x509.load_pem_x509_crl(row[4])
            if not crl.is_signature_valid(issuer.public_key()) or crl.issuer != issuer.subject:
                raise PKIError('Stored CRL signature is invalid')
            if crl.extensions.get_extension_for_class(x509.CRLNumber).value.crl_number != row[3]:
                raise PKIError('Stored CRL number is invalid')
            if crl.last_update_utc > now:
                raise PKIError('Clock moved behind the latest CRL')
            return root, issuer, key, row[3]
        except (ValueError, TypeError, InvalidSignature, UnsupportedAlgorithm, x509.ExtensionNotFound, x509.DuplicateExtension) as exc:
            raise PKIError('CA unlock or integrity validation failed') from exc

    def issue_radius(self, csr_pem, password, *, days=90, now=None):
        integer(days, 1, 365)
        now = instant(now)
        with self.store.connect() as db:
            db.execute('BEGIN IMMEDIATE')
            config = db.execute('SELECT config FROM state WHERE id=1').fetchone()[0]
            if config is None:
                raise PKIError('Save an appliance configuration before signing a server CSR')
            fqdn = dns_name(json.loads(config)['appliance_fqdn'])
            csr = validate_csr(csr_pem, fqdn)
            _, issuer, key, _ = self._authority(db, password, now)
            end = min(now + timedelta(days=days), issuer.not_valid_after_utc)
            if end - now < timedelta(days=1):
                raise PKIError('Issuer needs renewal before another server certificate can be issued')
            if db.execute('SELECT count(*) FROM pki_certificates').fetchone()[0] >= 10000:
                raise PKIError('Lab certificate capacity reached')
            public = csr.public_key()
            cert = (x509.CertificateBuilder()
                    .subject_name(x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, fqdn if len(fqdn) <= 64 else 'KANAME RADIUS')]))
                    .issuer_name(issuer.subject).public_key(public).serial_number(x509.random_serial_number())
                    .not_valid_before(max(now - timedelta(minutes=5), issuer.not_valid_before_utc))
                    .not_valid_after(end)
                    .add_extension(x509.BasicConstraints(ca=False, path_length=None), critical=True)
                    .add_extension(x509.KeyUsage(True, False, isinstance(public, rsa.RSAPublicKey), False, False, False, False, False, False), critical=True)
                    .add_extension(x509.ExtendedKeyUsage([ExtendedKeyUsageOID.SERVER_AUTH]), critical=False)
                    .add_extension(x509.SubjectAlternativeName([x509.DNSName(fqdn)]), critical=False)
                    .add_extension(x509.SubjectKeyIdentifier.from_public_key(public), critical=False)
                    .add_extension(x509.AuthorityKeyIdentifier.from_issuer_public_key(key.public_key()), critical=False)
                    .sign(key, hashes.SHA256()))
            pem = cert.public_bytes(PEM)
            serial = format(cert.serial_number, 'x')
            db.execute('INSERT INTO pki_certificates(serial,certificate) VALUES (?,?)', (serial, pem))
            self._audit(db, 'pki_radius_issued:' + serial)
        return pem

    @staticmethod
    def _build_crl(issuer, key, rows, number, now):
        end = min(now + timedelta(hours=24), issuer.not_valid_after_utc)
        if end <= now:
            raise PKIError('Issuer is expired')
        builder = (x509.CertificateRevocationListBuilder().issuer_name(issuer.subject)
                   .last_update(now).next_update(end)
                   .add_extension(x509.CRLNumber(number), critical=False)
                   .add_extension(x509.AuthorityKeyIdentifier.from_issuer_public_key(key.public_key()), critical=False))
        for serial, at, reason in rows:
            if reason not in REASONS:
                raise PKIError('Invalid stored revocation reason')
            at = instant(datetime.fromisoformat(at))
            if at > now:
                raise PKIError('Stored revocation time is in the future')
            revoked = (x509.RevokedCertificateBuilder().serial_number(int(serial, 16))
                       .revocation_date(at)
                       .add_extension(x509.CRLReason(REASONS[reason]), critical=False).build())
            builder = builder.add_revoked_certificate(revoked)
        return builder.sign(key, hashes.SHA256())

    def revoke(self, serial, password, *, reason='key_compromise', now=None, actor=None):
        if type(serial) is str:
            serial = serial.lower()
        if type(serial) is not str or not re.fullmatch(r'[1-9a-f][0-9a-f]{0,39}', serial) or type(reason) is not str or reason not in REASONS:
            raise PKIError('Invalid certificate serial or revocation reason')
        now = instant(now)
        with self.store.connect() as db:
            db.execute('BEGIN IMMEDIATE')
            _, issuer, key, number = self._authority(db, password, now)
            row = db.execute('SELECT certificate,revoked_at FROM pki_certificates WHERE serial=?', (serial,)).fetchone()
            if row is None:
                raise PKIError('Unknown issued certificate')
            try:
                cert = x509.load_pem_x509_certificate(row[0])
                cert.verify_directly_issued_by(issuer)
                if cert.serial_number != int(serial, 16):
                    raise PKIError('Certificate registry integrity failed')
            except (ValueError, InvalidSignature) as exc:
                raise PKIError('Certificate registry integrity failed') from exc
            if row[1] is not None:
                return {'serial': serial, 'already_revoked': True, 'crl_number': number}
            db.execute('UPDATE pki_certificates SET revoked_at=?,reason=? WHERE serial=?', (now.isoformat(), reason, serial))
            rows = db.execute('SELECT serial,revoked_at,reason FROM pki_certificates WHERE revoked_at IS NOT NULL ORDER BY serial').fetchall()
            crl = self._build_crl(issuer, key, rows, number + 1, now)
            db.execute('UPDATE pki_authority SET crl=?,crl_number=? WHERE id=1', (crl.public_bytes(PEM), number + 1))
            self._audit(db, 'pki_certificate_revoked:' + serial, actor)
        return {'serial': serial, 'already_revoked': False, 'crl_number': number + 1}

    def refresh_crl(self, password, *, now=None, actor=None):
        now = instant(now)
        with self.store.connect() as db:
            db.execute('BEGIN IMMEDIATE')
            _, issuer, key, number = self._authority(db, password, now)
            rows = db.execute('SELECT serial,revoked_at,reason FROM pki_certificates WHERE revoked_at IS NOT NULL ORDER BY serial').fetchall()
            crl = self._build_crl(issuer, key, rows, number + 1, now)
            db.execute('UPDATE pki_authority SET crl=?,crl_number=? WHERE id=1', (crl.public_bytes(PEM), number + 1))
            self._audit(db, 'pki_crl_refreshed', actor)
        return crl.public_bytes(PEM)

    def public_bundle(self):
        with self.store.connect() as db:
            row = db.execute('SELECT root_cert,issuer_cert,crl FROM pki_authority WHERE id=1').fetchone()
        if row is None:
            raise PKIError('CA has not been initialized')
        return {'root-ca.pem': row[0], 'issuer-ca.pem': row[1], 'issuer-crl.pem': row[2]}


def write_new(path, data):
    path = Path(path).absolute()
    # Never silently overwrite a certificate, private key or old export.
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, 'wb') as handle:
        handle.write(data)


def main():
    parser = argparse.ArgumentParser(description='KANAME local lab CA; no client enrollment')
    parser.add_argument('--state-dir', default='kaname-state')
    commands = parser.add_subparsers(dest='command', required=True)
    commands.add_parser('init')
    commands.add_parser('status')
    export = commands.add_parser('export-public'); export.add_argument('directory')
    issue = commands.add_parser('issue-radius'); issue.add_argument('csr'); issue.add_argument('output'); issue.add_argument('--days', type=int, default=90)
    revoke = commands.add_parser('revoke'); revoke.add_argument('serial'); revoke.add_argument('--reason', choices=REASONS, default='key_compromise')
    commands.add_parser('refresh-crl')
    args = parser.parse_args()
    try:
        service = PKIService(args.state_dir)
        if args.command == 'status':
            print(json.dumps(service.store.public_pki_status(), indent=2)); return
        if args.command == 'export-public':
            bundle = service.public_bundle()
            directory = Path(args.directory).absolute()
            directory.mkdir(mode=0o700)  # Existing directory is never overwritten.
            for name, data in bundle.items():
                write_new(directory / name, data)
            print('Public CA certificates and CRL exported; no private keys.'); return
        password = password_bytes(getpass.getpass('CA anahtar parolası (en az 16 UTF-8 byte): ').encode('utf-8'))
        if args.command == 'init':
            confirm = getpass.getpass('CA anahtar parolasını tekrar girin: ').encode('utf-8')
            if not hmac.compare_digest(password, confirm):
                raise PKIError('Passphrases do not match')
            print(json.dumps(service.initialize(password), indent=2))
        elif args.command == 'issue-radius':
            csr = Path(args.csr)
            if csr.is_symlink() or not csr.is_file() or csr.stat().st_size > 65536:
                raise PKIError('A regular bounded CSR file is required')
            # Reserve output before issuance: existing files cannot create an orphan issuance.
            output = Path(args.output).absolute()
            fd = os.open(output, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
            try:
                with os.fdopen(fd, 'wb') as handle:
                    pem = service.issue_radius(csr.read_bytes(), password, days=args.days)
                    handle.write(pem)
            except Exception:
                output.unlink(missing_ok=True)
                raise
            print('RADIUS server certificate issued; runtime is not connected.')
        elif args.command == 'revoke':
            print(json.dumps(service.revoke(args.serial, password, reason=args.reason), indent=2))
        elif args.command == 'refresh-crl':
            service.refresh_crl(password); print('Signed CRL refreshed; distribution is not connected.')
    except (PKIError, ValidationError, OSError, sqlite3.Error, EOFError, KeyboardInterrupt):
        parser.exit(1, 'PKI operation failed; existing CA and configuration were preserved. Check input, passphrase and storage.\n')


if __name__ == '__main__':
    main()
