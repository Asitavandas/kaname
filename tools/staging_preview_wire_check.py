"""Cross-runtime acceptance of the exact WinPS proposal and its ordered hashes."""
from pathlib import Path
import json
import sys
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from kaname.staging_preview_jobs import preview_valid,preview_hash

value=json.loads(Path(sys.argv[1]).read_text(encoding='utf-8-sig'))
assert preview_valid(value['preview'],value['target']), 'Native preview rejected by real server validator'
assert preview_hash(value['preview'])==value['preview_sha256'], 'Native/server canonical hashes differ'
print('AUTHWIRE_NATIVE_STAGING_WIRE_OK files=20 can_stage=false')
