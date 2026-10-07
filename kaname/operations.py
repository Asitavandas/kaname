"""Revision-controlled network inventory and saved read-only AD configuration."""
import json
import secrets

from .models import address, boolean, enum, integer, keys, text, ValidationError
from .directory import validate_connection, validate_search_scopes
from .store import ConflictError
from .vault import Vault


DIRECTORY_DEFAULTS = {'name': 'LDAP Server', 'dc_fqdn': '', 'username': '', 'search_base': '', 'sync_minutes': 15,
                      'check_minutes': 5, 'automatic_sync': False}


class Operations:
    def __init__(self, store):
        self.store = store
        self.vault = Vault(store.root)
        with store.connect() as db:
            db.executescript('''
            CREATE TABLE IF NOT EXISTS runtime_settings (name TEXT PRIMARY KEY, payload TEXT NOT NULL);
            CREATE TABLE IF NOT EXISTS protected_secrets (name TEXT PRIMARY KEY, ciphertext BLOB NOT NULL);
            ''')

    def _public(self, name, default):
        with self.store.connect() as db:
            row = db.execute('SELECT payload FROM runtime_settings WHERE name=?', (name,)).fetchone()
        return json.loads(row[0]) if row else default

    def _revision(self, db, expected):
        integer(expected, 0, 2**53 - 2)
        revision = db.execute('SELECT revision FROM state WHERE id=1').fetchone()[0]
        if revision != expected:
            raise ConflictError()
        return revision

    def _save(self, db, name, payload):
        db.execute('INSERT OR REPLACE INTO runtime_settings VALUES (?,?)', (name, json.dumps(payload, ensure_ascii=False)))

    def _audit(self, db, name, revision):
        db.execute('UPDATE state SET revision=? WHERE id=1', (revision + 1,))
        db.execute('INSERT INTO audit(event,revision) VALUES (?,?)', (name, revision + 1))

    def network(self):
        state = self.store.snapshot()
        default = {'vlans': [], 'radius_clients': (state['config'] or {}).get('radius_clients', []),
                   'authentication_port': 1812, 'accounting_port': 1813}
        result = self._public('network', default)
        result = {**result, 'vlans': list(result['vlans']), 'radius_clients': [dict(x) for x in result['radius_clients']]}
        for client in result['radius_clients']:
            client.setdefault('access_type', 'wired')
        # Preserve legacy VLAN assignments with an editable name; never erase policy data.
        for vlan in sorted({x['vlan'] for x in state['policies'] if x['vlan'] is not None}):
            if not any(x['id'] == vlan for x in result['vlans']):
                result['vlans'].append({'id': vlan, 'name': 'VLAN ' + str(vlan), 'description': ''})
        with self.store.connect() as db:
            saved = {x[0] for x in db.execute('SELECT name FROM protected_secrets')}
        for client in result['radius_clients']:
            client['secret_saved'] = 'radius:' + client['ip'] in saved
        return {'revision': state['revision'], **result, 'runtime_applied': False}

    def save_network(self, expected, value):
        fields = {'vlans', 'radius_clients', 'authentication_port', 'accounting_port'}
        keys(value, fields, fields)
        auth = integer(value['authentication_port'], 1, 65535)
        accounting = integer(value['accounting_port'], 1, 65535)
        if auth == accounting:
            raise ValidationError('RADIUS_PORT_CONFLICT')
        if type(value['vlans']) is not list or len(value['vlans']) > 4094:
            raise ValidationError('Invalid VLAN list')
        vlans = []
        for item in value['vlans']:
            keys(item, {'id', 'name', 'description'}, {'id', 'name', 'description'})
            description = item['description']
            if type(description) is not str or len(description) > 256 or any(ord(x) < 32 for x in description):
                raise ValidationError('Invalid description')
            vlans.append({'id': integer(item['id'], 1, 4094), 'name': text(item['name']), 'description': description})
        if len({x['id'] for x in vlans}) != len(vlans):
            raise ValidationError('Duplicate VLAN')
        clients, encrypted = [], {}
        if type(value['radius_clients']) is not list or len(value['radius_clients']) > 256:
            raise ValidationError('Invalid clients')
        for item in value['radius_clients']:
            keys(item, {'name', 'ip', 'secret', 'access_type'}, {'name', 'ip', 'secret', 'access_type'})
            client = {'name': text(item['name']), 'ip': address(item['ip']),
                      'access_type': enum(item['access_type'], {'wired', 'wireless'})}
            secret = item['secret']
            if type(secret) is not str or (secret and (not 16 <= len(secret) <= 128 or any(ord(c) < 33 or ord(c) > 126 for c in secret))):
                raise ValidationError('RADIUS_SECRET_INVALID')
            if secret:
                encrypted['radius:' + client['ip']] = self.vault.seal('radius:' + client['ip'], secret)
            clients.append(client)
        if len({x['ip'] for x in clients}) != len(clients):
            raise ValidationError('Duplicate source IP')
        with self.store.connect() as db:
            db.execute('BEGIN IMMEDIATE')
            revision = self._revision(db, expected)
            policies = json.loads(db.execute('SELECT policies FROM state WHERE id=1').fetchone()[0])
            if any(p['vlan'] is not None and p['vlan'] not in {x['id'] for x in vlans} for p in policies):
                raise ValidationError('VLAN_IN_USE')
            self._save(db, 'network', dict(vlans=vlans, radius_clients=clients, authentication_port=auth, accounting_port=accounting))
            for name, cipher in encrypted.items():
                db.execute('INSERT OR REPLACE INTO protected_secrets VALUES (?,?)', (name, cipher))
            for name, in db.execute("SELECT name FROM protected_secrets WHERE name LIKE 'radius:%'").fetchall():
                if name not in {'radius:' + x['ip'] for x in clients}:
                    db.execute('DELETE FROM protected_secrets WHERE name=?', (name,))
            raw = db.execute('SELECT config FROM state WHERE id=1').fetchone()[0]
            if raw:
                config = json.loads(raw); config['radius_clients'] = clients
                db.execute('UPDATE state SET config=? WHERE id=1', (json.dumps(config, ensure_ascii=False),))
            self._audit(db, 'network_saved', revision)
        return self.network()

    def radius_secret(self, ip, *, audit=True):
        name = 'radius:' + address(ip)
        with self.store.connect() as db:
            row = db.execute('SELECT ciphertext FROM protected_secrets WHERE name=?', (name,)).fetchone()
            if row is None:
                raise ValidationError('RADIUS_SECRET_MISSING')
            if audit:
                revision = db.execute('SELECT revision FROM state WHERE id=1').fetchone()[0]
                db.execute('INSERT INTO audit(event,revision) VALUES (?,?)', ('radius_secret_viewed', revision))
        return self.vault.open(name, row[0])

    def directory(self):
        result = self._public('directory', DIRECTORY_DEFAULTS.copy())
        config = self.store.snapshot()['config']
        if result.get('domain') != (config or {}).get('ad_domain'):
            return {**DIRECTORY_DEFAULTS, 'credentials_saved': False}
        with self.store.connect() as db:
            saved = db.execute("SELECT 1 FROM protected_secrets WHERE name='directory' ").fetchone() is not None
        return {**DIRECTORY_DEFAULTS, **result, 'credentials_saved': saved}

    def save_directory(self, expected, value):
        fields = set(DIRECTORY_DEFAULTS) | {'password'}
        keys(value, fields, fields - {'name'})
        config = self.store.snapshot()['config']
        if config is None:
            raise ValidationError('CONFIG_REQUIRED')
        password = value['password']
        previous = self.directory()
        if password == '' and (not previous['credentials_saved'] or any(previous[k] != value[k] for k in ('username', 'dc_fqdn'))):
            raise ValidationError('AD_PASSWORD_REQUIRED')
        connection = validate_connection({k: value[k] for k in ('dc_fqdn', 'username', 'password')} if password else
                                         {'dc_fqdn': value['dc_fqdn'], 'username': value['username'], 'password': 'unchanged'}, config)
        result = {k: connection[k] for k in ('dc_fqdn', 'username')}
        result.update(name=text(value.get('name', previous['name']), 128),
                      domain=config['ad_domain'], search_base=validate_search_scopes(value['search_base'], config['ad_domain']),
                      sync_minutes=integer(value['sync_minutes'], 1, 1440), check_minutes=integer(value['check_minutes'], 1, 1440),
                      automatic_sync=boolean(value['automatic_sync']))
        cipher = self.vault.seal('directory', password) if password else None
        with self.store.connect() as db:
            db.execute('BEGIN IMMEDIATE'); revision = self._revision(db, expected)
            self._save(db, 'directory', result)
            if cipher is not None:
                db.execute('INSERT OR REPLACE INTO protected_secrets VALUES (?,?)', ('directory', cipher))
            self._save(db, 'directory_health', {'state': 'pending', 'error': '', 'checked_at': '', 'last_success': ''})
            self._audit(db, 'directory_connection_saved', revision)
        return self.directory()

    def directory_connection(self):
        settings = self.directory()
        if not settings['credentials_saved']:
            raise ValidationError('AD_PASSWORD_REQUIRED')
        with self.store.connect() as db:
            cipher = db.execute("SELECT ciphertext FROM protected_secrets WHERE name='directory'").fetchone()[0]
        return {k: settings[k] for k in ('dc_fqdn', 'username', 'search_base')} | {'password': self.vault.open('directory', cipher)}

    def directory_probe_connection(self, value):
        keys(value, {'dc_fqdn', 'username', 'password', 'search_base'}, {'dc_fqdn', 'username', 'password', 'search_base'})
        result = dict(value)
        if result['password'] == '':
            saved = self.directory()
            if not saved['credentials_saved'] or any(result[k] != saved[k] for k in ('dc_fqdn', 'username')):
                raise ValidationError('AD_PASSWORD_REQUIRED')
            result['password'] = self.directory_connection()['password']
        return result

    def health(self):
        return self._public('directory_health', {'state': 'unconfigured', 'error': '', 'checked_at': '', 'last_success': ''})

    def record_health(self, code='', expected_revision=None):
        from datetime import datetime, timezone
        now = datetime.now(timezone.utc).isoformat()
        with self.store.connect() as db:
            db.execute('BEGIN IMMEDIATE')
            if expected_revision is not None:
                self._revision(db, expected_revision)
            old = db.execute("SELECT payload FROM runtime_settings WHERE name='directory_health'").fetchone()
            previous = json.loads(old[0]) if old else {}
            value = {'state': 'error' if code else 'connected', 'error': code, 'checked_at': now,
                     'last_success': previous.get('last_success', '') if code else now}
            self._save(db, 'directory_health', value)
            if previous.get('state') != value['state'] or previous.get('error') != code:
                revision = db.execute('SELECT revision FROM state WHERE id=1').fetchone()[0]
                db.execute('INSERT INTO audit(event,revision) VALUES (?,?)', ('directory_health_error' if code else 'directory_health_restored', revision))
        return value

    @staticmethod
    def generate_secret():
        return secrets.token_urlsafe(32)
