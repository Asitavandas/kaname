"""Real SQLite/RSA controller contract. Local NTFS observations are signed fixture data."""
import base64
import copy
import json
import unittest
import uuid

from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import padding

from kaname.connector_jobs import JobError, scope_id
from kaname.connector_registry import digest
from kaname.store import ConflictError
from kaname.staging_write_jobs import SECTION as JOBS, ROLLBACK, STAGE
from kaname import rollback_retirements as rr
from . import test_staging_write_jobs as wf


def sign(private, body, domain):
    frame=(domain+'\n'+digest(body)+'\n').encode('ascii')
    return {'Body':copy.deepcopy(body),'Signature':base64.b64encode(private.sign(frame,padding.PKCS1v15(),hashes.SHA256())).decode()}


def make_proof(jobs, private, job, ack_request, ack_receipt, now):
    """Same on-wire schema as the separately tested Windows CNG/NTFS producer."""
    stage=job['target']['stage_receipt']['stage_job_id']; baseline=job['target']['preview_record']['Preview']['baseline_inventory_sha256']
    body={'format':'AuthWireRollbackReadOnlyObservationV1','job_id':job['id'],'stage_job_id':stage,
          'stage_operation_id':str(uuid.uuid4()),'active_release':job['target']['writer_release_id'],
          'authority_expired':True,'intent_sha256':'1'*64,'original_child_running':False,
          'entered_marker_exists':False,'engine_markers':{'rolled-back.json':False,'rollback-started.json':False},
          'tree_sha256':job['target']['stage_receipt']['staged_tree_sha256'],'outside_baseline_sha256':baseline,
          'tree_rows':23,'staged_tree_unchanged':True,'outside_unchanged':True,'read_only':True,
          'can_delete':False,'authority_renewed':False,'at':now}
    obs={'domain':rr.OBSERVATION_DOMAIN,'body':body,'signature':base64.b64encode(private.sign(
        (rr.OBSERVATION_DOMAIN+'\n').encode()+rr.canonical(body),padding.PKCS1v15(),hashes.SHA256())).decode()}
    review={'format':'AuthWireConsumedRollbackRetirementReviewV1','job_id':job['id'],'stage_job_id':stage,
            'gpo_id':job['target']['scope_target']['gpo_id'],'binding_scope':job['scope'],
            'original_records_sha256':'2'*64,'reservation_sha256':'3'*64,'origin_chain_sha256':'4'*64,
            'tree_sha256':body['tree_sha256'],'baseline_sha256':baseline,'result_body_sha256':digest(job['result']),
            'observed_at':now,'expires_at':now+60,'retain_original_reservation':True,'retain_gpo_lock':True,
            'requires_new_rollback_job':True,'can_delete':False,'can_apply_gpo':False,
            'filesystem_intent_sha256':body['intent_sha256'],'prior_observation_sha256':digest(obs),
            'original_outcome':'requires_review','filesystem_effects':'unconfirmed'}
    record={'format':'AuthWireConsumedRollbackRetirementRecordV1','review':sign(private,review,rr.REVIEW_DOMAIN),
            'observation':obs,'acknowledgement_request':copy.deepcopy(ack_request),
            'acknowledgement_receipt':copy.deepcopy(ack_receipt),
            'acknowledge':'retire_consumed_rollback_preserve_unknown_outcome'}
    closed={'format':'AuthWireConsumedRollbackRetirementCompleteV1','job_id':job['id'],'stage_job_id':stage,
            'binding_scope':job['scope'],'original_records_sha256':review['original_records_sha256'],
            'review_record_sha256':digest(record),'reservation_sha256':review['reservation_sha256'],
            'closed_at':now,'original_reservation_retained':True,'gpo_lock_retained':True,
            'authority_renewed':False,'can_delete':False,'can_apply_gpo':False,
            'original_unknown_result_preserved':True,'filesystem_intent_sha256':review['filesystem_intent_sha256'],
            'prior_observation_sha256':review['prior_observation_sha256']}
    return {'review_record':record,'completion':sign(private,closed,rr.COMPLETE_DOMAIN)}


