"""Disposable combined signer fixtures, actual native Windows PowerShell 5.1."""
import hashlib
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import uuid
import zipfile

sys.path.insert(0,str(Path(__file__).resolve().parents[1]))

from types import SimpleNamespace
from datetime import datetime,timedelta,timezone
from cryptography import x509
from cryptography.hazmat.primitives import hashes,serialization
from cryptography.hazmat.primitives.asymmetric import rsa
from cryptography.x509.oid import NameOID
from kaname.device_enrollment import DeviceEnrollment
from tools.deployment_candidate_windows_check import fixtures

def main():
    if os.name != 'nt' or os.environ.get('RUNNER_ENVIRONMENT') != 'github-hosted':
        raise SystemExit('Hosted Windows fixture only')
    with tempfile.TemporaryDirectory(prefix='AuthWire-Combined-Fixture-') as root:
            path=Path(root)
            fixtures(path)
            network=(path/'good.zip').read_bytes()
            with zipfile.ZipFile(io.BytesIO(network)) as z:
                network_files={n:z.read(n) for n in z.namelist()}
            approval=json.loads((path/'approval.json').read_text())
            now=datetime.now(timezone.utc);key=rsa.generate_private_key(public_exponent=65537,key_size=2048)
            name=x509.Name([x509.NameAttribute(NameOID.COMMON_NAME,'kaname.fixture.example')])
            tls=x509.CertificateBuilder().subject_name(name).issuer_name(name).public_key(key.public_key()).serial_number(x509.random_serial_number()).not_valid_before(now-timedelta(hours=1)).not_valid_after(now+timedelta(days=1)).add_extension(x509.SubjectAlternativeName([x509.DNSName('kaname.fixture.example')]),critical=False).sign(key,hashes.SHA256()).public_bytes(serialization.Encoding.PEM)
            profile={'domain':approval['domain']}
            context=SimpleNamespace(profile=lambda identity:profile,pki=SimpleNamespace(public_bundle=lambda:{n:network_files[n] for n in ('root-ca.pem','issuer-ca.pem')}))
            enrollment=DeviceEnrollment.package(context,approval['machine_profile_id'],hostname='kaname.fixture.example',port=8765,tls_pem=tls)
            with zipfile.ZipFile(io.BytesIO(enrollment)) as z:
                items={'enrollment/'+n:z.read(n) for n in z.namelist()}
            items.update({'network/'+n:b for n,b in network_files.items()})
            items['network-profiles.zip']=network;items['README.txt']=b'Unsigned local fixture.'
            manifest=dict(format='AuthWireMachineDeploymentDraftV1',plan_id=approval['plan_id'],plan_version=1,machine_profile_id=approval['machine_profile_id'],machine_profile_version=3,network_zip_sha256=hashlib.sha256(network).hexdigest(),source_preview_sha256=approval['preview_hash'],requires_windows_signing=True,certificate_service_runtime_tested=False,can_stage=False,can_apply=False,runtime_applied=False,gpo_changed=False,files={n:hashlib.sha256(b).hexdigest() for n,b in items.items()})
            items['bundle-manifest.json']=json.dumps(manifest).encode()
            out=io.BytesIO()
            with zipfile.ZipFile(out,'w',zipfile.ZIP_DEFLATED) as z:
                for n,b in items.items():z.writestr(n,b)
            raw=out.getvalue();(path/'draft.zip').write_bytes(raw)
            variants={
                'traversal':{('../escape' if n=='README.txt' else n):b for n,b in items.items()},
                'large':items|{'README.txt':b'x'*262145},
                'content':items|{'enrollment/config.json':b'{}'},
            }
            changed=json.loads(items['bundle-manifest.json']);changed['can_apply']=True
            variants['apply']=items|{'bundle-manifest.json':json.dumps(changed).encode()}
            pins={'draft':hashlib.sha256(raw).hexdigest()}
            for name,files in variants.items():
                out=io.BytesIO()
                with zipfile.ZipFile(out,'w',zipfile.ZIP_DEFLATED) as z:
                    for n,b in files.items():z.writestr(n,b)
                value=out.getvalue();(path/(name+'.zip')).write_bytes(value)
                pins[name]=hashlib.sha256(value).hexdigest()
            (path/'pins.json').write_text(json.dumps(pins),encoding='utf-8')
            target=dict(candidate_id=str(uuid.uuid4()),network_candidate_id=str(uuid.uuid4()),plan_id=approval['plan_id'],plan_version=1,
                        gpo_id=approval['gpo_id'],approval_sha256='a'*64,network_manifest_sha256='b'*64,
                        manifest_sha256='c'*64,draft_sha256=pins['draft'],dependency_sha256='d'*64,
                        publisher_thumbprint=approval['publisher_thumbprint'],machine_profile_id=approval['machine_profile_id'],
                        machine_profile_version=3,domain=approval['domain'],root_thumbprint=approval['root_thumbprint'].lower(),group_sid=approval['group_sid'])
            (path/'combined-target.json').write_text(json.dumps({'target':target,'sha256':hashlib.sha256(json.dumps(target,sort_keys=True,separators=(',',':')).encode()).hexdigest()}))
            command=[str(Path(os.environ['SystemRoot'])/'System32/WindowsPowerShell/v1.0/powershell.exe'),
                '-NoProfile','-NonInteractive','-File','tools/combined_candidate_windows_fixture.ps1',
                '-FixtureDirectory',str(path)]
            environment={k:v for k,v in os.environ.items() if k.upper()!='PSMODULEPATH'}
            subprocess.run(command,env=environment,check=True,timeout=180)

if __name__=='__main__':main()
