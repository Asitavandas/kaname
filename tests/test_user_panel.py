"""Read-only group labels and actual panel profile boundaries, no customer AD."""
import unittest
from . import test_user_enrollment as fixtures
from .test_membership import membership_catalog


class UserPanelReadTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls): fixtures.UserEnrollmentTests.setUpClass.__func__(cls)
    @classmethod
    def tearDownClass(cls): cls.base.cleanup()
    def setUp(self): fixtures.UserEnrollmentTests.setUp(self)

    def test_profile_group_label_is_display_only_and_read_does_not_change_business_state(self):
        catalog=membership_catalog()
        group=next(g for g in catalog['groups'] if g['sid']==self.fields['group_sid'])
        group['name']='<img src=x onerror=alert(1)>'
        revision=self.users.store.snapshot()['revision']
        self.users.store.save_directory(revision,catalog)
        before=self.users.store.snapshot()
        status=self.users.status()
        profile=status['profiles'][0]
        self.assertEqual(group['name'],profile['group_name'])
        self.assertEqual(group['sid'],profile['group_sid'])
        self.assertEqual(self.profile['id'],profile['id'])
        self.assertEqual(before,self.users.store.snapshot())
        self.assertEqual([],self.devices.status()['profiles'])

    def test_missing_catalog_keeps_exact_profile_sid_and_no_implicit_creation(self):
        before=self.users.store.snapshot()
        status=self.users.status()
        self.assertEqual(1,len(status['profiles']))
        self.assertIsNone(status['profiles'][0]['group_name'])
        self.assertEqual(self.fields['group_sid'],status['profiles'][0]['group_sid'])
        self.assertEqual(before,self.users.store.snapshot())
