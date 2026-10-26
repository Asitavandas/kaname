"""Hosted, isolated permanent SCM host + actual Python HTTPS health fixture."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import threading
import time
import uuid

sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from cryptography import x509
from cryptography.hazmat.primitives import hashes
from kaname.server import DevelopmentServer,Handler
from kaname.store import Store
from kaname.operations import Operations
from kaname.pki import PKIService
from kaname.connector_registry import ConnectorRegistry
from tools.linux_initialize import create_web_certificate

def main():
    if os.name!='nt' or os.environ.get('RUNNER_ENVIRONMENT')!='github-hosted':raise RuntimeError('Hosted fixture only')
    with tempfile.TemporaryDirectory(prefix='authwire-scm-health-') as temp:
        root=Path(temp);fqdn='aw-'+uuid.uuid4().hex+'.lab.example'
        create_web_certificate(root,fqdn,'127.0.0.1')
        store=Store(root/'state');store.save(0,config={'appliance_fqdn':fqdn,'ad_domain':'lab.example','dc_ips':['127.0.0.2'],'radius_clients':[],'access_modes':['wired']})
        Operations(store);pki=PKIService(store.root).initialize(b'isolated-service-fixture-password')
        server=DevelopmentServer(store.root,0,tls_cert=root/'web.crt',tls_key=root/'web.key',public_name=fqdn)
        base={'instance_id':pki['instance_id'],'connector_id':str(uuid.uuid4()),'host_guid':str(uuid.uuid4()),'appliance_fqdn':fqdn,'appliance_tls_sha256':x509.load_pem_x509_certificate(server.web_certificate).fingerprint(hashes.SHA256()).hex(),'port':server.server_port}
        (root/'base.json').write_text(json.dumps(base),encoding='ascii')
        original=Handler.connector_peer
        def fixture_peer(handler):
            if (root/'case.txt').exists() and (root/'case.txt').read_text().strip()=='offline':
                handler.respond(503,{'error':'FIXTURE_OFFLINE'});return
            original(handler)
        Handler.connector_peer=fixture_peer
        thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
        env={k:v for k,v in os.environ.items() if k.upper()!='PSMODULEPATH'}
        process=None
        try:
            with (root/'fixture.log').open('w',encoding='utf-8') as output:
                process=subprocess.Popen(['powershell.exe','-NoProfile','-NonInteractive','-File',str(Path(__file__).with_name('connector_service_windows_fixture.ps1')),'-Directory',str(root)],env=env,stdout=output,stderr=subprocess.STDOUT)
                end=time.monotonic()+90
                while not (root/'candidate.json').exists():
                    if process.poll() is not None or time.monotonic()>=end:raise RuntimeError('Service fixture preparation failed')
                    time.sleep(.25)
                candidate=json.loads((root/'candidate.json').read_text(encoding='utf-8-sig'))
                registry=ConnectorRegistry(server.operations,server.web_certificate)
                intent={'expected_revision':store.snapshot()['revision'],'operation':'pair','candidate':candidate}
                preview=registry.preview(intent)
                registry.apply(intent|{'preview_hash':preview['preview_hash'],'confirmed_key_sha256':preview['after']['channel_key_sha256']},str(uuid.uuid4()))
                snapshot=store.snapshot();audit=store.audit()
                (root/'paired').write_text('paired',encoding='ascii')
                process.wait(timeout=290)
                if process.returncode:raise RuntimeError('Native service fixture failed')
            result=json.loads((root/'service-result.json').read_text(encoding='utf-8-sig'))
            assert result['checks']>=17 and result['actual_https'] and result['crash_recovery'] and not result['customer_gmsa_tested']
            assert result['fresh_public_control'] and result['fresh_control_modes']==['Inspect','Start','Start','Stop','Start','Remove']
            assert server.connector_pairing.status()['online'] and not server.connector_pairing.status()['can_apply']
            assert snapshot==store.snapshot() and audit==store.audit()
            print('AUTHWIRE_PERMANENT_SERVICE_WINDOWS_OK '+json.dumps(result,sort_keys=True))
        finally:
            (root/'abort').write_text('abort',encoding='ascii')
            if process is not None and process.poll() is None:process.wait(timeout=90)
            log=(root/'fixture.log').read_text(encoding='utf-8',errors='replace') if (root/'fixture.log').exists() else ''
            if process is not None and process.returncode:print(log[-12000:])
            server.shutdown();server.server_close();thread.join();Handler.connector_peer=original

if __name__=='__main__':main()
