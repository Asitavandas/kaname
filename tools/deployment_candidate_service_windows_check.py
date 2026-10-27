"""Native non-administrator SCM candidate verifier; synthetic public data only."""
import os
from pathlib import Path
import subprocess
import tempfile
from deployment_candidate_windows_check import fixtures

if __name__ == '__main__':
    if os.name != 'nt' or os.environ.get('RUNNER_ENVIRONMENT') != 'github-hosted':
        raise SystemExit('Disposable GitHub-hosted Windows only')
    with tempfile.TemporaryDirectory(prefix='authwire-candidate-service-') as temp:
        fixtures(Path(temp))
        env = {k: v for k, v in os.environ.items() if k.upper() != 'PSMODULEPATH'}
        ps = str(Path(os.environ['SystemRoot'])/'System32/WindowsPowerShell/v1.0/powershell.exe')
        subprocess.run([ps, '-NoProfile', '-NonInteractive', '-File',
                        'tools/deployment_candidate_service_windows_fixture.ps1',
                        '-FixtureDirectory', temp], env=env, check=True, timeout=240)
