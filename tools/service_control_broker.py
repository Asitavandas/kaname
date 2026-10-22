"""Fixed-scope local systemd broker. No shell, package imports or caller paths."""
import datetime
from contextlib import contextmanager
import json
import ipaddress
import os
from pathlib import Path
import re
import socket
import socketserver
import stat
import struct
import subprocess
import threading
import time
import uuid

SOCKET = Path('/run/authwire-service-control/control.sock')
HISTORY = Path('/var/lib/authwire-service-control/operations.json')
UNITS = {'radius':'authwire-radius.service', 'panel':'kaname-lab.service',
         'crl-sync':'authwire-radius-crl-sync.service',
         'crl-timer':'authwire-radius-crl-sync.timer'}
ACTIONS = {'radius':('start','stop','restart'), 'panel':(),
           'crl-sync':('sync',), 'crl-timer':('start','stop')}
PROPERTIES = ('Id','LoadState','ActiveState','SubState','UnitFileState','MainPID',
              'Result','ExecMainStatus','MemoryCurrent','CPUUsageNSec','TasksCurrent',
              'ActiveEnterTimestampMonotonic','NextElapseUSecRealtime','LastTriggerUSec')

def now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()

class ControlError(Exception):
    def __init__(self, code):
        self.code = code
        super().__init__(code)

def execute(arguments, timeout=5):
    return subprocess.run(arguments, capture_output=True, text=True, timeout=timeout,
                          env={'PATH':'/usr/sbin:/usr/bin','LC_ALL':'C'}, check=False)

def number(value):
    try:
        n=int(value)
        return n if 0 <= n < 2**63 else None
    except (TypeError, ValueError):
        return None

def properties(output):
    return dict(line.split('=',1) for line in output.splitlines() if '=' in line)

def validate_action(value):
    if type(value) is not dict or set(value) != {'kind','service','action','request_id','actor'}:
        raise ControlError('INVALID_INPUT')
    service, action = value['service'], value['action']
    if type(service) is not str or type(action) is not str or action not in ACTIONS.get(service, ()):
        raise ControlError('ACTION_NOT_ALLOWED')
    if type(value['request_id']) is not str:
        raise ControlError('INVALID_INPUT')
    try:
        if str(uuid.UUID(value['request_id'])) != value['request_id']:
            raise ValueError()
    except ValueError:
        raise ControlError('INVALID_INPUT') from None
    actor=value['actor']
    if type(actor) is not str or not re.fullmatch(r'[\w.@-]{1,64}', actor):
        raise ControlError('INVALID_INPUT')
    return service, action

def boot_identity():
    try:
        value=Path('/proc/sys/kernel/random/boot_id').read_text().strip()
        return value if str(uuid.UUID(value))==value else None
    except (OSError,ValueError):return None

def validate_power_action(value):
    if type(value) is not dict or set(value)!={'kind','action','request_id','actor'} or value.get('kind')!='power-action':
        raise ControlError('INVALID_INPUT')
    if type(value['action']) is not str or value['action'] not in {'reboot','poweroff'}:
        raise ControlError('ACTION_NOT_ALLOWED')
    validate_action({'kind':'action','service':'radius','action':'restart','request_id':value['request_id'],'actor':value['actor']})
    return 'system',value['action']

