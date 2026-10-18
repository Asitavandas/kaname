"""Offline server-data restore rehearsal. Never starts restored code/services."""
from contextlib import closing
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import sqlite3
import stat
import tarfile
import tempfile

ROOTS=('etc/kaname-lab','var/lib/kaname-lab','opt/kaname-lab/source',
       'opt/authwire-service-control','var/lib/authwire-service-control')
UNITS=tuple('etc/systemd/system/'+n for n in ('kaname-lab.service','authwire-radius.service',
       'authwire-service-control.service','authwire-radius-crl-sync.service','authwire-radius-crl-sync.timer'))
MAX_FILE=128*1024*1024
MAX_TOTAL=2*1024*1024*1024


def sha(path):
    h=hashlib.sha256()
    with Path(path).open('rb') as f:
        for data in iter(lambda:f.read(1024*1024),b''):h.update(data)
    return h.hexdigest()


def selected(name):return any(name==r or name.startswith(r+'/') for r in ROOTS+UNITS+tuple(u+'.d' for u in UNITS))


def restore_data(archive,destination):
    destination=Path(destination)
    if destination.exists():raise ValueError('New private restore destination required')
    destination.mkdir(mode=0o700)
    restored={};metadata=[];seen=set();total=0;skipped_links=0
    with tarfile.open(archive,'r:gz') as tar:
        for member in tar:
            name=member.name;p=PurePosixPath(name)
            if p.is_absolute() or '..' in p.parts or p.as_posix()!=name or '\\' in name or name in seen:
                raise ValueError('Unsafe or duplicate archive path')
            seen.add(name)
            if member.isfile():
                total+=member.size
                if member.size<0 or member.size>MAX_FILE or total>MAX_TOTAL:raise ValueError('Archive size bound exceeded')
            if member.issym() or member.islnk():
                if selected(name):raise ValueError('Link in restored data refused')
                skipped_links+=1;continue
            if not member.isdir() and not member.isfile():raise ValueError('Special archive member refused')
            if not selected(name):continue
            target=destination.joinpath(*p.parts)
            target.parent.mkdir(parents=True,exist_ok=True,mode=0o700)
            if member.isdir():target.mkdir(exist_ok=True,mode=0o700)
            else:
                fd=os.open(target,os.O_WRONLY|os.O_CREAT|os.O_EXCL|os.O_NOFOLLOW,0o600)
                h=hashlib.sha256();size=0
                with tar.extractfile(member) as src,os.fdopen(fd,'wb') as dst:
                    for data in iter(lambda:src.read(1024*1024),b''):
                        size+=len(data);dst.write(data);h.update(data)
                if size!=member.size or sha(target)!=h.hexdigest():raise ValueError('Restored bytes differ')
                restored[name]=h.hexdigest()
            if member.mode&0o7000:raise ValueError('Special mode in restored data refused')
            metadata.append((target,member.mode&0o777,member.uid,member.gid))
    for target,mode,uid,gid in sorted(metadata,key=lambda x:len(x[0].parts),reverse=True):
        if os.geteuid()==0:os.chown(target,uid,gid,follow_symlinks=False)
        elif (uid,gid)!=(os.getuid(),os.getgid()):raise ValueError('Archive ownership requires local root')
        target.chmod(mode)
        info=target.stat()
        if (info.st_uid,info.st_gid,stat.S_IMODE(info.st_mode))!=(uid,gid,mode):raise ValueError('Restored permissions differ')
    if stat.S_IMODE(destination.stat().st_mode)!=0o700:raise ValueError('Restore isolation root must remain private')
    return {'files_restored':len(restored),'file_bytes_verified':True,'ownership_and_modes_verified':True,
            'runtime_links_not_materialized':skipped_links,'restored_file_digests':restored}


def unseal(key,purpose,blob):
    from cryptography.hazmat.primitives.ciphers.aead import AESGCM
    if len(key)!=32 or not blob.startswith(b'AG1'):raise ValueError('Expected Linux protected value')
    item=json.loads(AESGCM(key).decrypt(blob[3:15],blob[15:],purpose.encode()))
    if item.get('purpose')!=purpose or type(item.get('value')) is not str:raise ValueError('Protected value binding mismatch')
    return item['value']


