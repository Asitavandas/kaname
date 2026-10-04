"""Bounded subprocess with private Kerberos cache and mandatory SASL sealing."""
import json
import os
import re
import subprocess
import sys
import time
import uuid
from pathlib import Path

from .directory import DirectoryError, TRANSPORT, validate_catalog

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

    def catalog(self, domain, dc, search_base=''):
        domain_base = ','.join('DC=' + x for x in domain.split('.'))
        if not search_base:
            collections = {kind: self.objects(kind, domain_base) for kind in FILTERS}
        else:
            collections = {'users': [], 'groups': self.objects('groups', search_base), 'computers': []}
            known = {x['_dn'].casefold() for x in collections['groups']}
            index = 0
            while index < len(collections['groups']):
                group = collections['groups'][index]; index += 1
                for dn in group['_members']:
                    if not dn.casefold().endswith(',' + domain_base.casefold()) or dn.casefold() in known:
                        continue
                    known.add(dn.casefold())
                    for kind in ('groups', 'users', 'computers'):
                        records = self.objects(kind, dn, scope=self.ldap.SCOPE_BASE)
                        if records:
                            collections[kind].extend(records)
                            break
                if re.fullmatch(r'S-1-5-21-\d+-\d+-\d+-\d+', group['sid']):
                    rid = group['sid'].rsplit('-', 1)[1]
                    for kind in ('users', 'computers'):
                        # RID is derived from validated binary SID, never user filter text.
                        filter_value = '(&' + FILTERS[kind] + '(primaryGroupID=' + rid + '))'
                        for record in self.objects(kind, domain_base, filter_value):
                            if record['_dn'].casefold() not in known:
                                known.add(record['_dn'].casefold()); collections[kind].append(record)
                if any(len(x) > 10000 for x in collections.values()):
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
    # Environment is confined to this disposable subprocess, not the panel.
    os.environ.update({k: env[k] for k in ('KRB5_CONFIG', 'KRB5CCNAME', 'LC_ALL')})
    connection = None
    try:
        connection = protected_connection(ldap, ldap.sasl, request['dc_fqdn'])
        rows = connection.search_s('', ldap.SCOPE_BASE, '(objectClass=*)', ['defaultNamingContext', 'dnsHostName'])
        if len(rows) != 1 or rows[0][0] != '':
            raise DirectoryError('AD_DOMAIN_MISMATCH')
        attrs = {key.lower(): values for key, values in rows[0][1].items()}
        expected = ','.join('DC=' + x for x in request['domain'].split('.'))
        if attribute(attrs, 'defaultnamingcontext').casefold() != expected.casefold() or attribute(attrs, 'dnshostname').lower() != request['dc_fqdn']:
            raise DirectoryError('AD_DOMAIN_MISMATCH')
        if request['probe']:
            return {'probe': 'ok', 'domain': request['domain'], 'dc_fqdn': request['dc_fqdn']}
        return Reader(connection, ldap, (ValueLessRequestControl, SimplePagedResultsControl)).catalog(
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
        request = json.loads(sys.stdin.buffer.read(32768))
        value = run(request)
        print(json.dumps(value, ensure_ascii=True)); return 0
    except DirectoryError as error:
        print(json.dumps({'error': error.code, **(error.diagnostic or {})})); return 1
    except Exception:
        print('{"error":"AD_SEARCH_FAILED"}'); return 1


if __name__ == '__main__':
    sys.exit(main())
