"""Privileged lab user enrollment: signed CSR + fresh Kerberos self proof.

No caller-supplied AD GUID/SID, outer identity, catalog binding or machine
certificate issuance. The endpoint private key is never generated here.
"""
import hashlib
import json
import re
import time
from datetime import timedelta

from cryptography import x509
from cryptography.exceptions import InvalidSignature, UnsupportedAlgorithm
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec, rsa
from cryptography.x509.oid import ExtendedKeyUsageOID, NameOID

from .directory import DirectoryError
from .directory_linux import authenticate_linux_user
from .models import integer
from .pki import PKIError, PKIService, PEM, instant, public_der
from .radius import CurrentDirectoryAccount, DirectoryUnavailable
from .radius_directory import LiveDirectory


class EnrollmentError(ValueError):
    def __init__(self, code):
        self.code = code
        super().__init__(code)


def client_csr(data):
    if type(data) is not bytes or not 1 <= len(data) <= 65536 or not re.fullmatch(
        rb'-----BEGIN CERTIFICATE REQUEST-----\s+[A-Za-z0-9+/=\r\n]+-----END CERTIFICATE REQUEST-----\s*', data):
        raise EnrollmentError('CSR_INVALID')
    try:
        csr = x509.load_pem_x509_csr(data)
        if not csr.is_signature_valid or not isinstance(csr.signature_hash_algorithm, (hashes.SHA256, hashes.SHA384, hashes.SHA512)):
            raise ValueError()
        key = csr.public_key()
        if isinstance(key, rsa.RSAPublicKey):
            if not 2048 <= key.key_size <= 4096 or key.public_numbers().e != 65537:
                raise ValueError()
        elif isinstance(key, ec.EllipticCurvePublicKey):
            if not isinstance(key.curve, (ec.SECP256R1, ec.SECP384R1)):
                raise ValueError()
        else:
            raise ValueError()
        # SAN/UPN, CA, EKU and key usage cannot be supplied by the requester.
        if list(csr.extensions) or len(csr.subject) > 16:
            raise ValueError()
        return csr
    except (ValueError, TypeError, InvalidSignature, UnsupportedAlgorithm,
            x509.DuplicateExtension, x509.UnsupportedGeneralNameType):
        raise EnrollmentError('CSR_INVALID') from None


