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

## Bounded local service-logon preparation

Initialize-AuthWireServiceLogon.ps1 defaults to Inspect. PrepareServiceRight
requires the same corporate-signed bootstrap 1.0.3 and a successful owned-account
readback with the expected computer, domain, installation GUID and existing SID.
It adds only SeServiceLogonRight to that SID via LsaAddAccountRights; there is no
right-name option and no production removal API. LSA account creation here means
a local policy entry, not an AD account. Existing account rights are additive and
other accounts' allow/deny assignments are retained.

Any deny-service assignment blocks PrepareServiceRight pending separate group
review. The tool does not infer group-derived effective access. Before a change,
it stores a small receipt with baseline SID lists under a uniquely named
ProgramData directory accessible only to SYSTEM and Administrators. It rechecks
for policy drift before the add, verifies the target and preserved assignments
afterwards, and records the result. If interrupted or verification fails, use the
receipt and Inspect to determine the result; never replace a whole DC rights
list. A repeated prepare is a no-op if the direct assignment already exists.

This grants no GPO/SYSVOL/signing-key access, creates no service and does not prove
service logon or persistence across future policy refreshes. Those gates remain
false. The native CI fixture writes only to a unique unused SID on a disposable
runner, tests guards/idempotence/preservation and removes only its two fixture
rights in finally. No customer account or AD forest is used.

Reference: https://learn.microsoft.com/en-us/windows/win32/api/ntsecapi/nf-ntsecapi-lsaaddaccountrights

## Actual service-logon probe

Test-AuthWireServiceLogon.ps1 defaults to Inspect. RunProbe reuses the signed
bootstrap and service-right preparation tool in Inspect mode, requires local
Test-ADServiceAccount success, and resolves the validated SID to its account.
It compiles a minimal .NET ServiceBase executable into a unique protected
ProgramData directory and signs it with the existing corporate publisher.
Only Administrators/SYSTEM can write the executable; the gMSA receives read/
execute there and modify access only to the separate result directory.

The native SCM controller creates a new demand-start own-process service with
a GUID-bound AuthWireLogonProbe name and a NULL managed-account password. It
never opens an existing service for control. The real service writes its SID,
machine, authenticated/service-group status, process ID and nonce. Acceptance
requires a running SCM service with the same process ID plus every proof binding.
A 45-second watchdog stops the helper if the caller disappears.

Finally the wrapper stops/deletes only the service created through its retained
handle and checks actual removal. It removes the temporary executable/result
directory after service removal, retaining admin-only manifest/proof/summary
metadata. Cleanup failures are explicit and never reported as connector success.
No account/GPO/right/signing-key ACL changes, product service restarts, password
requests or exports are performed. ConnectorInstalled and CanApplyGpo stay false.

Native CI starts the signed service twice under built-in LocalService and tests
proof tampering, ACLs, collision refusal and cleanup. Its temporary self-signed
code-signing certificate and public trust entries exist only in the disposable
runner and are removed. This validates SCM/helper mechanics, not a customer's
gMSA password retrieval or logon. Live gMSA acceptance remains required.

Reference: https://learn.microsoft.com/en-us/windows/win32/api/winsvc/nf-winsvc-createservicea

## Separate managed deployment GPO preparation

Initialize-AuthWireDeploymentGpo.ps1 defaults to Inspect. It previews the
instance-bound AuthWire-Managed-Deployment name, validates the signed account
bootstrap, same-domain security scope group and native service SID type.
PrepareGpo creates only a new empty, unlinked GPO with an exact installation/
host/service/scope ownership marker. It retains administrative ownership,
changes Authenticated Users to read, gives only the selected group apply and
gives only the owned gMSA GpoEdit. No GPO link or settings are written.

The existing pilot trust GPO is protected by a before/after report/delegation/
root-ACL fingerprint (excluding generated report ReadTime). It is not delegated
or adopted: it contains trust anchors and stays under administrator control.
No whole-permission-list replacement is used. GpoEditDeleteModifySecurity is
never assigned to the service.

Same-name foreign objects, settings, links, ownership drift, unexpected scope or
partial preparation block automatic reuse. A complete matching preparation is
a no-op. A protected receipt records creation and each permission stage; an
interrupted create is inspected before retry and is never deleted/recreated.
GPO/SYSVOL metadata checks do not prove actual service-account writes through
AD/SMB; ServiceWriteAccessVerified and CanApplyGpo remain false.

Version 1.0.1 verifies the ownership comment through a fresh GUID-bound GPMC
Get-GPO Description read. LDAP groupPolicyContainer.description is not the
GPO comment and may be empty; it is not used as ownership evidence.
The GPC object class, SYSVOL path, administrative owner and absence of links
or settings remain independent mandatory checks.

