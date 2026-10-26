# Single-account Windows Connector: channel foundation v1

Decision: standard single-domain deployments should require one managed AD
service account, not three manually maintained accounts. The existing gMSA,
owned-GPO and machine code-signing preparations remain useful. The LDAP and
HTTP accounts are not disabled or repurposed during this development stage.

## Health primitive and authenticated HTTPS transport

`kaname/connector_channel.py` and
`windows/connector/New-AuthWireConnectorHealthProof.ps1` implement a bounded
health challenge and proof primitive. The source now registers two fixed peer
HTTPS routes: POST /api/connector/v1/challenge and POST /api/connector/v1/health.
They authenticate possession of an administrator-enrolled dedicated channel key.
They do not install a service or enable AD, Kerberos, RADIUS or deployment work.
Customer rollout remains pending; the running customer appliance is dev.34.

An administrator-provisioned Binding pins installation GUID, connector GUID,
binding generation, AD computer GUID/FQDN, exact gMSA SID, appliance FQDN/TLS
leaf SHA256 and a dedicated public channel key. A peer-supplied key cannot
enroll or replace that binding. Durable administrative pairing/revocation is
implemented by the companion registry described below. The actual Windows
key provisioning and HTTPS health functions are implemented below; health-only
SCM host/runtime source is also prepared; actual customer gMSA acceptance and
staged upgrade/rotation remain separate gates.

The channel identity key is separate from the code-signing key and the Linux CA.
It is not another AD account. Windows uses a persistent non-exportable
machine RSA3072/4096 Software KSP signing-only key. The proof helper does not
create a key or grant access. The companion preparation engine creates one
dedicated key and grants only SYSTEM, Administrators and the exact gMSA SID;
health-only install/control sources are prepared; actual gMSA acceptance and staged upgrade/rotation are still pending. Production
must not reuse the existing code-signing key as this channel key.

## Frame and proof

The signed bytes are ASCII with LF separators, exactly these 16 lines followed
by a final LF:

1. AUTHWIRE-CONNECTOR-HEALTH-V1
2. installation UUID
3. connector UUID
4. binding generation, canonical positive decimal
5. AD computer UUID
6. connector computer FQDN, lowercase
7. runtime service account SID
8. appliance FQDN, lowercase
9. appliance HTTPS leaf SHA256, lowercase hex
10. channel public-key identifier, lowercase hex
11. challenge ID, random 32 bytes as lowercase hex
12. nonce, independent random 32 bytes as lowercase hex
13. issuance Unix seconds
14. expiry Unix seconds, issuance plus 60
15. POST
16. /api/connector/v1/health

The public-key identifier is SHA256 over ASCII
`AuthWireConnectorKeyV1` + LF + canonical Base64 unsigned big-endian modulus
+ LF + `AQAB` + LF. Only exponent65537 and RSA3072/4096 are accepted. Public
SPKI PEM in the server binding is canonical and contains no private material.
This explicit format avoids reliance on unavailable .NET Framework SPKI APIs.

Windows signs those exact bytes with RSA PKCS1v1.5/SHA256 only after validating
every binding, operation, byte and time field against its trusted local binding.
It also checks current process SID, local computer short name and CNG key
policy. This validates the calling Windows identity, not SCM installation or
proof that a particular job was executed. The helper accepts no scripts,
commands, arbitrary data signing request, claimed end-user or directory result.

The reply is UTF8 JSON with exactly `challenge_id` and `signature` (canonical
Base64). The server looks up its original frame and uses only the locally
pinned public key; no signed frame or key from the response is trusted.
Proofs are single-use with atomic consumption, at most four pending challenges,
three bad signatures per challenge and a monotonic60s deadline. Restart loses
all challenges and last-seen state; the peer must reconnect. Revocation clears
pending/health state. The durable registry invalidates the old verifier on
generation/key replacement, including across processes. No automatic trust-on-first-use.

A response proves only channel-key possession in this scoped health exchange.
It does not prove current AD membership, Kerberos client identity, certificate
installation, package signing or GPO execution. `can_apply`,
`directory_sync_ready`, and `kerberos_ready` always remain false. Online health
expires after90s independently of directory freshness or user authorization.

## Mandatory next integration gates

