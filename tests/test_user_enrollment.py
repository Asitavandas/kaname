"""User enrollment with real CA/CSR and disposable directory claims, never live AD."""
import base64
import json
import shutil
import tempfile
import unittest
import uuid
from concurrent.futures import ThreadPoolExecutor
from datetime import timedelta
from unittest.mock import patch

from cryptography import x509
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import ec

from kaname.device_enrollment import DeviceEnrollment
from kaname.enrollment import EnrollmentError
from kaname.operations import Operations
from kaname.pki import instant
from kaname.radius import CertificateReference
from kaname.radius_registry import CertificateRegistry
from kaname.store import Store
from kaname.user_enrollment import UserEnrollment
from .test_device_enrollment import DeviceTests, PRINCIPAL as MACHINE
from .test_enrollment import PASSWORD, request
from .test_radius_live import GROUP, GUID, SID, live_account

USER = 'Alice@LAB.EXAMPLE'


class UserEnrollmentTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        DeviceTests.setUpClass.__func__(cls)

    @classmethod
    def tearDownClass(cls):
        cls.base.cleanup()

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        shutil.copytree(self.base.name, self.temp.name, dirs_exist_ok=True)
        self.account, self.connections = live_account(kind='user'), []
        def resolve(connection, config, **kwargs):
            self.connections.append(connection)
            self.assertEqual({'user_sam': 'Alice'}, kwargs)
            return self.account
        self.devices = DeviceEnrollment(Operations(Store(self.temp.name)))
        self.devices.unlock_signer(PASSWORD, 'fixture')
        self.users = UserEnrollment(self.devices, resolver=resolve)
        self.fields = {'id':'', 'version':0, 'name':'Pilot users', 'group_sid':GROUP,
            'validity_days':90, 'renew_before_days':30, 'enabled':True}
        self.profile = self.users.save_profile(self.fields, 'fixture')
        self.key = ec.generate_private_key(ec.SECP256R1())

    proof = DeviceTests.proof

    def prepare(self, key=None):
        key = key or self.key; csr = request(key).decode()
        challenge = self.users.challenge(USER, {'profile_id':self.profile['id'], 'csr':csr})
        return {'challenge_id':challenge['challenge_id'], 'csr':csr, 'proof':self.proof(key, challenge['payload'])}

    def issue(self, key=None):
        return self.users.issue(USER, self.prepare(key))

    def receipt(self, result, key=None):
        return self.users.receipt(USER, {'serial':result['serial'], 'proof':self.proof(key or self.key, result['receipt_payload'])})

    def reject(self, code, action):
        with self.assertRaises(EnrollmentError) as caught: action()
        self.assertEqual(code, caught.exception.code)

    def binding(self, serial):
        issuer = x509.load_pem_x509_certificate(self.devices.pki.public_bundle()['issuer-ca.pem'])
        return CertificateRegistry(self.users.store).lookup(CertificateReference(issuer.fingerprint(hashes.SHA256()).hex(), serial))

    def test_user_binding_receipt_and_machine_storage_isolation(self):
        result = self.issue(); cert = x509.load_pem_x509_certificate(result['certificate'].encode())
        self.assertIn('AuthWire user '+GUID, cert.subject.rfc4514_string())
        self.assertEqual((GUID,SID,'user'), (self.binding(result['serial']).object_guid,self.binding(result['serial']).sid,self.binding(result['serial']).kind))
        self.assertEqual('issued',self.users.status()['users'][0]['status'])
        self.receipt(result); self.assertEqual('installed',self.users.status()['users'][0]['status'])
        self.assertEqual([], self.devices.status()['profiles']); self.assertEqual([],self.devices.status()['devices'])
        self.assertTrue(all(c['password']=='' for c in self.connections))
        self.assertFalse(self.users.status()['windows_client_available'])

    def test_proof_replay_is_idempotent_across_service_restart(self):
        value=self.prepare(); first=self.users.issue(USER,value)
        restarted=UserEnrollment(self.devices,resolver=self.users.resolver)
        self.assertEqual(first,restarted.issue(USER,value))
        with self.users.store.connect() as db:
            self.assertEqual(1, db.execute('SELECT count(*) FROM user_enrollment_issuances').fetchone()[0])
        self.receipt(first); audits=len(self.users.store.audit());self.receipt(first)
        self.assertEqual(audits,len(self.users.store.audit()))

    def test_same_csr_concurrency_issues_exactly_once(self):
        value=self.prepare()
        with ThreadPoolExecutor(max_workers=3) as pool:
            results=list(pool.map(lambda _:self.users.issue(USER,value),range(3)))
        self.assertEqual(1,len({r['serial'] for r in results}))
        with self.users.store.connect() as db:
            self.assertEqual(1,db.execute('SELECT count(*) FROM pki_client_keys').fetchone()[0])

    def test_machine_spn_other_realm_alias_and_untrusted_identifiers_refused(self):
        for principal in (MACHINE,'HTTP/server@LAB.EXAMPLE','Alice@foreign.example','Alice/admin@LAB.EXAMPLE','Alice\\name@LAB.EXAMPLE'):
            self.reject('USER_IDENTITY_REJECTED',lambda:self.users.challenge(principal,{'profile_id':self.profile['id'],'csr':request(self.key).decode()}))
        with self.assertRaises(ValueError):
            self.users.challenge(USER,{'profile_id':self.profile['id'],'csr':request(self.key).decode(),'sid':SID})

    def test_live_group_withdrawal_disabled_or_machine_account_refused(self):
        for changes in ({'enabled':False},{'kind':'computer'},{'security_group_sids':frozenset()}, {'domain':'foreign.example'}):
            self.account=live_account(kind='user') if 'kind' not in changes else live_account()
            self.account=live_account(**({'kind':'user'}|changes))
            self.reject('USER_IDENTITY_REJECTED',lambda:self.prepare())
        self.assertEqual(0,self.users.status()['total'])

    def test_recreated_user_between_challenge_and_issue_does_not_inherit_key(self):
        for changes in ({'object_guid':str(uuid.uuid4())},{'sid':'S-1-5-21-1-2-3-9999'}):
            self.account=live_account(kind='user');value=self.prepare()
            self.account=live_account(**({'kind':'user'}|changes))
            self.reject('USER_IDENTITY_REJECTED',lambda:self.users.issue(USER,value))

    def test_profile_version_disable_and_expired_challenge_block_issue(self):
        value=self.prepare(); self.users.save_profile(self.fields|self.profile|{'enabled':False},'fixture')
        self.reject('REVISION_CONFLICT',lambda:self.users.issue(USER,value))
        self.profile=self.users.save_profile(self.fields|self.profile|{'version':2},'fixture')
        value=self.prepare()
        with self.users.store.connect() as db: db.execute('UPDATE user_enrollment_challenges SET expires=0')
        self.reject('USER_CHALLENGE_REJECTED',lambda:self.users.issue(USER,value))

    def test_other_key_or_other_user_cannot_complete_challenge(self):
        value=self.prepare();other=ec.generate_private_key(ec.SECP256R1())
        self.reject('USER_CHALLENGE_REJECTED',lambda:self.users.issue('Bob@LAB.EXAMPLE',value))
        self.reject('USER_CHALLENGE_REJECTED',lambda:self.users.issue(USER,value|{'csr':request(other).decode()}))
        self.reject('DEVICE_KEY_PROOF_REJECTED',lambda:self.users.issue(USER,value|{'proof':base64.b64encode(b'wrong').decode()}))

    def test_existing_global_key_registry_prevents_machine_user_key_reuse(self):
        value=self.prepare(); first=self.users.issue(USER,value)
        # A new user profile cannot reuse a CSR/key that already has a binding.
        self.profile=self.users.save_profile(self.fields,'fixture')
        self.reject('CSR_ALREADY_USED',lambda:self.users.issue(USER,self.prepare()))
        self.assertEqual('user',self.binding(first['serial']).kind)
        self.devices.resolver=lambda *a,**kw:live_account()
        profile=self.devices.save_profile(self.fields,'fixture')
        csr=request(self.key).decode();challenge=self.devices.challenge(MACHINE,{'profile_id':profile['id'],'csr':csr})
        self.reject('CSR_ALREADY_USED',lambda:self.devices.issue(MACHINE,{'challenge_id':challenge['challenge_id'],'csr':csr,'proof':self.proof(self.key,challenge['payload'])}))

    def test_renewal_new_key_only_and_retirement_after_installation(self):
        first=self.issue();self.receipt(first)
        self.reject('USER_RENEWAL_NOT_DUE',lambda:self.issue(ec.generate_private_key(ec.SECP256R1())))
        self.users.request_renewal(first['serial'],'fixture')
        self.assertTrue(self.receipt(first)['renew_now'])
        key=ec.generate_private_key(ec.SECP256R1());second=self.issue(key)
        self.assertIsNotNone(self.binding(first['serial']))
        with self.users.store.connect() as db:
            self.assertIsNone(db.execute('SELECT retire_at FROM device_retirements WHERE serial=?',(first['serial'],)).fetchone())
        self.receipt(second,key);self.assertNotEqual(first['serial'],second['serial'])
        with self.users.store.connect() as db:
            self.assertIsNotNone(db.execute('SELECT retire_at FROM device_retirements WHERE serial=?',(first['serial'],)).fetchone())
            db.execute('UPDATE device_retirements SET retire_at=? WHERE serial=?',((instant()-timedelta(seconds=1)).isoformat(),first['serial']))
        self.assertIsNone(self.binding(first['serial']));self.assertIsNotNone(self.binding(second['serial']))
        self.devices.maintenance()
        with self.users.store.connect() as db:
            self.assertEqual('superseded',db.execute('SELECT reason FROM pki_certificates WHERE serial=?',(first['serial'],)).fetchone()[0])
        self.assertTrue(any(a['event']=='user_certificate_superseded:'+first['serial'] for a in self.users.store.audit()))

    def test_receipt_checks_fresh_identity_and_profile_and_is_not_machine_receipt(self):
        result=self.issue()
        self.account=live_account(kind='user',enabled=False)
        self.reject('USER_IDENTITY_REJECTED',lambda:self.receipt(result))
        self.account=live_account(kind='user')
        self.reject('DEVICE_IDENTITY_REJECTED',lambda:self.devices.receipt(MACHINE,{'serial':result['serial'],'proof':self.proof(self.key,result['receipt_payload'])}))
        self.users.save_profile(self.fields|self.profile|{'enabled':False},'fixture')
        self.reject('USER_IDENTITY_REJECTED',lambda:self.receipt(result))

    def test_issuer_lock_and_rate_limit_fail_closed(self):
        self.devices.lock_signer('fixture')
        self.reject('DEVICE_SIGNER_LOCKED',lambda:self.prepare())
        self.devices.unlock_signer(PASSWORD,'fixture')
        for _ in range(10):self.prepare()
        self.reject('USER_RETRY_LATER',lambda:self.prepare())
