"""Real, temporary loopback FreeRADIUS/eapol_test proof with synthetic AD.

Requires a separately built FreeRADIUS 3.2.10 prefix. Never installs a service,
uses a production CA, issues real endpoint credentials, or opens a LAN port.
Only sanitized facts survive: raw EAP logs, secrets, keys and packets do not.
"""
import argparse
import hashlib
import hmac
import json
import os
from pathlib import Path
import re
import secrets
import shutil
import socket
import struct
import subprocess
import tempfile
import threading
import time
from datetime import datetime, timedelta, timezone

import cryptography
from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.x509.oid import ExtendedKeyUsageOID, NameOID

from kaname.pki import PKIService
from kaname import VERSION
from tests.test_radius import DOMAIN, GUID, SID, GROUP, policy
from tools.radius_crl_sync import sync as sync_crl

FREE_RADIUS_COMMIT = '9071ea041b9172e52eabbba91619afaf3a238795'
PEM = serialization.Encoding.PEM
FQDN = 'kaname.lab.example.test'


def private_file(path, content):
    if type(content) is str:
        content = content.encode()
    fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, 'wb') as handle:
        handle.write(content)


def leaf(key, issuer, signing_key, name, *, expired=False, purpose=ExtendedKeyUsageOID.CLIENT_AUTH):
    now = datetime.now(timezone.utc).replace(microsecond=0)
    return (x509.CertificateBuilder()
            .subject_name(x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, name)]))
            .issuer_name(issuer.subject).public_key(key.public_key())
            .serial_number(x509.random_serial_number())
            .not_valid_before(now - timedelta(days=2) if expired else now - timedelta(minutes=5))
            .not_valid_after(now - timedelta(days=1) if expired else now + timedelta(days=1))
            .add_extension(x509.BasicConstraints(False, None), critical=True)
            .add_extension(x509.KeyUsage(True, False, True, False, False, False, False, False, False), critical=True)
            .add_extension(x509.ExtendedKeyUsage([purpose]), critical=False)
            .add_extension(x509.SubjectKeyIdentifier.from_public_key(key.public_key()), critical=False)
            .add_extension(x509.AuthorityKeyIdentifier.from_issuer_public_key(signing_key.public_key()), critical=False)
            .sign(signing_key, hashes.SHA256()))