class Controller:
    def __init__(self, history=HISTORY, runner=execute, update_lock=Path('/run/kaname-lab-update.lock'),
                 runtime_site=Path('/run/authwire-radius/sites-enabled/authwire')):
        self.history=Path(history); self.runner=runner
        self.update_lock=update_lock
        self.runtime_site=Path(runtime_site)
        self.lock=threading.Lock(); self.snapshot_lock=threading.Lock()
        self.jobs=[]; self.busy=False; self.cached=None; self.cached_at=0
        self.boot_id=boot_identity()
        if self.history.exists():
            if self.history.is_symlink() or self.history.stat().st_size > 262144:
                raise ControlError('HISTORY_INVALID')
            self.jobs=json.loads(self.history.read_text())
            if type(self.jobs) is not list or len(self.jobs)>100:
                raise ControlError('HISTORY_INVALID')
            # Never replay a command after broker restart. Its outcome may be unknown.
            for job in self.jobs:
                if job.get('service')=='system' and job['state']=='scheduled' and self.boot_id and job.get('boot_id') and job['boot_id']!=self.boot_id:
                    job.update(state='boot-observed',finished_at=now())
                if job['state'] in {'queued','running'}:
                    job.update(state='interrupted',error='OUTCOME_UNKNOWN',finished_at=now())
            self.save()

    def save(self):
        temp=self.history.with_suffix('.'+uuid.uuid4().hex+'.tmp')
        fd=os.open(temp,os.O_CREAT|os.O_EXCL|os.O_WRONLY|os.O_NOFOLLOW,0o600)
        try:
            with os.fdopen(fd,'w') as f:
                json.dump(self.jobs,f,ensure_ascii=True); f.flush(); os.fsync(f.fileno())
            os.replace(temp,self.history)
            directory=os.open(self.history.parent,os.O_RDONLY|os.O_DIRECTORY)
            try: os.fsync(directory)
            finally: os.close(directory)
        finally:
            if temp.exists(): temp.unlink()

    def inspect(self, service):
        result=self.runner(['/usr/bin/systemctl','show',UNITS[service],
                            '--property='+','.join(PROPERTIES)])
        if result.returncode:
            raise ControlError('SERVICE_STATUS_FAILED')
        p=properties(result.stdout)
        if p.get('Id') != UNITS[service]:
            raise ControlError('SERVICE_STATUS_FAILED')
        loaded=p.get('LoadState')=='loaded'
        pid=number(p.get('MainPID'))
        active=p.get('ActiveState','unknown')
        since=number(p.get('ActiveEnterTimestampMonotonic'))
        result_code=p.get('Result','')
        health=('not-installed' if not loaded else
                'failed' if active=='failed' or result_code not in ('','success') else
                'idle' if service=='crl-sync' and active=='inactive' else
                'running' if active=='active' else active)
        return {'id':service,'unit':UNITS[service], 'installed':loaded,
                'active_state':active, 'sub_state':p.get('SubState','unknown'),
                'health':health, 'enabled':p.get('UnitFileState','unknown'),
                'pid':pid, 'memory_bytes':number(p.get('MemoryCurrent')),
                'cpu_seconds':(number(p.get('CPUUsageNSec')) or 0)/1e9
                    if number(p.get('CPUUsageNSec')) is not None else None,
                'tasks':number(p.get('TasksCurrent')),
                'uptime_seconds':max(0,int(time.monotonic()-since/1e6))
                    if active=='active' and since else None,
                'last_result':result_code or None,
                'last_exit_code':number(p.get('ExecMainStatus')),
                'next_trigger':p.get('NextElapseUSecRealtime') or None,
                'last_trigger':p.get('LastTriggerUSec') or None,
                'actions':list(ACTIONS[service]) if loaded else []}

    def radius_listener(self, pid):
        if not pid: return False
        # Read only the generated non-secret listener stanza. Do not grant
        # CAP_SYS_PTRACE merely to inspect another user's /proc/<pid>/fd.
        directory=None
        try:
            directory=os.open('/',os.O_RDONLY|os.O_DIRECTORY)
            for part in self.runtime_site.parts[1:-1]:
                child=os.open(part,os.O_RDONLY|os.O_DIRECTORY|os.O_NOFOLLOW,dir_fd=directory)
                os.close(directory);directory=child
            descriptor=os.open(self.runtime_site.name,os.O_RDONLY|os.O_NOFOLLOW|os.O_NONBLOCK,dir_fd=directory)
            with os.fdopen(descriptor,'rb') as f:
                if not stat.S_ISREG(os.fstat(f.fileno()).st_mode):return False
                raw=f.read(32769)
            if len(raw)>32768:return False
            matches=re.findall(rb'listen\s*\{\s*type\s*=\s*auth\s+ipaddr\s*=\s*([0-9.]+)\s+port\s*=\s*([0-9]+)\s*\}',raw)
            if len(matches)!=1:return False
            ip=str(ipaddress.IPv4Address(matches[0][0].decode('ascii')));port=int(matches[0][1])
            if not 1<=port<=65535:return False
        except (OSError,ValueError,UnicodeError):return False
        finally:
            if directory is not None:os.close(directory)
        r=self.runner(['/usr/bin/ss','-H','-lun'])
        if r.returncode: return False
        return any(f'{ip}:{port}' in line.split() for line in r.stdout.splitlines())

    def status(self):
        with self.snapshot_lock:
            if self.cached is None or time.monotonic()-self.cached_at>2:
                rows=[self.inspect(service) for service in UNITS]
                for row in rows:
                    if row['id']=='radius':
                        row['listener_present']=self.radius_listener(row['pid']) if row['active_state']=='active' else False
                        if row['health']=='running' and not row['listener_present']:
                            row['health']='listener-missing'
                self.cached=rows; self.cached_at=time.monotonic()
            rows=self.cached
        with self.lock:
            return {'available':True,'checked_at':now(),'services':rows,
                    'busy':self.busy or self.pending_power(),'operations':list(reversed(self.jobs[-20:]))}

    def pending_power(self):
        return any(j.get('service')=='system' and j['state'] in {'queued','running','scheduled'} for j in self.jobs)

    def power_status(self):
        self.reconcile_power()
        with self.lock:
            return {'available':self.boot_id is not None,'checked_at':now(),'actions':['reboot','poweroff'] if self.boot_id else [],'busy':self.busy or self.pending_power(),
                    'operations':[dict(j) for j in reversed(self.jobs) if j.get('service')=='system'][:20]}

    def reconcile_power(self):
        with self.lock:
            pending=[dict(j) for j in self.jobs if j.get('service')=='system' and j['state']=='scheduled'
                     and time.monotonic()-j.get('scheduled_monotonic',time.monotonic())>20]
        for job in pending:
            # Inspect only a UUID-derived unit; never replay an uncertain request.
            unit='authwire-power-'+str(uuid.UUID(job['id']))+'.service'
            try:
                result=self.runner(['/usr/bin/systemctl','show',unit,'--property=LoadState,ActiveState,Result,ExecMainStatus'])
                values=properties(result.stdout)
                unknown=result.returncode!=0 or values.get('LoadState')!='loaded'
                failed=values.get('ActiveState')=='failed' or values.get('Result') not in (None,'','success')
                if not (unknown or failed):continue
                with self.lock:
                    current=next((j for j in self.jobs if j['id']==job['id'] and j['state']=='scheduled'),None)
                    if current:
                        current.update(state='interrupted' if unknown else 'failed',error='OUTCOME_UNKNOWN' if unknown else 'POWER_COMMAND_FAILED',finished_at=now())
                        self.save()
            except (OSError,ValueError,subprocess.TimeoutExpired):pass

    def submit_power(self,value):return self.submit(value,power=True)

    def submit(self, value, *, power=False):
        service, action=validate_power_action(value) if power else validate_action(value)
        if power and self.boot_id is None:raise ControlError('POWER_CONTROL_UNAVAILABLE')
        with self.lock:
            existing=next((j for j in self.jobs if j['id']==value['request_id']),None)
            if existing:
                if existing['service']!=service or existing['action']!=action or existing['actor']!=value['actor']:
                    raise ControlError('REQUEST_ID_CONFLICT')
                return dict(existing)
            if self.busy or self.pending_power(): raise ControlError('SERVICE_BUSY')
            if not power and self.inspect(service)['installed'] is not True:
                raise ControlError('SERVICE_NOT_INSTALLED')
            # Never run a sync action to restart a deliberately stopped RADIUS.
            if service=='crl-sync' and self.inspect('radius')['active_state']!='active':
                raise ControlError('RADIUS_NOT_RUNNING')
            job={'id':value['request_id'],'service':service,'action':action,
                 'actor':value['actor'],'state':'queued','created_at':now(),
                 'finished_at':None,'error':None}
            self.jobs=(self.jobs+[job])[-100:]
            try: self.save()
            except OSError:
                self.jobs.remove(job)
                raise ControlError('AUDIT_UNAVAILABLE') from None
            self.busy=True
            threading.Thread(target=self.perform,args=(job,),daemon=True).start()
            return dict(job)

    def perform(self, job):
        with self.maintenance_guard(job) as allowed:
            if allowed:self._perform(job)

    @contextmanager
    def maintenance_guard(self,job):
        descriptor=None
        try:
            if self.update_lock is not None:
                import fcntl
                descriptor=os.open(self.update_lock,os.O_RDONLY|os.O_NOFOLLOW)
                metadata=os.fstat(descriptor)
                if (not stat.S_ISREG(metadata.st_mode) or metadata.st_uid!=0
                        or metadata.st_nlink!=1 or metadata.st_mode & 0o077):
                    raise OSError('Unsafe maintenance lock')
                fcntl.flock(descriptor,fcntl.LOCK_SH|fcntl.LOCK_NB)
        except OSError:
            if descriptor is not None:os.close(descriptor);descriptor=None
            with self.lock:
                job.update(state='failed',error='MAINTENANCE_BUSY',finished_at=now());self.busy=False
                self.save()
            yield False
            return
        try:yield True
        finally:
            if descriptor is not None:os.close(descriptor)

    def _perform(self, job):
        if job['service']=='system':
            self._perform_power(job);return
        try:
            with self.lock:
                job['state']='running';self.save()
            service,action=job['service'],job['action']
            before=self.inspect(service)['enabled']
            result=self.runner(['/usr/bin/systemctl','start' if action=='sync' else action,
                                UNITS[service]],timeout=45)
            if result.returncode: raise ControlError('SERVICE_COMMAND_FAILED')
            deadline=time.monotonic()+20
            while True:
                current=self.inspect(service)
                if current['enabled'] != before: raise ControlError('BOOT_SETTING_CHANGED')
                if action=='sync':
                    good=current['active_state']=='inactive' and current['last_result']=='success' and current['last_exit_code']==0
                elif action=='stop':
                    good=current['active_state']=='inactive'
                else:
                    good=current['active_state']=='active'
                    if service=='radius':good=good and self.radius_listener(current['pid'])
                if good:break
                if time.monotonic()>=deadline:raise ControlError('SERVICE_VERIFICATION_FAILED')
                time.sleep(0.25)
            with self.lock:job.update(state='succeeded',finished_at=now())
        except Exception as error:
            with self.lock:
                job.update(state='failed',finished_at=now(),error=error.code if isinstance(error,ControlError) else 'SERVICE_ACTION_FAILED')
        finally:
            with self.lock:
                self.busy=False
                try:self.save()
                except OSError:job.update(state='failed',error='AUDIT_UNAVAILABLE')
            self.cached_at=0

    def _perform_power(self,job):
        # A fixed transient timer lets the HTTP acknowledgement arrive first.
        # No caller path, shell, arguments, unit name or deadline is accepted.
        try:
            unit='authwire-power-'+job['id']
            with self.lock:
                job.update(state='running',boot_id=self.boot_id,timer_unit=unit+'.timer')
                self.save()
            result=self.runner(['/usr/bin/systemd-run','--quiet','--collect','--unit='+unit,
                                '--on-active=5s','--timer-property=AccuracySec=1s',
                                '--property=Type=oneshot','/usr/bin/systemctl','--no-block',job['action']],timeout=15)
            if result.returncode:raise ControlError('POWER_SCHEDULE_FAILED')
            with self.lock:
                job.update(state='scheduled',scheduled_at=now(),scheduled_monotonic=time.monotonic());self.save()
            # Keep the shared maintenance lock through the timer's firing window.
            time.sleep(7)
        except Exception as error:
            with self.lock:
                job.update(state='failed',finished_at=now(),error=error.code if isinstance(error,ControlError) else 'POWER_OUTCOME_UNKNOWN')
        finally:
            with self.lock:
                self.busy=False
                try:self.save()
                except OSError:job.update(state='interrupted',error='OUTCOME_UNKNOWN')


