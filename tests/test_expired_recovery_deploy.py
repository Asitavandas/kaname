"""Narrow source and live-state preservation gates for expired-pending delivery."""
import base64
import copy
import hashlib
from pathlib import Path
import runpy
import re
import tempfile
import unittest


class ExpiredRecoveryDeployTests(unittest.TestCase):
    def setUp(self):
        repo = Path(__file__).parents[1]
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.ns = runpy.run_path(str(repo / 'docs/checkpoints/2026-10-21-expired-recovery-update.py'))
        self.ns = self.ns['source_check'].__globals__
        self.ns['ROOT'] = self.root
        self.ns['trusted'] = lambda p: p.read_bytes()
        old_client = (repo / 'docs/checkpoints/2026-10-19-authwire-client-dev11.ps1').read_bytes()
        new_client = (repo / 'kaname/device_client/AuthWire-Client.ps1').read_bytes()
        # Frozen source admitted by this historical deployment guard.
        installer = (repo / 'docs/checkpoints/2026-10-19-authwire-installer-dev11.ps1').read_bytes()
        self.base = {'kaname/__init__.py': b'VERSION = "0.14.0-dev.11"\n',
                     'kaname/radius_adapter.py': b'protected authorizer\n',
                     'kaname/device_client/AuthWire-Client.ps1': old_client,
                     'kaname/device_client/Install-AuthWire.ps1': installer}
        self.files = {**self.base, 'kaname/__init__.py': b'VERSION = "0.14.0-dev.12"\n',
                      'kaname/device_client/AuthWire-Client.ps1': new_client}
        self.ns['BASELINE'] = {n: hashlib.sha256(b).hexdigest() for n, b in self.base.items()}
        self.write(self.base)

    def write(self, files):
        for n, b in files.items():
            p = self.root / n
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_bytes(b)

    def test_only_reviewed_client_change_from_accepted_or_current_source(self):
        self.ns['source_check'](self.files)
        self.write(self.files)
        self.ns['source_check'](self.files)

    def test_unreviewed_client_or_installer_is_rejected(self):
        for n, code in [('kaname/device_client/AuthWire-Client.ps1', 'UNREVIEWED_CLIENT_SOURCE'),
                        ('kaname/device_client/Install-AuthWire.ps1', 'UNREVIEWED_INSTALLER_SOURCE')]:
            changed = dict(self.files)
            changed[n] += b'# unreviewed change\n'
            with self.assertRaisesRegex(ValueError, code):
                self.ns['source_check'](changed)

    def test_authorizer_change_even_when_installed_is_rejected(self):
        changed = dict(self.files)
        changed['kaname/radius_adapter.py'] += b'changed\n'
        self.write(changed)
        with self.assertRaisesRegex(ValueError, 'AUTHENTICATION_SOURCE_CHANGE_REFUSED'):
            self.ns['source_check'](changed)

    def test_installed_drift_missing_base_and_wrong_release_are_rejected(self):
        self.write({'kaname/radius_adapter.py': b'operator drift\n'})
        with self.assertRaisesRegex(ValueError, 'INSTALLED_SOURCE_DRIFT'):
            self.ns['source_check'](self.files)
        self.write(self.base)
        removed = dict(self.files)
        del removed['kaname/radius_adapter.py']
        with self.assertRaisesRegex(ValueError, 'BASE_SOURCE_REMOVAL_REFUSED'):
            self.ns['source_check'](removed)
        wrong = {**self.files, 'kaname/__init__.py': b'VERSION = "other"\n'}
        with self.assertRaisesRegex(ValueError, 'UNEXPECTED_CANDIDATE_VERSION'):
            self.ns['source_check'](wrong)

    def test_client_bytes_may_change_but_metadata_installer_state_processes_and_timers_may_not(self):
        client = '/opt/kaname-lab/source/kaname/device_client/AuthWire-Client.ps1'
        installer = '/opt/kaname-lab/source/kaname/device_client/Install-AuthWire.ps1'
        before = {'files': {client: ['old', 0o644, 0, 0], installer: ['same', 0o644, 0, 0],
                            '/native-module': ['same', 0o644, 0, 0]},
                  'pids': {'authwire-radius.service': '326873', 'broker': '149955'},
                  'timers': {'crl': 'active', 'backup': 'active'}, 'business_state': {'policy': 'same'}}
        after = copy.deepcopy(before)
        after['files'][client][0] = hashlib.sha256(self.files['kaname/device_client/AuthWire-Client.ps1']).hexdigest()
        self.assertTrue(all(self.ns['preservation'](before, after, self.files).values()))
        for category, key, value in [('files', client, ['new', 0o666, 0, 0]),
                                     ('files', installer, ['changed', 0o644, 0, 0]),
                                     ('files', '/native-module', ['changed', 0o644, 0, 0]),
                                     ('pids', 'authwire-radius.service', 'new'),
                                     ('timers', 'crl', 'inactive'),
                                     ('business_state', 'policy', 'changed')]:
            bad = copy.deepcopy(after)
            bad[category][key] = value
            self.assertFalse(self.ns['preservation'](before, bad, self.files)[category])

    def test_sysvol_payload_is_exact_reviewed_client_and_auditor(self):
        repo = Path(__file__).parents[1]
        helper = (repo / 'docs/checkpoints/2026-10-21-sysvol-client-update.ps1').read_text()
        for name, path in [('awTemplate', 'kaname/device_client/AuthWire-Client.ps1'),
                           ('awAudit', 'tools/AuthWire-GPO-Audit.ps1')]:
            match = re.search(r'\$script:' + name + r"=.*?FromBase64String\('([A-Za-z0-9+/=]+)'\)", helper)
            self.assertIsNotNone(match)
            self.assertEqual(base64.b64decode(match[1]), (repo / path).read_bytes())

    def test_unpinned_deployer_cannot_apply(self):
        with self.assertRaisesRegex(ValueError, 'RELEASE_NOT_PINNED'):
            self.ns['main']()


if __name__ == '__main__':
    unittest.main()
