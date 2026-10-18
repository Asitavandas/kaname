import base64
from concurrent.futures import ThreadPoolExecutor
import hashlib
import http.client
import json
from pathlib import Path
import sqlite3
import tempfile
import threading
import time
import types
import unittest
from unittest.mock import patch

from kaname import radius_events as events, radius_observer as observer
from kaname.policy import Decision
from kaname.radius import freeradius_result
from kaname.server import DevelopmentServer


def event(n=1, **changes):
    value = dict(event_id=hashlib.sha256(str(n).encode()).hexdigest(), at='2026-10-18T19:00:00.000Z',
                 response_code=2, nas_ip='192.0.2.2', reason='POLICY_ALLOW', reason_source='policy',
                 policy_id='pilot', vlan=110, tls_verified=True, certificate_serial='abcd',
                 object_guid='69b0d5cd-db61-4627-9db7-fcc5230152a3', identity_kind='computer',
                 calling_station='38:ca:84:db:ff:e6', capture_run='a' * 32)
    value.update(changes); return value


def native(code='2', *, context=True, **sections):
    value = {'config': ((observer.FINAL_CODE, code),
                       (observer.REQUEST_KEY, '"192.0.2.2|50123|0x' + 'a' * 32 + '"')),
             'request': (('EAP-Message', '0xdead'), ('User-Name', 'host/privileged-admin'),
                         ('NAS-IP-Address', '203.0.113.1'), ('Calling-Station-Id', '38-CA-84-DB-FF-E6')),
             'reply': (('Tunnel-Type:0', 'VLAN'), ('Tunnel-Medium-Type:0', 'IEEE-802'),
                       ('Tunnel-Private-Group-Id:0', '110')),
             'session-state': ()}
    if context:
        data = {k: event()[k] for k in ('policy_id', 'certificate_serial', 'object_guid', 'identity_kind')}
        data.update(action='allow', reason='POLICY_ALLOW')
        value['session-state'] = ((observer.CONTEXT, base64.urlsafe_b64encode(json.dumps(data).encode()).decode()),)
    value.update(sections); return value


class StorageTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(); self.addCleanup(self.temp.cleanup)
        self.state = Path(self.temp.name)
        self.path = events.initialize(self.state)

    def test_persistent_append_dedup_and_immutable_history(self):
        self.assertTrue(events.append(self.state, event()))
        self.assertFalse(events.append(self.state, event()))
        self.assertEqual(1, events.history(self.state, {})['storage']['records'])
        self.assertEqual(0, self.path.stat().st_mode & 0o077)
        before = hashlib.sha256(self.path.read_bytes()).digest()
        page = events.history(self.state, {})
        self.assertEqual(110, page['events'][0]['vlan'])
        self.assertTrue(page['events'][0]['tls_verified'])
        self.assertEqual(before, hashlib.sha256(self.path.read_bytes()).digest())
        self.assertFalse(page['coverage']['endpoint_success_proven'])
        with sqlite3.connect(self.path) as db:
            for sql in ('DELETE FROM access_events', "UPDATE access_events SET reason='forged'"):
                with self.assertRaises(sqlite3.IntegrityError): db.execute(sql)

    def test_concurrent_same_packet_is_one_event_and_reconnect_is_new(self):
        with ThreadPoolExecutor(max_workers=4) as pool:
            result = list(pool.map(lambda _: events.append(self.state, event()), range(8)))
        self.assertEqual(1, sum(result))
        events.append(self.state, event(2))
        self.assertEqual(2, events.history(self.state, {})['storage']['records'])

    def test_busy_budget_capacity_low_disk_and_missing_file_are_explicit(self):
        with sqlite3.connect(self.path) as writer:
            writer.execute('BEGIN EXCLUSIVE')
            start = time.monotonic()
            with self.assertRaisesRegex(events.EventStorageError, 'STORAGE_BUSY'): events.append(self.state, event())
            self.assertLess(time.monotonic() - start, 0.5)
        with patch.object(events, 'MAX_RECORDS', 1):
            events.append(self.state, event())
            with self.assertRaisesRegex(events.EventStorageError, 'CAPACITY_REACHED'): events.append(self.state, event(2))
        with patch.object(events.shutil, 'disk_usage', return_value=types.SimpleNamespace(free=0)):
            with self.assertRaisesRegex(events.EventStorageError, 'LOW_DISK_SPACE'): events.append(self.state, event(3))
        self.path.unlink()
        with self.assertRaises(FileNotFoundError): events.append(self.state, event())
        self.assertFalse(self.path.exists())

    def test_unknown_identity_and_reject_vlan_validation_and_private_paths(self):
        for change in ({'tls_verified': False}, {'response_code': 3}, {'nas_ip': 'bad'},
                       {'event_id': 'host/name'}, {'reason': 'secret payload'}, {'identity_kind': 'admin'}):
            with self.subTest(change=change), self.assertRaises(ValueError): events.append(self.state, event(**change))
        self.path.chmod(0o644)
        with self.assertRaisesRegex(events.EventStorageError, 'UNSAFE_STORAGE'): events.history(self.state, {})
        self.path.chmod(0o600)
        self.path.rename(self.path.with_suffix('.old'))
        self.path.symlink_to(self.path.with_suffix('.old'))
        with self.assertRaisesRegex(events.EventStorageError, 'UNSAFE_STORAGE'): events.initialize(self.state)

    def test_filters_pagination_time_boundaries_and_new_writes(self):
        for n in range(205): events.append(self.state, event(n))
        first = events.history(self.state, {})
        events.append(self.state, event(300))
        second = events.history(self.state, {'before': [str(first['next_before'])], 'watermark': [str(first['watermark'])]})
        third = events.history(self.state, {'before': [str(second['next_before'])], 'watermark': [str(first['watermark'])]})
        self.assertEqual(list(range(205, 0, -1)), [r['id'] for p in (first, second, third) for r in p['events']])
        q = {'from': ['2026-10-18T22:00:00+03:00'], 'to': ['2026-10-18T22:00:00.001+03:00'],
             'nas': ['192.0.2.2'], 'reason': ['POLICY_ALLOW'], 'result': ['accept'], 'q': ['ABCD']}
        self.assertEqual(100, len(events.history(self.state, q)['events']))
        q['q'] = ["%' OR 1=1 --"]
        self.assertEqual([], events.history(self.state, q)['events'])
        for q in ({'bad': ['x']}, {'result': ['allow']}, {'q': ['x\n']}, {'nas': ['host']},
                  {'reason': ['UNKNOWN']}, {'before': ['0']}, {'q': ['a', 'b']}):
            with self.assertRaises(ValueError): events.history(self.state, q)


