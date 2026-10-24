"""Policy scope crosses HTTP only as configuration or an explicit simulation."""
import copy
import unittest
from dataclasses import asdict
from . import test_admin as af
from .helpers import identity
from .test_membership import computer_membership_catalog
from .test_policy_identity_scope import scoped


class PolicyIdentityHTTPTests(unittest.TestCase):
    setUp = af.AdministratorHTTPTests.setUp
    close = af.AdministratorHTTPTests.close
    call = af.AdministratorHTTPTests.call
    system = af.AdministratorHTTPTests.system
    user = af.AdministratorHTTPTests.user
    login = af.AdministratorHTTPTests.login

    def save(self, policies, **kwargs):
        return self.call('POST', '/api/policies', {
            'expected_revision': self.server.store.snapshot()['revision'],
            'policies': policies}, **kwargs)

    def test_scoped_same_group_rules_roundtrip_and_simulation_is_not_network_proof(self):
        policies = [scoped(vlan=50), scoped('computer', id='computer', vlan=110)]
        self.assertEqual(200, self.save(policies)[0])
        self.assertEqual(policies, self.call('GET', '/api/state')[1]['policies'])
        before = self.server.store.snapshot()
        for kind, vlan in [('user', 50), ('computer', 110)]:
            payload = asdict(identity(account_kind=kind, domain_device=kind == 'computer'))
            payload.pop('account_sid')
            payload['group_sids'] = list(payload['group_sids'])
            code, result, _ = self.call('POST', '/api/simulate', payload)
            self.assertEqual(200, code, result)
            self.assertTrue(result['simulation_only'])
            self.assertFalse(result['network_enforced'])
            self.assertEqual(vlan, result['decision']['vlan'])
        self.assertEqual(before, self.server.store.snapshot())
        self.assertEqual(409, self.save(policies + [scoped(id='overlap', vlan=60)])[0])
        self.assertEqual(before, self.server.store.snapshot())

    def test_impossible_direct_account_scope_is_atomic_and_error_is_specific(self):
        catalog = computer_membership_catalog()
        self.server.store.save_directory(self.server.store.snapshot()['revision'], catalog)
        policy = scoped()
        policy['conditions']['group_sids'] = [catalog['computers'][0]['sid']]
        before, audit = self.server.store.snapshot(), self.server.store.audit()
        code, result, _ = self.save([policy])
        self.assertEqual((400, 'POLICY_IDENTITY_SCOPE_MISMATCH'), (code, result['error']))
        self.assertEqual(before, self.server.store.snapshot())
        self.assertEqual(audit, self.server.store.audit())
        policy['constraints']['require_domain_device'] = True
        code, result, _ = self.save([policy])
        self.assertEqual((400, 'POLICY_IDENTITY_SCOPE_INVALID'), (code, result['error']))
        self.assertEqual(before, self.server.store.snapshot())

    def test_new_scope_cannot_bypass_session_csrf_or_read_only_permissions(self):
        self.user()
        reader = self.login('reader')
        before = self.server.store.snapshot()
        for kwargs, expected in [({'auth': None}, 401), ({'headers': {'X-Kaname-CSRF': 'bad'}}, 403), ({'auth': reader}, 403)]:
            self.assertEqual(expected, self.save([scoped(vlan=50)], **kwargs)[0])
        self.assertEqual(before, self.server.store.snapshot())

    def test_legacy_simulation_and_edit_do_not_gain_an_inferred_identity_scope(self):
        policy = scoped('computer')
        del policy['conditions']['identity_types']
        self.assertEqual(200, self.save([policy])[0])
        payload = asdict(identity())
        payload.pop('account_kind'); payload.pop('account_sid')
        payload['group_sids'] = list(payload['group_sids'])
        self.assertEqual(120, self.call('POST', '/api/simulate', payload)[1]['decision']['vlan'])
        edited = copy.deepcopy(policy); edited['name'] = 'Legacy renamed'
        self.assertEqual(200, self.save([edited])[0])
        self.assertEqual([edited], self.server.store.snapshot()['policies'])
