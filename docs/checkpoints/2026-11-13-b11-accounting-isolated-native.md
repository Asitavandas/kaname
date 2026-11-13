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

Nine focused unit/runtime checks ran: seven passed, one passed native config
parsing against the installed FreeRADIUS binary, and one native packet-to-DB
test was skipped because this host blocks the ptrace capability FreeRADIUS
requires to run as an isolated listener. No result is claimed for sending a
packet through the native callback into SQLite on this host. The exact skip is
environmental; the test remains in the PR for a runner that can execute it.
The overall PR CI is separate and was still running at this checkpoint.

## Acceptance boundary and next work

There is no AuthWire API/UI/CSV, access-decision/session correlation,
retention/archive/cleanup acceptance, or real pilot NAS end-to-end result. No
service package was built or deployed. No B11 completion point is claimed.

Next, obtain native callback packet-to-database readback acceptance on a
runner that permits the isolated listener, including retransmission and
storage failure. Then continue with AuthWire query/API/UI and correlation,
followed by retention/archive/cleanup. Keep live NAS and RADIUS settings
unchanged until source acceptance passes; the real pilot NAS test remains later.