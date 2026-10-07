"""Stage the pinned FreeRADIUS runtime with a deterministic manifest."""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import tempfile


UPSTREAM_COMMIT = '9071ea041b9172e52eabbba91619afaf3a238795'


def prepare(source, destination):
    source, destination = Path(source).resolve(), Path(destination).absolute()
    if source.is_symlink() or not source.is_dir() or destination.is_symlink() or destination.parent.is_symlink():
        raise ValueError('Unsafe RADIUS staging path')
    required = [
        source / 'sbin/radiusd',
        source / 'share/freeradius/dictionary',
    ]
    modules = list(source.rglob('rlm_python3.so'))
    if any(not path.is_file() for path in required) or len(modules) != 1:
        raise ValueError('Incomplete pinned FreeRADIUS runtime')
    files = {}
    for prefix in ('lib', 'sbin', 'share'):
        root = source / prefix
        if not root.is_dir() or root.is_symlink():
            raise ValueError('Incomplete RADIUS runtime tree')
        for path in sorted(root.rglob('*')):
            if path.is_symlink():
                raise ValueError('RADIUS runtime symlink refused; archive must be dereferenced')
            if path.is_file():
                relative = path.relative_to(source).as_posix()
                pure = PurePosixPath(relative)
                if '..' in pure.parts or pure.parts[0] not in {'lib', 'sbin', 'share'}:
                    raise ValueError('Unsafe RADIUS runtime path')
                data = path.read_bytes()
                if len(data) > 100_000_000:
                    raise ValueError('Oversized RADIUS runtime file')
                files[relative] = {
                    'sha256': hashlib.sha256(data).hexdigest(),
                    'mode': path.stat().st_mode & 0o777,
                    'data': data,
                }
    manifest = json.dumps({
        'artifact': 'authwire-freeradius-runtime',
        'upstream_commit': UPSTREAM_COMMIT,
        'files': {name: {'sha256': row['sha256'], 'mode': row['mode']}
                  for name, row in sorted(files.items())},
    }, sort_keys=True, separators=(',', ':')).encode()
    digest = hashlib.sha256(manifest).hexdigest()
    destination.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    if destination.exists():
        raise ValueError('RADIUS staging destination already exists')
    with tempfile.TemporaryDirectory(dir=destination.parent) as temporary:
        pending = Path(temporary) / 'runtime'
        pending.mkdir(mode=0o700)
        for name, row in files.items():
            target = pending / name
            target.parent.mkdir(parents=True, exist_ok=True, mode=0o755)
            target.write_bytes(row['data'])
            target.chmod(row['mode'])
        (pending / 'RADIUS_RUNTIME_MANIFEST.json').write_bytes(manifest)
        os.rename(pending, destination)
    return {'staged': True, 'runtime_digest': digest, 'files': len(files),
            'upstream_commit': UPSTREAM_COMMIT}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--source', required=True)
    parser.add_argument('--destination', required=True)
    args = parser.parse_args()
    print(json.dumps(prepare(args.source, args.destination)))


if __name__ == '__main__':
    main()
