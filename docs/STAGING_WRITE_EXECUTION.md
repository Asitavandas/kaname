# Bounded authorized stage adapter (source only)

This SDK connects a saved, consumed grant and exact filesystem intent to the
isolated filesystem stage engine through a fixed AllSigned PowerShell child.
It is not included in the live connector package/runtime. Production create/peer
routes, GPO activation and endpoint deployment remain closed. No Linux/DC01
delivery or customer AD/GPO change is part of this source step.

## One launch and one child entry

The parent reopens the fixed private per-connector journal and verifies the
original claim signature, current runtime SID/hostname/key policy, binding,
receipt, consumed marker and exact intent. All identity/hash/time/flag fields
are strict. The operation ID must be the deterministic ID bound to that receipt;
it is a locator, never a substitute for authorization. Original expiry is not
renewed and the intent's live observation must still be fresh at parent launch.

Before starting any process, the parent CreateNew/Flush(true) writes
`stage-launch.json`. The only command is System32 Windows PowerShell5.1 with
`-NoProfile -NonInteractive -ExecutionPolicy AllSigned`, the fixed packaged
`Invoke-AuthWireStagingWriteChild.ps1`, local journal root, canonical job GUID and
the internally derived intent SHA256. No command, URL or source/GPO path can be
supplied by the job. The work budget is at most15 seconds and fits the remaining
original grant window with a two-second margin. Existing bounded kill/drain waits
are additional, up to3 seconds each. There is no retry after launch failure,
response loss, timeout, process crash or module reload.

The dedicated stage runner assigns the process to a Windows kill-on-close job
before releasing a private auto-reset event. Assignment or metadata persistence
failure never opens that gate. The parent flushes the exact child PID/start-time
record before release; the child must match its own identity and consume the
single signal. A direct later invocation cannot reuse a durable launch record
without that live parent-held gate. Parent death closes the kernel job and kills
the assigned child; descendants created after assignment inherit the job. This
is stronger than terminating only the immediate PowerShell process on timeout.

The child pins the local package/config, requires exact config fields and root,
opens only the configured dedicated machine CNG key and verifies its unchanged
ACL/public identity. It revalidates all authority/intent records, verifies the
launch, then atomically flushes `stage-entered.json`. A second direct child entry
cannot reuse it. The fixed child imports the standard AD/GroupPolicy modules and
rechecks public candidate signatures/content and current AD/PDC/GPO/SYSVOL scope
through the reviewed live-context reader. Source/GPO/protected GPO/PDC must equal
the approved local context; no grant path is used as an execution path.

## Actual stage and local completion evidence

The fresh child observation is flushed to `stage-preflight.json`. The adapter
passes the exact normalized preview, derived paths, protected GPO and original
grant expiry to the engine. The existing20-file/4MiB, new-directory-only, native
pin/identity/ACL/stream/hardlink, ownership journal and outside-baseline guards
remain. No payload artifact is executed. The unlinked GPO's settings, link and
GPT version are not activated by staging a version directory.

The engine checks the deadline before journal/destination creation, each
directory/file write and completion, with elapsed time as well as wall clock.
The zero-deadline default remains only for the historical trusted low-level
fixture interface; the authenticated adapter always passes the original expiry.
The parent also bounds the entire child so blocked AD/SMB work cannot run
indefinitely. Killing a process cannot prove that a remote SMB request had no
effect; uncertain/partial trees and every lock/journal are preserved for review.

On success, the child validates the actual engine intent/completion hashes,
target, preview, baseline, operation, paths and full23-row tree identity digest.
It flushes `execution-complete.json`, binding receipt/intent/launch/live-context
and actual completion/tree hashes, before returning a bounded JSON result.
The parent compares that result with pinned local journals and records
`execution-observed.json`. This is signed-child/local evidence, not independent
customer filesystem attestation or a result already accepted by the appliance.
`PeerResultSubmitted=false`, `CanApplyGpo=false` and `ArtifactExecuted=false`.

Any child error, invalid/truncated output, failed postcheck or missing result is
review-required; a review record is attempted without overwriting an existing
one. A failed launch-marker flush may leave only the original consumed/partial
launch records. No branch deletes data, rolls back, releases the GPO lock or
automatically starts another job. Even a complete engine journal with a lost
child reply requires separate reconciliation.

## Fixture boundaries

The hosted Windows fixture runs the unchanged production parent/child adapter
bodies in a disposable signed package, real native non-exportable CNG, NTFS and
actual SMB file creation/journals. Grants/receipts are locally seeded; the separate
preclaim transport workflow tests real HTTPS/SQLite issuance and replay rejection.
AD/content observations and SYSVOL namespace mapping are explicit signed fixture
shims. The production namespace derivation is separately checked before mapping
to a temporary localhost SMB share. This does not test a real domain, customer
gMSA, production SYSVOL name resolution or customer signing keys.

Cases cover stage success, context drift, engine completion disk failure,
incorrect engine result, launch-marker/child-metadata disk failure, wrong child
identity and a blocked child timeout.
Every case checks retained locks and no relaunch after SDK reload. Exact source
and SMB bytes/ACLs, real journals, key ACL preservation and cleanup of only unique
fixture keys/trust/shares/directories are checked. Native CI evidence is recorded
in the source checkpoint after completion.

A new direct signed child invocation also must fail without another live
observation. A separate real controller-death fixture verifies the kernel job
terminates its sleeping child; this is not a customer reboot or an interrupted
customer SMB transaction/restore test.

Remaining gates: result/POLL worker orchestration, separate rollback approval,
interrupted/partial transaction and lost-result reconciliation, strict backup
projection, signed package delivery, real gMSA/AD/SMB acceptance, and only then
controlled production execution. GPO activation/linking and real endpoint
acceptance are separate work. This source adapter does not complete those gates.
