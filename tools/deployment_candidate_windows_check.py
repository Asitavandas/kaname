"""Real WinPS 5.1 signing/NTFS fixture using public synthetic network profile data."""
import ast
from datetime import datetime, timedelta, timezone
import hashlib
import io
import json
import os
from pathlib import Path
import subprocess
import tempfile
import uuid
import zipfile
from xml.etree import ElementTree as ET

from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.x509.oid import NameOID


def fixtures(directory):
    # Exercise the product's actual network XML generator without loading a DB.
    source = ast.parse(Path('kaname/deployment.py').read_text(encoding='utf-8'))
    module = ast.Module(body=[next(n for n in source.body if isinstance(n, ast.FunctionDef) and n.name == 'network_xml')], type_ignores=[])
    namespace = {'ET': ET}
    exec(compile(module, 'kaname/deployment.py', 'exec'), namespace)
    now = datetime.now(timezone.utc)
    root_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    issuer_key = rsa.generate_private_key(public_exponent=65537, key_size=2048)
    name = x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, 'Isolated AuthWire fixture root')])
    root = x509.CertificateBuilder().subject_name(name).issuer_name(name).public_key(root_key.public_key()).serial_number(x509.random_serial_number()).not_valid_before(now-timedelta(hours=1)).not_valid_after(now+timedelta(days=2)).add_extension(x509.BasicConstraints(ca=True, path_length=1), critical=True).add_extension(x509.KeyUsage(False, False, False, False, False, True, True, False, False), critical=True).sign(root_key, hashes.SHA256())
    issuer = x509.CertificateBuilder().subject_name(x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, 'Isolated AuthWire fixture issuer')])).issuer_name(name).public_key(issuer_key.public_key()).serial_number(x509.random_serial_number()).not_valid_before(now-timedelta(hours=1)).not_valid_after(now+timedelta(days=1)).add_extension(x509.BasicConstraints(ca=True, path_length=0), critical=True).add_extension(x509.KeyUsage(False, False, False, False, False, True, True, False, False), critical=True).sign(root_key, hashes.SHA256())
    approval = dict(format=1, zip_sha256='0'*64, plan_id=str(uuid.uuid4()), plan_version=1, preview_hash='1'*64, machine_profile_id=str(uuid.uuid4()), machine_profile_version=3, group_sid='S-1-5-21-111-222-333-1647', domain='fixture.example', server_name='radius.fixture.example', ssid='AuthWire & Test', root_thumbprint=root.fingerprint(hashes.SHA1()).hex().upper(), connector_id=str(uuid.uuid4()), service_sid='S-1-5-21-111-222-333-1648', gpo_id=str(uuid.uuid4()), protected_gpo_id=str(uuid.uuid4()), publisher_thumbprint='A'*40)
    plan = dict(id=approval['plan_id'], version=1, machine_profile_id=approval['machine_profile_id'], computer_group_sid=approval['group_sid'], domain=approval['domain'], server_name=approval['server_name'], ssid=approval['ssid'], auth_mode='machine', user_profile_id='', wired=True, wireless=True)
    profile = dict(id=approval['machine_profile_id'], version=3, domain=approval['domain'], group_sid=approval['group_sid'], enabled=1)
    snapshot = dict(id=plan['id'], version=1, preview_hash=approval['preview_hash'], domain=approval['domain'], runtime_applied=False, gpo_changed=False, can_apply=False, can_export_profiles=True, artifact_blockers=[], plan=plan, enrollment_profiles=[profile], computer_targets=dict(available=True, enabled=2, count=2, unresolved=0), user_targets=None, trust=dict(ready=True, root_thumbprint=root.fingerprint(hashes.SHA1()).hex(), root_sha256=root.fingerprint(hashes.SHA256()).hex()))
    files = {'README.txt': b'Network preparation, not endpoint or GPO execution.', 'root-ca.pem': root.public_bytes(serialization.Encoding.PEM), 'issuer-ca.pem': issuer.public_bytes(serialization.Encoding.PEM), 'plan.json': json.dumps(snapshot).encode()}
    for wireless, filename in [(False, 'Wired-EAP-TLS.xml'), (True, 'WiFi-EAP-TLS.xml')]:
        files[filename] = namespace['network_xml'](plan, root.fingerprint(hashes.SHA1()).hex(), wireless=wireless)

    def archive(values, *, duplicate=False):
        values = dict(values)
        manifest = dict(format=1, plan_id=plan['id'], version=1, preview_hash=approval['preview_hash'], files={n: hashlib.sha256(v).hexdigest() for n, v in values.items()})
        values['manifest.json'] = json.dumps(manifest).encode()
        output = io.BytesIO()
        with zipfile.ZipFile(output, 'w', zipfile.ZIP_DEFLATED) as z:
            for n, v in values.items(): z.writestr(n, v)
            if duplicate: z.writestr('README.txt', values['README.txt'])
        return output.getvalue()

    cases = {'good': archive(files), 'extra': archive({**files, '../outside.ps1': b'whoami'}), 'duplicate': archive(files, duplicate=True), 'oversized': archive({**files, 'README.txt': b'A'*65537})}
    for field, before, after in [('xml_no_validation', b'>true</PerformServerValidation>', b'>false</PerformServerValidation>'), ('xml_wrong_server', b'radius.fixture.example', b'attacker.fixture.example'), ('xml_extra', b'</LANProfile>', b'<Extra>bad</Extra></LANProfile>')]:
        changed = dict(files); changed['Wired-EAP-TLS.xml'] = changed['Wired-EAP-TLS.xml'].replace(before, after)
        assert changed != files
        cases[field] = archive(changed)
    cases['xml_dtd'] = archive({**files, 'Wired-EAP-TLS.xml': b'<!DOCTYPE LANProfile [<!ENTITY x "bad">]><LANProfile>&x;</LANProfile>'})
    bad_plan = json.loads(files['plan.json']); bad_plan['plan']['wired'] = 'true'
    cases['typed_boolean'] = archive({**files, 'plan.json': json.dumps(bad_plan).encode()})
    cases['duplicate_json'] = archive({**files, 'plan.json': files['plan.json'].replace(b'"can_apply": false', b'"can_apply": true, "can_apply": false')})
    broken = bytearray(files['issuer-ca.pem']); pos = broken.find(b'\n')+20; broken[pos] = ord('A') if broken[pos] != ord('A') else ord('B')
    cases['bad_ca'] = archive({**files, 'issuer-ca.pem': bytes(broken)})
    # Keep the ZIP pin correct but break one internal manifest entry.
    output = io.BytesIO()
    with zipfile.ZipFile(io.BytesIO(cases['good'])) as z, zipfile.ZipFile(output, 'w') as out:
        for n in z.namelist(): out.writestr(n, z.read(n) + (b'changed' if n == 'README.txt' else b''))
    cases['bad_manifest'] = output.getvalue()
    for case, content in cases.items(): (directory/(case+'.zip')).write_bytes(content)
    approval['zip_sha256'] = hashlib.sha256(cases['good']).hexdigest()
    (directory/'approval.json').write_text(json.dumps(approval), encoding='utf-8')


if __name__ == '__main__':
    if os.name != 'nt' or os.environ.get('RUNNER_ENVIRONMENT') != 'github-hosted':
        raise SystemExit('Disposable GitHub-hosted Windows only')
    with tempfile.TemporaryDirectory(prefix='authwire-candidate-') as temp:
        directory = Path(temp)
        fixtures(directory)
        # A pwsh CI parent otherwise passes its incompatible module search path
        # into Windows PowerShell 5.1. Match the existing native service fixture.
        environment = {k: v for k, v in os.environ.items() if k.upper() != 'PSMODULEPATH'}
        powershell = str(Path(os.environ['SystemRoot'])/'System32/WindowsPowerShell/v1.0/powershell.exe')
        subprocess.run([powershell, '-NoProfile', '-NonInteractive', '-File', 'tools/deployment_candidate_windows_fixture.ps1', '-FixtureDirectory', str(directory)], env=environment, check=True, timeout=180)
