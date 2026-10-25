"""Real Windows PowerShell 5.1 CNG -> Python verifier interoperability fixture."""
import base64
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time

from cryptography.hazmat.primitives import serialization
from cryptography.hazmat.primitives.asymmetric import rsa

# Direct tool execution sets sys.path[0] to tools, not the repository root.
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from kaname.connector_channel import Binding, ChannelError, ConnectorHealth, public_key_id


def main():
    if os.name != 'nt' or os.environ.get('RUNNER_ENVIRONMENT') != 'github-hosted':
        raise RuntimeError('Hosted Windows fixture only')
    script = Path(__file__).with_name('connector_channel_windows_fixture.ps1')
    with tempfile.TemporaryDirectory(prefix='authwire-channel-') as directory:
        def run(mode):
            # GitHub's default pwsh shell can export its .NET/Core module path.
            # Let the child Windows PowerShell 5.1 rebuild its own module path.
            child_env = {k: v for k, v in os.environ.items() if k.upper() != 'PSMODULEPATH'}
            subprocess.run(['powershell.exe', '-NoProfile', '-NonInteractive', '-File',
                str(script), '-Mode', mode, '-Directory', directory],
                check=True, timeout=60, env=child_env)
        try:
            run('Create')
            fixture = json.loads((Path(directory)/'fixture.json').read_text(encoding='utf-8-sig'))
            public = rsa.RSAPublicNumbers(
                int.from_bytes(base64.b64decode(fixture['exponent']), 'big'),
                int.from_bytes(base64.b64decode(fixture['modulus']), 'big')).public_key()
            b = fixture['binding']
            assert public_key_id(public) == b.pop('channel_key_sha256')
            binding = Binding(**b, public_key_pem=public.public_bytes(
                serialization.Encoding.PEM, serialization.PublicFormat.SubjectPublicKeyInfo))
            channel = ConnectorHealth(binding)
            challenge = channel.challenge()
            (Path(directory)/'challenge.json').write_text(json.dumps(challenge), encoding='ascii')
            start = time.monotonic()
            run('Sign')
            # The frame must not time out while the native fixture checks are running.
            assert time.monotonic()-start < 60
            response = (Path(directory)/'proof.json').read_text(encoding='utf-8-sig').encode()
            result = channel.accept(response)
            assert result['channel_proof_verified'] and not result['can_apply']
            assert channel.status()['online']
            try: channel.accept(response)
            except ChannelError: pass
            else: raise AssertionError('Replay accepted')
            native = json.loads((Path(directory)/'native-result.json').read_text(encoding='utf-8-sig'))
            assert native['native_checks'] >= 33
            assert not any(native[k] for k in ('private_key_exported','ad_changed','gpo_changed','service_installed'))
            print('AUTHWIRE_CONNECTOR_CHANNEL_WINDOWS_OK '+json.dumps(native, sort_keys=True))
        finally:
            if (Path(directory)/'fixture.json').exists(): run('Cleanup')


if __name__ == '__main__': main()
