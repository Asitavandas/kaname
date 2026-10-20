# Expired pending enrollment recovery — isolated candidate

20 October 2026. Installed customer release remains 0.14.0-dev.11.

## Confirmed gap

The server rejects repeated issuance requests for an expired pending CSR with
DEVICE_CERTIFICATE_EXPIRED. The old client retains pending.json and therefore
repeats the same expired request indefinitely. A fresh key and CSR already
recover on the existing server, after fresh authorization. Two isolated repeats
and a fresh-key control reproduced this without changing any system clock.

## Candidate 0.14.0-dev.12

Only an issue-stage DEVICE_CERTIFICATE_EXPIRED response archives the exact
unchanged pending.json under the existing private state directory. The next
normal retry generates a new nonexportable machine key and CSR. Other errors
keep their pending request. Archive failures retain the old request and expose
EXPIRED_PENDING_ARCHIVE_FAILED in status.json. Active certificates, existing
private keys, current installed.json, trust, policies, service commands and
RADIUS are not modified by this recovery operation. Archived request metadata
and its nonexportable CNG key are retained for diagnosis; automatic deletion
of these expired-pending archives/keys is not introduced by this change.

## Validation boundaries

- Regression: repeated expired CSR rejection, fresh-key recovery and issuance
  idempotency on the real application with synthetic AD.
- Windows native test: signed production main AST as SYSTEM, actual machine
  CNG/CSR/proof, local real issuer, chain validation, certreq installation and
  receipt. Kerberos/session transport is synthetic; no customer AD is used.
- Native TLS expiry rejection uses the existing isolated eapol_test/FreeRADIUS
  suite; fixture validity is backdated, system clocks stay unchanged.
- Native fixture skips only its temporary backoff; natural retry deadlines
  already have separate SYSTEM and VV06 field acceptance.
- A production VV06 expired-certificate field rejection is NOT claimed by
  fixture success. Current VV06 serial26e43008251ac23612b2e654a6f6a259ee234f6e
  remains untouched. Normal enrollment profiles require at least two days.

Local verification: 539 tests run, 25 skipped, no failures (514 passed); focused
26 tests passed, and a related 55-test group had one skip and no failures.

Draft PR42 head f6ddf71629f251cd40feb936cf5f24fe4f38d489. GitHub Actions
run39458558838 Windows jobs and the real RADIUS run39458558740 ended in
failure before any job steps ran; Windows log download returned BlobNotFound.
The provider annotation cannot be read with the connected GitHub capability;
its exact reason is not known. No claim that native Windows or current native
TLS tests passed, and no production delivery/merge is performed.

Candidate client SHA256bf5008d1f35b9d9514ad700b7b0c130e3dc92d002bcdb670a0b8d1fcbcae5e60.
The unchanged dev11 client is frozen for historical deployment-guard tests;
the old historical deployers still refuse this new client by design.

Next gate: inspect the Actions provider error, restore native test execution,
then fix any native-fixture failures and complete signed source/SYSVOL delivery
with protected-state checks. A real production expired-VV06 field test remains
separate; the installed pilot certificate is not made expired for this test.
DHCP/DNS architecture and configuration remain out of scope by customer choice.
