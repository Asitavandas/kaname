"""Guarded panel-only update; fixed-label read checks and protected-state proof."""
from contextlib import contextmanager
import hashlib
import http.client
import json
import os
from pathlib import Path
import sqlite3
import ssl
import statistics
import subprocess
import time

STAGE=Path('/home/kaname-runner/kaname-stage-40d69fff4c84')
EXPECTED='0679cb615cfc05179363a28807c208f0235efdb14d08b616d0517e2b862accee'
ROOT=Path('/opt/kaname-lab/source')
STATE=Path('/var/lib/kaname-lab')
PHASE='preflight'
UPDATER={}

@contextmanager
def file_creation_mask(mask):
    previous=os.umask(mask)
    try:yield
    finally:os.umask(previous)

def emit(event,**values):print(json.dumps({'event':event,**values}),flush=True)
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def trusted(path):
    if path.is_symlink() or not path.is_file() or path.stat().st_uid!=0 or path.stat().st_mode & 0o022:
        raise ValueError('Trusted root-owned installed code required')
    return path.read_bytes()
def load_installed(path):
    data=trusted(path)
    namespace={'__name__':'guarded_installed_code','__file__':str(path)}
    exec(compile(data,str(path),'exec'),namespace)
    return namespace

def service_pids():
    result={}
    for unit in ('authwire-radius.service','authwire-service-control.service'):
        subprocess.run(['/usr/bin/systemctl','is-active','--quiet',unit],check=True,timeout=10)
        value=subprocess.check_output(['/usr/bin/systemctl','show',unit,'--property=MainPID','--value'],text=True,timeout=10).strip()
        if not value.isdecimal() or int(value)==0:raise ValueError('Existing active pilot service required')
        result[unit]=value
    return result

def preservation(updater):
    paths=['/etc/systemd/system/kaname-lab.service','/etc/systemd/system/authwire-radius.service',
      '/etc/systemd/system/authwire-service-control.service','/opt/authwire-service-control/broker.py',
      '/opt/authwire-radius/lib/rlm_python3.so','/etc/kaname-lab/web.crt','/etc/kaname-lab/web.key',
      '/var/lib/kaname-lab/secret-store.key','/var/lib/kaname-lab/radius/server.pem',
      '/var/lib/kaname-lab/radius/server-key.pem']
    return {'files':{p:sha(Path(p)) for p in paths},'pids':service_pids(),
            'control_state':updater['control_digest'](STATE)}

def database_checks():
    result=[]
    for name in ('kaname.sqlite3','administrators.sqlite3'):
        with sqlite3.connect((STATE/name).as_uri()+'?mode=ro',uri=True,timeout=3) as db:
            ok=all(row[0]=='ok' for row in db.execute('PRAGMA quick_check'))
            mode=db.execute('PRAGMA journal_mode').fetchone()[0]
        result.append({'database':name,'quick_check_ok':ok,'journal_mode':mode})
        if not ok:raise ValueError('Database integrity check failed; update refused')
    emit('PANEL_DATABASE_CHECK',results=result)

def measure(label):
    token=(STATE/'access-token').read_text().strip()
    context=ssl.create_default_context(cafile='/etc/kaname-lab/web.crt')
    results=[]
    for path in ('/api/auth/session','/api/state','/api/pki/certificates?offset=0',
                 '/api/device-admin/status?offset=0','/api/network','/api/services'):
        codes=[];times=[]
        for attempt in range(3):
            connection=http.client.HTTPSConnection('10.35.50.246',8765,context=context,timeout=20,source_address=('127.0.0.1',0))
            started=time.monotonic()
            try:
                connection.request('GET',path,headers={'Authorization':'Bearer '+token})
                response=connection.getresponse();response.read();codes.append(response.status)
            finally:connection.close()
            times.append(round((time.monotonic()-started)*1000,1))
        results.append({'path':path,'statuses':codes,'median_ms':statistics.median(times),'max_ms':max(times)})
    emit('PANEL_READ_CHECK',phase=label,authenticated=True,loopback=True,results=results)
    return all(code==200 for row in results for code in row['statuses'])

