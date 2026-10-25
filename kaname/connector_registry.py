"""Revisioned, audited connector trust binding; no AD/GPO writer or transport.

The only durable data is one explicit public binding in runtime_settings. Health
nonces and last-seen state stay volatile. Every proof reloads trust under SQLite
so another registry/process cannot keep accepting a revoked or rotated key.
The HTTPS administrator API supplies the authorization boundary; this class is
an internal trusted service, not a peer self-registration interface.
"""
import dataclasses
import hashlib
import json
import secrets
import threading
from datetime import datetime, timezone

from cryptography import x509
from cryptography.exceptions import UnsupportedAlgorithm
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.x509.oid import ExtendedKeyUsageOID

from .connector_channel import Binding, ChannelError, ConnectorHealth, public_key_id
from .models import dns_name, keys, strict_json


SECTION = 'windows_connector_pairing'
FIELDS = {f.name for f in dataclasses.fields(Binding)}
CANDIDATE_FIELDS = FIELDS - {'generation'}
MAX_GENERATION = 2**31-1


class RegistryError(ValueError):
    def __init__(self, code):
        self.code = code
        super().__init__(code)


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, ensure_ascii=True,
        separators=(',', ':'), allow_nan=False).encode('ascii')).hexdigest()


def binding_dict(binding):
    value = dataclasses.asdict(binding)
    value['public_key_pem'] = binding.public_key_pem.decode('ascii')
    return value


def decode_binding(value):
    keys(value, FIELDS, FIELDS)
    value = dict(value)
    if type(value['public_key_pem']) is not str:
        raise RegistryError('CONNECTOR_BINDING_INVALID')
    try:
        value['public_key_pem'] = value['public_key_pem'].encode('ascii')
        return Binding(**value)
    except (ChannelError, UnicodeError, TypeError, UnsupportedAlgorithm):
        raise RegistryError('CONNECTOR_BINDING_INVALID') from None


