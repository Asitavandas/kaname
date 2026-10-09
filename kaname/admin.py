"""Local panel accounts and least-privilege sessions, independent of AD."""
import hashlib
import hmac
import json
import os
import re
import secrets
import sqlite3
import time
import uuid
from pathlib import Path

from .models import ValidationError, boolean, integer, keys, text
from .store import ConflictError

ITERATIONS = 600_000
RESOURCES = {
    'setup.product': ['Kurulum', 'Ürün'], 'setup.directory': ['Kurulum', 'Dizin'],
    'setup.network': ['Kurulum', 'Ağ erişimi'], 'policies.rules': ['Politikalar', 'Kurallar'],
    'simulate.scenarios': ['Karar testi', 'Senaryolar'], 'audit.events': ['İşlem geçmişi', 'Kayıtlar'],
    'certificates.authority': ['Sertifikalar', 'Dahili CA'],
    'directory.connection': ['User&Authentication', 'Active Directory'],
    'directory.catalog': ['User&Authentication', 'Users/User Groups'],
    'system.administrators': ['System', 'Administrators'], 'system.profiles': ['System', 'Admin Profiles'],
    'network.devices': ['Network', 'Device Inventory'],
    'network.vlans': ['Network', 'VLANs'], 'network.radius': ['Network', 'RADIUS Clients'],
}
LEVELS = {'none': 0, 'read': 1, 'write': 2}
COOKIE = 'kaname_session'
TTL = 8 * 3600
IDLE = 30 * 60


class AdminError(Exception):
    def __init__(self, code):
        self.code = code
        super().__init__(code)


def password_hash(password):
    salt = secrets.token_hex(16)
    digest = hashlib.pbkdf2_hmac('sha256', password.encode(), bytes.fromhex(salt), ITERATIONS).hex()
    return f'pbkdf2_sha256${ITERATIONS}${salt}${digest}'


def password_matches(password, encoded):
    try:
        algorithm, count, salt, expected = encoded.split('$')
        if algorithm != 'pbkdf2_sha256' or not 1 <= int(count) <= 2_000_000 or len(salt) != 32 or len(expected) != 64:
            return False
        actual = hashlib.pbkdf2_hmac('sha256', password.encode(), bytes.fromhex(salt), int(count)).hex()
        return hmac.compare_digest(actual, expected)
    except (ValueError, TypeError):
        return False


def permissions(mode, grants):
    if mode == 'SuperAdmin':
        return {k: 'write' for k in RESOURCES}
    if mode == 'Admin_ReadOnly':
        return {k: 'read' for k in RESOURCES}
    if mode != 'Custom' or type(grants) is not dict or set(grants) - set(RESOURCES) or any(type(v) is not str or v not in LEVELS for v in grants.values()):
        raise ValidationError('Invalid profile permissions')
    # Preserve the connection right of existing Custom profiles until edited.
    return {k: grants.get(k, grants.get('directory.catalog', 'none') if k == 'directory.connection' else 'none') for k in RESOURCES}


def permits(actor, resource, write=False):
    return LEVELS.get(actor['permissions'].get(resource, 'none'), 0) >= (2 if write else 1)


def digest(value):
    return hashlib.sha256(value.encode()).hexdigest()


