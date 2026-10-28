"""RO public DB snapshot + actual existing exporters; no customer writes."""
import copy,hashlib,io,json,sqlite3,zipfile
from pathlib import Path
import unittest
from unittest.mock import patch
from kaname.deployment_bundle import snapshot_assets,read_zip,BundleError,sha
from tests.test_deployment import DeploymentTests
from tools.linux_initialize import create_web_certificate

class DeploymentBundleTests(unittest.TestCase):
 @classmethod
 def setUpClass(cls):DeploymentTests.setUpClass.__func__(cls)
 @classmethod
 def tearDownClass(cls):cls.base.cleanup()
 def setUp(self):
  DeploymentTests.setUp(self)
  self.value.update(auth_mode='machine',user_profile_id='')
  DeploymentTests.save(self)
  self.preview=DeploymentTests.preview(self)
  self.network=DeploymentTests.package(self,self.preview)
  self.web=Path(self.temp.name)/'bundle-web';self.web.mkdir()
  self.host='kaname.lab.example'
  self.tls_sha=create_web_certificate(self.web,self.host,'127.0.0.1')
  self.tls=(self.web/'web.crt').read_bytes()
 def build(self,**changes):
  args=dict(network_sha256=sha(self.network),plan_id=self.preview['id'],plan_version=self.preview['version'],tls_pem=self.tls,tls_sha256=self.tls_sha,hostname=self.host,port=8765)
  args.update(changes)
  with sqlite3.connect('file:'+str(self.store.path)+'?mode=ro',uri=True) as db:
   db.execute('PRAGMA query_only=ON');db.execute('BEGIN')
   return snapshot_assets(db,self.network,**args)
 def test_complete_assets_preserve_existing_client_and_network_bytes_without_private_keys(self):
  before=self.store.snapshot();audit=self.store.audit()
  with patch('kaname.device_enrollment.DeviceEnrollment._issuer',side_effect=AssertionError('private key access')):
   raw=self.build()
  with zipfile.ZipFile(io.BytesIO(raw)) as z:
   self.assertEqual(self.network,z.read('network-profiles.zip'))
   self.assertEqual((Path('kaname/device_client/AuthWire-Client.ps1')).read_bytes(),z.read('enrollment/AuthWire-Client.ps1'))
   self.assertNotIn(b'__AUTHWIRE_ASSET_HASHES__',z.read('enrollment/Install-AuthWire.ps1'))
   for n in ('Wired-EAP-TLS.xml','WiFi-EAP-TLS.xml'):self.assertEqual(read_zip(self.network)[n],z.read('network/'+n))
   manifest=json.loads(z.read('bundle-manifest.json'))
   self.assertFalse(manifest['can_stage']);self.assertFalse(manifest['can_apply']);self.assertTrue(manifest['requires_windows_signing'])
   self.assertEqual(set(manifest['files']),set(z.namelist())-{'bundle-manifest.json'})
   for n,pin in manifest['files'].items():self.assertEqual(pin,sha(z.read(n)));self.assertNotIn(b'PRIVATE KEY-----',z.read(n))
  self.assertEqual(before,self.store.snapshot());self.assertEqual(audit,self.store.audit())
 def test_all_profile_changes_are_detected(self):
  for field,value in [('version',4),('enabled',0),('group_sid',self.fields['group_sid']+'1')]:
   with self.store.connect() as db:
    old=db.execute('SELECT '+field+' FROM device_profiles WHERE id=?',(self.machine['id'],)).fetchone()[0]
    db.execute('UPDATE device_profiles SET '+field+'=? WHERE id=?',(value,self.machine['id']))
   try:
    with self.assertRaises(BundleError):self.build()
   finally:
    with self.store.connect() as db:db.execute('UPDATE device_profiles SET '+field+'=? WHERE id=?',(old,self.machine['id']))
 def test_hash_host_tls_plan_and_port_refusal(self):
  for c in [dict(network_sha256='0'*64),dict(hostname='other.lab.example'),dict(tls_sha256='0'*64),dict(plan_version=2),dict(port=True)]:
   with self.assertRaises(BundleError):self.build(**c)
 def test_query_only_and_transaction_are_required(self):
  with self.store.connect() as db:
   with self.assertRaisesRegex(BundleError,'QUERY_ONLY'):snapshot_assets(db,self.network,network_sha256=sha(self.network),plan_id=self.preview['id'],plan_version=1,tls_pem=self.tls,tls_sha256=self.tls_sha,hostname=self.host,port=8765)
 def test_plan_change_is_rejected_but_audit_only_revision_change_is_not(self):
  with self.store.connect() as db:db.execute('UPDATE state SET revision=revision+1 WHERE id=1')
  self.build()
  with self.store.connect() as db:
   row=db.execute("SELECT payload FROM runtime_settings WHERE name='windows_deployment_plans'").fetchone()
   plans=json.loads(row[0]);plans[0]['name']='Changed'
   db.execute("UPDATE runtime_settings SET payload=? WHERE name='windows_deployment_plans'",(json.dumps(plans),))
  with self.assertRaisesRegex(BundleError,'PLAN_CHANGED'):self.build()
 def test_unexpected_paths_duplicates_symlinks_and_large_entries_are_rejected(self):
  for names in [[('../x',b'x')],[('same',b'a'),('SAME',b'b')],[('huge',b'x'*262145)]]:
   out=io.BytesIO()
   with zipfile.ZipFile(out,'w') as z:
    for n,b in names:z.writestr(n,b)
   with self.assertRaises(BundleError):read_zip(out.getvalue())
  out=io.BytesIO()
  with zipfile.ZipFile(out,'w') as z:
   e=zipfile.ZipInfo('link');e.external_attr=0o120777<<16;z.writestr(e,b'target')
  with self.assertRaises(BundleError):read_zip(out.getvalue())
