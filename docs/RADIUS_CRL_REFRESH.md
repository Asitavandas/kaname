# RADIUS CRL publication and cache refresh

The database CRL is refreshed by the existing device signer maintenance. Before
this correction the native RADIUS CA directory was generated only at service
startup, so its CRL expired even though the database already held a valid newer
list. Certificate-free negative field acceptance must not use that broken state.

`tools/radius_crl_sync.py` runs as `kaname-lab`. It reads a consistent SQLite
snapshot in read-only mode, checks the existing runtime root/issuer pins, verifies
CA chain/constraints/validity, and checks the CRL signature, number and validity.
It rejects rollback, removed prior revocations, same-number replacement and
unsafe file/lock paths. Only the canonical runtime `ca/issuer-crl.pem` is replaced
atomically, retaining the existing OpenSSL hash link. It does not sign anything,
write business-state rows, alter policy or trust anchors, or restart RADIUS.

The timer runs once per minute only while the runtime CA directory exists. It
does not start or enable a stopped RADIUS service. Filesystem write access to the
private state directory allows SQLite WAL/SHM coordination; the database itself
is opened with `mode=ro` and no SQL write or application constructor is used.

Generated EAP configuration uses `ca_path_reload_interval = 300`. The pinned
FreeRADIUS 3.2.10 implementation refreshes its X509 store on a new TLS session
after that interval and clamps smaller values to 300 seconds. Publication and
cache pickup can therefore take approximately six minutes. Current certificate
registry checks still reject revoked/deactivated identities immediately; native
TLS expiration/revocation enforcement remains enabled and fails closed.

Installation uses tested root-owned source, refuses unknown existing timer units,
and verifies protected configuration and the primary RADIUS unit remain intact.
One initial RADIUS restart is necessary if the running EAP configuration lacks
the reload directive. Subsequent timer publication/cache refresh does not restart
the process. Stopping a RADIUS service intentionally remains respected.

The native protocol fixture first authenticates a synthetic computer, publishes
a newer signed CRL that revokes it while leaving its fixture registry row active,
waits the real 300-second interval, and verifies a TLS-level Access-Reject without
an authorization callback or process restart. No real AD, endpoint or production
CA is used. Unit fixtures cover signature/expiry/rollback/path/atomicity failures,
timer installation and rollback. Field acceptance still requires deployment and
observing the installed timer/status; source fixtures alone do not prove that.

Primary implementation references:
- https://github.com/FreeRADIUS/freeradius-server/blob/9071ea041b9172e52eabbba91619afaf3a238795/raddb/mods-available/eap
- https://github.com/FreeRADIUS/freeradius-server/blob/9071ea041b9172e52eabbba91619afaf3a238795/src/main/tls.c
