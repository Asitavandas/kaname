# Connector read-only probe jobs v1

This stage implements only `connector.probe`: a fixed identity/package report.
It never executes caller-supplied commands, PowerShell, paths, URLs, AD queries,
GPO operations or network-profile changes. Health, job support and GPO readiness
remain separate. Every response keeps `can_apply=false`; directory and Kerberos
readiness are unchanged.

## Operator boundary

The Windows connection page uses the existing independent `system.connectors`
permission. Its test preview is read-only. Explicit confirmation creates a job
with a client-generated UUID. A lost create reply locks further writes until a
GET finds that same UUID. No automatic POST replay or new replacement ID is used.
The server also idempotently recognizes the exact original actor/request/ID.
Another actor, changed request, stale revision/preview, revoked/demoted session,
maintenance bearer, missing CSRF, foreign Origin/Host or non-HTTPS request cannot
create a job. The administrator read lease covers the main-store commit.

The bounded ledger lives in the existing SQLite runtime_settings section
`windows_connector_probe_jobs`. No new DB schema or backup-worker change is
required. Enqueue and first completion have atomic audit/revision commits.
Polling only updates the operational nonce/lease/capability data. Read/preview
requests do not create storage. Corrupt state fails closed without repair.

V1 is a bounded pilot/test ledger: 32 retained IDs, at most four active jobs,
five-minute queued lifetime and a 90-second assignment lease. IDs are not silently
discarded and later reused. A full ledger refuses new work; production retention
and administrative archival are a later gate. A leased job is never automatically
reassigned after its lease expires. This is a read-only protocol and idempotent
result recording, **not exactly-once GPO execution**. A read-only probe may be
re-evaluated while its same lease is still active after a lost poll/reply.

## Peer protocol

Two fixed POST endpoints are added to the existing verified HTTPS peer boundary:

- `/api/connector/v1/jobs/poll`
- `/api/connector/v1/jobs/result`

Requests have exactly `frame`, `signature`, `payload`, all canonical Base64.
The UTF-8 payload is either an empty JSON object for a poll or a five-field probe
result: job_id, lease_id, intent_sha256, outcome=probe_completed, release_id.
Duplicate/unknown JSON fields, non-finite values and non-UTF-8 input are refused.
The dedicated non-exportable channel key signs an ASCII frame with a final LF:

1. AUTHWIRE-CONNECTOR-JOB-POLL-V1 or AUTHWIRE-CONNECTOR-JOB-RESULT-V1
2. The nine existing binding fields in their canonical health-frame order
3. Random request ID and independent nonce, each 32-byte lowercase hex
4. Issued and expiry Unix seconds, exactly 60 seconds apart
5. SHA256 of the decoded exact payload bytes
6. POST and the matching fixed endpoint

The job's scope digest is SHA256 over ASCII AuthWireConnectorJobBindingV1, LF,
the nine binding fields separated by LF, and final LF. Its intent digest is
SHA256 over AuthWireConnectorProbeIntentV1, LF, scope digest, LF, job UUID, LF,
connector.probe, LF. The response echoes the signed request ID. The client
requires matching scope/intent, exact read-only operation, an unexpired bounded
lease and strict flat response grammar before preparing its fixed result.

The current durable pairing/context is reloaded in the same SQLite write
transaction as each poll/result. Key rotation, revocation, TLS/domain/instance
drift therefore reject old work across processes. Poll replay hashes are durable,
expire with the signed request and have a separate 128-entry bound. A recorded
result is returned idempotently for the exact same content, including after a
server restart or lost response; conflicting content cannot replace it.

Body/response limits, source rate limiting, bounded peer concurrency, normal
certificate-chain/name/revocation validation plus leaf pin, no proxy/redirect/
cookies/default credentials and stop/crash child cleanup remain in force.

## Windows integration and rollout boundary

The reviewed probe helper reuses the existing runtime SID/host, machine KSP,
non-exportability and key-ID checks. The signed service worker polls probe jobs
only after successful health. Probe errors do not fabricate failed NAC or GPO
readiness; local status separately reports ProbeChannelVerified, ProbeJobsCompleted
and LastProbeJobId. Local status is an observation, not server authorization.

The source-only update adds the helper to reviewed builder/payload hash tables.
The existing customer service is **not overwritten** and no new account/key is
created. Old health-only clients remain compatible but do not poll jobs. A server
job may therefore wait/expire until an explicitly reviewed signed Windows delivery
is applied. Customer signed upgrade/rollback and actual gMSA job acceptance are
separate gates; neither is inferred from hosted tests or an online health channel.

Only after this read-only flow is accepted will a separately reviewed owned-GPO
inspection and explicitly bounded apply protocol be enabled. GPO linking, client
rollout, certificate/network readiness and live endpoint acceptance remain open.
