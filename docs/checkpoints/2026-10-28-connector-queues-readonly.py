#!/usr/bin/env python3
"""Read-only queue-schema diagnostic; never call poll/complete/status or open keys."""
import hashlib
import importlib
import json
import os
from pathlib import Path
import sqlite3
import sys
import time

SOURCE = Path('/opt/kaname-lab/source')
DATABASE = Path('/var/lib/kaname-lab/kaname.sqlite3')
CLASSES = (
    ('connector_jobs', 'ConnectorJobs'),
    ('candidate_jobs', 'CandidateJobs'),
    ('combined_jobs', 'CombinedJobs'),
    ('scope_jobs', 'ScopeJobs'),
    ('combined_scope_jobs', 'CombinedScopeJobs'),
)
EXPECTED = {
    "kaname/connector_jobs.py": "0fe8cd3e4470def0febb970990f5b1b2d6bd129a3cdb72e689c159dd26b130cc",
    "kaname/candidate_jobs.py": "086c08f9f67824ac771e765eb3519f548c34f57eeca61532b31427d4331dde09",
    "kaname/combined_jobs.py": "50fdc44fe3e99ccfd2bb43a4db82a28a0de007f9402b4b948eb4a5005dc59cbb",
    "kaname/scope_jobs.py": "1233ce0f245e8f5627259531cb5353a903bc2f63c7bec4700bacd5fafbb7ca0a",
    "kaname/combined_scope_jobs.py": "ca172ea0a7d1a76133be1f4a029b677b51a3d8ff84e13690fd32198c0f3247c0"
}

def inspect_queues(db):
    now = int(time.time())
    items = []
    for module_name, class_name in CLASSES:
        module = importlib.import_module('kaname.' + module_name)
        cls = getattr(module, class_name)
        row = db.execute('SELECT payload FROM runtime_settings WHERE name=?',
                         (module.SECTION,)).fetchone()
        item = {'name': module.SECTION, 'present': row is not None}
        if row is not None:
            raw = row[0]
            item['characters'] = len(raw) if isinstance(raw, str) else None
            item['within_100000_character_limit'] = isinstance(raw, str) and len(raw) <= 100000
            try:
                shape = json.loads(raw)
                if isinstance(shape, dict):
                    for field in ('jobs', 'polls'):
                        if isinstance(shape.get(field), list):
                            item[field + '_count'] = len(shape[field])
                    last = shape.get('last_poll')
                    if isinstance(last, dict) and type(last.get('at')) is int:
                        item['last_poll_age_seconds'] = now - last['at']
                    jobs = shape.get('jobs')
                    if isinstance(jobs, list):
                        item['job_states'] = {state: sum(isinstance(j, dict) and j.get('state') == state for j in jobs)
                                              for state in ('queued', 'leased', 'completed')}
            except (ValueError, TypeError):
                item['json_parse_failed'] = True
        try:
            # _read performs SELECT plus in-memory schema/consistency validation only.
            cls._read(object.__new__(cls), db)
            item['schema_valid'] = True
        except Exception as exc:
            item['schema_valid'] = False
            item['error_type'] = type(exc).__name__
            code = getattr(exc, 'code', '')
            item['error_code'] = code if isinstance(code, str) and code.endswith('STORE_INVALID') else 'VALIDATION_EXCEPTION'
        items.append(item)
    return items

def main():
    if os.geteuid() != 0:
        raise SystemExit('ROOT_READ_PERMISSION_REQUIRED')
    for relative, expected in EXPECTED.items():
        path = SOURCE / relative
        if hashlib.sha256(path.read_bytes()).hexdigest() != expected:
            raise SystemExit('SOURCE_HASH_MISMATCH:' + relative)
    sys.path.insert(0, str(SOURCE))
    db = sqlite3.connect(DATABASE.as_uri() + '?mode=ro', uri=True, timeout=3)
    try:
        db.execute('PRAGMA query_only=ON')
        db.execute('BEGIN')
        result = inspect_queues(db)
        db.rollback()
    finally:
        db.close()
    print(json.dumps({'event': 'CONNECTOR_JOB_QUEUES_SCHEMA_READONLY',
                      'checked_utc_epoch': int(time.time()),
                      'queues': result, 'database_writes': False,
                      'poll_requests_sent': False, 'jobs_created': False,
                      'services_changed': False, 'key_material_read': False,
                      'secret_values_exported': False}, sort_keys=True))

if __name__ == '__main__':
    main()

