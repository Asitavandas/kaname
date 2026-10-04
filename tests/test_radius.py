"""Identity boundary tests, not simulated RADIUS authentication claims."""
import unittest
from dataclasses import replace
import json
from pathlib import Path
import tempfile
from types import SimpleNamespace
from unittest.mock import patch

from kaname.models import ValidationError
from kaname.policy import Decision
from kaname.radius import (CertificateBinding, CertificateReference, CurrentDirectoryAccount,
                           DirectoryUnavailable, TLSAuthorization, freeradius_result)

DOMAIN = 'lab.example.test'
GUID = 'e946e670-f4a4-4faa-a1fd-3b534ff963a1'
SID = 'S-1-5-21-11-22-33-1001'
GROUP = 'S-1-5-21-11-22-33-1100'
CERT = CertificateReference('a' * 64, '12ab')


def policy(**changes):
    result = {'id': 'lab-policy', 'name': 'Lab', 'enabled': True,
              'conditions': {'group_sids': [GROUP], 'access_types': ['wired', 'wireless'],
                             'nas_ips': ['127.0.0.1']},
              'constraints': {'eap_methods': ['EAP-TLS'], 'require_domain_device': True},
              'action': 'allow', 'vlan': 33}
    result.update(changes)
    return result


def binding(**changes):
    return replace(CertificateBinding(CERT, DOMAIN, GUID, SID, 'computer'), **changes)


def account(**changes):
    return replace(CurrentDirectoryAccount(DOMAIN, GUID, SID, 'computer', True,
                                            frozenset({GROUP})), **changes)


class Registry:
    def __init__(self, value):
        self.value = value

    def lookup(self, certificate):
        return self.value


class Directory:
    def __init__(self, value):
        self.value = value
        self.lookups = []

    def lookup(self, domain, guid):
        self.lookups.append((domain, guid))
        if isinstance(self.value, Exception):
            raise self.value
        return self.value


