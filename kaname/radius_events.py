"""Private, bounded final-response history, separate from authorization state.

Only an explicitly enabled native post-auth observer writes here. A committed
row describes the response selected by the server, not NAS receipt, endpoint
authentication or an accounting session. No request payload is retained.
"""
from contextlib import closing
from datetime import datetime, timezone
import hashlib
import ipaddress
import json
import os
from pathlib import Path
import re
import shutil
import sqlite3
import stat
import time

from .audit import instant, number, AuditQueryLimit

MAX_RECORDS = 200_000
MAX_BYTES = 256 * 1024 * 1024
MIN_FREE_BYTES = 128 * 1024 * 1024
BUSY_SECONDS = 0.025
LIMIT = 100
FIELDS = ('event_id', 'request_id', 'at', 'response_code', 'nas_ip', 'reason', 'reason_source',
          'policy_id', 'vlan', 'tls_verified', 'certificate_serial', 'object_guid',
          'identity_kind', 'calling_station', 'capture_run')
REASONS = frozenset({
    'POLICY_ALLOW', 'POLICY_DENY', 'POLICY_CONFLICT', 'NO_MATCHING_POLICY',
    'ACCOUNT_DISABLED', 'DOMAIN_DEVICE_REQUIRED', 'DIRECTORY_UNAVAILABLE',
    'ACCOUNT_NOT_FOUND', 'ACCOUNT_BINDING_MISMATCH', 'DIRECTORY_RESULT_INVALID',
    'CERTIFICATE_UNBOUND', 'CERTIFICATE_INACTIVE', 'CERTIFICATE_BINDING_CHANGED',
    'AUTHORIZATION_INPUT_INVALID', 'RADIUS_ADAPTER_FAILED', 'IDENTITY_NOT_VERIFIED',
    'EAP_CONSTRAINT_FAILED', 'EAP_METHOD_NOT_ALLOWED', 'NATIVE_ACCESS_ACCEPT', 'NATIVE_ACCESS_REJECT',
    'NATIVE_REJECT_AFTER_POLICY_ALLOW', 'TLS_CERTIFICATE_REVOKED',
    'TLS_CERTIFICATE_EXPIRED', 'TLS_CERTIFICATE_UNTRUSTED',
    'TLS_CERTIFICATE_PURPOSE', 'TLS_CERTIFICATE_VERIFY_FAILED',
    'NON_EAP_REQUEST',
})


class EventStorageError(Exception):
    """Fixed non-sensitive error code; never include SQLite/path/request text."""


def utc():
    return datetime.now(timezone.utc).isoformat(timespec='milliseconds').replace('+00:00', 'Z')


def paths(state):
    root = Path(state).absolute() / 'radius-events'
    return root, root / 'access.sqlite3'


def _private(path, *, directory=False):
    info = path.lstat()
    valid = stat.S_ISDIR(info.st_mode) if directory else stat.S_ISREG(info.st_mode)
    if (not valid or info.st_mode & 0o077 or
            (os.name == 'posix' and info.st_uid != os.geteuid()) or
            (not directory and info.st_nlink != 1)):
        raise EventStorageError('UNSAFE_STORAGE')
    for parent in path.parents:
        if parent.is_symlink(): raise EventStorageError('UNSAFE_STORAGE')


def initialize(state):
    """Explicit startup preparation only; never run from a packet callback."""
    root, path = paths(state)
    if root.is_symlink(): raise EventStorageError('UNSAFE_STORAGE')
    root.mkdir(mode=0o700, exist_ok=True)
    _private(root, directory=True)
    if not path.exists():
        fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
        os.close(fd)
    _private(path)
    with closing(sqlite3.connect(path, timeout=1)) as db:
        if db.execute('PRAGMA user_version').fetchone()[0] not in (0, 1):
            raise EventStorageError('STORAGE_ERROR')
        db.executescript('''
            PRAGMA journal_mode=DELETE;
            PRAGMA synchronous=FULL;
            CREATE TABLE IF NOT EXISTS access_events (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                event_id TEXT NOT NULL UNIQUE,
                request_id TEXT NOT NULL,
                at TEXT NOT NULL,
                response_code INTEGER NOT NULL CHECK(response_code IN (2,3)),
                nas_ip TEXT NOT NULL,
                reason TEXT NOT NULL,
                reason_source TEXT NOT NULL,
                policy_id TEXT,
                vlan INTEGER CHECK(vlan BETWEEN 1 AND 4094),
                tls_verified INTEGER NOT NULL CHECK(tls_verified IN (0,1)),
                certificate_serial TEXT,
                object_guid TEXT,
                identity_kind TEXT,
                calling_station TEXT,
                capture_run TEXT NOT NULL
            );
            CREATE TRIGGER IF NOT EXISTS access_events_no_update BEFORE UPDATE ON access_events
                BEGIN SELECT RAISE(ABORT,'append-only access history'); END;
            CREATE TRIGGER IF NOT EXISTS access_events_no_delete BEFORE DELETE ON access_events
                BEGIN SELECT RAISE(ABORT,'append-only access history'); END;
            PRAGMA user_version=1;
        ''')
    return path


