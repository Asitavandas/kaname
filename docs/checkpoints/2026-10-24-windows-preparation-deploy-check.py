"""Disposable delivery/rollback checks. No live files, DB or service commands."""
import hashlib,runpy,tempfile,unittest
from pathlib import Path

class DeliveryTests(unittest.TestCase):
 def setUp(self):
  self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup);self.path=Path(self.tmp.name)
  n=runpy.run_path(str(Path(__file__).with_name('2026-10-24-windows-preparation-deploy.py')));self.n=n['source_check'].__globals__
  self.n.update(ROOT=self.path/'source',STATE=self.path/'state',trusted=lambda p:p.read_bytes(),EVIDENCE=self.path/'evidence')
  for name in ['ROOT','STATE','EVIDENCE']:self.n[name].mkdir()
  self.old={'kaname/__init__.py':b'VERSION="0.14.0-dev.33"\n','kaname/radius_adapter.py':b'protected\n'}
  self.files={**self.old,'kaname/__init__.py':b'VERSION="0.14.0-dev.34"\n','tests/test_scope.py':b'fixture\n'}
  self.n.update(BASELINE={k:hashlib.sha256(b).hexdigest() for k,b in self.old.items()},ALLOWED={'kaname/__init__.py','tests/test_scope.py'},NEW_FILES={'tests/test_scope.py'},PROTECTED=['kaname/radius_adapter.py'])
  for name,b in self.old.items():p=self.n['ROOT']/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(b)
  self.marker=self.n['STATE']/'current-policy';self.marker.write_text('must never restore or delete')
  self.commands=[]
  def atomic(p,text,mode=0o644):p.parent.mkdir(parents=True,exist_ok=True);p.write_text(text)
  self.helper={'command':lambda *a:self.commands.append(a[-2:]),'atomic_text':atomic}
  self.n.update(ready=lambda *a:None,radius_ready=lambda:'2')
 def test_source_scope_exact_retry_and_drift(self):
  self.n['source_check'](self.files)
  with self.assertRaisesRegex(ValueError,'PROTECTED_AUTHENTICATION_SOURCE_CHANGED'):self.n['source_check']({**self.files,'kaname/radius_adapter.py':b'drift'})
  with self.assertRaisesRegex(ValueError,'SOURCE_SET_DIFFERS'):self.n['source_check']({**self.files,'kaname/unreviewed.py':b'drift'})
  (self.n['ROOT']/'kaname/__init__.py').write_text('drift')
  with self.assertRaisesRegex(ValueError,'INSTALLED_SOURCE_DRIFT'):self.n['source_check'](self.files)
 def test_panel_only_transition_and_idempotent_retry(self):
  self.assertTrue(self.n['apply'](self.files,self.helper,lambda:True))
  self.assertEqual([('stop','kaname-lab.service'),('start','kaname-lab.service')],self.commands)
  self.n['source_check'](self.files);self.commands.clear()
  self.assertFalse(self.n['apply'](self.files,self.helper,lambda:True));self.assertEqual([],self.commands)
  self.assertEqual('must never restore or delete',self.marker.read_text())
 def test_health_failure_restores_only_source_and_both_services(self):
  def ready(version,files):
   if version=='0.14.0-dev.34':raise ValueError('synthetic health failure')
  self.n['ready']=ready
  with self.assertRaisesRegex(ValueError,'synthetic health failure'):self.n['apply'](self.files,self.helper,lambda:True)
  self.assertEqual(self.old['kaname/__init__.py'],(self.n['ROOT']/'kaname/__init__.py').read_bytes())
  self.assertFalse((self.n['ROOT']/'tests/test_scope.py').exists())
  self.assertEqual(('start','kaname-lab.service'),self.commands[-1]);self.assertTrue(all(unit=='kaname-lab.service' for action,unit in self.commands))
  self.assertEqual('must never restore or delete',self.marker.read_text())
 def test_partial_source_failure_rolls_back(self):
  atomic=self.helper['atomic_text'];failed=False
  def fail_once(p,text,mode=0o644):
   nonlocal failed
   if not failed and p.name=='test_scope.py':failed=True;raise OSError('synthetic disk failure')
   atomic(p,text,mode)
  self.helper['atomic_text']=fail_once
  with self.assertRaisesRegex(OSError,'synthetic disk failure'):self.n['apply'](self.files,self.helper,lambda:True)
  self.assertEqual(self.old['kaname/__init__.py'],(self.n['ROOT']/'kaname/__init__.py').read_bytes())
  self.assertFalse((self.n['ROOT']/'tests/test_scope.py').exists())
 def test_new_business_state_never_triggers_old_engine_or_database_restore(self):
  def ready(version,files):raise ValueError('synthetic health failure')
  self.n['ready']=ready
  with self.assertRaisesRegex(ValueError,'ROLLBACK_REQUIRES_STATE_REVIEW'):self.n['apply'](self.files,self.helper,lambda:False)
  self.assertEqual(self.files['kaname/__init__.py'],(self.n['ROOT']/'kaname/__init__.py').read_bytes())
  self.assertEqual(2,len(self.commands));self.assertEqual('must never restore or delete',self.marker.read_text())

if __name__=='__main__':unittest.main(verbosity=2)
