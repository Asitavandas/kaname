"""Read-only verifier fixtures: real config differences must never be excused."""
import io,json,runpy,sqlite3,tarfile,unittest
from contextlib import ExitStack,closing
from pathlib import Path

ns=runpy.run_path(str(Path(__file__).with_name('authwire-panel-dev6-verify-20261015.py')))
compare=ns['compare_databases']

def fixture():
    db=sqlite3.connect(':memory:')
    for name in ('state','protected_secrets','pki_certificates','device_signer','device_profiles','radius_certificate_bindings','pki_client_keys','admin_users','admin_profiles'):
        db.execute('CREATE TABLE '+name+' (id TEXT,payload TEXT)');db.execute('INSERT INTO '+name+' VALUES (?,?)',('one','sensitive fixture'))
    db.execute('CREATE TABLE pki_authority(root_cert BLOB,root_key BLOB,issuer_cert BLOB,issuer_key BLOB)')
    db.execute('INSERT INTO pki_authority VALUES (?,?,?,?)',(b'c',b'k',b'i',b'j'))
    db.execute('CREATE TABLE runtime_settings(name TEXT,payload TEXT)')
    db.executemany('INSERT INTO runtime_settings VALUES (?,?)',[('network','{"vlan":110}'),('directory','{"check_minutes":5}'),('directory_health',json.dumps({'state':'healthy','error':'','checked_at':'t1','last_success':'t1'}))])
    return db

class VerificationTests(unittest.TestCase):
    def setUp(self):
        self.stack=ExitStack();self.addCleanup(self.stack.close)
        self.before=self.stack.enter_context(closing(fixture()));self.after=self.stack.enter_context(closing(fixture()))
    def run_compare(self):return compare(self.before,self.after,self.before,self.after)
    def test_time_only_health_is_reported_and_control_state_remains_strict(self):
        self.after.execute("UPDATE runtime_settings SET payload=? WHERE name='directory_health'",(json.dumps({'state':'healthy','error':'','checked_at':'t2','last_success':'t2'}),))
        checks,health=self.run_compare();self.assertTrue(all(checks.values()));self.assertTrue(health['timestamps_only']);self.assertEqual(['checked_at','last_success'],health['changed_fields'])
    def test_policy_change_rejected_even_with_normal_health_change(self):
        self.after.execute("UPDATE state SET payload='changed policy'")
        checks,_=self.run_compare();self.assertFalse(checks['configuration_and_policies'])
    def test_network_change_cannot_be_hidden_as_health(self):
        self.after.execute("UPDATE runtime_settings SET payload='changed vlan' WHERE name='network'")
        checks,_=self.run_compare();self.assertFalse(checks['runtime_configuration'])
    def test_admin_or_ca_key_difference_rejected(self):
        self.after.execute("UPDATE admin_users SET payload='changed account'")
        self.after.execute("UPDATE pki_authority SET issuer_key=?",(b'changed',))
        checks,_=self.run_compare();self.assertFalse(checks['administrator_users']);self.assertFalse(checks['ca_material'])
    def test_missing_required_table_rejected(self):
        self.after.execute('DROP TABLE device_profiles')
        checks,_=self.run_compare();self.assertFalse(checks['enrollment_profiles'])
    def test_stable_state_accepted(self):
        checks,health=self.run_compare();self.assertTrue(all(checks.values()));self.assertFalse(health['changed'])
    def test_checkpoint_symlink_never_read(self):
        data=io.BytesIO()
        with tarfile.open(fileobj=data,mode='w') as tar:
            item=tarfile.TarInfo('db');item.type=tarfile.SYMTYPE;item.linkname='/etc/shadow';tar.addfile(item)
        data.seek(0)
        with tarfile.open(fileobj=data,mode='r') as tar:
            with self.assertRaises(ValueError):ns['member_bytes'](tar,'db',1024)

if __name__=='__main__':unittest.main()
