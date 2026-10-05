"""Stage generic tested source under the runner home; no system or AD changes."""
import argparse
import hashlib
import json
import os
import shutil
import tempfile
from pathlib import Path


def prepare(source, destination):
    source, destination = Path(source).resolve(), Path(destination).absolute()
    if destination.is_symlink() or destination.parent.is_symlink():
        raise ValueError('Unsafe staging directory')
    files = {}
    for prefix in ('kaname', 'tools', 'tests'):
        for path in sorted((source / prefix).rglob('*')):
            if '__pycache__' in path.parts or path.suffix == '.pyc':
                continue
            if path.is_symlink():
                raise ValueError('Source symlink refused')
            if path.is_file():
                if path.suffix not in {'.py', '.ps1', '.js', '.css', '.html'} and path.relative_to(source).as_posix() != 'kaname/static/authwire-logo.png':
                    continue
                files[path.relative_to(source).as_posix()] = path.read_bytes()
    files['pyproject.toml'] = (source / 'pyproject.toml').read_bytes()
    manifest = json.dumps({'artifact': 'kaname-linux-lab-source', 'files': {
        name: hashlib.sha256(data).hexdigest() for name, data in sorted(files.items())}}, sort_keys=True, separators=(',', ':')).encode()
    digest = hashlib.sha256(manifest).hexdigest()
    destination.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    if destination.exists():
        raise ValueError('Staging destination already exists')
    with tempfile.TemporaryDirectory(dir=destination.parent) as temporary:
        pending = Path(temporary) / 'source'; pending.mkdir(mode=0o700)
        for name, data in files.items():
            path = pending / name; path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(data); path.chmod(0o644)
        (pending / 'LINUX_SOURCE_MANIFEST.json').write_bytes(manifest)
        os.rename(pending, destination)
    return {'staged': True, 'source_digest': digest, 'files': len(files)}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--destination', required=True)
    args = parser.parse_args()
    print(json.dumps(prepare(Path(__file__).resolve().parent.parent, args.destination)))


if __name__ == '__main__':
    main()