def _optional(value, pattern):
    return value is None or type(value) is str and re.fullmatch(pattern, value) is not None


def validate(event):
    if type(event) is not dict or set(event) != set(FIELDS): raise ValueError('Invalid access event')
    if not re.fullmatch(r'[0-9a-f]{64}', event['event_id']): raise ValueError('Invalid event ID')
    if not re.fullmatch(r'[0-9a-f]{64}', event['request_id']): raise ValueError('Invalid request ID')
    if instant(event['at']) != event['at']: raise ValueError('Invalid event time')
    if type(event['response_code']) is not int or event['response_code'] not in (2, 3): raise ValueError('Invalid final response')
    if str(ipaddress.IPv4Address(event['nas_ip'])) != event['nas_ip']: raise ValueError('Invalid packet source')
    if event['reason'] not in REASONS or event['reason_source'] not in {'policy', 'native_category', 'native_generic'}:
        raise ValueError('Invalid event reason')
    if not _optional(event['policy_id'], r'[A-Za-z0-9_.-]{1,64}'): raise ValueError('Invalid policy ID')
    if event['vlan'] is not None and (type(event['vlan']) is not int or not 1 <= event['vlan'] <= 4094): raise ValueError('Invalid VLAN')
    if event['response_code'] == 3 and event['vlan'] is not None: raise ValueError('Reject cannot assign VLAN')
    if type(event['tls_verified']) is not bool: raise ValueError('Invalid TLS proof')
    if not _optional(event['certificate_serial'], r'[1-9a-f][0-9a-f]{0,39}'): raise ValueError('Invalid certificate serial')
    if not _optional(event['object_guid'], r'[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}'): raise ValueError('Invalid object ID')
    if event['identity_kind'] not in (None, 'computer', 'user'): raise ValueError('Invalid identity kind')
    if not event['tls_verified'] and any(event[k] is not None for k in ('certificate_serial', 'object_guid', 'identity_kind')):
        raise ValueError('Unverified identity cannot be promoted')
    if not _optional(event['calling_station'], r'(?:[0-9a-f]{2}:){5}[0-9a-f]{2}'): raise ValueError('Invalid NAS-reported station')
    if not re.fullmatch(r'[0-9a-f]{32}', event['capture_run']): raise ValueError('Invalid capture run')
    return event


