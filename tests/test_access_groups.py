import copy
import json
import tempfile
import types
import unittest
import uuid
from concurrent.futures import ThreadPoolExecutor

from kaname.access_groups import AccessGroups, AccessGroupError, DEFINITIONS, member_key
from kaname.models import ValidationError, validate_policies
from kaname.operations import Operations
from kaname.policy import PolicyConflictError, evaluate
from kaname.radius import CertificateBinding, CertificateReference, CurrentDirectoryAccount, TLSAuthorization
from kaname.store import Store, ConflictError
from .helpers import config, policy, identity
from .test_membership import membership_catalog


class AccessGroupTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.store=Store(self.temp.name);self.store.save(0,config=config())
        self.ops=Operations(self.store);self.groups=AccessGroups(self.ops)
        self.catalog=membership_catalog();self.catalog['users'][0]['enabled']=True
        self.store.save_directory(1,self.catalog)

    def ref(self,plural='users',index=0):
        return {'guid':self.catalog[plural][index]['guid'],'kind':{'users':'user','computers':'computer'}[plural]}

    def save(self,name='VLAN50',members=None,id=''):
        return self.groups.save(self.store.snapshot()['revision'],{'id':id,'name':name,'members':[self.ref()] if members is None else members})

    def rule(self,group,vlan=50,id='local'):
        return policy(id=id,vlan=vlan,conditions={'group_sids':[],'local_group_ids':[group],'access_types':['wired','wireless'],'nas_ips':[]},constraints={'eap_methods':['EAP-TLS'],'require_domain_device':False})

    def account(self,plural='users',index=0,**changes):
        a=self.catalog[plural][index]
        fields=dict(domain='lab.example',object_guid=a['guid'],sid=a['sid'],kind='user' if plural=='users' else 'computer',enabled=True,security_group_sids=frozenset())
        return CurrentDirectoryAccount(**(fields|changes))

    def test_empty_read_does_not_initialize_or_change_business_state(self):
        before=self.store.snapshot(),self.store.audit()
        self.assertEqual([],self.groups.list()['items'])
        with self.store.connect() as db:self.assertIsNone(db.execute('SELECT payload FROM runtime_settings WHERE name=?',(DEFINITIONS,)).fetchone())
        self.assertEqual(before,(self.store.snapshot(),self.store.audit()))

    def test_local_membership_does_not_change_ad_catalog_and_survives_reopen(self):
        before=self.store.directory_catalog();result=self.save(members=[self.ref(),self.ref('computers')])
        self.assertEqual(before,self.store.directory_catalog())
        reopened=AccessGroups(Operations(Store(self.temp.name)))
        self.assertEqual(2,reopened.list()['items'][0]['member_count'])
        self.assertEqual({'user','computer'},{m['kind'] for m in result['members']})

    def test_second_group_reports_old_group_and_preserves_every_record(self):
        self.save('First');before=self.store.snapshot(),self.store.audit(),self.groups.list()
        with self.assertRaises(AccessGroupError) as e:self.save('Second')
        self.assertEqual('ACCESS_GROUP_MEMBER_EXISTS',e.exception.code)
        self.assertEqual('First',e.exception.details['group_name'])
        self.assertEqual(before,(self.store.snapshot(),self.store.audit(),self.groups.list()))

    def test_bulk_duplicate_is_atomic_and_explicit_removal_allows_move(self):
        first=self.save('First');second=self.save('Second',members=[])
        with self.assertRaises(AccessGroupError):self.save('Second',members=[self.ref('users',1),self.ref()],id=second['group']['id'])
        self.assertEqual([],self.groups.detail(second['group']['id'])['members'])
        self.save('First',members=[],id=first['group']['id'])
        self.assertEqual(1,len(self.save('Second',id=second['group']['id'])['members']))

    def test_concurrent_additions_cannot_create_second_membership(self):
        a=self.save('A',[]);b=self.save('B',[]);revision=self.store.snapshot()['revision']
        def add(result):
            try:self.groups.save(revision,{'id':result['group']['id'],'name':result['group']['name'],'members':[self.ref()]});return 'saved'
            except ConflictError:return 'conflict'
        with ThreadPoolExecutor(max_workers=2) as pool:results=list(pool.map(add,[a,b]))
        self.assertEqual(['conflict','saved'],sorted(results))
        self.assertEqual(1,sum(x['member_count'] for x in self.groups.list()['items']))

    def test_policy_and_local_vs_ad_or_direct_conflicts_are_blocked(self):
        group=self.save()['group']['id'];local=self.rule(group)
        ad=policy(id='ad',vlan=60,conditions={'group_sids':[self.catalog['groups'][0]['sid']],'access_types':[],'nas_ips':[]},constraints=local['constraints'])
        with self.assertRaises(PolicyConflictError):self.store.save(self.store.snapshot()['revision'],policies=[local,ad])
        ad['conditions']['group_sids']=[self.catalog['users'][0]['sid']]
        with self.assertRaises(PolicyConflictError):self.store.save(self.store.snapshot()['revision'],policies=[local,ad])

    def test_membership_change_cannot_introduce_rule_conflict(self):
        group=self.save(members=[])['group']['id'];local=self.rule(group)
        direct=policy(id='direct',vlan=60,conditions={'group_sids':[self.catalog['users'][0]['sid']],'access_types':[],'nas_ips':[]},constraints=local['constraints'])
        self.store.save(self.store.snapshot()['revision'],policies=[local,direct])
        before=self.store.snapshot(),self.store.audit()
        with self.assertRaises(PolicyConflictError):self.save(id=group)
        self.assertEqual([],self.groups.detail(group)['members']);self.assertEqual(before,(self.store.snapshot(),self.store.audit()))

    def test_in_use_group_cannot_be_deleted_even_if_rule_disabled(self):
        group=self.save()['group']['id'];rule=self.rule(group);rule['enabled']=False
        self.store.save(self.store.snapshot()['revision'],policies=[rule])
        with self.assertRaises(AccessGroupError) as error:self.groups.delete(self.store.snapshot()['revision'],group)
        self.assertEqual('ACCESS_GROUP_IN_USE',error.exception.code)
        self.store.save(self.store.snapshot()['revision'],policies=[])
        self.assertEqual([],self.groups.delete(self.store.snapshot()['revision'],group)['items'])

    def test_unknown_group_and_invalid_or_duplicate_member_are_rejected(self):
        with self.assertRaises(AccessGroupError):self.store.save(self.store.snapshot()['revision'],policies=[self.rule(str(uuid.uuid4()))])
        for refs in ([self.ref(),self.ref()],[{'guid':str(uuid.uuid4()),'kind':'user'}],[self.ref()|{'sid':'S-1-5-21-1-2-3-5'}]):
            with self.assertRaises(ValueError):self.save(members=refs)
        self.assertEqual([],self.groups.list()['items'])

    def test_stale_catalog_blocks_new_members_and_enabled_rule_not_removal(self):
        group=self.save()['group']['id']
        with self.store.connect() as db:db.execute("UPDATE directory_catalog SET synced_at='2020-01-01T00:00:00+00:00'")
        with self.assertRaises(AccessGroupError):self.save('New',members=[self.ref('users',1)])
        with self.assertRaises(AccessGroupError):self.store.save(self.store.snapshot()['revision'],policies=[self.rule(group)])
        self.assertEqual([],self.save(members=[],id=group)['members'])

    def test_recreated_account_never_inherits_old_group_and_input_sid_is_rejected(self):
        group=self.save()['group']['id'];rule=self.rule(group)
        self.store.save(self.store.snapshot()['revision'],policies=[rule])
        for changed in ({'object_guid':str(uuid.uuid4())},{'sid':'S-1-5-21-1-2-3-9999'},{'kind':'computer'}):
            _,ids=self.groups.authorization(self.account(**changed));self.assertEqual(frozenset(),ids)
        _,ids=self.groups.authorization(self.account());self.assertEqual(frozenset({group}),ids)

    def test_local_rule_never_becomes_wildcard_without_verified_membership(self):
        group=self.save()['group']['id'];rule=self.rule(group)
        self.assertEqual('NO_MATCHING_POLICY',evaluate([rule],identity()).reason)
        self.assertEqual(50,evaluate([rule],identity(),local_group_ids=frozenset({group})).vlan)
        for ids in ({group},frozenset({group,str(uuid.uuid4())})):
            with self.assertRaises(ValueError):evaluate([rule],identity(),local_group_ids=ids)

    def test_live_tls_user_local_group_and_unavailable_or_disabled_ad(self):
        group=self.save()['group']['id'];rule=self.rule(group)
        self.store.save(self.store.snapshot()['revision'],policies=[rule])
        reference=CertificateReference('a'*64,'1');a=self.account()
        binding=CertificateBinding(reference,a.domain,a.object_guid,a.sid,a.kind)
        service=TLSAuthorization([rule],registry=types.SimpleNamespace(lookup=lambda _:binding),directory=types.SimpleNamespace(lookup=lambda *_:a),local_groups=self.groups)
        self.assertEqual(50,service.authorize(reference,nas_ip='192.0.2.2',access_type='wired').vlan)
        service.directory=types.SimpleNamespace(lookup=lambda *_:self.account(enabled=False))
        self.assertEqual('ACCOUNT_DISABLED',service.authorize(reference,nas_ip='192.0.2.2',access_type='wired').reason)
        service.directory=None
        self.assertEqual('DIRECTORY_UNAVAILABLE',service.authorize(reference,nas_ip='192.0.2.2',access_type='wired').reason)
        service.local_groups=None;service.directory=types.SimpleNamespace(lookup=lambda *_:a)
        self.assertEqual('LOCAL_GROUPS_UNAVAILABLE',service.authorize(reference,nas_ip='192.0.2.2',access_type='wired').reason)

    def test_ad_read_cannot_reuse_old_local_membership_or_policy_snapshot(self):
        group=self.save()['group']['id'];rule=self.rule(group)
        self.store.save(self.store.snapshot()['revision'],policies=[rule])
        a=self.account();reference=CertificateReference('a'*64,'1');binding=CertificateBinding(reference,a.domain,a.object_guid,a.sid,a.kind)
        def live(*_):self.save(members=[],id=group);return a
        service=TLSAuthorization([rule],registry=types.SimpleNamespace(lookup=lambda _:binding),directory=types.SimpleNamespace(lookup=live),local_groups=self.groups)
        self.assertEqual('NO_MATCHING_POLICY',service.authorize(reference,nas_ip='192.0.2.2',access_type='wired').reason)

    def test_names_are_unique_and_old_policy_shape_is_unchanged(self):
        self.save('Group',members=[])
        with self.assertRaises(AccessGroupError):self.save('GROUP',members=[])
        self.assertEqual([policy()],validate_policies([policy()]))

    def test_200_users_in_different_ad_groups_keep_ad_membership_and_get_local_vlan(self):
        users=[]
        for index in range(200):
            user={'guid':str(uuid.UUID(int=10000+index)),'sid':'S-1-5-21-1-2-3-'+str(2000+index),
                  'sam':'localuser'+str(index),'name':'Local User '+str(index),'enabled':True,'primary_group_unresolved':True}
            self.catalog['users'].append(user);users.append(user)
            self.catalog['memberships'].append({'member_sid':user['sid'],'group_sid':self.catalog['groups'][index%len(self.catalog['groups'])]['sid'],'type':'direct'})
        self.store.save_directory(1,self.catalog);before=self.store.directory_catalog()
        result=self.save(members=[{'guid':u['guid'],'kind':'user'} for u in users]);gid=result['group']['id']
        self.store.save(self.store.snapshot()['revision'],policies=[self.rule(gid)])
        for user in users:
            account=CurrentDirectoryAccount('lab.example',user['guid'],user['sid'],'user',True,frozenset())
            rules,ids=self.groups.authorization(account)
            self.assertEqual(50,evaluate(rules,identity(domain_device=False,account_sid=user['sid']),local_group_ids=ids).vlan)
        self.assertEqual(before,self.store.directory_catalog())
        self.assertEqual(200,self.groups.list()['items'][0]['member_count'])

    def test_ad_change_after_rule_save_still_fails_closed_at_runtime(self):
        group=self.save(members=[self.ref('users',1)])['group']['id'];local=self.rule(group)
        ad=policy(id='ad',vlan=60,conditions={'group_sids':[self.catalog['groups'][0]['sid']],'access_types':[],'nas_ips':[]},constraints=local['constraints'])
        self.store.save(self.store.snapshot()['revision'],policies=[local,ad])
        account=self.account(index=1,security_group_sids=frozenset({self.catalog['groups'][0]['sid']}))
        rules,ids=self.groups.authorization(account)
        self.assertEqual('POLICY_CONFLICT',evaluate(rules,identity(domain_device=False,group_sids=account.security_group_sids,account_sid=account.sid),local_group_ids=ids).reason)

    def test_group_save_and_membership_roll_back_if_audit_fails(self):
        with self.store.connect() as db:db.execute("CREATE TRIGGER group_audit_fail BEFORE INSERT ON audit WHEN NEW.event LIKE 'access_group_saved:%' BEGIN SELECT RAISE(ABORT,'fixture'); END")
        with self.assertRaises(Exception):self.save()
        self.assertEqual([],self.groups.list()['items'])
        with self.store.connect() as db:self.assertEqual(0,db.execute("SELECT count(*) FROM runtime_settings WHERE name GLOB 'authwire-access-member:*'").fetchone()[0])
