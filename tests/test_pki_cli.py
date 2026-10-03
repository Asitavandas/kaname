import contextlib
import io
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from kaname.pki import PKIService, main
from .test_pki import PASSWORD
from .helpers import config


class PKICLITests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.output = io.StringIO(); self.error = io.StringIO()

    def command(self, *args, passwords=()):
        argv = ['kaname.pki', '--state-dir', self.temp.name, *args]
        with patch('sys.argv', argv), patch('kaname.pki.getpass.getpass', side_effect=passwords), contextlib.redirect_stdout(self.output), contextlib.redirect_stderr(self.error):
            try: main(); return 0
            except SystemExit as exc: return exc.code

    def test_status_does_not_initialize_ca(self):
        self.assertEqual(self.command('status'), 0)
        self.assertIn('"initialized": false', self.output.getvalue())

    def test_init_confirmation_failure_preserves_empty_state(self):
        self.assertEqual(self.command('init', passwords=[PASSWORD.decode(), 'mismatch']), 1)
        self.assertFalse(PKIService(self.temp.name).store.public_pki_status()['initialized'])
        self.assertNotIn(PASSWORD.decode(), self.output.getvalue() + self.error.getvalue())

    def test_successful_init_does_not_print_passphrase(self):
        self.assertEqual(self.command('init', passwords=[PASSWORD.decode(), PASSWORD.decode()]), 0)
        self.assertTrue(PKIService(self.temp.name).store.public_pki_status()['initialized'])
        self.assertNotIn(PASSWORD.decode(), self.output.getvalue() + self.error.getvalue())
        self.assertNotIn('PRIVATE KEY', self.output.getvalue())

    def test_export_only_public_material(self):
        PKIService(self.temp.name).initialize(PASSWORD)
        destination = Path(self.temp.name) / 'public'
        self.assertEqual(self.command('export-public', str(destination)), 0)
        files = sorted(p.name for p in destination.iterdir())
        self.assertEqual(files, ['issuer-ca.pem', 'issuer-crl.pem', 'root-ca.pem'])
        for file in destination.iterdir(): self.assertNotIn(b'PRIVATE KEY', file.read_bytes())

    def test_existing_export_directory_is_preserved(self):
        PKIService(self.temp.name).initialize(PASSWORD)
        destination = Path(self.temp.name) / 'public'; destination.mkdir()
        marker = destination / 'keep.txt'; marker.write_text('existing')
        self.assertEqual(self.command('export-public', str(destination)), 1)
        self.assertEqual(marker.read_text(), 'existing')
        self.assertEqual(len(list(destination.iterdir())), 1)

    def test_invalid_csr_does_not_leave_an_output_file(self):
        service = PKIService(self.temp.name)
        service.initialize(PASSWORD); service.store.save(0, config=config())
        request = Path(self.temp.name) / 'bad.csr'; request.write_bytes(b'bad')
        destination = Path(self.temp.name) / 'result.pem'
        self.assertEqual(self.command('issue-radius', str(request), str(destination), passwords=[PASSWORD.decode()]), 1)
        self.assertFalse(destination.exists())

    def test_existing_certificate_output_is_preserved(self):
        PKIService(self.temp.name).initialize(PASSWORD)
        request = Path(self.temp.name) / 'request.csr'; request.write_bytes(b'bounded')
        destination = Path(self.temp.name) / 'keep.pem'; destination.write_bytes(b'old')
        self.assertEqual(self.command('issue-radius', str(request), str(destination), passwords=[PASSWORD.decode()]), 1)
        self.assertEqual(destination.read_bytes(), b'old')
        with PKIService(self.temp.name).store.connect() as db:
            self.assertEqual(db.execute('SELECT count(*) FROM pki_certificates').fetchone()[0], 0)
