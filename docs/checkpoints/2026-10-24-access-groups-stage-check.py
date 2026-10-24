from pathlib import Path
import hashlib,json,runpy
h=Path('/home/segmentiq/authwire-access-groups-20261024.py')
assert hashlib.sha256(h.read_bytes()).hexdigest()=='1eb6cbae1e5d91e2c1eaf27409d89e85a5a1c6036eee0a42291eb869d8f66da2'
ns=runpy.run_path(str(h));up=ns['load_pinned'](ns['ROOT']/'tools/linux_update.py','d168067e31160bb064db7faadd796ec79fe0dff27f1933fec25090faab57d0fe')
old=Path('/home/segmentiq/authwire-stage-dev28-301cea88e870');verified=up['verified_files'](old,ns['EXPECTED']);stage=ns['STAGE']
assert not stage.exists();stage.mkdir(mode=0o700)
for name,data in verified.items():
 p=stage/name;p.parent.mkdir(parents=True,exist_ok=True,mode=0o700);p.write_bytes(data);p.chmod(0o644)
(stage/'LINUX_SOURCE_MANIFEST.json').write_bytes((old/'LINUX_SOURCE_MANIFEST.json').read_bytes())
up['safe_tree'](ns['ROOT'],owner=0,quarantine_bytecode=True);files=up['verified_files'](stage,ns['EXPECTED']);ns['source_check'](files)
assert set(files)==set(ns['BASELINE'])|ns['NEW_FILES']
print(json.dumps({'event':'ACCESS_GROUPS_STAGE_VALIDATED','release':ns['RELEASE'],'files':len(files),'installed_updater_validation':True,'source_guard_passed':True,'live_source_changed':False,'services_changed':False,'manifest_sha256':ns['EXPECTED'],'helper_sha256':hashlib.sha256(h.read_bytes()).hexdigest()}))
