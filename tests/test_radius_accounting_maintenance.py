"""Retention preserves open sessions and requires an archive before deletion."""
from contextlib import closing
from datetime import datetime, timezone
import hashlib
from pathlib import Path
import sqlite3
import tempfile
import unittest
from unittest.mock import patch

from kaname.radius_accounting import AccountingStorageError, initialize, ingest, paths
from kaname.radius_accounting_maintenance import maintain
from tests.test_radius_accounting import packet


class AccountingMaintenanceTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.state = Path(temp.name) / 'state'
        self.state.mkdir(mode=0o700)
        self.archive = Path(temp.name) / 'archive'
        self.archive.mkdir(mode=0o700)
        initialize(self.state)
        self.db = paths(self.state)[1]
        self.now = datetime(2026, 11, 13, tzinfo=timezone.utc)
        for number, status, session, at in (
            (1, 'Start', 'old-closed', '2026-08-01'),
            (2, 'Stop', 'old-closed', '2026-08-01'),
            (3, 'Start', 'old-open', '2026-08-01'),
            (4, 'Interim-Update', 'old-open', '2026-08-02'),
            (5, 'Stop', 'old-orphan', '2026-08-01'),
            (6, 'Start', 'recently-closed', '2026-08-01'),
            (7, 'Stop', 'recently-closed', '2026-11-10'),
        ):
            with patch('kaname.radius_accounting.datetime') as clock:
                clock.now.return_value = datetime.fromisoformat(at).replace(tzinfo=timezone.utc)
                ingest(self.state, packet('127.0.0.2', f'0x{number:032x}', status, session))

    def count(self, database, table):
        with closing(sqlite3.connect(database)) as db:
            return db.execute('SELECT count(*) FROM accounting_' + table).fetchone()[0]

    def test_preview_is_read_only_then_archive_and_prune(self):
        before = self.db.read_bytes()
        preview = maintain(self.state, keep_days=30, now=self.now)
        self.assertEqual({'events': 3, 'sessions': 1}, preview['eligible'])
        self.assertFalse(preview['applied'])
        self.assertEqual(before, self.db.read_bytes())
        self.assertEqual([], list(self.archive.iterdir()))

        result = maintain(self.state, keep_days=30, now=self.now, archive_dir=self.archive)
        archived = self.archive / result['archive']
        self.assertTrue(result['applied'])
        self.assertEqual(result['sha256'], hashlib.sha256(archived.read_bytes()).hexdigest())
        self.assertEqual(0o600, archived.stat().st_mode & 0o777)
        self.assertEqual(7, self.count(archived, 'events'))
        self.assertEqual(3, self.count(archived, 'sessions'))
        with closing(sqlite3.connect(self.db)) as db:
            self.assertEqual(['old-open', 'recently-closed'], [
                row[0] for row in db.execute('SELECT session_id FROM accounting_sessions ORDER BY id')])
        self.assertEqual(4, self.count(self.db, 'events'))
        self.assertFalse(maintain(self.state, keep_days=30, now=self.now,
                                  archive_dir=self.archive)['applied'])
        self.assertEqual([archived], list(self.archive.iterdir()))

    def test_archive_failure_rolls_back_cleanup(self):
        with patch('kaname.radius_accounting_maintenance._archive', side_effect=OSError):
            with self.assertRaises(OSError):
                maintain(self.state, keep_days=30, now=self.now, archive_dir=self.archive)
        self.assertEqual(7, self.count(self.db, 'events'))
        self.assertEqual(3, self.count(self.db, 'sessions'))

    def test_unsafe_archive_directory_is_rejected(self):
        self.archive.chmod(0o755)
        with self.assertRaisesRegex(AccountingStorageError, 'UNSAFE_STORAGE'):
            maintain(self.state, keep_days=30, now=self.now, archive_dir=self.archive)
        self.assertEqual(7, self.count(self.db, 'events'))
