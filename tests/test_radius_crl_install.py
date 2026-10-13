"""Safe timer installation, inactive-service handling and rollback boundaries."""
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from tools import radius_crl_install as installer


class TimerInstallTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = self.root/'source';(self.source/'tools').mkdir(parents=True)
        (self.source/'tools/radius_crl_sync.py').write_text('verified fixture')
        (self.source/'tools/radius_runtime.py').write_text('ca_path_reload_interval = 300\n')
        self.radius = self.root/'radius.service';self.radius.write_bytes(b'unchanged primary unit')
        self.service = self.root/'sync.service';self.timer = self.root/'sync.timer'
        self.calls = []
        self.eap = self.root/'eap';self.eap.write_text('ca_path_reload_interval = 300\n')
        for name,value in (('ROOT',self.source),('RADIUS_UNIT',self.radius),
                           ('SERVICE',self.service),('TIMER',self.timer)):
            p=patch.object(installer,name,value);p.start();self.addCleanup(p.stop)
        for name,value in (('protected',None),('active',True),('preservation_digest','fixed-private-digest')):
            p=patch.object(installer,name,return_value=value);p.start();self.addCleanup(p.stop)
        original=Path.read_text
        def read(path,*args,**kwargs):
            if str(path)=='/run/authwire-radius/mods-enabled/eap':return self.eap.read_text()
            return original(path,*args,**kwargs)
        p=patch.object(Path,'read_text',read);p.start();self.addCleanup(p.stop)

    def command(self,*args):
        self.calls.append(args)
        if args[:2]==('systemctl','restart'):
            self.eap.write_text('ca_path_reload_interval = 300\n')
        if args[0]=='/usr/sbin/runuser':
            return subprocess.CompletedProcess(args,0,b'{"synced":true,"changed":false}')
        return subprocess.CompletedProcess(args,0,b'')

    def install(self,command=None):
        with patch.object(installer,'command',side_effect=command or self.command):
            return installer._install()

    def test_timer_and_hardening_are_installed_without_unneeded_radius_restart(self):
        result=self.install()
        self.assertTrue(result['timer_enabled']);self.assertFalse(result['initial_radius_restart'])
        self.assertEqual(b'unchanged primary unit',self.radius.read_bytes())
        self.assertIn('User=kaname-lab\n',self.service.read_text())
        self.assertNotIn('Requires=authwire-radius.service',self.service.read_text())
        self.assertIn('ConditionPathIsDirectory=/run/authwire-radius/ca',self.service.read_text())
        self.assertFalse(any(c[:2]==('systemctl','restart') for c in self.calls))
        self.assertFalse(self.install()['initial_radius_restart'])

    def test_old_runtime_gets_one_initial_restart(self):
        self.eap.write_text('old verified runtime')
        self.assertTrue(self.install()['initial_radius_restart'])
        self.assertEqual(1,sum(c[:2]==('systemctl','restart') for c in self.calls))

    def test_inactive_radius_or_unsupported_source_refuses_install(self):
        with patch.object(installer,'active',return_value=False), self.assertRaises(ValueError):self.install()
        self.assertFalse(self.service.exists());self.assertEqual([],self.calls)
        (self.source/'tools/radius_runtime.py').write_text('old generator')
        with self.assertRaises(ValueError):self.install()
        self.assertFalse(self.timer.exists())

    def test_unknown_existing_unit_is_never_overwritten(self):
        self.service.write_text('operator custom unit')
        with self.assertRaises(ValueError):self.install()
        self.assertEqual('operator custom unit',self.service.read_text())
        self.assertEqual([],self.calls)

    def test_verify_failure_removes_only_new_units(self):
        def command(*args):
            if args[0]=='systemd-analyze':raise subprocess.CalledProcessError(1,args)
            return self.command(*args)
        with patch.object(installer.subprocess,'run'), self.assertRaises(subprocess.CalledProcessError):
            self.install(command)
        self.assertFalse(self.service.exists());self.assertFalse(self.timer.exists())
        self.assertEqual(b'unchanged primary unit',self.radius.read_bytes())

    def test_failed_first_sync_does_not_enable_timer(self):
        def command(*args):
            if args[0]=='/usr/sbin/runuser':return subprocess.CompletedProcess(args,0,b'{"synced":false}')
            return self.command(*args)
        with patch.object(installer.subprocess,'run'), self.assertRaises(ValueError):self.install(command)
        self.assertFalse(any(c[:3]==('systemctl','enable','--now') for c in self.calls))

    def test_state_change_after_install_is_not_reported_as_preserved(self):
        with patch.object(installer,'preservation_digest',side_effect=['before','after']), \
             patch.object(installer.subprocess,'run'), self.assertRaises(ValueError):self.install()
        self.assertFalse(self.service.exists());self.assertFalse(self.timer.exists())


if __name__=='__main__':unittest.main()
