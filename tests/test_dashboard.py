"""Read-only dashboard aggregate, authorization and failure-isolation checks."""
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from kaname.dashboard import summary
from kaname import radius_events
from tools import service_control_broker as broker
from .test_radius_events import event
from . import test_admin as admins

NOW=datetime(2026,10,22,12,tzinfo=timezone.utc)

class DashboardTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory();self.addCleanup(self.temp.cleanup);self.root=Path(self.temp.name)
    def test_empty_does_not_create_files(self):
        value=summary(self.root,certificates=False,now=NOW)
        self.assertTrue(value['events']['available']);self.assertFalse(value['events']['initialized'])
        self.assertFalse(list(self.root.iterdir()));self.assertFalse(value['coverage']['accounting_sessions'])
    def test_aggregates_all_rows_snapshot_and_istanbul_boundary(self):
        path=radius_events.initialize(self.root)
        for n in range(205):
            radius_events.append(self.root,event(n,at='2026-10-21T22:00:00.000Z',response_code=2 if n%2 else 3,vlan=110 if n%2 else None))
        radius_events.append(self.root,event(300,at='2026-10-15T20:59:59.999Z'))
        radius_events.append(self.root,event(301,at='2026-10-22T12:00:00.000Z'))
        before=hashlib.sha256(path.read_bytes()).hexdigest()
        result=summary(self.root,'7d',certificates=False,now=NOW,network={'radius_clients':[{'ip':'192.0.2.2','name':'SW1','access_type':'wired'}]})
        e=result['events'];self.assertEqual((e['total'],e['accept'],e['reject']),(205,102,103));self.assertEqual(len(e['recent']),8)
        self.assertEqual(sum(r['accept']+r['reject'] for r in e['series']),205);self.assertEqual(e['heatmap'],[{'day':3,'hour':1,'count':205}])
        self.assertEqual(e['access_types'][0]['count'],205);self.assertEqual(e['nas'][0]['name'],'SW1')
        self.assertEqual(before,hashlib.sha256(path.read_bytes()).hexdigest())
        e=summary(self.root,'7d',certificates=False,now=NOW)['events'];self.assertEqual(e['access_types'][2]['count'],205);self.assertNotIn('SW1',str(e))
    def test_writer_can_append_between_watermarked_batches(self):
        import kaname.dashboard as dashboard
        radius_events.initialize(self.root)
        for n in range(600):radius_events.append(self.root,event(n,at='2026-10-22T11:00:00.000Z'))
        original=dashboard.readonly;injected=[]
        class Reader:
            def __init__(reader,path):reader.db=original(path)
            def execute(reader,sql,args=()):
                cursor=reader.db.execute(sql,args)
                if not sql.startswith('SELECT id,at,'):return cursor
                class Batch:
                    def fetchall(batch):
                        rows=cursor.fetchall()
                        if not injected:
                            injected.append(True)
                            radius_events.append(self.root,event(999,at='2026-10-22T11:30:00.000Z'))
                        return rows
                return Batch()
            def close(reader):reader.db.close()
        with patch.object(dashboard,'readonly',Reader):value=summary(self.root,certificates=False,now=NOW)['events']
        self.assertTrue(value['available']);self.assertEqual(value['total'],600);self.assertEqual(value['watermark'],600)
        self.assertEqual(radius_events.history(self.root,{},runtime=None)['storage']['records'],601)

    def test_invalid_period_and_storage_failure_isolated(self):
        with self.assertRaises(ValueError):summary(self.root,'all',now=NOW)
        radius_events.initialize(self.root).write_bytes(b'broken')
        value=summary(self.root,certificates=False,now=NOW);self.assertFalse(value['events']['available']);self.assertNotIn('broken',str(value))
        value=summary(self.root,events=False,certificates=False,now=NOW);self.assertIsNone(value['events']);self.assertIsNone(value['certificates'])
    def test_rolling_24h_series_and_date_bins(self):
        radius_events.initialize(self.root)
        radius_events.append(self.root,event(1,at='2026-10-21T12:00:00.000Z'))
        e=summary(self.root,'24h',now=NOW,certificates=False)['events']
        self.assertEqual(e['total'],1);self.assertEqual(sum(r['accept'] for r in e['series']),1)
        self.assertEqual(len(e['series']),24)

    def test_one_hour_minute_bins_exact_edges_and_partial_minute(self):
        now=datetime(2026,10,22,12,0,30,tzinfo=timezone.utc)
        radius_events.initialize(self.root)
        for n,at in enumerate(['2026-10-22T11:00:29.999Z','2026-10-22T11:00:30.000Z',
                               '2026-10-22T11:15:14.000Z','2026-10-22T12:00:29.999Z',
                               '2026-10-22T12:00:30.000Z']):
            radius_events.append(self.root,event(n,at=at,response_code=3 if n==2 else 2,vlan=None if n==2 else 110))
        value=summary(self.root,'1h',certificates=False,now=now);e=value['events']
        self.assertEqual(value['from'],'2026-10-22T11:00:30.000Z')
        self.assertEqual((e['total'],e['accept'],e['reject']),(3,2,1))
        self.assertEqual(len(e['series']),61)
        self.assertEqual(sum(r['accept']+r['reject'] for r in e['series']),3)
        self.assertEqual(e['series'][0]['accept'],1);self.assertEqual(e['series'][-1]['accept'],1)

    def test_calendar_periods_clamp_month_end_and_preserve_istanbul_boundaries(self):
        radius_events.initialize(self.root)
        now=datetime(2024,8,31,22,15,tzinfo=timezone.utc) # September 1 in Istanbul.
        cases=[('6m',now,'2024-02-29T21:00:00.000Z'),
               ('6m',datetime(2026,8,31,12,tzinfo=timezone.utc),'2026-02-27T21:00:00.000Z'),
               ('1y',datetime(2024,2,29,12,tzinfo=timezone.utc),'2023-02-27T21:00:00.000Z')]
        for period,current,start in cases:
            with self.subTest(period=period,now=current):
                value=summary(self.root,period,certificates=False,now=current)
                self.assertEqual(value['from'],start)
                self.assertTrue(value['events']['available'])
                self.assertLessEqual(len(value['events']['series']),367)
        # Long-range totals include every retained row in range, without sampling.
        for n,at in enumerate(['2026-04-21T21:00:00.000Z','2026-04-21T20:59:59.999Z',
                               '2025-10-21T21:00:00.000Z','2026-10-22T12:00:00.000Z']):
            radius_events.append(self.root,event(n,at=at))
        self.assertEqual(summary(self.root,'6m',certificates=False,now=NOW)['events']['total'],1)
        yearly=summary(self.root,'1y',certificates=False,now=NOW)['events']
        self.assertEqual(yearly['total'],3)
        self.assertEqual(sum(r['accept']+r['reject'] for r in yearly['series']),3)
    def test_certificate_totals_skip_revoked_expired_future_and_server(self):
        import sqlite3
        from datetime import timedelta
        from cryptography import x509
        from cryptography.hazmat.primitives import hashes,serialization
        from cryptography.hazmat.primitives.asymmetric import ec
        from cryptography.x509.oid import NameOID
        key=ec.generate_private_key(ec.SECP256R1())
        name=x509.Name([x509.NameAttribute(NameOID.COMMON_NAME,'fixture')])
        with sqlite3.connect(self.root/'kaname.sqlite3') as db:
            db.execute('CREATE TABLE pki_certificates(serial TEXT,certificate BLOB,revoked_at TEXT,archived_at TEXT)')
            db.execute('CREATE TABLE radius_certificate_bindings(serial TEXT,kind TEXT)')
            for n,(days,kind,revoked,archived,future) in enumerate([(90,'computer',False,False,False),(10,'computer',False,False,False),(-1,'computer',False,False,False),(5,'computer',True,False,False),(5,'computer',False,True,False),(5,'radius-server',False,False,False),(10,'computer',False,False,True)],1):
                cert=(x509.CertificateBuilder().subject_name(name).issuer_name(name).public_key(key.public_key()).serial_number(n).not_valid_before(NOW+timedelta(days=1) if future else NOW-timedelta(days=10)).not_valid_after(NOW+timedelta(days=days)).sign(key,hashes.SHA256()))
                db.execute('INSERT INTO pki_certificates VALUES(?,?,?,?)',(str(n),cert.public_bytes(serialization.Encoding.PEM),'revoked' if revoked else None,'archived' if archived else None))
                db.execute('INSERT INTO radius_certificate_bindings VALUES(?,?)',(str(n),kind))
        value=summary(self.root,events=False,now=NOW)['certificates']
        self.assertTrue(value['available']);self.assertEqual(value['valid_computers'],2);self.assertEqual(value['expiring_computers'],1)

    def test_backup_projection_fixed_metadata_and_no_raw_fields(self):
        with tempfile.TemporaryDirectory() as folder:
            p=Path(folder);good={'producer':'authwire-scheduled-backup-v1','event':'BACKUP_SUCCESS','created_utc':NOW.isoformat(),'archive_read_verified':True,'sqlite_integrity_verified':True,'backup':'secret/path','sha256':'private'}
            for name in ['last-run.json','last-success.json']:(p/name).write_text(json.dumps(good))
            # Fixture ancestors include /tmp; replace ownership/mode check for this isolated probe only.
            real=Path.lstat
            def info(path):
                r=real(path)
                from types import SimpleNamespace
                return SimpleNamespace(st_mode=r.st_mode & ~0o022,st_uid=0)
            real_fstat=broker.os.fstat
            def fstat(fd):
                r=real_fstat(fd)
                from types import SimpleNamespace
                return SimpleNamespace(st_mode=r.st_mode,st_uid=0,st_size=r.st_size)
            with patch.object(broker,'BACKUP_STATUS_ROOT',p),patch.object(Path,'lstat',info),patch.object(broker.os,'fstat',fstat):
                value=broker.backup_status();self.assertTrue(value['available']);self.assertNotIn('secret',str(value));self.assertNotIn('private',str(value))
                (p/'last-run.json').write_text(json.dumps({**good,'event':'BACKUP_FAILED'}));self.assertFalse(broker.backup_status()['last_run_succeeded'])
                (p/'last-run.json').write_text('{}');self.assertFalse(broker.backup_status()['available'])

