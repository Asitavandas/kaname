"""Local-only development panel. Not the production appliance HTTP stack."""
import hmac
import json
import os
import secrets
import sqlite3
from dataclasses import asdict
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

from . import VERSION
from .models import (ValidationError, address, array, boolean, enum, keys,
                     strict_json, text)
from .policy import VerifiedIdentity, evaluate, radius_vlan_attributes
from .store import ConflictError, Store

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
        super().__init__(('127.0.0.1', port), Handler)
        self.origins = {f'http://127.0.0.1:{self.server_port}', f'http://localhost:{self.server_port}'}
        self.hosts = {f'127.0.0.1:{self.server_port}', f'localhost:{self.server_port}'}


class Handler(BaseHTTPRequestHandler):
    server_version = 'KANAME-dev'
    sys_version = ''

    def setup(self):
        super().setup()
        self.connection.settimeout(5)

    def log_message(self, *_):
        # Never log URL, token, user fields or request bodies.
        pass

    def respond(self, code, value, content_type='application/json'):
        body = value if isinstance(value, bytes) else json.dumps(value, ensure_ascii=False, allow_nan=False).encode()
        self.send_response(code)
        self.send_header('Content-Type', content_type + '; charset=utf-8')
        self.send_header('Content-Length', str(len(body)))
        self.send_header('Cache-Control', 'no-store')
        self.send_header('X-Content-Type-Options', 'nosniff')
        self.send_header('Referrer-Policy', 'no-referrer')
        self.send_header('Content-Security-Policy', "default-src 'self'; script-src 'self'; style-src 'self'; connect-src 'self'; frame-ancestors 'none'; base-uri 'none'; form-action 'none'")
        self.end_headers()
        self.wfile.write(body)

    def guard(self, write=False):
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
        token = self.headers.get('Authorization', '').removeprefix('Bearer ')
        if not hmac.compare_digest(token.encode('utf-8'), self.server.token.encode('ascii')):
            self.respond(401, {'error': 'UNAUTHORIZED'})
            return False
        return True

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
        elif self.path == '/api/state' and self.guard():
            value = self.server.store.snapshot()
            value['pki_public'] = self.server.store.public_pki_status()
            value.update(product='KANAME', version=VERSION, runtime_ready=False,
                         integrations={'ad': 'pending', 'pki': 'pending', 'radius': 'pending', 'ovf': 'not-built'})
            self.respond(200, value)
        elif self.path == '/api/audit' and self.guard():
            self.respond(200, {'events': self.server.store.audit()})
        elif self.path not in {'/api/state', '/api/audit'}:
            self.respond(404, {'error': 'NOT_FOUND'})

    def do_POST(self):
        if not self.guard(write=True):
            return
        if self.path not in {'/api/config', '/api/policies', '/api/simulate'}:
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
            value = strict_json(self.rfile.read(size))
            if self.path == '/api/simulate':
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
                keys(value, {'expected_revision', section}, {'expected_revision', section})
                revision = self.server.store.save(value['expected_revision'], **{section: value[section]})
                self.respond(200, {'revision': revision, 'runtime_applied': False})
        except ConflictError:
            self.respond(409, {'error': 'REVISION_CONFLICT'})
        except (ValidationError, ValueError, TypeError, KeyError):
            self.respond(400, {'error': 'INVALID_INPUT'})
        except (sqlite3.Error, OSError):
            self.respond(503, {'error': 'STORE_UNAVAILABLE'})
