"""Actual HTTPS framing and current admin leases for the scope queue."""
import time
import uuid
from unittest.mock import patch

from kaname.combined_jobs import CombinedJobs
from kaname.deployment_candidates import DeploymentCandidates
from kaname.combined_scope_jobs import CombinedScopeJobs, OPERATION, POLL_PATH, RESULT_PATH
from kaname.server import Handler
from . import test_deployment_candidates_http as cf
from . import test_connector_jobs_http as jf
from . import test_combined_jobs as content_fixtures
from . import test_combined_scope_jobs as sf
from .test_scope_jobs import scope_catalog
from .test_combined_candidate_registration import combined_receipt
import json


class CombinedScopeJobHTTPTests(cf.CandidateHTTPTests):
    peer=jf.ConnectorJobHTTPTests.peer
    binding=sf.CombinedScopeJobTests.binding
    proof=sf.CombinedScopeJobTests.proof
    result=sf.CombinedScopeJobTests.result

    def setUp(self):
        super().setUp();self.now=int(time.time());self.store=self.server.store
        self.data['catalog']=scope_catalog(self.data['plans'][0]['computer_group_sid'])
        self.engine=DeploymentCandidates(self.server.connector_pairing,self.server.deployment)
        self.content=CombinedJobs(self.engine)
        self.jobs=CombinedScopeJobs(self.engine)

    def job_request(self):
        v=self.body();c,p,_=self.request('POST','/api/deployment/candidates/preview',v,self.headers)
        self.assertEqual(200,c,p)
        self.assertEqual(200,self.request('POST','/api/deployment/candidates/record',v|{'preview_hash':p['preview_hash']},self.headers)[0])
        # Preserve the original network receipt and register its current combined pair.
        v=self.body()|{'receipt_json':json.dumps(combined_receipt(self.data['plans'][0]))}
        c,p,_=self.request('POST','/api/deployment/candidates/preview',v,self.headers);self.assertEqual(200,c,p)
        self.assertEqual(200,self.request('POST','/api/deployment/candidates/record',v|{'preview_hash':p['preview_hash']},self.headers)[0])
        # Establish content through the real authenticated peer/admin endpoints.
        proof=content_fixtures.CombinedJobTests.proof(self)
        self.assertEqual(200,self.peer('/api/connector/v1/combined/poll',proof)[0])
        intent={'expected_revision':self.store.snapshot()['revision'],'candidate_id':v['registration_id'],
                'job_id':str(uuid.uuid4()),'operation':'combined.verify.v1'}
        c,p,_=self.request('POST','/api/deployment/candidates/combined/preview',intent,self.headers);self.assertEqual(200,c,p)
        self.assertEqual(200,self.request('POST','/api/deployment/candidates/combined/create',intent|{'preview_hash':p['preview_hash']},self.headers)[0])
        c,o=self.peer('/api/connector/v1/combined/poll',content_fixtures.CombinedJobTests.proof(self));self.assertEqual(200,c,o)
        b=content_fixtures.CombinedJobTests.result(self,o)
        self.assertEqual(200,self.peer('/api/connector/v1/combined/result',content_fixtures.CombinedJobTests.proof(self,'RESULT',b))[0])
        return {'expected_revision':self.store.snapshot()['revision'],'candidate_id':v['registration_id'],
                'job_id':str(uuid.uuid4()),'operation':OPERATION}

    def test_actual_https_scope_roundtrip_and_no_gpo_apply_route(self):
        self.assertEqual(200,self.peer(POLL_PATH,self.proof())[0])
        v=self.job_request()
        c,p,_=self.request('POST','/api/deployment/candidates/combined-scope/preview',v,self.headers);self.assertEqual(200,c,p)
        self.assertEqual(2,p['target']['target_count'])
        body=v|{'preview_hash':p['preview_hash']}
        for _ in range(2):self.assertEqual(200,self.request('POST','/api/deployment/candidates/combined-scope/create',body,self.headers)[0])
        c,o=self.peer(POLL_PATH,self.proof());self.assertEqual(200,c,o)
        self.now=int(time.time());raw=self.proof('RESULT',self.result(o))
        for _ in range(2):self.assertEqual(200,self.peer(RESULT_PATH,raw)[0])
        c,s,_=self.request('GET','/api/deployment/candidates',headers=self.headers);self.assertEqual(200,c,s)
        self.assertTrue(s['candidates'][0]['scope_snapshot_fresh'])
        self.assertFalse(s['candidates'][0]['connector_verified']);self.assertFalse(s['can_apply'])
        for path in ('/api/deployment/candidates/combined-scope/apply','/api/deployment/candidates/combined-scope/execute'):
            self.assertEqual(404,self.request('POST',path,{},self.headers)[0])

    def test_both_live_write_permissions_origin_csrf_and_interactive_session_required(self):
        v=self.job_request()
        for grants in ({'certificates.authority':'write'},{'system.connectors':'write'},
                       {'certificates.authority':'read','system.connectors':'read'}):
            h,_=self.user('scope-'+uuid.uuid4().hex[:8],grants)
            self.assertEqual(403,self.request('POST','/api/deployment/candidates/combined-scope/preview',v,h)[0])
        for h in (self.headers|{'X-Kaname-CSRF':'bad'},self.headers|{'Origin':'https://evil.example'},
                  {'Authorization':'Bearer '+self.server.token}):
            self.assertEqual(403,self.request('POST','/api/deployment/candidates/combined-scope/preview',v,h)[0])

    def test_scope_requires_own_capability_and_rejects_browser_and_content_proofs(self):
        self.job_request()
        for headers in ({'Cookie':'session=x'},{'Origin':'https://evil.example'},{'Authorization':'Bearer x'}):
            self.assertEqual(403,self.peer(POLL_PATH,self.proof(),headers)[0])
        for path,raw in [(POLL_PATH,content_fixtures.CombinedJobTests.proof(self)),
                         ('/api/connector/v1/combined/poll',self.proof()),
                         (RESULT_PATH,self.proof()),(POLL_PATH,self.proof(private=self.other))]:
            self.assertEqual(403,self.peer(path,raw)[0])

    def test_demotion_after_body_read_prevents_scope_job_write(self):
        self.assertEqual(200,self.peer(POLL_PATH,self.proof())[0]);v=self.job_request()
        h,profile=self.user('scope-operator',{'certificates.authority':'write','system.connectors':'write'})
        c,p,_=self.request('POST','/api/deployment/candidates/combined-scope/preview',v,h);self.assertEqual(200,c,p)
        original=Handler.read_body
        def demote(handler):
            result=original(handler)
            with self.server.admin.connect() as db:db.execute('UPDATE admin_profiles SET grants=? WHERE id=?',('{"certificates.authority":"write"}',profile))
            return result
        with patch.object(Handler,'read_body',demote):
            self.assertEqual(403,self.request('POST','/api/deployment/candidates/combined-scope/create',v|{'preview_hash':p['preview_hash']},h)[0])