class DashboardHTTPTests(unittest.TestCase):
    setUp=admins.AdministratorHTTPTests.setUp
    close=admins.AdministratorHTTPTests.close
    call=admins.AdministratorHTTPTests.call
    system=admins.AdministratorHTTPTests.system
    create_profile=admins.AdministratorHTTPTests.create_profile
    user=admins.AdministratorHTTPTests.user
    login=admins.AdministratorHTTPTests.login
    def test_anonymous_denied_and_query_validation(self):
        self.assertEqual(self.call('GET','/api/dashboard',auth=None)[0],401)
        for path in ['/api/dashboard?period=all','/api/dashboard?period=7d&period=30d','/api/dashboard?path=/etc/passwd']:
            self.assertEqual(self.call('GET',path)[0],400)
        self.assertEqual(self.call('GET','/api/auth/session')[0],200)
        for period in ('1h','24h','7d','30d','6m','1y'):
            with self.subTest(period=period):
                code,value,_=self.call('GET','/api/dashboard?period='+period)
                self.assertEqual(code,200);self.assertEqual(value['period'],period)
    def test_sections_respect_permissions_without_data_leak(self):
        profile=self.create_profile('History',{'audit.events':'read'});self.user('reader',profile);pair=self.login('reader')
        code,value,_=self.call('GET','/api/dashboard',auth=pair);self.assertEqual(code,200);self.assertIsNone(value['certificates']);self.assertIsNotNone(value['events'])
        profile=self.create_profile('Policies',{'policies.rules':'read'});self.user('policy-reader',profile);pair=self.login('policy-reader')
        self.assertEqual(self.call('GET','/api/dashboard',auth=pair)[0],403)
        profile=self.create_profile('Certificates',{'certificates.authority':'read'});self.user('cert-reader',profile);pair=self.login('cert-reader')
        code,value,_=self.call('GET','/api/dashboard',auth=pair);self.assertEqual(code,200);self.assertIsNone(value['events']);self.assertIsNotNone(value['certificates'])
    def test_read_does_not_mutate_business_state(self):
        before=self.server.store.snapshot()
        code,_,_=self.call('GET','/api/dashboard?period=30d');self.assertEqual(code,200)
        self.assertEqual(before,self.server.store.snapshot())

if __name__=='__main__':unittest.main()
