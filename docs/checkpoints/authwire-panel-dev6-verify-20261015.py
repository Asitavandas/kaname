"""Verify an already installed panel against the pinned pre-update checkpoint.
No service, source, configuration, session or certificate mutation is performed.
"""
from contextlib import closing
import hashlib
import http.client
import json
import os
from pathlib import Path
import sqlite3
import ssl
import statistics
import subprocess
import tarfile
import tempfile
import time

BACKUP=Path('/var/backups/authwire/authwire-pause-20261015T195441Z.tar.gz')
BACKUP_SHA='e40a7739e650f1dd7c4cfac001a6b903931fc58b415d2a3e53a7ea042db7bb47'
ROOT=Path('/opt/kaname-lab/source')
STATE=Path('/var/lib/kaname-lab')
STAGE=Path('/home/kaname-runner/kaname-stage-40d69fff4c84')
MANIFEST_SHA='0679cb615cfc05179363a28807c208f0235efdb14d08b616d0517e2b862accee'
PHASE='preflight'


def emit(event,**values):print(json.dumps({'event':event,**values}),flush=True)
def digest_bytes(data):return hashlib.sha256(data).hexdigest()
def digest_file(path):
    h=hashlib.sha256()
    with path.open('rb') as f:
        for data in iter(lambda:f.read(1024*1024),b''):h.update(data)
    return h.hexdigest()

def member_bytes(archive,name,limit):
    rows=[m for m in archive.getmembers() if m.name==name]
    if len(rows)!=1 or not rows[0].isfile() or not 0<=rows[0].size<=limit:
        raise ValueError('Expected bounded regular checkpoint member missing')
    with archive.extractfile(rows[0]) as f:data=f.read(limit+1)
    if len(data)!=rows[0].size:raise ValueError('Checkpoint member length mismatch')
    return data

def rows(db,table,columns='*'):
    # Every identifier comes from fixed code below, never from operator input.
    if db.execute("SELECT 1 FROM sqlite_master WHERE type='table' AND name=?",(table,)).fetchone() is None:
        return None
    return db.execute('SELECT '+columns+' FROM '+table+' ORDER BY 1').fetchall()

def compare_databases(old_main,new_main,old_admin,new_admin):
    checks={}
    for label,table,columns in (
      ('configuration_and_policies','state','*'),('protected_secrets','protected_secrets','*'),
      ('ca_material','pki_authority','root_cert,root_key,issuer_cert,issuer_key'),
      ('certificate_registry','pki_certificates','*'),('enrollment_signer','device_signer','*'),
      ('enrollment_profiles','device_profiles','*'),('certificate_bindings','radius_certificate_bindings','*'),
      ('client_key_registry','pki_client_keys','*')):
        previous=rows(old_main,table,columns)
        checks[label]=previous is not None and previous==rows(new_main,table,columns)
    checks['administrator_users']=rows(old_admin,'admin_users') is not None and rows(old_admin,'admin_users')==rows(new_admin,'admin_users')
    checks['administrator_profiles']=rows(old_admin,'admin_profiles') is not None and rows(old_admin,'admin_profiles')==rows(new_admin,'admin_profiles')
    old=dict(rows(old_main,'runtime_settings') or [])
    new=dict(rows(new_main,'runtime_settings') or [])
    old_health=json.loads(old.pop('directory_health','null'))
    new_health=json.loads(new.pop('directory_health','null'))
    checks['runtime_configuration']=old==new
    health_changed=old_health!=new_health
    allowed={'state','error','checked_at','last_success'}
    bounded=all(v is None or type(v) is dict and set(v)<=allowed for v in (old_health,new_health))
    checks['directory_health_shape']=bounded and (old_health is None)==(new_health is None)
    fields=[k for k in sorted(allowed) if (old_health or {}).get(k)!=(new_health or {}).get(k)] if bounded else []
    return checks,{'changed':health_changed,'changed_fields':fields,
                   'timestamps_only':health_changed and set(fields)<={'checked_at','last_success'}}

def api_checks():
    token=(STATE/'access-token').read_text().strip()
    context=ssl.create_default_context(cafile='/etc/kaname-lab/web.crt')
    results=[]
    for path in ('/api/auth/session','/api/state','/api/pki/certificates?offset=0','/api/network','/api/services'):
        codes=[];times=[]
        for _ in range(3):
            c=http.client.HTTPSConnection('10.35.50.246',8765,timeout=20,context=context,source_address=('127.0.0.1',0))
            started=time.monotonic()
            try:
                c.request('GET',path,headers={'Authorization':'Bearer '+token});r=c.getresponse();r.read();codes.append(r.status)
            finally:c.close()
            times.append(round((time.monotonic()-started)*1000,1))
        results.append({'path':path,'statuses':codes,'median_ms':statistics.median(times),'max_ms':max(times)})
    emit('PANEL_API_AFTER',authenticated=True,loopback=True,results=results)
    return all(code==200 for item in results for code in item['statuses'])

