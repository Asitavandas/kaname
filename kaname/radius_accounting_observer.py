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


def accounting(pairs, *, state='/var/lib/kaname-lab'):
    """Ack only after durable insert or an idempotently recognized retry."""
    import radiusd
    try:
        radius_accounting.ingest(state, pairs)
        return radiusd.RLM_MODULE_OK
    except radius_accounting.AccountingStorageError as error:
        code = str(error)
        if code not in {'UNSAFE_STORAGE', 'CAPACITY_REACHED', 'LOW_DISK_SPACE',
                        'STORAGE_BUSY', 'STORAGE_ERROR'}:
            code = 'STORAGE_ERROR'
    except (ValueError, TypeError, OSError):
        code = 'INVALID_ACCOUNTING_PACKET'
    try:
        _warning(radiusd, code)
    except Exception:
        pass
    # No Accounting-Response on a write/validation failure: allow NAS retry.
    return radiusd.RLM_MODULE_FAIL