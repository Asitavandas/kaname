"""Opt-in native observer. Observation never returns reply/Auth-Type changes."""
import base64
from contextlib import closing, contextmanager
import hashlib
import json
import os
from pathlib import Path
import re
import sqlite3
import tempfile
import threading
import time
import uuid

from . import radius_adapter
from .policy import Decision
from .radius import CertificateReference, freeradius_result, serial_number
from .radius_registry import CertificateRegistry
from .radius_events import append, packet_key, utc, REASONS, EventStorageError, _private, BUSY_SECONDS

CONTEXT = 'AuthWire-Event-Context'
REQUEST_KEY = 'AuthWire-Request-Key'
FINAL_CODE = 'AuthWire-Final-Code'
CAPTURE_RUN = uuid.uuid4().hex
_lock = threading.Lock()
_failed = 0
_last_warning = float('-inf')
_metrics = {'attempted': 0, 'committed': 0, 'duplicates': 0, 'dropped': 0}
_metrics_at = float('-inf')


def scalar(pairs, name, *, required=False):
    values = [v for k, v in pairs or () if k == name or k.startswith(name + ':')]
    if len(values) != 1 or type(values[0]) is not str:
        if required: raise ValueError('Missing trusted observer field')
        return None
    value = values[0]
    if value.startswith('"') and value.endswith('"'): value = value[1:-1]
    return value


class ReadOnlyRegistryStore:
    """Metadata reuse of the registry validator without Store startup writes."""
    def __init__(self, state):
        self.path = Path(state).absolute() / 'kaname.sqlite3'
        _private(self.path.parent, directory=True); _private(self.path)

    @contextmanager
    def connect(self):
        with closing(sqlite3.connect(self.path.as_uri() + '?mode=ro', uri=True, timeout=BUSY_SECONDS)) as db:
            db.execute('PRAGMA query_only=ON')
            yield db


def decision_context(decision, pairs, state):
    """Optional metadata after the existing authorization decision; no AD call."""
    serial = serial_number(radius_adapter.scalar(pairs, 'TLS-Client-Cert-Serial'))
    binding = None
    try:
        store = ReadOnlyRegistryStore(state)
        cert = CertificateReference(radius_adapter.issuer_sha256(store), serial)
        binding = CertificateRegistry(store).lookup(cert)
    except Exception:
        pass  # Keep the known decision/TLS serial even if optional lookup fails.
    data = {'reason': decision.reason if decision.reason in REASONS else 'RADIUS_ADAPTER_FAILED',
            'action': decision.action, 'policy_id': decision.policy_id,
            'certificate_serial': serial, 'object_guid': binding.object_guid if binding else None,
            'identity_kind': binding.kind if binding else None}
    token = base64.urlsafe_b64encode(json.dumps(data, separators=(',', ':')).encode()).decode()
    if len(token) > 1024: raise ValueError('Observer context too large')
    return ((CONTEXT, ':=', token),)


def authorize(pairs, *, state=radius_adapter.STATE):
    """Same decision provider, error fallback and native result as the adapter.

    Only server-internal control metadata is added. Metadata failure does not
    change the authorization result. No event is recorded at this stage.
    """
    import radiusd
    try:
        decision = radius_adapter.decision_for_pairs(pairs, state=state)
    except Exception:
        decision = Decision('deny', 'RADIUS_ADAPTER_FAILED')
    reply, config = freeradius_result(decision)
    try: config += decision_context(decision, pairs, state)
    except Exception: pass
    return radiusd.RLM_MODULE_OK, reply, config


def _context(values):
    token = scalar(values.get('session-state'), CONTEXT)
    if token is None: return None
    if not re.fullmatch(r'[A-Za-z0-9_=-]{1,1024}', token): return None
    try:
        data = json.loads(base64.b64decode(token, altchars=b'-_', validate=True))
        if (set(data) != {'reason', 'action', 'policy_id', 'certificate_serial', 'object_guid', 'identity_kind'} or
                data['reason'] not in REASONS or data['action'] not in ('allow', 'deny')): return None
        return data
    except (ValueError, TypeError): return None


def native_reason(values):
    # Inspect only this native error attribute, discard the raw message. A
    # category is emitted only for a recognized explicit native diagnostic.
    messages = [v.lower()[:2048] for section in ('request', 'session-state')
                for k, v in values.get(section) or () if k == 'Module-Failure-Message' and type(v) is str]
    combined = ' '.join(messages)
    for needles, reason in [
        (('certificate revoked',), 'TLS_CERTIFICATE_REVOKED'),
        (('certificate has expired', 'certificate expired'), 'TLS_CERTIFICATE_EXPIRED'),
        (('unsupported certificate purpose', 'unsuitable certificate purpose'), 'TLS_CERTIFICATE_PURPOSE'),
        (('unable to get local issuer', 'unknown ca', 'self-signed certificate'), 'TLS_CERTIFICATE_UNTRUSTED'),
        (('certificate verify failed', 'certificate verification failed'), 'TLS_CERTIFICATE_VERIFY_FAILED'),
    ]:
        if any(n in combined for n in needles): return reason, 'native_category'
    if not any(k == 'EAP-Message' for k, _ in values.get('request') or ()):
        return 'NON_EAP_REQUEST', 'native_category'
    return 'NATIVE_ACCESS_REJECT', 'native_generic'


