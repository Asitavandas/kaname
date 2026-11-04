# Durable stage/rollback lifecycle step and result-only recovery

Source-only trusted local SDK. It is not registered in the permanent service,
package, operator panel or production peer routes. This is a durable **step** for
the future scheduler, not a delivered perpetual idle loop. Retention, refusal
reporting, governed reconciliation/unlock and customer delivery remain gates.

## Records and dispatch

The installer-provisioned fixed private write root is mandatory. A child directory
`write-lifecycle` contains an immutable binding-scoped baseline and sequential
six-digit cycle directories. Initialization accepts an empty root or exactly one
fully observed/accepted legacy stage chain; unknown, partial, idle-only, review
or unreferenced history is not imported or reset. The original stage, engine,
GPO lock and accepted result remain intact. Older release evidence can be read
with its original release under the same binding/key generation; no binding
migration or renewed permission is inferred.

Before signing, flush poll-started; before HTTP, flush proof and one-send marker.
The stored POLL validator enforces the same nine binding fields, current service
identity, named machine non-exportable signing-only channel key and exact RSA
wire envelope. Historical reads use actual recorded send/receive times, never
fresh issuance. The typed TLS reply must match request/scope and may contain
only the existing stage or rollback operation or the strict no-job schema.
Its immutable response is flushed before the durable dispatch marker and SDK
calls. No path or command is accepted from the reply.

Fresh dispatch calls the existing stage or separate rollback preflight/CLAIM/
receipt/consumption/bounded execution/RESULT chain. Original grants, five-second
live freshness, reader/child budgets, pinned TLS and key/trust/AD guards are not
extended or bypassed. The global connector cycle mutex serializes steps.

## Restart classification

- Missing/partial start/proof/send/response, invalid signature/link, unknown root
  data, duplicate request/job history or sequence gaps stop for reconciliation.
  Lost POLL/CLAIM does not create a new poll, claim, lease, deadline or execution.
- A saved non-idle response without dispatch marker does not start dispatch after
  restart. A dispatch marker with missing authorization receipt stays uncertain.
- A valid saved receipt permits only existing result reporting. No recovery path
  invokes POLL, CLAIM, consumption, current AD/context readers or executors.
  Missing/unobserved execution may become only unconfirmed review, even when
  the grant was known and the controller probably had not written yet.
- Frozen RESULT/ACK recovery preserves exact outcome, body and completion time,
  uses existing durable attempt bounds, and checks role-specific accepted ACK.
  Lost cycle completion after accepted ACK can reconstruct bookkeeping only.
- Accepted `requires_review` is a durable barrier against later polling.
  Success/no-job completion allows a **later** step to poll again; that later
  poll is never appended in the same recovery call.

Root names, job/engine record names, original-stage references and rollback
markers must be explained by the baseline and saved cycles. Unknown data is
kept, not deleted. A missing/changed header or generation change cannot adopt
history or choose a new empty recovery root. The immutable journal is capped at
**64 cycles**; a full journal returns maintenance-required before a new signature
or request. This is a source storage limit, not a device quota. There is no
automatic pruning, lock deletion, unlock, background retry or reboot repair API.
It must be paired with approved retention/reconciliation before unattended
worker delivery. Existing per-job 512-target and root/job bounds remain intact.

## Disposable verification and remaining work

The new hosted Windows fixture reuses actual CNG/TLS/SQLite/signed child/SMB SDKs.
It exercises common stage dispatch, separate rollback, exact lost-ACK recovery,
lost POLL, changed reply, lost issued grant, repeated idle polls and a real saved
grant at a simulated controller-loss record boundary. Module reload and controlled
bookkeeping-boundary reconstruction are **not an actual machine reboot**.
Positive AD/content/service-identity observations and initial stage queues are
fixture substitutes. The 64-cycle capacity records after two real idle polls
are explicitly synthetic no-job metadata with independent real CNG signatures;
no server requests or write grants are synthesized for that capacity check.

Pending: active scheduler/SCM registration, safe idle/history retention and backup
projection, preauthorization refusal reporting, governed partial/unknown-state
reconciliation and unlock, actual reboot/off-host boot restore, controlled signed
delivery and real gMSA/AD/domain-SYSVOL/endpoint/latency acceptance. This source
step is not product-wide completion or operator acceptance.
