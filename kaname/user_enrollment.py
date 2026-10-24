"""Opt-in user enrollment backend; verified Kerberos principal, never a password.

User profiles and requests are separate from machine enrollment. The existing
protected issuer, database write lock, registry and retirement mechanism are
shared; the endpoint keeps its private key. No profile is created automatically.
Windows CurrentUser installation/distribution is a separate acceptance step.
"""
import base64
import json
import io
import zipfile
from pathlib import Path
import re
import secrets
import time
import uuid
from datetime import datetime, timedelta

from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.x509.oid import ExtendedKeyUsageOID, NameOID

from .device_enrollment import digest, identifier
from .directory import DirectoryError
from .directory_linux import read_linux_directory
from .enrollment import EnrollmentError, client_csr
from .models import boolean, dns_name, integer, keys, text
from .pki import PEM, instant, public_der
from .radius import CurrentDirectoryAccount, account_sid, serial_number


class UserEnrollment:
    def __init__(self, devices, *, resolver=read_linux_directory):
        self.devices, self.resolver = devices, resolver
        self.operations, self.store, self.pki = devices.operations, devices.store, devices.pki
        # Reuse the bounded enrollment worker budget and SQLite writer lock.
        self.gate, self.transaction = devices.gate, devices.transaction
        with self.transaction() as db:
            for statement in (
                '''CREATE TABLE IF NOT EXISTS user_enrollment_profiles (
                    id TEXT PRIMARY KEY, version INTEGER NOT NULL, name TEXT NOT NULL,
                    domain TEXT NOT NULL, group_sid TEXT NOT NULL, validity_days INTEGER NOT NULL,
                    renew_before_days INTEGER NOT NULL, enabled INTEGER NOT NULL)''',
                '''CREATE TABLE IF NOT EXISTS user_enrollment_challenges (
                    id TEXT PRIMARY KEY, principal TEXT NOT NULL, profile_id TEXT NOT NULL,
                    profile_version INTEGER NOT NULL, csr_sha256 TEXT NOT NULL,
                    object_guid TEXT NOT NULL, sid TEXT NOT NULL, payload TEXT NOT NULL,
                    expires REAL NOT NULL)''',
                '''CREATE TABLE IF NOT EXISTS user_enrollment_issuances (
                    serial TEXT PRIMARY KEY REFERENCES pki_certificates(serial),
                    profile_id TEXT NOT NULL, principal TEXT NOT NULL, csr_sha256 TEXT NOT NULL UNIQUE,
                    installed_at TEXT, last_seen TEXT NOT NULL, renew_at TEXT NOT NULL,
                    receipt_payload TEXT NOT NULL)''',
                '''CREATE INDEX IF NOT EXISTS user_enrollment_owner
                    ON user_enrollment_issuances(profile_id,principal)''',
                '''CREATE TABLE IF NOT EXISTS user_enrollment_rate (
                    principal TEXT PRIMARY KEY, window REAL NOT NULL, attempts INTEGER NOT NULL)''',
            ):
                db.execute(statement)

    def save_profile(self, value, actor):
        fields = {'id', 'version', 'name', 'group_sid', 'validity_days', 'renew_before_days', 'enabled'}
        keys(value, fields, fields)
        identity = identifier(value['id']) if value['id'] else str(uuid.uuid4())
        integer(value['version'], 0, 2**31 - 2)
        name = text(value['name'], 80).strip()
        if not name:
            raise EnrollmentError('USER_INPUT_INVALID')
        account_sid(value['group_sid'])
        integer(value['validity_days'], 2, 365)
        integer(value['renew_before_days'], 1, value['validity_days'] - 1)
        boolean(value['enabled'])
        with self.transaction() as db:
            config = json.loads(db.execute('SELECT config FROM state WHERE id=1').fetchone()[0] or 'null')
            if not config:
                raise EnrollmentError('USER_DIRECTORY_NOT_READY')
            old = db.execute('SELECT version FROM user_enrollment_profiles WHERE id=?', (identity,)).fetchone()
            if (old[0] if old else 0) != value['version']:
                raise EnrollmentError('REVISION_CONFLICT')
            if not old and db.execute('SELECT count(*) FROM user_enrollment_profiles').fetchone()[0] >= 100:
                raise EnrollmentError('USER_PROFILE_LIMIT')
            db.execute('INSERT OR REPLACE INTO user_enrollment_profiles VALUES (?,?,?,?,?,?,?,?)',
                (identity, value['version'] + 1, name, config['ad_domain'], value['group_sid'],
                 value['validity_days'], value['renew_before_days'], int(value['enabled'])))
            self.pki._audit(db, 'user_profile_saved:' + identity, actor)
        return {'id': identity, 'version': value['version'] + 1}

    def profile(self, identity):
        identifier(identity)
        with self.store.connect() as db:
            row = db.execute('SELECT * FROM user_enrollment_profiles WHERE id=?', (identity,)).fetchone()
        if not row:
            raise EnrollmentError('USER_PROFILE_NOT_FOUND')
        return dict(zip(('id', 'version', 'name', 'domain', 'group_sid', 'validity_days', 'renew_before_days', 'enabled'), row))

    def _authorize(self, principal, profile):
        if type(principal) is not str:
            raise EnrollmentError('USER_IDENTITY_REJECTED')
        match = re.fullmatch(r'([A-Za-z0-9_][A-Za-z0-9_.-]{0,19})@' + re.escape(profile['domain']), principal, re.I)
        if not match or not profile['enabled']:
            raise EnrollmentError('USER_IDENTITY_REJECTED')
        snapshot, settings = self.store.snapshot(), self.operations.directory()
        if not snapshot['config'] or snapshot['config']['ad_domain'] != profile['domain']:
            raise EnrollmentError('USER_DIRECTORY_NOT_READY')
        connection = self.operations.directory_connection()
        try:
            account = self.resolver(connection, snapshot['config'], user_sam=match[1])
            if type(account) is not CurrentDirectoryAccount or account.domain != profile['domain'] or account.kind != 'user' or not account.enabled or profile['group_sid'] not in account.security_group_sids:
                raise EnrollmentError('USER_IDENTITY_REJECTED')
            if self.store.snapshot()['revision'] != snapshot['revision'] or self.operations.directory() != settings:
                raise EnrollmentError('REVISION_CONFLICT')
            return account, snapshot['revision'], settings
        except DirectoryError:
            raise EnrollmentError('USER_DIRECTORY_UNAVAILABLE') from None
        finally:
            connection['password'] = ''

    def challenge(self, principal, value):
        keys(value, {'profile_id', 'csr'}, {'profile_id', 'csr'})
        profile = self.profile(value['profile_id'])
        csr = client_csr(value['csr'].encode('ascii'))
        if not self.gate.acquire(blocking=False):
            raise EnrollmentError('USER_BUSY')
        try:
            account, _, _ = self._authorize(principal, profile)
            identity, now = str(uuid.uuid4()), instant()
            csr_hash = digest(csr.public_bytes(serialization.Encoding.DER))
            payload = json.dumps({'purpose': 'AuthWire user enrollment', 'challenge': identity,
                'principal': principal.casefold(), 'profile': profile['id'], 'version': profile['version'],
                'object_guid': account.object_guid, 'sid': account.sid, 'csr_sha256': csr_hash,
                'nonce': secrets.token_hex(32)}, separators=(',', ':'))
            with self.transaction() as db:
                self.devices._issuer(db, now)
                timestamp = time.time()
                db.execute('DELETE FROM user_enrollment_challenges WHERE expires<?', (timestamp,))
                db.execute('DELETE FROM user_enrollment_rate WHERE window<?', (timestamp - 3600,))
                rate = db.execute('SELECT window,attempts FROM user_enrollment_rate WHERE principal=?', (principal.casefold(),)).fetchone()
                if rate and timestamp - rate[0] < 60 and rate[1] >= 10:
                    raise EnrollmentError('USER_RETRY_LATER')
                window, count = rate if rate and timestamp - rate[0] < 60 else (timestamp, 0)
                if db.execute('SELECT count(*) FROM user_enrollment_challenges').fetchone()[0] >= 10000:
                    raise EnrollmentError('USER_BUSY')
                db.execute('INSERT OR REPLACE INTO user_enrollment_rate VALUES (?,?,?)', (principal.casefold(), window, count + 1))
                db.execute('INSERT INTO user_enrollment_challenges VALUES (?,?,?,?,?,?,?,?,?)',
                    (identity, principal.casefold(), profile['id'], profile['version'], csr_hash,
                     account.object_guid, account.sid, payload, timestamp + 300))
            return {'challenge_id': identity, 'payload': base64.b64encode(payload.encode()).decode('ascii')}
        finally:
            self.gate.release()

    def _result(self, db, serial):
        row = db.execute('''SELECT c.certificate,c.revoked_at,u.renew_at,u.receipt_payload FROM
            pki_certificates c JOIN user_enrollment_issuances u ON u.serial=c.serial WHERE c.serial=?''', (serial,)).fetchone()
        if not row or row[1]:
            raise EnrollmentError('USER_CERTIFICATE_REVOKED')
        cert = x509.load_pem_x509_certificate(row[0])
        if instant() >= cert.not_valid_after_utc:
            raise EnrollmentError('USER_CERTIFICATE_EXPIRED')
        return {'serial': serial, 'certificate': row[0].decode('ascii'), 'renew_at': row[2],
            'receipt_payload': base64.b64encode(row[3].encode()).decode('ascii'),
            'not_after': cert.not_valid_after_utc.isoformat(), 'kind': 'user'}

    def issue(self, principal, value):
        keys(value, {'challenge_id', 'csr', 'proof'}, {'challenge_id', 'csr', 'proof'})
        identity = identifier(value['challenge_id'])
        csr = client_csr(value['csr'].encode('ascii'))
        csr_hash = digest(csr.public_bytes(serialization.Encoding.DER))
        with self.store.connect() as db:
            challenge = db.execute('SELECT * FROM user_enrollment_challenges WHERE id=?', (identity,)).fetchone()
        if not challenge or challenge[1] != principal.casefold() or challenge[4] != csr_hash or time.time() >= challenge[8]:
            raise EnrollmentError('USER_CHALLENGE_REJECTED')
        self.devices.proof(csr.public_key(), challenge[7].encode(), value['proof'])
        profile = self.profile(challenge[2])
        if profile['version'] != challenge[3]:
            raise EnrollmentError('REVISION_CONFLICT')
        if not self.gate.acquire(blocking=False):
            raise EnrollmentError('USER_BUSY')
        try:
            account, revision, settings = self._authorize(principal, profile)
            if (account.object_guid, account.sid) != (challenge[5], challenge[6]):
                raise EnrollmentError('USER_IDENTITY_REJECTED')
            now = instant()
            with self.transaction() as db:
                if time.time() >= challenge[8]:
                    raise EnrollmentError('USER_CHALLENGE_REJECTED')
                if db.execute('SELECT revision FROM state WHERE id=1').fetchone()[0] != revision or self.operations.directory() != settings:
                    raise EnrollmentError('REVISION_CONFLICT')
                if db.execute('SELECT version,enabled FROM user_enrollment_profiles WHERE id=?', (profile['id'],)).fetchone() != (profile['version'], 1):
                    raise EnrollmentError('REVISION_CONFLICT')
                issuer, key, _ = self.devices._issuer(db, now)
                old = db.execute('''SELECT u.serial,u.principal,u.profile_id,b.object_guid,b.sid FROM
                    user_enrollment_issuances u JOIN radius_certificate_bindings b ON b.serial=u.serial
                    WHERE u.csr_sha256=?''', (csr_hash,)).fetchone()
                if old:
                    if old[1:] != (principal.casefold(), profile['id'], account.object_guid, account.sid):
                        raise EnrollmentError('USER_IDENTITY_REJECTED')
                    return self._result(db, old[0])
                key_hash = digest(public_der(csr.public_key()))
                if db.execute('SELECT 1 FROM pki_client_keys WHERE csr_sha256=? OR public_sha256=?', (csr_hash, key_hash)).fetchone():
                    raise EnrollmentError('CSR_ALREADY_USED')
                latest = db.execute('''SELECT u.installed_at,u.renew_at,c.revoked_at,c.certificate
                    FROM user_enrollment_issuances u JOIN pki_certificates c ON c.serial=u.serial
                    WHERE u.principal=? AND u.profile_id=? ORDER BY u.rowid DESC LIMIT 1''', (principal.casefold(), profile['id'])).fetchone()
                if latest and not latest[2] and now < x509.load_pem_x509_certificate(latest[3]).not_valid_after_utc:
                    if not latest[0]:
                        raise EnrollmentError('USER_INSTALLATION_PENDING')
                    if now < datetime.fromisoformat(latest[1]):
                        raise EnrollmentError('USER_RENEWAL_NOT_DUE')
                if db.execute('SELECT count(*) FROM pki_certificates').fetchone()[0] >= 100000:
                    raise EnrollmentError('CERTIFICATE_LIMIT')
                end = min(now + timedelta(days=profile['validity_days']), issuer.not_valid_after_utc)
                if end - now <= timedelta(days=profile['renew_before_days']):
                    raise EnrollmentError('USER_ISSUER_RENEWAL_REQUIRED')
                cert = (x509.CertificateBuilder().subject_name(x509.Name([x509.NameAttribute(NameOID.COMMON_NAME, 'AuthWire user ' + account.object_guid)]))
                    .issuer_name(issuer.subject).public_key(csr.public_key()).serial_number(x509.random_serial_number())
                    .not_valid_before(max(now - timedelta(minutes=5), issuer.not_valid_before_utc)).not_valid_after(end)
                    .add_extension(x509.BasicConstraints(ca=False, path_length=None), critical=True)
                    .add_extension(x509.KeyUsage(True, False, False, False, False, False, False, False, False), critical=True)
                    .add_extension(x509.ExtendedKeyUsage([ExtendedKeyUsageOID.CLIENT_AUTH]), critical=False)
                    .add_extension(x509.SubjectKeyIdentifier.from_public_key(csr.public_key()), critical=False)
                    .add_extension(x509.AuthorityKeyIdentifier.from_issuer_public_key(key.public_key()), critical=False).sign(key, hashes.SHA256()))
                serial, pem = format(cert.serial_number, 'x'), cert.public_bytes(PEM)
                receipt = 'AuthWire user installed\n' + serial + '\n' + secrets.token_hex(32)
                db.execute('INSERT INTO pki_certificates(serial,certificate) VALUES (?,?)', (serial, pem))
                db.execute('INSERT INTO radius_certificate_bindings VALUES (?,?,?,?,?,?,1)',
                    (issuer.fingerprint(hashes.SHA256()).hex(), serial, account.domain, account.object_guid, account.sid, 'user'))
                db.execute('INSERT INTO pki_client_keys VALUES (?,?,?)', (serial, csr_hash, key_hash))
                db.execute('INSERT INTO user_enrollment_issuances VALUES (?,?,?,?,NULL,?,?,?)',
                    (serial, profile['id'], principal.casefold(), csr_hash, now.isoformat(), (end - timedelta(days=profile['renew_before_days'])).isoformat(), receipt))
                self.pki._audit(db, 'user_certificate_issued:' + serial)
                return self._result(db, serial)
        finally:
            self.gate.release()

    def receipt(self, principal, value):
        keys(value, {'serial', 'proof'}, {'serial', 'proof'})
        serial, now = serial_number(value['serial']), instant()
        with self.store.connect() as db:
            row = db.execute('''SELECT u.principal,u.profile_id,u.receipt_payload,u.installed_at,
                u.renew_at,c.certificate,c.revoked_at,b.object_guid,b.sid FROM user_enrollment_issuances u
                JOIN pki_certificates c ON c.serial=u.serial JOIN radius_certificate_bindings b ON b.serial=u.serial
                WHERE u.serial=?''', (serial,)).fetchone()
        if not row or row[0] != principal.casefold() or row[6]:
            raise EnrollmentError('USER_IDENTITY_REJECTED')
        cert = x509.load_pem_x509_certificate(row[5])
        if not cert.not_valid_before_utc <= now < cert.not_valid_after_utc:
            raise EnrollmentError('USER_CERTIFICATE_EXPIRED')
        self.devices.proof(cert.public_key(), row[2].encode(), value['proof'])
        profile = self.profile(row[1])
        if not self.gate.acquire(blocking=False):
            raise EnrollmentError('USER_BUSY')
        try:
            account, revision, settings = self._authorize(principal, profile)
            if (account.object_guid, account.sid) != (row[7], row[8]):
                raise EnrollmentError('USER_IDENTITY_REJECTED')
            with self.transaction() as db:
                # Directory lookup/another writer may have consumed the last
                # valid seconds. Never retire a working leaf for an expired replacement.
                now = instant()
                if not cert.not_valid_before_utc <= now < cert.not_valid_after_utc:
                    raise EnrollmentError('USER_CERTIFICATE_EXPIRED')
                if db.execute('SELECT revision FROM state WHERE id=1').fetchone()[0] != revision or self.operations.directory() != settings:
                    raise EnrollmentError('REVISION_CONFLICT')
                if db.execute('SELECT version,enabled FROM user_enrollment_profiles WHERE id=?', (profile['id'],)).fetchone() != (profile['version'], 1):
                    raise EnrollmentError('REVISION_CONFLICT')
                state = db.execute('''SELECT u.installed_at,c.revoked_at FROM user_enrollment_issuances u
                    JOIN pki_certificates c ON c.serial=u.serial WHERE u.serial=?''', (serial,)).fetchone()
                if not state or state[1]:
                    raise EnrollmentError('USER_IDENTITY_REJECTED')
                db.execute('UPDATE user_enrollment_issuances SET installed_at=COALESCE(installed_at,?),last_seen=? WHERE serial=?', (now.isoformat(), now.isoformat(), serial))
                if not state[0]:
                    for old, pem in db.execute('''SELECT u.serial,c.certificate FROM user_enrollment_issuances u
                        JOIN pki_certificates c ON c.serial=u.serial WHERE u.principal=? AND u.profile_id=?
                        AND u.serial<>? AND u.installed_at IS NOT NULL AND c.revoked_at IS NULL''', (row[0], row[1], serial)).fetchall():
                        deadline = min(now + timedelta(hours=24), x509.load_pem_x509_certificate(pem).not_valid_after_utc)
                        db.execute('INSERT OR IGNORE INTO device_retirements VALUES (?,?)', (old, deadline.isoformat()))
                    self.pki._audit(db, 'user_certificate_installed:' + serial)
            return {'installed': True, 'serial': serial, 'renew_now': now >= datetime.fromisoformat(row[4])}
        finally:
            self.gate.release()

    def request_renewal(self, serial, actor):
        serial, now = serial_number(serial), instant()
        with self.transaction() as db:
            row = db.execute('''SELECT u.installed_at,c.revoked_at,c.certificate FROM user_enrollment_issuances u
                JOIN pki_certificates c ON c.serial=u.serial WHERE u.serial=?''', (serial,)).fetchone()
            if not row or not row[0] or row[1] or not x509.load_pem_x509_certificate(row[2]).not_valid_before_utc <= now < x509.load_pem_x509_certificate(row[2]).not_valid_after_utc:
                raise EnrollmentError('USER_CERTIFICATE_UNAVAILABLE')
            db.execute('UPDATE user_enrollment_issuances SET renew_at=? WHERE serial=?', (now.isoformat(), serial))
            self.pki._audit(db, 'user_renewal_requested:' + serial, actor)
        return {'serial': serial, 'renewal_due': True, 'renew_at': now.isoformat()}

    def package(self, profile_id, *, hostname, port, tls_pem):
        profile = self.profile(profile_id)
        hostname = dns_name(hostname)
        integer(port, 1, 65535)
        tls = x509.load_pem_x509_certificate(tls_pem)
        names = tls.extensions.get_extension_for_class(x509.SubjectAlternativeName).value.get_values_for_type(x509.DNSName)
        if hostname not in names:
            raise EnrollmentError('USER_TLS_NAME_MISMATCH')
        bundle = self.pki.public_bundle()
        files = {name: bundle[name] for name in ('root-ca.pem', 'issuer-ca.pem')}
        if tls.issuer == tls.subject:
            tls.verify_directly_issued_by(tls)
            files['https-trust.pem'] = tls_pem
        files['config.json'] = json.dumps({'kind':'user', 'url':f'https://{hostname}:{port}',
            'spn':'HTTP/'+hostname, 'domain':profile['domain'], 'profile_id':profile_id,
            'tls_sha256':tls.fingerprint(hashes.SHA256()).hex()}, sort_keys=True, indent=2).encode()
        pins = json.dumps({name:digest(data) for name,data in files.items()}, sort_keys=True, separators=(',', ':')).encode()
        for name in ('AuthWire-User-Client.ps1', 'Install-AuthWire-User.ps1'):
            source = (Path(__file__).parent/'device_client'/name).read_bytes()
            if source.count(b'__AUTHWIRE_USER_ASSET_HASHES__') != 1:
                raise EnrollmentError('USER_PACKAGE_INVALID')
            files[name] = source.replace(b'__AUTHWIRE_USER_ASSET_HASHES__', pins)
        files['README.txt'] = ("AuthWire USER certificate enrollment pilot\r\n"
            "Sign BOTH PowerShell files with the same trusted enterprise Authenticode publisher.\r\n"
            "Their signatures bind config and public trust assets. Do not edit assets after signing.\r\n"
            "Publish on an administrator-write-only SYSVOL/share. Use a USER Configuration logon script:\r\n"
            "powershell.exe -NoProfile -NonInteractive -ExecutionPolicy AllSigned -File <Install-AuthWire-User.ps1>\r\n"
            "Signing publisher and CA/HTTPS roots must be deployed through approved GPO beforehand.\r\n"
            "Never deploy this installer as SYSTEM/computer startup, and never use Bypass or shared PFX.\r\n"
            "It installs into the current user's LocalAppData, validates predeployed root trust\r\n"
            "and registers a limited InteractiveToken task for that SID/profile.\r\n"
            "Logon and 5-minute checks honor a persistent 10-minute to 12-hour retry backoff.\r\n"
            "Healthy enrollment checks occur every 6 hours; no task stores a user password.\r\n"
            "Private keys are non-exportable CurrentUser CNG keys; no machine certificate/task is changed.\r\n"
            "Ethernet/WiFi 802.1X settings and GPO creation/linking are NOT included in this package.\r\n"
            "Real domain logon/GPO, EAP-TLS wired/WiFi and user/computer transition acceptance remain open.\r\n").encode()
        files['SHA256SUMS.txt'] = ('\n'.join(digest(data)+'  '+name for name,data in sorted(files.items()))+'\n').encode()
        output = io.BytesIO()
        with zipfile.ZipFile(output,'w',zipfile.ZIP_DEFLATED) as archive:
            for name,data in files.items():
                archive.writestr(name,data)
        return output.getvalue()

    def status(self, *, offset=0):
        integer(offset, 0, 100000)
        with self.store.connect() as db:
            profiles = [dict(zip(('id', 'version', 'name', 'domain', 'group_sid', 'validity_days', 'renew_before_days', 'enabled'), row)) for row in db.execute('SELECT * FROM user_enrollment_profiles ORDER BY name,id')]
            total = db.execute('''SELECT count(*) FROM user_enrollment_issuances u JOIN pki_certificates c
                ON c.serial=u.serial WHERE c.archived_at IS NULL''').fetchone()[0]
            rows = db.execute('''SELECT u.serial,u.profile_id,u.principal,u.installed_at,u.last_seen,u.renew_at,
                c.certificate,c.revoked_at FROM user_enrollment_issuances u JOIN pki_certificates c ON c.serial=u.serial
                WHERE c.archived_at IS NULL ORDER BY u.rowid DESC LIMIT 100 OFFSET ?''', (offset,)).fetchall()
        catalog = self.store.directory_catalog() or {}
        group_names = {g['sid']: g['name'] for g in catalog.get('groups', [])}
        for profile in profiles:
            profile['group_name'] = group_names.get(profile['group_sid'])
        now, users = instant(), []
        for serial, profile, principal, installed, seen, renew, pem, revoked in rows:
            cert = x509.load_pem_x509_certificate(pem)
            state = 'revoked' if revoked else 'expired' if now >= cert.not_valid_after_utc else 'issued' if not installed else 'renewal_due' if now >= datetime.fromisoformat(renew) else 'installed'
            users.append({'serial': serial, 'profile_id': profile, 'principal': principal, 'status': state,
                'installed_at': installed, 'last_seen': seen, 'renew_at': renew, 'not_after': cert.not_valid_after_utc.isoformat()})
        return {'profiles': profiles, 'users': users, 'total': total, 'offset': offset, 'radius_changed': False,
            'windows_client_available': True, 'enterprise_signing_required': True, 'endpoint_acceptance_pending': True}
