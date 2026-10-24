from pathlib import Path
import runpy,tempfile
from unittest.mock import patch
ns=runpy.run_path(str(Path(__file__).with_name('2026-10-24-access-groups-deploy.py')));g=ns['patch_source'].__globals__
for failure in (None,'write','panel_start','radius_start','health','listener'):
 with tempfile.TemporaryDirectory() as folder:
  root=Path(folder)
  old={'kaname/__init__.py':b'VERSION="0.14.0-dev.27"\n','kaname/server.py':b'old server'}
  new={**old,'kaname/__init__.py':b'VERSION="0.14.0-dev.28"\n','kaname/server.py':b'new server','kaname/access_groups.py':b'new group module','kaname/static/access-groups.js':b'new group UI','kaname/device_client/AuthWire-Client.ps1':b'unchanged'}
  for name in new:(root/name).parent.mkdir(parents=True,exist_ok=True)
  for name,data in old.items():(root/name).write_bytes(data)
  calls=[];remaining=[failure]
  def command(*args):
   calls.append(args)
   target={'panel_start':'kaname-lab.service','radius_start':'authwire-radius.service'}.get(remaining[0])
   if target and args[1:]==('start',target):remaining[0]=None;raise RuntimeError('Injected start failure')
  def atomic(path,text):
   if remaining[0]=='write' and path.name=='server.py':remaining[0]=None;raise RuntimeError('Injected partial write failure')
   path.write_text(text)
  def health(ip,version,digest):return not(remaining[0]=='health' and version.endswith('28'))
  def radius_ready():
   if remaining[0]=='listener':remaining[0]=None;raise RuntimeError('Injected missing listener')
   return '42'
  keys=('ROOT','ALLOWED','NEW_FILES','radius_ready');saved={k:g[k] for k in keys};g.update(ROOT=root,ALLOWED=set(new)-{'kaname/device_client/AuthWire-Client.ps1'},NEW_FILES={'kaname/access_groups.py','kaname/static/access-groups.js'},radius_ready=radius_ready)
  helper={'command':command,'atomic_text':atomic,'health':health}
  try:
   with patch('time.sleep',lambda _:None):
    if failure:
     try:ns['patch_source'](new,helper)
     except (RuntimeError,ValueError):pass
     else:raise AssertionError('Failure ignored')
     assert all((root/n).read_bytes()==v for n,v in old.items())
     assert all(not(root/n).exists() for n in g['NEW_FILES'])
     assert calls[-1]==('/usr/bin/systemctl','start','authwire-radius.service')
    else:
     assert ns['patch_source'](new,helper) is True
     assert all((root/n).read_bytes()==v for n,v in new.items() if n in g['ALLOWED'])
     assert calls==[('/usr/bin/systemctl','stop','authwire-radius.service'),('/usr/bin/systemctl','stop','kaname-lab.service'),('/usr/bin/systemctl','start','kaname-lab.service'),('/usr/bin/systemctl','start','authwire-radius.service')]
     calls.clear();assert ns['patch_source'](new,helper) is False;assert not calls
   assert all(a[:1]==('/usr/bin/systemctl',) and a[-1] in {'kaname-lab.service','authwire-radius.service'} for a in calls)
  finally:g.update(saved)
print('ACCESS_GROUPS_ROLLBACK_IDEMPOTENCE_AND_PLANNED_SERVICE_BOUNDARY_OK')
