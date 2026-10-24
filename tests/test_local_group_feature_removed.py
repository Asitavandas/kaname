"""Keep direct principal rules while rejecting the cancelled selector."""
import unittest

from kaname.models import ValidationError, validate_policies
from kaname.policy import evaluate
from .helpers import policy, identity


class RemovedLocalGroupFeatureTests(unittest.TestCase):
    def test_cancelled_selector_is_invalid_not_a_wildcard(self):
        for selected in ([], ['11111111-2222-4333-8444-555555555555']):
            p=policy();p['conditions']['group_sids']=[]
            p['conditions']['local_group_ids']=selected
            with self.subTest(selected=selected),self.assertRaises(ValidationError):
                validate_policies([p])
            with self.assertRaises(ValidationError):evaluate([p],identity())

    def test_direct_user_sid_is_independent_of_ordinary_ad_group_membership(self):
        selected='S-1-5-21-10-20-30-1001'
        p=policy(vlan=50);p['conditions']['group_sids']=[selected]
        p['constraints']['require_domain_device']=False
        for groups in (frozenset(),frozenset({'S-1-5-21-10-20-30-8000'})):
            result=evaluate([p],identity(account_sid=selected,domain_device=False,group_sids=groups))
            self.assertEqual((result.action,result.vlan),('allow',50))
        result=evaluate([p],identity(account_sid=selected+'1',domain_device=False))
        self.assertEqual(result.reason,'NO_MATCHING_POLICY')
