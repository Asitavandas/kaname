"""Isolated idempotency and session lifecycle tests for RADIUS Accounting."""
import sqlite3
import tempfile
import unittest
from pathlib import Path

from kaname.radius_accounting import initialize, ingest, paths, parse


def packet(nas, vector, status, session='shared-session', **extra):
    pairs = [
        ('Packet-Src-IP-Address', nas),
        ('Packet-Authentication-Vector', vector),
        ('Acct-Status-Type', status),
        ('Acct-Session-Id', session),
    ]
    pairs.extend(extra.items())
    return tuple(pairs)


class RadiusAccountingTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.state = Path(self.temp.name) / 'state'
        self.state.mkdir(mode=0o700)
        initialize(self.state)

    def tearDown(self):
        self.temp.cleanup()

    def rows(self, table):
        _, path = paths(self.state)
        with sqlite3.connect(path) as db:
            return db.execute('SELECT * FROM ' + table).fetchall()

    def test_start_interim_stop_persist_and_deduplicate_packet_retry(self):
        start = packet('127.0.0.2', '0x' + '01' * 16, 'Start',
                       **{'Acct-Session-Time': '0', 'Calling-Station-Id': 'AA-BB-CC-DD-EE-FF',
                          'Acct-Input-Octets': '10'})
        interim = packet('127.0.0.2', '0x' + '02' * 16, 'Interim-Update',
                         **{'Acct-Session-Time': '60', 'Acct-Input-Octets': '4294967295',
                            'Acct-Input-Gigawords': '1', 'Acct-Output-Octets': '9'})
        stop = packet('127.0.0.2', '0x' + '03' * 16, 'Stop',
                      **{'Acct-Session-Time': '90', 'Acct-Output-Octets': '11'})
        self.assertTrue(ingest(self.state, start))
        self.assertTrue(ingest(self.state, interim))
        self.assertFalse(ingest(self.state, interim))  # same authenticator, retry
        self.assertTrue(ingest(self.state, stop))
        events = self.rows('accounting_events')
        sessions = self.rows('accounting_sessions')
        self.assertEqual(len(events), 3)
        self.assertEqual([row[4] for row in events], ['Start', 'Interim-Update', 'Stop'])
        self.assertEqual([row[12] for row in events], [0, 0, 0])
        self.assertEqual(len(sessions), 1)
        self.assertIsNotNone(sessions[0][4])
        self.assertEqual(sessions[0][6], 90)
        self.assertEqual(sessions[0][7], 8589934591)
        self.assertEqual(sessions[0][8], 11)
        self.assertEqual(sessions[0][9], 'aa:bb:cc:dd:ee:ff')

    def test_session_id_is_scoped_by_nas(self):
        self.assertTrue(ingest(self.state, packet('127.0.0.2', '0x' + '11' * 16, 'Start')))
        self.assertTrue(ingest(self.state, packet('127.0.0.3', '0x' + '11' * 16, 'Start')))
        sessions = self.rows('accounting_sessions')
        self.assertEqual({row[1] for row in sessions}, {'127.0.0.2', '127.0.0.3'})
        self.assertEqual(len(sessions), 2)

    def test_stop_without_start_and_interim_after_stop_are_orphan_events(self):
        self.assertTrue(ingest(self.state, packet('127.0.0.2', '0x' + '21' * 16, 'Stop')))
        self.assertEqual(len(self.rows('accounting_sessions')), 0)
        self.assertTrue(ingest(self.state, packet('127.0.0.2', '0x' + '22' * 16, 'Start')))
        self.assertTrue(ingest(self.state, packet('127.0.0.2', '0x' + '23' * 16, 'Stop')))
        self.assertTrue(ingest(self.state, packet('127.0.0.2', '0x' + '24' * 16, 'Interim-Update')))
        events = self.rows('accounting_events')
        self.assertEqual([row[12] for row in events], [1, 0, 0, 1])
        self.assertEqual(len(self.rows('accounting_sessions')), 1)

    def test_counter_gigawords_are_combined_without_overflow(self):
        event = parse(packet('127.0.0.2', '0x' + '31' * 16, 'Interim-Update',
                             **{'Acct-Input-Octets': '5', 'Acct-Input-Gigawords': '2'}))
        self.assertEqual(event['input_bytes'], 2 * 2**32 + 5)

    def test_untrusted_or_malformed_packets_reject(self):
        bad = (
            packet('127.0.0.2', 'not-an-authenticator', 'Start'),
            packet('127.0.0.2', '0x' + '41' * 16, 'Accounting-On'),
            packet('127.0.0.2', '0x' + '42' * 16, 'Start',
                   **{'Acct-Session-Id': 'bad\nvalue'}),
            packet('127.0.0.2', '0x' + '43' * 16, 'Start',
                   **{'Acct-Input-Octets': '4294967296'}),
        )
        for item in bad:
            with self.subTest(item=item), self.assertRaises(ValueError):
                parse(item)


if __name__ == '__main__':
    unittest.main()