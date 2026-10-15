"""Guarded deployment checkpoint; no customer RADIUS action is executed."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys

STAGE=Path('/home/kaname-runner/kaname-stage-3eaa628ae5ea')
EXPECTED='dcf0957a545bf526c999cf849033868e9e32271a080d5e00004261d9b32ce3c4'
ROOT=Path('/opt/kaname-lab/source')
PHASE='preflight'

def hash_file(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def trusted(path):
    if path.is_symlink() or not path.is_file() or path.stat().st_uid!=0 or path.stat().st_mode & 0o022:
        raise ValueError('Trusted installed code required')
    return path.read_bytes()
def load_installed(path):
    data=trusted(path)
    space={'__name__':'guarded_installed_code','__file__':str(path)}
    exec(compile(data,str(path),'exec'),space)
    return space
def radius_pid():
    return subprocess.check_output(['/usr/bin/systemctl','show','authwire-radius.service','--property=MainPID','--value'],text=True).strip()

def main():
    global PHASE
    if os.geteuid()!=0:raise ValueError('Local sudo required')
    updater=load_installed(ROOT/'tools/linux_update.py')
    verified=updater['verified_files'](STAGE,EXPECTED)
    protected_names=[
      'kaname/device_client/AuthWire-Client.ps1','kaname/device_client/Install-AuthWire.ps1',
      'kaname/device_auth.py','kaname/device_enrollment.py','kaname/enrollment.py',
      'kaname/directory.py','kaname/directory_linux.py','kaname/directory_linux_helper.py',
      'kaname/directory_sync.py','kaname/membership.py','kaname/models.py','kaname/operations.py',
      'kaname/pki.py','kaname/policy.py','kaname/radius.py','kaname/radius_adapter.py',
      'kaname/radius_directory.py','kaname/radius_registry.py','kaname/store.py','kaname/vault.py']
    for name in protected_names:
        if trusted(ROOT/name)!=verified[name]:raise ValueError('Protected authentication source differs')
    if hash_file(ROOT/'kaname/device_client/AuthWire-Client.ps1')!='86081b41e7072c055cf3a0364f688914b5f66def91ab44273cdcea50e26f5b15':
        raise ValueError('Signed Windows source mismatch')
    files=[Path('/etc/systemd/system/kaname-lab.service'),Path('/etc/systemd/system/authwire-radius.service'),
      Path('/opt/authwire-radius/lib/rlm_python3.so'),Path('/etc/kaname-lab/web.crt'),Path('/etc/kaname-lab/web.key'),
      Path('/var/lib/kaname-lab/secret-store.key'),Path('/var/lib/kaname-lab/radius/server.pem'),
      Path('/var/lib/kaname-lab/radius/server-key.pem')]
    before={str(p):hash_file(p) for p in files}
    before_pid=radius_pid()
    if before_pid in ('','0'):raise ValueError('Existing active pilot RADIUS required')
    print(json.dumps({'event':'SERVICES_PREFLIGHT','protected_authentication_source_identical':True,
                      'radius_active':True,'radius_pid':before_pid}),flush=True)
    PHASE='current_data_backup'
    checkpoint=Path('/home/segmentiq/authwire-pause-backup-20261015.py')
    data=checkpoint.read_bytes()
    if hashlib.sha256(data).hexdigest()!='f3defafe3faed08d5cae48b982f74217c8a24a15107c25ced267a26a84958f43':
        raise ValueError('Prepared backup source changed')
    backup={'__name__':'guarded_data_backup','__file__':str(checkpoint)}
    exec(compile(data,str(checkpoint),'exec'),backup)
    backup['main']()
    PHASE='source_update'
    same=all((ROOT/name).is_file() and not (ROOT/name).is_symlink()
             and (ROOT/name).read_bytes()==content for name,content in verified.items())
    if same:
        print(json.dumps({'event':'SERVICES_SOURCE_UPDATED','already_current':True}),flush=True)
    else:
        update=updater['update'](STAGE,EXPECTED)
        print(json.dumps({'event':'SERVICES_SOURCE_UPDATED',**update}),flush=True)
    PHASE='service_control_install'
    installed=load_installed(ROOT/'tools/service_control_install.py')['install']()
    print(json.dumps({'event':'SERVICES_CONTROL_INSTALLED',**installed}),flush=True)
    PHASE='preservation_after'
    if before_pid!=radius_pid():raise ValueError('RADIUS process changed')
    if any(hash_file(Path(p))!=h for p,h in before.items()):raise ValueError('Protected file changed')
    for name in protected_names:
        if trusted(ROOT/name)!=verified[name]:raise ValueError('Protected authentication source changed')
    os.sync()
    print(json.dumps({'event':'SERVICES_DEPLOY_FINISHED','verified':True,'version':'0.14.0-dev.5',
                      'data_backup_created':True,'radius_process_preserved':True,'protected_authentication_source_preserved':True,
                      'protected_files_preserved':True,'service_actions_executed':False,
                      'windows_changed':False,'next':'Open System Services and inspect status before a controlled action'}),flush=True)

if __name__=='__main__':
    try:main()
    except Exception as error:
        print(json.dumps({'event':'SERVICES_DEPLOY_FAILED','phase':PHASE,'category':type(error).__name__, 'detail':str(error)[:180] if isinstance(error,(ValueError,RuntimeError)) else ''}),flush=True)
        raise SystemExit(1)