class AdminStore:
    def __init__(self, store):
        self.store = store
        self.path = store.root / 'administrators.sqlite3'
        if self.path.is_symlink():
            raise ValueError('Administrator database cannot be a symbolic link')
        # This hash also supplies equal-work verification for unknown accounts.
        self.dummy = password_hash(secrets.token_hex(32))
        with self.connect() as db:
            db.executescript('''
                CREATE TABLE IF NOT EXISTS admin_meta (id INTEGER PRIMARY KEY CHECK(id=1),revision INTEGER NOT NULL);
                CREATE TABLE IF NOT EXISTS admin_profiles (id TEXT PRIMARY KEY,name TEXT NOT NULL UNIQUE,mode TEXT NOT NULL,grants TEXT NOT NULL);
                CREATE TABLE IF NOT EXISTS admin_users (id TEXT PRIMARY KEY,username TEXT NOT NULL,normalized TEXT NOT NULL UNIQUE,password_hash TEXT NOT NULL,profile_id TEXT NOT NULL REFERENCES admin_profiles(id),enabled INTEGER NOT NULL,version INTEGER NOT NULL);
                CREATE TABLE IF NOT EXISTS admin_sessions (digest TEXT PRIMARY KEY,user_id TEXT NOT NULL REFERENCES admin_users(id) ON DELETE CASCADE,user_version INTEGER NOT NULL,csrf TEXT NOT NULL,expires REAL NOT NULL,last_seen REAL NOT NULL);
                CREATE TABLE IF NOT EXISTS admin_login_rate (id INTEGER PRIMARY KEY CHECK(id=1),started REAL NOT NULL,attempts INTEGER NOT NULL);
                CREATE TABLE IF NOT EXISTS admin_audit (id INTEGER PRIMARY KEY AUTOINCREMENT,event TEXT NOT NULL,actor_id TEXT NOT NULL,target_id TEXT NOT NULL,at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')));
                CREATE TRIGGER IF NOT EXISTS admin_audit_no_update BEFORE UPDATE ON admin_audit BEGIN SELECT RAISE(ABORT,'append only'); END;
                CREATE TRIGGER IF NOT EXISTS admin_audit_no_delete BEFORE DELETE ON admin_audit BEGIN SELECT RAISE(ABORT,'append only'); END;
            ''')
            db.execute('BEGIN IMMEDIATE')
            # Seed once, never re-create deleted accounts or profiles on restart.
            if db.execute('SELECT 1 FROM admin_meta WHERE id=1').fetchone() is None:
                db.execute('INSERT INTO admin_meta VALUES (1,0)')
                profile_id = str(uuid.uuid4())
                db.execute('INSERT INTO admin_profiles VALUES (?,?,?,?)', (profile_id, 'SuperAdmin', 'SuperAdmin', '{}'))
                db.execute('INSERT INTO admin_profiles VALUES (?,?,?,?)', (str(uuid.uuid4()), 'Admin_ReadOnly', 'Admin_ReadOnly', '{}'))
                db.execute('INSERT INTO admin_users VALUES (?,?,?,?,?,?,?)', (str(uuid.uuid4()), 'admin', 'admin', password_hash('Kaname'), profile_id, 1, 1))
        if os.name == 'posix':
            self.path.chmod(0o600)

    def connect(self):
        from contextlib import contextmanager

        @contextmanager
        def connection():
            db = sqlite3.connect(self.path, timeout=3)
            db.row_factory = sqlite3.Row
            db.execute('PRAGMA foreign_keys=ON')
            try:
                with db:
                    yield db
            finally:
                db.close()
        return connection()

    def principal(self, row):
        return {'id': row['id'], 'username': row['username'], 'profile_id': row['profile_id'],
                'profile_name': row['profile_name'], 'version': row['version'],
                'permissions': permissions(row['mode'], json.loads(row['grants'])), 'maintenance': False}

    def user_row(self, db, user_id=None, normalized=None):
        field, value = ('u.id', user_id) if user_id else ('u.normalized', normalized)
        return db.execute(f'SELECT u.*,p.name AS profile_name,p.mode,p.grants FROM admin_users u JOIN admin_profiles p ON p.id=u.profile_id WHERE {field}=?', (value,)).fetchone()

    def login(self, username, password):
        if type(username) is not str or type(password) is not str or not 1 <= len(username) <= 64 or not 1 <= len(password) <= 1024 or '\0' in password:
            raise AdminError('LOGIN_FAILED')
        now = time.time()
        with self.connect() as db:
            db.execute('BEGIN IMMEDIATE')
            rate = db.execute('SELECT started,attempts FROM admin_login_rate WHERE id=1').fetchone()
            if rate and now - rate['started'] < 60 and rate['attempts'] >= 30:
                raise AdminError('LOGIN_RATE_LIMIT')
            started, attempts = (rate['started'], rate['attempts'] + 1) if rate and now - rate['started'] < 60 else (now, 1)
            db.execute('INSERT OR REPLACE INTO admin_login_rate VALUES (1,?,?)', (started, attempts))
            row = self.user_row(db, normalized=username.strip().casefold())
        valid = password_matches(password, row['password_hash'] if row else self.dummy)
        if not valid or row is None or not row['enabled']:
            raise AdminError('LOGIN_FAILED')
        session, csrf = secrets.token_urlsafe(32), secrets.token_urlsafe(32)
        with self.connect() as db:
            db.execute('BEGIN IMMEDIATE')
            current = self.user_row(db, user_id=row['id'])
            if current is None or not current['enabled'] or current['version'] != row['version'] or current['password_hash'] != row['password_hash']:
                raise AdminError('LOGIN_FAILED')
            db.execute('DELETE FROM admin_sessions WHERE expires<=? OR last_seen<=?', (now, now - IDLE))
            # Bound valid sessions even across browser windows and process restarts.
            db.execute('DELETE FROM admin_sessions WHERE digest IN (SELECT digest FROM admin_sessions WHERE user_id=? ORDER BY last_seen DESC LIMIT -1 OFFSET 9)', (row['id'],))
            db.execute('INSERT INTO admin_sessions VALUES (?,?,?,?,?,?)', (digest(session), row['id'], row['version'], csrf, now + TTL, now))
            self.record(db, 'admin_login', row['id'], row['id'])
            actor = self.principal(current)
        return session, {**self.public_actor(actor), 'csrf': csrf}

    def authenticate(self, session):
        if type(session) is not str or not re.fullmatch(r'[A-Za-z0-9_-]{43}', session):
            return None
        now = time.time()
        with self.connect() as db:
            row = db.execute('SELECT * FROM admin_sessions WHERE digest=? AND expires>? AND last_seen>?', (digest(session), now, now - IDLE)).fetchone()
            user = self.user_row(db, user_id=row['user_id']) if row else None
            if not user or not user['enabled'] or row['user_version'] != user['version']:
                return None
            db.execute('UPDATE admin_sessions SET last_seen=? WHERE digest=?', (now, digest(session)))
            return {**self.principal(user), 'csrf': row['csrf'], 'session_digest': digest(session)}

    def public_actor(self, actor):
        return {'user': {k: actor[k] for k in ('id', 'username', 'profile_id', 'profile_name')}, 'permissions': actor['permissions']}

    def logout(self, actor):
        with self.connect() as db:
            db.execute('DELETE FROM admin_sessions WHERE digest=?', (actor.get('session_digest', ''),))

    def record(self, db, event, actor_id, target_id):
        db.execute('INSERT INTO admin_audit(event,actor_id,target_id) VALUES (?,?,?)', (event, actor_id, target_id))

    def current_actor(self, db, actor, resource):
        if actor.get('maintenance'):
            return actor
        row = self.user_row(db, user_id=actor['id'])
        if row is None or not row['enabled'] or row['version'] != actor['version']:
            raise AdminError('UNAUTHORIZED')
        current = self.principal(row)
        if not permits(current, resource, True):
            raise AdminError('FORBIDDEN')
        return current

    def delegation(self, actor, grants):
        if any(LEVELS[level] > LEVELS[actor['permissions'][resource]] for resource, level in grants.items()):
            raise AdminError('DELEGATION_DENIED')

    def snapshot(self, actor):
        with self.connect() as db:
            value = {'revision': db.execute('SELECT revision FROM admin_meta WHERE id=1').fetchone()[0], 'resources': RESOURCES}
            if permits(actor, 'system.administrators'):
                value['users'] = [{**dict(r), 'enabled': bool(r['enabled'])} for r in db.execute('SELECT u.id,u.username,u.profile_id,p.name AS profile_name,u.enabled FROM admin_users u JOIN admin_profiles p ON p.id=u.profile_id ORDER BY u.normalized')]
            if permits(actor, 'system.profiles') or permits(actor, 'system.administrators'):
                value['profiles'] = [{'id': r['id'], 'name': r['name'], **({'mode': r['mode'], 'grants': permissions(r['mode'], json.loads(r['grants'])), 'users_count': r['users_count']} if permits(actor, 'system.profiles') else {})} for r in db.execute('SELECT p.*,COUNT(u.id) AS users_count FROM admin_profiles p LEFT JOIN admin_users u ON u.profile_id=p.id GROUP BY p.id ORDER BY p.name')]
            return value

    def check_revision(self, db, value):
        integer(value, 0, 2**53 - 2)
        current = db.execute('SELECT revision FROM admin_meta WHERE id=1').fetchone()[0]
        if current != value:
            raise ConflictError()
        db.execute('UPDATE admin_meta SET revision=revision+1 WHERE id=1')

    def save_profile(self, actor, value):
        keys(value, {'expected_revision', 'profile'}, {'expected_revision', 'profile'})
        p = value['profile']; keys(p, {'id', 'name', 'mode', 'grants'}, {'id', 'name', 'mode', 'grants'})
        profile_id = str(uuid.UUID(p['id'])) if p['id'] else str(uuid.uuid4())
        name = text(p['name'], 64); grants = permissions(p['mode'], p['grants'])
        with self.connect() as db:
            db.execute('BEGIN IMMEDIATE'); actor = self.current_actor(db, actor, 'system.profiles')
            old = db.execute('SELECT * FROM admin_profiles WHERE id=?', (profile_id,)).fetchone()
            if p['id'] and not old: raise AdminError('NOT_FOUND')
            if old: self.delegation(actor, permissions(old['mode'], json.loads(old['grants'])))
            self.delegation(actor, grants); self.check_revision(db, value['expected_revision'])
            db.execute('INSERT INTO admin_profiles VALUES (?,?,?,?) ON CONFLICT(id) DO UPDATE SET name=excluded.name,mode=excluded.mode,grants=excluded.grants', (profile_id, name, p['mode'], json.dumps(grants)))
            self.record(db, 'admin_profile_saved', actor['id'], profile_id)
        return profile_id

    def save_user(self, actor, value):
        keys(value, {'expected_revision', 'user'}, {'expected_revision', 'user'})
        u = value['user']; keys(u, {'id', 'username', 'password', 'profile_id', 'enabled'}, {'id', 'username', 'password', 'profile_id', 'enabled'})
        user_id = str(uuid.UUID(u['id'])) if u['id'] else str(uuid.uuid4())
        username = text(u['username'], 64)
        if not re.fullmatch(r'[\w.@-]{1,64}', username): raise ValidationError('Invalid username')
        boolean(u['enabled']); password = u['password']
        if type(password) is not str or (not u['id'] and not password) or (password and (not 8 <= len(password) <= 1024 or '\0' in password)):
            raise ValidationError('New passwords must be 8 to 1024 characters')
        hashed = password_hash(password) if password else None
        with self.connect() as db:
            db.execute('BEGIN IMMEDIATE'); actor = self.current_actor(db, actor, 'system.administrators')
            profile = db.execute('SELECT * FROM admin_profiles WHERE id=?', (u['profile_id'],)).fetchone()
            if not profile: raise AdminError('PROFILE_REQUIRED')
            self.delegation(actor, permissions(profile['mode'], json.loads(profile['grants'])))
            old = self.user_row(db, user_id=user_id)
            if u['id'] and not old: raise AdminError('NOT_FOUND')
            if old: self.delegation(actor, permissions(old['mode'], json.loads(old['grants'])))
            self.check_revision(db, value['expected_revision'])
            db.execute('INSERT INTO admin_users VALUES (?,?,?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET username=excluded.username,normalized=excluded.normalized,password_hash=excluded.password_hash,profile_id=excluded.profile_id,enabled=excluded.enabled,version=excluded.version', (user_id, username, username.casefold(), hashed or old['password_hash'], u['profile_id'], int(u['enabled']), old['version'] + 1 if old else 1))
            db.execute('DELETE FROM admin_sessions WHERE user_id=?', (user_id,))
            self.record(db, 'admin_user_saved', actor['id'], user_id)
        return user_id

    def delete(self, actor, value, kind):
        keys(value, {'expected_revision', 'id'}, {'expected_revision', 'id'})
        target_id = str(uuid.UUID(value['id']))
        resource = 'system.administrators' if kind == 'user' else 'system.profiles'
        with self.connect() as db:
            db.execute('BEGIN IMMEDIATE'); actor = self.current_actor(db, actor, resource)
            if kind == 'user':
                row = self.user_row(db, user_id=target_id)
                if not row: raise AdminError('NOT_FOUND')
                self.delegation(actor, permissions(row['mode'], json.loads(row['grants'])))
                table = 'admin_users'
            else:
                row = db.execute('SELECT * FROM admin_profiles WHERE id=?', (target_id,)).fetchone()
                if not row: raise AdminError('NOT_FOUND')
                self.delegation(actor, permissions(row['mode'], json.loads(row['grants'])))
                if db.execute('SELECT 1 FROM admin_users WHERE profile_id=?', (target_id,)).fetchone(): raise AdminError('PROFILE_IN_USE')
                table = 'admin_profiles'
            self.check_revision(db, value['expected_revision'])
            db.execute(f'DELETE FROM {table} WHERE id=?', (target_id,))
            self.record(db, 'admin_' + kind + '_deleted', actor['id'], target_id)

    def change_password(self, actor, current, new):
        if type(current) is not str or not 1 <= len(current) <= 1024 or type(new) is not str or not 8 <= len(new) <= 1024 or '\0' in new:
            raise ValidationError('Invalid password')
        with self.connect() as db:
            row = self.user_row(db, user_id=actor['id'])
        if not row or not row['enabled'] or row['version'] != actor['version'] or not password_matches(current, row['password_hash']): raise AdminError('LOGIN_FAILED')
        hashed = password_hash(new)
        with self.connect() as db:
            db.execute('BEGIN IMMEDIATE')
            if db.execute('UPDATE admin_users SET password_hash=?,version=version+1 WHERE id=? AND version=?', (hashed, actor['id'], row['version'])).rowcount != 1:
                raise ConflictError()
            db.execute('DELETE FROM admin_sessions WHERE user_id=?', (actor['id'],))
            db.execute('UPDATE admin_meta SET revision=revision+1 WHERE id=1')
            self.record(db, 'admin_password_changed', actor['id'], actor['id'])