class EnrollmentService:
    def __init__(self, operations, *, authenticator=authenticate_linux_user, directory=None):
        self.operations, self.authenticator = operations, authenticator
        self.pki = PKIService(operations.store.root)
        self.store = self.pki.store
        self.directory = directory or LiveDirectory(operations)
        with self.store.connect() as db:
            db.executescript('''
                CREATE TABLE IF NOT EXISTS radius_certificate_bindings (
                    issuer_sha256 TEXT NOT NULL, serial TEXT PRIMARY KEY REFERENCES pki_certificates(serial),
                    domain TEXT NOT NULL, object_guid TEXT NOT NULL, sid TEXT NOT NULL,
                    kind TEXT NOT NULL CHECK(kind IN ('user','computer')),
                    active INTEGER NOT NULL CHECK(active IN (0,1))
                );
                CREATE TABLE IF NOT EXISTS pki_client_keys (
                    serial TEXT PRIMARY KEY REFERENCES pki_certificates(serial),
                    csr_sha256 TEXT NOT NULL UNIQUE, public_sha256 TEXT NOT NULL UNIQUE
                );
                CREATE TABLE IF NOT EXISTS pki_enrollment_rate (
                    id INTEGER PRIMARY KEY CHECK(id=1), next_attempt REAL NOT NULL
                );
            ''')

    def issue_user(self, csr_pem, username, credential, ca_password, *, expected_revision,
                   days=30, actor='local-operator', now=None):
        integer(expected_revision, 0, 2**53 - 2)
        integer(days, 1, 90)
        if type(actor) is not str or not re.fullmatch(r'[A-Za-z0-9_-]{1,64}', actor):
            raise EnrollmentError('ENROLLMENT_INPUT_INVALID')
        csr = client_csr(csr_pem)
        csr_hash = hashlib.sha256(csr.public_bytes(serialization.Encoding.DER)).hexdigest()
        key_hash = hashlib.sha256(public_der(csr.public_key())).hexdigest()
        current = self.store.snapshot()
        if current['revision'] != expected_revision or not current['config']:
            raise EnrollmentError('REVISION_CONFLICT')
        config = current['config']
        settings = self.operations.directory()
        # The connector supplies DC settings only. Its saved password is not
        # a proof of the requesting endpoint user's identity.
        credentials = {'dc_fqdn': settings['dc_fqdn'], 'username': username,
                       'password': credential, 'search_base': ''}
        if type(username) is not str or not re.fullmatch(r'[A-Za-z0-9_][A-Za-z0-9_.-]{0,19}@' + re.escape(config['ad_domain']), username, re.I):
            raise EnrollmentError('ENROLLMENT_LOGIN_FORMAT')
        supplied_time = now
        now = instant(now)
        with self.store.connect() as db:
            db.execute('BEGIN IMMEDIATE')
            self.pki._authority(db, ca_password, now)  # Unlock before any KDC attempt.
            if db.execute('SELECT 1 FROM pki_client_keys WHERE csr_sha256=? OR public_sha256=?', (csr_hash, key_hash)).fetchone():
                raise EnrollmentError('CSR_ALREADY_USED')
            rate = db.execute('SELECT next_attempt FROM pki_enrollment_rate WHERE id=1').fetchone()
            timestamp = time.time()
            if rate and timestamp < rate[0]:
                raise EnrollmentError('ENROLLMENT_RETRY_LATER')
            # Global, persistent lab bound. No automatic password retries.
            db.execute('INSERT OR REPLACE INTO pki_enrollment_rate VALUES (1,?)', (timestamp + 30,))
        try:
            account = self.authenticator(credentials, config)
            if type(account) is not CurrentDirectoryAccount or account.domain != config['ad_domain'] or account.kind != 'user' or not account.enabled:
                raise EnrollmentError('ENROLLMENT_IDENTITY_REJECTED')
            live = self.directory.lookup(account.domain, account.object_guid)
            if type(live) is not CurrentDirectoryAccount or not live.enabled or (
                live.domain, live.object_guid, live.sid, live.kind) != (
                account.domain, account.object_guid, account.sid, account.kind):
                raise EnrollmentError('ENROLLMENT_IDENTITY_REJECTED')
            if self.operations.directory() != settings:
                raise EnrollmentError('REVISION_CONFLICT')
            if supplied_time is None:
                now = instant()
            with self.store.connect() as db:
                db.execute('BEGIN IMMEDIATE')
                revision, stored = db.execute('SELECT revision,config FROM state WHERE id=1').fetchone()
                if revision != expected_revision or json.loads(stored) != config:
                    raise EnrollmentError('REVISION_CONFLICT')
                if db.execute('SELECT count(*) FROM pki_certificates').fetchone()[0] >= 10000:
                    raise EnrollmentError('CERTIFICATE_LIMIT')
                if db.execute('SELECT 1 FROM pki_client_keys WHERE csr_sha256=? OR public_sha256=?', (csr_hash, key_hash)).fetchone():
                    raise EnrollmentError('CSR_ALREADY_USED')
                _, issuer, key, _ = self.pki._authority(db, ca_password, now)
                end = min(now + timedelta(days=days), issuer.not_valid_after_utc)
                if end - now < timedelta(days=1):
                    raise PKIError('Issuer renewal required')
                cert = (x509.CertificateBuilder()
                    .subject_name(x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, 'KANAME user ' + account.object_guid)]))
                    .issuer_name(issuer.subject).public_key(csr.public_key()).serial_number(x509.random_serial_number())
                    .not_valid_before(max(now - timedelta(minutes=5), issuer.not_valid_before_utc)).not_valid_after(end)
                    .add_extension(x509.BasicConstraints(ca=False, path_length=None), critical=True)
                    .add_extension(x509.KeyUsage(True, False, False, False, False, False, False, False, False), critical=True)
                    .add_extension(x509.ExtendedKeyUsage([ExtendedKeyUsageOID.CLIENT_AUTH]), critical=False)
                    .add_extension(x509.SubjectKeyIdentifier.from_public_key(csr.public_key()), critical=False)
                    .add_extension(x509.AuthorityKeyIdentifier.from_issuer_public_key(key.public_key()), critical=False)
                    .sign(key, hashes.SHA256()))
                pem = cert.public_bytes(PEM)
                serial = format(cert.serial_number, 'x')
                issuer_hash = issuer.fingerprint(hashes.SHA256()).hex()
                db.execute('INSERT INTO pki_certificates(serial,certificate) VALUES (?,?)', (serial, pem))
                db.execute('INSERT INTO radius_certificate_bindings VALUES (?,?,?,?,?,?,1)',
                    (issuer_hash, serial, account.domain, account.object_guid, account.sid, account.kind))
                db.execute('INSERT INTO pki_client_keys VALUES (?,?,?)', (serial, csr_hash, key_hash))
                self.pki._audit(db, 'pki_user_issued:' + serial + ':actor:' + actor)
            return {'serial': serial, 'certificate': pem.decode('ascii'), 'kind': 'user',
                    'not_after': end.isoformat(), 'radius_connected': False}
        except DirectoryError:
            raise EnrollmentError('ENROLLMENT_AUTHENTICATION_FAILED') from None
        except DirectoryUnavailable:
            raise EnrollmentError('ENROLLMENT_DIRECTORY_UNAVAILABLE') from None
        finally:
            credentials['password'] = ''

    @staticmethod
    def certificates(store, *, offset=0):
        integer(offset, 0, 10000)
        with store.connect() as db:
            tables = {x[0] for x in db.execute("SELECT name FROM sqlite_master WHERE type='table'")}
            if 'pki_certificates' not in tables:
                return {'items': [], 'total': 0, 'offset': offset, 'radius_connected': False}
            total = db.execute('SELECT count(*) FROM pki_certificates').fetchone()[0]
            query = '''SELECT c.serial,c.certificate,c.revoked_at,b.kind,b.object_guid
                FROM pki_certificates c LEFT JOIN radius_certificate_bindings b ON b.serial=c.serial
                ORDER BY c.rowid DESC LIMIT 100 OFFSET ?''' if 'radius_certificate_bindings' in tables else '''
                SELECT serial,certificate,revoked_at,NULL,NULL FROM pki_certificates
                ORDER BY rowid DESC LIMIT 100 OFFSET ?'''
            rows = db.execute(query, (offset,)).fetchall()
        now = instant()
        items = []
        for serial, pem, revoked, kind, guid in rows:
            cert = x509.load_pem_x509_certificate(pem)
            items.append({'serial': serial, 'kind': kind or 'radius-server', 'object_guid': guid,
                'not_after': cert.not_valid_after_utc.isoformat(), 'status': 'revoked' if revoked else
                    'expired' if now >= cert.not_valid_after_utc else 'valid'})
        return {'items': items, 'total': total, 'offset': offset, 'radius_connected': False}
