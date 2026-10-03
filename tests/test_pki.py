import base64
import shutil
import socket
import sqlite3
import ssl
import subprocess
import tempfile
import threading
import unittest
from datetime import timedelta
from pathlib import Path

from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec, rsa
from cryptography.x509.oid import ExtendedKeyUsageOID, NameOID

from kaname.pki import PKIError, PKIService, instant, private_pem, validate_csr, write_new
from kaname.store import Store
from .helpers import config, policy

PASSWORD = b'fixture-only-passphrase-12345'
FQDN = config()['appliance_fqdn']
PEM = serialization.Encoding.PEM


def csr(key, names=None, extras=()):
    builder = (x509.CertificateSigningRequestBuilder()
               .subject_name(x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, 'Untrusted CSR subject')]))
               .add_extension(x509.SubjectAlternativeName(names or [x509.DNSName(FQDN)]), critical=False))
    for extension, critical in extras:
        builder = builder.add_extension(extension, critical)
    return builder.sign(key, hashes.SHA256()).public_bytes(PEM)


class PKITests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.baseline = tempfile.TemporaryDirectory()
        cls.now = instant()
        service = PKIService(cls.baseline.name)
        service.store.save(0, config=config())
        service.initialize(PASSWORD, now=cls.now)
        cls.server_key = rsa.generate_private_key(65537, 2048)
        cls.good_csr = csr(cls.server_key)

    @classmethod
    def tearDownClass(cls):
        cls.baseline.cleanup()

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        shutil.copyfile(Path(self.baseline.name) / 'kaname.sqlite3', Path(self.temp.name) / 'kaname.sqlite3')
        self.service = PKIService(self.temp.name)

    def issue(self, **changes):
        args = dict(csr_pem=self.good_csr, password=PASSWORD, now=self.now)
        args.update(changes)
        return x509.load_pem_x509_certificate(self.service.issue_radius(**args))

    def db_value(self, sql):
        with self.service.store.connect() as db:
            return db.execute(sql).fetchone()[0]

    def inject_audit_failure(self):
        with self.service.store.connect() as db:
            db.execute("CREATE TRIGGER pki_audit_fail BEFORE INSERT ON audit BEGIN SELECT RAISE(ABORT,'injected failure'); END")

    def test_previous_configuration_and_policies_survive(self):
        with tempfile.TemporaryDirectory() as temp:
            old = Store(temp)
            old.save(0, config=config()); old.save(1, policies=[policy()])
            before = old.snapshot()
            service = PKIService(temp)
            self.assertEqual(service.store.snapshot(), before)
            service.initialize(PASSWORD, now=self.now)
            self.assertEqual(service.store.snapshot(), before)

    def test_independent_initializations_have_distinct_keys_and_identity(self):
        with tempfile.TemporaryDirectory() as temp:
            other = PKIService(temp).initialize(PASSWORD, now=self.now)
            current = self.service.store.public_pki_status()
            self.assertNotEqual(other['instance_id'], current['instance_id'])
            self.assertNotEqual(other['root']['fingerprint_sha256'], current['root']['fingerprint_sha256'])
            self.assertNotEqual(other['issuer']['fingerprint_sha256'], current['issuer']['fingerprint_sha256'])

    def test_existing_ca_cannot_be_reinitialized(self):
        before = self.service.public_bundle()
        with self.assertRaises(PKIError): self.service.initialize(PASSWORD, now=self.now)
        self.assertEqual(self.service.public_bundle(), before)

    def test_short_password_rejected_without_ca(self):
        with tempfile.TemporaryDirectory() as temp:
            service = PKIService(temp)
            with self.assertRaises(PKIError): service.initialize(b'short')
            self.assertFalse(service.store.public_pki_status()['initialized'])

    def test_ca_keys_are_encrypted_pkcs8(self):
        with self.service.store.connect() as db:
            row = db.execute('SELECT root_key,issuer_key FROM pki_authority').fetchone()
        for pem in row:
            self.assertTrue(pem.startswith(b'-----BEGIN ENCRYPTED PRIVATE KEY-----'))
            with self.assertRaises(TypeError): serialization.load_pem_private_key(pem, None)
            self.assertEqual(serialization.load_pem_private_key(pem, PASSWORD).key_size, 3072)

    def test_hierarchy_constraints_and_signatures(self):
        bundle = self.service.public_bundle()
        root = x509.load_pem_x509_certificate(bundle['root-ca.pem'])
        issuer = x509.load_pem_x509_certificate(bundle['issuer-ca.pem'])
        root.verify_directly_issued_by(root); issuer.verify_directly_issued_by(root)
        self.assertEqual(root.extensions.get_extension_for_class(x509.BasicConstraints).value.path_length, 1)
        self.assertEqual(issuer.extensions.get_extension_for_class(x509.BasicConstraints).value.path_length, 0)
        self.assertTrue(issuer.extensions.get_extension_for_class(x509.KeyUsage).value.crl_sign)

    def test_public_status_and_export_never_return_keys(self):
        status = self.service.store.public_pki_status()
        self.assertTrue(status['initialized']); self.assertFalse(status['client_enrollment_enabled'])
        self.assertFalse(status['radius_connected'])
        content = str(status).encode() + b''.join(self.service.public_bundle().values())
        self.assertNotIn(b'PRIVATE KEY', content); self.assertNotIn(PASSWORD, content)

    def test_wrong_passphrase_does_not_issue_or_change_audit(self):
        before = self.service.store.audit()
        with self.assertRaises(PKIError): self.issue(password=b'wrong-password-123456')
        self.assertEqual(self.service.store.audit(), before)
        self.assertEqual(self.db_value('SELECT count(*) FROM pki_certificates'), 0)

    def test_missing_configuration_cannot_issue(self):
        with self.service.store.connect() as db: db.execute('UPDATE state SET config=NULL WHERE id=1')
        with self.assertRaises(PKIError): self.issue()

    def test_missing_ca_cannot_issue(self):
        with self.service.store.connect() as db: db.execute('DELETE FROM pki_authority')
        with self.assertRaises(PKIError): self.issue()

    def test_server_certificate_has_exact_san_and_server_only_eku(self):
        cert = self.issue()
        bundle = self.service.public_bundle()
        issuer = x509.load_pem_x509_certificate(bundle['issuer-ca.pem'])
        cert.verify_directly_issued_by(issuer)
        self.assertEqual(cert.extensions.get_extension_for_class(x509.SubjectAlternativeName).value.get_values_for_type(x509.DNSName), [FQDN])
        self.assertEqual(list(cert.extensions.get_extension_for_class(x509.ExtendedKeyUsage).value), [ExtendedKeyUsageOID.SERVER_AUTH])
        self.assertFalse(cert.extensions.get_extension_for_class(x509.BasicConstraints).value.ca)
        self.assertFalse(cert.extensions.get_extension_for_class(x509.KeyUsage).value.key_cert_sign)
        self.assertEqual(cert.public_key().public_numbers(), self.server_key.public_key().public_numbers())
        self.assertEqual(cert.subject.get_attributes_for_oid(NameOID.COMMON_NAME)[0].value, FQDN)

    def test_ec_p256_server_csr_is_supported(self):
        cert = self.issue(csr_pem=csr(ec.generate_private_key(ec.SECP256R1())))
        self.assertIsInstance(cert.public_key(), ec.EllipticCurvePublicKey)
        self.assertFalse(cert.extensions.get_extension_for_class(x509.KeyUsage).value.key_encipherment)

    def test_weak_rsa_csr_is_rejected(self):
        with self.assertRaises(PKIError): self.issue(csr_pem=csr(rsa.generate_private_key(65537, 1024)))

    def test_unsupported_ec_curve_is_rejected(self):
        with self.assertRaises(PKIError): self.issue(csr_pem=csr(ec.generate_private_key(ec.SECP521R1())))

    def test_csr_for_different_dns_is_rejected(self):
        with self.assertRaises(PKIError): self.issue(csr_pem=csr(self.server_key, [x509.DNSName('other.lab.example')]))

    def test_csr_with_extra_san_is_rejected(self):
        with self.assertRaises(PKIError): self.issue(csr_pem=csr(self.server_key, [x509.DNSName(FQDN), x509.DNSName('other.lab.example')]))

    def test_wildcard_san_is_rejected(self):
        with self.assertRaises(PKIError): self.issue(csr_pem=csr(self.server_key, [x509.DNSName('*.lab.example')]))

    def test_upn_or_email_san_is_rejected(self):
        with self.assertRaises(PKIError): self.issue(csr_pem=csr(self.server_key, [x509.RFC822Name('admin@lab.example')]))

    def test_csr_cannot_request_ca_privileges(self):
        data = csr(self.server_key, extras=[(x509.BasicConstraints(ca=True, path_length=None), True)])
        with self.assertRaises(PKIError): self.issue(csr_pem=data)

    def test_csr_cannot_request_client_eku(self):
        data = csr(self.server_key, extras=[(x509.ExtendedKeyUsage([ExtendedKeyUsageOID.CLIENT_AUTH]), False)])
        with self.assertRaises(PKIError): self.issue(csr_pem=data)

    def test_csr_signature_tampering_is_rejected(self):
        obj = x509.load_pem_x509_csr(self.good_csr)
        der = bytearray(obj.public_bytes(serialization.Encoding.DER)); der[-1] ^= 1
        data = b'-----BEGIN CERTIFICATE REQUEST-----\n' + base64.encodebytes(der) + b'-----END CERTIFICATE REQUEST-----\n'
        with self.assertRaises(PKIError): validate_csr(data, FQDN)

    def test_csr_trailing_object_is_rejected(self):
        with self.assertRaises(PKIError): self.issue(csr_pem=self.good_csr * 2)

    def test_oversized_or_nonbyte_csr_rejected(self):
        for value in (b'x' * 65537, 'not-bytes', b''):
            with self.subTest(value_type=type(value)), self.assertRaises(PKIError): self.issue(csr_pem=value)

    def test_validity_is_capped_by_issuer(self):
        issuer = x509.load_pem_x509_certificate(self.service.public_bundle()['issuer-ca.pem'])
        cert = self.issue(now=issuer.not_valid_after_utc - timedelta(days=10), days=90)
        self.assertEqual(cert.not_valid_after_utc, issuer.not_valid_after_utc)

    def test_expired_ca_is_rejected(self):
        issuer = x509.load_pem_x509_certificate(self.service.public_bundle()['issuer-ca.pem'])
        with self.assertRaises(PKIError): self.issue(now=issuer.not_valid_after_utc + timedelta(seconds=1))

    def test_near_expiry_ca_is_rejected(self):
        issuer = x509.load_pem_x509_certificate(self.service.public_bundle()['issuer-ca.pem'])
        with self.assertRaises(PKIError): self.issue(now=issuer.not_valid_after_utc - timedelta(hours=1))

    def test_naive_clock_is_rejected(self):
        with self.assertRaises(PKIError): self.issue(now=self.now.replace(tzinfo=None))

    def test_corrupted_ca_key_is_rejected_without_repair(self):
        with self.service.store.connect() as db: db.execute('UPDATE pki_authority SET issuer_key=?', (b'corrupt',))
        with self.assertRaises(PKIError): self.issue()
        self.assertEqual(self.db_value('SELECT issuer_key FROM pki_authority'), b'corrupt')

    def test_mismatched_ca_key_is_rejected(self):
        key = private_pem(rsa.generate_private_key(65537, 3072), PASSWORD)
        with self.service.store.connect() as db: db.execute('UPDATE pki_authority SET issuer_key=?', (key,))
        with self.assertRaises(PKIError): self.issue()

    def test_audit_failure_rolls_back_initialization(self):
        with tempfile.TemporaryDirectory() as temp:
            service = PKIService(temp)
            with service.store.connect() as db:
                db.execute("CREATE TRIGGER fail_init BEFORE INSERT ON audit BEGIN SELECT RAISE(ABORT,'failure'); END")
            with self.assertRaises(sqlite3.Error): service.initialize(PASSWORD, now=self.now)
            self.assertFalse(service.store.public_pki_status()['initialized'])

    def test_audit_failure_rolls_back_issuance(self):
        self.inject_audit_failure()
        with self.assertRaises(sqlite3.Error): self.issue()
        self.assertEqual(self.db_value('SELECT count(*) FROM pki_certificates'), 0)

    def test_signed_crl_and_revocation(self):
        cert = self.issue(); serial = format(cert.serial_number, 'x')
        result = self.service.revoke(serial, PASSWORD, now=self.now)
        crl = x509.load_pem_x509_crl(self.service.public_bundle()['issuer-crl.pem'])
        issuer = x509.load_pem_x509_certificate(self.service.public_bundle()['issuer-ca.pem'])
        self.assertTrue(crl.is_signature_valid(issuer.public_key()))
        self.assertEqual(crl.extensions.get_extension_for_class(x509.CRLNumber).value.crl_number, result['crl_number'])
        entry = crl.get_revoked_certificate_by_serial_number(cert.serial_number)
        self.assertEqual(entry.extensions.get_extension_for_class(x509.CRLReason).value.reason, x509.ReasonFlags.key_compromise)

    def test_repeated_revocation_is_idempotent(self):
        cert = self.issue(); serial = format(cert.serial_number, 'x')
        self.service.revoke(serial, PASSWORD, now=self.now)
        before = self.service.public_bundle(); audit = self.service.store.audit()
        result = self.service.revoke(serial, PASSWORD, now=self.now)
        self.assertTrue(result['already_revoked'])
        self.assertEqual(self.service.public_bundle(), before)
        self.assertEqual(self.service.store.audit(), audit)

    def test_unknown_serial_rejected(self):
        with self.assertRaises(PKIError): self.service.revoke('abc', PASSWORD, now=self.now)

    def test_uppercase_serial_is_canonicalized(self):
        cert = self.issue(); serial = format(cert.serial_number, 'X')
        result = self.service.revoke(serial, PASSWORD, now=self.now)
        self.assertEqual(result['serial'], serial.lower())

    def test_invalid_revocation_arguments_rejected(self):
        for serial, reason in (('../1', 'key_compromise'), ('abc', 'certificate_hold'), ('abc', ['bad'])):
            with self.subTest(serial=serial), self.assertRaises(PKIError): self.service.revoke(serial, PASSWORD, reason=reason)

    def test_revocation_audit_failure_rolls_back_crl_and_registry(self):
        cert = self.issue(); serial = format(cert.serial_number, 'x')
        before = self.service.public_bundle(); self.inject_audit_failure()
        with self.assertRaises(sqlite3.Error): self.service.revoke(serial, PASSWORD, now=self.now)
        self.assertEqual(self.service.public_bundle(), before)
        self.assertIsNone(self.db_value('SELECT revoked_at FROM pki_certificates'))

    def test_crl_refresh_preserves_revoked_serials(self):
        cert = self.issue(); serial = format(cert.serial_number, 'x')
        self.service.revoke(serial, PASSWORD, now=self.now)
        data = self.service.refresh_crl(PASSWORD, now=self.now + timedelta(hours=25))
        crl = x509.load_pem_x509_crl(data)
        self.assertIsNotNone(crl.get_revoked_certificate_by_serial_number(cert.serial_number))
        self.assertEqual(crl.extensions.get_extension_for_class(x509.CRLNumber).value.crl_number, 3)

    def test_clock_rollback_behind_crl_is_rejected(self):
        self.service.refresh_crl(PASSWORD, now=self.now + timedelta(hours=1))
        with self.assertRaises(PKIError): self.issue(now=self.now)

    def test_corrupted_crl_is_rejected(self):
        with self.service.store.connect() as db: db.execute('UPDATE pki_authority SET crl=?', (b'corrupt',))
        with self.assertRaises(PKIError): self.issue()

    def test_public_export_cannot_overwrite_files(self):
        path = Path(self.temp.name) / 'old.pem'; path.write_bytes(b'old')
        with self.assertRaises(FileExistsError): write_new(path, b'new')
        self.assertEqual(path.read_bytes(), b'old')

    def test_audit_contains_no_passphrase_or_keys(self):
        self.issue()
        events = str(self.service.store.audit()).encode()
        self.assertNotIn(PASSWORD, events); self.assertNotIn(b'PRIVATE KEY', events)

    def test_ca_chain_and_dns_work_in_real_local_tls_handshake(self):
        cert = self.issue()
        bundle = self.service.public_bundle()
        directory = Path(self.temp.name)
        chain = directory / 'server-chain.pem'; key = directory / 'server.key'
        chain.write_bytes(cert.public_bytes(PEM) + bundle['issuer-ca.pem'])
        key.write_bytes(private_pem(self.server_key, PASSWORD))
        server = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        server.minimum_version = ssl.TLSVersion.TLSv1_2
        server.load_cert_chain(chain, key, password=PASSWORD.decode())
        listener = socket.socket(); self.addCleanup(listener.close)
        listener.bind(('127.0.0.1', 0)); listener.listen(); listener.settimeout(3)
        errors = []
        def serve():
            try:
                connection, _ = listener.accept()
                with connection, server.wrap_socket(connection, server_side=True) as tls:
                    tls.settimeout(3); self.assertEqual(tls.recv(1), b'K'); tls.sendall(b'O')
            except BaseException as error: errors.append(error)
        thread = threading.Thread(target=serve, daemon=True); thread.start()
        client = ssl.create_default_context(cadata=bundle['root-ca.pem'].decode())
        with socket.create_connection(listener.getsockname(), timeout=3) as connection:
            with client.wrap_socket(connection, server_hostname=FQDN) as tls:
                tls.sendall(b'K'); self.assertEqual(tls.recv(1), b'O')
        thread.join(4); self.assertFalse(thread.is_alive()); self.assertEqual(errors, [])

    @unittest.skipUnless(shutil.which('openssl'), 'OpenSSL CLI not installed')
    def test_openssl_verifies_chain_and_rejects_wrong_dns_and_revoked_certificate(self):
        cert = self.issue(); serial = format(cert.serial_number, 'x')
        directory = Path(self.temp.name)
        bundle = self.service.public_bundle()
        for name, data in bundle.items(): (directory / name).write_bytes(data)
        leaf = directory / 'radius.pem'; leaf.write_bytes(cert.public_bytes(PEM))
        command = [shutil.which('openssl'), 'verify', '-CAfile', str(directory / 'root-ca.pem'),
                   '-untrusted', str(directory / 'issuer-ca.pem'), '-purpose', 'sslserver',
                   '-verify_hostname', FQDN, str(leaf)]
        self.assertEqual(subprocess.run(command, capture_output=True, timeout=5).returncode, 0)
        wrong = command.copy(); wrong[wrong.index('-verify_hostname') + 1] = 'wrong.lab.example'
        self.assertNotEqual(subprocess.run(wrong, capture_output=True, timeout=5).returncode, 0)
        self.service.revoke(serial, PASSWORD, now=self.now)
        crl = directory / 'issuer-crl.pem'; crl.write_bytes(self.service.public_bundle()['issuer-crl.pem'])
        result = subprocess.run(command[:-1] + ['-crl_check', '-CRLfile', str(crl), str(leaf)], capture_output=True, timeout=5)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(b'certificate revoked', result.stderr)
