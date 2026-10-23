from pathlib import Path
import runpy,tempfile
from unittest.mock import patch
ns=runpy.run_path(str(Path(__file__).with_name('2026-10-23-central-ui-update.py')))
g=ns['patch_source'].__globals__
for failure in (None,'write','start','health'):
 with tempfile.TemporaryDirectory() as folder:
  root=Path(folder);old={'kaname/__init__.py':b'VERSION="0.14.0-dev.19"\n','kaname/static/app.js':b'old ui'};new={**old,'kaname/__init__.py':b'VERSION="0.14.0-dev.20"\n','kaname/static/app.js':b'new ui','kaname/device_client/AuthWire-Client.ps1':b'preserved'}
  for name,data in old.items():p=root/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(data)
  calls=[];remaining=[failure]
  def command(*args):
   calls.append(args)
   if remaining[0]=='start' and args[1:] == ('start','kaname-lab.service'):remaining[0]=None;raise RuntimeError('Injected start failure')
  def atomic(path,text):
   if remaining[0]=='write' and path.name=='app.js':remaining[0]=None;raise RuntimeError('Injected write failure')
   path.write_text(text)
  def health(_ip,version,_sha):return not (remaining[0]=='health' and version.endswith('20'))
  saved={k:g[k] for k in ('ROOT','ALLOWED')};g.update(ROOT=root,ALLOWED=set(old))
  helper={'command':command,'atomic_text':atomic,'health':health}
  try:
   with patch('time.sleep',lambda _:None):
    if failure:
     try:ns['patch_source'](new,helper)
     except (RuntimeError,ValueError):pass
     else:raise AssertionError('Failure ignored')
     assert all((root/n).read_bytes()==v for n,v in old.items())
    else:
     assert ns['patch_source'](new,helper) is True
     calls.clear();assert ns['patch_source'](new,helper) is False;assert not calls
   assert all(args[:1]==('/usr/bin/systemctl',) and args[-1]=='kaname-lab.service' for args in calls)
  finally:g.update(saved)
print('CENTRAL_UI_PATCH_IDEMPOTENCE_WRITE_START_HEALTH_ROLLBACK_AND_SERVICE_BOUNDARY_OK')
