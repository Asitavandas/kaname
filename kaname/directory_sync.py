"""Single-reader periodic LDAP sync/probe while the panel process is running."""
import threading
import time

from .directory import DirectoryError, validate_connection, validate_catalog
from .models import ValidationError
from .store import ConflictError
from .vault import VaultError


class DirectorySync:
    def __init__(self, server):
        self.server = server
        self.stop = threading.Event()
        self.next_sync = 0.0
        self.next_check = 0.0
        self.settings_key = None
        self.thread = threading.Thread(target=self._loop, name='KANAME-AD-scheduler', daemon=True)
        self.thread.start()

    def close(self):
        self.stop.set()
        self.thread.join(timeout=65)

    def read(self, expected_revision, connection=None, *, probe=False):
        server = self.server
        current = server.store.snapshot()
        if current['config'] is None:
            raise ValidationError('CONFIG_REQUIRED')
        if type(expected_revision) is not int or expected_revision != current['revision']:
            raise ConflictError()
        if not server.directory_lock.acquire(blocking=False):
            raise DirectoryError('AD_QUERY_BUSY')
        try:
            if time.monotonic() < server.directory_next_attempt:
                raise DirectoryError('AD_RETRY_LATER')
            server.directory_next_attempt = time.monotonic() + 10
            connection = connection or server.operations.directory_connection()
            validate_connection(connection, current['config'])
            reader = server.directory_health_reader if probe else server.directory_reader
            value = reader(connection, current['config'])
            if probe:
                status = None
            else:
                try: value = validate_catalog(value, current['config']['ad_domain'], connection['dc_fqdn'])
                except (ValueError, TypeError, KeyError):
                    raise DirectoryError('AD_INVALID_RESPONSE') from None
                status = server.store.save_directory(current['revision'], value)
            server.operations.record_health(expected_revision=current['revision'])
            if not probe:
                self.next_sync = time.monotonic() + server.operations.directory()['sync_minutes'] * 60
            self.next_check = time.monotonic() + server.operations.directory()['check_minutes'] * 60
            return status
        except DirectoryError as error:
            if error.code not in {'AD_QUERY_BUSY', 'AD_RETRY_LATER'}:
                try: server.operations.record_health(error.code, expected_revision=current['revision'])
                except ConflictError: pass
            raise
        except VaultError:
            try: server.operations.record_health('SECRET_STORE_UNAVAILABLE', expected_revision=current['revision'])
            except ConflictError: pass
            raise
        finally:
            if connection is not None:
                connection['password'] = ''
            server.directory_lock.release()

    def tick(self, now=None):
        now = time.monotonic() if now is None else now
        settings = self.server.operations.directory()
        if not settings['credentials_saved']:
            return
        # No automatic LDAP call at installation; user must save connection settings.
        key = tuple(sorted(settings.items()))
        if key != self.settings_key:
            self.settings_key = key
            self.next_sync = now + settings['sync_minutes'] * 60
            self.next_check = now + settings['check_minutes'] * 60
        due_sync = settings['automatic_sync'] and now >= self.next_sync
        due_check = now >= self.next_check
        if not (due_sync or due_check):
            return
        revision = self.server.store.snapshot()['revision']
        try:
            self.read(revision, probe=not due_sync)
        finally:
            # Even a failure waits a full interval, avoiding repeated bad-password binds.
            if due_sync: self.next_sync = now + settings['sync_minutes'] * 60
            self.next_check = now + settings['check_minutes'] * 60

    def _loop(self):
        while not self.stop.wait(1):
            try:
                self.tick()
            except Exception:
                # Raw exceptions may contain connection data. Health carries fixed codes.
                pass
