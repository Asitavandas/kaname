"""Loopback LDAP wire fixture, no AD, credentials, or external network."""
import socket
import struct
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


def entry(message_id, attributes):
    items = b''.join(tlv(48, octet(name) + tlv(49, b''.join(octet(v) for v in values))) for name, values in attributes.items())
    return tlv(48, number(message_id) + tlv(100, octet('CN=fixture,DC=fixture,DC=invalid') + tlv(48, items)))


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
                    operation, content, _ = parse(packet, offset)
                    if operation == 96:  # anonymous bind, fixture only
                        conn.sendall(done(message_id, tag=97))
                    elif operation == 99:
                        self.searches += 1
                        first_user_page = self.searches == 1
                        is_group = b'groupType' in content
                        is_computer = b'computer' in content
                        index = self.searches
                        attrs = {
                            'objectSid': [sid(32, 544) if is_group else sid(21, 1, 2, 3, 1000 + index)],
                            'objectGUID': [uuid.UUID(int=index).bytes_le],
                            'sAMAccountName': [f'fixture-{index}'],
                            'name': [f'Fixture {index}'],
                            'userAccountControl': ['514' if first_user_page else '512'],
                        }
                        conn.sendall(entry(message_id, attrs))
                        if self.mode == 'referral':
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
