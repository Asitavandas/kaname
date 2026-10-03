"""Internal EAP-TLS authorization boundary, called after native TLS validation.

This is not a RADIUS packet server or enrollment API. The adapter must be
invoked only by FreeRADIUS's certificate-check virtual server, with a pinned
issuer and server-owned NAS configuration. Neither HTTP simulation input nor
the display catalog is a source of authentication or current AD rights.
"""
from dataclasses import dataclass
import re
import uuid

from .models import ValidationError, address, dns_name, enum, text, validate_policies
from .policy import Decision, VerifiedIdentity, evaluate, radius_vlan_attributes


def serial_number(value):
    if type(value) is not str or not re.fullmatch(r'[0-9a-fA-F]{1,40}', value):
        raise ValidationError('Invalid certificate serial')
    number = int(value, 16)
    if not 0 < number < 2 ** 159:
        raise ValidationError('Invalid certificate serial')
    return format(number, 'x')


def object_id(value):
    if type(value) is not str:
        raise ValidationError('Invalid AD object identity')
    try:
        canonical = str(uuid.UUID(value))
    except ValueError as exc:
        raise ValidationError('Invalid AD object identity') from exc
    if value != canonical or canonical == str(uuid.UUID(int=0)):
        raise ValidationError('Invalid AD object identity')
    return canonical


def account_sid(value):
    text(value, 184)
    if not re.fullmatch(r'S-1-5-21-[0-9]+-[0-9]+-[0-9]+-[0-9]+', value):
        raise ValidationError('An AD account SID is required')
    if any(int(part) > 2 ** 32 - 1 for part in value.split('-')[4:]):
        raise ValidationError('Invalid AD account SID')
    return value


@dataclass(frozen=True)
class CertificateReference:
    issuer_sha256: str
    serial: str

    def __post_init__(self):
        if type(self.issuer_sha256) is not str or not re.fullmatch(r'[0-9a-f]{64}', self.issuer_sha256):
            raise ValidationError('A pinned issuer fingerprint is required')
        object.__setattr__(self, 'serial', serial_number(self.serial))


@dataclass(frozen=True)
class CertificateBinding:
    certificate: CertificateReference
    domain: str
    object_guid: str
    sid: str
    kind: str
    active: bool = True

    def __post_init__(self):
        if type(self.certificate) is not CertificateReference or type(self.active) is not bool:
            raise ValidationError('Invalid certificate binding')
        if self.domain != dns_name(self.domain):
            raise ValidationError('Canonical AD domain is required')
        object_id(self.object_guid)
        account_sid(self.sid)
        enum(self.kind, {'user', 'computer'})


@dataclass(frozen=True)
class CurrentDirectoryAccount:
    """A live provider result; security groups must reflect AD access semantics.

    A provider must implement a bounded live lookup and raise
    DirectoryUnavailable on timeout/incomplete membership. The UI's structural
    membership graph (which includes distribution groups) cannot provide this.
    """
    domain: str
    object_guid: str
    sid: str
    kind: str
    enabled: bool
    security_group_sids: frozenset[str]

    def __post_init__(self):
        if self.domain != dns_name(self.domain) or type(self.enabled) is not bool:
            raise ValidationError('Invalid current AD account')
        object_id(self.object_guid)
        account_sid(self.sid)
        enum(self.kind, {'user', 'computer'})
        # Reuse the engine's strict group bounds; never silently truncate.
        VerifiedIdentity(True, True, self.enabled, self.kind == 'computer',
                         self.security_group_sids, 'wired', '127.0.0.1', 'EAP-TLS')


class DirectoryUnavailable(RuntimeError):
    pass


class TLSAuthorization:
    """Registry.lookup(cert) + Directory.lookup(domain, guid), deny by default.

    Missing directory objects are returned as None. A binding must come from
    authenticated enrollment, never a user-selected name/UPN or outer EAP
    identity. No production provider/registry is enabled in this milestone.
    """
    def __init__(self, policies, *, registry=None, directory=None):
        self.policies = validate_policies(policies)
        self.registry = registry
        self.directory = directory

    def authorize(self, certificate, *, nas_ip, access_type):
        # These arguments originate in the configured native TLS adapter.
        try:
            if type(certificate) is not CertificateReference:
                return Decision('deny', 'IDENTITY_NOT_VERIFIED')
            nas_ip = address(nas_ip)
            enum(access_type, {'wired', 'wireless'})
            if self.registry is None:
                return Decision('deny', 'CERTIFICATE_UNBOUND')
            binding = self.registry.lookup(certificate)
            if type(binding) is not CertificateBinding or binding.certificate != certificate:
                return Decision('deny', 'CERTIFICATE_UNBOUND')
            if not binding.active:
                return Decision('deny', 'CERTIFICATE_INACTIVE')
            if self.directory is None:
                return Decision('deny', 'DIRECTORY_UNAVAILABLE')
            account = self.directory.lookup(binding.domain, binding.object_guid)
            if account is None:
                return Decision('deny', 'ACCOUNT_NOT_FOUND')
            if type(account) is not CurrentDirectoryAccount:
                return Decision('deny', 'DIRECTORY_RESULT_INVALID')
            if (account.domain, account.object_guid, account.sid, account.kind) != (
                    binding.domain, binding.object_guid, binding.sid, binding.kind):
                return Decision('deny', 'ACCOUNT_BINDING_MISMATCH')
            identity = VerifiedIdentity(True, True, account.enabled, account.kind == 'computer',
                                        account.security_group_sids, access_type, nas_ip, 'EAP-TLS')
            return evaluate(self.policies, identity)
        except DirectoryUnavailable:
            return Decision('deny', 'DIRECTORY_UNAVAILABLE')
        except (ValidationError, ValueError, TypeError, AttributeError, OSError):
            return Decision('deny', 'AUTHORIZATION_INPUT_INVALID')


def freeradius_result(decision):
    """Only decision-derived native reply/config pairs; reject has no VLAN.

    The callback also returns the native rlm_python3 result code. Auth-Type is
    set only inside check-eap-tls, not in the outer EAP authorize section.
    """
    if (type(decision) is not Decision or decision.action != 'allow'
            or decision.reason != 'POLICY_ALLOW' or type(decision.policy_id) is not str
            or not re.fullmatch(r'[A-Za-z0-9_.-]{1,64}', decision.policy_id)
            or (decision.vlan is not None and (type(decision.vlan) is not int
                                               or not 1 <= decision.vlan <= 4094))):
        return (), (('Auth-Type', ':=', 'Reject'),)
    attrs = radius_vlan_attributes(decision)
    reply = tuple((key + ':0', ':=', str(attrs[key])) for key in (
        'Tunnel-Type', 'Tunnel-Medium-Type', 'Tunnel-Private-Group-ID') if key in attrs)
    return reply, (('Auth-Type', ':=', 'Accept'),)
