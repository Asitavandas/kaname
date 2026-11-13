"""FreeRADIUS accounting callback; storage errors trigger NAS retry."""
import json
import os
from pathlib import Path
import tempfile
import threading
import time

from . import radius_accounting
from .radius_events import utc

_lock = threading.Lock()
_failed = 0
_last_warning = float('-inf')
_last_status = float('-inf')
_counts = {'committed': 0, 'duplicates': 0, 'failed': 0}
_last_error = None


def _warning(radiusd, code):
    global _failed, _last_warning
    with _lock:
        _failed += 1
        now = time.monotonic()
        if now - _last_warning < 60:
            return
        _last_warning = now
        radiusd.radlog(radiusd.L_WARN,
                       'AUTHWIRE_ACCOUNTING_NOT_PERSISTED code=' + code +
                       ' process_drop_count=' + str(_failed))


def _status(runtime, outcome, error=None):
    global _last_status, _last_error
    root = Path(runtime)
    with _lock:
        _counts[outcome] += 1
        changed_error = error is not None and error != _last_error
        if error is not None:
            _last_error = error
        now = time.monotonic()
        if not changed_error and now - _last_status < 1:
            return
        radius_accounting._private(root, directory=True)
        fd, name = tempfile.mkstemp(prefix='.accounting-status-', dir=root)
        try:
            with os.fdopen(fd, 'w') as handle:
                json.dump({'enabled': True, 'at': utc(), **_counts,
                           'last_error_code': _last_error}, handle)
            os.replace(name, root / radius_accounting.STATUS_FILE)
            _last_status = now
        finally:
            Path(name).unlink(missing_ok=True)


def accounting(values):
    """Ack only after durable insert or an idempotently recognized retry."""
    import radiusd
    runtime = None
    try:
        control = values.get('config')
        runtime = radius_accounting._values(control, 'AuthWire-Accounting-Runtime')
        request = tuple((name, value) for name, value in values.get('request', ())
                        if name.split(':', 1)[0] not in
                        {'Packet-Src-IP-Address', 'Packet-Authentication-Vector'})
        state = radius_accounting._values(control, 'AuthWire-Accounting-State', required=True)
        source = radius_accounting._values(control, 'AuthWire-Accounting-Source', required=True)
        vector = radius_accounting._values(control, 'AuthWire-Accounting-Vector', required=True)
        saved = radius_accounting.ingest(state, request + (
            ('Packet-Src-IP-Address', source), ('Packet-Authentication-Vector', vector)))
        if runtime:
            try:
                _status(runtime, 'committed' if saved else 'duplicates')
            except (OSError, ValueError, radius_accounting.AccountingStorageError):
                pass
        return radiusd.RLM_MODULE_OK
    except radius_accounting.AccountingStorageError as error:
        code = str(error)
        if code not in {'UNSAFE_STORAGE', 'CAPACITY_REACHED', 'LOW_DISK_SPACE',
                        'STORAGE_BUSY', 'STORAGE_ERROR'}:
            code = 'STORAGE_ERROR'
    except (AttributeError, ValueError, TypeError, OSError):
        code = 'INVALID_ACCOUNTING_PACKET'
    if runtime:
        try:
            _status(runtime, 'failed', code)
        except (OSError, ValueError, radius_accounting.AccountingStorageError):
            pass
    try:
        _warning(radiusd, code)
    except Exception:
        pass
    # No Accounting-Response on a write/validation failure: allow NAS retry.
    return radiusd.RLM_MODULE_FAIL
