"""Fixed pilot helper: exact embedded library, public-only inspection and safe output."""
import base64
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
HELPER = ROOT/'docs/checkpoints/2026-10-28-linux-machine-bundle-export.py'

class MachineBundleDeliveryTests(unittest.TestCase):
    def setUp(self):
        spec = importlib.util.spec_from_file_location('bundle_export_delivery', HELPER)
        self.helper = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.helper)

    def test_embedded_library_exactly_matches_reviewed_source(self):
        raw = base64.b64decode(self.helper.LIBRARY, validate=True)
        self.assertEqual(raw, (ROOT/'kaname/deployment_bundle.py').read_bytes())
        self.assertEqual(hashlib.sha256(raw).hexdigest(), self.helper.LIBRARY_SHA)
        compile(raw, '<bundle>', 'exec')

    @unittest.skipUnless(os.name == 'posix', 'Linux output semantics')
    def test_output_exclusive_private_and_preserves_existing_file(self):
        with tempfile.TemporaryDirectory() as root:
            path = Path(root)/'draft.zip'
            self.helper.publish_new(path,b'first',os.getuid(),os.getgid())
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)
            with self.assertRaises(FileExistsError):
                self.helper.publish_new(path,b'second',os.getuid(),os.getgid())
            self.assertEqual(path.read_bytes(), b'first')

    @unittest.skipUnless(os.name == 'posix', 'Linux output semantics')
    def test_symlink_target_never_written(self):
        with tempfile.TemporaryDirectory() as root:
            target = Path(root)/'target';target.write_bytes(b'keep')
            link = Path(root)/'link';link.symlink_to(target)
            with self.assertRaises(FileExistsError):
                self.helper.publish_new(link,b'bad',os.getuid(),os.getgid())
            self.assertEqual(target.read_bytes(),b'keep')

    @unittest.skipUnless(os.name == 'posix', 'Linux output semantics')
    def test_failed_write_removes_only_new_output(self):
        with tempfile.TemporaryDirectory() as root:
            path = Path(root)/'draft.zip'
            with patch.object(self.helper.os,'fsync',side_effect=OSError('disk failure')):
                with self.assertRaises(OSError):
                    self.helper.publish_new(path,b'data',os.getuid(),os.getgid())
            self.assertFalse(path.exists())

    def test_public_inspection_never_opens_database_or_tls(self):
        with patch.object(self.helper,'public_preflight',return_value=(b'zip',b'library')), \
             patch.object(self.helper.sys,'argv',['helper','--inspect-public']), \
             patch.object(self.helper.sqlite3,'connect',side_effect=AssertionError('DB opened')), \
             patch.object(self.helper,'regular',side_effect=AssertionError('TLS opened')), \
             patch('builtins.print') as output:
            self.helper.main()
        value=json.loads(output.call_args.args[0])
        self.assertFalse(value['private_database_opened'])
        self.assertFalse(value['tls_file_opened'])
        self.assertFalse(value['output_created'])

    def test_export_requires_operator_sudo_before_private_reads(self):
        with patch.object(self.helper,'public_preflight',return_value=(b'zip',b'library')), \
             patch.object(self.helper.sys,'argv',['helper']), \
             patch.object(self.helper.os,'geteuid',return_value=1000), \
             patch.object(self.helper.sqlite3,'connect',side_effect=AssertionError('DB opened')):
            with self.assertRaisesRegex(ValueError,'OPERATOR_SUDO_REQUIRED'):
                self.helper.main()