- Actual customer acceptance of the dedicated key preparation, exact gMSA,
  health-only SCM service and HTTPS roundtrip. The signed host, protected runtime
  configuration, install/control and recovery sources are prepared; signed
  delivery, real boot/policy refresh and staged upgrade/rollback/rotation remain.
  Hosted fixtures do not establish an installed customer Connector. Independent
  host/account/key confirmation remains mandatory; pairing is a trust decision,
  not host attestation.
- Mutually authenticated, bounded job/result channel with exact operation and
  body binding, expiry, replay protection, idempotency and retry reconciliation.
  Health proof must never authorize arbitrary PowerShell or a GPO mutation.
- Move directory catalog/live lookups behind the Connector with scope and
  timeout/freshness guards. Cached catalog is not live AD acceptance. Preserve
  disabled/deleted/recreated account and nested/primary-group rejection behavior.
- Move Kerberos acceptor to Windows under the same gMSA, using the one owned SPN,
  mutual authentication, integrity/MIC on exact path/body/CSR, replay/sequence
  checks and separate machine/user sessions. No principal supplied by an HTTP
  header or a plain connector claim can become enrollment evidence.
- Preserve Linux CA/RADIUS boundaries, profile versions, certificate registry
  and CSR proof; define fail-closed behavior when AD/Connector is unavailable.
- Scoped GPO jobs use only the prepared owned GPO and separately controlled
  publisher trust. Existing trust GPOs are not silently adopted/delegated.
- Controlled pilot, outage/recovery/rollback and 200-device acceptance, then
  dependency-based retirement of old LDAP and HTTP account/SPN/keytab usage.

No new AD account, private-key export, customer state mutation, service restart,
app release, GPO link or endpoint deployment is part of this slice. A03/A04 and
the single-account migration remain open.

## Validation

Python tests exercise real RSA signatures, all frame-field tampering, different
keys, concurrent replay, monotonic expiry, bounded pending state, revocation,
restart/generation separation and strict JSON/key/binding boundaries.
The hosted Windows fixture creates one disposable non-exportable CNG machine
key, produces a native Windows PowerShell5.1 proof, and verifies it independently
in Python. It rejects wrong scope, operation, key policy and malformed/expired
frames, preserves the key ACL and removes its fixture key. No customer AD,
GPO, service, certificate or trust-store writes occur in that fixture.

References:
- https://learn.microsoft.com/en-us/entra/architecture/service-accounts-group-managed
- https://learn.microsoft.com/en-us/dotnet/api/system.security.cryptography.rsacng
- https://learn.microsoft.com/en-us/windows/win32/secauthn/context-requirements


## Durable administrator pairing (source prepared; customer rollout pending)

`kaname/connector_registry.py` stores one public trust binding under
`runtime_settings.windows_connector_pairing` in the existing protected SQLite
store. Pair/rotate/revoke and append-only audit/revision updates share one
transaction. No new credential database, AD account, private key, certificate,
GPO or service is created. Status/preview reads do not create a trust row.

Administrator API:

| Method / path | Permission and behavior |
|---|---|
| GET /api/deployment/connector | system.connectors read; HTTPS; metadata only, no public PEM/private material |
| POST /api/deployment/connector/preview | system.connectors write; interactive panel session, HTTPS, Origin and CSRF; read-only preview |
| POST /api/deployment/connector/apply | Same write boundary; rechecks current principal under administrator DB read transaction; commits preview-bound trust change |

The new permission is not inherited from directory or certificate write grants.
SuperAdmin and explicitly delegated connector administrators may manage pairing;
Admin_ReadOnly can inspect metadata only. A maintenance bearer token may inspect
status but cannot provision/rotate/revoke trust. Authentication failure, CSRF,
foreign Host/Origin, plaintext HTTP, unknown fields/queries, duplicate JSON and
peer self-registration are rejected. The two fixed peer health routes below use
dedicated key authentication; browser sessions or bearer tokens cannot replace it.

The preview body is exactly `expected_revision`, `operation`
(`pair`, `rotate`, `revoke`) and `candidate`. A pair/rotate candidate contains
all Binding fields except generation; its public PEM must be canonical
RSA3072/4096/exponent65537 SPKI. The server assigns the next generation. Candidate
instance, appliance FQDN and TLS leaf fingerprint must match local initialized
PKI/configuration and the loaded valid serverAuth/SAN web certificate; connector
host must be in the configured AD DNS domain. This scopes an administrator's
explicit trust decision, not an independent AD lookup/host attestation.

