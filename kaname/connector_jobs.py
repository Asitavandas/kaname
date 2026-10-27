"""Durable, authenticated read-only Connector probe jobs. No command/GPO executor.

V1 permits only connector.probe. Re-evaluating that read-only probe is harmless;
this is idempotent result recording, not a claim of exactly-once GPO execution.
Pairing is reloaded in the same write transaction as every peer transition.
"""
import base64
import hashlib
import re
import secrets
import time
import uuid

from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding

from .connector_registry import decode_binding, digest, RegistryError
from .models import keys, strict_json

SECTION = 'windows_connector_probe_jobs'
OPERATION = 'connector.probe'
POLL_PATH = '/api/connector/v1/jobs/poll'
RESULT_PATH = '/api/connector/v1/jobs/result'
LIMIT = 32
LIFETIME = 300
LEASE = 90
HEX = re.compile(r'[0-9a-f]{64}\Z')


class JobError(ValueError):
    def __init__(self, code):
        self.code = code
        super().__init__(code)


def require(ok, code='CONNECTOR_JOB_REJECTED'):
    if not ok:
        raise JobError(code)


def guid(value):
    try:
        return (type(value) is str and str(uuid.UUID(value)) == value and
                uuid.UUID(value).int != 0)
    except (ValueError, AttributeError):
        return False


def sha(value):
    return hashlib.sha256(value).hexdigest()


def scope_id(binding):
    return sha(('AuthWireConnectorJobBindingV1\n' + '\n'.join(binding.fields()) + '\n').encode('ascii'))


def intent_id(scope, identity):
    return sha(('AuthWireConnectorProbeIntentV1\n' + scope + '\n' + identity + '\n' + OPERATION + '\n').encode('ascii'))


