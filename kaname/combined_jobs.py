"""Authenticated, read-only candidate CONTENT verification, never GPO authority.

Separate paths/purpose/capability keep probe-only workers out of this queue.
The operator receipt remains immutable. Results are bound to its current
dependencies and do not assert fresh AD membership or live GPO state.
"""
from .connector_jobs import (ConnectorJobs, JobError, require, guid, HEX,
                             scope_id, sha, LIFETIME, LEASE, LIMIT)
from .connector_registry import digest, RegistryError
from .deployment_candidates import CandidateError, COMBINED
from .models import keys, strict_json
import secrets

SECTION = 'windows_combined_verify_jobs'
OPERATION = 'combined.verify.v1'
POLL_PATH = '/api/connector/v1/combined/poll'
RESULT_PATH = '/api/connector/v1/combined/result'
TARGET = {'candidate_id','network_candidate_id','plan_id','plan_version','gpo_id',
          'approval_sha256','network_manifest_sha256','manifest_sha256','draft_sha256',
          'dependency_sha256','publisher_thumbprint','machine_profile_id','machine_profile_version',
          'domain','root_thumbprint','group_sid'}


def target_valid(t):
    import re
    return (type(t) is dict and set(t) == TARGET and
            all(guid(t[n]) for n in ('candidate_id','network_candidate_id','plan_id','gpo_id','machine_profile_id')) and
            all(type(t[n]) is int and 1<=t[n]<2**31 for n in ('plan_version','machine_profile_version')) and
            all(type(t[n]) is str and HEX.fullmatch(t[n]) for n in
                ('approval_sha256','network_manifest_sha256','manifest_sha256','draft_sha256','dependency_sha256')) and
            type(t['publisher_thumbprint']) is str and re.fullmatch('[0-9A-F]{40}',t['publisher_thumbprint']) is not None and
            type(t['root_thumbprint']) is str and re.fullmatch('[0-9a-f]{40}',t['root_thumbprint']) is not None and
            type(t['group_sid']) is str and re.fullmatch(r'S-1-5-21-(?:[0-9]{1,10}-){3}[0-9]{1,10}',t['group_sid']) is not None and
            type(t['domain']) is str and len(t['domain'])<=253 and '.' in t['domain'] and
            all(re.fullmatch(r'[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?',label) for label in t['domain'].split('.')))


def intent_id(scope, identity, target):
    return sha(('AuthWireCombinedVerifyIntentV1\n'+scope+'\n'+identity+'\n'+digest(target)+'\n').encode('ascii'))


