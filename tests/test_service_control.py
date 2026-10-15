import json
import io
import struct
from types import SimpleNamespace
from pathlib import Path
import subprocess
import tempfile
import threading
import time
import unittest
import uuid
from unittest.mock import patch

from tools import service_control_broker as broker
from tools.service_control_install import unit_text, tmpfiles_text
from kaname.services import Services, ServiceError, validate
from . import test_admin as admin_tests

def action(service='radius',verb='restart'):
    return {'service':service,'action':verb,'request_id':str(uuid.uuid4()),'confirmed':True}

class Runner:
    def __init__(self):
        self.calls=[];self.running=True;self.listening=True;self.command_error=False
        self.wait=None;self.enabled='enabled'
    def __call__(self,args,timeout=5):
        self.calls.append(args)
        if args[0]=='/usr/bin/ss':
            return subprocess.CompletedProcess(args,0,'UNCONN 0 0 192.0.2.1:1812 0.0.0.0:* users:(("radiusd",pid=42,fd=3))' if self.listening else '', '')
        service=args[2]
        if args[1]=='show':
            active='active' if self.running else 'inactive'
            if service.endswith('crl-sync.service'):active='inactive'
            content={'Id':service,'LoadState':'loaded','ActiveState':active,'SubState':'running',
                'MainPID':'42','UnitFileState':self.enabled,'Result':'success',
                'ExecMainStatus':'0','MemoryCurrent':'12345','CPUUsageNSec':'2000000000',
                'TasksCurrent':'3','ActiveEnterTimestampMonotonic':'1'}
            return subprocess.CompletedProcess(args,0,'\n'.join(k+'='+v for k,v in content.items()),'')
        if self.wait:self.wait.wait(3)
        self.running=args[1]!='stop'
        return subprocess.CompletedProcess(args,1 if self.command_error else 0,'','secret-not-for-output')

