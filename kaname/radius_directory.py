"""Live authorization provider. No UI catalog fallback or positive cache."""
import threading
import time
import sqlite3

from .directory import DirectoryError
from .directory_linux import lookup_linux_account
from .models import ValidationError, dns_name
from .radius import CurrentDirectoryAccount, DirectoryUnavailable, object_id
from .vault import VaultError


class LiveDirectory:
    def __init__(self, operations, *, reader=lookup_linux_account):
        self.operations, self.reader = operations, reader
        # Lab bound: one expensive tokenGroups/GSSAPI lookup at a time.
        # Busy requests reject; no unbounded queue and no cached allow.
        self.lock = threading.Lock()
        self.retry_after = 0.0

    def lookup(self, domain, guid):
        connection = None
        if not self.lock.acquire(blocking=False):
            raise DirectoryUnavailable()
        try:
            object_id(guid)
            if domain != dns_name(domain):
                raise DirectoryUnavailable()
            current = self.operations.store.snapshot()
            config = current['config']
            if not config or config['ad_domain'] != domain or time.monotonic() < self.retry_after:
                raise DirectoryUnavailable()
            health = self.operations.health()
            if health.get('error') == 'AD_CREDENTIALS_REJECTED':
                raise DirectoryUnavailable()
            connection = self.operations.directory_connection()
            key = {k: connection[k] for k in ('dc_fqdn', 'username', 'search_base')}
            account = self.reader(connection, config, guid)
            # Concurrent policy/config/credential changes invalidate the read.
            if self.operations.store.snapshot()['revision'] != current['revision']:
                raise DirectoryUnavailable()
            if key != {k: self.operations.directory()[k] for k in key}:
                raise DirectoryUnavailable()
            if account is not None and (type(account) is not CurrentDirectoryAccount or
                    (account.domain, account.object_guid) != (domain, guid)):
                raise DirectoryUnavailable()
            return account
        except DirectoryError as error:
            self.retry_after = time.monotonic() + 10
            # Persist credential rejection across panel/adapter restarts; saving
            # corrected credentials in the existing panel clears this pause.
            if error.code == 'AD_CREDENTIALS_REJECTED':
                try:
                    self.operations.record_health(error.code, expected_revision=current['revision'])
                except Exception:
                    pass
            raise DirectoryUnavailable() from None
        except (VaultError, ValidationError, ValueError, TypeError, KeyError, OSError, sqlite3.Error):
            raise DirectoryUnavailable() from None
        finally:
            if connection is not None:
                connection['password'] = ''
            self.lock.release()
