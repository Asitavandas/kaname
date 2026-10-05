"""Disposable Windows CI fixture issuer. Never a live enrollment shortcut.

Temporary fixture root only; requires explicit fixture marker and account.
"""
import argparse
import json
from pathlib import Path

from kaname.device_enrollment import DeviceEnrollment
from kaname.operations import Operations
from kaname.pki import PKIService
from kaname.store import Store
from tests.helpers import config
from tests.test_directory import connection
from tests.test_enrollment import PASSWORD
from tests.test_radius_live import live_account, GROUP


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--root',required=True);parser.add_argument('--step',choices=['challenge','issue','receipt'],required=True)
    args=parser.parse_args();root=Path(args.root).resolve()
    if not root.name.startswith('authwire-ci-') or not (root/'CI_FIXTURE_ONLY').is_file():
        raise ValueError('Disposable fixture marker required')
    store=Store(root/'state');ops=Operations(store)
    if not store.snapshot()['config']:
        store.save(0,config=config());ops.save_directory(1,connection()|{'search_base':'','sync_minutes':15,'check_minutes':5,'automatic_sync':False})
        PKIService(store.root).initialize(PASSWORD)
    service=DeviceEnrollment(ops,resolver=lambda *args,**kwargs:live_account())
    service.unlock_signer(PASSWORD,'ci-fixture')
    if args.step=='challenge':
        profile=service.save_profile({'id':'','version':0,'name':'Disposable Windows CI','group_sid':GROUP,'validity_days':90,'renew_before_days':30,'enabled':True},'ci-fixture')
        result=service.challenge('PC01$@LAB.EXAMPLE',{'profile_id':profile['id'],'csr':(root/'request.pem').read_text()})
        (root/'challenge.json').write_text(json.dumps(result))
        bundle=service.pki.public_bundle()
        for name in ('root-ca.pem','issuer-ca.pem'):(root/name).write_bytes(bundle[name])
    elif args.step=='issue':
        challenge=json.loads((root/'challenge.json').read_text())
        result=service.issue('PC01$@LAB.EXAMPLE',{'challenge_id':challenge['challenge_id'],'csr':(root/'request.pem').read_text(),'proof':(root/'proof.txt').read_text().strip()})
        (root/'issued.pem').write_text(result['certificate']);(root/'issued.json').write_text(json.dumps(result))
    else:
        result=json.loads((root/'issued.json').read_text())
        service.receipt('PC01$@LAB.EXAMPLE',{'serial':result['serial'],'proof':(root/'receipt-proof.txt').read_text().strip()})
        assert service.status()['devices'][0]['status']=='installed'
    print(json.dumps({'fixture_step':args.step,'ok':True}))


if __name__=='__main__':main()