def material(root):
    """Create unrelated, disposable CA/state; test-only client signing lives here."""
    pki = PKIService(root / 'state')
    pki.store.save(0, config={'appliance_fqdn': FQDN, 'ad_domain': DOMAIN,
                           'dc_ips': ['127.0.0.1'], 'radius_clients': [],
                           'access_modes': ['wired', 'wireless']})
    password = secrets.token_hex(24).encode()
    pki.initialize(password)
    with pki.store.connect() as db:
        row = db.execute('SELECT issuer_cert,issuer_key FROM pki_authority WHERE id=1').fetchone()
    issuer = x509.load_pem_x509_certificate(row[0])
    issuer_key = serialization.load_pem_private_key(row[1], password)
    server_key = rsa.generate_private_key(65537, 2048)
    csr = (x509.CertificateSigningRequestBuilder().subject_name(x509.Name([]))
           .add_extension(x509.SubjectAlternativeName([x509.DNSName(FQDN)]), critical=False)
           .sign(server_key, hashes.SHA256()))
    server_cert = pki.issue_radius(csr.public_bytes(PEM), password)
    certs = root / 'certs'
    certs.mkdir(mode=0o700)
    private_file(certs / 'server.pem', server_cert + row[0])
    private_file(certs / 'server-key.pem', server_key.private_bytes(
        PEM, serialization.PrivateFormat.PKCS8, serialization.NoEncryption()))
    objects = {}
    for name in ('computer', 'user', 'unbound', 'revoked', 'expired', 'wrong-purpose'):
        key = rsa.generate_private_key(65537, 2048)
        cert = leaf(key, issuer, issuer_key, name, expired=name == 'expired',
                    purpose=ExtendedKeyUsageOID.SERVER_AUTH if name == 'wrong-purpose'
                    else ExtendedKeyUsageOID.CLIENT_AUTH)
        objects[name] = cert
        if name != 'revoked':
            with pki.store.connect() as db:
                db.execute('INSERT INTO pki_certificates(serial,certificate) VALUES (?,?)',
                           (format(cert.serial_number, 'x'), cert.public_bytes(PEM)))
        private_file(certs / (name + '.pem'), cert.public_bytes(PEM) + row[0])
        private_file(certs / (name + '-key.pem'), key.private_bytes(
            PEM, serialization.PrivateFormat.PKCS8, serialization.NoEncryption()))
    # Register only this synthetic revoked certificate so the existing CA CRL
    # implementation, rather than a hand-made allow/deny flag, revokes it.
    revoked = objects['revoked']
    with pki.store.connect() as db:
        db.execute('INSERT INTO pki_certificates(serial,certificate) VALUES (?,?)',
                   (format(revoked.serial_number, 'x'), revoked.public_bytes(PEM)))
    pki.revoke(format(revoked.serial_number, 'x'), password)
    # A signed CRL-only revocation for the hot-cache proof. Keep the registry's
    # computer row active so a native TLS reject cannot be explained by policy.
    with pki.store.connect() as db:
        revoked_rows = db.execute('SELECT serial,revoked_at,reason FROM pki_certificates WHERE revoked_at IS NOT NULL').fetchall()
        number = db.execute('SELECT crl_number FROM pki_authority').fetchone()[0]
    now = datetime.now(timezone.utc).replace(microsecond=0)
    hot_rows = revoked_rows + [(format(objects['computer'].serial_number,'x'),now.isoformat(),'superseded')]
    hot = pki._build_crl(issuer,issuer_key,hot_rows,number+1,now)
    private_file(root/'crl-native-revoked.pem',hot.public_bytes(PEM))
    for filename, content in pki.public_bundle().items():
        private_file(certs / filename, content)
    # A completely unrelated signing CA demonstrates native trust rejection.
    rogue_key = rsa.generate_private_key(65537, 2048)
    now = datetime.now(timezone.utc)
    name = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, 'Untrusted Lab CA')])
    rogue = (x509.CertificateBuilder().subject_name(name).issuer_name(name)
             .public_key(rogue_key.public_key()).serial_number(x509.random_serial_number())
             .not_valid_before(now - timedelta(minutes=5)).not_valid_after(now + timedelta(days=1))
             .add_extension(x509.BasicConstraints(True, 0), True)
             .sign(rogue_key, hashes.SHA256()))
    rogue_client_key = rsa.generate_private_key(65537, 2048)
    rogue_client = leaf(rogue_client_key, rogue, rogue_key, 'rogue')
    private_file(certs / 'rogue.pem', rogue_client.public_bytes(PEM) + rogue.public_bytes(PEM))
    private_file(certs / 'rogue-key.pem', rogue_client_key.private_bytes(
        PEM, serialization.PrivateFormat.PKCS8, serialization.NoEncryption()))
    private_file(certs / 'rogue-ca.pem', rogue.public_bytes(PEM))
    # Trust only KANAME root/issuer; the unrelated CA is outside ca_path.
    ca_path = root / 'ca'
    ca_path.mkdir(mode=0o700)
    for name, content in pki.public_bundle().items():
        private_file(ca_path / name, content)
    subprocess.run(['openssl', 'rehash', str(ca_path)], check=True, capture_output=True)
    return {'issuer_sha256': issuer.fingerprint(hashes.SHA256()).hex(),
            'issuer_dn': '/CN=' + issuer.subject.get_attributes_for_oid(NameOID.COMMON_NAME)[0].value,
            'serials': {name: format(cert.serial_number, 'x') for name, cert in objects.items()}}


def fixture(info):
    def bind(kind):
        return {'domain': DOMAIN, 'object_guid': GUID, 'sid': SID, 'kind': kind, 'active': True}
    return {'lab_only': True, 'persistent_registry': True, 'issuer_sha256': info['issuer_sha256'], 'issuer_dn': info['issuer_dn'],
            'nas_ip': '127.0.0.1', 'access_type': 'wired', 'directory_available': True,
            'case': 'valid-computer', 'policies': [policy()],
            'bindings': {info['serials'][name]: bind('user' if name == 'user' else 'computer')
                         for name in ('computer', 'user', 'revoked', 'expired', 'wrong-purpose')},
            'accounts': {GUID: {'domain': DOMAIN, 'object_guid': GUID, 'sid': SID, 'kind': 'computer',
                               'enabled': True, 'security_group_sids': [GROUP]}}}


