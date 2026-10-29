"""Disposable delivery checks; never access customer state or system services."""
import hashlib
import json
from pathlib import Path
import runpy
import tempfile
import unittest
from unittest.mock import patch

SCRIPT=Path(__file__).resolve().parents[1]/'docs/checkpoints/2026-10-28-combined-jobs-dev42-deploy.py'

class CombinedJobsDeliveryTests(unittest.TestCase):
 def setUp(self):
  temp=tempfile.TemporaryDirectory();self.addCleanup(temp.cleanup);self.root=Path(temp.name)
  loaded=runpy.run_path(str(SCRIPT));self.n=loaded['apply'].__globals__
  self.real_server_guard=self.n['server_guards'];self.n['server_guards']=lambda raw:None
  self.actual_allowed=set(self.n['ALLOWED']);self.actual_protected=set(self.n['PROTECTED']);self.actual_new=set(self.n['NEW_FILES'])
  source=self.root/'source';source.mkdir();state=self.root/'state';state.mkdir();evidence=self.root/'evidence';evidence.mkdir()
  self.n.update(ROOT=source,STATE=state,EVIDENCE=evidence,trusted=lambda p:p.read_bytes())
  self.old={'kaname/__init__.py':b'VERSION="0.14.0-dev.41"\n','kaname/radius.py':b'protected radius\n','kaname/static/app.js':b'old ui\n'}
  self.files={**self.old,'kaname/server.py':b'fixture server','kaname/scope_jobs.py':b'readonly jobs','kaname/__init__.py':b'VERSION="0.14.0-dev.42"\n','kaname/static/app.js':b'reviewed ui\n'}
  self.n.update(BASELINE={k:hashlib.sha256(v).hexdigest() for k,v in self.old.items()},ALLOWED={'kaname/__init__.py','kaname/static/app.js','kaname/server.py','kaname/scope_jobs.py'},NEW_FILES={'kaname/server.py','kaname/scope_jobs.py'},PROTECTED=['kaname/radius.py'])
  for name,data in self.old.items():self.write(name,data)
  self.calls=[];self.caches=[]
  def atomic(path,text,mode=0o644):path.parent.mkdir(parents=True,exist_ok=True);path.write_text(text);path.chmod(mode)
  backup=self.root/'backup';backup.mkdir();self.n['BACKUP_ROOT']=backup
  self.old_worker=b'old worker';self.new_worker=b'new worker'
  self.n.update(BACKUP_OLD=hashlib.sha256(self.old_worker).hexdigest(),BACKUP_NEW=hashlib.sha256(self.new_worker).hexdigest(),CHECKER=hashlib.sha256(b'checker').hexdigest())
  (backup/'scheduled_backup.py').write_bytes(self.old_worker);(backup/'offline_restore_check.py').write_bytes(b'checker')
  (backup/'release.json').write_text(json.dumps({'offline_restore_check.py':self.n['CHECKER'],'scheduled_backup.py':self.n['BACKUP_OLD']}))
  self.files['tools/scheduled_backup.py']=self.new_worker;self.old['tools/scheduled_backup.py']=self.old_worker
  self.n['ALLOWED'].add('tools/scheduled_backup.py');self.n['BASELINE']['tools/scheduled_backup.py']=self.n['BACKUP_OLD'];self.write('tools/scheduled_backup.py',self.old_worker)
  self.backup_old=self.n['backup_before']()
  self.helper={'command':lambda *args:self.calls.append(args),'atomic_text':atomic}
  self.n.update(ready=lambda *a:None,radius_ready=lambda:'radius-pid',UPDATER={'quarantine_caches':lambda *a,**k:self.caches.append(a)})
 def write(self,name,data):
  path=self.n['ROOT']/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(data)
 def test_actual_release_has_seven_reviewed_files_and_one_new_module(self):
  self.assertEqual({'pyproject.toml','kaname/deployment_candidates.py','kaname/combined_jobs.py','kaname/static/deployment.js','kaname/server.py','tools/scheduled_backup.py','kaname/__init__.py'},self.actual_allowed)
  self.assertEqual({'kaname/combined_jobs.py'},self.actual_new)
  self.assertTrue({'kaname/admin.py','kaname/connector_channel.py','kaname/connector_registry.py','kaname/radius.py','kaname/policy.py','kaname/device_client/AuthWire-Client.ps1'}<=self.actual_protected)
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
   if version=='0.14.0-dev.42':raise ValueError('candidate health failed')
  self.n['ready']=ready
  with self.assertRaisesRegex(ValueError,'candidate health failed'):self.n['apply'](self.files,self.helper,lambda:True)
  self.assertEqual(self.old['kaname/__init__.py'],(self.n['ROOT']/'kaname/__init__.py').read_bytes())
  self.assertEqual(self.old['kaname/static/app.js'],(self.n['ROOT']/'kaname/static/app.js').read_bytes())
  self.assertFalse((self.n['ROOT']/'kaname/scope_jobs.py').exists());self.assertFalse((self.n['ROOT']/'kaname/server.py').exists())
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


 def test_actual_protected_server_functions_and_function_set_are_checked(self):
  raw=(SCRIPT.parents[2]/'kaname/server.py').read_bytes()
  # The dev37 updater remains frozen. Current source additionally contains the
  # explicitly reviewed dev38 receipt handler; protected dev37 bodies stay pinned.
  # The next reviewed release extends only peer dispatch; this historical updater
  # keeps its old pin and is not used to install the current source.
  self.n['SERVER_PROTECTED']={k:v for k,v in self.n['SERVER_PROTECTED'].items() if k not in {'Handler.connector_peer','Handler.deployment_candidate_admin','Handler.do_POST'}} # Reviewed combined dispatch only; guard/auth bodies remain pinned.
  # Historical installers remain frozen and reject the new function by default.
  with self.assertRaisesRegex(ValueError,'SERVER_FUNCTION_SET_CHANGED'):self.real_server_guard(raw)
  self.n['SERVER_FUNCTIONS']=[*self.n['SERVER_FUNCTIONS'],'Handler.staging_write_admin']
  self.n['SERVER_PROTECTED']['Handler.staging_write_admin']='b76772b9d4fdbd1f0829c31fa241dddff8ec1b57424e243e59bacfdb711a0332'
  # Pin the reviewed GET dispatch too; do not relax authentication guards.
  self.n['SERVER_PROTECTED']['Handler.get_response']='0ca6ca0f3a37ae7f600dff10163ca280bdece488cd653660dd1fcdbbd9b0d8a6'
  self.real_server_guard(raw)
  changed=raw.replace(b'def guard(self',b'def altered_guard(self',1)
  self.assertNotEqual(raw,changed)
  with self.assertRaisesRegex(ValueError,'SERVER_FUNCTION_SET_CHANGED'):self.real_server_guard(changed)
  changed=raw.replace(b'def guard(self',b'def guard(self',1)+b'\n\ndef unreviewed():pass\n'
  with self.assertRaisesRegex(ValueError,'SERVER_FUNCTION_SET_CHANGED'):self.real_server_guard(changed)
  import ast
  module=ast.parse(raw)
  handler=next(n for n in module.body if isinstance(n,ast.ClassDef) and n.name=='Handler')
  guard=next(n for n in handler.body if isinstance(n,ast.FunctionDef) and n.name=='guard')
  guard.body.insert(0,ast.Expr(value=ast.Constant(value='tampered protected guard')))
  with self.assertRaisesRegex(ValueError,'PROTECTED_SERVER_FUNCTION_CHANGED'):self.real_server_guard(ast.unparse(ast.fix_missing_locations(module)))
  module=ast.parse(raw)
  handler=next(n for n in module.body if isinstance(n,ast.ClassDef) and n.name=='Handler')
  review=next(n for n in handler.body if isinstance(n,ast.FunctionDef) and n.name=='staging_write_admin')
  review.body.insert(0,ast.Expr(value=ast.Constant(value='tampered review gate')))
  with self.assertRaisesRegex(ValueError,'PROTECTED_SERVER_FUNCTION_CHANGED'):self.real_server_guard(ast.unparse(ast.fix_missing_locations(module)))
  module=ast.parse(raw)
  handler=next(n for n in module.body if isinstance(n,ast.ClassDef) and n.name=='Handler')
  response=next(n for n in handler.body if isinstance(n,ast.FunctionDef) and n.name=='get_response')
  response.body.insert(0,ast.Expr(value=ast.Constant(value='tampered dispatch')))
  with self.assertRaisesRegex(ValueError,'PROTECTED_SERVER_FUNCTION_CHANGED'):self.real_server_guard(ast.unparse(ast.fix_missing_locations(module)))

 def test_poll_projection_matches_the_reviewed_backup_guard_without_omitting_rows(self):
  import sqlite3
  path=self.root/'fixture.sqlite3'
  with sqlite3.connect(path) as db:db.execute('CREATE TABLE runtime_settings (name TEXT PRIMARY KEY,payload TEXT)')
  self.assertEqual(4,len(self.n['POLL_SECTIONS']));self.assertIn('windows_combined_verify_jobs',self.n['POLL_SECTIONS'])
  value={'format':1,'jobs':[],'polls':[],'last_poll':None}
  with sqlite3.connect(path) as db:db.execute('INSERT INTO runtime_settings VALUES (?,?)',('windows_combined_verify_jobs',json.dumps(value)))
  before=self.n['projection'](path)
  value['polls']=[{'id':'a'*64,'until':1800000060}]
  value['last_poll']={'scope':'b'*64,'at':1800000000,'release_id':'00000000-0000-4000-8000-000000000001'}
  with sqlite3.connect(path) as db:db.execute('UPDATE runtime_settings SET payload=?',(json.dumps(value),))
  self.assertEqual(before,self.n['projection'](path))
  value['jobs']=[{'id':'fixture-job','lease':'durable','result':None}]
  with sqlite3.connect(path) as db:db.execute('UPDATE runtime_settings SET payload=?',(json.dumps(value),))
  with_job=self.n['projection'](path);self.assertNotEqual(before,with_job)
  value['last_poll']['at']+=1;value['polls']=[]
  with sqlite3.connect(path) as db:db.execute('UPDATE runtime_settings SET payload=?',(json.dumps(value),))
  self.assertEqual(with_job,self.n['projection'](path))
  value['jobs'][0]['result']='changed'
  with sqlite3.connect(path) as db:db.execute('UPDATE runtime_settings SET payload=?',(json.dumps(value),))
  self.assertNotEqual(with_job,self.n['projection'](path))
  value['unknown']='not ignored'
  with sqlite3.connect(path) as db:db.execute('UPDATE runtime_settings SET payload=?',(json.dumps(value),))
  self.assertNotEqual(with_job,self.n['projection'](path))

 def test_backup_pair_updated_and_exact_old_bytes_restored_on_health_failure(self):
  self.n['apply'](self.files,self.helper,lambda:True)
  self.assertEqual(self.n['backup_candidate'](self.files),self.n['backup_before']())
  self.assertEqual(0o644,(self.n['BACKUP_ROOT']/'scheduled_backup.py').stat().st_mode&0o777)
  self.n['restore'](self.files,self.helper,{n:self.old.get(n) for n in self.n['ALLOWED']},lambda:True,self.backup_old)
  self.assertEqual(self.backup_old,self.n['backup_before']())
  def ready(version,files):
   if version=='0.14.0-dev.42':raise ValueError('candidate health failed')
  self.n['ready']=ready
  with self.assertRaisesRegex(ValueError,'candidate health failed'):self.n['apply'](self.files,self.helper,lambda:True)
  self.assertEqual(self.backup_old,self.n['backup_before']())
 def test_backup_drift_checker_change_and_inconsistent_release_are_refused_before_restart(self):
  p=self.n['BACKUP_ROOT']/'release.json';p.write_text('{}')
  with self.assertRaisesRegex(ValueError,'BACKUP_RELEASE_PIN_DIFFERS'):self.n['apply'](self.files,self.helper,lambda:True)
  self.assertEqual([],self.calls)
  p.write_bytes(self.backup_old['release.json']);(self.n['BACKUP_ROOT']/'offline_restore_check.py').write_bytes(b'drift')
  with self.assertRaisesRegex(ValueError,'RESTORE_CHECKER_CHANGED'):self.n['apply'](self.files,self.helper,lambda:True)
  self.assertEqual([],self.calls)
 def test_idempotence_repairs_source_current_but_worker_old(self):
  for n in self.n['ALLOWED']:self.write(n,self.files[n])
  self.assertTrue(self.n['apply'](self.files,self.helper,lambda:True))
  self.assertEqual(self.n['backup_candidate'](self.files),self.n['backup_before']())
 def test_preservation_allows_only_exact_reviewed_backup_hash_changes(self):
  before={str(self.n['BACKUP_ROOT']/n):[hashlib.sha256(data).hexdigest(),0o644,0,0] for n,data in self.backup_old.items()}
  before['protected']=['a'*64,0o600,0,0]
  after={k:list(v) for k,v in before.items()}
  for n,data in self.n['backup_candidate'](self.files).items():after[str(self.n['BACKUP_ROOT']/n)][0]=hashlib.sha256(data).hexdigest()
  self.assertTrue(self.n['backup_preserved'](before,after,self.files))
  after['protected'][0]='b'*64;self.assertFalse(self.n['backup_preserved'](before,after,self.files))
  after['protected'][0]='a'*64;after[str(self.n['BACKUP_ROOT']/'scheduled_backup.py')][1]=0o666
  self.assertFalse(self.n['backup_preserved'](before,after,self.files))
 def test_third_party_worker_change_is_not_overwritten_by_rollback(self):
  self.n['apply'](self.files,self.helper,lambda:True)
  (self.n['BACKUP_ROOT']/'scheduled_backup.py').write_bytes(b'third party')
  with self.assertRaisesRegex(ValueError,'BACKUP_ROLLBACK_REQUIRES_REVIEW'):
   self.n['restore'](self.files,self.helper,{n:self.old.get(n) for n in self.n['ALLOWED']},lambda:True,self.backup_old)
  self.assertEqual(b'third party',(self.n['BACKUP_ROOT']/'scheduled_backup.py').read_bytes())

if __name__=='__main__':unittest.main()

