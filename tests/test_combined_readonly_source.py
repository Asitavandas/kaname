"""Keep the service's keyless verifier limited to reviewed public functions."""
import base64
import re
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
