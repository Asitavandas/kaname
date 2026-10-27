# Native signer metadata revision 2

The v1 customer diagnostic opened the named machine KSP key but saw managed IsEphemeral=true and null managed names. It stopped before public-key/file/ACL inspection. The marker's origin is unconfirmed. The original runtime verification/cleanup already passed; do not rerun the service probe or clear/change key properties.

Microsoft reference source shows that CngKey.IsEphemeral reads the custom CLR marker and managed KeyName/UniqueName return null when that marker is true:
https://github.com/microsoft/referencesource/blob/main/System.Core/System/Security/Cryptography/CngKey.cs

The v2 diagnostic reports native names/type/length/export/usage, the CLR marker before/after, fixed public RSA blob equality with strict certificate public DER, and current file ACL. It does not call managed private-key acquisition or force an ephemeral option, create/delete/sign/export private data, repair association or write any property/ACL. Native key metadata and marker are separate observations; no original preservation acceptance or panel attestation is inferred.

Primary native API/property definitions:
- https://learn.microsoft.com/en-us/windows/win32/api/ncrypt/nf-ncrypt-ncryptgetproperty
- https://learn.microsoft.com/en-us/windows/win32/seccng/key-storage-property-identifiers
- https://learn.microsoft.com/en-us/windows/win32/api/ncrypt/nf-ncrypt-ncryptexportkey

Final native WinPS fixture: 16 checks. It forces the marker on a disposable owned named key, reproduces the managed null-name contradiction, validates native identities/public equality/constraints and verifies marker/ACL remain unchanged. Customer native output is pending. Linux remains dev.38; only a public helper file is staged in the operator home.