Apply also requires the exact `preview_hash` and `confirmed_key_sha256`
(`''` for revoke). The administrator must compare the public key/host/account to
the trusted installer output; blindly copying a peer-supplied fingerprint is not
identity verification. The preview binds prior public trust, global revision and
current context. Changing a candidate/context invalidates it. A stale writer
gets409; a lost reply is reconciled through GET metadata/generation/fingerprint,
without repeating a trust write or weakening the revision lease.

Rotation keeps installation/connector/host/service identity fixed and changes
only the dedicated public key and/or current appliance TLS pin. Moving identity
requires explicit revoke then pair. Revocation retains a tombstone and generation;
re-pair cannot reset the counter. Exhausting the generation range blocks new
pair/rotate but still permits revocation. No-op rotations and duplicate pairing
are rejected. An audit/commit failure rolls back trust and revision and preserves
the previous volatile verifier until commit succeeds.

Every internal health challenge/acceptance reloads the current binding. Acceptance
holds a SQLite write transaction to serialize it with a concurrent revoke/rotate.
Old local caches in other registry instances/processes are invalidated by durable
state/generation changes. Restart retains public pairing but loses all nonces and
online state. Configuration/PKI/TLS context drift blocks proofs; revocation remains
available for a stale binding. Malformed stored records fail closed without repair.

`paired=true` is a configured trust decision, not a running Connector.
`transport_active` follows recent verified health (90-second freshness); it is
false after restart/expiry/revoke and is not SCM installation attestation.
`can_apply/directory_sync_ready/kerberos_ready` remain false. Dedicated key
preparation, outbound HTTPS health and health-only SCM service sources are
prepared. Customer gMSA acceptance, upgrade/rotation, jobs and legacy-account
migration remain open.
The new administrator API is source-prepared and tested; it has not been deployed
to the customer's live dev.34 appliance.

Validation adds17 SQLite/public-PKI tests and9 real verified HTTPS boundary tests,
including a real second-process revoke, restart/rotation, concurrent stale
writers, failed audit rollback, role demotion before commit, actual plaintext
refusal, and lost-reply reconciliation. SQLite backup retains public pairing and
the existing backup stability fingerprint tracks its rotation; volatile health
proofs do not survive that copy. No backup worker changes are needed for storage.
Restoring an older appliance/database is still a separate activation/re-approval
gate: this code does not claim rollback-resistant revocation across old backups
or full appliance boot-restore acceptance.



## Dedicated Windows key and outbound HTTPS health (source prepared)

Accepted source: PR85, 8fc2859ccccbfb72a46b586cd4a8ec8507a44dfe; merge 6ac3a0f86395b7b13ad74e8cdfaf37e202fb9dff.
Native WinPS5.1 validation:19 channel tests,33 prior CNG checks,8 new key/ACL
checks and16 actual HTTPS checks. Five actual HTTPS handler tests also pass;
full foundation774 tests (28 environment skips), all seven PR workflows pass.
See checkpoints/2026-10-26-connector-dedicated-key-https.json.

`Initialize-AuthWireConnectorChannelKey.ps1` defaults to Inspect. The public
entry verifies the signed existing bootstrap and helper publisher, current
computer/domain, existing bootstrap connector UUID, gMSA SID, KDS/account
readiness, local Test-ADServiceAccount and elevated administrator context. It
does not create or repair an AD account, change GPOs or reuse the code-signing key.

PrepareKey creates a protected, connector-owned ProgramData directory and one
persistent RSA3072 Software KSP machine key, non-exportable and signing-only.
A receipt is flushed before key creation and atomically advanced after creation
and ACL verification. Its public binding, public PEM, key ID and expected ACL
allow idempotent reuse of that exact verified key. Partial receipts, foreign
scope, unexpected owner/ACL, reparse points and writable receipts stop for
review; they never silently create a second key or repair existing permissions.
The gMSA receives read/use access, not key export or write access. SYSTEM and
Administrators retain full control. ServiceKeyAccessVerified remains false until
the actual gMSA executes a signed proof with this dedicated key.

`Invoke-AuthWireConnectorHealth.ps1` performs two fixed signed operations:

1. A bounded, 60-second POLL frame signed by the paired key requests a challenge.
   It has the same identity fields as the health frame, a client request ID and
   nonce, tag AUTHWIRE-CONNECTOR-POLL-V1 and path /api/connector/v1/challenge.
2. The server verifies signature, binding, time and replay state before allocating
   its independent unpredictable health challenge. The Windows helper signs it;
   the health response cannot confer AD/GPO/Kerberos authority.

