"""Profile-based computer enrollment; all identities come from Kerberos/AD.

The unattended signer seals ONLY the issuing key in the existing OS-private
vault. It never stores the operator's CA password or unlocks the root key.
This development appliance uses one service account, not an isolated HSM.
"""
import base64
import hashlib
import io
import json
import os
import re
import secrets
import threading
import time
import uuid
import zipfile
from contextlib import contextmanager
from datetime import datetime, timedelta
from pathlib import Path

from cryptography import x509
from cryptography.exceptions import InvalidSignature
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec, padding, rsa
from cryptography.x509.oid import ExtendedKeyUsageOID, NameOID

from .directory import DirectoryError
from .directory_linux import read_linux_directory
from .enrollment import EnrollmentError, EnrollmentService, client_csr
from .models import boolean, dns_name, integer, keys, text
from .pki import PKIError, PEM, instant, public_der
from .radius import CurrentDirectoryAccount
from .vault import Vault


def digest(data):
    return hashlib.sha256(data).hexdigest()


def identifier(value):
    if type(value) is not str or str(uuid.UUID(value)) != value:
        raise EnrollmentError('DEVICE_INPUT_INVALID')
    return value


class DeviceEnrollment:
    def __init__(self, operations, *, resolver=read_linux_directory):
        self.operations, self.resolver = operations, resolver
        enrollment = EnrollmentService(operations)
        self.store, self.pki = enrollment.store, enrollment.pki
        self.vault = Vault(self.store.root)
        self.gate = threading.BoundedSemaphore(4)
        self.write_lock = threading.Lock()
        self.signer_lock = threading.Lock()
        self.signer_cache = None
        with self.store.connect() as db:
            db.executescript('''
                CREATE TABLE IF NOT EXISTS device_signer (id INTEGER PRIMARY KEY CHECK(id=1),
                    issuer_sha256 TEXT NOT NULL, key_sealed BLOB NOT NULL);
                CREATE TABLE IF NOT EXISTS device_profiles (id TEXT PRIMARY KEY, version INTEGER NOT NULL,
                    name TEXT NOT NULL, domain TEXT NOT NULL, group_sid TEXT NOT NULL,
                    validity_days INTEGER NOT NULL, renew_before_days INTEGER NOT NULL, enabled INTEGER NOT NULL);
                CREATE TABLE IF NOT EXISTS device_challenges (id TEXT PRIMARY KEY, principal TEXT NOT NULL,
                    profile_id TEXT NOT NULL, profile_version INTEGER NOT NULL, csr_sha256 TEXT NOT NULL,
                    payload TEXT NOT NULL, expires REAL NOT NULL, serial TEXT);
                CREATE TABLE IF NOT EXISTS device_issuances (serial TEXT PRIMARY KEY REFERENCES pki_certificates(serial),
                    profile_id TEXT NOT NULL, profile_version INTEGER NOT NULL, principal TEXT NOT NULL,
                    csr_sha256 TEXT NOT NULL UNIQUE, installed_at TEXT, last_seen TEXT NOT NULL,
                    renew_at TEXT NOT NULL, receipt_payload TEXT NOT NULL);
                CREATE INDEX IF NOT EXISTS device_owner ON device_issuances(profile_id,principal);
                CREATE TABLE IF NOT EXISTS device_retirements (serial TEXT PRIMARY KEY, retire_at TEXT NOT NULL);
                CREATE TABLE IF NOT EXISTS device_rate (principal TEXT PRIMARY KEY, window REAL NOT NULL, attempts INTEGER NOT NULL);
            ''')

    @contextmanager
    def transaction(self):
        # At most four authenticated device workers wait here. Serialize SQLite
        # writers explicitly; busy_timeout alone can starve a writer under load.
        with self.write_lock:
            with self.store.connect() as db:
                db.execute('BEGIN IMMEDIATE')
                yield db

    def unlock_signer(self, password, actor):
        with self.transaction() as db:
            _, issuer, key, _ = self.pki._authority(db, password, instant())
            pem = key.private_bytes(PEM, serialization.PrivateFormat.PKCS8, serialization.NoEncryption()).decode('ascii')
            sealed = self.vault.seal('device-issuer-key', pem)
            db.execute('INSERT OR REPLACE INTO device_signer VALUES (1,?,?)', (issuer.fingerprint(hashes.SHA256()).hex(), sealed))
            self.pki._audit(db, 'device_signer_enabled', actor)
        return {'enabled': True, 'root_key_unlocked': False}

    def lock_signer(self, actor):
        with self.transaction() as db:
            db.execute('DELETE FROM device_signer')
            self.pki._audit(db, 'device_signer_disabled', actor)
        with self.signer_lock:
            self.signer_cache = None
        return {'enabled': False}

    def _issuer(self, db, now):
        row = db.execute('SELECT issuer_sha256,key_sealed FROM device_signer WHERE id=1').fetchone()
        authority = db.execute('SELECT root_cert,issuer_cert,crl,crl_number FROM pki_authority WHERE id=1').fetchone()
        if not row or not authority:
            raise EnrollmentError('DEVICE_SIGNER_LOCKED')
        try:
            root, issuer = (x509.load_pem_x509_certificate(x) for x in authority[:2])
            # RSA private-key structural validation is expensive. Keep the
            # unattended key in memory, invalidating on vault/key/CA changes.
            # Never bypass validation with unsafe_skip_rsa_key_validation.
            vault_identity = digest(self.vault._key()) if os.name != 'nt' else 'current-user-dpapi'
            identity = (digest(row[1]),digest(authority[0]),digest(authority[1]),vault_identity)
            with self.signer_lock:
                if self.signer_cache is None or self.signer_cache[0] != identity:
                    key = serialization.load_pem_private_key(self.vault.open('device-issuer-key',row[1]).encode(),password=None)
                    self.signer_cache = (identity,key)
                key = self.signer_cache[1]
            root.verify_directly_issued_by(root)
            issuer.verify_directly_issued_by(root)
            if issuer.fingerprint(hashes.SHA256()).hex() != row[0] or public_der(key.public_key()) != public_der(issuer.public_key()):
                raise ValueError()
            if not root.not_valid_before_utc <= now < root.not_valid_after_utc or not issuer.not_valid_before_utc <= now < issuer.not_valid_after_utc:
                raise ValueError()
            for cert,length in ((root,1),(issuer,0)):
                constraints = cert.extensions.get_extension_for_class(x509.BasicConstraints)
                usage = cert.extensions.get_extension_for_class(x509.KeyUsage)
                if not constraints.critical or not constraints.value.ca or constraints.value.path_length != length:
                    raise ValueError()
                if not usage.critical or not usage.value.key_cert_sign or not usage.value.crl_sign:
                    raise ValueError()
                if not isinstance(cert.public_key(),rsa.RSAPublicKey) or cert.public_key().key_size != 3072 or not isinstance(cert.signature_hash_algorithm,hashes.SHA256):
                    raise ValueError()
            crl = x509.load_pem_x509_crl(authority[2])
            if not crl.is_signature_valid(issuer.public_key()) or crl.issuer != issuer.subject or crl.last_update_utc > now or crl.extensions.get_extension_for_class(x509.CRLNumber).value.crl_number != authority[3]:
                raise ValueError()
            return issuer, key, authority[3]
        except Exception:
            raise EnrollmentError('DEVICE_SIGNER_UNAVAILABLE') from None

    def save_profile(self, value, actor):
        fields = {'id', 'version', 'name', 'group_sid', 'validity_days', 'renew_before_days', 'enabled'}
        keys(value, fields, fields)
        identity = identifier(value['id']) if value['id'] else str(uuid.uuid4())
        integer(value['version'], 0, 2**31 - 2)
        name = text(value['name'], 80).strip()
        group = value['group_sid']
        if not name or type(group) is not str or not re.fullmatch(r'S-1-5-21-(?:[0-9]{1,10}-){2}[0-9]{1,10}-[0-9]{1,10}', group):
            raise EnrollmentError('DEVICE_INPUT_INVALID')
        integer(value['validity_days'], 2, 365)
        integer(value['renew_before_days'], 1, value['validity_days'] - 1)
        boolean(value['enabled'])
        config = self.store.snapshot()['config']
        if not config:
            raise EnrollmentError('DEVICE_DIRECTORY_NOT_READY')
        with self.transaction() as db:
            configured = db.execute('SELECT config FROM state WHERE id=1').fetchone()[0]
            if not configured or json.loads(configured)['ad_domain'] != config['ad_domain']:
                raise EnrollmentError('REVISION_CONFLICT')
            old = db.execute('SELECT version FROM device_profiles WHERE id=?', (identity,)).fetchone()
            if (old[0] if old else 0) != value['version']:
                raise EnrollmentError('REVISION_CONFLICT')
            if not old and db.execute('SELECT count(*) FROM device_profiles').fetchone()[0] >= 100:
                raise EnrollmentError('DEVICE_PROFILE_LIMIT')
            db.execute('INSERT OR REPLACE INTO device_profiles VALUES (?,?,?,?,?,?,?,?)',
                (identity, value['version'] + 1, name, config['ad_domain'], group, value['validity_days'], value['renew_before_days'], int(value['enabled'])))
            self.pki._audit(db, 'device_profile_saved:' + identity, actor)
        return {'id': identity, 'version': value['version'] + 1}

    def profile(self, identity):
        identifier(identity)
        with self.store.connect() as db:
            row = db.execute('SELECT * FROM device_profiles WHERE id=?', (identity,)).fetchone()
        if not row:
            raise EnrollmentError('DEVICE_PROFILE_NOT_FOUND')
        return dict(zip(('id','version','name','domain','group_sid','validity_days','renew_before_days','enabled'), row))

    def status(self, *, offset=0):
        integer(offset, 0, 100000)
        now = instant()
        with self.store.connect() as db:
            profiles = [dict(zip(('id','version','name','domain','group_sid','validity_days','renew_before_days','enabled'), x))
                for x in db.execute('SELECT * FROM device_profiles ORDER BY name,id')]
            signer = db.execute('SELECT 1 FROM device_signer').fetchone() is not None
            signer_ready = False
            if signer:
                try:
                    self._issuer(db,now)
                    signer_ready = True
                except EnrollmentError:
                    pass
            total = db.execute('SELECT count(*) FROM device_issuances').fetchone()[0]
            rows = db.execute('''SELECT d.serial,d.profile_id,d.principal,d.installed_at,d.last_seen,d.renew_at,
                c.certificate,c.revoked_at,b.object_guid FROM device_issuances d
                JOIN pki_certificates c ON c.serial=d.serial JOIN radius_certificate_bindings b ON b.serial=d.serial
                ORDER BY d.rowid DESC LIMIT 100 OFFSET ?''', (offset,)).fetchall()
        devices = []
        for serial, profile, principal, installed, seen, renew, pem, revoked, guid in rows:
            cert = x509.load_pem_x509_certificate(pem)
            state = 'revoked' if revoked else 'expired' if now >= cert.not_valid_after_utc else 'issued' if not installed else 'renewal_due' if now >= datetime.fromisoformat(renew) else 'installed'
            devices.append({'serial': serial, 'profile_id': profile, 'principal': principal, 'object_guid': guid,
                'status': state, 'installed_at': installed, 'last_seen': seen, 'renew_at': renew, 'not_after': cert.not_valid_after_utc.isoformat()})
        return {'profiles': profiles, 'devices': devices, 'total': total, 'offset': offset,
                'signer_enabled': signer, 'signer_ready':signer_ready, 'radius_changed': False}

    def _authorize(self, principal, profile):
        match = re.fullmatch(r'([A-Za-z0-9_][A-Za-z0-9_.-]{0,19}\$)@' + re.escape(profile['domain']), principal, re.I)
        if not match or not profile['enabled']:
            raise EnrollmentError('DEVICE_IDENTITY_REJECTED')
        snapshot = self.store.snapshot()
        settings = self.operations.directory()
        if not snapshot['config'] or snapshot['config']['ad_domain'] != profile['domain']:
            raise EnrollmentError('DEVICE_DIRECTORY_NOT_READY')
        connection = self.operations.directory_connection()
        try:
            account = self.resolver(connection, snapshot['config'], computer_sam=match[1])
            if type(account) is not CurrentDirectoryAccount or account.domain != profile['domain'] or account.kind != 'computer' or not account.enabled or profile['group_sid'] not in account.security_group_sids:
                raise EnrollmentError('DEVICE_IDENTITY_REJECTED')
            if self.store.snapshot()['revision'] != snapshot['revision'] or self.operations.directory() != settings:
                raise EnrollmentError('REVISION_CONFLICT')
            return account, snapshot['revision'], settings
        except DirectoryError:
            raise EnrollmentError('DEVICE_DIRECTORY_UNAVAILABLE') from None
        finally:
            connection['password'] = ''

    def challenge(self, principal, value):
        keys(value, {'profile_id','csr'}, {'profile_id','csr'})
        profile = self.profile(value['profile_id'])
        csr = client_csr(value['csr'].encode('ascii'))
        if not self.gate.acquire(blocking=False):
            raise EnrollmentError('DEVICE_BUSY')
        try:
            self._authorize(principal, profile)
            now = instant()
            identity = str(uuid.uuid4())
            payload = json.dumps({'purpose':'AuthWire device enrollment', 'challenge': identity,
                'principal': principal.casefold(), 'profile': profile['id'], 'version': profile['version'],
                'csr_sha256': digest(csr.public_bytes(serialization.Encoding.DER)), 'nonce':secrets.token_hex(32)}, separators=(',', ':'))
            with self.transaction() as db:
                self._issuer(db, now)
                db.execute('DELETE FROM device_challenges WHERE expires<?', (time.time(),))
                db.execute('DELETE FROM device_rate WHERE window<?', (time.time()-3600,))
                rate = db.execute('SELECT window,attempts FROM device_rate WHERE principal=?', (principal.casefold(),)).fetchone()
                if rate and time.time()-rate[0] < 60 and rate[1] >= 10:
                    raise EnrollmentError('DEVICE_RETRY_LATER')
                window, attempts = rate if rate and time.time()-rate[0] < 60 else (time.time(),0)
                db.execute('INSERT OR REPLACE INTO device_rate VALUES (?,?,?)', (principal.casefold(),window,attempts+1))
                if db.execute('SELECT count(*) FROM device_challenges').fetchone()[0] >= 10000:
                    raise EnrollmentError('DEVICE_BUSY')
                db.execute('INSERT INTO device_challenges VALUES (?,?,?,?,?,?,?,NULL)',
                    (identity, principal.casefold(), profile['id'], profile['version'], digest(csr.public_bytes(serialization.Encoding.DER)), payload, time.time()+300))
            return {'challenge_id':identity, 'payload':base64.b64encode(payload.encode()).decode('ascii')}
        finally:
            self.gate.release()

    @staticmethod
    def proof(key, payload, signature):
        try:
            if type(signature) is not str or len(signature) > 8192:
                raise ValueError()
            signature = base64.b64decode(signature, validate=True)
            if isinstance(key, rsa.RSAPublicKey):
                key.verify(signature, payload, padding.PKCS1v15(), hashes.SHA256())
            elif isinstance(key, ec.EllipticCurvePublicKey):
                key.verify(signature, payload, ec.ECDSA(hashes.SHA256()))
            else:
                raise ValueError()
        except (ValueError, InvalidSignature):
            raise EnrollmentError('DEVICE_KEY_PROOF_REJECTED') from None

    def _result(self, db, serial):
        row = db.execute('''SELECT c.certificate,c.revoked_at,d.renew_at,d.receipt_payload FROM
            pki_certificates c JOIN device_issuances d ON d.serial=c.serial WHERE c.serial=?''', (serial,)).fetchone()
        if not row or row[1]:
            raise EnrollmentError('DEVICE_CERTIFICATE_REVOKED')
        cert = x509.load_pem_x509_certificate(row[0])
        if instant() >= cert.not_valid_after_utc:
            raise EnrollmentError('DEVICE_CERTIFICATE_EXPIRED')
        return {'serial': serial, 'certificate': row[0].decode('ascii'), 'renew_at': row[2],
            'receipt_payload': base64.b64encode(row[3].encode()).decode('ascii'), 'not_after':cert.not_valid_after_utc.isoformat()}

    def issue(self, principal, value):
        keys(value, {'challenge_id','csr','proof'}, {'challenge_id','csr','proof'})
        identifier(value['challenge_id'])
        csr = client_csr(value['csr'].encode('ascii'))
        csr_hash = digest(csr.public_bytes(serialization.Encoding.DER))
        with self.store.connect() as db:
            challenge = db.execute('SELECT * FROM device_challenges WHERE id=?', (value['challenge_id'],)).fetchone()
        if not challenge or challenge[1] != principal.casefold() or challenge[4] != csr_hash or time.time() >= challenge[6]:
            raise EnrollmentError('DEVICE_CHALLENGE_REJECTED')
        self.proof(csr.public_key(), challenge[5].encode(), value['proof'])
        profile = self.profile(challenge[2])
        if profile['version'] != challenge[3]:
            raise EnrollmentError('REVISION_CONFLICT')
        if not self.gate.acquire(blocking=False):
            raise EnrollmentError('DEVICE_BUSY')
        try:
            account, revision, settings = self._authorize(principal, profile)
            now = instant()
            with self.transaction() as db:
                if time.time() >= challenge[6]:
                    raise EnrollmentError('DEVICE_CHALLENGE_REJECTED')
                if db.execute('SELECT revision FROM state WHERE id=1').fetchone()[0] != revision or self.operations.directory() != settings:
                    raise EnrollmentError('REVISION_CONFLICT')
                if db.execute('SELECT version,enabled FROM device_profiles WHERE id=?', (profile['id'],)).fetchone() != (profile['version'],1):
                    raise EnrollmentError('REVISION_CONFLICT')
                issuer, key, _ = self._issuer(db, now)
                old = db.execute('''SELECT d.serial,d.principal,d.profile_id,b.object_guid,b.sid FROM device_issuances d
                    JOIN radius_certificate_bindings b ON b.serial=d.serial WHERE d.csr_sha256=?''', (csr_hash,)).fetchone()
                if old:
                    if old[1:] != (principal.casefold(), profile['id'], account.object_guid,account.sid):
                        raise EnrollmentError('DEVICE_IDENTITY_REJECTED')
                    return self._result(db, old[0])
                if db.execute('SELECT serial FROM device_challenges WHERE id=?', (challenge[0],)).fetchone()[0]:
                    raise EnrollmentError('DEVICE_CHALLENGE_REJECTED')
                key_hash = digest(public_der(csr.public_key()))
                if db.execute('SELECT 1 FROM pki_client_keys WHERE csr_sha256=? OR public_sha256=?', (csr_hash,key_hash)).fetchone():
                    raise EnrollmentError('CSR_ALREADY_USED')
                latest = db.execute('''SELECT d.serial,d.installed_at,d.renew_at,c.revoked_at,c.certificate FROM device_issuances d
                    JOIN pki_certificates c ON c.serial=d.serial WHERE d.principal=? AND d.profile_id=? ORDER BY d.rowid DESC LIMIT 1''',
                    (principal.casefold(),profile['id'])).fetchone()
                if latest and not latest[3] and now < x509.load_pem_x509_certificate(latest[4]).not_valid_after_utc:
                    if not latest[1]:
                        raise EnrollmentError('DEVICE_INSTALLATION_PENDING')
                    if now < datetime.fromisoformat(latest[2]):
                        raise EnrollmentError('DEVICE_RENEWAL_NOT_DUE')
                if db.execute('SELECT count(*) FROM pki_certificates').fetchone()[0] >= 100000:
                    raise EnrollmentError('CERTIFICATE_LIMIT')
                end = min(now+timedelta(days=profile['validity_days']),issuer.not_valid_after_utc)
                if end-now <= timedelta(days=profile['renew_before_days']):
                    raise EnrollmentError('DEVICE_ISSUER_RENEWAL_REQUIRED')
                cert = (x509.CertificateBuilder().subject_name(x509.Name([x509.NameAttribute(NameOID.COMMON_NAME,'AuthWire computer '+account.object_guid)]))
                    .issuer_name(issuer.subject).public_key(csr.public_key()).serial_number(x509.random_serial_number())
                    .not_valid_before(max(now-timedelta(minutes=5),issuer.not_valid_before_utc)).not_valid_after(end)
                    .add_extension(x509.BasicConstraints(ca=False,path_length=None),critical=True)
                    .add_extension(x509.KeyUsage(True,False,False,False,False,False,False,False,False),critical=True)
                    .add_extension(x509.ExtendedKeyUsage([ExtendedKeyUsageOID.CLIENT_AUTH]),critical=False)
                    .add_extension(x509.SubjectKeyIdentifier.from_public_key(csr.public_key()),critical=False)
                    .add_extension(x509.AuthorityKeyIdentifier.from_issuer_public_key(key.public_key()),critical=False).sign(key,hashes.SHA256()))
                serial, pem = format(cert.serial_number,'x'), cert.public_bytes(PEM)
                receipt = 'AuthWire installed\n'+serial+'\n'+secrets.token_hex(32)
                db.execute('INSERT INTO pki_certificates(serial,certificate) VALUES (?,?)',(serial,pem))
                db.execute('INSERT INTO radius_certificate_bindings VALUES (?,?,?,?,?,?,1)',
                    (issuer.fingerprint(hashes.SHA256()).hex(),serial,account.domain,account.object_guid,account.sid,'computer'))
                db.execute('INSERT INTO pki_client_keys VALUES (?,?,?)',(serial,csr_hash,key_hash))
                db.execute('INSERT INTO device_issuances VALUES (?,?,?,?,?,NULL,?,?,?)',
                    (serial,profile['id'],profile['version'],principal.casefold(),csr_hash,now.isoformat(),(end-timedelta(days=profile['renew_before_days'])).isoformat(),receipt))
                db.execute('UPDATE device_challenges SET serial=? WHERE id=?',(serial,challenge[0]))
                self.pki._audit(db,'device_certificate_issued:'+serial)
                return self._result(db,serial)
        finally:
            self.gate.release()

    def receipt(self, principal, value):
        keys(value, {'serial','proof'}, {'serial','proof'})
        from .radius import serial_number
        serial = serial_number(value['serial'])
        now = instant()
        with self.transaction() as db:
            row = db.execute('''SELECT d.principal,d.profile_id,d.receipt_payload,d.installed_at,c.certificate,c.revoked_at FROM
                device_issuances d JOIN pki_certificates c ON c.serial=d.serial WHERE d.serial=?''',(serial,)).fetchone()
            if not row or row[0] != principal.casefold() or row[5]:
                raise EnrollmentError('DEVICE_IDENTITY_REJECTED')
            cert = x509.load_pem_x509_certificate(row[4])
            if not cert.not_valid_before_utc <= now < cert.not_valid_after_utc:
                raise EnrollmentError('DEVICE_CERTIFICATE_EXPIRED')
            self.proof(cert.public_key(),row[2].encode(),value['proof'])
            db.execute('UPDATE device_issuances SET installed_at=COALESCE(installed_at,?),last_seen=? WHERE serial=?',(now.isoformat(),now.isoformat(),serial))
            if not row[3]:
                for old in db.execute('''SELECT d.serial,c.certificate FROM device_issuances d JOIN pki_certificates c ON c.serial=d.serial
                    WHERE d.principal=? AND d.profile_id=? AND d.serial<>? AND d.installed_at IS NOT NULL AND c.revoked_at IS NULL''',(row[0],row[1],serial)).fetchall():
                    previous = x509.load_pem_x509_certificate(old[1])
                    deadline = min(now+timedelta(hours=24),previous.not_valid_after_utc)
                    db.execute('INSERT OR IGNORE INTO device_retirements VALUES (?,?)',(old[0],deadline.isoformat()))
                self.pki._audit(db,'device_certificate_installed:'+serial)
        return {'installed':True,'serial':serial}

    def maintenance(self):
        now = instant()
        with self.transaction() as db:
            due = db.execute('''SELECT r.serial FROM device_retirements r JOIN pki_certificates c ON c.serial=r.serial
                WHERE r.retire_at<=? AND c.revoked_at IS NULL''',(now.isoformat(),)).fetchall()
            authority = db.execute('SELECT crl FROM pki_authority WHERE id=1').fetchone()
            refresh_due = bool(authority) and x509.load_pem_x509_crl(authority[0]).next_update_utc <= now+timedelta(hours=12)
            if not due and not refresh_due:
                return
            issuer, key, number = self._issuer(db,now)
            for serial, in due:
                db.execute("UPDATE pki_certificates SET revoked_at=?,reason='superseded' WHERE serial=?",(now.isoformat(),serial))
                self.pki._audit(db,'device_certificate_superseded:'+serial)
            rows = db.execute('SELECT serial,revoked_at,reason FROM pki_certificates WHERE revoked_at IS NOT NULL ORDER BY serial').fetchall()
            crl = self.pki._build_crl(issuer,key,rows,number+1,now)
            db.execute('UPDATE pki_authority SET crl=?,crl_number=? WHERE id=1',(crl.public_bytes(PEM),number+1))
            if not due:
                self.pki._audit(db,'device_crl_refreshed')

    def package(self, profile_id, *, hostname, port, tls_pem):
        profile = self.profile(profile_id)
        hostname = dns_name(hostname)
        tls_cert = x509.load_pem_x509_certificate(tls_pem)
        # No IP URLs, arbitrary names or insecure TLS callbacks in deployment.
        names = tls_cert.extensions.get_extension_for_class(x509.SubjectAlternativeName).value.get_values_for_type(x509.DNSName)
        if hostname not in names:
            raise EnrollmentError('DEVICE_TLS_NAME_MISMATCH')
        bundle = self.pki.public_bundle()
        files = {'root-ca.pem':bundle['root-ca.pem'],'issuer-ca.pem':bundle['issuer-ca.pem']}
        if tls_cert.issuer == tls_cert.subject:
            tls_cert.verify_directly_issued_by(tls_cert)
            files['https-trust.pem'] = tls_pem
        directory = Path(__file__).parent/'device_client'
        for name in ('AuthWire-Client.ps1','Install-AuthWire.ps1'):
            files[name] = (directory/name).read_bytes()
        files['config.json'] = json.dumps({'url':f'https://{hostname}:{port}', 'spn':'HTTP/'+hostname,
            'domain':profile['domain'], 'profile_id':profile_id, 'tls_sha256':tls_cert.fingerprint(hashes.SHA256()).hex()},indent=2).encode()
        asset_hashes = json.dumps({name:digest(data) for name,data in sorted(files.items())
            if name.endswith('.pem') or name=='config.json'},sort_keys=True,separators=(',',':'))
        files['Install-AuthWire.ps1'] = files['Install-AuthWire.ps1'].replace(b'__AUTHWIRE_ASSET_HASHES__',asset_hashes.encode())
        files['README.txt'] = ('AuthWire certificate deployment pilot\r\n'
            '1. Sign BOTH .ps1 files with your trusted enterprise Authenticode publisher.\r\n'
            '2. Put the whole package in an administrator-write-only SYSVOL/share.\r\n'
            '3. Deploy Install-AuthWire.ps1 as a Computer startup script to a pilot OU.\r\n'
            '   Use AllSigned; trust the publisher through GPO. Do not use Bypass.\r\n'
            '4. Enable the profile after verifying HTTP SPN/keytab and HTTPS DNS trust.\r\n'
            'No 802.1X, switch configuration or RADIUS activation is included.\r\n'
            'Domain SYSTEM identity only. No password, CA private key or shared certificate.\r\n').encode()
        files['SHA256SUMS.txt'] = '\n'.join(digest(data)+'  '+name for name,data in sorted(files.items())).encode()
        output = io.BytesIO()
        with zipfile.ZipFile(output,'w',zipfile.ZIP_DEFLATED) as archive:
            for name,data in files.items():
                archive.writestr(name,data)
        return output.getvalue()
