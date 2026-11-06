"""Keep the service's keyless verifier limited to reviewed public functions."""
import base64
import re
import io
import hashlib
import zipfile
from pathlib import Path
import unittest

ROOT=Path(__file__).resolve().parents[1]
def functions(text):
 return {m[1]:chunk.rstrip() for chunk in re.split(r'(?m)(?=^function )',text)
         if (m:=re.match(r'function ([A-Za-z0-9-]+)',chunk))}

class CombinedReadonlySourceTests(unittest.TestCase):
 def test_public_function_bodies_match_reviewed_producer(self):
  text=(ROOT/'windows/connector/Test-AuthWireCombinedContent.ps1').read_text()
  actual=functions(text)
  for source in ('New-AuthWireDeploymentCandidate.ps1','New-AuthWireCombinedCandidate.ps1'):
   for name,body in functions((ROOT/'windows/connector'/source).read_text()).items():
    if name in actual:self.assertEqual(body,actual[name],name)
 def test_template_is_exact_and_private_or_write_capabilities_absent(self):
  text=(ROOT/'windows/connector/Test-AuthWireCombinedContent.ps1').read_text()
  raw=base64.b64decode(re.search(r"FromBase64String\('([^']+)'\)",text).group(1),validate=True)
  self.assertEqual(raw,(ROOT/'kaname/device_client/Install-AuthWire.ps1').read_bytes().replace(b'\r\n',b'\n'))
  for forbidden in ('GetRSAPrivateKey','Set-AuthenticodeSignature','Get-AuthWireNamedMachineKeyMetadata','Set-Acl','WriteAllBytes','New-Item','Directory]::Move','Get-AuthWireCandidateSigner'):
   self.assertNotIn(forbidden,text)

 def test_current_and_legacy_installer_templates_are_explicit_and_identical_in_both_readers(self):
  expected={(ROOT/'kaname/device_client/Install-AuthWire.ps1').read_bytes(),(ROOT/'tests/fixtures/authwire-installer-dev45.ps1').read_bytes()}
  for name in ('Test-AuthWireCombinedContent.ps1','CombinedCandidateContent.ps1'):
   source=(ROOT/'windows/connector'/name).read_text()
   template=functions(source)['Get-AuthWireCombinedReadonlyTemplate']
   values={base64.b64decode(x,validate=True) for x in re.findall(r"FromBase64String\('([^']+)'\)",template)}
   self.assertEqual(expected,values)
   for value in values:self.assertIn(hashlib.sha256(value).hexdigest(),template)
   self.assertIn('COMBINED_READONLY_TEMPLATE_REJECTED',template)

 def test_service_probe_keeps_exact_current_verifier_body_pin(self):
  verifier=(ROOT/'windows/connector/Test-AuthWireCombinedContent.ps1').read_bytes().replace(b'\r\n',b'\n').rstrip(b'\r\n')+b'\n'
  service=(ROOT/'windows/connector/Test-AuthWireCombinedService.ps1').read_text()
  self.assertIn(hashlib.sha256(verifier).hexdigest().upper(),service)
  self.assertLess(len(verifier),131072)

 def test_fixed_runtime_delivery_contains_exact_reviewed_sources(self):
  text=(ROOT/'docs/checkpoints/2026-10-28-dc01-combined-runtime.ps1').read_text()
  raw=base64.b64decode(re.search(r"\$embedded='([^']+)'",text).group(1),validate=True)
  self.assertEqual(hashlib.sha256(raw).hexdigest(),re.search(r"\$archivePin='([^']+)'",text).group(1))
  pins=dict(re.findall(r"'([^']+\.ps1)'='([a-f0-9]{64})'",text))
  self.assertEqual(len(pins),5)
  with zipfile.ZipFile(io.BytesIO(raw)) as z:
   self.assertEqual(set(z.namelist()),set(pins))
   for n,pin in pins.items():
    self.assertEqual(hashlib.sha256(z.read(n)).hexdigest(),pin)
    expected=(ROOT/'tests/fixtures/combined-content-dev45.ps1') if n=='Test-AuthWireCombinedContent.ps1' else ((ROOT/'tests/fixtures/combined-service-dev45.ps1') if n=='Test-AuthWireCombinedService.ps1' else (ROOT/'windows/connector'/n))
    self.assertEqual(z.read(n),expected.read_bytes().replace(b'\r\n',b'\n'))
