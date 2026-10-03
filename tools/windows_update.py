"""Scoped Windows lab source upgrade; local state is never sent to GitHub."""
import argparse
import hashlib
import json
import os
import shutil
import signal
import sqlite3
import subprocess
import sys
import time
from datetime import datetime, timezone
from pathlib import Path

from tools.windows_diagnose import get_json, read_token
WINDOWS = os.name == 'nt'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def protected_path(root, relative):
    parts = Path(relative).parts
    if not parts or Path(relative).is_absolute() or '..' in parts or ':' in relative or '\\' in relative:
        raise ValueError('Invalid managed source path')
    if parts[0] not in {'kaname', 'tools', 'tests', 'docs', '.github', 'appliance', 'README.md', 'CHANGELOG.md', '.gitignore', 'pyproject.toml'}:
        raise ValueError('Managed path is outside source')
    path = root / relative
    for candidate in (path, *path.parents):
        if candidate.is_symlink() or getattr(candidate, 'is_junction', lambda: False)():
            raise ValueError('Source reparse point is not supported')
        if candidate == root:
            break
    return path


def snapshot(root):
    path = root / 'kaname-state' / 'kaname.sqlite3'
    db = sqlite3.connect(path.as_uri() + '?mode=ro', uri=True)
    try:
        state = db.execute('SELECT revision,config,policies FROM state WHERE id=1').fetchone()
        pki = None
        if db.execute("SELECT 1 FROM sqlite_master WHERE type='table' AND name='pki_authority'").fetchone():
            pki = db.execute('SELECT public_data,crl_number FROM pki_authority WHERE id=1').fetchone()
        return state, pki
    finally:
        db.close()


def checked_panel_pid(python, probe=False):
    # All input is data on stdin; never interpolate machine values into a shell.
    script = '''$ErrorActionPreference='Stop'; $p=[Console]::In.ReadToEnd()|ConvertFrom-Json;
$listeners=@(Get-NetTCPConnection -State Listen -LocalPort 8765 -ErrorAction SilentlyContinue | Select-Object -ExpandProperty OwningProcess -Unique);
if($listeners.Count -ne 1){throw 'Expected exactly one KANAME listener'};
$process=Get-CimInstance Win32_Process -Filter ('ProcessId='+$listeners[0]);
$owner=Invoke-CimMethod -InputObject $process -MethodName GetOwner;
$current=[System.Security.Principal.WindowsIdentity]::GetCurrent().Name;
$facts=@{pid=[int]$listeners[0]; exe_matches_virtualenv=($process.ExecutablePath -ieq $p.python); exe_matches_base=($process.ExecutablePath -ieq $p.base); module_matches=($process.CommandLine -match '\\s-m\\s+"?kaname"?(?:\\s|$)'); owner_matches=(($owner.Domain+'\\'+$owner.User) -ieq $current)};
$facts|ConvertTo-Json -Compress'''
    executable = Path(os.environ['SystemRoot']) / 'System32/WindowsPowerShell/v1.0/powershell.exe'
    result = subprocess.run([str(executable), '-NoProfile', '-NonInteractive', '-Command', script],
                            input=json.dumps({'python': str(python), 'base': getattr(sys, '_base_executable', sys.executable)}).encode(), capture_output=True, timeout=15)
    if result.returncode:
        raise ValueError('KANAME process could not be safely identified; no process stopped')
    facts = json.loads(result.stdout.decode('utf-8-sig'))
    if probe:
        return facts
    # Windows venv redirectors may report the base interpreter in Win32_Process.
    # Module, owner and authenticated local state checks still remain mandatory.
    if facts.get('module_matches') is not True or facts.get('owner_matches') is not True or not (facts.get('exe_matches_virtualenv') is True or facts.get('exe_matches_base') is True):
        raise ValueError('KANAME process could not be safely identified; no process stopped')
    return facts['pid']


def start_panel(root, python):
    # Do not retain GitHub job tokens or tracking data in the persistent panel.
    os_names = {'SYSTEMROOT', 'WINDIR', 'SYSTEMDRIVE', 'COMSPEC', 'TEMP', 'TMP', 'USERPROFILE',
                'LOCALAPPDATA', 'APPDATA', 'PROGRAMDATA', 'PATH', 'PATHEXT', 'USERNAME', 'USERDOMAIN',
                'HOMEDRIVE', 'HOMEPATH', 'NUMBER_OF_PROCESSORS', 'PROCESSOR_ARCHITECTURE'}
    env = {k: v for k, v in os.environ.items() if k.upper() in os_names}
    state = root / 'kaname-state'
    with (state / 'panel.stdout.log').open('ab') as output, (state / 'panel.stderr.log').open('ab') as errors:
        child = subprocess.Popen([str(python), '-u', '-m', 'kaname', '--state-dir', str(state)],
                                 cwd=root, env=env, stdin=subprocess.DEVNULL, stdout=output, stderr=errors,
                                 creationflags=subprocess.DETACHED_PROCESS | subprocess.CREATE_NEW_PROCESS_GROUP)
    (state / 'panel.pid').write_text(str(child.pid), encoding='ascii')
    return child


def wait_panel(version, token):
    deadline = time.monotonic() + 25
    while time.monotonic() < deadline:
        code, health = get_json('/healthz')
        if code == 200 and isinstance(health, dict) and health.get('product') == 'KANAME' and health.get('version') == version:
            status, state = get_json('/api/state', token=token)
            if status == 200:
                return state
        time.sleep(0.3)
    raise ValueError('Updated panel health check failed')


