"""Separate bounded live-directory/owned-GPO READ snapshot jobs.

A successful snapshot is never GPO staging, write permission or execution.
A Windows scope-capable worker must be delivered separately.
"""
from .connector_jobs import (ConnectorJobs, JobError, require, guid, HEX,
                             scope_id, sha, LIFETIME, LEASE, LIMIT)
from .connector_registry import digest, RegistryError
from .deployment_candidates import CandidateError
from .models import keys, strict_json
import secrets
import re
from .combined_jobs import CombinedJobs, TARGET as CONTENT_TARGET, target_valid as content_target_valid
from .membership import related

SECTION = 'windows_combined_scope_jobs'
OPERATION = 'combined.scope.verify.v1'
POLL_PATH = '/api/connector/v1/combined-scope/poll'
RESULT_PATH = '/api/connector/v1/combined-scope/result'
TARGET = CONTENT_TARGET | {'target_sids_sha256','target_count','content_result_sha256'}

CHECKS = ['combined_content','network_content','directory','gpo_identity','gpo_permissions',
          'gpo_unlinked','gpo_empty','sysvol_root_acl','sysvol_tree']

REJECTIONS = {'CONTENT_REJECTED','DIRECTORY_SCOPE_CHANGED','GPO_SCOPE_CHANGED',
              'READ_TIMEOUT','READ_FAILED'}


def target_sids_hash(sids):
    return sha(('AuthWireDeploymentTargetsV1\n'+'\n'.join(sorted(sids))+'\n').encode('ascii'))


def target_valid(t):
    return (type(t) is dict and set(t)==TARGET and
            content_target_valid({k:t[k] for k in CONTENT_TARGET}) and
            all(type(t[n]) is str and HEX.fullmatch(t[n]) for n in ('target_sids_sha256','content_result_sha256')) and
            type(t['target_count']) is int and 1<=t['target_count']<=512)


def intent_id(scope, identity, target):
    return sha(('AuthWireCombinedScopeIntentV1\n'+scope+'\n'+identity+'\n'+digest(target)+'\n').encode('ascii'))


