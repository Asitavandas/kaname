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


def computer_membership_catalog():
    value = membership_catalog()
    group = {'guid': '00000000-0000-0000-0000-000000000008',
             'sid': 'S-1-5-21-1-2-3-515', 'sam': 'Domain Computers',
             'name': 'Domain Computers', 'security_enabled': True, 'unresolved_members': 0}
    value['groups'].append(group)
    value['computers'][0]['primary_group_unresolved'] = False
    for n in range(1, 6):
        value['computers'].append({
            'guid': f'00000000-0000-0000-0000-{20+n:012}',
            'sid': f'S-1-5-21-1-2-3-{1002+n}', 'sam': f'LAB-PC{n:02}$',
            'name': f'LAB-PC{n:02}', 'enabled': n != 5, 'primary_group_unresolved': False})
    for computer in value['computers']:
        value['memberships'].append({'member_sid': computer['sid'], 'group_sid': group['sid'], 'type': 'primary'})
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
        self.assertEqual({'alice': 'indirect', 'PC$': 'indirect'}, {x['sam']: x['membership'] for x in self.detail('groups', 3)['items']})
        self.assertEqual(1, self.detail('groups')['computer_members'])
        self.assertEqual(1, self.detail('groups', 3)['unresolved_members'])
        self.assertEqual(2, self.detail('groups', 3)['nested_groups'])

    def test_cycle_terminates_and_keeps_direct_membership_priority(self):
        self.value['memberships'].append({'member_sid': self.value['groups'][3]['sid'], 'group_sid': self.value['groups'][0]['sid'], 'type': 'direct'})
        self.store.save_directory(1, self.value)
        self.assertEqual(4, self.detail('users')['total'])
        self.assertEqual('direct', next(x for x in self.detail('users')['items'] if x['sam'] == 'Access')['membership'])
        self.assertEqual(2, self.detail('groups')['total'])
        computer = next(x for x in self.detail('groups')['items'] if x['kind'] == 'computers')
        self.assertEqual('direct', computer['membership'])

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
        for group in [self.value['groups'][2]['sid'], 'S-1-5-32-544']:
            bad = copy.deepcopy(self.value)
            bad['groups'].append({'guid': '00000000-0000-0000-0000-000000000099', 'sid': 'S-1-5-32-544', 'sam': 'Builtin', 'name': 'Builtin', 'security_enabled': True, 'unresolved_members': 0})
            bad['memberships'][1]['group_sid'] = group
            with self.assertRaises(ValidationError): validate_catalog(bad)

    def test_scope_change_hides_details_and_invalid_parameters_are_rejected(self):
        for params in [('unknown', self.value['users'][0]['guid']), ('users', 'invalid-guid')]:
            with self.assertRaises(ValueError): self.store.directory_detail(*params)
        with self.assertRaises(LookupError):
            self.store.directory_detail('computers', self.value['users'][0]['guid'])
        with self.assertRaises(ValueError): self.detail('users', offset=-1)
        with self.assertRaises(ValueError): self.detail('users', query='\0')
        changed = config(); changed['ad_domain'] = 'other.example'; self.store.save(1, config=changed)
        with self.assertRaises(LookupError): self.detail('users')

    def test_domain_computers_lists_all_six_primary_members_and_drills_back(self):
        self.value = computer_membership_catalog(); self.store.save_directory(1, self.value)
        before = self.store.directory_catalog()
        detail = self.detail('groups', 4)
        self.assertEqual(6, detail['total'])
        self.assertEqual(6, detail['computer_members'])
        self.assertTrue(all(x['kind'] == 'computers' and x['membership'] == 'primary' for x in detail['items']))
        self.assertEqual(1, sum(not x['enabled'] for x in detail['items']))
        self.assertEqual(1, self.detail('groups', 4, query='lab-pc05$')['total'])
        groups = self.detail('computers')['items']
        self.assertEqual({'Access': 'direct', 'Department': 'indirect', 'Parent': 'indirect',
                          'Domain Computers': 'primary'}, {x['sam']: x['membership'] for x in groups})
        self.assertTrue(all(x['kind'] == 'groups' for x in groups))
        self.assertFalse(self.detail('computers')['primary_group_unresolved'])
        self.assertEqual(before, self.store.directory_catalog())

    def test_mixed_group_search_and_primary_computer_priority(self):
        computer = self.value['computers'][0]
        self.value['memberships'].append({'member_sid': computer['sid'],
            'group_sid': self.value['groups'][3]['sid'], 'type': 'direct'})
        self.value['memberships'].append({'member_sid': computer['sid'],
            'group_sid': self.value['groups'][3]['sid'], 'type': 'primary'})
        computer['primary_group_unresolved'] = False
        self.store.save_directory(1, self.value)
        detail = self.detail('groups', 3)
        self.assertEqual(2, detail['total'])
        self.assertEqual(1, detail['computer_members'])
        self.assertEqual('primary', next(x for x in detail['items'] if x['kind'] == 'computers')['membership'])
        self.assertEqual('computers', self.detail('groups', 3, query=computer['sid'])['items'][0]['kind'])
        self.assertEqual([], self.detail('groups', 3, offset=2)['items'])

    def test_computer_catalog_and_large_primary_group_pagination(self):
        self.value = computer_membership_catalog()
        for n in range(101):
            computer = {'guid': f'00000000-0000-0000-0002-{n:012}',
                        'sid': f'S-1-5-21-1-2-3-{4000+n}', 'sam': f'PC{n:03}$',
                        'name': f'PC{n:03}', 'enabled': True, 'primary_group_unresolved': False}
            self.value['computers'].append(computer)
            self.value['memberships'].append({'member_sid': computer['sid'],
                'group_sid': self.value['groups'][4]['sid'], 'type': 'primary'})
        self.store.save_directory(1, self.value)
        self.assertEqual(107, self.detail('groups', 4)['total'])
        self.assertEqual(100, len(self.detail('groups', 4)['items']))
        self.assertEqual(7, len(self.detail('groups', 4, offset=100)['items']))
        self.assertEqual(107, self.store.directory_page('computers')['total'])
        self.assertEqual('PC100$', self.store.directory_page('computers', query='pc100$')['items'][0]['sam'])


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

    def test_computer_detail_and_mixed_members_require_authorization(self):
        self.server.store.save_directory(1, computer_membership_catalog())
        computer = '/api/directory/detail?kind=computers&id=00000000-0000-0000-0000-000000000007'
        self.assertEqual(401, self.call('GET', computer, authenticated=False)[0])
        status, detail = self.call('GET', computer)
        self.assertEqual(200, status)
        self.assertEqual('computers', detail['kind'])
        self.assertTrue(all(x['kind'] == 'groups' for x in detail['items']))
        group = '/api/directory/detail?kind=groups&id=00000000-0000-0000-0000-000000000008'
        self.assertEqual(401, self.call('GET', group, authenticated=False)[0])
        status, members = self.call('GET', group)
        self.assertEqual(200, status)
        self.assertEqual(6, members['total'])
        self.assertTrue(all(x['kind'] == 'computers' for x in members['items']))
        self.assertEqual(404, self.call('GET', computer.replace('000000000007', '000000000001'))[0])
