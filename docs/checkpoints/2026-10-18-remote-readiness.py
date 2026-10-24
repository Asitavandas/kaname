"""Live read checks + fresh private backup + isolated data-restore rehearsal."""
from contextlib import redirect_stdout
import hashlib
import http.client
import io
import json
import os
from pathlib import Path
import sqlite3
import ssl
import statistics
import subprocess
import time

STATE=Path('/var/lib/kaname-lab')
PHASE='preflight'
TOOL=Path('/home/segmentiq/authwire-offline-restore-check-20261018.py')
TOOL_SHA='8d887e14588d8f9b5fe1b164678aef0feb24fd5b2288ffcec1d6da4d062ceab5'


def emit(event,**values):print(json.dumps({'event':event,**values}),flush=True)
def sha(path):return hashlib.sha256(Path(path).read_bytes()).hexdigest()
def read_ns(path,expected):
    data=path.read_bytes()
    if hashlib.sha256(data).hexdigest()!=expected:raise ValueError('Prepared checker source mismatch')
    ns={'__name__':'guarded_offline_checker','__file__':str(path)};exec(compile(data,str(path),'exec'),ns);return ns

def protected():
    names=['/etc/systemd/system/kaname-lab.service','/etc/systemd/system/authwire-radius.service',
       '/etc/systemd/system/authwire-service-control.service','/opt/authwire-service-control/broker.py',
       '/opt/authwire-radius/lib/rlm_python3.so','/etc/kaname-lab/web.crt','/etc/kaname-lab/web.key',
       '/var/lib/kaname-lab/secret-store.key','/var/lib/kaname-lab/radius/server.pem',
       '/var/lib/kaname-lab/radius/server-key.pem','/opt/kaname-lab/source/kaname/device_client/AuthWire-Client.ps1',
       '/opt/kaname-lab/source/kaname/device_client/Install-AuthWire.ps1']
    pids={}
    for unit in ('kaname-lab.service','authwire-radius.service','authwire-service-control.service'):
        subprocess.run(['/usr/bin/systemctl','is-active','--quiet',unit],check=True,timeout=10)
        pids[unit]=subprocess.check_output(['/usr/bin/systemctl','show',unit,'--property=MainPID','--value'],text=True,timeout=10).strip()
        if pids[unit] in ('','0'):raise ValueError('Active service PID required')
    values={}
    for dbname,queries in [('kaname.sqlite3',['SELECT * FROM state ORDER BY id',"SELECT name,payload FROM runtime_settings WHERE name<>'directory_health' ORDER BY name",'SELECT * FROM protected_secrets ORDER BY name','SELECT root_cert,root_key,issuer_cert,issuer_key FROM pki_authority ORDER BY id']),('administrators.sqlite3',['SELECT * FROM admin_users ORDER BY id','SELECT * FROM admin_profiles ORDER BY id'])]:
        db=sqlite3.connect((STATE/dbname).as_uri()+'?mode=ro',uri=True,timeout=3)
        try:
            for index,q in enumerate(queries):values[dbname+':'+str(index)]=hashlib.sha256(repr(db.execute(q).fetchall()).encode()).hexdigest()
        finally:db.close()
    return {'files':{p:sha(p) for p in names},'pids':pids,'control':values}


def panel_reads():
    token=(STATE/'access-token').read_text().strip()
    context=ssl.create_default_context(cafile='/etc/kaname-lab/web.crt');results=[]
    for path in ('/api/auth/session','/api/state','/api/pki/certificates?offset=0','/api/network','/api/services'):
        codes=[];times=[]
        for _ in range(3):
            c=http.client.HTTPSConnection('10.35.50.246',8765,timeout=15,context=context,source_address=('127.0.0.1',0));start=time.monotonic()
            try:
                c.request('GET',path,headers={'Authorization':'Bearer '+token});r=c.getresponse();r.read();codes.append(r.status)
            finally:c.close()
            times.append(round((time.monotonic()-start)*1000,1))
        results.append({'path':path,'statuses':codes,'median_ms':statistics.median(times),'max_ms':max(times)})
    emit('LIVE_PANEL_READ_CHECK',results=results,authenticated=True,loopback=True)
    if any(code!=200 for r in results for code in r['statuses']):raise ValueError('Live panel read check failed')


