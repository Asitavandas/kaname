# Operator managed root CRLs

An issuer CRL describes leaf certificates. It cannot establish whether the
issuing CA itself was revoked. This operator tool adds a root-signed base CRL
without replacing either CA certificate or exporting a private key.

## Scope

This is the first repair layer for legacy authorities with no root CRL.
It does not configure CDP URLs, expose a public download route, install CRLs
on Windows, or provide an unattended root signer. The existing public bundle
and endpoint profiles are unchanged. Automatic authenticated distribution,
preauthentication reachability, refresh monitoring and legacy certificate/CDP
migration remain separate acceptance work.

Windows Crypt32 can use a current CRL in its CA system store even when a
certificate has no downloadable CDP. A controlled import can therefore test
the existing chain without reissuing the CA. This is temporary cache-based
acceptance, not automatic online publication. Both issuer and root CRLs must
remain current. Never disable revocation checking to obtain a successful result.

## Commands

Run the accepted source as the state owner or an authorized operator able to
read its private database. Use the actual private state directory.

```sh
python -m kaname.root_crl --state-dir /private/authwire-state status
```

Record the returned public `root_sha256`. To create the first root CRL:

```sh
python -m kaname.root_crl --state-dir /private/authwire-state refresh \
  --expected-root-sha256 ROOT_SHA256_FROM_STATUS --initialize-first-crl --days 30
```

The tool requires a local interactive terminal and prompts with hidden input.
Enter the CA passphrase there. It is not the Linux login password. Do not put
the passphrase in chat, arguments, environment variables or a file. There is
no noninteractive passphrase option. The root key stays encrypted in storage
and is unlocked in memory only for this operation.

For later refreshes omit `--initialize-first-crl`. The durable number increases,
all previous revoked entries stay intact, and the validity end cannot regress.
An expired previous CRL can be refreshed. A corrupt, future-dated or mismatched
ledger is rejected rather than replaced with an empty list. Database restore
can restore an older ledger: external rollback/high-water reconciliation is
outside this command and must be handled before publishing a restored CRL.

Export the current public CRL to a new path:

```sh
python -m kaname.root_crl --state-dir /private/authwire-state export \
  --output /private/operator-export/root-crl.pem
```

The parent directory must already exist. Export never overwrites a file or
follows a symbolic link. If export fails, use another new path; do not issue
another CRL merely to repeat an export. Refresh commits its ledger and audit
atomically; export is a separate read-only operation on the authority database.
No existing CA, server certificate, device binding or configuration is replaced.

## Issuance guard

Legacy absence of a root CRL does not silently initialize one or alter existing
signing behavior. Once a root CRL exists, normal password-based signing and the
unattended device/user issuer reject a corrupt or stale CRL or a revoked issuer.
The guard runs on every issuance, including when the issuer key is cached.
This source change does not by itself reconfigure an already running RADIUS
process or prove that every relying party checks intermediate revocation.

## Acceptance gates

1. Test with disposable fixture authorities: correct root signature and key,
   wrong password/root, missing explicit initialization, replay/reset,
   expired/corrupt lists, revoked-entry preservation and failed audit rollback.
2. Verify the complete fixture chain using both CRLs; missing root CRL fails
   and a root-revoked intermediate fails. These are fixture tests, not customer
   Windows acceptance.
3. Deliver the exact accepted source through the normal controlled deployment.
4. Operator unlocks the existing CA locally; record root fingerprint, CRL
   number/hash/expiry and export only its signed public CRL.
5. Validate/import that public CRL on the isolated pilot endpoint; require a
   complete Windows online chain with no ignore flags, then repeat wired
   EAP-TLS and VLAN acceptance while preserving management access.
6. Complete automated distribution/renewal and stale/unreachable/rollback
   negative tests before closing the production revocation acceptance.

References: [Microsoft Crypt32 CRL semantics](https://learn.microsoft.com/en-us/windows/win32/seccrypto/certificate-revocation-list-semantics)
and [RFC 5280 section 5](https://www.rfc-editor.org/rfc/rfc5280.html#section-5).
