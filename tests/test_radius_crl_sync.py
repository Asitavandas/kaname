"""Real signature, validity, monotonic revocation and atomic publication checks."""
from datetime import datetime, timedelta, timezone
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa

from kaname.pki import PKIService
from tools import radius_crl_sync as updater

PASSWORD = b'disposable-crl-signing-fixture'
PEM = serialization.Encoding.PEM


class CRLPublicationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.state = self.root/'state'
        self.pki = PKIService(self.state);self.pki.initialize(PASSWORD)
        self.now = datetime.now(timezone.utc).replace(microsecond=0)
        with self.pki.store.connect() as db:
            row = db.execute('SELECT root_cert,issuer_cert,issuer_key FROM pki_authority').fetchone()
        self.issuer = x509.load_pem_x509_certificate(row[1])
        self.key = serialization.load_pem_private_key(row[2], PASSWORD)
        self.ca = self.root/'runtime'/'ca';self.ca.mkdir(parents=True, mode=0o700)
        self.ca.parent.chmod(0o700)
        for name, raw in self.pki.public_bundle().items():
            (self.ca/name).write_bytes(raw);(self.ca/name).chmod(0o600)
        self.target = self.ca/'issuer-crl.pem'
        self.old = self.target.read_bytes()

    def crl(self, number=2, serials=(), *, now=None, key=None):
        rows = [(format(serial, 'x'), self.now.isoformat(), 'superseded') for serial in serials]
        return self.pki._build_crl(self.issuer, key or self.key, rows, number,
                                  now or self.now).public_bytes(PEM)

    def publish(self, raw, number=2):
        with self.pki.store.connect() as db:
            db.execute('UPDATE pki_authority SET crl=?,crl_number=?', (raw, number))

    def sync(self):
        return updater.sync(self.state, self.ca, now=self.now)

    def refused(self):
        before = self.target.read_bytes()
        with self.assertRaises(Exception):self.sync()
        self.assertEqual(before, self.target.read_bytes())

    def test_signed_publication_keeps_ca_state_and_keys_unchanged(self):
        self.publish(self.crl(serials=(10,)))
        with self.pki.store.connect() as db:before = db.execute('SELECT * FROM pki_authority').fetchone()
        anchors = [(self.ca/name).read_bytes() for name in ('root-ca.pem','issuer-ca.pem')]
        result = self.sync()
        self.assertTrue(result['changed']);self.assertFalse(result['radius_restarted'])
        self.assertEqual(0o600, self.target.stat().st_mode & 0o777)
        self.assertEqual(os.geteuid(), self.target.stat().st_uid)
        with self.pki.store.connect() as db:self.assertEqual(before, db.execute('SELECT * FROM pki_authority').fetchone())
        self.assertEqual(anchors, [(self.ca/name).read_bytes() for name in ('root-ca.pem','issuer-ca.pem')])
        self.assertFalse(self.sync()['changed'])

    def test_valid_new_list_recovers_expired_runtime_copy(self):
        old = self.crl(1, now=self.now-timedelta(days=2))
        self.target.write_bytes(old)
        self.publish(self.crl())
        self.assertTrue(self.sync()['changed'])

    def test_expired_or_future_source_is_never_published(self):
        for now in (self.now-timedelta(days=2), self.now+timedelta(hours=1)):
            self.publish(self.crl(now=now));self.refused()

    def test_forged_signature_is_never_published(self):
        self.publish(self.crl(key=rsa.generate_private_key(65537, 3072)))
        self.refused()

    def test_number_mismatch_and_same_number_replacement_are_refused(self):
        self.publish(self.crl(), number=3);self.refused()
        self.publish(self.crl(number=1, serials=(10,)), number=1);self.refused()

    def test_number_rollback_and_removal_of_existing_revocation_are_refused(self):
        self.target.write_bytes(self.crl(3, serials=(10,)))
        self.publish(self.crl(2, serials=(10,)), 2);self.refused()
        self.publish(self.crl(4), 4);self.refused()

    def test_authority_expiry_or_runtime_trust_change_is_refused(self):
        self.publish(self.crl())
        with self.assertRaises(Exception):updater.sync(self.state,self.ca,now=self.now+timedelta(days=4000))
        original = self.ca/'issuer-ca.pem'
        original.write_bytes((self.ca/'root-ca.pem').read_bytes())
        self.refused()

    def test_symlink_destination_state_and_lock_are_refused(self):
        self.publish(self.crl())
        outside = self.root/'outside';outside.write_bytes(self.old)
        self.target.unlink();self.target.symlink_to(outside)
        self.refused();self.assertEqual(self.old,outside.read_bytes())
        self.target.unlink();self.target.write_bytes(self.old);self.target.chmod(0o600)
        linked = self.root/'linked-state';linked.symlink_to(self.state, target_is_directory=True)
        with self.assertRaises(Exception):updater.sync(linked,self.ca,now=self.now)
        lock = self.ca/'.crl-sync.lock';lock.unlink(missing_ok=True);lock.symlink_to(outside)
        self.refused();self.assertEqual(self.old,outside.read_bytes())

    def test_atomic_failure_preserves_previous_list_and_cleans_temporary_file(self):
        self.publish(self.crl())
        with patch('tools.radius_crl_sync.os.replace',side_effect=OSError('fixture failure')):
            self.refused()
        self.assertFalse(list(self.ca.glob('.issuer-crl-*')))

    def test_writable_runtime_file_and_stopped_runtime_are_refused(self):
        self.publish(self.crl());self.target.chmod(0o666);self.refused()
        stopped = self.root/'absent-runtime'/'ca'
        with self.assertRaises(Exception):updater.sync(self.state,stopped,now=self.now)
        self.assertFalse(stopped.parent.exists())


if __name__ == '__main__':unittest.main()
