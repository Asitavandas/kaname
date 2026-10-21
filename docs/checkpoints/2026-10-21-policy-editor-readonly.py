"""Read-only pilot policy/backup/event comparison. Never changes the live appliance."""
from contextlib import closing
from datetime import datetime, timezone, timedelta
import hashlib
import json
import os
from pathlib import Path
import sqlite3
import subprocess
import tarfile
import time

STATE = Path('/var/lib/kaname-lab')
BACKUP = Path('/var/backups/authwire/scheduled/authwire-scheduled-20261021T181414Z-77a4a68ad8c4.tar.gz')
BACKUP_SHA256 = 'a51a4575c98b8199ddcc61c600c10db6d2f65e04b9362d14d8db69f0d766cde7'
PILOT_IDS = ('authwire-pilot-wired', 'authwire-pilot-wireless')


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def readonly(path):
    db = sqlite3.connect(path.absolute().as_uri() + '?mode=ro', uri=True, timeout=2)
    db.row_factory = sqlite3.Row
    db.execute('PRAGMA query_only=ON')
    deadline = time.monotonic() + 5
    db.set_progress_handler(lambda: int(time.monotonic() > deadline), 1000)
    return db


def policy_view(db):
    row = db.execute('SELECT revision,policies FROM state WHERE id=1').fetchone()
    policies = json.loads(row['policies'])
    # No configuration, passwords, tokens, vault or enrollment key material.
    return {'revision': row['revision'], 'policies': [p for p in policies if p.get('id') in PILOT_IDS],
            'other_wireless_rules': [{k: p.get(k) for k in ('id', 'enabled', 'action', 'vlan', 'conditions')}
                                     for p in policies if p.get('id') not in PILOT_IDS
                                     and 'wireless' in p.get('conditions', {}).get('access_types', [])]}


def compare(current, previous):
    old = {p['id']: p for p in previous['policies']}
    result = []
    for p in current['policies']:
        before = old.get(p['id'])
        changed = None if before is None else [k for k in sorted(set(before) | set(p)) if before.get(k) != p.get(k)]
        result.append({'id': p['id'], 'changed_fields_since_backup': changed,
                       'settings_except_enabled_preserved': before is not None and
                       {k: v for k, v in before.items() if k != 'enabled'} ==
                       {k: v for k, v in p.items() if k != 'enabled'}})
    return result


def backup_view(path, expected_digest):
    if digest(path) != expected_digest:
        raise ValueError('BACKUP_DIGEST_DIFFERS')
    with tarfile.open(path, 'r:gz') as archive:
        member = archive.getmember('var/lib/kaname-lab/kaname.sqlite3')
        if not member.isfile() or not 0 < member.size <= 128 * 1024 * 1024:
            raise ValueError('BACKUP_DATABASE_ENTRY_INVALID')
        with archive.extractfile(member) as stream:
            data = stream.read(member.size + 1)
        if len(data) != member.size:
            raise ValueError('BACKUP_DATABASE_TRUNCATED')
    # Load bytes into memory only. No archive extraction or on-disk restore.
    with closing(sqlite3.connect(':memory:')) as db:
        db.deserialize(data)
        db.row_factory = sqlite3.Row
        db.execute('PRAGMA query_only=ON')
        return policy_view(db)


def recent_events(path):
    if not path.exists():
        return {'available': False, 'events': []}
    with closing(readonly(path)) as db:
        rows = db.execute('SELECT id,at,response_code,reason,reason_source,nas_ip,policy_id,vlan,'
                          'tls_verified,calling_station,certificate_serial,object_guid '
                          'FROM access_events WHERE nas_ip=? ORDER BY id DESC LIMIT 20',
                          ('10.35.50.52',)).fetchall()
    values = []
    for row in rows:
        item = dict(row)
        item['at_istanbul'] = datetime.fromisoformat(item['at'].replace('Z', '+00:00')).astimezone(
            timezone(timedelta(hours=3))).isoformat()
        values.append(item)
    return {'available': True, 'events': values}


def pids():
    values = {}
    for unit in ('kaname-lab.service', 'authwire-radius.service', 'authwire-service-control.service'):
        values[unit] = subprocess.check_output(['/usr/bin/systemctl', 'show', unit,
                                               '--property=MainPID', '--value'], text=True, timeout=10).strip()
    return values


def main():
    if os.geteuid() != 0:
        raise PermissionError('LOCAL_SUDO_REQUIRED_FOR_PRIVATE_READS')
    before_pids = pids()
    with closing(readonly(STATE / 'kaname.sqlite3')) as db:
        db.execute('BEGIN')
        current = policy_view(db)
        audit = [dict(row) for row in db.execute("SELECT id,event,revision,at FROM audit "
                                                "WHERE event='policies_saved' ORDER BY id DESC LIMIT 8")]
    previous = backup_view(BACKUP, BACKUP_SHA256)
    event_data = recent_events(STATE / 'radius-events/access.sqlite3')
    with closing(readonly(STATE / 'kaname.sqlite3')) as db:
        end_revision = db.execute('SELECT revision FROM state WHERE id=1').fetchone()[0]
    print(json.dumps({'event': 'POLICY_EDITOR_READONLY', 'checked_utc': datetime.now(timezone.utc).isoformat(),
                      'current': current, 'verified_backup': previous, 'comparison': compare(current, previous),
                      'recent_policy_audit': audit, 'wireless_events': event_data,
                      'revision_stable_during_check': end_revision == current['revision'],
                      'service_pids_preserved': pids() == before_pids,
                      'policy_changed_by_check': False, 'services_restarted': False,
                      'disk_restore_performed': False}, ensure_ascii=False, indent=2))


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        print(json.dumps({'event': 'POLICY_EDITOR_READONLY_FAILED', 'category': type(error).__name__,
                          'detail': str(error) if isinstance(error, (ValueError, PermissionError)) else None}))
        raise SystemExit(1)
