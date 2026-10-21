"""Each generated lab module must import without another module extending sys.path."""
from pathlib import Path
import re
import subprocess
import sys
import tempfile
import unittest

from tools.radius_lab import configuration


class RadiusLabPathTests(unittest.TestCase):
    def test_observer_and_authorizer_import_independently(self):
        with tempfile.TemporaryDirectory(prefix='authwire-lab-path-') as directory:
            root = Path(directory) / 'fixture'
            root.mkdir()
            (root / 'state').mkdir()
            prefix = Path(directory) / 'native'
            share = prefix / 'share/freeradius'
            share.mkdir(parents=True)
            (share / 'dictionary').write_text('')
            library = prefix / 'lib/rlm_python3.so'
            library.parent.mkdir()
            library.write_bytes(b'fixture; never executed')
            configuration(root, prefix, 18120, 'disposable-fixture-secret', access_events=True)
            for filename, module in [('access-events', 'kaname_lab_observer'), ('python3', 'kaname_lab_module')]:
                with self.subTest(module=module):
                    text = (root / 'mods-enabled' / filename).read_text()
                    paths = re.search(r'python_path = "([^"]+)"', text)[1].split(':')
                    # A fresh isolated interpreter per module exposes load-order dependencies.
                    code = f'import sys;sys.path[:0]={paths!r};import {module};assert callable({module}.' + ('post_auth' if filename == 'access-events' else 'authorize') + ')'
                    result = subprocess.run([sys.executable, '-I', '-B', '-c', code], capture_output=True, text=True, timeout=20)
                    self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == '__main__':
    unittest.main()
