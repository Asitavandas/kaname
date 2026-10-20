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

Candidate/native CI and controlled delivery are pending at this checkpoint.
DHCP/DNS architecture and configuration remain out of scope by customer choice.
