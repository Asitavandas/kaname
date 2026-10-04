"""Disposable GitHub-hosted VM installation check. Never run on user runners."""
import http.client
import json
import os
import socket
import ssl
import subprocess
import tempfile
import threading
from pathlib import Path

from .linux_prepare import prepare


def main():
    if os.environ.get('RUNNER_ENVIRONMENT') != 'github-hosted' or os.geteuid() != 0:
        raise SystemExit('Installation fixture is restricted to disposable GitHub-hosted CI')
    listeners = []
    stopped = threading.Event()
    def accept_loop(listener):
        while not stopped.is_set():
            try:
                connection, _ = listener.accept(); connection.close()
            except socket.timeout: pass
            except OSError: return
    for port in (88, 389):
        listener = socket.socket(); listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        listener.bind(('127.0.0.1', port)); listener.listen(5); listener.settimeout(0.2)
        listeners.append(listener)
        threading.Thread(target=accept_loop, args=(listener,), daemon=True).start()
    try:
        with tempfile.TemporaryDirectory() as temporary:
            stage = Path(temporary) / 'source'
            prepared = prepare(Path(__file__).resolve().parent.parent, stage)
            result = subprocess.run(['/usr/bin/python3', str(stage / 'tools/linux_install.py'),
                '--source-digest', prepared['source_digest'], '--domain', 'fixture.invalid',
                '--dc-ip', '127.0.0.1', '--dc-fqdn', 'dc01.fixture.invalid', '--listen-ip', '127.0.0.1'],
                check=True, timeout=600)
            context = ssl.create_default_context(cafile='/etc/kaname-lab/web.crt')
            def request(method, path, value=None, extra=None):
                connection = http.client.HTTPSConnection('127.0.0.1', 8765, context=context, timeout=5)
                try:
                    headers = {'Origin': 'https://127.0.0.1:8765', 'Content-Type': 'application/json', **(extra or {})}
                    connection.request(method, path, json.dumps(value) if value is not None else None, headers)
                    response = connection.getresponse()
                    return response.status, json.loads(response.read()), response.getheader('Set-Cookie')
                finally: connection.close()
            status, health, _ = request('GET', '/healthz')
            assert status == 200 and health['product'] == 'KANAME'
            status, actor, cookie = request('POST', '/api/auth/login', {'username': 'admin', 'password': 'Kaname'})
            assert status == 200 and '; Secure' in cookie
            cookie = cookie.split(';', 1)[0]
            status, session, _ = request('GET', '/api/auth/session', extra={'Cookie': cookie})
            assert status == 200
            status, _, _ = request('POST', '/api/auth/password', {'current': 'Kaname', 'new': 'fixture-password-changed'},
                {'Cookie': cookie, 'X-Kaname-CSRF': session['csrf']})
            assert status == 200
            subprocess.run(['systemctl', 'restart', 'kaname-lab.service'], check=True, timeout=70)
            # systemd Type=simple can report active before the HTTPS socket is ready.
            import time
            for attempt in range(20):
                try:
                    status, _, _ = request('POST', '/api/auth/login', {'username': 'admin', 'password': 'fixture-password-changed'})
                    if status == 200: break
                except OSError: time.sleep(0.5)
            else: raise AssertionError('Restart lost the edited admin password or service health')
            user = subprocess.check_output(['systemctl', 'show', 'kaname-lab.service', '--property=User', '--value'], text=True).strip()
            assert user == 'kaname-lab'
            for binary in ('kinit',):
                assert Path('/usr/bin/' + binary).is_file()
            print(json.dumps({'installation_fixture': 'passed', 'tls_verified': True, 'non_root_service': True,
                'changed_password_survives_restart': True, 'real_ad_called': False, 'radius_started': False}))
    except Exception:
        subprocess.run(['journalctl', '-u', 'kaname-lab.service', '-n', '40', '--no-pager'], check=False)
        raise
    finally:
        stopped.set()
        for listener in listeners: listener.close()
        subprocess.run(['systemctl', 'stop', 'kaname-lab.service'], check=False)


if __name__ == '__main__':
    main()
