"""Bounded connector health proof, version 1. Not an HTTP route or job executor.

An administrator-provisioned public key and identity are the trust anchor.
An unpaired peer cannot supply its own key. HTTPS with normal chain/name checks
and the configured appliance leaf pin is a separate mandatory transport gate.
Only a health challenge may be signed here; no AD/user assertion or arbitrary
command is authorized. Challenges/last-seen state deliberately die at restart.
"""
import base64
import hashlib
import json
import re
import secrets
import threading
import time
import uuid
from dataclasses import dataclass

from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding, rsa


TAG = 'AUTHWIRE-CONNECTOR-HEALTH-V1'
PATH = '/api/connector/v1/health'
LIFETIME = 60
MAX_PENDING = 4


class ChannelError(ValueError):
    """Stable non-secret boundary error; never include incoming proof contents."""


def _require(ok, code='CONNECTOR_PROOF_REJECTED'):
    if not ok:
        raise ChannelError(code)


def _guid(value):
    try:
        _require(type(value) is str and str(uuid.UUID(value)) == value and
                 uuid.UUID(value).int != 0, 'CONNECTOR_BINDING_INVALID')
    except (ValueError, AttributeError):
        raise ChannelError('CONNECTOR_BINDING_INVALID') from None
    return value


def _dns(value):
    _require(type(value) is str and 3 <= len(value) <= 253 and
             value == value.lower() and len(value.split('.')) >= 2 and
             all(re.fullmatch(r'[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?', s)
                 for s in value.split('.')), 'CONNECTOR_BINDING_INVALID')
    return value