class ConnectorJobs:
    def __init__(self, registry, *, wall_clock=time.time):
        self.registry, self.ops, self.store = registry, registry.ops, registry.store
        self.clock = wall_clock

    def _binding(self, db):
        record = self.registry._read(db)
        require(record is not None and record['state'] == 'paired', 'CONNECTOR_NOT_PAIRED')
        require(self.registry._scope_matches(record, self.registry._context(db)), 'CONNECTOR_CONTEXT_CHANGED')
        return decode_binding(record['binding'])

    def _read(self, db):
        row = db.execute('SELECT payload FROM runtime_settings WHERE name=?', (SECTION,)).fetchone()
        if row is None:
            return {'format': 1, 'jobs': [], 'polls': [], 'last_poll': None}
        try:
            require(type(row[0]) is str and len(row[0]) <= 100000)
            v = strict_json(row[0]); keys(v, {'format', 'jobs', 'polls', 'last_poll'}, {'format', 'jobs', 'polls', 'last_poll'})
            require(type(v['format']) is int and v['format'] == 1)
            require(type(v['jobs']) is list and len(v['jobs']) <= LIMIT)
            require(type(v['polls']) is list and len(v['polls']) <= 128)
            ids = set()
            for j in v['jobs']:
                names = {'id', 'operation', 'actor', 'scope', 'created', 'deadline', 'lease_until',
                         'lease_id', 'state', 'intent_sha256', 'creation_sha256', 'result'}
                keys(j, names, names)
                require(guid(j['id']) and j['id'] not in ids and guid(j['actor']))
                ids.add(j['id'])
                require(j['operation'] == OPERATION and type(j['state']) is str and j['state'] in ('queued', 'leased', 'completed'))
                require(all(type(j[k]) is str and HEX.fullmatch(j[k]) for k in ('scope', 'intent_sha256', 'creation_sha256')))
                require(j['intent_sha256'] == intent_id(j['scope'], j['id']))
                require(all(type(j[k]) is int and 0 < j[k] < 2**40 for k in ('created', 'deadline')))
                require(j['deadline'] - j['created'] == LIFETIME)
                if j['state'] == 'queued':
                    require(j['lease_id'] == '' and type(j['lease_until']) is int and j['lease_until'] == 0 and j['result'] is None)
                else:
                    require(type(j['lease_id']) is str and HEX.fullmatch(j['lease_id']))
                    require(type(j['lease_until']) is int and j['created'] < j['lease_until'] <= j['deadline'])
                    require(j['result'] is None if j['state'] == 'leased' else self._result_valid(j['result'], j))
            for poll in v['polls']:
                keys(poll, {'id', 'until'}, {'id', 'until'})
                require(type(poll['id']) is str and HEX.fullmatch(poll['id']) and type(poll['until']) is int and 0 < poll['until'] < 2**40)
            if v['last_poll'] is not None:
                keys(v['last_poll'], {'scope', 'at'}, {'scope', 'at'})
                require(type(v['last_poll']['scope']) is str and HEX.fullmatch(v['last_poll']['scope']))
                require(type(v['last_poll']['at']) is int and 0 < v['last_poll']['at'] < 2**40)
            return v
        except (ValueError, TypeError, KeyError, AttributeError):
            raise JobError('CONNECTOR_JOB_STORE_INVALID') from None

    @staticmethod
    def _result_valid(value, job):
        names = {'job_id', 'lease_id', 'intent_sha256', 'outcome', 'release_id'}
        if type(value) is not dict or set(value) != names:
            return False
        return (value['job_id'] == job['id'] and value['lease_id'] == job['lease_id'] and
                value['intent_sha256'] == job['intent_sha256'] and
                value['outcome'] == 'probe_completed' and guid(value['release_id']))

    @staticmethod
    def _state(job, scope, now):
        if job['scope'] != scope:
            return 'obsolete'
        if job['state'] == 'completed':
            return 'completed'
        if now < job['created'] - 5 or now >= (job['lease_until'] if job['state'] == 'leased' else job['deadline']):
            return 'expired'
        return job['state']

    def status(self):
        with self.store.connect() as db:
            db.execute('BEGIN')
            revision = db.execute('SELECT revision FROM state WHERE id=1').fetchone()[0]
            v = self._read(db); now = int(self.clock())
            try:
                scope = scope_id(self._binding(db))
            except (JobError, RegistryError) as error:
                if error.code not in {'CONNECTOR_NOT_PAIRED', 'CONNECTOR_CONTEXT_CHANGED', 'CONNECTOR_CONTEXT_NOT_READY'}:
                    raise
                scope = None
            last = v['last_poll']
            return {'revision': revision, 'probe_only': True, 'can_apply': False,
                    'worker_probe_ready': bool(scope and last and last['scope'] == scope and 0 <= now - last['at'] < 90),
                    'jobs': [{'id': j['id'], 'operation': OPERATION, 'state': self._state(j, scope, now),
                              'created_at': j['created'], 'expires_at': j['deadline'], 'result': j['result'],
                              'read_only': True, 'gpo_changed': False} for j in reversed(v['jobs'])]}

    def _intent(self, db, value):
        names = {'expected_revision', 'job_id', 'operation'}
        keys(value, names, names)
        require(guid(value['job_id']) and value['operation'] == OPERATION, 'CONNECTOR_JOB_OPERATION_INVALID')
        revision = self.ops._revision(db, value['expected_revision'])
        scope = scope_id(self._binding(db))
        preview = {'revision': revision, 'job_id': value['job_id'], 'operation': OPERATION,
                   'scope_sha256': scope, 'intent_sha256': intent_id(scope, value['job_id']),
                   'read_only': True, 'gpo_changed': False, 'can_apply': False}
        preview['preview_hash'] = digest(preview)
        return preview

    def preview(self, value):
        with self.store.connect() as db:
            db.execute('BEGIN')
            return self._intent(db, value)

    def create(self, value, actor):
        names = {'expected_revision', 'job_id', 'operation', 'preview_hash'}
        keys(value, names, names)
        require(guid(actor) and guid(value['job_id']), 'CONNECTOR_JOB_INPUT_INVALID')
        require(value['operation'] == OPERATION, 'CONNECTOR_JOB_OPERATION_INVALID')
        creation = digest({'request': value, 'actor': actor})
        with self.store.connect() as db:
            db.execute('BEGIN IMMEDIATE')
            scope = scope_id(self._binding(db)); v = self._read(db); now = int(self.clock())
            old = next((j for j in v['jobs'] if j['id'] == value['job_id']), None)
            if old:
                require(old['creation_sha256'] == creation and old['scope'] == scope, 'CONNECTOR_JOB_ID_CONFLICT')
                return {'job_id': old['id'], 'state': self._state(old, scope, now), 'recorded': True, 'read_only': True, 'gpo_changed': False}
            preview = self._intent(db, {k: value[k] for k in ('expected_revision', 'job_id', 'operation')})
            require(type(value['preview_hash']) is str and secrets.compare_digest(value['preview_hash'], preview['preview_hash']), 'CONNECTOR_JOB_PREVIEW_STALE')
            # Never discard an ID and then execute it again. The bounded ledger fills closed.
            require(len(v['jobs']) < LIMIT, 'CONNECTOR_JOB_LIMIT')
            require(sum(self._state(j, scope, now) in ('queued', 'leased') for j in v['jobs']) < 4, 'CONNECTOR_JOB_BUSY')
            v['jobs'].append({'id': value['job_id'], 'operation': OPERATION, 'actor': actor, 'scope': scope,
                              'created': now, 'deadline': now + LIFETIME, 'lease_until': 0, 'lease_id': '',
                              'state': 'queued', 'intent_sha256': preview['intent_sha256'],
                              'creation_sha256': creation, 'result': None})
            self.ops._save(db, SECTION, v)
            self.ops._audit(db, 'connector_probe_queued:' + value['job_id'] + ':actor:' + actor, preview['revision'])
            return {'job_id': value['job_id'], 'state': 'queued', 'recorded': True, 'read_only': True, 'gpo_changed': False}

    def _proof(self, raw, binding, kind):
        result = verify_job_proof(raw,binding,kind,self.clock)
        if kind == 'POLL': require(result[3] == {})
        return result

    def poll(self, raw):
        with self.store.connect() as db:
            db.execute('BEGIN IMMEDIATE')
            binding = self._binding(db); scope = scope_id(binding)
            request, identity, until, _ = self._proof(raw, binding, 'POLL')
            v = self._read(db); now = int(self.clock())
            v['polls'] = [p for p in v['polls'] if now < p['until']]
            require(all(p['id'] != identity for p in v['polls']))
            require(len(v['polls']) < 128, 'CONNECTOR_JOB_BUSY')
            v['polls'].append({'id': identity, 'until': until})
            v['last_poll'] = {'scope': scope, 'at': now}
            job = next((j for j in v['jobs'] if self._state(j, scope, now) == 'leased'), None)
            if job is None:
                job = next((j for j in v['jobs'] if self._state(j, scope, now) == 'queued'), None)
                if job:
                    job.update(state='leased', lease_id=secrets.token_hex(32), lease_until=min(now + LEASE, job['deadline']))
            self.ops._save(db, SECTION, v)
            return {'format': 1, 'request_id': request, 'scope_sha256': scope,
                    'job_id': job['id'] if job else '', 'operation': OPERATION if job else '',
                    'lease_id': job['lease_id'] if job else '', 'intent_sha256': job['intent_sha256'] if job else '',
                    'expires_at': job['lease_until'] if job else 0, 'read_only': True, 'can_apply': False}

    def complete(self, raw):
        with self.store.connect() as db:
            db.execute('BEGIN IMMEDIATE')
            binding = self._binding(db); scope = scope_id(binding)
            request, _, _, body = self._proof(raw, binding, 'RESULT')
            v = self._read(db); now = int(self.clock())
            require(guid(body.get('job_id')))
            job = next((j for j in v['jobs'] if j['id'] == body['job_id']), None)
            require(job is not None and job['scope'] == scope and self._result_valid(body, job))
            if job['state'] == 'completed':
                require(job['result'] == body, 'CONNECTOR_JOB_RESULT_CONFLICT')
            else:
                require(self._state(job, scope, now) == 'leased')
                job.update(state='completed', result=body)
                self.ops._save(db, SECTION, v)
                revision = db.execute('SELECT revision FROM state WHERE id=1').fetchone()[0]
                self.ops._revision(db, revision)
                self.ops._audit(db, 'connector_probe_completed:' + job['id'], revision)
            return {'format': 1, 'request_id': request, 'job_id': job['id'],
                    'result_recorded': True, 'read_only': True, 'can_apply': False}


