"""Build reproducible, commit-pinned Linux delivery candidates; never install."""
import argparse
import ast
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import stat
import subprocess
import tomllib
import zipfile

ROOTS = {'kaname', 'tools', 'tests'}
SECRET_SUFFIXES = {'.key', '.keytab', '.pfx', '.p12', '.pem', '.der', '.csr', '.crl',
                   '.sqlite', '.sqlite3', '.db', '.vmdk', '.ova', '.ovf', '.pyc'}
REQUIRED = {'kaname/__init__.py', 'kaname/server.py', 'kaname/__main__.py',
            'kaname/device_client/AuthWire-Client.ps1', 'kaname/device_client/Install-AuthWire.ps1',
            'tools/linux_update.py', 'tools/linux_install.py', 'tools/linux_initialize.py',
            'tools/backup_upgrade.py', 'tools/scheduled_backup.py', 'tools/offline_restore_check.py',
            'pyproject.toml'}
WORKER_FILES = ('scheduled_backup.py', 'offline_restore_check.py')
STAMP = (2026, 11, 4, 0, 0, 0)


def digest(data):
    return hashlib.sha256(data).hexdigest()


def json_bytes(value):
    return (json.dumps(value, sort_keys=True, indent=2, ensure_ascii=False) + '\n').encode()


def git(source, *args):
    return subprocess.run(['git', '-C', str(source), *args], check=True,
                          capture_output=True, timeout=30).stdout


def selected(name):
    path = PurePosixPath(name)
    return name == 'pyproject.toml' or bool(path.parts and path.parts[0] in ROOTS)


def source_files(source, expected):
    if not re.fullmatch('[a-f0-9]{40}', expected):
        raise ValueError('Exact source commit required')
    source = Path(source).absolute()
    if source.resolve() != source or not source.is_dir():
        raise ValueError('Source directory must not contain symlink ancestors')
    if git(source, 'rev-parse', 'HEAD').decode().strip() != expected:
        raise ValueError('Checkout differs from expected source commit')
    if git(source, 'status', '--porcelain=v1', '--untracked-files=no').strip():
        raise ValueError('Tracked checkout is dirty')
    result = {}
    for entry in git(source, 'ls-tree', '-r', '-z', '--full-tree', 'HEAD').split(b'\0'):
        if not entry:
            continue
        meta, raw_name = entry.split(b'\t', 1)
        name = raw_name.decode('utf-8')
        if not selected(name):
            continue
        mode, kind, oid = meta.decode().split()
        relative = PurePosixPath(name)
        if (mode not in ('100644', '100755') or kind != 'blob' or relative.is_absolute()
                or '..' in relative.parts or '\\' in name or name != relative.as_posix()
                or set(relative.parts) & {'__pycache__', '.git', 'node_modules', 'kaname-state', 'output'}
                or relative.suffix.lower() in SECRET_SUFFIXES or relative.name in ('.env', 'access-token')):
            raise ValueError('Unsafe tracked source member')
        path = source
        for part in relative.parts:
            path /= part
            if path.is_symlink():
                raise ValueError('Source symlink refused')
        info = path.lstat()
        if not stat.S_ISREG(info.st_mode) or info.st_size > 2_000_000:
            raise ValueError('Bounded regular source member required')
        data = path.read_bytes()
        blob = hashlib.sha1(b'blob ' + str(len(data)).encode() + b'\0' + data).hexdigest()
        if blob != oid:
            raise ValueError('Worktree bytes differ from pinned Git blob')
        result[name] = data
    if not REQUIRED <= set(result):
        raise ValueError('Incomplete Linux delivery checkout')
    # Ignore disposable Python caches, but refuse unknown source/state files,
    # including ignored .env/database/key files under shipped roots.
    for root in sorted(ROOTS):
        for directory, dirs, files in os.walk(source / root, followlinks=False):
            for name in list(dirs):
                path = Path(directory) / name
                if path.is_symlink():
                    raise ValueError('Untracked source directory link refused')
                if name == '__pycache__':
                    dirs.remove(name)
            for name in files:
                path = Path(directory) / name
                if path.relative_to(source).as_posix() not in result:
                    raise ValueError('Untracked file inside source payload roots')
    # Recheck index/head after reading: no mixed-checkout package is accepted.
    if git(source, 'rev-parse', 'HEAD').decode().strip() != expected or git(
            source, 'status', '--porcelain=v1', '--untracked-files=no').strip():
        raise ValueError('Checkout changed during packaging')
    return result


