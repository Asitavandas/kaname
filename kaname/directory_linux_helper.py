"""Bounded subprocess with private Kerberos cache and mandatory SASL sealing."""
import json
import os
import re
import subprocess
import sys
import time
import uuid
from dataclasses import asdict
from datetime import datetime, timezone
from pathlib import Path

from .directory import DirectoryError, TRANSPORT, validate_catalog, validate_search_scopes, dn_within
from .radius import CurrentDirectoryAccount, account_sid, object_id

DOMAIN_SCOPE = '1.2.840.113556.1.4.1339'
PAGED = '1.2.840.113556.1.4.319'
FILTERS = {'users': '(&(objectCategory=person)(objectClass=user))',
           'groups': '(objectCategory=group)', 'computers': '(objectCategory=computer)'}
ATTRIBUTES = ['objectGUID', 'objectSid', 'sAMAccountName', 'displayName', 'name',
              'userAccountControl', 'primaryGroupID', 'groupType', 'member']


def attribute(attributes, name, optional=False):
    values = attributes.get(name.lower(), [])
    if optional and not values:
        return ''
    if len(values) != 1 or type(values[0]) is not bytes:
        raise DirectoryError('AD_SEARCH_FAILED')
    return values[0].decode('utf-8', errors='strict')


def sid_from_bytes(value):
    if type(value) is not bytes or not 8 <= len(value) <= 68 or value[0] != 1 or value[1] > 15 or len(value) != 8 + 4 * value[1]:
        raise DirectoryError('AD_INVALID_RESPONSE')
    authority = int.from_bytes(value[2:8], 'big')
    parts = [int.from_bytes(value[i:i + 4], 'little') for i in range(8, len(value), 4)]
    return 'S-1-' + str(authority) + ''.join('-' + str(x) for x in parts)


