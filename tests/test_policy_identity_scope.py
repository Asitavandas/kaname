"""Explicit identity scope is backed by bound certificate + fresh AD, not UI claims."""
import copy,tempfile,unittest
from dataclasses import asdict
from kaname.models import ValidationError,validate_policies
from kaname.policy import evaluate,policy_conflicts,validate_identity_targets,VerifiedIdentity
from kaname.store import Store
from .helpers import identity,policy,config
from .test_membership import computer_membership_catalog
from . import test_radius as rf
from .test_radius import binding,account,policy as radius_policy,SID,GROUP


def scoped(kind='user',**changes):
 p=policy();p['conditions']['identity_types']=[kind] if kind!='both' else ['user','computer'];p['constraints']['require_domain_device']=kind=='computer';p.update(changes);return p

class ScopeModelTests(unittest.TestCase):
 def test_legacy_rule_roundtrip_does_not_add_or_change_scope(self):
  p=policy();self.assertEqual([p],validate_policies([p]));self.assertNotIn('identity_types',p['conditions'])
 def test_strict_scope_and_contradictory_user_device_guard(self):
  for value in [[],['guest'],['user','user'],'user',None,[True]]:
   p=scoped();p['conditions']['identity_types']=value
   with self.subTest(value=value),self.assertRaises(ValidationError):validate_policies([p])
  p=scoped();p['constraints']['require_domain_device']=True
  with self.assertRaisesRegex(ValidationError,'POLICY_IDENTITY_SCOPE_INVALID'):validate_policies([p])
 def test_domain_device_flag_alone_is_not_user_proof(self):
  self.assertEqual('NO_MATCHING_POLICY',evaluate([scoped()],identity(domain_device=False)).reason)
  self.assertEqual('NO_MATCHING_POLICY',evaluate([scoped('computer')],identity()).reason)
  with self.assertRaises(ValidationError):identity(account_kind='user',domain_device=True)
  for bad in [None,True,'Computer','group']:
   with self.subTest(bad=bad),self.assertRaises(ValidationError):identity(account_kind=bad)
 def test_user_and_computer_same_group_can_receive_distinct_vlan(self):
  user=scoped(vlan=50);computer=scoped('computer',id='computer',vlan=110)
  self.assertEqual([],policy_conflicts([user,computer]))
  self.assertEqual(50,evaluate([computer,user],identity(domain_device=False,account_kind='user')).vlan)
  self.assertEqual(110,evaluate([user,computer],identity(account_kind='computer')).vlan)
 def test_wrong_scope_never_uses_other_role_fallback(self):
  self.assertEqual('NO_MATCHING_POLICY',evaluate([scoped()],identity(account_kind='computer')).reason)
  self.assertEqual('NO_MATCHING_POLICY',evaluate([scoped('computer')],identity(account_kind='user',domain_device=False)).reason)
 def test_verification_membership_eap_nas_and_enabled_gates_still_apply(self):
  p=scoped();base={'domain_device':False,'account_kind':'user'}
  for change,reason in [({'authenticated':False},'IDENTITY_NOT_VERIFIED'),({'directory_available':False},'DIRECTORY_UNAVAILABLE'),({'account_enabled':False},'ACCOUNT_DISABLED'),({'group_sids':frozenset()},'NO_MATCHING_POLICY'),({'eap_method':'PEAP-MSCHAPV2'},'EAP_CONSTRAINT_FAILED')]:
   self.assertEqual(reason,evaluate([p],identity(**(base|change))).reason)
  p['conditions']['nas_ips']=['192.0.2.20'];self.assertEqual('NO_MATCHING_POLICY',evaluate([p],identity(**base)).reason)
  p['enabled']=False;self.assertEqual('NO_MATCHING_POLICY',evaluate([p],identity(**base)).reason)
 def test_scoped_conflict_still_denies_runtime_and_store(self):
  p=scoped(vlan=50);q=scoped(id='other',vlan=60)
  self.assertEqual(1,len(policy_conflicts([p,q])));self.assertEqual('POLICY_CONFLICT',evaluate([p,q],identity(domain_device=False,account_kind='user')).reason)
 def test_legacy_computer_requirement_is_not_silently_reinterpreted(self):
  old=policy(vlan=110);user=scoped(id='user',vlan=50)
  self.assertEqual(1,len(policy_conflicts([old,user])))
  self.assertEqual('POLICY_CONFLICT',evaluate([old,user],identity(domain_device=False,account_kind='user')).reason)
  self.assertEqual('DOMAIN_DEVICE_REQUIRED',evaluate([old],identity(domain_device=False,account_kind='user')).reason)
 def test_both_scope_can_match_each_proven_kind(self):
  p=scoped('both')
  for kind in ['computer','user']:self.assertEqual('allow',evaluate([p],identity(account_kind=kind,domain_device=kind=='computer')).action)

