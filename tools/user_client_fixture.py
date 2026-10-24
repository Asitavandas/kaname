"""Disposable native Windows USER client issuer; no network/customer AD shortcut."""
import argparse
import json
from pathlib import Path
from cryptography import x509
from cryptography.hazmat.primitives import serialization
from kaname.device_enrollment import DeviceEnrollment
from kaname.enrollment import EnrollmentError
from kaname.operations import Operations
from kaname.pki import PKIService
from kaname.store import Store
from kaname.user_enrollment import UserEnrollment
from tests.helpers import config
from tests.test_directory import connection
from tests.test_enrollment import PASSWORD
from tests.test_radius_live import live_account, GROUP

USER='Alice@LAB.EXAMPLE'

def service(root):
    if not root.name.startswith('authwire-user-ci-') or not (root/'USER_CLIENT_FIXTURE_ONLY').is_file():
        raise ValueError('Disposable user fixture marker required')
    store=Store(root/'state');ops=Operations(store)
    if not store.snapshot()['config']:
        store.save(0,config=config());ops.save_directory(1,connection()|{'search_base':'','sync_minutes':15,'check_minutes':5,'automatic_sync':False})
        PKIService(store.root).initialize(PASSWORD)
    devices=DeviceEnrollment(ops);devices.unlock_signer(PASSWORD,'ci-fixture')
    return UserEnrollment(devices,resolver=lambda *a,**kw:live_account(kind='user'))

def main():
    p=argparse.ArgumentParser();p.add_argument('--root',required=True);p.add_argument('--step',choices=['prepare','call','renew','expire','status'],required=True);p.add_argument('--request');p.add_argument('--response');args=p.parse_args()
    root=Path(args.root).resolve();users=service(root)
    if args.step=='prepare':
        profile=users.save_profile({'id':'','version':0,'name':'Disposable user pilot','group_sid':GROUP,'validity_days':90,'renew_before_days':30,'enabled':True},'ci-fixture')
        (root/'profile.json').write_text(json.dumps(profile))
        for name,data in users.pki.public_bundle().items():
            if name in ('root-ca.pem','issuer-ca.pem'):(root/name).write_bytes(data)
        from tools.linux_initialize import create_web_certificate
        create_web_certificate(root,'authwire.lab.example','127.0.0.1')
        import zipfile,io
        package=users.package(profile['id'],hostname='authwire.lab.example',port=8765,tls_pem=(root/'web.crt').read_bytes())
        with zipfile.ZipFile(io.BytesIO(package)) as archive:archive.extractall(root/'package')
        result={'profile_id':profile['id'],'fixture_only':True}
    elif args.step=='call':
        request=json.loads(Path(args.request).read_text(encoding='utf-8-sig'));body=request['body']
        try:
            if request['path']=='/api/user/challenge':result=users.challenge(USER,body)
            elif request['path']=='/api/user/issue':result=users.issue(USER,body)
            elif request['path']=='/api/user/receipt':result=users.receipt(USER,body)
            else:raise ValueError('Fixture route refused')
        except EnrollmentError as error:result={'fixture_error':error.code}
        Path(args.response).write_text(json.dumps(result),encoding='utf-8')
    elif args.step=='renew':
        with users.store.connect() as db:serial=db.execute('SELECT serial FROM user_enrollment_issuances ORDER BY rowid DESC LIMIT 1').fetchone()[0]
        result=users.request_renewal(serial,'ci-fixture')
    elif args.step=='expire':
        from datetime import timedelta
        from kaname.pki import instant,PEM
        from cryptography.hazmat.primitives import hashes
        now=instant()
        with users.transaction() as db:
            serial,pem=db.execute('SELECT c.serial,c.certificate FROM user_enrollment_issuances u JOIN pki_certificates c ON c.serial=u.serial ORDER BY u.rowid DESC LIMIT 1').fetchone()
            cert=x509.load_pem_x509_certificate(pem);issuer,key,_=users.devices._issuer(db,now)
            builder=(x509.CertificateBuilder().subject_name(cert.subject).issuer_name(issuer.subject).public_key(cert.public_key()).serial_number(cert.serial_number).not_valid_before(now-timedelta(minutes=4)).not_valid_after(now-timedelta(minutes=1)))
            for extension in cert.extensions:builder=builder.add_extension(extension.value,extension.critical)
            db.execute('UPDATE pki_certificates SET certificate=? WHERE serial=?',(builder.sign(key,hashes.SHA256()).public_bytes(PEM),serial))
        result={'expired':True}
    else:
        result=users.status()
        with users.store.connect() as db:
            result['csr_counts']=[n for n, in db.execute('SELECT count(*) FROM user_enrollment_issuances GROUP BY csr_sha256')]
            result['machine_issuances']=db.execute('SELECT count(*) FROM device_issuances').fetchone()[0]
    print(json.dumps({'step':args.step,'ok':True,**(result if args.step!='call' else {})}))

if __name__=='__main__':main()
