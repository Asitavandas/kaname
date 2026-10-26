# Signed Windows network preparation candidate

The saved deployment plan and public network-profile ZIP now have a bounded local
signing step: `windows/connector/New-AuthWireDeploymentCandidate.ps1`.

This first candidate is for the machine-identity pilot with both Ethernet and
Wi-Fi. It is not an installed Connector worker operation or a GPO executor. It
does not install/enroll a client, import network profiles, modify trust or keys,
copy assets to SYSVOL, link a GPO or claim endpoint acceptance. Existing service
packages, accounts and pairing remain unchanged. `CanApplyGpo` stays false.

## Inputs and modes

The caller supplies an absolute network ZIP path, an absolute approval JSON path
and the approval's independently reviewed lowercase SHA256. The approval contains
exactly these fields:

```json
{
  "format": 1,
  "zip_sha256": "<64 lowercase hex>",
  "plan_id": "<canonical GUID>",
  "plan_version": 1,
  "preview_hash": "<64 lowercase hex>",
  "machine_profile_id": "<canonical GUID>",
  "machine_profile_version": 3,
  "group_sid": "<pilot domain group SID>",
  "domain": "example.test",
  "server_name": "radius.example.test",
  "ssid": "PilotSSID",
  "root_thumbprint": "<40 uppercase hex>",
  "connector_id": "<canonical GUID>",
  "service_sid": "<existing domain service SID>",
  "gpo_id": "<owned deployment GPO GUID>",
  "protected_gpo_id": "<different protected trust GPO GUID>",
  "publisher_thumbprint": "<40 uppercase hex>"
}
```

The approval is a local reviewed snapshot, not a new remote command authority or
permanent guarantee of current AD membership/GPO ownership. A future executor
must verify current binding, plan/profile revisions, AD targets, exact GPO marker,
links/settings, permissions and publisher trust before making any live change.
The legacy `WINDOWS_CONNECTOR_NOT_CONFIGURED` value in the old plan preview is not
treated as a new failure of the already accepted health/probe channel.

- `Inspect` validates inputs, certificate metadata and public signer chain; it
  does not create a directory, open a private key or sign anything.
- `Prepare` requires a current code-signing-only certificate in LocalMachine My,
  normal online signer-chain validation, and an RSA >=3072-bit non-exportable
  machine signing-only CNG key from Microsoft Software Key Storage Provider.
  It writes a private candidate below
  `ProgramData\AuthWire-DeploymentCandidates-<connectorN>` and signs a fixed,
  comment-only manifest. It never executes that manifest.
- `Verify` verifies an existing candidate. Repeated `Prepare` also verifies it
  without replacing or re-signing any bytes. Drift requires review.

All modes require a 64-bit elevated administrator process. The tool creates no
account or service and changes no key ACL or trust store. A future gMSA worker
will use a separately reviewed integration; administrator preparation is not
claimed as customer gMSA execution of this new helper.

## Validation and output

The exact seven-file input ZIP is held in memory with strict byte limits. No ZIP
entry is extracted to an input-chosen filesystem path. Entry names, uniqueness,
internal SHA256, plan/profile/group/version bindings and typed flags are checked.
JSON rejects duplicate/case-folded keys, excessive nesting, oversized input and
invalid UTF-8. The two XML trees must match the machine EAP-TLS generator's exact
schema, root and server checks; DTDs, extra nodes/attributes and other EAP methods
are rejected. Public CA dates, CA constraints, pinned root DER fingerprint and
issuer-to-root path are checked without adding that root to Windows trust.
Public CA path validation uses offline revocation mode; this is not a CRL or
RADIUS leaf validation claim. The RADIUS leaf is not present in this ZIP.

The candidate contains exactly:

1. `network-profiles.zip` (original, byte-for-byte);
2. `approval.json` (original pinned approval);
3. `AuthWire-Candidate-Manifest.ps1` (fixed comment-only Base64 JSON manifest with
   an actual Authenticode signature covering the approval hash, ZIP hash, exact
   plan, Connector and owned GPO identities).

Candidate directories and files have protected administrator/SYSTEM write access
and only read access for the existing service SID. Reparse points, extra files,
broadened ACLs, wrong signer, data drift or executable manifest bodies are refused.
Atomic directory publication avoids exposing a partially signed candidate as
complete. Failed preparation removes only its newly created staging directory;
an empty protected parent may remain. No candidate overwrite/cleanup capability
is exposed for an existing published candidate.

## Native verification

`tools/deployment_candidate_windows_check.py` builds synthetic root/issuer
certificates and profiles using the actual Python network XML generator, then
invokes the PowerShell fixture on a disposable GitHub-hosted Windows runner.
The fixture uses a real non-exportable machine CNG key, actual Authenticode,
fresh `-NoProfile -ExecutionPolicy AllSigned` inspection, real NTFS ACL/reparse
checks and changed data/identity/XML/manifest refusal. It temporarily trusts only
its own disposable signer and removes its key, trust entries and candidate.
It never contacts customer AD or imports endpoint network profiles. These tests
do not replace customer candidate acceptance or a future GPO/endpoint test.
