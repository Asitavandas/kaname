"""Real SQLite/RSA write intents; no HTTP registration or filesystem mutation."""
import concurrent.futures
import copy
import json
import sqlite3
import unittest
import uuid
from unittest.mock import patch

from kaname.connector_jobs import JobError, scope_id
from kaname.connector_registry import digest
from kaname.store import ConflictError
from kaname.staging_write_jobs import (StagingWriteJobs, SECTION, STAGE, ROLLBACK,
    CAPABILITY, ACK, POLL_PATH, CLAIM_PATH, RESULT_PATH, RESULT_GRACE, target_valid)
from . import test_staging_preview_jobs as pf
from . import test_connector_jobs as proofs


class StagingWriteJobTests(unittest.TestCase):
    setUpClass = classmethod(pf.StagingPreviewJobTests.setUpClass.__func__)
    tearDownClass = classmethod(pf.StagingPreviewJobTests.tearDownClass.__func__)
    context = pf.StagingPreviewJobTests.context
    pem = staticmethod(pf.StagingPreviewJobTests.pem)
    intent = pf.StagingPreviewJobTests.intent
    prepare = pf.StagingPreviewJobTests.prepare
    pair = pf.StagingPreviewJobTests.pair
    request = pf.StagingPreviewJobTests.request
    save = pf.StagingPreviewJobTests.save
    binding = pf.StagingPreviewJobTests.binding
    verify_content = pf.StagingPreviewJobTests.verify_content

    def setUp(self):
        pf.StagingPreviewJobTests.setUp(self)
        self.preview_jobs = self.jobs
        self.refresh_preview()
        self.jobs = StagingWriteJobs(self.engine, wall_clock=lambda: self.now)
        self.release = str(uuid.uuid4())

    def refresh_preview(self):
        jobs = self.preview_jobs
        jobs.poll(pf.StagingPreviewJobTests.proof(self))
        v = pf.StagingPreviewJobTests.request_job(self)
        jobs.create(v | {'preview_hash': jobs.preview(v)['preview_hash']}, self.actor)
        offer = jobs.poll(pf.StagingPreviewJobTests.proof(self))
        result = pf.StagingPreviewJobTests.result(self, offer)
        jobs.complete(pf.StagingPreviewJobTests.proof(self, 'RESULT', result))
        self.preview_result = result

    def proof(self, kind='POLL', body=None, **kwargs):
        if body is None:
            body = {'capability': CAPABILITY, 'release_id': self.release}
        paths = {'POLL': POLL_PATH, 'CLAIM': CLAIM_PATH, 'RESULT': RESULT_PATH}
        changes = {0: 'AUTHWIRE-STAGING-WRITE-JOB-' + kind + '-V1', 16: paths[kind]}
        changes.update(kwargs.pop('changes', {}))
        return proofs.ConnectorJobTests.proof(self, kind, body, changes=changes, **kwargs)

    def value(self, operation=STAGE, stage_id='', **changes):
        return {'expected_revision': self.store.snapshot()['revision'], 'job_id': str(uuid.uuid4()),
                'operation': operation, 'candidate_id': self.identity, 'stage_job_id': stage_id,
                'staging_preview_sha256': self.preview_result['preview_sha256'],
                'acknowledge': ACK[operation]} | changes

    def enqueue(self, value=None):
        self.jobs.poll(self.proof())
        v = value or self.value()
        v = v | {'review_hash': self.jobs.review(v, self.actor)['review_hash']}
        self.jobs.create(v, self.actor)
        return v

    def offer(self):
        self.enqueue()
        return self.jobs.poll(self.proof())

    def claim_body(self, offer, **changes):
        return {'job_id': offer['job_id'], 'lease_id': offer['lease_id'],
                'intent_sha256': offer['intent_sha256'], 'target_sha256': digest(offer['target']),
                'release_id': self.release} | changes

    def authorize(self, offer):
        return self.jobs.claim(self.proof('CLAIM', self.claim_body(offer)))

    def result(self, offer, authorization=None, **changes):
        rollback = offer['operation'] == ROLLBACK
        return {'job_id': offer['job_id'], 'lease_id': offer['lease_id'],
                'intent_sha256': offer['intent_sha256'], 'target_sha256': digest(offer['target']),
                'release_id': self.release, 'authorization_id': authorization['authorization_id'] if authorization else '',
                'checked_at': self.now, 'outcome': 'rolled_back' if rollback else 'staged', 'reason': 'OK',
                'journal_sha256': 'a' * 64,
                'tree_sha256': offer['target']['stage_receipt']['staged_tree_sha256'] if rollback else 'b' * 64,
                'filesystem_effects': 'removed_owned_directory' if rollback else 'created_owned_directory'} | changes

    def finish_stage(self):
        offer = self.offer(); authorization = self.authorize(offer)
        result = self.result(offer, authorization)
        self.jobs.complete(self.proof('RESULT', result))
        return offer, authorization, result

    def test_review_is_readonly_actor_bound_and_never_gpo_activation(self):
        self.jobs.poll(self.proof()); before = self.store.snapshot(); audit = self.store.audit()
        v = self.value(); a = self.jobs.review(v, self.actor)
        self.assertFalse(a['read_only']); self.assertFalse(a['can_apply_gpo'])
        self.assertTrue(target_valid(a['target'], STAGE))
        self.assertEqual(self.preview_result['preview'], a['target']['preview_record']['Preview'])
        self.assertNotEqual(a['review_hash'], self.jobs.review(v, str(uuid.uuid4()))['review_hash'])
        self.assertEqual(before, self.store.snapshot()); self.assertEqual(audit, self.store.audit())
        self.assertFalse(self.jobs.status()['execution_adapter_available'])

    def test_exact_create_is_idempotent_but_actor_request_or_scope_change_conflicts(self):
        v = self.enqueue(); audit = self.store.audit()
        self.assertTrue(self.jobs.create(v, self.actor)['recorded'])
        self.assertEqual(audit, self.store.audit())
        for changed, actor in ((v | {'candidate_id': str(uuid.uuid4())}, self.actor),
                               (v, str(uuid.uuid4()))):
            with self.assertRaisesRegex(JobError, 'ID_CONFLICT'):
                self.jobs.create(changed, actor)

    def test_revision_conflict_and_cross_actor_review_do_not_enqueue(self):
        self.jobs.poll(self.proof()); v = self.value()
        review = self.jobs.review(v, self.actor)
        with self.assertRaisesRegex(JobError, 'REVIEW_CHANGED'):
            self.jobs.create(v | {'review_hash': review['review_hash']}, str(uuid.uuid4()))
        stale = v | {'expected_revision': v['expected_revision'] - 1}
        with self.assertRaises(ConflictError):
            self.jobs.review(stale, self.actor)
        self.assertEqual([], self.jobs.status()['jobs'])

    def test_ack_operation_and_arbitrary_paths_are_closed(self):
        self.jobs.poll(self.proof())
        variants = ({'acknowledge': True}, {'acknowledge': ACK[ROLLBACK]},
                    {'operation': 'powershell.execute'}, {'command': 'whoami'},
                    {'destination': 'C:\\Windows'}, {'stage_job_id': str(uuid.uuid4())})
        for change in variants:
            with self.subTest(change=change), self.assertRaises(ValueError):
                self.jobs.review(self.value() | change, self.actor)

    def test_read_preview_never_promotes_itself_to_write_authorization(self):
        self.jobs.poll(self.proof()); v = self.value()
        with self.assertRaisesRegex(JobError, 'REVIEW_CHANGED'):
            self.jobs.create(v | {'review_hash': self.preview_result['preview_sha256']}, self.actor)
        offer = self.offer()
        self.assertFalse(offer['write_authorized']); self.assertFalse(offer['can_apply_gpo'])
        with self.assertRaises(JobError):
            self.jobs.complete(self.proof('RESULT', self.result(offer)))

    def test_worker_and_preview_freshness_are_separate(self):
        with self.assertRaisesRegex(JobError, 'WORKER_NOT_READY'):
            self.jobs.review(self.value(), self.actor)
        self.jobs.poll(self.proof()); self.now += 90
        self.jobs.poll(self.proof())
        with self.assertRaisesRegex(JobError, 'PREVIEW_EXPIRED'):
            self.jobs.review(self.value(), self.actor)
        self.refresh_preview(); self.jobs.poll(self.proof())
        self.assertIn('review_hash', self.jobs.review(self.value(), self.actor))

    def test_wrong_key_purpose_path_and_replayed_poll_are_rejected(self):
        good = self.proof(); self.jobs.poll(good)
        wrong = (good, self.proof(private=self.other), pf.StagingPreviewJobTests.proof(self),
                 self.proof(changes={16: RESULT_PATH}), self.proof(body={'capability': CAPABILITY,
                 'release_id': self.release, 'command': 'x'}))
        for raw in wrong:
            with self.subTest(raw=raw[:40]), self.assertRaises(JobError):
                self.jobs.poll(raw)

    def test_lease_is_offered_once_and_never_released_after_lost_reply(self):
        offer = self.offer()
        self.assertTrue(offer['job_id'])
        self.assertEqual('', self.jobs.poll(self.proof())['job_id'])
        self.now = offer['expires_at']
        self.assertEqual('', self.jobs.poll(self.proof())['job_id'])
        with self.assertRaisesRegex(JobError, 'NOT_CLAIMABLE'):
            self.authorize(offer)
        self.assertEqual('expired', self.jobs.status()['jobs'][0]['state'])

    def test_approval_pins_worker_release_and_candidate_dependencies(self):
        self.enqueue(); old = self.release; self.release = str(uuid.uuid4())
        self.assertEqual('', self.jobs.poll(self.proof())['job_id'])
        self.release = old; offer = self.jobs.poll(self.proof())
        for field in ('lease_id', 'intent_sha256', 'target_sha256', 'release_id'):
            change = str(uuid.uuid4()) if field == 'release_id' else '0' * 64
            with self.subTest(field=field), self.assertRaisesRegex(JobError, 'CLAIM_CHANGED'):
                self.jobs.claim(self.proof('CLAIM', self.claim_body(offer, **{field: change})))
        self.data['machine_profiles'][0]['version'] += 1
        with self.assertRaisesRegex(JobError, 'CLAIM_CHANGED'):
            self.authorize(offer)

    def test_claim_is_single_use_and_duplicate_claim_never_returns_a_write_grant(self):
        offer = self.offer(); raw = self.proof('CLAIM', self.claim_body(offer))
        result = self.jobs.claim(raw)
        self.assertTrue(result['write_authorized']); self.assertFalse(result['can_apply_gpo'])
        self.assertLessEqual(result['expires_at'] - self.now, 30)
        for retry in (raw, self.proof('CLAIM', self.claim_body(offer))):
            with self.assertRaisesRegex(JobError, 'NOT_CLAIMABLE'):
                self.jobs.claim(retry)

    def test_concurrent_claims_have_only_one_authorization(self):
        offer = self.offer()
        bodies = [self.proof('CLAIM', self.claim_body(offer)) for _ in range(2)]
        def claim(raw):
            try:
                return self.jobs.claim(raw)['write_authorized']
            except JobError:
                return False
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            self.assertEqual([False, True], sorted(pool.map(claim, bodies)))

    def test_claim_response_loss_and_timeout_hold_gpo_lock(self):
        offer = self.offer(); self.authorize(offer)  # caller intentionally loses response
        self.now += 100; self.refresh_preview(); self.jobs.poll(self.proof())
        self.assertEqual('requires_review', self.jobs.status()['jobs'][0]['state'])
        with self.assertRaisesRegex(JobError, 'GPO_BUSY'):
            self.enqueue()
        self.assertEqual('', self.jobs.poll(self.proof())['job_id'])

    def test_stage_result_is_recorded_once_and_described_only_as_peer_evidence(self):
        offer, authorization, result = self.finish_stage()
        before = self.store.audit()
        self.jobs.complete(self.proof('RESULT', result))
        self.assertEqual(before, self.store.audit())
        status = self.jobs.status()['jobs'][0]
        self.assertEqual('staged', status['peer_reported_outcome'])
        self.assertFalse(status['customer_filesystem_attested'])
        with self.assertRaisesRegex(JobError, 'RESULT_CONFLICT'):
            self.jobs.complete(self.proof('RESULT', result | {'journal_sha256': 'c' * 64}))
        with self.assertRaisesRegex(JobError, 'GPO_BUSY'):
            self.enqueue()

    def test_result_cannot_clear_authorization_with_a_before_write_refusal(self):
        offer = self.offer(); authorization = self.authorize(offer)
        bad = self.result(offer, outcome='refused_before_authorization', reason='PREFLIGHT_FAILED',
                          journal_sha256='', tree_sha256='', filesystem_effects='none')
        with self.assertRaises(JobError):
            self.jobs.complete(self.proof('RESULT', bad))
        self.assertTrue(self.jobs.status()['jobs'][0]['authorization_issued'])

    def test_late_signed_result_can_reconcile_transport_delay_without_reauthorizing(self):
        offer = self.offer(); authorization = self.authorize(offer)
        result = self.result(offer, authorization)
        self.now += 100
        self.assertEqual('requires_review', self.jobs.status()['jobs'][0]['state'])
        self.jobs.complete(self.proof('RESULT', result))
        self.assertEqual('completed', self.jobs.status()['jobs'][0]['state'])
        with self.assertRaises(JobError):
            self.authorize(offer)

    def test_result_transport_grace_is_bounded(self):
        offer = self.offer(); authorization = self.authorize(offer)
        result = self.result(offer, authorization); self.now += RESULT_GRACE + 1
        with self.assertRaisesRegex(JobError, 'RESULT_EXPIRED'):
            self.jobs.complete(self.proof('RESULT', result))
        self.assertEqual('requires_review', self.jobs.status()['jobs'][0]['state'])

    def test_plan_change_after_claim_does_not_discard_outcome_evidence(self):
        offer = self.offer(); authorization = self.authorize(offer)
        result = self.result(offer, authorization)
        self.data['machine_profiles'][0]['version'] += 1
        self.jobs.complete(self.proof('RESULT', result))
        self.assertEqual('staged', self.jobs.status()['jobs'][0]['peer_reported_outcome'])

    def test_before_authorization_refusal_is_safe_and_does_not_claim_staging(self):
        offer = self.offer()
        result = self.result(offer, outcome='refused_before_authorization', reason='SCOPE_CHANGED',
                             journal_sha256='', tree_sha256='', filesystem_effects='none')
        self.jobs.complete(self.proof('RESULT', result))
        self.assertEqual('completed', self.jobs.status()['jobs'][0]['state'])
        self.assertFalse(self.jobs.status()['jobs'][0]['authorization_issued'])
        self.assertTrue(self.enqueue()['job_id'])

    def test_partial_failure_is_durable_and_never_automatically_retried(self):
        offer = self.offer(); authorization = self.authorize(offer)
        result = self.result(offer, authorization, outcome='requires_review', reason='IO_FAILURE',
                             filesystem_effects='unconfirmed', journal_sha256='', tree_sha256='')
        self.jobs.complete(self.proof('RESULT', result))
        self.assertEqual('requires_review', self.jobs.status()['jobs'][0]['state'])
        self.assertEqual('', self.jobs.poll(self.proof())['job_id'])
        with self.assertRaisesRegex(JobError, 'GPO_BUSY'):
            self.enqueue()

    def test_rollback_requires_completed_stage_receipt_and_separate_approval(self):
        self.jobs.poll(self.proof())
        with self.assertRaisesRegex(JobError, 'RECEIPT_REQUIRED'):
            self.jobs.review(self.value(ROLLBACK, str(uuid.uuid4())), self.actor)
        stage, _, result = self.finish_stage()
        # A stage preview may expire; rollback still binds its completed ownership receipt.
        self.now += 100; self.jobs.poll(self.proof())
        request = self.value(ROLLBACK, stage['job_id'])
        self.enqueue(request); offer = self.jobs.poll(self.proof())
        receipt = offer['target']['stage_receipt']
        self.assertEqual(result['journal_sha256'], receipt['complete_journal_sha256'])
        self.assertEqual(result['tree_sha256'], receipt['staged_tree_sha256'])
        authorization = self.authorize(offer)
        self.jobs.complete(self.proof('RESULT', self.result(offer, authorization)))
        with self.assertRaisesRegex(JobError, 'ALREADY_ROLLED_BACK'):
            self.jobs.review(self.value(ROLLBACK, stage['job_id']), self.actor)

    def test_rollback_cannot_claim_a_different_staged_tree(self):
        stage, _, _ = self.finish_stage()
        self.enqueue(self.value(ROLLBACK, stage['job_id'])); offer = self.jobs.poll(self.proof())
        authorization = self.authorize(offer)
        with self.assertRaises(JobError):
            self.jobs.complete(self.proof('RESULT', self.result(offer, authorization, tree_sha256='0' * 64)))

    def test_revocation_invalidates_peer_proofs_but_keeps_uncertain_write_visible(self):
        offer = self.offer(); authorization = self.authorize(offer)
        old_binding = self.binding(); result = self.result(offer, authorization)
        self.registry.apply(self.prepare(self.intent('revoke')), self.actor)
        status = self.jobs.status()['jobs'][0]
        self.assertEqual('requires_review', status['state']); self.assertTrue(status['authorization_issued'])
        with self.assertRaises(JobError):
            self.jobs.complete(self.proof('RESULT', result, binding=old_binding))

    def test_repairing_cannot_drop_an_old_generation_uncertain_write_lock(self):
        offer = self.offer(); authorization = self.authorize(offer)
        result = self.result(offer, authorization)
        old_scope = scope_id(self.binding())
        self.registry.apply(self.prepare(self.intent('revoke')), self.actor); self.pair()
        new_scope = scope_id(self.binding()); self.assertNotEqual(old_scope, new_scope)
        self.assertEqual('requires_review', self.jobs.status()['jobs'][0]['state'])
        with self.store.connect() as db:
            self.assertTrue(self.jobs._busy(self.jobs._read(db), offer['target'], STAGE, new_scope, self.now))
        with self.assertRaises(JobError):
            self.jobs.complete(self.proof('RESULT', result))
        self.assertEqual('', self.jobs.poll(self.proof())['job_id'])

    def test_clock_rollback_after_authorization_requires_review(self):
        offer = self.offer(); self.authorize(offer); self.now -= 1
        self.assertEqual('requires_review', self.jobs.status()['jobs'][0]['state'])

    def test_idempotent_create_reply_never_reissues_the_write_grant(self):
        request = self.enqueue(); offer = self.jobs.poll(self.proof()); self.authorize(offer)
        reply = self.jobs.create(request, self.actor)
        self.assertEqual('authorized', reply['state'])
        self.assertNotIn('authorization_id', reply); self.assertNotIn('write_authorized', reply)

    def test_more_than_512_targets_are_still_refused_not_silently_truncated(self):
        from .test_combined_scope_jobs import scope_catalog
        self.jobs.poll(self.proof())
        target = copy.deepcopy(self.jobs.review(self.value(), self.actor)['target'])
        target['scope_target']['target_count'] = 513
        target['preview_record']['Preview']['scope_target_sha256'] = digest(target['scope_target'])
        target['preview_record']['PreviewSha256'] = pf.preview_hash(target['preview_record']['Preview'])
        self.assertFalse(target_valid(target, STAGE))
        self.data['catalog'] = scope_catalog(self.data['plans'][0]['computer_group_sid'], 513)
        with self.assertRaisesRegex(JobError, 'DIRECTORY_NOT_READY|TARGET_CHANGED'):
            self.jobs.review(self.value(), self.actor)
        self.assertEqual([], self.jobs.status()['jobs'])

    def test_create_claim_and_result_audit_failure_rolls_back_the_whole_transition(self):
        self.jobs.poll(self.proof()); value = self.value()
        value['review_hash'] = self.jobs.review(value, self.actor)['review_hash']
        with patch.object(self.ops, '_audit', side_effect=sqlite3.OperationalError('fixture')):
            with self.assertRaises(sqlite3.Error):
                self.jobs.create(value, self.actor)
        self.assertEqual([], self.jobs.status()['jobs'])
        self.jobs.create(value, self.actor); offer = self.jobs.poll(self.proof())
        with patch.object(self.ops, '_audit', side_effect=sqlite3.OperationalError('fixture')):
            with self.assertRaises(sqlite3.Error):
                self.authorize(offer)
        self.assertEqual('leased', self.jobs.status()['jobs'][0]['state'])
        authorization = self.authorize(offer); result = self.result(offer, authorization)
        with patch.object(self.ops, '_audit', side_effect=sqlite3.OperationalError('fixture')):
            with self.assertRaises(sqlite3.Error):
                self.jobs.complete(self.proof('RESULT', result))
        self.assertEqual('authorized', self.jobs.status()['jobs'][0]['state'])
        self.jobs.complete(self.proof('RESULT', result))

    def test_store_corruption_is_not_hidden_as_an_offline_worker(self):
        self.enqueue()
        with self.store.connect() as db:
            raw = db.execute('SELECT payload FROM runtime_settings WHERE name=?', (SECTION,)).fetchone()[0]
        for mutate in (lambda v: v['jobs'][0].update(authorization_id='a' * 64),
                       lambda v: v['jobs'][0].update(intent_sha256='0' * 64),
                       lambda v: v['polls'].append(copy.deepcopy(v['polls'][0])),
                       lambda v: v['jobs'][0]['target']['preview_record']['Preview'].update(can_apply_gpo=True)):
            value = json.loads(raw); mutate(value)
            with self.store.connect() as db:
                db.execute('UPDATE runtime_settings SET payload=? WHERE name=?', (json.dumps(value), SECTION))
            with self.assertRaisesRegex(JobError, 'STORE_INVALID'):
                self.jobs.status()
        with self.store.connect() as db:
            db.execute('UPDATE runtime_settings SET payload=? WHERE name=?', (raw, SECTION))

    def test_claim_result_schema_type_and_window_overclaims_are_rejected(self):
        offer = self.offer(); authorization = self.authorize(offer)
        result = self.result(offer, authorization)
        for change in ({'authorization_id': '0' * 64}, {'checked_at': True},
                       {'checked_at': self.now + 31}, {'filesystem_effects': 'activated_gpo'},
                       {'can_apply_gpo': True}, {'path': 'C:\\elsewhere'},
                       {'outcome': 'gpo_applied'}, {'journal_sha256': ''}):
            with self.subTest(change=change), self.assertRaises(JobError):
                self.jobs.complete(self.proof('RESULT', result | change))
        self.jobs.complete(self.proof('RESULT', result))

    def test_existing_read_protocol_cannot_authorize_or_complete_write_jobs(self):
        offer = self.offer(); authorization = self.authorize(offer)
        result = self.result(offer, authorization)
        for raw in (self.proof('RESULT', result, changes={0: 'AUTHWIRE-STAGING-PREVIEW-JOB-RESULT-V1'}),
                    self.proof('RESULT', result, changes={16: CLAIM_PATH}),
                    self.proof('RESULT', result, private=self.other)):
            with self.assertRaises(JobError):
                self.jobs.complete(raw)

    def test_job_record_and_signed_messages_are_bounded(self):
        offer = self.offer(); authorization = self.authorize(offer)
        result = self.result(offer, authorization)
        self.assertLessEqual(len(json.dumps(offer).encode()), 32768)
        self.assertLessEqual(len(json.dumps(result, separators=(',', ':')).encode()), 1024)
        self.assertLessEqual(len(self.proof('RESULT', result)), 4096)
        with self.assertRaises(JobError):
            self.jobs.complete(self.proof('RESULT', result | {'padding': 'x' * 2000}))

    def test_internal_service_has_no_execution_or_general_command_entrypoint(self):
        from pathlib import Path
        server = Path(__file__).parents[1] / 'kaname' / 'server.py'
        self.assertNotIn('staging_write_jobs', server.read_text())
        self.assertNotIn(POLL_PATH, server.read_text())
        self.assertFalse(hasattr(self.jobs, 'execute'))
        self.assertFalse(self.jobs.status()['can_apply_gpo'])

    def test_consumed_job_ids_are_retained_and_full_ledger_fails_closed(self):
        for _ in range(32):
            offer = self.offer()
            result = self.result(offer, outcome='refused_before_authorization', reason='PREFLIGHT_FAILED',
                                 journal_sha256='', tree_sha256='', filesystem_effects='none')
            self.jobs.complete(self.proof('RESULT', result))
        status = self.jobs.status()['jobs']
        self.assertEqual(32, len({j['id'] for j in status}))
        with self.assertRaisesRegex(JobError, 'STAGING_WRITE_LIMIT'):
            self.enqueue()
        self.assertEqual(32, len(self.jobs.status()['jobs']))

    def test_transport_nonce_limit_expires_without_pruning_write_history(self):
        for _ in range(128):
            self.jobs.poll(self.proof())
        with self.assertRaises(JobError):
            self.jobs.poll(self.proof())
        self.now += 61
        self.assertEqual('', self.jobs.poll(self.proof())['job_id'])
        with self.store.connect() as db:
            self.assertEqual(1, len(self.jobs._read(db)['polls']))

    def test_backup_does_not_ignore_new_write_ledger_without_reviewed_projection(self):
        from tools.scheduled_backup import stable_runtime_payload
        self.enqueue()
        with self.store.connect() as db:
            raw = db.execute('SELECT payload FROM runtime_settings WHERE name=?', (SECTION,)).fetchone()[0]
        value = json.loads(raw); value['polls'] = []; value['last_poll'] = None
        self.assertNotEqual(stable_runtime_payload(SECTION, raw),
                            stable_runtime_payload(SECTION, json.dumps(value)))
        # No source deployment until an explicit strict projection has been reviewed.
