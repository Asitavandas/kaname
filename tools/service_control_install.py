"""Install the restricted service broker without changing RADIUS or panel units."""
import hashlib
import json
import os
from pathlib import Path
import shutil
import stat
import subprocess
import sys
import time
import uuid

SOURCE=Path('/opt/kaname-lab/source')
TARGET=Path('/opt/authwire-service-control')
UNIT=Path('/etc/systemd/system/authwire-service-control.service')
LOCK=Path('/run/kaname-lab-update.lock')
TMPFILES=Path('/etc/tmpfiles.d/authwire-service-control.conf')

def tmpfiles_text():return 'f /run/kaname-lab-update.lock 0600 root root -\n'

def unit_text():
    return '''[Unit]
Description=AuthWire restricted local service control
After=local-fs.target systemd-tmpfiles-setup.service

[Service]
Type=simple
User=root
Group=kaname-lab
ExecStart=/usr/bin/python3 -I -B /opt/authwire-service-control/broker.py
Restart=on-failure
RestartSec=3
TimeoutStopSec=70
RuntimeDirectory=authwire-service-control
RuntimeDirectoryMode=0750
StateDirectory=authwire-service-control
StateDirectoryMode=0700
UMask=0077
NoNewPrivileges=yes
PrivateTmp=yes
PrivateDevices=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=/run/authwire-service-control /var/lib/authwire-service-control
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectControlGroups=yes
ProtectKernelLogs=yes
ProtectClock=yes
ProtectHostname=yes
RestrictSUIDSGID=yes
RestrictNamespaces=yes
LockPersonality=yes
RestrictRealtime=yes
RestrictAddressFamilies=AF_UNIX AF_NETLINK
CapabilityBoundingSet=CAP_DAC_READ_SEARCH
SystemCallArchitectures=native

[Install]
WantedBy=multi-user.target
'''

def protected(path,directory=False):
    info=path.lstat()
    if (not (stat.S_ISDIR(info.st_mode) if directory else stat.S_ISREG(info.st_mode))
            or info.st_uid!=0 or info.st_mode & 0o022):
        raise ValueError('Trusted root-owned installed path required')

def command(*args):
    return subprocess.run(list(args),check=True,capture_output=True,text=True,timeout=80)

def pid():
    return command('systemctl','show','authwire-radius.service','--property=MainPID','--value').stdout.strip()

def digest(path):return hashlib.sha256(path.read_bytes()).hexdigest()

def control_state():
    p=SOURCE/'tools/linux_update.py';protected(p)
    namespace={'__name__':'verified_state_reader','__file__':str(p)}
    exec(compile(p.read_bytes(),str(p),'exec'),namespace)
    return namespace['control_digest'](Path('/var/lib/kaname-lab'))

