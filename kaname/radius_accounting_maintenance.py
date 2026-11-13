"""Archive a verified Accounting snapshot before pruning expired history."""
import argparse
from contextlib import closing
from datetime import datetime, timedelta, timezone
import hashlib
import json
import os
from pathlib import Path
import sqlite3
import tempfile
import time
import uuid

from .radius_accounting import AccountingStorageError, _private, paths


def _expired(db, cutoff):
    db.execute('CREATE TEMP TABLE expired_sessions(id INTEGER PRIMARY KEY)')
    db.execute('INSERT INTO expired_sessions SELECT id FROM accounting_sessions '
               'WHERE stopped_at < ? AND last_at < ?', (cutoff, cutoff))
    db.execute('CREATE TEMP TABLE expired_events(id INTEGER PRIMARY KEY)')
    db.execute('INSERT INTO expired_events SELECT id FROM accounting_events WHERE '
               'session_instance IN (SELECT id FROM expired_sessions) '
               'OR (session_instance IS NULL AND orphan=1 AND received_at < ?)', (cutoff,))
    return {kind: db.execute('SELECT count(*) FROM expired_' + kind).fetchone()[0]
            for kind in ('sessions', 'events')}


def _archive(source, directory):
    _private(directory, directory=True)
    fd, name = tempfile.mkstemp(prefix='.accounting-', dir=directory)
    os.close(fd)
    temp = Path(name)
    final = directory / ('accounting-' + uuid.uuid4().hex + '.sqlite3')
    try:
        deadline = time.monotonic() + 15

        def progress(*_):
            if time.monotonic() >= deadline:
                raise TimeoutError('Accounting archive deadline exceeded')

        with closing(sqlite3.connect(source.as_uri() + '?mode=ro', uri=True, timeout=0.25)) as reader, \
                closing(sqlite3.connect(temp)) as copy:
            reader.backup(copy, pages=256, progress=progress, sleep=0.05)
            if copy.execute('PRAGMA integrity_check').fetchall() != [('ok',)]:
                raise AccountingStorageError('ARCHIVE_INVALID')
        with temp.open('rb') as handle:
            digest = hashlib.file_digest(handle, 'sha256').hexdigest()
            os.fsync(handle.fileno())
        os.link(temp, final)
        directory_fd = os.open(directory, os.O_RDONLY | os.O_DIRECTORY)
        try:
            os.fsync(directory_fd)
        finally:
            os.close(directory_fd)
        return final, digest
    finally:
        temp.unlink(missing_ok=True)


def maintain(state, *, keep_days, archive_dir=None, now=None):
    """Preview, or archive then remove expired closed sessions and orphan events.

    No age-based deletion of open sessions. Archive directory must already
    exist and be private to the service account, outside application state.
    """
    if type(keep_days) is not int or not 1 <= keep_days <= 3650:
        raise ValueError('Retention must be 1 to 3650 days')
    now = now if now is not None else datetime.now(timezone.utc)
    if now.utcoffset() is None:
        raise ValueError('Timezone required')
    cutoff = (now.astimezone(timezone.utc) - timedelta(days=keep_days)).isoformat(
        timespec='milliseconds').replace('+00:00', 'Z')
    root, path = paths(state)
    _private(root, directory=True)
    _private(path)
    if archive_dir is not None:
        archive_dir = Path(archive_dir).absolute()
        _private(archive_dir, directory=True)
        if archive_dir.is_relative_to(Path(state).resolve()):
            raise ValueError('Archive directory must be outside application state')
    result = {'cutoff_utc': cutoff, 'applied': False}
    mode = 'ro' if archive_dir is None else 'rw'
    with closing(sqlite3.connect(path.as_uri() + '?mode=' + mode, uri=True, timeout=0.25)) as db:
        if archive_dir is None:
            db.execute('BEGIN')
        else:
            db.execute('PRAGMA synchronous=FULL')
            db.execute('BEGIN IMMEDIATE')
        if db.execute('PRAGMA user_version').fetchone()[0] != 2:
            raise AccountingStorageError('STORAGE_VERSION_UNSUPPORTED')
        counts = _expired(db, cutoff)
        result['eligible'] = counts
        if archive_dir is None or not any(counts.values()):
            return result
        final, digest = _archive(path, archive_dir)
        for kind in ('events', 'sessions'):
            changed = db.execute('DELETE FROM accounting_' + kind +
                                 ' WHERE id IN (SELECT id FROM expired_' + kind + ')').rowcount
            if changed != counts[kind]:
                raise AccountingStorageError('CLEANUP_COUNT_CHANGED')
        db.commit()
    return dict(result, applied=True, archive=final.name, sha256=digest)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--state-dir', default='/var/lib/kaname-lab')
    parser.add_argument('--keep-days', type=int, required=True)
    parser.add_argument('--archive-dir', help='Private archive directory required to apply')
    parser.add_argument('--apply', action='store_true')
    args = parser.parse_args()
    if args.apply != bool(args.archive_dir):
        parser.error('--apply and --archive-dir must be used together')
    try:
        print(json.dumps(maintain(args.state_dir, keep_days=args.keep_days,
                                  archive_dir=args.archive_dir)))
    except (ValueError, OSError, sqlite3.Error, AccountingStorageError) as error:
        parser.exit(1, 'Accounting maintenance failed: ' + type(error).__name__ + '\n')


if __name__ == '__main__':
    main()
