"""One central root action to provision the HTTP acceptor keytab, not clients.

No AD password/SPN mutation or RADIUS activation. The administrator obtains
an AES keytab for the existing HTTPS FQDN from AD. Service-owned mode 0600;
validate as the unprivileged service account before an atomic replacement.
"""
import argparse
import json
import os
import pwd
import stat
import subprocess
import tempfile
from pathlib import Path


def setup(keytab):
    if os.geteuid()!=0:
        raise ValueError('Run this central setup with sudo')
    source=Path(keytab).absolute()
    for path in (source,*source.parents):
        if path.is_symlink(): raise ValueError('Keytab symlink refused')
    info=source.stat()
    if not stat.S_ISREG(info.st_mode) or info.st_uid!=0 or info.st_mode&0o077 or not 1<=info.st_size<=65536:
        raise ValueError('Input keytab must be a private root-owned regular file (0600)')
    state=Path('/var/lib/kaname-lab')
    account=pwd.getpwnam('kaname-lab')
    if state.is_symlink() or not state.is_dir() or state.stat().st_uid!=account.pw_uid:
        raise ValueError('Existing AuthWire service state required')
    python='/opt/kaname-lab/venv/bin/python'
    code=Path('/opt/kaname-lab/source')
    if not (code/'kaname/device_auth.py').is_file(): raise ValueError('Install the bulk enrollment update first')
    destination=state/'device-http.keytab'
    if destination.is_symlink(): raise ValueError('Installed keytab symlink refused')
    # Apt is explicit in this separate setup, never hidden in the code updater.
    subprocess.run(['/usr/bin/apt-get','install','-y','python3-gssapi'],check=True,
        env={**os.environ,'DEBIAN_FRONTEND':'noninteractive'})
    with tempfile.TemporaryDirectory(dir=state,prefix='device-keytab-') as temporary:
        pending=Path(temporary);os.chown(pending,account.pw_uid,account.pw_gid)
        candidate=pending/'device-http.keytab'
        fd=os.open(candidate,os.O_WRONLY|os.O_CREAT|os.O_EXCL,0o600)
        with os.fdopen(fd,'wb') as output:output.write(source.read_bytes())
        os.chown(candidate,account.pw_uid,account.pw_gid)
        script=('from pathlib import Path;import sys;from kaname.store import Store;'
            'from kaname.device_auth import KerberosSessions;'
            'c=Store("/var/lib/kaname-lab").snapshot()["config"];'
            's=KerberosSessions(Path(sys.argv[1]),c["appliance_fqdn"],c["ad_domain"]);'
            'assert s.readiness(),"Keytab does not contain the HTTPS HTTP service principal"')
        subprocess.run(['/usr/sbin/runuser','-u','kaname-lab','--',python,'-B','-c',script,str(pending)],cwd=code,check=True)
        if destination.exists():
            raise ValueError('Existing HTTP keytab preserved; rotate it in a separate reviewed operation')
        os.rename(candidate,destination)
    return {'kerberos_keytab_installed':True,'permissions':'0600','ad_changed':False,'radius_started':False}


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--keytab',required=True)
    args=parser.parse_args()
    try:print(json.dumps(setup(args.keytab)))
    except (ValueError,OSError,subprocess.CalledProcessError) as error:
        print(json.dumps({'installed':False,'error':str(error)}));raise SystemExit(1)


if __name__=='__main__':main()
