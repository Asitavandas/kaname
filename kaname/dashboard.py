"""Read-only dashboard projections. Never used by the RADIUS decision path.

Counts are retained server responses, not clients, sessions or NAS delivery.
Per-section permissions are enforced by the HTTP caller; no secrets returned.
"""
from contextlib import closing
from calendar import monthrange
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
    # Append-only IDs make the watermark an immutable snapshot. Fetch short
    # primary-key batches without a long read transaction, so dashboard scans
    # release DELETE-journal read locks between batches for the native writer.
    minute = period == '1h'
    hourly = period == '24h'
    grouped_counts, nas_counts, heat_counts, recent = {}, {}, {}, []
    accept = reject = 0
    low, high_time = stamp(start), stamp(end)
    deadline = time.monotonic() + 1.5
    with closing(readonly(path)) as db:
        high = db.execute('SELECT coalesce(max(id),0) FROM access_events').fetchone()[0]
        cursor = 0
        while cursor < high:
            if time.monotonic() > deadline: raise ValueError('DASHBOARD_QUERY_LIMIT')
            rows = db.execute('SELECT id,at,response_code,reason,nas_ip,policy_id,vlan,object_guid,calling_station,certificate_serial FROM access_events WHERE id>? AND id<=? ORDER BY id LIMIT 512',(cursor,high)).fetchall()
            if not rows: break
            cursor = rows[-1][0]
            for row in rows:
                ident, at, code, reason, ip, policy, vlan, guid, mac, serial = row
                if not low <= at < high_time: continue
                local = datetime.fromisoformat(at.replace('Z','+00:00')).astimezone(ZONE)
                key = at[:16]+':00Z' if minute else at[:13]+':00:00Z' if hourly else local.strftime('%Y-%m-%d')
                yes, no = int(code == 2), int(code == 3)
                accept += yes; reject += no
                bucket = grouped_counts.setdefault(key,[0,0]); bucket[0] += yes; bucket[1] += no
                bucket = nas_counts.setdefault(ip,[0,0,0]); bucket[0] += 1; bucket[1] += yes; bucket[2] += no
                heat_key = (local.weekday(),local.hour)
                heat_counts[heat_key] = heat_counts.get(heat_key,0)+1
                recent.append(row)
                if len(recent)>8:recent.pop(0)
    grouped = [(key,*value) for key,value in sorted(grouped_counts.items())]
    nas = [(ip,*value) for ip,value in sorted(nas_counts.items(),key=lambda item:(-item[1][0],item[0]))]
    heat = [(day,hour,count) for (day,hour),count in sorted(heat_counts.items())]
    rows = list(reversed(recent))
    client_map = {c['ip']: c for c in (network or {}).get('radius_clients', [])}
    types = {'wired':0,'wireless':0,'unknown':0}
    devices = []
    for ip, count, yes, no in nas:
        client = client_map.get(ip, {})
        kind = client.get('access_type','unknown')
        types[kind if kind in types else 'unknown'] += count
        devices.append({'ip':ip,'name':client.get('name',ip),'count':count,'accept':yes,'reject':no})
    indexed = {key:(yes,no) for key,yes,no in grouped}
    cursor = start.replace(second=0,microsecond=0) if minute else start.replace(minute=0,second=0,microsecond=0) if hourly else start
    series=[]
    while cursor < end:
        key=cursor.astimezone(timezone.utc).strftime('%Y-%m-%dT%H:%M:00Z') if minute else cursor.astimezone(timezone.utc).strftime('%Y-%m-%dT%H:00:00Z') if hourly else cursor.strftime('%Y-%m-%d')
        yes,no=indexed.get(key,(0,0));series.append({'at':stamp(cursor),'accept':yes,'reject':no})
        cursor += timedelta(minutes=1) if minute else timedelta(hours=1) if hourly else timedelta(days=1)
    return {'available':True,'initialized':True,'watermark':high,'total':accept+reject,'accept':accept,'reject':reject,
            'series':series,'nas':devices[:6],'access_types':[{'type':k,'count':v} for k,v in types.items()],
            'heatmap':[{'day':day,'hour':hour,'count':count} for day,hour,count in heat],
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
    if period not in {'1h','24h','7d','30d','6m','1y'}:raise ValueError('INVALID_PERIOD')
    now=(now or datetime.now(timezone.utc)).astimezone(timezone.utc)
    local=now.astimezone(ZONE)
    if period in {'1h','24h'}:
        start=local-timedelta(hours=int(period[:-1]))
    elif period in {'6m','1y'}:
        months=6 if period=='6m' else 12
        year,month=divmod(local.year*12+local.month-1-months,12);month+=1
        start=local.replace(year=year,month=month,day=min(local.day,monthrange(year,month)[1]),hour=0,minute=0,second=0,microsecond=0)
    else:
        start=local.replace(hour=0,minute=0,second=0,microsecond=0)-timedelta(days=int(period[:-1])-1)
    result={'period':period,'from':stamp(start),'to':stamp(now),'checked_at':stamp(now),'timezone':'Europe/Istanbul',
            'events':None,'certificates':None,'coverage':{'accounting_sessions':False,'endpoint_success_proven':False,'retained_server_responses_only':True}}
    if events:
        try:result['events']=response_summary(root,start,now,period,network)
        except (OSError,sqlite3.Error,history.EventStorageError,ValueError):result['events']={'available':False,'error':'ACCESS_HISTORY_UNAVAILABLE'}
    if certificates:
        try:result['certificates']=certificate_summary(root,now)
        except (OSError,sqlite3.Error,ValueError,ImportError):result['certificates']={'available':False,'error':'CERTIFICATE_SUMMARY_UNAVAILABLE'}
    return result
