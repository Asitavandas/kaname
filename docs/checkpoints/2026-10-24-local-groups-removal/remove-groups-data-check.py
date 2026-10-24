from pathlib import Path
import json,runpy,sqlite3,sys,tempfile
sys.path.insert(0,str(Path('authwire-remove-groups-20261024').resolve()))
from kaname.store import Store
from kaname.operations import Operations
from tests.helpers import config,policy
from contextlib import closing, nullcontext
from unittest.mock import patch
ns=runpy.run_path('authwire-remove-groups-20261024.py');g=ns['cleanup_plan'].__globals__
worker=runpy.run_path('authwire-remove-groups-20261024/tools/scheduled_backup.py')
for case in ('normal','referenced','stale','audit_failure'):
 with tempfile.TemporaryDirectory() as folder:
  root=Path(folder);store=Store(root);store.save(0,config=config());ops=Operations(store);store.save(1,policies=[policy()])
  with store.connect() as db:
   ops._save(db,'authwire_access_groups',[{'id':'test','name':'AW-Test-1'}]);ops._save(db,'authwire-access-member:lab.example:guid',{'sid':'test'});ops._save(db,'network',{'preserve':'exact bytes'});ops._save(db,'ordinary_setting',{'keep':True})
   if case=='referenced':
    p=policy();p['conditions']['local_group_ids']=['test'];db.execute('UPDATE state SET policies=?',(json.dumps([p]),))

  old=g['STATE'];g['STATE']=root
  try:
   before=worker['db_fingerprint'](store.path)
   if case=='referenced':
    try:ns['cleanup_plan'](worker)
    except ns['GuardError'] as e:assert e.code=='CANCELLED_SELECTOR_STILL_REFERENCED'
    else:raise AssertionError('Referenced selector accepted')
    assert worker['db_fingerprint'](store.path)==before;continue
   plan=ns['cleanup_plan'](worker);assert plan['before']==before
   if case=='stale':
    with store.connect() as db:ops._save(db,'ordinary_setting',{'keep':'changed'})
    before=worker['db_fingerprint'](store.path)
   if case in ('stale','audit_failure'):
    class Failing(sqlite3.Connection):
     def execute(self,sql,*args):
      if sql.startswith('INSERT INTO audit'):raise sqlite3.IntegrityError('injected audit failure')
      return super().execute(sql,*args)
    original_connect=sqlite3.connect
    context=patch.object(sqlite3,'connect',lambda *args,**kwargs:original_connect(*args,factory=Failing,**kwargs)) if case=='audit_failure' else nullcontext()
    try:
     with context:ns['cleanup_feature'](plan,worker)
    except (ns['GuardError'],sqlite3.IntegrityError):pass
    else:raise AssertionError('Data boundary failure ignored')
    assert worker['db_fingerprint'](store.path)==before
    with store.connect() as db:assert len(ns['feature_rows'](db))==2
   else:
    state=store.snapshot();result=ns['cleanup_feature'](plan,worker);assert result['deleted_rows']==2
    after=store.snapshot();assert after['revision']==state['revision']+1 and after['config']==state['config'] and after['policies']==state['policies']
    assert worker['db_fingerprint'](store.path)==plan['after']
    with store.connect() as db:
     assert not ns['feature_rows'](db);assert db.execute("SELECT payload FROM runtime_settings WHERE name='network'").fetchone()[0]=='{"preserve": "exact bytes"}'
     assert db.execute("SELECT count(*) FROM audit WHERE event LIKE 'local_access_groups_removed:%'").fetchone()[0]==1
    again=ns['cleanup_feature'](ns['cleanup_plan'](worker),worker);assert again['deleted_rows']==0 and store.snapshot()==after
  finally:g['STATE']=old
print('LOCAL_GROUP_REMOVAL_DATA_BOUNDARY_ATOMICITY_STALE_GUARD_AND_IDEMPOTENCE_OK')
