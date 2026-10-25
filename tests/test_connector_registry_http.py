"""Real trusted HTTPS and panel permissions for durable public connector pairing."""
import http.client
import json
from pathlib import Path
import shutil
import sqlite3
import ssl
import tempfile
import threading
import unittest
from unittest.mock import patch
import uuid

from kaname.connector_registry import SECTION
from kaname.server import DevelopmentServer, Handler
from . import test_connector_registry as registry_fixtures
from . import test_enrollment_http as https_fixtures


class ConnectorRegistryHTTPTests(unittest.TestCase):
    setUpClass = classmethod(registry_fixtures.ConnectorRegistryTests.setUpClass.__func__)
    tearDownClass = classmethod(registry_fixtures.ConnectorRegistryTests.tearDownClass.__func__)
    request = https_fixtures.EnrollmentHTTPTests.request
    login = https_fixtures.EnrollmentHTTPTests.login

    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        root = Path(self.temp.name); state = root/'state'; state.mkdir(mode=0o700)
        shutil.copyfile(Path(self.base.name)/'state/kaname.sqlite3', state/'kaname.sqlite3')
        self.server = DevelopmentServer(state, 0,
            tls_cert=Path(self.base.name)/'web.crt', tls_key=Path(self.base.name)/'web.key')
        self.server.daemon_threads = False
        self.context = ssl.create_default_context(cafile=str(Path(self.base.name)/'web.crt'))
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True); self.thread.start()
        self.addCleanup(self.close)
        self.headers = self.login()
        from cryptography import x509
        from cryptography.hazmat.primitives import hashes
        self.candidate = {'instance_id':self.authority['instance_id'], 'connector_id':str(uuid.uuid4()),
            'host_guid':str(uuid.uuid4()), 'host_fqdn':'dc01.lab.example',
            'service_sid':'S-1-5-21-111-222-333-1648', 'appliance_fqdn':'kaname.lab.example',
            'appliance_tls_sha256':x509.load_pem_x509_certificate(self.server.web_certificate).fingerprint(hashes.SHA256()).hex(),
            'public_key_pem':registry_fixtures.ConnectorRegistryTests.pem(self.private)}

    def close(self):
        self.server.shutdown(); self.server.server_close(); self.thread.join()

    def intent(self, operation='pair', candidate=None):
        return {'expected_revision':self.server.store.snapshot()['revision'], 'operation':operation,
            'candidate': (self.candidate if candidate is None else candidate) if operation!='revoke' else {}}

    def prepare(self, intent):
        code, p, _ = self.request('POST','/api/deployment/connector/preview',intent,self.headers)
        self.assertEqual(200,code,p)
        return intent|{'preview_hash':p['preview_hash'],
            'confirmed_key_sha256':p['after']['channel_key_sha256'] if intent['operation']!='revoke' else ''}

    def user(self, name, grants=None):
        code, system, _ = self.request('GET','/api/system',headers=self.headers); self.assertEqual(200,code)
        if grants is None:
            profile = next(p for p in system['profiles'] if p['mode']=='Admin_ReadOnly')['id']
        else:
            body = {'expected_revision':system['revision'], 'profile':{
                'id':'','name':name+'-profile','mode':'Custom','grants':grants}}
            self.assertEqual(200,self.request('POST','/api/system/profiles/save',body,self.headers)[0])
            system = self.request('GET','/api/system',headers=self.headers)[1]
            profile = next(p for p in system['profiles'] if p['name']==name+'-profile')['id']
        body = {'expected_revision':system['revision'], 'user':{'id':'','username':name,
            'password':'FixturePassword42','profile_id':profile,'enabled':True}}
        self.assertEqual(200,self.request('POST','/api/system/users/save',body,self.headers)[0])
        return self.login(name,'FixturePassword42'), profile

    def test_pair_rotate_revoke_over_real_verified_https_without_runtime_apply(self):
        before = self.server.store.snapshot()
        code, status, _ = self.request('GET','/api/deployment/connector',headers=self.headers)
        self.assertEqual(200,code); self.assertFalse(status['paired'])
        for operation, candidate, generation in [('pair',self.candidate,1),
                ('rotate',self.candidate|{'public_key_pem':registry_fixtures.ConnectorRegistryTests.pem(self.other)},2),
                ('revoke',{},3)]:
            value = self.prepare(self.intent(operation,candidate))
            code, result, _ = self.request('POST','/api/deployment/connector/apply',value,self.headers)
            self.assertEqual(200,code,result); self.assertEqual(generation,result['binding']['generation'])
            self.assertFalse(result['runtime_applied']); self.assertFalse(result['gpo_changed'])
        status = self.request('GET','/api/deployment/connector',headers=self.headers)[1]
        self.assertFalse(status['paired']); self.assertFalse(status['can_apply'])
        self.assertFalse(status['transport_active']); self.assertNotIn('public_key_pem',status['binding'])
        self.assertEqual(before['config'],self.server.store.snapshot()['config'])
        self.assertEqual(before['policies'],self.server.store.snapshot()['policies'])

    def test_unauthorized_csrf_origin_host_maintenance_and_readonly_boundaries(self):
        value = self.prepare(self.intent())
        self.assertEqual(401,self.request('GET','/api/deployment/connector')[0])
        self.assertEqual(401,self.request('POST','/api/deployment/connector/apply',value)[0])
        for change in ({'X-Kaname-CSRF':'bad'}, {'Origin':'https://evil.example'},
                       {'Origin':''}, {'Host':'evil.example'}):
            self.assertEqual(403,self.request('POST','/api/deployment/connector/apply',value,self.headers|change)[0])
        reader,_ = self.user('reader')
        self.assertEqual(200,self.request('GET','/api/deployment/connector',headers=reader)[0])
        for path in ('preview','apply'):
            self.assertEqual(403,self.request('POST','/api/deployment/connector/'+path,value,reader)[0])
        maintenance = {'Authorization':'Bearer '+self.server.token}
        self.assertEqual(200,self.request('GET','/api/deployment/connector',headers=maintenance)[0])
        code, result, _ = self.request('POST','/api/deployment/connector/apply',value,maintenance)
        self.assertEqual((403,'CONNECTOR_PANEL_SESSION_REQUIRED'),(code,result['error']))
        self.assertFalse(self.request('GET','/api/deployment/connector',headers=self.headers)[1]['paired'])

    def test_new_permission_is_not_inherited_from_certificate_or_directory_write(self):
        limited,_ = self.user('limited',{'certificates.authority':'write','directory.connection':'write'})
        self.assertEqual(403,self.request('GET','/api/deployment/connector',headers=limited)[0])
        self.assertEqual(403,self.request('POST','/api/deployment/connector/preview',self.intent(),limited)[0])
        connector,_ = self.user('connector',{'system.connectors':'write'})
        code, result, _ = self.request('POST','/api/deployment/connector/preview',self.intent(),connector)
        self.assertEqual(200,code,result)
        self.assertEqual(403,self.request('GET','/api/directory/settings',headers=connector)[0])

    def test_permissions_rechecked_after_body_read_before_trust_commit(self):
        connector,profile = self.user('connector',{'system.connectors':'write'})
        value = self.prepare(self.intent()); before = self.server.store.snapshot()
        original = Handler.read_body
        def demote(handler):
            result = original(handler)
            with self.server.admin.connect() as db:
                db.execute('UPDATE admin_profiles SET grants=? WHERE id=?', ('{}',profile))
            return result
        with patch.object(Handler,'read_body',demote):
            self.assertEqual(403,self.request('POST','/api/deployment/connector/apply',value,connector)[0])
        self.assertEqual(before,self.server.store.snapshot())

    def test_lost_reply_reconciles_from_status_without_second_trust_write(self):
        value = self.prepare(self.intent())
        self.assertEqual(200,self.request('POST','/api/deployment/connector/apply',value,self.headers)[0])
        self.assertEqual(409,self.request('POST','/api/deployment/connector/apply',value,self.headers)[0])
        status = self.request('GET','/api/deployment/connector',headers=self.headers)[1]
        self.assertEqual(value['candidate']['connector_id'],status['binding']['connector_id'])
        self.assertEqual(value['confirmed_key_sha256'],status['binding']['channel_key_sha256'])
        self.assertEqual(1,status['generation'])
        self.assertEqual(1,sum(x['event'].startswith('windows_connector_pair:') for x in self.server.store.audit()))

    def test_queries_unknown_fields_and_peer_self_registration_are_rejected(self):
        before = self.server.store.snapshot()
        for suffix in ('?x=1','?q=x&q=y','?'):
            code = self.request('GET','/api/deployment/connector'+suffix,headers=self.headers)[0]
            self.assertEqual(400,code)
        for change in ({'command':'powershell.exe'},{'candidate':self.candidate|{'password':'never-accepted'}},
                       {'candidate':self.candidate|{'generation':1}}):
            self.assertEqual(400,self.request('POST','/api/deployment/connector/preview',self.intent()|change,self.headers)[0])
        for path in ('/api/connector/v1/health','/api/connector/v1/challenge','/api/deployment/connector/register'):
            self.assertEqual(404,self.request('POST',path,{},self.headers)[0])
        self.assertEqual(before,self.server.store.snapshot())

    def test_duplicate_json_and_private_key_are_not_echoed_or_saved(self):
        raw = b'{"expected_revision":1,"operation":"pair","operation":"revoke","candidate":{}}'
        conn = http.client.HTTPSConnection('127.0.0.1',self.server.server_port,context=self.context,timeout=8)
        try:
            conn.request('POST','/api/deployment/connector/preview',raw,{
                'Content-Type':'application/json','Origin':f'https://127.0.0.1:{self.server.server_port}',**self.headers})
            response=conn.getresponse();self.assertEqual(400,response.status);response.read()
        finally: conn.close()
        from cryptography.hazmat.primitives import serialization
        private=self.private.private_bytes(serialization.Encoding.PEM,
            serialization.PrivateFormat.PKCS8,serialization.NoEncryption()).decode()
        intent=self.intent(candidate=self.candidate|{'public_key_pem':private})
        code,result,_=self.request('POST','/api/deployment/connector/preview',intent,self.headers)
        self.assertEqual(400,code);self.assertNotIn('PRIVATE KEY',json.dumps(result))
        self.assertFalse(self.request('GET','/api/deployment/connector',headers=self.headers)[1]['paired'])

    def test_corruption_and_busy_have_safe_distinct_errors(self):
        error=sqlite3.OperationalError('DO_NOT_LOG_CONNECTION_SENTINEL');error.sqlite_errorcode=sqlite3.SQLITE_BUSY
        with patch.object(self.server.store,'connect',side_effect=error):
            with self.assertLogs('authwire.panel',level='WARNING') as logs:
                code,result,_=self.request('GET','/api/deployment/connector',headers=self.headers)
        self.assertEqual((503,'STORE_BUSY'),(code,result['error']))
        self.assertNotIn('DO_NOT_LOG_CONNECTION_SENTINEL',''.join(logs.output))
        with self.server.store.connect() as db:
            db.execute('INSERT INTO runtime_settings VALUES (?,?)',(SECTION,'{"private":"not-a-binding"}'))
        code,result,_=self.request('GET','/api/deployment/connector',headers=self.headers)
        self.assertEqual((503,'CONNECTOR_STORE_INVALID'),(code,result['error']))
        self.assertNotIn('private',json.dumps(result))

    def test_tls_gate_and_plain_http_never_accept_pairing(self):
        with patch.object(self.server,'tls',False):
            code,result,_=self.request('GET','/api/deployment/connector',headers=self.headers)
            self.assertEqual((403,'CONNECTOR_HTTPS_REQUIRED'),(code,result['error']))
        plain=DevelopmentServer(Path(self.temp.name)/'plain',0)
        thread=threading.Thread(target=plain.serve_forever,daemon=True);thread.start()
        try:
            conn=http.client.HTTPConnection('127.0.0.1',plain.server_port,timeout=8)
            try:
                conn.request('GET','/api/deployment/connector',headers={'Authorization':'Bearer '+plain.token})
                response=conn.getresponse();body=json.loads(response.read())
                self.assertEqual((403,'CONNECTOR_HTTPS_REQUIRED'),(response.status,body['error']))
            finally: conn.close()
        finally: plain.shutdown();plain.server_close();thread.join()


if __name__ == '__main__': unittest.main()