class BrokerTests(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup)
        self.runner=Runner();self.history=Path(self.tmp.name)/'operations.json'
        self.site=Path(self.tmp.name)/'authwire';self.site.write_text('listen {\n type = auth\n ipaddr = 192.0.2.1\n port = 1812\n}\n')
        self.control=broker.Controller(self.history,self.runner,update_lock=None,runtime_site=self.site)
    def request(self,service='radius',verb='restart'):
        v=action(service,verb);v.pop('confirmed');return {'kind':'action',**v,'actor':'operator'}
    def finish(self):
        limit=time.monotonic()+4
        while self.control.busy and time.monotonic()<limit:time.sleep(.01)
        self.assertFalse(self.control.busy)
        return self.control.jobs[-1]
    def test_allowlist_blocks_shell_other_units_and_self_stop(self):
        for service,verb in [('sshd','stop'),('panel','stop'),('radius;id','restart'),('radius','enable'),('radius','disable'),('crl-sync','restart')]:
            with self.assertRaises(broker.ControlError):self.control.submit(self.request(service,verb))
        self.assertEqual([],self.runner.calls)
    def test_restart_verified_idempotent_and_boot_setting_unchanged(self):
        req=self.request();self.control.submit(req);self.assertEqual('succeeded',self.finish()['state'])
        self.control.submit(req)
        commands=[a for a in self.runner.calls if a[1]=='restart']
        self.assertEqual(1,len(commands));self.assertEqual('enabled',self.runner.enabled)
        self.assertTrue(any(a[0]=='/usr/bin/ss' for a in self.runner.calls))
        self.assertNotIn('secret-not-for-output',self.history.read_text())
    def test_conflicting_id_and_parallel_commands_rejected(self):
        self.runner.wait=threading.Event()
        req=self.request();self.control.submit(req)
        with self.assertRaisesRegex(broker.ControlError,'SERVICE_BUSY'):self.control.submit(self.request())
        changed={**req,'action':'stop'}
        with self.assertRaisesRegex(broker.ControlError,'REQUEST_ID_CONFLICT'):self.control.submit(changed)
        self.runner.wait.set();self.finish()
    def test_durable_intent_failure_prevents_command(self):
        with patch.object(self.control,'save',side_effect=OSError):
            with self.assertRaisesRegex(broker.ControlError,'AUDIT_UNAVAILABLE'):self.control.submit(self.request())
        self.assertFalse(any(a[1] in ('start','restart','stop') for a in self.runner.calls))
    def test_stop_does_not_disable_boot(self):
        self.control.submit(self.request(verb='stop'));self.assertEqual('succeeded',self.finish()['state'])
        self.assertEqual('enabled',self.runner.enabled)
        self.assertFalse(any('disable' in a for a in self.runner.calls))
    def test_command_failure_redacts_stderr_and_records_actor(self):
        self.runner.command_error=True;self.control.submit(self.request());job=self.finish()
        self.assertEqual('failed',job['state']);self.assertEqual('SERVICE_COMMAND_FAILED',job['error'])
        self.assertEqual('operator',json.loads(self.history.read_text())[0]['actor'])
        self.assertNotIn('secret-not-for-output',self.history.read_text())
    def test_missing_listener_does_not_claim_success(self):
        self.runner.listening=False
        with patch.object(broker.time,'monotonic',side_effect=[0,0,21,21]):
            # Direct worker invocation avoids scheduler timing in this deadline test.
            job={**self.request(),'id':str(uuid.uuid4()),'state':'queued'}
            self.control.jobs=[job];self.control.busy=True;self.control.perform(job)
        self.assertEqual('SERVICE_VERIFICATION_FAILED',job['error'])
    def test_sync_idle_is_healthy_and_never_starts_stopped_radius(self):
        state=self.control.status();sync=next(x for x in state['services'] if x['id']=='crl-sync')
        self.assertEqual('idle',sync['health'])
        self.runner.running=False
        with self.assertRaisesRegex(broker.ControlError,'RADIUS_NOT_RUNNING'):self.control.submit(self.request('crl-sync','sync'))
        self.assertFalse(any(a[1]=='start' for a in self.runner.calls))
    def test_restart_marks_unfinished_unknown_without_replay(self):
        req=self.request();job={**req,'id':req['request_id'],'state':'running','created_at':'test'}
        self.history.write_text(json.dumps([job]))
        restored=broker.Controller(self.history,self.runner,update_lock=None)
        self.assertEqual('interrupted',restored.jobs[0]['state'])
        self.assertEqual('OUTCOME_UNKNOWN',restored.jobs[0]['error']);self.assertEqual([],self.runner.calls)
    def test_maintenance_lock_prevents_mutation(self):
        self.control.update_lock=Path(self.tmp.name)/'absent'
        self.control.submit(self.request());self.assertEqual('MAINTENANCE_BUSY',self.finish()['error'])
        self.assertFalse(any(a[1]=='restart' for a in self.runner.calls))
    def test_installed_unit_retains_web_hardening_and_has_no_network_api(self):
        unit=unit_text()
        for value in ['User=root','Group=kaname-lab','NoNewPrivileges=yes','ProtectSystem=strict','RestrictAddressFamilies=AF_UNIX AF_NETLINK']:
            self.assertIn(value,unit)
        self.assertNotIn('AF_INET',unit)
        self.assertEqual((),broker.ACTIONS['panel'])
        self.assertIn('After=local-fs.target systemd-tmpfiles-setup.service',unit)
        self.assertEqual('f /run/kaname-lab-update.lock 0600 root root -\n',tmpfiles_text())
    def test_client_rejects_unknown_fields_unconfirmed_and_invalid_ids(self):
        for v in [{**action(),'confirmed':False},{**action(),'actor':'spoof'},{**action(),'request_id':'bad'},{**action(),'service':'panel'},{**action(),'unit':'sshd.service'}]:
            with self.assertRaises(ServiceError):validate(v)
        with self.assertRaisesRegex(ServiceError,'SERVICE_CONTROL_UNAVAILABLE'):
            Services(Path(self.tmp.name)/'missing').status()

    @unittest.skipUnless(hasattr(broker.socket,'SO_PEERCRED'),'Linux Unix peer credentials')
    def test_peer_uid_and_bounded_protocol_gate_before_controller(self):
        for uid,raw,error in [(1234,b'{"kind":"status"}\n','PEER_FORBIDDEN'),
                              (1001,b'x'*4097,'INVALID_INPUT'),
                              (1001,b'{"kind":"shell","command":"id"}\n','INVALID_INPUT')]:
            conn=SimpleNamespace(settimeout=lambda _:None,getsockopt=lambda *args:struct.pack('3i',5,uid,100))
            handler=SimpleNamespace(connection=conn,rfile=io.BytesIO(raw),wfile=io.BytesIO(),
                                    server=SimpleNamespace(allowed_uid=1001,controller=self.control))
            broker.Handler.handle(handler)
            self.assertEqual(error,json.loads(handler.wfile.getvalue())['error'])
        self.assertEqual([],self.runner.calls)

