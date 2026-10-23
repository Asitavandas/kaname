"""Resource math, bounded read failures and authenticated read permissions."""
from pathlib import Path
from types import SimpleNamespace
import tempfile
import unittest
from unittest.mock import patch
from kaname.resources import ResourceSampler
from . import test_admin as admins

class ResourceTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup);self.root=Path(self.temp.name)
        self.time=0;self.disk=SimpleNamespace(total=1000,used=400,free=600)
        self.s=ResourceSampler(self.root,clock=lambda:self.time,disk=lambda root:self.disk)
        self.write('cpu 100 0 100 800 0 0 0 0 9 9\n')
        (self.root/'meminfo').write_text('MemTotal: 1000 kB\nMemAvailable: 400 kB\n')
        (self.root/'uptime').write_text('123456.5 34567.1\n')
    def write(self,cpu): (self.root/'stat').write_text(cpu)
    def test_first_cpu_is_pending_then_interval_math_and_cache(self):
        first=self.s.sample(self.root);self.assertIsNone(first['cpu']['percent']);self.assertTrue(first['cpu']['available'])
        self.assertEqual(first['memory']['percent'],60);self.assertEqual(first['memory']['used_bytes'],600*1024)
        self.assertEqual(first['disk']['percent'],40);self.assertEqual(first['uptime']['seconds'],123456)
        self.write('cpu 300 0 300 1400 0 0 0 0 10000 10000\n');self.time=4
        self.assertEqual(self.s.sample(self.root),first)
        self.time=6;v=self.s.sample(self.root);self.assertEqual(v['cpu']['percent'],40);self.assertEqual(v['cpu']['sample_seconds'],6)
        self.assertEqual(v['scope'],'linux_guest');self.assertEqual(v['disk']['scope'],'authwire_data_filesystem');self.assertNotIn(str(self.root),str(v))
    def test_counter_reset_and_clock_rollback_never_emit_fake_cpu(self):
        self.s.sample(self.root);self.time=6;self.write('cpu 1 0 1 8 0 0 0 0\n');self.assertIsNone(self.s.sample(self.root)['cpu']['percent'])
        self.time=1;self.assertIsNone(self.s.sample(self.root)['cpu']['percent'])
    def test_missing_or_malformed_metrics_fail_independently(self):
        self.write('cpu invalid\n');(self.root/'meminfo').write_text('MemTotal: 100 kB\nMemAvailable: 200 kB\n');v=self.s.sample(self.root)
        self.assertFalse(v['cpu']['available']);self.assertFalse(v['memory']['available']);self.assertTrue(v['disk']['available']);self.assertTrue(v['uptime']['available'])
        self.time=6;(self.root/'uptime').write_text('nan\n');self.disk=SimpleNamespace(total=0,used=0,free=0);v=self.s.sample(self.root);self.assertFalse(v['disk']['available']);self.assertFalse(v['uptime']['available'])
    def test_io_failure_isolated_and_reads_create_no_files(self):
        before={p.name:p.read_bytes() for p in self.root.iterdir()}
        with patch.object(self.s,'disk',side_effect=OSError()):v=self.s.sample(self.root)
        self.assertFalse(v['disk']['available']);self.assertTrue(v['memory']['available']);self.assertEqual(before,{p.name:p.read_bytes() for p in self.root.iterdir()})
    def test_oversized_memory_file_rejected(self):
        (self.root/'meminfo').write_text('x'*32769);self.assertFalse(self.s.sample(self.root)['memory']['available'])

class ResourceHTTPTests(unittest.TestCase):
    setUp=admins.AdministratorHTTPTests.setUp
    close=admins.AdministratorHTTPTests.close
    call=admins.AdministratorHTTPTests.call
    system=admins.AdministratorHTTPTests.system
    create_profile=admins.AdministratorHTTPTests.create_profile
    user=admins.AdministratorHTTPTests.user
    login=admins.AdministratorHTTPTests.login
    def test_anonymous_and_no_service_permission_never_sample(self):
        profile=self.create_profile('Events only',{'audit.events':'read'});self.user('resource-reader',profile);pair=self.login('resource-reader')
        with patch('kaname.server.resource_snapshot') as sample:
            self.assertEqual(self.call('GET','/api/system/resources',auth=None)[0],401)
            self.assertEqual(self.call('GET','/api/system/resources',auth=pair)[0],403);sample.assert_not_called()
    def test_read_only_service_account_can_read_without_business_write(self):
        profile=self.create_profile('Resource read',{'system.services':'read'});self.user('service-reader',profile);pair=self.login('service-reader')
        before=self.server.store.snapshot();public={'checked_at':'2026-10-23T00:00:00Z','scope':'linux_guest','cpu':{'available':True,'percent':None}}
        with patch('kaname.server.resource_snapshot',return_value=public) as sample:
            code,value,_=self.call('GET','/api/system/resources',auth=pair);self.assertEqual(code,200);self.assertEqual(value,public);sample.assert_called_once_with(self.server.store.root)
            self.assertEqual(self.call('GET','/api/system/resources?path=/etc/passwd',auth=pair)[0],400)
        code,value,_=self.call('GET','/api/dashboard',auth=pair);self.assertEqual(code,200);self.assertIsNone(value['events']);self.assertIsNone(value['certificates']);self.assertEqual(before,self.server.store.snapshot())

if __name__=='__main__':unittest.main()
