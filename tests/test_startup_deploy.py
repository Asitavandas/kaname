"""Source-scope and no-RADIUS-restart guards for the startup installer update."""
import base64
import copy
import hashlib
from pathlib import Path
import runpy
import re
import tempfile
import unittest


class StartupDeployGuardTests(unittest.TestCase):
    def setUp(self):
        repo = Path(__file__).parents[1]
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.ns = runpy.run_path(str(repo / 'docs/checkpoints/2026-10-19-startup-update.py'))
        self.ns = self.ns['source_check'].__globals__
        self.ns['ROOT'] = self.root; self.ns['trusted'] = lambda p: p.read_bytes()
        self.base = {'kaname/__init__.py': b'VERSION = "0.14.0-dev.9"\n',
                     'kaname/radius_adapter.py': b'protected authorizer\n',
                     'kaname/device_client/AuthWire-Client.ps1': (repo / 'kaname/device_client/AuthWire-Client.ps1').read_bytes(),
                     'kaname/device_client/Install-AuthWire.ps1': b'accepted old installer\n'}
        # This historical checkpoint admits exactly the reviewed dev10 template,
        # even after a later release changes the current installer source.
        frozen = (repo / 'docs/checkpoints/2026-10-19-sysvol-installer-update.ps1').read_text()
        encoded = re.search(r"FromBase64String\('([A-Za-z0-9+/=]+)'\)", frozen).group(1)
        self.files = {**self.base, 'kaname/__init__.py': b'VERSION = "0.14.0-dev.10"\n',
                      'kaname/device_client/Install-AuthWire.ps1': base64.b64decode(encoded)}
        self.ns['BASELINE'] = {k: hashlib.sha256(v).hexdigest() for k, v in self.base.items()}
        self.write(self.base)

    def write(self, values):
        for name, value in values.items():
            p = self.root / name; p.parent.mkdir(parents=True, exist_ok=True); p.write_bytes(value)

    def test_only_exact_installer_change_is_accepted_from_old_and_current_source(self):
        self.ns['source_check'](self.files)
        self.write(self.files); self.ns['source_check'](self.files)

    def test_changed_client_or_unreviewed_installer_is_refused(self):
        for name, reason in [('kaname/device_client/AuthWire-Client.ps1', 'CLIENT_SOURCE_CHANGED'),
                             ('kaname/device_client/Install-AuthWire.ps1', 'UNREVIEWED_INSTALLER_SOURCE')]:
            files = dict(self.files); files[name] += b'# unexpected change\n'
            self.write(files)
            with self.assertRaisesRegex(ValueError, reason): self.ns['source_check'](files)

    def test_authorizer_change_is_refused_even_if_already_installed(self):
        files = dict(self.files); files['kaname/radius_adapter.py'] += b'changed\n'
        self.write(files)
        with self.assertRaisesRegex(ValueError, 'AUTHENTICATION_SOURCE_CHANGE_REFUSED'): self.ns['source_check'](files)

    def test_installed_source_drift_is_refused(self):
        self.write({'kaname/radius_adapter.py': b'operator drift\n'})
        with self.assertRaisesRegex(ValueError, 'INSTALLED_SOURCE_DRIFT'): self.ns['source_check'](self.files)

    def test_preservation_allows_only_installer_bytes_and_never_radius_restart(self):
        name = '/opt/kaname-lab/source/kaname/device_client/Install-AuthWire.ps1'
        before = {'files': {name: ['old', 0o644, 0, 0], '/native-module': ['same', 0o644, 0, 0]},
                  'pids': {'authwire-radius.service': '326873', 'broker': '149955'},
                  'timers': {'crl': 'active', 'backup': 'active'}, 'business_state': {'policy': 'same'}}
        after = copy.deepcopy(before)
        after['files'][name][0] = hashlib.sha256(self.files['kaname/device_client/Install-AuthWire.ps1']).hexdigest()
        self.assertTrue(all(self.ns['preservation'](before, after, self.files).values()))
        for category, key, value in [('pids', 'authwire-radius.service', 'new-pid'),
                                     ('files', '/native-module', ['changed', 0o644, 0, 0]),
                                     ('business_state', 'policy', 'changed')]:
            bad = copy.deepcopy(after); bad[category][key] = value
            self.assertFalse(self.ns['preservation'](before, bad, self.files)[category])


if __name__ == '__main__': unittest.main()
