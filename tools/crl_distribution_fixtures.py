"""Synthetic public Windows CRL fixtures. No customer authority or private output."""
import argparse
import base64
from datetime import timedelta
import json
from pathlib import Path
import tempfile

from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa

from kaname.pki import PKIService, instant


def fixtures():
    now = instant().replace(microsecond=0)
    with tempfile.TemporaryDirectory() as state:
        pki = PKIService(state); password=b'crl-fixture-only-password'; pki.initialize(password, now=now-timedelta(days=2))
        with pki.store.connect() as db:
            row=db.execute('SELECT root_cert,issuer_cert,root_key,issuer_key FROM pki_authority').fetchone()
        root,issuer=(x509.load_pem_x509_certificate(x) for x in row[:2])
        rootkey,issuerkey=(serialization.load_pem_private_key(x,password) for x in row[2:])
    def b64(raw): return base64.b64encode(raw).decode()
    def crl(cert,key,number=9,entries=(12345,),at=None,days=1,extra=()):
        at=at or now-timedelta(minutes=1)
        b=(x509.CertificateRevocationListBuilder().issuer_name(cert.subject).last_update(at).next_update(at+timedelta(days=days))
           .add_extension(x509.CRLNumber(number),False).add_extension(x509.AuthorityKeyIdentifier.from_issuer_public_key(key.public_key()),False))
        for serial in entries:
            b=b.add_revoked_certificate(x509.RevokedCertificateBuilder().serial_number(serial).revocation_date(now-timedelta(days=1))
              .add_extension(x509.CRLReason(x509.ReasonFlags.key_compromise),False).build())
        for ext,critical in extra: b=b.add_extension(ext,critical)
        return b64(b.sign(key,hashes.SHA256()).public_bytes(serialization.Encoding.DER))
    return dict(now=now.isoformat(),root=b64(root.public_bytes(serialization.Encoding.DER)),issuer=b64(issuer.public_bytes(serialization.Encoding.DER)),
        root_crl=crl(root,rootkey,number=1,entries=(),days=30),issuer_crl=crl(issuer,issuerkey),
        previous=crl(issuer,issuerkey,number=8,at=now-timedelta(hours=2)),
        newer=crl(issuer,issuerkey,number=10,at=now),
        rollback=crl(issuer,issuerkey,number=7),lost_revocation=crl(issuer,issuerkey,number=10,entries=()),
        reused_number=crl(issuer,issuerkey,entries=(12345,23456)),
        expired=crl(issuer,issuerkey,at=now-timedelta(days=2)),future=crl(issuer,issuerkey,at=now+timedelta(minutes=1)),
        forged=crl(issuer,rsa.generate_private_key(65537,3072)),
        revoked_issuer=crl(root,rootkey,number=2,entries=(issuer.serial_number,),days=30),
        delta=crl(issuer,issuerkey,extra=((x509.DeltaCRLIndicator(8),False),)),
        critical=crl(issuer,issuerkey,extra=((x509.UnrecognizedExtension(x509.ObjectIdentifier('1.2.3.4.5'),b'\x05\x00'),True),)))


if __name__=='__main__':
    parser=argparse.ArgumentParser(); parser.add_argument('output'); args=parser.parse_args()
    path=Path(args.output)
    with path.open('x',encoding='utf-8') as out: json.dump(fixtures(),out)