class CombinedScopeJobs(ConnectorJobs):
    def __init__(self, candidates, **kwargs):
        super().__init__(candidates.registry, **kwargs)
        self.candidates = candidates

    def _target(self, db, identity):
        content=CombinedJobs(self.candidates,wall_clock=self.clock)
        target=content._target(db,identity)
        row=next(r for r in self.candidates._read(db) if r['id']==identity)
        require(content.content_verified(db,row),'COMBINED_SCOPE_CONTENT_REQUIRED')
        # Bind this snapshot to the exact latest accepted combined content proof.
        accepted=next(j for j in reversed(content._read(db)['jobs']) if j['target']==target and
                      j['scope']==row['binding_scope'] and j['state']=='completed')
        require(accepted['result']['outcome']=='combined_content_verified','COMBINED_SCOPE_CONTENT_REQUIRED')
        target['content_result_sha256']=digest({'job_id':accepted['id'],
            'intent_sha256':accepted['intent_sha256'],'result':accepted['result']})
        state=self.candidates.dep._snapshot(db)
        plan=next(p for p in state['plans'] if p['id']==target['plan_id'])
        catalog=state['catalog']
        require(catalog and catalog.get('membership_schema')==1,'COMBINED_SCOPE_DIRECTORY_NOT_READY')
        group=next((g for g in catalog['groups'] if g['sid']==plan['computer_group_sid'] and g.get('security_enabled')),None)
        require(group is not None,'COMBINED_SCOPE_DIRECTORY_NOT_READY')
        accounts,stats=related(catalog,'groups',group)
        computers=[a for a in accounts if a['kind']=='computers']
        require(not stats['unresolved_members'] and 1<=len(computers)<=512 and
                all(a['enabled'] for a in computers),'COMBINED_SCOPE_DIRECTORY_NOT_READY')
        sids=sorted(a['sid'] for a in computers)
        domain_sid=self._binding(db).service_sid.rsplit('-',1)[0]
        require(len(set(sids))==len(sids) and all(type(sid) is str and
                re.fullmatch(r'S-1-5-21-(?:[0-9]{1,10}-){3}[0-9]{1,10}',sid) and
                sid.rsplit('-',1)[0]==domain_sid for sid in sids) and
                plan['computer_group_sid'].rsplit('-',1)[0]==domain_sid,
                'COMBINED_SCOPE_DIRECTORY_NOT_READY')
        target.update(target_sids_sha256=target_sids_hash(sids),target_count=len(sids))
        return target

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
            raise JobError('COMBINED_SCOPE_JOB_STORE_INVALID') from None

    @staticmethod
    def _result_valid(v,j):
        names={'job_id','lease_id','intent_sha256','outcome','release_id','target_sha256',
               'checked_at','checks','reason','observations_sha256'}
        if not (type(v) is dict and set(v)==names and v['job_id']==j['id'] and
                v['lease_id']==j['lease_id'] and v['intent_sha256']==j['intent_sha256'] and
                v['target_sha256']==digest(j['target']) and guid(v['release_id']) and
                type(v['checked_at']) is int and j['created']<=v['checked_at']<=j['lease_until'] and
                type(v['observations_sha256']) is str and HEX.fullmatch(v['observations_sha256']) and
                type(v['checks']) is list): return False
        if v['outcome']=='combined_scope_snapshot_verified':
            return v['reason']=='OK' and v['checks']==CHECKS
        return (v['outcome']=='combined_scope_snapshot_rejected' and v['checks']==[] and
                type(v['reason']) is str and v['reason'] in REJECTIONS)

    def status(self):
        with self.store.connect() as db:
            db.execute('BEGIN'); v=self._read(db); now=int(self.clock())
            try: scope=scope_id(self._binding(db))
            except (JobError,RegistryError) as e:
                if e.code.endswith('STORE_INVALID'): raise
                scope=None
            last=v['last_poll']
            return {'revision':db.execute('SELECT revision FROM state WHERE id=1').fetchone()[0],
                    'scope_snapshot_only':True,'can_apply':False,
                    'worker_ready':bool(scope and last and last['scope']==scope and 0<=now-last['at']<90),
                    'jobs':[{'id':j['id'],'candidate_id':j['target']['candidate_id'],
                             'state':self._state(j,scope,now) if self._current(db,j) else 'obsolete',
                             'created_at':j['created'],'result':j['result']} for j in reversed(v['jobs'])]}

    def snapshot(self,db,row):
        empty={'scope_snapshot_verified':False,'scope_snapshot_fresh':False,
               'scope_checked_at':None,'scope_reason':None}
        # Validate this ledger even if current content is rejected. Corrupt state
        # must not silently become a normal unavailable snapshot.
        ledger=self._read(db)
        try: expected=self._target(db,row['id'])
        except (CandidateError,JobError,RegistryError) as e:
            if e.code.endswith('STORE_INVALID'): raise
            return empty
        latest=next((j for j in reversed(ledger['jobs']) if j['target']==expected and
                     j['scope']==row['binding_scope'] and j['state']=='completed'),None)
        if latest is None:return empty
        v=latest['result'];verified=v['outcome']=='combined_scope_snapshot_verified'
        return {'scope_snapshot_verified':verified,
                'scope_snapshot_fresh':bool(verified and 0<=int(self.clock())-v['checked_at']<90),
                'scope_checked_at':v['checked_at'],'scope_reason':v['reason']}

    def _intent(self,db,value):
        names={'expected_revision','job_id','operation','candidate_id'};keys(value,names,names)
        require(guid(value['job_id']) and value['operation']==OPERATION,'COMBINED_SCOPE_JOB_OPERATION_INVALID')
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
                require(old['creation_sha256']==creation and old['scope']==scope,'COMBINED_SCOPE_JOB_ID_CONFLICT')
                return {'job_id':old['id'],'recorded':True,'can_apply':False}
            p=self._intent(db,{k:value[k] for k in names-{'preview_hash'}})
            require(type(value['preview_hash']) is str and secrets.compare_digest(value['preview_hash'],p['preview_hash']),'COMBINED_SCOPE_JOB_PREVIEW_STALE')
            require(len(v['jobs'])<LIMIT,'COMBINED_SCOPE_JOB_LIMIT')
            require(not any(self._state(j,scope,now) in ('queued','leased') and self._current(db,j) for j in v['jobs']),'COMBINED_SCOPE_JOB_BUSY')
            last=v['last_poll']
            require(last and last['scope']==scope and 0<=now-last['at']<90,'COMBINED_SCOPE_WORKER_NOT_READY')
            v['jobs'].append({'id':value['job_id'],'operation':OPERATION,'actor':actor,'scope':scope,
                'created':now,'deadline':now+LIFETIME,'lease_until':0,'lease_id':'','state':'queued',
                'intent_sha256':p['intent_sha256'],'creation_sha256':creation,'result':None,'target':p['target']})
            self.ops._save(db,SECTION,v);self.ops._audit(db,'combined_scope_queued:'+value['job_id']+':actor:'+actor,p['revision'])
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
            if job['state']=='completed':require(job['result']==body,'COMBINED_SCOPE_JOB_RESULT_CONFLICT')
            else:
                require(self._state(job,scope,now)=='leased' and 0<=now-body['checked_at']<90);job.update(state='completed',result=body)
                self.ops._save(db,SECTION,v)
                revision=db.execute('SELECT revision FROM state WHERE id=1').fetchone()[0];self.ops._revision(db,revision)
                self.ops._audit(db,'combined_scope_'+body['outcome']+':'+job['id'],revision)
            return {'format':1,'request_id':request,'job_id':job['id'],'result_recorded':True,'read_only':True,'can_apply':False}

    def _proof(self,raw,binding,kind):
        # Same bounded RSA framing primitive; purpose and routes are separate.
        from .connector_jobs import verify_job_proof
        return verify_job_proof(raw,binding,kind,self.clock,
            prefix='AUTHWIRE-COMBINED-SCOPE-JOB-',poll_path=POLL_PATH,result_path=RESULT_PATH)
