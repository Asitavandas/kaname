"""Panel-only delivery must preserve Windows, authorization, and live policy state."""
import copy
import hashlib
from pathlib import Path
import runpy
import tempfile
import unittest


class PolicyToggleDeployTests(unittest.TestCase):
    def setUp(self):
        repo = Path(__file__).parents[1]
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.ns = runpy.run_path(str(repo / 'docs/checkpoints/2026-10-21-policy-toggle-update.py'))
        self.ns = self.ns['source_check'].__globals__
        self.ns['ROOT'] = self.root
        self.ns['trusted'] = lambda p: p.read_bytes()
        self.base = {'kaname/__init__.py': b'VERSION = "0.14.0-dev.12"\n',
                     'kaname/static/app.js': b'accepted UI\n',
                     'kaname/radius_adapter.py': b'protected authorizer\n',
                     **{f'kaname/device_client/{name}': (repo / 'kaname/device_client' / name).read_bytes()
                        for name in ('AuthWire-Client.ps1', 'Install-AuthWire.ps1')}}
        self.files = {**self.base, 'kaname/__init__.py': b'VERSION = "0.14.0-dev.13"\n',
                      'kaname/static/app.js': b'reviewed toggle UI\n'}
        self.ns['BASELINE'] = {n: hashlib.sha256(b).hexdigest() for n, b in self.base.items()}
        self.write(self.base)

    def write(self, files):
        for name, data in files.items():
            p = self.root / name
            p.parent.mkdir(parents=True, exist_ok=True)
            p.write_bytes(data)

    def test_panel_update_or_exact_retry_accepted(self):
        self.ns['source_check'](self.files)
        self.write(self.files)
        self.ns['source_check'](self.files)

    def test_authorizer_or_windows_change_rejected_even_if_installed(self):
        for name, code in [('kaname/radius_adapter.py', 'AUTHENTICATION_SOURCE_CHANGE_REFUSED'),
                           ('kaname/device_client/AuthWire-Client.ps1', 'UNREVIEWED_CLIENT_SOURCE'),
                           ('kaname/device_client/Install-AuthWire.ps1', 'UNREVIEWED_INSTALLER_SOURCE')]:
            with self.subTest(name=name):
                changed = {**self.files, name: self.files[name] + b'# change\n'}
                self.write(changed)
                with self.assertRaisesRegex(ValueError, code):
                    self.ns['source_check'](changed)
                self.write(self.base)

    def test_drift_removal_and_wrong_release_rejected(self):
        self.write({'kaname/static/app.js': b'operator drift\n'})
        with self.assertRaisesRegex(ValueError, 'INSTALLED_SOURCE_DRIFT'):
            self.ns['source_check'](self.files)
        self.write(self.base)
        for changed, code in [({k: v for k, v in self.files.items() if k != 'kaname/radius_adapter.py'}, 'BASE_SOURCE_REMOVAL_REFUSED'),
                              ({**self.files, 'kaname/__init__.py': b'VERSION="other"\n'}, 'UNEXPECTED_CANDIDATE_VERSION')]:
            with self.assertRaisesRegex(ValueError, code):
                self.ns['source_check'](changed)

    def test_no_protected_file_pid_timer_or_policy_change_allowed(self):
        before = {'files': {'client': ['same', 0o644, 0, 0], 'CA': ['same', 0o600, 0, 0], 'native': ['same', 0o644, 0, 0]},
                  'pids': {'radius': '326873', 'broker': '149955'},
                  'timers': {'crl': 'active', 'backup': 'active'}, 'business_state': {'policies': 'enabled VLAN140'}}
        self.assertTrue(all(self.ns['preservation'](before, copy.deepcopy(before), self.files).values()))
        for category in before:
            after = copy.deepcopy(before)
            after[category][next(iter(after[category]))] = 'changed'
            self.assertFalse(self.ns['preservation'](before, after, self.files)[category])

    def test_unpinned_deployer_cannot_apply(self):
        with self.assertRaisesRegex(ValueError, 'RELEASE_NOT_PINNED'):
            self.ns['main']()


if __name__ == '__main__':
    unittest.main()
