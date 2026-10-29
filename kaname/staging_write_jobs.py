"""Source-only filesystem write authorization ledger; no HTTP/worker registration.

The future administrator API must enforce both existing write permissions and
session/Origin/CSRF checks. Actor UUIDs and acknowledgement text are not auth.
Peer possession proofs do not attest to filesystem effects. This ledger never
enables GPO activation and never re-leases an uncertain write.
"""
import copy
import secrets

from .connector_jobs import (ConnectorJobs, JobError, require, guid, HEX,
                             scope_id, sha, LIFETIME, LIMIT, verify_job_proof)
from .connector_registry import digest, RegistryError
from .deployment_candidates import CandidateError
from .models import keys, strict_json
from .staging_preview_jobs import (StagingPreviewJobs, preview_valid,
                                  preview_hash, target_valid as scope_target_valid)

SECTION = 'windows_staging_write_jobs'
STAGE = 'combined.filesystem.stage.v1'
ROLLBACK = 'combined.filesystem.rollback.v1'
CAPABILITY = 'combined.filesystem.write.v1'
POLL_PATH = '/api/connector/v1/staging-write/poll'
CLAIM_PATH = '/api/connector/v1/staging-write/claim'
RESULT_PATH = '/api/connector/v1/staging-write/result'
ACK = {STAGE: 'create_owned_version_directory', ROLLBACK: 'delete_owned_version_directory'}
CLAIM_LIFETIME = 30
RESULT_GRACE = 300
REFUSALS = {'CONTENT_REJECTED', 'SCOPE_CHANGED', 'PREVIEW_EXPIRED',
            'PREFLIGHT_FAILED', 'WRITER_UNAVAILABLE'}
REVIEW_REASONS = {'IO_FAILURE', 'JOURNAL_FAILURE', 'DRIFT', 'WORKER_INTERRUPTED',
                  'OUTCOME_UNKNOWN', 'POSTCHECK_FAILED'}


def is_hash(value):
    return type(value) is str and bool(HEX.fullmatch(value))


def target_valid(t, operation):
    names = {'scope_target', 'preview_record', 'preview_job_id',
             'preview_result_sha256', 'writer_release_id', 'stage_receipt'}
    if not (type(t) is dict and set(t) == names and scope_target_valid(t['scope_target']) and
            guid(t['preview_job_id']) and guid(t['writer_release_id']) and
            is_hash(t['preview_result_sha256'])):
        return False
    p = t['preview_record']
    if not (type(p) is dict and set(p) == {'Preview', 'PreviewSha256'} and
            preview_valid(p['Preview'], t['scope_target']) and
            p['PreviewSha256'] == preview_hash(p['Preview'])):
        return False
    r = t['stage_receipt']
    if operation == STAGE:
        return r is None
    return (operation == ROLLBACK and type(r) is dict and
            set(r) == {'stage_job_id', 'complete_journal_sha256', 'staged_tree_sha256'} and
            guid(r['stage_job_id']) and is_hash(r['complete_journal_sha256']) and
            is_hash(r['staged_tree_sha256']))


def intent_id(scope, identity, operation, target):
    return sha(('AuthWireStagingWriteIntentV1\n' + scope + '\n' + identity + '\n' +
                operation + '\n' + digest(target) + '\n').encode('ascii'))