class Handler(socketserver.StreamRequestHandler):
    def handle(self):
        self.connection.settimeout(2)
        try:
            uid=struct.unpack('3i',self.connection.getsockopt(socket.SOL_SOCKET,socket.SO_PEERCRED,12))[1]
            if uid not in {0,self.server.allowed_uid}:raise ControlError('PEER_FORBIDDEN')
            raw=self.rfile.readline(4097)
            if len(raw)>4096 or not raw.endswith(b'\n'):raise ControlError('INVALID_INPUT')
            value=json.loads(raw)
            if type(value) is dict and value=={'kind':'status'}:
                result=self.server.controller.status()
            elif type(value) is dict and value=={'kind':'power-status'}:
                result=self.server.controller.power_status()
            elif type(value) is dict and value.get('kind')=='power-action':
                result={'operation':self.server.controller.submit_power(value)}
            elif type(value) is dict and value.get('kind')=='action':
                result={'operation':self.server.controller.submit(value)}
            else:raise ControlError('INVALID_INPUT')
            response={'ok':True,'result':result}
        except Exception as error:
            response={'ok':False,'error':error.code if isinstance(error,ControlError) else 'CONTROL_FAILED'}
        self.wfile.write(json.dumps(response,ensure_ascii=True).encode()+b'\n')

