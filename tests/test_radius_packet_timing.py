import importlib.util
import json
import os
from pathlib import Path
import socket
import struct
import sys
import tempfile
import time
import unittest


PATH = Path(__file__).resolve().parents[1] / 'tools' / 'radius_packet_timing.py'
spec = importlib.util.spec_from_file_location('radius_packet_timing', PATH)
probe = importlib.util.module_from_spec(spec)
spec.loader.exec_module(probe)
NAS = '192.0.2.10'


def frame(attributes=b'', *, response=True, tags=0):
    radius = bytes([2 if response else 1, 7]) + struct.pack('!H', 20 + len(attributes)) + b'X' * 16 + attributes
    source, target = ('192.0.2.20', NAS) if response else (NAS, '192.0.2.20')
    ports = (1812, 40000) if response else (40000, 1812)
    udp = struct.pack('!HHHH', *ports, 8 + len(radius), 0) + radius
    ip = bytes([0x45, 0]) + struct.pack('!H', 20 + len(udp)) + b'\0' * 5 + bytes([17]) + b'\0\0'
    ip += socket.inet_aton(source) + socket.inet_aton(target)
    ethernet = b'\0' * 12
    for _ in range(tags):
        ethernet += b'\x81\0\0\1'
    return ethernet + b'\x08\0' + ip + udp


def attr(kind, value):
    return bytes([kind, len(value) + 2]) + value


class PacketTests(unittest.TestCase):
    def test_terminal_metadata_omits_secrets(self):
        secret = b'NEVER_EXPORT_KEY_MATERIAL'
        vendor = struct.pack('!I', 311) + bytes([16, len(secret) + 2]) + secret
        attributes = attr(79, b'\3\11\0\4') + attr(26, vendor) + attr(80, b'M' * 16)
        row = probe.radius_metadata(frame(attributes), NAS)
        self.assertEqual((row['radius_code'], row['eap_code'], row['eap_id']), (2, 3, 9))
        self.assertTrue(row['mppe_send'])
        self.assertFalse(row['mppe_receive'])
        self.assertTrue(row['message_authenticator'])
        self.assertNotIn(secret.decode(), json.dumps(row))
        self.assertNotIn('authenticator', row)

    def test_vlan_and_request(self):
        for tags in range(3):
            with self.subTest(tags=tags):
                self.assertEqual(probe.radius_metadata(frame(response=False, tags=tags), NAS)['direction'], 'from_nas')
        self.assertIsNone(probe.radius_metadata(frame(tags=3), NAS))

    def test_truncated_frames(self):
        packet = frame(attr(79, b'\3\11\0\4'))
        for end in range(len(packet)):
            with self.subTest(end=end):
                self.assertIsNone(probe.radius_metadata(packet[:end], NAS))

    def test_wrong_nas_and_port(self):
        self.assertIsNone(probe.radius_metadata(frame(), '192.0.2.99'))
        packet = bytearray(frame())
        packet[34:36] = b'\0\1'
        self.assertIsNone(probe.radius_metadata(packet, NAS))

    def test_ip_fragment_rejected(self):
        for field in (0x2000, 1):
            packet = bytearray(frame())
            packet[20:22] = struct.pack('!H', field)
            self.assertIsNone(probe.radius_metadata(packet, NAS))

    def test_malformed_lengths(self):
        for attributes in (b'\x01', b'\x01\x01', b'\x01\xff', attr(80, b'bad'),
                           attr(79, b'\3\11\0\5'), attr(79, b'\3\11\0\5X'),
                           attr(79, b'\2\11\0\4'),
                           attr(26, struct.pack('!I', 311) + b'\x10\x01')):
            with self.subTest(attributes=attributes):
                self.assertIsNone(probe.radius_metadata(frame(attributes), NAS))

    def test_split_eap_attributes(self):
        row = probe.radius_metadata(frame(attr(79, b'\2\11') + attr(79, b'\0\5\15')), NAS)
        self.assertEqual((row['eap_code'], row['eap_type']), (2, 13))


@unittest.skipUnless(sys.platform == 'linux' and struct.calcsize('@l') == 8,
                     'Linux 64-bit timestamp ABI required')
class TimestampTests(unittest.TestCase):
    def test_no_userspace_fallback(self):
        option = 35
        valid = [(socket.SOL_SOCKET, option, struct.pack('@ll', 100, 123))]
        self.assertEqual(probe.kernel_timestamp_ns(valid, 0, option), 100000000123)
        for ancillary, flags in (([], 0), (valid, socket.MSG_CTRUNC),
                                 (valid, socket.MSG_TRUNC), (valid + valid, 0),
                                 ([(socket.SOL_SOCKET, option, b'bad')], 0),
                                 ([(socket.SOL_SOCKET, option, struct.pack('@ll', 1, 1000000000))], 0)):
            self.assertIsNone(probe.kernel_timestamp_ns(ancillary, flags, option))

    def test_real_kernel_timestamp_precedes_delayed_read(self):
        option = probe.timestamp_option()
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as receiver, socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sender:
            receiver.bind(('127.0.0.1', 0))
            receiver.setsockopt(socket.SOL_SOCKET, option, 1)
            receiver.settimeout(2)
            before = time.time_ns()
            sender.sendto(b'timestamp-only-fixture', receiver.getsockname())
            time.sleep(0.04)  # Prove a queue delay is not attributed to the wire.
            _, ancillary, flags, _ = receiver.recvmsg(256, socket.CMSG_SPACE(64))
            after = time.time_ns()
            stamp = probe.kernel_timestamp_ns(ancillary, flags, option)
        self.assertIsNotNone(stamp)
        self.assertGreaterEqual(stamp, before)
        self.assertLessEqual(stamp, after - 20_000_000)


@unittest.skipUnless(os.name == 'posix', 'POSIX private file operations required')
class OutputTests(unittest.TestCase):
    def test_exclusive_private_output_and_symlink_rejection(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory) / 'metadata.jsonl'
            with probe.private_output(target) as handle:
                handle.write('{}\n')
            self.assertEqual(target.stat().st_mode & 0o777, 0o600)
            with self.assertRaises(FileExistsError):
                probe.private_output(target)
            link = Path(directory) / 'link.jsonl'
            link.symlink_to(target)
            with self.assertRaises(FileExistsError):
                probe.private_output(link)
            self.assertEqual(target.read_text(), '{}\n')
            os.chmod(directory, 0o755)
            with self.assertRaises(ValueError):
                probe.private_output(Path(directory) / 'unsafe.jsonl')
            os.chmod(directory, 0o700)


if __name__ == '__main__':
    unittest.main()