def public_key_id(public_key):
    """Cross-platform public-only fingerprint; Windows 5.1 needs no SPKI API."""
    _require(isinstance(public_key, rsa.RSAPublicKey) and
             public_key.key_size in (3072, 4096) and
             public_key.public_numbers().e == 65537, 'CONNECTOR_KEY_INVALID')
    n = public_key.public_numbers().n.to_bytes(public_key.key_size // 8, 'big')
    data = (b'AuthWireConnectorKeyV1\n' + base64.b64encode(n) + b'\nAQAB\n')
    return hashlib.sha256(data).hexdigest()


@dataclass(frozen=True)
class Binding:
    """Local trusted configuration, never populated from an unauthenticated peer."""
    instance_id: str
    connector_id: str
    generation: int
    host_guid: str
    host_fqdn: str
    service_sid: str
    appliance_fqdn: str
    appliance_tls_sha256: str
    public_key_pem: bytes

    def __post_init__(self):
        for x in (self.instance_id, self.connector_id, self.host_guid):
            _guid(x)
        for x in (self.host_fqdn, self.appliance_fqdn):
            _dns(x)
        _require(type(self.generation) is int and 1 <= self.generation <= 2**31-1,
                 'CONNECTOR_BINDING_INVALID')
        _require(type(self.service_sid) is str and re.fullmatch(
            r'S-1-5-21-(?:[1-9][0-9]{0,9}-){3}[1-9][0-9]{0,9}', self.service_sid)
            and all(int(x) <= 2**32-1 for x in self.service_sid.split('-')[4:]),
            'CONNECTOR_BINDING_INVALID')
        _require(type(self.appliance_tls_sha256) is str and re.fullmatch(
            '[0-9a-f]{64}', self.appliance_tls_sha256), 'CONNECTOR_BINDING_INVALID')
        _require(type(self.public_key_pem) is bytes and
                 len(self.public_key_pem) <= 2048, 'CONNECTOR_KEY_INVALID')
        try:
            public = serialization.load_pem_public_key(self.public_key_pem)
            public_key_id(public)
            canonical = public.public_bytes(serialization.Encoding.PEM,
                serialization.PublicFormat.SubjectPublicKeyInfo)
            _require(self.public_key_pem == canonical, 'CONNECTOR_KEY_INVALID')
        except (ValueError, TypeError):
            raise ChannelError('CONNECTOR_KEY_INVALID') from None

    def fields(self):
        key = serialization.load_pem_public_key(self.public_key_pem)
        return [self.instance_id, self.connector_id, str(self.generation),
                self.host_guid, self.host_fqdn, self.service_sid,
                self.appliance_fqdn, self.appliance_tls_sha256, public_key_id(key)]


class ConnectorHealth:
    """Explicitly constructed health verifier; not registered by the live app.

    The caller must authorize provisioning/revocation and validate HTTPS before
    sending or accepting frames. A valid result is connector-key possession,
    never permission to issue certificates, update a directory, or apply a GPO.
    """
    def __init__(self, binding, *, monotonic=time.monotonic, wall_clock=time.time):
        _require(type(binding) is Binding, 'CONNECTOR_BINDING_INVALID')
        self.binding = binding
        self._public = serialization.load_pem_public_key(binding.public_key_pem)
        self._monotonic, self._wall = monotonic, wall_clock
        self._pending, self._last_seen = {}, None
        self._revoked = False
        self._lock = threading.Lock()

    def _prune(self, now):
        self._pending = {k: v for k, v in self._pending.items() if now < v[1]}

    def challenge(self):
        with self._lock:
            _require(not self._revoked, 'CONNECTOR_REVOKED')
            now = self._monotonic()
            self._prune(now)
            _require(len(self._pending) < MAX_PENDING, 'CONNECTOR_BUSY')
            issued = int(self._wall())
            request_id, nonce = secrets.token_hex(32), secrets.token_hex(32)
            fields = [TAG] + self.binding.fields() + [request_id, nonce,
                str(issued), str(issued + LIFETIME), 'POST', PATH]
            frame = ('\n'.join(fields) + '\n').encode('ascii')
            self._pending[request_id] = [frame, now + LIFETIME, 0]
            return {'frame': base64.b64encode(frame).decode('ascii')}

    def accept(self, raw):
        _require(type(raw) is bytes and 1 <= len(raw) <= 2048)
        def pairs(items):
            result = {}
            for k, v in items:
                _require(k not in result)
                result[k] = v
            return result
        try:
            value = json.loads(raw, object_pairs_hook=pairs,
                parse_constant=lambda _: (_ for _ in ()).throw(ChannelError('CONNECTOR_PROOF_REJECTED')))
            _require(type(value) is dict and set(value) == {'challenge_id', 'signature'})
            identity, encoded = value['challenge_id'], value['signature']
            _require(type(identity) is str and re.fullmatch('[0-9a-f]{64}', identity))
            _require(type(encoded) is str and 1 <= len(encoded) <= 684)
            signature = base64.b64decode(encoded, validate=True)
            _require(base64.b64encode(signature).decode('ascii') == encoded and
                     len(signature) == self._public.key_size // 8)
        except (ValueError, TypeError, UnicodeError, RecursionError):
            raise ChannelError('CONNECTOR_PROOF_REJECTED') from None
        with self._lock:
            _require(not self._revoked, 'CONNECTOR_REVOKED')
            now = self._monotonic()
            self._prune(now)
            item = self._pending.get(identity)
            _require(item is not None)
            try:
                self._public.verify(signature, item[0], padding.PKCS1v15(), hashes.SHA256())
            except InvalidSignature:
                item[2] += 1
                if item[2] >= 3:
                    del self._pending[identity]
                raise ChannelError('CONNECTOR_PROOF_REJECTED') from None
            # Consume and update last seen atomically: concurrent/replayed replies fail.
            del self._pending[identity]
            self._last_seen = now
            return {'channel_proof_verified': True, 'can_apply': False,
                    'directory_sync_ready': False, 'kerberos_ready': False}

    def revoke(self):
        with self._lock:
            self._revoked = True
            self._pending.clear()
            self._last_seen = None

    def status(self):
        with self._lock:
            age = None if self._last_seen is None else self._monotonic() - self._last_seen
            return {'configured': not self._revoked,
                    'online': not self._revoked and age is not None and 0 <= age < 90,
                    'channel_proof_verified': not self._revoked and age is not None and 0 <= age < 90,
                    'can_apply': False, 'directory_sync_ready': False, 'kerberos_ready': False}
