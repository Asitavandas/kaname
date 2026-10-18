"""Bounded read-only views of existing append-only management audit tables.

No RADIUS decisions, accounting sessions or historical actors are invented here.
"""
from contextlib import closing
from datetime import datetime, timezone
import json
import re
import sqlite3
import time

LIMIT = 100


class AuditQueryLimit(Exception):
    pass


def number(value, *, zero=False):
    if type(value) is not str or not re.fullmatch(r'0|[1-9][0-9]{0,18}', value):
        raise ValueError('Invalid audit cursor')
    n = int(value)
    if n < (0 if zero else 1) or n > 2**63 - 1: raise ValueError('Invalid audit cursor')
    return n


def instant(value):
    if not value: return ''
    if len(value) > 40: raise ValueError('Invalid audit time')
    result = datetime.fromisoformat(value.replace('Z', '+00:00'))
    if result.tzinfo is None: raise ValueError('Audit time needs timezone')
    return result.astimezone(timezone.utc).isoformat(timespec='milliseconds').replace('+00:00', 'Z')


def parse(query):
    if set(query) - {'source', 'before', 'watermark', 'from', 'to', 'event', 'q'} or any(len(v) != 1 for v in query.values()):
        raise ValueError('Invalid audit query')
    values = {k: v[0] for k, v in query.items()}
    source = values.get('source', 'application')
    if source not in {'application', 'administrators'}: raise ValueError('Invalid audit source')
    start, end = instant(values.get('from', '')), instant(values.get('to', ''))
    if start and end and start >= end: raise ValueError('Invalid audit range')
    event, q = values.get('event', ''), values.get('q', '')
    if event and not re.fullmatch(r'[a-z][a-z0-9_]{0,63}', event): raise ValueError('Invalid audit event')
    if len(q) > 128 or any(ord(c) < 32 or ord(c) == 127 for c in q): raise ValueError('Invalid audit search')
    return {'source': source, 'before': number(values['before']) if 'before' in values else None,
            'watermark': number(values['watermark'], zero=True) if 'watermark' in values else None,
            'start': start, 'end': end, 'event': event, 'q': q}


def _project(row, source):
    if source == 'administrators':
        return {'id': row[0], 'source': source, 'event': row[1], 'at': row[4],
                'actor': row[2], 'target': row[3], 'revision': None, 'reference': None,
                'service': None, 'action': None, 'request_id': None}
    raw = row[1]; kind, _, rest = raw.partition(':')
    result = {'id': row[0], 'source': source, 'event': kind if re.fullmatch(r'[a-z][a-z0-9_]{0,63}', kind) else 'unrecognized_event',
              'at': row[3], 'revision': row[2], 'actor': None, 'target': None,
              'reference': None, 'service': None, 'action': None, 'request_id': None}
    if kind == 'service_action_requested':
        try:
            data = json.loads(rest)
            # Projection only; never return an arbitrary JSON payload.
            for key in ('actor', 'service', 'action', 'request_id'):
                value = data.get(key)
                if type(value) is str and len(value) <= 64 and not any(ord(c) < 32 for c in value): result[key] = value
        except (ValueError, TypeError, AttributeError): pass
    else:
        reference = rest.partition(':')[0]
        if re.fullmatch(r'[a-fA-F0-9-]{1,40}', reference): result['reference'] = reference
        actor = raw.rpartition(':actor:')[2]
        if ':actor:' in raw and re.fullmatch(r'[A-Za-z0-9_-]{1,64}', actor): result['actor'] = actor
    return result


def history(store, admin, query, *, administrators=False):
    filters = parse(query)
    if filters['source'] == 'administrators' and not administrators: raise PermissionError('Administrator audit permission required')
    source = filters['source']; path = store.path if source == 'application' else admin.path
    table = 'audit' if source == 'application' else 'admin_audit'
    columns = 'id,event,revision,at' if source == 'application' else 'id,event,actor_id,target_id,at'
    with closing(sqlite3.connect(path.as_uri() + '?mode=ro', uri=True, timeout=1)) as db:
        deadline = time.monotonic() + 2
        db.set_progress_handler(lambda: int(time.monotonic() > deadline), 1000)
        db.execute('PRAGMA query_only=ON'); db.execute('BEGIN')
        try:
            count = db.execute('SELECT count(*) FROM ' + table).fetchone()[0]
            last = db.execute('SELECT id,at FROM ' + table + ' ORDER BY id DESC LIMIT 1').fetchone()
            first = db.execute('SELECT at FROM ' + table + ' ORDER BY id LIMIT 1').fetchone()
            high, newest = last if last else (0, None); oldest = first[0] if first else None
            watermark = high if filters['watermark'] is None else min(high, filters['watermark'])
            clauses, args = ['id<=?'], [watermark]
            if filters['before'] is not None: clauses.append('id<?'); args.append(filters['before'])
            if filters['start']: clauses.append('at>=?'); args.append(filters['start'])
            if filters['end']: clauses.append('at<?'); args.append(filters['end'])
            if filters['event']:
                clauses.append('(event=? OR substr(event,1,?)=?)')
                args.extend([filters['event'], len(filters['event']) + 1, filters['event'] + ':'])
            if filters['q']: clauses.append('instr(lower(event),lower(?))>0'); args.append(filters['q'])
            rows = db.execute('SELECT ' + columns + ' FROM ' + table + ' WHERE ' + ' AND '.join(clauses) + ' ORDER BY id DESC LIMIT ?', [*args, LIMIT + 1]).fetchall()
        except sqlite3.OperationalError as error:
            if getattr(error, 'sqlite_errorcode', None) == sqlite3.SQLITE_INTERRUPT: raise AuditQueryLimit() from None
            raise
    more = len(rows) > LIMIT; rows = rows[:LIMIT]
    return {'events': [_project(r, source) for r in rows], 'source': source, 'watermark': watermark,
            'next_before': rows[-1][0] if rows and more else None, 'has_more': more, 'limit': LIMIT,
            'sources': ['application', *(['administrators'] if administrators else [])],
            'storage': {'records': count, 'oldest': oldest, 'newest': newest, 'database_bytes': path.stat().st_size,
                        'automatic_deletion': False, 'append_only': True},
            'coverage': {'radius_decisions': False, 'accounting_sessions': False,
                         'service_requests_are_completion_proof': False}}
