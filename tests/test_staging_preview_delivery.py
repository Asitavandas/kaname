"""Review the operator-only delivery delta without invoking sudo or services."""
import ast
import hashlib
import json
from pathlib import Path
import runpy
import unittest

ROOT=Path(__file__).resolve().parents[1]
NEW=ROOT/'docs/checkpoints/2026-10-28-staging-preview-jobs-dev44-deploy.py'
OLD=ROOT/'docs/checkpoints/2026-10-28-combined-scope-jobs-dev43-deploy.py'

class StagingPreviewDeliveryTests(unittest.TestCase):
 @classmethod
 def setUpClass(cls):
  cls.new=runpy.run_path(str(NEW),run_name='delivery_review')
  cls.old=runpy.run_path(str(OLD),run_name='previous_delivery_review')

 def test_only_reviewed_runtime_version_and_backup_files_are_allowed(self):
  expected={'kaname/__init__.py','pyproject.toml','kaname/staging_preview_jobs.py',
   'kaname/connector_jobs.py','kaname/deployment_candidates.py','kaname/server.py',
   'kaname/static/deployment.js','tools/scheduled_backup.py'}
  self.assertEqual(expected,self.new['ALLOWED'])
  self.assertEqual({'kaname/staging_preview_jobs.py'},self.new['NEW_FILES'])
  self.assertEqual(set(self.new['BASELINE'])-expected,set(self.new['PROTECTED']))
  self.assertEqual(self.old['SERVER_PROTECTED'],self.new['SERVER_PROTECTED'])
  self.assertEqual(self.old['SERVER_FUNCTIONS'],self.new['SERVER_FUNCTIONS'])

 def test_baseline_advances_only_the_previously_reviewed_delivery(self):
  self.assertEqual(set(self.old['BASELINE'])|self.old['NEW_FILES'],set(self.new['BASELINE']))
  changed={n for n,h in self.old['BASELINE'].items() if self.new['BASELINE'][n]!=h}
  self.assertLessEqual(changed,self.old['ALLOWED'])
  self.assertEqual(182,len(self.new['BASELINE']))

 def test_installer_behaviour_preserves_reviewed_guards_and_rollback(self):
  def functions(path):
   return {n.name:ast.unparse(n) for n in ast.parse(path.read_text()).body if isinstance(n,ast.FunctionDef)}
  old,new=functions(OLD),functions(NEW)
  self.assertEqual(set(old),set(new))
  def normalize(value):
   for a,b in [('0.14.0-dev.44','0.14.0-dev.43'),
    ('STAGING_PREVIEW_JOBS','COMBINED_SCOPE_JOBS'),
    ('staging-preview-jobs-dev44-','combined-scope-jobs-dev43-'),
    ('reviewed_readonly_staging_preview_jobs','reviewed_readonly_combined_scope_jobs'),
    ('staging_preview_worker_delivery_pending','combined_scope_worker_delivery_pending'),
    ('staging_preview_job_channel_added','combined_scope_job_channel_added'),
    ('staging_preview_jobs_created','combined_scope_jobs_created')]:value=value.replace(a,b)
   return value
  for name in set(old)-{'stable_runtime_payload','preflight_import'}:
   self.assertEqual(old[name],normalize(new[name]),name)
  self.assertEqual(old['preflight_import'],new['preflight_import'].replace('import kaname.staging_preview_jobs;',''))

 def test_same_normalization_as_the_installed_candidate_worker(self):
  def function(path,name):
   return next(ast.dump(n,include_attributes=False) for n in ast.parse(path.read_text()).body if isinstance(n,ast.FunctionDef) and n.name==name)
  self.assertEqual(function(NEW,'stable_runtime_payload'),function(ROOT/'tools/scheduled_backup.py','stable_runtime_payload'))
  self.assertEqual(self.old['POLL_SECTIONS']|{'windows_staging_preview_jobs'},self.new['POLL_SECTIONS'])

 def test_large_results_are_preserved_and_only_poll_metadata_is_ignored(self):
  ledger={'format':1,'jobs':[{'evidence':'x'*110000}],'polls':[],
   'last_poll':{'scope':'a'*64,'at':1,'release_id':'11111111-1111-4111-8111-111111111111'}}
  raw=json.dumps(ledger);f=self.new['stable_runtime_payload']
  normalized=f('windows_staging_preview_jobs',raw)
  self.assertEqual(json.loads(normalized),{'format':1,'jobs':ledger['jobs']})
  ledger['last_poll']['at']=2
  self.assertEqual(normalized,f('windows_staging_preview_jobs',json.dumps(ledger)))
  ledger['jobs'][0]['evidence']+='changed'
  self.assertNotEqual(normalized,f('windows_staging_preview_jobs',json.dumps(ledger)))
  self.assertEqual(raw,f('windows_candidate_verify_jobs',raw))

 def test_malformed_polling_is_never_silently_discarded(self):
  raw='{"format":1,"jobs":[],"polls":[{"id":"bad","until":1}],"last_poll":null}'
  self.assertEqual(raw,self.new['stable_runtime_payload']('windows_staging_preview_jobs',raw))

 def test_backup_candidate_and_restore_checker_are_pinned(self):
  data=(ROOT/'tools/scheduled_backup.py').read_bytes()
  self.assertEqual(hashlib.sha256(data).hexdigest(),self.new['BACKUP_NEW'])
  self.assertEqual(self.old['BACKUP_NEW'],self.new['BACKUP_OLD'])
  self.assertEqual(self.old['CHECKER'],self.new['CHECKER'])
  result=self.new['backup_candidate']({'tools/scheduled_backup.py':data})
  self.assertEqual(self.new['BACKUP_NEW'],json.loads(result['release.json'])['scheduled_backup.py'])
  with self.assertRaises(self.new['GuardError']):self.new['backup_candidate']({'tools/scheduled_backup.py':data+b'changed'})

 def test_import_does_not_run_delivery_and_manifest_is_pinned(self):
  self.assertEqual('preflight',self.new['PHASE']);self.assertIsNone(self.new['EVIDENCE'])
  self.assertRegex(self.new['EXPECTED'],r'\A[a-f0-9]{64}\Z')
  self.assertRegex(self.new['RELEASE'],r'\A[a-f0-9]{40}\Z')
  self.assertIn('LOCAL_SUDO_REQUIRED',NEW.read_text())

if __name__=='__main__':unittest.main()
