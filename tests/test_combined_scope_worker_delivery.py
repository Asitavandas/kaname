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
ENTRY=ROOT/'docs/checkpoints/2026-10-28-dc01-combined-scope-worker-upgrade.ps1'

class CombinedScopeWorkerDeliveryTests(unittest.TestCase):
 def test_embedded_archive_is_exact_current_reviewed_source_not_operator_code(self):
  text=ENTRY.read_text()
  table=re.search(r'\$reviewedSources=@\{(.*?)\n\}',text,re.S).group(1)
  pins=dict(re.findall(r"'([^']+)'='([a-f0-9]{64})'",table))
  expected={'Compare-AuthWireSigningKeyAcl.ps1','ConnectorChannelKey.ps1','ConnectorChannelTypes.ps1',
   'ConnectorServiceControl.ps1','ConnectorServiceHost.cs','ConnectorServicePackage.ps1','ConnectorServiceRuntime.ps1',
   'ConnectorServiceUpgrade.ps1','Initialize-AuthWireConnectorChannelKey.ps1','Install-AuthWireConnectorService.ps1',
   'Invoke-AuthWireConnectorHealth.ps1','Invoke-AuthWireConnectorProbeJob.ps1','New-AuthWireConnectorHealthProof.ps1',
   'Update-AuthWireConnectorService.ps1','Invoke-AuthWireCandidateJob.ps1','Test-AuthWireDeploymentCandidate.ps1','DeploymentScope.ps1','Read-AuthWireDeploymentScope.ps1','Invoke-AuthWireScopeJob.ps1','CombinedCandidateContent.ps1','Invoke-AuthWireCombinedJob.ps1','CombinedDeploymentScope.ps1','Invoke-AuthWireCombinedScopeJob.ps1','Read-AuthWireCombinedDeploymentScope.ps1'}
  self.assertEqual(expected,set(pins))
  archive=base64.b64decode(re.search(r"\$embeddedSources='([^']+)'",text).group(1),validate=True)
  self.assertLess(len(archive),524288)
  self.assertEqual(re.search(r"\$archiveSha256='([^']+)'",text).group(1),hashlib.sha256(archive).hexdigest())
  with zipfile.ZipFile(io.BytesIO(archive)) as z:
   self.assertEqual(24,len(z.namelist()));self.assertEqual(expected,set(z.namelist()))
   for n in expected:
    data=z.read(n);self.assertEqual(pins[n],hashlib.sha256(data).hexdigest())
    source=(ROOT/'windows/connector'/n).read_text().replace('\r\n','\n').rstrip('\r\n')+'\n'
    self.assertEqual(source.encode(),data)
 def test_new_release_is_not_the_running_release_and_component_is_canonical(self):
  text=ENTRY.read_text();release=re.search(r"\$releaseId='([^']+)'",text).group(1)
  self.assertEqual(release,str(uuid.UUID(release)))
  self.assertNotEqual(release,'689649c0-61df-40aa-bbfb-b84fa1cc2ac0')
  component=re.search(r"\$sourceCommit='([^']+)'",text).group(1)
  self.assertRegex(component,r'\A[0-9a-f]{40}\Z')

 def test_dc01_delivery_is_bound_to_the_last_accepted_scope_worker_release(self):
  text=ENTRY.read_text()
  current=re.search(r"\$oldRelease=\[guid\]'([^']+)'",text).group(1)
  self.assertEqual('689649c0-61df-40aa-bbfb-b84fa1cc2ac0',current)
  self.assertIn('-ExpectedCurrentRelease $oldRelease',text)
