"""Pinned operator launcher's source guard rejects drift and scope expansion."""
import hashlib
from pathlib import Path
import runpy
import tempfile
import unittest


class AccessDeployGuardTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.ns = runpy.run_path(str(Path(__file__).parents[1] / 'docs/checkpoints/2026-10-18-access-history.py'))
        self.ns = self.ns['source_check'].__globals__
        self.ns['ROOT'] = self.root
        self.ns['trusted'] = lambda p: p.read_bytes()
        self.base = {'kaname/__init__.py': b'VERSION = "0.14.0-dev.8"\n',
                     'kaname/admin.py': b'protected authorization\n',
                     'tools/radius_runtime.py': b'old generator\n', 'pyproject.toml': b'old version\n'}
        self.ns['BASELINE'] = {k: hashlib.sha256(v).hexdigest() for k, v in self.base.items()}
        self.files = {**self.base, 'kaname/__init__.py': b'VERSION = "0.14.0-dev.9"\n',
                      'tools/radius_runtime.py': b'reviewed opt-in generator\n',
                      'kaname/radius_events.py': b'reviewed observer storage\n'}
        self.write(self.base)

    def write(self, files):
        for name, data in files.items():
            path = self.root / name; path.parent.mkdir(parents=True, exist_ok=True); path.write_bytes(data)

    def test_exact_base_and_same_reviewed_candidate_are_accepted(self):
        self.ns['source_check'](self.files)
        self.write(self.files); self.ns['source_check'](self.files)

    def test_existing_source_drift_and_unexpected_feature_file_are_refused(self):
        (self.root / 'tools/radius_runtime.py').write_bytes(b'operator changed generator')
        with self.assertRaisesRegex(ValueError, 'INSTALLED_SOURCE_DRIFT'): self.ns['source_check'](self.files)
        self.write(self.base)
        self.write({'kaname/radius_events.py': b'unexpected observer'})
        with self.assertRaisesRegex(ValueError, 'UNEXPECTED_EXISTING_FEATURE_SOURCE'): self.ns['source_check'](self.files)

    def test_candidate_cannot_expand_into_authorization_changes_even_on_rerun(self):
        self.files['kaname/admin.py'] = b'changed authorization'
        self.write(self.files)
        with self.assertRaisesRegex(ValueError, 'AUTHENTICATION_SOURCE_CHANGE_REFUSED'):
            self.ns['source_check'](self.files)

    def test_source_removal_and_unknown_extra_installed_code_are_refused(self):
        files = {k: v for k, v in self.files.items() if k != 'kaname/admin.py'}
        with self.assertRaisesRegex(ValueError, 'BASE_SOURCE_REMOVAL_REFUSED'): self.ns['source_check'](files)
        self.write({'kaname/unexpected.py': b'unknown source'})
        with self.assertRaisesRegex(ValueError, 'UNRECOGNIZED_INSTALLED_SOURCE'): self.ns['source_check'](self.files)


if __name__ == '__main__': unittest.main()
