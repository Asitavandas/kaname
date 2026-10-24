import json
import types
import unittest
import uuid
from dataclasses import asdict
from unittest.mock import patch
from kaname.directory import DirectoryError
from kaname.directory_linux import read_linux_directory
from kaname.directory_linux_helper import Reader
from .helpers import config
from .test_directory import connection
from .test_radius_live import GUID, live_account


class UserDirectoryTests(unittest.TestCase):
    def test_connector_resolves_exact_verified_user_without_password_authentication(self):
        seen={}
        account=asdict(live_account(kind='user'));account['security_group_sids']=sorted(account['security_group_sids'])
        def communicate(raw,timeout):
            seen.update(json.loads(raw))
            return json.dumps({'domain':'lab.example','dc_fqdn':'dc01.lab.example','account':account}).encode(),None
        proc=types.SimpleNamespace(returncode=0,communicate=communicate)
        with patch('kaname.directory_linux.socket.getaddrinfo',return_value=[(0,0,0,'',('192.0.2.10',389))]),patch('kaname.directory_linux.subprocess.Popen',return_value=proc):
            result=read_linux_directory(connection(),config(),user_sam='Alice')
        self.assertEqual('user',result.kind);self.assertEqual('Alice',seen['user_sam']);self.assertNotIn('authenticate_self',seen)
        self.assertEqual(connection()['username'],seen['username'])

    def test_user_sam_cannot_select_machine_or_inject_ldap_or_mix_lookup_modes(self):
        for value in ('PC01$','Alice@LAB.EXAMPLE','x)(objectClass=*)','HTTP/server',None,123):
            if value is None:continue
            with self.assertRaises(DirectoryError):read_linux_directory(connection(),config(),user_sam=value)
        for extras in ({'computer_sam':'PC01$'},{'authenticate_self':True},{'object_guid':GUID},{'probe':True}):
            with self.assertRaises(DirectoryError):read_linux_directory(connection(),config(),user_sam='Alice',**extras)

    def test_live_reader_binds_unique_domain_guid_and_user_kind(self):
        reader=Reader(None,types.SimpleNamespace(SCOPE_SUBTREE=2),None)
        dn='CN=Alice,DC=lab,DC=example';attrs={'objectguid':[uuid.UUID(GUID).bytes_le],'samaccountname':[b'Alice']}
        calls=[]
        reader.search=lambda *args:(calls.append(args) or ([(dn,attrs)],[]))
        account=asdict(live_account(kind='user'));reader.account=lambda *args:account
        self.assertEqual(account,reader.kerberos_user('lab.example','Alice'))
        self.assertIn('(!(objectClass=computer))',calls[0][2]);self.assertIn('(sAMAccountName=Alice)',calls[0][2])
        account['kind']='computer'
        with self.assertRaises(DirectoryError):reader.kerberos_user('lab.example','Alice')
        account['kind']='user';reader.search=lambda *args:([(dn,attrs),(dn,attrs)],[])
        with self.assertRaises(DirectoryError):reader.kerberos_user('lab.example','Alice')
