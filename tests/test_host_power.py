"""All power runners are fakes. These tests never schedule a real host action."""
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
import uuid
from unittest.mock import patch

from kaname.admin import permissions
from kaname.services import validate_power, ServiceError
from tools import service_control_broker as broker
from . import test_admin as admins


def body(action='reboot'):
    return {'action':action,'request_id':str(uuid.uuid4()),'confirmed':True}


class PowerBrokerTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.calls=[]
        self.controller=broker.Controller(Path(self.temp.name)/'operations.json',self.runner,update_lock=None)
    def runner(self,args,timeout=5):
        self.calls.append(args)
        return subprocess.CompletedProcess(args,0,'','')
    def request(self,action='reboot'):
        return {'kind':'power-action','action':action,'actor':'admin','request_id':str(uuid.uuid4())}
    def perform(self,value):
        with patch.object(broker.threading.Thread,'start'):
            self.controller.submit_power(value)
        job=self.controller.jobs[-1]
        with patch.object(broker.time,'sleep'):
            self.controller.perform(job)
        return job
    def test_fixed_timer_command_durable_intent_and_no_replay(self):
        value=self.request();job=self.perform(value)
        self.assertEqual(job['state'],'scheduled')
        self.assertEqual(self.calls,[['/usr/bin/systemd-run','--quiet','--collect','--unit=authwire-power-'+value['request_id'],
            '--on-active=5s','--timer-property=AccuracySec=1s','--property=Type=oneshot','/usr/bin/systemctl','--no-block','reboot']])
        self.controller.submit_power(value)
        self.assertEqual(len(self.calls),1)
        self.assertTrue(self.controller.power_status()['busy'])
        with self.assertRaisesRegex(broker.ControlError,'SERVICE_BUSY'):self.controller.submit_power(self.request('poweroff'))
    def test_poweroff_is_distinct_and_arguments_cannot_be_injected(self):
        self.assertEqual(self.perform(self.request('poweroff'))['action'],'poweroff')
        for changes in [{'action':'reboot;id'},{'action':['reboot']},{'unit':'sshd'},{'request_id':'--bad'},{'actor':'admin;id'},{'kind':'action'}]:
            with self.subTest(changes=changes),self.assertRaises(broker.ControlError):broker.validate_power_action({**self.request(),**changes})
    def test_audit_failure_prevents_any_scheduling(self):
        with patch.object(self.controller,'save',side_effect=OSError),self.assertRaisesRegex(broker.ControlError,'AUDIT_UNAVAILABLE'):
            self.controller.submit_power(self.request())
        self.assertEqual(self.calls,[])
    def test_command_failure_is_recorded_and_redacted(self):
        self.controller.runner=lambda *args,**kwargs:subprocess.CompletedProcess(args,1,'','SECRET')
        job=self.perform(self.request())
        self.assertEqual(job['state'],'failed');self.assertEqual(job['error'],'POWER_SCHEDULE_FAILED')
        self.assertNotIn('SECRET',self.controller.history.read_text())
    def test_broker_restart_does_not_reschedule_and_boot_change_is_only_observed(self):
        value=self.request();self.perform(value)
        first=broker.Controller(self.controller.history,self.runner,update_lock=None)
        self.assertTrue(first.power_status()['busy']);self.assertEqual(len(self.calls),1)
        with patch.object(broker,'boot_identity',return_value=str(uuid.uuid4())):
            second=broker.Controller(self.controller.history,self.runner,update_lock=None)
        self.assertEqual(second.jobs[-1]['state'],'boot-observed')
        self.assertFalse(second.power_status()['busy']);self.assertEqual(len(self.calls),1)
    def test_reused_id_cannot_change_action_or_actor(self):
        value=self.request();self.perform(value)
        for fields in [{'action':'poweroff'},{'actor':'other'}]:
            with self.assertRaisesRegex(broker.ControlError,'REQUEST_ID_CONFLICT'):self.controller.submit_power({**value,**fields})
    def test_service_permission_does_not_imply_power_permission(self):
        self.assertEqual(permissions('Custom',{'system.services':'write'})['system.power'],'none')
    def test_missing_boot_identity_refuses_scheduling(self):
        self.controller.boot_id=None
        with self.assertRaisesRegex(broker.ControlError,'POWER_CONTROL_UNAVAILABLE'):
            self.controller.submit_power(self.request())
        self.assertEqual(self.calls,[])
    def test_client_requires_explicit_confirmation_and_exact_fields(self):
        validate_power(body())
        for changes in [{'confirmed':False},{'confirmed':1},{'action':'halt'},{'service':'radius'},{'actor':'spoof'}]:
            with self.assertRaises(ServiceError):validate_power({**body(),**changes})


class PowerHTTPTests(unittest.TestCase):
    setUp=admins.AdministratorHTTPTests.setUp
    close=admins.AdministratorHTTPTests.close
    call=admins.AdministratorHTTPTests.call
    system=admins.AdministratorHTTPTests.system
    create_profile=admins.AdministratorHTTPTests.create_profile
    user=admins.AdministratorHTTPTests.user
    login=admins.AdministratorHTTPTests.login
    def test_session_csrf_origin_maintenance_and_readonly_boundaries(self):
        with patch.object(self.server.services,'power_action') as perform:
            for auth,headers,expected in [(None,{},401),('default',{'X-Kaname-CSRF':'wrong'},403),
                    ('default',{'Origin':'https://wrong.example'},403),(None,{'Authorization':'Bearer '+self.server.token},403)]:
                self.assertEqual(self.call('POST','/api/system/power/action',body(),auth=auth,headers=headers)[0],expected)
            self.user();pair=self.login('reader')
            self.assertEqual(self.call('POST','/api/system/power/action',body(),auth=pair)[0],403)
            perform.assert_not_called()
    def test_custom_service_operator_cannot_power_host(self):
        profile=self.create_profile('ServicesOnly',{'system.services':'write'});self.user('operator',profile);pair=self.login('operator')
        self.assertEqual(self.call('GET','/api/system/power',auth=pair)[0],403)
        self.assertEqual(self.call('POST','/api/system/power/action',body(),auth=pair)[0],403)
    def test_bad_payload_and_audit_failure_never_reach_broker(self):
        with patch.object(self.server.services,'power_action') as perform:
            for value in [{**body(),'confirmed':False},{**body(),'actor':'spoof'},{**body(),'action':'reboot;id'}]:
                self.assertEqual(self.call('POST','/api/system/power/action',value)[0],400)
            perform.assert_not_called()
    def test_action_records_intent_without_changing_business_state(self):
        before=self.server.store.snapshot();value=body()
        with patch.object(self.server.services,'power_action',return_value={'operation':{'id':value['request_id'],'state':'queued'}}) as perform:
            self.assertEqual(self.call('POST','/api/system/power/action',value)[0],202);perform.assert_called_once()
        self.assertEqual(self.server.store.snapshot(),before)
        self.assertIn('system_power_requested:',self.server.store.audit()[0]['event'])
    def test_status_failure_does_not_break_session(self):
        self.assertEqual(self.call('GET','/api/system/power')[0],503)
        self.assertEqual(self.call('GET','/api/auth/session')[0],200)


if __name__=='__main__':unittest.main()