def verify_job_proof(raw,binding,kind,clock,*,prefix='AUTHWIRE-CONNECTOR-JOB-',
                     poll_path=POLL_PATH,result_path=RESULT_PATH):
    try:
        require(type(raw) is bytes and 1 <= len(raw) <= 4096)
        value = strict_json(raw.decode('utf-8')); keys(value, {'frame', 'signature', 'payload'}, {'frame', 'signature', 'payload'})
        decoded = []
        for name, limit in (('frame', 2048), ('signature', 512), ('payload', 1024)):
            text = value[name]; require(type(text) is str and len(text) <= (limit + 2) // 3 * 4)
            data = base64.b64decode(text, validate=True)
            require(len(data) <= limit and base64.b64encode(data).decode('ascii') == text)
            decoded.append(data)
        frame, signature, payload = decoded
        fields = frame.decode('ascii').split('\n')
        path = poll_path if kind == 'POLL' else result_path
        require(len(fields) == 18 and fields[-1] == '' and fields[0] == prefix + kind + '-V1')
        require(fields[1:10] == binding.fields() and fields[14:17] == [sha(payload), 'POST', path])
        require(all(HEX.fullmatch(s) for s in fields[10:12]))
        require(all(re.fullmatch('[1-9][0-9]{0,10}', s) for s in fields[12:14]))
        now = int(clock()); issued, until = int(fields[12]), int(fields[13])
        require(until - issued == 60 and issued - 5 <= now < until)
        public = serialization.load_pem_public_key(binding.public_key_pem)
        require(len(signature) == public.key_size // 8)
        public.verify(signature, frame, padding.PKCS1v15(), hashes.SHA256())
        require(issued - 5 <= int(clock()) < until)
        body = strict_json(payload.decode('utf-8'))
        require(type(body) is dict)
        return fields[10], sha(frame), until, body
    except (ValueError, TypeError, UnicodeError, InvalidSignature, KeyError):
        raise JobError('CONNECTOR_JOB_REJECTED') from None

