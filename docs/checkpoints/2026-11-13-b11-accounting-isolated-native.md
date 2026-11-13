# B11 Accounting isolated native and source acceptance — 13 November 2026

## Prior isolated native protocol result

A temporary FreeRADIUS instance was started from the installed native RADIUS
binary under a private temporary directory. It listened on an ephemeral UDP
port bound to loopback only. It used temporary, independently generated
secrets for two test NAS entries and a temporary detail log with mode 0600.
The instance was terminated and its temporary directory removed at the end.
No live AuthWire, RADIUS, NAS, switch, policy, database, or service setting was
changed.

The production `authwire-radius.service` PID was captured before and after the
exercise and remained unchanged. The final result was seven authenticated
responses and seven detail records; Start, Interim-Update, Stop, cross-NAS
session separation, Stop without Start, Interim after Stop, and rejection of
unknown NAS/invalid secret were observed.

The repeated Interim-Update produced two identical native detail records. The
detail receiver did not provide application idempotency.

## Source-only accounting ingest

Added `kaname/radius_accounting.py`, a separate private SQLite event and
session store. It scopes sessions by NAS source IP plus Acct-Session-Id,
deduplicates packet retries by NAS source plus Request Authenticator, preserves
existing counters when a later packet omits them, records orphan Stop/Interim
events without inventing sessions, and combines octet/gigaword counters. The
parser uses server-supplied packet attributes and does not persist User-Name or
unverified identity claims.

Added `kaname/radius_accounting_observer.py` and
`tools/radius_accounting_config.py`. Runtime generation remains opt-in via
`--accounting-events`; it prepares the private store and generates the native
FreeRADIUS Accounting callback. The callback acknowledges only after a durable
insert or recognized retry. Validation/storage failures return failure so the
NAS can retry. The production service was not restarted and the feature flag
was not enabled live.

## Verification

Seven focused Accounting tests passed on the Linux host, covering:
Start/Interim/Stop persistence, deduplication, NAS scoping, orphan events,
gigaword counters, invalid input, callback acknowledgment, and storage failure.
The opt-in runtime setup/failure-isolation test passed. The generated production
FreeRADIUS configuration, with Accounting enabled, passed native `radiusd -XC`
parsing against the installed pinned runtime. CI is running separately on the
draft PR.

## Acceptance boundary and next work

No packet has yet been sent through the generated application callback into
this SQLite store under the native listener. There is no AuthWire API/UI/CSV,
access-decision/session correlation, retention/archive/cleanup acceptance, or
real pilot NAS end-to-end result. No service package was built or deployed.
No B11 completion point is claimed.

Next, extend the isolated native protocol exercise to invoke the generated
callback and read back persisted session/event rows, including a duplicate
retry and storage failure. Keep live NAS and RADIUS settings unchanged until
that source acceptance passes. Then verify a separately authorized real pilot
NAS session end to end and continue with correlation and retention/archive/cleanup.