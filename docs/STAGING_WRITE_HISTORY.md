# Governed local write history archives

Source-only trusted local SDK. The continuous worker, installer, panel and peer
routes do not expose the new review or archival operation. This is bounded local
history maintenance, not customer delivery, an off-host backup or boot restore.

`Get-AuthWireWriteReconciliationReview` inspects the fixed private journal
under the same cycle mutex. It distinguishes incomplete POLL or CLAIM records,
an authorization with no frozen outcome, a frozen outbox awaiting a verified
ACK, and a verified ACK with missing local completion. Invalid, inconsistent
or unreadable history returns `evidence_invalid_or_unavailable`. An outcome
appears only after the existing completion or ACK readers validate it. The
reported outcome describes saved local evidence. The function creates no
records, sends no requests, and grants no permission to unlock or apply GPO.

For a verified saved offer the review also returns `Evidence`, a bounded
projection of the job ID, connector scope digest, intent digest, validated
result-body digest (when available), and whether the local ACK was verified.
`StagingWriteJobs.reconcile_readonly` accepts this projection from trusted
operator code and compares it with one SQLite read snapshot. Matching result
bytes and a missing local ACK are reported explicitly. Missing and mismatched
records do not resolve the job. The stored state and reported outcome describe
ledger evidence and cannot attest to the current filesystem or authorize action.
The comparison has no HTTP route, retry, ACK reconstruction, or unlock effect.

## Review and storage policy

The fixed private write root and immutable binding-scoped baseline remain
mandatory. `Get-AuthWireWriteHistoryReview` classifies saved history without
creating records, POLL/CLAIM/RESULT, live AD observations, execution or deletion.
It shares the cycle mutex. A 60-second review binds the generation, baseline,
previous signed archive head, monotonic slot range, original cycle bytes and
protected job, engine and GPO-lock records.

Only a full block of 64 observed and accepted cycles is eligible. Outcomes must
be `no_job`, `staged` or `rolled_back`; pending replies, missing completion and
`requires_review` block archiving. Historical grants are not consumed or renewed.
The exact review and acknowledgement
`archive_observed_history_preserve_all_evidence` are required. Review hashes
constrain trusted local consent; they are not authentication or network grants.

The active window stays bounded at 64 cycles. Up to eight signed archive
segments are retained, each at most 16 MiB of cycle data. At quota, maintenance
stops. No oldest archive, baseline or job lock is deleted. These are storage
bounds, not device quotas. Off-host retention/pruning and reconciliation remain
required before continuous service delivery.

## Copy verify seal retire

Native delete-capable leases bind only the reviewed local cycle directories and
compare held hashes again. An immutable intent is flushed under
`write-lifecycle/history-archives/NNNNNN`. Copies read through the existing native
handles, use create-only writes/durable flushes, and are independently hash
checked and held against mutation. The body binds scope, baseline, previous
head, original slots, totals, cycle hashes, reviewed state and intent.

The existing non-exportable CNG channel key seals it with the distinct
`AUTHWIRE-WRITE-HISTORY-ARCHIVE-V1` purpose. No private key is exported. Only after
the complete sealed copy exists may held local originals retire. The existing
native known-tree deletion primitive never traverses an unexpected new child.
Retirement has a maximum 30-second wall/monotonic budget inside the original
60-second review. No server write grant or deadline is created or renewed;
HTTP, AD freshness, reader, signed-child and server grant limits are unchanged.
The immutable commit is flushed last.

Original job, engine, stage-origin, result/ACK, GPO lock and legacy records remain
in their fixed root. Original baseline and archived cycle bytes remain intact.
Copies use private archive access rather than claiming an NTFS owner/ACL restore.
The archive area is created private only when new; existing ACLs are verified,
not weakened. This is not a full Windows journal/OS backup product.

## Continuation and interruption

Later lifecycle steps validate archive sequence/private boundaries, actual CNG
seal, previous-head chain, original stored POLL proofs and accepted completion
evidence. Duplicate request/job history is rejected across legacy, archive and
active history. Original slot numbers never restart: after sealing slots 1–64,
a **later** step may create slot 65. Archival itself sends no request.

Partial intent/copy, missing commit, changed bytes, unknown entries, sequence
gaps, generation changes or quota excess stop before a new POLL. There is no
automatic resume, commit reconstruction, cleanup, reset or unlock. Copy failure
leaves all originals; retirement failure may leave partial originals with the
complete verified archive and foreign data preserved. Neither is a successful
maintenance outcome. Governed reconciliation remains a separate gate.

## Verification scope

The hosted Windows fixture covers a real common stage and a legacy stage plus
idle history; preserved job/engine/lock records; review expiry/ack/state drift;
byte/seal tampering; lost commit; cross-archive replay; changed generation;
unknown/excess archive entries; actual copy and native retirement fault
boundaries; and a later real pinned HTTPS/RSA/SQLite POLL. Extra idle records
have real CNG signatures but synthetic no-job metadata, not server requests or
write grants. Positive AD/content/service identity observations remain fixture
substitutes. Recorded interruptions are not actual machine reboots. All
filesystem effects stay in owned temporary NTFS/SMB areas.

Pending: partial-maintenance reconciliation/unlock, off-host retention/restore,
refusal reporting, active scheduler/SCM, signed customer delivery, real reboot
and gMSA/AD/domain-SYSVOL/endpoint/latency acceptance.
