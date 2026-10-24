"""Real public PKI/profile assets, disposable AD snapshot; no customer GPO calls."""
import copy,hashlib,io,json,unittest,uuid,zipfile
from xml.etree import ElementTree as ET
from pathlib import Path
from kaname.deployment import Deployment,DeploymentError,FIELDS,network_xml
from kaname.operations import Operations
from kaname.store import ConflictError
from kaname.models import ValidationError
from . import test_user_enrollment as uf
from .test_membership import computer_membership_catalog
from .test_enrollment import PASSWORD
from tools.radius_initialize import initialize

class DeploymentTests(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  uf.UserEnrollmentTests.setUpClass.__func__(cls);initialize(cls.base.name,PASSWORD)
 @classmethod
 def tearDownClass(cls):cls.base.cleanup()
 def setUp(self):
  uf.UserEnrollmentTests.setUp(self)
  self.store=self.devices.store;self.ops=self.devices.operations;self.dep=Deployment(self.ops)
  catalog=computer_membership_catalog();catalog['groups'][0]['unresolved_members']=0;catalog['users'][0]['enabled']=True
  self.store.save_directory(self.store.snapshot()['revision'],catalog)
  self.machine=self.devices.save_profile(self.fields|{'name':'Machines'},'fixture')
  self.value={'id':str(uuid.uuid4()),'version':0,'name':'Pilot <name>','computer_group_sid':self.fields['group_sid'],'machine_profile_id':self.machine['id'],'user_profile_id':self.profile['id'],'wired':True,'wireless':True,'ssid':'VV_802.1X &<test>','auth_mode':'machineOrUser','server_name':'kaname.lab.example'}
 def save(self,value=None):return self.dep.save({'expected_revision':self.store.snapshot()['revision'],'plan':value or self.value},'fixture-admin')
 def preview(self):
  p=self.dep.status()['plans'][0];return self.dep.preview({'expected_revision':self.store.snapshot()['revision'],'id':p['id'],'version':p['version']})
 def package(self,preview):return self.dep.package({k:preview[k] for k in ['id','version','preview_hash']}|{'expected_revision':preview['revision']})
 def test_read_only_preparation_no_profile_gpo_or_certificate_mutation(self):
  before=self.store.snapshot();profiles=self.users.status()['profiles'];status=self.dep.status();self.assertFalse(status['connector']['can_apply']);self.assertEqual([],status['plans']);self.assertEqual(before,self.store.snapshot())
  self.save();after=self.store.snapshot();self.assertEqual(before['config'],after['config']);self.assertEqual(before['policies'],after['policies']);self.assertEqual(profiles,self.users.status()['profiles'])
  current=self.store.snapshot();p=self.preview();self.assertTrue(p['can_export_profiles']);self.assertFalse(p['can_apply']);self.assertFalse(p['gpo_changed']);self.assertEqual(current,self.store.snapshot())
 def test_version_history_and_global_and_plan_leases(self):
  result=self.save();self.assertEqual(1,result['version']);before=self.store.snapshot()
  with self.assertRaises(ConflictError):self.save()
  self.assertEqual(before,self.store.snapshot());v=self.value|{'version':1,'name':'Second'};self.save(v)
  p=self.dep.status()['plans'][0];self.assertEqual(2,p['version']);self.assertEqual('Pilot <name>',p['history'][0]['name']);self.assertNotIn('history',p['history'][0])
  with self.assertRaises(ConflictError):self.dep.save({'expected_revision':before['revision'],'plan':v},'fixture')
 def test_exact_ad_groups_profiles_and_identity_modes(self):
  for change in [{'computer_group_sid':'S-1-5-21-1-2-3-9999'},{'machine_profile_id':self.profile['id']},{'auth_mode':'machine','user_profile_id':self.profile['id']},{'user_profile_id':''},{'wired':False,'wireless':False},{'wireless':True,'ssid':''},{'ssid':'ü'*17},{'name':''},{'id':'../escape'}]:
   before=self.store.snapshot()
   with self.subTest(change=change),self.assertRaises((ValueError,ValidationError)):self.save(self.value|change)
   self.assertEqual(before,self.store.snapshot())
  self.save(self.value|{'auth_mode':'user','machine_profile_id':''});p=self.preview();self.assertEqual(1,p['computer_targets']['enabled']);self.assertEqual(1,p['user_targets']['enabled'])
 def test_targets_are_separate_nested_snapshot_counts_not_installations(self):
  self.save();p=self.preview();self.assertEqual(1,p['computer_targets']['count']);self.assertEqual(1,p['user_targets']['count']);self.assertIn('cached',p['target_basis']);self.assertFalse(p['runtime_applied']);self.assertTrue(p['catalog_synced_at'])
 def test_missing_membership_and_disabled_profile_block_export(self):
  self.save();catalog=computer_membership_catalog();catalog.pop('membership_schema');catalog.pop('memberships')
  self.store.save_directory(self.store.snapshot()['revision'],catalog);p=self.preview();self.assertIn('MEMBERSHIP_UNAVAILABLE',p['artifact_blockers']);self.assertFalse(p['can_export_profiles'])
  with self.assertRaises(DeploymentError):self.package(p)
 def test_unresolved_members_and_disabled_empty_target_are_not_silent_success(self):
  self.save();catalog=computer_membership_catalog();catalog['groups'][0]['unresolved_members']=1;catalog['computers'][0]['enabled']=False
  self.store.save_directory(self.store.snapshot()['revision'],catalog);p=self.preview();self.assertIn('NO_ENABLED_TARGETS',p['artifact_blockers']);self.assertIn('UNRESOLVED_MEMBERS',p['artifact_blockers'])
 def test_dependency_change_after_preview_blocks_package_without_revision_change(self):
  self.save();p=self.preview();self.users.save_profile(self.fields|self.profile|{'enabled':False},'fixture')
  with self.assertRaisesRegex(DeploymentError,'DEPLOYMENT_PREVIEW_STALE'):self.package(p)
  p=self.preview();self.assertIn('ENROLLMENT_PROFILE_NOT_ENABLED',p['artifact_blockers'])
 def test_wrong_server_name_and_revoked_server_leaf_fail_closed(self):
  self.save(self.value|{'server_name':'other.lab.example'});self.assertFalse(self.preview()['trust']['ready'])
  self.save(self.value|{'version':1});self.assertTrue(self.preview()['trust']['ready'])
  from cryptography import x509
  leaf=Path(self.temp.name)/'radius/server.pem';serial=format(x509.load_pem_x509_certificate(leaf.read_bytes()).serial_number,'x')
  self.devices.pki.revoke(serial,PASSWORD)
  self.assertFalse(self.preview()['trust']['ready'])
 def test_public_deterministic_archive_only_pinned_xml_no_keys_or_installer(self):
  self.save();p=self.preview();raw=self.package(p);self.assertEqual(raw,self.package(p))
  with zipfile.ZipFile(io.BytesIO(raw)) as z:
   names=set(z.namelist());self.assertEqual({'Wired-EAP-TLS.xml','WiFi-EAP-TLS.xml','root-ca.pem','issuer-ca.pem','plan.json','manifest.json','README.txt'},names)
   manifest=json.loads(z.read('manifest.json'));self.assertEqual(p['preview_hash'],manifest['preview_hash'])
   for n,h in manifest['files'].items():self.assertEqual(hashlib.sha256(z.read(n)).hexdigest(),h)
   for n in names:self.assertNotIn(b'PRIVATE KEY',z.read(n))
   for n in ['Wired-EAP-TLS.xml','WiFi-EAP-TLS.xml']:
    xml=ET.fromstring(z.read(n));values={e.tag.rsplit('}',1)[-1]:e.text for e in xml.iter()}
    self.assertEqual('machineOrUser',values['authMode']);self.assertEqual('13',values['Type']);self.assertEqual('true',values['DisableUserPromptForServerValidation']);self.assertEqual('true',values['PerformServerValidation']);self.assertEqual('true',values['AcceptServerName']);self.assertEqual(self.value['server_name'],values['ServerNames']);self.assertEqual(p['trust']['root_thumbprint'],values['TrustedRootCA'].replace(' ',''))
   self.assertEqual(self.value['ssid'],ET.fromstring(z.read('WiFi-EAP-TLS.xml')).find('{*}name').text)
 def test_preview_token_rejects_catalog_or_plan_change_and_foreign_token(self):
  self.save();p=self.preview()
  with self.assertRaisesRegex(DeploymentError,'DEPLOYMENT_PREVIEW_STALE'):self.package(p|{'preview_hash':'0'*64})
  self.save(self.value|{'version':1,'name':'Updated'})
  with self.assertRaises(ConflictError):self.package(p)

