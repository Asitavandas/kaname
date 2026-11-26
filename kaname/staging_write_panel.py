"""Read-only panel description for the existing explicitly scoped pilot.

This projection grants no execution authority and never changes the ledger.
The existing authenticated review/create and peer grant gates remain mandatory.
"""
from .connector_jobs import scope_id, JobError
from .connector_registry import RegistryError
from .staging_write_jobs import STAGE, ROLLBACK


def describe(jobs, status, pilot_gpo_id):
    result = {'format': 'AuthWireFilesystemPanelV1', 'enabled': False,
              'gpo_id': None, 'worker_ready': False, 'rollback_targets': [],
              'can_apply_gpo': False}
    if pilot_gpo_id is None or pilot_gpo_id != getattr(jobs, 'pilot_gpo_id', None):
        return result
    with jobs.store.connect() as db:
        db.execute('BEGIN')
        if db.execute('SELECT revision FROM state WHERE id=1').fetchone()[0] != status['revision']:
            return result
        try:
            binding_scope = scope_id(jobs._binding(db))
        except (JobError, RegistryError) as error:
            if error.code.endswith('STORE_INVALID'):
                raise
            return result
        ledger = jobs._read(db)
        public = {j['id']: j for j in status['jobs']}
        if set(public) != {j['id'] for j in ledger['jobs']}:
            return result
        undone = {j['target']['stage_receipt']['stage_job_id'] for j in ledger['jobs']
                  if j['operation'] == ROLLBACK and j['state'] == 'completed' and
                  j['result']['outcome'] == 'rolled_back'}
        for job in ledger['jobs']:
            if (job['operation'] != STAGE or job['id'] in undone or job['scope'] != binding_scope or
                    public[job['id']]['state'] != 'completed' or not job['result'] or
                    job['result']['outcome'] != 'staged'):
                continue
            target = job['target']
            if target['scope_target']['gpo_id'] != pilot_gpo_id:
                continue
            result['rollback_targets'].append({
                'stage_job_id': job['id'],
                'candidate_id': target['scope_target']['candidate_id'],
                'staging_preview_sha256': target['preview_record']['PreviewSha256'],
            })
        last = ledger['last_poll']
        result.update(enabled=True, gpo_id=pilot_gpo_id,
                      worker_ready=bool(last and last['scope'] == binding_scope and
                                        0 <= int(jobs.clock()) - last['at'] < 90))
    return result
