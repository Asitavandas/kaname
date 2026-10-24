"""Ordered policy semantics. Inputs must originate from a trusted adapter.

The development HTTP endpoint only simulates these decisions and cannot
issue RADIUS responses. UI-supplied identity claims are never network proof.
"""
from dataclasses import dataclass

from .models import ValidationError, address, boolean, enum, validate_policies
import re
import uuid


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
    account_sid: str = ''

    def __post_init__(self):
        for value in (self.authenticated, self.directory_available, self.account_enabled, self.domain_device):
            boolean(value)
        if type(self.group_sids) is not frozenset or len(self.group_sids) > 256:
            raise ValidationError('Expected a bounded immutable group set')
        if any(type(x) is not str or len(x) > 184 or not re.fullmatch(r'S-1-[0-9]+(?:-[0-9]+)+', x) for x in self.group_sids):
            raise ValidationError('Invalid verified group SID')
        if type(self.account_sid) is not str or (self.account_sid and (len(self.account_sid) > 184 or not re.fullmatch(r'S-1-[0-9]+(?:-[0-9]+)+', self.account_sid))):
            raise ValidationError('Invalid verified account SID')
        enum(self.access_type, {'wired', 'wireless'})
        enum(self.eap_method, {'EAP-TLS', 'PEAP-TLS', 'PEAP-MSCHAPV2'})
        object.__setattr__(self, 'nas_ip', address(self.nas_ip))


@dataclass(frozen=True)
class Decision:
    action: str
    reason: str
    policy_id: str | None = None
    vlan: int | None = None


class PolicyConflictError(ValueError):
    def __init__(self, conflicts):
        self.conflicts = conflicts
        super().__init__('POLICY_CONFLICT')


def policy_conflicts(policies, catalog=None, local_groups=None):
    """Detect shared conditions and observed cross-group membership overlaps.

    Separate AD groups may coexist in future. Runtime evaluation remains
    order-independent and denies conflicting decisions even after AD changes.
    """
    policies = validate_policies(policies)
    members = {}
    if catalog and catalog.get('membership_schema') == 1:
        from collections import defaultdict
        children = defaultdict(set)
        for edge in catalog['memberships']:
            children[edge['group_sid']].add(edge['member_sid'])
        accounts = {a['sid'] for kind in ('users', 'computers') for a in catalog[kind]}
        for group in {g for p in policies for g in p['conditions']['group_sids']}:
            seen, queue = set(), [group]
            while queue:
                node = queue.pop()
                if node in seen: continue
                seen.add(node); queue.extend(children[node] - seen)
            members[group] = seen.intersection(accounts)
    if catalog:
        for plural in ('users', 'computers'):
            for account in catalog[plural]:
                members[account['sid']] = {account['sid']}
    member_sets = {}
    for policy in policies:
        key = policy['id']
        direct = policy['conditions']['group_sids']
        local = policy['conditions'].get('local_group_ids', [])
        member_sets[key] = set().union(*(members.get(g, set()) for g in direct), *((local_groups or {}).get(g,set()) for g in local))
    conflicts = []
    active = [p for p in policies if p['enabled']]
    for index, left in enumerate(active):
        for right in active[index + 1:]:
            lc, rc = left['conditions'], right['conditions']
            if any(lc[k] and rc[k] and not set(lc[k]).intersection(rc[k]) for k in ('access_types', 'nas_ips')):
                continue
            lg, rg = set(lc['group_sids']), set(rc['group_sids'])
            ll, rl = set(lc.get('local_group_ids', [])), set(rc.get('local_group_ids', []))
            if (lg or ll) and (rg or rl) and not lg.intersection(rg) and not ll.intersection(rl) and not member_sets[left['id']].intersection(member_sets[right['id']]):
                continue
            # Constraint mismatches can create allow/deny conflicts too.
            same = (left['action'], left['vlan'], set(left['constraints']['eap_methods']), left['constraints']['require_domain_device']) == (right['action'], right['vlan'], set(right['constraints']['eap_methods']), right['constraints']['require_domain_device'])
            if not same:
                conflicts.append({'policy_ids': [left['id'], right['id']], 'policy_names': [left['name'], right['name']],
                                  'reason': 'OVERLAPPING_DECISIONS'})
                if len(conflicts) >= 50:
                    return conflicts
    return conflicts


def evaluate(policies, identity, *, local_group_ids=frozenset()):
    policies = validate_policies(policies)
    if type(local_group_ids) is not frozenset or len(local_group_ids)>1 or any(type(x) is not str or str(uuid.UUID(x))!=x or uuid.UUID(x).int==0 for x in local_group_ids):
        raise ValidationError('Invalid verified local group set')
    if not isinstance(identity, VerifiedIdentity):
        raise ValidationError('Verified adapter identity context is required')
    if not identity.authenticated:
        return Decision('deny', 'IDENTITY_NOT_VERIFIED')
    if not identity.directory_available:
        return Decision('deny', 'DIRECTORY_UNAVAILABLE')
    if not identity.account_enabled:
        return Decision('deny', 'ACCOUNT_DISABLED')
    decisions = []
    for policy in sorted(policies, key=lambda x: x['id']):
        if not policy['enabled']:
            continue
        c = policy['conditions']
        local = c.get('local_group_ids', [])
        if (c['group_sids'] or local) and not (identity.group_sids.intersection(c['group_sids']) or identity.account_sid in c['group_sids'] or local_group_ids.intersection(local)):
            continue
        if c['access_types'] and identity.access_type not in c['access_types']:
            continue
        if c['nas_ips'] and identity.nas_ip not in c['nas_ips']:
            continue
        r = policy['constraints']
        if identity.eap_method not in r['eap_methods']:
            decisions.append(Decision('deny', 'EAP_CONSTRAINT_FAILED', policy['id']))
        elif r['require_domain_device'] and not identity.domain_device:
            decisions.append(Decision('deny', 'DOMAIN_DEVICE_REQUIRED', policy['id']))
        elif policy['action'] == 'deny':
            decisions.append(Decision('deny', 'POLICY_DENY', policy['id']))
        else:
            decisions.append(Decision('allow', 'POLICY_ALLOW', policy['id'], policy['vlan']))
    if not decisions:
        return Decision('deny', 'NO_MATCHING_POLICY')
    if len({(d.action, d.vlan) for d in decisions}) > 1:
        return Decision('deny', 'POLICY_CONFLICT')
    return decisions[0]


def radius_vlan_attributes(decision):
    """Attribute construction only; no network IO or RADIUS server."""
    if decision.action != 'allow' or decision.vlan is None:
        return {}
    return {'Tunnel-Type': 13, 'Tunnel-Medium-Type': 6,
            'Tunnel-Private-Group-ID': str(decision.vlan), 'Tunnel-Tag': 0}
