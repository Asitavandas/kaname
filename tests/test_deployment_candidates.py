"""Actual SQLite/RSA binding; mocked directory/trust snapshot, no GPO authority."""
import copy
import json
import sqlite3
import types
import unittest
import uuid
from unittest.mock import patch

from kaname.deployment_candidates import DeploymentCandidates, CandidateError, SECTION
from . import test_connector_registry as rf


def fixture_snapshot():
    plan={'id':str(uuid.uuid4()),'version':1,'auth_mode':'machine','wired':True,'wireless':True,
          'machine_profile_id':str(uuid.uuid4()),'domain':'lab.example','computer_group_sid':'S-1-5-21-111-222-333-1647'}
    profile={'id':plan['machine_profile_id'],'version':3,'domain':'lab.example','enabled':1,'group_sid':plan['computer_group_sid']}
    return {'plans':[plan],'machine_profiles':[profile],'config':{'ad_domain':'lab.example'},'catalog':{'synced_at':'first','members':['fixture']}}


def make_receipt(plan):
    nested={'Event':'WINDOWS_DEPLOYMENT_CANDIDATE','CandidatePath':'C:\\ignored\\candidate',
            'PlanId':plan['id'],'PlanVersion':plan['version'],'GpoId':str(uuid.uuid4()),
            'ManifestSha256':'1'*64,'SignatureVerified':True,'ArtifactExecuted':False,'CanApplyGpo':False,
            'AdChanged':False,'GpoChanged':False,'EndpointChanged':False,'ServicesChanged':False,
            'TrustStoreChanged':False,'KeyAclChanged':False,'SecretsExported':False,'PreparedNow':True}
    return {'Event':'WINDOWS_DEPLOYMENT_CANDIDATE_DELIVERY','ToolVersion':'1.0.0','Mode':'Prepare','Computer':'DC01',
            'SourceCommit':'a'*40,'SourcesDirectory':'C:\\ignored\\sources','SourcesPreparedNow':True,
            'SourceSignaturesValid':True,'ApprovalSha256':'2'*64,'Stage':'prepared','Candidate':nested,
            'ExistingConnectorChanged':False,'AdChanged':False,'GpoChanged':False,'TrustStoreChanged':False,
            'KeyAclChanged':False,'WindowsEndpointChanged':False,'CanApplyGpo':False,'SecretsExported':False}


