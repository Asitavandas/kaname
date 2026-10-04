"""Local-only development panel. Not the production appliance HTTP stack."""
import hmac
import json
import os
import secrets
import sqlite3
import threading
import time
from dataclasses import asdict
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from http.cookies import SimpleCookie, CookieError
from pathlib import Path
from urllib.parse import parse_qs, urlsplit

from . import VERSION
from .models import (ValidationError, address, array, boolean, enum, keys,
                     strict_json, text)
from .policy import VerifiedIdentity, evaluate, radius_vlan_attributes, policy_conflicts, PolicyConflictError
from .store import ConflictError, Store
from .directory import DirectoryError, read_windows_directory, check_windows_directory, validate_connection
from .operations import Operations
from .directory_sync import DirectorySync
from .vault import VaultError
from .admin import AdminStore, AdminError, COOKIE, TTL, RESOURCES, permits

STATIC = Path(__file__).parent / 'static'
ASSETS = {'/': ('index.html', 'text/html'), '/app.js': ('app.js', 'application/javascript'),
          '/styles.css': ('styles.css', 'text/css')}


def development_token(root):
    path = root / 'access-token'
    if path.is_symlink():
        raise ValueError('Token cannot be a symbolic link')
    if path.exists():
        if os.name == 'posix' and (path.stat().st_uid != os.getuid() or path.stat().st_mode & 0o077):
            raise ValueError('Token must be private and owned by the current user')
        token = path.read_text().strip()
        if len(token) != 64 or any(c not in '0123456789abcdef' for c in token):
            raise ValueError('Invalid development token file')
        return token
    token = secrets.token_hex(32)
    fd = os.open(path, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
    with os.fdopen(fd, 'w') as handle:
        handle.write(token + '\n')
    return token


class DevelopmentServer(ThreadingHTTPServer):
    daemon_threads = True

    def __init__(self, root, port=8765, token=None):
        self.store = Store(root)
        self.token = token or development_token(self.store.root)
        self.admin = AdminStore(self.store)
        self.directory_lock = threading.Lock()
        self.directory_next_attempt = 0.0
        self.directory_reader = read_windows_directory
        self.directory_health_reader = check_windows_directory
        self.operations = Operations(self.store)
        super().__init__(('127.0.0.1', port), Handler)
        self.origins = {f'http://127.0.0.1:{self.server_port}', f'http://localhost:{self.server_port}'}
        self.hosts = {f'127.0.0.1:{self.server_port}', f'localhost:{self.server_port}'}
        self.directory_sync = DirectorySync(self)

    def server_close(self):
        self.directory_sync.close()
        super().server_close()


class Handler(BaseHTTPRequestHandler):
    server_version = 'KANAME-dev'
    sys_version = ''

    def setup(self):
        super().setup()
        self.connection.settimeout(5)
        self.body_read = False

    def log_message(self, *_):
        # Never log URL, token, user fields or request bodies.
        pass

    def respond(self, code, value, content_type='application/json', cookie=None):
        # Consume only bounded, declared rejected POST data before closing this
        # HTTP/1.0 socket. An unread body can turn a 403 into a TCP reset on
        # Windows. This never parses or authorizes that rejected request.
        if code >= 400 and self.command == 'POST' and not self.body_read and not self.headers.get('Transfer-Encoding'):
            try:
                size = int(self.headers.get('Content-Length', '0'))
                if 0 < size <= 262144:
                    self.connection.settimeout(0.15)
                    self.rfile.read(size)
                    self.body_read = True
            except (OSError, ValueError):
                pass
            finally:
                self.connection.settimeout(5)
        body = value if isinstance(value, bytes) else json.dumps(value, ensure_ascii=False, allow_nan=False).encode()
        self.send_response(code)
        self.send_header('Content-Type', content_type + '; charset=utf-8')
        self.send_header('Content-Length', str(len(body)))
        self.send_header('Cache-Control', 'no-store')
        if cookie is not None:
            self.send_header('Set-Cookie', cookie)
        self.send_header('X-Content-Type-Options', 'nosniff')
        self.send_header('Referrer-Policy', 'no-referrer')
        self.send_header('Content-Security-Policy', "default-src 'self'; script-src 'self'; style-src 'self'; connect-src 'self'; frame-ancestors 'none'; base-uri 'none'; form-action 'none'")
        self.end_headers()
        self.wfile.write(body)

    def guard(self, write=False, resource=None, permission_write=None, public=False):
        if self.headers.get('Host') not in self.server.hosts:
            self.respond(403, {'error': 'INVALID_HOST'})
            return False
        origin = self.headers.get('Origin')
        if origin and origin not in self.server.origins:
            self.respond(403, {'error': 'INVALID_ORIGIN'})
            return False
        if write and origin not in self.server.origins:
            self.respond(403, {'error': 'ORIGIN_REQUIRED'})
            return False
        if public:
            return True
        authorization = self.headers.get('Authorization', '')
        token = authorization.removeprefix('Bearer ')
        if authorization.startswith('Bearer ') and hmac.compare_digest(token.encode('utf-8'), self.server.token.encode('ascii')):
            # Existing private loopback maintenance key remains usable by CLI
            # checks/updater; browser login never accepts or displays it.
            self.actor = {'id': 'maintenance', 'username': 'maintenance', 'profile_id': '', 'profile_name': 'Maintenance', 'permissions': {k: 'write' for k in RESOURCES}, 'maintenance': True}
        else:
            try:
                cookie = SimpleCookie(); cookie.load(self.headers.get('Cookie', ''))
                session = cookie[COOKIE].value if COOKIE in cookie else ''
            except CookieError:
                session = ''
            try:
                self.actor = self.server.admin.authenticate(session)
            except (sqlite3.Error, ValueError, TypeError, ValidationError):
                self.respond(503, {'error': 'STORE_UNAVAILABLE'}); return False
        if self.actor is None:
            self.respond(401, {'error': 'UNAUTHORIZED'})
            return False
        if write and not self.actor['maintenance'] and not hmac.compare_digest(self.headers.get('X-Kaname-CSRF', '').encode(), self.actor['csrf'].encode()):
            self.respond(403, {'error': 'CSRF_REQUIRED'})
            return False
        if resource and not permits(self.actor, resource, write if permission_write is None else permission_write):
            self.respond(403, {'error': 'FORBIDDEN'})
            return False
        return True

    def session_cookie(self, value='', remove=False):
        return f'{COOKIE}={value}; Path=/; HttpOnly; SameSite=Strict; Max-Age={0 if remove else TTL}'

    def read_body(self):
        if self.headers.get('Transfer-Encoding') or self.headers.get_content_type() != 'application/json':
            raise AdminError('JSON_REQUIRED')
        size = int(self.headers.get('Content-Length', '0'))
        if not 1 <= size <= 262144:
            raise AdminError('BODY_LIMIT')
        raw = self.rfile.read(size); self.body_read = True
        return strict_json(raw)

    def state_projection(self, value):
        if self.actor['maintenance']:
            return value
        result = {k: value[k] for k in ('revision', 'product', 'version', 'runtime_ready')}
        config = value['config'] or {}
        config_fields = {'setup.product': ['appliance_fqdn'], 'setup.directory': ['ad_domain', 'dc_ips'], 'setup.network': ['access_modes', 'radius_clients']}
        result['config'] = {k: config[k] for resource, fields in config_fields.items() if permits(self.actor, resource) for k in fields if k in config} or None
        if permits(self.actor, 'policies.rules'): result['policies'] = value['policies']
        if permits(self.actor, 'certificates.authority'): result['pki_public'] = value['pki_public']
        if permits(self.actor, 'directory.catalog') or permits(self.actor, 'directory.connection'):
            result['directory_public'] = value['directory_public']
            result['directory_context'] = {'configured': bool(config), 'domain': config.get('ad_domain', '')}
            result['directory_health'] = value['directory_health']
        if permits(self.actor, 'policies.rules'):
            result['policy_conflicts'] = value['policy_conflicts']
        return result

    def do_GET(self):
        if self.headers.get('Host') not in self.server.hosts:
            self.respond(403, {'error': 'INVALID_HOST'})
            return
        if self.path in ASSETS:
            filename, mime = ASSETS[self.path]
            self.respond(200, (STATIC / filename).read_bytes(), mime)
        elif self.path == '/healthz':
            self.respond(200, {'product': 'KANAME', 'version': VERSION, 'mode': 'development'})
        elif self.path == '/readyz':
            self.respond(503, {'ready': False, 'reason': 'AD_PKI_RADIUS_NOT_CONNECTED'})
        elif self.path == '/api/auth/session' and self.guard():
            self.respond(200, {**self.server.admin.public_actor(self.actor), 'csrf': self.actor.get('csrf', '')})
        elif self.path == '/api/system' and self.guard():
            if not (permits(self.actor, 'system.administrators') or permits(self.actor, 'system.profiles')):
                self.respond(403, {'error': 'FORBIDDEN'}); return
            self.respond(200, self.server.admin.snapshot(self.actor))
        elif self.path == '/api/state' and self.guard():
            value = self.server.store.snapshot()
            value['pki_public'] = self.server.store.public_pki_status()
            value['directory_public'] = self.server.store.directory_status()
            value['directory_public']['automatic_sync_enabled'] = self.server.operations.directory()['automatic_sync']
            value['directory_health'] = self.server.operations.health()
            value['policy_conflicts'] = policy_conflicts(value['policies'], self.server.store.directory_catalog())
            value.update(product='KANAME', version=VERSION, runtime_ready=False,
                         integrations={'ad': 'catalog-only' if value['directory_public']['catalog_available'] else 'pending', 'pki': 'pending', 'radius': 'pending', 'ovf': 'not-built'})
            self.respond(200, self.state_projection(value))
        elif self.path == '/api/audit' and self.guard(resource='audit.events'):
            self.respond(200, {'events': self.server.store.audit()})
        elif self.path == '/api/network' and self.guard():
            if not any(permits(self.actor, r) for r in ('network.vlans', 'network.radius', 'policies.rules')):
                self.respond(403, {'error': 'FORBIDDEN'}); return
            result = self.server.operations.network()
            if not (permits(self.actor, 'network.vlans') or permits(self.actor, 'policies.rules')): result.pop('vlans')
            if not permits(self.actor, 'network.radius'):
                for field in ('radius_clients', 'authentication_port', 'accounting_port'): result.pop(field)
            self.respond(200, result)
        elif self.path == '/api/directory/settings' and self.guard(resource='directory.connection'):
            self.respond(200, self.server.operations.directory())
        elif urlsplit(self.path).path == '/api/policies/groups' and self.guard():
            if not any(permits(self.actor, r) for r in ('policies.rules', 'simulate.scenarios')):
                self.respond(403, {'error': 'FORBIDDEN'}); return
            try:
                query = parse_qs(urlsplit(self.path).query, keep_blank_values=True)
                if len(self.path) > 1024 or set(query) - {'offset', 'q'} or any(len(v) != 1 for v in query.values()): raise ValueError()
                self.respond(200, self.server.store.directory_page('groups', int(query.get('offset', ['0'])[0]), query=query.get('q', [''])[0], security_only=True))
            except (ValueError, TypeError): self.respond(400, {'error': 'INVALID_INPUT'})
        elif urlsplit(self.path).path == '/api/directory/catalog' and self.guard(resource='directory.catalog'):
            try:
                if len(self.path) > 1024:
                    raise ValueError()
                query = parse_qs(urlsplit(self.path).query, keep_blank_values=True)
                if set(query) - {'kind', 'offset', 'q'} or any(len(v) != 1 for v in query.values()):
                    raise ValueError()
                value = self.server.store.directory_page(query.get('kind', ['groups'])[0],
                    int(query.get('offset', ['0'])[0]), query=query.get('q', [''])[0])
                self.respond(200, value)
            except (ValueError, TypeError):
                self.respond(400, {'error': 'INVALID_INPUT'})
            except sqlite3.Error:
                self.respond(503, {'error': 'STORE_UNAVAILABLE'})
        elif urlsplit(self.path).path == '/api/directory/detail' and self.guard(resource='directory.catalog'):
            try:
                query = parse_qs(urlsplit(self.path).query, keep_blank_values=True)
                if len(self.path) > 1024 or set(query) - {'kind', 'id', 'offset', 'q'} or any(len(v) != 1 for v in query.values()): raise ValueError()
                self.respond(200, self.server.store.directory_detail(query.get('kind', [''])[0], query.get('id', [''])[0], int(query.get('offset', ['0'])[0]), query.get('q', [''])[0]))
            except LookupError: self.respond(404, {'error': 'CATALOG_OBJECT_NOT_FOUND'})
            except (ValueError, TypeError): self.respond(400, {'error': 'INVALID_INPUT'})
            except sqlite3.Error: self.respond(503, {'error': 'STORE_UNAVAILABLE'})
        elif urlsplit(self.path).path not in {'/api/state', '/api/audit', '/api/auth/session', '/api/system', '/api/directory/catalog', '/api/directory/detail', '/api/policies/groups', '/api/network', '/api/directory/settings'}:
            self.respond(404, {'error': 'NOT_FOUND'})

    def do_POST(self):
        if self.path == '/api/auth/login':
            if not self.guard(write=True, public=True): return
            try:
                value = self.read_body(); keys(value, {'username', 'password'}, {'username', 'password'})
                session, actor = self.server.admin.login(value['username'], value['password'])
                value['password'] = ''
                self.respond(200, actor, cookie=self.session_cookie(session))
            except AdminError as exc:
                self.respond(429 if exc.code == 'LOGIN_RATE_LIMIT' else 401 if exc.code == 'LOGIN_FAILED' else 400, {'error': exc.code})
            except (ValidationError, ValueError, TypeError, KeyError): self.respond(400, {'error': 'INVALID_INPUT'})
            except sqlite3.Error: self.respond(503, {'error': 'STORE_UNAVAILABLE'})
            return
        resources = {'/api/config': None, '/api/policies': 'policies.rules', '/api/simulate': 'simulate.scenarios', '/api/directory/sync': 'directory.connection', '/api/directory/settings': 'directory.connection', '/api/network/vlans': 'network.vlans', '/api/network/radius': 'network.radius', '/api/network/secret/generate': 'network.radius', '/api/network/secret/reveal': 'network.radius', '/api/system/users/save': 'system.administrators', '/api/system/users/delete': 'system.administrators', '/api/system/profiles/save': 'system.profiles', '/api/system/profiles/delete': 'system.profiles', '/api/auth/logout': None, '/api/auth/password': None}
        if not self.guard(write=True, resource=resources.get(self.path), permission_write=self.path != '/api/simulate'):
            return
        if self.path not in resources:
            self.respond(404, {'error': 'NOT_FOUND'})
            return
        if self.headers.get('Transfer-Encoding') or self.headers.get_content_type() != 'application/json':
            self.respond(415, {'error': 'JSON_REQUIRED'})
            return
        try:
            size = int(self.headers.get('Content-Length', '0'))
            if not 1 <= size <= 262144:
                self.respond(413, {'error': 'BODY_LIMIT'})
                return
            raw = self.rfile.read(size); self.body_read = True
            value = strict_json(raw)
            if self.path == '/api/auth/logout':
                keys(value, set(), set()); self.server.admin.logout(self.actor)
                self.respond(200, {'logged_out': True}, cookie=self.session_cookie(remove=True))
            elif self.path == '/api/auth/password':
                if self.actor['maintenance']: raise AdminError('FORBIDDEN')
                keys(value, {'current', 'new'}, {'current', 'new'})
                self.server.admin.change_password(self.actor, value['current'], value['new'])
                value['current'] = value['new'] = ''
                self.respond(200, {'password_changed': True}, cookie=self.session_cookie(remove=True))
            elif self.path.startswith('/api/system/'):
                if self.path == '/api/system/users/save': self.server.admin.save_user(self.actor, value)
                elif self.path == '/api/system/profiles/save': self.server.admin.save_profile(self.actor, value)
                elif self.path == '/api/system/users/delete': self.server.admin.delete(self.actor, value, 'user')
                else: self.server.admin.delete(self.actor, value, 'profile')
                self.respond(200, {'saved': True})
            elif self.path == '/api/directory/settings':
                keys(value, {'expected_revision', 'settings'}, {'expected_revision', 'settings'})
                try: result = self.server.operations.save_directory(value['expected_revision'], value['settings'])
                finally: value['settings']['password'] = ''
                self.respond(200, result)
            elif self.path == '/api/directory/sync':
                keys(value, {'expected_revision', 'connection'}, {'expected_revision'})
                status = self.server.directory_sync.read(value['expected_revision'], value.get('connection'))
                self.respond(200, {'directory_public': status, 'network_enforced': False,
                                   'credentials_saved': self.server.operations.directory()['credentials_saved']})
            elif self.path in {'/api/network/vlans', '/api/network/radius'}:
                part = self.path.rsplit('/', 1)[1]
                fields = {'vlans'} if part == 'vlans' else {'radius_clients', 'authentication_port', 'accounting_port'}
                keys(value, fields | {'expected_revision'}, fields | {'expected_revision'})
                network = self.server.operations.network()
                data = {k: network[k] for k in ('vlans', 'radius_clients', 'authentication_port', 'accounting_port')}
                data['radius_clients'] = [{k: c[k] for k in ('name', 'ip')} | {'secret': ''} for c in data['radius_clients']]
                data.update({k: value[k] for k in fields})
                self.server.operations.save_network(value['expected_revision'], data)
                self.respond(200, {'saved': True, 'runtime_applied': False})
            elif self.path == '/api/network/secret/generate':
                keys(value, set(), set())
                self.respond(200, {'secret': self.server.operations.generate_secret()})
            elif self.path == '/api/network/secret/reveal':
                keys(value, {'ip'}, {'ip'})
                self.respond(200, {'secret': self.server.operations.radius_secret(value['ip'])})
            elif self.path == '/api/simulate':
                required = {'authenticated', 'directory_available', 'account_enabled', 'domain_device', 'group_sids', 'access_type', 'nas_ip', 'eap_method'}
                keys(value, required, required)
                context = VerifiedIdentity(
                    boolean(value['authenticated']), boolean(value['directory_available']),
                    boolean(value['account_enabled']), boolean(value['domain_device']),
                    frozenset(array(value['group_sids'], lambda x: text(x, 184))),
                    enum(value['access_type'], {'wired', 'wireless'}), address(value['nas_ip']),
                    enum(value['eap_method'], {'EAP-TLS', 'PEAP-TLS', 'PEAP-MSCHAPV2'}))
                decision = evaluate(self.server.store.snapshot()['policies'], context)
                self.respond(200, {'simulation_only': True, 'network_enforced': False,
                                   'decision': asdict(decision), 'radius_attributes': radius_vlan_attributes(decision)})
            else:
                section = self.path.split('/')[-1]
                if section == 'config' and not self.actor['maintenance']:
                    keys(value, {'expected_revision', 'patch'}, {'expected_revision', 'patch'})
                    patch = value['patch']
                    if type(patch) is not dict or not patch: raise ValidationError('Invalid patch')
                    fields = {'appliance_fqdn': 'setup.product', 'ad_domain': 'setup.directory', 'dc_ips': 'setup.directory', 'access_modes': 'setup.network', 'radius_clients': 'setup.network'}
                    if set(patch) - set(fields): raise ValidationError('Invalid config fields')
                    if any(not permits(self.actor, fields[k], True) for k in patch): raise AdminError('FORBIDDEN')
                    current = self.server.store.snapshot()
                    value = {'expected_revision': value['expected_revision'], 'config': {**(current['config'] or {}), **patch}}
                keys(value, {'expected_revision', section}, {'expected_revision', section})
                revision = self.server.store.save(value['expected_revision'], **{section: value[section]})
                self.respond(200, {'revision': revision, 'runtime_applied': False})
        except PolicyConflictError as exc:
            self.respond(409, {'error': 'POLICY_CONFLICT', 'conflicts': exc.conflicts})
        except ConflictError:
            self.respond(409, {'error': 'REVISION_CONFLICT'})
        except DirectoryError as exc:
            self.respond(429 if exc.code in {'AD_QUERY_BUSY', 'AD_RETRY_LATER'} else 503, {'error': exc.code, **({'diagnostic': exc.diagnostic} if exc.diagnostic else {})})
        except VaultError:
            self.respond(503, {'error': 'SECRET_STORE_UNAVAILABLE'})
        except AdminError as exc:
            self.respond(401 if exc.code == 'UNAUTHORIZED' else 403 if exc.code in {'FORBIDDEN', 'DELEGATION_DENIED'} else 409 if exc.code == 'PROFILE_IN_USE' else 400, {'error': exc.code})
        except sqlite3.IntegrityError:
            self.respond(409 if self.path.startswith('/api/system/') else 503, {'error': 'ADMIN_NAME_EXISTS' if self.path.startswith('/api/system/') else 'STORE_UNAVAILABLE'})
        except ValidationError as exc:
            allowed = {'AD_SCOPE_INVALID', 'AD_PASSWORD_REQUIRED', 'CONFIG_REQUIRED', 'VLAN_IN_USE', 'VLAN_NOT_DEFINED', 'RADIUS_CLIENTS_MANAGED', 'RADIUS_SECRET_INVALID', 'RADIUS_PORT_CONFLICT', 'RADIUS_SECRET_MISSING'}
            self.respond(400, {'error': str(exc) if str(exc) in allowed else 'INVALID_INPUT'})
        except (ValueError, TypeError, KeyError):
            self.respond(400, {'error': 'INVALID_INPUT'})
        except (sqlite3.Error, OSError):
            self.respond(503, {'error': 'STORE_UNAVAILABLE'})
