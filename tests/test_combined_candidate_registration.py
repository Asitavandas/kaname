"""Combined reports remain distinct from existing verified network candidates."""
import copy
import json
import sqlite3
import unittest
import uuid
from kaname.deployment_candidates import CandidateError, SECTION, COMBINED
from kaname.candidate_jobs import CandidateJobs
from kaname.connector_jobs import JobError
from kaname.scope_jobs import ScopeJobs
from tests import test_deployment_candidates as fixtures


def combined_receipt(plan):
    return {'Event':'WINDOWS_COMBINED_SIGNING_DELIVERY','ToolVersion':'1.0.0','Mode':'Prepare',
            'SourceCommit':'a'*40,'SourcesDirectory':'C:\\ignored\\combined-sources',
            'SourcesPreparedNow':True,'Stage':'verified','OriginalDraftPreserved':True,
            'AdChanged':False,'GpoChanged':False,'PermanentConnectorChanged':False,'CanApplyGpo':False,
            'Result':{'Event':'WINDOWS_COMBINED_CANDIDATE_PREPARED','CandidatePath':'C:\\ignored\\combined',
                      'PlanId':plan['id'],'PlanVersion':plan['version'],'DraftSha256':'d'*64,
                      'ManifestSha256':'e'*64,'PublisherThumbprint':'F'*40,'SignaturesVerified':3,
                      'InstallerTemplateUpdated':True,'CanStage':False,'CanApplyGpo':False,
                      'ArtifactExecuted':False,'AdChanged':False,'GpoChanged':False,'EndpointChanged':False,
                      'ServicesChanged':False,'KeyAclChanged':False,'TrustStoreChanged':False,
                      'SecretsExported':False,'PreparedNow':True,'SignerSnapshotPreserved':True}}


