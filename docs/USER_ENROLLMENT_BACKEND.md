# User certificate enrollment backend (A03 technical foundation)

The user flow is separate from machine enrollment. It does not prove two
identities at once or change an existing wired/WLAN profile. A03 is not fully
accepted: there is no deployed Windows CurrentUser client/package yet and no
real user EAP-TLS wired/Wi-Fi pilot. A04 panel/GPO automation remains open.

## Trust and opt-in scope

- The existing HTTP SPN/keytab and HTTPS endpoint are used. The new user-only
  GSSAPI acceptor rejects machine accounts, SPNs and other realms. The existing
  machine acceptor still rejects user accounts. Their session stores are separate.
- Kerberos mutual authentication, replay/sequence detection and a MIC over the
  exact API path plus JSON bytes protect every application request and response.
  No user password, caller-supplied account GUID/SID, remote-user header, NTLM
  or panel session authorizes a user enrollment request.
- First supported principal form is samAccountName@configured-domain, ASCII
  SAM up to 20 characters. Alternate UPN suffixes/enterprise aliases, cross-forest
  enrollment and service accounts are not claimed as supported.
- A certificates.authority administrator explicitly creates and enables a user
  profile with its own AD group SID and renewal times. No user profile is seeded.
  This is an enrollment profile, not a new AuthWire local access group.
- The existing unlocked issuing key is reused; the root key is not unlocked.
  Machine and user issuance share the bounded worker gate and database writer
  lock. No live signer/profile setting is changed by the source tests.

## Issuance, renewal and revocation

The LDAP connector reads the verified principal's exact SAM, rejects ambiguous
or foreign results and resolves its immutable GUID/SID, account state and fresh
tokenGroups. The user password is never sent or captured. The challenge contains
that binding, profile version, CSR digest and nonce. Issuance repeats the AD
check; deletion/recreation between challenge and issuance cannot inherit the key.

Only a signed CSR and a proof from its private key can obtain a clientAuth-only
certificate bound to kind=user. The issuer generates the subject. Global CSR/key
uniqueness prevents reuse across user and machine flows. Repeating the same valid
CSR after a lost response returns the original issuance, including concurrent
requests and a service restart. It does not produce a second certificate.

An installation receipt proves possession of the issued private key, checks the
current AD identity/profile and records installed separately from issued. Renewal
requires a new key and a due date (or authorized renew-now). Previous installed
certificates enter the existing retirement ledger only after the replacement's
receipt, with a grace bounded by 24 hours/certificate expiry. The registry rejects
a passed retirement deadline even before CRL maintenance. Existing maintenance
revokes the old leaf and refreshes the signed CRL; user retirement has a user audit
name. A pre-existing ordinary revoke also blocks result reuse.

## HTTP and storage

- /api/user/session, /challenge, /issue, /receipt: HTTPS, correct Host and no
  browser Origin; user Kerberos plus per-message integrity, not panel cookies.
- /api/user-admin/status: certificates.authority read permission.
- /api/user-admin/profile and /renew-now: existing panel session, Origin/CSRF,
  certificates.authority write permission and HTTPS.
- No user unlock/lock or machine package download alias is exposed. Shared
  signer controls remain under the existing authorized administrator path.
- New tables are user_enrollment_profiles, user_enrollment_challenges,
  user_enrollment_issuances and user_enrollment_rate. They are lazy-created with
  the user service. Profiles/issuances are business state; short-lived challenges
  and rate rows are volatile for backup consistency. All tables remain in the
  SQLite online backup. Restore checks recognize a complete optional user schema.
- The status response explicitly reports windows_client_available=false and
  endpoint_acceptance_pending=true; backend readiness is not endpoint acceptance.

## Deployment/remaining work

This source milestone is not yet applied to the customer's appliance. Any later
live update must preserve machine policy/certificates/Windows/GPO/native module,
install the compatible scheduled-backup worker before user activity, check the
optional user schema and demonstrate recovery. Daily backups continue; no new
full backup or live state mutation is needed for these development tests.

Next: a signed CurrentUser Windows client with user-only non-exportable CNG key,
per-user protected state, installation receipt, renewal/retry/recovery and old-key
cleanup; panel user-profile management; constrained GPO user distribution with
signing and rollback; then separate real user wired/Wi-Fi/VLAN and negative tests.
The Windows user/computer transition must be validated separately from machine
EAP-TLS. It is not simultaneous identity chaining (TEAP).