class ServiceHTTPTests(unittest.TestCase):
    # Reuse fixture helpers, not its test methods.
    setUp=admin_tests.AdministratorHTTPTests.setUp
    close=admin_tests.AdministratorHTTPTests.close
    call=admin_tests.AdministratorHTTPTests.call
    system=admin_tests.AdministratorHTTPTests.system
    create_profile=admin_tests.AdministratorHTTPTests.create_profile
    user=admin_tests.AdministratorHTTPTests.user
    login=admin_tests.AdministratorHTTPTests.login

    def test_read_permission_does_not_allow_service_action(self):
        self.user();auth=self.login('reader')
        with patch.object(self.server.services,'status',return_value={'available':True}):
            self.assertEqual(200,self.call('GET','/api/services',auth=auth)[0])
        with patch.object(self.server.services,'action') as perform:
            self.assertEqual(403,self.call('POST','/api/services/action',action(),auth=auth)[0]);perform.assert_not_called()
    def test_ungranted_custom_profile_cannot_read_or_write(self):
        p=self.create_profile('PoliciesOnly',{'policies.rules':'write'});self.user('custom',p);auth=self.login('custom')
        self.assertEqual(403,self.call('GET','/api/services',auth=auth)[0])
        self.assertEqual(403,self.call('POST','/api/services/action',action(),auth=auth)[0])
    def test_csrf_origin_and_session_required(self):
        with patch.object(self.server.services,'action') as perform:
            self.assertEqual(401,self.call('POST','/api/services/action',action(),auth=None)[0])
            self.assertEqual(403,self.call('POST','/api/services/action',action(),headers={'X-Kaname-CSRF':'bad'})[0])
            self.assertEqual(403,self.call('POST','/api/services/action',action(),headers={'Origin':'https://wrong.example'})[0])
            self.assertEqual(403,self.call('POST','/api/services/action',action(),auth=None,headers={'Authorization':'Bearer '+self.server.token})[0]);perform.assert_not_called()
    def test_accepted_action_audited_without_policy_or_revision_changes(self):
        before=self.server.store.snapshot();value=action()
        with patch.object(self.server.services,'action',return_value={'operation':{'id':value['request_id'],'state':'queued'}}) as perform:
            code,result,_=self.call('POST','/api/services/action',value)
            self.assertEqual(202,code);self.assertEqual('queued',result['operation']['state']);perform.assert_called_once()
        after=self.server.store.snapshot();self.assertEqual(before,after)
        event=self.server.store.audit()[0]['event'];self.assertIn('service_action_requested:',event);self.assertIn('admin',event)
    def test_invalid_action_never_reaches_broker_and_unavailable_is_local(self):
        with patch.object(self.server.services,'action') as perform:
            for v in [{**action(),'confirmed':False},{**action(),'service':'sshd'},{**action(),'action':'enable'},{**action(),'actor':'spoof'}]:
                self.assertEqual(400,self.call('POST','/api/services/action',v)[0])
            perform.assert_not_called()
        self.assertEqual(503,self.call('GET','/api/services')[0])
        self.assertEqual(200,self.call('GET','/api/state')[0])
        self.assertEqual(200,self.call('GET','/api/auth/session')[0])
