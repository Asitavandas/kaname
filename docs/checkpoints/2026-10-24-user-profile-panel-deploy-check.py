"""Disposable delivery boundaries; no customer paths or real service commands."""
import hashlib,json,runpy,sqlite3,tempfile,unittest
from pathlib import Path
ROOT=Path(__file__).parents[2]
class DeliveryTests(unittest.TestCase):
 def setUp(self):
  self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup);self.path=Path(self.tmp.name)
  n=runpy.run_path(str(Path(__file__).with_name('2026-10-24-user-profile-panel-deploy.py')));self.n=n['source_check'].__globals__
  self.n.update(ROOT=self.path/'source',STATE=self.path/'state',trusted=lambda p:p.read_bytes())
  self.n['ROOT'].mkdir();self.n['STATE'].mkdir()
  self.old={'kaname/__init__.py':b'VERSION="0.14.0-dev.29"\n','kaname/radius.py':b'protected\n'}
  self.files={**self.old,'kaname/__init__.py':b'VERSION="0.14.0-dev.32"\n','kaname/user_enrollment.py':b'new user backend\n'}
  self.n.update(BASELINE={k:hashlib.sha256(b).hexdigest() for k,b in self.old.items()},ALLOWED={'kaname/__init__.py','kaname/user_enrollment.py'},NEW_FILES={'kaname/user_enrollment.py'},PROTECTED=['kaname/radius.py'])
  self.write(self.old)
 def write(self,files):
  for name,b in files.items():p=self.n['ROOT']/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(b)
 def test_source_guard_and_exact_retry(self):
  self.n['source_check'](self.files)
  for files in [{**self.files,'kaname/radius.py':b'changed'}, {**self.files,'kaname/unknown.py':b'unknown'}]:
   with self.assertRaises(ValueError):self.n['source_check'](files)
  (self.n['ROOT']/'kaname/__init__.py').write_text('drift')
  with self.assertRaisesRegex(ValueError,'INSTALLED_SOURCE_DRIFT'):self.n['source_check'](self.files)
  self.write(self.files);self.n['source_check'](self.files)
 def test_empty_additive_schema_projection_and_mismatch(self):
  path=self.n['STATE']/'kaname.sqlite3'
  with sqlite3.connect(path) as db:db.execute('CREATE TABLE existing (id INTEGER PRIMARY KEY,value TEXT)');db.execute("INSERT INTO existing VALUES (1,'keep')")
  statements,expected=self.n['plan_schema']({'kaname/user_enrollment.py':(ROOT/'kaname/user_enrollment.py').read_bytes()});before=self.n['projection'](path)
  self.n['install_schema'](statements,expected);self.n['verify_empty_schema'](expected);self.assertEqual(before,self.n['projection'](path))
  with sqlite3.connect(path) as db:db.execute("UPDATE existing SET value='changed'")
  self.assertNotEqual(before,self.n['projection'](path))
  with sqlite3.connect(path) as db:db.execute('CREATE INDEX surprise ON user_enrollment_profiles(name)')
  with self.assertRaisesRegex(ValueError,'USER_SCHEMA_CHANGED'):self.n['verify_empty_schema'](expected)
 def test_partial_user_schema_is_not_accepted(self):
  path=self.n['STATE']/'kaname.sqlite3'
  with sqlite3.connect(path) as db:db.execute('CREATE TABLE user_enrollment_profiles (id TEXT)')
  with self.assertRaisesRegex(ValueError,'EXISTING_USER_SCHEMA_DIFFERS'):self.n['plan_schema']({'kaname/user_enrollment.py':(ROOT/'kaname/user_enrollment.py').read_bytes()})
 def test_pinned_backup_worker_migration_and_tamper_rejection(self):
  names=['scheduled_backup.py','offline_restore_check.py'];paths={k:self.path/k for k in names};self.n['WORKER_PATHS']=paths;self.n['RELEASE_PATH']=self.path/'release.json'
  candidate={k:(ROOT/'tools'/k).read_bytes() for k in names}
  old={'scheduled_backup.py':candidate['scheduled_backup.py'].replace(b"'user_enrollment_challenges', 'user_enrollment_rate', ",b'',1),'offline_restore_check.py':b'old restore worker'}
  self.n['BASELINE'].update({'tools/'+k:hashlib.sha256(b).hexdigest() for k,b in old.items()})
  for k,p in paths.items():p.write_bytes(old[k])
  self.n['RELEASE_PATH'].write_text(json.dumps({k:hashlib.sha256(b).hexdigest() for k,b in old.items()}))
  plan=self.n['worker_plan']({'tools/'+k:b for k,b in candidate.items()});self.assertEqual(candidate,plan[2])
  paths['scheduled_backup.py'].write_bytes(old['scheduled_backup.py']+b'# tamper')
  with self.assertRaises(ValueError):self.n['worker_plan']({'tools/'+k:b for k,b in candidate.items()})
 def setup_apply(self):
  self.n['EVIDENCE']=self.path/'evidence';self.n['EVIDENCE'].mkdir()
  self.n['WORKER_PATHS']={k:self.path/k for k in ['scheduled_backup.py','offline_restore_check.py']};self.n['RELEASE_PATH']=self.path/'release.json'
  old={k:('old '+k).encode() for k in self.n['WORKER_PATHS']};new={k:('new '+k).encode() for k in old}
  for k,p in self.n['WORKER_PATHS'].items():p.write_bytes(old[k])
  self.n['RELEASE_PATH'].write_bytes(b'old release');self.workers=(old,b'old release',new,b'new release');self.commands=[]
  def atomic(p,text,mode=0o644):p.parent.mkdir(parents=True,exist_ok=True);p.write_text(text);p.chmod(mode)
  self.helper={'command':lambda *a:self.commands.append(a),'atomic_text':atomic}
  self.n.update(install_schema=lambda *a:None,ready=lambda *a:None)
 def test_apply_idempotence_and_radius_preservation(self):
  self.setup_apply();self.assertTrue(self.n['apply'](self.files,self.helper,(),(),self.workers))
  self.assertEqual([('stop','kaname-lab.service'),('start','kaname-lab.service')],[a[-2:] for a in self.commands]);self.commands.clear()
  same=(self.workers[2],self.workers[3],self.workers[2],self.workers[3]);self.assertFalse(self.n['apply'](self.files,self.helper,(),(),same));self.assertEqual([],self.commands)
 def test_new_health_failure_rolls_back(self):
  self.setup_apply()
  def ready(version,files):
   if version=='0.14.0-dev.32':raise ValueError('synthetic health failure')
  self.n['ready']=ready
  with self.assertRaisesRegex(ValueError,'synthetic health failure'):self.n['apply'](self.files,self.helper,(),(),self.workers)
  self.assertEqual(self.old['kaname/__init__.py'],(self.n['ROOT']/'kaname/__init__.py').read_bytes());self.assertFalse((self.n['ROOT']/'kaname/user_enrollment.py').exists())
  for name,p in self.n['WORKER_PATHS'].items():self.assertEqual(self.workers[0][name],p.read_bytes())
  self.assertTrue(all(a[-1]=='kaname-lab.service' for a in self.commands))
 def test_postcheck_restore_does_not_erase_data(self):
  self.setup_apply();marker=self.n['STATE']/'business';marker.write_text('preserved');previous={n:self.old.get(n) for n in self.n['ALLOWED']}
  self.n['apply'](self.files,self.helper,(),(),self.workers);self.n['restore'](self.files,self.helper,previous,self.workers)
  self.assertEqual('preserved',marker.read_text());self.assertFalse((self.n['ROOT']/'kaname/user_enrollment.py').exists());self.assertTrue(all(a[-1]=='kaname-lab.service' for a in self.commands))
if __name__=='__main__':unittest.main(verbosity=2)
