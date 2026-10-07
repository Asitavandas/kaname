import json
import sqlite3
import tempfile
import unittest
from unittest.mock import patch
from kaname.store import Store, ConflictError
from kaname.models import ValidationError
from .helpers import config, policy


class StoreTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.store=Store(self.temp.name)

    def test_empty_state(self):
        self.assertEqual(self.store.snapshot(),{'revision':0,'config':None,'policies':[]})

    def test_config_and_audit_saved(self):
        self.store.save(0,config=config())
        self.assertEqual(self.store.snapshot()['config'],config())
        self.assertEqual(self.store.audit()[0]['revision'],1)

    def test_stale_revision_does_not_overwrite(self):
        self.store.save(0,config=config())
        with self.assertRaises(ConflictError):self.store.save(0,policies=[policy()])
        self.assertEqual(self.store.snapshot()['policies'],[])
        self.assertEqual(len(self.store.audit()),1)

    def test_audit_failure_rolls_back_state(self):
        with self.store.connect() as db:
            db.execute("CREATE TRIGGER audit_fail BEFORE INSERT ON audit BEGIN SELECT RAISE(ABORT,'injected failure'); END")
        with self.assertRaises(sqlite3.Error):self.store.save(0,config=config())
        self.assertEqual(self.store.snapshot()['revision'],0)
        self.assertIsNone(self.store.snapshot()['config'])

    def test_audit_is_append_only(self):
        self.store.save(0,config=config())
        for sql in ['DELETE FROM audit','UPDATE audit SET event="forged"']:
            with self.subTest(sql=sql),self.assertRaises(sqlite3.Error):
                with self.store.connect() as db:db.execute(sql)

    def test_restart_preserves_state(self):
        self.store.save(0,policies=[policy()])
        self.assertEqual(Store(self.temp.name).snapshot()['policies'],[policy()])

    def test_invalid_config_leaves_state_unchanged(self):
        c=config();c['ad_domain']='not-fqdn'
        with self.assertRaises(ValidationError):self.store.save(0,config=c)
        self.assertEqual(self.store.snapshot()['revision'],0)

    def test_audit_contains_no_customer_config(self):
        self.store.save(0,config=config())
        self.assertNotIn('lab.example',json.dumps(self.store.audit()))

    def test_both_sections_rejected(self):
        with self.assertRaises(ValueError):self.store.save(0,config=config(),policies=[])

    def test_boolean_revision_rejected(self):
        with self.assertRaises(ValidationError):self.store.save(False,config=config())

    def test_policy_order_persists(self):
        rows=[policy(id='b'),policy(id='a')];self.store.save(0,policies=rows)
        self.assertEqual([x['id'] for x in self.store.snapshot()['policies']],['b','a'])


    def test_store_owner_check_uses_effective_uid(self):
        owner = self.store.root.stat().st_uid
        with patch('kaname.store.os.getuid', return_value=owner + 1000), \
             patch('kaname.store.os.geteuid', return_value=owner):
            reopened = Store(self.temp.name)
        self.assertEqual(reopened.root, self.store.root)