class ScopeCatalogTests(unittest.TestCase):
 def setUp(self):self.catalog=computer_membership_catalog()
 def test_direct_kind_mismatch_is_rejected_before_save(self):
  p=scoped();p['conditions']['group_sids']=[self.catalog['computers'][0]['sid']]
  with self.assertRaisesRegex(ValidationError,'POLICY_IDENTITY_SCOPE_MISMATCH'):validate_identity_targets([p],self.catalog)
  p=scoped('computer');p['conditions']['group_sids']=[self.catalog['users'][0]['sid']]
  with self.assertRaisesRegex(ValidationError,'POLICY_IDENTITY_SCOPE_MISMATCH'):validate_identity_targets([p],self.catalog)
 def test_groups_are_not_inferred_as_computers_and_missing_labels_never_prove_kind(self):
  p=scoped();p['conditions']['group_sids']=[self.catalog['groups'][0]['sid']];validate_identity_targets([p],self.catalog);validate_identity_targets([p],None)
  self.assertEqual('NO_MATCHING_POLICY',evaluate([p],identity(domain_device=False)).reason)
 def test_same_group_disjoint_scopes_but_nested_same_scope_conflicts(self):
  user=scoped(vlan=50);user['conditions']['group_sids']=[self.catalog['groups'][0]['sid']]
  computer=scoped('computer',id='pc',vlan=110);computer['conditions']['group_sids']=user['conditions']['group_sids'][:]
  self.assertEqual([],policy_conflicts([user,computer],self.catalog))
  direct=scoped(id='direct',vlan=60);direct['conditions']['group_sids']=[self.catalog['users'][0]['sid']]
  self.assertEqual(1,len(policy_conflicts([user,direct],self.catalog)))
 def test_observed_member_overlap_is_filtered_by_the_common_verified_kind(self):
  left=scoped('computer');left['conditions']['group_sids']=[self.catalog['groups'][1]['sid']]
  right=scoped('computer',id='right',vlan=60);right['conditions']['group_sids']=[self.catalog['groups'][3]['sid']]
  self.assertEqual([],policy_conflicts([left,right],self.catalog))
  left['conditions']['identity_types']=['user'];right['conditions']['identity_types']=['user'];left['constraints']['require_domain_device']=False;right['constraints']['require_domain_device']=False
  self.assertEqual(1,len(policy_conflicts([left,right],self.catalog)))
 def test_direct_user_any_ad_group_matches_only_its_sid(self):
  p=scoped();sid=self.catalog['users'][1]['sid'];p['conditions']['group_sids']=[sid]
  self.assertEqual(50,evaluate([scoped(vlan=50)|{'conditions':p['conditions']}],identity(domain_device=False,account_kind='user',account_sid=sid,group_sids=frozenset())).vlan)
  self.assertEqual('NO_MATCHING_POLICY',evaluate([p],identity(domain_device=False,account_kind='user',account_sid=self.catalog['users'][0]['sid'],group_sids=frozenset())).reason)
 def test_store_rejects_mismatch_atomically_and_keeps_legacy_bytes(self):
  with tempfile.TemporaryDirectory() as t:
   s=Store(t);s.save(0,config=config());s.save_directory(1,self.catalog);before=s.snapshot()
   p=scoped();p['conditions']['group_sids']=[self.catalog['computers'][0]['sid']]
   with self.assertRaises(ValidationError):s.save(before['revision'],policies=[p])
   self.assertEqual(before,s.snapshot())
   legacy=policy();s.save(before['revision'],policies=[legacy]);self.assertEqual([legacy],s.snapshot()['policies'])

class ScopeRadiusTests(unittest.TestCase):
 def service(self,p,kind='user',**changes):
  f=rf.RadiusAuthorizationTests();s=f.service(b=binding(kind=kind),a=account(kind=kind),policies=[p],**changes);return f,s
 def user_policy(self):
  p=radius_policy(vlan=50);p['conditions']['identity_types']=['user'];p['constraints']['require_domain_device']=False;return p
 def test_actual_adapter_supplies_fresh_kind_after_binding_and_registry_recheck(self):
  p=self.user_policy();f,s=self.service(p);self.assertEqual(50,f.decide(s).vlan)
  f,s=self.service(p,kind='computer');self.assertEqual('NO_MATCHING_POLICY',f.decide(s).reason)
  s.directory.value=account(kind='user');self.assertEqual('ACCOUNT_BINDING_MISMATCH',f.decide(s).reason)
 def test_user_kind_does_not_bypass_inactive_certificate_or_group_removal(self):
  p=self.user_policy();f,s=self.service(p);s.directory.value=account(kind='user',security_group_sids=frozenset());self.assertEqual('NO_MATCHING_POLICY',f.decide(s).reason)
  f,s=self.service(p);s.registry.value=binding(kind='user',active=False);self.assertEqual('CERTIFICATE_INACTIVE',f.decide(s).reason)
