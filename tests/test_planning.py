"""Preparation must remain separate from live RADIUS policy and device IO."""
import json
import sqlite3
import tempfile
import unittest

from kaname.models import ValidationError
from kaname.operations import Operations
from kaname.planning import Planning
from kaname.store import Store, ConflictError
from kaname.admin import permissions
from .helpers import config, identity, policy
from .test_directory import catalog
from kaname.policy import evaluate


def device(**changes):
    return {**dict(id='', name='SW-01', vendor='Cisco', model='C9300', ip='192.0.2.2',
                   device_type='switch', connection_type='none', management_mode='manual',
                   location='Floor 1', notes=''), **changes}


def draft(**changes):
    return {**dict(id='', name='Finance', selector_type='user',
                  target_ids=[catalog()['users'][0]['guid']], ou_dn='', action='allow',
                  vlan=120, access_types=['wired', 'wireless']), **changes}


class PlanningTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.store = Store(self.temp.name); self.store.save(0, config=config())
        self.store.save(1, policies=[policy()]); self.store.save_directory(2, catalog())
        self.ops = Operations(self.store); self.planning = Planning(self.ops)

    def test_inventory_crud_restart_and_runtime_unchanged(self):
        before = self.store.snapshot(); decision = evaluate(before['policies'], identity())
        saved = self.planning.save_device(2, device()); item = saved['items'][0]
        self.assertEqual('inventory_only', item['status'])
        self.assertFalse(saved['connection_enabled']); self.assertFalse(saved['runtime_applied'])
        changed = {k: v for k, v in item.items() if k != 'status'}; changed['name'] = 'SW-renamed'
        self.planning.save_device(3, changed)
        reopened = Planning(Operations(Store(self.temp.name)))
        self.assertEqual('SW-renamed', reopened.devices()['items'][0]['name'])
        reopened.delete_device(4, item['id']); self.assertEqual([], reopened.devices()['items'])
        self.assertEqual(before['config'], self.store.snapshot()['config'])
        self.assertEqual(before['policies'], self.store.snapshot()['policies'])
        self.assertEqual(decision, evaluate(self.store.snapshot()['policies'], identity()))

    def test_modes_connections_credentials_and_duplicate_ip(self):
        for mode, conn in [('manual', 'none'), ('import', 'none'), ('read_only', 'direct'), ('managed', 'cloud')]:
            result = self.planning.save_device(self.store.snapshot()['revision'], device(management_mode=mode, connection_type=conn))
            self.planning.delete_device(result['revision'], result['items'][0]['id'])
        for changes in [{'management_mode': 'manual', 'connection_type': 'cloud'},
                        {'management_mode': 'import', 'connection_type': 'direct'},
                        {'management_mode': 'managed', 'connection_type': 'none'},
                        {'password': 'sentinel'}, {'ip': 'https://example.invalid'},
                        {'management_mode': 'managed', 'connection_type': 'direct', 'ip': ''},
                        {'status': 'connected'}]:
            with self.subTest(changes=changes), self.assertRaises(ValidationError):
                self.planning.save_device(self.store.snapshot()['revision'], device(**changes))
        self.planning.save_device(self.store.snapshot()['revision'], device())
        with self.assertRaises(ValidationError): self.planning.save_device(self.store.snapshot()['revision'], device())

    def test_stale_revision_and_audit_failure_do_not_write(self):
        self.planning.save_device(2, device())
        before, audit = self.planning.devices(), self.store.audit()
        with self.assertRaises(ConflictError): self.planning.save_device(2, device(ip='192.0.2.3'))
        with self.store.connect() as db:
            db.execute("CREATE TRIGGER no_plan BEFORE INSERT ON audit WHEN NEW.event='network_devices_saved' BEGIN SELECT RAISE(ABORT,'fixture'); END")
        with self.assertRaises(sqlite3.Error): self.planning.save_device(3, device(ip='192.0.2.3'))
        self.assertEqual(before, self.planning.devices()); self.assertEqual(audit, self.store.audit())

    def test_all_selectors_persist_only_as_drafts(self):
        c = catalog(); c['computers'] = [dict(guid='00000000-0000-0000-0000-000000000003', sid='S-1-5-21-1-2-3-1200', sam='PC$', name='PC', enabled=True)]
        self.store.save_directory(2, c)
        before = self.store.snapshot()['policies']
        for kind, ids, ou in [('user', [c['users'][0]['guid']], ''), ('computer', [c['computers'][0]['guid']], ''),
                              ('group', [c['groups'][0]['guid']], ''), ('ou', [], 'OU=Finance,DC=lab,DC=example'), ('everyone', [], '')]:
            result = self.planning.save_draft(self.store.snapshot()['revision'], draft(selector_type=kind, target_ids=ids, ou_dn=ou))
            item = result['items'][-1]
            self.assertEqual('draft', item['status']); self.assertFalse(item['runtime_applied']); self.assertTrue(item['domain_matches'])
        self.assertEqual(before, self.store.snapshot()['policies'])
        reopened = Planning(Operations(Store(self.temp.name)))
        self.assertEqual(5, len(reopened.drafts()['items']))
        self.planning.delete_draft(self.store.snapshot()['revision'], result['items'][0]['id'])
        self.assertEqual(4, len(self.planning.drafts()['items']))

    def test_selector_validation_and_catalog_bound_identity(self):
        for changes in [{'target_ids': []}, {'target_ids': [catalog()['groups'][0]['guid']]},
                        {'target_ids': ['not-guid']}, {'selector_type': 'everyone', 'target_ids': draft()['target_ids']},
                        {'selector_type': 'ou', 'target_ids': [], 'ou_dn': 'OU=Finance,DC=other,DC=example'},
                        {'selector_type': 'ou', 'target_ids': [], 'ou_dn': 'DC=lab,DC=example'},
                        {'enabled': True}, {'vlan': 33}, {'action': 'deny', 'vlan': 120}]:
            with self.subTest(changes=changes), self.assertRaises((ValidationError, ValueError)):
                self.planning.save_draft(self.store.snapshot()['revision'], draft(**changes))
        result = self.planning.save_draft(2, draft())
        self.assertEqual(catalog()['users'][0]['sid'], result['items'][0]['targets'][0]['sid'])
        self.assertNotIn('password', json.dumps(result))
        self.assertEqual(catalog()['users'][0]['guid'], self.planning.targets('user')['items'][0]['guid'])
        c = config(); c['ad_domain'] = 'other.example'; self.store.save(3, config=c)
        self.assertFalse(self.planning.drafts()['items'][0]['domain_matches'])

    def test_new_permissions_do_not_expand_existing_custom_profiles(self):
        self.assertEqual('none', permissions('Custom', {'network.radius': 'write'})['network.devices'])
        self.assertEqual('read', permissions('Admin_ReadOnly', {})['network.devices'])
        self.assertEqual('write', permissions('SuperAdmin', {})['network.devices'])
