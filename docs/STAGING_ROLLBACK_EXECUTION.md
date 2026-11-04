# Bounded authenticated rollback child, parent observation and RESULT

Source-only SDK following PR129's separate rollback CLAIM/receipt/one-use intent.
It is not loaded by the permanent package/worker and exposes no production route.
It performs real deletion only when explicitly called by a trusted local adapter
after validating the entire authority chain. No customer delivery is implied.

The input remains the original false-flag consumption intent. A path, hash or
operation ID alone cannot authorize deletion. The adapter pins rollback authority,
reservation, original GPO lock and original accepted stage chain/engine journals.
It verifies the CLAIM proof, exact receipt, consumption, original deadline and
consumption witness under those pins. Current permission is separate from history.

A durable one-launch marker precedes process creation. A private one-use event
gate binds the fixed AllSigned System32 WinPS5.1 child to the registered PID and
process start ticks. The existing kill-on-close Windows job runner enforces
min(15 seconds, original grant remaining minus two seconds), including startup.
There is no URL, executable, source or destination path in child arguments.
The fixed package configuration opens only the existing non-exportable channel
key for public proof verification, never the corporate code-signing private key.

A refusal-only entry filter first compares the current PID and process start
ticks with the bounded record in the fixed private journal root, under native
file pins. A different process is rejected before key opening, AD-module import
or rebuilding the original authority chain. Matching this local record grants
no permission: the complete key/receipt/consumption/launch/event/identity chain
above is still validated before every observation or filesystem effect. The
real signed replay fixture requires exit20 at this entry identity phase within
the existing eight-second process check; a timeout is still a test failure.

Before the engine, the child rechecks current nonadmin service identity,
signatures/content, AD/PDC/GPO scope, original ownership/tree/outside baseline and
five-second live freshness against the original offer and consumption witness.
It passes the **unchanged** server expiry to the existing bounded native rollback
engine. That engine checks UTC and monotonic time around every handle deletion,
flushes a non-replayable start record, and deletes only the exact owned tree.
No AD/GPO settings, links, ACLs, existing client data or package script are executed.

The child validates the actual engine start/final records and stores a strict
completion record tied to launch, registered process, intent, receipt and live
witness. The parent checks actual process identity, exact stdout/file equality,
native journal hashes and an independent complete GPO baseline observation at the
original verified PDC/path. Only then does it flush a parent observation. Parent
baseline reading is not a second independent AD discovery or a hard SMB timeout.

Any missing/altered completion, timeout, result loss, foreign post-child data or
uncertain observation freezes **requires_review / unconfirmed**, even if all
owned files were actually deleted. There is no automatic continuation, promotion,
cleanup, new deadline or unlock. The original stage GPO lock remains intact.
A launched/frozen operation cannot launch again; a new direct child cannot reuse
the closed gate. In-flight SMB work can finish after process/deadline expiry;
this is not atomic rollback or guaranteed I/O cancellation/zero effects.

Role-specific immutable outbox/body timestamps survive module reload and ACK
loss. Only the observed chain can produce `rolled_back`, tied to the actual
rollback journal and the **original removed tree** hash. Review takes precedence
over an uncertain observation. Reporting uses the existing pinned normal TLS,
strict RSA proof and exact ACK checks; three durable attempts per job, one per
call, may resend the unchanged RESULT body with a fresh proof. It cannot reclaim,
consume again, refresh AD observations, delete again or renew a grant. Stage and
rollback records/outboxes are not interchangeable.

## Disposable validation

The dedicated hosted Windows fixture uses real CNG/TLS/SQLite and signed child
processes over real SMB/NTFS. It runs nine original stage/accepted RESULTs and
separate real core review/create/POLL/CLAIM/rollback/RESULT chains. Positive
AD/content/service-identity observations and initial stage queues remain explicit
fixture substitutes. This is not customer gMSA/AD/domain-SYSVOL acceptance.

Cases: success, lost accepted ACK, live PDC drift, missing native completion after
actual deletion, malformed engine result, foreign post-child baseline drift,
launch-flush failure, wrong registered PID, and bounded child timeout. Only
fixture-owned signed copies contain fault hooks. The overall multi-case test
timeout is longer; production grant/reader/child/native limits are unchanged.

Pending: durable full rollback POLL lifecycle/permanent worker; refusal reporting,
idle/history/retention; reboot/lost-result/partial-journal reconciliation and
separately approved unlock; backup projection/off-host boot restore; controlled
signed delivery and real service identity, AD/SYSVOL, latency and endpoint
acceptance; GPO activation, single account, user EAP-TLS and 500/1000 scale.

