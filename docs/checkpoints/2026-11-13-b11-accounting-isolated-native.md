# B11 Accounting isolated native acceptance — 13 November 2026

## Scope

A temporary FreeRADIUS instance was started from the installed native RADIUS
binary under a private temporary directory. It listened on an ephemeral UDP
port bound to loopback only. It used temporary, independently generated
secrets for two test NAS entries and a temporary detail log with mode 0600.
The instance was terminated and its temporary directory removed at the end.
No live AuthWire, RADIUS, NAS, switch, policy, database, or service setting was
changed.

The production `authwire-radius.service` PID was captured before and after the
exercise and remained unchanged.

## Observed native result

The final run returned:

```json
{
  "authenticated_responses": 7,
  "detail_records": 7,
  "distinct_nas_same_session": true,
  "identical_interim_records": 2,
  "interim_after_stop_observed": true,
  "invalid_secret_and_unknown_nas_rejected": true,
  "loopback_only": true,
  "stop_without_start_observed": true
}
```

The isolated native listener accepted and logged Start, Interim-Update, and
Stop requests. It kept the same Acct-Session-Id from two different configured
NAS addresses distinct. It also logged a Stop without a preceding Start and
an Interim-Update arriving after Stop, without creating an access-accept
decision. Invalid-secret and unknown-NAS requests received no accepted
response.

The repeated Interim-Update produced two identical detail records. The native
detail receiver does not provide the required idempotent application ingest.

## Source-only persistence step

Added `kaname/radius_accounting.py` with a separate private SQLite event and
session store. It scopes sessions by NAS source IP plus Acct-Session-Id,
deduplicates retransmissions by NAS source plus Request Authenticator, preserves
counter values when a later packet omits them, records orphan Stop/Interim
events without inventing a session, and combines octet/gigaword counters.
The parser accepts only server-supplied packet attributes and does not persist
User-Name or other unverified identity claims.

Added `tests/test_radius_accounting.py`. The focused isolated run passed all
five tests: Start/Interim/Stop persistence, retransmission deduplication,
cross-NAS separation, orphan event handling, gigaword counters, and malformed
input rejection.

## Acceptance boundary and next work

This source module is not yet connected to the production FreeRADIUS accounting
callback, service-start database initialization, AuthWire API/UI/CSV, or access
decision correlation. No service package was built or deployed. Retention,
archive, cleanup, and real pilot NAS acceptance remain open. No B11 completion
point is claimed.

Next, wire this store to an authenticated native Accounting callback and
startup preparation, then add an isolated native-to-application/database
acceptance. Keep the live NAS and RADIUS configuration unchanged until that
source path passes. Then verify one separately authorized real pilot NAS
session end to end and continue with correlation and retention/archive/cleanup.