class ConnectorRegistry:
    def __init__(self, operations, web_certificate, *, health_factory=ConnectorHealth):
        self.ops, self.store = operations, operations.store
        self.web_certificate = web_certificate
        self._factory = health_factory
        self._lock = threading.RLock()
        self._health, self._tag = None, None

    def _invalidate(self):
        if self._health is not None:
            self._health.revoke()
        self._health, self._tag = None, None

    def _read(self, db):
        row = db.execute('SELECT payload FROM runtime_settings WHERE name=?', (SECTION,)).fetchone()
        if row is None:
            return None
        try:
            record = strict_json(row[0])
            keys(record, {'format', 'state', 'domain', 'binding'}, {'format', 'state', 'domain', 'binding'})
            if type(record['format']) is not int or record['format'] != 1 or record['state'] not in ('paired', 'revoked'):
                raise ValueError()
            if dns_name(record['domain']) != record['domain']:
                raise ValueError()
            decode_binding(record['binding'])
            return record
        except (ValueError, TypeError, KeyError, AttributeError):
            raise RegistryError('CONNECTOR_STORE_INVALID') from None

    def _context(self, db):
        try:
            config = strict_json(db.execute('SELECT config FROM state WHERE id=1').fetchone()[0])
            domain, fqdn = dns_name(config['ad_domain']), dns_name(config['appliance_fqdn'])
            if not db.execute("SELECT 1 FROM sqlite_master WHERE type='table' AND name='pki_authority'").fetchone():
                raise ValueError()
            row = db.execute('SELECT instance_id,public_data FROM pki_authority WHERE id=1').fetchone()
            if not row or strict_json(row[1])['instance_id'] != row[0]:
                raise ValueError()
            cert = x509.load_pem_x509_certificate(self.web_certificate)
            now = datetime.now(timezone.utc)
            if not cert.not_valid_before_utc <= now < cert.not_valid_after_utc:
                raise ValueError()
            if fqdn not in cert.extensions.get_extension_for_class(x509.SubjectAlternativeName).value.get_values_for_type(x509.DNSName):
                raise ValueError()
            if ExtendedKeyUsageOID.SERVER_AUTH not in cert.extensions.get_extension_for_class(x509.ExtendedKeyUsage).value:
                raise ValueError()
            return {'instance_id': row[0], 'domain': domain, 'appliance_fqdn': fqdn,
                    'appliance_tls_sha256': cert.fingerprint(hashes.SHA256()).hex()}
        except (ValueError, TypeError, KeyError, IndexError, x509.ExtensionNotFound):
            raise RegistryError('CONNECTOR_CONTEXT_NOT_READY') from None

    def _scope_matches(self, record, context):
        b = record['binding']
        return (record['domain'] == context['domain'] and
            all(b[k] == context[k] for k in ('instance_id', 'appliance_fqdn', 'appliance_tls_sha256')) and
            b['host_fqdn'].endswith('.' + context['domain']))

    def _projection(self, record):
        if record is None:
            return None
        b = decode_binding(record['binding'])
        public = serialization.load_pem_public_key(b.public_key_pem)
        return {**{k: v for k, v in record['binding'].items() if k != 'public_key_pem'},
                'channel_key_sha256': public_key_id(public), 'domain': record['domain'], 'state': record['state']}

    def status(self):
        with self._lock, self.store.connect() as db:
            db.execute('BEGIN')
            revision = db.execute('SELECT revision FROM state WHERE id=1').fetchone()[0]
            record = self._read(db)
            valid, blocker = False, None
            if record and record['state'] == 'paired':
                try:
                    valid = self._scope_matches(record, self._context(db))
                    if not valid:
                        blocker = 'CONNECTOR_CONTEXT_CHANGED'
                except RegistryError as exc:
                    blocker = exc.code
            if not valid:
                self._invalidate()
            # A cache from a different binding must not remain online after a peer rotation.
            if self._tag is not None and self._tag != digest(record):
                self._invalidate()
            health = self._health.status() if valid and self._health is not None else {'online': False}
            return {'revision': revision, 'paired': bool(record and record['state'] == 'paired'),
                    'generation': record['binding']['generation'] if record else 0,
                    'binding': self._projection(record), 'scope_matches': valid,
                    'blocker': blocker, 'online': health['online'], 'transport_active': False,
                    'can_apply': False, 'directory_sync_ready': False, 'kerberos_ready': False}

    def _preview(self, db, value):
        keys(value, {'expected_revision', 'operation', 'candidate'}, {'expected_revision', 'operation', 'candidate'})
        revision = self.ops._revision(db, value['expected_revision'])
        operation = value['operation']
        if type(operation) is not str or operation not in ('pair', 'rotate', 'revoke'):
            raise RegistryError('CONNECTOR_OPERATION_INVALID')
        before = self._read(db)
        if operation == 'pair' and before and before['state'] == 'paired':
            raise RegistryError('CONNECTOR_ALREADY_PAIRED')
        if operation != 'pair' and (before is None or before['state'] != 'paired'):
            raise RegistryError('CONNECTOR_NOT_PAIRED')
        generation = before['binding']['generation'] if before else 0
        context = None
        if operation == 'revoke':
            keys(value['candidate'], set(), set())
            after = {**before, 'state': 'revoked', 'binding': {
                **before['binding'], 'generation': min(generation + 1, MAX_GENERATION)}}
        else:
            if generation >= MAX_GENERATION:
                raise RegistryError('CONNECTOR_GENERATION_EXHAUSTED')
            context = self._context(db)
            keys(value['candidate'], CANDIDATE_FIELDS, CANDIDATE_FIELDS)
            b = decode_binding({**value['candidate'], 'generation': generation + 1})
            after = {'format': 1, 'state': 'paired', 'domain': context['domain'], 'binding': binding_dict(b)}
            if not self._scope_matches(after, context):
                raise RegistryError('CONNECTOR_SCOPE_MISMATCH')
            if operation == 'rotate':
                immutable = FIELDS - {'generation', 'public_key_pem', 'appliance_tls_sha256'}
                if before['domain'] != after['domain'] or any(before['binding'][k] != after['binding'][k] for k in immutable):
                    raise RegistryError('CONNECTOR_IDENTITY_CHANGE_REQUIRES_REVOKE')
                if all(before['binding'][k] == after['binding'][k] for k in ('public_key_pem', 'appliance_tls_sha256')):
                    raise RegistryError('CONNECTOR_ROTATION_UNCHANGED')
        preview_hash = digest({'revision': revision, 'operation': operation,
            'before': before, 'after': after, 'context': context})
        return {'revision': revision, 'operation': operation, 'before': self._projection(before),
                'after': self._projection(after), 'preview_hash': preview_hash,
                'can_apply_gpo': False, 'ad_changed': False, 'gpo_changed': False}, after

    def preview(self, value):
        with self.store.connect() as db:
            db.execute('BEGIN')
            return self._preview(db, value)[0]

    def apply(self, value, actor):
        required = {'expected_revision', 'operation', 'candidate', 'preview_hash', 'confirmed_key_sha256'}
        keys(value, required, required)
        # The API passes the authenticated panel principal, never a peer assertion.
        import uuid
        if type(actor) is not str or str(uuid.UUID(actor)) != actor or uuid.UUID(actor).int == 0:
            raise RegistryError('CONNECTOR_ACTOR_INVALID')
        with self._lock:
            with self.store.connect() as db:
                db.execute('BEGIN IMMEDIATE')
                preview, after = self._preview(db, {k: value[k] for k in ('expected_revision', 'operation', 'candidate')})
                supplied = value['preview_hash']
                if type(supplied) is not str or not secrets.compare_digest(supplied, preview['preview_hash']):
                    raise RegistryError('CONNECTOR_PREVIEW_STALE')
                expected = preview['after']['channel_key_sha256'] if value['operation'] != 'revoke' else ''
                confirmed = value['confirmed_key_sha256']
                if type(confirmed) is not str or not secrets.compare_digest(confirmed, expected):
                    raise RegistryError('CONNECTOR_KEY_CONFIRMATION_REQUIRED')
                self.ops._save(db, SECTION, after)
                event = 'windows_connector_' + value['operation'] + ':' + json.dumps({
                    'actor': actor, 'connector_id': after['binding']['connector_id'],
                    'generation': after['binding']['generation'],
                    'key_sha256': preview['after']['channel_key_sha256'],
                    'before_sha256': digest(preview['before']), 'after_sha256': digest(preview['after'])},
                    sort_keys=True, separators=(',', ':'))
                self.ops._audit(db, event, preview['revision'])
            # Invalidate volatile evidence only after a successful durable commit.
            self._invalidate()
            return {'revision': preview['revision'] + 1, 'binding': preview['after'],
                    'runtime_applied': False, 'ad_changed': False, 'gpo_changed': False}

    def _active(self, db):
        try:
            record = self._read(db)
            if not record or record['state'] != 'paired':
                raise RegistryError('CONNECTOR_NOT_PAIRED')
            if not self._scope_matches(record, self._context(db)):
                raise RegistryError('CONNECTOR_CONTEXT_CHANGED')
            tag = digest(record)
            if tag != self._tag:
                self._invalidate()
                self._health = self._factory(decode_binding(record['binding']))
                self._tag = tag
            return self._health
        except RegistryError:
            self._invalidate()
            raise

    def challenge(self):
        """Internal future transport hook; no public connector route is registered."""
        with self._lock, self.store.connect() as db:
            db.execute('BEGIN')
            return self._active(db).challenge()

    def accept(self, raw):
        """Serialize proof acceptance with durable rotation/revocation in other processes."""
        with self._lock, self.store.connect() as db:
            db.execute('BEGIN IMMEDIATE')
            return self._active(db).accept(raw)
