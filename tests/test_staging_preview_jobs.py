"""RSA/SQLite staging proposals remain readonly and bound to current dependencies."""
import copy
import json
import sqlite3
import unittest
import uuid
from unittest.mock import patch
from kaname.staging_preview_jobs import (StagingPreviewJobs, OPERATION, POLL_PATH,
    RESULT_PATH, SECTION, FILES, ordered_json, preview_hash, preview_valid)
from kaname.connector_jobs import JobError, sha, verify_job_proof
from kaname.connector_registry import digest
from . import test_combined_scope_jobs as sf
from . import test_connector_jobs as proofs


def proposal(target,checked):
    rows=[]
    for name in FILES:
        pin=target['manifest_sha256'] if name=='signed-manifest.json' else target['draft_sha256'] if name=='original-draft.zip' else sha(name.encode())
        rows.append({'Path':name,'Size':31,'Sha256':pin,'Sddl':'O:BAG:BAD:P(A;;FA;;;SY)(A;;FA;;;BA)'})
    relative='Machine/AuthWire-'+target['plan_id'].replace('-','')+'-v'+str(target['plan_version'])+'-'+target['manifest_sha256']
    return {'format':'AuthWireCombinedStagingPreviewV1','operation':'combined.stage.preview.v1',
      'scope_target_sha256':digest(target),'scope_observations_sha256':'3'*64,
      'baseline_inventory_sha256':'4'*64,'source_ledger_sha256':sha(ordered_json(rows)),
      **{n:target[n] for n in ('plan_id','plan_version','gpo_id','manifest_sha256','draft_sha256')},
      'relative_destination':relative,'files':rows,'file_count':20,'total_bytes':620,
      'checked_at':checked,'expires_at':checked+90,
      'rollback':{'relative_directory':relative,'requires_ownership_journal':True,
       'requires_exact_staged_tree':True,'drift_requires_review':True,'delete_existing_data':False},
      'read_only':True,'can_stage':False,'can_apply_gpo':False,'writer_available':False,
      'requires_new_write_approval':True}