class CandidateTests(unittest.TestCase):
    setUpClass=classmethod(rf.ConnectorRegistryTests.setUpClass.__func__)
    tearDownClass=classmethod(rf.ConnectorRegistryTests.tearDownClass.__func__)
    context=rf.ConnectorRegistryTests.context
    pem=staticmethod(rf.ConnectorRegistryTests.pem)
    intent=rf.ConnectorRegistryTests.intent
    prepare=rf.ConnectorRegistryTests.prepare
    pair=rf.ConnectorRegistryTests.pair

    def setUp(self):
        rf.ConnectorRegistryTests.setUp(self);self.pair();self.data=fixture_snapshot()
        self.targets={'available':True,'enabled':2,'unresolved':0};self.trust={'ready':True,'root_thumbprint':'c'*40}
        self.dep=types.SimpleNamespace(_snapshot=lambda db:copy.deepcopy(self.data),
            _targets=lambda *a:dict(self.targets),_trust=lambda *a:dict(self.trust))
        self.engine=DeploymentCandidates(self.registry,self.dep,wall_clock=lambda:1800000000)
        self.receipt=make_receipt(self.data['plans'][0])

    def request(self):
        return {'expected_revision':self.store.snapshot()['revision'],'registration_id':str(uuid.uuid4()),
                'receipt_json':json.dumps(self.receipt)}

    def save(self,v=None):
        v=v or self.request();p=self.engine.preview(v)
        payload=v|{'preview_hash':p['preview_hash']}
        return payload,self.engine.record(payload,self.actor)

    def test_read_preview_are_read_only_and_never_claim_machine_authority(self):
        before=self.store.snapshot();audit=self.store.audit()
        self.assertEqual([],self.engine.status()['candidates'])
        p=self.engine.preview(self.request());self.assertEqual('operator_reported',p['state'])
        self.assertFalse(p['connector_verified']);self.assertFalse(p['can_apply'])
        self.assertEqual(before,self.store.snapshot());self.assertEqual(audit,self.store.audit())

    def test_record_exact_receipt_idempotent_without_paths_or_execution_authority(self):
        body,r=self.save();audit=self.store.audit();self.assertEqual(r,self.engine.record(body,self.actor))
        self.assertEqual(audit,self.store.audit());s=self.engine.status();self.assertTrue(s['worker_delivery_pending'])
        self.assertEqual('operator_reported',s['candidates'][0]['state']);self.assertFalse(s['can_apply'])
        with self.store.connect() as db: raw=db.execute('SELECT payload FROM runtime_settings WHERE name=?',(SECTION,)).fetchone()[0]
        self.assertNotIn('ignored',raw);self.assertNotIn('CandidatePath',raw);self.assertNotIn('SignatureVerified',raw)

    def test_missing_unknown_duplicate_and_typed_receipts_refused_without_write(self):
        for value in [self.receipt|{'command':'whoami'},self.receipt|{'CanApplyGpo':True},
                      self.receipt|{'CanApplyGpo':0},self.receipt|{'SourceSignaturesValid':'true'},
                      self.receipt|{'Computer':'OTHER'},self.receipt|{'Stage':'applied'}]:
            with self.subTest(value=value),self.assertRaises(ValueError):self.engine.preview(self.request()|{'receipt_json':json.dumps(value)})
        for change in [{'SignatureVerified':False},{'GpoChanged':True},{'PlanVersion':True},{'ManifestSha256':'bad'}]:
            changed=self.receipt|{'Candidate':self.receipt['Candidate']|change}
            with self.subTest(change=change),self.assertRaises(ValueError):self.engine.preview(self.request()|{'receipt_json':json.dumps(changed)})
        raw=json.dumps(self.receipt).replace('"Mode":','"Mode":"bad","Mode":')
        for raw in (raw,'[]','{}','x'*8193):
            with self.assertRaises(ValueError):self.engine.preview(self.request()|{'receipt_json':raw})
        self.assertEqual([],self.engine.status()['candidates'])

    def test_plan_profile_catalog_trust_or_binding_change_invalidates_record(self):
        self.save();original=copy.deepcopy(self.data)
        for change in ('plan','profile','members','disabled','trust','unresolved'):
            self.data=copy.deepcopy(original);self.trust['ready']=True;self.targets['unresolved']=0
            if change=='plan':self.data['plans'][0]['version']+=1
            if change=='profile':self.data['machine_profiles'][0]['version']+=1
            if change=='members':self.data['catalog']['members'].append('new')
            if change=='disabled':self.data['machine_profiles'][0]['enabled']=0
            if change=='trust':self.trust['ready']=False
            if change=='unresolved':self.targets['unresolved']=1
            self.assertEqual('outdated',self.engine.status()['candidates'][0]['state'],change)
        self.data=original;self.trust['ready']=True;self.targets['unresolved']=0
        self.registry.apply(self.prepare(self.intent('revoke')),self.actor)
        self.assertEqual('outdated',self.engine.status()['candidates'][0]['state'])

    def test_timestamp_refresh_is_not_deployment_or_semantic_change(self):
        self.save();self.data['catalog']['synced_at']='new timestamp'
        self.assertEqual('operator_reported',self.engine.status()['candidates'][0]['state'])
        self.assertFalse(self.engine.status()['candidates'][0]['connector_verified'])

    def test_stale_preview_same_revision_dependency_and_id_conflict(self):
        v=self.request();p=self.engine.preview(v);self.data['machine_profiles'][0]['version']+=1
        with self.assertRaisesRegex(CandidateError,'PREVIEW_STALE'):self.engine.record(v|{'preview_hash':p['preview_hash']},self.actor)
        body,_=self.save()
        with self.assertRaisesRegex(CandidateError,'ID_CONFLICT'):self.engine.record(body,str(uuid.uuid4()))
        with self.assertRaisesRegex(CandidateError,'ALREADY_RECORDED'):self.save()

    def test_corrupt_store_fails_closed_and_audit_failure_rolls_back(self):
        v=self.request();p=self.engine.preview(v)
        with patch.object(self.ops,'_audit',side_effect=sqlite3.OperationalError('unavailable')):
            with self.assertRaises(sqlite3.Error):self.engine.record(v|{'preview_hash':p['preview_hash']},self.actor)
        self.assertEqual([],self.engine.status()['candidates'])
        with self.store.connect() as db:db.execute('INSERT INTO runtime_settings VALUES (?,?)',(SECTION,'{"secret":"DO_NOT_ECHO"}'))
        with self.assertRaisesRegex(CandidateError,'STORE_INVALID'):self.engine.status()


if __name__=='__main__':unittest.main()
