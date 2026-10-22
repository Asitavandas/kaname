import hashlib
import http.client
import json
import secrets
import tempfile
import threading
import unittest
from dataclasses import asdict
from pathlib import Path
from kaname.server import DevelopmentServer
from .helpers import config, policy, identity


class HTTPTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp=tempfile.TemporaryDirectory();cls.token=secrets.token_hex(32)
        cls.server=DevelopmentServer(cls.temp.name,0,token=cls.token)
        cls.thread=threading.Thread(target=cls.server.serve_forever,daemon=True);cls.thread.start()

    @classmethod
    def tearDownClass(cls):
        cls.server.shutdown();cls.server.server_close();cls.thread.join();cls.temp.cleanup()

    def request(self, method, path, body=None, *, token=True, origin=True, headers=None):
        data=json.dumps(body) if body is not None else None
        h={'Content-Type':'application/json'}
        if token:h['Authorization']='Bearer '+self.token
        if origin:h['Origin']=f'http://127.0.0.1:{self.server.server_port}'
        h.update(headers or {})
        connection=http.client.HTTPConnection('127.0.0.1',self.server.server_port,timeout=3)
        self.addCleanup(connection.close)
        connection.request(method,path,body=data,headers=h)
        r=connection.getresponse();return r.status,r.read(),dict(r.headers)

    def test_health_is_not_readiness(self):
        status,body,_=self.request('GET','/healthz',token=False)
        self.assertEqual(status,200)
        health=json.loads(body)
        client=Path(__file__).parents[1]/'kaname'/'device_client'/'AuthWire-Client.ps1'
        self.assertEqual(hashlib.sha256(client.read_bytes()).hexdigest(),health['device_client_sha256'])
        status,body,_=self.request('GET','/readyz',token=False)
        self.assertEqual(status,503);self.assertFalse(json.loads(body)['ready'])

    def test_state_requires_token(self):
        self.assertEqual(self.request('GET','/api/state',token=False)[0],401)

    def test_bad_token_rejected(self):
        self.assertEqual(self.request('GET','/api/state',headers={'Authorization':'Bearer invalid'})[0],401)

    def test_dns_rebinding_host_rejected(self):
        self.assertEqual(self.request('GET','/api/state',headers={'Host':'attacker.example'})[0],403)

    def test_cross_origin_rejected(self):
        self.assertEqual(self.request('POST','/api/config',{},headers={'Origin':'https://attacker.example'})[0],403)

    def test_write_requires_origin(self):
        self.assertEqual(self.request('POST','/api/config',{},origin=False)[0],403)

    def test_no_cors_allow_header(self):
        self.assertNotIn('Access-Control-Allow-Origin',self.request('GET','/api/state')[2])

    def test_csp_disables_external_scripts(self):
        headers=self.request('GET','/')[2]
        self.assertIn("script-src 'self'",headers['Content-Security-Policy'])

    def test_saved_config_is_not_applied(self):
        revision=json.loads(self.request('GET','/api/state')[1])['revision']
        status,body,_=self.request('POST','/api/config',{'expected_revision':revision,'config':config()})
        self.assertEqual(status,200);self.assertFalse(json.loads(body)['runtime_applied'])

    def test_secret_field_rejected_and_not_logged(self):
        c=config();c['password']='example-do-not-store'
        status,_,_=self.request('POST','/api/config',{'expected_revision':0,'config':c})
        self.assertEqual(status,400)
        self.assertNotIn(b'example-do-not-store',self.request('GET','/api/audit')[1])

    def test_oversized_body_rejected(self):
        self.assertEqual(self.request('POST','/api/config',{'x':'x'*262144})[0],413)

    def test_simulation_is_inert(self):
        revision=json.loads(self.request('GET','/api/state')[1])['revision']
        self.assertEqual(self.request('POST','/api/policies',{'expected_revision':revision,'policies':[policy()]})[0],200)
        data=asdict(identity());data.pop('account_sid');data['group_sids']=list(data['group_sids'])
        status,body,_=self.request('POST','/api/simulate',data)
        self.assertEqual(status,200);value=json.loads(body)
        self.assertTrue(value['simulation_only']);self.assertFalse(value['network_enforced'])

    def test_simulation_cannot_supply_trusted_account_sid(self):
        data=asdict(identity());data['group_sids']=list(data['group_sids'])
        self.assertEqual(self.request('POST','/api/simulate',data)[0],400)

    def test_static_traversal_is_not_served(self):
        self.assertEqual(self.request('GET','/../access-token')[0],404)

    def test_runtime_capabilities_are_pending(self):
        value=json.loads(self.request('GET','/api/state')[1])
        self.assertFalse(value['runtime_ready']);self.assertEqual(value['integrations']['radius'],'pending')

    def test_pki_status_does_not_create_ca(self):
        value=json.loads(self.request('GET','/api/state')[1])
        self.assertFalse(value['pki_public']['initialized'])
        self.assertFalse(value['pki_public']['client_enrollment_enabled'])
        self.assertNotIn(b'PRIVATE KEY',self.request('GET','/api/state')[1])
