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
pagination. The runtime optionally includes an opaque RADIUS Class value in a committed
Access-Accept when both histories are enabled. The session list resolves the
Class echoed on Accounting Start to a prior accept from the same NAS. Old
sessions and absent, ambiguous or unrecognized echoes have no linked decision.
The panel shows the matched decision time, policy and VLAN. The native lab
exercises the Class round trip on loopback. Retention/archive/cleanup and the
real pilot NAS test remain open. This loopback test did not deploy or
activate Accounting in the live service. No B11 completion point is claimed.

## Accounting retention

From the AuthWire source directory, run the maintenance command as the
service account. Set the retention period in days according to the site's
policy. Example preview for 90 days:

```bash
python -m kaname.radius_accounting_maintenance --keep-days 90
```

Use the same arguments with `--apply --archive-dir /path/to/private/archive`
to archive and remove eligible records. The archive directory must exist,
be private to the service account, and be outside application state.
Each run that removes records saves a complete pre-cleanup Accounting SQLite
snapshot, verifies its integrity, and returns its SHA-256. A snapshot can
contain active sessions and other records outside the cleanup window, so it
has the same sensitivity as the source database. Archive lifetime and external
backup are managed by the operator.

Cleanup preserves sessions still awaiting Stop and their events. It removes
closed sessions older than the cutoff and old orphan events. Exact packet retry
recognition is limited to records still in the active database. Freed SQLite
pages can be reused for new records. Run the command during low traffic because
the archive and cleanup hold a SQLite write reservation. There is no default
site retention period or scheduled deletion.


## Accounting runtime diagnostics

The Accounting session API includes the latest validated runtime snapshot,
and the access history panel shows persisted, duplicate and failed callback
counts and the last known error. Counters are process-local observations
sampled as Accounting requests arrive. They reset when RADIUS restarts and do
not measure packets discarded before the callback. Failure to publish the
snapshot does not change the Accounting response or the persistence decision.
