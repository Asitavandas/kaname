# Write-ledger backup comparison

Source-only extension of the existing scheduled Linux backup worker. A valid
`windows_staging_write_jobs` envelope now uses the same comparison-only POLL
projection as the read queues, with the write ledger's 1,048,576-character bound.
This covers stage and separately authorized rollback in their shared ledger.

The strict envelope has exactly `format`, `jobs`, `polls`, and `last_poll`.
Only format integer 1 is accepted. POLL entries have exactly `id` and `until`,
with a lower-case 64-hex ID, positive bounded integer expiry, no duplicates and
at most 128 entries. A non-null write `last_poll` has exactly a valid scope hash,
positive bounded integer time, and canonical nonzero release UUID. Unknown
envelopes, malformed transport, duplicate JSON keys, non-finite numbers and
oversized payloads keep their original raw comparison value. Duplicate POLL IDs
are now also rejected by the comparison projection for the older queues.

The projected comparison retains `format` and the **entire ordered jobs list**.
No job field, nested target, stage receipt, actor, approval, lease, authorization,
claim, outcome, hash or unknown future job field is filtered. Jobs are opaque
durable comparison data; the backup worker does not authorize them or replace
the write engine's semantic validation. A new/removed job or a changed job field
still changes the business-state fingerprint. The durable `requires_review`
barrier remains protected.

This projection is used only by the existing before/copy/after business-state
comparison. SQLite backup still copies the original complete database row,
including POLL replay IDs, expiries and `last_poll`; archive verification still
checks the copied bytes. The source database is opened read-only by the backup
worker. A copied replay ledger is evidence, not permission to resume a write.

## Retention and delivery boundary

No Windows lifecycle record, stage origin, engine record or GPO lock is pruned,
renumbered or reset. The existing 64-cycle maintenance stop remains. Existing
Linux archive retention remains the same (14 successful managed backups by
default); it is distinct from Windows write-journal retention. This change
does not back up the Windows journal through the Linux appliance archive.

Pending before continuous worker delivery: governed Windows idle/history
retention and backup/restore policy, preauthorization refusal reporting, partial
record reconciliation, separately approved unlock, active scheduler/SCM wiring,
controlled signed source installation, actual reboot, off-host boot restore,
and real gMSA/AD/domain-SYSVOL/endpoint/latency acceptance. New source bytes do
not update the already installed backup worker automatically. Historical pinned
delivery scripts remain frozen; no new privileged delivery is enabled here.
The dev.44 backup worker is kept as an exact historical test fixture with the
original delivery SHA-256. Its installer tests verify that frozen bytes still
match and that the historical installer rejects the new current worker. They
do not require today's source to have identical normalization to an old release.

## Verification

`tests.test_staging_write_backup` uses real RSA proofs and the existing SQLite
write engine for idle polls, stage create/lease/claim/result, and separate
rollback create/lease/claim/result. It checks full snapshot row equality,
retained replay metadata, actual live replay rejection, field-by-field job
removal sensitivity, nested receipt/target/result changes, and strict fallback
for malformed transport. Opaque-data unit cases are not authorization fixtures.
Existing backup churn tests now include the write ledger in actual temporary
archive capture and ensure durable changes still refuse publication.

The backup workflow runs these suites on hosted Linux and checks that the new
Linux-only test module can be discovered and skipped on hosted Windows. These
are disposable fixture checks, not customer backup, restore or filesystem
acceptance evidence.
