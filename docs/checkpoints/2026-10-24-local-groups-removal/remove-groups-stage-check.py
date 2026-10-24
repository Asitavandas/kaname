from pathlib import Path,PurePosixPath
import base64,gzip,hashlib,json,runpy
home=Path('/home/segmentiq');h=home/'authwire-remove-groups-20261024.py'
assert hashlib.sha256(h.read_bytes()).hexdigest()=='12697cfd3fa0673cd40f7d4e4fb4ba71bda2d8de239f05e01606b3b5f84a2c76'
ns=runpy.run_path(str(h));raw=''.join((home/'authwire-remove-groups-transfer-20261024.b64').read_text().split())
assert hashlib.sha256(raw.encode()).hexdigest()=='4256a121e76447f6302636336abceff2761aaac4c6f5ad29d677ca64ba975cd6'
bundle=json.loads(gzip.decompress(base64.b64decode(raw,validate=True)));manifest=base64.b64decode(bundle['manifest'])
assert hashlib.sha256(manifest).hexdigest()==ns['EXPECTED']
up=ns['load_pinned'](ns['ROOT']/'tools/linux_update.py','d168067e31160bb064db7faadd796ec79fe0dff27f1933fec25090faab57d0fe')
for name,digest in bundle['base_files'].items():assert hashlib.sha256(ns['trusted'](ns['ROOT']/name)).hexdigest()==digest,name
stage=ns['STAGE'];assert not stage.exists();stage.mkdir(mode=0o700)
old=home/'authwire-stage-dev27-e6b899b2dccb'
for name,digest in json.loads(manifest)['files'].items():
 relative=PurePosixPath(name);assert not relative.is_absolute() and '..' not in relative.parts and relative.as_posix()==name
 if name in bundle['files']:data=base64.b64decode(bundle['files'][name],validate=True)
 else:
  current=ns['ROOT']/name
  if current.exists() and hashlib.sha256(current.read_bytes()).hexdigest()==digest:data=current.read_bytes()
  else:
   p=old/name;assert not p.is_symlink();data=p.read_bytes()
 assert hashlib.sha256(data).hexdigest()==digest,name
 p=stage/name;p.parent.mkdir(parents=True,exist_ok=True,mode=0o700);p.write_bytes(data);p.chmod(0o644)
(stage/'LINUX_SOURCE_MANIFEST.json').write_bytes(manifest)
up['safe_tree'](ns['ROOT'],owner=0,quarantine_bytecode=True);files=up['verified_files'](stage,ns['EXPECTED']);ns['source_check'](files)
assert set(files)==(set(ns['BASELINE'])-ns['REMOVED'])|ns['NEW_FILES']
print(json.dumps({'event':'LOCAL_GROUP_REMOVAL_STAGE_VALIDATED','release':ns['RELEASE'],'files':len(files),'actual_updater_used':True,'source_guard_passed':True,'live_source_changed':False,'services_changed':False,'data_changed':False,'helper_sha256':hashlib.sha256(h.read_bytes()).hexdigest()}))
