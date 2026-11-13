"""Idempotent, private RADIUS Accounting event and session storage.

The native FreeRADIUS callback must call ingest only after its NAS shared-secret
validation and pass packet metadata from server-owned attributes. User-Name and
other identity claims are intentionally not persisted here.
"""
from contextlib import closing
from datetime import datetime, timezone
import hashlib
import ipaddress
import os
from pathlib import Path
import re
import shutil
import sqlite3
import stat
import time

from .audit import AuditQueryLimit, LIMIT, number
from .radius_events import access_accepts, class_event_id

MAX_BYTES = 64 * 1024 * 1024
MAX_RECORDS = 200_000
MIN_FREE_BYTES = 128 * 1024 * 1024
BUSY_SECONDS = 0.025
STATUSES = {'1': 'Start', '2': 'Stop', '3': 'Interim-Update',
            'Start': 'Start', 'Stop': 'Stop', 'Interim-Update': 'Interim-Update'}
COUNTERS = ('Acct-Session-Time', 'Acct-Input-Octets', 'Acct-Input-Gigawords',
            'Acct-Output-Octets', 'Acct-Output-Gigawords')


class AccountingStorageError(Exception):
    """Fixed storage error; do not expose packet, SQLite, or filesystem data."""


def paths(state):
    root = Path(state).absolute() / 'radius-accounting'
    return root, root / 'accounting.sqlite3'


def _private(path, *, directory=False):
    info = path.lstat()
    expected = stat.S_ISDIR(info.st_mode) if directory else stat.S_ISREG(info.st_mode)
    if (not expected or info.st_mode & 0o077 or
            (os.name == 'posix' and info.st_uid != os.geteuid()) or
            (not directory and info.st_nlink != 1)):
        raise AccountingStorageError('UNSAFE_STORAGE')
    for parent in path.parents:
        if parent.is_symlink():
            raise AccountingStorageError('UNSAFE_STORAGE')


def initialize(state):
    """Create the bounded database during service setup, never in packet path."""
    root, path = paths(state)
    if root.is_symlink():
        raise AccountingStorageError('UNSAFE_STORAGE')
    root.mkdir(mode=0o700, exist_ok=True)
    _private(root, directory=True)
    if not path.exists():
        fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
        os.close(fd)
    _private(path)
    with closing(sqlite3.connect(path, timeout=1)) as db:
        version = db.execute('PRAGMA user_version').fetchone()[0]
        if version not in (0, 1, 2):
            raise AccountingStorageError('STORAGE_ERROR')
        db.executescript("""
            PRAGMA journal_mode=DELETE;
            PRAGMA synchronous=FULL;
            CREATE TABLE IF NOT EXISTS accounting_events (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                event_key TEXT NOT NULL UNIQUE,
                nas_ip TEXT NOT NULL,
                session_id TEXT NOT NULL,
                status TEXT NOT NULL CHECK(status IN ('Start','Stop','Interim-Update')),
                received_at TEXT NOT NULL,
                session_time INTEGER,
                input_bytes INTEGER,
                output_bytes INTEGER,
                calling_station TEXT,
                nas_port TEXT,
                session_instance INTEGER,
                orphan INTEGER NOT NULL CHECK(orphan IN (0,1))
            );
            CREATE TABLE IF NOT EXISTS accounting_sessions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                nas_ip TEXT NOT NULL,
                session_id TEXT NOT NULL,
                started_at TEXT NOT NULL,
                last_at TEXT NOT NULL,
                stopped_at TEXT,
                session_time INTEGER,
                input_bytes INTEGER,
                output_bytes INTEGER,
                calling_station TEXT,
                nas_port TEXT
            );
            CREATE INDEX IF NOT EXISTS accounting_events_session
                ON accounting_events(nas_ip, session_id, id);
            CREATE INDEX IF NOT EXISTS accounting_sessions_lookup
                ON accounting_sessions(nas_ip, session_id, id);
        """)
        db.execute('BEGIN IMMEDIATE')
        if 'access_event_id' not in {row[1] for row in db.execute('PRAGMA table_info(accounting_sessions)')}:
            db.execute('ALTER TABLE accounting_sessions ADD COLUMN access_event_id TEXT')
        db.execute('PRAGMA user_version=2')
        db.commit()
    return path


def _values(pairs, name, *, required=False):
    values = [value for key, value in pairs or ()
              if key == name or key.startswith(name + ':')]
    if len(values) != 1 or type(values[0]) is not str:
        if required:
            raise ValueError('Missing native accounting attribute')
        return None
    value = values[0]
    if len(value) >= 2 and value[0] == value[-1] == '"':
        value = value[1:-1]
    return value


def _counter(value, name):
    if value is None:
        return None
    if not value.isdecimal() or int(value) > 2**32 - 1:
        raise ValueError('Invalid accounting counter')
    return int(value)


def _mac(value):
    if value is None:
        return None
    compact = re.sub(r'[:-]', '', value).lower()
    if not re.fullmatch(r'[0-9a-f]{12}', compact):
        return None
    return ':'.join(compact[i:i + 2] for i in range(0, 12, 2))


