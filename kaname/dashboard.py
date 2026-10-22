"""Read-only dashboard projections. Never used by the RADIUS decision path.

Counts are retained server responses, not clients, sessions or NAS delivery.
Per-section permissions are enforced by the HTTP caller; no secrets returned.
"""
from contextlib import closing
from datetime import datetime, timedelta, timezone
from pathlib import Path
import sqlite3
import time

from . import radius_events as history

# Reporting and SQL buckets use the same explicit UTC+03:00 offset.
# No OS tzdata dependency at server import (including Windows fixture hosts).
ZONE = timezone(timedelta(hours=3), 'Europe/Istanbul')


def stamp(value):
    return value.astimezone(timezone.utc).isoformat(timespec='milliseconds').replace('+00:00', 'Z')


def readonly(path):
    db = sqlite3.connect(path.as_uri() + '?mode=ro', uri=True, timeout=.025)
    db.execute('PRAGMA query_only=ON')
    deadline = time.monotonic() + 1.5
    db.set_progress_handler(lambda: int(time.monotonic() > deadline), 1000)
    return db


def response_summary(root, start, end, period, network):
    directory, path = history.paths(root)
    if not directory.exists() and not directory.is_symlink():
        return {'available': True, 'initialized': False, 'total': 0, 'accept': 0, 'reject': 0,
                'series': [], 'nas': [], 'access_types': [], 'heatmap': [], 'recent': [], 'observer': None}
    history._private(directory, directory=True); history._private(path)
    # Same transaction / watermark for all widgets. No first-page sampling.
    with closing(readonly(path)) as db:
        db.execute('BEGIN')
        high = db.execute('SELECT coalesce(max(id),0) FROM access_events').fetchone()[0]
        where = 'id<=? AND at>=? AND at<?'
        args = (high, stamp(start), stamp(end))
        accept, reject = db.execute('SELECT coalesce(sum(response_code=2),0),coalesce(sum(response_code=3),0) FROM access_events WHERE '+where,args).fetchone()
        hourly = period == '24h'
        bucket = "strftime('%Y-%m-%dT%H:00:00Z',at)" if hourly else "date(at,'+3 hours')"
        grouped = db.execute('SELECT '+bucket+',sum(response_code=2),sum(response_code=3) FROM access_events WHERE '+where+' GROUP BY 1 ORDER BY 1',args).fetchall()
        nas = db.execute('SELECT nas_ip,count(*),sum(response_code=2),sum(response_code=3) FROM access_events WHERE '+where+' GROUP BY nas_ip ORDER BY count(*) DESC,nas_ip',args).fetchall()
        heat = db.execute("SELECT strftime('%w',at,'+3 hours'),strftime('%H',at,'+3 hours'),count(*) FROM access_events WHERE "+where+' GROUP BY 1,2',args).fetchall()
        rows = db.execute('SELECT id,at,response_code,reason,nas_ip,policy_id,vlan,object_guid,calling_station,certificate_serial FROM access_events WHERE '+where+' ORDER BY id DESC LIMIT 8',args).fetchall()
    client_map = {c['ip']: c for c in (network or {}).get('radius_clients', [])}
    types = {'wired':0,'wireless':0,'unknown':0}
    devices = []
    for ip, count, yes, no in nas:
        client = client_map.get(ip, {})
        kind = client.get('access_type','unknown')
        types[kind if kind in types else 'unknown'] += count
        devices.append({'ip':ip,'name':client.get('name',ip),'count':count,'accept':yes,'reject':no})
    indexed = {key:(yes,no) for key,yes,no in grouped}
    cursor = start.replace(minute=0,second=0,microsecond=0) if hourly else start
    series=[]
    while cursor < end:
        key=cursor.astimezone(timezone.utc).strftime('%Y-%m-%dT%H:00:00Z') if hourly else cursor.strftime('%Y-%m-%d')
        yes,no=indexed.get(key,(0,0));series.append({'at':stamp(cursor),'accept':yes,'reject':no})
        cursor += timedelta(hours=1) if hourly else timedelta(days=1)
    return {'available':True,'initialized':True,'watermark':high,'total':accept+reject,'accept':accept,'reject':reject,
            'series':series,'nas':devices,'access_types':[{'type':k,'count':v} for k,v in types.items()],
            'heatmap':[{'day':(int(day)+6)%7,'hour':int(hour),'count':count} for day,hour,count in heat],
            'recent':[dict(zip(('id','at','response_code','reason','nas_ip','policy_id','vlan','object_guid','calling_station','certificate_serial'),row)) for row in rows],
            'observer':history.runtime_status(Path('/run/authwire-radius')),
            'classification':'current_nas_configuration' if network is not None else 'unavailable'}


