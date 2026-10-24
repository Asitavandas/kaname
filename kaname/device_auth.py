"""Kerberos-only HTTP sessions with integrity on EVERY application message.

No remote-user headers, delegated passwords or NTLM. The SSPI client signs
the path and exact request bytes: relaying an AP-REQ cannot substitute a CSR.
Contexts are bounded, short-lived and lost at restart; clients reconnect.
"""
import base64
import os
import re
import secrets
import threading
import time

from .enrollment import EnrollmentError
from .models import keys, strict_json


def decode(value, maximum=131072):
    if type(value) is not str or len(value) > maximum:
        raise EnrollmentError('DEVICE_AUTH_REJECTED')
    try:
        return base64.b64decode(value, validate=True)
    except ValueError:
        raise EnrollmentError('DEVICE_AUTH_REJECTED') from None


def encode(value):
    return base64.b64encode(value).decode('ascii')


class KerberosSessions:
    def __init__(self, root, hostname, domain):
        self.root, self.hostname, self.domain = root, hostname, domain
        self.sessions = {}
        self.lock = threading.Lock()
        self.gate = threading.BoundedSemaphore(4)

    def principal_allowed(self, principal):
        return bool(re.fullmatch(r'[A-Za-z0-9_][A-Za-z0-9_.-]{0,19}\$@' + re.escape(self.domain.upper()), principal, re.I))

    def credentials(self):
        try:
            import gssapi
            path = self.root / 'device-http.keytab'
            if not self.hostname or not self.domain or path.is_symlink():
                raise ValueError()
            stat = path.stat()
            if stat.st_uid != os.getuid() or stat.st_mode & 0o077 or not 1 <= stat.st_size <= 65536:
                raise ValueError()
            principal = 'HTTP/' + self.hostname + '@' + self.domain.upper()
            creds = gssapi.Credentials(name=gssapi.Name(principal, gssapi.NameType.kerberos_principal),
                usage='accept', mechs=[gssapi.MechType.kerberos], store={'keytab': str(path)})
            return gssapi, creds
        except Exception:
            raise EnrollmentError('DEVICE_KERBEROS_NOT_READY') from None

    def readiness(self):
        try:
            self.credentials()
            return True
        except EnrollmentError:
            return False

    def start(self, value):
        keys(value, {'token'}, {'token'})
        if not self.gate.acquire(blocking=False):
            raise EnrollmentError('DEVICE_BUSY')
        try:
            gssapi, creds = self.credentials()
            with self.lock:
                now = time.monotonic()
                self.sessions = {k: v for k, v in self.sessions.items() if now < v[2]}
                if len(self.sessions) >= 128:
                    raise EnrollmentError('DEVICE_BUSY')
                context = gssapi.SecurityContext(creds=creds, usage='accept')
                output = context.step(decode(value['token'], 65536))
                required = {gssapi.RequirementFlag.mutual_authentication, gssapi.RequirementFlag.integrity,
                    gssapi.RequirementFlag.replay_detection, gssapi.RequirementFlag.out_of_sequence_detection}
                principal = str(context.initiator_name)
                if not context.complete or context.mech != gssapi.MechType.kerberos or not required <= set(context.actual_flags):
                    raise ValueError()
                if not self.principal_allowed(principal):
                    raise ValueError()
                identity = secrets.token_hex(32)
                self.sessions[identity] = (context, principal, now + 900)
                return {'id': identity, 'token': encode(output or b'')}
        except EnrollmentError:
            raise
        except Exception:
            raise EnrollmentError('DEVICE_AUTH_REJECTED') from None
        finally:
            self.gate.release()

    def verify(self, path, envelope):
        keys(envelope, {'id', 'message', 'mic'}, {'id', 'message', 'mic'})
        if type(envelope['id']) is not str or not re.fullmatch('[0-9a-f]{64}', envelope['id']):
            raise EnrollmentError('DEVICE_AUTH_REJECTED')
        with self.lock:
            record = self.sessions.get(envelope['id'])
            if not record or time.monotonic() >= record[2]:
                self.sessions.pop(envelope['id'], None)
                raise EnrollmentError('DEVICE_SESSION_EXPIRED')
            context, principal, _ = record
            try:
                message = decode(envelope['message'])
                context.verify_signature(path.encode('ascii') + b'\n' + message, decode(envelope['mic'], 8192))
                return principal, strict_json(message), context
            except Exception:
                self.sessions.pop(envelope['id'], None)
                raise EnrollmentError('DEVICE_AUTH_REJECTED') from None

    def response(self, path, context, body):
        import json
        raw = json.dumps(body, ensure_ascii=True, separators=(',', ':')).encode('utf-8')
        with self.lock:
            return {'message': encode(raw), 'mic': encode(context.get_signature(path.encode('ascii') + b'\n' + raw))}

    def end(self, identity, context):
        with self.lock:
            if identity in self.sessions and self.sessions[identity][0] is context:
                del self.sessions[identity]


class UserKerberosSessions(KerberosSessions):
    """Separate user-only contexts; never accepts a machine/service principal.

    The caller must use a dedicated instance for /api/user/* so a valid
    machine enrollment session cannot be reused to request a user certificate.
    """
    def principal_allowed(self, principal):
        return bool(re.fullmatch(r'[A-Za-z0-9_][A-Za-z0-9_.-]{0,19}@' + re.escape(self.domain.upper()), principal, re.I))
