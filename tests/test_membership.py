import copy
import tempfile
import unittest

from kaname.directory import validate_catalog
from kaname.models import ValidationError
from kaname.store import Store
from .helpers import config
from .test_directory import catalog
from . import test_directory


def membership_catalog():
    value = catalog()
    value.update(membership_schema=1, memberships=[])
    value['users'][0]['primary_group_unresolved'] = False
    value['users'].append({'guid': '00000000-0000-0000-0000-000000000003', 'sid': 'S-1-5-21-1-2-3-1001', 'sam': 'bob', 'name': 'Bob', 'enabled': True, 'primary_group_unresolved': False})
    value['computers'].append({'guid': '00000000-0000-0000-0000-000000000007', 'sid': 'S-1-5-21-1-2-3-1002', 'sam': 'PC$', 'name': 'PC', 'enabled': True, 'primary_group_unresolved': True})
    value['groups'][0].update(security_enabled=True, unresolved_members=1)
    for i, rid, name, security in [(4, 513, 'Domain Users', True), (5, 1200, 'Department', False), (6, 1300, 'Parent', True)]:
        value['groups'].append({'guid': f'00000000-0000-0000-0000-{i:012}', 'sid': f'S-1-5-21-1-2-3-{rid}', 'sam': name, 'name': name, 'security_enabled': security, 'unresolved_members': 0})
    for member, group, kind in [(1000, 1100, 'direct'), (1000, 513, 'primary'), (1001, 513, 'primary'), (1100, 1200, 'direct'), (1200, 1300, 'direct'), (1002, 1100, 'direct')]:
        value['memberships'].append({'member_sid': f'S-1-5-21-1-2-3-{member}', 'group_sid': f'S-1-5-21-1-2-3-{group}', 'type': kind})
    return value


class MembershipTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.store = Store(self.temp.name); self.store.save(0, config=config())
        self.value = membership_catalog(); self.store.save_directory(1, self.value)

    def detail(self, kind, index=0, **kwargs):
        return self.store.directory_detail(kind, self.value[kind][index]['guid'], **kwargs)

    def test_direct_primary_and_nested_distribution_bridge_are_visible(self):
        value = self.detail('users')
        self.assertTrue(value['membership_available'])
        self.assertEqual({'Access': 'direct', 'Domain Users': 'primary', 'Department': 'indirect', 'Parent': 'indirect'}, {x['sam']: x['membership'] for x in value['items']})

    def test_group_details_match_user_details_and_include_primary_members(self):
        self.assertEqual({'alice': 'primary', 'bob': 'primary'}, {x['sam']: x['membership'] for x in self.detail('groups', 1)['items']})
        self.assertEqual({'alice': 'indirect'}, {x['sam']: x['membership'] for x in self.detail('groups', 3)['items']})
        self.assertEqual(1, self.detail('groups')['computer_members'])
        self.assertEqual(1, self.detail('groups', 3)['unresolved_members'])
        self.assertEqual(2, self.detail('groups', 3)['nested_groups'])

    def test_cycle_terminates_and_keeps_direct_membership_priority(self):
        self.value['memberships'].append({'member_sid': self.value['groups'][3]['sid'], 'group_sid': self.value['groups'][0]['sid'], 'type': 'direct'})
        self.store.save_directory(1, self.value)
        self.assertEqual(4, self.detail('users')['total'])
        self.assertEqual('direct', next(x for x in self.detail('users')['items'] if x['sam'] == 'Access')['membership'])
        self.assertEqual(1, self.detail('groups')['total'])

    def test_legacy_catalog_does_not_claim_no_members(self):
        old = catalog(); self.store.save_directory(1, old)
        detail = self.store.directory_detail('users', old['users'][0]['guid'])
        self.assertFalse(detail['membership_available']); self.assertEqual([], detail['items'])
        self.assertFalse(self.store.directory_status()['membership_available'])

    def test_distribution_groups_are_listed_but_not_offered_for_policy(self):
        self.assertEqual(4, self.store.directory_page('groups')['total'])
        self.assertEqual(3, self.store.directory_page('groups', security_only=True)['total'])

    def test_pagination_search_and_disabled_flags(self):
        self.assertEqual(1, self.detail('groups', 1, query='ALICE')['total'])
        self.assertFalse(self.detail('groups', 1, query='ALICE')['items'][0]['enabled'])
        self.assertEqual([], self.detail('groups', 1, offset=2)['items'])
        self.assertTrue(self.detail('groups', 1, offset=1)['items'][0]['enabled'])

    def test_large_group_is_paged_without_truncating_total(self):
        for n in range(201):
            user = {'guid': f'00000000-0000-0000-0001-{n:012}', 'sid': f'S-1-5-21-1-2-3-{2000+n}', 'sam': f'user{n:03}', 'name': f'User {n:03}', 'enabled': True, 'primary_group_unresolved': False}
            self.value['users'].append(user)
            self.value['memberships'].append({'member_sid': user['sid'], 'group_sid': self.value['groups'][1]['sid'], 'type': 'primary'})
        self.store.save_directory(1, self.value)
        self.assertEqual(203, self.detail('groups', 1)['total'])
        self.assertEqual(100, len(self.detail('groups', 1)['items']))
        self.assertEqual(3, len(self.detail('groups', 1, offset=200)['items']))

    def test_invalid_graph_preserves_prior_snapshot(self):
        before = self.store.directory_catalog()
        variants = []
        for change in [{'group_sid': 'S-1-5-21-1-2-3-9999'}, {'member_sid': 'S-1-5-21-1-2-3-9999'}, {'type': []}, {'password': 'secret'}]:
            bad = copy.deepcopy(self.value); bad['memberships'][0].update(change); variants.append(bad)
        bad = copy.deepcopy(self.value); bad['memberships'].append(copy.deepcopy(bad['memberships'][0])); variants.append(bad)
        bad = copy.deepcopy(self.value); bad['users'][0]['primary_group_unresolved'] = True; variants.append(bad)
        bad = copy.deepcopy(self.value); del bad['memberships']; variants.append(bad)
        bad = copy.deepcopy(self.value); bad['membership_schema'] = True; variants.append(bad)
        for bad in variants:
            with self.assertRaises(ValidationError): self.store.save_directory(1, bad)
            self.assertEqual(before, self.store.directory_catalog())

    def test_primary_group_must_be_account_domain_security_group(self):
        for group in [self.value['groups'][2]['sid'], self.value['groups'][0]['sid']]:
            bad = copy.deepcopy(self.value)
            bad['memberships'].append({'member_sid': bad['users'][0]['sid'], 'group_sid': group, 'type': 'primary'})
            with self.assertRaises(ValidationError): validate_catalog(bad)

    def test_scope_change_hides_details_and_invalid_parameters_are_rejected(self):
        for params in [('computers', self.value['users'][0]['guid']), ('users', 'invalid-guid')]:
            with self.assertRaises(ValueError): self.store.directory_detail(*params)
        with self.assertRaises(ValueError): self.detail('users', offset=-1)
        with self.assertRaises(ValueError): self.detail('users', query='\0')
        changed = config(); changed['ad_domain'] = 'other.example'; self.store.save(1, config=changed)
        with self.assertRaises(LookupError): self.detail('users')


class MembershipHTTPTests(unittest.TestCase):
    setUp = test_directory.DirectoryHTTPTests.setUp
    close = test_directory.DirectoryHTTPTests.close
    call = test_directory.DirectoryHTTPTests.call

    def test_detail_requires_authorization_and_strict_bounded_query(self):
        self.server.store.save_directory(1, membership_catalog())
        valid = '/api/directory/detail?kind=users&id=00000000-0000-0000-0000-000000000001'
        self.assertEqual(401, self.call('GET', valid, authenticated=False)[0])
        self.assertEqual(200, self.call('GET', valid)[0])
        for suffix in ['&offset=-1', '&q=a&q=b', '&secret=x', '&id=duplicate']:
            self.assertEqual(400, self.call('GET', valid + suffix)[0])
        self.assertEqual(404, self.call('GET', valid.replace('000000000001', '000000000099'))[0])

    def test_policy_picker_excludes_distribution_groups(self):
        self.server.store.save_directory(1, membership_catalog())
        self.assertEqual(3, self.call('GET', '/api/policies/groups')[1]['total'])
