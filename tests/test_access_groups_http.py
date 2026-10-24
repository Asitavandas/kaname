import unittest
from dataclasses import asdict
from . import test_admin as admin_fixture
from .test_membership import membership_catalog
from .helpers import identity


class AccessGroupHTTPTests(unittest.TestCase):
    close=admin_fixture.AdministratorHTTPTests.close
    call=admin_fixture.AdministratorHTTPTests.call
    system=admin_fixture.AdministratorHTTPTests.system
    create_profile=admin_fixture.AdministratorHTTPTests.create_profile
    user=admin_fixture.AdministratorHTTPTests.user
    login=admin_fixture.AdministratorHTTPTests.login

    def setUp(self):
        admin_fixture.AdministratorHTTPTests.setUp(self)
        self.catalog=membership_catalog()
        self.server.store.save_directory(1,self.catalog)

    def payload(self,name='VLAN50'):
        return {'expected_revision':self.server.store.snapshot()['revision'],'group':{'id':'','name':name,
                'members':[{'guid':self.catalog['users'][0]['guid'],'kind':'user'}]}}

    def test_group_crud_labels_and_duplicate_error_are_safe(self):
        code,value,_=self.call('POST','/api/access-groups/save',self.payload())
        self.assertEqual(200,code,value);first=value['group']['id']
        code,value,_=self.call('GET','/api/access-groups');self.assertEqual(1,len(value['items']))
        code,value,_=self.call('GET','/api/policies/targets?kind=local_group&q=VLAN')
        self.assertEqual(200,code);self.assertEqual('local:'+first,value['items'][0]['sid'])
        code,value,_=self.call('POST','/api/access-groups/save',self.payload('Other'))
        self.assertEqual(409,code);self.assertEqual('VLAN50',value['group_name'])
        code,value,_=self.call('POST','/api/access-groups/delete',{'expected_revision':self.server.store.snapshot()['revision'],'id':first})
        self.assertEqual(200,code);self.assertEqual([],value['items'])

    def test_unauthenticated_csrf_and_origin_cannot_write(self):
        self.assertEqual(401,self.call('GET','/api/access-groups',auth=None)[0])
        self.assertEqual(403,self.call('POST','/api/access-groups/save',self.payload(),headers={'X-Kaname-CSRF':''})[0])
        self.assertEqual(403,self.call('POST','/api/access-groups/save',self.payload(),headers={'Origin':'https://evil.example'})[0])
        self.assertEqual([],self.server.access_groups.list()['items'])

    def test_readonly_can_view_but_cannot_change_membership(self):
        self.user();reader=self.login('reader')
        self.assertEqual(200,self.call('GET','/api/access-groups',auth=reader)[0])
        self.assertEqual(403,self.call('POST','/api/access-groups/save',self.payload(),auth=reader)[0])

    def test_directory_write_alone_is_not_access_policy_write(self):
        profile=self.create_profile('Catalog only',{'directory.catalog':'write'})
        self.user(name='catalog',profile_id=profile);actor=self.login('catalog')
        self.assertEqual(200,self.call('GET','/api/access-groups',auth=actor)[0])
        self.assertEqual(403,self.call('POST','/api/access-groups/save',self.payload(),auth=actor)[0])

    def test_policy_writer_can_manage_groups_without_directory_credentials_right(self):
        profile=self.create_profile('Rules only',{'policies.rules':'write'})
        self.user(name='rules',profile_id=profile);actor=self.login('rules')
        self.assertEqual(200,self.call('POST','/api/access-groups/save',self.payload(),auth=actor)[0])
        self.assertEqual(403,self.call('GET','/api/directory/settings',auth=actor)[0])

    def test_invalid_selectors_and_forged_simulation_group_are_rejected(self):
        self.assertEqual(400,self.call('GET','/api/access-groups?id=bad')[0])
        self.assertEqual(400,self.call('GET','/api/access-groups?id=x&id=y')[0])
        payload=self.payload();payload['group']['members'][0]['sid']='S-1-5-21-1-2-3-9999'
        self.assertEqual(400,self.call('POST','/api/access-groups/save',payload)[0])
        claims=asdict(identity());claims.pop('account_sid');claims['group_sids']=list(claims['group_sids']);claims['local_group_ids']=[]
        self.assertEqual(400,self.call('POST','/api/simulate',claims)[0])