def certificate_summary(root, now):
    from cryptography import x509
    path=Path(root).absolute()/'kaname.sqlite3'
    with closing(readonly(path)) as db:
        db.execute('BEGIN')
        tables={r[0] for r in db.execute("SELECT name FROM sqlite_master WHERE type='table'")}
        if 'pki_certificates' not in tables:return {'available':True,'valid_computers':0,'expiring_computers':0,'window_days':30,'crl':None}
        columns={r[1] for r in db.execute('PRAGMA table_info(pki_certificates)')}
        visible='c.archived_at IS NULL' if 'archived_at' in columns else '1=1'
        # Fixed bounded result: never label a truncated certificate sample a total.
        rows=db.execute('SELECT c.certificate FROM pki_certificates c JOIN radius_certificate_bindings b ON b.serial=c.serial WHERE b.kind=? AND c.revoked_at IS NULL AND '+visible+' LIMIT 10001',('computer',)).fetchall() if 'radius_certificate_bindings' in tables else []
        if len(rows)>10000:raise ValueError('CERTIFICATE_QUERY_LIMIT')
    valid=expiring=0
    deadline=time.monotonic()+1.5
    for (pem,) in rows:
        if time.monotonic()>deadline:raise ValueError('CERTIFICATE_QUERY_LIMIT')
        cert=x509.load_pem_x509_certificate(pem)
        if cert.not_valid_before_utc <= now < cert.not_valid_after_utc:
            valid+=1
            if cert.not_valid_after_utc <= now+timedelta(days=30):expiring+=1
    crl=None
    try:
        # Runtime validity + signature against the runtime issuer, no private key.
        ca=Path('/run/authwire-radius/ca')
        raw=(ca/'issuer-crl.pem').read_bytes()
        if len(raw)>4*1024*1024:raise ValueError()
        issuer=x509.load_pem_x509_certificate((ca/'issuer-ca.pem').read_bytes())
        value=x509.load_pem_x509_crl(raw)
        crl={'current':value.last_update_utc<=now<value.next_update_utc,
             'signature_valid':value.is_signature_valid(issuer.public_key()),'next_update':stamp(value.next_update_utc)}
    except (OSError,ValueError,TypeError):pass
    return {'available':True,'valid_computers':valid,'expiring_computers':expiring,'window_days':30,'crl':crl}


def summary(root, period='7d', *, events=True, certificates=True, network=None, now=None):
    if period not in {'24h','7d','30d'}:raise ValueError('INVALID_PERIOD')
    now=(now or datetime.now(timezone.utc)).astimezone(timezone.utc)
    local=now.astimezone(ZONE)
    start=local-timedelta(hours=24) if period=='24h' else local.replace(hour=0,minute=0,second=0,microsecond=0)-timedelta(days=int(period[:-1])-1)
    result={'period':period,'from':stamp(start),'to':stamp(now),'checked_at':stamp(now),'timezone':'Europe/Istanbul',
            'events':None,'certificates':None,'coverage':{'accounting_sessions':False,'endpoint_success_proven':False,'retained_server_responses_only':True}}
    if events:
        try:result['events']=response_summary(root,start,now,period,network)
        except (OSError,sqlite3.Error,history.EventStorageError,ValueError):result['events']={'available':False,'error':'ACCESS_HISTORY_UNAVAILABLE'}
    if certificates:
        try:result['certificates']=certificate_summary(root,now)
        except (OSError,sqlite3.Error,ValueError,ImportError):result['certificates']={'available':False,'error':'CERTIFICATE_SUMMARY_UNAVAILABLE'}
    return result