class Reader:
    def __init__(self, connection, ldap_module, controls):
        self.connection, self.ldap, self.controls = connection, ldap_module, controls
        self.deadline = time.monotonic() + 45
        self.member_count = 0

    def remaining(self):
        value = self.deadline - time.monotonic()
        if value <= 0:
            raise DirectoryError('AD_TIMEOUT')
        return min(10, value)

    def search(self, base, scope, filter_value, attributes, cookie=None):
        domain_control, page_control = self.controls
        controls = [domain_control(DOMAIN_SCOPE, criticality=True)]
        if cookie is not None:
            controls.append(page_control(criticality=True, size=250, cookie=cookie))
        msgid = self.connection.search_ext(base, scope, filter_value, attributes,
                                           serverctrls=controls, timeout=10)
        kind, rows, response_id, response_controls = self.connection.result3(msgid, all=1, timeout=self.remaining())
        if kind != self.ldap.RES_SEARCH_RESULT or response_id != msgid:
            raise DirectoryError('AD_SEARCH_FAILED')
        normalized = []
        for dn, attrs in rows:
            if type(dn) is not str or not dn or type(attrs) is not dict:
                raise DirectoryError('AD_SEARCH_FAILED', 'users_search', 'REFERRAL_RETURNED')
            folded = {key.lower(): value for key, value in attrs.items()}
            if len(folded) != len(attrs):
                raise DirectoryError('AD_INVALID_RESPONSE')
            normalized.append((dn, folded))
        return normalized, response_controls

    def raw_objects(self, base, filter_value, scope=None):
        cookie, seen_cookies, seen_dns, count = b'', set(), set(), 0
        while True:
            rows, controls = self.search(base, self.ldap.SCOPE_SUBTREE if scope is None else scope,
                                         filter_value, ATTRIBUTES, cookie)
            for dn, attrs in rows:
                key = dn.casefold()
                if key in seen_dns:
                    raise DirectoryError('AD_INVALID_RESPONSE')
                seen_dns.add(key); count += 1
                if count > 10000:
                    raise DirectoryError('AD_DIRECTORY_LIMIT')
                yield dn, attrs
            pages = [x for x in controls if x.controlType == PAGED]
            if len(pages) != 1 or type(pages[0].cookie) is not bytes:
                raise DirectoryError('AD_SEARCH_FAILED')
            cookie = pages[0].cookie
            if not cookie:
                break
            if cookie in seen_cookies or len(cookie) > 4096:
                raise DirectoryError('AD_SEARCH_FAILED')
            seen_cookies.add(cookie)

    def members(self, dn, attrs):
        start, result, seen = 0, [], set()
        while True:
            ranged = [x for x in attrs if x.startswith('member;range=')]
            complete = True
            if len(ranged) > 1 or (ranged and attrs.get('member')):
                raise DirectoryError('AD_SEARCH_FAILED', 'groups_members', 'MEMBERSHIP_RANGE_INVALID')
            if ranged:
                match = re.fullmatch(r'member;range=(\d+)-(\d+|\*)', ranged[0])
                if not match or int(match[1]) != start:
                    raise DirectoryError('AD_SEARCH_FAILED', 'groups_members', 'MEMBERSHIP_RANGE_INVALID')
                values = attrs[ranged[0]]
                complete = match[2] == '*'
                end = start if complete else int(match[2])
                if not complete and (end < start or len(values) != end - start + 1):
                    raise DirectoryError('AD_SEARCH_FAILED', 'groups_members', 'MEMBERSHIP_RANGE_INVALID')
            elif start:
                raise DirectoryError('AD_SEARCH_FAILED', 'groups_members', 'MEMBERSHIP_RANGE_INVALID')
            else:
                values = attrs.get('member', [])
            for value in values:
                value = value.decode('utf-8', errors='strict')
                if not value or len(value) > 4096 or value.casefold() in seen:
                    raise DirectoryError('AD_SEARCH_FAILED', 'groups_members', 'MEMBERSHIP_RANGE_INVALID')
                seen.add(value.casefold()); result.append(value); self.member_count += 1
                if len(result) > 10000 or self.member_count > 100000:
                    raise DirectoryError('AD_DIRECTORY_LIMIT')
            if complete:
                return result
            start = end + 1
            rows, _ = self.search(dn, self.ldap.SCOPE_BASE, FILTERS['groups'], [f'member;range={start}-{start + 999}'])
            if len(rows) != 1 or rows[0][0].casefold() != dn.casefold():
                raise DirectoryError('AD_SEARCH_FAILED')
            attrs = rows[0][1]

    def objects(self, kind, base, filter_value=None, scope=None):
        result = []
        for dn, attrs in self.raw_objects(base, filter_value or FILTERS[kind], scope):
            guid_values, sid_values = attrs.get('objectguid', []), attrs.get('objectsid', [])
            if len(guid_values) != 1 or len(sid_values) != 1 or len(guid_values[0]) != 16:
                raise DirectoryError('AD_INVALID_RESPONSE')
            sid = sid_from_bytes(sid_values[0])
            record = {'guid': str(uuid.UUID(bytes_le=guid_values[0])), 'sid': sid,
                      'sam': attribute(attrs, 'samaccountname'),
                      'name': attribute(attrs, 'displayname', True) or attribute(attrs, 'name'), '_dn': dn}
            if kind == 'groups':
                record.update(security_enabled=bool(int(attribute(attrs, 'grouptype')) & 0x80000000),
                              _members=self.members(dn, attrs))
            else:
                rid = attribute(attrs, 'primarygroupid')
                if not rid.isdecimal() or not 0 <= int(rid) <= 0xffffffff:
                    raise DirectoryError('AD_INVALID_RESPONSE')
                record.update(enabled=not bool(int(attribute(attrs, 'useraccountcontrol')) & 2),
                              _primary=sid.rsplit('-', 1)[0] + '-' + str(int(rid)))
            result.append(record)
        return result

    def account(self, domain, guid, *, now=None):
        """Resolve immutable GUID, then BASE-read computed tokenGroups.

        Missing or ranged tokenGroups are incomplete, never an empty group set.
        This intentionally requires a DC able to compute transitive memberships.
        """
        object_id(guid)
        base = ','.join('DC=' + x for x in domain.split('.'))
        escaped = ''.join('\\' + format(x, '02x') for x in uuid.UUID(guid).bytes_le)
        filter_value = '(&(objectGUID=' + escaped + ')(objectClass=user))'
        rows, _ = self.search(base, self.ldap.SCOPE_SUBTREE, filter_value, ['objectGUID'])
        if not rows:
            return None
        if len(rows) != 1 or not rows[0][0].casefold().endswith(',' + base.casefold()):
            raise DirectoryError('AD_INVALID_RESPONSE')
        dn = rows[0][0]
        attributes = ['objectGUID', 'objectSid', 'objectClass', 'userAccountControl',
                      'msDS-User-Account-Control-Computed', 'accountExpires', 'primaryGroupID', 'tokenGroups']
        rows, _ = self.search(dn, self.ldap.SCOPE_BASE, filter_value, attributes)
        if not rows:
            return None  # Object deleted or changed between the two reads.
        if len(rows) != 1 or rows[0][0].casefold() != dn.casefold():
            raise DirectoryError('AD_INVALID_RESPONSE')
        attrs = rows[0][1]
        identifiers = attrs.get('objectguid', [])
        sids = attrs.get('objectsid', [])
        if len(identifiers) != 1 or identifiers[0] != uuid.UUID(guid).bytes_le or len(sids) != 1:
            raise DirectoryError('AD_INVALID_RESPONSE')
        classes = attrs.get('objectclass', [])
        if not classes or any(type(x) is not bytes for x in classes) or b'user' not in {x.lower() for x in classes}:
            raise DirectoryError('AD_INVALID_RESPONSE')
        kind = 'computer' if b'computer' in {x.lower() for x in classes} else 'user'
        sid = account_sid(sid_from_bytes(sids[0]))

        def decimal(name, maximum):
            value = attribute(attrs, name)
            if not re.fullmatch(r'[0-9]{1,20}', value) or int(value) > maximum:
                raise DirectoryError('AD_INVALID_RESPONSE')
            return int(value)

        flags = decimal('useraccountcontrol', 0xffffffff)
        computed = decimal('msds-user-account-control-computed', 0xffffffff)
        expires = decimal('accountexpires', 2**63 - 1)
        primary = decimal('primarygroupid', 0xffffffff)
        if (kind == 'user' and (not flags & 0x200 or flags & 0x3800)) or (kind == 'computer' and not flags & 0x3000):
            raise DirectoryError('AD_INVALID_RESPONSE')
        if any(x.startswith('tokengroups;') for x in attrs):
            raise DirectoryError('AD_INVALID_RESPONSE')
        tokens = attrs.get('tokengroups')
        if type(tokens) is not list or not 1 <= len(tokens) <= 256:
            raise DirectoryError('AD_INVALID_RESPONSE')
        groups = frozenset(sid_from_bytes(x) for x in tokens)
        if len(groups) != len(tokens) or sid.rsplit('-', 1)[0] + '-' + str(primary) not in groups:
            raise DirectoryError('AD_INVALID_RESPONSE')
        now = datetime.now(timezone.utc) if now is None else now
        delta = now - datetime(1601, 1, 1, tzinfo=timezone.utc)
        ticks = (delta.days * 86400 + delta.seconds) * 10_000_000 + delta.microseconds * 10
        enabled = not flags & 2 and not computed & 0x10 and (expires in (0, 2**63 - 1) or expires > ticks)
        result = asdict(CurrentDirectoryAccount(domain, guid, sid, kind, bool(enabled), groups))
        result['security_group_sids'] = sorted(groups)
        return result

    def computer(self, domain, sam):
        # The caller obtained this SAM from a verified Kerberos initiator.
        if not re.fullmatch(r'[A-Za-z0-9_][A-Za-z0-9_.-]{0,19}\$', sam):
            raise DirectoryError('AD_INPUT_INVALID')
        base = ','.join('DC=' + x for x in domain.split('.'))
        rows, _ = self.search(base, self.ldap.SCOPE_SUBTREE,
            '(&(objectClass=computer)(sAMAccountName=' + sam + '))', ['objectGUID', 'sAMAccountName'])
        if len(rows) != 1 or not rows[0][0].casefold().endswith(',' + base.casefold()):
            raise DirectoryError('AD_INVALID_RESPONSE')
        attrs = rows[0][1]
        guids = attrs.get('objectguid', [])
        if len(guids) != 1 or len(guids[0]) != 16 or attribute(attrs, 'samaccountname').casefold() != sam.casefold():
            raise DirectoryError('AD_INVALID_RESPONSE')
        result = self.account(domain, str(uuid.UUID(bytes_le=guids[0])))
        if result is None or result['kind'] != 'computer':
            raise DirectoryError('AD_INVALID_RESPONSE')
        return result

    def authenticated_user(self, domain, sam, configuration_dn=None):
        if not re.fullmatch(r'[A-Za-z0-9_][A-Za-z0-9_.-]{0,19}', sam):
            raise DirectoryError('AD_INPUT_INVALID')
        base = ','.join('DC=' + x for x in domain.split('.'))
        self.remaining()
        authz = self.connection.whoami_s()
        if type(authz) is not str or len(authz) > 256:
            raise DirectoryError('AD_INVALID_RESPONSE')
        authenticated_sid = None
        if authz.startswith('u:S-'):
            authenticated_sid = account_sid(authz[2:])
        else:
            # Resolve the NetBIOS name of this precise domain from the DC's
            # configuration partition; never infer it from the DNS prefix.
            named = re.fullmatch(r'u:([A-Za-z0-9_-]{1,15})\\([A-Za-z0-9_][A-Za-z0-9_.-]{0,19})', authz)
            if not named or named[2].casefold() != sam.casefold() or type(configuration_dn) is not str or not configuration_dn.casefold().startswith('cn=configuration,') or len(configuration_dn) > 2048:
                raise DirectoryError('AD_INVALID_RESPONSE')
            refs, _ = self.search('CN=Partitions,' + configuration_dn, self.ldap.SCOPE_SUBTREE,
                '(&(objectClass=crossRef)(nCName=' + base + '))', ['nCName', 'nETBIOSName'])
            if len(refs) != 1 or attribute(refs[0][1], 'ncname').casefold() != base.casefold() or attribute(refs[0][1], 'netbiosname').casefold() != named[1].casefold():
                raise DirectoryError('AD_INVALID_RESPONSE')
        rows, _ = self.search(base, self.ldap.SCOPE_SUBTREE,
            '(&(objectClass=user)(!(objectClass=computer))(sAMAccountName=' + sam + '))',
            ['objectGUID', 'sAMAccountName'])
        if len(rows) != 1 or not rows[0][0].casefold().endswith(',' + base.casefold()):
            raise DirectoryError('AD_INVALID_RESPONSE')
        attrs = rows[0][1]
        identifiers = attrs.get('objectguid', [])
        if len(identifiers) != 1 or len(identifiers[0]) != 16 or attribute(attrs, 'samaccountname').casefold() != sam.casefold():
            raise DirectoryError('AD_INVALID_RESPONSE')
        account = self.account(domain, str(uuid.UUID(bytes_le=identifiers[0])))
        if account is None or account['kind'] != 'user' or not account['enabled'] or (authenticated_sid is not None and account['sid'] != authenticated_sid):
            raise DirectoryError('AD_CREDENTIALS_REJECTED')
        return account

    def resolve_scopes(self, domain, search_base):
        domain_base = ','.join('DC=' + x for x in domain.split('.'))
        scopes = validate_search_scopes(search_base, domain).splitlines() or [domain_base]
        resolved = []
        for scope in scopes:
            if '=' not in scope:
                escaped = ''.join({'\\': r'\5c', '*': r'\2a', '(': r'\28', ')': r'\29', '\0': r'\00'}.get(c, c) for c in scope)
                matches = [dn for dn, _ in self.raw_objects(domain_base,
                    '(&(objectClass=organizationalUnit)(ou=' + escaped + '))')]
                if not matches:
                    raise DirectoryError('AD_SCOPE_NOT_FOUND')
                if len(matches) != 1:
                    raise DirectoryError('AD_SCOPE_AMBIGUOUS')
                scope = matches[0]
            if not dn_within(scope, domain_base):
                raise DirectoryError('AD_SCOPE_INVALID')
            if scope.casefold() != domain_base.casefold():
                rows, _ = self.search(scope, self.ldap.SCOPE_BASE, '(objectClass=*)', ['objectClass'])
                if len(rows) != 1 or not dn_within(rows[0][0], scope) or not dn_within(scope, rows[0][0]):
                    raise DirectoryError('AD_SCOPE_NOT_FOUND')
            if not any(dn_within(scope, x) for x in resolved):
                resolved = [x for x in resolved if not dn_within(x, scope)] + [scope]
        return resolved

    def catalog(self, domain, dc, search_base=''):
        scopes = self.resolve_scopes(domain, search_base)
        collections = {kind: [] for kind in FILTERS}
        seen = set()
        for base in scopes:
            for kind in FILTERS:
                for record in self.objects(kind, base):
                    if not dn_within(record['_dn'], base):
                        raise DirectoryError('AD_SCOPE_INVALID')
                    if record['guid'] in seen:
                        raise DirectoryError('AD_INVALID_RESPONSE')
                    seen.add(record['guid']); collections[kind].append(record)
                if len(collections[kind]) > 10000:
                    raise DirectoryError('AD_DIRECTORY_LIMIT')
        all_records = [x for records in collections.values() for x in records]
        by_dn = {x['_dn'].casefold(): x['sid'] for x in all_records}
        if len(by_dn) != len(all_records):
            raise DirectoryError('AD_INVALID_RESPONSE')
        groups = {x['sid']: x for x in collections['groups']}
        edges = []
        for group in collections['groups']:
            group['unresolved_members'] = 0
            for dn in group.pop('_members'):
                if dn.casefold() in by_dn:
                    edges.append({'member_sid': by_dn[dn.casefold()], 'group_sid': group['sid'], 'type': 'direct'})
                else:
                    group['unresolved_members'] += 1
        for kind in ('users', 'computers'):
            for account in collections[kind]:
                primary = account.pop('_primary')
                account['primary_group_unresolved'] = primary not in groups
                if primary in groups:
                    edges.append({'member_sid': account['sid'], 'group_sid': primary, 'type': 'primary'})
        for record in all_records:
            del record['_dn']
        return validate_catalog({'domain': domain, 'dc_fqdn': dc, 'transport': TRANSPORT,
                                 **collections, 'membership_schema': 1, 'memberships': edges}, domain, dc)


