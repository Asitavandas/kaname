from kaname.policy import VerifiedIdentity


def policy(**changes):
    value = {'id': 'corporate', 'name': 'Corporate', 'enabled': True,
             'conditions': {'group_sids': ['S-1-5-21-10-20-30-40'], 'access_types': ['wired', 'wireless'], 'nas_ips': []},
             'constraints': {'eap_methods': ['EAP-TLS'], 'require_domain_device': True},
             'action': 'allow', 'vlan': 120}
    value.update(changes)
    return value


def identity(**changes):
    value = dict(authenticated=True, directory_available=True, account_enabled=True,
                 domain_device=True, group_sids=frozenset({'S-1-5-21-10-20-30-40'}),
                 access_type='wired', nas_ip='192.0.2.2', eap_method='EAP-TLS')
    value.update(changes)
    return VerifiedIdentity(**value)


def config():
    return {'appliance_fqdn': 'kaname.lab.example', 'ad_domain': 'lab.example',
            'dc_ips': ['192.0.2.10'], 'radius_clients': [{'name': 'SW1', 'ip': '192.0.2.2', 'access_type': 'wired'}],
            'access_modes': ['wired', 'wireless']}
