"""Exercise real systemd only on disposable GitHub-hosted fixtures, never customer units."""
import json
import grp
import os
from pathlib import Path
import pwd
import shutil
import socket
import subprocess
import sys
import tempfile
import threading
import time
import uuid

from tools import service_control_broker as broker
from tools.service_control_install import unit_text

def command(*args):
    return subprocess.run(list(args),check=True,capture_output=True,text=True,timeout=30)

def main():
    if os.geteuid()!=0 or os.environ.get('RUNNER_ENVIRONMENT')!='github-hosted':
        raise ValueError('Disposable GitHub-hosted root fixture required')
    root=Path('/etc/systemd/system');tag='authwire-control-fixture-'+str(os.getpid())
    mapping={'radius':tag+'-radius.service','panel':tag+'-panel.service',
             'crl-sync':tag+'-sync.service','crl-timer':tag+'-sync.timer'}
    assert all('fixture' in name and name not in broker.UNITS.values() for name in mapping.values())
    paths=[root/name for name in mapping.values()]
    if any(p.exists() for p in paths):raise ValueError('Fixture already exists')
    uid=int(os.environ['SUDO_UID']);user=pwd.getpwuid(uid)
    folder=Path(tempfile.mkdtemp(prefix=tag+'-',dir='/run'));folder.chmod(0o750);os.chown(folder,0,user.pw_gid)
    with socket.socket(socket.AF_INET,socket.SOCK_DGRAM) as probe:
        probe.bind(('127.0.0.1',0));port=probe.getsockname()[1]
    units={
        'radius':'[Service]\nType=simple\nExecStart=/usr/bin/python3 -c "import socket,time;s=socket.socket(socket.AF_INET,socket.SOCK_DGRAM);s.bind((\'127.0.0.1\','+str(port)+'));time.sleep(600)"\n',
        'panel':'[Service]\nType=simple\nExecStart=/usr/bin/sleep infinity\n',
        'crl-sync':'[Service]\nType=oneshot\nExecStart=/usr/bin/true\n',
        'crl-timer':'[Timer]\nOnActiveSec=1h\nUnit='+mapping['crl-sync']+'\n'}
    old_units=broker.UNITS.copy();server=None;thread=None
    try:
        for key,name in mapping.items():(root/name).write_text(units[key])
        command('systemctl','daemon-reload')
        command('systemctl','start',mapping['radius'],mapping['panel'],mapping['crl-timer'])
        broker.UNITS=mapping
        lock=folder/'update.lock';lock.touch(mode=0o600)
        site=folder/'authwire';site.write_text('listen {\n type = auth\n ipaddr = 127.0.0.1\n port = '+str(port)+'\n}\n')
        control=broker.Controller(folder/'operations.json',update_lock=lock,runtime_site=site)
        server=broker.Server(folder/'control.sock',control,uid);os.chown(folder/'control.sock',0,user.pw_gid);os.chmod(folder/'control.sock',0o660)
        thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
        def rpc(service=None,verb=None,request_id=None,socket_name='control.sock'):
            value={'kind':'status'} if service is None else {'kind':'action','service':service,'action':verb,'request_id':request_id or str(uuid.uuid4()),'actor':'fixture-operator'}
            with socket.socket(socket.AF_UNIX,socket.SOCK_STREAM) as client:
                client.settimeout(10);client.connect(str(folder/socket_name));client.sendall(json.dumps(value).encode()+b'\n')
                with client.makefile('rb') as f:return json.loads(f.readline(262145))
        def complete(request):
            assert request['ok'],request
            ident=request['result']['operation']['id'];deadline=time.monotonic()+20
            while time.monotonic()<deadline:
                current=next(x for x in rpc()['result']['operations'] if x['id']==ident)
                if current['state'] not in {'queued','running'}:
                    assert current['state']=='succeeded',current
                    return current
                time.sleep(.2)
            raise ValueError('Fixture action timed out')
        # Validate the real Unix peer and socket permissions as the non-root panel user.
        source=str(Path(__file__).resolve().parents[1])
        script="import sys;sys.path.insert(0,sys.argv[1]);from kaname.services import Services;print(Services(sys.argv[2]).status()['available'])"
        result=command('/usr/sbin/runuser','-u',user.pw_name,'--','/usr/bin/python3','-I','-B','-c',script,source,str(folder/'control.sock'))
        assert result.stdout.strip()=='True'
        initial=rpc()['result'];radius=next(x for x in initial['services'] if x['id']=='radius');old_pid=radius['pid'];boot=radius['enabled']
        assert radius['listener_present']
        restart=rpc('radius','restart');complete(restart)
        current=control.inspect('radius');assert current['pid']!=old_pid and current['enabled']==boot
        duplicate=rpc('radius','restart',restart['result']['operation']['id']);assert duplicate['result']['operation']['state']=='succeeded'
        complete(rpc('radius','stop'));assert control.inspect('radius')['active_state']=='inactive'
        assert rpc('crl-sync','sync')['error']=='RADIUS_NOT_RUNNING'
        complete(rpc('radius','start'));complete(rpc('crl-sync','sync'))
        complete(rpc('crl-timer','stop'));complete(rpc('crl-timer','start'))
        assert control.inspect('panel')['active_state']=='active'
        assert rpc('panel','stop')['error']=='ACTION_NOT_ALLOWED'
        assert rpc('sshd','stop')['error']=='ACTION_NOT_ALLOWED'
        # Execute the actual hardened unit contract as well as the in-process
        # lifecycle fixture. Fixture files/units are distinct from product names.
        shutil.copy2(Path(broker.__file__),folder/'broker.py')
        launcher=folder/'sandbox.py'
        launcher.write_text("import importlib.util,os\nfrom pathlib import Path\n"
            +"s=importlib.util.spec_from_file_location('fixture_broker',"+repr(str(folder/'broker.py'))+");m=importlib.util.module_from_spec(s);s.loader.exec_module(m)\n"
            +"m.UNITS="+repr(mapping)+"\n"
            +"c=m.Controller(Path("+repr(str(folder/'sandbox-operations.json'))+"),update_lock=Path("+repr(str(lock))+"),runtime_site=Path("+repr(str(site))+"))\n"
            +"with m.Server(Path("+repr(str(folder/'sandbox.sock'))+"),c,"+str(uid)+") as server:\n os.chmod("+repr(str(folder/'sandbox.sock'))+",0o660)\n server.serve_forever()\n")
        sandbox_name=tag+'-broker.service';sandbox_unit=root/sandbox_name;paths.append(sandbox_unit)
        text=unit_text().replace('Group=kaname-lab','Group='+grp.getgrgid(user.pw_gid).gr_name)
        text=text.replace('/opt/authwire-service-control/broker.py',str(launcher))
        text=text.replace('RuntimeDirectory=authwire-service-control','RuntimeDirectory='+folder.name)
        text=text.replace('StateDirectory=authwire-service-control','StateDirectory='+folder.name)
        text=text.replace('/run/authwire-service-control /var/lib/authwire-service-control',str(folder)+' /var/lib/'+folder.name)
        sandbox_unit.write_text(text);command('systemd-analyze','verify',str(sandbox_unit))
        command('systemctl','daemon-reload');command('systemctl','start',sandbox_name)
        deadline=time.monotonic()+10
        while not (folder/'sandbox.sock').exists() and time.monotonic()<deadline:time.sleep(.1)
        result=command('/usr/sbin/runuser','-u',user.pw_name,'--','/usr/bin/python3','-I','-B','-c',script,source,str(folder/'sandbox.sock'))
        assert result.stdout.strip()=='True'
        initial_sandbox=rpc(socket_name='sandbox.sock')
        assert initial_sandbox['ok'] and next(r for r in initial_sandbox['result']['services'] if r['id']=='radius')['listener_present']
        requested=rpc('radius','restart',socket_name='sandbox.sock');assert requested['ok']
        ident=requested['result']['operation']['id'];deadline=time.monotonic()+20
        while time.monotonic()<deadline:
            outcome=next(j for j in rpc(socket_name='sandbox.sock')['result']['operations'] if j['id']==ident)
            if outcome['state'] not in {'queued','running'}:break
            time.sleep(.2)
        assert outcome['state']=='succeeded',outcome
        command('systemctl','stop',sandbox_name)
        shutil.rmtree(Path('/var/lib')/folder.name)
        print(json.dumps({'service_control_systemd_fixture':'passed','real_systemd_start_stop_restart':True,
                          'radius_udp_listener_verified':True,'boot_setting_preserved':True,
                          'nonroot_socket_query':True,'duplicate_restart_not_replayed':True,
                          'panel_self_stop_rejected':True,'hardened_broker_unit_verified':True,'customer_units_used':False}))
    finally:
        if server:server.shutdown();server.server_close()
        if thread:thread.join(timeout=5)
        broker.UNITS=old_units
        subprocess.run(['systemctl','stop',tag+'-broker.service'],capture_output=True,timeout=30)
        subprocess.run(['systemctl','stop',*mapping.values()],capture_output=True,timeout=30)
        for path in paths:path.unlink(missing_ok=True)
        command('systemctl','daemon-reload')
        if folder.exists():shutil.rmtree(folder)

if __name__=='__main__':main()
