"""One-time Ubuntu lab installer. Run locally with sudo after source tests.

No passwordless sudo, domain join, RADIUS listener or OS DNS replacement.
Private domain/IP values are supplied locally, never embedded in source/CI.
"""
import argparse
import hashlib
import http.client
import ipaddress
import json
import os
import re
import socket
import ssl
import subprocess
import time
from pathlib import Path, PurePosixPath

PRODUCT = Path('/opt/kaname-lab')
STATE = Path('/var/lib/kaname-lab')
SETTINGS = Path('/etc/kaname-lab')
UNIT = Path('/etc/systemd/system/kaname-lab.service')
ACCOUNT = 'kaname-lab'


def dns_name(value):
    value = value.lower()
    if len(value) > 253 or len(value.split('.')) < 2 or any(not re.fullmatch(r'[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?', x) for x in value.split('.')):
        raise ValueError('Invalid DNS name')
    return value


def verified_files(source, expected):
    if not re.fullmatch(r'[0-9a-f]{64}', expected):
        raise ValueError('Expected source digest is required')
    manifest_path = source / 'LINUX_SOURCE_MANIFEST.json'
    if manifest_path.is_symlink() or not manifest_path.is_file() or manifest_path.stat().st_size > 200000:
        raise ValueError('Invalid manifest')
    manifest_bytes = manifest_path.read_bytes()
    if hashlib.sha256(manifest_bytes).hexdigest() != expected:
        raise ValueError('Source manifest changed; nothing installed')
    manifest = json.loads(manifest_bytes)
    if set(manifest) != {'artifact', 'files'} or manifest['artifact'] != 'kaname-linux-lab-source' or type(manifest['files']) is not dict:
        raise ValueError('Invalid source artifact')
    result = {}
    for name, digest in manifest['files'].items():
        relative = PurePosixPath(name)
        if relative.is_absolute() or '..' in relative.parts or not relative.parts or '\\' in name or relative.as_posix() != name:
            raise ValueError('Unsafe source path')
        if relative.parts[0] not in {'kaname', 'tools', 'tests', 'pyproject.toml'}:
            raise ValueError('Unexpected source root')
        path = source
        for part in relative.parts:
            path = path / part
            if path.is_symlink():
                raise ValueError('Source symlink refused')
        if not path.is_file() or path.stat().st_size > 2_000_000:
            raise ValueError('Invalid source file')
        data = path.read_bytes()
        if hashlib.sha256(data).hexdigest() != digest:
            raise ValueError('Source file changed; nothing installed')
        result[name] = data
    if not {'kaname/server.py', 'kaname/__main__.py', 'tools/linux_install.py', 'tools/linux_initialize.py'} <= set(result):
        raise ValueError('Incomplete source')
    return result


def checked(command, **kwargs):
    return subprocess.run(command, check=True, timeout=kwargs.pop('timeout', 600), **kwargs)


def discover_dc(domain, dc_ip):
    query = '_ldap._tcp.dc._msdcs.' + domain
    result = checked(['/usr/bin/dig', '@' + dc_ip, query, 'SRV', '+short', '+time=2', '+tries=1'], capture_output=True, text=True, timeout=5)
    candidates = []
    for line in result.stdout.splitlines():
        parts = line.split()
        if len(parts) == 4 and all(x.isdecimal() for x in parts[:3]) and parts[2] == '389':
            host = dns_name(parts[3].rstrip('.'))
            if host.endswith('.' + domain):
                candidates.append((int(parts[0]), host))
    for _, host in sorted(set(candidates))[:16]:
        response = checked(['/usr/bin/dig', '@' + dc_ip, host, 'A', '+short', '+time=2', '+tries=1'], capture_output=True, text=True, timeout=5)
        addresses = []
        for line in response.stdout.splitlines():
            try: addresses.append(str(ipaddress.ip_address(line.strip())))
            except ValueError: pass
        if addresses and set(addresses) == {dc_ip}:
            return host
    raise ValueError('AD DNS did not return a DC name mapped only to the supplied IP; specify a verified --dc-fqdn')


def hosts_with_dc(content, fqdn, ip):
    for line in content.splitlines():
        fields = line.split('#', 1)[0].split()
        if len(fields) > 1 and fqdn.casefold() in {x.casefold() for x in fields[1:]}:
            if fields[0] != ip:
                raise ValueError('Existing DC hosts entry differs; automatic replacement refused')
            return content
    return content.rstrip('\n') + '\n' + ip + '\t' + fqdn + ' # KANAME lab AD controller\n'


