"""Local-only development panel. Not the production appliance HTTP stack."""
import hashlib
import hmac
import ipaddress
import json
import logging
import os
import secrets
import sqlite3
import ssl
import sys
import threading
import time
from dataclasses import asdict
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from http.cookies import SimpleCookie, CookieError
from pathlib import Path
from urllib.parse import parse_qs, urlsplit

from . import VERSION
from .models import (ValidationError, address, array, boolean, dns_name, enum, keys,
                     strict_json, text)
from .policy import VerifiedIdentity, evaluate, radius_vlan_attributes, policy_conflicts, PolicyConflictError
from .store import ConflictError, Store
from .directory import DirectoryError, read_windows_directory, check_windows_directory, validate_connection
from .operations import Operations
from .planning import Planning
from .deployment import Deployment, DeploymentError
from .services import Services, ServiceError, validate as validate_service_action
from .audit import history as audit_history, AuditQueryLimit
from .radius_events import history as access_history, EventStorageError
from .dashboard import summary as dashboard_summary
from .resources import snapshot as resource_snapshot
from .directory_sync import DirectorySync
from .vault import VaultError
from .admin import AdminStore, AdminError, COOKIE, TTL, RESOURCES, permits

STATIC = Path(__file__).parent / 'static'
ASSETS = {'/deployment.js': ('deployment.js','application/javascript'), '/user-enrollment.js': ('user-enrollment.js','application/javascript'), '/dashboard.js': ('dashboard.js','application/javascript'), '/device.js': ('device.js','application/javascript'), '/': ('index.html', 'text/html'), '/app.js': ('app.js', 'application/javascript'),
          '/audit.js': ('audit.js','application/javascript'),
          '/access-events.js': ('access-events.js','application/javascript'),
          '/services.js': ('services.js','application/javascript'),
          '/styles.css': ('styles.css', 'text/css'),
          '/planning.js': ('planning.js', 'application/javascript'),
          '/authwire-logo.png': ('authwire-logo.png', 'image/png')}


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

    def __init__(self, root, port=8765, token=None, *, listen='127.0.0.1', tls_cert=None, tls_key=None, public_name=None):
        endpoint = ipaddress.ip_address(listen)
        if endpoint.version != 4 or endpoint.is_unspecified or endpoint.is_multicast:
            raise ValueError('An explicit unicast IPv4 listen address is required')
        if bool(tls_cert) != bool(tls_key) or (not endpoint.is_loopback and not tls_cert):
            raise ValueError('TLS certificate and key are required for LAN access')
        if public_name:
            public_name = dns_name(public_name)
            if not tls_cert:
                raise ValueError('Public name requires TLS')
        self.tls = bool(tls_cert)
        context = None
        if self.tls:
            context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
            context.minimum_version = ssl.TLSVersion.TLSv1_2
            context.load_cert_chain(tls_cert, tls_key)
        self.store = Store(root)
        self.token = token or development_token(self.store.root)
        self.admin = AdminStore(self.store)
        self.directory_lock = threading.Lock()
        self.directory_next_attempt = 0.0
        if os.name == 'nt':
            self.directory_reader = read_windows_directory
            self.directory_health_reader = check_windows_directory
        else:
            from .directory_linux import read_linux_directory, check_linux_directory
            self.directory_reader = read_linux_directory
            self.directory_health_reader = check_linux_directory
        self.operations = Operations(self.store)
        self.planning = Planning(self.operations)
        self.deployment = Deployment(self.operations)
        self.services = Services()
        self.public_name = public_name
        self.web_certificate = Path(tls_cert).read_bytes() if tls_cert else b''
        self.connector_pairing = None
        self.connector_init_lock = threading.Lock()
        self.connector_peer_lock = threading.Lock()
        self.connector_peer_gate = threading.BoundedSemaphore(4)
        self.connector_peer_rates = {}
        self.users = None
        self.user_sessions = None
        self.user_init_lock = threading.Lock()
        self.devices = None
        self.device_sessions = None
        self.device_init_lock = threading.Lock()
        self.enrollment_lock = threading.Lock()
        super().__init__((str(endpoint), port), Handler)
        if context:
            self.socket = context.wrap_socket(self.socket, server_side=True, do_handshake_on_connect=False)
        scheme = 'https' if self.tls else 'http'
        self.hosts = {f'127.0.0.1:{self.server_port}', f'localhost:{self.server_port}'}
        self.hosts.add(f'{endpoint}:{self.server_port}')
        if public_name:
            self.hosts.add(f'{public_name}:{self.server_port}')
        self.origins = {scheme + '://' + host for host in self.hosts}
        self.directory_sync = DirectorySync(self)
        self.device_stop = threading.Event()
        self.device_worker = threading.Thread(target=self.device_maintenance,daemon=True)
        self.device_worker.start()

    def device_maintenance(self):
        while not self.device_stop.wait(30):
            if self.devices is not None:
                try:
                    self.devices.maintenance()
                except Exception:
                    # Registry retirement deadlines still fail closed when the
                    # signer is locked; never drop/update a failed CRL.
                    pass

    def server_close(self):
        self.device_stop.set()
        self.device_worker.join(timeout=4)
        self.directory_sync.close()
        super().server_close()


