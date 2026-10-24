import uuid,unittest
from . import test_admin as af
from .test_membership import computer_membership_catalog
from kaname.device_enrollment import DeviceEnrollment
from kaname.user_enrollment import UserEnrollment

class DeploymentHTTPTests(unittest.TestCase):
 setUp=af.AdministratorHTTPTests.setUp
 close=af.AdministratorHTTPTests.close
 call=af.AdministratorHTTPTests.call
 system=af.AdministratorHTTPTests.system
 user=af.AdministratorHTTPTests.user
 login=af.AdministratorHTTPTests.login
 def seed(self):
  catalog=computer_membership_catalog();catalog['users'][0]['enabled']=True;catalog['groups'][0]['unresolved_members']=0;self.server.store.save_directory(self.server.store.snapshot()['revision'],catalog)
  devices=DeviceEnrollment(self.server.operations);fields={'id':'','version':0,'name':'Machines','group_sid':catalog['groups'][0]['sid'],'validity_days':90,'renew_before_days':30,'enabled':True};profile=devices.save_profile(fields,'fixture');UserEnrollment(devices)
  return {'id':str(uuid.uuid4()),'version':0,'name':'Plan','computer_group_sid':fields['group_sid'],'machine_profile_id':profile['id'],'user_profile_id':'','wired':True,'wireless':False,'ssid':'','auth_mode':'machine','server_name':'kaname.lab.example'}
 def test_plan_save_preview_and_profile_package_fail_closed_without_real_trust(self):
  plan=self.seed();before=self.server.store.snapshot();value={'expected_revision':before['revision'],'plan':plan}
  code,result,_=self.call('POST','/api/deployment/save',value);self.assertEqual(200,code,result);self.assertFalse(result['gpo_changed'])
  code,status,_=self.call('GET','/api/deployment/status');self.assertEqual(200,code);self.assertEqual(1,len(status['plans']));self.assertFalse(status['connector']['configured'])
  query={'expected_revision':status['revision'],'id':plan['id'],'version':1};code,preview,_=self.call('POST','/api/deployment/preview',query);self.assertEqual(200,code);self.assertFalse(preview['can_apply']);self.assertIn('RADIUS_SERVER_TRUST_NOT_READY',preview['artifact_blockers'])
  self.assertEqual(400,self.call('POST','/api/deployment/package',query|{'preview_hash':preview['preview_hash']})[0]);self.assertEqual(before['policies'],self.server.store.snapshot()['policies'])
  self.assertEqual(409,self.call('POST','/api/deployment/save',value)[0])
 def test_session_csrf_read_role_and_no_gpo_apply_endpoint(self):
  plan=self.seed();value={'expected_revision':self.server.store.snapshot()['revision'],'plan':plan};self.user();reader=self.login('reader')
  for kwargs,code in [({'auth':None},401),({'headers':{'X-Kaname-CSRF':'wrong'}},403),({'auth':reader},403)]:self.assertEqual(code,self.call('POST','/api/deployment/save',value,**kwargs)[0])
  self.assertEqual(200,self.call('GET','/api/deployment/status',auth=reader)[0]);self.assertEqual(401,self.call('GET','/api/deployment/status',auth=None)[0])
  self.assertEqual(403,self.call('POST','/api/deployment/package',{},auth=reader)[0]);self.assertEqual(404,self.call('POST','/api/deployment/apply',{})[0])
 def test_unknown_fields_duplicates_invalid_query_and_command_injection_are_rejected(self):
  plan=self.seed();before=self.server.store.snapshot()
  for suffix in ['?offset=0&offset=1','?q=x&q=y','?unknown=x','?offset=-1']:
   self.assertEqual(400,self.call('GET','/api/deployment/status'+suffix)[0])
  for change in [{'command':'shutdown'},{'server_name':'x; shutdown'},{'computer_group_sid':'$(whoami)'}]:
   self.assertEqual(400,self.call('POST','/api/deployment/save',{'expected_revision':before['revision'],'plan':plan|change})[0])
  self.assertEqual(before,self.server.store.snapshot())
