import base64
import http.client
import json
import secrets
import time
import unittest
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import padding
from kaname.connector_channel import public_key_id
from . import test_connector_registry_http as fixtures

class ConnectorTransportTests(unittest.TestCase):
    setUpClass=classmethod(fixtures.ConnectorRegistryHTTPTests.setUpClass.__func__)
    tearDownClass=classmethod(fixtures.ConnectorRegistryHTTPTests.tearDownClass.__func__)
    setUp=fixtures.ConnectorRegistryHTTPTests.setUp
    close=fixtures.ConnectorRegistryHTTPTests.close
    request=fixtures.ConnectorRegistryHTTPTests.request
    login=fixtures.ConnectorRegistryHTTPTests.login
    intent=fixtures.ConnectorRegistryHTTPTests.intent
    prepare=fixtures.ConnectorRegistryHTTPTests.prepare

    def pair(self):
        value=self.prepare(self.intent())
        self.assertEqual(200,self.request('POST','/api/deployment/connector/apply',value,self.headers)[0])

    def poll(self, *, field=None, wrong_key=False, nonce=None):
        c=self.candidate;now=int(time.time())
        fields=['AUTHWIRE-CONNECTOR-POLL-V1',c['instance_id'],c['connector_id'],'1',c['host_guid'],c['host_fqdn'],c['service_sid'],c['appliance_fqdn'],c['appliance_tls_sha256'],public_key_id(self.private.public_key()),nonce or secrets.token_hex(32),secrets.token_hex(32),str(now),str(now+60),'POST','/api/connector/v1/challenge','']
        if field is not None:fields[field]+='x'
        frame='\n'.join(fields).encode();key=self.other if wrong_key else self.private
        return {'frame':base64.b64encode(frame).decode(),'signature':base64.b64encode(key.sign(frame,padding.PKCS1v15(),hashes.SHA256())).decode()}

    def peer(self,path,value,headers=None):
        conn=http.client.HTTPSConnection('127.0.0.1',self.server.server_port,context=self.context,timeout=8)
        try:
            body=value if isinstance(value,bytes) else json.dumps(value).encode()
            conn.request('POST',path,body,{'Content-Type':'application/json',**(headers or {})})
            r=conn.getresponse();return r.status,json.loads(r.read())
        finally:conn.close()

    def health(self,reply):
        frame=base64.b64decode(reply['frame'])
        return {'challenge_id':frame.decode().split('\n')[10],'signature':base64.b64encode(self.private.sign(frame,padding.PKCS1v15(),hashes.SHA256())).decode()}

    def test_real_https_signed_poll_then_fresh_health_has_no_ad_or_gpo_authority(self):
        self.pair();before=self.server.store.snapshot();audit=self.server.store.audit()
        code,reply=self.peer('/api/connector/v1/challenge',self.poll());self.assertEqual(200,code)
        self.assertFalse(self.server.connector_pairing.status()['online'])
        code,result=self.peer('/api/connector/v1/health',self.health(reply));self.assertEqual(200,code)
        self.assertTrue(result['channel_proof_verified'])
        self.assertTrue(self.server.connector_pairing.status()['transport_active'])
        for k in ('can_apply','directory_sync_ready','kerberos_ready'):self.assertFalse(result[k])
        self.assertEqual(before,self.server.store.snapshot());self.assertEqual(audit,self.server.store.audit())

    def test_unsigned_foreign_wrong_scope_poll_and_replays_rejected(self):
        self.pair()
        for value in ({},self.poll(wrong_key=True),self.poll(field=1),self.poll(field=3),self.poll(field=8),self.poll(field=14),self.poll(field=15)):
            code,result=self.peer('/api/connector/v1/challenge',value)
            self.assertEqual((403,{'error':'CONNECTOR_REQUEST_REJECTED'}),(code,result))
        value=self.poll();code,reply=self.peer('/api/connector/v1/challenge',value);self.assertEqual(200,code)
        self.assertEqual(403,self.peer('/api/connector/v1/challenge',value)[0])
        health=self.health(reply);self.assertEqual(200,self.peer('/api/connector/v1/health',health)[0])
        self.assertEqual(403,self.peer('/api/connector/v1/health',health)[0])

    def test_browser_headers_do_not_substitute_for_key_or_consume_good_proof(self):
        self.pair();poll=self.poll()
        for headers in ({'Origin':''},{'Cookie':''},{'Authorization':'Bearer '+self.server.token},self.headers,{'Host':'evil.example'}):
            self.assertEqual(403,self.peer('/api/connector/v1/challenge',poll,headers)[0])
        code,reply=self.peer('/api/connector/v1/challenge',poll);self.assertEqual(200,code)
        proof=self.health(reply)
        self.assertEqual(403,self.peer('/api/connector/v1/health',proof,{'Cookie':'bad'})[0])
        self.assertEqual(200,self.peer('/api/connector/v1/health',proof)[0])

    def test_oversized_duplicate_json_and_capacity_limits_fail_closed(self):
        self.pair()
        for raw in (b'x'*4097,b'{"frame":"a","frame":"b","signature":"x"}',json.dumps(self.poll()).encode('utf-16')):
            self.assertEqual(403,self.peer('/api/connector/v1/challenge',raw)[0])
        self.server.connector_peer_rates={'127.0.0.1':(time.monotonic(),30)}
        self.assertEqual(429,self.peer('/api/connector/v1/challenge',self.poll())[0])
        self.assertFalse(self.server.connector_pairing.status()['online'])

    def test_revoked_or_unpaired_peer_gets_no_trust_metadata(self):
        self.assertEqual((403,{'error':'CONNECTOR_REQUEST_REJECTED'}),self.peer('/api/connector/v1/challenge',self.poll()))
        self.pair();code,reply=self.peer('/api/connector/v1/challenge',self.poll());self.assertEqual(200,code)
        revoke=self.prepare(self.intent('revoke'))
        self.assertEqual(200,self.request('POST','/api/deployment/connector/apply',revoke,self.headers)[0])
        self.assertEqual((403,{'error':'CONNECTOR_REQUEST_REJECTED'}),self.peer('/api/connector/v1/health',self.health(reply)))

if __name__=='__main__':unittest.main()
