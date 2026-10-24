"""Strict non-secret configuration and policy boundary validation."""
import ipaddress
import json
import re


class ValidationError(ValueError):
    pass


def strict_json(data):
    def pairs(items):
        result = {}
        for key, value in items:
            if key in result:
                raise ValidationError("Duplicate JSON property")
            result[key] = value
        return result

    def constant(_):
        raise ValidationError("Non-finite JSON number")

    try:
        return json.loads(data, object_pairs_hook=pairs, parse_constant=constant)
    except (UnicodeError, json.JSONDecodeError, RecursionError) as exc:
        raise ValidationError("Invalid JSON") from exc


def keys(value, allowed, required):
    if type(value) is not dict or set(value) - set(allowed) or set(required) - set(value):
        raise ValidationError("Missing or unsupported properties")


def text(value, maximum=128):
    if type(value) is not str or not value or len(value) > maximum or any(ord(c) < 32 for c in value):
        raise ValidationError("Invalid text value")
    return value


def integer(value, minimum, maximum):
    if type(value) is not int or not minimum <= value <= maximum:
        raise ValidationError("Invalid integer value")
    return value


def boolean(value):
    if type(value) is not bool:
        raise ValidationError("Invalid boolean value")
    return value


def address(value):
    try:
        text(value, 64)
        return str(ipaddress.ip_address(value))
    except ValueError as exc:
        raise ValidationError("Invalid IP address") from exc


def dns_name(value):
    value = text(value, 253).lower()
    if len(value.split('.')) < 2 or any(not re.fullmatch(r'[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?', x) for x in value.split('.')):
        raise ValidationError("A valid fully qualified DNS name is required")
    return value


def array(value, validator, maximum=256):
    if type(value) is not list or len(value) > maximum:
        raise ValidationError("Invalid list")
    result = [validator(x) for x in value]
    if len(set(result)) != len(result):
        raise ValidationError("Duplicate list entries")
    return result


def enum(value, options):
    if type(value) is not str or value not in options:
        raise ValidationError("Unsupported choice")
    return value


def validate_config(value):
    required = {'appliance_fqdn', 'ad_domain', 'dc_ips', 'radius_clients', 'access_modes'}
    keys(value, required, required)
    dc = array(value['dc_ips'], address, 16)
    modes = array(value['access_modes'], lambda x: enum(x, {'wired', 'wireless'}), 2)
    if not dc or not modes:
        raise ValidationError("DC and access mode are required")
    clients = value['radius_clients']
    if type(clients) is not list or len(clients) > 256:
        raise ValidationError("Invalid RADIUS client list")
    result = []
    for client in clients:
        keys(client, {'name', 'ip', 'access_type'}, {'name', 'ip'})
        result.append({'name': text(client['name']), 'ip': address(client['ip']),
                       'access_type': enum(client.get('access_type', 'wired'), {'wired', 'wireless'})})
    if len({x['ip'] for x in result}) != len(result):
        raise ValidationError("Duplicate RADIUS source IP")
    return {'appliance_fqdn': dns_name(value['appliance_fqdn']),
            'ad_domain': dns_name(value['ad_domain']), 'dc_ips': dc,
            'radius_clients': result, 'access_modes': modes}


def validate_policies(value):
    if type(value) is not list or len(value) > 1000:
        raise ValidationError("Invalid policy list")
    result = []
    for policy in value:
        fields = {'id', 'name', 'enabled', 'conditions', 'constraints', 'action', 'vlan'}
        keys(policy, fields, fields)
        pid = text(policy['id'], 64)
        if not re.fullmatch(r'[A-Za-z0-9_.-]+', pid):
            raise ValidationError("Invalid policy identifier")
        conditions = policy['conditions']
        constraints = policy['constraints']
        keys(conditions, {'group_sids', 'access_types', 'nas_ips', 'identity_types'}, {'group_sids', 'access_types', 'nas_ips'})
        keys(constraints, {'eap_methods', 'require_domain_device'}, {'eap_methods', 'require_domain_device'})
        methods = array(constraints['eap_methods'], lambda x: enum(x, {'EAP-TLS', 'PEAP-TLS', 'PEAP-MSCHAPV2'}), 3)
        if not methods:
            raise ValidationError("At least one EAP method is required")
        groups = array(conditions['group_sids'], lambda x: text(x, 184))
        if any(not re.fullmatch(r'S-1-[0-9]+(?:-[0-9]+)+', x) for x in groups):
            raise ValidationError("Expected immutable AD principal SID")
        identity_types = None
        if 'identity_types' in conditions:
            identity_types = array(conditions['identity_types'], lambda x: enum(x, {'user', 'computer'}), 2)
            if not identity_types or ('user' in identity_types and constraints['require_domain_device']):
                raise ValidationError('POLICY_IDENTITY_SCOPE_INVALID')
        action = enum(policy['action'], {'allow', 'deny'})
        vlan = policy['vlan']
        if action == 'allow':
            if vlan is not None:
                integer(vlan, 1, 4094)
        elif vlan is not None:
            raise ValidationError("Deny cannot assign a VLAN")
        result.append({'id': pid, 'name': text(policy['name']), 'enabled': boolean(policy['enabled']),
                       'conditions': {'group_sids': groups,
                                      'access_types': array(conditions['access_types'], lambda x: enum(x, {'wired', 'wireless'}), 2),
                                      'nas_ips': array(conditions['nas_ips'], address)},
                       'constraints': {'eap_methods': methods, 'require_domain_device': boolean(constraints['require_domain_device'])},
                       'action': action, 'vlan': vlan})
        if identity_types is not None:
            result[-1]['conditions']['identity_types'] = identity_types
    if len({x['id'] for x in result}) != len(result):
        raise ValidationError("Duplicate policy identifier")
    return result
