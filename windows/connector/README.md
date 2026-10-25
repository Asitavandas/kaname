# AuthWire Windows AD bootstrap v1

This is the one-time AD preparation entry point for central deployment, not a
running connector or a GPO execution endpoint. It runs on a writable DC in the
explicitly selected domain using 64-bit Windows PowerShell 5.1. The eventual
connector can be hosted on the separately named domain computer; the current
pilot uses DC01. Domain administrator privileges are not assigned to its gMSA.

`Initialize-AuthWireWindows.ps1` defaults to **Inspect**, which changes no AD,
GPO, certificate, local policy, account, service or task. Domain, target computer
and nonempty installation GUID are mandatory; they are not hardcoded to the
pilot domain. The account name defaults to `aw-deploy`. The installation GUID
must be retained across retries and future upgrades.

Inspection reads KDS metadata without dumping key material, distinguishes zero
objects from a wrapped empty collection, and waits until the later of creation
plus ten hours and the recorded effective time. Only then does it call the native
`Test-KdsRootKey`. Multiple roots, invalid metadata, a failed configuration test
or an unexpected result shape block account preparation. No KDS key is created,
deleted, refreshed or backdated by this entry point.

Optional GPO GUID and publisher thumbprint provide read-only inventories. A
matching CurrentUser certificate with HasPrivateKey does not prove a service can
use its key. Bootstrap 1.0.1 reads EKU from the certificate's actual X.509 DER
extension using X509EnhancedKeyUsageExtension, not the Cert: provider's display
ObjectId shape (string on some Windows versions, Oid on others). Missing or
malformed EKU is reported as absent/invalid with CodeSigningEku=false. An existing GPO is inspected without being adopted as product-owned
or receiving new permissions. The cmdlets never request managed account
passwords or export private keys, PFX or keytab data.

## Account preparation

Bootstrap 1.0.3 treats an absent SPN or membership attribute ($null) and an empty
collection as zero entries. PowerShell's @($null).Count is one, which previously
produced a false settings mismatch on the real DC. Every actual SPN or group
entry remains disallowed, including malformed empty strings or null array
elements. The native fixture uses the observed absent-SPN/empty-AD-membership
shape and wrapped ADKerberosEncryptionType enum. Account settings are not changed.


Bootstrap 1.0.2 normalizes single-valued integer and Boolean AD attributes when
the AD module returns ADPropertyValueCollection instead of a scalar. Exactly
one value is required. Missing, multiple, nested, non-integral, overflowing or
wrongly typed values block preparation. AES-only, ownership, delegation and
primary-group checks retain their original required values. The Windows fixture
loads genuine AD collection types using RSAT, with all directory calls mocked.

If an earlier PrepareAccount attempt failed during post-create validation, its
creation outcome is unknown. Run the corrected version in Inspect mode with the
same installation GUID first; do not delete, recreate or change an existing
account to work around a read-back error.

After the live readiness inspection has been accepted and its wait has expired,
`-Mode PrepareAccount` creates only the named gMSA if absent. It sets AES128/256,
no trusted Kerberos delegation, and one exact computer principal allowed to
retrieve its managed password. No broad host group, SPN or group membership is
added. Its DNSHostName attribute is an account attribute, not a DNS record change.
The ordinary Group parameter set is used: the outbound-only parameter set does
not accept PrincipalsAllowedToRetrieveManagedPassword in the documented cmdlet
syntax, so these incompatible parameters are not combined.

Ownership is an installation GUID plus target computer GUID in the description,
validated together with the account type, SAM/DNS names, encryption, delegation,
password readers and lack of extra group/SPN memberships. Normal nonprivileged
primary group RIDs 513 and 515 are permitted; privileged/custom RIDs are not.
A same-name customer object is never adopted, overwritten or deleted. Description
markers are not an authentication credential; domain administrators remain the
trust boundary for this local bootstrap.

A second lookup catches intervening objects before the single create. AD naming
constraints are the final concurrency guard; this is not a forest-wide lock.
If the create response or readback is lost, re-run Inspect before any retry; do
not delete a possibly created account. A matching prior account is revalidated
and reused without any Set-ADServiceAccount repair. Drift blocks preparation.

This step does **not** install the gMSA locally, grant service/batch logon rights,
alter local or domain groups, grant GPO/OU/SYSVOL permissions, grant signing-key
access, register tasks, open a listener, configure TLS or connect to AuthWire.
These are subsequent independent gates. GmsaReadinessVerified, ConnectorInstalled
and CanApplyGpo remain false even after account creation.

For on-site delivery, verify the distributed file's pinned SHA256 before the
administrator signs it with the already trusted corporate Code Signing publisher.
Require a valid Authenticode signature before execution. Do not lower execution
policy or use Bypass. GPO-distributed endpoint scripts remain AllSigned.

## Validation

`tools/connector_bootstrap_windows_check.ps1` executes the complete entry point
under native Windows PowerShell 5.1 on a disposable hosted runner. AD, KDS, GPMC
and certificate-store calls are simulated; it verifies denied writes for wrong
domain/DC/RODC, KDS wait/failure/count, existing identities, scope drift, races
and lost receipts, plus exactly one bounded create and unchanged reruns.
Actual disposable in-memory X.509 certificates cover Code Signing, Server Auth,
missing and malformed EKU, including string/Oid display-property variants. No
certificate store is written and no customer certificate or key is used.
This is not a real AD forest, KDS replication, gMSA password retrieval, service
logon or GPO acceptance test. Live verification remains required.

Primary references:

- https://learn.microsoft.com/en-us/powershell/module/activedirectory/new-adserviceaccount
- https://learn.microsoft.com/en-us/powershell/module/kds/test-kdsrootkey
- https://learn.microsoft.com/en-us/windows-server/identity/ad-ds/manage/group-managed-service-accounts/group-managed-service-accounts/create-the-key-distribution-services-kds-root-key
- https://learn.microsoft.com/en-us/powershell/module/activedirectory/install-adserviceaccount


## Read-only local service-logon assignments

Get-AuthWireServiceRights.ps1 reads only the local LSA SeServiceLogonRight and
SeDenyServiceLogonRight assignment lists. It opens the local policy with
POLICY_VIEW_LOCAL_INFORMATION | POLICY_LOOKUP_NAMES, not write access. Every
enumeration buffer, Unicode string allocation and policy handle is released.
STATUS_NO_MORE_ENTRIES is a successful empty list; all other native errors fail
the probe. It never grants a right, modifies a GPO, creates a service, logs on
or retrieves managed passwords.

Supply the expected local computer and a validated domain account SID. Direct
SID matches do not establish effective rights through groups. ReadSucceeded
does not imply ServiceLogonVerified, which remains false. Empty secedit exports
must not be treated as proof of absent effective rights.

The native Windows CI check reads the disposable runner's actual LSA database
and verifies error propagation, host/SID guards and the absence of write APIs.
It does not test a customer DC, group-derived access or a real gMSA logon.

References:
- https://learn.microsoft.com/en-us/windows/win32/api/ntsecapi/nf-ntsecapi-lsaenumerateaccountswithuserright
- https://learn.microsoft.com/en-us/windows/win32/secauthz/account-rights-constants