def vv06_retirement_readonly():
    from contextlib import closing
    from datetime import datetime,timezone
    from cryptography import x509
    old='6fc12360e627e5b92b0d60ab103def6cb40fe624'
    new='5899e122009871b0d5536890bee81e4f0499e605'
    guid='69b0d5cd-db61-4627-9db7-fcc5230152a3'
    with closing(sqlite3.connect((STATE/'kaname.sqlite3').as_uri()+'?mode=ro',uri=True,timeout=3)) as db:
        records={row[0]:row[1:] for row in db.execute(
            'SELECT c.serial,c.revoked_at,c.reason,r.retire_at,d.installed_at FROM pki_certificates c JOIN radius_certificate_bindings b ON b.serial=c.serial LEFT JOIN device_retirements r ON r.serial=c.serial LEFT JOIN device_issuances d ON d.serial=c.serial WHERE b.object_guid=? AND c.serial IN (?,?)',(guid,old,new))}
        issuer=x509.load_pem_x509_certificate(db.execute('SELECT issuer_cert FROM pki_authority WHERE id=1').fetchone()[0])
        stored=db.execute('SELECT crl FROM pki_authority WHERE id=1').fetchone()[0]
    runtime=Path('/run/authwire-radius/ca/issuer-crl.pem').read_bytes()
    crl=x509.load_pem_x509_crl(runtime);now=datetime.now(timezone.utc)
    old_row=records.get(old);new_row=records.get(new)
    proof={'old_registry_revoked':bool(old_row and old_row[0]),'old_registry_reason':old_row[1] if old_row and old_row[1] in ('superseded','cessation_of_operation','key_compromise') else None,
      'old_retire_deadline':old_row[2] if old_row else None,'old_in_runtime_crl':crl.get_revoked_certificate_by_serial_number(int(old,16)) is not None,
      'new_registry_not_revoked':bool(new_row and not new_row[0]),'new_absent_from_runtime_crl':crl.get_revoked_certificate_by_serial_number(int(new,16)) is None,
      'runtime_crl_signature_valid':crl.is_signature_valid(issuer.public_key()),'runtime_crl_current':crl.last_update_utc<=now<crl.next_update_utc,
      'database_runtime_crl_identical':hashlib.sha256(stored).digest()==hashlib.sha256(runtime).digest()}
    deadline_ok=False;revocation_after_deadline=False;grace_seconds=None
    if old_row and new_row and old_row[0] and old_row[2] and new_row[3]:
        deadline=datetime.fromisoformat(old_row[2]);installed=datetime.fromisoformat(new_row[3]);revoked=datetime.fromisoformat(old_row[0])
        if all(v.tzinfo is not None for v in (deadline,installed,revoked)):
            grace_seconds=(deadline-installed).total_seconds()
            deadline_ok=0<=grace_seconds<=86400 and deadline<=now
            revocation_after_deadline=revoked>=deadline
    proof.update(old_revoked_at=old_row[0] if old_row else None,planned_grace_seconds=grace_seconds,deadline_within_24h=deadline_ok,revocation_after_deadline=revocation_after_deadline)
    complete=deadline_ok and revocation_after_deadline and all(proof[k] for k in ('old_registry_revoked','old_in_runtime_crl','new_registry_not_revoked','new_absent_from_runtime_crl','runtime_crl_signature_valid','runtime_crl_current','database_runtime_crl_identical')) and proof['old_registry_reason']=='superseded'
    emit('VV06_SERVER_RETIREMENT_READONLY',**proof,server_retirement_verified=complete,windows_local_cleanup_verified=False,eap_selected_leaf_verified=False)


def main():
    global PHASE
    if os.geteuid()!=0:raise ValueError('Local sudo required')
    tool=read_ns(TOOL,TOOL_SHA)
    before=protected();PHASE='live_panel_reads';panel_reads()
    PHASE='vv06_server_retirement_readonly';vv06_retirement_readonly()
    PHASE='fresh_backup'
    backup=read_ns(Path('/home/segmentiq/authwire-pause-backup-20261015.py'),'f3defafe3faed08d5cae48b982f74217c8a24a15107c25ced267a26a84958f43')
    backup['ROOTS'] += [Path('/opt/authwire-service-control'),Path('/var/lib/authwire-service-control')]
    backup['UNIT_NAMES'].append('authwire-service-control.service')
    output=io.StringIO();old_mask=os.umask(0o077)
    try:
        with redirect_stdout(output):backup['main']()
    finally:os.umask(old_mask)
    record=json.loads(output.getvalue().strip())
    if record.get('event')!='PAUSE_BACKUP_CREATED' or not record.get('live_state_stable') or not record.get('radius_process_preserved'):raise ValueError('Fresh backup proof missing')
    print(json.dumps(record),flush=True)
    baseline=Path(record['backup']+'.rehearsal-before.json')
    fd=os.open(baseline,os.O_WRONLY|os.O_CREAT|os.O_EXCL|os.O_NOFOLLOW,0o600)
    with os.fdopen(fd,'w') as f:json.dump(before,f,indent=2);f.write('\n');f.flush();os.fsync(f.fileno())
    PHASE='isolated_restore'
    result=tool['check'](Path(record['backup']),record['sha256'],Path('/var/lib/authwire-restore-checks'))
    PHASE='preservation'
    after=protected()
    emit('REMOTE_PRESERVATION_CHECK',file_checks={p:before['files'][p]==after['files'].get(p) for p in before['files']},process_checks={p:before['pids'][p]==after['pids'].get(p) for p in before['pids']},control_checks={p:before['control'][p]==after['control'].get(p) for p in before['control']})
    if before!=after:raise ValueError('Live protected state or service process changed')
    evidence=Path(record['backup']+'.restore-check.json')
    fd=os.open(evidence,os.O_WRONLY|os.O_CREAT|os.O_EXCL|os.O_NOFOLLOW,0o600)
    with os.fdopen(fd,'w') as f:json.dump({'backup':record['backup'],**result,'live_protected_state_preserved':True,'service_processes_preserved':True},f,indent=2);f.write('\n');f.flush();os.fsync(f.fileno())
    emit('OFFLINE_DATA_RESTORE_VERIFIED',**result,live_protected_state_preserved=True,
         service_processes_preserved=True,evidence=str(evidence),gpo_audit_pending=True,
         operator_browser_acceptance_pending=True)

if __name__=='__main__':
    try:main()
    except Exception as error:
        emit('REMOTE_CHECK_FAILED',phase=PHASE,category=type(error).__name__,
             sqlite_code=getattr(error,'sqlite_errorcode',None) if isinstance(error,sqlite3.Error) else None)
        raise SystemExit(1)
