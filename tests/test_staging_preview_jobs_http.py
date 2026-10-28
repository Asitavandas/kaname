"""Real HTTPS + RSA proposals, existing live admin leases and separate body limits."""
import copy
import json
import time
import unittest
import uuid
from kaname.deployment_candidates import DeploymentCandidates
from kaname.combined_jobs import CombinedJobs
from kaname.staging_preview_jobs import StagingPreviewJobs,OPERATION,POLL_PATH,RESULT_PATH
from . import test_deployment_candidates_http as cf
from . import test_combined_scope_jobs_http as sf
from . import test_connector_jobs_http as jf
from .test_combined_scope_jobs import scope_catalog
from . import test_staging_preview_jobs as stage_fixtures


class StagingPreviewHTTPTests(unittest.TestCase):
    setUpClass=classmethod(cf.CandidateHTTPTests.setUpClass.__func__)
    tearDownClass=classmethod(cf.CandidateHTTPTests.tearDownClass.__func__)
    request=cf.CandidateHTTPTests.request
    login=cf.CandidateHTTPTests.login
    close=cf.CandidateHTTPTests.close
    intent=cf.CandidateHTTPTests.intent
    prepare=cf.CandidateHTTPTests.prepare
    user=cf.CandidateHTTPTests.user
    body=cf.CandidateHTTPTests.body
    peer=jf.ConnectorJobHTTPTests.peer
    binding=stage_fixtures.StagingPreviewJobTests.binding
    proof=stage_fixtures.StagingPreviewJobTests.proof
    def setUp(self):
        cf.CandidateHTTPTests.setUp(self);self.now=int(time.time());self.store=self.server.store
        self.data['catalog']=scope_catalog(self.data['plans'][0]['computer_group_sid'])
        self.engine=DeploymentCandidates(self.server.connector_pairing,self.server.deployment)
        self.content=CombinedJobs(self.engine);self.jobs=StagingPreviewJobs(self.engine)
    def job_request(self):
        v=sf.CombinedScopeJobHTTPTests.job_request(self);v['operation']=OPERATION;return v
    def result(self,offer,**changes):
        self.now=int(time.time());return stage_fixtures.StagingPreviewJobTests.result(self,offer,**changes)
    def create(self):
        self.assertEqual(200,self.peer(POLL_PATH,self.proof())[0]);v=self.job_request()
        c,p,_=self.request('POST','/api/deployment/candidates/staging-preview/preview',v,self.headers)
        self.assertEqual(200,c,p)
        body=v|{'preview_hash':p['preview_hash']}
        self.assertEqual(200,self.request('POST','/api/deployment/candidates/staging-preview/create',body,self.headers)[0])
        return self.peer(POLL_PATH,self.proof())[1]
    def test_actual_https_large_result_and_readonly_panel_projection(self):
        o=self.create();v=self.result(o);raw=self.proof('RESULT',v)
        self.assertGreater(len(raw),4096);self.assertLessEqual(len(raw),32768)
        for _ in range(2):self.assertEqual(200,self.peer(RESULT_PATH,raw)[0])
        c,s,_=self.request('GET','/api/deployment/candidates',headers=self.headers);self.assertEqual(200,c,s)
        row=s['candidates'][0];self.assertTrue(row['staging_preview_fresh']);self.assertEqual(20,row['staging_preview']['file_count'])
        self.assertFalse(row['staging_preview']['can_stage']);self.assertFalse(s['can_apply'])
        for path in ('/api/deployment/candidates/staging-preview/apply','/api/deployment/candidates/staging-preview/execute'):
            self.assertEqual(404,self.request('POST',path,{},self.headers)[0])
        self.assertEqual(403,self.peer('/api/connector/v1/combined-scope/result',raw)[0])
    def test_both_current_permissions_csrf_origin_and_panel_session_are_required(self):
        v=self.job_request()
        for grants in ({'certificates.authority':'write'},{'system.connectors':'write'},
                       {'certificates.authority':'read','system.connectors':'read'}):
            h,_=self.user('stage-'+uuid.uuid4().hex[:8],grants)
            self.assertEqual(403,self.request('POST','/api/deployment/candidates/staging-preview/preview',v,h)[0])
        for h in (self.headers|{'X-Kaname-CSRF':'bad'},self.headers|{'Origin':'https://evil.example'},
                  {'Authorization':'Bearer '+self.server.token}):
            self.assertEqual(403,self.request('POST','/api/deployment/candidates/staging-preview/preview',v,h)[0])
    def test_peer_rejects_browser_credentials_cross_purpose_and_oversized_result(self):
        for h in ({'Cookie':'session=x'},{'Origin':'https://evil.example'},{'Authorization':'Bearer x'}):
            self.assertEqual(403,self.peer(POLL_PATH,self.proof(),h)[0])
        o=self.create();body=self.result(o)
        for change in ({'can_apply':True},{'padding':'x'*20000}):
            self.assertEqual(403,self.peer(RESULT_PATH,self.proof('RESULT',body|change))[0])
        self.assertEqual(200,self.peer(RESULT_PATH,self.proof('RESULT',body))[0])
