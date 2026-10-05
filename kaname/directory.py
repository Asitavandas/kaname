"""Read-only directory import. Catalog data is never EAP identity proof."""
import ipaddress
import json
import os
import re
import socket
import subprocess
import uuid
from pathlib import Path

from .models import ValidationError, boolean, dns_name, integer, keys, text

TRANSPORT = 'kerberos-sign-seal'
ERRORS = {'AD_BIND_FAILED', 'AD_CREDENTIALS_REJECTED', 'AD_DOMAIN_MISMATCH',
          'AD_DIRECTORY_LIMIT', 'AD_SEARCH_FAILED', 'AD_PROTOCOL_UNAVAILABLE',
          'AD_PROTECTION_REQUIRED', 'AD_INPUT_INVALID', 'AD_TIMEOUT', 'AD_INVALID_RESPONSE',
          'AD_SCOPE_NOT_FOUND', 'AD_SCOPE_AMBIGUOUS', 'AD_SCOPE_INVALID', 'AD_CONNECT_FAILED'}
STAGES = {'input', 'bind', 'rootdse', 'serialize', 'groups_members', 'memberships'} | {kind + '_' + step for kind in ('users', 'groups', 'computers', 'ous', 'scopes') for step in ('prepare', 'search', 'decode', 'page')}
REASONS = {'UNKNOWN', 'LDAP_RESULT', 'ACCESS_DENIED', 'LDAP_CONNECTION', 'VALUE_CONVERSION', 'ATTRIBUTE_MISSING', 'BINARY_ATTRIBUTE_INVALID', 'PROPERTY_ACCESS', 'METHOD_BINDING', 'REFERRAL_RETURNED', 'MEMBERSHIP_RANGE_INVALID'}


class DirectoryError(Exception):
    def __init__(self, code, stage=None, reason=None):
        self.code = code
        self.diagnostic = {'stage': stage, 'reason': reason} if type(stage) is str and type(reason) is str and stage in STAGES and reason in REASONS else None
        super().__init__(code)


def validate_search_base(value, domain):
    """A bounded OU/CN/DC DN in this domain, never a raw LDAP filter."""
    if type(value) is not str or len(value) > 2048 or any(ord(c) < 32 for c in value):
        raise ValidationError('AD_SCOPE_INVALID')
    value = value.strip()
    if not value:
        return ''
    # Accept escaped DN separators and UTF-8 names, but no multivalued RDNs.
    parts = re.split(r'(?<!\\),', value)
    normalized = []
    for part in parts:
        match = re.fullmatch(r'\s*(OU|CN|DC)\s*=\s*((?:\\(?:[0-9A-Fa-f]{2}|[,=+<>#;"\\ ])|[^,\\+<>;"=])+?)\s*', part, re.I)
        if not match:
            raise ValidationError('AD_SCOPE_INVALID')
        normalized.append(match[1].upper() + '=' + match[2])
    dc = ['DC=' + x for x in domain.split('.')]
    if len(normalized) < len(dc) or [x.casefold() for x in normalized[-len(dc):]] != [x.casefold() for x in dc] or any(x.startswith('DC=') for x in normalized[:-len(dc)]):
        raise ValidationError('AD_SCOPE_INVALID')
    return ','.join(normalized)


def validate_connection(value, config):
    keys(value, {'dc_fqdn', 'username', 'password', 'search_base'}, {'dc_fqdn', 'username', 'password'})
    host = dns_name(value['dc_fqdn'])
    domain = config['ad_domain']
    if not host.endswith('.' + domain):
        raise ValidationError('DC must belong to the configured domain')
    username = text(value['username'], 256)
    if username.count('@') != 1 or username.rsplit('@', 1)[1].lower() != domain:
        raise ValidationError('Use a UPN in the configured domain')
    password = value['password']
    if type(password) is not str or not 1 <= len(password) <= 1024 or '\0' in password:
        raise ValidationError('Invalid credential')
    return {'dc_fqdn': host, 'domain': domain, 'username': username, 'password': password,
            'search_base': validate_search_scopes(value.get('search_base', ''), domain)}


def validate_search_scopes(value, domain):
    """One DN or OU name per line; never silently discard an invalid scope."""
    if type(value) is not str or len(value) > 32768 or any(ord(c) < 32 and c not in '\r\n' for c in value):
        raise ValidationError('AD_SCOPE_INVALID')
    lines = value.splitlines()
    if len(lines) > 16 or any(not line.strip() for line in lines) and value.strip():
        raise ValidationError('AD_SCOPE_INVALID')
    normalized, seen = [], set()
    for line in lines:
        line = line.strip()
        if not line:
            continue
        if '=' in line:
            if not re.search(r'(?:^|,)\s*DC\s*=', line, re.I):
                line += ',' + ','.join('DC=' + x for x in domain.split('.'))
            line = validate_search_base(line, domain)
        elif len(line) > 256 or any(c in line for c in ',\\+<>;"()*'):
            raise ValidationError('AD_SCOPE_INVALID')
        folded = line.casefold()
        if folded not in seen:
            normalized.append(line); seen.add(folded)
    return '\n'.join(normalized)


