"""Policy scope crosses HTTP only as configuration or an explicit simulation."""
import copy
import unittest
from dataclasses import asdict
from kaname.directory import DirectoryError
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
            payload.pop('directory_domain')
            payload.pop('directory_dn')
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
        payload.pop('directory_domain'); payload.pop('directory_dn')
        payload['group_sids'] = list(payload['group_sids'])
        self.assertEqual(120, self.call('POST', '/api/simulate', payload)[1]['decision']['vlan'])
        edited = copy.deepcopy(policy); edited['name'] = 'Legacy renamed'
        self.assertEqual(200, self.save([edited])[0])
        self.assertEqual([edited], self.server.store.snapshot()['policies'])

    def test_selector_http_save_requires_scoped_ad_and_retains_existing_state_on_failure(self):
        def rule(identity, dn):
            value = scoped('computer', id=identity)
            value['conditions']['group_sids'] = []
            value['conditions']['selector'] = {'type': 'ou', 'domain': 'lab.example', 'dn': dn}
            return value

        parent = 'OU=Pilot,DC=lab,DC=example'
        rules = [rule('ou-one', parent), rule('ou-two', 'OU=Child,' + parent)]
        calls = []
        self.server.operations.directory_connection = lambda: {
            'dc_fqdn': 'dc01.lab.example', 'username': 'reader@lab.example',
            'password': 'fixture-secret', 'search_base': parent}

        def reader(connection, config, *, ou_dn):
            calls.append(ou_dn)
            return {'ou_dn': ou_dn, 'scope': 'subtree'}

        self.server.directory_reader = reader
        self.assertEqual(200, self.save(rules)[0])
        self.assertEqual([parent, 'OU=Child,' + parent], calls)
        before, audit = self.server.store.snapshot(), self.server.store.audit()
        disabled = copy.deepcopy(rules)
        disabled[0]['enabled'] = False
        self.assertEqual(200, self.save(disabled)[0])
        self.assertEqual(2, len(calls))
        self.server.directory_next_attempt = 0

        def missing(*args, **kwargs):
            raise DirectoryError('AD_SCOPE_NOT_FOUND')

        self.server.directory_reader = missing
        before, audit = self.server.store.snapshot(), self.server.store.audit()
        code, result, _ = self.save(rules)
        self.assertEqual((400, 'AD_SCOPE_NOT_FOUND'), (code, result['error']))
        self.assertEqual(before, self.server.store.snapshot())
        self.assertEqual(audit, self.server.store.audit())
        foreign = rule('foreign', parent)
        foreign['conditions']['selector'] = {'type': 'everyone', 'domain': 'other.example'}
        self.assertEqual(400, self.save([foreign])[0])
        self.assertEqual(before, self.server.store.snapshot())

    def test_selector_http_does_not_admit_forged_live_identity_and_detects_stale_ad_read(self):
        payload = asdict(identity())
        payload.pop('account_sid')
        payload['group_sids'] = list(payload['group_sids'])
        for field in ('directory_domain', 'directory_dn'):
            forged = {key: value for key, value in payload.items() if key not in {'directory_domain', 'directory_dn'}}
            forged[field] = 'lab.example' if field == 'directory_domain' else 'CN=Host,OU=Pilot,DC=lab,DC=example'
            self.assertEqual(400, self.call('POST', '/api/simulate', forged)[0])
        rule = scoped('computer')
        rule['conditions'].update(group_sids=[], selector={
            'type': 'ou', 'domain': 'lab.example', 'dn': 'OU=Pilot,DC=lab,DC=example'})
        self.server.operations.directory_connection = lambda: {
            'dc_fqdn': 'dc01.lab.example', 'username': 'reader@lab.example',
            'password': 'fixture-secret', 'search_base': ''}

        def concurrent_change(connection, config, *, ou_dn):
            current = self.server.store.snapshot()
            self.server.store.save(current['revision'], config=current['config'])
            return {'ou_dn': ou_dn, 'scope': 'subtree'}

        self.server.directory_reader = concurrent_change
        code, result, _ = self.save([rule])
        self.assertEqual((409, 'REVISION_CONFLICT'), (code, result['error']))
        self.assertEqual([], self.server.store.snapshot()['policies'])

    def test_selector_http_rechecks_session_after_live_ad_read(self):
        rule = scoped('computer')
        rule['conditions'].update(group_sids=[], selector={
            'type': 'ou', 'domain': 'lab.example', 'dn': 'OU=Pilot,DC=lab,DC=example'})
        self.server.operations.directory_connection = lambda: {
            'dc_fqdn': 'dc01.lab.example', 'username': 'reader@lab.example',
            'password': 'fixture-secret', 'search_base': ''}

        def expires_during_read(connection, config, *, ou_dn):
            with self.server.admin.connect() as db:
                db.execute('DELETE FROM admin_sessions')
            return {'ou_dn': ou_dn, 'scope': 'subtree'}

        self.server.directory_reader = expires_during_read
        before, audit = self.server.store.snapshot(), self.server.store.audit()
        self.assertEqual(401, self.save([rule])[0])
        self.assertEqual(before, self.server.store.snapshot())
        self.assertEqual(audit, self.server.store.audit())