def resign(private, proof):
    """Re-sign semantic counterexamples so they test more than hash tampering."""
    record=proof['review_record'];ob=record['observation'];review=record['review']['Body'];closed=proof['completion']['Body']
    ob['signature']=base64.b64encode(private.sign((rr.OBSERVATION_DOMAIN+'\n').encode()+rr.canonical(ob['body']),
        padding.PKCS1v15(),hashes.SHA256())).decode()
    review['prior_observation_sha256']=digest(ob)
    record['review']=sign(private,review,rr.REVIEW_DOMAIN)
    closed['prior_observation_sha256']=review['prior_observation_sha256'];closed['review_record_sha256']=digest(record)
    proof['completion']=sign(private,closed,rr.COMPLETE_DOMAIN)


class RollbackRetirementTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        wf.StagingWriteJobTests.setUpClass()

    @classmethod
    def tearDownClass(cls):
        wf.StagingWriteJobTests.tearDownClass()

    def setUp(self):
        self.f=wf.StagingWriteJobTests();self.addCleanup(self.f.doCleanups);self.f.setUp()
        self.jobs=self.f.jobs;self.actor=self.f.actor
        self.offer,self.grant,ack=self.f.saved_uncertain_result()
        self.f.now=self.grant['expires_at']+1
        old_review=self.jobs.review_reconciliation(ack,self.actor)
        self.ack_request=ack|{'review_hash':old_review['review_hash'],'acknowledge':'record_reconciliation_decision'}
        receipt=self.jobs.record_reconciliation(self.ack_request,self.actor)
        self.receipt=receipt|{'approval_enabled':False,'write_authorization_enabled':False,
                              'execution_adapter_available':False,'can_apply_gpo':False}
        with self.f.store.connect() as db:
            job=next(j for j in self.jobs._read(db)['jobs'] if j['id']==self.offer['job_id'])
        self.proof=make_proof(self.jobs,self.f.private,job,self.ack_request,self.receipt,self.f.now)
        self.value={'expected_revision':self.f.store.snapshot()['revision'],'evidence':ack['evidence'],
                    'decision':rr.DECISION,'retirement':self.proof}

    def original(self):
        with self.f.store.connect() as db:
            return db.execute('SELECT payload FROM runtime_settings WHERE name=?',(JOBS,)).fetchone()[0]

    def confirmed(self, value=None, actor=None):
        v=value or self.value;a=actor or self.actor
        review=self.jobs.review_reconciliation(v,a)
        return v|{'review_hash':review['review_hash'],'acknowledge':rr.ACK}

    def test_valid_retirement_is_audited_idempotent_and_preserves_original_ledger(self):
        before=self.original();audit=self.f.store.audit();request=self.confirmed()
        self.assertEqual(before,self.original());self.assertEqual(audit,self.f.store.audit())
        first=self.jobs.record_reconciliation(request,self.actor)
        self.assertEqual(first,self.jobs.record_reconciliation(request,self.actor))
        self.assertEqual(self.value['expected_revision']+1,first['revision'])
        self.assertTrue(first['original_state_preserved']);self.assertFalse(first['authority_renewed'])
        self.assertFalse(first['can_apply_gpo']);self.assertEqual(before,self.original())
        self.assertEqual(len(audit)+1,len(self.f.store.audit()))
        self.assertEqual('requires_review',self.jobs.status()['jobs'][0]['state'])
        with self.assertRaisesRegex(JobError,'NOT_CLAIMABLE'):
            self.f.authorize(self.offer)

    def test_only_distinct_fresh_rollback_can_follow_accepted_retirement(self):
        self.jobs.record_reconciliation(self.confirmed(),self.actor)
        old=json.loads(self.original())['jobs'];stage=self.offer['target']['stage_receipt']['stage_job_id']
        self.jobs.poll(self.f.proof());value=self.f.value(ROLLBACK,stage)
        self.f.enqueue(value);new=self.jobs.poll(self.f.proof())
        self.assertNotEqual(new['job_id'],self.offer['job_id'])
        self.assertEqual('requires_review',next(j for j in self.jobs.status()['jobs'] if j['id']==self.offer['job_id'])['state'])
        new_grant=self.f.authorize(new);self.assertNotEqual(self.grant['authorization_id'],new_grant['authorization_id'])
        self.assertEqual(old,json.loads(self.original())['jobs'][:-1])
        # A third job cannot bypass the new unretired successor.
        self.jobs.poll(self.f.proof())
        with self.assertRaisesRegex(JobError,'GPO_BUSY'):
            self.f.enqueue(self.f.value(ROLLBACK,stage))

    def test_unaccepted_or_different_stage_retirement_does_not_clear_busy(self):
        self.jobs.poll(self.f.proof());stage=self.offer['target']['stage_receipt']['stage_job_id']
        with self.assertRaisesRegex(JobError,'GPO_BUSY'):
            self.f.enqueue(self.f.value(ROLLBACK,stage))
        with self.f.store.connect() as db:
            ledger=self.jobs._read(db);target=copy.deepcopy(self.offer['target'])
            self.assertIs(ledger,rr.queue_ledger(self.jobs,db,ledger,target,STAGE,self.offer['scope_sha256']))
        self.jobs.record_reconciliation(self.confirmed(self.value|{'expected_revision':self.f.store.snapshot()['revision']}),self.actor)
        with self.f.store.connect() as db:
            ledger=self.jobs._read(db);target=copy.deepcopy(self.offer['target']);target['stage_receipt']['stage_job_id']=str(uuid.uuid4())
            self.assertEqual(ledger,rr.queue_ledger(self.jobs,db,ledger,target,ROLLBACK,self.offer['scope_sha256']))

    def test_wrong_key_or_signature_domain_cannot_retire(self):
        for wrong in (True,False):
            with self.subTest(wrong=wrong):
                value=copy.deepcopy(self.value);p=value['retirement'];body=p['completion']['Body']
                p['completion']=sign(self.f.other if wrong else self.f.private,body,
                    rr.COMPLETE_DOMAIN if wrong else rr.REVIEW_DOMAIN)
                with self.assertRaises(JobError):self.jobs.review_reconciliation(value,self.actor)

    def test_every_proof_component_rejects_byte_tampering(self):
        for component in ('review','observation','completion'):
            with self.subTest(component=component):
                v=copy.deepcopy(self.value);p=v['retirement']
                if component=='completion':p['completion']['Body']['original_records_sha256']='f'*64
                elif component=='review':p['review_record']['review']['Body']['baseline_sha256']='f'*64
                else:p['review_record']['observation']['body']['tree_sha256']='f'*64
                with self.assertRaises(JobError):self.jobs.review_reconciliation(v,self.actor)

    def test_validly_signed_semantic_changes_remain_rejected(self):
        changes=[('review','gpo_id',str(uuid.uuid4())),('review','stage_job_id',str(uuid.uuid4())),
                 ('review','binding_scope','a'*64),('review','tree_sha256','c'*64),
                 ('review','original_outcome','rolled_back'),('review','can_delete',True),
                 ('review','retain_gpo_lock',False),('review','expires_at',self.f.now+61),
                 ('closed','authority_renewed',True),('closed','original_unknown_result_preserved',False),
                 ('closed','closed_at',self.f.now+60),('ob','original_child_running',True),
                 ('ob','entered_marker_exists',True),('ob','active_release',str(uuid.uuid4())),
                 ('ob','tree_rows',True),('ob','at',self.grant['expires_at']-1)]
        for section,name,value in changes:
            with self.subTest(section=section,name=name):
                v=copy.deepcopy(self.value);p=v['retirement'];record=p['review_record']
                body=record['review']['Body'] if section=='review' else p['completion']['Body'] if section=='closed' else record['observation']['body']
                body[name]=value;resign(self.f.private,p)
                with self.assertRaises(JobError):self.jobs.review_reconciliation(v,self.actor)

    def test_ack_receipt_must_match_original_immutable_server_audit(self):
        for field in ('revision','decision'):
            v=copy.deepcopy(self.value);receipt=v['retirement']['review_record']['acknowledgement_receipt']
            receipt[field]=receipt[field]+1 if field=='revision' else 'keep_under_review'
            resign(self.f.private,v['retirement'])
            with self.assertRaises(JobError):self.jobs.review_reconciliation(v,self.actor)
        v=copy.deepcopy(self.value);req=v['retirement']['review_record']['acknowledgement_request'];req['review_hash']='f'*64
        resign(self.f.private,v['retirement'])
        with self.assertRaisesRegex(JobError,'ACK_AUDIT_REQUIRED'):self.jobs.review_reconciliation(v,self.actor)

    def test_different_current_reviewer_may_use_old_audited_ack_but_not_another_review(self):
        actor=str(uuid.uuid4());reviewed=self.confirmed(actor=actor)
        with self.assertRaisesRegex(JobError,'REVIEW_CHANGED'):
            self.jobs.record_reconciliation(reviewed,self.actor)
        self.assertTrue(self.jobs.record_reconciliation(reviewed,actor)['retirement_recorded'])
        with self.assertRaisesRegex(JobError,'CONFLICT'):
            self.jobs.record_reconciliation(reviewed,self.actor)

    def test_revision_and_review_hash_are_enforced(self):
        request=self.confirmed()
        with self.assertRaisesRegex(JobError,'REVIEW_CHANGED'):
            self.jobs.record_reconciliation(request|{'review_hash':'0'*64},self.actor)
        with self.assertRaises(ConflictError):
            self.jobs.review_reconciliation(self.value|{'expected_revision':0},self.actor)
        with self.assertRaises(JobError):
            self.jobs.record_reconciliation(request|{'acknowledge':'record_reconciliation_decision'},self.actor)

    def test_historical_proof_does_not_renew_local_or_grant_deadlines(self):
        self.f.now+=1000
        result=self.jobs.record_reconciliation(self.confirmed(),self.actor)
        self.assertTrue(result['retirement_recorded']);self.assertFalse(result['authority_renewed'])
        old=json.loads(self.original())['jobs'][-1]
        self.assertEqual(self.grant['expires_at'],old['authorized_until'])

    def test_corrupt_stored_retirement_fails_closed_before_queue_admission(self):
        self.jobs.record_reconciliation(self.confirmed(),self.actor)
        with self.f.store.connect() as db:
            saved=json.loads(db.execute('SELECT payload FROM runtime_settings WHERE name=?',(rr.SECTION,)).fetchone()[0])
            saved['records'][0]['request']['retirement']['completion']['Body']['gpo_lock_retained']=False
            db.execute('UPDATE runtime_settings SET payload=? WHERE name=?',(json.dumps(saved),rr.SECTION))
        self.jobs.poll(self.f.proof());stage=self.offer['target']['stage_receipt']['stage_job_id']
        with self.assertRaisesRegex(JobError,'RETIREMENT_STORE_INVALID'):
            self.f.enqueue(self.f.value(ROLLBACK,stage))

    def test_extra_fields_and_oversized_input_are_rejected(self):
        for value in (self.value|{'command':'delete'},self.value|{'expected_revision':True}):
            with self.assertRaises(JobError):self.jobs.review_reconciliation(value,self.actor)
        value=copy.deepcopy(self.value);value['retirement']['review_record']['observation']['body']['extra']='x'*17000
        with self.assertRaises(JobError):self.jobs.review_reconciliation(value,self.actor)


if __name__=='__main__':
    unittest.main()
