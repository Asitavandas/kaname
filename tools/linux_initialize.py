"""Service-account state bootstrap; never migrate/reset an existing installation."""
import argparse
import ipaddress
import json
from datetime import datetime, timedelta, timezone
from pathlib import Path

from kaname.admin import AdminStore
from kaname.store import Store


def initialize(root, domain, dc_ip, name):
    store = Store(root)
    expected = {'appliance_fqdn': name, 'ad_domain': domain, 'dc_ips': [dc_ip],
                'radius_clients': [], 'access_modes': ['wired', 'wireless']}
    snapshot = store.snapshot()
    if snapshot['config'] is None:
        store.save(snapshot['revision'], config=expected)
    elif any(snapshot['config'][key] != expected[key] for key in ('appliance_fqdn', 'ad_domain', 'dc_ips')):
        raise ValueError('Existing configuration differs; automatic replacement refused')
    AdminStore(store)
    return {'state_ready': True, 'existing_policies_preserved': True}


def create_web_certificate(directory, name, listen):
    from cryptography import x509
    from cryptography.hazmat.primitives import hashes, serialization
    from cryptography.hazmat.primitives.asymmetric import ec
    from cryptography.x509.oid import ExtendedKeyUsageOID, NameOID
    directory = Path(directory)
    cert_path, key_path = directory / 'web.crt', directory / 'web.key'
    if cert_path.exists() or key_path.exists():
        raise ValueError('Existing TLS files are preserved; overwrite refused')
    key = ec.generate_private_key(ec.SECP256R1())
    subject = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, name)])
    now = datetime.now(timezone.utc)
    cert = (x509.CertificateBuilder().subject_name(subject).issuer_name(subject)
            .public_key(key.public_key()).serial_number(x509.random_serial_number())
            .not_valid_before(now - timedelta(minutes=5)).not_valid_after(now + timedelta(days=365))
            .add_extension(x509.SubjectAlternativeName([x509.DNSName(name), x509.IPAddress(ipaddress.ip_address(listen))]), False)
            .add_extension(x509.BasicConstraints(ca=False, path_length=None), True)
            .add_extension(x509.ExtendedKeyUsage([ExtendedKeyUsageOID.SERVER_AUTH]), False)
            .sign(key, hashes.SHA256()))
    with key_path.open('xb') as handle:
        handle.write(key.private_bytes(serialization.Encoding.PEM, serialization.PrivateFormat.PKCS8, serialization.NoEncryption()))
    key_path.chmod(0o600)
    with cert_path.open('xb') as handle:
        handle.write(cert.public_bytes(serialization.Encoding.PEM))
    cert_path.chmod(0o644)
    return cert.fingerprint(hashes.SHA256()).hex()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--state-dir', required=True)
    parser.add_argument('--domain', required=True)
    parser.add_argument('--dc-ip', required=True)
    parser.add_argument('--name', required=True)
    parser.add_argument('--certificate-dir')
    parser.add_argument('--listen')
    args = parser.parse_args()
    if args.certificate_dir:
        print(json.dumps({'certificate_sha256': create_web_certificate(args.certificate_dir, args.name, args.listen)}))
    else:
        print(json.dumps(initialize(args.state_dir, args.domain, args.dc_ip, args.name)))


if __name__ == '__main__':
    main()
