# User Windows client and distribution package (A03/A04 partial delivery)

This is a separate CurrentUser client; the machine client and its SYSTEM task
are unchanged. Each profile installs in the signed-in user's LocalAppData under
AuthWire/UserEnrollment/<profile UUID>. Per-user ACLs, SID/profile-bound state,
path/reparse checks and a per-directory exclusive file lease isolate its work.

- Requests use the existing user-only Kerberos acceptor. The SSPI client requests
  Kerberos (not Negotiate/NTLM), mutual authentication, replay/sequence detection
  and MICs over every exact API path and JSON message. HTTPS validates both the
  Windows chain/name and pinned SHA256 server certificate. No password is stored.
- certreq uses -user, MachineKeySet=FALSE and a non-exportable CurrentUser CNG
  key with a unique profile-prefixed name. Key scope/exportability, public key,
  leaf constraints/clientAuth chain, issuer/root pins and returned serial/kind
  are checked before the CurrentUser certificate is accepted.
- A pending key intent is saved before CSR creation. If creation was interrupted,
  UseExistingKeySet recovers the same native key; committed/lost issuance keeps
  its CSR/key and retries idempotently. An expired pending issuance is archived
  before a new key is attempted; it is not blindly deleted. Installation receipts
  and local installed state are separate from issuance.
- Predecessor leaf/key cleanup requires a client-owned container prefix,
  thumbprint/public-key binding and a passed 24-hour local grace. Current
  key/thumbprint/hash are explicitly excluded. Carry all predecessors across
  multiple renewals. Expired pending archive keys are retained for diagnosis.
- A user/SID/profile-specific task uses InteractiveToken and LeastPrivilege,
  AllSigned, logon plus persistent 5-minute daily repetition and IgnoreNew. It
  uses no password, SYSTEM, S4U or elevated execution. Logoff means no user job.
  Five-minute checks honor a persisted exponential 10-minute to 12-hour retry
  deadline; no fractional-deadline one-shot retry task is created. Healthy
  receipt checks are limited to once per six hours; logon also runs cleanup.

The authorized /api/user-admin/package download contains both user scripts and
public CA/TLS assets/config, never a private key/PFX. Asset hashes are embedded in
BOTH scripts before the operator signs them with the same enterprise publisher.
The signed installer validates the package and copies it to the private user
folder, installs only CurrentUser trust and registers its own user task. The
launcher verifies signatures/assets on every invocation. Initial trust of the
enterprise signing publisher is still the customer's approved GPO prerequisite.

Deploy Install-AuthWire-User.ps1 through USER Configuration logon scripts with
AllSigned, not Computer startup/SYSTEM. Creating/linking the GPO, user-profile
panel controls and 802.1X NIC/WLAN profile distribution remain separate A04 work.
Never distribute a shared user certificate or private key. The server's profile
membership gate controls enrollment/renewal; network policy/revocation separately
controls access. A disabled enrollment profile does not itself revoke a leaf.

Technical acceptance uses disposable native Windows CurrentUser CNG/certreq,
signed packages and an actual limited interactive task. The production client's
main function is also exercised with only Kerberos/HTTP transport substituted by
a guarded synthetic-directory issuer. Native MIT KDC/user HTTPS tests separately
cover the real server authentication boundary. This combination does not claim
real Windows AD logon, deployed GPO, user wired/Wi-Fi/VLAN or computer/user switch
acceptance. Those remain field gates. No customer endpoint or live appliance is
changed by the development tests; A03/A04 are not closed as a whole.

Microsoft API references:
- https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/certreq_1
- https://learn.microsoft.com/en-us/windows/win32/taskschd/taskschedulerschema-logontype-principaltype-element
- https://learn.microsoft.com/en-us/windows/win32/taskschd/taskschedulerschema-repetition-triggerbasetype-element
