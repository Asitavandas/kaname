"""Disposable IPC bridge exercises the real expiry/new-CSR/receipt path."""
import base64
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest
import uuid

from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import ec

from .test_enrollment import request


class ExpiredFixtureBridgeTests(unittest.TestCase):
    def test_private_owner_bridge_rejects_expired_pending_then_accepts_fresh_key(self):
        with tempfile.TemporaryDirectory(prefix='authwire-ci-expired-') as directory:
            root = Path(directory)
            for name in ('CI_FIXTURE_ONLY', 'EXPIRED_RECOVERY_FIXTURE_ONLY'):
                (root / name).touch()
            key = ec.generate_private_key(ec.SECP256R1())
            (root / 'request.pem').write_bytes(request(key))

            def run(module, step):
                result = subprocess.run([sys.executable, '-m', module, '--root', str(root), '--step', step],
                                        text=True, capture_output=True, timeout=15)
                self.assertEqual(0, result.returncode, result.stderr)
                return json.loads(result.stdout)

            def proof(private, payload):
                return base64.b64encode(private.sign(base64.b64decode(payload), ec.ECDSA(hashes.SHA256()))).decode()

            run('tools.device_fixture', 'challenge')
            challenge = json.loads((root / 'challenge.json').read_text())
            (root / 'proof.txt').write_text(proof(key, challenge['payload']))
            run('tools.device_fixture', 'issue')
            old = json.loads((root / 'issued.json').read_text())
            run('tools.device_expired_fixture', 'expire')
            profile = json.loads((root / 'profile.json').read_text())
            process = subprocess.Popen([sys.executable, '-m', 'tools.device_expired_fixture',
                                        '--root', str(root), '--step', 'serve'],
                                       stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
            try:
                until = time.monotonic() + 15
                while not (root / 'bridge-ready').exists() and process.poll() is None and time.monotonic() < until:
                    time.sleep(0.05)
                self.assertTrue((root / 'bridge-ready').exists(), 'Owner bridge did not start')

                def call(path, body):
                    identifier = uuid.uuid4().hex
                    temporary = root / 'bridge-request.tmp'
                    temporary.write_text(json.dumps({'id': identifier, 'path': path, 'body': body}))
                    os.replace(temporary, root / 'bridge-request.json')
                    until = time.monotonic() + 10
                    while time.monotonic() < until:
                        target = root / 'bridge-response.json'
                        if target.exists():
                            response = json.loads(target.read_text())
                            if response['id'] == identifier:
                                return response['body']
                        if process.poll() is not None:
                            self.fail('Owner bridge exited during dispatch')
                        time.sleep(0.05)
                    self.fail('Owner bridge response timed out')

                old_csr = (root / 'request.pem').read_text()
                ch = call('/api/device/challenge', {'profile_id': profile['id'], 'csr': old_csr})
                expired = call('/api/device/issue', {'challenge_id': ch['challenge_id'],
                               'csr': old_csr, 'proof': proof(key, ch['payload'])})
                self.assertEqual({'fixture_error': 'DEVICE_CERTIFICATE_EXPIRED'}, expired)
                fresh = ec.generate_private_key(ec.SECP256R1())
                csr = request(fresh).decode()
                ch = call('/api/device/challenge', {'profile_id': profile['id'], 'csr': csr})
                issued = call('/api/device/issue', {'challenge_id': ch['challenge_id'], 'csr': csr,
                              'proof': proof(fresh, ch['payload'])})
                self.assertNotEqual(old['serial'], issued['serial'])
                installed = call('/api/device/receipt', {'serial': issued['serial'],
                                 'proof': proof(fresh, issued['receipt_payload'])})
                self.assertTrue(installed['installed'])
            finally:
                (root / 'bridge-stop').touch()
                try:
                    out, error = process.communicate(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    out, error = process.communicate(timeout=5)
            self.assertEqual(0, process.returncode, error)