def build_event(values):
    if type(values) is not dict: raise ValueError('Native attribute lists required')
    code = scalar(values.get('config'), FINAL_CODE)
    if code not in ('2', '3'): return None  # challenges and other packet types
    code = int(code)
    source, key = packet_key(scalar(values.get('config'), REQUEST_KEY, required=True))
    context = _context(values)
    reason, reason_source = ('NATIVE_ACCESS_ACCEPT', 'native_generic') if code == 2 else native_reason(values)
    if context:
        if (code == 2 and context['action'] == 'allow' or code == 3 and context['action'] == 'deny'):
            reason, reason_source = context['reason'], 'policy'
        elif code == 3: reason, reason_source = 'NATIVE_REJECT_AFTER_POLICY_ALLOW', 'native_generic'
    vlan = None
    if code == 2:
        t = scalar(values.get('reply'), 'Tunnel-Type')
        medium = scalar(values.get('reply'), 'Tunnel-Medium-Type')
        group = scalar(values.get('reply'), 'Tunnel-Private-Group-Id')
        # Dictionary canonicalization differs in Group-ID casing.
        if group is None: group = scalar(values.get('reply'), 'Tunnel-Private-Group-ID')
        if t in ('13', 'VLAN') and medium in ('6', 'IEEE-802') and group and group.isdecimal() and 1 <= int(group) <= 4094:
            vlan = int(group)
    station = scalar(values.get('request'), 'Calling-Station-Id')
    station = re.sub(r'[:-]', '', station or '').lower()
    station = ':'.join(station[i:i+2] for i in range(0, 12, 2)) if re.fullmatch(r'[0-9a-f]{12}', station) else None
    return {'event_id': hashlib.sha256((key + '|' + str(code)).encode()).hexdigest(),
            'request_id': key, 'at': utc(), 'response_code': code, 'nas_ip': source,
            'reason': reason, 'reason_source': reason_source,
            'policy_id': context['policy_id'] if context else None, 'vlan': vlan,
            'tls_verified': context is not None,
            'certificate_serial': context['certificate_serial'] if context else None,
            'object_guid': context['object_guid'] if context else None,
            'identity_kind': context['identity_kind'] if context else None,
            'calling_station': station, 'capture_run': CAPTURE_RUN}


def _warning(radiusd, code):
    global _failed, _last_warning
    with _lock:
        _failed += 1
        now = time.monotonic()
        if now - _last_warning < 60: return
        _last_warning = now
        radiusd.radlog(radiusd.L_WARN, 'AUTHWIRE_ACCESS_EVENT_DROPPED code=' + code + ' process_drop_count=' + str(_failed))


def _status(outcome, error_code, runtime):
    # Advisory process-local counters; no complete-history/heartbeat promise.
    # RuntimeDirectory is transient and excluded from persistent backup guards.
    global _metrics_at
    with _lock:
        _metrics['attempted'] += 1
        _metrics[outcome] += 1
        if error_code: _metrics['last_error_code'] = error_code
        now = time.monotonic()
        if now - _metrics_at < 1: return
        _metrics_at = now
        data = {**_metrics, 'requested': True, 'enabled': True, 'at': utc(),
                'pid': os.getpid(), 'capture_run': CAPTURE_RUN}
    directory = Path(runtime)
    from .radius_events import _private
    _private(directory, directory=True)
    path = directory / 'observer-status.json'
    if path.exists() or path.is_symlink(): _private(path)
    fd, name = tempfile.mkstemp(prefix='.observer-', dir=directory)
    try:
        with os.fdopen(fd, 'w') as handle: json.dump(data, handle)
        os.replace(name, path)
    finally:
        try: os.unlink(name)
        except FileNotFoundError: pass


def post_auth(values, *, state=radius_adapter.STATE, runtime=Path('/run/authwire-radius')):
    import radiusd
    outcome, code = 'dropped', None
    try:
        event = build_event(values)
        if event is None: return radiusd.RLM_MODULE_NOOP
        outcome = 'committed' if append(state, event) else 'duplicates'
    except Exception as error:
        code = str(error) if isinstance(error, EventStorageError) else 'OBSERVER_ERROR'
        if code not in {'UNSAFE_STORAGE', 'CAPACITY_REACHED', 'LOW_DISK_SPACE', 'STORAGE_BUSY', 'STORAGE_ERROR'}:
            code = 'OBSERVER_ERROR'
        try: _warning(radiusd, code)
        except Exception: pass
    try: _status(outcome, code, runtime)
    except Exception: pass
    # Returning only NOOP cannot add/remove reply attributes or change Auth-Type.
    return radiusd.RLM_MODULE_NOOP
