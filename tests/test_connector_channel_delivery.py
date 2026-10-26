"""Disposable delivery checks; never access customer state or system services."""
import hashlib
import json
from pathlib import Path
import runpy
import tempfile
import unittest
from unittest.mock import patch

SCRIPT=Path(__file__).resolve().parents[1]/'docs/checkpoints/2026-10-26-connector-channel-deploy.py'

class ConnectorDeliveryTests(unittest.TestCase):
 def setUp(self):
  temp=tempfile.TemporaryDirectory();self.addCleanup(temp.cleanup);self.root=Path(temp.name)
  loaded=runpy.run_path(str(SCRIPT));self.n=loaded['apply'].__globals__
  source=self.root/'source';source.mkdir();state=self.root/'state';state.mkdir();evidence=self.root/'evidence';evidence.mkdir()
  self.n.update(ROOT=source,STATE=state,EVIDENCE=evidence,trusted=lambda p:p.read_bytes())
  self.old={'kaname/__init__.py':b'VERSION="0.14.0-dev.34"\n','kaname/radius.py':b'protected radius\n'}
  self.files={**self.old,'kaname/__init__.py':b'VERSION="0.14.0-dev.35"\n','kaname/connector_channel.py':b'reviewed channel\n'}
  self.n.update(BASELINE={k:hashlib.sha256(v).hexdigest() for k,v in self.old.items()},ALLOWED={'kaname/__init__.py','kaname/connector_channel.py'},NEW_FILES={'kaname/connector_channel.py'},PROTECTED=['kaname/radius.py'])
  for name,data in self.old.items():self.write(name,data)
  self.calls=[];self.caches=[]
  def atomic(path,text):path.parent.mkdir(parents=True,exist_ok=True);path.write_text(text)
  self.helper={'command':lambda *args:self.calls.append(args),'atomic_text':atomic}
  self.n.update(ready=lambda *a:None,radius_ready=lambda:'radius-pid',UPDATER={'quarantine_caches':lambda *a,**k:self.caches.append(a)})
 def write(self,name,data):
  path=self.n['ROOT']/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(data)
 def test_exact_source_scope_blocks_protected_unknown_and_installed_drift(self):
  self.n['source_check'](self.files)
  for files in ({**self.files,'kaname/radius.py':b'tampered'},{**self.files,'kaname/unknown.py':b'unknown'}):
   with self.assertRaises(ValueError):self.n['source_check'](files)
  self.write('kaname/__init__.py',b'drift')
  with self.assertRaisesRegex(ValueError,'INSTALLED_SOURCE_DRIFT'):self.n['source_check'](self.files)
 def test_unrecognized_installed_source_is_not_silently_kept(self):
  self.write('kaname/surprise.py',b'unknown')
  with self.assertRaisesRegex(ValueError,'UNRECOGNIZED_INSTALLED_SOURCE'):self.n['source_check'](self.files)
 def test_panel_only_apply_quarantines_before_swap_and_is_idempotent(self):
  self.assertTrue(self.n['apply'](self.files,self.helper,lambda:True))
  self.assertEqual([('/usr/bin/systemctl','stop','kaname-lab.service'),('/usr/bin/systemctl','start','kaname-lab.service')],self.calls)
  self.assertEqual(1,len(self.caches));self.calls.clear()
  self.assertFalse(self.n['apply'](self.files,self.helper,lambda:True));self.assertEqual([],self.calls)
  self.assertEqual(1,len(self.caches));self.n['source_check'](self.files)
 def test_health_failure_restores_code_removes_only_new_source_and_preserves_data(self):
  marker=self.n['STATE']/'business';marker.write_text('keep')
  def ready(version,files):
   if version=='0.14.0-dev.35':raise ValueError('candidate health failed')
  self.n['ready']=ready
  with self.assertRaisesRegex(ValueError,'candidate health failed'):self.n['apply'](self.files,self.helper,lambda:True)
  self.assertEqual(self.old['kaname/__init__.py'],(self.n['ROOT']/'kaname/__init__.py').read_bytes())
  self.assertFalse((self.n['ROOT']/'kaname/connector_channel.py').exists())
  self.assertEqual('keep',marker.read_text());self.assertTrue(all(c[-1]=='kaname-lab.service' for c in self.calls))
 def test_concurrent_business_change_defers_rollback_without_reverting_data(self):
  marker=self.n['STATE']/'business';marker.write_text('new policy')
  self.n['ready']=lambda *a:(_ for _ in ()).throw(ValueError('candidate health failed'))
  with self.assertRaisesRegex(ValueError,'ROLLBACK_REQUIRES_STATE_REVIEW'):self.n['apply'](self.files,self.helper,lambda:False)
  self.assertEqual('new policy',marker.read_text())
  self.assertEqual(self.files['kaname/__init__.py'],(self.n['ROOT']/'kaname/__init__.py').read_bytes())
  self.assertEqual(2,len(self.calls))
 def test_active_backup_is_refused_without_stopping_it(self):
  for state in ('active','activating','deactivating'):
   with patch('subprocess.check_output',return_value=state),self.assertRaisesRegex(ValueError,'SCHEDULED_BACKUP_CURRENTLY_RUNNING'):self.n['backup_idle']()
  with patch('subprocess.check_output',return_value='inactive'):self.n['backup_idle']()
  self.assertEqual([],self.calls)

class ConnectorPublicMetadataTests(unittest.TestCase):
 def test_public_context_read_has_no_database_or_binding_write(self):
  from . import test_connector_registry as fixtures
  fixtures.ConnectorRegistryTests.setUpClass()
  try:
   root=Path(fixtures.ConnectorRegistryTests.base.name)
   n=runpy.run_path(str(SCRIPT))['public_metadata'].__globals__
   state=root/'state';certificate=(root/'web.crt').read_bytes()
   n.update(ROOT=SCRIPT.parents[2],STATE=state,trusted=lambda p:certificate)
   from kaname.store import Store
   store=Store(state);snapshot=store.snapshot();audit=store.audit()
   value=n['public_metadata']()
   self.assertEqual(fixtures.ConnectorRegistryTests.authority['instance_id'],value['instance_id'])
   self.assertFalse(value['secrets_exported']);self.assertFalse(value['binding_created'])
   self.assertNotIn('PRIVATE KEY',json.dumps(value));self.assertNotIn('public_key_pem',value)
   self.assertEqual(snapshot,store.snapshot());self.assertEqual(audit,store.audit())
  finally:fixtures.ConnectorRegistryTests.tearDownClass()

if __name__=='__main__':unittest.main()
