import unittest
from kaname.policy import evaluate, radius_vlan_attributes
from kaname.models import ValidationError, strict_json, validate_config, validate_policies
from .helpers import policy, identity, config


class PolicyTests(unittest.TestCase):
    def test_allowed_device(self):
        self.assertEqual(evaluate([policy()], identity()).action, 'allow')

    def test_no_policy_defaults_deny(self):
        self.assertEqual(evaluate([], identity()).reason, 'NO_MATCHING_POLICY')

    def test_not_authenticated(self):
        self.assertEqual(evaluate([policy()], identity(authenticated=False)).reason, 'IDENTITY_NOT_VERIFIED')

    def test_directory_down_is_fail_closed(self):
        self.assertEqual(evaluate([policy()], identity(directory_available=False)).reason, 'DIRECTORY_UNAVAILABLE')

    def test_disabled_account(self):
        self.assertEqual(evaluate([policy()], identity(account_enabled=False)).reason, 'ACCOUNT_DISABLED')

    def test_domain_constraint_does_not_fall_through(self):
        fallback = policy(id='fallback', constraints={'eap_methods':['EAP-TLS'], 'require_domain_device': False})
        result = evaluate([policy(), fallback], identity(domain_device=False))
        self.assertEqual((result.action, result.policy_id, result.reason), ('deny','corporate','DOMAIN_DEVICE_REQUIRED'))

    def test_eap_constraint_does_not_fall_through(self):
        fallback = policy(id='fallback', constraints={'eap_methods':['PEAP-MSCHAPV2'], 'require_domain_device':False})
        self.assertEqual(evaluate([policy(), fallback], identity(eap_method='PEAP-MSCHAPV2')).reason, 'EAP_CONSTRAINT_FAILED')

    def test_unmatched_condition_continues(self):
        first = policy(conditions={'group_sids':['S-1-5-21-1-2-3-4'], 'access_types':[], 'nas_ips':[]})
        self.assertEqual(evaluate([first,policy(id='next')], identity()).policy_id, 'next')

    def test_disabled_policy_is_ignored(self):
        self.assertEqual(evaluate([policy(enabled=False),policy(id='next')], identity()).policy_id, 'next')

    def test_first_deny_wins(self):
        result = evaluate([policy(action='deny',vlan=None),policy(id='next')], identity())
        self.assertEqual(result.reason, 'POLICY_DENY')

    def test_first_allow_wins(self):
        self.assertEqual(evaluate([policy(),policy(id='deny',action='deny',vlan=None)], identity()).action, 'allow')

    def test_order_changes_decision(self):
        allow,deny=policy(),policy(id='deny',action='deny',vlan=None)
        self.assertNotEqual(evaluate([allow,deny],identity()).action,evaluate([deny,allow],identity()).action)

    def test_group_membership_matches_any_selected_group(self):
        p=policy();p['conditions']['group_sids'].append('S-1-5-21-5-6-7-8')
        self.assertEqual(evaluate([p],identity()).action,'allow')

    def test_nas_condition(self):
        p=policy();p['conditions']['nas_ips']=['192.0.2.3']
        self.assertEqual(evaluate([p],identity()).action,'deny')

    def test_wireless_access(self):
        self.assertEqual(evaluate([policy()],identity(access_type='wireless')).action,'allow')

    def test_vlan_is_string_on_radius_boundary(self):
        attrs=radius_vlan_attributes(evaluate([policy()],identity()))
        self.assertEqual(attrs,{'Tunnel-Type':13,'Tunnel-Medium-Type':6,'Tunnel-Private-Group-ID':'120','Tunnel-Tag':0})

    def test_no_vlan_on_deny(self):
        self.assertEqual(radius_vlan_attributes(evaluate([],identity())),{})

    def test_duplicate_policy_id_rejected(self):
        with self.assertRaises(ValidationError):validate_policies([policy(),policy()])

    def test_invalid_vlan_rejected(self):
        for value in [0,4095,True,'120']:
            with self.subTest(value=value),self.assertRaises(ValidationError):validate_policies([policy(vlan=value)])

    def test_text_name_is_not_group_identity(self):
        p=policy();p['conditions']['group_sids']=['Domain Users']
        with self.assertRaises(ValidationError):validate_policies([p])

    def test_empty_method_list_rejected(self):
        p=policy();p['constraints']['eap_methods']=[]
        with self.assertRaises(ValidationError):validate_policies([p])

    def test_unknown_method_rejected(self):
        p=policy();p['constraints']['eap_methods']=['PAP']
        with self.assertRaises(ValidationError):validate_policies([p])

    def test_nonboolean_enabled_rejected(self):
        with self.assertRaises(ValidationError):validate_policies([policy(enabled='false')])

    def test_duplicate_json_properties_rejected(self):
        with self.assertRaises(ValidationError):strict_json('{"action":"deny","action":"allow"}')

    def test_nonfinite_json_rejected(self):
        with self.assertRaises(ValidationError):strict_json('{"vlan":NaN}')

    def test_config_cannot_store_admin_password(self):
        c=config();c['domain_admin_password']='example-not-a-real-secret'
        with self.assertRaises(ValidationError):validate_config(c)

    def test_client_cannot_store_management_password(self):
        c=config();c['radius_clients'][0]['ssh_password']='example'
        with self.assertRaises(ValidationError):validate_config(c)

    def test_duplicate_radius_ip_rejected(self):
        c=config();c['radius_clients'].append({'name':'Other','ip':'192.0.2.2'})
        with self.assertRaises(ValidationError):validate_config(c)

    def test_valid_config(self):
        self.assertEqual(validate_config(config()),config())

    def test_string_proof_flag_rejected(self):
        with self.assertRaises(ValidationError):identity(authenticated='false')

    def test_dictionary_is_not_verified_context(self):
        with self.assertRaises(ValidationError):evaluate([policy()],{'authenticated':True})
