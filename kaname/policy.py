"""Ordered policy semantics. Inputs must originate from a trusted adapter.

The development HTTP endpoint only simulates these decisions and cannot
issue RADIUS responses. UI-supplied identity claims are never network proof.
"""
from dataclasses import dataclass

from .models import ValidationError, address, boolean, enum, validate_policies
import re


@dataclass(frozen=True)
class VerifiedIdentity:
    authenticated: bool
    directory_available: bool
    account_enabled: bool
    domain_device: bool
    group_sids: frozenset[str]
    access_type: str
    nas_ip: str
    eap_method: str

    def __post_init__(self):
        for value in (self.authenticated, self.directory_available, self.account_enabled, self.domain_device):
            boolean(value)
        if type(self.group_sids) is not frozenset or len(self.group_sids) > 256:
            raise ValidationError('Expected a bounded immutable group set')
        if any(type(x) is not str or len(x) > 184 or not re.fullmatch(r'S-1-[0-9]+(?:-[0-9]+)+', x) for x in self.group_sids):
            raise ValidationError('Invalid verified group SID')
        enum(self.access_type, {'wired', 'wireless'})
        enum(self.eap_method, {'EAP-TLS', 'PEAP-TLS', 'PEAP-MSCHAPV2'})
        object.__setattr__(self, 'nas_ip', address(self.nas_ip))


@dataclass(frozen=True)
class Decision:
    action: str
    reason: str
    policy_id: str | None = None
    vlan: int | None = None


def evaluate(policies, identity):
    policies = validate_policies(policies)
    if not isinstance(identity, VerifiedIdentity):
        raise ValidationError('Verified adapter identity context is required')
    if not identity.authenticated:
        return Decision('deny', 'IDENTITY_NOT_VERIFIED')
    if not identity.directory_available:
        return Decision('deny', 'DIRECTORY_UNAVAILABLE')
    if not identity.account_enabled:
        return Decision('deny', 'ACCOUNT_DISABLED')
    for policy in policies:
        if not policy['enabled']:
            continue
        c = policy['conditions']
        if c['group_sids'] and not identity.group_sids.intersection(c['group_sids']):
            continue
        if c['access_types'] and identity.access_type not in c['access_types']:
            continue
        if c['nas_ips'] and identity.nas_ip not in c['nas_ips']:
            continue
        r = policy['constraints']
        if identity.eap_method not in r['eap_methods']:
            return Decision('deny', 'EAP_CONSTRAINT_FAILED', policy['id'])
        if r['require_domain_device'] and not identity.domain_device:
            return Decision('deny', 'DOMAIN_DEVICE_REQUIRED', policy['id'])
        if policy['action'] == 'deny':
            return Decision('deny', 'POLICY_DENY', policy['id'])
        return Decision('allow', 'POLICY_ALLOW', policy['id'], policy['vlan'])
    return Decision('deny', 'NO_MATCHING_POLICY')


def radius_vlan_attributes(decision):
    """Attribute construction only; no network IO or RADIUS server."""
    if decision.action != 'allow' or decision.vlan is None:
        return {}
    return {'Tunnel-Type': 13, 'Tunnel-Medium-Type': 6,
            'Tunnel-Private-Group-ID': str(decision.vlan), 'Tunnel-Tag': 0}
