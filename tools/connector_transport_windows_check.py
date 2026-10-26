"""Hosted Windows machine CNG key + real pinned HTTPS to the actual Python handler."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import threading
import time
import uuid

sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from kaname.server import DevelopmentServer, Handler
from kaname.store import Store
from kaname.operations import Operations
from kaname.pki import PKIService
from kaname.connector_registry import ConnectorRegistry
from tools.linux_initialize import create_web_certificate

def main():
    if os.name!='nt' or os.environ.get('RUNNER_ENVIRONMENT')!='github-hosted':raise RuntimeError('Hosted Windows fixture only')
    with tempfile.TemporaryDirectory(prefix='authwire-transport-') as temp:
        root=Path(temp);fqdn='aw-'+uuid.uuid4().hex+'.lab.example'
        create_web_certificate(root,fqdn,'127.0.0.1')
        store=Store(root/'state');store.save(0,config={'appliance_fqdn':fqdn,'ad_domain':'lab.example','dc_ips':['127.0.0.2'],'radius_clients':[],'access_modes':['wired']})
        Operations(store);authority=PKIService(store.root).initialize(b'fixture-channel-only-password')
        server=DevelopmentServer(store.root,0,tls_cert=root/'web.crt',tls_key=root/'web.key',public_name=fqdn)
        from cryptography import x509
        from cryptography.hazmat.primitives import hashes
        base={'instance_id':authority['instance_id'],'connector_id':str(uuid.uuid4()),'host_guid':str(uuid.uuid4()),'appliance_fqdn':fqdn,'appliance_tls_sha256':x509.load_pem_x509_certificate(server.web_certificate).fingerprint(hashes.SHA256()).hex(),'port':server.server_port}
        (root/'base.json').write_text(json.dumps(base),encoding='ascii')
        fixture=Path(__file__).with_name('connector_transport_windows_fixture.ps1')
        def run(mode):
            env={k:v for k,v in os.environ.items() if k.upper()!='PSMODULEPATH'}
            subprocess.run(['powershell.exe','-NoProfile','-NonInteractive','-File',str(fixture),'-Mode',mode,'-Directory',str(root)],check=True,timeout=90,env=env)
        original=Handler.connector_peer;metrics={'redirect_followed':0}
        def fixture_peer(handler):
            case=(root/'case.txt').read_text().strip() if (root/'case.txt').exists() else 'normal'
            if case=='slow':time.sleep(6)
            if case=='slow_body':
                handler.send_response(200);handler.send_header('Content-Type','application/json');handler.send_header('Content-Length','16');handler.end_headers()
                try:
                    handler.wfile.write(b'{');handler.wfile.flush();time.sleep(6);handler.wfile.write(b'"frame":"AAAA"}')
                except OSError:pass
                return
            if case=='redirect':
                handler.send_response(302);handler.send_header('Location','/must-not-follow');handler.send_header('Content-Length','0');handler.end_headers();return
            if case=='oversized':handler.respond(200,{'frame':'A'*5000});return
            try:original(handler)
            except OSError:pass # timed-out fixture request only
        Handler.connector_peer=fixture_peer
        thread=threading.Thread(target=server.serve_forever,daemon=True);thread.start()
        server.daemon_threads=False
        try:
            run('Create')
            prep=json.loads((root/'prepared.json').read_text(encoding='utf-8-sig'))
            registry=ConnectorRegistry(server.operations,server.web_certificate)
            intent={'expected_revision':store.snapshot()['revision'],'operation':'pair','candidate':prep['PairingCandidate']}
            p=registry.preview(intent);registry.apply(intent|{'preview_hash':p['preview_hash'],'confirmed_key_sha256':p['after']['channel_key_sha256']},str(uuid.uuid4()))
            run('Client')
            result=json.loads((root/'client-result.json').read_text(encoding='utf-8-sig'))
            created=json.loads((root/'create-result.json').read_text(encoding='utf-8-sig'))
            assert result['verified'] and result['key_acl_preserved']
            assert server.connector_pairing.status()['online'] and not server.connector_pairing.status()['can_apply']
            assert created['create_checks']>=8 and result['client_checks']>=16
            print('AUTHWIRE_CONNECTOR_TRANSPORT_WINDOWS_OK '+json.dumps(created|result,sort_keys=True))
        finally:
            server.shutdown();server.server_close();thread.join();Handler.connector_peer=original
            if (root/'prepared.json').exists() or (root/'key-root').exists():run('Cleanup')

if __name__=='__main__':main()