def protected_connection(ldap, sasl, dc):
    connection = ldap.initialize('ldap://' + dc + ':389')
    connection.set_option(ldap.OPT_PROTOCOL_VERSION, 3)
    connection.set_option(ldap.OPT_REFERRALS, 0)
    connection.set_option(ldap.OPT_NETWORK_TIMEOUT, 10)
    connection.set_option(ldap.OPT_TIMEOUT, 10)
    # NOCANON=1 prevents reverse-DNS substitution of the trusted LDAP SPN.
    connection.set_option(ldap.OPT_X_SASL_NOCANON, 1)
    connection.set_option(ldap.OPT_X_SASL_SECPROPS, 'minssf=56,maxssf=256,noplain,noanonymous')
    connection.sasl_interactive_bind_s('', sasl.gssapi())
    if connection.get_option(ldap.OPT_X_SASL_SSF) < 56:
        connection.unbind_s()
        raise DirectoryError('AD_PROTECTION_REQUIRED')
    return connection


def verify_ticket_identity(env, principal):
    try:
        tickets = subprocess.run(['/usr/bin/klist', '-c', env['KRB5CCNAME']],
            capture_output=True, env=env, timeout=5, check=False)
        principals = re.findall(rb'^Default principal: (.+)$', tickets.stdout, re.M)
        if tickets.returncode or len(tickets.stdout) > 16384 or len(principals) != 1 or principals[0].decode('ascii').casefold() != principal.casefold():
            raise DirectoryError('AD_INVALID_RESPONSE')
    except (OSError, subprocess.TimeoutExpired, UnicodeError):
        raise DirectoryError('AD_BIND_FAILED') from None


