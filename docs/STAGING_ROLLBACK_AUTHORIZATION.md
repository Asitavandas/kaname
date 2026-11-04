# Separate rollback authorization and one-use intent

This source-only SDK follows the read-only origin guard. It is not loaded by the
permanent package/worker, exposes no production create/peer route, and never calls
the rollback/delete engine. `can_delete` and `can_apply_gpo` stay false. A later
executor must independently validate the consumed intent, live tree and deadline;
this module's returned hash or stage operation ID is not execution authority.

## Local sequence

1. A trusted caller supplies a strict, current rollback offer from a **separate**
   operator approval. The original accepted stage RESULT and ACK, chain, binding,
   preview lineage, current original-stage gate and GPO lock must match.
2. Save in the existing fixed private write journal root. Reserve the original
   stage with `rollback-stage-<stage-job>.json` using CreateNew/Flush(true) **before**
   creating the rollback job directory. Neither a new job ID nor partial local
   setup bypasses that reservation. The original GPO lock is not overwritten.
3. A fixed AllSigned System32 WinPS5.1 reader opens only the existing channel key
   to verify public proof. It does not sign, export, create/repair a key, modify
   its ACL or open the corporate code-signing private key. Strict package config
   and expected key ACL are checked. AD/content/nonadmin service identity,
   original chain and current ownership/tree/outside baseline are rechecked.
   Whole reader work is limited to 15 seconds; five-second live freshness starts
   **before** live observation. The original authority/ACK chain is verified under
   native file pins and the original-stage mutex before that live clock starts;
   those exact pins remain held through both live observations. Current gate,
   review and rollback-marker exclusions are checked again after observation.
4. `rollback-claim-started.json` is flushed before proof construction. The existing
   wire CLAIM proof and strict RSA/key/binding validators are reused. A role-specific
   `rollback-claim-sent.json` is flushed before the existing pinned, normal-validation,
   five-second HTTPS transport. A strict matching reply becomes
   `AuthWireRollbackAuthorizationReceiptV1`. Lost reply, malformed grant, signing
   failure or receipt disk failure never automatically sign/re-send CLAIM.
5. Current receipt use is separate from historical evidence reading: expiry is
   never refreshed. The historical reader verifies the original send/proof/grant
   times and original stage chain. It is not a current permission check.
6. Under the rollback-job outcome mutex and immutable input pins, refuse any
   existing consumption/intent before another live read. Flush the one-use
   `rollback-grant-consumed.json` before the second reader. That reader is limited
   to min(8 seconds, original grant remaining minus two seconds), and still must
   satisfy the same five-second live freshness. Original binding, stage operation,
   origin chain, current PDC/directory/tree and outside baseline must match.
7. Save consumption witness and a separate `AuthWireRollbackFilesystemIntentV1`
   with the **unchanged** server deadline and false delete/activation flags. UTC
   and monotonic time surround reading and final flush. Any uncertainty after the
   marker retains the consumed grant for review; there is no retry/cleanup/unlock.

Stage readers/executors cannot interpret the role-specific rollback files as stage
authority. Historical origin reading tolerates later rollback markers only as
history; current origin/preflight still refuses review state, previous rollback
attempt or active stage gate. Same binding/key generation is mandatory; an old
release may only be read as its original historical fact.

## Isolated validation and limits

`staging_rollback_authorization_windows_check.py` reuses the disposable Windows
CNG/TLS/SQLite/SMB stage harness. Eight original stages run through real signed
child execution and accepted RESULT. Separate rollback review/create/POLL/CLAIM
use real server core and RSA proof bodies. Positive AD/content/service-identity
observations are explicitly signed fixture shims; the caller is the hosted CI
account, not the customer's gMSA. Stage queued jobs remain seeded test inputs.
Rollback POLL is direct fixture orchestration, not a durable product rollback cycle.

Cases cover success, lost issued grant, altered operation in reply, receipt-disk
failure, disk failure after consumed-marker flush, live PDC drift, expired grant,
and proof-disk failure. Assertions check no second claim, no second live reader
after consumption, original stage journals/GPO lock/SMB tree unchanged, no delete,
false execution flags, original deadline, and stage/rollback record separation.
Unsigned-reader and alternate-root refusals are included. All fault injection is
in test-owned signed copies; no fault/time/path override is added to product code.

PR130 adds the source-only bounded rollback child/parent observation/immutable
RESULT adapter; see [STAGING_ROLLBACK_EXECUTION.md](STAGING_ROLLBACK_EXECUTION.md).
This authorization component still never deletes or activates GPOs itself.
Consumption now pins all fixed rollback and original stage authority inputs
before one full validation, keeping the same pins held through live observation.
The grant deadline and five-second/15-second/eight-second limits are unchanged.

Pending: durable full rollback POLL cycle/worker; refusal reporting/reboot/lost-result and
partial-journal reconciliation; separately approved unlock/retention; strict backup
projection/off-host restore; controlled delivery and real gMSA/AD/domain SYSVOL,
latency/refusal and endpoint acceptance. An in-flight SMB operation can outlast its
deadline; the process budget is not atomic deletion or guaranteed I/O cancellation.
