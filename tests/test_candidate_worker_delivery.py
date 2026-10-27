"""Exact standalone delivery data and source set; native behavior runs in Windows."""
import base64
import hashlib
import io
from pathlib import Path
import re
import unittest
import uuid
import zipfile

ROOT=Path(__file__).resolve().parents[1]
FROZEN_PINS={'Compare-AuthWireSigningKeyAcl.ps1': 'ea8d67ac4f7673654c24bee7b59aaf6d50f0427bdac6d05c535cd5d2d47e8734', 'ConnectorChannelKey.ps1': 'd6f0d2cebde20b9016ac8bc1c1cde566245a722ae447164fe55c946cfad43bd6', 'ConnectorChannelTypes.ps1': 'c5c72dd8fdacd703773609c0527dd91816477e8ffc3f87f2f304001b3f87ae79', 'ConnectorServiceControl.ps1': 'a6ba90bb2aabd1bb0ad12f649a0e7eabbedc54776194042a538d5fe8fec3f97d', 'ConnectorServiceHost.cs': '14e2246637793391937d16e8fb73218e237e9a57f26b7210b560f9a1c9f8082f', 'ConnectorServicePackage.ps1': '6ec8ef863ea410d627460b72efe60318c4716f205d1abf0d2a822a5e510b879d', 'ConnectorServiceRuntime.ps1': '5fbb6f04207336ab19977788e771e5434250bed640402c56b1694d7013ff0dbb', 'ConnectorServiceUpgrade.ps1': 'e808e8eb57832e3b9f18fa0e631dbb12a2046bad210775f7c1b18fb40476c7de', 'Initialize-AuthWireConnectorChannelKey.ps1': '836fc43feacb286239e556a1e2339e8ab141f1fe8363bf243764c087ddb0eece', 'Install-AuthWireConnectorService.ps1': 'fd91f9af6e7838ce1f795e8e3f64f0e10afe7380fbeb9524d211cadfebd7227f', 'Invoke-AuthWireCandidateJob.ps1': '8252bc3048d823df34183b49c87bec7667908a06176cce4f5ef65140190f3cdd', 'Invoke-AuthWireConnectorHealth.ps1': '1a58b86580ff123d2cd253b774f015a9bba747e5b072346786d6c133bed2122d', 'Invoke-AuthWireConnectorProbeJob.ps1': 'd032eb81410b2914eb72d9d70ad7a742773afcbfe8d536b820d81d1c8b9d85b6', 'New-AuthWireConnectorHealthProof.ps1': 'e8e369dcd0b60375ea2adb672f904dda217d22db3bab5a9b4981607e24958940', 'Test-AuthWireDeploymentCandidate.ps1': '24d3868c7d9d1b9747535092b2f3234fe8a18bf9d6eb5deb1a36780e894c8829', 'Update-AuthWireConnectorService.ps1': '0ffc2e433f2ead83725a14a07b41cd737f42a799a6780a7eab882fbf684d7ad3'}
ENTRY=ROOT/'docs/checkpoints/2026-10-27-dc01-candidate-worker-upgrade.ps1'

class CandidateWorkerDeliveryTests(unittest.TestCase):
 def test_embedded_archive_is_exact_current_reviewed_source_not_operator_code(self):
  text=ENTRY.read_text()
  table=re.search(r'\$reviewedSources=@\{(.*?)\n\}',text,re.S).group(1)
  pins=dict(re.findall(r"'([^']+)'='([a-f0-9]{64})'",table))
  self.assertEqual(FROZEN_PINS,pins)
  expected={'Compare-AuthWireSigningKeyAcl.ps1','ConnectorChannelKey.ps1','ConnectorChannelTypes.ps1',
   'ConnectorServiceControl.ps1','ConnectorServiceHost.cs','ConnectorServicePackage.ps1','ConnectorServiceRuntime.ps1',
   'ConnectorServiceUpgrade.ps1','Initialize-AuthWireConnectorChannelKey.ps1','Install-AuthWireConnectorService.ps1',
   'Invoke-AuthWireConnectorHealth.ps1','Invoke-AuthWireConnectorProbeJob.ps1','New-AuthWireConnectorHealthProof.ps1',
   'Update-AuthWireConnectorService.ps1','Invoke-AuthWireCandidateJob.ps1','Test-AuthWireDeploymentCandidate.ps1'}
  self.assertEqual(expected,set(pins))
  archive=base64.b64decode(re.search(r"\$embeddedSources='([^']+)'",text).group(1),validate=True)
  self.assertLess(len(archive),524288)
  self.assertEqual(re.search(r"\$archiveSha256='([^']+)'",text).group(1),hashlib.sha256(archive).hexdigest())
  with zipfile.ZipFile(io.BytesIO(archive)) as z:
   self.assertEqual(16,len(z.namelist()));self.assertEqual(expected,set(z.namelist()))
   for n in expected:
    data=z.read(n);self.assertEqual(pins[n],hashlib.sha256(data).hexdigest())
    self.assertEqual(FROZEN_PINS[n],hashlib.sha256(data).hexdigest())
 def test_new_release_is_not_the_running_release_and_component_is_canonical(self):
  text=ENTRY.read_text();release=re.search(r"\$releaseId='([^']+)'",text).group(1)
  self.assertEqual(release,str(uuid.UUID(release)))
  self.assertNotEqual(release,'970d7039-3798-478b-a5f4-a57e245693a0')
  component=re.search(r"\$sourceCommit='([^']+)'",text).group(1)
  self.assertRegex(component,r'\A[0-9a-f]{40}\Z')
