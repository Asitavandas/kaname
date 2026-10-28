"""Pinned worker bytes and reversible atomic source publication primitives."""
import base64
import hashlib
import importlib.util
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT=Path(__file__).resolve().parents[1]
class BackupPollDeliveryTests(unittest.TestCase):
    def setUp(self):
        spec=importlib.util.spec_from_file_location('backup_poll_delivery',ROOT/'docs/checkpoints/2026-10-28-backup-poll-fix-r2.py')
        self.module=importlib.util.module_from_spec(spec);spec.loader.exec_module(self.module)
    def test_embedded_worker_exactly_matches_reviewed_source(self):
        raw=base64.b64decode(self.module.PAYLOAD,validate=True)
        self.assertEqual(hashlib.sha256(raw).hexdigest(),'c18bfafecbefb136d0d5bca0b0994c373629708d19c100040b383e673edc697c') # Frozen r2 delivery, not the new four-queue worker.
        self.assertEqual(hashlib.sha256(raw).hexdigest(),self.module.NEW)
        compile(raw,'worker','exec')
    def test_atomic_write_preserves_old_content_if_fsync_fails(self):
        with tempfile.TemporaryDirectory() as root:
            p=Path(root)/'worker';p.write_bytes(b'old');p.chmod(0o640)
            with patch.object(self.module.os,'fsync',side_effect=OSError('failure')):
                with self.assertRaises(OSError):self.module.atomic(p,b'new',p.stat())
            self.assertEqual(p.read_bytes(),b'old')
            self.assertEqual(list(Path(root).iterdir()),[p])
    def test_successful_atomic_write_keeps_existing_mode(self):
        with tempfile.TemporaryDirectory() as root:
            p=Path(root)/'worker';p.write_bytes(b'old');p.chmod(0o640)
            self.module.atomic(p,b'new',p.stat())
            self.assertEqual(p.read_bytes(),b'new')
            self.assertEqual(p.stat().st_mode&0o777,0o640)
            self.assertEqual(list(Path(root).iterdir()),[p])