def _bytes(octets, gigawords):
    low, high = _counter(octets, 'octets'), _counter(gigawords, 'gigawords')
    if low is None and high is None:
        return None
    return (high or 0) * 2**32 + (low or 0)


def parse(pairs):
    """Validate server-supplied accounting attributes and make a safe event."""
    nas = _values(pairs, 'Packet-Src-IP-Address', required=True)
    nas = str(ipaddress.IPv4Address(nas))
    vector = _values(pairs, 'Packet-Authentication-Vector', required=True)
    if not re.fullmatch(r'0x[0-9a-fA-F]{32}', vector):
        raise ValueError('Invalid accounting request authenticator')
    session = _values(pairs, 'Acct-Session-Id', required=True)
    if (not 1 <= len(session) <= 128 or
            any(ord(char) < 0x21 or ord(char) > 0x7e for char in session)):
        raise ValueError('Invalid accounting session ID')
    status = _values(pairs, 'Acct-Status-Type', required=True)
    if status not in STATUSES:
        raise ValueError('Unsupported accounting status')
    status = STATUSES[status]
    session_time = _counter(_values(pairs, 'Acct-Session-Time'), 'session time')
    input_bytes = _bytes(_values(pairs, 'Acct-Input-Octets'),
                         _values(pairs, 'Acct-Input-Gigawords'))
    output_bytes = _bytes(_values(pairs, 'Acct-Output-Octets'),
                          _values(pairs, 'Acct-Output-Gigawords'))
    station = _mac(_values(pairs, 'Calling-Station-Id'))
    port = _values(pairs, 'NAS-Port-Id') or _values(pairs, 'NAS-Port')
    if port is not None and (not 1 <= len(port) <= 64 or
                             any(ord(char) < 0x20 or ord(char) == 0x7f for char in port)):
        port = None
    # Request Authenticator is stable across retransmissions; source UDP port is
    # deliberately excluded so a retry from a changed port remains idempotent.
    event_key = hashlib.sha256((nas + '|' + vector.lower()).encode('ascii')).hexdigest()
    received_at = datetime.now(timezone.utc).isoformat(timespec='milliseconds').replace('+00:00', 'Z')
    return {'event_key': event_key, 'nas_ip': nas, 'session_id': session, 'status': status,
            'received_at': received_at, 'session_time': session_time,
            'input_bytes': input_bytes, 'output_bytes': output_bytes,
            'calling_station': station, 'nas_port': port,
            'access_event_id': class_event_id(pairs)}


