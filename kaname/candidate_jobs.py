"""Authenticated, read-only candidate CONTENT verification, never GPO authority.

Separate paths/purpose/capability keep probe-only workers out of this queue.
The operator receipt remains immutable. Results are bound to its current
dependencies and do not assert fresh AD membership or live GPO state.
"""
from .connector_jobs import (ConnectorJobs, JobError, require, guid, HEX,
                             scope_id, sha, LIFETIME, LEASE, LIMIT)
from .connector_registry import digest, RegistryError
from .deployment_candidates import CandidateError
from .models import keys, strict_json
import secrets

SECTION = 'windows_candidate_verify_jobs'
OPERATION = 'candidate.verify.v1'
POLL_PATH = '/api/connector/v1/candidates/poll'
RESULT_PATH = '/api/connector/v1/candidates/result'
TARGET = {'candidate_id','plan_id','plan_version','gpo_id','approval_sha256',
          'manifest_sha256','dependency_sha256'}


def target_valid(t):
    return (type(t) is dict and set(t) == TARGET and
            all(guid(t[n]) for n in ('candidate_id','plan_id','gpo_id')) and
            type(t['plan_version']) is int and 1 <= t['plan_version'] < 2**31 and
            all(type(t[n]) is str and HEX.fullmatch(t[n]) for n in
                ('approval_sha256','manifest_sha256','dependency_sha256')))


def intent_id(scope, identity, target):
    return sha(('AuthWireCandidateVerifyIntentV1\n'+scope+'\n'+identity+'\n'+digest(target)+'\n').encode('ascii'))


