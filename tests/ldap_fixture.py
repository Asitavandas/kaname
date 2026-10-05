"""Loopback LDAP wire fixture, no AD, credentials, or external network."""
import socket
import struct
import re
import threading
import uuid


def tlv(tag, value):
    size = len(value)
    length = bytes([size]) if size < 128 else (lambda raw: bytes([128 + len(raw)]) + raw)(size.to_bytes((size.bit_length() + 7) // 8, 'big'))
    return bytes([tag]) + length + value


def number(value, tag=2):
    raw = value.to_bytes(max(1, (value.bit_length() + 7) // 8), 'big')
    if raw[0] & 128:
        raw = b'\0' + raw
    return tlv(tag, raw)


def octet(value):
    return tlv(4, value.encode() if isinstance(value, str) else value)


def parse(data, offset=0):
    tag, length = data[offset:offset + 2]
    offset += 2
    if length & 128:
        count = length & 127
        length = int.from_bytes(data[offset:offset + count], 'big')
        offset += count
    return tag, data[offset:offset + length], offset + length


def read_packet(conn):
    def exact(size):
        value = b''
        while len(value) < size:
            chunk = conn.recv(size - len(value))
            if not chunk:
                raise EOFError()
            value += chunk
        return value
    tag, first = exact(2)
    length = first
    if first & 128:
        count = first & 127
        if not 1 <= count <= 4:
            raise ValueError('Invalid fixture BER size')
        length = int.from_bytes(exact(count), 'big')
    if tag != 48 or length > 1_000_000:
        raise ValueError('Invalid fixture LDAP packet')
    return exact(length)


def sid(*parts):
    return bytes([1, len(parts)]) + (5).to_bytes(6, 'big') + b''.join(struct.pack('<I', p) for p in parts)


def entry(message_id, attributes, dn='CN=fixture,DC=fixture,DC=invalid'):
    items = b''.join(tlv(48, octet(name) + tlv(49, b''.join(octet(v) for v in values))) for name, values in attributes.items())
    return tlv(48, number(message_id) + tlv(100, octet(dn) + tlv(48, items)))


def done(message_id, tag=101, cookie=None, omit_control=False):
    controls = b''
    if cookie is not None and not omit_control:
        value = tlv(48, number(0) + octet(cookie))
        controls = tlv(160, tlv(48, octet('1.2.840.113556.1.4.319') + octet(value)))
    return tlv(48, number(message_id) + tlv(tag, number(0, 10) + octet('') + octet('')) + controls)


class LDAPFixture:
    def __init__(self, mode='normal'):
        self.mode = mode
        self.listener = socket.socket()
        self.listener.bind(('127.0.0.1', 0))
        self.listener.listen(1)
        self.listener.settimeout(1)
        self.port = self.listener.getsockname()[1]
        self.stop = threading.Event()
        self.conn = None
        self.errors = []
        self.searches = 0
        self.domain_scope_controls = []
        self.search_records = []
        self.thread = threading.Thread(target=self.serve, daemon=True)

    def __enter__(self):
        self.thread.start()
        return self

    def __exit__(self, *_):
        self.stop.set()
        if self.conn:
            self.conn.close()
        self.listener.close()
        self.thread.join(timeout=3)

    def serve(self):
        try:
            while not self.stop.is_set():
                try:
                    self.conn, _ = self.listener.accept()
                    break
                except socket.timeout:
                    continue
            if not self.conn:
                return
            self.conn.settimeout(15)
            with self.conn as conn:
                while not self.stop.is_set():
                    packet = read_packet(conn)
                    _, mid, offset = parse(packet)
                    message_id = int.from_bytes(mid, 'big')
                    operation, content, next_offset = parse(packet, offset)
                    if operation == 96:  # anonymous bind, fixture only
                        conn.sendall(done(message_id, tag=97))
                    elif operation == 119 and self.mode in {'account-user','account-user-named'}:
                        oid_tag, oid, _ = parse(content)
                        if oid_tag != 128 or oid != b'1.3.6.1.4.1.4203.1.11.3':
                            raise ValueError('Unexpected fixture extended operation')
                        authz=b'u:FIXTURE\\alice' if self.mode == 'account-user-named' else b'u:S-1-5-21-1-2-3-1001'
                        value = number(0, tag=10) + octet('') + octet('') + tlv(139,authz)
                        conn.sendall(tlv(48,number(message_id)+tlv(120,value)))
                    elif operation == 99:
                        self.searches += 1
                        domain_scope = False
                        if next_offset < len(packet):
                            tag, controls, _ = parse(packet, next_offset)
                            if tag != 160:
                                raise ValueError('Invalid fixture control wrapper')
                            pos = 0
                            while pos < len(controls):
                                _, control, pos = parse(controls, pos)
                                _, oid, at = parse(control)
                                if oid == b'1.2.840.113556.1.4.1339':
                                    tag, critical, at = parse(control, at)
                                    domain_scope = tag == 1 and critical != b'\0'
                                    if at < len(control):
                                        tag, value, _ = parse(control, at)
                                        domain_scope = domain_scope and tag == 4 and value == b''
                        self.domain_scope_controls.append(domain_scope)
                        _, base, pos = parse(content)
                        _, search_scope, pos = parse(content, pos)
                        for _ in range(4):
                            _, _, pos = parse(content, pos)
                        _, filter_data, _ = parse(content, pos)
                        self.search_records.append((base.decode(), int.from_bytes(search_scope, 'big')))
                        if self.mode.startswith('account-'):
                            self.account_response(conn, message_id, base.decode(), int.from_bytes(search_scope, 'big'))
                            continue
                        if self.mode == 'scoped':
                            self.legacy_scoped_response(conn, message_id, base.decode(), filter_data)
                            continue
                        if self.mode == 'ou-scoped':
                            self.scoped_response(conn, message_id, base.decode(), filter_data, int.from_bytes(search_scope, "big"))
                            continue
                        ranged = re.search(rb'member;range=(\d+)-\d+', content)
                        if ranged:
                            start = int(ranged.group(1))
                            attrs = {f'member;range={start}-*': ['CN=fixture-2,DC=fixture,DC=invalid', 'CN=external,DC=other,DC=invalid']}
                            if self.mode == 'range-missing': attrs = {}
                            if self.mode == 'range-repeat': attrs = {'member;range=0-*': ['CN=fixture-1,DC=fixture,DC=invalid']}
                            if self.mode == 'range-duplicate': attrs = {f'member;range={start}-*': ['CN=fixture-1,DC=fixture,DC=invalid']}
                            conn.sendall(entry(message_id, attrs, 'CN=fixture-3,DC=fixture,DC=invalid'))
                            conn.sendall(done(message_id))
                            continue
                        first_user_page = self.searches == 1
                        is_group = b'objectCategory' in content and b'group' in content and b'person' not in content and b'computer' not in content
                        # All searches request groupType, so inspect the BER filter
                        # rather than treating that requested attribute as a filter.
                        is_computer = b'computer' in content
                        index = 3 if is_group else 4 if is_computer else self.searches
                        attrs = {
                            'objectSid': [sid(32, 544) if is_group else sid(21, 1, 2, 3, 1000 + index)],
                            'objectGUID': [uuid.UUID(int=index).bytes_le],
                            'sAMAccountName': [f'fixture-{index}'],
                            'name': [f'Fixture {index}'],
                            'userAccountControl': ['514' if first_user_page else '512'],
                            'primaryGroupID': ['513'],
                            'groupType': ['-2147483646'],
                        }
                        if is_group:
                            members = ['CN=fixture-1,DC=fixture,DC=invalid', 'CN=fixture-2,DC=fixture,DC=invalid', 'CN=external,DC=other,DC=invalid']
                            if self.mode.startswith('range-'):
                                attrs['member;range=0-0'] = members[:1]
                                if self.mode == 'range-large':
                                    attrs['member;range=0-1499'] = [members[0]] + [f'CN=external-{i},DC=other,DC=invalid' for i in range(1499)]
                                    del attrs['member;range=0-0']
                            else: attrs['member'] = members
                        conn.sendall(entry(message_id, attrs, f'CN=fixture-{index},DC=fixture,DC=invalid'))
                        if self.mode == 'referral' or (self.mode == 'ad-referrals' and not domain_scope):
                            conn.sendall(tlv(48, number(message_id) + tlv(115, octet('ldap://outside.invalid/DC=other'))))
                        cookie = b'next-page' if first_user_page or self.mode == 'repeat' else b''
                        conn.sendall(done(message_id, cookie=cookie, omit_control=self.mode == 'missing'))
                    elif operation == 66:  # unbind
                        return
                    else:
                        raise ValueError('Unexpected fixture operation')
        except (EOFError, OSError):
            pass
        except Exception as exc:
            self.errors.append(type(exc).__name__)

    def account_response(self, conn, message_id, base, scope):
        """BASE computed attributes for a synthetic live account; no Kerberos."""
        dn = 'CN=fixture-1001,DC=fixture,DC=invalid'
        if self.mode == 'account-user-named' and base.startswith('CN=Partitions,'):
            conn.sendall(entry(message_id,{'nCName':['DC=fixture,DC=invalid'],'nETBIOSName':['FIXTURE']},'CN=FIXTURE,'+base))
            conn.sendall(done(message_id));return
        attrs = {'objectGUID': [uuid.UUID(int=1001).bytes_le], 'sAMAccountName': ['alice']}
        if scope == 0:
            attrs.update(objectSid=[sid(21, 1, 2, 3, 1001)], objectClass=['top', 'person', 'user', 'computer'],
                         userAccountControl=['4096'], accountExpires=['0'], primaryGroupID=['513'],
                         **{'msDS-User-Account-Control-Computed': ['0'],
                            'tokenGroups': [sid(21, 1, 2, 3, 513), sid(21, 1, 2, 3, 1100)]})
            if self.mode == 'account-disabled': attrs['userAccountControl'] = ['4098']
            if self.mode == 'account-group-removed': attrs['tokenGroups'] = [sid(21, 1, 2, 3, 513)]
            if self.mode == 'account-incomplete': del attrs['tokenGroups']
            if self.mode in {'account-user','account-user-named'}:
                attrs.update(objectClass=['top', 'person', 'user'], userAccountControl=['512'])
        if self.mode != 'account-deleted':
            conn.sendall(entry(message_id, attrs, dn))
        conn.sendall(done(message_id))

    def scoped_response(self, conn, message_id, base, filter_data, scope):
        domain = 'DC=fixture,DC=invalid'
        network = 'OU=Network,' + domain
        other = 'OU=Other,' + domain
        group_dn = 'CN=Access,' + network
        nested_dn = 'CN=Child,' + other
        inside_dn = 'CN=Inside,' + network
        alice_dn = 'CN=Alice,OU=Users,' + domain
        bob_dn = 'CN=Bob,OU=Elsewhere,' + domain
        containers = [network, other, 'OU=Users,' + domain, 'OU=Elsewhere,' + domain]
        if b'organizationalUnit' in filter_data:
            selected = [dn for dn in containers if dn.split(',')[0][3:].encode() in filter_data]
            if b'Ambiguous' in filter_data:
                selected = ['OU=Ambiguous,OU=Network,' + domain, 'OU=Ambiguous,OU=Other,' + domain]
            for dn in selected:
                conn.sendall(entry(message_id, {'objectClass': ['organizationalUnit']}, dn))
        elif scope == 0:
            if base in containers:
                conn.sendall(entry(message_id, {'objectClass': ['organizationalUnit']}, base))
        else:
            objects = [(1100, group_dn, 'group', [inside_dn, nested_dn, 'CN=Foreign,DC=other,DC=invalid'], 0),
                       (1101, nested_dn, 'group', [alice_dn], 0),
                       (1000, inside_dn, 'user', [], 513),
                       (1001, alice_dn, 'user', [], 513),
                       (1002, bob_dn, 'user', [], 1100),
                       (1003, 'CN=PC01,' + network, 'computer', [], 513)]
            kind = 'group' if b'group' in filter_data else 'user' if b'person' in filter_data else 'computer'
            for index, dn, object_kind, members, primary_id in objects:
                if object_kind != kind or not (dn.lower() == base.lower() or dn.lower().endswith(',' + base.lower())):
                    continue
                attrs = {'objectSid': [sid(21, 1, 2, 3, index)], 'objectGUID': [uuid.UUID(int=index).bytes_le],
                         'sAMAccountName': [f'fixture-{index}'], 'name': [f'Fixture {index}'],
                         'userAccountControl': ['512'], 'primaryGroupID': [str(primary_id)], 'groupType': ['-2147483646']}
                if kind == 'group': attrs['member'] = members
                conn.sendall(entry(message_id, attrs, dn))
        conn.sendall(done(message_id, cookie=b''))

    def legacy_scoped_response(self, conn, message_id, base, filter_data):
        domain = 'DC=fixture,DC=invalid'
        group_dn = 'CN=Access,OU=Network,' + domain
        nested_dn = 'CN=Child,OU=Other,' + domain
        alice_dn = 'CN=Alice,OU=Users,' + domain
        bob_dn = 'CN=Bob,OU=Elsewhere,' + domain
        is_group = b'group' in filter_data
        is_user = b'person' in filter_data
        primary = b'primaryGroupID' in filter_data
        result = []
        if is_group and base == 'OU=Network,' + domain:
            result = [(1100, group_dn, 'group', [nested_dn, 'CN=Foreign,DC=other,DC=invalid'], 0)]
        elif is_group and base == nested_dn:
            result = [(1101, nested_dn, 'group', [alice_dn], 0)]
        elif is_user and base == alice_dn:
            result = [(1001, alice_dn, 'user', [], 513)]
        elif is_user and primary and b'1100' in filter_data:
            result = [(1002, bob_dn, 'user', [], 1100)]
        for index, dn, kind, members, primary_id in result:
            attrs = {'objectSid': [sid(21, 1, 2, 3, index)], 'objectGUID': [uuid.UUID(int=index).bytes_le],
                     'sAMAccountName': [f'fixture-{index}'], 'name': [f'Fixture {index}'],
                     'userAccountControl': ['512'], 'primaryGroupID': [str(primary_id)], 'groupType': ['-2147483646']}
            if kind == 'group': attrs['member'] = members
            conn.sendall(entry(message_id, attrs, dn))
        conn.sendall(done(message_id, cookie=b''))
