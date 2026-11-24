# Intent-bearing rollback retirement without replay

This gate closes only a distinct rollback whose one-use grant and filesystem
intent were recorded, whose child never entered, and whose original immutable
`requires_review / OUTCOME_UNKNOWN / filesystem_effects=unconfirmed` result was
already accepted by the server and completed in the durable lifecycle.
It does not convert that historical result to `rolled_back` or `none`.
An unchanged tree observed later cannot prove that no transient effect occurred.

The refused-before-authorization retirement is deliberately not used. The new
review and completion use separate CNG signature domains. Inputs must include
the existing CNG-signed `AuthWireRollbackReadOnlyObservationV1`; it is verified
without rewriting its timestamp, release, original signature or old evidence.
Current binding and original release/job/intent/stage/operation, hashes, expiry,
no-entry markers, dead child identity, tree rows, staged digest and outside
baseline must agree. All original authority/result/ACK/completion readers still
perform their historical checks at the original recorded times.

`Get-AuthWireConsumedRollbackRetirementReview` reads the latest active rollback,
holds its original files, verifies the full consumed-intent chain and signed
observation, and compares the actual current staged tree and outside inventory.
Its distinct signed review expires after 60 seconds.
`Complete-AuthWireConsumedRollbackRetirement` takes that exact review and the
explicit local acknowledgement `retire_consumed_rollback_preserve_unknown_outcome`.
Under the cycle, job and store locks it rechecks everything, confirms the exact
saved server result through the existing privileged Origin/CSRF endpoint, then
checks child/marker/tree/outside state again while staged files remain pinned.
The server acknowledgement confirms saved evidence; it is never delete authority.

Only two CreateNew records are appended in the old rollback job:
`rollback-consumed-retirement-review.json` and
`rollback-consumed-retirement-complete.json`. Original job bytes, uncertain
result and accepted ACK, root/per-job reservations, original stage and GPO lock
are retained. Missing, partial, conflicting, stale, tampered or replayed closure
stays blocked. Historical validation later checks the signed frozen originals;
it does not turn the old observation into a current grant.

The lifecycle may pass this exact validated retirement. A successor still needs
a new independently approved rollback job, current full AD/GPO/ACL/content/tree
preflight, distinct single-use grant and unchanged original execution deadlines.
Every rollback predecessor for that original stage must be validly retired; a
third job cannot skip an unresolved second job. No automatic new write is made
by review or completion. General GPO activation remains disabled.

Archiving this new consumed retirement is intentionally still blocked by the
existing archive eligibility gate. Its archived acceptance and matching external
restore require their own evidence. This change does not claim field rollback
success, three-device effective delivery, or completion of G01 (still 2/5).

Focused native check: `tools/staging_consumed_rollback_retirement_windows_check.ps1`.
It uses real non-exportable CNG keys, distinct signature domains, NTFS pins,
CreateNew journals, child-liveness checks, staged tree digests and outside
inventory. Historical POLL/CLAIM/origin protocol bodies and privileged HTTPS are
explicit fixture seams; this is not a domain GPO acceptance test. Existing
native authorization/execution workflows continue to cover those protocol bodies.
