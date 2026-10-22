"""Isolated update probes: no real service, host power or customer data access."""
from pathlib import Path
import runpy,tempfile,json,subprocess
from unittest.mock import patch

script=Path(__file__).with_name('authwire-account-menu-20261022.py')
if not script.exists():script=Path(__file__).with_name('2026-10-22-account-menu-update.py')
ns=runpy.run_path(str(script));g=ns['patch_source'].__globals__
scope={'kaname/__init__.py','kaname/static/app.js','tools/service_control_broker.py','tests/test_host_power.py'}

def scenario(failure=None):
    with tempfile.TemporaryDirectory() as folder:
        root=Path(folder)/'source';root.mkdir();broker=Path(folder)/'broker.py';broker.write_bytes(b'old broker');broker.chmod(0o600)
        old={'kaname/__init__.py':b'VERSION="0.14.0-dev.17"\n','kaname/static/app.js':b'old ui', 'tools/service_control_broker.py':b'old broker'}
        new={**old,'kaname/__init__.py':b'VERSION="0.14.0-dev.18"\n','kaname/static/app.js':b'new ui', 'tools/service_control_broker.py':b'new broker','tests/test_host_power.py':b'new test','kaname/device_client/AuthWire-Client.ps1':b'unchanged client'}
        for name,data in old.items():p=root/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(data)
        (root/'tests').mkdir();calls=[];remaining=[failure]
        def command(*args):
            calls.append(args)
            if args[0]=='/usr/sbin/runuser':
                is_new=b'dev.18' in (root/'kaname/__init__.py').read_bytes()
                if not is_new and 'power_status' in args[-1]:raise ValueError('Old client cannot query new route')
                return subprocess.CompletedProcess(args,0,json.dumps({'available':True,'busy':False,'power_available':True,'power_busy':False}),'')
            if remaining[0]=='start' and args[1:]==('start','authwire-service-control.service'):
                remaining[0]=None;raise RuntimeError('Injected broker start failure')
            return subprocess.CompletedProcess(args,0,b'',b'')
        def atomic(path,text,mode=0o644):
            if remaining[0]=='write' and path.name=='app.js':remaining[0]=None;raise RuntimeError('Injected source write failure')
            path.write_text(text);path.chmod(mode)
        def health(_ip,version,_sha):return not (remaining[0]=='health' and version.endswith('18'))
        save={k:g[k] for k in ('ROOT','BROKER','ALLOWED')};g.update(ROOT=root,BROKER=broker,ALLOWED=scope)
        helper={'command':command,'atomic_text':atomic,'health':health,'radius_process_guard':lambda:'832810'}
        try:
            with patch('time.sleep',lambda _:None):
                if failure:
                    try:ns['patch_source'](new,helper)
                    except (RuntimeError,ValueError):pass
                    else:raise AssertionError('Injected failure was ignored')
                    assert all((root/n).read_bytes()==v for n,v in old.items())
                    assert broker.read_bytes()==b'old broker'
                    assert not (root/'tests/test_host_power.py').exists()
                else:
                    assert ns['patch_source'](new,helper) is True
                    assert broker.read_bytes()==b'new broker'
                    calls.clear();assert ns['patch_source'](new,helper) is False
                    assert not any(a[0]=='/usr/bin/systemctl' for a in calls)
                    # A post-check rollback also restores the dev17 client/broker.
                    rollback={**new,**old,'tests/test_host_power.py':None}
                    assert ns['patch_source'](rollback,helper) is True
                    assert broker.read_bytes()==b'old broker'
            assert broker.stat().st_mode&0o777==0o600
            assert not any(a[0]=='/usr/bin/systemctl' and 'authwire-radius.service' in a for a in calls)
            assert not any('reboot' in a or 'poweroff' in a or a[0]=='/usr/bin/systemd-run' for a in calls)
        finally:g.update(save)

for failure in (None,'write','start','health'):scenario(failure)
print('ACCOUNT_UPDATE_IDEMPOTENCE_ROLLBACK_BROKER_MODE_RADIUS_AND_POWER_BOUNDARIES_OK')