def run(request):
    try:
        import ldap
        import ldap.sasl
        from ldap.controls.simple import ValueLessRequestControl
        from ldap.controls.libldap import SimplePagedResultsControl
    except ImportError:
        raise DirectoryError('AD_PROTOCOL_UNAVAILABLE') from None
    directory = Path(request['cache_dir'])
    if directory.is_symlink() or directory.stat().st_uid != os.getuid() or directory.stat().st_mode & 0o077:
        raise DirectoryError('AD_INPUT_INVALID')
    realm = request['domain'].upper()
    krb = directory / 'krb5.conf'
    krb.write_text('[libdefaults]\n default_realm = ' + realm + '\n dns_lookup_kdc = false\n'
                   ' dns_lookup_realm = false\n rdns = false\n dns_canonicalize_hostname = false\n'
                   ' forwardable = false\n ticket_lifetime = 5m\n[realms]\n ' + realm + ' = {\n'
                   '  kdc = ' + request['dc_fqdn'] + '\n }\n[domain_realm]\n .'
                   + request['domain'] + ' = ' + realm + '\n ' + request['domain'] + ' = ' + realm + '\n')
    krb.chmod(0o600)
    env = {**os.environ, 'KRB5_CONFIG': str(krb), 'KRB5CCNAME': 'FILE:' + str(directory / 'ticket'), 'LC_ALL': 'C'}
    principal = request['username'].split('@', 1)[0] + '@' + realm
    try:
        result = subprocess.run(['/usr/bin/kinit', '-l', '5m', '-F', principal],
                                input=(request['password'] + '\n').encode(), capture_output=True,
                                env=env, timeout=10, check=False)
    except (OSError, subprocess.TimeoutExpired):
        raise DirectoryError('AD_BIND_FAILED') from None
    finally:
        request['password'] = ''
    if result.returncode:
        code = 'AD_CREDENTIALS_REJECTED' if any(x in result.stderr for x in
                (b'Preauthentication failed', b'Password incorrect', b'Client not found')) else 'AD_BIND_FAILED'
        raise DirectoryError(code)
    if request.get('authenticate_self'):
        # Do not trust the submitted login name if the KDC canonicalized it.
        # Both kinit and klist use the same private FILE cache and fixed locale.
        verify_ticket_identity(env, principal)
    # Environment is confined to this disposable subprocess, not the panel.
    os.environ.update({k: env[k] for k in ('KRB5_CONFIG', 'KRB5CCNAME', 'LC_ALL')})
    connection = None
    try:
        connection = protected_connection(ldap, ldap.sasl, request['dc_fqdn'])
        root_attributes = ['defaultNamingContext', 'dnsHostName']
        if request.get('authenticate_self'):
            root_attributes.append('configurationNamingContext')
        rows = connection.search_s('', ldap.SCOPE_BASE, '(objectClass=*)', root_attributes)
        if len(rows) != 1 or rows[0][0] != '':
            raise DirectoryError('AD_DOMAIN_MISMATCH')
        attrs = {key.lower(): values for key, values in rows[0][1].items()}
        expected = ','.join('DC=' + x for x in request['domain'].split('.'))
        if attribute(attrs, 'defaultnamingcontext').casefold() != expected.casefold() or attribute(attrs, 'dnshostname').lower() != request['dc_fqdn']:
            raise DirectoryError('AD_DOMAIN_MISMATCH')
        reader = Reader(connection, ldap, (ValueLessRequestControl, SimplePagedResultsControl))
        if request['probe']:
            reader.resolve_scopes(request['domain'], request['search_base'])
            return {'probe': 'ok', 'domain': request['domain'], 'dc_fqdn': request['dc_fqdn']}
        if request.get('computer_sam') is not None:
            return {'domain': request['domain'], 'dc_fqdn': request['dc_fqdn'],
                    'account': reader.computer(request['domain'], request['computer_sam'])}
        if request.get('authenticate_self'):
            return {'domain': request['domain'], 'dc_fqdn': request['dc_fqdn'],
                    'account': reader.authenticated_user(request['domain'], principal.split('@')[0],
                        attribute(attrs, 'configurationnamingcontext'))}
        if request.get('object_guid') is not None:
            return {'domain': request['domain'], 'dc_fqdn': request['dc_fqdn'],
                    'account': reader.account(request['domain'], request['object_guid'])}
        return reader.catalog(
            request['domain'], request['dc_fqdn'], request['search_base'])
    except ldap.INVALID_CREDENTIALS:
        raise DirectoryError('AD_CREDENTIALS_REJECTED') from None
    except ldap.LDAPError:
        raise DirectoryError('AD_SEARCH_FAILED') from None
    finally:
        if connection is not None:
            try: connection.unbind_s()
            except Exception: pass


def main():
    try:
        payload = sys.stdin.buffer.read(262145)
        if len(payload) > 262144:
            raise DirectoryError('AD_INPUT_INVALID')
        request = json.loads(payload)
        value = run(request)
        print(json.dumps(value, ensure_ascii=True)); return 0
    except DirectoryError as error:
        print(json.dumps({'error': error.code, **(error.diagnostic or {})})); return 1
    except Exception:
        print('{"error":"AD_SEARCH_FAILED"}'); return 1


if __name__ == '__main__':
    sys.exit(main())