class RadiusAuthorizationTests(unittest.TestCase):
    def service(self, b=None, a=None, policies=None):
        return TLSAuthorization(policies or [policy()], registry=Registry(b or binding()),
                                directory=Directory(a or account()))

    def decide(self, service, **changes):
        args = {'nas_ip': '127.0.0.1', 'access_type': 'wired'}
        args.update(changes)
        return service.authorize(CERT, **args)

    def test_valid_bound_computer_policy_and_tagged_vlan(self):
        s = self.service()
        d = self.decide(s)
        self.assertEqual(d, Decision('allow', 'POLICY_ALLOW', 'lab-policy', 33))
        self.assertEqual(s.directory.lookups, [(DOMAIN, GUID)])
        reply, config = freeradius_result(d)
        self.assertEqual(dict((x[0], x[2]) for x in reply), {
            'Tunnel-Type:0': '13', 'Tunnel-Medium-Type:0': '6', 'Tunnel-Private-Group-ID:0': '33'})
        self.assertEqual(config, (('Auth-Type', ':=', 'Accept'),))

    def test_wireless_uses_same_verified_boundary(self):
        self.assertEqual(self.decide(self.service(), access_type='wireless').action, 'allow')

    def test_missing_registry_and_directory_never_allow(self):
        self.assertEqual(self.decide(TLSAuthorization([policy()])).reason, 'CERTIFICATE_UNBOUND')
        s = TLSAuthorization([policy()], registry=Registry(binding()))
        self.assertEqual(self.decide(s).reason, 'DIRECTORY_UNAVAILABLE')

    def test_unknown_cert_and_issuer_are_unbound(self):
        s = self.service()
        for cert in (CertificateReference('b' * 64, CERT.serial),
                     CertificateReference(CERT.issuer_sha256, '12ac')):
            self.assertEqual(s.authorize(cert, nas_ip='127.0.0.1', access_type='wired').reason,
                             'CERTIFICATE_UNBOUND')
        s.registry.value = None
        self.assertEqual(self.decide(s).reason, 'CERTIFICATE_UNBOUND')

    def test_inactive_binding_rejects_before_directory_lookup(self):
        s = self.service(b=binding(active=False))
        self.assertEqual(self.decide(s).reason, 'CERTIFICATE_INACTIVE')
        self.assertEqual(s.directory.lookups, [])

    def test_live_directory_failure_not_display_catalog_fallback(self):
        s = self.service(a=DirectoryUnavailable())
        self.assertEqual(self.decide(s).reason, 'DIRECTORY_UNAVAILABLE')
        s.directory.value = None
        self.assertEqual(self.decide(s).reason, 'ACCOUNT_NOT_FOUND')

    def test_disabled_account_and_removed_group_are_rechecked_each_call(self):
        s = self.service()
        self.assertEqual(self.decide(s).action, 'allow')
        s.directory.value = account(enabled=False)
        self.assertEqual(self.decide(s).reason, 'ACCOUNT_DISABLED')
        s.directory.value = account(security_group_sids=frozenset())
        self.assertEqual(self.decide(s).reason, 'NO_MATCHING_POLICY')
        self.assertEqual(len(s.directory.lookups), 3)

    def test_directory_binding_guid_sid_domain_kind_all_match(self):
        changes = ({'sid': 'S-1-5-21-11-22-33-1002'}, {'domain': 'other.example.test'},
                   {'object_guid': '19fc1747-55c7-4dd3-bf65-5c649ffbe606'}, {'kind': 'user'})
        for change in changes:
            with self.subTest(change=change):
                self.assertEqual(self.decide(self.service(a=account(**change))).reason,
                                 'ACCOUNT_BINDING_MISMATCH')

    def test_user_certificate_does_not_prove_domain_device(self):
        s = self.service(b=binding(kind='user'), a=account(kind='user'))
        self.assertEqual(self.decide(s).reason, 'DOMAIN_DEVICE_REQUIRED')
        p = policy(constraints={'eap_methods': ['EAP-TLS'], 'require_domain_device': False})
        self.assertEqual(self.decide(self.service(b=binding(kind='user'), a=account(kind='user'),
                                                policies=[p])).action, 'allow')

    def test_conflicts_constraints_and_nas_conditions_still_apply(self):
        self.assertEqual(self.decide(self.service(policies=[policy(action='deny', vlan=None),
                                                          policy(id='later')])).reason, 'POLICY_CONFLICT')
        p = policy(constraints={'eap_methods': ['PEAP-TLS'], 'require_domain_device': True})
        self.assertEqual(self.decide(self.service(policies=[p])).reason, 'EAP_CONSTRAINT_FAILED')
        self.assertEqual(self.decide(self.service(), nas_ip='127.0.0.2').reason, 'NO_MATCHING_POLICY')

    def test_reject_does_not_emit_any_vlan(self):
        reply, config = freeradius_result(Decision('deny', 'ACCOUNT_DISABLED', 'lab-policy', 33))
        self.assertEqual(reply, ())
        self.assertEqual(config, (('Auth-Type', ':=', 'Reject'),))

    def test_malformed_allow_result_cannot_emit_accept_or_vlan(self):
        for value in (None, {}, Decision('allow', 'unverified', 'policy', 33),
                      Decision('allow', 'POLICY_ALLOW', None, 33),
                      Decision('allow', 'POLICY_ALLOW', 'policy', '33'),
                      Decision('allow', 'POLICY_ALLOW', 'policy', True),
                      Decision('allow', 'POLICY_ALLOW', 'policy', 4095)):
            with self.subTest(value=value):
                self.assertEqual(freeradius_result(value), ((), (('Auth-Type', ':=', 'Reject'),)))

    def test_serial_canonicalization_and_bounds(self):
        self.assertEqual(CertificateReference('a' * 64, '0012AB'), CERT)
        for serial in ('', '0', '-1', '12:ab', '"12ab"', '8' + '0' * 39, 'f' * 41):
            with self.subTest(serial=serial), self.assertRaises(ValidationError):
                CertificateReference('a' * 64, serial)
        for issuer in ('a' * 63, 'A' * 64, 'z' * 64):
            with self.assertRaises(ValidationError):
                CertificateReference(issuer, '1')

    def test_invalid_guid_sid_domain_and_account_kind(self):
        for change in ({'object_guid': 'some-user'}, {'object_guid': str(__import__('uuid').UUID(int=0))},
                       {'sid': GROUP + '-3'}, {'sid': 'S-1-5-21-11-22-33-4294967296'},
                       {'domain': 'not-a-domain'}, {'domain': DOMAIN.upper()}, {'kind': 'group'},
                       {'active': 1}):
            with self.subTest(change=change), self.assertRaises(ValidationError):
                binding(**change)

    def test_group_limit_is_rejected_not_truncated(self):
        groups = frozenset('S-1-5-21-11-22-33-' + str(n) for n in range(257))
        with self.assertRaises(ValidationError):
            account(security_group_sids=groups)
        with self.assertRaises(ValidationError):
            account(security_group_sids=[GROUP])

    def test_untrusted_identity_input_or_provider_result_never_allows(self):
        s = self.service()
        s.directory.value = {'authenticated': True, 'group_sids': [GROUP]}
        self.assertEqual(self.decide(s).reason, 'DIRECTORY_RESULT_INVALID')
        self.assertEqual(s.authorize({'serial': CERT.serial}, nas_ip='127.0.0.1',
                                    access_type='wired').reason, 'IDENTITY_NOT_VERIFIED')
        for change in ({'nas_ip': 'bad'}, {'access_type': 'other'}):
            self.assertEqual(self.decide(self.service(), **change).action, 'deny')

    def test_native_fixture_callback_never_accepts_on_event_storage_failure(self):
        from tests.radius_fixture import authorize
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            (root / 'LAB_ONLY').write_text('KANAME temporary loopback EAP-TLS laboratory\n')
            data = {'lab_only': True, 'issuer_sha256': CERT.issuer_sha256, 'issuer_dn': '/CN=Test',
                    'nas_ip': '127.0.0.1', 'access_type': 'wired', 'case': 'unit',
                    'directory_available': True, 'policies': [policy()],
                    'bindings': {CERT.serial: {'domain': DOMAIN, 'object_guid': GUID, 'sid': SID,
                                              'kind': 'computer', 'active': True}},
                    'accounts': {GUID: {'domain': DOMAIN, 'object_guid': GUID, 'sid': SID,
                                       'kind': 'computer', 'enabled': True,
                                       'security_group_sids': [GROUP]}}}
            (root / 'fixture.json').write_text(json.dumps(data))
            (root / 'decisions.jsonl').mkdir()  # Force the event write to fail AFTER an allow.
            pairs = (('TLS-Client-Cert-Issuer', '"/CN=Test"'), ('TLS-Client-Cert-Serial', '"12AB"'))
            with patch.dict('sys.modules', {'radiusd': SimpleNamespace(RLM_MODULE_OK=2)}):
                self.assertEqual(authorize(pairs, root), (2, (), (('Auth-Type', ':=', 'Reject'),)))

    def test_native_fixture_missing_duplicate_and_wrong_issuer_fields_reject(self):
        from tests.radius_fixture import scalar
        for pairs in ((), (('Serial', '1'), ('Serial', '2')), (('Serial', '"1\\2"'),)):
            with self.assertRaises(ValueError):
                scalar(pairs, 'Serial')


if __name__ == '__main__':
    unittest.main()
