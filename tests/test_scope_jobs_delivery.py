"""Disposable delivery checks; never access customer state or system services."""
import hashlib
import json
from pathlib import Path
import runpy
import tempfile
import unittest
from unittest.mock import patch

SCRIPT=Path(__file__).resolve().parents[1]/'docs/checkpoints/2026-10-27-scope-jobs-dev40-deploy.py'

class ScopeJobsDeliveryTests(unittest.TestCase):
 def setUp(self):
  temp=tempfile.TemporaryDirectory();self.addCleanup(temp.cleanup);self.root=Path(temp.name)
  loaded=runpy.run_path(str(SCRIPT));self.n=loaded['apply'].__globals__
  self.real_server_guard=self.n['server_guards'];self.n['server_guards']=lambda raw:None
  self.actual_allowed=set(self.n['ALLOWED']);self.actual_protected=set(self.n['PROTECTED']);self.actual_new=set(self.n['NEW_FILES'])
  source=self.root/'source';source.mkdir();state=self.root/'state';state.mkdir();evidence=self.root/'evidence';evidence.mkdir()
  self.n.update(ROOT=source,STATE=state,EVIDENCE=evidence,trusted=lambda p:p.read_bytes())
  self.old={'kaname/__init__.py':b'VERSION="0.14.0-dev.39"\n','kaname/radius.py':b'protected radius\n','kaname/static/app.js':b'old ui\n'}
  self.files={**self.old,'kaname/server.py':b'fixture server','kaname/scope_jobs.py':b'readonly jobs','kaname/__init__.py':b'VERSION="0.14.0-dev.40"\n','kaname/static/app.js':b'reviewed ui\n'}
  self.n.update(BASELINE={k:hashlib.sha256(v).hexdigest() for k,v in self.old.items()},ALLOWED={'kaname/__init__.py','kaname/static/app.js','kaname/server.py','kaname/scope_jobs.py'},NEW_FILES={'kaname/server.py','kaname/scope_jobs.py'},PROTECTED=['kaname/radius.py'])
  for name,data in self.old.items():self.write(name,data)
  self.calls=[];self.caches=[]
  def atomic(path,text):path.parent.mkdir(parents=True,exist_ok=True);path.write_text(text)
  self.helper={'command':lambda *args:self.calls.append(args),'atomic_text':atomic}
  self.n.update(ready=lambda *a:None,radius_ready=lambda:'radius-pid',UPDATER={'quarantine_caches':lambda *a,**k:self.caches.append(a)})
 def write(self,name,data):
  path=self.n['ROOT']/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(data)
 def test_actual_release_allows_only_six_ui_and_version_files(self):
  self.assertEqual({'pyproject.toml', 'kaname/deployment_candidates.py', 'kaname/scope_jobs.py', 'kaname/server.py', 'kaname/static/deployment.js', 'kaname/__init__.py'},self.actual_allowed)
  self.assertEqual({'kaname/scope_jobs.py'},self.actual_new)
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
   if version=='0.14.0-dev.40':raise ValueError('candidate health failed')
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
  self.n['SERVER_FUNCTIONS']=[*self.n['SERVER_FUNCTIONS'],'Handler.deployment_candidate_admin']
  # The next reviewed release extends only peer dispatch; this historical updater
  # keeps its old pin and is not used to install the current source.
  self.n['SERVER_PROTECTED']={k:v for k,v in self.n['SERVER_PROTECTED'].items() if k!='Handler.connector_peer'}
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

 def test_new_capability_heartbeat_is_volatile_but_all_jobs_stay_protected(self):
  import sqlite3
  path=self.root/'fixture.sqlite3'
  with sqlite3.connect(path) as db:db.execute('CREATE TABLE runtime_settings (name TEXT PRIMARY KEY,payload TEXT)')
  before=self.n['projection'](path)
  value={'format':1,'jobs':[],'polls':[{'id':'poll','until':42}],'last_poll':{'at':41}}
  with sqlite3.connect(path) as db:db.execute('INSERT INTO runtime_settings VALUES (?,?)',('windows_deployment_scope_jobs',json.dumps(value)))
  self.assertEqual(before,self.n['projection'](path))
  value['jobs']=[{'id':'fixture-job','lease':'durable','result':None}]
  with sqlite3.connect(path) as db:db.execute('UPDATE runtime_settings SET payload=?',(json.dumps(value),))
  with_job=self.n['projection'](path);self.assertNotEqual(before,with_job)
  value['last_poll']={'at':100};value['polls']=[]
  with sqlite3.connect(path) as db:db.execute('UPDATE runtime_settings SET payload=?',(json.dumps(value),))
  self.assertEqual(with_job,self.n['projection'](path))
  value['jobs'][0]['result']='changed'
  with sqlite3.connect(path) as db:db.execute('UPDATE runtime_settings SET payload=?',(json.dumps(value),))
  self.assertNotEqual(with_job,self.n['projection'](path))

if __name__=='__main__':unittest.main()