def version_of(files):
    values = [node.value.value for node in ast.parse(files['kaname/__init__.py']).body
              if isinstance(node, ast.Assign) and any(isinstance(t, ast.Name) and t.id == 'VERSION' for t in node.targets)
              and isinstance(node.value, ast.Constant) and type(node.value.value) is str]
    if len(values) != 1 or not re.fullmatch(r'\d+\.\d+\.\d+-dev\.\d+', values[0]):
        raise ValueError('One explicit development version required')
    if tomllib.loads(files['pyproject.toml'].decode())['project']['version'] != values[0].replace('-dev.', '.dev'):
        raise ValueError('Python project and product versions differ')
    return values[0]


def archive_bytes(files):
    import io
    output = io.BytesIO()
    # Stored ZIP avoids zlib-version-dependent compressed bytes across rebuilds.
    with zipfile.ZipFile(output, 'w', compression=zipfile.ZIP_STORED) as archive:
        for name, data in sorted(files.items()):
            entry = zipfile.ZipInfo(name, STAMP)
            entry.create_system = 3
            entry.compress_type = zipfile.ZIP_STORED
            entry.external_attr = 0o100644 << 16
            archive.writestr(entry, data, compress_type=zipfile.ZIP_STORED)
    value = output.getvalue()
    with zipfile.ZipFile(io.BytesIO(value)) as archive:
        if set(archive.namelist()) != set(files) or len(archive.namelist()) != len(files) or archive.testzip():
            raise ValueError('Archive membership/CRC verification failed')
        for name, data in files.items():
            if archive.read(name) != data:
                raise ValueError('Archive bytes differ from source')
    return value


def build(source, destination, expected_commit):
    files = source_files(source, expected_commit)
    version = version_of(files)
    panel_manifest = json_bytes({'artifact': 'kaname-linux-lab-source',
                                 'files': {n: digest(v) for n, v in files.items()}})
    if len(panel_manifest) > 200000:
        raise ValueError('Linux updater manifest bound exceeded')
    worker = {name: files['tools/' + name] for name in WORKER_FILES}
    worker_manifest = json_bytes({n: digest(v) for n, v in worker.items()})
    panel = archive_bytes({**{'linux-source/' + n: v for n, v in files.items()},
                           'linux-source/LINUX_SOURCE_MANIFEST.json': panel_manifest})
    backup = archive_bytes({**{'backup-worker/' + n: v for n, v in worker.items()},
                            'backup-worker/manifest.json': worker_manifest,
                            'backup-upgrade/backup_upgrade.py': files['tools/backup_upgrade.py']})
    panel_name = 'AuthWire-' + version + '-linux-source.zip'
    worker_name = 'AuthWire-' + version + '-backup-worker.zip'
    metadata = {'artifact': 'authwire-linux-delivery-candidate', 'version': version,
                'source_commit': expected_commit, 'source_files': len(files),
                'required_os': 'Ubuntu 24.04', 'live_install_applied': False,
                'packages': {panel_name: digest(panel), worker_name: digest(backup)},
                'linux_source_manifest_sha256': digest(panel_manifest),
                'backup_worker_manifest_sha256': digest(worker_manifest),
                'backup_upgrade_tool_sha256': digest(files['tools/backup_upgrade.py']),
                'windows_client_source_sha256': {n: digest(files['kaname/device_client/' + n])
                                                  for n in ('AuthWire-Client.ps1', 'Install-AuthWire.ps1')},
                'archive_bytes_verified': True, 'full_appliance_boot_restore_tested': False}
    output = {panel_name: panel, worker_name: backup, 'DELIVERY.json': json_bytes(metadata)}
    output['SHA256SUMS'] = ''.join(digest(data) + '  ' + name + '\n' for name, data in sorted(output.items())).encode()
    destination = Path(destination).absolute()
    if destination.exists() or destination.is_symlink() or destination.parent.resolve() != destination.parent:
        raise ValueError('New destination under non-symlink parent required')
    # Nothing is published until both archives have been built and verified.
    # Never overwrite an existing package directory or deliverable.
    destination.mkdir(mode=0o700)  # Exclusive creation also refuses an empty raced directory.
    for name, data in output.items():
        with (destination / name).open('xb') as stream:
            stream.write(data)
        if (destination / name).read_bytes() != data:
            raise ValueError('Published artifact bytes differ')
    return metadata


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source', type=Path, required=True)
    parser.add_argument('--destination', type=Path, required=True)
    parser.add_argument('--expected-commit', required=True)
    args = parser.parse_args()
    print(json.dumps(build(args.source, args.destination, args.expected_commit), sort_keys=True))


if __name__ == '__main__':
    main()