class StagingPreviewJobTests(unittest.TestCase):
    setUpClass=classmethod(sf.CombinedScopeJobTests.setUpClass.__func__)
    tearDownClass=classmethod(sf.CombinedScopeJobTests.tearDownClass.__func__)
    context=sf.CombinedScopeJobTests.context
    pem=staticmethod(sf.CombinedScopeJobTests.pem)
    intent=sf.CombinedScopeJobTests.intent
    prepare=sf.CombinedScopeJobTests.prepare
    pair=sf.CombinedScopeJobTests.pair
    request=sf.CombinedScopeJobTests.request
    save=sf.CombinedScopeJobTests.save
    binding=sf.CombinedScopeJobTests.binding
    verify_content=sf.CombinedScopeJobTests.verify_content
    def setUp(self):
        sf.CombinedScopeJobTests.setUp(self)
        self.jobs=StagingPreviewJobs(self.engine,wall_clock=lambda:self.now)
    def proof(self,kind='POLL',body=None,**kwargs):
        if body is None:body={'capability':OPERATION,'release_id':str(uuid.uuid4())}
        changes={0:'AUTHWIRE-STAGING-PREVIEW-JOB-'+kind+'-V1',16:POLL_PATH if kind=='POLL' else RESULT_PATH}
        changes.update(kwargs.pop('changes',{}))
        return proofs.ConnectorJobTests.proof(self,kind,body,changes=changes,**kwargs)
    def request_job(self,**changes):
        return {'expected_revision':self.store.snapshot()['revision'],'candidate_id':self.identity,
                'operation':OPERATION,'job_id':str(uuid.uuid4())}|changes
    create_job=sf.CombinedScopeJobTests.create_job
    def result(self,o,**changes):
        p=proposal(o['target'],self.now)
        return {'job_id':o['job_id'],'lease_id':o['lease_id'],'intent_sha256':o['intent_sha256'],
            'outcome':'staging_preview_verified','release_id':str(uuid.uuid4()),'target_sha256':digest(o['target']),
            'checked_at':self.now,'reason':'OK','preview':p,'preview_sha256':preview_hash(p)}|changes
    def finish(self):
        self.create_job();o=self.jobs.poll(self.proof());v=self.result(o)
        self.jobs.complete(self.proof('RESULT',v));return o,v
    def test_success_returns_exact_files_without_application_or_business_mutation(self):
        with self.store.connect() as db:before=self.engine._read(db)
        self.finish();row=self.engine.status()['candidates'][0]
        self.assertTrue(row['staging_preview_verified']);self.assertTrue(row['staging_preview_fresh'])
        p=row['staging_preview'];self.assertEqual(list(FILES),[r['Path'] for r in p['files']])
        self.assertFalse(p['can_stage']);self.assertFalse(p['can_apply_gpo']);self.assertFalse(p['writer_available'])
        self.assertFalse(row['connector_verified']);self.assertFalse(row['can_apply'])
        with self.store.connect() as db:self.assertEqual(before,self.engine._read(db))
        self.now+=90;self.assertFalse(self.engine.status()['candidates'][0]['staging_preview_fresh'])
    def test_only_new_result_protocol_accepts_larger_bounded_preview(self):
        self.create_job();o=self.jobs.poll(self.proof());v=self.result(o);raw=self.proof('RESULT',v)
        self.assertGreater(len(ordered_json(v)),1024)
        self.assertLessEqual(len(raw),32768)
        with self.assertRaises(JobError):verify_job_proof(raw,self.binding(),'RESULT',lambda:self.now)
        self.jobs.complete(raw)
    def test_canonical_hash_is_independent_of_persisted_object_key_order(self):
        self.create_job();o=self.jobs.poll(self.proof());v=self.result(o)
        h=v['preview_sha256'];v=json.loads(json.dumps(v,sort_keys=True))
        self.assertEqual(h,preview_hash(v['preview']));self.jobs.complete(self.proof('RESULT',v))
    def test_authority_wrong_path_missing_files_hashes_sizes_and_rollback_overclaims_refused(self):
        self.create_job();o=self.jobs.poll(self.proof());base=self.result(o)
        mutations=[lambda p:p.update(can_stage=True),lambda p:p.update(can_apply_gpo=True),
            lambda p:p.update(writer_available=True),lambda p:p.update(read_only=1),
            lambda p:p.update(relative_destination='../../other'),lambda p:p['files'].pop(),
            lambda p:p['files'][0].update(Path='enrollment/config.json:secret'),
            lambda p:p['files'][0].update(Size=True),lambda p:p['files'][0].update(Size=1048577),
            lambda p:p['files'][0].update(Sha256='0'*64),lambda p:p['rollback'].update(delete_existing_data=True),
            lambda p:p['rollback'].update(drift_requires_review=False),lambda p:p.update(expires_at=self.now+91),
            lambda p:p.update(scope_target_sha256='0'*64),lambda p:p.update(extra='command')]
        for mutation in mutations:
            v=copy.deepcopy(base);mutation(v['preview'])
            try:v['preview_sha256']=preview_hash(v['preview'])
            except (KeyError,TypeError):pass
            with self.subTest(mutation=mutation),self.assertRaises(JobError):self.jobs.complete(self.proof('RESULT',v))
        self.jobs.complete(self.proof('RESULT',base))
    def test_replay_scope_payload_and_key_binding_are_not_shared_with_old_jobs(self):
        raw=self.proof();self.jobs.poll(raw)
        for wrong in (raw,self.proof(private=self.other),sf.CombinedScopeJobTests.proof(self),
                self.proof(body={'capability':OPERATION,'release_id':str(uuid.uuid4()),'path':'C:\\evil'})):
            with self.assertRaises(JobError):self.jobs.poll(wrong)
    def test_idempotent_result_conflict_lease_expiry_and_revocation(self):
        request=self.create_job();self.jobs.create(request,self.actor)
        o=self.jobs.poll(self.proof());v=self.result(o);raw=self.proof('RESULT',v)
        self.jobs.complete(raw);audit=self.store.audit();self.jobs.complete(raw);self.assertEqual(audit,self.store.audit())
        changed=copy.deepcopy(v);changed['preview']['scope_observations_sha256']='5'*64;changed['preview_sha256']=preview_hash(changed['preview'])
        with self.assertRaisesRegex(JobError,'RESULT_CONFLICT'):self.jobs.complete(self.proof('RESULT',changed))
        self.registry.apply(self.prepare(self.intent('revoke')),self.actor)
        self.assertFalse(self.engine.status()['staging_preview_worker_ready'])
        self.assertFalse(self.engine.status()['candidates'][0]['staging_preview_verified'])
    def test_dependency_drift_rejects_result_and_obsoletes_record(self):
        self.create_job();o=self.jobs.poll(self.proof());v=self.result(o)
        self.data['machine_profiles'][0]['version']+=1
        self.assertEqual('obsolete',self.jobs.status()['jobs'][0]['state'])
        with self.assertRaises(JobError):self.jobs.complete(self.proof('RESULT',v))
    def test_rejection_clears_preview_and_transaction_failure_is_atomic(self):
        self.create_job();o=self.jobs.poll(self.proof());v=self.result(o,outcome='staging_preview_rejected',reason='READ_FAILED',preview=None,preview_sha256='')
        with patch.object(self.ops,'_audit',side_effect=sqlite3.OperationalError('fixture')):
            with self.assertRaises(sqlite3.Error):self.jobs.complete(self.proof('RESULT',v))
        self.assertEqual('leased',self.jobs.status()['jobs'][0]['state'])
        self.jobs.complete(self.proof('RESULT',v));row=self.engine.status()['candidates'][0]
        self.assertFalse(row['staging_preview_verified']);self.assertIsNone(row['staging_preview']);self.assertEqual('READ_FAILED',row['staging_preview_reason'])
    def test_corrupt_ledger_is_not_treated_as_unavailable_worker(self):
        self.jobs.poll(self.proof())
        with self.store.connect() as db:db.execute('UPDATE runtime_settings SET payload=? WHERE name=?',('{}',SECTION))
        with self.assertRaisesRegex(JobError,'STORE_INVALID'):self.engine.status()
    def test_expired_worker_and_active_job_guards(self):
        self.jobs.poll(self.proof());v=self.request_job();p=self.jobs.preview(v);self.now+=90
        with self.assertRaisesRegex(JobError,'WORKER_NOT_READY'):self.jobs.create(v|{'preview_hash':p['preview_hash']},self.actor)
        self.create_job();v=self.request_job();p=self.jobs.preview(v)
        with self.assertRaisesRegex(JobError,'BUSY'):self.jobs.create(v|{'preview_hash':p['preview_hash']},self.actor)
    def test_large_valid_ledger_keeps_backup_poll_projection_but_not_result_changes(self):
        from tools.scheduled_backup import stable_runtime_payload
        for _ in range(16):self.finish()
        with self.store.connect() as db:raw=db.execute('SELECT payload FROM runtime_settings WHERE name=?',(SECTION,)).fetchone()[0]
        self.assertGreater(len(raw),100000)
        value=json.loads(raw);before=stable_runtime_payload(SECTION,raw)
        value['polls']=[];value['last_poll']=None
        self.assertEqual(before,stable_runtime_payload(SECTION,json.dumps(value)))
        value['jobs'][0]['result']['preview']['files'][0]['Sha256']='0'*64
        self.assertNotEqual(before,stable_runtime_payload(SECTION,json.dumps(value)))
