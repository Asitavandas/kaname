"""Read-only publication of signed public revocation lists; never unlocks a CA."""
import base64

from cryptography.hazmat.primitives.serialization import Encoding

from .pki import PKIError, instant
from .root_crl import RootCRLService, authority, stored, validate_crl


def public_crls(state, *, now=None):
    now = instant(now)
    # One read-only SQLite snapshot keeps the authority and both CRLs together.
    with RootCRLService(state).connect() as db:
        row = db.execute('SELECT root_cert,issuer_cert,crl,crl_number FROM pki_authority WHERE id=1').fetchone()
        if row is None:
            raise PKIError('AUTHORITY_MISSING')
        root, issuer = authority(row[0], row[1], now)
        if not issuer.not_valid_before_utc <= now < issuer.not_valid_after_utc:
            raise PKIError('ISSUER_NOT_CURRENT')
        root_list = stored(db, root, now)
        if root_list is None:
            raise PKIError('ROOT_CRL_MISSING')
        if root_list[0].get_revoked_certificate_by_serial_number(issuer.serial_number) is not None:
            raise PKIError('ISSUER_REVOKED_BY_ROOT')
        # The same signature, AKI, scope, freshness and entry checks apply to
        # the issuer CRL. This function reads no private-key columns.
        issuer_list = validate_crl(row[2], issuer, now)
        if type(row[3]) is not int or issuer_list[1] != row[3]:
            raise PKIError('ISSUER_CRL_LEDGER_MISMATCH')
        result = {'version': 1}
        for name, (crl, _) in (('root_crl', root_list), ('issuer_crl', issuer_list)):
            der = crl.public_bytes(Encoding.DER)
            if len(der) > 1048576 or len(crl) > 25000:
                raise PKIError('CRL_PUBLIC_LIMIT')
            result[name] = base64.b64encode(der).decode('ascii')
        return result
