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
from .models import strict_json
from .radius import CurrentDirectoryAccount, object_id


def read_linux_directory(value, config, *, probe=False, object_guid=None):
    request = validate_connection(value, config)
    if object_guid is not None:
        object_id(object_guid)
        if probe:
            raise DirectoryError('AD_INPUT_INVALID')
        request['object_guid'] = object_guid
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
    if object_guid is not None:
        return decode_account_response(output, process.returncode, request, object_guid)
    return decode_helper_response(output, process.returncode, config['ad_domain'], request['dc_fqdn'])


def decode_account_response(output, returncode, request, guid):
    try:
        if type(output) is not bytes or len(output) > 65536:
            raise ValueError()
        value = strict_json(output)
        if returncode != 0:
            from .directory import ERRORS
            if type(value) is dict and set(value) == {'error'} and value['error'] in ERRORS:
                raise DirectoryError(value['error'])
            raise ValueError()
        if type(value) is not dict or set(value) != {'domain', 'dc_fqdn', 'account'}:
            raise ValueError()
        if value['domain'] != request['domain'] or value['dc_fqdn'] != request['dc_fqdn']:
            raise ValueError()
        row = value['account']
        if row is None:
            return None
        fields = {'domain', 'object_guid', 'sid', 'kind', 'enabled', 'security_group_sids'}
        if type(row) is not dict or set(row) != fields or row['domain'] != request['domain'] or row['object_guid'] != guid:
            raise ValueError()
        groups = row['security_group_sids']
        if type(groups) is not list or len(groups) > 256 or len(set(groups)) != len(groups):
            raise ValueError()
        return CurrentDirectoryAccount(**(row | {'security_group_sids': frozenset(groups)}))
    except (ValueError, TypeError, KeyError):
        raise DirectoryError('AD_INVALID_RESPONSE') from None


def lookup_linux_account(value, config, object_guid):
    """Fresh account/tokenGroups lookup; never consults the display catalog."""
    return read_linux_directory(value, config, object_guid=object_guid)


def check_linux_directory(value, config):
    return read_linux_directory(value, config, probe=True)
