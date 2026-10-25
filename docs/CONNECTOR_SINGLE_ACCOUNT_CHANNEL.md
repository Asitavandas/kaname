# Single-account Windows Connector: channel foundation v1

Decision: standard single-domain deployments should require one managed AD
service account, not three manually maintained accounts. The existing gMSA,
owned-GPO and machine code-signing preparations remain useful. The LDAP and
HTTP accounts are not disabled or repurposed during this development stage.

## First implemented slice

`kaname/connector_channel.py` and
`windows/connector/New-AuthWireConnectorHealthProof.ps1` implement a bounded
health challenge and proof primitive. They are deliberately not registered as
live HTTP routes, installed as a service, or wired into RADIUS/deployment status.
The path in the frame is a reserved protocol label, not an available endpoint.

An administrator-provisioned Binding pins installation GUID, connector GUID,
binding generation, AD computer GUID/FQDN, exact gMSA SID, appliance FQDN/TLS
leaf SHA256 and a dedicated public channel key. A peer-supplied key cannot
enroll or replace that binding. Durable administrative pairing/revocation,
authenticated HTTPS and its permission/audit boundary are the next slice.

The channel identity key is separate from the code-signing key and the Linux CA.
It is not another AD account. Windows uses a persistent non-exportable
machine RSA3072/4096 Software KSP signing-only key. The proof helper does not
create a key or grant access: controlled provisioning, gMSA-only use and key
ACL/lifecycle checks must be provided by the future installer. Production
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
pending/health state. Generation/key replacement requires invalidating the old
verifier when future durable pairing is integrated. No automatic trust-on-first-use.

A response proves only channel-key possession in this scoped health exchange.
It does not prove current AD membership, Kerberos client identity, certificate
installation, package signing or GPO execution. `can_apply`,
`directory_sync_ready`, and `kerberos_ready` always remain false. Online health
expires after90s independently of directory freshness or user authorization.

## Mandatory next integration gates

- Authenticated admin pairing with protected persistent binding, revision lease,
  audit, explicit rotation/revocation, and installer-owned channel key ACLs.
- Outbound HTTPS communication from Connector to appliance; normal TLS chain
  and FQDN validation plus the explicitly enrolled pin; no redirect, HTTP or
  certificate-error bypass. Merely copying a pin into the frame is not TLS
  validation. The current primitive intentionally performs no network calls.
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
