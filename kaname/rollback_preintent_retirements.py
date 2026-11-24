"""Distinct consumed-grant/no-intent retirement; no authority or result rewrite."""
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa

from .connector_jobs import guid
from .connector_registry import digest
from .rollback_retirements import (check, fields, flags, integer, is_hash,
                                   signed_body, validate_acknowledgement)

OBSERVATION_DOMAIN = 'AUTHWIRE-PREINTENT-ROLLBACK-OBSERVATION-V1'
REVIEW_DOMAIN = 'AUTHWIRE-PREINTENT-ROLLBACK-RETIRE-REVIEW-V1'
COMPLETE_DOMAIN = 'AUTHWIRE-PREINTENT-ROLLBACK-RETIRE-COMPLETE-V1'


def validate(jobs, db, job, evidence, proof, binding, now):
    # Caller has already verified current binding, exact immutable uncertain
    # authorized rollback/result, expired grant and reconciliation evidence.
    record = proof['review_record']
    fields(record, 'format review observation acknowledgement_request acknowledgement_receipt acknowledge')
    check(record['format'] == 'AuthWirePreIntentRollbackRetirementRecordV1' and
          record['acknowledge'] == 'retire_consumed_rollback_before_intent_preserve_unknown_outcome')
    public = serialization.load_pem_public_key(binding.public_key_pem)
    check(isinstance(public, rsa.RSAPublicKey) and public.key_size in (2048, 3072, 4096))
    ob = signed_body(public, record['observation'], OBSERVATION_DOMAIN)
    review = signed_body(public, record['review'], REVIEW_DOMAIN)
    closed = signed_body(public, proof['completion'], COMPLETE_DOMAIN)
    fields(ob, 'format job_id stage_job_id stage_operation_id binding_scope authority_release authorization_id '
           'authorization_sha256 grant_consumption_sha256 original_records_sha256 consumed_at expires_at '
           'tree_sha256 outside_baseline_sha256 tree_rows authority_expired filesystem_intent_absent '
           'execution_markers_absent staged_tree_unchanged outside_unchanged read_only can_delete authority_renewed observed_at')
    fields(review, 'format job_id stage_job_id gpo_id binding_scope original_records_sha256 reservation_sha256 '
           'origin_chain_sha256 tree_sha256 baseline_sha256 result_body_sha256 observed_at expires_at '
           'retain_original_reservation retain_gpo_lock requires_new_rollback_job can_delete can_apply_gpo '
           'grant_consumption_sha256 observation_sha256 original_outcome filesystem_effects filesystem_intent_absent')
    fields(closed, 'format job_id stage_job_id binding_scope original_records_sha256 review_record_sha256 '
           'reservation_sha256 closed_at original_reservation_retained gpo_lock_retained authority_renewed '
           'can_delete can_apply_gpo original_unknown_result_preserved grant_consumption_sha256 observation_sha256 filesystem_intent_absent')
    check(ob['format'] == 'AuthWireRollbackPreIntentObservationV1' and
          review['format'] == 'AuthWirePreIntentRollbackRetirementReviewV1' and
          closed['format'] == 'AuthWirePreIntentRollbackRetirementCompleteV1')
    stage = job['target']['stage_receipt']['stage_job_id']
    for value in (ob, review, closed):
        check(value['job_id'] == job['id'] and value['stage_job_id'] == stage and value['binding_scope'] == job['scope'])
    flags(ob, ('authority_expired', 'filesystem_intent_absent', 'execution_markers_absent',
               'staged_tree_unchanged', 'outside_unchanged', 'read_only'), ('can_delete', 'authority_renewed'))
    flags(review, ('retain_original_reservation', 'retain_gpo_lock', 'requires_new_rollback_job',
                   'filesystem_intent_absent'), ('can_delete', 'can_apply_gpo'))
    flags(closed, ('original_reservation_retained', 'gpo_lock_retained', 'original_unknown_result_preserved',
                   'filesystem_intent_absent'), ('authority_renewed', 'can_delete', 'can_apply_gpo'))
    check(guid(ob['stage_operation_id']) and ob['authority_release'] == job['target']['writer_release_id'] and
          ob['authorization_id'] == job['authorization_id'] and is_hash(ob['authorization_sha256']) and
          review['gpo_id'] == job['target']['scope_target']['gpo_id'] and
          review['result_body_sha256'] == evidence['result_body_sha256'] and
          ob['tree_sha256'] == review['tree_sha256'] == job['target']['stage_receipt']['staged_tree_sha256'] and
          ob['outside_baseline_sha256'] == review['baseline_sha256'] == job['target']['preview_record']['Preview']['baseline_inventory_sha256'] and
          review['original_outcome'] == 'requires_review' and review['filesystem_effects'] == 'unconfirmed')
    for name in ('original_records_sha256', 'grant_consumption_sha256'):
        check(is_hash(ob[name]) and ob[name] == review[name] == closed[name])
    check(is_hash(review['reservation_sha256']) and review['reservation_sha256'] == closed['reservation_sha256'] and
          is_hash(review['origin_chain_sha256']) and digest(record['observation']) == review['observation_sha256'] == closed['observation_sha256'] and
          closed['review_record_sha256'] == digest(record))
    check(all(integer(v) for v in (ob['consumed_at'], ob['expires_at'], ob['observed_at'], ob['tree_rows'],
                                   review['observed_at'], review['expires_at'], closed['closed_at'])) and
          ob['tree_rows'] > 0 and job['authorized_at'] <= ob['consumed_at'] < ob['expires_at'] == job['authorized_until'] and
          max(ob['expires_at'], job['lease_until']) <= ob['observed_at'] <= review['observed_at'] <= closed['closed_at'] < review['expires_at'] and
          review['expires_at'] == review['observed_at']+60 and closed['closed_at'] <= now)
    validate_acknowledgement(jobs, db, job, record, evidence)
    return job
