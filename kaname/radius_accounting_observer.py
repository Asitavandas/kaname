"""FreeRADIUS accounting callback; storage errors trigger NAS retry."""
import threading
import time

from . import radius_accounting

_lock = threading.Lock()
_failed = 0
_last_warning = float('-inf')


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


def accounting(values):
    """Ack only after durable insert or an idempotently recognized retry."""
    import radiusd
    try:
        control = values.get('config')
        request = tuple((name, value) for name, value in values.get('request', ())
                        if name.split(':', 1)[0] not in
                        {'Packet-Src-IP-Address', 'Packet-Authentication-Vector'})
        state = radius_accounting._values(control, 'AuthWire-Accounting-State', required=True)
        source = radius_accounting._values(control, 'AuthWire-Accounting-Source', required=True)
        vector = radius_accounting._values(control, 'AuthWire-Accounting-Vector', required=True)
        radius_accounting.ingest(state, request + (
            ('Packet-Src-IP-Address', source), ('Packet-Authentication-Vector', vector)))
        return radiusd.RLM_MODULE_OK
    except radius_accounting.AccountingStorageError as error:
        code = str(error)
        if code not in {'UNSAFE_STORAGE', 'CAPACITY_REACHED', 'LOW_DISK_SPACE',
                        'STORAGE_BUSY', 'STORAGE_ERROR'}:
            code = 'STORAGE_ERROR'
    except (AttributeError, ValueError, TypeError, OSError):
        code = 'INVALID_ACCOUNTING_PACKET'
    try:
        _warning(radiusd, code)
    except Exception:
        pass
    # No Accounting-Response on a write/validation failure: allow NAS retry.
    return radiusd.RLM_MODULE_FAIL
