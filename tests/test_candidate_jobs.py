"""Real SQLite/RSA lifecycle; operator data never becomes GPO authority."""
import copy
import json
import sqlite3
import uuid
import unittest
from unittest.mock import patch
from kaname.candidate_jobs import CandidateJobs, SECTION, OPERATION, POLL_PATH, RESULT_PATH
from kaname.connector_jobs import JobError, ConnectorJobs
from kaname.connector_registry import digest
from . import test_deployment_candidates as cf
from . import test_connector_jobs as jf


class CandidateJobTests(unittest.TestCase):
    setUpClass=classmethod(cf.CandidateTests.setUpClass.__func__)
    tearDownClass=classmethod(cf.CandidateTests.tearDownClass.__func__)
    context=cf.CandidateTests.context
    pem=staticmethod(cf.CandidateTests.pem)
    intent=cf.CandidateTests.intent
    prepare=cf.CandidateTests.prepare
    pair=cf.CandidateTests.pair
    request=cf.CandidateTests.request
    save=cf.CandidateTests.save
    def setUp(self):
        cf.CandidateTests.setUp(self);self.now=1800000000
        _,r=self.save();self.identity=r['id']
        self.jobs=CandidateJobs(self.engine,wall_clock=lambda:self.now)

    def binding(self):
        with self.store.connect() as db:return self.jobs._binding(db)

    def proof(self,kind='POLL',body=None,**kwargs):
        if body is None:body={'capability':OPERATION,'release_id':str(uuid.uuid4())}
        changes={0:'AUTHWIRE-CANDIDATE-JOB-'+kind+'-V1',16:POLL_PATH if kind=='POLL' else RESULT_PATH}
        changes.update(kwargs.pop('changes',{}))
        return jf.ConnectorJobTests.proof(self,kind,body,changes=changes,**kwargs)

    def request_job(self,**changes):
        return {'expected_revision':self.store.snapshot()['revision'],'candidate_id':self.identity,
                'operation':OPERATION,'job_id':str(uuid.uuid4())}|changes

    def create_job(self):
        self.jobs.poll(self.proof());v=self.request_job()
        body=v|{'preview_hash':self.jobs.preview(v)['preview_hash']}
        self.jobs.create(body,self.actor);return body

    def result(self,o,**changes):
        return {'job_id':o['job_id'],'lease_id':o['lease_id'],'intent_sha256':o['intent_sha256'],
                'outcome':'content_verified','release_id':str(uuid.uuid4()),'target_sha256':digest(o['target'])}|changes

    def test_content_roundtrip_preserves_operator_receipt_and_does_not_grant_apply(self):
        with self.store.connect() as db:before=self.engine._read(db)
        self.create_job();o=self.jobs.poll(self.proof());b=self.result(o)
        self.jobs.complete(self.proof('RESULT',b));audit=self.store.audit()
        restarted=CandidateJobs(self.engine,wall_clock=lambda:self.now)
        restarted.complete(self.proof('RESULT',b));self.assertEqual(audit,self.store.audit())
        c=self.engine.status()['candidates'][0]
        self.assertTrue(c['content_verified']);self.assertEqual('content_verified',c['state'])
        self.assertFalse(c['connector_verified']);self.assertFalse(c['can_apply'])
        with self.store.connect() as db:self.assertEqual(before,self.engine._read(db))

    def test_probe_only_worker_cannot_receive_candidate_and_missing_capability_cannot_create(self):
        v=self.request_job();p=self.jobs.preview(v)
        with self.assertRaisesRegex(JobError,'WORKER_NOT_READY'):self.jobs.create(v|{'preview_hash':p['preview_hash']},self.actor)
        for raw in [jf.ConnectorJobTests.proof(self),self.proof(body={}),self.proof(body={'capability':'candidate.verify.v2','release_id':str(uuid.uuid4())})]:
            with self.assertRaises(JobError):self.jobs.poll(raw)
        self.assertEqual('',ConnectorJobs(self.registry,wall_clock=lambda:self.now).poll(jf.ConnectorJobTests.proof(self))['job_id'])

    def test_wrong_purpose_key_method_and_payload_cannot_write(self):
        self.create_job();before=self.jobs.status()
        for raw in [self.proof(private=self.other),self.proof(changes={16:'/api/connector/v1/jobs/poll'}),
                    self.proof(changes={15:'GET'}),self.proof(payload=b'{"capability":"x","capability":"y"}'),
                    self.proof(body={'capability':OPERATION,'release_id':str(uuid.uuid4()),'command':'whoami'})]:
            with self.assertRaises(JobError):self.jobs.poll(raw)
        self.assertEqual(before,self.jobs.status())

    def test_scope_change_before_lease_or_result_and_status_invalidates(self):
        self.create_job();o=self.jobs.poll(self.proof());self.data['catalog']['members'].append('changed')
        self.assertEqual('',self.jobs.poll(self.proof())['job_id'])
        with self.assertRaises(JobError):self.jobs.complete(self.proof('RESULT',self.result(o)))
        self.assertEqual('obsolete',self.jobs.status()['jobs'][0]['state'])
        self.assertEqual('outdated',self.engine.status()['candidates'][0]['state'])

    def test_harmless_directory_timestamp_refresh_is_allowed(self):
        self.create_job();self.data['catalog']['synced_at']='later';o=self.jobs.poll(self.proof())
        self.jobs.complete(self.proof('RESULT',self.result(o)))
        self.assertTrue(self.engine.status()['candidates'][0]['content_verified'])

    def test_overclaims_wrong_target_and_conflicting_result_are_refused(self):
        self.create_job();o=self.jobs.poll(self.proof());b=self.result(o)
        for delta in [{'can_apply':True},{'gpo_state_checked':True},{'outcome':'gpo_applied'},{'target_sha256':'0'*64},{'release_id':True}]:
            with self.assertRaises(JobError):self.jobs.complete(self.proof('RESULT',b|delta))
        self.jobs.complete(self.proof('RESULT',b))
        with self.assertRaisesRegex(JobError,'RESULT_CONFLICT'):self.jobs.complete(self.proof('RESULT',b|{'outcome':'content_rejected'}))

    def test_later_rejection_replaces_displayed_content_success_but_not_receipt(self):
        self.create_job();o=self.jobs.poll(self.proof());self.jobs.complete(self.proof('RESULT',self.result(o)))
        self.assertTrue(self.engine.status()['candidates'][0]['content_verified'])
        self.create_job();o=self.jobs.poll(self.proof());self.jobs.complete(self.proof('RESULT',self.result(o,outcome='content_rejected')))
        self.assertFalse(self.engine.status()['candidates'][0]['content_verified'])

    def test_lost_create_reply_reconciles_without_duplicate_or_requeue(self):
        b=self.create_job();audit=self.store.audit();self.jobs.create(b,self.actor)
        self.assertEqual(audit,self.store.audit());self.assertEqual(1,len(self.jobs.status()['jobs']))
        with self.assertRaisesRegex(JobError,'ID_CONFLICT'):self.jobs.create(b|{'candidate_id':str(uuid.uuid4())},self.actor)

    def test_replay_expiry_and_old_lease_rejected(self):
        self.create_job();raw=self.proof();o=self.jobs.poll(raw)
        with self.assertRaises(JobError):self.jobs.poll(raw)
        self.now+=90;self.assertEqual('',self.jobs.poll(self.proof())['job_id'])
        with self.assertRaises(JobError):self.jobs.complete(self.proof('RESULT',self.result(o)))

    def test_atomic_audit_failure_rolls_back_result(self):
        self.create_job();o=self.jobs.poll(self.proof())
        with patch.object(self.ops,'_audit',side_effect=sqlite3.OperationalError('unavailable')):
            with self.assertRaises(sqlite3.Error):self.jobs.complete(self.proof('RESULT',self.result(o)))
        self.assertEqual('leased',self.jobs.status()['jobs'][0]['state'])
        self.assertFalse(self.engine.status()['candidates'][0]['content_verified'])

    def test_rotated_or_revoked_binding_rejects_queued_work(self):
        self.create_job();binding=self.binding();o=self.jobs.poll(self.proof())
        raw=self.proof('RESULT',self.result(o));self.registry.apply(self.prepare(self.intent('revoke')),self.actor)
        with self.assertRaises(JobError):self.jobs.complete(raw)
        self.assertFalse(self.engine.status()['candidates'][0]['content_verified'])

    def test_corrupt_ledger_fails_closed_in_candidate_status(self):
        with self.store.connect() as db:db.execute('INSERT INTO runtime_settings VALUES (?,?)',(SECTION,'{}'))
        with self.assertRaisesRegex(JobError,'STORE_INVALID'):self.engine.status()
