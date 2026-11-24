"""Separate before-intent proof schema, real SQLite/RSA/audited queue admission."""
import copy
import json
import unittest
import uuid

from kaname import rollback_retirements as rr
from kaname import rollback_preintent_retirements as pp
from kaname.connector_jobs import JobError
from kaname.connector_registry import digest
from kaname.staging_write_jobs import ROLLBACK, SECTION as JOBS
from . import test_rollback_retirements as base


def make_proof(private, job, ack, receipt, now):
    p=base.make_proof(None, private, job, ack, receipt, now)
    review=p['review_record']['review']['Body'];closed=p['completion']['Body']
    for body in (review,closed):
        del body['filesystem_intent_sha256'];del body['prior_observation_sha256']
        body['grant_consumption_sha256']='8'*64;body['filesystem_intent_absent']=True
    review['format']='AuthWirePreIntentRollbackRetirementReviewV1'
    closed['format']='AuthWirePreIntentRollbackRetirementCompleteV1'
    ob={'format':'AuthWireRollbackPreIntentObservationV1','job_id':job['id'],
        'stage_job_id':job['target']['stage_receipt']['stage_job_id'],'stage_operation_id':str(uuid.uuid4()),
        'binding_scope':job['scope'],'authority_release':job['target']['writer_release_id'],
        'authorization_id':job['authorization_id'],'authorization_sha256':'9'*64,
        'grant_consumption_sha256':'8'*64,'original_records_sha256':review['original_records_sha256'],
        'consumed_at':job['authorized_at']+1,'expires_at':job['authorized_until'],
        'tree_sha256':review['tree_sha256'],'outside_baseline_sha256':review['baseline_sha256'],
        'tree_rows':23,'authority_expired':True,'filesystem_intent_absent':True,'execution_markers_absent':True,
        'staged_tree_unchanged':True,'outside_unchanged':True,'read_only':True,'can_delete':False,
        'authority_renewed':False,'observed_at':now}
    p['review_record']['format']='AuthWirePreIntentRollbackRetirementRecordV1'
    p['review_record']['acknowledge']='retire_consumed_rollback_before_intent_preserve_unknown_outcome'
    p['review_record']['observation']={'Body':ob,'Signature':''}
    resign(private,p)
    return p


def resign(private,p):
    r=p['review_record'];v=r['review']['Body'];c=p['completion']['Body']
    r['observation']=base.sign(private,r['observation']['Body'],pp.OBSERVATION_DOMAIN)
    v['observation_sha256']=digest(r['observation']);r['review']=base.sign(private,v,pp.REVIEW_DOMAIN)
    c['observation_sha256']=v['observation_sha256'];c['review_record_sha256']=digest(r)
    p['completion']=base.sign(private,c,pp.COMPLETE_DOMAIN)


class PreIntentRetirementTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):base.RollbackRetirementTests.setUpClass()

    @classmethod
    def tearDownClass(cls):base.RollbackRetirementTests.tearDownClass()

    def setUp(self):
        self.b=base.RollbackRetirementTests();self.addCleanup(self.b.doCleanups);self.b.setUp()
        self.f=self.b.f;self.jobs=self.b.jobs;self.actor=self.b.actor
        with self.f.store.connect() as db:
            job=next(j for j in self.jobs._read(db)['jobs'] if j['id']==self.b.offer['job_id'])
        self.f.now=max(self.f.now,job['lease_until']+1)
        self.b.value['retirement']=make_proof(self.f.private,job,self.b.ack_request,self.b.receipt,self.f.now)
        self.value=self.b.value

    def test_paired_proof_is_idempotent_and_original_ledger_bytes_are_immutable(self):
        before=self.b.original();req=self.b.confirmed();receipt=self.jobs.record_reconciliation(req,self.actor)
        self.assertEqual(receipt,self.jobs.record_reconciliation(req,self.actor))
        self.assertEqual(before,self.b.original());self.assertTrue(receipt['original_state_preserved'])
        self.assertFalse(receipt['authority_renewed']);self.assertFalse(receipt['can_apply_gpo'])

    def test_only_accepted_exact_stage_can_admit_distinct_successor(self):
        stage=self.b.offer['target']['stage_receipt']['stage_job_id'];self.jobs.poll(self.f.proof())
        with self.assertRaisesRegex(JobError,'GPO_BUSY'):self.f.enqueue(self.f.value(ROLLBACK,stage))
        self.value['expected_revision']=self.f.store.snapshot()['revision']
        self.jobs.record_reconciliation(self.b.confirmed(),self.actor)
        before=json.loads(self.b.original())['jobs'];self.jobs.poll(self.f.proof())
        self.f.enqueue(self.f.value(ROLLBACK,stage));offer=self.jobs.poll(self.f.proof())
        grant=self.f.authorize(offer);self.assertNotEqual(grant['authorization_id'],self.b.grant['authorization_id'])
        self.assertEqual(before,json.loads(self.b.original())['jobs'][:-1])
        self.jobs.poll(self.f.proof())
        with self.assertRaisesRegex(JobError,'GPO_BUSY'):self.f.enqueue(self.f.value(ROLLBACK,stage))

    def test_old_domains_and_wrong_key_cannot_substitute(self):
        for domain,key in ((rr.COMPLETE_DOMAIN,self.f.private),(pp.REVIEW_DOMAIN,self.f.private),(pp.COMPLETE_DOMAIN,self.f.other)):
            v=copy.deepcopy(self.value);v['retirement']['completion']=base.sign(key,v['retirement']['completion']['Body'],domain)
            with self.assertRaises(JobError):self.jobs.review_reconciliation(v,self.actor)

    def test_every_component_is_signature_bound(self):
        for section in ('observation','review','completion'):
            v=copy.deepcopy(self.value);p=v['retirement'];body=p[section]['Body'] if section=='completion' else p['review_record'][section]['Body']
            body['job_id']=str(uuid.uuid4())
            with self.assertRaises(JobError):self.jobs.review_reconciliation(v,self.actor)

    def test_validly_signed_unsafe_semantics_fail_closed(self):
        changes=[('observation','filesystem_intent_absent',False),('observation','execution_markers_absent',False),
                 ('observation','authority_renewed',True),('observation','authority_expired',False),
                 ('observation','authorization_id','f'*64),('observation','authority_release',str(uuid.uuid4())),
                 ('observation','expires_at',self.b.grant['expires_at']+1),('observation','consumed_at',self.b.grant['expires_at']),
                 ('observation','original_records_sha256','f'*64),('observation','grant_consumption_sha256','f'*64),
                 ('observation','tree_rows',True),('observation','outside_unchanged',False),('observation','can_delete',True),
                 ('observation','observed_at',self.b.grant['expires_at']+1),
                 ('review','filesystem_intent_absent',False),('review','original_outcome','rolled_back'),
                 ('review','expires_at',self.f.now+61),('review','gpo_id',str(uuid.uuid4())),
                 ('completion','original_unknown_result_preserved',False),('completion','authority_renewed',True),
                 ('completion','closed_at',self.f.now+60),('completion','filesystem_intent_absent',False)]
        for section,name,value in changes:
            with self.subTest(section=section,name=name):
                v=copy.deepcopy(self.value);p=v['retirement'];body=p[section]['Body'] if section=='completion' else p['review_record'][section]['Body']
                body[name]=value;resign(self.f.private,p)
                with self.assertRaises(JobError):self.jobs.review_reconciliation(v,self.actor)

    def test_no_schema_mix_or_extra_fields(self):
        for section in ('observation','review','completion'):
            v=copy.deepcopy(self.value);p=v['retirement'];body=p[section]['Body'] if section=='completion' else p['review_record'][section]['Body']
            body['filesystem_intent_sha256']='f'*64;resign(self.f.private,p)
            with self.assertRaises(JobError):self.jobs.review_reconciliation(v,self.actor)
        v=copy.deepcopy(self.value);v['retirement']['review_record']['acknowledge']='retire_consumed_rollback_preserve_unknown_outcome';resign(self.f.private,v['retirement'])
        with self.assertRaises(JobError):self.jobs.review_reconciliation(v,self.actor)

    def test_original_ack_must_be_actually_audited(self):
        v=copy.deepcopy(self.value);record=v['retirement']['review_record']
        record['acknowledgement_request']['expected_revision']+=10
        record['acknowledgement_receipt']['revision']+=10
        resign(self.f.private,v['retirement'])
        with self.assertRaisesRegex(JobError,'ACK_AUDIT_REQUIRED'):self.jobs.review_reconciliation(v,self.actor)

    def test_stored_corruption_blocks_future_admission(self):
        self.jobs.record_reconciliation(self.b.confirmed(),self.actor)
        with self.f.store.connect() as db:
            saved=json.loads(db.execute('SELECT payload FROM runtime_settings WHERE name=?',(rr.SECTION,)).fetchone()[0])
            saved['records'][0]['request']['retirement']['review_record']['observation']['Body']['filesystem_intent_absent']=False
            db.execute('UPDATE runtime_settings SET payload=? WHERE name=?',(json.dumps(saved),rr.SECTION))
        self.jobs.poll(self.f.proof())
        with self.assertRaises(JobError):self.f.enqueue(self.f.value(ROLLBACK,self.b.offer['target']['stage_receipt']['stage_job_id']))
