"""Pinned installation entrypoint; root password stays in the operator terminal."""
import hashlib
import json
from pathlib import Path

STAGE = Path('/home/segmentiq/authwire-backup-package-20261018')
INSTALLER_SHA = '8206459365a1f85fd87ef86facb45a5aed8ccfe0cfdb2e0f3b23908c39def521'
MANIFEST_SHA = '9c84b47a709af791963e25e057a80f6f08feb0094391cdfd5f26bd5afe8f62ec'


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