def main():
    global PHASE,UPDATER
    if os.geteuid()!=0:raise ValueError('Local sudo required')
    UPDATER=load_installed(ROOT/'tools/linux_update.py')
    files=UPDATER['verified_files'](STAGE,EXPECTED)
    allowed={'kaname/admin.py','kaname/server.py','kaname/__init__.py'}
    protected=[name for name in files if name.startswith('kaname/') and not name.startswith('kaname/static/') and name not in allowed]
    for name in protected:
        if trusted(ROOT/name)!=files[name]:raise ValueError('Protected authentication source differs')
    if sha(ROOT/'kaname/device_client/AuthWire-Client.ps1')!='86081b41e7072c055cf3a0364f688914b5f66def91ab44273cdcea50e26f5b15':
        raise ValueError('Signed Windows client mismatch')
    before=preservation(UPDATER)
    database_checks()
    emit('PANEL_PREFLIGHT',protected_authentication_source_identical=True,radius_active=True,service_pids=before['pids'])
    PHASE='baseline_read_checks'
    measure('before')
    PHASE='fresh_data_backup'
    checkpoint=Path('/home/segmentiq/authwire-pause-backup-20261015.py')
    data=checkpoint.read_bytes()
    if hashlib.sha256(data).hexdigest()!='f3defafe3faed08d5cae48b982f74217c8a24a15107c25ced267a26a84958f43':
        raise ValueError('Prepared backup source changed')
    namespace={'__name__':'guarded_data_backup','__file__':str(checkpoint)}
    exec(compile(data,str(checkpoint),'exec'),namespace)
    namespace['ROOTS'] += [Path('/opt/authwire-service-control'),Path('/var/lib/authwire-service-control')]
    namespace['UNIT_NAMES'].append('authwire-service-control.service')
    with file_creation_mask(0o077):namespace['main']()
    PHASE='panel_source_update'
    same=all((ROOT/name).is_file() and not (ROOT/name).is_symlink() and (ROOT/name).read_bytes()==data for name,data in files.items())
    with file_creation_mask(0o022):
        updated={'already_current':True} if same else UPDATER['update'](STAGE,EXPECTED)
    emit('PANEL_UPDATED',**updated)
    PHASE='preservation_after'
    after=preservation(UPDATER)
    if before!=after:raise ValueError('Protected file/state or pilot process changed')
    if any(trusted(ROOT/name)!=files[name] for name in protected):raise ValueError('Protected authentication source changed')
    PHASE='panel_read_checks_after'
    if not measure('after'):raise ValueError('Panel read acceptance failed; protected state retained')
    os.sync()
    emit('PANEL_DEPLOY_FINISHED',verified=True,version='0.14.0-dev.6',radius_process_preserved=True,
         service_broker_process_preserved=True,protected_authentication_source_preserved=True,
         protected_state_preserved=True,windows_changed=False,database_settings_changed=False,
         new_session_idle_seconds=7200,new_session_absolute_seconds=43200,
         historical_storage_error_cause='not_retroactively_provable',operator_reload_observation_pending=True)

if __name__=='__main__':
    try:main()
    except Exception as error:
        emit('PANEL_DEPLOY_FAILED',phase=PHASE,category=type(error).__name__,
             updater_stage=UPDATER.get('_PHASE') if PHASE=='panel_source_update' else None,
             sqlite_code=getattr(error,'sqlite_errorcode',None) if isinstance(error,sqlite3.Error) else None,
             failed_program=Path(str(error.cmd[0])).name if isinstance(error,subprocess.CalledProcessError) and isinstance(error.cmd,(list,tuple)) and error.cmd else None,
             exit_code=error.returncode if isinstance(error,subprocess.CalledProcessError) else None)
        raise SystemExit(1)
