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

from kaname.device_auth import KerberosSessions, encode
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

    def session(self):
        import gssapi
        service=KerberosSessions(self.root,'authwire.lab.example','lab.example')
        flags=[gssapi.RequirementFlag.mutual_authentication,gssapi.RequirementFlag.integrity,
            gssapi.RequirementFlag.replay_detection,gssapi.RequirementFlag.out_of_sequence_detection]
        creds=gssapi.Credentials(usage='initiate',store={'ccache':'FILE:'+str(self.root/'ticket')})
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
