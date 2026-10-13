"""Actual non-root timer sandbox proof only on disposable hosted systemd."""
import json
import os
from pathlib import Path
import subprocess


def command(*args):
    return subprocess.run(list(args), check=True, capture_output=True, timeout=60)


def main():
    if os.geteuid()!=0 or os.environ.get('RUNNER_ENVIRONMENT')!='github-hosted':
        raise ValueError('Disposable hosted VM required')
    unit=Path('/etc/systemd/system/authwire-radius.service')
    fixture=Path('/opt/kaname-lab/source/tools/crl_timer_disposable_fixture.py')
    if unit.exists() or unit.is_symlink() or fixture.exists():
        raise ValueError('Fixture collision')
    fixture.write_text('''import sqlite3,os
from pathlib import Path
root=Path('/run/authwire-radius')
ca=root/'ca';ca.mkdir(mode=0o700)
with sqlite3.connect('file:/var/lib/kaname-lab/kaname.sqlite3?mode=ro',uri=True) as db:
 row=db.execute('SELECT root_cert,issuer_cert,crl FROM pki_authority').fetchone()
for name,data in zip(('root-ca.pem','issuer-ca.pem','issuer-crl.pem'),row):
 p=ca/name;p.write_bytes(data);p.chmod(0o600)
(root/'mods-enabled').mkdir(mode=0o700)
(root/'mods-enabled/eap').write_text('ca_path_reload_interval = 300\\n')
''')
    fixture.chmod(0o644)
    unit.write_text('''[Unit]
Description=Disposable sleep process for CRL timer sandbox proof
[Service]
Type=simple
User=kaname-lab
Group=kaname-lab
RuntimeDirectory=authwire-radius
RuntimeDirectoryMode=0700
ExecStartPre=/opt/kaname-lab/venv/bin/python -I -B /opt/kaname-lab/source/tools/crl_timer_disposable_fixture.py
ExecStart=/usr/bin/sleep infinity
''')
    units=['authwire-radius-crl-sync.service','authwire-radius-crl-sync.timer']
    try:
        command('systemctl','daemon-reload')
        command('systemctl','start',unit.name)
        command('/usr/bin/python3','/opt/kaname-lab/source/tools/radius_crl_install.py')
        command('systemctl','start',units[0])
        result=command('systemctl','show',units[0],'--property=Result','--value').stdout.strip()
        if result!=b'success':raise ValueError('Timer sandbox failed')
        command('systemctl','stop',unit.name)
        command('systemctl','start',units[0])
        check=command('systemctl','show',unit.name,'--property=ActiveState','--value').stdout.strip()
        if check!=b'inactive':raise ValueError('Timer started an intentionally stopped RADIUS')
        command('systemctl','is-active','--quiet',units[1])
        print(json.dumps({'crl_timer_systemd_fixture':'passed','service_user':'kaname-lab',
             'sandbox_sqlite_read_succeeded':True,'stopped_radius_respected':True,
             'real_radius_started':False,'customer_state_used':False}))
    finally:
        subprocess.run(['systemctl','disable','--now',units[1]],capture_output=True,timeout=30)
        subprocess.run(['systemctl','stop',units[0],unit.name],capture_output=True,timeout=30)
        for name in units:
            (Path('/etc/systemd/system')/name).unlink(missing_ok=True)
        unit.unlink(missing_ok=True);fixture.unlink(missing_ok=True)
        command('systemctl','daemon-reload')


if __name__=='__main__':main()
