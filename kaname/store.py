"""Revision-controlled SQLite configuration with atomic append-only audit."""
import json
import importlib.util
import os
import shutil
import sqlite3
import sys
from datetime import datetime, timezone
from contextlib import contextmanager
from pathlib import Path

from .models import integer, validate_config, validate_policies


def _directory_display(value, kind=None):
    """Return a UI-safe copy without changing the stored AD identity."""
    object_kind = kind or value.get('kind')
    if object_kind != 'computers':
        return value
    result = dict(value)
    suffix = chr(36)
    for field in ('name', 'sam'):
        text = result.get(field)
        if isinstance(text, str) and text.endswith(suffix):
            result[field] = text[:-1]
    return result


class ConflictError(ValueError):
    pass


class Store:
    def __init__(self, root):
        self.root = Path(root).absolute()
        if self.root.is_symlink():
            raise ValueError('State directory cannot be a symbolic link')
        self.root.mkdir(parents=True, exist_ok=True, mode=0o700)
        if os.name == 'posix':
            if self.root.stat().st_uid != os.geteuid():
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
            if policies is not None:
                from .policy import PolicyConflictError, policy_conflicts, validate_identity_targets
                catalog = self.directory_catalog()
                validate_identity_targets(value, catalog)
                conflicts = policy_conflicts(value, catalog)
                if conflicts:
                    raise PolicyConflictError(conflicts)
                if db.execute("SELECT 1 FROM sqlite_master WHERE type='table' AND name='runtime_settings'").fetchone():
                    row = db.execute("SELECT payload FROM runtime_settings WHERE name='network'").fetchone()
                    if row and any(p['vlan'] is not None and p['vlan'] not in {v['id'] for v in json.loads(row[0])['vlans']} for p in value):
                        from .models import ValidationError
                        raise ValidationError('VLAN_NOT_DEFINED')
            elif db.execute("SELECT 1 FROM sqlite_master WHERE type='table' AND name='runtime_settings'").fetchone():
                row = db.execute("SELECT payload FROM runtime_settings WHERE name='network'").fetchone()
                if row and value['radius_clients'] != json.loads(row[0])['radius_clients']:
                    from .models import ValidationError
                    raise ValidationError('RADIUS_CLIENTS_MANAGED')
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

    def save_directory(self, expected_revision, catalog):
        from .directory import validate_catalog
        integer(expected_revision, 0, 2**53 - 2)
        catalog = validate_catalog(catalog)
        now = datetime.now(timezone.utc).isoformat()
        with self.connect() as db:
            db.execute('BEGIN IMMEDIATE')
            revision, config = db.execute('SELECT revision,config FROM state WHERE id=1').fetchone()
            if revision != expected_revision:
                raise ConflictError('State changed during directory query')
            if not config or json.loads(config)['ad_domain'] != catalog['domain']:
                raise ValueError('Directory domain does not match config')
            db.execute('CREATE TABLE IF NOT EXISTS directory_catalog (id INTEGER PRIMARY KEY CHECK(id=1), domain TEXT NOT NULL, synced_at TEXT NOT NULL, payload TEXT NOT NULL)')
            db.execute('INSERT OR REPLACE INTO directory_catalog VALUES (1,?,?,?)',
                       (catalog['domain'], now, json.dumps(catalog, ensure_ascii=False, allow_nan=False)))
            db.execute('INSERT INTO audit(event,revision) VALUES (?,?)', ('directory_synced', revision))
        return self.directory_status()

    def directory_catalog(self):
        from .directory import validate_catalog
        with self.connect() as db:
            if not db.execute("SELECT 1 FROM sqlite_master WHERE type='table' AND name='directory_catalog'").fetchone():
                return None
            row = db.execute('SELECT domain,synced_at,payload FROM directory_catalog WHERE id=1').fetchone()
            config = db.execute('SELECT config FROM state WHERE id=1').fetchone()[0]
            if row is None or not config or row[0] != json.loads(config)['ad_domain']:
                return None
            catalog = validate_catalog(json.loads(row[2]), row[0])
        return {**catalog, 'synced_at': row[1]}

    def directory_status(self):
        catalog = self.directory_catalog()
        linux_reader = sys.platform == 'linux' and importlib.util.find_spec('ldap') is not None and shutil.which('kinit') is not None
        result = {'catalog_available': catalog is not None, 'windows_reader_available': os.name == 'nt',
                  'reader_available': os.name == 'nt' or linux_reader,
                  'runtime_auth_ready': False, 'automatic_sync_enabled': False,
                  'membership_available': catalog is not None and catalog.get('membership_schema') == 1}
        if catalog:
            result.update(domain=catalog['domain'], dc_fqdn=catalog['dc_fqdn'], synced_at=catalog['synced_at'],
                          transport=catalog['transport'], counts={k: len(catalog[k]) for k in ('users', 'groups', 'computers')})
        return result

    def directory_page(self, kind, offset=0, limit=100, query='', security_only=False):
        if kind not in {'users', 'groups', 'computers'}:
            raise ValueError('Invalid catalog kind')
        integer(offset, 0, 10000); integer(limit, 1, 200)
        if type(query) is not str or len(query) > 128 or any(ord(c) < 32 for c in query):
            raise ValueError('Invalid directory query')
        catalog = self.directory_catalog()
        if catalog is None:
            return {'items': [], 'total': 0, 'offset': offset, 'catalog_available': False}
        items = [x for x in catalog[kind] if (not security_only or x.get('security_enabled', True)) and (not query or any(query.casefold() in x[k].casefold() for k in ('name', 'sam', 'sid')))]
        visible = [_directory_display(x, kind) for x in items[offset:offset + limit]]
        return {'items': visible, 'total': len(items), 'offset': offset, 'catalog_available': True}

    def policy_labels(self):
        selected = {sid for p in self.snapshot()['policies'] for sid in p['conditions']['group_sids']}
        catalog = self.directory_catalog()
        items = []
        if catalog:
            for plural, kind in [('users', 'user'), ('computers', 'computer'), ('groups', 'group')]:
                for obj in catalog[plural]:
                    if obj['sid'] in selected:
                        items.append({**_directory_display(obj, plural), 'kind': kind})
        return {'items': items, 'catalog_available': catalog is not None}

    def directory_detail(self, kind, object_id, offset=0, query=''):
        import uuid
        from .membership import related
        if kind not in {'users', 'groups', 'computers'}: raise ValueError('Invalid detail kind')
        integer(offset, 0, 10000)
        if type(object_id) is not str or str(uuid.UUID(object_id)) != object_id: raise ValueError('Invalid object identity')
        if type(query) is not str or len(query) > 128 or any(ord(c) < 32 for c in query): raise ValueError('Invalid directory query')
        catalog = self.directory_catalog()
        target = next((x for x in catalog[kind] if x['guid'] == object_id), None) if catalog else None
        if target is None: raise LookupError('Catalog object not found')
        result = {'object': _directory_display(target, kind), 'kind': kind, 'offset': offset, 'synced_at': catalog['synced_at'],
                  'membership_available': catalog.get('membership_schema') == 1, 'scope': 'single-domain-snapshot'}
        if not result['membership_available']: return {**result, 'items': [], 'total': 0}
        items, coverage = related(catalog, kind, target)
        items = [x for x in items if not query or any(query.casefold() in x[k].casefold() for k in ('name', 'sam', 'sid'))]
        items.sort(key=lambda x: (x['name'].casefold(), x['sam'].casefold(), x['guid']))
        visible = [_directory_display(x) for x in items[offset:offset + 100]]
        return {**result, **coverage, 'items': visible, 'total': len(items)}
