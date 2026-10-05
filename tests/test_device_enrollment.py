"""Real CA/CSR transactions with synthetic AD identities, never customer AD."""
import base64
import io
import json
import shutil
import tempfile
import unittest
import uuid
import zipfile
from datetime import datetime, timedelta, timezone
from pathlib import Path
from unittest.mock import patch

from cryptography import x509
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import ec, rsa, padding

from kaname.device_enrollment import DeviceEnrollment
from kaname.directory import DirectoryError
from kaname.directory_linux_helper import Reader
from kaname.enrollment import EnrollmentError
from kaname.operations import Operations
from kaname.pki import PKIService
from kaname.radius import CertificateReference
from kaname.radius_registry import CertificateRegistry
from kaname.store import Store
from tools.linux_initialize import create_web_certificate
from .test_enrollment import PASSWORD, request
from .test_directory import connection
from .test_radius_live import live_account, GROUP, GUID, SID, attributes
from .helpers import config

PRINCIPAL='PC01$@LAB.EXAMPLE'


class DeviceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.base=tempfile.TemporaryDirectory()
        store=Store(cls.base.name); store.save(0,config=config())
        Operations(store).save_directory(1,connection()|{'search_base':'','sync_minutes':15,'check_minutes':5,'automatic_sync':False})
        PKIService(cls.base.name).initialize(PASSWORD)

    @classmethod
    def tearDownClass(cls): cls.base.cleanup()

    def setUp(self):
        self.temp=tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        shutil.copytree(self.base.name,self.temp.name,dirs_exist_ok=True)
        self.account=live_account(); self.connections=[]
        def resolve(connection,cfg,**kwargs):
            self.connections.append(connection)
            self.assertIn(kwargs['computer_sam'].upper(), {'PC01$','PC02$'})
            return self.account
        self.service=DeviceEnrollment(Operations(Store(self.temp.name)),resolver=resolve)
        self.service.unlock_signer(PASSWORD,'test')
        self.fields={'id':'','version':0,'name':'Pilot computers','group_sid':GROUP,'validity_days':90,'renew_before_days':30,'enabled':True}
        self.profile=self.service.save_profile(self.fields,'test')
        self.key=ec.generate_private_key(ec.SECP256R1())

    def proof(self,key,payload):
        raw=base64.b64decode(payload)
        signature=key.sign(raw,padding.PKCS1v15(),hashes.SHA256()) if isinstance(key,rsa.RSAPrivateKey) else key.sign(raw,ec.ECDSA(hashes.SHA256()))
        return base64.b64encode(signature).decode()

    def enrollment(self,key=None,principal=PRINCIPAL):
        key=key or self.key; csr=request(key).decode()
        challenge=self.service.challenge(principal,{'profile_id':self.profile['id'],'csr':csr})
        value={'challenge_id':challenge['challenge_id'],'csr':csr,'proof':self.proof(key,challenge['payload'])}
        return self.service.issue(principal,value),value

    def receipt(self,result,key=None,principal=PRINCIPAL):
        return self.service.receipt(principal,{'serial':result['serial'],'proof':self.proof(key or self.key,result['receipt_payload'])})

    def reject(self,code,fn):
        with self.assertRaises(EnrollmentError) as error: fn()
        self.assertEqual(code,error.exception.code)

    def count(self):
        with self.service.store.connect() as db: return db.execute('SELECT count(*) FROM pki_certificates').fetchone()[0]

    def test_computer_binding_installed_receipt_and_restart_idempotency(self):
        result,value=self.enrollment()
        self.assertEqual('issued',self.service.status()['devices'][0]['status'])
        cert=x509.load_pem_x509_certificate(result['certificate'].encode())
        self.assertIn('AuthWire computer '+GUID,cert.subject.rfc4514_string())
        self.assertNotIn('Forged',cert.subject.rfc4514_string())
        issuer=x509.load_pem_x509_certificate(self.service.pki.public_bundle()['issuer-ca.pem'])
        binding=CertificateRegistry(self.service.store).lookup(CertificateReference(issuer.fingerprint(hashes.SHA256()).hex(),result['serial']))
        self.assertEqual((GUID,SID,'computer'),(binding.object_guid,binding.sid,binding.kind))
        self.assertEqual(result,self.service.issue(PRINCIPAL,value))
        restarted=DeviceEnrollment(self.service.operations,resolver=self.service.resolver)
        self.assertEqual(result,restarted.issue(PRINCIPAL,value))
        self.assertEqual(1,self.count())
        self.receipt(result)
        self.assertEqual('installed',self.service.status()['devices'][0]['status'])
        audits=len(self.service.store.audit()); self.receipt(result)
        self.assertEqual(audits,len(self.service.store.audit()))
        self.assertTrue(all(x['password']=='' for x in self.connections))

    def test_only_issuer_key_is_sealed_and_lock_prevents_issuance(self):
        with self.service.store.connect() as db:
            row=db.execute('SELECT key_sealed FROM device_signer').fetchone()[0]
            self.assertNotIn(PASSWORD,row)
            self.assertNotIn(b'PRIVATE KEY',row)
        self.assertNotIn(PASSWORD.decode(),json.dumps(self.service.status())+json.dumps(self.service.store.audit()))
        self.service.lock_signer('test')
        self.reject('DEVICE_SIGNER_LOCKED',lambda:self.enrollment())
        self.assertEqual(0,self.count())

    def test_wrong_proof_csr_identity_expiry_and_foreign_session_reject(self):
        csr=request(self.key).decode(); ch=self.service.challenge(PRINCIPAL,{'profile_id':self.profile['id'],'csr':csr})
        value={'challenge_id':ch['challenge_id'],'csr':csr,'proof':self.proof(self.key,ch['payload'])}
        self.reject('DEVICE_KEY_PROOF_REJECTED',lambda:self.service.issue(PRINCIPAL,value|{'proof':base64.b64encode(b'bad').decode()}))
        self.reject('DEVICE_CHALLENGE_REJECTED',lambda:self.service.issue('PC02$@LAB.EXAMPLE',value))
        self.reject('DEVICE_CHALLENGE_REJECTED',lambda:self.service.issue(PRINCIPAL,value|{'csr':request().decode()}))
        with self.service.store.connect() as db: db.execute('UPDATE device_challenges SET expires=0')
        self.reject('DEVICE_CHALLENGE_REJECTED',lambda:self.service.issue(PRINCIPAL,value))
        self.assertEqual(0,self.count())

    def test_users_disabled_group_removed_and_ad_failure_cannot_issue(self):
        for account in (live_account(kind='user'),live_account(enabled=False),live_account(security_group_sids=frozenset())):
            self.account=account; self.reject('DEVICE_IDENTITY_REJECTED',lambda:self.enrollment())
        self.reject('DEVICE_IDENTITY_REJECTED',lambda:self.service.challenge('alice@LAB.EXAMPLE',{'profile_id':self.profile['id'],'csr':request().decode()}))
        self.service.resolver=lambda *args,**kwargs: (_ for _ in ()).throw(DirectoryError('AD_TIMEOUT'))
        self.reject('DEVICE_DIRECTORY_UNAVAILABLE',lambda:self.enrollment())
        self.assertEqual(0,self.count())

    def test_profile_version_change_between_challenge_and_issue(self):
        csr=request(self.key).decode(); ch=self.service.challenge(PRINCIPAL,{'profile_id':self.profile['id'],'csr':csr})
        self.service.save_profile(self.fields|self.profile|{'name':'Changed'},'test')
        self.reject('REVISION_CONFLICT',lambda:self.service.issue(PRINCIPAL,{'challenge_id':ch['challenge_id'],'csr':csr,'proof':self.proof(self.key,ch['payload'])}))
        self.reject('REVISION_CONFLICT',lambda:self.service.save_profile(self.fields|self.profile,'test'))

    def test_revocation_cannot_be_resurrected_by_retry_or_receipt(self):
        result,value=self.enrollment(); self.service.pki.revoke(result['serial'],PASSWORD)
        self.reject('DEVICE_CERTIFICATE_REVOKED',lambda:self.service.issue(PRINCIPAL,value))
        self.reject('DEVICE_IDENTITY_REJECTED',lambda:self.receipt(result))
        self.assertEqual('revoked',self.service.status()['devices'][0]['status'])

    def test_new_key_renewal_retains_old_until_receipt_then_signed_retirement(self):
        old,_=self.enrollment()
        newkey=rsa.generate_private_key(public_exponent=65537,key_size=2048)
        self.reject('DEVICE_INSTALLATION_PENDING',lambda:self.enrollment(newkey))
        self.receipt(old)
        self.reject('DEVICE_RENEWAL_NOT_DUE',lambda:self.enrollment(newkey))
        future=datetime.now(timezone.utc)+timedelta(days=70)
        with patch('kaname.device_enrollment.instant',return_value=future):
            new,_=self.enrollment(newkey); self.receipt(new,newkey)
        self.assertNotEqual(old['serial'],new['serial'])
        with self.service.store.connect() as db:
            self.assertIsNone(db.execute('SELECT revoked_at FROM pki_certificates WHERE serial=?',(old['serial'],)).fetchone()[0])
            db.execute('UPDATE device_retirements SET retire_at=?',((datetime.now(timezone.utc)-timedelta(seconds=1)).isoformat(),))
        self.service.maintenance()
        crl=x509.load_pem_x509_crl(self.service.pki.public_bundle()['issuer-crl.pem'])
        self.assertIn(int(old['serial'],16),[row.serial_number for row in crl])
        self.assertEqual('revoked',next(x for x in self.service.status()['devices'] if x['serial']==old['serial'])['status'])

    def test_identity_change_even_same_principal_cannot_get_old_certificate(self):
        result,value=self.enrollment()
        self.account=live_account(object_guid=str(uuid.UUID(int=2002)),sid='S-1-5-21-1-2-3-2002')
        self.reject('DEVICE_IDENTITY_REJECTED',lambda:self.service.issue(PRINCIPAL,value))
        self.assertEqual(1,self.count())

    def test_certificate_and_binding_rollback_on_audit_failure(self):
        csr=request(self.key).decode(); ch=self.service.challenge(PRINCIPAL,{'profile_id':self.profile['id'],'csr':csr})
        with patch.object(self.service.pki,'_audit',side_effect=RuntimeError('fixture audit outage')):
            with self.assertRaises(RuntimeError):self.service.issue(PRINCIPAL,{'challenge_id':ch['challenge_id'],'csr':csr,'proof':self.proof(self.key,ch['payload'])})
        self.assertEqual(0,self.count())
        with self.service.store.connect() as db:self.assertEqual(0,db.execute('SELECT count(*) FROM radius_certificate_bindings').fetchone()[0])

    def test_deployment_contains_only_public_certificates_and_requires_signing(self):
        tlsdir=Path(self.temp.name)/'tls';tlsdir.mkdir()
        create_web_certificate(tlsdir,'authwire.lab.example','127.0.0.1')
        data=self.service.package(self.profile['id'],hostname='authwire.lab.example',port=8765,tls_pem=(tlsdir/'web.crt').read_bytes())
        with zipfile.ZipFile(io.BytesIO(data)) as archive:
            self.assertEqual({'AuthWire-Client.ps1','Install-AuthWire.ps1','config.json','root-ca.pem','issuer-ca.pem','https-trust.pem','README.txt','SHA256SUMS.txt'},set(archive.namelist()))
            for name in archive.namelist():self.assertNotIn(b'PRIVATE KEY',archive.read(name))
            self.assertIn(b'AllSigned',archive.read('Install-AuthWire.ps1'))
            self.assertIn(b'Authenticode',archive.read('README.txt'))
            self.assertIn(b'authwire.lab.example',archive.read('config.json'))
        self.reject('DEVICE_TLS_NAME_MISMATCH',lambda:self.service.package(self.profile['id'],hostname='wrong.lab.example',port=8765,tls_pem=(tlsdir/'web.crt').read_bytes()))

    def test_machine_sam_ldap_resolution_no_caller_guid(self):
        import types
        reader=Reader(None,types.SimpleNamespace(SCOPE_SUBTREE=2,SCOPE_BASE=0),None)
        calls=[];dn='CN=PC01,DC=lab,DC=example'
        def search(base,scope,filter_value,attrs):
            calls.append(filter_value)
            return [(dn,attributes()|{'samaccountname':[b'PC01$']})],[]
        reader.search=search
        account=reader.computer('lab.example','PC01$')
        self.assertEqual((GUID,'computer'),(account['object_guid'],account['kind']))
        self.assertIn('(sAMAccountName=PC01$)',calls[0])
        with self.assertRaises(DirectoryError):reader.computer('lab.example','*)(objectClass=*)')
