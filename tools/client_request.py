"""Create an endpoint-owned encrypted key and extension-free user CSR offline."""
import argparse
import getpass
import hmac
from pathlib import Path

from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.x509.oid import NameOID

from kaname.pki import password_bytes, private_pem, write_new


def create(directory, password):
    password_bytes(password)
    target = Path(directory).absolute()
    target.mkdir(mode=0o700)  # Never overwrite an endpoint's existing key.
    key = ec.generate_private_key(ec.SECP256R1())
    csr = (x509.CertificateSigningRequestBuilder()
           .subject_name(x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, 'AuthWire user request')]))
           .sign(key, hashes.SHA256()))
    write_new(target / 'client-key.pem', private_pem(key, password))
    write_new(target / 'client-request.pem', csr.public_bytes(serialization.Encoding.PEM))
    return target


def main():
    parser = argparse.ArgumentParser(description='Run on the endpoint; only send the CSR to AuthWire')
    parser.add_argument('--directory', required=True)
    args = parser.parse_args()
    try:
        password = password_bytes(getpass.getpass('İstemci anahtar parolası (en az 16 byte): ').encode('utf-8'))
        if not hmac.compare_digest(password, getpass.getpass('Parolayı tekrar girin: ').encode('utf-8')):
            raise ValueError()
        create(args.directory, password)
        print('CSR hazır. Panele yalnız client-request.pem gönderin; client-key.pem endpoint üzerinde kalır.')
    except (ValueError, OSError, EOFError, KeyboardInterrupt):
        parser.exit(1, 'İstek oluşturulamadı; mevcut klasör/anahtar üzerine yazılmadı.\n')


if __name__ == '__main__':
    main()
