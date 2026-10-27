# Persisted signer metadata diagnostic

The gMSA candidate verification/cleanup was accepted from the operator's saved summary. The outer preservation guard remains unresolved. This diagnostic does not repair a key association, change ACLs or replace the failing wrapper. Inspect its current output before any fix or key action.

The product reads CERT_KEY_PROV_INFO (property 2), requires a Microsoft Software Key Storage Provider machine binding, opens the existing named key with MachineKey|Silent, reports metadata, compares public RSA parameters to the certificate and reads its existing ACL. It never creates a key, signs, exports private data or writes certificate/key/ACL properties. Unsupported bindings are reported without user/ephemeral fallback. Do not infer a persisted key's state only from the cached private-key acquisition exception.

Primary API references:
- https://learn.microsoft.com/en-us/windows/win32/api/wincrypt/ns-wincrypt-crypt_key_prov_info
- https://github.com/MicrosoftDocs/sdk-api/blob/docs/sdk-api-src/content/wincrypt/nf-wincrypt-certgetcertificatecontextproperty.md
- https://learn.microsoft.com/en-us/dotnet/api/system.security.cryptography.cngkey.open

Native WinPS 5.1 fixture: 12 checks passed, including actual named non-exportable machine signing key, no provider binding, deliberately conflicting cached handle, mismatched public key, unchanged certificate/key ACL and fresh entry process. The cached-handle fixture produced an invalid-handle exception, not an exact reproduction of the customer's ephemeral-option exception. Customer persisted-key metadata is still pending.
