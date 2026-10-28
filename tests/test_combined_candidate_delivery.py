"""Fixed delivery must contain exactly the reviewed product/helper/template bytes."""
import base64
import hashlib
import io
from pathlib import Path
import re
import unittest
import zipfile

ROOT=Path(__file__).resolve().parents[1]
class CombinedDeliveryTests(unittest.TestCase):
 def test_embedded_sources_exact_and_complete(self):
  text=(ROOT/'docs/checkpoints/2026-10-28-dc01-combined-candidate.ps1').read_text()
  raw=base64.b64decode(re.search(r"\$embedded='([^']+)'",text).group(1),validate=True)
  self.assertEqual(hashlib.sha256(raw).hexdigest(),re.search(r"\$archivePin='([^']+)'",text).group(1))
  pins=dict(re.findall(r"'([^']+\.ps1)'='([a-f0-9]{64})'",text))
  self.assertEqual(set(pins),{'New-AuthWireDeploymentCandidate.ps1','Get-AuthWireMachineSignerMetadata.ps1','New-AuthWireCombinedCandidate.ps1','Install-AuthWire.ps1'})
  with zipfile.ZipFile(io.BytesIO(raw)) as z:
   self.assertEqual(set(z.namelist()),set(pins))
   for n,pin in pins.items():
    expected=ROOT/('kaname/device_client' if n=='Install-AuthWire.ps1' else 'windows/connector')/n
    self.assertEqual(z.read(n),expected.read_bytes().replace(b'\r\n',b'\n'))
    self.assertEqual(hashlib.sha256(z.read(n)).hexdigest(),pin)
 def test_product_never_uses_managed_ephemeral_marker_as_key_authority(self):
  source=(ROOT/'windows/connector/New-AuthWireCombinedCandidate.ps1').read_text()
  self.assertNotIn('GetRSAPrivateKey',source)
  self.assertNotIn('.SetProperty(',source)
  self.assertNotIn('NCryptSetProperty',source)
  self.assertIn('Get-AuthWireNamedMachineKeyMetadata',source)
  self.assertIn('COMBINED_SIGNER_PRESERVATION_FAILED',source)
