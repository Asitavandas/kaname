"""Signed consumed-rollback retirements: queue succession only, never deletion.

Original jobs/results/grants are immutable. A separate append-only ledger stores
the paired service's historical local closure and its original audited ACK.
Every queue admission revalidates it under the current pairing and exact job.
"""
import base64
import copy
import json
import re
import secrets

from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding, rsa

from .connector_jobs import JobError, guid, scope_id
from .connector_registry import digest
from .models import strict_json

SECTION = 'windows_consumed_rollback_retirements_v1'
DECISION = 'accept_consumed_rollback_retirement'
ACK = 'record_signed_rollback_retirement_preserve_original_result'
ROLLBACK = 'combined.filesystem.rollback.v1'
HASH = re.compile(r'[0-9a-f]{64}\Z')
REVIEW_DOMAIN = 'AUTHWIRE-CONSUMED-ROLLBACK-RETIRE-REVIEW-V1'
COMPLETE_DOMAIN = 'AUTHWIRE-CONSUMED-ROLLBACK-RETIRE-COMPLETE-V1'
OBSERVATION_DOMAIN = 'AUTHWIRE-ROLLBACK-READONLY-OBSERVATION-V1'


def check(ok, code='STAGING_WRITE_RETIREMENT_REJECTED'):
    if not ok:
        raise JobError(code)


def fields(value, names):
    check(type(value) is dict and set(value) == set(names.split()))


def integer(value):
    return type(value) is int and 0 <= value < 2**53


def is_hash(value):
    return type(value) is str and HASH.fullmatch(value) is not None


def canonical(value):
    return json.dumps(value, ensure_ascii=False, sort_keys=True, separators=(',', ':'), allow_nan=False).encode()


def flags(value, true=(), false=()):
    for name in true:
        check(type(value[name]) is bool and value[name])
    for name in false:
        check(type(value[name]) is bool and not value[name])


