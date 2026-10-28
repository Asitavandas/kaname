"""Disposable combined signer fixtures, actual native Windows PowerShell 5.1."""
import hashlib
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import zipfile

sys.path.insert(0,str(Path(__file__).resolve().parents[1]))

from tests.test_deployment_bundle import DeploymentBundleTests

def main():
    if os.name != 'nt' or os.environ.get('RUNNER_ENVIRONMENT') != 'github-hosted':
        raise SystemExit('Hosted Windows fixture only')
    DeploymentBundleTests.setUpClass()
    case=DeploymentBundleTests()
    try:
        case.setUp()
        raw=case.build()
        with tempfile.TemporaryDirectory(prefix='AuthWire-Combined-Fixture-') as root:
            path=Path(root);(path/'draft.zip').write_bytes(raw)
            with zipfile.ZipFile(io.BytesIO(raw)) as z:
                items={n:z.read(n) for n in z.namelist()}
            variants={
                'traversal':{('../escape' if n=='README.txt' else n):b for n,b in items.items()},
                'large':items|{'README.txt':b'x'*262145},
                'content':items|{'enrollment/config.json':b'{}'},
            }
            changed=json.loads(items['bundle-manifest.json']);changed['can_apply']=True
            variants['apply']=items|{'bundle-manifest.json':json.dumps(changed).encode()}
            pins={'draft':hashlib.sha256(raw).hexdigest()}
            for name,files in variants.items():
                out=io.BytesIO()
                with zipfile.ZipFile(out,'w',zipfile.ZIP_DEFLATED) as z:
                    for n,b in files.items():z.writestr(n,b)
                value=out.getvalue();(path/(name+'.zip')).write_bytes(value)
                pins[name]=hashlib.sha256(value).hexdigest()
            (path/'pins.json').write_text(json.dumps(pins),encoding='utf-8')
            command=[str(Path(os.environ['SystemRoot'])/'System32/WindowsPowerShell/v1.0/powershell.exe'),
                '-NoProfile','-NonInteractive','-File','tools/combined_candidate_windows_fixture.ps1',
                '-FixtureDirectory',str(path)]
            subprocess.run(command,check=True,timeout=180)
    finally:
        case.tearDown();case.doCleanups();DeploymentBundleTests.tearDownClass()

if __name__=='__main__':main()
