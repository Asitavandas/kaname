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
          'AD_PROTECTION_REQUIRED', 'AD_INPUT_INVALID'}
STAGES = {'input', 'bind', 'rootdse', 'serialize'} | {kind + '_' + step for kind in ('users', 'groups', 'computers') for step in ('search', 'decode', 'page')}
REASONS = {'UNKNOWN', 'LDAP_RESULT', 'ACCESS_DENIED', 'LDAP_CONNECTION', 'VALUE_CONVERSION', 'ATTRIBUTE_MISSING', 'BINARY_ATTRIBUTE_INVALID'}


class DirectoryError(Exception):
    def __init__(self, code, stage=None, reason=None):
        self.code = code
        self.diagnostic = {'stage': stage, 'reason': reason} if type(stage) is str and type(reason) is str and stage in STAGES and reason in REASONS else None
        super().__init__(code)


def validate_connection(value, config):
    keys(value, {'dc_fqdn', 'username', 'password'}, {'dc_fqdn', 'username', 'password'})
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
    return {'dc_fqdn': host, 'domain': domain, 'username': username, 'password': password}


def validate_catalog(value, domain=None, dc_fqdn=None):
    fields = {'domain', 'dc_fqdn', 'transport', 'users', 'groups', 'computers'}
    keys(value, fields, fields)
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
            keys(obj, required, required)
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
            result[kind].append(record)
    return result


def read_windows_directory(value, config):
    request = validate_connection(value, config)
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
    return decode_helper_response(completed.stdout, completed.returncode, config['ad_domain'], value['dc_fqdn'].lower())


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