ResumeGpo is an explicit recovery mode, not automatic adoption. Supply both
PreparationReceiptPath and ExpectedGpoId. The original admin/SYSTEM-protected
ProgramData receipt must bind that exact GUID, instance, marker, name and
unchanged protected-trust fingerprint. Reparse points, other writable trustees,
foreign markers, ambiguous names, links/settings and drift are refused.
Only a created_unlinked receipt with initial default delegation is resumable:
Authenticated Users apply, domain/enterprise administrators and SYSTEM admin
roles, optional Enterprise Domain Controllers read, and no prior service/scope
delegation or direct service SYSVOL access. Other default delegation shapes,
including forest-root enterprise admins in a child domain, require review.
The three original bounded permission assignments complete on the same GUID;
New-GPO is never called by ResumeGpo. Intermediate interrupted permission phases
require reinspection. A verified_unlinked matching rerun is a no-op.
Inspect with the same receipt/GUID only previews ReadyForResume and makes no writes.

Native Windows tests exercise LookupAccountSid and both user/computer trustee
mapping. The full preparation algorithm runs with AD/GPMC simulated, covering
scope boundaries, races, partial writes and protected trust preservation. This
does not claim actual GPO creation/delegation or endpoint acceptance.

References:
- https://learn.microsoft.com/en-us/powershell/module/grouppolicy/new-gpo
- https://learn.microsoft.com/en-us/powershell/module/grouppolicy/set-gppermission
- https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-lookupaccountsidw


## Actual managed-GPO write probe

Test-AuthWireGpoWrite.ps1 defaults to Inspect and requires the corporate-signed
bootstrap, service-right, logon-probe and deployment-GPO tools. The receipt must
already be verified_unlinked for the explicitly supplied managed GPO GUID.
The GPO must be empty, unlinked, correctly owned/delegated and its LDAP
description initially empty. Inspection performs no writes or service creation.

RunProbe creates a signed short-lived own-process service under the validated
gMSA with a NULL password, using the already tested owned SCM controller.
The service authenticates to the fixed DC via Kerberos LDAP with signing, sealing
and no referral following. It adds a nonce-bound value only to the managed GPC's
LDAP description, reads it back and deletes only that exact value in finally.
This is independent of GPMC Gpo.Description; no GPO comment, settings, version,
links or delegation are written. The GPC modification timestamp can advance.
Concurrent customer values are retained and explicitly fail preservation.

The service opens a GUID/nonce-bound temporary file at that GPO's DC-pinned
SYSVOL UNC root with CreateNew, writes/flushes/reads it and uses DeleteOnClose
for handle-owned removal, including process exit. No existing file is replaced.
A fixed admin-controlled configuration binds host, SID, instance, managed and
protected GPO IDs. Runtime evidence must bind actual service SID, SCM PID, host
and nonce; the controller independently checks target business/file/ACL state
and protected trust fingerprints after service cleanup. It never repairs or
removes arbitrary LDAP values or files as Administrator. A crash with unknown
LDAP outcome is explicit and retains a nonce/config manifest for review.

Temporary service, binary, config and result data are removed; admin-only
summary/manifest/proof remain. ServiceWriteAccessVerified requires actual write,
read, cleanup and preservation acceptance. It does not imply signing-key access,
connector installation, policy persistence or endpoint acceptance.

Version 1.0.1 fixes the target postcheck's GPMC report field name: XML uses
root ModifiedTime while the PowerShell Gpo object exposes ModificationTime.
Only direct root ReadTime/ModifiedTime are excluded from the business comparison;
CreatedTime, nested settings, versions, enabled state, links, permission rows,
root ACL, and each existing SYSVOL file/directory ACL and file content remain
covered. Raw reports and the observed timestamp values are retained separately.
An admin-only gpo-before.json baseline is written before service creation;
gpo-comparison.json stores before/after components and precise changed fields.
Missing comparison evidence fails acceptance. Earlier 1.0.0 results without
component baselines are not retroactively accepted; rerun the corrected probe
to establish preservation. Real operation success and overall postcheck
acceptance are separate results.

Native hosted Windows tests exercise the real file engine and signed SCM helper
under LocalService. Only the test-compiled helper substitutes the LDAP adapter
and UNC path with an in-memory directory and local fixture directory. Production
contains no fixture-mode switch. Customer AD/SMB/gMSA acceptance remains separate.


## Read-only service-signing readiness

Get-AuthWireSigningReadiness.ps1 has only Inspect mode. It validates the signed
owned-account bootstrap, explicit host/domain/instance/SID, then inventories the
current corporate publisher and any locally marked machine signer certificate.
Native CertGetCertificateContextProperty reads only provider metadata: CNG/CSP,
keyset flags and a hash of the container identifier. It does not acquire, use or
export the private key. HasPrivateKey/provider metadata do not establish service
access. CurrentUser and machine scope are reported independently of store name.