Poll JSON is exactly frame/signature, strict UTF8 with canonical Base64 and a
4096-byte cap. Poll replay memory is volatile, bounded to128 entries and65-second
monotonic retention; a restart may permit an unexpired poll to request a new
challenge, never replay an old health proof. Invalid signatures allocate no poll
slot or challenge. Signature completion rechecks expiry.

Both peer routes require HTTPS and an allowed Host and reject any Origin,
Cookie or Authorization header, even empty. They accept only bounded JSON POST
bodies; no transfer encoding or arbitrary operation is accepted. Per actual
client IP, the cap is30 attempts/60seconds with64 IP buckets; at most4 peer
operations run concurrently. Rejections disclose no key, identity or trust state.
An outbound denial cannot hold the rate-map lock during socket writes.

The per-request .NET Framework HttpClientHandler uses TLS1.2, normal chain and
FQDN validation, revocation checking and the exact enrolled SHA256 leaf pin.
No redirect, HTTP, proxy, cookies, default credentials, global TLS callback or
certificate-error bypass is allowed. Timeout/cancellation is configured to five
seconds, with a16KiB response-header and4096-byte complete buffered-body cap.
Slow response headers and bodies are tested. OS DNS/certificate operations can
outlast that SDK timeout; it is not a universal wall-clock five-second guarantee.
The service independently bounds child lifetime with a kill-on-close job. JSON replies are strict and reject duplicate/unknown fields,
invalid encoding or authority overclaims. Caller-supplied binding/key parameters
come from the protected hash-bound service configuration described in
WINDOWS_CONNECTOR_HEALTH_SERVICE.md, not network input.

Hosted Windows tests create and remove a disposable machine CNG key and owned
receipt directory, and exercise real HTTPS against the actual Python handler.
Only the disposable hosted runner temporarily trusts its public fixture
certificate and adds loopback host aliases; both are restored in finally.
These are not customer trust-store changes or proof of gMSA/SCM installation.
Existing customer accounts, SPNs, signing keys, GPOs and endpoint packages remain
unchanged. The health-only permanent service is source-prepared below;
actual gMSA, boot, delivery and upgrade/rotation acceptance remain pending.

## Health-only permanent Windows service (source prepared)

PR86 source e743a8bc66b15f4dca5213fd35de8b02957d097d; merge 62e9be9d4e58bd06ad38f6aeffaf3dbb32dcdc5a.
The fixed signed x64 SCM host, reviewed-source-only package builder, protected
runtime configuration, default read-only Inspector, owned gMSA installation and
bounded network/crash/stop recovery are implemented. A private kill-on-close
Windows job also covers blocked worker/descendant cleanup. The account password
is neither read nor exported. No AD/GPO/Kerberos job or arbitrary command is added.

Native Windows acceptance adds23 checks with an isolated temporary local account,
actual SCM, machine CNG key and verified HTTPS against the Python handler.
The public builder/Inspector, non-gMSA refusal and administrator-tool ACL
separation are covered. Full foundation774 tests (28 environment skips), three
relevant PR workflows and all four native Windows jobs pass. This is not actual
DC01 gMSA/reboot acceptance. Existing packages are immutable in v1; staged
upgrade/rollback and key/pin/publisher rotation remain open gates.

See WINDOWS_CONNECTOR_HEALTH_SERVICE.md and
checkpoints/2026-10-26-connector-permanent-service.json. The customer appliance
remains dev.34; no customer service/account/key/trust/GPO mutation occurred.

## Installation identity namespaces

Do not equate the appliance and Windows bootstrap installation IDs:

| Field | Authority / existing use |
|---|---|
| Binding.instance_id | Local appliance pki_authority.instance_id |
| Binding.connector_id | Windows bootstrap InstanceId, retained in its owned gMSA/GPO markers |
| Binding.host_guid | AD computer object GUID, not hardware/SMBIOS UUID |

For the current pilot, connector_id is4c23eebe-0715-46d1-88ee-a2e96ad7ee46.
The existing Windows tools keep that value in their InstanceId parameter. The
future adapter maps Binding.connector_id to that parameter; it never rewrites
ownership markers to the appliance PKI UUID or recreates the prepared account/GPO.
The appliance UUID must be read from its trusted local metadata, not guessed
from a root certificate CN or inferred from the Windows bootstrap value.
