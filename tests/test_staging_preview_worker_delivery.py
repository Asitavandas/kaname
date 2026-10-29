"""Exact Windows delivery bytes and unchanged customer-host/signing guards."""
import base64
import hashlib
import io
from pathlib import Path
import re
import unittest
import uuid
import zipfile
from tools.connector_service_source_hashes import ALL

ROOT=Path(__file__).resolve().parents[1]
ENTRY=ROOT/'docs/checkpoints/2026-10-28-dc01-staging-preview-worker-upgrade.ps1'
OLD=ROOT/'docs/checkpoints/2026-10-28-dc01-sysvol-unc-fix.ps1'

class StagingPreviewWorkerDeliveryTests(unittest.TestCase):
 def test_archive_and_all_twenty_eight_current_sources_are_exact(self):
  text=ENTRY.read_text()
  pins=dict(re.findall(r"'([^']+)'='([a-f0-9]{64})'",re.search(r'\$reviewedSources=@\{(.*?)\n\}',text,re.S).group(1)))
  expected=set(ALL)|{'ConnectorServiceUpgrade.ps1','Update-AuthWireConnectorService.ps1'}
  self.assertEqual(expected,set(pins));self.assertEqual(28,len(expected))
  archive=base64.b64decode(re.search(r"\$embeddedSources='([^']+)'",text).group(1),validate=True)
  digest=hashlib.sha256(archive).hexdigest()
  self.assertEqual('62eff1fa1bc2492a2e83abf39961e90fe148c3cdb98d4dd148eb17c035b8dc63',digest)
  self.assertEqual(re.search(r"\$archiveSha256='([^']+)'",text).group(1),digest)
  self.assertLess(len(archive),524288)
  with zipfile.ZipFile(io.BytesIO(archive)) as z:
   self.assertEqual(28,len(z.namelist()));self.assertEqual(expected,set(z.namelist()))
   for name in expected:
    data=z.read(name);self.assertEqual(pins[name],hashlib.sha256(data).hexdigest())
    source=(ROOT/'windows/connector'/name).read_text().replace('\r\n','\n').rstrip('\r\n')+'\n'
    self.assertEqual(source.encode(),data,name)

 def test_only_release_pins_change_in_the_reviewed_customer_wrapper(self):
  def mask(text):
   text=re.sub(r'\$reviewedSources=@\{.*?\n\}','SOURCES',text,count=1,flags=re.S)
   for name in ('archiveSha256','embeddedSources','sourceCommit','releaseId','oldRelease'):
    text=re.sub(r'(?m)^\$'+name+r'=.*$',name,text,count=1)
   return re.sub(r"ToolVersion='[^']+'","ToolVersion='VERSION'",text)
  self.assertEqual(mask(OLD.read_text()),mask(ENTRY.read_text()))

 def test_delivery_is_bound_to_current_accepted_release_and_existing_identity(self):
  text=ENTRY.read_text()
  self.assertIn("$oldRelease=[guid]'cf74295c-ec97-4edf-a15a-877b155d1740'",text)
  release=re.search(r"\$releaseId='([^']+)'",text).group(1)
  self.assertEqual(release,str(uuid.UUID(release)))
  self.assertEqual('df28f70c-104e-4d6d-972c-e311d38adde6',release)
  self.assertIn("$sourceCommit='92b2af9b78347058802f4bb135b5fbb243abc813'",text)
  self.assertIn("ToolVersion='1.5.0'",text)
  self.assertIn('-ExpectedCurrentRelease $oldRelease',text)
  self.assertIn("$context.AccountName -cne 'VIZYONVERI\\aw-deploy$'",text)
  self.assertIn("$context.KeyName -cne 'AuthWire-Channel-4c23eebe071546d188eea2e96ad7ee46-7f99fddfd15c4529a70c288bdb40e98c'",text)

 def test_previous_full_generation_map_matches_the_accepted_delivery(self):
  old=OLD.read_text();pins=dict(re.findall(r"'([^']+)'='([a-f0-9]{64})'",re.search(r'\$reviewedSources=@\{(.*?)\n\}',old,re.S).group(1)))
  package=(ROOT/'windows/connector/ConnectorServicePackage.ps1').read_text()
  block=re.search(r'function Get-AuthWireCombinedScopeOnlyPayloadHashes\s*\{\s*@\{(.*?)\n\s*\}\s*\}',package,re.S).group(1)
  legacy=dict(re.findall(r"'([^']+)'='([A-F0-9]{64})'",block))
  self.assertEqual(17,len(legacy))
  self.assertEqual({n:h.lower() for n,h in legacy.items()},{n:pins[n] for n in legacy})

 def test_published_script_sha_matches_the_operator_pin(self):
  self.assertEqual('2c8fbe776a240bc98bbb387c529a90ab4fbfc3fa2467096799d3a9e159ea33cf',hashlib.sha256(ENTRY.read_text().encode()).hexdigest())

if __name__=='__main__':unittest.main()
