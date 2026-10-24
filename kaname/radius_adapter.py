"""Production FreeRADIUS EAP-TLS authorization adapter.

Only native FreeRADIUS certificate fields and the actual packet source IP are
accepted as authorization inputs. Outer identity and NAS-IP-Address attributes
are never trusted. Any integration error fails closed.
"""
from pathlib import Path

from cryptography import x509
from cryptography.hazmat.primitives import hashes

from .access_groups import AccessGroups
from .operations import Operations
from .policy import Decision
from .radius import CertificateReference, TLSAuthorization, freeradius_result
from .radius_directory import LiveDirectory
from .radius_registry import CertificateRegistry
from .store import Store


STATE = Path('/var/lib/kaname-lab')


def scalar(pairs, name):
    values = [value for key, value in pairs if key == name]
    if len(values) != 1 or type(values[0]) is not str:
        raise ValueError('Missing or duplicate trusted RADIUS field')
    value = values[0]
    # rlm_python3 may quote string values before handing them to Python.
    if value.startswith('"') and value.endswith('"'):
        value = value[1:-1]
    if not value or '"' in value or '\\' in value or any(ord(c) < 32 for c in value):
        raise ValueError('Invalid trusted RADIUS field')
    return value


def issuer_sha256(store):
    with store.connect() as db:
        row = db.execute('SELECT issuer_cert FROM pki_authority WHERE id=1').fetchone()
    if row is None:
        raise ValueError('PKI issuer unavailable')
    issuer = x509.load_pem_x509_certificate(row[0])
    return issuer.fingerprint(hashes.SHA256()).hex()


def client_context(operations, source_ip):
    network = operations.network()
    matches = [client for client in network['radius_clients'] if client['ip'] == source_ip]
    if len(matches) != 1 or not matches[0].get('secret_saved'):
        raise ValueError('Unregistered RADIUS source')
    return matches[0]['access_type']


def decision_for_pairs(pairs, *, state=STATE, directory_factory=LiveDirectory):
    store = Store(state)
    operations = Operations(store)
    source_ip = scalar(pairs, 'Packet-Src-IP-Address')
    access_type = client_context(operations, source_ip)
    reference = CertificateReference(issuer_sha256(store), scalar(pairs, 'TLS-Client-Cert-Serial'))
    service = TLSAuthorization(
        store.snapshot()['policies'],
        registry=CertificateRegistry(store),
        directory=directory_factory(operations),
        local_groups=AccessGroups(operations),
    )
    return service.authorize(reference, nas_ip=source_ip, access_type=access_type)


def authorize(pairs):
    import radiusd  # Provided by the embedded FreeRADIUS runtime.
    try:
        decision = decision_for_pairs(pairs)
    except Exception:
        decision = Decision('deny', 'RADIUS_ADAPTER_FAILED')
    reply, config = freeradius_result(decision)
    return radiusd.RLM_MODULE_OK, reply, config
