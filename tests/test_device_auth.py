"""Actual MIT KDC/GSSAPI fixture; no AD, NTLM or customer credentials."""
import base64
import importlib.util
import json
import os
import shutil
import socket
import subprocess
import tempfile
import time
import unittest
from pathlib import Path
from unittest.mock import patch

from kaname.device_auth import KerberosSessions, UserKerberosSessions, encode
from kaname.enrollment import EnrollmentError

AVAILABLE=importlib.util.find_spec('gssapi') is not None and all(shutil.which(name) for name in ('kinit','kadmin.local','kdb5_util','krb5kdc'))


class AcceptorBoundaryTests(unittest.TestCase):
    def test_no_dependency_or_keytab_means_fail_closed(self):
        with tempfile.TemporaryDirectory() as root:
            service=KerberosSessions(Path(root),'authwire.lab.example','lab.example')
            self.assertFalse(service.readiness())
            with self.assertRaises(EnrollmentError):service.start({'token':'TlRMTVNTUA=='})
            with self.assertRaises(EnrollmentError):service.verify('/api/device/issue',{'id':'0'*64,'message':'e30=','mic':'AA=='})

    def test_keytab_symlink_and_public_permissions_rejected(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary);target=root/'target';target.write_bytes(b'fixture');target.chmod(0o644)
            (root/'device-http.keytab').symlink_to(target)
            self.assertFalse(KerberosSessions(root,'authwire.lab.example','lab.example').readiness())

    def test_ci_requires_native_kerberos_fixture(self):
        if os.environ.get('AUTHWIRE_REQUIRE_KERBEROS')=='1':self.assertTrue(AVAILABLE,'Install native gssapi/KDC fixture dependencies')


