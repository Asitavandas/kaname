"""Direct principal rules retain the certificate-to-live-AD trust boundary."""
import tempfile
import unittest
from dataclasses import replace

from kaname.models import ValidationError
from kaname.policy import evaluate, policy_conflicts
from kaname.radius import DirectoryUnavailable
from kaname.store import Store
from .helpers import config, policy, identity
from .test_radius import SID, binding, account
from .test_membership import computer_membership_catalog


class PrincipalPolicyTests(unittest.TestCase):
    def direct(self, sid=SID):
        p = policy()
        p['conditions']['group_sids'] = [sid]
        return p

    def test_direct_account_matches_only_its_verified_sid(self):
        p = self.direct()
        self.assertEqual(evaluate([p], identity(account_sid=SID)).action, 'allow')
        self.assertEqual(evaluate([p], identity()).reason, 'NO_MATCHING_POLICY')
        self.assertEqual(evaluate([p], identity(account_sid=SID+'1')).reason, 'NO_MATCHING_POLICY')

    def test_group_and_direct_principals_are_any_of_not_all_of(self):
        p = policy()
        p['conditions']['group_sids'].append(SID)
        self.assertEqual(evaluate([p], identity()).action, 'allow')
        self.assertEqual(evaluate([p], identity(group_sids=frozenset(), account_sid=SID)).action, 'allow')

    def test_direct_sid_does_not_bypass_verification_or_constraints(self):
        p = self.direct()
        for change, reason in [({'authenticated':False},'IDENTITY_NOT_VERIFIED'),
                               ({'directory_available':False},'DIRECTORY_UNAVAILABLE'),
                               ({'account_enabled':False},'ACCOUNT_DISABLED'),
                               ({'domain_device':False},'DOMAIN_DEVICE_REQUIRED')]:
            self.assertEqual(evaluate([p], identity(account_sid=SID, **change)).reason, reason)
        self.assertEqual(evaluate([self.direct()], identity(account_sid=SID, access_type='wireless')).action,'allow')
        p['conditions']['access_types']=['wired']
        self.assertEqual(evaluate([p], identity(account_sid=SID, access_type='wireless')).reason,'NO_MATCHING_POLICY')

    def test_user_account_is_distinct_from_machine_and_requires_user_authentication(self):
        p=self.direct()
        self.assertEqual(evaluate([p],identity(account_sid=SID,domain_device=False)).action,'deny')
        p['constraints']['require_domain_device']=False
        self.assertEqual(evaluate([p],identity(account_sid=SID,domain_device=False)).action,'allow')
        self.assertEqual(evaluate([p],identity(account_sid=SID+'1')).action,'deny')

    def test_invalid_trusted_sid_is_rejected(self):
        for bad in (None, True, ['S-1-5-21'], 'computer name', 'S-1-'+('1-'*100)+'1'):
            with self.subTest(bad=bad), self.assertRaises(ValidationError):identity(account_sid=bad)

    def test_direct_account_and_nested_group_conflicts_are_detected(self):
        catalog=computer_membership_catalog()
        direct=self.direct(catalog['computers'][0]['sid'])
        group=policy(id='group',vlan=140)
        group['conditions']['group_sids']=[catalog['groups'][-1]['sid']]
        self.assertEqual(len(policy_conflicts([direct,group],catalog)),1)

    def test_labels_expose_only_referenced_principals_with_types(self):
        with tempfile.TemporaryDirectory() as temp:
            store=Store(temp);store.save(0,config=config());catalog=computer_membership_catalog();store.save_directory(1,catalog)
            self.assertEqual(store.policy_labels()['items'],[])
            p=self.direct(catalog['computers'][0]['sid']);p['conditions']['group_sids'] += [catalog['users'][0]['sid'],catalog['groups'][0]['sid']]
            store.save(store.snapshot()['revision'],policies=[p])
            items=store.policy_labels()['items']
            self.assertEqual({x['kind'] for x in items},{'user','computer','group'})
            self.assertEqual({x['sid'] for x in items},set(p['conditions']['group_sids']))


class DirectRadiusTests(unittest.TestCase):
    def test_live_account_sid_is_supplied_after_binding_verification(self):
        from .test_radius import policy as radius_policy, RadiusAuthorizationTests
        fixture=RadiusAuthorizationTests()
        p=radius_policy();p['conditions']['group_sids']=[SID]
        s=fixture.service(policies=[p],a=account(security_group_sids=frozenset()))
        self.assertEqual(fixture.decide(s).action,'allow')
        s.directory.value=account(sid=SID+'1')
        self.assertEqual(fixture.decide(s).reason,'ACCOUNT_BINDING_MISMATCH')
        s.directory.value=account(enabled=False)
        self.assertEqual(fixture.decide(s).reason,'ACCOUNT_DISABLED')
        s.directory.value=DirectoryUnavailable()
        self.assertEqual(fixture.decide(s).reason,'DIRECTORY_UNAVAILABLE')
        s.registry.value=binding(active=False)
        self.assertEqual(fixture.decide(s).reason,'CERTIFICATE_INACTIVE')
