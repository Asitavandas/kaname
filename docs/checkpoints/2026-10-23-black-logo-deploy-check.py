from pathlib import Path
import os,runpy,tempfile
from unittest.mock import patch
ns=runpy.run_path(str(Path(__file__).with_name('authwire-black-logo-20261023.py')));g=ns['patch_source'].__globals__
for failure in (None,'write','binary','start','health'):
 with tempfile.TemporaryDirectory() as folder:
  root=Path(folder);old={'kaname/__init__.py':b'VERSION="0.14.0-dev.22"\n','kaname/static/styles.css':b'old ui','kaname/static/authwire-logo.png':b'\x89PNG\r\n\x1a\nOLD\x00\xff'};new={**old,'kaname/__init__.py':b'VERSION="0.14.0-dev.23"\n','kaname/static/styles.css':b'new ui','kaname/static/authwire-logo.png':b'\x89PNG\r\n\x1a\nNEW\x00\xfe','kaname/device_client/AuthWire-Client.ps1':b'preserved'}
  for name,data in old.items():p=root/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(data)
  calls=[];remaining=[failure];replace=os.replace
  def command(*args):
   calls.append(args)
   if remaining[0]=='start' and args[1:] == ('start','kaname-lab.service'):remaining[0]=None;raise RuntimeError('Injected start failure')
  def atomic(path,text):
   if remaining[0]=='write' and path.name=='styles.css':remaining[0]=None;raise RuntimeError('Injected text write failure after PNG')
   path.write_text(text)
  def atomic_replace(a,b):
   if remaining[0]=='binary' and str(b).endswith('.png'):remaining[0]=None;raise OSError('Injected PNG replace failure')
   replace(a,b)
  def health(_ip,version,_sha):return not (remaining[0]=='health' and version.endswith('23'))
  saved={k:g[k] for k in ('ROOT','ALLOWED')};g.update(ROOT=root,ALLOWED=set(old));helper={'command':command,'atomic_text':atomic,'health':health}
  try:
   with patch('time.sleep',lambda _:None),patch('os.replace',atomic_replace):
    if failure:
     try:ns['patch_source'](new,helper)
     except (RuntimeError,ValueError,OSError):pass
     else:raise AssertionError('Failure ignored')
     assert all((root/n).read_bytes()==v for n,v in old.items())
    else:
     assert ns['patch_source'](new,helper) is True;assert (root/'kaname/static/authwire-logo.png').read_bytes()==new['kaname/static/authwire-logo.png'];calls.clear();assert ns['patch_source'](new,helper) is False;assert not calls
   assert all(args[:1]==('/usr/bin/systemctl',) and args[-1]=='kaname-lab.service' for args in calls);assert not list(root.rglob('.*.update-*'));assert (root/'kaname/static/authwire-logo.png').stat().st_mode&0o777==0o644
  finally:g.update(saved)
print('BLACK_LOGO_ATOMIC_BINARY_IDEMPOTENCE_WRITE_START_HEALTH_ROLLBACK_AND_SERVICE_BOUNDARY_OK')