def upgrade(root, source):
    if not WINDOWS:
        raise ValueError('Windows lab update only')
    root = Path(root).absolute()
    source = Path(source).absolute()
    if root == source or root.is_symlink() or not root.is_dir():
        raise ValueError('Invalid installation directory')
    release = json.loads((source / 'tools/windows_release.json').read_text(encoding='utf-8'))
    old = json.loads((source / 'tools/windows_baseline.json').read_text(encoding='utf-8'))['files']
    previous = {}
    previous_path = source / 'tools/windows_previous_release.json'
    if previous_path.is_file():
        # Trusted staged manifest, never the installation's mutable manifest.
        # Its digest is covered by this release's source manifest.
        if release['files'].get('tools/windows_previous_release.json') != digest(previous_path):
            raise ValueError('Previous release digest mismatch')
        previous = json.loads(previous_path.read_text(encoding='utf-8'))['files']
    files = {**release['files'], 'tools/windows_release.json': digest(source / 'tools/windows_release.json')}
    for name, expected in files.items():
        staged = protected_path(source, name)
        local = protected_path(root, name)
        if digest(staged) != expected:
            raise ValueError('Staged source digest mismatch')
        if local.exists() and (not local.is_file() or digest(local) not in {expected, old.get(name), previous.get(name)}):
            raise ValueError('Local source changes found; update refused')
    token = read_token(root)
    if not token:
        raise ValueError('Existing access token is not usable')
    status, active = get_json('/api/state', token=token)
    if status != 200 or not isinstance(active, dict) or active.get('product') != 'KANAME':
        raise ValueError('Existing panel could not be authenticated')
    existing, _ = snapshot(root)
    if not existing or active.get('revision') != existing[0] or active.get('config') != (json.loads(existing[1]) if existing[1] else None) or active.get('policies') != json.loads(existing[2]):
        raise ValueError('Existing panel does not match the requested installation')
    if active.get('version') == release['version'] and all((root/n).is_file() and digest(root/n) == h for n,h in files.items()):
        return {'updated': False, 'already_current': True, 'version': release['version']}
    python = root / '.venv/Scripts/python.exe'
    pid = checked_panel_pid(python)
    backup_root = root / '.kaname-upgrades'
    if backup_root.is_symlink() or getattr(backup_root, 'is_junction', lambda: False)():
        raise ValueError('Backup path cannot be a reparse point')
    backup = backup_root / datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ')
    backup.mkdir(parents=True, exist_ok=False)
    original = []
    for name in files:
        local = root / name
        if local.exists():
            destination = backup / 'source' / name
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(local, destination)
            original.append(name)
    # No state restoration is performed; rollback preserves newer user edits.
    child = None
    stopped = False
    try:
        os.kill(pid, signal.SIGTERM)
        stopped = True
        time.sleep(1)
        before = snapshot(root)
        state = root / 'kaname-state'
        db = sqlite3.connect((state / 'kaname.sqlite3').as_uri() + '?mode=ro', uri=True)
        saved = sqlite3.connect(backup / 'state.sqlite3')
        try:
            db.backup(saved)
        finally:
            db.close(); saved.close()
        shutil.copy2(state / 'access-token', backup / 'access-token')
        for name in files:
            destination = root / name
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source / name, destination)
        child = start_panel(root, python)
        current = wait_panel(release['version'], token)
        if read_token(root) != token or snapshot(root) != before:
            raise ValueError('Existing configuration or CA preservation check failed')
        if current.get('directory_public', {}).get('runtime_auth_ready') is not False:
            raise ValueError('Directory readiness boundary failed')
        return {'updated': True, 'version': release['version'], 'backup_created': True,
                'configuration_preserved': True, 'policies_preserved': True, 'ca_preserved': True,
                'token_preserved': True, 'real_ad_tested': False}
    except Exception:
        if not stopped:
            raise ValueError('Update refused; existing panel not stopped') from None
        if child and child.poll() is None:
            child.terminate(); child.wait(timeout=10)
        for name in files:
            destination = root / name
            if name in original:
                shutil.copy2(backup / 'source' / name, destination)
            elif destination.is_file():
                destination.unlink()
        start_panel(root, python)
        wait_panel(active['version'], token)
        raise ValueError('Update failed; previous source restored and panel restarted') from None


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--root', required=True)
    parser.add_argument('--probe', action='store_true')
    args = parser.parse_args()
    try:
        if args.probe:
            print(json.dumps({'process_probe': checked_panel_pid(Path(args.root) / '.venv/Scripts/python.exe', probe=True)}))
        else:
            print(json.dumps(upgrade(args.root, Path(__file__).resolve().parent.parent)))
    except Exception as exc:
        # Only fixed, non-sensitive errors above are used for operator feedback.
        allowed = str(exc) if isinstance(exc, ValueError) and str(exc) in {
            'Local source changes found; update refused', 'Existing panel could not be authenticated',
            'KANAME process could not be safely identified; no process stopped',
            'Update failed; previous source restored and panel restarted'} else 'WINDOWS_UPDATE_FAILED'
        print(json.dumps({'updated': False, 'error': allowed}))
        raise SystemExit(1)


if __name__ == '__main__':
    main()