def configuration(root, prefix, port, secret):
    libraries = list(prefix.rglob('rlm_python3.so'))
    if len(libraries) != 1:
        raise RuntimeError('Pinned build must include exactly one rlm_python3 module')
    share = prefix / 'share' / 'freeradius'
    if not (share / 'dictionary').is_file():
        raise RuntimeError('Pinned FreeRADIUS dictionaries are missing')
    repo = Path(__file__).resolve().parents[1]
    for path in (root, prefix, repo):
        if not re.fullmatch(r'[A-Za-z0-9_./-]+', str(path)):
            raise RuntimeError('Lab paths must have safe literal config characters')
    mods = root / 'mods-enabled'
    sites = root / 'sites-enabled'
    shim = root / 'python'
    for path in (mods, sites, shim):
        path.mkdir(mode=0o700)
    private_file(root / 'dictionary', '$INCLUDE ' + str(share / 'dictionary') + '\n')
    private_file(root / 'radiusd.conf', f'''prefix = {prefix}
name = kaname-lab
raddbdir = {root}
confdir = ${{raddbdir}}
modconfdir = ${{raddbdir}}
certdir = ${{raddbdir}}/certs
cadir = ${{raddbdir}}/ca
libdir = {libraries[0].parent}
logdir = ${{raddbdir}}
run_dir = ${{raddbdir}}
pidfile = ${{run_dir}}/kaname-lab.pid
max_request_time = 10
cleanup_delay = 1
max_requests = 128
hostname_lookups = no
proxy_requests = no
log {{
 destination = stdout
 auth = no
 auth_badpass = no
 auth_goodpass = no
 colourise = no
}}
security {{
 allow_core_dumps = no
 max_attributes = 128
 reject_delay = 0
 status_server = no
 require_message_authenticator = yes
 limit_proxy_state = yes
}}
modules {{
 $INCLUDE mods-enabled/
}}
$INCLUDE clients.conf
$INCLUDE sites-enabled/
''')
    private_file(root / 'clients.conf', f'''client kaname-loopback-lab {{
 ipaddr = 127.0.0.1
 secret = {secret}
 require_message_authenticator = yes
 limit_proxy_state = yes
}}
''')
    private_file(mods / 'eap', '''eap {
 default_eap_type = tls
 timer_expire = 15
 ignore_unknown_eap_types = no
 max_sessions = 64
 tls-config kaname-tls {
  private_key_file = ${certdir}/server-key.pem
  certificate_file = ${certdir}/server.pem
  ca_file = ${certdir}/root-ca.pem
  ca_path = ${cadir}
  ca_path_reload_interval = 300
  auto_chain = no
  check_crl = yes
  allow_expired_crl = no
  reject_unknown_intermediate_ca = yes
  tls_min_version = "1.2"
  tls_max_version = "1.2"
  cipher_list = "ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256"
  fragment_size = 512
  cache {
   enable = no
  }
 }
 tls {
  tls = kaname-tls
  require_client_cert = yes
  virtual_server = kaname-cert-check
 }
}
''')
    private_file(mods / 'python3', f'''python3 kaname_lab {{
 python_path = "{repo}:{shim}:{Path(cryptography.__file__).resolve().parent.parent}"
 python_path_mode = prepend
 module = kaname_lab_module
 mod_authorize = ${{.module}}
 func_authorize = authorize
}}
''')
    private_file(mods / 'reject', 'always reject {\n rcode = reject\n}\n')
    private_file(shim / 'kaname_lab_module.py',
                 'from tests.radius_fixture import authorize as lab_authorize\n'
                 'def authorize(pairs):\n    return lab_authorize(pairs, ' + repr(str(root)) + ')\n')
    private_file(sites / 'kaname', f'''server kaname-lab {{
 listen {{
  type = auth
  ipaddr = 127.0.0.1
  port = {port}
 }}
 authorize {{
  if (!&EAP-Message) {{
   reject
  }}
  eap
 }}
 authenticate {{
  eap
 }}
}}
server kaname-cert-check {{
 authorize {{
  update control {{
   Auth-Type := Reject
  }}
  kaname_lab
 }}
}}
''')


