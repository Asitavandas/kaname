# Read-only verification under the Connector service identity

The first signed network candidate and its panel receipt are accepted. The old
Prepare/Verify entry point requires administrator membership, so it cannot be
used unchanged by the installed non-admin Connector worker.

`Test-AuthWireDeploymentCandidate.ps1` is the runtime prerequisite. It requires an
exact, authenticated, non-administrator SID and ten scalar pins. The candidate
path is derived beneath the fixed ProgramData Connector/plan/version/hash tree.
There is no input command, script, executable, URL or arbitrary file path. It
checks the exact protected read-only ACLs, original pinned approval, bounded ZIP,
duplicate-safe JSON, exact XML/server/root configuration, public CA signatures,
public TrustedPublisher code-signing chain, native Authenticode and a comment-only
manifest. It rechecks all three pinned files before returning success.

It does not open a private key, sign a file, execute a candidate, import a profile,
write AD/GPO/SYSVOL or change trust/ACL. The inherited public CA path validation
does not establish current RADIUS leaf/CRL or directory/GPO freshness.
`GpoStateChecked=false`, `DirectoryFreshnessChecked=false` and `CanApplyGpo=false`
remain explicit. Virtual service SIDs are also accepted when externally pinned;
the existing DC01 deployment still uses the same aw-deploy$ gMSA SID.

`Test-AuthWireCandidateService.ps1` uses an owned temporary signed SCM executable
to exercise that verifier under the exact service account. The compiled host
binds one reviewed signed verifier, its raw signed-file hash and the ten pins;
arguments are passed with AddCommand/AddParameters, not evaluated as code. A
nonce, runtime SID, service logon group and actual SCM PID bind the result. The
probe checks the typed result and cleans up its temporary service, executable,
verifier copy and runtime output. Admin-only summary/evidence remains. The probe
host is a temporary diagnostic service, not the permanent Connector upgrade.
The operator preparing this probe uses the existing local machine signer to sign
only reviewed helper/host code; this is distinct from the verifier's key-free run.

The DC01 wrapper pins the existing account, Connector release, exact candidate,
signer and protected trust context. It snapshots the permanent Connector PID,
config/package/executable, candidate bytes/ACL and signing-key ACL before/after.
It creates only a new signed source directory and the owned temporary probe.
Existing signed source directories are verified and never overwritten. Repeating
the probe creates a separate temporary diagnostic service; it is not a resumed
deployment and does not reissue/re-sign the candidate.

Native CI runs Windows PowerShell 5.1 and a real dedicated non-admin virtual SCM
identity with synthetic public network/CA data, machine CNG signing, native
AllSigned/Authenticode, NTFS ACLs and negative content/pin/identity tests. It does
not prove customer gMSA, AD/CRL network access or permanent worker acceptance.
The exact DC01 delivery archive, reviewed helper bodies, ACLs and host rejection
are exercised without running its customer main.

This step does **not** update the panel's `connector_verified=false` receipt.
The next integration still needs a bounded typed worker job, authenticated result
roundtrip, current plan/dependency and owned GPO checks. Links-free staging and
GPO application remain later separate gates. No permanent manual-probe workflow
is intended for the final automated product.
