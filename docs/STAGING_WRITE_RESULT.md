# Durable staging result outbox — source only

This SDK freezes an authorized stage outcome before network I/O. It is not
registered in the shipped Connector package or worker. Appliance peer write
routes and administrator job creation remain closed. Nothing in this change
installs or executes a customer deployment, links a GPO, or enables GPO apply.

## Evidence and authority

`New-AuthWireWriteResultOutbox` accepts only the installer's fixed private
ProgramData journal root, current binding, current channel key and original
authorization receipt. Historical offer/proof/grant validation uses the recorded
CLAIM send/receive times; the live execution APIs still enforce the original
30-second expiry. Reading historical evidence never renews write authority.

A successful `staged` result requires the parent's immutable observation, the
child's exact result and identity, the original launch/intent, and the actual
filesystem engine completion and tree digests. This is a report of the completed
stage; it does not freshly attest the current SYSVOL contents or authorize
rollback. Reconciliation and rollback require separate current checks.

Without this full observation the only generated result is
`requires_review / OUTCOME_UNKNOWN / unconfirmed`, with empty completion hashes.
This includes partial writes, timeout, process interruption and a completed tree
whose child or parent reply was lost. No report claims that uncertainty means
zero filesystem effects. Corrupt observed evidence fails closed. It is never
silently downgraded into a convenient success or new authorization.

The global per-job decision mutex spans parent launch, child execution and
completion observation. A reporter cannot freeze an outcome during that interval.
The reporter also checks the original live kernel gate and exact PID/start time.
An abandoned mutex requires review; no process is killed by the reporter.
Stage launch refuses any existing result outbox. Existing per-GPO locks and all
local/engine records remain in place.

## Immutable report and bounded transport

The exact twelve-field result body and its digest are saved with CreateNew and
Flush(true) in `result-outbox.json`. Once frozen, subsequent calls return the
same body, including the original checked_at. No promotion from review to staged,
new AD observation, source copy, CLAIM or execution takes place on a result retry.

`Send-AuthWireWriteResult` performs at most one HTTPS POST per call and at most
three durable attempts per job. Each attempt is reserved before signing; its
fresh nonce/signature covers the same frozen body. Attempt gaps or corruption,
signing failures, transport failures and exhausted attempts preserve evidence.
There is no unbounded internal loop or timer in this SDK.

Normal TLS chain/name/time/revocation validation and the paired SHA256 leaf pin
are both required. The existing fixed RESULT route, five-second deadline,
4096-byte envelope/response and 1024-byte payload bounds remain in force.
Only an exact typed ACK matching the current request/job is accepted. It is
durably recorded before local success. A subsequent call with a valid accepted
receipt returns locally without signing or another HTTP request.

If the server committed but the ACK was lost, a fresh request with exactly the
same body is idempotent in the existing SQLite core and adds no second audit
transition. Initial reports retain the existing 300-second grace. Accepted
duplicates can be acknowledged later under the existing core rule; expired or
conflicting initial reports remain review work. There is no alternate journal,
reset, deletion or auto-unlock recovery path.

## Validation boundaries

The native WinPS 5.1 preclaim fixture exercises real non-exportable machine CNG,
durable private NTFS journals, pinned TLS and the unchanged real SQLite CLAIM and
RESULT core. AD/current-context lookup and already-leased test offers are explicit
stubs. It tests lost ACK with identical-body retry and distinct nonce, wrong ACK
and three-attempt exhaustion, outbox flush failure before network, strict fields,
hardlinks/streams, active kernel gate, module reload and reporting after original
write authorization expiry. No second CLAIM is sent.

The separate native execution fixture exercises a signed child and real SMB
filesystem engine using seeded grants and simulated AD/content observations.
Its successful observed stage becomes a success outbox; drift, partial writes,
bad engine result, metadata/disk failure, identity mismatch and timeout become
review outboxes. Result construction leaves SMB bytes/ACL and observation counts
unchanged. These two fixtures do not constitute one customer end-to-end run.

Still open: bounded POLL-to-RESULT worker orchestration, pre-authorization refusal
reporting, separately approved authenticated rollback adapter, restart/crash/disk
reconciliation, controlled packaging/delivery, off-host verified backup/restore,
and actual customer operator/endpoint acceptance. No live Linux/DC01 update or
backup is performed by these source checks.
