import unittest
from unittest.mock import patch
from tools import retry_network_probe as probe


class RetryNetworkProbeTests(unittest.TestCase):
    def test_exact_client_server_port_and_kernel_expiry_only(self):
        value = probe.rules('aw_retry_probe_123456abcdef')
        self.assertIn('10.10.110.4 timeout 180s', value)
        self.assertIn('ip daddr 10.35.50.246 tcp dport 8765', value)
        self.assertIn('flags timeout;', value)
        self.assertIn('policy accept;', value)
        self.assertNotIn('1812', value)
        self.assertNotIn('flush', value)
        self.assertNotIn('update element', value)

    def test_arbitrary_table_and_unbounded_duration_refused(self):
        for name in ('filter', 'aw_retry_probe_123456abcdef; delete table inet filter', 'aw_retry_probe_1'):
            with self.assertRaises(ValueError):
                probe.rules(name)
        for seconds in (0, -1, 181, True, '180'):
            with self.assertRaises(ValueError):
                probe.rules('aw_retry_probe_123456abcdef', seconds)

    def test_overlapping_probe_refused_before_mutation(self):
        with patch.object(probe, 'tables', return_value=[{'table': {'name': 'aw_retry_probe_111111111111'}}]), patch.object(probe, 'command') as call:
            with self.assertRaisesRegex(ValueError, 'EXISTING_PROBE_REFUSED'):
                probe.create('aw_retry_probe_123456abcdef')
            call.assert_not_called()

    def test_removal_cannot_target_foreign_table(self):
        with patch.object(probe, 'command') as call:
            with self.assertRaises(ValueError):
                probe.remove('filter')
            call.assert_not_called()


if __name__ == '__main__':
    unittest.main()
