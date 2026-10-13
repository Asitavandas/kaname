"""Generate ephemeral production FreeRADIUS configuration from AuthWire state.

Secrets are decrypted only into the systemd RuntimeDirectory. Persistent product
state keeps them sealed. This module never starts a listener by itself.
"""
import argparse
import ipaddress
import os
from pathlib import Path
import re
import subprocess

import cryptography
from cryptography import x509
from cryptography.hazmat.primitives import serialization
from cryptography.x509.oid import ExtendedKeyUsageOID

from kaname.models import dns_name
from kaname.operations import Operations
from kaname.pki import PKIService
from kaname.store import Store


STATE = Path('/var/lib/kaname-lab')


def private_file(path, content):
    if type(content) is str:
        content = content.encode()
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    with os.fdopen(descriptor, 'wb') as handle:
        handle.write(content)


def _server_material(state, fqdn):
    directory = state / 'radius'
    key_path, cert_path = directory / 'server-key.pem', directory / 'server.pem'
    for path in (directory, key_path, cert_path):
        if path.is_symlink():
            raise ValueError('RADIUS server material symlink refused')
    if not directory.is_dir() or not key_path.is_file() or not cert_path.is_file():
        raise ValueError('RADIUS server certificate is not initialized')
    if key_path.stat().st_mode & 0o077:
        raise ValueError('RADIUS private key permissions are too broad')
    key = serialization.load_pem_private_key(key_path.read_bytes(), password=None)
    cert = x509.load_pem_x509_certificate(cert_path.read_bytes())
    if cert.public_key().public_bytes(serialization.Encoding.DER, serialization.PublicFormat.SubjectPublicKeyInfo) != key.public_key().public_bytes(
            serialization.Encoding.DER, serialization.PublicFormat.SubjectPublicKeyInfo):
        raise ValueError('RADIUS certificate/private key mismatch')
    san = cert.extensions.get_extension_for_class(x509.SubjectAlternativeName).value
    if san.get_values_for_type(x509.DNSName) != [fqdn]:
        raise ValueError('RADIUS certificate name mismatch')
    eku = cert.extensions.get_extension_for_class(x509.ExtendedKeyUsage).value
    if set(eku) != {ExtendedKeyUsageOID.SERVER_AUTH}:
        raise ValueError('RADIUS certificate purpose mismatch')
    return key_path.read_bytes(), cert_path.read_bytes()


