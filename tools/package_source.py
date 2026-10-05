"""Build and verify a reproducible source ZIP, without runtime state or keys."""
import argparse
import hashlib
import json
import tempfile
import zipfile
from pathlib import Path

from kaname import VERSION

ROOT_FILES = {'README.md', 'CHANGELOG.md', '.gitignore', 'pyproject.toml'}
ROOT_DIRS = {'kaname', 'tools', 'tests', 'appliance', 'docs', '.github'}
EXCLUDED_DIRS = {'__pycache__', '.git', 'node_modules', 'kaname-state', 'output'}
SECRET_SUFFIXES = {'.key', '.keytab', '.pfx', '.p12', '.pem', '.der', '.csr', '.crl', '.sqlite', '.sqlite3', '.vmdk', '.ova', '.ovf'}


def package(source, destination):
    source = Path(source).absolute()
    destination = Path(destination).absolute()
    files = []
    for path in sorted(source.rglob('*')):
        relative = path.relative_to(source)
        if set(relative.parts) & EXCLUDED_DIRS:
            continue
        if relative.parts[0] not in ROOT_DIRS | ROOT_FILES:
            continue
        if path.is_symlink():
            raise ValueError('Source symlink cannot be packaged')
        if not path.is_file() or path.suffix == '.pyc':
            continue
        if path.suffix.lower() in SECRET_SUFFIXES or path.name in {'access-token', '.env'}:
            raise ValueError('State, key or disk image found in source tree')
        files.append((relative.as_posix(), path.read_bytes()))
    if not ROOT_FILES <= {name for name, _ in files}:
        raise ValueError('Source root is incomplete')
    manifest = {'product': 'AuthWire', 'version': VERSION, 'artifact': 'source-only',
                'files': {name: hashlib.sha256(data).hexdigest() for name, data in files}}
    files.append(('SOURCE_MANIFEST.json', (json.dumps(manifest, ensure_ascii=False, indent=2) + '\n').encode()))
    destination.parent.mkdir(parents=True, exist_ok=True)
    if destination.is_symlink():
        raise ValueError('Destination cannot be a symbolic link')
    # Prepare and validate before atomically replacing the local deliverable.
    with tempfile.TemporaryDirectory(dir=destination.parent) as temp:
        pending = Path(temp) / 'source.zip'
        with zipfile.ZipFile(pending, 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
            for name, data in files:
                info = zipfile.ZipInfo('kaname/' + name, (2026, 10, 2, 0, 0, 0))
                info.compress_type = zipfile.ZIP_DEFLATED
                info.external_attr = 0o100644 << 16
                archive.writestr(info, data)
        with zipfile.ZipFile(pending) as archive:
            if archive.testzip() is not None:
                raise ValueError('ZIP CRC verification failed')
            for name, digest in manifest['files'].items():
                if hashlib.sha256(archive.read('kaname/' + name)).hexdigest() != digest:
                    raise ValueError('Source manifest mismatch')
        pending.replace(destination)
    return {'file': str(destination), 'source_files': len(manifest['files']),
            'bytes': destination.stat().st_size, 'sha256': hashlib.sha256(destination.read_bytes()).hexdigest(),
            'crc_verified': True, 'source_manifest_verified': True, 'artifact': 'source-only'}


def main():
    parser = argparse.ArgumentParser(description='AuthWire source ZIP')
    parser.add_argument('destination')
    args = parser.parse_args()
    print(json.dumps(package(Path(__file__).parent.parent, args.destination), indent=2))


if __name__ == '__main__':
    main()