The tool reads enterprise enrollment-service objects and code-signing template
metadata from the forest configuration partition, including publication, EKU and
application policies, machine/user flags, export/archive/UI/subject flags, minimum
key size and raw enrollment ACEs. A shape-compatible template is not selected or
authorized: effective group enrollment, issuer policy and provider compatibility
require review. No CA template, certificate, key ACL, trust store, GPO or account
is changed; no enrollment is submitted and automated signing remains false.

The intended service signer uses a dedicated non-exportable machine key and
code-signing-only certificate. The existing administrator publisher/key and
already signed packages remain in place. Public trust for a new publisher must
be prepared before switching endpoint packages; the protected trust GPO remains
administrator controlled. This inventory does not claim that preparation or
actual gMSA signing has occurred.

Native Windows validation creates disposable user/machine CNG and legacy CSP
certificates, reads actual provider metadata and removes the fixture keys. AD/CA
discovery is simulated with genuine AD collection and ACL types; no customer key
or CA is used. Production contains no mutation mode or key-acquisition API.

References:
- https://learn.microsoft.com/en-us/windows/win32/api/wincrypt/nf-wincrypt-certgetcertificatecontextproperty
- https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-crtd/f6122d87-b999-4b92-bff8-f465e8949667
- https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-wcce/c07fc301-a7c1-4a61-ba91-142b751ad114
- https://learn.microsoft.com/en-us/windows/win32/adschema/r-certificate-enrollment

Signing readiness 1.0.1 emits no output for unrelated templates and explicitly
filters null discovery/shape records before counting. Mixed inventories and an
empty code-signing template array are valid inspections, not signing approval.
Malformed relevant signing metadata continues to fail. Native regression checks
cover mixed, all-unrelated, empty and all-null discovery plus JSON array shape.


## Separate unpublished machine code-signing template preparation

Initialize-AuthWireSigningTemplate.ps1 defaults to Inspect. It reuses the signed
readonly readiness1.0.1 and bootstrap, validates the instance/host/service SID,
exact CA and published source template, and derives an instance-specific template
and OID below the forest's registered OID prefix. It creates a new definition;
no source attributes or source enrollment permissions are copied or changed.

The plan is schema3, RSA3072/SHA256 with Microsoft Software Key Storage Provider,
code-signing-only EKU/application policy, digital-signature-only key usage, a
365-day validity/30-day renewal window, no export/archive/UI/auto-enrollment and
an AD-machine-derived DNS CN. Only the exact connector computer receives the
explicit Enroll extended right; the gMSA receives no template enrollment or
administrative grant. Authenticated Users have read only; the domain admins and
SYSTEM retain administrative control of these new objects.

PrepareTemplate atomically creates the new OID and template LDAP objects with
explicit binary protected security descriptors. Kerberos signing/sealing is
required on the fixed DC; no credentials are read or exported. A protected
ProgramData receipt records before-create and each GUID-bound stage. Source
critical attributes/ACL and the selected CA publication/ACL fingerprint are
checked before/after. Existing names/OIDs or partial setups require review;
there is no automatic adoption, repair, deletion or repeat creation.

This stage does not publish to any CA, submit a certificate request, create a
key, change key ACLs, modify trust/GPO, install the connector or deploy endpoint
packages. TemplatePublished, ServiceKeyAccessVerified and CanApplyGpo remain
false. Native Windows tests exercise genuine AD security descriptors, AD value
collections and LDAP AddRequest construction; all directory writes are simulated.
Actual forest creation/readback and subsequent CA acceptance remain required.

References:
- https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-crtd/c55ec697-be3f-4117-8316-8895e4399237
- https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-wcce/b083a3c4-f57e-4925-b3f8-3dba81dae946
- https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-crtd/1192823c-d839-4bc3-9b6b-fa8c53507ae1
- https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-adsc/db4b45f7-e57a-4ae1-9b8f-1b107b69d98c


## Managed-account machine key challenge signing

`Test-AuthWireServiceSigning.ps1` defaults to Inspect. RunProbe reuses the owned signed SCM lifecycle and null managed-account password. The worker selects only the exact machine signer thumbprint, enforces RSA3072/SoftwareKSP/machine/persistent/nonexport/signing-only properties, and signs an SID/PID/host/service/nonce-bound challenge with SHA256/PKCS1. The controller independently verifies the public signature. Signed bootstrap/right helpers and a verified exact-key ACL receipt are required. Both current ACL and receipt scope are checked, and the key ACL is compared again after cleanup. No AD, GPO, logon-right, key ACL or trust mutation is performed.

Native Windows tests run actual low-privilege LocalService workers both without and with key Read, reject tampered bindings/signatures/certificates/policy, and remove fixture artifacts. Customer gMSA acceptance remains separate. This proves challenge signing only: Authenticode package signing and issuer-chain/trust validation are not claimed. See checkpoints/2026-10-25-windows-connector-service-signing-probe-prepared.json for exact delivery and acceptance state.
