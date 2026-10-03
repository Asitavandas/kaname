import http.client
import json
import tempfile
import threading
import time
import unittest
import sys
from pathlib import Path

from kaname.admin import AdminStore, RESOURCES, password_matches
from kaname.server import DevelopmentServer
from .helpers import config, identity
from dataclasses import asdict


class AdministratorHTTPTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.server = DevelopmentServer(self.temp.name, 0)
        # Join request workers before removing the fixture database, including
        # when a timed-out client has disconnected. Do not leave Windows handles
        # in a daemon worker and hide the original failure under cleanup errors.
        self.server.daemon_threads = False
        self.server.store.save(0, config=config())
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True); self.thread.start()
        self.addCleanup(self.close)
        self.auth = None
        code, value, headers = self.call('POST', '/api/auth/login', {'username': 'admin', 'password': 'Kaname'})
        self.assertEqual(200, code)
        self.auth = (headers['Set-Cookie'].split(';')[0], value['csrf'])

    def close(self):
        self.server.shutdown(); self.server.server_close(); self.thread.join()

    def call(self, method, path, value=None, auth='default', headers=None):
        pair = self.auth if auth == 'default' else auth
        h = {'Content-Type': 'application/json', 'Origin': f'http://127.0.0.1:{self.server.server_port}'}
        if pair:
            h.update(Cookie=pair[0]); h['X-Kaname-CSRF'] = pair[1]
        h.update(headers or {})
        conn = http.client.HTTPConnection('127.0.0.1', self.server.server_port, timeout=8)
        try:
            conn.request(method, path, body=json.dumps(value) if value is not None else None, headers=h)
            response = conn.getresponse()
            return response.status, json.loads(response.read()), dict(response.headers)
        except TimeoutError:
            # Source locations only: never headers, values, locals or secrets.
            stacks = []
            for frame in sys._current_frames().values():
                locations = []
                while frame:
                    name = Path(frame.f_code.co_filename).name
                    if name in {'admin.py', 'server.py', 'store.py'}:
                        locations.append({'module': name, 'function': frame.f_code.co_name,
                                          'line': frame.f_lineno})
                    frame = frame.f_back
                if locations:
                    stacks.append(locations)
            print('KANAME_TEST_TIMEOUT_LOCATIONS=' + json.dumps(stacks), flush=True)
            raise
        finally:
            conn.close()

    def system(self):
        code, value, _ = self.call('GET', '/api/system'); self.assertEqual(200, code)
        return value

    def create_profile(self, name, grants, mode='Custom'):
        s = self.system()
        code, value, _ = self.call('POST', '/api/system/profiles/save', {'expected_revision': s['revision'], 'profile': {'id': '', 'name': name, 'mode': mode, 'grants': grants}})
        self.assertEqual(200, code, value)
        return next(p['id'] for p in self.system()['profiles'] if p['name'] == name)

    def user(self, name='reader', profile_id=None, user_id='', password='PrivateTestPassword42', enabled=True):
        s = self.system()
        profile_id = profile_id or next(p['id'] for p in s['profiles'] if p['mode'] == 'Admin_ReadOnly')
        code, value, _ = self.call('POST', '/api/system/users/save', {'expected_revision': s['revision'], 'user': {'id': user_id, 'username': name, 'profile_id': profile_id, 'password': password, 'enabled': enabled}})
        self.assertEqual(200, code, value)
        return next(u['id'] for u in self.system()['users'] if u['username'] == name)

    def login(self, name, password='PrivateTestPassword42'):
        code, value, headers = self.call('POST', '/api/auth/login', {'username': name, 'password': password}, auth=None)
        self.assertEqual(200, code, value)
        return (headers['Set-Cookie'].split(';')[0], value['csrf'])

    def test_default_login_cookie_and_hash_only_storage(self):
        self.assertEqual({'write'}, set(self.call('GET', '/api/auth/session')[1]['permissions'].values()))
        code, value, headers = self.call('POST', '/api/auth/login', {'username': 'ADMIN', 'password': 'Kaname'})
        self.assertEqual(200, code)
        self.assertIn('HttpOnly', headers['Set-Cookie']); self.assertIn('SameSite=Strict', headers['Set-Cookie'])
        self.assertNotEqual(self.auth[0], headers['Set-Cookie'].split(';')[0])
        with self.server.admin.connect() as db:
            hashed = db.execute('SELECT password_hash FROM admin_users WHERE normalized=?', ('admin',)).fetchone()[0]
            session_ids = [r[0] for r in db.execute('SELECT digest FROM admin_sessions')]
        self.assertTrue(hashed.startswith('pbkdf2_sha256$600000$'))
        self.assertTrue(password_matches('Kaname', hashed))
        self.assertNotIn(self.auth[0].split('=')[1], session_ids)
        self.assertNotIn(b'Kaname', self.server.admin.path.read_bytes())
        self.assertNotIn('password_hash', json.dumps(self.system()))

    def test_windows_initial_login_check_uses_and_revokes_its_session(self):
        from tools.windows_update import verify_initial_login
        with self.server.admin.connect() as db:
            count = db.execute('SELECT COUNT(*) FROM admin_sessions').fetchone()[0]
        self.assertTrue(verify_initial_login(self.server.server_port))
        with self.server.admin.connect() as db:
            self.assertEqual(count, db.execute('SELECT COUNT(*) FROM admin_sessions').fetchone()[0])

    def test_windows_initial_login_check_rejects_changed_default_credentials(self):
        from tools.windows_update import verify_initial_login
        from kaname.admin import password_hash
        with self.server.admin.connect() as db:
            db.execute('UPDATE admin_users SET password_hash=?', (password_hash('ChangedPrivatePassword42'),))
        with self.assertRaisesRegex(ValueError, '^Initial panel login check failed$'):
            verify_initial_login(self.server.server_port)

    def test_wrong_password_unknown_user_and_disabled_account_share_error(self):
        self.user(enabled=False)
        for name, password in [('admin', 'wrong'), ('missing', 'wrong'), ('reader', 'PrivateTestPassword42')]:
            code, value, _ = self.call('POST', '/api/auth/login', {'username': name, 'password': password}, auth=None)
            self.assertEqual((401, {'error': 'LOGIN_FAILED'}), (code, value))

    def test_readonly_reads_but_cannot_mutate_any_management_route(self):
        self.user(); pair = self.login('reader')
        for path in ['/api/state', '/api/audit', '/api/system', '/api/directory/catalog', '/api/policies/groups']:
            self.assertEqual(200, self.call('GET', path, auth=pair)[0], path)
        for path in ['/api/policies', '/api/directory/sync', '/api/system/users/save', '/api/system/users/delete', '/api/system/profiles/save', '/api/system/profiles/delete']:
            self.assertEqual(403, self.call('POST', path, {}, auth=pair)[0], path)
        self.assertEqual(403, self.call('POST', '/api/config', {'expected_revision': 1, 'patch': {'appliance_fqdn': 'changed.lab.example'}}, auth=pair)[0])
        data = asdict(identity()); data['group_sids'] = list(data['group_sids'])
        self.assertEqual(200, self.call('POST', '/api/simulate', data, auth=pair)[0])

    def test_custom_profile_filters_state_and_checks_each_setup_tab(self):
        profile = self.create_profile('ProductEditor', {'setup.product': 'write'})
        self.user('product', profile); pair = self.login('product')
        code, value, _ = self.call('GET', '/api/state', auth=pair)
        self.assertEqual(200, code); self.assertEqual({'appliance_fqdn'}, set(value['config']))
        for forbidden in ['policies', 'directory_public', 'pki_public', 'directory_context']: self.assertNotIn(forbidden, value)
        for path in ['/api/system', '/api/audit', '/api/directory/catalog', '/api/policies/groups']:
            self.assertEqual(403, self.call('GET', path, auth=pair)[0])
        code, _, _ = self.call('POST', '/api/config', {'expected_revision': 1, 'patch': {'appliance_fqdn': 'new.lab.example'}}, auth=pair)
        self.assertEqual(200, code)
        self.assertEqual('lab.example', self.server.store.snapshot()['config']['ad_domain'])
        self.assertEqual(403, self.call('POST', '/api/config', {'expected_revision': 2, 'patch': {'ad_domain': 'other.example'}}, auth=pair)[0])

    def test_directory_connection_and_catalog_have_independent_rights(self):
        from .test_membership import membership_catalog
        self.server.store.save_directory(1, membership_catalog())
        detail = '/api/directory/detail?kind=users&id=00000000-0000-0000-0000-000000000001'
        for name, grants, detail_status, catalog_status, sync_status in [
            ('connector', {'directory.connection': 'write', 'directory.catalog': 'none'}, 403, 403, 400),
            ('catalogreader', {'directory.connection': 'none', 'directory.catalog': 'read'}, 200, 200, 403),
        ]:
            profile = self.create_profile(name, grants); self.user(name, profile); auth = self.login(name)
            self.assertEqual(detail_status, self.call('GET', detail, auth=auth)[0])
            self.assertEqual(catalog_status, self.call('GET', '/api/directory/catalog?kind=users', auth=auth)[0])
            self.assertEqual(sync_status, self.call('POST', '/api/directory/sync', {}, auth=auth)[0])

    def test_legacy_custom_directory_right_is_preserved_until_explicitly_split(self):
        from kaname.admin import permissions
        self.assertEqual('write', permissions('Custom', {'directory.catalog': 'write'})['directory.connection'])
        self.assertEqual('none', permissions('Custom', {'directory.catalog': 'write', 'directory.connection': 'none'})['directory.connection'])

    def test_session_writes_require_origin_and_csrf(self):
        for extra in [{'X-Kaname-CSRF': ''}, {'Origin': ''}, {'Origin': 'https://attacker.example'}]:
            self.assertEqual(403, self.call('POST', '/api/auth/logout', {}, headers=extra)[0])
        self.assertEqual(403, self.call('POST', '/api/auth/login', {'username': 'admin', 'password': 'Kaname'}, auth=None, headers={'Origin': ''})[0])
        self.assertEqual(403, self.call('GET', '/api/state', headers={'Host': 'attacker.example'})[0])

    def test_rejected_partial_post_is_bounded_and_does_not_execute_logout(self):
        started = time.monotonic()
        self.assertEqual(403, self.call('POST', '/api/auth/logout', {}, headers={'X-Kaname-CSRF': '', 'Content-Length': '200000'})[0])
        self.assertLess(time.monotonic() - started, 2)
        self.assertEqual(200, self.call('GET', '/api/auth/session')[0])

    def test_logout_expiry_and_idle_timeout_invalidate_cookie(self):
        self.assertEqual(200, self.call('POST', '/api/auth/logout', {})[0])
        self.assertEqual(401, self.call('GET', '/api/state')[0])
        pair = self.login('admin', 'Kaname')
        with self.server.admin.connect() as db: db.execute('UPDATE admin_sessions SET last_seen=?', (time.time() - 1801,))
        self.assertEqual(401, self.call('GET', '/api/state', auth=pair)[0])
        pair = self.login('admin', 'Kaname')
        with self.server.admin.connect() as db: db.execute('UPDATE admin_sessions SET expires=0')
        self.assertEqual(401, self.call('GET', '/api/state', auth=pair)[0])

    def test_edit_user_password_or_disable_revokes_existing_sessions(self):
        uid = self.user(); pair = self.login('reader')
        self.user('reader', user_id=uid, password='NewPrivatePassword43')
        self.assertEqual(401, self.call('GET', '/api/state', auth=pair)[0])
        pair = self.login('reader', 'NewPrivatePassword43')
        self.user('reader', user_id=uid, password='', enabled=False)
        self.assertEqual(401, self.call('GET', '/api/state', auth=pair)[0])

    def test_profile_change_applies_to_current_session_and_cannot_escalate(self):
        profile = self.create_profile('PolicyEditor', {'policies.rules': 'write'})
        self.user('policyeditor', profile); pair = self.login('policyeditor')
        self.assertEqual(200, self.call('POST', '/api/policies', {'expected_revision': 1, 'policies': []}, auth=pair)[0])
        s = self.system()
        self.assertEqual(200, self.call('POST', '/api/system/profiles/save', {'expected_revision': s['revision'], 'profile': {'id': profile, 'name': 'PolicyViewer', 'mode': 'Custom', 'grants': {'policies.rules': 'read'}}})[0])
        self.assertEqual(403, self.call('POST', '/api/policies', {'expected_revision': 2, 'policies': []}, auth=pair)[0])
        self.assertEqual('read', self.call('GET', '/api/auth/session', auth=pair)[1]['permissions']['policies.rules'])
        elevated = self.create_profile('ProfileOperator', {'system.profiles': 'write', 'system.administrators': 'write'})
        self.user('operator', elevated); operator = self.login('operator')
        rev = self.call('GET', '/api/system', auth=operator)[1]['revision']
        request = {'expected_revision': rev, 'profile': {'id': '', 'name': 'Escalation', 'mode': 'SuperAdmin', 'grants': {}}}
        self.assertEqual(403, self.call('POST', '/api/system/profiles/save', request, auth=operator)[0])
        admin = next(u for u in self.system()['users'] if u['username'] == 'admin')
        self.assertEqual(403, self.call('POST', '/api/system/users/delete', {'expected_revision': rev, 'id': admin['id']}, auth=operator)[0])

    def test_all_accounts_and_unused_profiles_are_deletable_without_reseeding(self):
        s = self.system(); admin_id = s['users'][0]['id']
        self.assertEqual(200, self.call('POST', '/api/system/users/delete', {'expected_revision': s['revision'], 'id': admin_id})[0])
        self.assertEqual(401, self.call('GET', '/api/state')[0])
        AdminStore(self.server.store)
        with self.server.admin.connect() as db: self.assertEqual(0, db.execute('SELECT COUNT(*) FROM admin_users').fetchone()[0])
        maintenance = {'Authorization': 'Bearer ' + self.server.token}
        profiles = self.call('GET', '/api/system', auth=None, headers=maintenance)[1]['profiles']
        for p in profiles:
            rev = self.call('GET', '/api/system', auth=None, headers=maintenance)[1]['revision']
            self.assertEqual(200, self.call('POST', '/api/system/profiles/delete', {'expected_revision': rev, 'id': p['id']}, auth=None, headers=maintenance)[0])
        AdminStore(self.server.store)
        with self.server.admin.connect() as db: self.assertEqual(0, db.execute('SELECT COUNT(*) FROM admin_profiles').fetchone()[0])

    def test_used_profile_delete_and_stale_save_are_rejected_atomically(self):
        s = self.system(); p = next(p for p in s['profiles'] if p['mode'] == 'SuperAdmin')
        self.assertEqual(409, self.call('POST', '/api/system/profiles/delete', {'expected_revision': s['revision'], 'id': p['id']})[0])
        self.assertEqual(s['revision'], self.system()['revision'])
        self.create_profile('NewProfile', {})
        self.assertEqual(409, self.call('POST', '/api/system/profiles/save', {'expected_revision': s['revision'], 'profile': {'id': '', 'name': 'Stale', 'mode': 'Custom', 'grants': {}}})[0])

    def test_default_profile_is_editable_and_grants_schema_is_closed(self):
        s = self.system(); p = next(p for p in s['profiles'] if p['mode'] == 'Admin_ReadOnly')
        self.assertEqual(200, self.call('POST', '/api/system/profiles/save', {'expected_revision': s['revision'], 'profile': {'id': p['id'], 'name': 'RenamedViewer', 'mode': 'Custom', 'grants': {'audit.events': 'read'}}})[0])
        rev = self.system()['revision']
        for grants in [{'unknown': 'write'}, {'audit.events': True}, {'audit.events': 'root'}]:
            self.assertEqual(400, self.call('POST', '/api/system/profiles/save', {'expected_revision': rev, 'profile': {'id': '', 'name': 'Invalid', 'mode': 'Custom', 'grants': grants}})[0])

    def test_own_password_change_requires_current_password_and_revokes_cookie(self):
        self.assertEqual(400, self.call('POST', '/api/auth/password', {'current': 'wrong', 'new': 'NewPrivatePassword43'})[0])
        self.assertEqual(200, self.call('POST', '/api/auth/password', {'current': 'Kaname', 'new': 'NewPrivatePassword43'})[0])
        self.assertEqual(401, self.call('GET', '/api/state')[0])
        pair = self.login('admin', 'NewPrivatePassword43')
        self.assertEqual(200, self.call('GET', '/api/state', auth=pair)[0])
        self.assertNotIn(b'NewPrivatePassword43', self.server.admin.path.read_bytes())

    def test_user_edit_with_empty_password_preserves_password_and_casefold_uniqueness(self):
        uid = self.user(); self.user('renamed', user_id=uid, password='')
        self.assertEqual(200, self.call('GET', '/api/state', auth=self.login('renamed'))[0])
        s = self.system()
        self.assertEqual(409, self.call('POST', '/api/system/users/save', {'expected_revision': s['revision'], 'user': {'id': '', 'username': 'RENAMED', 'password': 'PrivateTestPassword42', 'profile_id': s['users'][0]['profile_id'], 'enabled': True}})[0])

    def test_login_throttle_is_persistent_and_resets_after_window(self):
        with self.server.admin.connect() as db: db.execute('UPDATE admin_login_rate SET attempts=30')
        self.assertEqual(429, self.call('POST', '/api/auth/login', {'username': 'admin', 'password': 'Kaname'}, auth=None)[0])
        AdminStore(self.server.store)
        self.assertEqual(429, self.call('POST', '/api/auth/login', {'username': 'admin', 'password': 'Kaname'}, auth=None)[0])
        with self.server.admin.connect() as db: db.execute('UPDATE admin_login_rate SET started=?', (time.time() - 61,))
        self.assertEqual(200, self.call('POST', '/api/auth/login', {'username': 'admin', 'password': 'Kaname'}, auth=None)[0])
