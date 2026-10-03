"""Integrity and RFC tunnel encoding checks for the protocol test observer."""
import hashlib
import hmac
import struct
import unittest

from tools.radius_lab import radius_attrs, response_fact

SECRET = b'test-only-packet-secret'
REQUEST = bytes((1, 7, 0, 20)) + bytes(range(16))


def reply(vlan=b'33', extras=b''):
    # Independent wire fixture. Native FreeRADIUS tests are in radius.yml.
    attrs = (bytes((64, 6, 0, 0, 0, 13, 65, 6, 0, 0, 0, 6, 81, len(vlan) + 2))
             + vlan + extras + b'\x50\x12' + b'\0' * 16)
    prefix = bytes((2, 7)) + struct.pack('!H', 20 + len(attrs))
    mac = hmac.new(SECRET, prefix + REQUEST[4:20] + attrs, hashlib.md5).digest()
    attrs = attrs[:-16] + mac
    authenticator = hashlib.md5(prefix + REQUEST[4:20] + attrs + SECRET).digest()
    return prefix + authenticator + attrs


class RadiusPacketTests(unittest.TestCase):
    def test_native_untagged_and_explicit_zero_tag_string_forms(self):
        for vlan in (b'33', b'\x0033'):
            with self.subTest(vlan=vlan):
                self.assertEqual(response_fact(reply(vlan), REQUEST, SECRET), {
                    'code': 2, 'message_authenticator_valid': True,
                    'vlan': {64: 13, 65: 6, 81: '33'}})

    def test_payload_and_response_authenticator_tampering_reject(self):
        original = reply()
        for position in (4, 24, 33):
            changed = bytearray(original)
            changed[position] ^= 1
            with self.assertRaises(ValueError):
                response_fact(changed, REQUEST, SECRET)
        with self.assertRaises(ValueError):
            response_fact(original, REQUEST, b'wrong-secret')

    def test_mac_tamper_even_with_recomputed_response_authenticator_reject(self):
        changed = bytearray(reply())
        changed[-1] ^= 1
        changed[4:20] = hashlib.md5(changed[:4] + REQUEST[4:20] + changed[20:] + SECRET).digest()
        with self.assertRaises(ValueError):
            response_fact(changed, REQUEST, SECRET)

    def test_tagged_or_duplicate_vlan_and_mac_reject(self):
        for vlan, extras in ((b'\x0133', b''), (b'33', b'\x51\x0433'),
                             (b'33', b'\x50\x12' + b'\0' * 16)):
            with self.subTest(vlan=vlan, extras=extras), self.assertRaises(ValueError):
                response_fact(reply(vlan, extras), REQUEST, SECRET)

    def test_truncated_and_invalid_attribute_lengths_reject(self):
        for data in (b'', REQUEST + b'\x01', REQUEST[:-1],
                     bytes((1, 7, 0, 22)) + REQUEST[4:] + b'\x01\x01',
                     bytes((1, 7, 0, 22)) + REQUEST[4:] + b'\x01\x05'):
            with self.assertRaises(ValueError):
                radius_attrs(data)


if __name__ == '__main__':
    unittest.main()
