"""rlm_python3 callback ONLY for the temporary loopback protocol laboratory.

No fixture provider is installed/enabled in KANAME's panel or an appliance.
The harness supplies a fresh CA and ephemeral directory/binding data. This
does not authenticate AD, and it never loads a real KANAME state directory.
"""
import json
from pathlib import Path

from kaname.models import strict_json
from kaname.policy import Decision
from kaname.radius import (CertificateBinding, CertificateReference, CurrentDirectoryAccount,
                           DirectoryUnavailable, TLSAuthorization, freeradius_result)


def scalar(pairs, name):
    values = [v for k, v in pairs if k == name]
    if len(values) != 1 or type(values[0]) is not str:
        raise ValueError('Missing/duplicate native certificate field')
    value = values[0]
    # FreeRADIUS's string formatter quotes string values passed to Python.
    if value.startswith('"') and value.endswith('"'):
        value = value[1:-1]
    if '"' in value or '\\' in value or any(ord(c) < 32 for c in value):
        raise ValueError('Invalid native certificate field')
    return value


def authorize(pairs, root):
    import radiusd  # Provided by embedded FreeRADIUS, not a PyPI package.
    root = Path(root)
    decision = Decision('deny', 'FIXTURE_ADAPTER_FAILED')
    try:
        if (root / 'LAB_ONLY').read_text() != 'KANAME temporary loopback EAP-TLS laboratory\n':
            raise ValueError('Not a protocol laboratory')
        data = strict_json((root / 'fixture.json').read_bytes())
        if data['lab_only'] is not True or data['nas_ip'] != '127.0.0.1':
            raise ValueError('Only a loopback fixture is supported')
        if scalar(pairs, 'TLS-Client-Cert-Issuer') != data['issuer_dn']:
            decision = Decision('deny', 'CERTIFICATE_ISSUER_MISMATCH')
        else:
            cert = CertificateReference(data['issuer_sha256'], scalar(pairs, 'TLS-Client-Cert-Serial'))

            class Registry:
                def lookup(self, reference):
                    row = data['bindings'].get(reference.serial)
                    return CertificateBinding(reference, **row) if row else None

            class Directory:
                def lookup(self, domain, guid):
                    # Deliberately synthetic. The runtime must use a LIVE AD provider.
                    if not data['directory_available']:
                        raise DirectoryUnavailable()
                    row = data['accounts'].get(guid)
                    if row is None:
                        return None
                    row = dict(row)
                    row['security_group_sids'] = frozenset(row['security_group_sids'])
                    return CurrentDirectoryAccount(**row)

            service = TLSAuthorization(data['policies'], registry=Registry(), directory=Directory())
            decision = service.authorize(cert, nas_ip=data['nas_ip'], access_type=data['access_type'])
        reply, config = freeradius_result(decision)
        event = {'case': data['case'], 'action': decision.action, 'reason': decision.reason,
                 'policy_id': decision.policy_id, 'vlan': decision.vlan}
        with (root / 'decisions.jsonl').open('a') as handle:
            handle.write(json.dumps(event) + '\n')
        return radiusd.RLM_MODULE_OK, reply, config
    except Exception:
        # Native integration failures are always a Reject, never a bypass.
        reply, config = freeradius_result(decision)
        return radiusd.RLM_MODULE_OK, reply, config
