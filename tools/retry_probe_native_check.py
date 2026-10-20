"""Disposable network-namespace proof; never run on the customer appliance."""
import argparse
import json
import os
from pathlib import Path
import socket
import socketserver
import subprocess
import sys
import threading
import time
import uuid

from tools import retry_network_probe as probe


class TCP(socketserver.BaseRequestHandler):
    def handle(self):
        self.request.sendall(b'ok')


class UDP(socketserver.BaseRequestHandler):
    def handle(self):
        data, sock = self.request
        sock.sendto(b'ok', self.client_address)


def connect(source, port=8765):
    with socket.socket() as sock:
        sock.settimeout(0.35)
        sock.bind((source, 0))
        try:
            sock.connect((probe.SERVER, port))
            return sock.recv(2) == b'ok'
        except (ConnectionError, TimeoutError, OSError):
            return False


def inside():
    addresses = json.loads(subprocess.check_output(['/usr/sbin/ip', '-j', 'link'], text=True))
    assert [i['ifname'] for i in addresses] == ['lo'], 'Fixture requires an empty network namespace'
    subprocess.run(['/usr/sbin/ip', 'link', 'set', 'lo', 'up'], check=True)
    for ip in (probe.SERVER, probe.CLIENT, '10.10.110.5'):
        subprocess.run(['/usr/sbin/ip', 'address', 'add', ip+'/32', 'dev', 'lo'], check=True)
    servers = []
    for port in (8765, 22, 7777):
        server = socketserver.ThreadingTCPServer((probe.SERVER, port), TCP)
        servers.append(server)
    servers.append(socketserver.ThreadingUDPServer((probe.SERVER, 1812), UDP))
    for server in servers:
        threading.Thread(target=server.serve_forever, daemon=True).start()
    guard = 'fixture_guard'
    name = 'aw_retry_probe_' + uuid.uuid4().hex[:12]
    created = False
    try:
        guard_rules = ('add table inet fixture_guard\n'
                       'add chain inet fixture_guard input { type filter hook input priority 10; policy accept; }\n'
                       'add rule inet fixture_guard input tcp dport 7777 drop\n')
        subprocess.run([probe.NFT, '-f', '-'], input=guard_rules, text=True, check=True)
        before = subprocess.check_output([probe.NFT, '-j', 'list', 'table', 'inet', guard])
        assert connect(probe.CLIENT)
        assert not connect(probe.CLIENT, 7777)
        probe.create(name, duration=4)
        created = True
        assert not connect(probe.CLIENT), 'The single pilot client must fail immediately'
        assert connect('10.10.110.5'), 'A different client must remain allowed'
        assert connect('127.0.0.1'), 'Loopback administration must remain allowed'
        assert connect(probe.CLIENT, 22), 'Pilot SSH must remain allowed'
        assert not connect(probe.CLIENT, 7777), 'The probe must not bypass a different chain drop'
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
            sock.bind((probe.CLIENT, 0)); sock.settimeout(1)
            sock.sendto(b'probe', (probe.SERVER, 1812))
            assert sock.recv(2) == b'ok', 'UDP1812 must not match the probe'
        assert probe.hits(name) > 0
        until = time.monotonic() + 7
        while time.monotonic() < until and not connect(probe.CLIENT):
            time.sleep(0.2)
        assert connect(probe.CLIENT), 'Kernel timeout must restore HTTPS without a cleanup process'
        after = subprocess.check_output([probe.NFT, '-j', 'list', 'table', 'inet', guard])
        assert before == after, 'Foreign rules changed'
        probe.remove(name); created = False
        assert connect(probe.CLIENT)
        assert not connect(probe.CLIENT, 7777)
        print('RETRY_PROBE_NATIVE_OK scoped_tcp_reject=true other_client=true ssh=true udp1812=true loopback=true kernel_expiry=true foreign_rules_preserved=true own_table_removed=true', flush=True)
    finally:
        if created:
            probe.remove(name)
        subprocess.run([probe.NFT, 'delete', 'table', 'inet', guard], check=False)
        for server in servers:
            server.shutdown(); server.server_close()


def main():
    assert os.geteuid() == 0
    assert os.environ.get('GITHUB_ACTIONS') == 'true', 'Disposable hosted CI only'
    assert os.environ.get('RUNNER_ENVIRONMENT') == 'github-hosted', 'Never use a self-hosted appliance'
    p = argparse.ArgumentParser(); p.add_argument('--inside', action='store_true'); args = p.parse_args()
    if args.inside:
        inside(); return
    namespace = 'awprobe-' + uuid.uuid4().hex[:12]
    subprocess.run(['/usr/sbin/ip', 'netns', 'add', namespace], check=True)
    try:
        subprocess.run(['/usr/sbin/ip', 'netns', 'exec', namespace, sys.executable, '-m', 'tools.retry_probe_native_check', '--inside'], check=True, timeout=45)
    finally:
        subprocess.run(['/usr/sbin/ip', 'netns', 'delete', namespace], check=True)


if __name__ == '__main__':
    main()