def generate(output, prefix, state=STATE, listen_ip='127.0.0.1'):
    output, prefix, state = Path(output), Path(prefix), Path(state)
    listen = ipaddress.ip_address(listen_ip)
    if listen.version != 4 or listen.is_unspecified or listen.is_multicast:
        raise ValueError('A specific unicast IPv4 RADIUS listen address is required')
    listen_ip = str(listen)
    if output.is_symlink() or not output.is_dir() or output.stat().st_mode & 0o077:
        raise ValueError('Private runtime directory required')
    if prefix.is_symlink() or not prefix.is_dir():
        raise ValueError('Pinned FreeRADIUS prefix required')
    modules = list(prefix.rglob('rlm_python3.so'))
    dictionary = prefix / 'share' / 'freeradius' / 'dictionary'
    radiusd = prefix / 'sbin' / 'radiusd'
    if len(modules) != 1 or not dictionary.is_file() or not radiusd.is_file():
        raise ValueError('Pinned FreeRADIUS runtime incomplete')

    store = Store(state)
    operations = Operations(store)
    snapshot = store.snapshot()
    config = snapshot['config']
    if config is None:
        raise ValueError('AuthWire configuration missing')
    fqdn = dns_name(config['appliance_fqdn'])
    network = operations.network()
    clients = network['radius_clients']
    if not clients:
        raise ValueError('At least one RADIUS client is required')
    if any(not client.get('secret_saved') for client in clients):
        raise ValueError('Every RADIUS client requires a shared secret')

    key_pem, cert_pem = _server_material(state, fqdn)
    bundle = PKIService(state).public_bundle()
    issuer = x509.load_pem_x509_certificate(bundle['issuer-ca.pem'])
    leaf = x509.load_pem_x509_certificate(cert_pem)
    leaf.verify_directly_issued_by(issuer)

    certdir, cadir = output / 'certs', output / 'ca'
    mods, sites = output / 'mods-enabled', output / 'sites-enabled'
    for directory in (certdir, cadir, mods, sites):
        directory.mkdir(mode=0o700)
    private_file(certdir / 'server-key.pem', key_pem)
    private_file(certdir / 'server.pem', cert_pem + bundle['issuer-ca.pem'])
    for name in ('root-ca.pem', 'issuer-ca.pem', 'issuer-crl.pem'):
        private_file(cadir / name, bundle[name])
    subprocess.run(['/usr/bin/openssl', 'rehash', str(cadir)], check=True, capture_output=True, timeout=10)

    client_lines = []
    for index, client in enumerate(clients, 1):
        secret = operations.radius_secret(client['ip'], audit=False)
        try:
            client_lines.append(f'''client authwire_{index:03d} {{
 ipaddr = {client["ip"]}
 secret = {secret}
 require_message_authenticator = yes
 limit_proxy_state = yes
}}
''')
        finally:
            secret = ''
    private_file(output / 'clients.conf', ''.join(client_lines))

    source = Path(__file__).resolve().parents[1]
    # rlm_python3 ignores the venv interpreter's PYTHONPATH and defaults to
    # appending module paths after distro packages. Pin the same dependency
    # directory used by this generator, before importing the authorization code.
    dependencies = Path(cryptography.__file__).resolve().parent.parent
    for path in (output, prefix, source, dependencies):
        if not re.fullmatch(r'[A-Za-z0-9_./-]+', str(path)):
            raise ValueError('RADIUS runtime path contains unsafe characters')
    prefix_text = str(prefix)
    module_dir = str(modules[0].parent)
    private_file(output / 'dictionary', '$INCLUDE ' + str(dictionary) + '\n')
    private_file(output / 'radiusd.conf', f'''prefix = {prefix_text}
name = authwire-radius
raddbdir = {output}
confdir = ${{raddbdir}}
modconfdir = ${{raddbdir}}
certdir = ${{raddbdir}}/certs
cadir = ${{raddbdir}}/ca
libdir = {module_dir}
logdir = {output}
run_dir = {output}
pidfile = ${{run_dir}}/radiusd.pid
max_request_time = 10
cleanup_delay = 1
max_requests = 1024
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

    private_file(mods / 'eap', '''eap {
 default_eap_type = tls
 timer_expire = 15
 ignore_unknown_eap_types = no
 max_sessions = 1024
 tls-config authwire-tls {
  private_key_file = ${certdir}/server-key.pem
  certificate_file = ${certdir}/server.pem
  ca_file = ${cadir}/root-ca.pem
  ca_path = ${cadir}
  ca_path_reload_interval = 300
  auto_chain = no
  check_crl = yes
  allow_expired_crl = no
  reject_unknown_intermediate_ca = yes
  tls_min_version = "1.2"
  fragment_size = 1024
  cache {
   enable = no
  }
 }
 tls {
  tls = authwire-tls
  require_client_cert = yes
  virtual_server = authwire-cert-check
 }
}
''')
    private_file(mods / 'python3', f'''python3 authwire_authorize {{
 python_path = "{source}:{dependencies}"
 python_path_mode = prepend
 module = kaname.radius_adapter
 mod_authorize = ${{.module}}
 func_authorize = authorize
}}
''')
    private_file(mods / 'reject', 'always reject {\n rcode = reject\n}\n')

    auth_port = network['authentication_port']
    private_file(sites / 'authwire', f'''server authwire-radius {{
 listen {{
  type = auth
  ipaddr = {listen_ip}
  port = {auth_port}
 }}
 authorize {{
  if (!&EAP-Message) {{
   reject
  }}
  update request {{
   Packet-Src-IP-Address := "%{{Packet-Src-IP-Address}}"
  }}
  eap
 }}
 authenticate {{
  eap
 }}
}}
server authwire-cert-check {{
 authorize {{
  update control {{
   Auth-Type := Reject
  }}
  authwire_authorize
 }}
}}
''')
    return {'generated': True, 'authentication_port': auth_port, 'clients': len(clients),
            'accounting_enabled': False, 'fqdn': fqdn, 'listen_ip': listen_ip}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--output', required=True)
    parser.add_argument('--prefix', required=True)
    parser.add_argument('--state-dir', default=str(STATE))
    parser.add_argument('--listen-ip', required=True)
    args = parser.parse_args()
    print(generate(args.output, args.prefix, args.state_dir, args.listen_ip))


if __name__ == '__main__':
    main()

