"""Isolated synthetic-AD issuance load measurement, not a capacity promise."""
import argparse
import base64
import json
import tempfile
import time
import uuid
from concurrent.futures import ThreadPoolExecutor

from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.asymmetric import ec

from kaname.device_enrollment import DeviceEnrollment
from kaname.operations import Operations
from kaname.pki import PKIService
from kaname.radius import CurrentDirectoryAccount
from kaname.store import Store
from tests.helpers import config
from tests.test_directory import connection
from tests.test_enrollment import PASSWORD, request
from tests.test_radius_live import GROUP, PRIMARY


def run(count):
    with tempfile.TemporaryDirectory(prefix='authwire-load-fixture-') as temporary:
        store=Store(temporary);store.save(0,config=config());ops=Operations(store)
        ops.save_directory(1,connection()|{'search_base':'','sync_minutes':15,'check_minutes':5,'automatic_sync':False})
        PKIService(temporary).initialize(PASSWORD)
        def resolve(connection,cfg,*,computer_sam):
            number=int(computer_sam[2:-1])+10000
            return CurrentDirectoryAccount('lab.example',str(uuid.UUID(int=number)),f'S-1-5-21-1-2-3-{number}',
                'computer',True,frozenset({GROUP,PRIMARY}))
        service=DeviceEnrollment(ops,resolver=resolve);service.unlock_signer(PASSWORD,'load-fixture')
        profile=service.save_profile({'id':'','version':0,'name':'Load fixture','group_sid':GROUP,'validity_days':90,'renew_before_days':30,'enabled':True},'load-fixture')
        def one(number):
            key=ec.generate_private_key(ec.SECP256R1());csr=request(key).decode();principal=f'PC{number}$@LAB.EXAMPLE'
            ch=service.challenge(principal,{'profile_id':profile['id'],'csr':csr})
            proof=base64.b64encode(key.sign(base64.b64decode(ch['payload']),ec.ECDSA(hashes.SHA256()))).decode()
            result=service.issue(principal,{'challenge_id':ch['challenge_id'],'csr':csr,'proof':proof})
            proof=base64.b64encode(key.sign(base64.b64decode(result['receipt_payload']),ec.ECDSA(hashes.SHA256()))).decode()
            service.receipt(principal,{'serial':result['serial'],'proof':proof})
            return result['serial']
        start=time.monotonic();cpu=time.process_time()
        with ThreadPoolExecutor(max_workers=4) as pool:serials=list(pool.map(one,range(count)))
        elapsed=time.monotonic()-start;cpu=time.process_time()-cpu
        assert len(set(serials))==count
        with store.connect() as db:
            assert db.execute('SELECT count(*) FROM device_issuances WHERE installed_at IS NOT NULL').fetchone()[0]==count
        return {'fixture_only':True,'devices':count,'workers':4,'unique_certificates':len(set(serials)),
            'wall_seconds':round(elapsed,3),'cpu_seconds':round(cpu,3),'live_ad_tested':False,'windows_gpo_tested':False}


if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--devices',type=int,default=1000);args=parser.parse_args()
    if not 1<=args.devices<=2000:raise SystemExit('Fixture bound is 1–2000')
    print(json.dumps(run(args.devices)))
