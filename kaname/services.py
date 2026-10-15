"""Unprivileged client for the installed, fixed-scope local control broker."""
import json
import socket
import stat
from pathlib import Path

SOCKET=Path('/run/authwire-service-control/control.sock')

class ServiceError(Exception):
    def __init__(self,code):
        self.code=code
        super().__init__(code)

class Services:
    def __init__(self,path=SOCKET):self.path=Path(path)

    def request(self,value):
        try:
            info=self.path.lstat()
            if not stat.S_ISSOCK(info.st_mode) or info.st_uid!=0 or info.st_mode & 0o007:
                raise ServiceError('SERVICE_CONTROL_UNAVAILABLE')
            with socket.socket(socket.AF_UNIX,socket.SOCK_STREAM) as client:
                client.settimeout(4)
                client.connect(str(self.path))
                # Linux SO_PEERCRED pins the privileged peer, not merely its pathname.
                import struct
                if struct.unpack('3i',client.getsockopt(socket.SOL_SOCKET,socket.SO_PEERCRED,12))[1]!=0:
                    raise ServiceError('SERVICE_CONTROL_UNAVAILABLE')
                client.sendall(json.dumps(value,ensure_ascii=True).encode()+b'\n')
                with client.makefile('rb') as f:raw=f.readline(262145)
            if len(raw)>262144 or not raw.endswith(b'\n'):raise ValueError()
            data=json.loads(raw)
            if data.get('ok') is not True:raise ServiceError(data.get('error','CONTROL_FAILED'))
            return data['result']
        except ServiceError:raise
        except (OSError,ValueError,KeyError,TypeError,AttributeError):
            raise ServiceError('SERVICE_CONTROL_UNAVAILABLE') from None

    def status(self):return self.request({'kind':'status'})

    def action(self,value,actor):
        validate(value)
        return self.request({'kind':'action',**{k:value[k] for k in ('service','action','request_id')},'actor':actor['username']})

def validate(value):
    import uuid
    allowed={'radius':{'start','stop','restart'},'crl-sync':{'sync'},'crl-timer':{'start','stop'}}
    if type(value) is not dict or set(value)!={'service','action','request_id','confirmed'}:
        raise ServiceError('INVALID_INPUT')
    if value['confirmed'] is not True:raise ServiceError('CONFIRMATION_REQUIRED')
    if type(value['service']) is not str or type(value['action']) is not str or value['action'] not in allowed.get(value['service'],set()):
        raise ServiceError('ACTION_NOT_ALLOWED')
    try:
        if type(value['request_id']) is not str or str(uuid.UUID(value['request_id']))!=value['request_id']:raise ValueError()
    except ValueError:raise ServiceError('INVALID_INPUT') from None
