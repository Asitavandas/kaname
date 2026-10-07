"""Initialize the persistent AuthWire RADIUS server certificate once.

The private key is generated locally under the existing protected AuthWire state
directory and never leaves the appliance. Existing material is never overwritten.
"""
import argparse
import getpass
import os
from pathlib import Path

from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa

from kaname.models import dns_name
from kaname.pki import PKIService, password_bytes
from kaname.store import Store


STATE = Path('/var/lib/kaname-lab')


def write_new(path, data):
    descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600)
    with os.fdopen(descriptor, 'wb') as handle:
        handle.write(data)


def initialize(state, password, days=90):
    state = Path(state)
    password = password_bytes(password)
    snapshot = Store(state).snapshot()
    if snapshot['config'] is None:
        raise ValueError('AuthWire configuration missing')
    fqdn = dns_name(snapshot['config']['appliance_fqdn'])
    directory = state / 'radius'
    if directory.is_symlink():
        raise ValueError('RADIUS state symlink refused')
    directory.mkdir(mode=0o700, exist_ok=True)
    if directory.stat().st_mode & 0o077:
        raise ValueError('Private RADIUS state directory required')
    key_path, cert_path = directory / 'server-key.pem', directory / 'server.pem'
    if key_path.exists() or cert_path.exists():
        raise ValueError('RADIUS server material already exists; overwrite refused')

    key = rsa.generate_private_key(public_exponent=65537, key_size=3072)
    csr = (x509.CertificateSigningRequestBuilder()
           .subject_name(x509.Name([]))
           .add_extension(x509.SubjectAlternativeName([x509.DNSName(fqdn)]), critical=False)
           .sign(key, hashes.SHA256()))
    cert_pem = PKIService(state).issue_radius(
        csr.public_bytes(serialization.Encoding.PEM), password, days=days)
    key_pem = key.private_bytes(
        serialization.Encoding.PEM,
        serialization.PrivateFormat.PKCS8,
        serialization.NoEncryption())
    try:
        write_new(key_path, key_pem)
        write_new(cert_path, cert_pem)
    except Exception:
        if cert_path.exists():
            cert_path.unlink()
        if key_path.exists():
            key_path.unlink()
        raise
    cert = x509.load_pem_x509_certificate(cert_pem)
    return {'initialized': True, 'serial': format(cert.serial_number, 'x'),
            'not_after': cert.not_valid_after_utc.isoformat(), 'fqdn': fqdn}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--state-dir', default=str(STATE))
    parser.add_argument('--days', type=int, default=90)
    args = parser.parse_args()
    first = getpass.getpass('AuthWire CA password: ').encode()
    try:
        print(initialize(args.state_dir, first, args.days))
    finally:
        first = b''


if __name__ == '__main__':
    main()
