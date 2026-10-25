"""Isolated public-key channel boundaries; no AD/network/customer state."""
import base64
import concurrent.futures
import dataclasses
import json
import unittest

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec, padding, rsa

from kaname.connector_channel import Binding, ChannelError, ConnectorHealth, public_key_id


class ConnectorChannelTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.private = rsa.generate_private_key(public_exponent=65537, key_size=3072)
        cls.other = rsa.generate_private_key(public_exponent=65537, key_size=3072)
        cls.pem = cls.private.public_key().public_bytes(serialization.Encoding.PEM,
            serialization.PublicFormat.SubjectPublicKeyInfo)

    def setUp(self):
        self.now = 1000.0
        self.wall = 1792950000.0
        self.binding = Binding('4c23eebe-0715-46d1-88ee-a2e96ad7ee46',
            'cf0ac716-0a62-4013-89f6-75121cc890a2', 1,
            '0fa4143f-aae3-4bc3-9cd3-db8a1de24acd', 'dc01.fixture.example',
            'S-1-5-21-111-222-333-1648', 'authwire.fixture.example', 'a'*64, self.pem)
        self.channel = self.new_channel()

    def new_channel(self, binding=None):
        return ConnectorHealth(binding or self.binding,
            monotonic=lambda: self.now, wall_clock=lambda: self.wall)

    def proof(self, challenge, *, private=None, alter=None):
        frame = base64.b64decode(challenge['frame'])
        signed = alter(frame) if alter else frame
        signature = (private or self.private).sign(signed, padding.PKCS1v15(), hashes.SHA256())
        return json.dumps({'challenge_id': frame.decode().split('\n')[10],
            'signature': base64.b64encode(signature).decode()}).encode()

    def test_real_rsa_proof_and_no_ad_or_deployment_authority(self):
        self.assertFalse(self.channel.status()['online'])
        result = self.channel.accept(self.proof(self.channel.challenge()))
        self.assertTrue(result['channel_proof_verified'])
        for k in ('can_apply', 'directory_sync_ready', 'kerberos_ready'):
            self.assertFalse(result[k]); self.assertFalse(self.channel.status()[k])
        self.assertTrue(self.channel.status()['online'])

    def test_atomic_single_consumption_even_with_concurrent_replies(self):
        proof = self.proof(self.channel.challenge())
        def accept(_):
            try: self.channel.accept(proof); return True
            except ChannelError: return False
        with concurrent.futures.ThreadPoolExecutor(max_workers=12) as pool:
            self.assertEqual(1, sum(pool.map(accept, range(24))))

    def test_challenge_binds_every_identity_pin_generation_and_operation(self):
        for field in range(16):
            challenge = self.channel.challenge()
            def alter(frame):
                parts = frame.decode().split('\n'); parts[field] += 'x'
                return '\n'.join(parts).encode()
            with self.subTest(field=field), self.assertRaises(ChannelError):
                self.channel.accept(self.proof(challenge, alter=alter))
            self.channel.accept(self.proof(challenge))

    def test_foreign_key_cannot_self_pair_or_replace_trust(self):
        challenge = self.channel.challenge()
        with self.assertRaises(ChannelError):
            self.channel.accept(self.proof(challenge, private=self.other))
        value = json.loads(self.proof(challenge)); value['public_key'] = self.pem.decode()
        with self.assertRaises(ChannelError): self.channel.accept(json.dumps(value).encode())
        self.channel.accept(self.proof(challenge))

    def test_expiry_uses_monotonic_clock_and_boundary_is_exclusive(self):
        p = self.proof(self.channel.challenge())
        self.wall -= 86400 # A wall clock correction cannot extend server lifetime.
        self.now += 60
        with self.assertRaises(ChannelError): self.channel.accept(p)
        self.assertFalse(self.channel.status()['online'])

    def test_online_expires_and_restart_discards_challenges_and_last_seen(self):
        self.channel.accept(self.proof(self.channel.challenge()))
        pending = self.proof(self.channel.challenge())
        self.now += 89; self.assertTrue(self.channel.status()['online'])
        self.now += 1; self.assertFalse(self.channel.status()['online'])
        restarted = self.new_channel()
        self.assertFalse(restarted.status()['online'])
        with self.assertRaises(ChannelError): restarted.accept(pending)

    def test_rotation_generation_and_peer_instance_do_not_share_pending_state(self):
        proof = self.proof(self.channel.challenge())
        for binding in (dataclasses.replace(self.binding, generation=2),
                        dataclasses.replace(self.binding, connector_id='c26f2c4a-4b77-4465-998e-7a5c4bb157ac'),
                        dataclasses.replace(self.binding, public_key_pem=self.other.public_key().public_bytes(
                            serialization.Encoding.PEM, serialization.PublicFormat.SubjectPublicKeyInfo))):
            with self.assertRaises(ChannelError): self.new_channel(binding).accept(proof)
        self.channel.revoke()
        with self.assertRaisesRegex(ChannelError, 'CONNECTOR_REVOKED'): self.channel.accept(proof)
        with self.assertRaisesRegex(ChannelError, 'CONNECTOR_REVOKED'): self.channel.challenge()
        self.assertFalse(self.channel.status()['configured'])

    def test_pending_count_is_bounded_and_expired_slots_recovered(self):
        for _ in range(4): self.channel.challenge()
        with self.assertRaisesRegex(ChannelError, 'CONNECTOR_BUSY'): self.channel.challenge()
        self.now += 60
        self.assertTrue(self.channel.challenge()['frame'])

    def test_three_invalid_signatures_burn_only_that_challenge(self):
        challenge = self.channel.challenge(); other = self.channel.challenge()
        for _ in range(3):
            with self.assertRaises(ChannelError):
                self.channel.accept(self.proof(challenge, private=self.other))
        with self.assertRaises(ChannelError): self.channel.accept(self.proof(challenge))
        self.channel.accept(self.proof(other))

    def test_malformed_unknown_duplicate_and_oversized_envelopes(self):
        p = json.loads(self.proof(self.channel.challenge()))
        cases = [b'', b'\xff', b'x'*2049, b'[]', b'null', b'NaN', b'{',
            json.dumps(p).encode('utf-16'), json.dumps(p).encode('utf-32'),
            json.dumps(p|{'command':'powershell.exe'}).encode(),
            json.dumps(p|{'challenge_id':True}).encode(),
            json.dumps(p|{'challenge_id':'F'*64}).encode(),
            json.dumps(p|{'signature':False}).encode(),
            json.dumps(p|{'signature':'!invalid'}).encode(),
            json.dumps(p|{'signature':p['signature']+'\n'}).encode(),
            json.dumps(p|{'signature':base64.b64encode(b'x'*383).decode()}).encode(),
            ('{"challenge_id":"'+p['challenge_id']+'","signature":"'+p['signature']+'","signature":"x"}').encode(),
            ('['*1000 + ']'*1000).encode()]
        for value in cases:
            with self.subTest(value=value[:50]), self.assertRaises(ChannelError):
                self.channel.accept(value)
        self.channel.accept(json.dumps(p).encode())

    def test_bindings_reject_noncanonical_weak_foreign_or_private_keys(self):
        for change in ({'generation':True}, {'generation':0}, {'generation':2**31},
            {'instance_id':'00000000-0000-0000-0000-000000000000'},
            {'host_guid':self.binding.host_guid.upper()}, {'host_fqdn':'DC01.fixture.example'},
            {'host_fqdn':'dc01'}, {'host_fqdn':'evil\nPOST.example'},
            {'service_sid':'S-1-5-18'}, {'service_sid':'S-1-5-21-1-2-3-4294967296'},
            {'appliance_tls_sha256':'A'*64}, {'public_key_pem':self.pem+b'\n'},
            {'public_key_pem':self.private.private_bytes(serialization.Encoding.PEM,
                serialization.PrivateFormat.PKCS8, serialization.NoEncryption())},
            {'public_key_pem':rsa.generate_private_key(public_exponent=65537,key_size=2048).public_key().public_bytes(
                serialization.Encoding.PEM,serialization.PublicFormat.SubjectPublicKeyInfo)},
            {'public_key_pem':ec.generate_private_key(ec.SECP256R1()).public_key().public_bytes(
                serialization.Encoding.PEM,serialization.PublicFormat.SubjectPublicKeyInfo)}):
            with self.subTest(fields=list(change)), self.assertRaises(ChannelError):
                dataclasses.replace(self.binding, **change)

    def test_key_identifier_covers_public_modulus_and_protocol_label(self):
        self.assertRegex(public_key_id(self.private.public_key()), '^[0-9a-f]{64}$')
        self.assertNotEqual(public_key_id(self.private.public_key()), public_key_id(self.other.public_key()))


if __name__ == '__main__': unittest.main()