class Handler(BaseHTTPRequestHandler):
    server_version = 'AuthWire-dev'
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
            if not ipaddress.ip_address(self.client_address[0]).is_loopback:
                self.respond(403, {'error': 'MAINTENANCE_LOOPBACK_REQUIRED'})
                return False
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
            except sqlite3.Error as error:
                self.store_error(error); return False
            except (ValueError, TypeError, ValidationError):
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
        return f'{COOKIE}={value}; Path=/; HttpOnly; SameSite=Strict; Max-Age={0 if remove else TTL}' + ('; Secure' if self.server.tls else '')

    def read_body(self):
        if self.headers.get('Transfer-Encoding') or self.headers.get_content_type() != 'application/json':
            raise AdminError('JSON_REQUIRED')
        size = int(self.headers.get('Content-Length', '0'))
        if not 1 <= size <= 262144:
            raise AdminError('BODY_LIMIT')
        raw = self.rfile.read(size); self.body_read = True
        return strict_json(raw)

    def device_services(self):
        # Lazy PKI imports retain the stdlib-only configuration panel/install
        # behavior on systems where optional certificate dependencies are absent.
        with self.server.device_init_lock:
            if self.server.devices is None:
                from .device_enrollment import DeviceEnrollment
                from .device_auth import KerberosSessions
                self.server.devices = DeviceEnrollment(self.server.operations)
                config = self.server.store.snapshot()['config'] or {}
                self.server.device_sessions = KerberosSessions(self.server.store.root,
                    self.server.public_name, config.get('ad_domain'))
            else:
                config = self.server.store.snapshot()['config'] or {}
                if self.server.device_sessions.domain != config.get('ad_domain'):
                    from .device_auth import KerberosSessions
                    self.server.device_sessions = KerberosSessions(self.server.store.root,
                        self.server.public_name,config.get('ad_domain'))
        return self.server.devices, self.server.device_sessions

    def connector_services(self):
        # Keep the optional cryptography dependency lazy and do not create PKI,
        # pairing records, services or keys while reading the ordinary panel.
        with self.server.connector_init_lock:
            if self.server.connector_pairing is None:
                from .connector_registry import ConnectorRegistry
                self.server.connector_pairing = ConnectorRegistry(self.server.operations, self.server.web_certificate)
        return self.server.connector_pairing

    def connector_admin(self, *, write=False):
        if not self.guard(write=write, resource='system.connectors'):
            return
        if not self.server.tls:
            self.respond(403, {'error': 'CONNECTOR_HTTPS_REQUIRED'}); return
        if write and self.actor['maintenance']:
            self.respond(403, {'error': 'CONNECTOR_PANEL_SESSION_REQUIRED'}); return
        try:
            from .connector_registry import RegistryError
        except ImportError:
            self.respond(503, {'error': 'CONNECTOR_SERVICE_UNAVAILABLE'}); return
        try:
            registry = self.connector_services()
            if not write:
                if self.path != '/api/deployment/connector':
                    raise ValidationError('Unsupported query')
                result = registry.status()
            else:
                value = self.read_body()
                # Hold the administrator read transaction while committing the
                # main-store trust change. A stale/demoted/disabled principal
                # must not provision trust using a permissions snapshot.
                with self.server.admin.connect() as adb:
                    adb.execute('BEGIN')
                    actor = self.server.admin.current_actor(adb, self.actor, 'system.connectors')
                    if self.path.endswith('/preview'):
                        result = registry.preview(value)
                    else:
                        result = registry.apply(value, actor['id'])
            self.respond(200, result)
        except RegistryError as error:
            self.respond(503 if error.code == 'CONNECTOR_STORE_INVALID' else
                         409 if error.code == 'CONNECTOR_PREVIEW_STALE' else 400, {'error': error.code})
        except ConflictError:
            self.respond(409, {'error': 'REVISION_CONFLICT'})
        except AdminError as error:
            status = {'UNAUTHORIZED': 401, 'FORBIDDEN': 403, 'JSON_REQUIRED': 415, 'BODY_LIMIT': 413}.get(error.code, 400)
            self.respond(status, {'error': error.code})
        except (ValueError, TypeError, KeyError):
            self.respond(400, {'error': 'CONNECTOR_INPUT_INVALID'})
        except sqlite3.Error as error:
            self.store_error(error)
        except ImportError:
            self.respond(503, {'error': 'CONNECTOR_SERVICE_UNAVAILABLE'})

    def connector_peer(self):
        if (not self.server.tls or self.headers.get('Host') not in self.server.hosts or
            any(self.headers.get(h) is not None for h in ('Origin','Cookie','Authorization'))):
            self.respond(403, {'error':'CONNECTOR_REQUEST_REJECTED'}); return
        import time
        with self.server.connector_peer_lock:
            now = time.monotonic()
            rates = {k:v for k,v in self.server.connector_peer_rates.items() if now-v[0] < 60}
            source = self.client_address[0]
            busy = (source not in rates and len(rates) >= 64) or rates.get(source,(now,0))[1] >= 30
            if not busy:
                start, count = rates.get(source,(now,0)); rates[source]=(start,count+1)
            self.server.connector_peer_rates = rates
        if busy:
            self.respond(429, {'error':'CONNECTOR_BUSY'}); return
        if not self.server.connector_peer_gate.acquire(blocking=False):
            self.respond(429, {'error':'CONNECTOR_BUSY'}); return
        try:
            from .connector_channel import ChannelError
            from .connector_registry import RegistryError
            if self.headers.get('Transfer-Encoding') or self.headers.get_content_type() != 'application/json':
                raise ValueError()
            size = int(self.headers.get('Content-Length','0'))
            if not 1 <= size <= 4096: raise ValueError()
            raw = self.rfile.read(size); self.body_read = True
            if len(raw) != size: raise ValueError()
            registry = self.connector_services()
            result = registry.poll(raw) if self.path.endswith('/challenge') else registry.accept(raw)
            self.respond(200,result)
        except ImportError:
            self.respond(503, {'error':'CONNECTOR_SERVICE_UNAVAILABLE'})
        except (ValueError, TypeError, KeyError, OSError):
            # Never disclose configured identity, key, phase, or trust state to a peer.
            self.respond(403, {'error':'CONNECTOR_REQUEST_REJECTED'})
        except sqlite3.Error as error:
            self.store_error(error)
        finally:
            self.server.connector_peer_gate.release()

    def user_services(self):
        devices, _ = self.device_services()
        with self.server.user_init_lock:
            from .device_auth import UserKerberosSessions
            if self.server.users is None:
                from .user_enrollment import UserEnrollment
                self.server.users = UserEnrollment(devices)
            config = self.server.store.snapshot()['config'] or {}
            if self.server.user_sessions is None or self.server.user_sessions.domain != config.get('ad_domain'):
                self.server.user_sessions = UserKerberosSessions(self.server.store.root,
                    self.server.public_name, config.get('ad_domain'))
        return self.server.users, self.server.user_sessions

    def user_post(self):
        if not self.server.tls or self.headers.get('Host') not in self.server.hosts or self.headers.get('Origin'):
            self.respond(403, {'error': 'USER_HTTPS_REQUIRED'}); return
        try:
            from .enrollment import EnrollmentError
            users, sessions = self.user_services()
            value = self.read_body()
            if self.path == '/api/user/session':
                self.respond(200, sessions.start(value)); return
            principal, message, context = sessions.verify(self.path, value)
            result = {'/api/user/challenge': users.challenge,
                '/api/user/issue': users.issue, '/api/user/receipt': users.receipt}[self.path](principal, message)
            self.respond(200, sessions.response(self.path, context, result))
            if self.path == '/api/user/receipt':
                sessions.end(value['id'], context)
        except EnrollmentError as error:
            self.respond(429 if error.code in {'USER_BUSY', 'USER_RETRY_LATER', 'DEVICE_BUSY'} else
                503 if error.code in {'DEVICE_KERBEROS_NOT_READY', 'DEVICE_SIGNER_LOCKED', 'DEVICE_SIGNER_UNAVAILABLE', 'USER_DIRECTORY_UNAVAILABLE'} else 403,
                {'error': error.code})
        except (ValueError, TypeError, KeyError, UnicodeError):
            self.respond(400, {'error': 'USER_INPUT_INVALID'})
        except (ImportError, OSError, sqlite3.Error):
            self.respond(503, {'error': 'USER_SERVICE_UNAVAILABLE'})

    def user_admin_post(self, value):
        from .enrollment import EnrollmentError
        try:
            if not self.server.tls:
                raise EnrollmentError('PKI_HTTPS_REQUIRED')
            users, _ = self.user_services()
            if self.path == '/api/user-admin/profile':
                result = users.save_profile(value, self.actor['id'])
            else:
                keys(value, {'serial'}, {'serial'})
                result = users.request_renewal(value['serial'], self.actor['id'])
            self.respond(200, result)
        except EnrollmentError as error:
            self.respond(409 if error.code == 'REVISION_CONFLICT' else 400, {'error': error.code})

    def device_post(self):
        if not self.server.tls or self.headers.get('Host') not in self.server.hosts or self.headers.get('Origin'):
            self.respond(403, {'error': 'DEVICE_HTTPS_REQUIRED'}); return
        try:
            from .enrollment import EnrollmentError
            devices, sessions = self.device_services()
            value = self.read_body()
            if self.path == '/api/device/session':
                self.respond(200, sessions.start(value)); return
            principal, message, context = sessions.verify(self.path, value)
            result = {'/api/device/challenge': devices.challenge,
                '/api/device/issue': devices.issue, '/api/device/receipt': devices.receipt}[self.path](principal, message)
            self.respond(200, sessions.response(self.path, context, result))
            if self.path == '/api/device/receipt':
                sessions.end(value['id'],context)
        except EnrollmentError as error:
            self.respond(429 if error.code in {'DEVICE_BUSY','DEVICE_RETRY_LATER'} else
                503 if error.code in {'DEVICE_KERBEROS_NOT_READY','DEVICE_SIGNER_LOCKED','DEVICE_SIGNER_UNAVAILABLE','DEVICE_DIRECTORY_UNAVAILABLE'} else 403,
                {'error': error.code})
        except (ValueError, TypeError, KeyError, UnicodeError):
            self.respond(400, {'error': 'DEVICE_INPUT_INVALID'})
        except (ImportError, OSError, sqlite3.Error):
            self.respond(503, {'error': 'DEVICE_SERVICE_UNAVAILABLE'})

    def device_admin_post(self, value):
        from .enrollment import EnrollmentError
        from .pki import PKIError, password_bytes
        try:
            if not self.server.tls:
                raise EnrollmentError('PKI_HTTPS_REQUIRED')
            devices, _ = self.device_services()
            if self.path == '/api/device-admin/profile':
                result = devices.save_profile(value, self.actor['id'])
            elif self.path == '/api/device-admin/unlock':
                keys(value, {'ca_password'}, {'ca_password'})
                secret = password_bytes(text(value['ca_password'],128).encode('utf-8'))
                result = devices.unlock_signer(secret,self.actor['id'])
            elif self.path == '/api/device-admin/renew-now':
                keys(value, {'serial'}, {'serial'})
                result = devices.request_renewal(value['serial'], self.actor['id'])
            else:
                keys(value,set(),set())
                result = devices.lock_signer(self.actor['id'])
            self.respond(200, result)
        except EnrollmentError as error:
            self.respond(409 if error.code == 'REVISION_CONFLICT' else 400, {'error':error.code})
        except PKIError:
            self.respond(400, {'error':'PKI_OPERATION_FAILED'})
        finally:
            if type(value) is dict and 'ca_password' in value:
                value['ca_password'] = ''

    def pki_write(self, value):
        from .enrollment import EnrollmentError, EnrollmentService
        from .pki import PKIError, PKIService, password_bytes
        try:
            if not self.server.tls:
                raise EnrollmentError('PKI_HTTPS_REQUIRED')
            if sys.platform != 'linux':
                raise EnrollmentError('AD_PLATFORM_UNSUPPORTED')
            if type(value) is not dict:
                raise EnrollmentError('ENROLLMENT_INPUT_INVALID')
            if not self.server.enrollment_lock.acquire(blocking=False):
                raise EnrollmentError('ENROLLMENT_BUSY')
            try:
                pki = PKIService(self.server.store.root)
                if self.path == '/api/pki/archive':
                    keys(value, {'serial'}, {'serial'})
                    result = pki.archive_revoked(value['serial'], actor=self.actor['id'])
                else:
                    secret = password_bytes(text(value.get('ca_password'), 128).encode('utf-8'))
                    if self.path == '/api/pki/initialize':
                        keys(value, {'ca_password', 'confirm'}, {'ca_password', 'confirm'})
                        if not hmac.compare_digest(secret, text(value['confirm'], 128).encode('utf-8')):
                            raise PKIError('Confirmation mismatch')
                        result = pki.initialize(secret, actor=self.actor['id'])
                    elif self.path == '/api/pki/enroll-user':
                        fields = {'csr', 'username', 'password', 'ca_password', 'expected_revision', 'days'}
                        keys(value, fields, fields)
                        if type(value['csr']) is not str or not 1 <= len(value['csr']) <= 65536:
                            raise EnrollmentError('CSR_INVALID')
                        result = EnrollmentService(self.server.operations).issue_user(
                            value['csr'].encode('ascii'), value['username'], value['password'], secret,
                            expected_revision=value['expected_revision'], days=value['days'], actor=self.actor['id'])
                    elif self.path == '/api/pki/revoke':
                        keys(value, {'serial', 'reason', 'ca_password'}, {'serial', 'reason', 'ca_password'})
                        result = pki.revoke(value['serial'], secret, reason=value['reason'], actor=self.actor['id'])
                    else:
                        keys(value, {'ca_password'}, {'ca_password'})
                        pki.refresh_crl(secret, actor=self.actor['id'])
                        result = {'refreshed': True, 'radius_connected': False}
                self.respond(200, result)
            finally:
                self.server.enrollment_lock.release()
        except EnrollmentError as error:
            self.respond(429 if error.code in {'ENROLLMENT_BUSY', 'ENROLLMENT_RETRY_LATER'} else
                403 if error.code == 'PKI_HTTPS_REQUIRED' else 409 if error.code in {'CSR_ALREADY_USED', 'REVISION_CONFLICT'} else 400,
                {'error': error.code})
        except PKIError:
            self.respond(400, {'error': 'PKI_OPERATION_FAILED'})
        finally:
            if type(value) is dict:
                for name in ('ca_password', 'password', 'confirm'):
                    if name in value: value[name] = ''

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

    def store_error(self, error):
        # Fixed labels only: never SQL, parameters, URLs, exception text or secrets.
        code = getattr(error, 'sqlite_errorcode', None)
        base = (code & 255) if type(code) is int else None
        busy = base in (sqlite3.SQLITE_BUSY, sqlite3.SQLITE_LOCKED)
        path = urlsplit(self.path).path
        area = 'session' if path.startswith('/api/auth/') else 'certificates' if path.startswith(('/api/pki/', '/api/device-admin/', '/api/user-admin/')) else 'panel'
        logging.getLogger('authwire.panel').warning(json.dumps({
            'event': 'PANEL_DATABASE_ERROR', 'area': area,
            'method': 'GET' if self.command == 'GET' else 'POST',
            'sqlite_code': code if type(code) is int else None, 'transient': busy}))
        self.respond(503, {'error': 'STORE_BUSY' if busy else 'STORE_UNAVAILABLE'})

    def do_GET(self):
        try:
            self.get_response()
        except sqlite3.Error as error:
            self.store_error(error)

    def get_response(self):
        if self.headers.get('Host') not in self.server.hosts:
            self.respond(403, {'error': 'INVALID_HOST'})
            return
        if urlsplit(self.path).path == '/api/deployment/connector':
            self.connector_admin(); return
        if urlsplit(self.path).path == '/api/deployment/status':
            if not self.guard(resource='certificates.authority'):return
            try:
                query=parse_qs(urlsplit(self.path).query,keep_blank_values=True)
                if set(query)-{'q','offset'} or any(len(v)!=1 for v in query.values()):raise ValueError()
                self.respond(200,self.server.deployment.status(q=query.get('q',[''])[0],offset=int(query.get('offset',['0'])[0])))
            except (ValidationError,ValueError,TypeError):self.respond(400,{'error':'DEPLOYMENT_INPUT_INVALID'})
            except sqlite3.Error as error:self.store_error(error)
            return
        if urlsplit(self.path).path in {'/api/user-admin/status','/api/user-admin/package'}:
            if not self.guard(resource='certificates.authority'): return
            try:
                query = parse_qs(urlsplit(self.path).query, keep_blank_values=True)
                if len(self.path) > 256 or any(len(v) != 1 for v in query.values()): raise ValueError()
                users, sessions = self.user_services()
                if urlsplit(self.path).path.endswith('/package'):
                    if not permits(self.actor,'certificates.authority',True): self.respond(403,{'error':'FORBIDDEN'}); return
                    if not self.server.tls: raise ValueError()
                    keys(query,{'profile_id'},{'profile_id'})
                    self.respond(200,users.package(query['profile_id'][0],hostname=self.server.public_name,
                        port=self.server.server_port,tls_pem=self.server.web_certificate),'application/zip')
                    return
                if set(query)-{'offset'}: raise ValueError()
                result = users.status(offset=int(query.get('offset', ['0'])[0]))
                result.update(https_ready=self.server.tls, kerberos_ready=sessions.readiness(),
                    service_spn='HTTP/' + self.server.public_name if self.server.public_name else None)
                self.respond(200, result)
            except sqlite3.Error as error:
                self.store_error(error)
            except (ValueError, TypeError, KeyError, ImportError, OSError):
                self.respond(400, {'error': 'USER_SETUP_REQUIRED'})
            return
        if urlsplit(self.path).path in {'/api/device-admin/status','/api/device-admin/package'}:
            if not self.guard(resource='certificates.authority'): return
            try:
                devices,sessions = self.device_services()
                query = parse_qs(urlsplit(self.path).query,keep_blank_values=True)
                if len(self.path)>256 or any(len(v)!=1 for v in query.values()): raise ValueError()
                if urlsplit(self.path).path.endswith('/status'):
                    if set(query)-{'offset'}: raise ValueError()
                    result = devices.status(offset=int(query.get('offset',['0'])[0]))
                    result.update(https_ready=self.server.tls, dns_ready=bool(self.server.public_name),
                        kerberos_ready=sessions.readiness(), signing_required=True,
                        service_spn='HTTP/'+self.server.public_name if self.server.public_name else None)
                    self.respond(200,result)
                else:
                    if not permits(self.actor,'certificates.authority',True): self.respond(403,{'error':'FORBIDDEN'}); return
                    keys(query,{'profile_id'},{'profile_id'})
                    self.respond(200,devices.package(query['profile_id'][0],hostname=self.server.public_name,
                        port=self.server.server_port,tls_pem=self.server.web_certificate),'application/zip')
            except sqlite3.Error as error:
                self.store_error(error)
            except (ValueError,TypeError,KeyError,ImportError,OSError):
                self.respond(400,{'error':'DEVICE_SETUP_REQUIRED'})
            return
        if self.path in ASSETS:
            filename, mime = ASSETS[self.path]
            self.respond(200, (STATIC / filename).read_bytes(), mime)
        elif self.path == '/healthz':
            client = Path(__file__).parent / 'device_client' / 'AuthWire-Client.ps1'
            self.respond(200, {'product': 'AuthWire', 'version': VERSION, 'mode': 'development',
                'device_client_sha256': hashlib.sha256(client.read_bytes()).hexdigest()})
        elif self.path == '/readyz':
            self.respond(503, {'ready': False, 'reason': 'AD_PKI_RADIUS_NOT_CONNECTED'})
        elif self.path == '/api/auth/session' and self.guard():
            self.respond(200, {**self.server.admin.public_actor(self.actor), 'csrf': self.actor.get('csrf', '')})
        elif self.path == '/api/services' and self.guard(resource='system.services'):
            try:self.respond(200,self.server.services.status())
            except ServiceError as error:self.respond(503,{'error':error.code})
        elif self.path == '/api/system' and self.guard():
            if not (permits(self.actor, 'system.administrators') or permits(self.actor, 'system.profiles')):
                self.respond(403, {'error': 'FORBIDDEN'}); return
            self.respond(200, self.server.admin.snapshot(self.actor))
        elif self.path == '/api/state' and self.guard():
            value = self.server.store.snapshot()
            value['pki_public'] = self.server.store.public_pki_status()
            value['pki_public']['user_enrollment_available'] = self.server.tls and sys.platform == 'linux'
            value['pki_public']['machine_enrollment_enabled'] = bool(self.server.devices and self.server.device_sessions and self.server.device_sessions.readiness() and self.server.devices.status()['signer_ready'])
            value['directory_public'] = self.server.store.directory_status()
            value['directory_public']['automatic_sync_enabled'] = self.server.operations.directory()['automatic_sync']
            value['directory_health'] = self.server.operations.health()
            value['policy_conflicts'] = policy_conflicts(value['policies'], self.server.store.directory_catalog())
            value.update(product='AuthWire', version=VERSION, runtime_ready=False,
                         integrations={'ad': 'catalog-only' if value['directory_public']['catalog_available'] else 'pending', 'pki': 'pending', 'radius': 'pending', 'ovf': 'not-built'})
            self.respond(200, self.state_projection(value))
        elif urlsplit(self.path).path == '/api/system/resources' and self.guard(resource='system.services'):
            if urlsplit(self.path).query:
                self.respond(400, {'error':'INVALID_INPUT'}); return
            self.respond(200, resource_snapshot(self.server.store.root))
        elif urlsplit(self.path).path == '/api/dashboard' and self.guard():
            allowed = {r: permits(self.actor, r) for r in ('audit.events', 'certificates.authority', 'system.services')}
            if not any(allowed.values()):
                self.respond(403, {'error': 'FORBIDDEN'}); return
            try:
                query = parse_qs(urlsplit(self.path).query, keep_blank_values=True)
                if len(self.path) > 128 or set(query) - {'period'} or any(len(v) != 1 for v in query.values()): raise ValueError()
                network = self.server.operations.network() if allowed['audit.events'] and permits(self.actor, 'network.radius') else None
                self.respond(200, dashboard_summary(self.server.store.root, query.get('period', ['7d'])[0],
                    events=allowed['audit.events'], certificates=allowed['certificates.authority'], network=network))
            except (ValueError, TypeError): self.respond(400, {'error': 'INVALID_INPUT'})
        elif urlsplit(self.path).path == '/api/radius/events' and self.guard(resource='audit.events'):
            try:
                if len(self.path) > 2048: raise ValueError()
                query = parse_qs(urlsplit(self.path).query, keep_blank_values=True)
                self.respond(200, access_history(self.server.store.root, query))
            except (ValueError, TypeError, OverflowError): self.respond(400, {'error': 'INVALID_INPUT'})
            except AuditQueryLimit: self.respond(503, {'error': 'AUDIT_QUERY_LIMIT'})
            except (EventStorageError, OSError): self.respond(503, {'error': 'ACCESS_HISTORY_UNAVAILABLE'})
            except sqlite3.Error as error: self.store_error(error)
        elif urlsplit(self.path).path == '/api/audit/history' and self.guard(resource='audit.events'):
            try:
                if len(self.path) > 2048: raise ValueError()
                query = parse_qs(urlsplit(self.path).query, keep_blank_values=True)
                self.respond(200, audit_history(self.server.store, self.server.admin, query,
                    administrators=permits(self.actor, 'system.administrators')))
            except PermissionError: self.respond(403, {'error': 'FORBIDDEN'})
            except (ValueError, TypeError, OverflowError): self.respond(400, {'error': 'INVALID_INPUT'})
            except AuditQueryLimit: self.respond(503, {'error': 'AUDIT_QUERY_LIMIT'})
            except sqlite3.Error as error: self.store_error(error)
        elif self.path == '/api/audit' and self.guard(resource='audit.events'):
            self.respond(200, {'events': self.server.store.audit()})
        elif self.path == '/api/system/power' and self.guard(resource='system.power'):
            try:self.respond(200,self.server.services.power_status())
            except ServiceError as error:self.respond(503,{'error':error.code})
        elif self.path == '/api/network/devices' and self.guard(resource='network.devices'):
            self.respond(200, self.server.planning.devices())
        elif self.path == '/api/policies/labels' and self.guard(resource='policies.rules'):
            self.respond(200, self.server.store.policy_labels())
        elif self.path == '/api/policies/drafts' and self.guard(resource='policies.rules'):
            self.respond(200, self.server.planning.drafts())
        elif urlsplit(self.path).path == '/api/policies/targets' and self.guard(resource='policies.rules'):
            try:
                query = parse_qs(urlsplit(self.path).query, keep_blank_values=True)
                if len(self.path) > 1024 or set(query) - {'kind', 'offset', 'q'} or any(len(v) != 1 for v in query.values()):
                    raise ValueError()
                self.respond(200, self.server.planning.targets(query.get('kind', [''])[0], int(query.get('offset', ['0'])[0]), query.get('q', [''])[0]))
            except (ValueError, TypeError): self.respond(400, {'error': 'INVALID_INPUT'})
            except sqlite3.Error as error: self.store_error(error)
        elif self.path == '/api/network' and self.guard():
            if not any(permits(self.actor, r) for r in ('network.vlans', 'network.radius', 'policies.rules')):
                self.respond(403, {'error': 'FORBIDDEN'}); return
            result = self.server.operations.network()
            if not (permits(self.actor, 'network.vlans') or permits(self.actor, 'policies.rules')): result.pop('vlans')
            if not permits(self.actor, 'network.radius'):
                for field in ('radius_clients', 'authentication_port', 'accounting_port'): result.pop(field)
            self.respond(200, result)
        elif urlsplit(self.path).path == '/api/pki/certificates' and self.guard(resource='certificates.authority'):
            try:
                query = parse_qs(urlsplit(self.path).query, keep_blank_values=True)
                if len(self.path) > 256 or set(query) - {'offset'} or any(len(v) != 1 for v in query.values()): raise ValueError()
                from .enrollment import EnrollmentService
                self.respond(200, EnrollmentService.certificates(self.server.store, offset=int(query.get('offset', ['0'])[0])))
            except (ValueError, TypeError): self.respond(400, {'error': 'INVALID_INPUT'})
            except sqlite3.Error as error: self.store_error(error)
        elif urlsplit(self.path).path == '/api/pki/public' and self.guard(resource='certificates.authority'):
            try:
                query = parse_qs(urlsplit(self.path).query, keep_blank_values=True)
                if set(query) != {'name'} or len(query['name']) != 1 or query['name'][0] not in {'root-ca.pem', 'issuer-ca.pem', 'issuer-crl.pem'}: raise ValueError()
                name = query['name'][0]
                column = {'root-ca.pem':'root_cert', 'issuer-ca.pem':'issuer_cert', 'issuer-crl.pem':'crl'}[name]
                with self.server.store.connect() as db:
                    exists = db.execute("SELECT 1 FROM sqlite_master WHERE name='pki_authority' AND type='table'").fetchone()
                    row = db.execute('SELECT ' + column + ' FROM pki_authority WHERE id=1').fetchone() if exists else None
                if row is None: raise ValueError()
                self.respond(200, {'name': name, 'pem': row[0].decode('ascii')})
            except (ValueError, TypeError): self.respond(400, {'error': 'PKI_OPERATION_FAILED'})
            except sqlite3.Error as error: self.store_error(error)
        elif urlsplit(self.path).path == '/api/pki/certificate' and self.guard(resource='certificates.authority'):
            try:
                from .radius import serial_number
                query = parse_qs(urlsplit(self.path).query, keep_blank_values=True)
                if len(self.path) > 128 or set(query) != {'serial'} or len(query['serial']) != 1: raise ValueError()
                serial = serial_number(query['serial'][0])
                with self.server.store.connect() as db:
                    exists = db.execute("SELECT 1 FROM sqlite_master WHERE type='table' AND name='pki_certificates'").fetchone()
                    row = db.execute('SELECT certificate FROM pki_certificates WHERE serial=?', (serial,)).fetchone() if exists else None
                self.respond(200 if row else 404, {'serial': serial, 'pem': row[0].decode('ascii')} if row else {'error': 'CERTIFICATE_NOT_FOUND'})
            except (ValueError, TypeError): self.respond(400, {'error': 'INVALID_INPUT'})
            except sqlite3.Error as error: self.store_error(error)
        elif self.path == '/api/directory/settings' and self.guard(resource='directory.connection'):
            self.respond(200, self.server.operations.directory())
        elif urlsplit(self.path).path == '/api/policies/groups' and self.guard():
            if not any(permits(self.actor, r) for r in ('policies.rules', 'simulate.scenarios','certificates.authority')):
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
            except sqlite3.Error as error:
                self.store_error(error)
        elif urlsplit(self.path).path == '/api/directory/detail' and self.guard(resource='directory.catalog'):
            try:
                query = parse_qs(urlsplit(self.path).query, keep_blank_values=True)
                if len(self.path) > 1024 or set(query) - {'kind', 'id', 'offset', 'q'} or any(len(v) != 1 for v in query.values()): raise ValueError()
                self.respond(200, self.server.store.directory_detail(query.get('kind', [''])[0], query.get('id', [''])[0], int(query.get('offset', ['0'])[0]), query.get('q', [''])[0]))
            except LookupError: self.respond(404, {'error': 'CATALOG_OBJECT_NOT_FOUND'})
            except (ValueError, TypeError): self.respond(400, {'error': 'INVALID_INPUT'})
            except sqlite3.Error as error: self.store_error(error)
        elif urlsplit(self.path).path not in {'/api/system/resources', '/api/dashboard', '/api/radius/events', '/api/services', '/api/pki/certificate', '/api/pki/certificates', '/api/pki/public', '/api/state', '/api/audit', '/api/audit/history', '/api/auth/session', '/api/system', '/api/directory/catalog', '/api/directory/detail', '/api/policies/groups', '/api/network', '/api/network/devices', '/api/policies/drafts', '/api/policies/targets', '/api/policies/labels', '/api/system/power', '/api/directory/settings'}:
            self.respond(404, {'error': 'NOT_FOUND'})

    def do_POST(self):
        if self.path in {'/api/connector/v1/challenge','/api/connector/v1/health'}:
            self.connector_peer(); return
        if self.path in {'/api/deployment/connector/preview', '/api/deployment/connector/apply'}:
            self.connector_admin(write=True); return
        if self.path == '/api/system/power/action':
            if not self.guard(write=True,resource='system.power'):return
            if self.actor['maintenance']:
                self.respond(403,{'error':'SERVICES_SESSION_REQUIRED'});return
            try:
                from .services import validate_power
                value=self.read_body();validate_power(value)
                with self.server.store.connect() as db:
                    revision=db.execute('SELECT revision FROM state WHERE id=1').fetchone()[0]
                    event='system_power_requested:'+json.dumps({'request_id':value['request_id'],'action':value['action'],'actor':self.actor['username']},ensure_ascii=True,separators=(',',':'))
                    db.execute('INSERT INTO audit(event,revision) VALUES (?,?)',(event,revision))
                self.respond(202,self.server.services.power_action(value,self.actor))
            except ServiceError as error:
                status=409 if error.code in {'SERVICE_BUSY','REQUEST_ID_CONFLICT','MAINTENANCE_BUSY'} else 400 if error.code in {'INVALID_INPUT','CONFIRMATION_REQUIRED','ACTION_NOT_ALLOWED'} else 503
                self.respond(status,{'error':error.code})
            except (AdminError,ValidationError,ValueError,TypeError,KeyError):self.respond(400,{'error':'INVALID_INPUT'})
            except sqlite3.Error as error:self.store_error(error)
            return
        if self.path == '/api/services/action':
            if not self.guard(write=True,resource='system.services'):return
            if self.actor['maintenance']:
                self.respond(403,{'error':'SERVICES_SESSION_REQUIRED'});return
            try:
                value=self.read_body();validate_service_action(value)
                # Durable intent precedes the broker call; config revision is unchanged.
                with self.server.store.connect() as db:
                    revision=db.execute('SELECT revision FROM state WHERE id=1').fetchone()[0]
                    event='service_action_requested:'+json.dumps({**{k:value[k] for k in ('request_id','service','action')},'actor':self.actor['username']},ensure_ascii=True,separators=(',',':'))
                    db.execute('INSERT INTO audit(event,revision) VALUES (?,?)',(event,revision))
                self.respond(202,self.server.services.action(value,self.actor))
            except ServiceError as error:
                status=409 if error.code in {'SERVICE_BUSY','REQUEST_ID_CONFLICT','RADIUS_NOT_RUNNING'} else 400 if error.code in {'INVALID_INPUT','CONFIRMATION_REQUIRED','ACTION_NOT_ALLOWED'} else 503
                self.respond(status,{'error':error.code})
            except (AdminError,ValidationError,ValueError,TypeError,KeyError):self.respond(400,{'error':'INVALID_INPUT'})
            except sqlite3.Error as error:self.store_error(error)
            return
        if self.path in {'/api/user/session', '/api/user/challenge', '/api/user/issue', '/api/user/receipt'}:
            self.user_post(); return
        if self.path in {'/api/device/session','/api/device/challenge','/api/device/issue','/api/device/receipt'}:
            self.device_post(); return
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
            except sqlite3.Error as error: self.store_error(error)
            return
        resources = {'/api/config': None, '/api/policies': 'policies.rules', '/api/simulate': 'simulate.scenarios', '/api/directory/sync': 'directory.connection', '/api/directory/settings': 'directory.connection', '/api/directory/connectivity': 'directory.connection', '/api/directory/test-credentials': 'directory.connection', '/api/network/vlans': 'network.vlans', '/api/network/radius': 'network.radius', '/api/network/secret/generate': 'network.radius', '/api/network/secret/reveal': 'network.radius', '/api/system/users/save': 'system.administrators', '/api/system/users/delete': 'system.administrators', '/api/system/profiles/save': 'system.profiles', '/api/system/profiles/delete': 'system.profiles', '/api/auth/logout': None, '/api/auth/password': None}
        resources.update({'/api/network/devices/save': 'network.devices', '/api/network/devices/delete': 'network.devices',
                          '/api/policies/drafts/save': 'policies.rules', '/api/policies/drafts/delete': 'policies.rules'})
        resources.update({path: 'certificates.authority' for path in ('/api/pki/initialize', '/api/pki/enroll-user', '/api/pki/revoke', '/api/pki/refresh-crl', '/api/pki/archive')})
        resources.update({path:'certificates.authority' for path in
            ('/api/device-admin/profile','/api/device-admin/unlock','/api/device-admin/lock','/api/device-admin/renew-now')})
        resources.update({path: 'certificates.authority' for path in ('/api/user-admin/profile', '/api/user-admin/renew-now')})
        resources.update({path:'certificates.authority' for path in ('/api/deployment/save','/api/deployment/preview','/api/deployment/package')})
        if not self.guard(write=True, resource=resources.get(self.path), permission_write=self.path not in {'/api/simulate','/api/deployment/preview'}):
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
            if self.path.startswith('/api/deployment/'):
                if self.path.endswith('/save'):self.respond(200,self.server.deployment.save(value,self.actor['id']))
                elif self.path.endswith('/preview'):self.respond(200,self.server.deployment.preview(value))
                else:
                    if not self.server.tls:raise DeploymentError('DEPLOYMENT_HTTPS_REQUIRED')
                    import base64
                    self.respond(200,{'name':'AuthWire-Network-Profiles.zip','content_base64':base64.b64encode(self.server.deployment.package(value)).decode(),'gpo_changed':False,'runtime_applied':False})
            elif self.path.startswith('/api/user-admin/'):
                self.user_admin_post(value)
            elif self.path.startswith('/api/device-admin/'):
                self.device_admin_post(value)
            elif self.path.startswith('/api/pki/'):
                self.pki_write(value)
            elif self.path == '/api/auth/logout':
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
            elif self.path == '/api/directory/connectivity':
                keys(value, {'expected_revision', 'connection'}, {'expected_revision', 'connection'})
                result = self.server.directory_sync.connectivity(value['expected_revision'], value['connection'])
                self.respond(200, result)
            elif self.path == '/api/directory/test-credentials':
                keys(value, {'expected_revision', 'connection'}, {'expected_revision', 'connection'})
                connection = None
                try:
                    connection = self.server.operations.directory_probe_connection(value['connection'])
                    self.server.directory_sync.read(value['expected_revision'], connection, probe=True, update_health=False)
                    self.respond(200, {'authenticated': True, 'scope_verified': True, 'catalog_changed': False})
                finally:
                    if connection is not None: connection['password'] = ''
                    if type(value['connection']) is dict: value['connection']['password'] = ''
            elif self.path == '/api/directory/sync':
                keys(value, {'expected_revision', 'connection'}, {'expected_revision'})
                status = self.server.directory_sync.read(value['expected_revision'], value.get('connection'))
                self.respond(200, {'directory_public': status, 'network_enforced': False,
                                   'credentials_saved': self.server.operations.directory()['credentials_saved']})
            elif self.path in {'/api/network/devices/save', '/api/network/devices/delete', '/api/policies/drafts/save', '/api/policies/drafts/delete'}:
                deleting = self.path.endswith('/delete')
                field = 'id' if deleting else 'item'
                keys(value, {'expected_revision', field}, {'expected_revision', field})
                device = self.path.startswith('/api/network/')
                operation = (self.server.planning.delete_device if deleting else self.server.planning.save_device) if device else (self.server.planning.delete_draft if deleting else self.server.planning.save_draft)
                self.respond(200, operation(value['expected_revision'], value[field]))
            elif self.path in {'/api/network/vlans', '/api/network/radius'}:
                part = self.path.rsplit('/', 1)[1]
                fields = {'vlans'} if part == 'vlans' else {'radius_clients', 'authentication_port', 'accounting_port'}
                keys(value, fields | {'expected_revision'}, fields | {'expected_revision'})
                network = self.server.operations.network()
                data = {k: network[k] for k in ('vlans', 'radius_clients', 'authentication_port', 'accounting_port')}
                data['radius_clients'] = [{k: c[k] for k in ('name', 'ip', 'access_type')} | {'secret': ''} for c in data['radius_clients']]
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
                keys(value, required | {'account_kind'}, required)
                context = VerifiedIdentity(
                    boolean(value['authenticated']), boolean(value['directory_available']),
                    boolean(value['account_enabled']), boolean(value['domain_device']),
                    frozenset(array(value['group_sids'], lambda x: text(x, 184))),
                    enum(value['access_type'], {'wired', 'wireless'}), address(value['nas_ip']),
                    enum(value['eap_method'], {'EAP-TLS', 'PEAP-TLS', 'PEAP-MSCHAPV2'}),
                    account_kind=value.get('account_kind', ''))
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
        except DeploymentError as exc:
            self.respond(409 if exc.code=='DEPLOYMENT_PREVIEW_STALE' else 400,{'error':exc.code})
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
            allowed = {'POLICY_IDENTITY_SCOPE_MISMATCH', 'POLICY_IDENTITY_SCOPE_INVALID', 'DEVICE_IP_EXISTS', 'DEVICE_MODE_CONNECTION_INVALID', 'PLANNING_ITEM_NOT_FOUND', 'DRAFT_TARGET_REQUIRED', 'CATALOG_OBJECT_NOT_FOUND', 'AD_SCOPE_INVALID', 'AD_PASSWORD_REQUIRED', 'CONFIG_REQUIRED', 'VLAN_IN_USE', 'VLAN_NOT_DEFINED', 'RADIUS_CLIENTS_MANAGED', 'RADIUS_SECRET_INVALID', 'RADIUS_PORT_CONFLICT', 'RADIUS_SECRET_MISSING'}
            self.respond(400, {'error': str(exc) if str(exc) in allowed else 'INVALID_INPUT'})
        except (ValueError, TypeError, KeyError):
            self.respond(400, {'error': 'INVALID_INPUT'})
        except sqlite3.Error as error:
            self.store_error(error)
        except OSError:
            self.respond(503, {'error': 'STORE_UNAVAILABLE'})


