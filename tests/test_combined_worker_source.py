"""Public combined verification functions and source pins are auditable."""
import hashlib
from pathlib import Path
import re
import unittest

ROOT=Path(__file__).resolve().parents[1]

def functions(source):
    source=source.split('\nTest-AuthWireServiceCombinedContent @PSBoundParameters')[0]
    return {m[1]:chunk.rstrip() for chunk in re.split(r'(?m)(?=^function )',source)
            if (m:=re.match(r'function ([A-Za-z0-9-]+)',chunk))}

class CombinedWorkerSourceTests(unittest.TestCase):
    def test_library_contains_exact_public_verifier_bodies_and_no_entrypoint(self):
        old=functions((ROOT/'windows/connector/Test-AuthWireCombinedContent.ps1').read_text())
        raw=(ROOT/'windows/connector/CombinedCandidateContent.ps1').read_text()
        actual=functions(raw)
        self.assertEqual(9,len(actual))
        for name,body in actual.items():self.assertEqual(old[name],body,name)
        for forbidden in ('GetRSAPrivateKey','Set-AuthenticodeSignature','Set-Acl','WriteAllBytes','Get-AuthWireNamedMachineKeyMetadata'):
            self.assertNotIn(forbidden,raw)
        self.assertNotIn('Test-AuthWireServiceCombinedContent @PSBoundParameters',raw)

    def test_old_queue_still_explicitly_refuses_combined_receipts(self):
        source=(ROOT/'kaname/candidate_jobs.py').read_text()
        self.assertIn("require('artifact_kind' not in row",source)
        source=(ROOT/'windows/connector/Invoke-AuthWireCombinedJob.ps1').read_text()
        for required in ('Test-AuthWireJobCandidateContent','Assert-AuthWireCombinedJobAssets',
                         'Test-AuthWireServiceCombinedContent','AUTHWIRE-COMBINED-JOB-',
                         '/api/connector/v1/combined/poll','combined_content_rejected'):
            self.assertIn(required,source)
