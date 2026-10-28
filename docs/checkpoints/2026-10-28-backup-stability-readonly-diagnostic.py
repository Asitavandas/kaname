"""Root/operator read-only backup stability diagnostic; no backup or DB writes."""
import ast
from contextlib import closing
import hashlib
import json
import os
from pathlib import Path
import sqlite3
import stat
import time

WORKER=Path('/opt/authwire-backup/scheduled_backup.py')
WORKER_SHA='83de9cb66df58b5f0a12c18c6526731e9697023f268a12c7b566ba6efbda77b0'

def digest(value):
    return hashlib.sha256(repr(value).encode()).hexdigest()

def snapshot(path, volatile):
    with closing(sqlite3.connect(path.as_uri()+'?mode=ro',uri=True,timeout=3)) as db:
        db.execute('PRAGMA query_only=ON');db.execute('BEGIN')
        schema=db.execute("SELECT type,name,tbl_name,sql FROM sqlite_master WHERE name NOT LIKE 'sqlite_%' ORDER BY type,name").fetchall()
        result={'schema':digest(schema),'tables':{},'runtime_rows':{}}
        for (name,) in db.execute("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name"):
            if name in volatile:continue
            quoted='"'+name.replace('"','""')+'"'
            where=" WHERE name<>'directory_health'" if name=='runtime_settings' else ''
            rows=db.execute('SELECT * FROM '+quoted+where).fetchall()
            result['tables'][name]=digest(sorted(rows,key=repr))
            if name=='runtime_settings':
                result['runtime_rows']={str(row[0]):digest(row) for row in rows}
        return result

def main():
    if os.geteuid()!=0:raise ValueError('OPERATOR_SUDO_REQUIRED')
    info=WORKER.lstat();raw=WORKER.read_bytes()
    if not stat.S_ISREG(info.st_mode) or info.st_uid!=0 or info.st_mode&0o022 or hashlib.sha256(raw).hexdigest()!=WORKER_SHA:
        raise ValueError('BACKUP_SOURCE_CHANGED')
    assignments={}
    for node in ast.parse(raw).body:
        if isinstance(node,ast.Assign) and len(node.targets)==1 and isinstance(node.targets[0],ast.Name) and node.targets[0].id=='VOLATILE':
            assignments['volatile']=ast.literal_eval(node.value)
    volatile=assignments['volatile']
    for name in ('last-run.json','last-success.json'):
        path=Path('/var/backups/authwire/scheduled')/name
        if path.exists():
            value=json.loads(path.read_bytes())
            allowed=('event','phase','category','checked_utc','created_utc','backup','sha256','archive_read_verified','sqlite_integrity_verified')
            print(json.dumps({'event':'BACKUP_DIAGNOSTIC_STATUS','file':name,'status':{k:value[k] for k in allowed if k in value}}),flush=True)
    databases=[]
    for root in (Path('/var/lib/kaname-lab'),Path('/var/lib/authwire-service-control')):
        for path in sorted(root.rglob('*')):
            if path.suffix in ('.sqlite3','.sqlite','.db') and stat.S_ISREG(path.lstat().st_mode):databases.append(path)
    if not databases:raise ValueError('DATABASES_NOT_FOUND')
    first={str(p):snapshot(p,volatile) for p in databases};changed_tables=set();changed_rows=set();schema_changes=set()
    for _ in range(3):
        time.sleep(12)
        for path in databases:
            before=first[str(path)];after=snapshot(path,volatile)
            if before['schema']!=after['schema']:schema_changes.add(str(path))
            for name in before['tables'].keys()|after['tables'].keys():
                if before['tables'].get(name)!=after['tables'].get(name):changed_tables.add((str(path),name))
            for name in before['runtime_rows'].keys()|after['runtime_rows'].keys():
                if before['runtime_rows'].get(name)!=after['runtime_rows'].get(name):
                    label=name if name.startswith(('windows_','directory_')) else 'name-sha256:'+hashlib.sha256(name.encode()).hexdigest()
                    changed_rows.add((str(path),label))
    if hashlib.sha256(WORKER.read_bytes()).hexdigest()!=WORKER_SHA:raise ValueError('BACKUP_SOURCE_CHANGED')
    print(json.dumps({'event':'BACKUP_STABILITY_READONLY_DIAGNOSTIC','observation_seconds':36,
        'databases':len(databases),'schema_changed_databases':sorted(schema_changes),
        'changed_protected_tables':[{'database':p,'table':n} for p,n in sorted(changed_tables)],
        'changed_runtime_rows':[{'database':p,'name':n} for p,n in sorted(changed_rows)],
        'backup_started':False,'services_changed':False,'database_writes':False,'secret_values_exported':False}),flush=True)

if __name__=='__main__':
    try:main()
    except Exception as error:
        print(json.dumps({'event':'BACKUP_DIAGNOSTIC_FAILED','category':type(error).__name__}),flush=True)
        raise SystemExit(1)