class CandidateJobs(ConnectorJobs):
    def __init__(self, candidates, **kwargs):
        super().__init__(candidates.registry, **kwargs)
        self.candidates = candidates

    def _target(self, db, identity):
        require(guid(identity))
        row = next((r for r in self.candidates._read(db) if r['id'] == identity), None)
        require(row is not None, 'CANDIDATE_JOB_TARGET_CHANGED')
        require('artifact_kind' not in row, 'CANDIDATE_JOB_FORMAT_UNSUPPORTED')
        binding = scope_id(self._binding(db))
        require(row['binding_scope'] == binding, 'CANDIDATE_JOB_TARGET_CHANGED')
        require(self.candidates._dependencies(db,row['plan_id'],row['plan_version']) == row['dependency_sha256'],
                'CANDIDATE_JOB_TARGET_CHANGED')
        return {'candidate_id':row['id'], **{n:row[n] for n in TARGET-{'candidate_id'}}}

    def _current(self, db, job):
        try: return self._target(db,job['target']['candidate_id']) == job['target']
        except (CandidateError,JobError,RegistryError) as e:
            if e.code.endswith('STORE_INVALID'): raise
            return False

    def _read(self, db):
        row=db.execute('SELECT payload FROM runtime_settings WHERE name=?',(SECTION,)).fetchone()
        if row is None: return {'format':1,'jobs':[],'polls':[],'last_poll':None}
        try:
            require(type(row[0]) is str and len(row[0]) <= 100000)
            v=strict_json(row[0]); keys(v,{'format','jobs','polls','last_poll'},{'format','jobs','polls','last_poll'})
            require(type(v['format']) is int and v['format']==1)
            require(type(v['jobs']) is list and len(v['jobs'])<=LIMIT)
            require(type(v['polls']) is list and len(v['polls'])<=128)
            ids=set()
            names={'id','operation','actor','scope','created','deadline','lease_until','lease_id',
                   'state','intent_sha256','creation_sha256','result','target'}
            for j in v['jobs']:
                keys(j,names,names)
                require(guid(j['id']) and j['id'] not in ids and guid(j['actor'])); ids.add(j['id'])
                require(j['operation']==OPERATION and j['state'] in ('queued','leased','completed') and target_valid(j['target']))
                require(all(type(j[n]) is str and HEX.fullmatch(j[n]) for n in ('scope','intent_sha256','creation_sha256')))
                require(j['intent_sha256']==intent_id(j['scope'],j['id'],j['target']))
                require(all(type(j[n]) is int and 0<j[n]<2**40 for n in ('created','deadline')) and j['deadline']-j['created']==LIFETIME)
                if j['state']=='queued':
                    require(j['lease_id']=='' and type(j['lease_until']) is int and j['lease_until']==0 and j['result'] is None)
                else:
                    require(type(j['lease_id']) is str and HEX.fullmatch(j['lease_id']))
                    require(type(j['lease_until']) is int and j['created']<j['lease_until']<=j['deadline'])
                    require(j['result'] is None if j['state']=='leased' else self._result_valid(j['result'],j))
            for p in v['polls']:
                keys(p,{'id','until'},{'id','until'})
                require(type(p['id']) is str and HEX.fullmatch(p['id']) and type(p['until']) is int and 0<p['until']<2**40)
            p=v['last_poll']
            if p is not None:
                keys(p,{'scope','at','release_id'},{'scope','at','release_id'})
                require(type(p['scope']) is str and HEX.fullmatch(p['scope']) and type(p['at']) is int and 0<p['at']<2**40 and guid(p['release_id']))
            return v
        except (ValueError,TypeError,KeyError,AttributeError):
            raise JobError('CANDIDATE_JOB_STORE_INVALID') from None

    @staticmethod
    def _result_valid(v,j):
        names={'job_id','lease_id','intent_sha256','outcome','release_id','target_sha256'}
        return (type(v) is dict and set(v)==names and v['job_id']==j['id'] and
                v['lease_id']==j['lease_id'] and v['intent_sha256']==j['intent_sha256'] and
                v['target_sha256']==digest(j['target']) and guid(v['release_id']) and
                v['outcome'] in ('content_verified','content_rejected'))

    def status(self):
        with self.store.connect() as db:
            db.execute('BEGIN'); v=self._read(db); now=int(self.clock())
            try: scope=scope_id(self._binding(db))
            except (JobError,RegistryError) as e:
                if e.code.endswith('STORE_INVALID'): raise
                scope=None
            last=v['last_poll']
            return {'revision':db.execute('SELECT revision FROM state WHERE id=1').fetchone()[0],
                    'content_only':True,'can_apply':False,
                    'worker_ready':bool(scope and last and last['scope']==scope and 0<=now-last['at']<90),
                    'jobs':[{'id':j['id'],'candidate_id':j['target']['candidate_id'],
                             'state':self._state(j,scope,now) if self._current(db,j) else 'obsolete',
                             'created_at':j['created'],'result':j['result']} for j in reversed(v['jobs'])]}

    def content_verified(self,db,row):
        if 'artifact_kind' in row: return False
        # Current dependency check is performed by the candidate status caller.
        expected={'candidate_id':row['id'],**{n:row[n] for n in TARGET-{'candidate_id'}}}
        latest=next((j for j in reversed(self._read(db)['jobs']) if
                     j['target']==expected and j['scope']==row['binding_scope'] and j['state']=='completed'),None)
        return bool(latest and latest['result']['outcome']=='content_verified')

    def _intent(self,db,value):
        names={'expected_revision','job_id','operation','candidate_id'};keys(value,names,names)
        require(guid(value['job_id']) and value['operation']==OPERATION,'CANDIDATE_JOB_OPERATION_INVALID')
        revision=self.ops._revision(db,value['expected_revision']); scope=scope_id(self._binding(db))
        target=self._target(db,value['candidate_id'])
        p={'revision':revision,'job_id':value['job_id'],'operation':OPERATION,'target':target,
           'intent_sha256':intent_id(scope,value['job_id'],target),'read_only':True,'can_apply':False}
        p['preview_hash']=digest(p);return p

    def create(self,value,actor):
        names={'expected_revision','job_id','operation','candidate_id','preview_hash'};keys(value,names,names)
        require(guid(actor) and guid(value['job_id']) and value['operation']==OPERATION)
        creation=digest({'request':value,'actor':actor})
        with self.store.connect() as db:
            db.execute('BEGIN IMMEDIATE');scope=scope_id(self._binding(db));v=self._read(db);now=int(self.clock())
            old=next((j for j in v['jobs'] if j['id']==value['job_id']),None)
            if old:
                require(old['creation_sha256']==creation and old['scope']==scope,'CANDIDATE_JOB_ID_CONFLICT')
                return {'job_id':old['id'],'recorded':True,'can_apply':False}
            p=self._intent(db,{k:value[k] for k in names-{'preview_hash'}})
            require(type(value['preview_hash']) is str and secrets.compare_digest(value['preview_hash'],p['preview_hash']),'CANDIDATE_JOB_PREVIEW_STALE')
            require(len(v['jobs'])<LIMIT,'CANDIDATE_JOB_LIMIT')
            require(not any(self._state(j,scope,now) in ('queued','leased') and self._current(db,j) for j in v['jobs']),'CANDIDATE_JOB_BUSY')
            last=v['last_poll']
            require(last and last['scope']==scope and 0<=now-last['at']<90,'CANDIDATE_WORKER_NOT_READY')
            v['jobs'].append({'id':value['job_id'],'operation':OPERATION,'actor':actor,'scope':scope,
                'created':now,'deadline':now+LIFETIME,'lease_until':0,'lease_id':'','state':'queued',
                'intent_sha256':p['intent_sha256'],'creation_sha256':creation,'result':None,'target':p['target']})
            self.ops._save(db,SECTION,v);self.ops._audit(db,'candidate_verify_queued:'+value['job_id']+':actor:'+actor,p['revision'])
            return {'job_id':value['job_id'],'recorded':True,'can_apply':False}

    def poll(self,raw):
        with self.store.connect() as db:
            db.execute('BEGIN IMMEDIATE');binding=self._binding(db);scope=scope_id(binding)
            request,identity,until,body=self._proof(raw,binding,'POLL')
            require(set(body)=={'capability','release_id'} and body['capability']==OPERATION and guid(body['release_id']))
            v=self._read(db);now=int(self.clock());v['polls']=[p for p in v['polls'] if now<p['until']]
            require(all(p['id']!=identity for p in v['polls']) and len(v['polls'])<128)
            v['polls'].append({'id':identity,'until':until});v['last_poll']={'scope':scope,'at':now,'release_id':body['release_id']}
            eligible=[j for j in v['jobs'] if self._state(j,scope,now) in ('queued','leased') and self._current(db,j)]
            job=next((j for j in eligible if j['state']=='leased'),eligible[0] if eligible else None)
            if job and job['state']=='queued':job.update(state='leased',lease_id=secrets.token_hex(32),lease_until=min(now+LEASE,job['deadline']))
            self.ops._save(db,SECTION,v)
            return {'format':1,'request_id':request,'scope_sha256':scope,'job_id':job['id'] if job else '',
                    'operation':OPERATION if job else '','lease_id':job['lease_id'] if job else '',
                    'intent_sha256':job['intent_sha256'] if job else '','expires_at':job['lease_until'] if job else 0,
                    'target':job['target'] if job else None,'read_only':True,'can_apply':False}

    def complete(self,raw):
        with self.store.connect() as db:
            db.execute('BEGIN IMMEDIATE');binding=self._binding(db);scope=scope_id(binding)
            request,_,_,body=self._proof(raw,binding,'RESULT');v=self._read(db);now=int(self.clock())
            require(guid(body.get('job_id')));job=next((j for j in v['jobs'] if j['id']==body['job_id']),None)
            require(job and job['scope']==scope and self._result_valid(body,job) and self._current(db,job))
            if job['state']=='completed':require(job['result']==body,'CANDIDATE_JOB_RESULT_CONFLICT')
            else:
                require(self._state(job,scope,now)=='leased');job.update(state='completed',result=body)
                self.ops._save(db,SECTION,v)
                revision=db.execute('SELECT revision FROM state WHERE id=1').fetchone()[0];self.ops._revision(db,revision)
                self.ops._audit(db,'candidate_verify_'+body['outcome']+':'+job['id'],revision)
            return {'format':1,'request_id':request,'job_id':job['id'],'result_recorded':True,'read_only':True,'can_apply':False}

    def _proof(self,raw,binding,kind):
        # Same bounded RSA framing primitive; purpose and routes are separate.
        from .connector_jobs import verify_job_proof
        return verify_job_proof(raw,binding,kind,self.clock,
            prefix='AUTHWIRE-CANDIDATE-JOB-',poll_path=POLL_PATH,result_path=RESULT_PATH)

