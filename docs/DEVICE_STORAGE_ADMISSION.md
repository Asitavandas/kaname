# Device enrollment storage contention — dev.27

## Observation and scope

Historical job 119851757698 failed during the four-worker, 1,000-device
synthetic-directory load fixture. The exception was SQLITE_BUSY / database is
locked in Operations._public during DeviceEnrollment._authorize, not an AD
credential rejection. Passing repetitions of unchanged code do not close it.

DeviceEnrollment previously serialized writers but let its profile, status,
challenge lookup and authorization-settings readers enter SQLite independently.
In rollback-journal mode a writer can exclude new readers. Its busy handler
does not provide application admission ordering. This patch puts those short
reads and writes behind the same service-instance lock. LDAP/Kerberos calls
remain outside the lock. The four-worker enrollment gate is unchanged.

Admission is bounded to three seconds. SQLite BUSY/LOCKED, including extended
codes, is returned as the existing DEVICE_BUSY error after the connection
context has rolled back/closed. Existing machine HTTP handling returns 429;
the signed Windows retry path already understands temporary enrollment errors.
No credential fallback, cached identity, default settings or successful
certificate response is substituted. Non-lock storage errors still propagate.

No database migration, journal-mode switch, SQLite timeout increase, worker
increase/decrease, key-validation bypass or RADIUS authorization change occurs.
This is a per-service-instance admission boundary, not a cross-process mutex.
External writers can still cause a bounded retryable busy response.

## Verification boundaries

- A controlled exclusive-writer collision with a short fixture-only SQLite
  timeout fails on the unchanged dev.26 implementation with database is locked.
  The same test passes on the candidate, waiting until the writer releases.
  The fixture deliberately exposes the class of reader/writer collision;
  it does not reconstruct the exact historical runner timing or identify
  the particular transaction that owned that historical lock.
- Regression coverage includes external lock rejection without issuance/audit
  mutation, bounded admission timeout, non-lock error propagation, rollback
  and lock release, and ensuring the live AD query holds no storage turn.
- Load fixture additionally verifies certificate, identity binding, key registry,
  issuance/receipt audit counts, SQLite integrity, foreign-key consistency and
  unchanged DELETE journal mode. Unique certificate and installed receipt
  assertions remain; fixture size and worker count are not relaxed.
- Synthetic directory load is not a live AD, 200 real Windows devices, GPO,
  switch/AP, DHCP, or real endpoint EAP-TLS acceptance.
- Independent Windows retry fixture intermittency remains a separate open
  investigation. This change does not claim that cause has been fixed.

Candidate and deployment evidence are recorded in CURRENT_STATUS.md and dated
checkpoints. No deployment is implied by this document.

Reference: https://www.sqlite.org/lockingv3.html
