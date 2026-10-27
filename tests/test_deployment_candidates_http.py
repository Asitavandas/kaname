"""Verified HTTPS, both current privileges, CSRF and operator-only receipt state."""
import copy
import json
import unittest
import uuid
from unittest.mock import patch
from kaname.server import Handler
from . import test_connector_registry_http as hf
from .test_deployment_candidates import fixture_snapshot,make_receipt


class CandidateHTTPTests(unittest.TestCase):
    setUpClass=classmethod(hf.ConnectorRegistryHTTPTests.setUpClass.__func__)
    tearDownClass=classmethod(hf.ConnectorRegistryHTTPTests.tearDownClass.__func__)
    request=hf.ConnectorRegistryHTTPTests.request
    login=hf.ConnectorRegistryHTTPTests.login
    close=hf.ConnectorRegistryHTTPTests.close
    intent=hf.ConnectorRegistryHTTPTests.intent
    prepare=hf.ConnectorRegistryHTTPTests.prepare
    user=hf.ConnectorRegistryHTTPTests.user

    def setUp(self):
        hf.ConnectorRegistryHTTPTests.setUp(self)
        self.assertEqual(200,self.request('POST','/api/deployment/connector/apply',self.prepare(self.intent()),self.headers)[0])
        self.data=fixture_snapshot()
        for method,fn in [('_snapshot',lambda db:copy.deepcopy(self.data)),
                          ('_targets',lambda *a:{'available':True,'enabled':2,'unresolved':0}),
                          ('_trust',lambda *a:{'ready':True,'root_thumbprint':'c'*40})]:
            p=patch.object(self.server.deployment,method,side_effect=fn);p.start();self.addCleanup(p.stop)

    def body(self):
        return {'expected_revision':self.server.store.snapshot()['revision'],'registration_id':str(uuid.uuid4()),
                'receipt_json':json.dumps(make_receipt(self.data['plans'][0]))}

    def test_roundtrip_records_only_operator_report_no_peer_or_gpo_authority(self):
        before=self.server.store.snapshot();v=self.body()
        c,p,_=self.request('POST','/api/deployment/candidates/preview',v,self.headers);self.assertEqual(200,c,p)
        body=v|{'preview_hash':p['preview_hash']}
        for _ in range(2):self.assertEqual(200,self.request('POST','/api/deployment/candidates/record',body,self.headers)[0])
        c,s,_=self.request('GET','/api/deployment/candidates',headers=self.headers);self.assertEqual(200,c,s)
        self.assertEqual(1,len(s['candidates']));self.assertEqual('operator_reported',s['candidates'][0]['state'])
        self.assertFalse(s['candidates'][0]['connector_verified']);self.assertFalse(s['can_apply'])
        self.assertEqual(before['config'],self.server.store.snapshot()['config'])
        self.assertEqual(before['policies'],self.server.store.snapshot()['policies'])
        for path in ('/api/deployment/candidates/apply','/api/deployment/candidates/execute'):
            self.assertEqual(404,self.request('POST',path,{},self.headers)[0])

    def test_both_write_grants_required_and_read_only_cannot_preview(self):
        for grants in ({'certificates.authority':'write'},{'system.connectors':'write'},
                       {'certificates.authority':'read','system.connectors':'read'}):
            headers,_=self.user('candidate-'+str(uuid.uuid4())[:8],grants)
            self.assertEqual(403,self.request('POST','/api/deployment/candidates/preview',self.body(),headers)[0])
        self.assertEqual(401,self.request('GET','/api/deployment/candidates')[0])

    def test_stale_demotion_after_body_read_is_rechecked_inside_admin_lease(self):
        headers,profile=self.user('candidate-operator',{'certificates.authority':'write','system.connectors':'write'})
        v=self.body();c,p,_=self.request('POST','/api/deployment/candidates/preview',v,headers);self.assertEqual(200,c,p)
        original=Handler.read_body
        def demote(handler):
            v=original(handler)
            with self.server.admin.connect() as db:db.execute('UPDATE admin_profiles SET grants=? WHERE id=?',('{"certificates.authority":"write"}',profile))
            return v
        with patch.object(Handler,'read_body',demote):
            self.assertEqual(403,self.request('POST','/api/deployment/candidates/record',v|{'preview_hash':p['preview_hash']},headers)[0])
        self.assertEqual([],self.request('GET','/api/deployment/candidates',headers=self.headers)[1]['candidates'])

    def test_csrf_origin_host_maintenance_and_unknown_fields_refused(self):
        for headers in (self.headers|{'X-Kaname-CSRF':'bad'},self.headers|{'Origin':'https://evil.example'},
                        self.headers|{'Host':'evil.example'},{'Authorization':'Bearer '+self.server.token}):
            self.assertEqual(403,self.request('POST','/api/deployment/candidates/preview',self.body(),headers)[0])
        self.assertEqual(400,self.request('GET','/api/deployment/candidates?x=1',headers=self.headers)[0])
        self.assertEqual(400,self.request('POST','/api/deployment/candidates/preview',self.body()|{'command':'whoami'},self.headers)[0])


if __name__=='__main__':unittest.main()
