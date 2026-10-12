"""Isolated native Python reply/control parsing check; localhost only, no AD."""
import argparse
import hashlib
import hmac
import json
import os
from pathlib import Path
import re
import secrets
import socket
import subprocess
import tempfile
import time


def response(packet, request, secret):
    if len(packet) < 20 or int.from_bytes(packet[2:4], 'big') != len(packet) or packet[1] != request[1]:
        raise ValueError('Invalid native response header')
    expected = hashlib.md5(packet[:4] + request[4:20] + packet[20:] + secret).digest()
    if not hmac.compare_digest(packet[4:20], expected):
        raise ValueError('Invalid native response authenticator')
    attrs = []
    offset = 20
    while offset < len(packet):
        if offset + 2 > len(packet):
            raise ValueError('Invalid native response attribute')
        kind, size = packet[offset:offset+2]
        if size < 2 or offset + size > len(packet):
            raise ValueError('Invalid native response attribute length')
        attrs.append((kind, packet[offset+2:offset+size], offset))
        offset += size
    macs = [(value, offset) for kind, value, offset in attrs if kind == 80]
    if len(macs) != 1 or len(macs[0][0]) != 16:
        raise ValueError('Native response Message-Authenticator missing')
    value, offset = macs[0]
    zeroed = bytearray(packet)
    zeroed[4:20] = request[4:20]
    zeroed[offset+2:offset+18] = bytes(16)
    if not hmac.compare_digest(value, hmac.digest(secret, zeroed, 'md5')):
        raise ValueError('Invalid native response Message-Authenticator')
    return packet[0], {kind: value for kind, value, _ in attrs if kind in (18, 64, 65, 81)}


def check(prefix, *, debug=False):
    prefix = Path(prefix).resolve()
    if not re.fullmatch(r'/[A-Za-z0-9_./-]+', str(prefix)):
        raise ValueError('Unsafe native prefix')
    binary = prefix / 'sbin/radiusd'
    secret = secrets.token_hex(32).encode()
    with tempfile.TemporaryDirectory(prefix='authwire-native-check-') as folder:
        root = Path(folder)
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as probe:
            probe.bind(('127.0.0.1', 0))
            port = probe.getsockname()[1]
        (root/'probe.py').write_text('''import radiusd
def authorize(pairs):
    deny = any(k == 'User-Name' and v.strip('"') == 'fixture-deny' for k,v in pairs)
    if deny:
        return radiusd.RLM_MODULE_OK, (), (('Auth-Type', ':=', 'Reject'),)
    return radiusd.RLM_MODULE_OK, (
        ('Reply-Message', ':=', 'NATIVE-ALLOW'),
        ('Tunnel-Type:0', ':=', '13'),
        ('Tunnel-Medium-Type:0', ':=', '6'),
        ('Tunnel-Private-Group-ID:0', ':=', '120'),
    ), (('Auth-Type', ':=', 'Accept'),)
''')
        (root/'radiusd.conf').write_text(f'''prefix = {prefix}
libdir = ${{prefix}}/lib
log {{
 destination = stdout
 auth = no
 auth_badpass = no
 auth_goodpass = no
}}
security {{
 require_message_authenticator = yes
 limit_proxy_state = yes
 reject_delay = 0
}}
client loopback {{
 ipaddr = 127.0.0.1
 secret = {secret.decode()}
 require_message_authenticator = yes
}}
modules {{
 python3 reply_probe {{
  python_path = "{root}"
  python_path_mode = prepend
  module = probe
  mod_authorize = ${{.module}}
  func_authorize = authorize
 }}
}}
server reply-check {{
 listen {{
  type = auth
  ipaddr = 127.0.0.1
  port = {port}
 }}
 authorize {{
  reply_probe
 }}
}}
''')
        env = dict(os.environ, LD_LIBRARY_PATH=str(prefix/'lib'), PYTHONDONTWRITEBYTECODE='1')
        log = root/'private-native.log'
        facts = []
        with log.open('wb') as output:
            log.chmod(0o600)
            args = [str(binary), *(['-X'] if debug else ['-f']), '-D',
                    str(prefix/'share/freeradius'), '-d', str(root)]
            process = subprocess.Popen(args, env=env, stdout=output, stderr=subprocess.STDOUT)
            try:
                deadline = time.monotonic()+10
                while time.monotonic() < deadline:
                    if 'Ready to process requests' in log.read_text(errors='replace'):
                        break
                    if process.poll() is not None:
                        raise RuntimeError('Native reply checker did not start')
                    time.sleep(0.05)
                else:
                    raise RuntimeError('Native reply checker startup timed out')
                for ident, name in enumerate(('fixture-allow', 'fixture-deny'), 1):
                    value = name.encode()
                    attrs = bytes((1, len(value)+2))+value+bytes((80, 18))+bytes(16)
                    request = bytes((1, ident))+(20+len(attrs)).to_bytes(2, 'big')+secrets.token_bytes(16)+attrs
                    request = request[:-16]+hmac.digest(secret, request, 'md5')
                    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as client:
                        client.settimeout(4)
                        client.sendto(request, ('127.0.0.1', port))
                        packet = client.recv(4096)
                    code, values = response(packet, request, secret)
                    expected = 2 if name == 'fixture-allow' else 3
                    if code != expected:
                        raise RuntimeError('Native Python Auth-Type was not applied in '+('debug' if debug else 'normal')+' mode')
                    if expected == 2 and (values.get(18) != b'NATIVE-ALLOW' or values.get(64) != b'\0\0\0\x0d'
                            or values.get(65) != b'\0\0\0\x06' or values.get(81) not in (b'120', b'\x00120')):
                        raise RuntimeError('Native Python VLAN or reply attributes were not applied')
                    if expected == 3 and any(kind in values for kind in (64, 65, 81)):
                        raise RuntimeError('Native Reject unexpectedly contains VLAN attributes')
                    facts.append({'action': 'allow' if expected == 2 else 'deny',
                                  'radius_code': code, 'authenticated_response': True,
                                  'vlan': 120 if expected == 2 else None})
            finally:
                process.terminate()
                try:
                    process.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=3)
        return {'native_reply_check_passed': True, 'server_mode': 'debug' if debug else 'normal',
                'loopback_only': True, 'cases': facts}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--radius-prefix', required=True)
    parser.add_argument('--debug', action='store_true')
    args = parser.parse_args()
    try:
        print(json.dumps(check(args.radius_prefix, debug=args.debug)))
    except Exception as error:
        print(json.dumps({'native_reply_check_passed': False, 'category': type(error).__name__}))
        raise SystemExit(1)