class Server(socketserver.ThreadingUnixStreamServer):
    daemon_threads=True
    request_queue_size=8
    def __init__(self,path,controller,allowed_uid):
        self.controller=controller;self.allowed_uid=allowed_uid
        self.slots=threading.BoundedSemaphore(8)
        super().__init__(str(path),Handler)
    def process_request(self, request, client_address):
        if not self.slots.acquire(blocking=False):
            self.shutdown_request(request);return
        try:super().process_request(request,client_address)
        except Exception:self.slots.release();raise
    def process_request_thread(self,request,client_address):
        try:super().process_request_thread(request,client_address)
        finally:self.slots.release()

def main():
    if os.geteuid()!=0:raise SystemExit('Root service required')
    import pwd
    identity=pwd.getpwnam('kaname-lab')
    for path in (SOCKET.parent,HISTORY.parent):
        info=path.lstat()
        if not stat.S_ISDIR(info.st_mode) or info.st_uid!=0 or info.st_mode & 0o022:
            raise SystemExit('Protected service directory required')
    if SOCKET.exists() or SOCKET.is_symlink():
        info=SOCKET.lstat()
        if not stat.S_ISSOCK(info.st_mode) or info.st_uid!=0:raise SystemExit('Unsafe socket path')
        SOCKET.unlink()
    os.umask(0o077)
    with Server(SOCKET,Controller(),identity.pw_uid) as server:
        os.chmod(SOCKET,0o660)
        # systemd Group=kaname-lab supplies the socket group; never broaden access.
        if SOCKET.stat().st_gid!=identity.pw_gid:raise SystemExit('Socket group mismatch')
        server.serve_forever(poll_interval=0.25)

if __name__=='__main__':main()
