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
exercise and remained unchanged. Seven authenticated responses and seven
detail records were observed. Start, Interim-Update, Stop, cross-NAS session
separation, Stop without Start, Interim after Stop, and rejection of unknown
NAS/invalid secret were covered.

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
`--accounting-events`; only that flag prepares the private store, adds a
loopback-or-configured Accounting listener, and generates the native callback.
The callback acknowledges only after a durable insert or recognized retry.
Validation/storage failures return failure so the NAS can retry. The live
service was not restarted and the feature flag was not enabled live.

## Verification

On the pilot Linux host, nine focused tests passed without skips against
the installed FreeRADIUS binary and temporary fixture state. The loopback
listener sent authenticated Accounting responses for Start, Interim-Update
and Stop. SQLite contained one event for the exact duplicate, separate
sessions for the two NAS sources, and an orphan Stop with no invented
session. While an independent SQLite write transaction held the database
lock, no Accounting response or event was produced. The same packet was
acknowledged and persisted once after releasing the lock.

The generated configuration now supplies packet metadata and the state
directory through FreeRADIUS control attributes. The callback consumes the
native attribute dictionary and reads those values from its control list.
The test uses the repository's existing native listener readiness check.

## Remaining acceptance

The panel now lists NAS-reported Accounting sessions under Access records.
The read-only session API uses the audit-events permission and bounded
pagination. Access decision correlation, retention/archive/cleanup and the
real pilot NAS test remain open. This loopback test did not deploy or
activate Accounting in the live service. No B11 completion point is claimed.
