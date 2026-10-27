"""Operator-reported local candidates, not machine attestation or deployment jobs.

Importing a receipt never grants execution authority. A future typed worker must
independently verify it before any GPO staging can become available.
"""
import json
import re
import secrets
import time

from .connector_jobs import guid, scope_id
from .connector_registry import decode_binding, digest, RegistryError
from .models import keys, strict_json

SECTION = 'windows_deployment_candidates'
HEX = re.compile(r'[0-9a-f]{64}\Z')
LIMIT = 32


class CandidateError(ValueError):
    def __init__(self, code): self.code = code; super().__init__(code)


def require(value, code='DEPLOYMENT_CANDIDATE_INPUT_INVALID'):
    if not value: raise CandidateError(code)


class DeploymentCandidates:
    def __init__(self, registry, deployment, *, wall_clock=time.time):
        self.registry, self.dep = registry, deployment
        self.ops, self.store, self.clock = registry.ops, registry.store, wall_clock

    def _binding(self, db):
        record = self.registry._read(db)
        require(record and record['state'] == 'paired', 'CONNECTOR_NOT_PAIRED')
        require(self.registry._scope_matches(record, self.registry._context(db)), 'CONNECTOR_CONTEXT_CHANGED')
        return decode_binding(record['binding'])

    def _read(self, db):
        row = db.execute('SELECT payload FROM runtime_settings WHERE name=?', (SECTION,)).fetchone()
        if row is None: return []
        try:
            require(type(row[0]) is str and len(row[0]) <= 65536)
            rows = strict_json(row[0]); require(type(rows) is list and len(rows) <= LIMIT)
            seen = set()
            names = {'id','plan_id','plan_version','gpo_id','manifest_sha256','approval_sha256',
                     'source_commit','actor','created_at','binding_scope','dependency_sha256','request_sha256'}
            for item in rows:
                keys(item, names, names)
                require(all(guid(item[n]) for n in ('id','plan_id','gpo_id','actor')) and item['id'] not in seen)
                seen.add(item['id'])
                require(type(item['plan_version']) is int and 1 <= item['plan_version'] < 2**31)
                require(type(item['created_at']) is int and 0 < item['created_at'] < 2**40)
                require(all(type(item[n]) is str and HEX.fullmatch(item[n]) for n in
                            ('manifest_sha256','approval_sha256','binding_scope','dependency_sha256','request_sha256')))
                require(type(item['source_commit']) is str and re.fullmatch('[0-9a-f]{40}',item['source_commit']))
            return rows
        except (ValueError, TypeError, KeyError, AttributeError):
            raise CandidateError('DEPLOYMENT_CANDIDATE_STORE_INVALID') from None

    def _dependencies(self, db, identity, version):
        s = self.dep._snapshot(db)
        plan = next((p for p in s['plans'] if p['id'] == identity and p['version'] == version), None)
        require(plan is not None, 'DEPLOYMENT_CANDIDATE_PLAN_CHANGED')
        # The accepted candidate format is the machine Ethernet+Wi-Fi pilot.
        require(plan['auth_mode'] == 'machine' and plan['wired'] is True and plan['wireless'] is True,
                'DEPLOYMENT_CANDIDATE_MODE_UNSUPPORTED')
        profile = next((p for p in s['machine_profiles'] if p['id'] == plan['machine_profile_id']), None)
        require(profile and profile['enabled'] and profile['domain'] == plan['domain'] == s['config'].get('ad_domain')
                and profile['group_sid'] == plan['computer_group_sid'], 'DEPLOYMENT_CANDIDATE_PLAN_CHANGED')
        targets = self.dep._targets(s, plan['computer_group_sid'], 'computers')
        require(targets['available'] and targets['enabled'] and not targets['unresolved'], 'DEPLOYMENT_CANDIDATE_TARGETS_NOT_READY')
        trust = self.dep._trust(s, plan)
        require(trust['ready'], 'DEPLOYMENT_CANDIDATE_TRUST_NOT_READY')
        catalog = dict(s['catalog'] or {}); catalog.pop('synced_at', None)
        # A harmless directory timestamp/revision refresh does not imply deployment.
        # Any actual catalog, profile, plan, trust or configuration change invalidates it.
        return digest({'plan':plan, 'profile':profile, 'catalog':catalog, 'config':s['config'], 'trust':trust})

    def _receipt(self, raw):
        require(type(raw) is str and len(raw) <= 8192)
        try:
            v = strict_json(raw)
            top = {'Event','ToolVersion','Mode','Computer','SourceCommit','SourcesDirectory','SourcesPreparedNow',
                   'SourceSignaturesValid','ApprovalSha256','Stage','Candidate','ExistingConnectorChanged',
                   'AdChanged','GpoChanged','TrustStoreChanged','KeyAclChanged','WindowsEndpointChanged','CanApplyGpo','SecretsExported'}
            nested = {'Event','CandidatePath','PlanId','PlanVersion','GpoId','ManifestSha256','SignatureVerified',
                      'ArtifactExecuted','CanApplyGpo','AdChanged','GpoChanged','EndpointChanged','ServicesChanged',
                      'TrustStoreChanged','KeyAclChanged','SecretsExported','PreparedNow'}
            keys(v, top, top); c = v['Candidate']; keys(c, nested, nested)
            require(v['Event'] == 'WINDOWS_DEPLOYMENT_CANDIDATE_DELIVERY' and v['ToolVersion'] == '1.0.0'
                    and v['Mode'] == 'Prepare' and v['Stage'] == 'prepared' and c['Event'] == 'WINDOWS_DEPLOYMENT_CANDIDATE')
            for obj, allowed in ((v, {'SourcesPreparedNow','SourceSignaturesValid'}), (c, {'SignatureVerified','PreparedNow'})):
                for name, value in obj.items():
                    if type(value) is bool: require(name in allowed or value is False)
                for name in allowed: require(type(obj[name]) is bool)
            for name in ('ExistingConnectorChanged','AdChanged','GpoChanged','TrustStoreChanged','KeyAclChanged',
                         'WindowsEndpointChanged','CanApplyGpo','SecretsExported'): require(v[name] is False)
            for name in ('ArtifactExecuted','CanApplyGpo','AdChanged','GpoChanged','EndpointChanged','ServicesChanged',
                         'TrustStoreChanged','KeyAclChanged','SecretsExported'): require(c[name] is False)
            require(v['SourceSignaturesValid'] is True and c['SignatureVerified'] is True)
            require(all(guid(c[n]) for n in ('PlanId','GpoId')) and type(c['PlanVersion']) is int and 1 <= c['PlanVersion'] < 2**31)
            require(all(type(x) is str and HEX.fullmatch(x) for x in (v['ApprovalSha256'],c['ManifestSha256'])))
            require(type(v['SourceCommit']) is str and re.fullmatch('[0-9a-f]{40}',v['SourceCommit']))
            for value in (v['Computer'],v['SourcesDirectory'],c['CandidatePath']):
                require(type(value) is str and 1 <= len(value) <= 512 and not any(ord(ch)<32 for ch in value))
            # Paths are ignored and never returned, persisted, opened or executed.
            return {'plan_id':c['PlanId'],'plan_version':c['PlanVersion'],'gpo_id':c['GpoId'],
                    'manifest_sha256':c['ManifestSha256'],'approval_sha256':v['ApprovalSha256'],
                    'source_commit':v['SourceCommit']}, v['Computer']
        except (ValueError, TypeError, KeyError, AttributeError):
            raise CandidateError('DEPLOYMENT_CANDIDATE_RECEIPT_INVALID') from None

    def _intent(self, db, value):
        names = {'expected_revision','registration_id','receipt_json'}; keys(value,names,names)
        require(guid(value['registration_id']))
        revision = self.ops._revision(db,value['expected_revision'])
        summary, computer = self._receipt(value['receipt_json']); binding = self._binding(db)
        require(computer.casefold() == binding.host_fqdn.split('.')[0].casefold(), 'DEPLOYMENT_CANDIDATE_HOST_MISMATCH')
        dependencies = self._dependencies(db,summary['plan_id'],summary['plan_version'])
        p = {'id':value['registration_id'], **summary, 'binding_scope':scope_id(binding),
             'dependency_sha256':dependencies, 'revision':revision, 'state':'operator_reported',
             'connector_verified':False,'can_apply':False,'gpo_changed':False}
        p['preview_hash'] = digest(p)
        return p

    def preview(self, value):
        with self.store.connect() as db: db.execute('BEGIN'); return self._intent(db,value)

    def record(self, value, actor):
        names = {'expected_revision','registration_id','receipt_json','preview_hash'}; keys(value,names,names)
        require(guid(actor) and guid(value['registration_id']))
        token = digest({'value':value,'actor':actor})
        with self.store.connect() as db:
            db.execute('BEGIN IMMEDIATE'); rows=self._read(db); binding=self._binding(db)
            old=next((r for r in rows if r['id']==value['registration_id']),None)
            if old:
                require(old['request_sha256']==token and old['binding_scope']==scope_id(binding),'DEPLOYMENT_CANDIDATE_ID_CONFLICT')
                return {'id':old['id'],'recorded':True,'connector_verified':False,'can_apply':False}
            p=self._intent(db,{k:value[k] for k in names-{'preview_hash'}})
            require(type(value['preview_hash']) is str and secrets.compare_digest(value['preview_hash'],p['preview_hash']), 'DEPLOYMENT_CANDIDATE_PREVIEW_STALE')
            require(len(rows)<LIMIT,'DEPLOYMENT_CANDIDATE_LIMIT')
            require(not any(r['plan_id']==p['plan_id'] and r['plan_version']==p['plan_version']
                            and r['binding_scope']==p['binding_scope'] and r['dependency_sha256']==p['dependency_sha256']
                            for r in rows),'DEPLOYMENT_CANDIDATE_ALREADY_RECORDED')
            rows.append({k:p[k] for k in ('id','plan_id','plan_version','gpo_id','manifest_sha256','approval_sha256',
                                         'source_commit','binding_scope','dependency_sha256')} |
                        {'actor':actor,'created_at':int(self.clock()),'request_sha256':token})
            self.ops._save(db,SECTION,rows)
            self.ops._audit(db,'deployment_candidate_reported:'+p['id']+':actor:'+actor,p['revision'])
            return {'id':p['id'],'recorded':True,'connector_verified':False,'can_apply':False}

    def status(self):
        with self.store.connect() as db:
            db.execute('BEGIN'); rows=self._read(db); result=[]
            try: binding=scope_id(self._binding(db))
            except (CandidateError,RegistryError) as e:
                if e.code not in {'CONNECTOR_NOT_PAIRED','CONNECTOR_CONTEXT_CHANGED','CONNECTOR_CONTEXT_NOT_READY'}: raise
                binding=None
            from .candidate_jobs import CandidateJobs
            jobs=CandidateJobs(self,wall_clock=self.clock)
            for row in reversed(rows):
                current=row['binding_scope']==binding
                if current:
                    try: current=self._dependencies(db,row['plan_id'],row['plan_version'])==row['dependency_sha256']
                    except CandidateError: current=False
                verified=bool(current and jobs.content_verified(db,row))
                result.append({k:row[k] for k in ('id','plan_id','plan_version','gpo_id','manifest_sha256','approval_sha256','created_at')} |
                              {'state':('content_verified' if verified else 'operator_reported') if current else 'outdated',
                               'content_verified':verified,'connector_verified':False,'can_apply':False})
            ledger=jobs._read(db);last=ledger['last_poll'];now=int(self.clock())
            ready=bool(binding and last and last['scope']==binding and 0<=now-last['at']<90)
            verification=[{'id':j['id'],'candidate_id':j['target']['candidate_id'],
                           'state':jobs._state(j,binding,now) if jobs._current(db,j) else 'obsolete',
                           'outcome':j['result']['outcome'] if j['result'] else None}
                          for j in reversed(ledger['jobs'])]
            return {'revision':db.execute('SELECT revision FROM state WHERE id=1').fetchone()[0],
                    'candidates':result,'worker_delivery_pending':not ready,'verification_worker_ready':ready,
                    'verification_jobs':verification,'can_apply':False}
