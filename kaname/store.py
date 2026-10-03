"""Revision-controlled SQLite configuration with atomic append-only audit."""
import json
import os
import sqlite3
from contextlib import contextmanager
from pathlib import Path

from .models import integer, validate_config, validate_policies


class ConflictError(ValueError):
    pass


class Store:
    def __init__(self, root):
        self.root = Path(root).absolute()
        if self.root.is_symlink():
            raise ValueError('State directory cannot be a symbolic link')
        self.root.mkdir(parents=True, exist_ok=True, mode=0o700)
        if os.name == 'posix':
            if self.root.stat().st_uid != os.getuid():
                raise ValueError('State directory owner mismatch')
            self.root.chmod(0o700)
        self.path = self.root / 'kaname.sqlite3'
        if self.path.is_symlink():
            raise ValueError('Database cannot be a symbolic link')
        with self.connect() as db:
            db.executescript('''
            CREATE TABLE IF NOT EXISTS state (id INTEGER PRIMARY KEY CHECK(id=1), revision INTEGER NOT NULL, config TEXT, policies TEXT NOT NULL);
            INSERT OR IGNORE INTO state VALUES (1, 0, NULL, '[]');
            CREATE TABLE IF NOT EXISTS audit (id INTEGER PRIMARY KEY AUTOINCREMENT, event TEXT NOT NULL, revision INTEGER NOT NULL, at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')));
            CREATE TRIGGER IF NOT EXISTS audit_no_update BEFORE UPDATE ON audit BEGIN SELECT RAISE(ABORT, 'append only'); END;
            CREATE TRIGGER IF NOT EXISTS audit_no_delete BEFORE DELETE ON audit BEGIN SELECT RAISE(ABORT, 'append only'); END;
            ''')
        if os.name == 'posix':
            self.path.chmod(0o600)

    @contextmanager
    def connect(self):
        db = sqlite3.connect(self.path, timeout=3)
        try:
            with db:
                yield db
        finally:
            db.close()

    def snapshot(self):
        with self.connect() as db:
            revision, config, policies = db.execute('SELECT revision, config, policies FROM state WHERE id=1').fetchone()
        return {'revision': revision, 'config': json.loads(config) if config else None, 'policies': json.loads(policies)}

    def save(self, expected_revision, *, config=None, policies=None):
        integer(expected_revision, 0, 2**53 - 2)
        if (config is None) == (policies is None):
            raise ValueError('Exactly one state section is required')
        section = 'config' if config is not None else 'policies'
        value = validate_config(config) if config is not None else validate_policies(policies)
        with self.connect() as db:
            db.execute('BEGIN IMMEDIATE')
            revision = db.execute('SELECT revision FROM state WHERE id=1').fetchone()[0]
            if revision != expected_revision:
                raise ConflictError('State changed; refresh before saving')
            db.execute(f'UPDATE state SET {section}=?, revision=? WHERE id=1',
                       (json.dumps(value, ensure_ascii=False, allow_nan=False), revision + 1))
            db.execute('INSERT INTO audit(event, revision) VALUES (?,?)',
                       (section + '_saved', revision + 1))
        return revision + 1

    def audit(self):
        with self.connect() as db:
            rows = db.execute('SELECT id,event,revision,at FROM audit ORDER BY id DESC LIMIT 100').fetchall()
        return [dict(zip(('id', 'event', 'revision', 'at'), r)) for r in rows]

    def public_pki_status(self):
        """Read public metadata only; never decrypt keys or create a CA."""
        with self.connect() as db:
            if not db.execute("SELECT 1 FROM sqlite_master WHERE type='table' AND name='pki_authority'").fetchone():
                return {'initialized': False, 'mode': 'not-initialized', 'client_enrollment_enabled': False, 'radius_connected': False}
            row = db.execute('SELECT public_data,crl_number FROM pki_authority WHERE id=1').fetchone()
            if row is None:
                return {'initialized': False, 'mode': 'not-initialized', 'client_enrollment_enabled': False, 'radius_connected': False}
            value = json.loads(row[0])
            # Explicit output projection even if database metadata is malformed.
            public_certs = {kind: {k: value[kind][k] for k in ('serial', 'fingerprint_sha256', 'not_before', 'not_after')}
                            for kind in ('root', 'issuer')}
            return {**{k: value[k] for k in ('initialized', 'mode', 'instance_id')}, **public_certs,
                    'client_enrollment_enabled': False, 'radius_connected': False, 'crl_number': row[1]}