def unit_text(listen, name):
    return f'''[Unit]
Description=KANAME laboratory HTTPS panel and read-only AD synchronization
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User={ACCOUNT}
Group={ACCOUNT}
WorkingDirectory={PRODUCT}/source
Environment=PYTHONUNBUFFERED=1
Environment=PYTHONDONTWRITEBYTECODE=1
Environment=TMPDIR=/run/kaname-lab
ExecStart={PRODUCT}/venv/bin/python -m kaname --state-dir {STATE} --listen {listen} --port 8765 --public-name {name} --tls-cert {SETTINGS}/web.crt --tls-key {SETTINGS}/web.key
Restart=on-failure
RestartSec=5
TimeoutStopSec=65
UMask=0077
StateDirectory=kaname-lab
StateDirectoryMode=0700
RuntimeDirectory=kaname-lab
RuntimeDirectoryMode=0700
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths={STATE}
ProtectKernelTunables=yes
ProtectKernelModules=yes
ProtectControlGroups=yes
RestrictSUIDSGID=yes
RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6
CapabilityBoundingSet=
KillMode=control-group

[Install]
WantedBy=multi-user.target
'''


def install(args):
    import pwd
    domain, dc = dns_name(args.domain), str(ipaddress.IPv4Address(args.dc_ip))
    name, listen = dns_name(args.name or 'kaname.' + domain), str(ipaddress.IPv4Address(args.listen_ip))
    if ipaddress.ip_address(listen).is_unspecified or ipaddress.ip_address(listen).is_multicast:
        raise ValueError('A specific LAN IP is required')
    source = Path(__file__).resolve().parent.parent
    files = verified_files(source, args.source_digest)
    if os.geteuid() != 0:
        raise ValueError('Local sudo is required only for this installation')
    release = Path('/etc/os-release').read_text()
    if not re.search(r'^ID=ubuntu$', release, re.M) or not re.search(r'^VERSION_ID="24\.04"$', release, re.M):
        raise ValueError('This lab installer targets Ubuntu 24.04 only')
    if PRODUCT.exists() or UNIT.exists() or STATE.exists() or SETTINGS.exists():
        raise ValueError('Existing installation preserved. This first-install command does not upgrade or reset state.')
    # Confirm the selected address belongs to this machine before installing.
    test_socket = socket.socket()
    try: test_socket.bind((listen, 0))
    finally: test_socket.close()
    with socket.socket() as port:
        port.bind((listen, 8765))
    try:
        pwd.getpwnam(ACCOUNT)
    except KeyError:
        pass
    else:
        raise ValueError('Existing service account preserved; manual review required')
    env = {**os.environ, 'DEBIAN_FRONTEND': 'noninteractive'}
    checked(['/usr/bin/apt-get', 'update'], env=env)
    checked(['/usr/bin/apt-get', 'install', '-y', 'python3-venv', 'python3-ldap', 'krb5-user',
             'libsasl2-modules-gssapi-mit', 'bind9-dnsutils', 'ca-certificates'], env=env)
    fqdn = dns_name(args.dc_fqdn) if args.dc_fqdn else discover_dc(domain, dc)
    if not fqdn.endswith('.' + domain):
        raise ValueError('DC name must belong to the supplied domain')
    for port_number in (88, 389):
        with socket.create_connection((dc, port_number), timeout=3):
            pass
    host_path = Path('/etc/hosts')
    original_hosts = host_path.read_text()
    next_hosts = hosts_with_dc(original_hosts, fqdn, dc)
    # Copy verified bytes to a root-owned directory; never import runner source as root.
    PRODUCT.mkdir(mode=0o755)
    (PRODUCT / 'source').mkdir(mode=0o755)
    for filename, data in files.items():
        target = PRODUCT / 'source' / filename
        target.parent.mkdir(parents=True, exist_ok=True, mode=0o755)
        target.write_bytes(data); target.chmod(0o644)
    checked(['/usr/bin/python3', '-m', 'venv', '--system-site-packages', str(PRODUCT / 'venv')])
    python = str(PRODUCT / 'venv/bin/python')
    checked([python, '-m', 'pip', 'install', '--only-binary=:all:', 'cryptography==46.0.0'])
    checked([python, '-c', 'import ldap, ldap.sasl; from ldap.controls.libldap import SimplePagedResultsControl; import cryptography; assert cryptography.__version__ == "46.0.0"'])
    checked(['/usr/sbin/useradd', '--system', '--home-dir', str(STATE), '--shell', '/usr/sbin/nologin', ACCOUNT])
    account = pwd.getpwnam(ACCOUNT)
    STATE.mkdir(mode=0o700); os.chown(STATE, account.pw_uid, account.pw_gid)
    SETTINGS.mkdir(mode=0o750); os.chown(SETTINGS, 0, account.pw_gid)
    boot = {'domain': domain, 'dc_ip': dc, 'dc_fqdn': fqdn, 'listen_ip': listen,
            'name': name, 'source_digest': args.source_digest, 'mode': 'linux-lab'}
    (SETTINGS / 'bootstrap.json').write_text(json.dumps(boot, indent=2) + '\n')
    (SETTINGS / 'bootstrap.json').chmod(0o600)
    if next_hosts != original_hosts:
        (SETTINGS / 'hosts.before').write_text(original_hosts)
        (SETTINGS / 'hosts.before').chmod(0o600)
        # Keep the existing inode and permissions, including mounted /etc/hosts.
        host_path.write_text(next_hosts)
    checked(['/usr/sbin/runuser', '-u', ACCOUNT, '--', python, '-m', 'tools.linux_initialize',
             '--state-dir', str(STATE), '--domain', domain, '--dc-ip', dc, '--name', name], cwd=PRODUCT / 'source')
    certificate = checked([python, '-m', 'tools.linux_initialize', '--state-dir', str(STATE),
                            '--domain', domain, '--dc-ip', dc, '--name', name,
                            '--certificate-dir', str(SETTINGS), '--listen', listen], cwd=PRODUCT / 'source', capture_output=True, text=True)
    fingerprint = json.loads(certificate.stdout)['certificate_sha256']
    os.chown(SETTINGS / 'web.key', 0, account.pw_gid); (SETTINGS / 'web.key').chmod(0o640)
    os.chown(SETTINGS / 'web.crt', 0, account.pw_gid)
    UNIT.write_text(unit_text(listen, name)); UNIT.chmod(0o644)
    checked(['/usr/bin/systemctl', 'daemon-reload'])
    checked(['/usr/bin/systemctl', 'enable', '--now', 'kaname-lab.service'])
    checked(['/usr/bin/systemctl', 'is-active', 'kaname-lab.service'])
    context = ssl.create_default_context(cafile=str(SETTINGS / 'web.crt'))
    healthy = False
    for _ in range(20):
        connection = http.client.HTTPSConnection(listen, 8765, context=context, timeout=2)
        try:
            connection.request('GET', '/healthz')
            response = connection.getresponse()
            status = json.loads(response.read(4096))
            if response.status == 200 and status.get('product') == 'KANAME':
                healthy = True; break
        except (OSError, ValueError, http.client.HTTPException):
            time.sleep(0.5)
        finally:
            connection.close()
    if not healthy:
        checked(['/usr/bin/systemctl', 'stop', 'kaname-lab.service'])
        raise ValueError('Verified HTTPS health check failed; lab service stopped and state retained for diagnosis')
    print(json.dumps({'installed': True, 'mode': 'linux-lab', 'panel': 'https://' + listen + ':8765/',
                      'dc_fqdn': fqdn, 'certificate_sha256': fingerprint,
                      'radius_listener_enabled': False, 'existing_windows_installation_changed': False}, indent=2))


def main():
    parser = argparse.ArgumentParser(description='First-install only KANAME Ubuntu laboratory bootstrap')
    parser.add_argument('--source-digest', required=True)
    parser.add_argument('--domain', required=True)
    parser.add_argument('--dc-ip', required=True)
    parser.add_argument('--listen-ip', required=True)
    parser.add_argument('--dc-fqdn')
    parser.add_argument('--name')
    args = parser.parse_args()
    try:
        install(args)
    except Exception as error:
        # No credentials are accepted by this installer. Partial OS package
        # installations are not described as a transactional rollback.
        print('KANAME installation did not complete. Existing state was not reset.', file=__import__('sys').stderr)
        print(type(error).__name__ + ': ' + str(error), file=__import__('sys').stderr)
        raise SystemExit(1)


if __name__ == '__main__':
    main()