def radius_attrs(packet):
    if len(packet) < 20 or struct.unpack('!H', packet[2:4])[0] != len(packet):
        raise ValueError('Invalid RADIUS packet length')
    attrs = []
    offset = 20
    while offset < len(packet):
        if offset + 2 > len(packet):
            raise ValueError('Truncated RADIUS attribute')
        kind, length = packet[offset:offset + 2]
        if length < 2 or offset + length > len(packet):
            raise ValueError('Invalid RADIUS attribute')
        attrs.append((kind, packet[offset + 2:offset + length], offset))
        offset += length
    return attrs


def response_fact(packet, request, secret):
    attrs = radius_attrs(packet)
    expected = hashlib.md5(packet[:4] + request[4:20] + packet[20:] + secret).digest()
    if packet[1] != request[1] or not hmac.compare_digest(packet[4:20], expected):
        raise ValueError('Invalid RADIUS response authenticator')
    macs = [(v, offset) for kind, v, offset in attrs if kind == 80]
    if len(macs) != 1 or len(macs[0][0]) != 16:
        raise ValueError('Exactly one Message-Authenticator is required')
    value, offset = macs[0]
    zeroed = bytearray(packet)
    zeroed[4:20] = request[4:20]
    zeroed[offset + 2:offset + 18] = b'\0' * 16
    if not hmac.compare_digest(value, hmac.digest(secret, zeroed, 'md5')):
        raise ValueError('Invalid response Message-Authenticator')
    vlan = {}
    for kind, value, _ in attrs:
        if kind in (64, 65):
            if len(value) != 4 or value[0] != 0 or kind in vlan:
                raise ValueError('Invalid or duplicate untagged VLAN integer')
            vlan[kind] = int.from_bytes(value[1:], 'big')
        elif kind == 81:
            # RFC 2868: a first octet > 0x1f belongs to the string itself;
            # FreeRADIUS omits a zero tag for Tunnel-Private-Group-ID.
            if not value or 0 < value[0] <= 31 or kind in vlan:
                raise ValueError('Invalid VLAN string tag')
            vlan[kind] = (value[1:] if value[0] == 0 else value).decode('ascii')
    return {'code': packet[0], 'message_authenticator_valid': True, 'vlan': vlan}


class Relay:
    """Test transport to observe authentic replies; never emits Accept itself."""
    def __init__(self, port, secret):
        self.socket = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.socket.bind(('127.0.0.1', 0))
        self.port = self.socket.getsockname()[1]
        self.target = ('127.0.0.1', port)
        self.secret = secret.encode()
        self.facts = []
        self.errors = []
        self.running = True
        self.requests = {}
        self.client = None
        self.socket.settimeout(0.1)
        self.thread = threading.Thread(target=self.run, daemon=True)
        self.thread.start()

    def run(self):
        while self.running:
            try:
                packet, peer = self.socket.recvfrom(4096)
            except socket.timeout:
                continue
            except OSError:
                return
            try:
                if peer == self.target:
                    self.facts.append(response_fact(packet, self.requests[packet[1]], self.secret))
                    self.socket.sendto(packet, self.client)
                else:
                    if peer[0] != '127.0.0.1' or packet[0] != 1:
                        raise ValueError('Unexpected lab request peer or code')
                    radius_attrs(packet)
                    self.client = peer
                    self.requests[packet[1]] = packet
                    self.socket.sendto(packet, self.target)
            except Exception as exc:
                self.errors.append(type(exc).__name__ + ': ' + str(exc))

    def close(self):
        self.running = False
        self.thread.join(timeout=1)
        self.socket.close()


def wait_ready(process, log):
    deadline = time.monotonic() + 10
    while time.monotonic() < deadline:
        if process.poll() is not None:
            break
        if 'Ready to process requests' in log.read_text(errors='replace'):
            return
        time.sleep(0.1)
    # Never dump TLS debug logs, keys, secrets or full request attributes.
    safe = [line for line in log.read_text(errors='replace').splitlines()
            if re.search(r'Error|Failed|Unknown|not found|Cannot|Invalid', line, re.I)
            and not re.search(r'secret|password|key|User-Name|cert|TLS|EAP-Message', line, re.I)]
    raise RuntimeError('FreeRADIUS startup failed: ' + ' | '.join(safe[-5:]))