class StagingWriteJobs(ConnectorJobs):
    """Internal trusted-caller service. Deliberately not installed in server.py."""
    def __init__(self, candidates, **kwargs):
        super().__init__(candidates.registry, **kwargs)
        self.candidates = candidates
        self.previews = StagingPreviewJobs(candidates, wall_clock=self.clock)

    def _proof(self, raw, binding, kind):
        require(kind in {'POLL', 'CLAIM', 'RESULT'})
        return verify_job_proof(raw, binding, kind, self.clock,
            prefix='AUTHWIRE-STAGING-WRITE-JOB-', poll_path=POLL_PATH,
            result_path=CLAIM_PATH if kind == 'CLAIM' else RESULT_PATH)

    @staticmethod
    def _result_valid(v, j):
        names = {'job_id', 'lease_id', 'intent_sha256', 'target_sha256', 'release_id',
                 'authorization_id', 'checked_at', 'outcome', 'reason',
                 'journal_sha256', 'tree_sha256', 'filesystem_effects'}
        if not (type(v) is dict and set(v) == names and v['job_id'] == j['id'] and
                v['lease_id'] == j['lease_id'] and v['intent_sha256'] == j['intent_sha256'] and
                v['target_sha256'] == digest(j['target']) and
                v['release_id'] == j['target']['writer_release_id'] and
                type(v['checked_at']) is int):
            return False
        if not j['authorization_id']:
            return (v['authorization_id'] == '' and v['outcome'] == 'refused_before_authorization' and
                    type(v['reason']) is str and v['reason'] in REFUSALS and
                    j['created'] <= v['checked_at'] <= j['lease_until'] and
                    v['journal_sha256'] == v['tree_sha256'] == '' and v['filesystem_effects'] == 'none')
        if not (v['authorization_id'] == j['authorization_id'] and
                j['authorized_at'] <= v['checked_at'] <= j['authorized_until']):
            return False
        if v['outcome'] == 'requires_review':
            return (type(v['reason']) is str and v['reason'] in REVIEW_REASONS and
                    v['filesystem_effects'] == 'unconfirmed' and
                    all(x == '' or is_hash(x) for x in (v['journal_sha256'], v['tree_sha256'])))
        if not (v['reason'] == 'OK' and is_hash(v['journal_sha256']) and is_hash(v['tree_sha256'])):
            return False
        if j['operation'] == STAGE:
            return v['outcome'] == 'staged' and v['filesystem_effects'] == 'created_owned_directory'
        return (v['outcome'] == 'rolled_back' and v['filesystem_effects'] == 'removed_owned_directory' and
                v['tree_sha256'] == j['target']['stage_receipt']['staged_tree_sha256'])

    def _read(self, db):
        row = db.execute('SELECT payload FROM runtime_settings WHERE name=?', (SECTION,)).fetchone()
        if row is None:
            return {'format': 1, 'jobs': [], 'polls': [], 'last_poll': None}
        try:
            require(type(row[0]) is str and len(row[0]) <= 1048576)
            v = strict_json(row[0]); keys(v, {'format', 'jobs', 'polls', 'last_poll'},
                                        {'format', 'jobs', 'polls', 'last_poll'})
            require(type(v['format']) is int and v['format'] == 1 and
                    type(v['jobs']) is list and len(v['jobs']) <= LIMIT and
                    type(v['polls']) is list and len(v['polls']) <= 128)
            ids = set()
            names = {'id', 'operation', 'actor', 'scope', 'created', 'deadline', 'lease_id',
                     'lease_until', 'state', 'intent_sha256', 'creation_sha256', 'approval_sha256',
                     'target', 'authorized_at', 'authorized_until', 'authorization_id',
                     'claim_sha256', 'result'}
            for j in v['jobs']:
                keys(j, names, names)
                require(guid(j['id']) and j['id'] not in ids and guid(j['actor'])); ids.add(j['id'])
                require(j['operation'] in ACK and target_valid(j['target'], j['operation']) and
                        j['state'] in {'queued', 'leased', 'authorized', 'completed', 'requires_review'})
                require(all(is_hash(j[n]) for n in ('scope', 'intent_sha256', 'creation_sha256', 'approval_sha256')))
                require(j['intent_sha256'] == intent_id(j['scope'], j['id'], j['operation'], j['target']))
                require(all(type(j[n]) is int and 0 < j[n] < 2**40 for n in ('created', 'deadline')) and
                        0 < j['deadline'] - j['created'] <= LIFETIME)
                if j['operation'] == STAGE:
                    p = j['target']['preview_record']['Preview']
                    require(p['checked_at'] <= j['created'] < p['expires_at'] and j['deadline'] == p['expires_at'])
                else:
                    require(j['deadline'] == j['created'] + LIFETIME)
                if j['state'] == 'queued':
                    require(j['lease_id'] == '' and type(j['lease_until']) is int and j['lease_until'] == 0)
                else:
                    require(is_hash(j['lease_id']) and type(j['lease_until']) is int and
                            j['created'] < j['lease_until'] <= j['deadline'])
                if not j['authorization_id']:
                    require(type(j['authorized_at']) is int and j['authorized_at'] == 0 and
                            type(j['authorized_until']) is int and j['authorized_until'] == 0 and
                            j['authorization_id'] == j['claim_sha256'] == '' and
                            j['state'] in {'queued', 'leased', 'completed'})
                else:
                    require(is_hash(j['authorization_id']) and is_hash(j['claim_sha256']) and
                            all(type(j[n]) is int for n in ('authorized_at', 'authorized_until')) and
                            j['created'] <= j['authorized_at'] < j['authorized_until'] <= j['lease_until'] and
                            j['authorized_until'] - j['authorized_at'] <= CLAIM_LIFETIME and
                            j['state'] in {'authorized', 'completed', 'requires_review'})
                if j['state'] in {'completed', 'requires_review'}:
                    require(self._result_valid(j['result'], j) and
                            (j['state'] == 'requires_review') == (j['result']['outcome'] == 'requires_review'))
                else:
                    require(j['result'] is None)
            poll_ids = set()
            for p in v['polls']:
                keys(p, {'id', 'until'}, {'id', 'until'})
                require(is_hash(p['id']) and p['id'] not in poll_ids and type(p['until']) is int and 0 < p['until'] < 2**40)
                poll_ids.add(p['id'])
            p = v['last_poll']
            if p is not None:
                keys(p, {'scope', 'at', 'release_id'}, {'scope', 'at', 'release_id'})
                require(is_hash(p['scope']) and type(p['at']) is int and 0 < p['at'] < 2**40 and guid(p['release_id']))
            return v
        except (ValueError, TypeError, KeyError, AttributeError):
            raise JobError('STAGING_WRITE_STORE_INVALID') from None

    def _state(self, j, scope, now):
        # An issued write never becomes a harmless expired/obsolete read job.
        if j['state'] == 'requires_review':
            return 'requires_review'
        if j['state'] == 'authorized':
            return 'authorized' if j['scope'] == scope and j['authorized_at'] <= now < j['authorized_until'] else 'requires_review'
        if j['state'] == 'completed':
            return 'completed'
        if j['scope'] != scope:
            return 'obsolete'
        if now < j['created'] or now >= (j['lease_until'] if j['state'] == 'leased' else j['deadline']):
            return 'expired'
        return j['state']

    def _stage_target(self, db, identity, release):
        scope = scope_id(self._binding(db)); target = self.previews._target(db, identity)
        latest = next((j for j in reversed(self.previews._read(db)['jobs']) if
                       j['scope'] == scope and j['target'] == target and j['state'] == 'completed'), None)
        require(latest and latest['result']['outcome'] == 'staging_preview_verified', 'STAGING_WRITE_PREVIEW_REQUIRED')
        r = latest['result']; p = r['preview']; now = int(self.clock())
        require(p['checked_at'] <= now < p['expires_at'], 'STAGING_WRITE_PREVIEW_EXPIRED')
        return {'scope_target': target, 'preview_record': {'Preview': p, 'PreviewSha256': r['preview_sha256']},
                'preview_job_id': latest['id'],
                'preview_result_sha256': digest({'job_id': latest['id'], 'intent_sha256': latest['intent_sha256'], 'result': r}),
                'writer_release_id': release, 'stage_receipt': None}

    def _rollback_target(self, db, ledger, identity, stage_id, release):
        scope = scope_id(self._binding(db))
        old = next((j for j in ledger['jobs'] if j['id'] == stage_id), None)
        require(old and old['operation'] == STAGE and old['scope'] == scope and old['state'] == 'completed' and
                old['result']['outcome'] == 'staged' and old['target']['scope_target']['candidate_id'] == identity,
                'STAGING_ROLLBACK_RECEIPT_REQUIRED')
        require(not any(j['operation'] == ROLLBACK and j['state'] == 'completed' and
                j['result']['outcome'] == 'rolled_back' and j['target']['stage_receipt']['stage_job_id'] == stage_id
                for j in ledger['jobs']), 'STAGING_ALREADY_ROLLED_BACK')
        require(self.previews._target(db, identity) == old['target']['scope_target'], 'STAGING_WRITE_TARGET_CHANGED')
        target = copy.deepcopy(old['target']); target['writer_release_id'] = release
        target['stage_receipt'] = {'stage_job_id': stage_id,
            'complete_journal_sha256': old['result']['journal_sha256'],
            'staged_tree_sha256': old['result']['tree_sha256']}
        return target

    def _current(self, db, ledger, j):
        try:
            identity = j['target']['scope_target']['candidate_id']
            expected = (self._stage_target(db, identity, j['target']['writer_release_id']) if j['operation'] == STAGE
                        else self._rollback_target(db, ledger, identity,
                             j['target']['stage_receipt']['stage_job_id'], j['target']['writer_release_id']))
            return expected == j['target']
        except (JobError, CandidateError, RegistryError) as error:
            if error.code.endswith('STORE_INVALID'):
                raise
            return False

    def _busy(self, ledger, target, operation, scope, now):
        gpo = target['scope_target']['gpo_id']
        for j in ledger['jobs']:
            if j['target']['scope_target']['gpo_id'] != gpo:
                continue
            if j['state'] in {'authorized', 'requires_review'} or self._state(j, scope, now) in {'queued', 'leased'}:
                return True
            if operation == STAGE and j['operation'] == STAGE and j['state'] == 'completed' and j['result']['outcome'] == 'staged':
                undone = any(r['operation'] == ROLLBACK and r['state'] == 'completed' and
                    r['result']['outcome'] == 'rolled_back' and r['target']['stage_receipt']['stage_job_id'] == j['id']
                    for r in ledger['jobs'])
                if not undone:
                    return True
        return False

    def _review(self, db, value, actor):
        names = {'expected_revision', 'job_id', 'operation', 'candidate_id',
                 'staging_preview_sha256', 'stage_job_id', 'acknowledge'}
        keys(value, names, names)
        require(guid(actor) and guid(value['job_id']) and guid(value['candidate_id']) and
                type(value['operation']) is str and value['operation'] in ACK and
                value['acknowledge'] == ACK[value['operation']] and is_hash(value['staging_preview_sha256']),
                'STAGING_WRITE_APPROVAL_REQUIRED')
        revision = self.ops._revision(db, value['expected_revision']); scope = scope_id(self._binding(db))
        ledger = self._read(db); now = int(self.clock()); last = ledger['last_poll']
        require(last and last['scope'] == scope and 0 <= now - last['at'] < 90, 'STAGING_WRITE_WORKER_NOT_READY')
        if value['operation'] == STAGE:
            require(value['stage_job_id'] == '', 'STAGING_WRITE_APPROVAL_REQUIRED')
            target = self._stage_target(db, value['candidate_id'], last['release_id'])
        else:
            require(guid(value['stage_job_id']), 'STAGING_ROLLBACK_RECEIPT_REQUIRED')
            target = self._rollback_target(db, ledger, value['candidate_id'], value['stage_job_id'], last['release_id'])
        require(value['staging_preview_sha256'] == target['preview_record']['PreviewSha256'], 'STAGING_WRITE_PREVIEW_CHANGED')
        review = {'revision': revision, 'job_id': value['job_id'], 'operation': value['operation'],
                  'actor': actor, 'scope_sha256': scope, 'target': target,
                  'intent_sha256': intent_id(scope, value['job_id'], value['operation'], target),
                  'acknowledge': value['acknowledge'], 'read_only': False, 'can_apply_gpo': False}
        review['review_hash'] = digest(review)
        return review

    def review(self, value, actor):
        with self.store.connect() as db:
            db.execute('BEGIN')
            return self._review(db, value, actor)

    def create(self, value, actor):
        names = {'expected_revision', 'job_id', 'operation', 'candidate_id',
                 'staging_preview_sha256', 'stage_job_id', 'acknowledge', 'review_hash'}
        keys(value, names, names); require(guid(actor) and guid(value['job_id']))
        creation = digest({'request': value, 'actor': actor})
        with self.store.connect() as db:
            db.execute('BEGIN IMMEDIATE'); scope = scope_id(self._binding(db)); ledger = self._read(db)
            old = next((j for j in ledger['jobs'] if j['id'] == value['job_id']), None)
            if old:
                require(old['creation_sha256'] == creation and old['scope'] == scope, 'STAGING_WRITE_ID_CONFLICT')
                return {'job_id': old['id'], 'recorded': True, 'state': self._state(old, scope, int(self.clock())), 'can_apply_gpo': False}
            p = self._review(db, {k: value[k] for k in names - {'review_hash'}}, actor)
            require(is_hash(value['review_hash']) and secrets.compare_digest(value['review_hash'], p['review_hash']),
                    'STAGING_WRITE_REVIEW_CHANGED')
            require(len(ledger['jobs']) < LIMIT, 'STAGING_WRITE_LIMIT')
            now = int(self.clock())
            require(not self._busy(ledger, p['target'], p['operation'], scope, now), 'STAGING_WRITE_GPO_BUSY')
            deadline = p['target']['preview_record']['Preview']['expires_at'] if p['operation'] == STAGE else now + LIFETIME
            ledger['jobs'].append({'id': p['job_id'], 'operation': p['operation'], 'actor': actor, 'scope': scope,
                'created': now, 'deadline': deadline, 'lease_id': '', 'lease_until': 0, 'state': 'queued',
                'intent_sha256': p['intent_sha256'], 'creation_sha256': creation, 'approval_sha256': p['review_hash'],
                'target': p['target'], 'authorized_at': 0, 'authorized_until': 0,
                'authorization_id': '', 'claim_sha256': '', 'result': None})
            self.ops._save(db, SECTION, ledger)
            self.ops._audit(db, 'staging_write_queued:' + p['operation'] + ':' + p['job_id'] + ':actor:' + actor, p['revision'])
            return {'job_id': p['job_id'], 'recorded': True, 'state': 'queued', 'can_apply_gpo': False}

    def poll(self, raw):
        with self.store.connect() as db:
            db.execute('BEGIN IMMEDIATE'); binding = self._binding(db); scope = scope_id(binding)
            request, identity, until, body = self._proof(raw, binding, 'POLL')
            require(set(body) == {'capability', 'release_id'} and body['capability'] == CAPABILITY and guid(body['release_id']))
            ledger = self._read(db); now = int(self.clock())
            ledger['polls'] = [p for p in ledger['polls'] if now < p['until']]
            require(len(ledger['polls']) < 128 and all(p['id'] != identity for p in ledger['polls']), 'STAGING_WRITE_POLL_REPLAY')
            ledger['polls'].append({'id': identity, 'until': until})
            ledger['last_poll'] = {'scope': scope, 'at': now, 'release_id': body['release_id']}
            # Offer only once. Lost offer/lease never causes automatic re-leasing.
            job = next((j for j in ledger['jobs'] if j['state'] == 'queued' and
                self._state(j, scope, now) == 'queued' and j['target']['writer_release_id'] == body['release_id'] and
                self._current(db, ledger, j)), None)
            if job:
                job.update(state='leased', lease_id=secrets.token_hex(32), lease_until=min(now + 90, job['deadline']))
            self.ops._save(db, SECTION, ledger)
            return {'format': 1, 'request_id': request, 'scope_sha256': scope,
                    'job_id': job['id'] if job else '', 'operation': job['operation'] if job else '',
                    'lease_id': job['lease_id'] if job else '', 'intent_sha256': job['intent_sha256'] if job else '',
                    'expires_at': job['lease_until'] if job else 0, 'target': copy.deepcopy(job['target']) if job else None,
                    'write_authorized': False, 'can_apply_gpo': False}

    def claim(self, raw):
        with self.store.connect() as db:
            db.execute('BEGIN IMMEDIATE'); binding = self._binding(db); scope = scope_id(binding)
            request, proof_hash, _, body = self._proof(raw, binding, 'CLAIM')
            keys(body, {'job_id', 'lease_id', 'intent_sha256', 'target_sha256', 'release_id'},
                       {'job_id', 'lease_id', 'intent_sha256', 'target_sha256', 'release_id'})
            ledger = self._read(db); now = int(self.clock())
            j = next((j for j in ledger['jobs'] if j['id'] == body['job_id']), None)
            require(j and j['scope'] == scope and self._state(j, scope, now) == 'leased', 'STAGING_WRITE_NOT_CLAIMABLE')
            require(body['lease_id'] == j['lease_id'] and body['intent_sha256'] == j['intent_sha256'] and
                    body['target_sha256'] == digest(j['target']) and body['release_id'] == j['target']['writer_release_id'] and
                    self._current(db, ledger, j), 'STAGING_WRITE_CLAIM_CHANGED')
            end = min(now + CLAIM_LIFETIME, j['lease_until'])
            require(now < end, 'STAGING_WRITE_NOT_CLAIMABLE')
            j.update(state='authorized', authorized_at=now, authorized_until=end,
                     authorization_id=secrets.token_hex(32), claim_sha256=proof_hash)
            self.ops._save(db, SECTION, ledger)
            self.ops._audit(db, 'staging_write_authorized:' + j['id'],
                            db.execute('SELECT revision FROM state WHERE id=1').fetchone()[0])
            return {'format': 1, 'request_id': request, 'job_id': j['id'], 'operation': j['operation'],
                    'intent_sha256': j['intent_sha256'], 'target_sha256': digest(j['target']),
                    'authorization_id': j['authorization_id'], 'expires_at': end,
                    'write_authorized': True, 'can_apply_gpo': False}

    def complete(self, raw):
        with self.store.connect() as db:
            db.execute('BEGIN IMMEDIATE'); binding = self._binding(db); scope = scope_id(binding)
            request, _, _, body = self._proof(raw, binding, 'RESULT'); ledger = self._read(db); now = int(self.clock())
            j = next((j for j in ledger['jobs'] if j['id'] == body.get('job_id')), None)
            require(j and j['scope'] == scope and self._result_valid(body, j))
            if j['state'] in {'completed', 'requires_review'}:
                require(j['result'] == body, 'STAGING_WRITE_RESULT_CONFLICT')
            else:
                require((j['state'] == 'authorized' or self._state(j, scope, now) == 'leased') and
                        0 <= now - body['checked_at'] <= RESULT_GRACE, 'STAGING_WRITE_RESULT_EXPIRED')
                # Do not discard outcome evidence merely because the plan changed
                # after authorization. Never use this result to authorize a new job.
                j.update(state='requires_review' if body['outcome'] == 'requires_review' else 'completed', result=body)
                self.ops._save(db, SECTION, ledger)
                self.ops._audit(db, 'staging_write_result:' + j['id'] + ':' + body['outcome'],
                                db.execute('SELECT revision FROM state WHERE id=1').fetchone()[0])
            return {'format': 1, 'request_id': request, 'job_id': j['id'],
                    'result_recorded': True, 'can_apply_gpo': False}

    def status(self):
        with self.store.connect() as db:
            db.execute('BEGIN'); ledger = self._read(db); now = int(self.clock())
            try:
                scope = scope_id(self._binding(db))
            except (JobError, RegistryError) as error:
                if error.code.endswith('STORE_INVALID'):
                    raise
                scope = None
            return {'revision': db.execute('SELECT revision FROM state WHERE id=1').fetchone()[0],
                    'source_only': True, 'execution_adapter_available': False, 'can_apply_gpo': False,
                    'jobs': [{'id': j['id'], 'operation': j['operation'], 'state': self._state(j, scope, now),
                              'authorization_issued': bool(j['authorization_id']),
                              'peer_reported_outcome': j['result']['outcome'] if j['result'] else None,
                              'customer_filesystem_attested': False} for j in reversed(ledger['jobs'])]}
