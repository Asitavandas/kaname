"""User deployment package trust/scope boundaries; actual native client runs in Windows CI."""
import hashlib
import io
import json
import re
import unittest
import zipfile
from pathlib import Path
from . import test_user_enrollment as fixtures
from tools.linux_initialize import create_web_certificate


class UserPackageTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):fixtures.UserEnrollmentTests.setUpClass.__func__(cls)
    @classmethod
    def tearDownClass(cls):cls.base.cleanup()
    def setUp(self):
        fixtures.UserEnrollmentTests.setUp(self)
        create_web_certificate(Path(self.temp.name),'authwire.lab.example','127.0.0.1')
    def package(self,**changes):
        args={'hostname':'authwire.lab.example','port':8765,'tls_pem':(Path(self.temp.name)/'web.crt').read_bytes()}
        return self.users.package(self.profile['id'],**(args|changes))
    def contents(self):
        with zipfile.ZipFile(io.BytesIO(self.package())) as z:return {n:z.read(n) for n in z.namelist()}
    def test_only_public_trust_user_scripts_and_user_config_are_packaged(self):
        files=self.contents()
        self.assertEqual({'root-ca.pem','issuer-ca.pem','https-trust.pem','config.json','AuthWire-User-Client.ps1','Install-AuthWire-User.ps1','README.txt','SHA256SUMS.txt'},set(files))
        config=json.loads(files['config.json']);self.assertEqual('user',config['kind']);self.assertEqual(self.profile['id'],config['profile_id'])
        self.assertEqual('https://authwire.lab.example:8765',config['url']);self.assertEqual('HTTP/authwire.lab.example',config['spn'])
        self.assertNotIn(b'PRIVATE KEY',b''.join(files.values()));self.assertNotIn('AuthWire-Client.ps1',files)
    def test_both_signed_script_bodies_bind_exact_config_and_ca_asset_hashes(self):
        files=self.contents();assets={n:hashlib.sha256(d).hexdigest() for n,d in files.items() if n.endswith('.pem') or n=='config.json'}
        for name in ('AuthWire-User-Client.ps1','Install-AuthWire-User.ps1'):
            source=files[name].decode();self.assertNotIn('__AUTHWIRE_USER_ASSET_HASHES__',source)
            match=re.search(r"\$expected=@'\n(.+?)\n'@",source,re.S);self.assertIsNotNone(match)
            self.assertEqual(assets,json.loads(match[1]))
        sums=files['SHA256SUMS.txt'].decode()
        for name,data in files.items():
            if name!='SHA256SUMS.txt':self.assertIn(hashlib.sha256(data).hexdigest()+'  '+name,sums)
    def test_user_key_store_task_and_transport_do_not_fall_back_to_machine_identity(self):
        files=self.contents();client=files['AuthWire-User-Client.ps1'].decode();installer=files['Install-AuthWire-User.ps1'].decode()
        self.assertIn('MachineKeySet=FALSE',client);self.assertIn("@('-new','-user'",client);self.assertIn("@('-accept','-user'",client)
        self.assertNotIn('Cert:\\LocalMachine',client);self.assertNotIn('::MachineKey)',client);self.assertIn('::None)',client)
        self.assertIn('<LogonType>InteractiveToken</LogonType>',installer);self.assertIn('<RunLevel>LeastPrivilege</RunLevel>',installer)
        self.assertIn('<Interval>PT5M</Interval>',installer);self.assertIn('ExecutionPolicy AllSigned',installer);self.assertNotIn('Bypass',installer)
        self.assertNotIn('/api/device/',client);self.assertIn('/api/user/session',client)
    def test_mismatched_name_port_or_profile_is_rejected_before_download(self):
        for changes in ({'hostname':'other.lab.example'},{'hostname':'127.0.0.1'},{'port':0},{'port':True}):
            with self.assertRaises(ValueError):self.package(**changes)
        with self.assertRaises(ValueError):self.users.package('invalid',hostname='authwire.lab.example',port=8765,tls_pem=b'bad')
    def test_export_does_not_seed_profiles_enable_issuer_or_issue_user_certificate(self):
        before=self.users.store.snapshot();profiles=self.users.status()['profiles'];self.package()
        self.assertEqual(before,self.users.store.snapshot());self.assertEqual(profiles,self.users.status()['profiles']);self.assertEqual(0,self.users.status()['total'])
