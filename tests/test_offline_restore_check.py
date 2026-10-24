import io
import json
import os
import runpy
from pathlib import Path
import shutil
import sqlite3
import subprocess
import sys
import tarfile
import tempfile
import unittest
from contextlib import closing
from cryptography import x509
from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives.ciphers.aead import AESGCM
from kaname.pki import PKIService
from kaname.admin import AdminStore
from kaname.operations import Operations
from kaname.models import ValidationError
from .helpers import config
from .test_pki import PASSWORD,csr
from tools.offline_restore_check import check,restore_data,sha,validate_copy

class OfflineRestoreTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.base=tempfile.TemporaryDirectory();root=Path(cls.base.name)
        cls.state=root/'var/lib/kaname-lab';cls.state.mkdir(parents=True)
        pki=PKIService(cls.state);pki.store.save(0,config=config());pki.initialize(PASSWORD)
        admin=AdminStore(pki.store);ops=Operations(pki.store)
        with pki.store.connect() as db:
            issuer=serialization.load_pem_private_key(db.execute('SELECT issuer_key FROM pki_authority').fetchone()[0],PASSWORD)
            db.execute('CREATE TABLE device_signer(id INTEGER PRIMARY KEY,key_sealed BLOB)')
            pem=issuer.private_bytes(serialization.Encoding.PEM,serialization.PrivateFormat.PKCS8,serialization.NoEncryption()).decode()
            db.execute('INSERT INTO device_signer VALUES (1,?)',(ops.vault.seal('device-issuer-key',pem),))
            db.execute('INSERT INTO protected_secrets VALUES (?,?)',('directory',ops.vault.seal('directory','fixture secret never printed')))
            for table in ('device_profiles','radius_certificate_bindings','pki_client_keys','device_issuances','device_retirements'):
                db.execute('CREATE TABLE '+table+' (id TEXT)')
        key=ec.generate_private_key(ec.SECP256R1());cert=pki.issue_radius(csr(key),PASSWORD)
        keybytes=key.private_bytes(serialization.Encoding.PEM,serialization.PrivateFormat.PKCS8,serialization.NoEncryption())
        for certpath,keypath in [('etc/kaname-lab/web.crt','etc/kaname-lab/web.key'),('var/lib/kaname-lab/radius/server.pem','var/lib/kaname-lab/radius/server-key.pem')]:
            for name,data in [(certpath,cert),(keypath,keybytes)]:
                p=root/name;p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(data);p.chmod(0o600)
        drop=root/'etc/systemd/system/authwire-radius.service.d/override.conf'
        drop.parent.mkdir(parents=True);drop.write_text('[Service]\nPrivateTmp=yes\n');drop.chmod(0o640)
        # Runtime symlinks are intentionally not materialized by the data rehearsal.
        p=root/'opt/kaname-lab/venv/bin';p.mkdir(parents=True);(p/'python').symlink_to('/usr/bin/python3')
        cls.archive=root/'backup.tar.gz'
        with tarfile.open(cls.archive,'w:gz') as tar:
            for name in ('var/lib/kaname-lab','etc/kaname-lab','opt/kaname-lab/venv','etc/systemd/system'):tar.add(root/name,arcname=name)
        cls.expected=sha(cls.archive)
    @classmethod
    def tearDownClass(cls):cls.base.cleanup()
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup);self.root=Path(self.temp.name)
    def test_real_encrypted_state_certificate_keys_and_cleanup(self):
        result=check(self.archive,self.expected,self.root/'work')
        self.assertTrue(result['data_restore_exercised']);self.assertTrue(all(result['checks'].values()))
        self.assertEqual(1,result['protected_secret_count_verified']);self.assertTrue(result['ownership_and_modes_verified'])
        self.assertFalse(result['services_started']);self.assertFalse(result['restored_code_executed'])
        self.assertEqual([],list((self.root/'work').iterdir()))
    def test_optional_user_schema_must_be_complete_and_readable(self):
        copy=self.root/'restored';restore_data(self.archive,copy)
        path=copy/'var/lib/kaname-lab/kaname.sqlite3'
        tables=('user_enrollment_profiles','user_enrollment_challenges','user_enrollment_issuances','user_enrollment_rate')
        with closing(sqlite3.connect(path)) as db:
            db.execute('CREATE TABLE '+tables[0]+' (id TEXT)');db.commit()
        with self.assertRaisesRegex(ValueError,'Incomplete user enrollment schema'):validate_copy(copy)
        with closing(sqlite3.connect(path)) as db:
            for table in tables[1:]:db.execute('CREATE TABLE '+table+' (id TEXT)')
            db.commit()
        self.assertTrue(validate_copy(copy)['checks']['user_enrollment_tables_readable'])

    def test_unit_dropin_is_rehydrated_without_running_it(self):
        copy=self.root/'restored';restore_data(self.archive,copy)
        p=copy/'etc/systemd/system/authwire-radius.service.d/override.conf'
        self.assertEqual('[Service]\nPrivateTmp=yes\n',p.read_text())
        self.assertEqual(0o640,p.stat().st_mode&0o777)
    def test_cli_reports_real_rehearsal_and_does_not_print_secrets(self):
        tool=Path(__file__).parents[1]/'tools/offline_restore_check.py'
        result=subprocess.run([sys.executable,str(tool),'--backup',str(self.archive),'--sha256',self.expected,'--workspace',str(self.root/'cli')],capture_output=True,text=True,timeout=20)
        self.assertEqual(0,result.returncode,result.stderr)
        self.assertTrue(json.loads(result.stdout)['data_restore_exercised'])
        self.assertNotIn('fixture secret never printed',result.stdout+result.stderr)
    def test_privileged_launcher_pin_and_tamper_guard(self):
        ns=runpy.run_path(str(Path(__file__).parents[1]/'docs/checkpoints/2026-10-18-remote-readiness.py'))
        tool=Path(__file__).parents[1]/'tools/offline_restore_check.py'
        self.assertEqual(sha(tool),ns['TOOL_SHA'])
        fake=self.root/'tampered.py';fake.write_text('raise AssertionError("must not execute")')
        with self.assertRaisesRegex(ValueError,'mismatch'):ns['read_ns'](fake,'0'*64)
    def test_wrong_archive_digest_rejected_before_restore(self):
        with self.assertRaisesRegex(ValueError,'digest'):check(self.archive,'0'*64,self.root/'work')
        self.assertFalse((self.root/'work').exists())
    def test_replaced_vault_key_cannot_restore_secrets(self):
        copy=self.root/'restored';restore_data(self.archive,copy)
        (copy/'var/lib/kaname-lab/secret-store.key').write_bytes(b'x'*32)
        with self.assertRaises(Exception):validate_copy(copy)
    def test_replaced_server_key_is_rejected(self):
        copy=self.root/'restored';restore_data(self.archive,copy)
        key=ec.generate_private_key(ec.SECP256R1())
        (copy/'etc/kaname-lab/web.key').write_bytes(key.private_bytes(serialization.Encoding.PEM,serialization.PrivateFormat.PKCS8,serialization.NoEncryption()))
        with self.assertRaisesRegex(ValueError,'check failed'):validate_copy(copy)
    def malicious(self,name,kind=tarfile.REGTYPE):
        archive=self.root/'unsafe.tar.gz'
        with tarfile.open(archive,'w:gz') as tar:
            entry=tarfile.TarInfo(name);entry.type=kind;entry.mode=0o600
            if kind==tarfile.SYMTYPE:entry.linkname='/etc/shadow';tar.addfile(entry)
            else:entry.size=1;tar.addfile(entry,io.BytesIO(b'x'))
        return archive
    def test_escape_and_restored_link_are_rejected(self):
        for index,(name,kind) in enumerate([('../escape',tarfile.REGTYPE),('etc/kaname-lab/key',tarfile.SYMTYPE)]):
            archive=self.malicious(name,kind)
            with self.assertRaises(ValueError):restore_data(archive,self.root/str(index))
        self.assertFalse((self.root.parent/'escape').exists())
    def test_live_workspace_is_refused(self):
        with self.assertRaisesRegex(ValueError,'Live application'):check(self.archive,self.expected,'/var/lib/kaname-lab/drill')
    def test_world_readable_workspace_refused(self):
        work=self.root/'work';work.mkdir(mode=0o755)
        with self.assertRaisesRegex(ValueError,'Private'):check(self.archive,self.expected,work)

if __name__=='__main__':unittest.main()