def validate_copy(root):
    from cryptography import x509
    from cryptography.hazmat.primitives import hashes,serialization
    from cryptography.hazmat.primitives.asymmetric import ec,rsa,padding
    root=Path(root);state=root/'var/lib/kaname-lab';checks={}
    with closing(sqlite3.connect((state/'kaname.sqlite3').as_uri()+'?mode=ro',uri=True)) as db, \
         closing(sqlite3.connect((state/'administrators.sqlite3').as_uri()+'?mode=ro',uri=True)) as admin:
        checks['databases_integrity_ok']=all(all(r[0]=='ok' for r in c.execute('PRAGMA integrity_check')) for c in (db,admin))
        row=db.execute('SELECT config,policies FROM state WHERE id=1').fetchone()
        checks['configuration_and_policies_readable']=bool(row and isinstance(json.loads(row[0]),dict) and isinstance(json.loads(row[1]),list))
        checks['administrator_users_and_profiles_readable']=bool(admin.execute('SELECT count(*) FROM admin_users').fetchone()[0] and admin.execute('SELECT count(*) FROM admin_profiles').fetchone()[0])
        authority=db.execute('SELECT root_cert,root_key,issuer_cert,issuer_key,crl FROM pki_authority WHERE id=1').fetchone()
        ca=x509.load_pem_x509_certificate(authority[0]);issuer=x509.load_pem_x509_certificate(authority[2])
        ca.verify_directly_issued_by(ca);issuer.verify_directly_issued_by(ca)
        checks['ca_chain_and_encrypted_key_material_present']=bool(authority[1] and authority[3])
        now=datetime.now(timezone.utc)
        checks['ca_certificates_current']=all(c.not_valid_before_utc<=now<c.not_valid_after_utc for c in (ca,issuer))
        crl=x509.load_pem_x509_crl(authority[4]);checks['crl_signature_valid']=crl.is_signature_valid(issuer.public_key())
        checks['snapshot_crl_current']=crl.last_update_utc<=datetime.now(timezone.utc)<crl.next_update_utc
        key=(state/'secret-store.key').read_bytes();secret_count=0
        for purpose,blob in db.execute('SELECT name,ciphertext FROM protected_secrets'):
            value=unseal(key,purpose,blob);secret_count+=1;del value
        checks['protected_secrets_decryptable']=True
        signer=db.execute('SELECT key_sealed FROM device_signer WHERE id=1').fetchone()
        if not signer:raise ValueError('Active enrollment signer required for this rehearsal')
        value=unseal(key,'device-issuer-key',signer[0])
        signer_key=serialization.load_pem_private_key(value.encode(),password=None);del value
        public=lambda k:k.public_bytes(serialization.Encoding.DER,serialization.PublicFormat.SubjectPublicKeyInfo)
        checks['restored_signer_matches_issuer']=public(signer_key.public_key())==public(issuer.public_key())
        probe=b'AuthWire offline restore proof: not a certificate or CRL'
        if isinstance(signer_key,rsa.RSAPrivateKey):
            signature=signer_key.sign(probe,padding.PKCS1v15(),hashes.SHA256());issuer.public_key().verify(signature,probe,padding.PKCS1v15(),hashes.SHA256())
        elif isinstance(signer_key,ec.EllipticCurvePrivateKey):
            signature=signer_key.sign(probe,ec.ECDSA(hashes.SHA256()));issuer.public_key().verify(signature,probe,ec.ECDSA(hashes.SHA256()))
        else:raise ValueError('Unsupported restored signer')
        checks['restored_signer_can_sign_probe']=True
        for label,certpath,keypath in [('web','etc/kaname-lab/web.crt','etc/kaname-lab/web.key'),('radius','var/lib/kaname-lab/radius/server.pem','var/lib/kaname-lab/radius/server-key.pem')]:
            cert=x509.load_pem_x509_certificate((root/certpath).read_bytes())
            private=serialization.load_pem_private_key((root/keypath).read_bytes(),password=None)
            checks[label+'_certificate_matches_key']=public(cert.public_key())==public(private.public_key())
            checks[label+'_certificate_current']=cert.not_valid_before_utc<=now<cert.not_valid_after_utc
            if label=='radius':cert.verify_directly_issued_by(issuer)
        for table in ('device_profiles','radius_certificate_bindings','pki_certificates','pki_client_keys','device_issuances','device_retirements'):
            db.execute('SELECT count(*) FROM '+table).fetchone()
        checks['enrollment_registry_tables_readable']=True
        checks['database_foreign_keys_consistent']=all(not c.execute('PRAGMA foreign_key_check').fetchall() for c in (db,admin))
        for serial,pem in db.execute('SELECT serial,certificate FROM pki_certificates'):
            cert=x509.load_pem_x509_certificate(pem);cert.verify_directly_issued_by(issuer)
            if int(serial,16)!=cert.serial_number:raise ValueError('Restored certificate serial mismatch')
        checks['certificate_registry_signatures_and_serials']=True
    if not all(checks.values()):raise ValueError('Restored application data check failed')
    return {'checks':checks,'protected_secret_count_verified':secret_count}


def check(backup,expected,workspace):
    backup=Path(backup);workspace=Path(workspace)
    if not re.fullmatch('[0-9a-f]{64}',expected) or backup.is_symlink() or sha(backup)!=expected:raise ValueError('Pinned backup digest mismatch')
    workspace=workspace.absolute()
    if workspace.resolve()!=workspace:raise ValueError('Rehearsal path symlink refused')
    if any(workspace==Path('/'+r) or Path('/'+r) in workspace.parents for r in ROOTS):raise ValueError('Live application path refused')
    workspace.mkdir(mode=0o700,parents=True,exist_ok=True)
    info=workspace.lstat()
    if not stat.S_ISDIR(info.st_mode) or info.st_uid!=os.geteuid() or info.st_mode&0o077:raise ValueError('Private rehearsal workspace required')
    with tempfile.TemporaryDirectory(prefix='offline-',dir=workspace) as temp:
        destination=Path(temp)/'restored'
        files=restore_data(backup,destination)
        validated=validate_copy(destination)
        result={k:v for k,v in files.items() if k!='restored_file_digests'}
        result.update(validated)
    return {'data_restore_exercised':True,'backup_sha256':expected,**result,
            'isolated_copy_removed':True,'restored_code_executed':False,'services_started':False,
            'network_calls_from_restore_check':False,'full_appliance_boot_restore_tested':False}


def main():
    import argparse
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--backup',required=True)
    parser.add_argument('--sha256',required=True)
    parser.add_argument('--workspace',default='/var/lib/authwire-restore-checks')
    args=parser.parse_args()
    try:
        print(json.dumps({'event':'OFFLINE_RESTORE_CHECK',**check(args.backup,args.sha256,args.workspace)}))
        return 0
    except Exception as error:
        print(json.dumps({'event':'OFFLINE_RESTORE_CHECK_FAILED','category':type(error).__name__}))
        return 1

if __name__=='__main__':raise SystemExit(main())