@unittest.skipUnless(AVAILABLE,'Native Kerberos fixture dependencies are optional outside its mandatory CI job')
class NativeKerberosTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temporary=tempfile.TemporaryDirectory();root=Path(cls.temporary.name);cls.root=root
        sock=socket.socket();sock.bind(('127.0.0.1',0));port=sock.getsockname()[1];sock.close()
        (root/'krb5.conf').write_text(f'''[libdefaults]
 default_realm = LAB.EXAMPLE
 dns_lookup_kdc = false
 dns_lookup_realm = false
 rdns = false
 udp_preference_limit = 1
 dns_canonicalize_hostname = false
[realms]
 LAB.EXAMPLE = {{
  kdc = 127.0.0.1:{port}
 }}
''')
        (root/'kdc.conf').write_text(f'''[kdcdefaults]
 kdc_ports = {port}
 kdc_tcp_ports = {port}
[realms]
 LAB.EXAMPLE = {{
  database_name = {root}/principal
  key_stash_file = {root}/stash
  acl_file = {root}/acl
  max_life = 1h
 }}
''')
        cls.environment={**os.environ,'KRB5_CONFIG':str(root/'krb5.conf'),'KRB5_KDC_PROFILE':str(root/'kdc.conf'),'KRB5CCNAME':'FILE:'+str(root/'ticket')}
        def run(args,**kwargs):return subprocess.run(args,env=cls.environment,capture_output=True,check=True,timeout=10,**kwargs)
        run(['kdb5_util','create','-s','-r','LAB.EXAMPLE','-P','fixture-master-only'])
        run(['kadmin.local','-r','LAB.EXAMPLE','-q','addprinc -pw fixture-machine-only PC01$'])
        run(['kadmin.local','-r','LAB.EXAMPLE','-q','addprinc -pw fixture-user-only Alice'])
        run(['kadmin.local','-r','LAB.EXAMPLE','-q','addprinc -randkey HTTP/authwire.lab.example'])
        run(['kadmin.local','-r','LAB.EXAMPLE','-q','ktadd -k '+str(root/'device-http.keytab')+' HTTP/authwire.lab.example'])
        (root/'device-http.keytab').chmod(0o600)
        cls.process=subprocess.Popen(['krb5kdc','-n','-r','LAB.EXAMPLE'],env=cls.environment,stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)
        for attempt in range(30):
            try:
                run(['kinit','PC01$@LAB.EXAMPLE'],input=b'fixture-machine-only\n');break
            except subprocess.CalledProcessError:time.sleep(0.1)
        else:raise RuntimeError('Fixture KDC did not start')
        cls.env_patch=patch.dict(os.environ,cls.environment);cls.env_patch.start()

    @classmethod
    def tearDownClass(cls):
        cls.env_patch.stop();cls.process.terminate();cls.process.wait(timeout=5);cls.temporary.cleanup()

    def session(self, service_type=KerberosSessions, ticket=None):
        import gssapi
        service=service_type(self.root,'authwire.lab.example','lab.example')
        flags=[gssapi.RequirementFlag.mutual_authentication,gssapi.RequirementFlag.integrity,
            gssapi.RequirementFlag.replay_detection,gssapi.RequirementFlag.out_of_sequence_detection]
        creds=gssapi.Credentials(usage='initiate',store={'ccache':'FILE:'+str(ticket or self.root/'ticket')})
        client=gssapi.SecurityContext(name=gssapi.Name('HTTP/authwire.lab.example@LAB.EXAMPLE',gssapi.NameType.kerberos_principal),
            creds=creds,mech=gssapi.MechType.kerberos,flags=flags)
        start=service.start({'token':encode(client.step())});client.step(base64.b64decode(start['token']))
        self.assertTrue(client.complete)
        return service,client,start['id']

    def test_real_mutual_auth_and_both_message_integrity_directions(self):
        service,client,identity=self.session();path='/api/device/challenge';raw=b'{"csr":"fixture-not-an-issuance"}'
        envelope={'id':identity,'message':encode(raw),'mic':encode(client.get_signature(path.encode()+b'\n'+raw))}
        principal,body,context=service.verify(path,envelope)
        self.assertEqual('PC01$@LAB.EXAMPLE',principal)
        self.assertEqual({'csr':'fixture-not-an-issuance'},body)
        result=service.response(path,context,{'challenge':'fixture'})
        message=base64.b64decode(result['message'])
        client.verify_signature(path.encode()+b'\n'+message,base64.b64decode(result['mic']))
        self.assertEqual({'challenge':'fixture'},json.loads(message))
        with self.assertRaises(EnrollmentError):service.verify(path,envelope) # replay

    def test_relay_cannot_replace_request_or_path(self):
        for substituted in ('message','path'):
            service,client,identity=self.session();path='/api/device/issue';raw=b'{"csr":"original"}'
            envelope={'id':identity,'message':encode(raw),'mic':encode(client.get_signature(path.encode()+b'\n'+raw))}
            if substituted=='message':envelope['message']=encode(b'{"csr":"attacker"}')
            else:path='/api/device/receipt'
            with self.assertRaises(EnrollmentError):service.verify(path,envelope)

    def test_receipt_session_end_requires_fresh_application_session(self):
        service,client,identity=self.session();path='/api/device/receipt';raw=b'{"serial":"fixture"}'
        envelope={'id':identity,'message':encode(raw),'mic':encode(client.get_signature(path.encode()+b'\n'+raw))}
        principal,body,context=service.verify(path,envelope)
        self.assertEqual('PC01$@LAB.EXAMPLE',principal)
        self.assertEqual({'serial':'fixture'},body)
        result=service.response(path,context,{'installed':True,'renew_now':True})
        message=base64.b64decode(result['message'])
        client.verify_signature(path.encode()+b'\n'+message,base64.b64decode(result['mic']))
        service.end(identity,context)
        with self.assertRaises(EnrollmentError) as error:
            service.verify('/api/device/challenge',envelope)
        self.assertEqual('DEVICE_SESSION_EXPIRED',error.exception.code)

    def test_ntlm_never_negotiates_even_with_a_valid_acceptor_keytab(self):
        service=KerberosSessions(self.root,'authwire.lab.example','lab.example')
        with self.assertRaises(EnrollmentError) as error:service.start({'token':encode(b'NTLMSSP\x00'+b'\x01\x00\x00\x00'+b'\x00'*32)})
        self.assertEqual('DEVICE_AUTH_REJECTED',error.exception.code)


    def test_real_user_kerberos_is_separate_from_machine_enrollment(self):
        ticket=self.root/'user-ticket'
        subprocess.run(['kinit','Alice@LAB.EXAMPLE'],input=b'fixture-user-only\n',
            env={**self.environment,'KRB5CCNAME':'FILE:'+str(ticket)},capture_output=True,check=True,timeout=10)
        service,client,identity=self.session(UserKerberosSessions,ticket)
        path='/api/user/challenge';raw=b'{"profile_id":"fixture","csr":"key owned by Alice"}'
        envelope={'id':identity,'message':encode(raw),'mic':encode(client.get_signature(path.encode()+b'\n'+raw))}
        principal,body,context=service.verify(path,envelope)
        self.assertEqual('Alice@LAB.EXAMPLE',principal)
        self.assertEqual('fixture',body['profile_id'])
        reply=service.response(path,context,{'user':'accepted'})
        client.verify_signature(path.encode()+b'\n'+base64.b64decode(reply['message']),base64.b64decode(reply['mic']))
        with self.assertRaises(EnrollmentError):service.verify(path,envelope)
        for cls,credential in ((KerberosSessions,ticket),(UserKerberosSessions,None)):
            with self.assertRaises(EnrollmentError) as caught:self.session(cls,credential)
            self.assertEqual('DEVICE_AUTH_REJECTED',caught.exception.code)

    def test_real_user_mic_cannot_be_transferred_between_sessions_or_paths(self):
        ticket=self.root/'user-ticket-mic'
        subprocess.run(['kinit','Alice@LAB.EXAMPLE'],input=b'fixture-user-only\n',
            env={**self.environment,'KRB5CCNAME':'FILE:'+str(ticket)},capture_output=True,check=True,timeout=10)
        for substitution in ('path','message','machine-session'):
            service,client,identity=self.session(UserKerberosSessions,ticket)
            path='/api/user/issue';raw=b'{"csr":"Alice original"}'
            envelope={'id':identity,'message':encode(raw),'mic':encode(client.get_signature(path.encode()+b'\n'+raw))}
            if substitution=='path':path='/api/user/receipt'
            elif substitution=='message':envelope['message']=encode(b'{"csr":"forged"}')
            else:service=KerberosSessions(self.root,'authwire.lab.example','lab.example')
            with self.assertRaises(EnrollmentError):service.verify(path,envelope)


    def test_real_user_session_over_https_issues_only_bound_user_certificate(self):
        import http.client
        import ssl
        import gssapi
        import threading
        from cryptography import x509
        from cryptography.hazmat.primitives import hashes
        from cryptography.hazmat.primitives.asymmetric import ec
        from kaname.device_enrollment import DeviceEnrollment
        from kaname.operations import Operations
        from kaname.pki import PKIService
        from kaname.server import DevelopmentServer
        from kaname.user_enrollment import UserEnrollment
        from tools.linux_initialize import create_web_certificate
        from tests.helpers import config
        from tests.test_directory import connection
        from tests.test_enrollment import PASSWORD,request
        from tests.test_radius_live import GROUP,live_account
        from tests.test_device_enrollment import DeviceTests
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);create_web_certificate(root,'authwire.lab.example','127.0.0.1')
            server=DevelopmentServer(root/'state',0,tls_cert=root/'web.crt',tls_key=root/'web.key',public_name='authwire.lab.example')
            server.store.save(0,config=config());ops=server.operations
            ops.save_directory(1,connection()|{'search_base':'','sync_minutes':15,'check_minutes':5,'automatic_sync':False})
            PKIService(server.store.root).initialize(PASSWORD)
            server.devices=DeviceEnrollment(ops);server.devices.unlock_signer(PASSWORD,'fixture')
            server.device_sessions=KerberosSessions(server.store.root,'authwire.lab.example','lab.example')
            server.users=UserEnrollment(server.devices,resolver=lambda *a,**kw:live_account(kind='user'))
            profile=server.users.save_profile({'id':'','version':0,'name':'Users','group_sid':GROUP,'validity_days':90,'renew_before_days':30,'enabled':True},'fixture')
            shutil.copyfile(self.root/'device-http.keytab',server.store.root/'device-http.keytab');(server.store.root/'device-http.keytab').chmod(0o600)
            thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
            try:
                context=ssl.create_default_context(cafile=str(root/'web.crt'))
                def post(path,body):
                    c=http.client.HTTPSConnection('127.0.0.1',server.server_port,context=context,timeout=10)
                    try:
                        c.request('POST',path,json.dumps(body),{'Host':f'authwire.lab.example:{server.server_port}','Content-Type':'application/json'})
                        response=c.getresponse();result=json.loads(response.read());self.assertEqual(200,response.status,result);return result
                    finally:c.close()
                ticket=root/'user-ticket'
                subprocess.run(['kinit','Alice@LAB.EXAMPLE'],input=b'fixture-user-only\n',env={**self.environment,'KRB5CCNAME':'FILE:'+str(ticket)},capture_output=True,check=True,timeout=10)
                creds=gssapi.Credentials(usage='initiate',store={'ccache':'FILE:'+str(ticket)})
                client=gssapi.SecurityContext(name=gssapi.Name('HTTP/authwire.lab.example@LAB.EXAMPLE',gssapi.NameType.kerberos_principal),creds=creds,mech=gssapi.MechType.kerberos,flags=[gssapi.RequirementFlag.mutual_authentication,gssapi.RequirementFlag.integrity,gssapi.RequirementFlag.replay_detection,gssapi.RequirementFlag.out_of_sequence_detection])
                session=post('/api/user/session',{'token':encode(client.step())});client.step(base64.b64decode(session['token']));self.assertTrue(client.complete)
                def protected(path,body):
                    raw=json.dumps(body,separators=(',',':')).encode()
                    result=post(path,{'id':session['id'],'message':encode(raw),'mic':encode(client.get_signature(path.encode()+b'\n'+raw))})
                    message=base64.b64decode(result['message']);client.verify_signature(path.encode()+b'\n'+message,base64.b64decode(result['mic']));return json.loads(message)
                key=ec.generate_private_key(ec.SECP256R1());csr=request(key).decode()
                challenge=protected('/api/user/challenge',{'profile_id':profile['id'],'csr':csr})
                def proof(payload):return encode(key.sign(base64.b64decode(payload),ec.ECDSA(hashes.SHA256())))
                result=protected('/api/user/issue',{'challenge_id':challenge['challenge_id'],'csr':csr,'proof':proof(challenge['payload'])})
                self.assertEqual('user',result['kind']);cert=x509.load_pem_x509_certificate(result['certificate'].encode());self.assertIn('AuthWire user',cert.subject.rfc4514_string())
                receipt=protected('/api/user/receipt',{'serial':result['serial'],'proof':proof(result['receipt_payload'])});self.assertTrue(receipt['installed'])
                self.assertEqual('installed',server.users.status()['users'][0]['status']);self.assertEqual([],server.devices.status()['devices'])
            finally:server.shutdown();server.server_close();thread.join(timeout=5)
