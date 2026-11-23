# Refused rollback: append-only local retirement

This explicit AllSigned maintenance closes only an already accepted, expired,
preauthorization-refused rollback. It does not erase or reopen the old job,
renew an offer/grant, remove the original reservation/GPO lock, or touch SYSVOL.

The reader revalidates the complete signed poll/offer, strict absence of claim
or execution history, frozen no-authorization/no-effects result, server ACK,
completion, exact original stage chain, staged tree and outside baseline.
The operator reviews a separately signed, 60-second, binding/job/stage-specific
retirement proof. Completion additionally requires the exact saved-result
acknowledgement to be rechecked through a current privileged product session
with Origin/CSRF and both existing permissions. That server acknowledgement
confirms the original result; it is not server rollback or deletion authority.
The three endpoint capability flags may be enabled on the isolated pilot.
They are checked as consistent boolean metadata, never accepted as a grant;
the acknowledgement still has the exact decision/job and cannot apply a GPO.
The explicit local acknowledgement is `retire_refused_rollback_without_replay`.

Completion appends only `rollback-retirement-review.json` and
`rollback-retirement-complete.json` in the refused job directory. Both records
are immutable CreateNew writes; the proof and completion use distinct CNG
signature domains. A partial or conflicting closure remains blocked. The
original refusal/outbox, timestamps, reservation and GPO lock remain unchanged.

Before saving a fresh independently approved rollback offer, every previous
rollback for that same original stage must have a valid signed retirement.
The first root reservation remains as its immutable anchor. A successor adds
`rollback-reservation.json` inside its own new job directory. This preserves
all old readers and prevents a third job from bypassing an outstanding second
reservation. Lifecycle continuation and archiving recognize only a fully
validated retirement; the original outcome still reads
`refused_before_authorization`.

The subsequent rollback still needs a new job, current AD/GPO/ACL/content/tree
preflight, separate single-use claim/grant, original time bounds, and the
existing independently observed baseline restoration. General HTTP write
creation and GPO activation remain gated. No old stage is repeated.

Focused native check: `tools/staging_rollback_retirement_windows_check.ps1`.
It uses real non-exportable CNG keys, NTFS handles/CreateNew records and
reservation succession. Original stage-chain inputs and privileged HTTPS are
explicit fixture seams; real pilot validation is recorded separately. The
9-check live-window and 22-check retirement native acceptances are distinct;
neither is a new EAP, renewal, reboot or successful-stage replay.