def append(state, event):
    """At most 25ms SQLite busy wait; disk latency is not a real-time guarantee.

    Success is committed with FULL synchronization. Capacity/storage failure is
    surfaced to the observer; it must not turn this into an authorization rule.
    Retransmission keys are deduplicated across process restarts.
    """
    validate(event)
    root, path = paths(state)
    _private(root, directory=True); _private(path)
    if path.stat().st_size >= MAX_BYTES: raise EventStorageError('CAPACITY_REACHED')
    if shutil.disk_usage(root).free < MIN_FREE_BYTES: raise EventStorageError('LOW_DISK_SPACE')
    try:
        with closing(sqlite3.connect(path.as_uri() + '?mode=rw', uri=True, timeout=BUSY_SECONDS)) as db:
            db.execute('PRAGMA synchronous=FULL')
            db.execute('PRAGMA max_page_count=' + str(MAX_BYTES // 4096))
            db.execute('BEGIN IMMEDIATE')
            if db.execute('SELECT 1 FROM access_events WHERE event_id=?', (event['event_id'],)).fetchone():
                db.rollback(); return False
            # IDs cannot have gaps from ignored inserts: duplicates are checked
            # before INSERT, and deletion/update are prohibited.
            maximum = db.execute('SELECT coalesce(max(id),0) FROM access_events').fetchone()[0]
            if maximum >= MAX_RECORDS: raise EventStorageError('CAPACITY_REACHED')
            db.execute('INSERT INTO access_events(' + ','.join(FIELDS) + ') VALUES (' + ','.join('?' for _ in FIELDS) + ')',
                       [int(event[k]) if k == 'tls_verified' else event[k] for k in FIELDS])
            db.commit()
    except sqlite3.Error as error:
        code = getattr(error, 'sqlite_errorcode', 0) & 0xff
        if code in (sqlite3.SQLITE_BUSY, sqlite3.SQLITE_LOCKED): raise EventStorageError('STORAGE_BUSY') from None
        if code == sqlite3.SQLITE_FULL: raise EventStorageError('CAPACITY_REACHED') from None
        raise EventStorageError('STORAGE_ERROR') from None
    return True


def packet_key(value):
    # Materialized by server-owned unlang, never supplied by User-Name/NAS-IP.
    if type(value) is not str: raise ValueError('Missing native packet key')
    source, port, vector = value.split('|')
    source = str(ipaddress.IPv4Address(source))
    if not port.isdecimal() or not 1 <= int(port) <= 65535: raise ValueError('Invalid native source port')
    if not re.fullmatch(r'0x[0-9a-fA-F]{32}', vector): raise ValueError('Invalid request authenticator')
    return source, hashlib.sha256((source + '|' + str(int(port)) + '|' + vector.lower()).encode('ascii')).hexdigest()


def filters(query):
    if (set(query) - {'before', 'watermark', 'from', 'to', 'result', 'nas', 'reason', 'q'} or
            any(len(v) != 1 for v in query.values())): raise ValueError('Invalid access query')
    q = {k: v[0] for k, v in query.items()}
    start, end = instant(q.get('from', '')), instant(q.get('to', ''))
    if start and end and start >= end: raise ValueError('Invalid time range')
    result = q.get('result', '')
    if result not in ('', 'accept', 'reject'): raise ValueError('Invalid result')
    nas = q.get('nas', '')
    if nas and str(ipaddress.IPv4Address(nas)) != nas: raise ValueError('Invalid NAS')
    reason, text = q.get('reason', ''), q.get('q', '')
    if reason and reason not in REASONS: raise ValueError('Invalid reason')
    if len(text) > 128 or any(ord(c) < 32 or ord(c) == 127 for c in text): raise ValueError('Invalid search')
    return {'start': start, 'end': end, 'result': result, 'nas': nas, 'reason': reason, 'q': text,
            'before': number(q['before']) if 'before' in q else None,
            'watermark': number(q['watermark'], zero=True) if 'watermark' in q else None}


def runtime_status(runtime):
    path = Path(runtime) / 'observer-status.json'
    try:
        _private(path)
        if path.stat().st_size > 2048: return None
        data = json.loads(path.read_text())
        if (type(data) is not dict or type(data.get('requested')) is not bool or
                type(data.get('enabled')) is not bool or not instant(data.get('at', ''))): return None
        result = {k: data[k] for k in ('requested', 'enabled', 'at')}
        for k in ('attempted', 'committed', 'duplicates', 'dropped', 'pid'):
            v = data.get(k)
            if type(v) is int and 0 <= v <= 2**63 - 1: result[k] = v
        for k in ('capture_run', 'last_error_code'):
            v = data.get(k)
            if type(v) is str and re.fullmatch(r'[A-Za-z0-9_]{1,64}', v): result[k] = v
        return result
    except (OSError, ValueError, TypeError, EventStorageError): return None


def history(state, query, *, runtime=Path('/run/authwire-radius')):
    f = filters(query)
    root, path = paths(state)
    base = {'events': [], 'watermark': 0, 'has_more': False, 'next_before': None, 'limit': LIMIT,
            'storage': {'records': 0, 'database_bytes': 0, 'max_records': MAX_RECORDS,
                        'max_bytes': MAX_BYTES, 'automatic_deletion': False},
            'coverage': {'server_selected_responses': True, 'nas_receipt_proven': False,
                         'endpoint_success_proven': False, 'accounting_sessions': False,
                         'silent_drops_included': False, 'complete_delivery_guaranteed': False},
            'initialized': False, 'observer': runtime_status(runtime) if runtime is not None else None}
    if not root.exists() and not root.is_symlink(): return base
    _private(root, directory=True)
    if not path.exists() and not path.is_symlink(): return base
    _private(path)
    with closing(sqlite3.connect(path.as_uri() + '?mode=ro', uri=True, timeout=0.25)) as db:
        deadline = time.monotonic() + 2
        db.set_progress_handler(lambda: int(time.monotonic() > deadline), 1000)
        db.execute('PRAGMA query_only=ON'); db.execute('BEGIN')
        try:
            n, high = db.execute('SELECT count(*),coalesce(max(id),0) FROM access_events').fetchone()
            watermark = high if f['watermark'] is None else min(high, f['watermark'])
            clauses, args = ['id<=?'], [watermark]
            for key, clause in [('before', 'id<?'), ('start', 'at>=?'), ('end', 'at<?'),
                                ('nas', 'nas_ip=?'), ('reason', 'reason=?')]:
                if f[key]: clauses.append(clause); args.append(f[key])
            if f['result']: clauses.append('response_code=?'); args.append(2 if f['result'] == 'accept' else 3)
            if f['q']:
                clauses.append("instr(lower(coalesce(certificate_serial,'')||' '||coalesce(object_guid,'')||' '||coalesce(policy_id,'')||' '||coalesce(calling_station,'')),lower(?))>0")
                args.append(f['q'])
            rows = db.execute('SELECT id,' + ','.join(FIELDS) + ' FROM access_events WHERE ' +
                              ' AND '.join(clauses) + ' ORDER BY id DESC LIMIT ?', [*args, LIMIT + 1]).fetchall()
        except sqlite3.OperationalError as error:
            if getattr(error, 'sqlite_errorcode', None) == sqlite3.SQLITE_INTERRUPT: raise AuditQueryLimit() from None
            raise
    more = len(rows) > LIMIT; rows = rows[:LIMIT]
    events = [dict(zip(('id', *FIELDS), row)) for row in rows]
    for event in events: event['tls_verified'] = bool(event['tls_verified'])
    base.update(events=events, watermark=watermark, has_more=more, initialized=True,
                next_before=events[-1]['id'] if events and more else None)
    base['storage'].update(records=n, database_bytes=path.stat().st_size,
                           capacity_reached=high >= MAX_RECORDS or path.stat().st_size >= MAX_BYTES)
    return base
