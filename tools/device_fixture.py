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
    parser=argparse.ArgumentParser();parser.add_argument('--root',required=True);parser.add_argument('--step',choices=['challenge','issue','receipt','renew','renew-challenge','renew-issue','renew-receipt'],required=True)
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
        (root/'profile.json').write_text(json.dumps(profile))
        result=service.challenge('PC01$@LAB.EXAMPLE',{'profile_id':profile['id'],'csr':(root/'request.pem').read_text()})
        (root/'challenge.json').write_text(json.dumps(result))
        bundle=service.pki.public_bundle()
        for name in ('root-ca.pem','issuer-ca.pem'):(root/name).write_bytes(bundle[name])
    elif args.step=='issue':
        challenge=json.loads((root/'challenge.json').read_text())
        result=service.issue('PC01$@LAB.EXAMPLE',{'challenge_id':challenge['challenge_id'],'csr':(root/'request.pem').read_text(),'proof':(root/'proof.txt').read_text().strip()})
        (root/'issued.pem').write_text(result['certificate']);(root/'issued.json').write_text(json.dumps(result))
    elif args.step=='receipt':
        result=json.loads((root/'issued.json').read_text())
        service.receipt('PC01$@LAB.EXAMPLE',{'serial':result['serial'],'proof':(root/'receipt-proof.txt').read_text().strip()})
        assert service.status()['devices'][0]['status']=='installed'
    elif args.step=='renew':
        result=json.loads((root/'issued.json').read_text())
        renewed=service.request_renewal(result['serial'],'ci-fixture')
        assert renewed['renewal_due'] is True
        assert service.status()['devices'][0]['status']=='renewal_due'
    elif args.step=='renew-challenge':
        profile=json.loads((root/'profile.json').read_text())
        result=service.challenge('PC01$@LAB.EXAMPLE',{'profile_id':profile['id'],'csr':(root/'renew-request.pem').read_text()})
        (root/'renew-challenge.json').write_text(json.dumps(result))
    elif args.step=='renew-issue':
        challenge=json.loads((root/'renew-challenge.json').read_text())
        result=service.issue('PC01$@LAB.EXAMPLE',{'challenge_id':challenge['challenge_id'],'csr':(root/'renew-request.pem').read_text(),'proof':(root/'renew-proof.txt').read_text().strip()})
        (root/'renew-issued.pem').write_text(result['certificate']);(root/'renew-issued.json').write_text(json.dumps(result))
    else:
        old=json.loads((root/'issued.json').read_text())
        result=json.loads((root/'renew-issued.json').read_text())
        service.receipt('PC01$@LAB.EXAMPLE',{'serial':result['serial'],'proof':(root/'renew-receipt-proof.txt').read_text().strip()})
        devices=service.status()['devices']
        assert devices[0]['serial']==result['serial'] and devices[0]['status']=='installed'
        with service.store.connect() as db:
            assert db.execute('SELECT revoked_at FROM pki_certificates WHERE serial=?',(old['serial'],)).fetchone()[0] is None
            assert db.execute('SELECT retire_at FROM device_retirements WHERE serial=?',(old['serial'],)).fetchone() is not None
    print(json.dumps({'fixture_step':args.step,'ok':True}))


if __name__=='__main__':main()