def ingest(state, pairs):
    """Append one authenticated accounting packet and update its NAS-scoped session.

    Returns False for an exact retransmission. A Stop/Interim without an active
    Start remains an auditable orphan event and never creates a phantom session.
    """
    event = parse(pairs)
    root, path = paths(state)
    _private(root, directory=True)
    _private(path)
    if path.stat().st_size >= MAX_BYTES:
        raise AccountingStorageError('CAPACITY_REACHED')
    if shutil.disk_usage(root).free < MIN_FREE_BYTES:
        raise AccountingStorageError('LOW_DISK_SPACE')
    try:
        with closing(sqlite3.connect(path.as_uri() + '?mode=rw', uri=True,
                                     timeout=BUSY_SECONDS)) as db:
            db.execute('PRAGMA synchronous=FULL')
            db.execute('PRAGMA max_page_count=' + str(MAX_BYTES // 4096))
            db.execute('BEGIN IMMEDIATE')
            if db.execute('SELECT 1 FROM accounting_events WHERE event_key=?',
                          (event['event_key'],)).fetchone():
                db.rollback()
                return False
            count = db.execute('SELECT count(*) FROM accounting_events').fetchone()[0]
            if count >= MAX_RECORDS:
                raise AccountingStorageError('CAPACITY_REACHED')

            session_row = None
            if event['status'] == 'Start':
                session_row = db.execute(
                    'SELECT id,stopped_at FROM accounting_sessions '
                    'WHERE nas_ip=? AND session_id=? ORDER BY id DESC LIMIT 1',
                    (event['nas_ip'], event['session_id'])).fetchone()
                if session_row is None or session_row[1] is not None:
                    cursor = db.execute(
                        'INSERT INTO accounting_sessions(nas_ip,session_id,started_at,last_at,'
                        'session_time,input_bytes,output_bytes,calling_station,nas_port,access_event_id) '
                        'VALUES(?,?,?,?,?,?,?,?,?,?)',
                        (event['nas_ip'], event['session_id'], event['received_at'],
                         event['received_at'], event['session_time'], event['input_bytes'],
                         event['output_bytes'], event['calling_station'], event['nas_port'], event['access_event_id']))
                    session_row = (cursor.lastrowid, None)
            else:
                session_row = db.execute(
                    'SELECT id,stopped_at FROM accounting_sessions '
                    'WHERE nas_ip=? AND session_id=? AND stopped_at IS NULL '
                    'ORDER BY id DESC LIMIT 1',
                    (event['nas_ip'], event['session_id'])).fetchone()

            orphan = session_row is None
            instance = session_row[0] if session_row else None
            db.execute(
                'INSERT INTO accounting_events(event_key,nas_ip,session_id,status,received_at,'
                'session_time,input_bytes,output_bytes,calling_station,nas_port,session_instance,orphan) '
                'VALUES(?,?,?,?,?,?,?,?,?,?,?,?)',
                (event['event_key'], event['nas_ip'], event['session_id'], event['status'],
                 event['received_at'], event['session_time'], event['input_bytes'],
                 event['output_bytes'], event['calling_station'], event['nas_port'],
                 instance, int(orphan)))
            if session_row is not None and event['status'] != 'Start':
                if event['status'] == 'Stop':
                    db.execute(
                        'UPDATE accounting_sessions SET last_at=?,stopped_at=?,session_time=coalesce(?,session_time),'
                        'input_bytes=coalesce(?,input_bytes),output_bytes=coalesce(?,output_bytes),calling_station=coalesce(?,calling_station),'
                        'nas_port=coalesce(?,nas_port) WHERE id=?',
                        (event['received_at'], event['received_at'], event['session_time'],
                         event['input_bytes'], event['output_bytes'], event['calling_station'],
                         event['nas_port'], instance))
                else:
                    db.execute(
                        'UPDATE accounting_sessions SET last_at=?,session_time=coalesce(?,session_time),'
                        'input_bytes=coalesce(?,input_bytes),output_bytes=coalesce(?,output_bytes),calling_station=coalesce(?,calling_station),'
                        'nas_port=coalesce(?,nas_port) WHERE id=?',
                        (event['received_at'], event['session_time'], event['input_bytes'],
                         event['output_bytes'], event['calling_station'], event['nas_port'], instance))
            db.commit()
    except sqlite3.Error as error:
        code = getattr(error, 'sqlite_errorcode', 0) & 0xff
        if code in (sqlite3.SQLITE_BUSY, sqlite3.SQLITE_LOCKED):
            raise AccountingStorageError('STORAGE_BUSY') from None
        if code == sqlite3.SQLITE_FULL:
            raise AccountingStorageError('CAPACITY_REACHED') from None
        raise AccountingStorageError('STORAGE_ERROR') from None
    return True
def session_history(state, query):
    """Read a bounded page of NAS-reported sessions without creating storage."""
    if set(query) - {'before', 'watermark'} or any(len(values) != 1 for values in query.values()):
        raise ValueError('Invalid accounting session query')
    before = number(query['before'][0]) if 'before' in query else None
    watermark = number(query['watermark'][0], zero=True) if 'watermark' in query else None
    root, path = paths(state)
    empty = {'initialized': False, 'sessions': [], 'watermark': '0',
             'has_more': False, 'next_before': None}
    if not root.exists() and not root.is_symlink():
        return empty
    _private(root, directory=True)
    if not path.exists() and not path.is_symlink():
        return empty
    _private(path)

    with closing(sqlite3.connect(path.as_uri() + '?mode=ro', uri=True, timeout=0.25)) as db:
        db.row_factory = sqlite3.Row
        deadline = time.monotonic() + 2
        db.set_progress_handler(lambda: int(time.monotonic() >= deadline), 1000)
        try:
            db.execute('BEGIN')
            high = db.execute('SELECT coalesce(max(id), 0) FROM accounting_sessions').fetchone()[0]
            high = high if watermark is None else min(watermark, high)
            filters, args = 'id <= ?', [high]
            if before is not None:
                filters += ' AND id < ?'
                args.append(before)
            version = db.execute('PRAGMA user_version').fetchone()[0]
            link_column = 'access_event_id' if version == 2 else 'NULL'
            rows = db.execute(
                'SELECT CAST(id AS TEXT) AS id, nas_ip, session_id, started_at, last_at, '
                'stopped_at, session_time, CAST(input_bytes AS TEXT) AS input_bytes, '
                'CAST(output_bytes AS TEXT) AS output_bytes, calling_station, nas_port '
                f', {link_column} AS access_event_id FROM accounting_sessions WHERE ' + filters + ' ORDER BY accounting_sessions.id DESC LIMIT ?',
                (*args, LIMIT + 1)).fetchall()
        except sqlite3.OperationalError as error:
            if getattr(error, 'sqlite_errorcode', None) == sqlite3.SQLITE_INTERRUPT:
                raise AuditQueryLimit() from None
            raise
    more = len(rows) > LIMIT
    sessions = [dict(row) for row in rows[:LIMIT]]
    keys = [row.pop('access_event_id') for row in sessions]
    decisions = access_accepts(state, {key for key in keys if key})
    for session, key in zip(sessions, keys):
        decision = decisions.get(key)
        session['access_decision'] = (decision if decision and decision['nas_ip'] == session['nas_ip']
                                      and decision['at'] <= session['started_at'] else None)
    return {'initialized': True, 'sessions': sessions, 'watermark': str(high),
            'has_more': more, 'next_before': sessions[-1]['id'] if more else None}
