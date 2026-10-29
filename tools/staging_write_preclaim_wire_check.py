"""Verify real native WinPS proof output with the existing Python verifier."""
import base64
import copy
import json
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from kaname.connector_jobs import JobError, scope_id, verify_job_proof
from kaname.connector_registry import decode_binding, digest
from kaname.staging_write_jobs import STAGE, target_valid, intent_id, POLL_PATH, CLAIM_PATH, RESULT_PATH
from kaname.staging_preview_jobs import preview_hash


def main(path):
    value = json.loads(Path(path).read_text(encoding='utf-8-sig'))
    native_binding = dict(value['binding'])
    native_key_id = native_binding.pop('channel_key_sha256')
    binding = decode_binding(native_binding | {'public_key_pem': value['public_key_pem']})
    assert binding.fields()[-1] == native_key_id
    target = value['target']; offer = value['offer']
    assert target_valid(target, STAGE)
    assert digest(target) == value['target_sha256']
    assert preview_hash(target['preview_record']['Preview']) == target['preview_record']['PreviewSha256']
    assert intent_id(offer['scope_sha256'], offer['job_id'], STAGE, target) == offer['intent_sha256']
    assert scope_id(binding) == offer['scope_sha256']
    checks = 6
    for row in value['proofs']:
        raw = json.dumps(row['proof'], separators=(',', ':')).encode()
        kind = row['kind']
        frame = base64.b64decode(row['proof']['frame']).decode('ascii').split('\n')
        # Offline wire evidence stays verifiable after the actual60s transport
        # window. The production verifier still receives its real wall clock.
        clock = lambda: int(frame[12])
        args = dict(prefix='AUTHWIRE-STAGING-WRITE-JOB-', poll_path=POLL_PATH,
                    result_path=CLAIM_PATH if kind == 'CLAIM' else RESULT_PATH)
        request, _, _, body = verify_job_proof(raw, binding, kind, clock, **args)
        assert request == frame[10]; assert len(raw) <= 4096
        assert 'path' not in body and 'command' not in body
        if kind == 'CLAIM':
            assert body['target_sha256'] == digest(target) and body['job_id'] == offer['job_id']
        checks += 1
        for change in ('wrong_kind', 'wrong_path', 'tamper'):
            try:
                bad = copy.deepcopy(row['proof'])
                if change == 'tamper':
                    bad['payload'] = base64.b64encode(b'{}').decode()
                verify_job_proof(json.dumps(bad).encode(), binding, 'POLL' if kind != 'POLL' and change == 'wrong_kind' else 'RESULT' if change == 'wrong_kind' else kind, clock,
                    prefix=args['prefix'], poll_path='/wrong' if change == 'wrong_path' else POLL_PATH,
                    result_path='/wrong' if change == 'wrong_path' else args['result_path'])
            except JobError:
                checks += 1
            else:
                raise AssertionError(change)
    print(json.dumps({'event':'WRITE_PRECLAIM_NATIVE_WIRE_VERIFIED', 'checks':checks,
                      'private_key_exported':False, 'claim_sent':False, 'gpo_changed':False}))


if __name__ == '__main__':
    main(sys.argv[1])