def signature(public, text, encoded):
    check(type(encoded) is str and len(encoded) <= 684)
    try:
        raw = base64.b64decode(encoded, validate=True)
        check(len(raw) == public.key_size // 8 and base64.b64encode(raw).decode() == encoded)
        public.verify(raw, text, padding.PKCS1v15(), hashes.SHA256())
    except (ValueError, TypeError, InvalidSignature):
        raise JobError('STAGING_WRITE_RETIREMENT_SIGNATURE_REJECTED') from None


def signed_body(public, proof, domain):
    fields(proof, 'Body Signature')
    check(type(proof['Body']) is dict)
    signature(public, (domain+'\n'+digest(proof['Body'])+'\n').encode('ascii'), proof['Signature'])
    return proof['Body']


def validate_proof(jobs, db, ledger, evidence, proof):
    """Verify current channel key + original job + three distinct signatures."""
    jobs._validate_reconciliation_evidence(evidence)
    binding = jobs._binding(db)
    job = next((j for j in ledger['jobs'] if j['id'] == evidence['job_id']), None)
    check(job is not None and job['scope'] == scope_id(binding) == evidence['scope_sha256'])
    result = job['result']; now = int(jobs.clock())
    check(job['operation'] == ROLLBACK and job['state'] == 'requires_review' and
          job['authorization_id'] and integer(job['authorized_until']) and now >= job['authorized_until'])
    check(result is not None and result['authorization_id'] == job['authorization_id'] and
          result['outcome'] == 'requires_review' and result['reason'] == 'OUTCOME_UNKNOWN' and
          result['filesystem_effects'] == 'unconfirmed' and result['journal_sha256'] == result['tree_sha256'] == '')
    expected = dict(job_id=job['id'], scope_sha256=job['scope'], intent_sha256=job['intent_sha256'],
                    result_body_sha256=digest(result), accepted_ack=True)
    check(evidence == expected and type(evidence['accepted_ack']) is bool)
    fields(proof, 'review_record completion')
    record = proof['review_record']; completion = proof['completion']
    fields(record, 'format review observation acknowledgement_request acknowledgement_receipt acknowledge')
    check(record['format'] == 'AuthWireConsumedRollbackRetirementRecordV1' and
          record['acknowledge'] == 'retire_consumed_rollback_preserve_unknown_outcome')
    public = serialization.load_pem_public_key(binding.public_key_pem)
    check(isinstance(public, rsa.RSAPublicKey) and public.key_size in (2048, 3072, 4096))
    review = signed_body(public, record['review'], REVIEW_DOMAIN)
    closed = signed_body(public, completion, COMPLETE_DOMAIN)
    fields(review, 'format job_id stage_job_id gpo_id binding_scope original_records_sha256 reservation_sha256 '
           'origin_chain_sha256 tree_sha256 baseline_sha256 result_body_sha256 observed_at expires_at '
           'retain_original_reservation retain_gpo_lock requires_new_rollback_job can_delete can_apply_gpo '
           'filesystem_intent_sha256 prior_observation_sha256 original_outcome filesystem_effects')
    fields(closed, 'format job_id stage_job_id binding_scope original_records_sha256 review_record_sha256 '
           'reservation_sha256 closed_at original_reservation_retained gpo_lock_retained authority_renewed '
           'can_delete can_apply_gpo original_unknown_result_preserved filesystem_intent_sha256 prior_observation_sha256')
    check(review['format'] == 'AuthWireConsumedRollbackRetirementReviewV1' and
          closed['format'] == 'AuthWireConsumedRollbackRetirementCompleteV1')
    flags(review, ('retain_original_reservation', 'retain_gpo_lock', 'requires_new_rollback_job'), ('can_delete', 'can_apply_gpo'))
    flags(closed, ('original_reservation_retained', 'gpo_lock_retained', 'original_unknown_result_preserved'),
          ('authority_renewed', 'can_delete', 'can_apply_gpo'))
    stage = job['target']['stage_receipt']['stage_job_id']
    check(review['job_id'] == closed['job_id'] == job['id'] and
          review['stage_job_id'] == closed['stage_job_id'] == stage and
          review['binding_scope'] == closed['binding_scope'] == job['scope'] and
          review['gpo_id'] == job['target']['scope_target']['gpo_id'] and
          review['result_body_sha256'] == evidence['result_body_sha256'] and
          review['tree_sha256'] == job['target']['stage_receipt']['staged_tree_sha256'] and
          review['baseline_sha256'] == job['target']['preview_record']['Preview']['baseline_inventory_sha256'] and
          review['original_outcome'] == 'requires_review' and review['filesystem_effects'] == 'unconfirmed')
    for name in ('original_records_sha256', 'reservation_sha256', 'filesystem_intent_sha256', 'prior_observation_sha256'):
        check(is_hash(review[name]) and closed[name] == review[name])
    check(is_hash(review['origin_chain_sha256']) and closed['review_record_sha256'] == digest(record))
    check(all(integer(v) for v in (review['observed_at'], review['expires_at'], closed['closed_at'])) and
          job['authorized_until'] <= review['observed_at'] <= closed['closed_at'] < review['expires_at'] and
          review['expires_at'] == review['observed_at']+60 and closed['closed_at'] <= now)
    observation = record['observation']
    fields(observation, 'domain body signature'); ob = observation['body']
    fields(ob, 'format job_id stage_job_id stage_operation_id active_release authority_expired intent_sha256 '
           'original_child_running entered_marker_exists engine_markers tree_sha256 outside_baseline_sha256 '
           'tree_rows staged_tree_unchanged outside_unchanged read_only can_delete authority_renewed at')
    check(observation['domain'] == OBSERVATION_DOMAIN)
    signature(public, (OBSERVATION_DOMAIN+'\n').encode()+canonical(ob), observation['signature'])
    fields(ob['engine_markers'], 'rolled-back.json rollback-started.json')
    flags(ob['engine_markers'], false=('rolled-back.json', 'rollback-started.json'))
    flags(ob, ('authority_expired', 'staged_tree_unchanged', 'outside_unchanged', 'read_only'),
          ('original_child_running', 'entered_marker_exists', 'can_delete', 'authority_renewed'))
    check(ob['format'] == 'AuthWireRollbackReadOnlyObservationV1' and ob['job_id'] == job['id'] and
          ob['stage_job_id'] == stage and guid(ob['stage_operation_id']) and
          ob['active_release'] == job['target']['writer_release_id'] and
          ob['intent_sha256'] == review['filesystem_intent_sha256'] and
          ob['tree_sha256'] == review['tree_sha256'] and ob['outside_baseline_sha256'] == review['baseline_sha256'] and
          integer(ob['tree_rows']) and ob['tree_rows'] > 0 and integer(ob['at']) and
          job['authorized_until'] <= ob['at'] <= review['observed_at'] and
          digest(observation) == review['prior_observation_sha256'])
    request = record['acknowledgement_request']; receipt = record['acknowledgement_receipt']
    fields(request, 'expected_revision evidence decision review_hash acknowledge')
    check(integer(request['expected_revision']) and request['evidence'] == expected and
          request['decision'] == 'acknowledge_saved_result' and is_hash(request['review_hash']) and
          request['acknowledge'] == 'record_reconciliation_decision')
    names = 'job_id decision decision_recorded revision approval_enabled write_authorization_enabled execution_adapter_available can_apply_gpo'
    if type(receipt) is dict and 'source_only' in receipt:
        names += ' source_only'
    fields(receipt, names)
    flags(receipt, ('decision_recorded',), ('can_apply_gpo',))
    check(receipt['job_id'] == job['id'] and receipt['decision'] == request['decision'] and
          integer(receipt['revision']) and receipt['revision'] == request['expected_revision']+1)
    for name in ('approval_enabled', 'write_authorization_enabled', 'execution_adapter_available'):
        check(type(receipt[name]) is bool and receipt[name] == receipt['approval_enabled'])
    if 'source_only' in receipt:
        check(type(receipt['source_only']) is bool and receipt['source_only'] != receipt['approval_enabled'])
    else:
        check(not receipt['approval_enabled'])
    # The old operator may already have been removed. Validate its exact audit
    # event, not the new caller's identity or an unaudited client-supplied ACK.
    prefix = f"staging_write_reconciliation:{job['id']}:acknowledge_saved_result:actor:"
    audited = False
    for row in db.execute('SELECT event FROM audit WHERE revision=?', (receipt['revision'],)):
        event = row[0]
        if event.startswith(prefix):
            original_actor = event[len(prefix):].split(':request:', 1)[0]
            audited |= guid(original_actor) and event == jobs._reconciliation_event(request, original_actor)
    check(audited, 'STAGING_WRITE_RETIREMENT_ACK_AUDIT_REQUIRED')
    return job


def validate_request(value, actor, confirm=False):
    names = 'expected_revision evidence decision retirement'
    if confirm:
        names += ' review_hash acknowledge'
    fields(value, names)
    check(len(canonical(value)) <= 16384 and guid(actor) and integer(value['expected_revision']) and value['decision'] == DECISION)
    if confirm:
        check(is_hash(value['review_hash']) and value['acknowledge'] == ACK)


def review_body(value, actor, job):
    return {'revision': value['expected_revision'], 'actor': actor, 'job_id': job['id'], 'decision': DECISION,
            'scope_sha256': job['scope'], 'job_sha256': digest(job), 'result_body_sha256': digest(job['result']),
            'closure_sha256': digest(value['retirement']['completion']), 'retirement_sha256': digest(value['retirement']),
            'original_state_preserved': True, 'authority_renewed': False, 'can_apply_gpo': False}


def audit_event(identity, actor, closure):
    return f'staging_write_consumed_rollback_retired:{identity}:actor:{actor}:closure:{closure}'


def entries(jobs, db, ledger):
    row = db.execute('SELECT payload FROM runtime_settings WHERE name=?', (SECTION,)).fetchone()
    if row is None:
        return []
    try:
        check(type(row[0]) is str and len(row[0]) <= 1048576)
        value = strict_json(row[0]); fields(value, 'format records')
        check(type(value['format']) is int and value['format'] == 1 and type(value['records']) is list and len(value['records']) <= 32)
        seen = set()
        for record in value['records']:
            fields(record, 'job_id actor revision recorded_at request')
            req = record['request']; validate_request(req, record['actor'], True)
            check(record['job_id'] not in seen); seen.add(record['job_id'])
            job = validate_proof(jobs, db, ledger, req['evidence'], req['retirement'])
            check(record['job_id'] == job['id'] and integer(record['revision']) and
                  record['revision'] == req['expected_revision']+1 and integer(record['recorded_at']) and
                  req['retirement']['completion']['Body']['closed_at'] <= record['recorded_at'] <= int(jobs.clock()) and
                  req['review_hash'] == digest(review_body(req, record['actor'], job)))
            event = audit_event(job['id'], record['actor'], digest(req['retirement']['completion']))
            check(db.execute('SELECT 1 FROM audit WHERE revision=? AND event=?', (record['revision'], event)).fetchone())
        return value['records']
    except (ValueError, TypeError, KeyError, AttributeError, RecursionError):
        raise JobError('STAGING_WRITE_RETIREMENT_STORE_INVALID') from None


def review(jobs, value, actor):
    validate_request(value, actor)
    with jobs.store.connect() as db:
        db.execute('BEGIN'); jobs.ops._revision(db, value['expected_revision'])
        ledger = jobs._read(db); records = entries(jobs, db, ledger)
        job = validate_proof(jobs, db, ledger, value['evidence'], value['retirement'])
        check(all(r['job_id'] != job['id'] for r in records), 'STAGING_WRITE_RETIREMENT_ALREADY_RECORDED')
        result = review_body(value, actor, job)
        return result | {'review_hash': digest(result)}


def record(jobs, value, actor):
    validate_request(value, actor, True)
    with jobs.store.connect() as db:
        db.execute('BEGIN IMMEDIATE'); ledger = jobs._read(db); records = entries(jobs, db, ledger)
        job = validate_proof(jobs, db, ledger, value['evidence'], value['retirement'])
        old = next((r for r in records if r['job_id'] == job['id']), None)
        if old:
            check(old['actor'] == actor and old['request'] == value, 'STAGING_WRITE_RETIREMENT_CONFLICT')
            revision = old['revision']
        else:
            revision = jobs.ops._revision(db, value['expected_revision'])+1
            check(secrets.compare_digest(value['review_hash'], digest(review_body(value, actor, job))),
                  'STAGING_WRITE_RETIREMENT_REVIEW_CHANGED')
            check(len(records) < 32, 'STAGING_WRITE_RETIREMENT_LIMIT')
            records.append({'job_id': job['id'], 'actor': actor, 'revision': revision,
                            'recorded_at': int(jobs.clock()), 'request': copy.deepcopy(value)})
            jobs.ops._save(db, SECTION, {'format': 1, 'records': records})
            jobs.ops._audit(db, audit_event(job['id'], actor, digest(value['retirement']['completion'])), revision-1)
        return {'job_id': job['id'], 'decision': DECISION, 'retirement_recorded': True, 'revision': revision,
                'original_state_preserved': True, 'authority_renewed': False, 'requires_new_rollback_job': True,
                'can_apply_gpo': False}


def queue_ledger(jobs, db, ledger, target, operation, scope):
    verified = entries(jobs, db, ledger)
    if operation != ROLLBACK:
        return ledger
    stage = target['stage_receipt']['stage_job_id']
    retired = {r['job_id'] for r in verified if r['request']['evidence']['scope_sha256'] == scope and
               r['request']['retirement']['completion']['Body']['stage_job_id'] == stage}
    # A copy is used solely by the busy predicate. The saved original ledger,
    # uncertain job/result/grant and all other blocked jobs remain untouched.
    return ledger | {'jobs': [j for j in ledger['jobs'] if j['id'] not in retired]}