class CombinedJobs(ConnectorJobs):
    def __init__(self, candidates, **kwargs):
        super().__init__(candidates.registry, **kwargs)
        self.candidates = candidates

    def _target(self, db, identity):
        require(guid(identity))
        rows=self.candidates._read(db)
        row=next((r for r in rows if r['id']==identity),None)
        require(row is not None and row.get('artifact_kind')==COMBINED,'COMBINED_JOB_FORMAT_UNSUPPORTED')
        require(row['binding_scope']==scope_id(self._binding(db)) and
                self.candidates._dependencies(db,row['plan_id'],row['plan_version'])==row['dependency_sha256'],
                'COMBINED_JOB_TARGET_CHANGED')
        network=next((r for r in rows if r['id']==row['network_candidate_id']),None)
        require(network is not None and 'artifact_kind' not in network,'COMBINED_JOB_TARGET_CHANGED')
        state=self.candidates.dep._snapshot(db)
        plan=next((p for p in state['plans'] if p['id']==row['plan_id'] and p['version']==row['plan_version']),None)
        require(plan is not None,'COMBINED_JOB_TARGET_CHANGED')
        profile=next((p for p in state['machine_profiles'] if p['id']==plan['machine_profile_id']),None)
        require(profile is not None,'COMBINED_JOB_TARGET_CHANGED')
        trust=self.candidates.dep._trust(state,plan)
        value={n:row[n] for n in ('plan_id','plan_version','gpo_id','approval_sha256','manifest_sha256',
                                'draft_sha256','dependency_sha256','publisher_thumbprint','network_candidate_id')}
        value.update(candidate_id=row['id'],network_manifest_sha256=network['manifest_sha256'],
                     machine_profile_id=profile['id'],machine_profile_version=profile['version'],
                     domain=profile['domain'],root_thumbprint=trust['root_thumbprint'].lower(),group_sid=plan['computer_group_sid'])
        require(target_valid(value),'COMBINED_JOB_TARGET_CHANGED')
        return value

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
            raise JobError('COMBINED_JOB_STORE_INVALID') from None

    @staticmethod
    def _result_valid(v,j):
        names={'job_id','lease_id','intent_sha256','outcome','release_id','target_sha256'}
        return (type(v) is dict and set(v)==names and v['job_id']==j['id'] and
                v['lease_id']==j['lease_id'] and v['intent_sha256']==j['intent_sha256'] and
                v['target_sha256']==digest(j['target']) and guid(v['release_id']) and
                v['outcome'] in ('combined_content_verified','combined_content_rejected'))

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
        if row.get('artifact_kind')!=COMBINED:return False
        # Dependency and binding changes invalidate accepted content immediately.
        ledger=self._read(db)
        try:expected=self._target(db,row['id'])
        except (CandidateError,JobError,RegistryError) as error:
            if error.code.endswith('STORE_INVALID'):raise
            return False
        latest=next((j for j in reversed(ledger['jobs']) if j['target']==expected and
                     j['scope']==row['binding_scope'] and j['state']=='completed'),None)
        return bool(latest and latest['result']['outcome']=='combined_content_verified')

    def _intent(self,db,value):
        names={'expected_revision','job_id','operation','candidate_id'};keys(value,names,names)
        require(guid(value['job_id']) and value['operation']==OPERATION,'COMBINED_JOB_OPERATION_INVALID')
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
                require(old['creation_sha256']==creation and old['scope']==scope,'COMBINED_JOB_ID_CONFLICT')
                return {'job_id':old['id'],'recorded':True,'can_apply':False}
            p=self._intent(db,{k:value[k] for k in names-{'preview_hash'}})
            require(type(value['preview_hash']) is str and secrets.compare_digest(value['preview_hash'],p['preview_hash']),'COMBINED_JOB_PREVIEW_STALE')
            require(len(v['jobs'])<LIMIT,'COMBINED_JOB_LIMIT')
            require(not any(self._state(j,scope,now) in ('queued','leased') and self._current(db,j) for j in v['jobs']),'COMBINED_JOB_BUSY')
            last=v['last_poll']
            require(last and last['scope']==scope and 0<=now-last['at']<90,'COMBINED_WORKER_NOT_READY')
            v['jobs'].append({'id':value['job_id'],'operation':OPERATION,'actor':actor,'scope':scope,
                'created':now,'deadline':now+LIFETIME,'lease_until':0,'lease_id':'','state':'queued',
                'intent_sha256':p['intent_sha256'],'creation_sha256':creation,'result':None,'target':p['target']})
            self.ops._save(db,SECTION,v);self.ops._audit(db,'combined_verify_queued:'+value['job_id']+':actor:'+actor,p['revision'])
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
            if job['state']=='completed':require(job['result']==body,'COMBINED_JOB_RESULT_CONFLICT')
            else:
                require(self._state(job,scope,now)=='leased');job.update(state='completed',result=body)
                self.ops._save(db,SECTION,v)
                revision=db.execute('SELECT revision FROM state WHERE id=1').fetchone()[0];self.ops._revision(db,revision)
                self.ops._audit(db,'combined_verify_'+body['outcome']+':'+job['id'],revision)
            return {'format':1,'request_id':request,'job_id':job['id'],'result_recorded':True,'read_only':True,'can_apply':False}

    def _proof(self,raw,binding,kind):
        # Same bounded RSA framing primitive; purpose and routes are separate.
        from .connector_jobs import verify_job_proof
        return verify_job_proof(raw,binding,kind,self.clock,
            prefix='AUTHWIRE-COMBINED-JOB-',poll_path=POLL_PATH,result_path=RESULT_PATH)