def eap_case(root, relay, secret, name, cert='computer', *, expected=2, reason=None,
             ca='root-ca.pem', server_name=FQDN, identity='untrusted-outer-identity', method='TLS'):
    certdir = root / 'certs'
    conf = root / (name + '.conf')
    private_file(conf, f'''network={{
 key_mgmt=WPA-EAP
 eap={method}
 identity="{identity}"
 ca_cert="{certdir / ca}"
 domain_match="{server_name}"
 client_cert="{certdir / (cert + '.pem')}"
 private_key="{certdir / (cert + '-key.pem')}"
 fragment_size=512
}}
''')
    before = len(relay.facts)
    result = subprocess.run(['eapol_test', '-c', str(conf), '-a', '127.0.0.1',
                             '-p', str(relay.port), '-s', secret, '-t', '8'],
                            capture_output=True, timeout=12)
    # Packet logs remain memory-only and are deliberately not persisted.
    facts = relay.facts[before:]
    finals = [f for f in facts if f['code'] in (2, 3)]
    if relay.errors:
        raise AssertionError(name + ': ' + '; '.join(relay.errors))
    if not finals or finals[-1]['code'] != expected:
        raise AssertionError(name + ': expected genuine RADIUS ' + str(expected)
                             + ', observed ' + str([f['code'] for f in facts]))
    if expected == 2:
        if result.returncode != 0 or b'SUCCESS' not in result.stdout:
            raise AssertionError(name + ': supplicant did not confirm success')
        if finals[-1]['vlan'] != {64: 13, 65: 6, 81: '33'}:
            raise AssertionError(name + ': VLAN response did not match policy')
    elif result.returncode == 0 or any(f['code'] == 2 or f['vlan'] for f in facts):
        raise AssertionError(name + ': rejected session had success/VLAN attributes')
    if not any(f['code'] == 11 for f in facts):
        raise AssertionError(name + ': no actual Access-Challenge exchange')
    if reason:
        events = [json.loads(line) for line in (root / 'decisions.jsonl').read_text().splitlines()]
        matches = [e for e in events if e['case'] == name]
        if not matches or matches[-1]['reason'] != reason:
            raise AssertionError(name + ': expected adapter decision ' + reason
                                 + ', observed ' + str([e['reason'] for e in matches]))
    return {'case': name, 'passed': True, 'radius_code': expected,
            'access_challenges': sum(f['code'] == 11 for f in facts),
            'response_integrity_checked': True, 'policy_reason': reason,
            'vlan': 33 if expected == 2 else None}


def drop_case(port, secret, name, *, source='127.0.0.1', mac='invalid', non_eap=False):
    # An ordinary malformed/unauthorized test request; no fuzzing or exploit.
    authenticator = secrets.token_bytes(16)
    eap_identity = b'\x02\x01\x00\x06\x01x'
    attrs = b'\x01\x03x' + (b'' if non_eap else bytes((79, len(eap_identity) + 2)) + eap_identity)
    if mac != 'missing':
        attrs += b'\x50\x12' + b'\0' * 16
    packet = bytearray(b'\x01\x07' + struct.pack('!H', 20 + len(attrs)) + authenticator + attrs)
    if mac == 'valid':
        packet[-16:] = hmac.digest(secret.encode(), packet, 'md5')
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.bind((source, 0))
        sock.settimeout(0.6)
        sock.sendto(packet, ('127.0.0.1', port))
        try:
            reply = sock.recv(4096)
        except socket.timeout:
            reply = None
    if non_eap:
        if reply is None or reply[0] != 3:
            raise AssertionError(name + ': plain non-EAP request was not rejected')
        fact = response_fact(reply, packet, secret.encode())
        if fact['vlan']:
            raise AssertionError(name + ': non-EAP reject assigned VLAN')
    elif reply is not None:
        raise AssertionError(name + ': unauthorized RADIUS request was answered')
    return {'case': name, 'passed': True, 'radius_code': 3 if non_eap else None,
            'silently_discarded': not non_eap}