class ObserverTests(unittest.TestCase):
    def test_selected_final_response_overrides_callback_allow_and_ignores_outer_identity(self):
        value = observer.build_event(native())
        events.validate(value)
        self.assertEqual('192.0.2.2', value['nas_ip']); self.assertEqual(110, value['vlan'])
        self.assertNotIn('privileged-admin', json.dumps(value))
        self.assertNotIn('203.0.113.1', json.dumps(value))
        value = observer.build_event(native('3'))
        self.assertEqual('NATIVE_REJECT_AFTER_POLICY_ALLOW', value['reason']); self.assertIsNone(value['vlan'])
        self.assertIsNone(observer.build_event(native('11')))

    def test_pre_callback_tls_failure_keeps_identity_unknown_and_sanitizes_native_reason(self):
        for message, reason in [('certificate revoked secret-key-value', 'TLS_CERTIFICATE_REVOKED'),
                                ('certificate has expired', 'TLS_CERTIFICATE_EXPIRED'),
                                ('unknown ca', 'TLS_CERTIFICATE_UNTRUSTED'),
                                ('unrecognized private detail', 'NATIVE_ACCESS_REJECT')]:
            value = native('3', context=False)
            value['request'] += (('Module-Failure-Message', message), ('TLS-Client-Cert-Serial', 'deadbeef'))
            result = observer.build_event(value); events.validate(result)
            self.assertEqual(reason, result['reason'])
            self.assertFalse(result['tls_verified']); self.assertIsNone(result['certificate_serial'])
            self.assertIsNone(result['object_guid']); self.assertNotIn('secret-key', json.dumps(result))

    def test_spoofed_context_in_request_and_duplicate_internal_key_do_not_promote_identity(self):
        value = native('3', context=False)
        value['request'] += native()['session-state']
        self.assertFalse(observer.build_event(value)['tls_verified'])
        value['config'] += (value['config'][1],)
        with self.assertRaises(ValueError): observer.build_event(value)

    def test_authorization_reply_and_auth_type_stay_identical_even_if_metadata_fails(self):
        radiusd = types.SimpleNamespace(RLM_MODULE_OK=2)
        for decision in (Decision('allow', 'POLICY_ALLOW', 'pilot', 110), Decision('deny', 'NO_MATCHING_POLICY')):
            with patch.dict('sys.modules', radiusd=radiusd), \
                 patch.object(observer.radius_adapter, 'decision_for_pairs', return_value=decision), \
                 patch.object(observer, 'decision_context', side_effect=OSError('private detail')):
                code, reply, config = observer.authorize(())
                self.assertEqual((2, *freeradius_result(decision)), (code, reply, config))
        with patch.dict('sys.modules', radiusd=radiusd), \
             patch.object(observer.radius_adapter, 'decision_for_pairs', side_effect=RuntimeError()), \
             patch.object(observer, 'decision_context', side_effect=RuntimeError()):
            self.assertEqual((2, (), (('Auth-Type', ':=', 'Reject'),)), observer.authorize(()))

    def test_observer_storage_error_is_noop_with_no_reply_changes_or_sensitive_error(self):
        warnings = []
        radiusd = types.SimpleNamespace(RLM_MODULE_NOOP=7, L_WARN=1, radlog=lambda level, message: warnings.append(message))
        with patch.dict('sys.modules', radiusd=radiusd), patch.object(observer, '_last_warning', float('-inf')), \
             patch.object(observer, 'append', side_effect=events.EventStorageError('STORAGE_BUSY')):
            self.assertEqual(7, observer.post_auth(native()))
            self.assertEqual(7, observer.post_auth(native()))
        self.assertEqual(1, len(warnings)); self.assertIn('STORAGE_BUSY', warnings[0])
        self.assertNotIn('privileged-admin', warnings[0])


if __name__ == '__main__': unittest.main()
