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

## Observed result

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

## Acceptance boundary

This proves protocol reception and native detail logging in an isolated
FreeRADIUS instance. It does not prove AuthWire application persistence,
deduplication, access-decision/session correlation, retention, archive,
cleanup, UI/CSV visibility, or operation with the real pilot NAS.

The repeated Interim-Update produced two identical detail records. Therefore
single-processing/idempotent accounting on retransmission is still open; the
native detail receiver itself does not satisfy that criterion. No B11
completion point is claimed.

## Next B11 work

Implement or identify the AuthWire accounting ingestion path in a source-only
change, then validate deduplication and session lifecycle in an isolated
application/database fixture. Preserve the current live NAS and RADIUS
configuration. After source acceptance, use a separately approved real pilot
NAS session to verify Start/Interim/Stop end to end, followed by session
correlation and retention/archive/cleanup acceptance.