def run_lab(prefix, *, debug=False):
    if os.name != 'posix' or not shutil.which('eapol_test'):
        raise RuntimeError('Linux and native eapol_test are required')
    binary = prefix / 'sbin' / 'radiusd'
    version = subprocess.run([str(binary), '-v'], capture_output=True, check=True).stdout.decode()
    if not re.search(r'Version 3\.2\.10(?:\s|,)', version):
        raise RuntimeError('Only the pinned, security-updated 3.2.10 proof build is accepted')
    facts = []
    with tempfile.TemporaryDirectory(prefix='kaname-radius-lab-') as temporary:
        root = Path(temporary)
        private_file(root / 'LAB_ONLY', 'KANAME temporary loopback EAP-TLS laboratory\n')
        info = material(root)
        secret = secrets.token_hex(32)
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as probe:
            probe.bind(('127.0.0.1', 0))
            port = probe.getsockname()[1]
        configuration(root, prefix, port, secret)
        log = root / 'private-debug.log'
        process = None
        relay = None
        try:
            with log.open('wb') as handle:
                mode = ['-X'] if debug else ['-f']
                process = subprocess.Popen([str(binary), *mode, '-d', str(root)],
                                           stdout=handle, stderr=subprocess.STDOUT)
                process_started = time.monotonic()
                wait_ready(process, log)
                relay = Relay(port, secret)

                def case(name, cert='computer', expected=3, reason=None, change=None, **options):
                    data = fixture(info)
                    data['case'] = name
                    if change:
                        change(data)
                    # Synthetic enrollment rows only in this disposable state.
                    # The runtime registry itself has no public writer/API.
                    with PKIService(root / 'state').store.connect() as db:
                        db.execute('''CREATE TABLE IF NOT EXISTS radius_certificate_bindings(
                            issuer_sha256 TEXT,serial TEXT,domain TEXT,object_guid TEXT,sid TEXT,kind TEXT,
                            active INTEGER,PRIMARY KEY(issuer_sha256,serial))''')
                        db.execute('DELETE FROM radius_certificate_bindings')
                        for serial, b in data['bindings'].items():
                            db.execute('INSERT INTO radius_certificate_bindings VALUES (?,?,?,?,?,?,?)',
                                       (info['issuer_sha256'], serial, b['domain'], b['object_guid'],
                                        b['sid'], b['kind'], int(b['active'])))
                    target = root / 'fixture.json'
                    staging = root / 'fixture-next.json'
                    private_file(staging, json.dumps(data))
                    staging.replace(target)
                    facts.append(eap_case(root, relay, secret, name, cert, expected=expected,
                                          reason=reason, **options))

                case('valid-computer', expected=2, reason='POLICY_ALLOW')
                case('valid-wireless', expected=2, reason='POLICY_ALLOW',
                     change=lambda d: d.update(access_type='wireless'))
                case('disabled-account', reason='ACCOUNT_DISABLED',
                     change=lambda d: d['accounts'][GUID].update(enabled=False))
                case('group-removed', reason='NO_MATCHING_POLICY',
                     change=lambda d: d['accounts'][GUID].update(security_group_sids=[]))
                case('directory-outage', reason='DIRECTORY_UNAVAILABLE',
                     change=lambda d: d.update(directory_available=False))
                case('account-deleted', reason='ACCOUNT_NOT_FOUND', change=lambda d: d.update(accounts={}))
                case('recreated-account', reason='ACCOUNT_BINDING_MISMATCH',
                     change=lambda d: d['accounts'][GUID].update(sid='S-1-5-21-11-22-33-1002'))
                case('inactive-binding', reason='CERTIFICATE_INACTIVE',
                     change=lambda d: d['bindings'][info['serials']['computer']].update(active=False))
                case('unbound-certificate', cert='unbound', reason='CERTIFICATE_UNBOUND',
                     identity='host/privileged-admin')
                case('explicit-deny', reason='POLICY_DENY',
                     change=lambda d: d.update(policies=[policy(action='deny', vlan=None)]))

                case('conflicting-allow-deny', reason='POLICY_CONFLICT',
                     change=lambda d: d.update(policies=[policy(), policy(id='deny', action='deny', vlan=None)]))
                case('conflicting-deny-allow', reason='POLICY_CONFLICT',
                     change=lambda d: d.update(policies=[policy(id='deny', action='deny', vlan=None), policy()]))

                def as_user(data):
                    data['accounts'][GUID]['kind'] = 'user'

                case('user-cannot-prove-computer', cert='user', reason='DOMAIN_DEVICE_REQUIRED', change=as_user)

                def allow_user(data):
                    as_user(data)
                    data['policies'][0]['constraints']['require_domain_device'] = False

                case('valid-user-policy', cert='user', expected=2, reason='POLICY_ALLOW', change=allow_user)
                case('revoked-certificate', cert='revoked')
                case('expired-certificate', cert='expired')
                case('untrusted-client-ca', cert='rogue')
                case('wrong-client-purpose', cert='wrong-purpose')
                case('untrusted-server-ca', ca='rogue-ca.pem')
                case('wrong-server-name', server_name='other.lab.example.test')
                for name, options in (
                    ('missing-message-authenticator', {'mac': 'missing'}),
                    ('invalid-message-authenticator', {}),
                    ('unknown-nas-source', {'source': '127.0.0.2', 'mac': 'valid'}),
                    ('non-eap-request', {'mac': 'valid', 'non_eap': True})):
                    facts.append(drop_case(port, secret, name, **options))
                if not debug:
                    case('crl-before-publication',expected=2,reason='POLICY_ALLOW')
                    raw = (root/'crl-native-revoked.pem').read_bytes()
                    crl = x509.load_pem_x509_crl(raw)
                    number = crl.extensions.get_extension_for_class(x509.CRLNumber).value.crl_number
                    with PKIService(root/'state').store.connect() as db:
                        db.execute('UPDATE pki_authority SET crl=?,crl_number=?',(raw,number))
                    publication = sync_crl(root/'state',root/'ca')
                    if publication['changed'] is not True:
                        raise AssertionError('Fresh CRL was not published')
                    # 3.2.10 clamps the native interval to >=300 seconds. Test
                    # that real interval without patching clocks or TLS code.
                    while time.monotonic() < process_started+306:
                        if process.poll() is not None:
                            raise AssertionError('RADIUS exited during CRL cache proof')
                        time.sleep(0.2)
                    case('crl-after-publication',expected=3)
                    events = [json.loads(line) for line in (root/'decisions.jsonl').read_text().splitlines()]
                    if any(e['case']=='crl-after-publication' for e in events):
                        raise AssertionError('CRL reject reached policy; native cache proof missing')
                    if process.poll() is not None:
                        raise AssertionError('RADIUS did not retain the running process')
                    facts[-1].update(native_crl_cache_reloaded=True,radius_process_preserved=True)
        finally:
            if relay:
                relay.close()
            if process:
                process.terminate()
                try:
                    process.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=3)
    packages = subprocess.run(['dpkg-query', '-W', '-f=${Package}=${Version}\n',
                               'eapoltest', 'libssl3t64', 'libpython3.12t64'],
                              capture_output=True, check=True).stdout.decode().splitlines()
    if len(packages) != 3 or any(line.endswith('=') for line in packages):
        raise RuntimeError('Native dependency version evidence is incomplete')
    return {'version': VERSION, 'freeradius_version': '3.2.10', 'test_packages': packages,
            'freeradius_source_commit': FREE_RADIUS_COMMIT,
            'server_mode': 'debug' if debug else 'normal',
            'upstream_patches': ['58bafac6e5d4eb098d533cc0e7fe2fd41a73d213'],
            'transport': 'loopback UDP with native FreeRADIUS and eapol_test',
            'tls_version': '1.2', 'fixture_ad_only': True, 'real_ad_tested': False,
            'physical_wired_wireless_tested': False, 'client_enrollment_enabled': False,
            'production_radius_enabled': False, 'secrets_exported': False,
            'persistent_registry_tested': True,
            'case_count': len(facts), 'cases': facts}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--radius-prefix', type=Path, required=True)
    parser.add_argument('--report', type=Path, required=True)
    parser.add_argument('--debug', action='store_true', help='Also support the explicit debug-mode comparison')
    args = parser.parse_args()
    result = run_lab(args.radius_prefix.resolve(), debug=args.debug)
    private_file(args.report, json.dumps(result, indent=2) + '\n')
    print('KANAME_RADIUS_REPORT_BEGIN')
    print(json.dumps(result, indent=2))
    print('KANAME_RADIUS_REPORT_END')


if __name__ == '__main__':
    main()