class CombinedRegistrationTests(unittest.TestCase):
    setUpClass=classmethod(fixtures.CandidateTests.setUpClass.__func__)
    tearDownClass=classmethod(fixtures.CandidateTests.tearDownClass.__func__)
    context=fixtures.CandidateTests.context
    pem=staticmethod(fixtures.CandidateTests.pem)
    intent=fixtures.CandidateTests.intent
    prepare=fixtures.CandidateTests.prepare
    pair=fixtures.CandidateTests.pair
    request=fixtures.CandidateTests.request
    save=fixtures.CandidateTests.save

    def setUp(self):
        fixtures.CandidateTests.setUp(self)
        _,saved=self.save();self.network_id=saved['id']
        self.receipt=combined_receipt(self.data['plans'][0])

    def test_full_real_envelope_records_separately_and_preserves_original_network_row(self):
        with self.store.connect() as db:before=self.engine._read(db)
        request=self.request();snapshot=self.store.snapshot();audit=self.store.audit()
        preview=self.engine.preview(request)
        self.assertEqual(COMBINED,preview['artifact_kind'])
        self.assertEqual(self.network_id,preview['network_candidate_id'])
        self.assertEqual(before[0]['gpo_id'],preview['gpo_id'])
        self.assertEqual(snapshot,self.store.snapshot());self.assertEqual(audit,self.store.audit())
        body=request|{'preview_hash':preview['preview_hash']}
        result=self.engine.record(body,self.actor);saved_audit=self.store.audit()
        self.assertEqual(result,self.engine.record(body,self.actor))
        self.assertEqual(saved_audit,self.store.audit())
        with self.store.connect() as db:
            after=self.engine._read(db)
            raw=db.execute('SELECT payload FROM runtime_settings WHERE name=?',(SECTION,)).fetchone()[0]
        self.assertEqual(before[0],after[0]);self.assertEqual(2,len(after))
        for text in ('ignored','CandidatePath','SourcesDirectory','SignaturesVerified'):
            self.assertNotIn(text,raw)
        status=self.engine.status();row=next(r for r in status['candidates'] if r['id']==result['id'])
        for flag in ('content_verified','connector_verified','can_apply','scope_snapshot_verified'):
            self.assertIs(row[flag],False)
        self.assertEqual('operator_reported',row['state']);self.assertTrue(row['content_verification_available'])

    def test_old_content_and_scope_workers_cannot_verify_combined_record(self):
        _,result=self.save();identity=result['id']
        for engine,operation in ((CandidateJobs(self.engine),'candidate.verify.v1'),
                                 (ScopeJobs(self.engine),'deployment.scope.verify.v1')):
            request={'expected_revision':self.store.snapshot()['revision'],'candidate_id':identity,
                     'job_id':str(uuid.uuid4()),'operation':operation}
            before=self.store.snapshot();audit=self.store.audit()
            with self.assertRaisesRegex(JobError,'FORMAT_UNSUPPORTED'):engine.preview(request)
            with self.assertRaises(JobError):engine.create(request|{'preview_hash':'0'*64},self.actor)
            self.assertEqual(before,self.store.snapshot());self.assertEqual(audit,self.store.audit())

    def test_current_network_record_and_dependencies_are_required(self):
        for change in ('missing_network','profile','binding'):
            with self.subTest(change=change):
                with self.store.connect() as db:saved=self.engine._read(db)
                old=copy.deepcopy(self.data)
                try:
                    if change=='missing_network':
                        with self.store.connect() as db:self.ops._save(db,SECTION,[])
                    elif change=='profile':self.data['machine_profiles'][0]['version']+=1
                    else:
                        with self.store.connect() as db:
                            altered=copy.deepcopy(saved);altered[0]['binding_scope']='0'*64
                            self.ops._save(db,SECTION,altered)
                    with self.assertRaisesRegex(CandidateError,'NETWORK_RECORD_REQUIRED'):
                        self.engine.preview(self.request())
                finally:
                    self.data.clear();self.data.update(old)
                    with self.store.connect() as db:self.ops._save(db,SECTION,saved)

    def test_previews_and_records_do_not_accept_mutation_or_authority_overclaims(self):
        cases=[self.receipt|{'CanApplyGpo':True}, self.receipt|{'Stage':'applied'},
               self.receipt|{'Computer':'other-host'},self.receipt|{'SourceSignaturesValid':True}]
        for key,value in [('CanStage',True),('CanApplyGpo',True),('ArtifactExecuted',True),
                          ('SignaturesVerified',True),('SignaturesVerified',2),('SignerSnapshotPreserved',False),
                          ('DraftSha256','bad'),('PublisherThumbprint','f'*40),('PlanVersion',True)]:
            cases.append(self.receipt|{'Result':self.receipt['Result']|{key:value}})
        before=self.store.snapshot();audit=self.store.audit()
        for receipt in cases:
            with self.subTest(receipt=receipt),self.assertRaises(CandidateError):
                self.engine.preview(self.request()|{'receipt_json':json.dumps(receipt)})
        raw=json.dumps(self.receipt).replace('"DraftSha256":','"DraftSha256":"'+('0'*64)+'","DraftSha256":')
        with self.assertRaises(CandidateError):self.engine.preview(self.request()|{'receipt_json':raw})
        self.assertEqual(before,self.store.snapshot());self.assertEqual(audit,self.store.audit())

    def test_stale_combined_record_is_never_relabelled_as_verified(self):
        _,result=self.save();self.data['machine_profiles'][0]['version']+=1
        row=next(r for r in self.engine.status()['candidates'] if r['id']==result['id'])
        self.assertEqual('outdated',row['state']);self.assertFalse(row['content_verified'])

    def test_corrupt_combined_store_is_refused_without_repair(self):
        self.save()
        with self.store.connect() as db:
            rows=self.engine._read(db);rows[-1]['artifact_kind']='network_v1'
            self.ops._save(db,SECTION,rows)
        with self.assertRaisesRegex(CandidateError,'STORE_INVALID'):self.engine.status()

    def test_second_combined_report_does_not_replace_accepted_record(self):
        self.save();self.receipt['Result']['ManifestSha256']='b'*64
        request=self.request();p=self.engine.preview(request)
        with self.assertRaisesRegex(CandidateError,'ALREADY_RECORDED'):
            self.engine.record(request|{'preview_hash':p['preview_hash']},self.actor)
