# One-use grant consumption and filesystem intent (source only)

This SDK creates a durable authorization-bound filesystem **intent**, not a staged
package. It is absent from the installed package/runtime. HTTP create and peer
write routes remain closed. No Linux/DC01 installation or customer GPO write is
performed by this source change.

## Fixed local store

The future installer must provision the private local root:
`%ProgramData%\AuthWire-WriteJournal-<connector GUID without hyphens>`.
The consumer requires that exact location and the existing private owner/DACL,
native ancestor/file pins, no reparse points, hardlinks or alternate streams.
The SDK does not create this root or alter any ACL. A different empty directory
cannot reset consumption. Connector generation/re-pair does not change the root;
the old durable GPO lock must remain visible across restart and upgrade.

Existing admission limits are unchanged: at most32 job directories and64 root
entries, with no automatic removal to make room. A journal operation ID is only a
deterministic local locator; it is never authentication or authority by itself.

## Exact saved authorization validation

`Read-AuthWireWriteAuthorization` pins and rereads the offer, original preflight,
claim-started, signed claim proof, claim-sent, authorization receipt and GPO lock.
It independently checks runtime SID/hostname, native non-exportable machine key,
RSA signature, purpose/path/binding/payload, original send request and receipt
hashes, scope, release, types and expiry. Rollback remains unsupported here.

Historical evidence is checked at its recorded send/receive times: the original
claim and preflight had to be fresh when sent, and the grant had to match the
five-second transport window and thirty-second grant lifetime. This is not a new
issuance or lease extension. Public live/transmission wrappers still use actual
wall-clock time. At use, current wall-clock time must be at least the recorded
receipt time and strictly before the original server expiry. A clock rollback,
invalid timestamp/type, edited receipt/proof or expired grant fails closed.

## Consume before another operation

`New-AuthWireAuthorizedFilesystemIntent` rechecks pinned records, then writes
`grant-consumed.json` with CreateNew and Flush(true). It binds scope, release,
job, exact authorization receipt hash, deterministic filesystem operation ID,
consumption time and unchanged expiry. This happens **before** another process,
live read or filesystem intent. Concurrent attempts race at the same atomic
CreateNew; no overwrite, renewal, deletion or automatic retry exists.

After consumption, a fixed AllSigned readonly child rechecks current public
content/signatures and AD/PDC/GPO/SYSVOL observations against the same approved
preview. Its work budget is at most8 seconds and also fits the remaining grant
window with a two-second margin. Existing bounded process termination/drain
cleanup waits are additional, not part of the8-second work budget. Output is
bounded and checked for schema, freshness and job/intent identity. Current PDC,
source/GPO paths and protected GPO must also equal the pre-CLAIM context.

Only then is `filesystem-intent.json` created/flushed. It binds the consumed
marker, receipt, offer, target and preview hashes to the fresh locally derived
context and original expiry. A final expiry check cannot renew that deadline.
The returned state always has `FilesystemWriteEnabled=false` and
`CanApplyGpo=false`. No filesystem transaction directory or completion result is
fabricated, no artifact is executed, and the low-level stage engine is not called.

Reader failure/timeout, PDC/context drift, disk error or expiry after consumption
retains the marker and GPO lock. An intent flush failure leaves no valid intent;
a partial file remains review evidence. Reload/reboot cannot consume the same
grant again. These states require explicit reconciliation; choosing another
root, removing a marker or re-creating the grant is not recovery.

## Test boundaries and remaining gates

The hosted fixture uses real native CNG, NTFS records, pinned HTTPS and unchanged
SQLite claim logic. Eight distinct grants are authorized; each core replay is
refused and each job has one native HTTP attempt. Four grants cover successful
consumption, intent disk failure, current-context drift and a simulated reader
timeout. The positive live AD/content reader observation is explicitly simulated;
strict path derivation, receipt/signature verification and local persistence are
real. The genuine fixed AllSigned child is also checked on its fail-closed invalid
config path. Customer gMSA/AD/SMB acceptance is not claimed.

The next execution adapter must consume the exact saved intent into a bounded
stage child, enforce the still-current grant and source/GPO boundary immediately
before writes, and bind actual filesystem journals/results to this operation ID.
POLL/result orchestration, rollback approval, interrupted/partial transaction
reconciliation, strict backup projection, signed package delivery and real
operator acceptance remain open. Activation/linking/applying GPOs is separate.
