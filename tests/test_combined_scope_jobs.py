"""Real RSA/SQLite scope-job contract. No claim of a customer AD/GPO read."""
import copy
import json
import sqlite3
import unittest
import uuid
from unittest.mock import patch

from kaname.combined_jobs import CombinedJobs
from kaname.connector_jobs import JobError
from kaname.connector_registry import digest
from kaname.combined_scope_jobs import CombinedScopeJobs, SECTION, OPERATION, POLL_PATH, RESULT_PATH, CHECKS, target_sids_hash
from . import test_combined_jobs as content_fixtures
from . import test_connector_jobs as proof_fixtures
from . import test_deployment_candidates as candidates


def scope_catalog(group_sid,count=2):
    domain=group_sid.rsplit('-',1)[0]
    computers=[{'sid':domain+'-'+str(2000+n),'guid':str(uuid.uuid4()),
                'name':'PC'+str(n),'enabled':True} for n in range(count)]
    return {'membership_schema':1,'synced_at':'first','members':[], 'users':[],
            'groups':[{'sid':group_sid,'security_enabled':True,'unresolved_members':0}],
            'computers':computers,'memberships':[{'member_sid':c['sid'],'group_sid':group_sid,
                                               'type':'direct'} for c in computers]}


class CombinedScopeJobTests(unittest.TestCase):
    setUpClass=classmethod(candidates.CandidateTests.setUpClass.__func__)
    tearDownClass=classmethod(candidates.CandidateTests.tearDownClass.__func__)
    context=candidates.CandidateTests.context
    pem=staticmethod(candidates.CandidateTests.pem)
    intent=candidates.CandidateTests.intent
    prepare=candidates.CandidateTests.prepare
    pair=candidates.CandidateTests.pair
    request=candidates.CandidateTests.request
    save=candidates.CandidateTests.save
    binding=content_fixtures.CombinedJobTests.binding

    def setUp(self):
        candidates.CandidateTests.setUp(self);self.now=1800000000
        self.engine.clock=lambda:self.now
        self.data['catalog']=scope_catalog(self.data['plans'][0]['computer_group_sid'])
        _,network=self.save();self.network_identity=network['id']
        from .test_combined_candidate_registration import combined_receipt
        self.receipt=combined_receipt(self.data['plans'][0])
        _,r=self.save();self.identity=r['id']
        self.content=CombinedJobs(self.engine,wall_clock=lambda:self.now)
        self.jobs=self.content;self.verify_content()
        self.jobs=CombinedScopeJobs(self.engine,wall_clock=lambda:self.now)

    def verify_content(self,outcome='combined_content_verified'):
        raw=content_fixtures.CombinedJobTests.proof(self)
        self.content.poll(raw)
        v={'expected_revision':self.store.snapshot()['revision'],'candidate_id':self.identity,
           'job_id':str(uuid.uuid4()),'operation':'combined.verify.v1'}
        self.content.create(v|{'preview_hash':self.content.preview(v)['preview_hash']},self.actor)
        offer=self.content.poll(content_fixtures.CombinedJobTests.proof(self))
        result=content_fixtures.CombinedJobTests.result(self,offer,outcome=outcome)
        self.content.complete(content_fixtures.CombinedJobTests.proof(self,'RESULT',result))

    def proof(self,kind='POLL',body=None,**kwargs):
        if body is None:body={'capability':OPERATION,'release_id':str(uuid.uuid4())}
        changes={0:'AUTHWIRE-COMBINED-SCOPE-JOB-'+kind+'-V1',16:POLL_PATH if kind=='POLL' else RESULT_PATH}
        changes.update(kwargs.pop('changes',{}))
        return proof_fixtures.ConnectorJobTests.proof(self,kind,body,changes=changes,**kwargs)

    def request_job(self,**changes):
        return {'expected_revision':self.store.snapshot()['revision'],'candidate_id':self.identity,
                'operation':OPERATION,'job_id':str(uuid.uuid4())}|changes

    def create_job(self):
        self.jobs.poll(self.proof());v=self.request_job()
        body=v|{'preview_hash':self.jobs.preview(v)['preview_hash']}
        self.jobs.create(body,self.actor);return body

    def result(self,offer,**changes):
        return {'job_id':offer['job_id'],'lease_id':offer['lease_id'],'intent_sha256':offer['intent_sha256'],
                'outcome':'combined_scope_snapshot_verified','release_id':str(uuid.uuid4()),
                'target_sha256':digest(offer['target']),'checked_at':self.now,
                'checks':list(CHECKS),'reason':'OK','observations_sha256':'3'*64}|changes

    def finish(self,**changes):
        self.create_job();offer=self.jobs.poll(self.proof());v=self.result(offer,**changes)
        self.jobs.complete(self.proof('RESULT',v));return offer,v

    def test_success_is_an_expiring_read_snapshot_not_application_or_effective_write(self):
        with self.store.connect() as db:before=self.engine._read(db)
        self.finish();row=self.engine.status()['candidates'][0]
        self.assertTrue(row['scope_snapshot_verified']);self.assertTrue(row['scope_snapshot_fresh'])
        self.assertTrue(row['content_verified']);self.assertFalse(row['connector_verified']);self.assertFalse(row['can_apply'])
        with self.store.connect() as db:self.assertEqual(before,self.engine._read(db))
        self.now+=90;row=self.engine.status()['candidates'][0]
        self.assertTrue(row['scope_snapshot_verified']);self.assertFalse(row['scope_snapshot_fresh'])

    def test_snapshot_body_fits_existing_bounded_signed_protocol(self):
        self.create_job();offer=self.jobs.poll(self.proof());body=self.result(offer)
        self.assertLessEqual(len(json.dumps(body,separators=(',',':')).encode()),1024)
        self.jobs.complete(self.proof('RESULT',body))

    def test_separate_capability_and_content_acceptance_required(self):
        v=self.request_job();p=self.jobs.preview(v)
        with self.assertRaisesRegex(JobError,'WORKER_NOT_READY'):self.jobs.create(v|{'preview_hash':p['preview_hash']},self.actor)
        for raw in [content_fixtures.CombinedJobTests.proof(self),self.proof(body={}),
                    self.proof(body={'capability':'combined.verify.v1','release_id':str(uuid.uuid4())})]:
            with self.assertRaises(JobError):self.jobs.poll(raw)
        self.verify_content('combined_content_rejected')
        with self.assertRaisesRegex(JobError,'CONTENT_REQUIRED'):self.jobs.preview(self.request_job())

    def test_full_directory_set_is_hashed_beyond_twenty_item_display_sample(self):
        catalog=scope_catalog(self.data['plans'][0]['computer_group_sid'],200)
        self.data['catalog']=catalog
        # The old record correctly becomes obsolete when dependencies change.
        with self.assertRaises(JobError):self.jobs.preview(self.request_job())
        # Test this full-set calculation with a newly recorded current candidate.
        with self.store.connect() as db:db.execute("DELETE FROM runtime_settings WHERE name='windows_deployment_candidates'")
        from .test_deployment_candidates import make_receipt
        from .test_combined_candidate_registration import combined_receipt
        self.receipt=make_receipt(self.data['plans'][0]);self.save()
        self.receipt=combined_receipt(self.data['plans'][0]);_,r=self.save();self.identity=r['id'];self.verify_content()
        p=self.jobs.preview(self.request_job())
        self.assertEqual(200,p['target']['target_count'])
        self.assertEqual(target_sids_hash([c['sid'] for c in catalog['computers']]),p['target']['target_sids_sha256'])
        self.assertNotEqual(target_sids_hash([c['sid'] for c in catalog['computers'][:20]]),p['target']['target_sids_sha256'])

    def test_nested_and_primary_members_deduplicated_by_sid(self):
        group=self.data['catalog']['groups'][0]['sid'];nested=group.rsplit('-',1)[0]+'-3000'
        catalog=copy.deepcopy(self.data['catalog']);catalog['groups'].append({'sid':nested,'security_enabled':True,'unresolved_members':0})
        catalog['memberships'] += [{'member_sid':nested,'group_sid':group,'type':'direct'},
                                  {'member_sid':catalog['computers'][0]['sid'],'group_sid':nested,'type':'primary'}]
        from kaname.membership import related
        accounts,_=related(catalog,'groups',catalog['groups'][0])
        self.assertEqual(2,len([a for a in accounts if a['kind']=='computers']))

    def test_rejected_disabled_unresolved_oversized_and_missing_membership(self):
        for change in ('disabled','unresolved','oversized','missing'):
            with self.subTest(change=change):
                original=copy.deepcopy(self.data)
                if change=='disabled':self.data['catalog']['computers'][0]['enabled']=False
                if change=='unresolved':self.data['catalog']['groups'][0]['unresolved_members']=1
                if change=='oversized':self.data['catalog']=scope_catalog(self.data['plans'][0]['computer_group_sid'],513)
                if change=='missing':self.data['catalog'].pop('membership_schema')
                with self.assertRaises(JobError):self.jobs.preview(self.request_job())
                self.data=original

    def test_catalog_profile_binding_and_content_drift_invalidate_lease_and_snapshot(self):
        self.create_job();offer=self.jobs.poll(self.proof());original=copy.deepcopy(self.data)
        self.data['machine_profiles'][0]['version']+=1
        self.assertEqual('obsolete',self.jobs.status()['jobs'][0]['state'])
        with self.assertRaises(JobError):self.jobs.complete(self.proof('RESULT',self.result(offer)))
        self.data=original;self.verify_content('combined_content_rejected')
        self.assertEqual('obsolete',self.jobs.status()['jobs'][0]['state'])
        self.assertFalse(self.engine.status()['candidates'][0]['scope_snapshot_verified'])

    def test_harmless_timestamp_refresh_preserves_current_target(self):
        self.create_job();self.data['catalog']['synced_at']='later';offer=self.jobs.poll(self.proof())
        self.jobs.complete(self.proof('RESULT',self.result(offer)))
        self.assertTrue(self.engine.status()['candidates'][0]['scope_snapshot_fresh'])

    def test_outcomes_checks_times_and_overclaims_are_strict(self):
        self.create_job();offer=self.jobs.poll(self.proof());body=self.result(offer)
        for change in [{'checks':CHECKS[:-1]},{'checks':CHECKS+['gpo_applied']},{'checked_at':True},
                       {'checked_at':self.now-1},{'checked_at':self.now+91},{'reason':'UNKNOWN'},
                       {'outcome':'gpo_applied'},{'target_sha256':'0'*64},{'can_apply':True},
                       {'effective_write_access':True},{'observations_sha256':'bad'}]:
            with self.subTest(change=change),self.assertRaises(JobError):self.jobs.complete(self.proof('RESULT',body|change))
        self.jobs.complete(self.proof('RESULT',body))

    def test_signed_rejection_and_later_rejection_remove_displayed_success(self):
        self.finish();self.assertTrue(self.engine.status()['candidates'][0]['scope_snapshot_verified'])
        self.finish(outcome='combined_scope_snapshot_rejected',checks=[],reason='DIRECTORY_SCOPE_CHANGED')
        row=self.engine.status()['candidates'][0]
        self.assertFalse(row['scope_snapshot_verified']);self.assertTrue(row['content_verified'])
        self.assertEqual('DIRECTORY_SCOPE_CHANGED',row['scope_reason'])

    def test_replay_wrong_key_path_payload_and_expired_lease_fail_closed(self):
        self.create_job();raw=self.proof();offer=self.jobs.poll(raw)
        for proof in [raw,self.proof(private=self.other),self.proof(changes={16:'/api/connector/v1/candidates/poll'}),
                      self.proof(body={'capability':OPERATION,'release_id':str(uuid.uuid4()),'command':'whoami'})]:
            with self.assertRaises(JobError):self.jobs.poll(proof)
        self.now+=90
        with self.assertRaises(JobError):self.jobs.complete(self.proof('RESULT',self.result(offer)))

    def test_idempotent_create_result_and_conflicts_are_not_requeued(self):
        request=self.create_job();audit=self.store.audit();self.jobs.create(request,self.actor)
        self.assertEqual(audit,self.store.audit())
        offer=self.jobs.poll(self.proof());body=self.result(offer);raw=self.proof('RESULT',body)
        self.jobs.complete(raw);audit=self.store.audit();self.jobs.complete(raw)
        self.assertEqual(audit,self.store.audit())
        with self.assertRaisesRegex(JobError,'RESULT_CONFLICT'):
            self.jobs.complete(self.proof('RESULT',body|{'observations_sha256':'4'*64}))

    def test_transaction_audit_failure_rolls_back_and_corrupt_ledger_fails_closed(self):
        self.create_job();offer=self.jobs.poll(self.proof())
        with patch.object(self.ops,'_audit',side_effect=sqlite3.OperationalError('unavailable')):
            with self.assertRaises(sqlite3.Error):self.jobs.complete(self.proof('RESULT',self.result(offer)))
        self.assertEqual('leased',self.jobs.status()['jobs'][0]['state'])
        with self.store.connect() as db:db.execute('UPDATE runtime_settings SET payload=? WHERE name=?',('{}',SECTION))
        with self.assertRaisesRegex(JobError,'STORE_INVALID'):self.engine.status()

    def test_queue_limit_and_single_current_job_are_enforced(self):
        self.create_job();v=self.request_job();p=self.jobs.preview(v)
        with self.assertRaisesRegex(JobError,'BUSY'):self.jobs.create(v|{'preview_hash':p['preview_hash']},self.actor)

    def test_expired_capability_cannot_create_a_job(self):
        self.jobs.poll(self.proof());v=self.request_job();p=self.jobs.preview(v)
        self.now+=90
        with self.assertRaisesRegex(JobError,'WORKER_NOT_READY'):
            self.jobs.create(v|{'preview_hash':p['preview_hash']},self.actor)
        self.assertEqual([],self.jobs.status()['jobs'])

    def test_revocation_invalidates_completed_snapshot_and_fresh_capability(self):
        self.finish();self.assertTrue(self.engine.status()['candidates'][0]['scope_snapshot_verified'])
        self.registry.apply(self.prepare(self.intent('revoke')),self.actor)
        status=self.engine.status()
        self.assertFalse(status['combined_scope_worker_ready']);self.assertFalse(status['candidates'][0]['scope_snapshot_verified'])
        self.assertEqual('obsolete',status['combined_scope_verification_jobs'][0]['state'])


    def test_new_positive_content_result_invalidates_prior_scope_lease(self):
        self.create_job();offer=self.jobs.poll(self.proof())
        before=offer['target']['content_result_sha256'];self.verify_content()
        self.assertEqual('obsolete',self.jobs.status()['jobs'][0]['state'])
        with self.assertRaises(JobError):self.jobs.complete(self.proof('RESULT',self.result(offer)))
        self.assertNotEqual(before,self.jobs.preview(self.request_job())['target']['content_result_sha256'])

    def test_network_record_and_old_scope_proof_cannot_authorize_combined_scope(self):
        from kaname.scope_jobs import ScopeJobs
        from . import test_scope_jobs as old
        with self.assertRaises(JobError):self.jobs.preview(self.request_job(candidate_id=self.network_identity))
        with self.assertRaises(JobError):self.jobs.poll(old.ScopeJobTests.proof(self))
        with self.assertRaises(JobError):ScopeJobs(self.engine,wall_clock=lambda:self.now).preview(self.request_job(operation='deployment.scope.verify.v1'))
