"""Real HTTPS peer proofs and both current admin privileges."""
import time
import uuid
from unittest.mock import patch
from kaname.combined_jobs import CombinedJobs,OPERATION,POLL_PATH,RESULT_PATH
from kaname.deployment_candidates import DeploymentCandidates
from kaname.server import Handler
from . import test_deployment_candidates_http as cf
from . import test_connector_jobs_http as jf
from . import test_combined_jobs as pf
from .test_combined_candidate_registration import combined_receipt
import json


class CombinedJobHTTPTests(cf.CandidateHTTPTests):
    peer=jf.ConnectorJobHTTPTests.peer
    binding=pf.CombinedJobTests.binding
    proof=pf.CombinedJobTests.proof
    result=pf.CombinedJobTests.result

    def setUp(self):
        super().setUp();self.now=int(time.time());self.store=self.server.store
        self.jobs=CombinedJobs(DeploymentCandidates(self.server.connector_pairing,self.server.deployment))

    def new_candidate(self):
        v=self.body();c,p,_=self.request('POST','/api/deployment/candidates/preview',v,self.headers)
        self.assertEqual(200,c,p)
        self.assertEqual(200,self.request('POST','/api/deployment/candidates/record',v|{'preview_hash':p['preview_hash']},self.headers)[0])
        return v['registration_id']

    def job_request(self):
        self.new_candidate()
        v=self.body()|{'receipt_json':json.dumps(combined_receipt(self.data['plans'][0]))}
        code,p,_=self.request('POST','/api/deployment/candidates/preview',v,self.headers)
        self.assertEqual(200,code,p)
        code,r,_=self.request('POST','/api/deployment/candidates/record',v|{'preview_hash':p['preview_hash']},self.headers)
        self.assertEqual(200,code,r)
        identity=v['registration_id']
        return {'expected_revision':self.server.store.snapshot()['revision'],'candidate_id':identity,
                'job_id':str(uuid.uuid4()),'operation':OPERATION}

    def test_actual_https_peer_roundtrip_does_not_enable_gpo(self):
        c,r=self.peer(POLL_PATH,self.proof());self.assertEqual(200,c,r)
        v=self.job_request();v['expected_revision']=self.server.store.snapshot()['revision']
        c,p,_=self.request('POST','/api/deployment/candidates/combined/preview',v,self.headers);self.assertEqual(200,c,p)
        b=v|{'preview_hash':p['preview_hash']}
        for _ in range(2):self.assertEqual(200,self.request('POST','/api/deployment/candidates/combined/create',b,self.headers)[0])
        c,o=self.peer(POLL_PATH,self.proof());self.assertEqual(200,c,o)
        raw=self.proof('RESULT',self.result(o))
        for _ in range(2):self.assertEqual(200,self.peer(RESULT_PATH,raw)[0])
        c,s,_=self.request('GET','/api/deployment/candidates',headers=self.headers);self.assertEqual(200,c,s)
        self.assertTrue(s['candidates'][0]['content_verified']);self.assertFalse(s['candidates'][0]['connector_verified'])
        self.assertFalse(s['can_apply'])

    def test_both_live_permissions_csrf_and_interactive_session_required(self):
        v=self.job_request()
        for grants in ({'certificates.authority':'write'},{'system.connectors':'write'},
                       {'certificates.authority':'read','system.connectors':'read'}):
            h,_=self.user('verify-'+uuid.uuid4().hex[:8],grants)
            self.assertEqual(403,self.request('POST','/api/deployment/candidates/combined/preview',v,h)[0])
        for h in (self.headers|{'X-Kaname-CSRF':'bad'},{'Authorization':'Bearer '+self.server.token}):
            self.assertEqual(403,self.request('POST','/api/deployment/candidates/combined/preview',v,h)[0])

    def test_peer_rejects_cookies_browser_origin_and_cross_purpose(self):
        for headers in ({'Cookie':'session=x'},{'Origin':'https://evil.example'},{'Authorization':'Bearer x'}):
            self.assertEqual(403,self.peer(POLL_PATH,self.proof(),headers)[0])
        self.assertEqual(403,self.peer('/api/connector/v1/jobs/poll',self.proof())[0])

    def test_demotion_between_body_and_write_is_rechecked(self):
        v=self.job_request();h,profile=self.user('verify-operator',{'certificates.authority':'write','system.connectors':'write'})
        self.peer(POLL_PATH,self.proof())
        c,p,_=self.request('POST','/api/deployment/candidates/combined/preview',v,h);self.assertEqual(200,c,p)
        original=Handler.read_body
        def demote(handler):
            result=original(handler)
            with self.server.admin.connect() as db:db.execute('UPDATE admin_profiles SET grants=? WHERE id=?',('{"certificates.authority":"write"}',profile))
            return result
        with patch.object(Handler,'read_body',demote):
            self.assertEqual(403,self.request('POST','/api/deployment/candidates/combined/create',v|{'preview_hash':p['preview_hash']},h)[0])

    def test_combined_routes_have_no_apply_or_execute_authority(self):
        for path in ('/api/deployment/candidates/combined/apply','/api/deployment/candidates/combined/execute'):
            self.assertEqual(404,self.request('POST',path,{},self.headers)[0])
        from .test_candidate_jobs import CandidateJobTests
        for path in (POLL_PATH,RESULT_PATH):
            self.assertEqual(403,self.peer(path,CandidateJobTests.proof(self))[0])
