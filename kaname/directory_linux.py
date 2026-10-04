"""Read-only Linux GSSAPI adapter. No domain join, Simple Bind or NTLM."""
import ipaddress
import json
import os
import signal
import socket
import subprocess
import sys
import tempfile
from pathlib import Path

from .directory import DirectoryError, decode_helper_response, validate_connection


def read_linux_directory(value, config, *, probe=False):
    request = validate_connection(value, config)
    if sys.platform != 'linux':
        raise DirectoryError('AD_PLATFORM_UNSUPPORTED')
    if '\n' in request['password'] or '\r' in request['password']:
        raise DirectoryError('AD_INPUT_INVALID')
    try:
        addresses = {str(ipaddress.ip_address(x[4][0])) for x in
                     socket.getaddrinfo(request['dc_fqdn'], 389, type=socket.SOCK_STREAM)}
    except (OSError, ValueError):
        raise DirectoryError('AD_DNS_FAILED') from None
    if not addresses or not addresses <= {str(ipaddress.ip_address(x)) for x in config['dc_ips']}:
        raise DirectoryError('AD_DC_IP_MISMATCH')
    # Parent owns the directory so a killed helper cannot leave a ticket behind.
    with tempfile.TemporaryDirectory(prefix='kaname-kerberos-') as temporary:
        request.update(probe=probe, cache_dir=temporary)
        payload = json.dumps(request, ensure_ascii=True).encode()
        try:
            process = subprocess.Popen([sys.executable, '-m', 'kaname.directory_linux_helper'],
                                       cwd=Path(__file__).resolve().parent.parent,
                                       stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                       stderr=subprocess.DEVNULL, start_new_session=True)
            try:
                output, _ = process.communicate(payload, timeout=60)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                process.communicate()
                raise DirectoryError('AD_TIMEOUT') from None
        except OSError:
            raise DirectoryError('AD_PROTOCOL_UNAVAILABLE') from None
        finally:
            request['password'] = ''
            payload = b''
    if probe:
        try:
            result = json.loads(output)
            if process.returncode == 0 and result == {'probe': 'ok', 'domain': request['domain'], 'dc_fqdn': request['dc_fqdn']}:
                return result
        except (ValueError, UnicodeError):
            pass
    return decode_helper_response(output, process.returncode, config['ad_domain'], request['dc_fqdn'])


def check_linux_directory(value, config):
    return read_linux_directory(value, config, probe=True)