def install():
    if sys.platform!='linux' or os.geteuid()!=0:raise ValueError('Local sudo required')
    import fcntl
    for p in (SOURCE,SOURCE/'tools',SOURCE/'kaname',SOURCE/'kaname/static',UNIT.parent):protected(p,True)
    for p in (SOURCE/'tools/service_control_broker.py',SOURCE/'kaname/services.py',SOURCE/'kaname/static/services.js'):protected(p)
    source=SOURCE/'tools/service_control_broker.py'
    compile(source.read_bytes(),str(source),'exec')
    descriptor=os.open(LOCK,os.O_CREAT|os.O_RDWR|os.O_NOFOLLOW,0o600)
    with os.fdopen(descriptor,'r+') as lock:
        protected(LOCK);fcntl.flock(lock,fcntl.LOCK_EX|fcntl.LOCK_NB)
        before_pid=pid();before=control_state()
        guarded=[Path('/etc/systemd/system/kaname-lab.service'),Path('/etc/systemd/system/authwire-radius.service'),
                 Path('/opt/authwire-radius/lib/rlm_python3.so'),SOURCE/'kaname/device_client/AuthWire-Client.ps1']
        hashes={str(p):digest(p) for p in guarded}
        backup=Path('/opt/kaname-lab/backups')/('service-control-'+uuid.uuid4().hex)
        protected(backup.parent,True);backup.mkdir(mode=0o700)
        existing_unit=UNIT.exists() or UNIT.is_symlink()
        existing_target=TARGET.exists() or TARGET.is_symlink()
        existing_tmpfiles=TMPFILES.exists() or TMPFILES.is_symlink()
        if existing_tmpfiles:
            protected(TMPFILES)
            if TMPFILES.read_text()!=tmpfiles_text():raise ValueError('Different existing lock setup; overwrite refused')
        if existing_unit:
            protected(UNIT)
            if UNIT.read_text()!=unit_text():raise ValueError('Different existing control unit; overwrite refused')
            shutil.copy2(UNIT,backup/'service.unit')
        if existing_target:
            protected(TARGET,True)
            if set(p.name for p in TARGET.iterdir())!={'broker.py'}:raise ValueError('Unexpected installed control files')
            protected(TARGET/'broker.py');shutil.copy2(TARGET/'broker.py',backup/'broker.py')
        was_enabled=subprocess.run(['systemctl','is-enabled','--quiet',UNIT.name],capture_output=True).returncode==0
        was_active=subprocess.run(['systemctl','is-active','--quiet',UNIT.name],capture_output=True).returncode==0
        try:
            TARGET.mkdir(mode=0o755,exist_ok=True)
            pending=TARGET/('broker-'+uuid.uuid4().hex+'.tmp')
            pending.write_bytes(source.read_bytes());pending.chmod(0o644);os.replace(pending,TARGET/'broker.py')
            if not existing_unit:UNIT.write_text(unit_text());UNIT.chmod(0o644)
            if not existing_tmpfiles:TMPFILES.write_text(tmpfiles_text());TMPFILES.chmod(0o644)
            command('systemd-tmpfiles','--create',str(TMPFILES))
            command('systemd-analyze','verify',str(UNIT))
            command('systemctl','daemon-reload')
            command('systemctl','restart' if existing_unit else 'start',UNIT.name)
            command('systemctl','enable',UNIT.name)
            socket_path=Path('/run/authwire-service-control/control.sock')
            deadline=time.monotonic()+10
            while not socket_path.exists() and time.monotonic()<deadline:time.sleep(.2)
            # Use the low-privilege client under the actual panel identity.
            result=command('/usr/sbin/runuser','-u','kaname-lab','--',
                '/opt/kaname-lab/venv/bin/python','-I','-B','-c',
                "import sys,json;sys.path.insert(0,'/opt/kaname-lab/source');from kaname.services import Services;v=Services().status();print(json.dumps({'available':v['available'],'services':len(v['services'])}))")
            check=json.loads(result.stdout)
            if check!={'available':True,'services':4}:raise ValueError('Low privilege service query failed')
            preserved=before==control_state() and all(digest(Path(p))==h for p,h in hashes.items())
            if not preserved or before_pid!=pid():raise ValueError('Protected state or RADIUS PID changed')
            os.sync()
            return {'installed':True,'broker_active':True,'query_as_panel_user':True,
                    'radius_process_preserved':True,'protected_state_preserved':True,
                    'panel_unit_changed':False,'radius_unit_changed':False,'service_actions_executed':False,
                    'backup_created':True,'broker_sha256':digest(TARGET/'broker.py')}
        except Exception:
            subprocess.run(['systemctl','stop',UNIT.name],capture_output=True,timeout=80)
            if existing_target:shutil.copy2(backup/'broker.py',TARGET/'broker.py')
            elif TARGET.exists():shutil.rmtree(TARGET)
            if not existing_unit:UNIT.unlink(missing_ok=True)
            if not existing_tmpfiles:TMPFILES.unlink(missing_ok=True)
            if not was_enabled:subprocess.run(['systemctl','disable',UNIT.name],capture_output=True,timeout=10)
            command('systemctl','daemon-reload')
            if existing_unit and was_active:command('systemctl','start',UNIT.name)
            raise

def main():
    try:print(json.dumps(install()))
    except Exception as error:
        print(json.dumps({'installed':False,'error':'SERVICE_CONTROL_INSTALL_FAILED','category':type(error).__name__}))
        raise SystemExit(1)

if __name__=='__main__':main()
