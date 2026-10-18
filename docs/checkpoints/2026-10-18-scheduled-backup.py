"""Pinned installation entrypoint; root password stays in the operator terminal."""
import hashlib
import json
from pathlib import Path

STAGE = Path('/home/segmentiq/authwire-backup-package-20261018')
INSTALLER_SHA = 'ed18f5c0c3e65aa6d2a6fe8311ddd1fa604b128c724e5854214e986118faf347'
MANIFEST_SHA = '3fd5b7b58785c4539aafdbfda1c44c6e4e1a5956304434f8f40813ece642cbec'


def main():
    path = STAGE / 'backup_install.py'
    data = path.read_bytes()
    if hashlib.sha256(data).hexdigest() != INSTALLER_SHA:
        raise ValueError('Pinned installer source differs')
    ns = {'__name__': 'guarded_backup_installer', '__file__': str(path)}
    exec(compile(data, str(path), 'exec'), ns)
    try:
        print(json.dumps(ns['install'](STAGE, MANIFEST_SHA)))
    except Exception as error:
        print(json.dumps({'event': 'BACKUP_INSTALL_FAILED', 'phase': ns.get('PHASE'),
                          'category': type(error).__name__, 'exit_code': getattr(error, 'returncode', None)}))
        raise SystemExit(1)


if __name__ == '__main__': main()
