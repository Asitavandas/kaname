"""Disposable expired-pending bridge for native Windows CI; never customer state."""
import argparse
import json
import os
import time
from datetime import datetime, timedelta, timezone
from pathlib import Path

from cryptography import x509
from cryptography.hazmat.primitives import hashes, serialization

from kaname.device_enrollment import DeviceEnrollment
from kaname.enrollment import EnrollmentError
from kaname.operations import Operations
from kaname.store import Store
from tests.test_enrollment import PASSWORD
from tests.test_radius_live import live_account

PRINCIPAL = 'PC01$@LAB.EXAMPLE'


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--root', required=True)
    parser.add_argument('--step', choices=['expire', 'dispatch', 'inspect', 'serve'], required=True)
    args = parser.parse_args()
    root = Path(args.root).resolve()
    if (not root.name.startswith('authwire-ci-expired-')
            or not (root / 'CI_FIXTURE_ONLY').is_file()
            or not (root / 'EXPIRED_RECOVERY_FIXTURE_ONLY').is_file()):
        raise ValueError('Disposable expired fixture markers required')
    service = DeviceEnrollment(Operations(Store(root / 'state')),
                               resolver=lambda *a, **kw: live_account())
    service.unlock_signer(PASSWORD, 'expired-ci-fixture')
    if args.step == 'expire':
        issued = json.loads((root / 'issued.json').read_text())
        now = datetime.now(timezone.utc)
        original = x509.load_pem_x509_certificate(issued['certificate'].encode())
        with service.transaction() as db:
            issuer, key, _ = service._issuer(db, now)
            builder = (x509.CertificateBuilder().subject_name(original.subject)
                       .issuer_name(issuer.subject).public_key(original.public_key())
                       .serial_number(original.serial_number)
                       .not_valid_before(max(now - timedelta(minutes=4), issuer.not_valid_before_utc))
                       .not_valid_after(now - timedelta(minutes=1)))
            for extension in original.extensions:
                builder = builder.add_extension(extension.value, extension.critical)
            expired = builder.sign(key, hashes.SHA256()).public_bytes(serialization.Encoding.PEM)
            # The fixture changes only its own synthetic issuance, with the same
            # CSR/key. Production code and system clocks are never patched.
            db.execute('UPDATE pki_certificates SET certificate=? WHERE serial=?',
                       (expired, issued['serial']))
        print(json.dumps({'fixture_expired': True, 'system_clock_changed': False}))
    elif args.step in ('dispatch', 'serve'):
        routes = {'/api/device/challenge': service.challenge,
                  '/api/device/issue': service.issue,
                  '/api/device/receipt': service.receipt}
        def dispatch(request):
            if request['path'] not in routes:
                raise ValueError('Unexpected fixture route')
            try:
                return routes[request['path']](PRINCIPAL, request['body'])
            except EnrollmentError as error:
                return {'fixture_error': error.code}
        if args.step == 'dispatch':
            print(json.dumps(dispatch(json.loads((root / 'bridge-request.json').read_text()))))
        else:
            # Keep server-side DPAPI secrets under the original fixture user.
            # SYSTEM owns only the client; private files provide disposable IPC.
            # No sockets, real Kerberos, customer secrets or machine-DPAPI bypass.
            (root / 'bridge-ready').write_text('ready')
            seen = None
            deadline = time.monotonic() + 480
            while time.monotonic() < deadline and not (root / 'bridge-stop').exists():
                path = root / 'bridge-request.json'
                if path.exists():
                    request = json.loads(path.read_text(encoding='utf-8-sig'))
                    if request['id'] != seen:
                        result = {'id': request['id'], 'body': dispatch(request)}
                        temporary = root / 'bridge-response.tmp'
                        temporary.write_text(json.dumps(result), encoding='utf-8')
                        publish_until = time.monotonic() + 5
                        while True:
                            try:
                                os.replace(temporary, root / 'bridge-response.json')
                                break
                            except PermissionError:
                                if time.monotonic() >= publish_until:
                                    raise
                                time.sleep(0.02)
                        seen = request['id']
                time.sleep(0.05)
    else:
        with service.store.connect() as db:
            rows = db.execute('SELECT serial,csr_sha256,installed_at FROM device_issuances ORDER BY rowid').fetchall()
        print(json.dumps({'issuances': [dict(zip(('serial', 'csr_sha256', 'installed_at'), r)) for r in rows]}))


if __name__ == '__main__':
    main()
