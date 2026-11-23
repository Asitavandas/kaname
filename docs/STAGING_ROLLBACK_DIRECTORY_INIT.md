# Cold directory report initialization before live rollback observations

The isolated pilot's fixed AllSigned/gMSA read-only diagnostic reproduced
ROLLBACK_PREFLIGHT_EXPIRED with 4347ms actual observation time: the recorded
integer Unix start and current time differed by5seconds. Its unchanged native
parent budget was15000ms; it exited20 after12246ms without timeout. Historical
offer inputs were read at their original receipt only, the output uses a
separate diagnostic format with expires_at0 and can_delete=false, and no job,
grant, stage, preview, result or journal was replayed or changed.

A separate command profile found Get-GPOReport's first call2203ms and next13ms.
This identifies cold report initialization inside the live window as a
reproducible latency source. The old production wrapper retained only a
generic failure, so its exact original inner error cannot be recovered from
that wrapper alone; the reproduced condition is recorded separately.

Initialize-AuthWireRollbackDirectoryReader pays this cold read-only report
initialization cost inside the original outer budget, before checked_at.
It verifies current service identity, domain/SID and fixed PDC/GPO scope, reads
one bounded report, and discards it. It returns no eligibility, cached report,
directory digest or observation timestamp. Both following full AD/GPO/ACL
observations still execute and agree under held native content/tree pins.
The original checked_at+5, actual stopwatch5second guard, outer15second guard,
and offer/grant deadlines are unchanged. A slow initialization can still fail
closed under the original outer budget. GPO links/settings are never applied.

The focused native check has13checks, including5200ms cold preparation,
two subsequent fresh observations, changed live scope rejection, and slow
live observation expiry. Identity/content/AD are explicit fixture seams;
NTFS handles and clocks are native. Actual signed field acceptance and package
delivery are separate checkpoints. Prior retirement/state/archival gates and
macro counts are unaffected.
