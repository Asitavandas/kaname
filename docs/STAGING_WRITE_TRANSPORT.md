# Windows write-claim transport and durable receipt (source only)

This SDK is not in the active connector package or runtime. The appliance peer
write routes remain absent and administrator create remains closed. No Linux or
DC01 delivery, GPO staging, activation, endpoint execution or customer acceptance
is claimed by these source tests.

`StagingWriteTransport.ps1` extends the isolated preclaim primitives. The trusted
future adapter must still obtain an authorized offer, save it, run the fixed
signed readonly preflight and create the durable claim proof before transmission.
These helpers are internal SDK functions, not a public authorization boundary.

## HTTPS boundary

The separate .NET Framework client permits only the three fixed staging-write
paths under the configured HTTPS appliance origin. It requires normal chain,
hostname, validity and revocation validation **and** the paired leaf SHA256 pin.
It does not modify global TLS callbacks, trust stores, proxy settings or existing
readonly channel allowlists. Redirects, credentials, cookies, proxy use and
decompression are disabled. TLS 1.2 is required.

Requests are at most 4096 bytes. Poll replies are at most 32768 bytes; claim and
result replies are at most 4096 bytes. This is a transport allowance, not schema
acceptance. Status, JSON media type, charset, UTF8 and encoding are checked. A
single five-second cancellation deadline includes headers and streamed body
reads. Cancellation also disposes the response to interrupt Framework streams
that do not independently honor a read cancellation token. Unknown-length and
chunked bodies are bounded while being read, rather than after allocation.

The new orchestrator sends only CLAIM. Poll orchestration, result submission,
grant consumption and filesystem execution remain separate unfinished work.

## Durable one-send rule

`Invoke-AuthWireStagingWriteClaimTransport` reopens the private local offer, GPO
lock, preflight, claim-started and claim-proof records under native pins. Existing
reparse, alternate stream, hardlink and private root ACL checks remain in use.
It checks the actual runtime SID/hostname, persistent non-exportable signing key,
signature, exact frame purpose/path/binding, original payload and five-second
claim/preflight freshness. This verification uses only public key material;
transmission never constructs a second proof or changes an existing key.

Before any network attempt, it writes `claim-sent.json` using CreateNew and
Flush(true). A second thread or process cannot replace that marker. Even failure
before connection, a lost response, malformed grant, clock rollback or receipt
disk error leaves the marker and GPO lock. There is no automatic retry, cleanup,
renewal or unlock. Restarting/reloading the SDK cannot send that claim again.
This deliberately favors operator review over duplicate write authorization.

The grant has exactly ten fields and must match request, job, operation, intent
and target. Authorization ID must be a lowercase SHA256-shaped value. Flags must
be exact booleans with write authorized and GPO application false. The response
must arrive within the local five-second send window, remain unexpired, fit the
original lease, and expire no more than thirty seconds after receipt. The
original server expiry is recorded unchanged, never renewed by local receipt.

Only after validation does the SDK CreateNew/Flush `authorization.json`, binding
the original offer, preflight, proof, scope, release and timestamps to the exact
grant. The return value reports `GrantRecorded=true` but always
`FilesystemWriteEnabled=false` and `CanApplyGpo=false`. Receipt persistence is not
a filesystem outcome or permission to link/apply a GPO.

## Evidence boundaries

The hosted Windows check runs real WinPS5.1, native non-exportable machine CNG
RSA, NTFS records, TLS to a disposable Python HTTPS server, and the unchanged
SQLite `StagingWriteJobs.claim` core. The harness seeds already leased fixture
offers; paired binding lookup and current AD/candidate observations are explicit
stubs. This tests neither administrator enqueue authentication nor real AD,
gMSA, SMB, appliance peer routes or customer keys.

Four real grants exercise accepted receipt, mismatched response, lost response
and injected receipt disk failure. Each core grant rejects replay. Native checks
verify no second HTTP attempt after SDK reload, preserved locks and absence of a
valid receipt on failed cases. TLS tests cover untrusted root, wrong pin/name,
HTTP, forbidden paths, redirects, size bounds without Content-Length, slow
headers/body, wrong media type and invalid UTF8. The existing preclaim, signed
reader and Python wire compatibility checks also run.

The test changes only unique disposable runner keys/trust entries and restores
the runner hosts file. Its temporary web server key is unrelated to the native
connector signing key. No existing customer key/private material is exported.

## Remaining delivery gates

Grant consumption must still be bound once to the filesystem journal before a
write, with fresh AD/PDC/source/ACL rechecks and bounded execution. Separate
rollback approval, interrupted-write reconciliation, immutable completion/result
recovery, strict backup projection, package/signature delivery and real operator
acceptance are still required. HTTP create, write peer routes and live worker
registration must remain closed until those gates are complete.
