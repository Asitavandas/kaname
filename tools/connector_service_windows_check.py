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
from kaname.connector_jobs import ConnectorJobs, OPERATION
from kaname.candidate_jobs import CandidateJobs
from kaname.deployment_candidates import DeploymentCandidates
from tests.test_deployment_candidates import fixture_snapshot,make_receipt
import copy
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
            if (root/'case.txt').exists() and ((root/'case.txt').read_text().strip()=='offline' or
                    ((root/'case.txt').read_text().strip()=='candidate-offline' and handler.path.startswith('/api/connector/v1/candidates/'))):
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
                jobs=ConnectorJobs(registry)
                probe={'expected_revision':store.snapshot()['revision'],'job_id':str(uuid.uuid4()),'operation':OPERATION}
                prepared=jobs.preview(probe)
                jobs.create(probe|{'preview_hash':prepared['preview_hash']},str(uuid.uuid4()))
                snapshot=store.snapshot();audit=store.audit()
                (root/'paired').write_text('paired',encoding='ascii')
                # The actual installed low-privilege worker advertises separately.
                data=fixture_snapshot();data['config']['ad_domain']='lab.example'
                server.deployment._snapshot=lambda db:copy.deepcopy(data)
                server.deployment._targets=lambda *args:{'available':True,'enabled':2,'unresolved':0}
                server.deployment._trust=lambda *args:{'ready':True,'root_thumbprint':'c'*40}
                candidates=DeploymentCandidates(registry,server.deployment)
                cj=CandidateJobs(candidates)
                end=time.monotonic()+90
                while not cj.status()['worker_ready']:
                    if process.poll() is not None or time.monotonic()>end:raise RuntimeError('Candidate worker capability missing')
                    time.sleep(.25)
                receipt=make_receipt(data['plans'][0]);receipt['Computer']=candidate['host_fqdn'].split('.')[0]
                cr={'expected_revision':store.snapshot()['revision'],'registration_id':str(uuid.uuid4()),'receipt_json':json.dumps(receipt)}
                cp=candidates.preview(cr);candidates.record(cr|{'preview_hash':cp['preview_hash']},str(uuid.uuid4()))
                ci={'expected_revision':store.snapshot()['revision'],'job_id':str(uuid.uuid4()),'candidate_id':cr['registration_id'],'operation':'candidate.verify.v1'}
                cp=cj.preview(ci);cj.create(ci|{'preview_hash':cp['preview_hash']},str(uuid.uuid4()))
                end=time.monotonic()+90
                while cj.status()['jobs'][0]['state']!='completed':
                    if process.poll() is not None or time.monotonic()>end:raise RuntimeError('Candidate worker result missing')
                    time.sleep(.25)
                assert cj.status()['jobs'][0]['result']['outcome']=='content_rejected' # No candidate exists in this fixture.
                assert not candidates.status()['candidates'][0]['connector_verified']
                process.wait(timeout=540)
                if process.returncode:raise RuntimeError('Native service fixture failed')
            result=json.loads((root/'service-result.json').read_text(encoding='utf-8-sig'))
            assert result['checks']>=17 and result['actual_https'] and result['crash_recovery'] and not result['customer_gmsa_tested']
            assert result['legacy_staged_upgrade'] and result['automatic_upgrade_rollback'] and result['explicit_upgrade_rollback']
            assert result['candidate_channel_required'] and result['candidate_channel_failed_upgrade_rollback']
            assert result['fresh_public_control'] and result['fresh_control_modes']==['Inspect','Start','Start','Stop','Start','Remove']
            assert server.connector_pairing.status()['online'] and not server.connector_pairing.status()['can_apply']
            after=store.snapshot()
            assert snapshot['config']==after['config'] and snapshot['policies']==after['policies']
            assert after['revision']==snapshot['revision']+4 and len(store.audit())==len(audit)+4
            status=jobs.status()
            assert status['jobs'][0]['state']=='completed' and status['jobs'][0]['result']['release_id']==result['release_id']
            assert status['worker_probe_ready'] and not status['can_apply']
            print('AUTHWIRE_PERMANENT_SERVICE_WINDOWS_OK '+json.dumps(result,sort_keys=True))
        finally:
            (root/'abort').write_text('abort',encoding='ascii')
            if process is not None and process.poll() is None:process.wait(timeout=90)
            log=(root/'fixture.log').read_text(encoding='utf-8',errors='replace') if (root/'fixture.log').exists() else ''
            if process is not None and process.returncode:print(log[-12000:])
            server.shutdown();server.server_close();thread.join();Handler.connector_peer=original

if __name__=='__main__':main()