def dn_within(dn, base):
    """Compare complete RDN boundaries, including escaped commas/backslashes."""
    def parts(value):
        result, current, escaped = [], [], False
        for char in value:
            if char == ',' and not escaped:
                result.append(''.join(current).strip().casefold()); current = []
            else:
                current.append(char)
            escaped = char == '\\' and not escaped
        result.append(''.join(current).strip().casefold())
        return result
    actual, expected = parts(dn), parts(base)
    return len(actual) >= len(expected) and actual[-len(expected):] == expected


def check_directory_connectivity(value, config):
    """Bounded TCP probe to configured DC IPs only; no password or LDAP bind."""
    keys(value, {'dc_fqdn'}, {'dc_fqdn'})
    host = dns_name(value['dc_fqdn'])
    if not host.endswith('.' + config['ad_domain']):
        raise ValidationError('AD_DOMAIN_MISMATCH')
    try:
        addresses = {str(ipaddress.ip_address(r[4][0])) for r in socket.getaddrinfo(host, 389, type=socket.SOCK_STREAM)}
    except (OSError, ValueError):
        raise DirectoryError('AD_DNS_FAILED') from None
    if not addresses or len(addresses) > 4 or not addresses <= {str(ipaddress.ip_address(x)) for x in config['dc_ips']}:
        raise DirectoryError('AD_DC_IP_MISMATCH')
    for address in sorted(addresses):
        try:
            with socket.create_connection((address, 389), timeout=2):
                return {'connected': True, 'port': 389, 'authenticated': False}
        except OSError:
            continue
    raise DirectoryError('AD_CONNECT_FAILED')


def validate_catalog(value, domain=None, dc_fqdn=None):
    fields = {'domain', 'dc_fqdn', 'transport', 'users', 'groups', 'computers'}
    keys(value, fields | {'membership_schema', 'memberships'}, fields)
    membership_available = 'membership_schema' in value or 'memberships' in value
    if membership_available and (type(value.get('membership_schema')) is not int or value['membership_schema'] != 1 or type(value.get('memberships')) is not list):
        raise ValidationError('Invalid membership schema')
    if value['transport'] != TRANSPORT:
        raise ValidationError('Protected directory connection required')
    result = {'domain': dns_name(value['domain']), 'dc_fqdn': dns_name(value['dc_fqdn']), 'transport': TRANSPORT}
    if not result['dc_fqdn'].endswith('.' + result['domain']):
        raise ValidationError('Invalid DC domain')
    if domain is not None and result['domain'] != domain:
        raise ValidationError('Directory domain mismatch')
    if dc_fqdn is not None and result['dc_fqdn'] != dc_fqdn:
        raise ValidationError('Directory controller mismatch')
    guids, sids = set(), set()
    for kind in ('users', 'groups', 'computers'):
        objects = value[kind]
        if type(objects) is not list or len(objects) > 10000:
            raise ValidationError('Directory size limit')
        result[kind] = []
        for obj in objects:
            required = {'guid', 'sid', 'sam', 'name'} | ({'enabled'} if kind != 'groups' else set())
            extra = {'security_enabled', 'unresolved_members'} if kind == 'groups' else {'primary_group_unresolved'}
            keys(obj, required | extra, required | (extra if membership_available else set()))
            guid = str(uuid.UUID(text(obj['guid'], 36)))
            sid = text(obj['sid'], 184)
            pattern = r'S-1-5-21-[0-9]+-[0-9]+-[0-9]+-[0-9]+'
            if kind == 'groups':
                pattern = r'(?:' + pattern + r'|S-1-5-32-[0-9]+)'
            if not re.fullmatch(pattern, sid):
                raise ValidationError('Expected domain object SID')
            if guid in guids or sid in sids:
                raise ValidationError('Duplicate directory object identity')
            guids.add(guid); sids.add(sid)
            record = {'guid': guid, 'sid': sid, 'sam': text(obj['sam'], 256), 'name': text(obj['name'], 256)}
            if kind != 'groups':
                record['enabled'] = boolean(obj['enabled'])
                if 'primary_group_unresolved' in obj: record['primary_group_unresolved'] = boolean(obj['primary_group_unresolved'])
            else:
                if 'security_enabled' in obj: record['security_enabled'] = boolean(obj['security_enabled'])
                if 'unresolved_members' in obj: record['unresolved_members'] = integer(obj['unresolved_members'], 0, 10000)
            result[kind].append(record)
    if membership_available:
        if len(value['memberships']) > 100000: raise ValidationError('Membership size limit')
        groups = {x['sid']: x for x in result['groups']}
        accounts = {x['sid'] for kind in ('users', 'computers') for x in result[kind]}
        seen, primary = set(), set()
        edges = []
        for edge in value['memberships']:
            keys(edge, {'member_sid', 'group_sid', 'type'}, {'member_sid', 'group_sid', 'type'})
            member, group = text(edge['member_sid'], 184), text(edge['group_sid'], 184)
            if member not in sids or group not in groups or member == group or type(edge['type']) is not str or edge['type'] not in {'direct', 'primary'}:
                raise ValidationError('Invalid membership reference')
            key = (member, group, edge['type'])
            if key in seen: raise ValidationError('Duplicate membership')
            seen.add(key)
            if edge['type'] == 'primary':
                if member not in accounts or member in primary or member.rsplit('-', 1)[0] != group.rsplit('-', 1)[0] or not groups[group]['security_enabled']:
                    raise ValidationError('Invalid primary group')
                primary.add(member)
            edges.append({'member_sid': member, 'group_sid': group, 'type': edge['type']})
        for kind in ('users', 'computers'):
            for account in result[kind]:
                if account['primary_group_unresolved'] == (account['sid'] in primary):
                    raise ValidationError('Missing or contradictory primary group')
        result.update(membership_schema=1, memberships=edges)
    return result


