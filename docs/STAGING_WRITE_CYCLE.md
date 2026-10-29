# Single controlled stage cycle — source only

`StagingWriteCycle.ps1` connects the existing pinned POLL/CLAIM/RESULT transport,
fixed signed preflight, one-use grant consumption, bounded signed stage child and
immutable result outbox. This is one controlled transaction for a trusted local
caller, not an unattended polling service. It is not registered in the shipped
package/runtime; production administrator creation and peer write routes stay
closed. No customer installation or GPO activation is performed by this change.

## Entry and interruption rules

The installer-provisioned fixed private ProgramData journal root must be empty.
A global Connector mutex serializes the whole cycle. The exact POLL proof and
request identity are flushed with CreateNew before HTTP transmission. Any prior
record, including a lost or no-job POLL, stops a new cycle before signing/network.
This intentionally conservative API has no idle loop, automatic pruning, reset,
alternate root, cleanup or unlock. A new empty store is not recovery. Permanent
worker integration must separately handle authenticated idle history and bounded
retention before it can be enabled.

The typed POLL response must match the request and binding scope. An exact empty
response records no-job without creating a deployment. Only the stage operation
is accepted; rollback remains a separately approved adapter. Nonempty offers are
persisted with the existing GPO/job locks, followed by the fixed AllSigned live
reader, one-use CLAIM, durable receipt, grant consumption, another live reader,
and the bounded stage child. All original preview/grant/deadline, content, scope,
identity, file/ACL and no-activation checks remain in force.

If a grant or its local receipt is lost, the cycle reports local reconciliation
required and never consumes or reclaims an unknown authorization. A stage or
consumption failure with a valid receipt generates the existing conservative
review outbox. A lost RESULT ACK leaves result_pending. Neither case is retried
inside this function.

`Resume-AuthWireStagingWriteCycleResult` validates the saved cycle/offer link and
historical authorization, then invokes only bounded result reporting. It cannot
POLL, CLAIM, consume, execute, delete or unlock. The immutable body, fresh nonce
per attempt, three-attempt cap, exact ACK and accepted-receipt local return are
unchanged. Partial disk records or missing/corrupt authority fail closed.

The cycle has no new whole-transaction wall-clock guarantee. Existing HTTPS
calls are each bounded to five seconds; preflight/intent/stage processes retain
their original budgets and grant expiry. Local disk/CNG latency and remote SMB
completion still require real customer validation. Process termination does not
prove that remote effects were absent.

## Safe failure diagnostics

The signed stage child now reports only allowlisted failure phase and exception
category. The parent retains those, parent phase, timeout/truncation/exit status,
and numeric work budget/elapsed time in a bounded private review record. It never
stores raw exception text, stdout/stderr, paths, key material or configuration.
Malformed child diagnostics are ignored and the result remains uncertain.
Timeout, context drift and engine failure are tested separately. No authority,
deadline, or gate was relaxed to make a previously intermittent CI test pass.

The PR125 success-scenario failure cannot be retrospectively attributed: its
inner diagnostics were not retained. This change makes future occurrences
distinguishable; actual reproduction/root cause and customer latency acceptance
remain required before controlled delivery.

## Combined native fixture

The Windows fixture can now run with a disposable pinned TLS server and the real
SQLite core. Only the initial queued jobs/approval history and AD/current-target/
content/namespace observations are explicitly seeded or simulated. POLL leases,
CLAIM grants, machine CNG proofs, signed reader/child, actual SMB stage journals,
RESULT transition and immutable retry gates use the production SDK/core bodies.
The two older separate fixtures remain regression checks.

Cases include real success, drift, partial/completion disk error, wrong engine
result, launch/child-metadata failure, identity mismatch, timeout, lost ACK, lost
grant, lost/changed POLL reply and no job. Re-entering a cycle sends no second
POLL; result-only recovery repeats no live observation or SMB write. The test
runner removes only its own disposable journal between independent cases; that
fixture isolation is not a product reset/recovery API. No payload is executed.

Still open: pre-authorization refusal reporting, permanent idle/history lifecycle,
separately approved authenticated rollback, reboot/partial-journal reconciliation,
explicit unlock, strict backup projection/off-host restore, controlled signed
delivery and actual customer gMSA/AD/domain-SYSVOL/endpoint acceptance.
