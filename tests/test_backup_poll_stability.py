"""Poll churn must not mask durable job/result changes or omit archive data."""
import copy
import json
import sqlite3
import tarfile
import unittest
from unittest.mock import patch
from tests import test_scheduled_backup as fixtures
from tools import scheduled_backup as worker

class BackupPollStabilityTests(unittest.TestCase):
    db=fixtures.ScheduledBackupTests.db
    archives=fixtures.ScheduledBackupTests.archives
    def setUp(self):
        fixtures.ScheduledBackupTests.setUp(self)
        self.value={'format':1,'jobs':[{'id':'durable','state':'queued','target':{'vlan':50},'result':None}],
                    'polls':[], 'last_poll':None}
        for name in worker.POLL_SECTIONS:self.save(name,self.value)
    def save(self,name,value):
        payload=json.dumps(value) if not isinstance(value,str) else value
        with sqlite3.connect(self.db()) as db:
            db.execute('INSERT OR REPLACE INTO runtime_settings VALUES (?,?)',(name,payload))
    def activity(self,number):
        value=copy.deepcopy(self.value)
        value['polls']=[{'id':format(number,'064x'),'until':2000000000+number}]
        value['last_poll']={'scope':'a'*64,'at':1800000000+number,'release_id':'00000000-0000-4000-8000-000000000001'}
        return value
    def test_only_poll_metadata_is_ignored_for_all_three_queues(self):
        before=worker.db_fingerprint(self.db())
        for name in worker.POLL_SECTIONS:self.save(name,self.activity(1))
        self.assertEqual(before,worker.db_fingerprint(self.db()))
        for name in worker.POLL_SECTIONS:
            for change in ('new_job','lease','result','target'):
                value=self.activity(2)
                if change=='new_job':value['jobs'].append({'id':'another'})
                elif change=='lease':value['jobs'][0].update(state='leased',lease_id='b'*64)
                elif change=='result':value['jobs'][0].update(state='completed',result={'outcome':'verified'})
                else:value['jobs'][0]['target']['vlan']=100
                self.save(name,value)
                self.assertNotEqual(before,worker.db_fingerprint(self.db()),(name,change))
                self.save(name,self.activity(3))
        with sqlite3.connect(self.db()) as db:db.execute('DELETE FROM runtime_settings WHERE name=?',(name,))
        self.assertNotEqual(before,worker.db_fingerprint(self.db()))
    def test_real_archive_keeps_complete_poll_and_replay_metadata_during_churn(self):
        original=worker.inventory;calls=0
        def changing(items):
            nonlocal calls
            result=original(items);calls+=1
            for name in worker.POLL_SECTIONS:self.save(name,self.activity(calls))
            return result
        with patch.object(worker,'inventory',side_effect=changing):result=worker.run()
        self.assertTrue(result['archive_read_verified'])
        with tarfile.open(result['backup']) as archive:
            restored=self.root/'snapshot.sqlite3'
            restored.write_bytes(archive.extractfile('var/lib/kaname-lab/kaname.sqlite3').read())
        with sqlite3.connect(restored) as db:
            for name in worker.POLL_SECTIONS:
                value=json.loads(db.execute('SELECT payload FROM runtime_settings WHERE name=?',(name,)).fetchone()[0])
                self.assertEqual(self.value['jobs'],value['jobs'])
                self.assertTrue(value['polls']);self.assertIsNotNone(value['last_poll'])
            self.assertEqual([('ok',)],db.execute('PRAGMA integrity_check').fetchall())
    def test_unknown_and_malformed_payloads_keep_raw_guard(self):
        name=next(iter(worker.POLL_SECTIONS))
        bad=[self.value|{'unexpected':'retained'},self.value|{'format':2},self.value|{'polls':[{'id':'bad','until':True}]},self.value|{'last_poll':{'extra':1}},'{"format":1,"format":1}', '{"jobs":NaN}', '{bad']
        for value in bad:
            raw=json.dumps(value) if not isinstance(value,str) else value
            self.assertEqual(raw,worker.stable_runtime_payload(name,raw))
        raw=json.dumps(self.activity(1))
        self.assertEqual(raw,worker.stable_runtime_payload('windows_connector_binding',raw))
    def test_job_mutation_still_refuses_publication_under_poll_churn(self):
        original=worker.inventory;calls=0
        def changing(items):
            nonlocal calls
            result=original(items);calls+=1
            value=self.activity(calls);value['jobs'][0]['result']={'sequence':calls}
            for name in worker.POLL_SECTIONS:self.save(name,value)
            return result
        with patch.object(worker,'inventory',side_effect=changing),self.assertRaisesRegex(ValueError,'Business state'):
            worker.run()
        self.assertEqual([],self.archives())