def main():
    global PHASE
    if os.geteuid()!=0:raise ValueError('Local sudo required')
    pids={}
    for unit,expected in [('authwire-radius.service','1274'),('authwire-service-control.service','149955')]:
        subprocess.run(['/usr/bin/systemctl','is-active','--quiet',unit],check=True,timeout=10)
        pids[unit]=subprocess.check_output(['/usr/bin/systemctl','show',unit,'--property=MainPID','--value'],text=True,timeout=10).strip()==expected
    PHASE='backup_integrity'
    if digest_file(BACKUP)!=BACKUP_SHA:raise ValueError('Pinned checkpoint archive mismatch')
    paths=['/etc/systemd/system/kaname-lab.service','/etc/systemd/system/authwire-radius.service',
      '/etc/systemd/system/authwire-service-control.service','/opt/authwire-service-control/broker.py',
      '/opt/authwire-radius/lib/rlm_python3.so','/etc/kaname-lab/web.crt','/etc/kaname-lab/web.key',
      '/var/lib/kaname-lab/secret-store.key','/var/lib/kaname-lab/radius/server.pem','/var/lib/kaname-lab/radius/server-key.pem',
      '/opt/kaname-lab/source/kaname/device_client/AuthWire-Client.ps1',
      '/opt/kaname-lab/source/kaname/device_client/Install-AuthWire.ps1']
    PHASE='backup_comparison'
    with tempfile.TemporaryDirectory(prefix='authwire-readonly-verify-') as temp:
        work=Path(temp);work.chmod(0o700)
        with tarfile.open(BACKUP,'r:gz') as archive:
            files={p:digest_bytes(member_bytes(archive,p.lstrip('/'),32*1024*1024))==digest_file(Path(p)) for p in paths}
            copies=[]
            for name in ('kaname.sqlite3','administrators.sqlite3'):
                target=work/name
                fd=os.open(target,os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o600)
                with os.fdopen(fd,'wb') as f:f.write(member_bytes(archive,'var/lib/kaname-lab/'+name,128*1024*1024))
                copies.append(target)
        with closing(sqlite3.connect(copies[0].as_uri()+'?mode=ro',uri=True,timeout=3)) as old_main, \
             closing(sqlite3.connect((STATE/'kaname.sqlite3').as_uri()+'?mode=ro',uri=True,timeout=3)) as new_main, \
             closing(sqlite3.connect(copies[1].as_uri()+'?mode=ro',uri=True,timeout=3)) as old_admin, \
             closing(sqlite3.connect((STATE/'administrators.sqlite3').as_uri()+'?mode=ro',uri=True,timeout=3)) as new_admin:
            integrity=all(all(row[0]=='ok' for row in db.execute('PRAGMA quick_check')) for db in (old_main,new_main,old_admin,new_admin))
            checks,health=compare_databases(old_main,new_main,old_admin,new_admin)
    emit('PANEL_BACKUP_COMPARISON',backup_verified=True,sqlite_integrity_verified=integrity,
         protected_files=files,protected_state=checks,processes_preserved=pids,directory_health=health)
    if not integrity or not all(files.values()) or not all(checks.values()) or not all(pids.values()):
        raise ValueError('A protected difference remains; no changes performed')
    PHASE='installed_source'
    manifest=(STAGE/'LINUX_SOURCE_MANIFEST.json').read_bytes()
    if digest_bytes(manifest)!=MANIFEST_SHA:raise ValueError('Tested manifest mismatch')
    for name,expected in json.loads(manifest)['files'].items():
        if digest_file(ROOT/name)!=expected:raise ValueError('Installed source differs from tested dev6')
    PHASE='api_checks'
    if not api_checks():raise ValueError('Panel read acceptance failed')
    for unit,expected in [('authwire-radius.service','1274'),('authwire-service-control.service','149955')]:
        current=subprocess.check_output(['/usr/bin/systemctl','show',unit,'--property=MainPID','--value'],text=True,timeout=10).strip()
        if current!=expected:raise ValueError('Pilot process changed during verification')
    emit('PANEL_VERIFICATION_FINISHED',verified=True,version='0.14.0-dev.6',
         protected_state_preserved=True,radius_process_preserved=True,broker_process_preserved=True,
         installed_source_matches_tested_release=True,directory_health_changed=health['changed'],
         services_restarted=False,configuration_changed=False,certificates_changed=False,
         original_preflight_snapshot_persisted=False,baseline='pinned full checkpoint immediately before source update',
         operator_reload_observation_pending=True)

if __name__=='__main__':
    try:main()
    except Exception as error:
        emit('PANEL_VERIFICATION_FAILED',phase=PHASE,category=type(error).__name__,
             sqlite_code=getattr(error,'sqlite_errorcode',None) if isinstance(error,sqlite3.Error) else None)
        raise SystemExit(1)