def read_windows_directory(value, config, *, probe=False):
    request = validate_connection(value, config)
    request['probe'] = probe
    if os.name != 'nt':
        raise DirectoryError('AD_PLATFORM_UNSUPPORTED')
    try:
        addresses = {str(ipaddress.ip_address(r[4][0])) for r in socket.getaddrinfo(request['dc_fqdn'], 389, type=socket.SOCK_STREAM)}
    except (OSError, ValueError):
        raise DirectoryError('AD_DNS_FAILED') from None
    allowed = {str(ipaddress.ip_address(x)) for x in config['dc_ips']}
    if not addresses or not addresses <= allowed:
        raise DirectoryError('AD_DC_IP_MISMATCH')
    # Fixed executable and script; no credentials in argv, environment or files.
    executable = Path(os.environ.get('SystemRoot', 'C:\\Windows')) / 'System32' / 'WindowsPowerShell' / 'v1.0' / 'powershell.exe'
    script = Path(__file__).with_name('directory_windows.ps1')
    try:
        completed = subprocess.run([str(executable), '-NoLogo', '-NoProfile', '-NonInteractive',
                                    '-ExecutionPolicy', 'Bypass', '-File', str(script)],
                                   input=json.dumps(request, ensure_ascii=True).encode('utf-8'),
                                   capture_output=True, timeout=60, check=False,
                                   creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0))
    except subprocess.TimeoutExpired:
        raise DirectoryError('AD_TIMEOUT') from None
    except OSError:
        raise DirectoryError('AD_PROTOCOL_UNAVAILABLE') from None
    finally:
        request['password'] = ''
    if probe:
        try:
            result = json.loads(completed.stdout.decode('utf-8-sig'))
            if completed.returncode == 0 and result == {'probe': 'ok', 'domain': request['domain'], 'dc_fqdn': request['dc_fqdn']}:
                return result
        except (ValueError, UnicodeError):
            pass
    return decode_helper_response(completed.stdout, completed.returncode, config['ad_domain'], value['dc_fqdn'].lower())


def check_windows_directory(value, config):
    return read_windows_directory(value, config, probe=True)


def decode_helper_response(stdout, returncode, domain, dc_fqdn):
    try:
        if len(stdout) > 24_000_000:
            raise DirectoryError('AD_DIRECTORY_LIMIT')
        result = json.loads(stdout.decode('utf-8-sig'))
        if type(result) is not dict:
            raise ValueError()
        if 'error' in result:
            code = result['error'] if result['error'] in ERRORS else 'AD_SEARCH_FAILED'
            raise DirectoryError(code, result.get('stage'), result.get('reason'))
        if returncode != 0:
            raise DirectoryError('AD_SEARCH_FAILED')
        return validate_catalog(result, domain, dc_fqdn)
    except (ValueError, TypeError, KeyError, UnicodeError):
        # Never surface subprocess stderr, exceptions or server diagnostic text.
        raise DirectoryError('AD_INVALID_RESPONSE') from None
