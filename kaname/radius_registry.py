"""Read-only certificate binding registry for the trusted TLS boundary.

No registration or enrollment API exists here. A future authenticated issuer
must atomically write a client certificate and its immutable account binding.
Synthetic bindings in tests do not authorize customer endpoint enrollment.
"""
import sqlite3
from datetime import datetime, timezone

from cryptography import x509
from cryptography.exceptions import InvalidSignature, UnsupportedAlgorithm
from cryptography.hazmat.primitives import hashes
from cryptography.x509.oid import ExtendedKeyUsageOID

from .radius import CertificateBinding, CertificateReference


class CertificateRegistry:
    def __init__(self, store):
        self.store = store

    def lookup(self, reference):
        if type(reference) is not CertificateReference:
            return None
        try:
            with self.store.connect() as db:
                tables = {x[0] for x in db.execute("SELECT name FROM sqlite_master WHERE type='table'")}
                if not {'pki_authority', 'pki_certificates', 'radius_certificate_bindings'} <= tables:
                    return None
                # One read transaction pins CA, revocation and binding together.
                db.execute('BEGIN')
                authority = db.execute('SELECT issuer_cert FROM pki_authority WHERE id=1').fetchone()
                row = db.execute('''SELECT b.domain,b.object_guid,b.sid,b.kind,b.active,c.certificate,c.revoked_at
                    FROM radius_certificate_bindings b JOIN pki_certificates c ON c.serial=b.serial
                    WHERE b.issuer_sha256=? AND b.serial=?''',
                    (reference.issuer_sha256, reference.serial)).fetchone()
                retirement = db.execute('SELECT retire_at FROM device_retirements WHERE serial=?',
                    (reference.serial,)).fetchone() if 'device_retirements' in tables else None
            if authority is None or row is None or row[6] is not None or row[4] not in (0, 1):
                return None
            issuer = x509.load_pem_x509_certificate(authority[0])
            if issuer.fingerprint(hashes.SHA256()).hex() != reference.issuer_sha256:
                return None
            cert = x509.load_pem_x509_certificate(row[5])
            cert.verify_directly_issued_by(issuer)
            now = datetime.now(timezone.utc)
            if retirement and now >= datetime.fromisoformat(retirement[0]):
                return None
            if format(cert.serial_number, 'x') != reference.serial or not cert.not_valid_before_utc <= now < cert.not_valid_after_utc:
                return None
            if cert.extensions.get_extension_for_class(x509.BasicConstraints).value.ca:
                return None
            if set(cert.extensions.get_extension_for_class(x509.ExtendedKeyUsage).value) != {ExtendedKeyUsageOID.CLIENT_AUTH}:
                return None
            if not cert.extensions.get_extension_for_class(x509.KeyUsage).value.digital_signature:
                return None
            return CertificateBinding(reference, *row[:4], active=bool(row[4]))
        except (ValueError, TypeError, InvalidSignature, UnsupportedAlgorithm, x509.ExtensionNotFound, x509.DuplicateExtension, sqlite3.Error, OSError):
            return None
