"""Real SQLite/public PKI fixtures; no customer AD, GPO, key ACL or service writes."""
import base64
import concurrent.futures
import copy
import json
from pathlib import Path
import shutil
import sqlite3
import subprocess
import sys
import tempfile
import unittest
import uuid
from unittest.mock import patch

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding, rsa

from kaname.connector_channel import ChannelError
from kaname.connector_registry import ConnectorRegistry, RegistryError, SECTION
from kaname.operations import Operations
from kaname.pki import PKIService
from kaname.store import Store, ConflictError
from tools.linux_initialize import create_web_certificate
from .helpers import config


class ConnectorRegistryTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.base = tempfile.TemporaryDirectory()
        root = Path(cls.base.name)
        store = Store(root/'state')
        store.save(0, config=config())
        Operations(store)
        cls.authority = PKIService(store.root).initialize(b'fixture-connector-pairing-password')
        create_web_certificate(root, 'kaname.lab.example', '127.0.0.1')
        cls.cert = (root/'web.crt').read_bytes()
        cls.private = rsa.generate_private_key(public_exponent=65537, key_size=3072)
        cls.other = rsa.generate_private_key(public_exponent=65537, key_size=3072)
        cls.actor = str(uuid.uuid4())

    @classmethod
    def tearDownClass(cls):
        cls.base.cleanup()

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        root = Path(self.temp.name)
        shutil.copyfile(Path(self.base.name)/'state/kaname.sqlite3', root/'kaname.sqlite3')
        self.store = Store(root); self.ops = Operations(self.store)
        self.registry = ConnectorRegistry(self.ops, self.cert)
        self.candidate = {
            'instance_id': self.authority['instance_id'], 'connector_id': str(uuid.uuid4()),
            'host_guid': str(uuid.uuid4()), 'host_fqdn': 'dc01.lab.example',
            'service_sid': 'S-1-5-21-111-222-333-1648',
            'appliance_fqdn': 'kaname.lab.example',
            'appliance_tls_sha256': self.context()['appliance_tls_sha256'],
            'public_key_pem': self.pem(self.private)}

    def context(self):
        with self.store.connect() as db:
            return self.registry._context(db)

    @staticmethod
    def pem(private):
        return private.public_key().public_bytes(serialization.Encoding.PEM,
            serialization.PublicFormat.SubjectPublicKeyInfo).decode('ascii')

    def intent(self, operation='pair', candidate=None):
        return {'expected_revision': self.store.snapshot()['revision'], 'operation': operation,
                'candidate': (self.candidate if candidate is None else candidate) if operation != 'revoke' else {}}

    def prepare(self, intent):
        preview = self.registry.preview(intent)
        return intent | {'preview_hash': preview['preview_hash'],
            'confirmed_key_sha256': preview['after']['channel_key_sha256'] if intent['operation'] != 'revoke' else ''}

    def pair(self):
        return self.registry.apply(self.prepare(self.intent()), self.actor)

    def proof(self, registry=None, private=None):
        registry = registry or self.registry
        frame = base64.b64decode(registry.challenge()['frame'])
        sig = (private or self.private).sign(frame, padding.PKCS1v15(), hashes.SHA256())
        return json.dumps({'challenge_id': frame.decode().split('\n')[10],
                          'signature': base64.b64encode(sig).decode()}).encode()

    def test_preview_is_readonly_and_apply_is_atomic_audited_public_metadata(self):
        before = self.store.snapshot(); audit = self.store.audit()
        value = self.prepare(self.intent())
        self.assertEqual(before, self.store.snapshot()); self.assertEqual(audit, self.store.audit())
        result = self.registry.apply(value, self.actor)
        self.assertEqual(before['revision'] + 1, result['revision'])
        after = self.store.snapshot()
        self.assertEqual(before['config'], after['config']); self.assertEqual(before['policies'], after['policies'])
        status = self.registry.status()
        self.assertTrue(status['paired']); self.assertTrue(status['scope_matches'])
        for flag in ('online','transport_active','can_apply','directory_sync_ready','kerberos_ready'):
            self.assertFalse(status[flag])
        self.assertNotIn('public_key_pem', status['binding'])
        self.assertIn('windows_connector_pair:', self.store.audit()[0]['event'])
        self.assertIn(self.actor, self.store.audit()[0]['event'])
        self.assertNotIn('PRIVATE KEY', json.dumps(status))
        with self.store.connect() as db:
            self.assertEqual(1, db.execute('SELECT COUNT(*) FROM runtime_settings WHERE name=?', (SECTION,)).fetchone()[0])
            self.assertEqual(0, db.execute('SELECT COUNT(*) FROM pki_certificates').fetchone()[0])

    def test_pairing_survives_restart_but_nonces_and_online_do_not(self):
        self.pair()
        pending = self.proof()
        self.registry.accept(self.proof())
        self.assertTrue(self.registry.status()['online'])
        fresh = ConnectorRegistry(Operations(Store(self.store.root)), self.cert)
        self.assertTrue(fresh.status()['paired']); self.assertFalse(fresh.status()['online'])
        with self.assertRaises(ChannelError): fresh.accept(pending)

    def test_two_writers_from_same_preview_only_one_commits(self):
        value = self.prepare(self.intent())
        def apply(_):
            r = ConnectorRegistry(self.ops, self.cert)
            try: return r.apply(value, self.actor)['revision']
            except ConflictError: return None
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            results = list(pool.map(apply, range(2)))
        self.assertEqual(1, sum(v is not None for v in results))
        self.assertEqual(1, sum(x['event'].startswith('windows_connector_pair:') for x in self.store.audit()))

    def test_wrong_confirmation_or_tampered_preview_has_no_mutation(self):
        value = self.prepare(self.intent()); before = self.store.snapshot(); audit = self.store.audit()
        for change in ({'preview_hash':'0'*64}, {'confirmed_key_sha256':'0'*64},
                       {'candidate':self.candidate|{'public_key_pem':self.pem(self.other)}},
                       {'candidate':self.candidate|{'generation':1}}):
            with self.subTest(change=list(change)), self.assertRaises(ValueError):
                self.registry.apply(value|change, self.actor)
            self.assertEqual(before, self.store.snapshot()); self.assertEqual(audit, self.store.audit())

    def test_configuration_and_context_drift_invalidates_preview(self):
        value = self.prepare(self.intent())
        self.store.save(self.store.snapshot()['revision'], config=config()|{'ad_domain':'new.example'})
        with self.assertRaises(ConflictError): self.registry.apply(value, self.actor)
        # A TLS-context change does not bump the config revision, but still stales the preview.
        with self.store.connect() as db:
            db.execute('UPDATE state SET config=? WHERE id=1', (json.dumps(config()),))
        value = self.prepare(self.intent())
        create_web_certificate(Path(self.temp.name), 'kaname.lab.example', '127.0.0.1')
        self.registry.web_certificate = (Path(self.temp.name)/'web.crt').read_bytes()
        changed = self.candidate|{'appliance_tls_sha256':self.context()['appliance_tls_sha256']}
        with self.assertRaisesRegex(RegistryError, 'CONNECTOR_PREVIEW_STALE'):
            self.registry.apply(value|{'candidate':changed}, self.actor)

    def test_rotation_invalidates_old_proofs_in_another_registry(self):
        self.pair(); other = ConnectorRegistry(self.ops, self.cert)
        pending = self.proof(other)
        candidate = self.candidate|{'public_key_pem':self.pem(self.other)}
        self.registry.apply(self.prepare(self.intent('rotate', candidate)), self.actor)
        self.assertEqual(2, other.status()['generation'])
        with self.assertRaises(ChannelError): other.accept(pending)
        self.assertTrue(other.accept(self.proof(other, self.other))['channel_proof_verified'])

    def test_revocation_seen_by_another_registry_and_survives_restart(self):
        self.pair(); other = ConnectorRegistry(self.ops, self.cert)
        pending = self.proof(other)
        self.registry.apply(self.prepare(self.intent('revoke')), self.actor)
        for registry in (other, ConnectorRegistry(self.ops, self.cert)):
            self.assertFalse(registry.status()['paired'])
            self.assertFalse(registry.status()['online'])
            with self.assertRaisesRegex(RegistryError, 'CONNECTOR_NOT_PAIRED'): registry.accept(pending)
        self.assertEqual(2, other.status()['generation'])
        self.pair(); self.assertEqual(3, self.registry.status()['generation'])
        with self.assertRaises(ChannelError): self.registry.accept(pending)

    def test_identity_change_requires_explicit_revoke_not_rotation(self):
        self.pair()
        for change in ({'host_guid':str(uuid.uuid4())}, {'service_sid':'S-1-5-21-111-222-333-1649'},
                       {'connector_id':str(uuid.uuid4())}, {'host_fqdn':'other.lab.example'}):
            with self.assertRaisesRegex(RegistryError, 'CONNECTOR_IDENTITY_CHANGE_REQUIRES_REVOKE'):
                self.registry.preview(self.intent('rotate', self.candidate|change))
        with self.assertRaisesRegex(RegistryError, 'CONNECTOR_ROTATION_UNCHANGED'):
            self.registry.preview(self.intent('rotate'))
        with self.assertRaisesRegex(RegistryError, 'CONNECTOR_ALREADY_PAIRED'):
            self.registry.preview(self.intent())

    def test_tls_rollover_blocks_old_scope_until_explicit_rotation(self):
        self.pair(); pending = self.proof()
        create_web_certificate(Path(self.temp.name), 'kaname.lab.example', '127.0.0.1')
        replacement = (Path(self.temp.name)/'web.crt').read_bytes()
        updated = ConnectorRegistry(self.ops, replacement)
        self.assertFalse(updated.status()['scope_matches'])
        with self.assertRaisesRegex(RegistryError, 'CONNECTOR_CONTEXT_CHANGED'): updated.accept(pending)
        self.registry = updated
        candidate = self.candidate|{'appliance_tls_sha256':self.context()['appliance_tls_sha256']}
        updated.apply(self.prepare(self.intent('rotate', candidate)), self.actor)
        self.assertTrue(updated.status()['scope_matches']); self.assertEqual(2, updated.status()['generation'])

    def test_context_change_blocks_proofs_but_revocation_is_still_possible(self):
        self.pair(); pending = self.proof()
        self.store.save(self.store.snapshot()['revision'], config=config()|{'ad_domain':'other.example'})
        self.assertEqual('CONNECTOR_CONTEXT_CHANGED', self.registry.status()['blocker'])
        with self.assertRaisesRegex(RegistryError, 'CONNECTOR_CONTEXT_CHANGED'): self.registry.accept(pending)
        self.registry.apply(self.prepare(self.intent('revoke')), self.actor)
        self.assertFalse(self.registry.status()['paired'])

    def test_corrupt_unknown_binding_fails_closed_without_repair(self):
        self.pair()
        with self.store.connect() as db:
            raw = db.execute('SELECT payload FROM runtime_settings WHERE name=?', (SECTION,)).fetchone()[0]
            record = json.loads(raw); record['injected']='unexpected'
            db.execute('UPDATE runtime_settings SET payload=? WHERE name=?', (json.dumps(record),SECTION))
        with self.assertRaisesRegex(RegistryError, 'CONNECTOR_STORE_INVALID'): self.registry.status()
        with self.store.connect() as db:
            self.assertEqual(record, json.loads(db.execute('SELECT payload FROM runtime_settings WHERE name=?',(SECTION,)).fetchone()[0]))

    def test_audit_failure_rolls_back_binding_and_revision(self):
        value = self.prepare(self.intent()); before = self.store.snapshot()
        with patch.object(self.ops, '_audit', side_effect=sqlite3.OperationalError('fixture-write-failed')):
            with self.assertRaises(sqlite3.Error): self.registry.apply(value, self.actor)
        self.assertEqual(before, self.store.snapshot()); self.assertFalse(self.registry.status()['paired'])

    def test_failed_rotation_keeps_original_binding_and_unconsumed_proof(self):
        self.pair(); pending = self.proof(); before = self.store.snapshot()
        candidate = self.candidate|{'public_key_pem':self.pem(self.other)}
        value = self.prepare(self.intent('rotate',candidate))
        with patch.object(self.ops,'_audit',side_effect=sqlite3.OperationalError('fixture-audit-failed')):
            with self.assertRaises(sqlite3.Error): self.registry.apply(value,self.actor)
        self.assertEqual(before,self.store.snapshot())
        self.assertEqual(1,self.registry.status()['generation'])
        self.assertTrue(self.registry.accept(pending)['channel_proof_verified'])

    def test_revocation_committed_by_a_real_second_process_invalidates_local_cache(self):
        self.pair(); pending = self.proof()
        code = '''import json,sys
from kaname.store import Store
from kaname.operations import Operations
from kaname.connector_registry import ConnectorRegistry
v=json.load(sys.stdin)
r=ConnectorRegistry(Operations(Store(sys.argv[1])),v['web_certificate'].encode('ascii'))
intent={'expected_revision':r.status()['revision'],'operation':'revoke','candidate':{}}
p=r.preview(intent)
result=r.apply(intent|{'preview_hash':p['preview_hash'],'confirmed_key_sha256':''},v['actor'])
print(json.dumps(result))
'''
        child = subprocess.run([sys.executable,'-c',code,str(self.store.root)],
            input=json.dumps({'web_certificate':self.cert.decode('ascii'),'actor':self.actor}),
            text=True,capture_output=True,check=True,timeout=15)
        self.assertEqual(2,json.loads(child.stdout)['binding']['generation'])
        with self.assertRaisesRegex(RegistryError,'CONNECTOR_NOT_PAIRED'): self.registry.accept(pending)
        self.assertFalse(self.registry.status()['online'])

    @unittest.skipUnless(sys.platform == 'linux','Scheduled backup runs on the Linux appliance')
    def test_sqlite_backup_keeps_public_binding_and_stability_guard_tracks_rotation(self):
        from tools.scheduled_backup import copy_database, db_fingerprint
        self.pair(); self.registry.accept(self.proof())
        before = db_fingerprint(self.store.path)
        copied = Path(self.temp.name)/'copied'; copied.mkdir(mode=0o700)
        copy_database(self.store.path,copied/'kaname.sqlite3')
        restored = ConnectorRegistry(Operations(Store(copied)),self.cert)
        self.assertTrue(restored.status()['paired']);self.assertFalse(restored.status()['online'])
        self.assertEqual(self.registry.status()['binding'],restored.status()['binding'])
        candidate = self.candidate|{'public_key_pem':self.pem(self.other)}
        self.registry.apply(self.prepare(self.intent('rotate',candidate)),self.actor)
        self.assertNotEqual(before,db_fingerprint(self.store.path))

    def test_revision_exhaustion_does_not_prevent_revocation(self):
        self.pair()
        with self.store.connect() as db:
            record = json.loads(db.execute('SELECT payload FROM runtime_settings WHERE name=?',(SECTION,)).fetchone()[0])
            record['binding']['generation']=2**31-1
            db.execute('UPDATE runtime_settings SET payload=? WHERE name=?',(json.dumps(record),SECTION))
        self.registry.apply(self.prepare(self.intent('revoke')), self.actor)
        self.assertFalse(self.registry.status()['paired'])
        with self.assertRaisesRegex(RegistryError, 'CONNECTOR_GENERATION_EXHAUSTED'):
            self.registry.preview(self.intent())

    def test_candidate_must_match_local_instance_domain_tls_and_public_key_policy(self):
        private = self.private.private_bytes(serialization.Encoding.PEM,
            serialization.PrivateFormat.PKCS8,serialization.NoEncryption()).decode()
        for change in ({'instance_id':str(uuid.uuid4())}, {'host_fqdn':'dc01.evil.example'},
                       {'appliance_fqdn':'other.lab.example'}, {'appliance_tls_sha256':'0'*64},
                       {'public_key_pem':private}, {'password':'not-accepted'}, {'generation':1}):
            with self.subTest(change=list(change)), self.assertRaises(ValueError):
                self.registry.preview(self.intent(candidate=self.candidate|change))
        self.assertFalse(self.registry.status()['paired'])
        from cryptography.exceptions import UnsupportedAlgorithm
        with patch('kaname.connector_channel.serialization.load_pem_public_key',
                   side_effect=UnsupportedAlgorithm('fixture-unsupported-key')):
            with self.assertRaisesRegex(RegistryError,'CONNECTOR_BINDING_INVALID'):
                self.registry.preview(self.intent())


if __name__ == '__main__': unittest.main()
