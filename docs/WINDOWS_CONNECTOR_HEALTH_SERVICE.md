# Windows Connector health service v1

Accepted source: PR86. Native acceptance:23 new checks; foundation774 tests,
28 environment skips; three relevant workflows and four Windows jobs pass.

This is source preparation for the single-gMSA architecture. It does not deploy
Windows customer services, retire any existing account, or enable AD,
Kerberos, GPO, enrollment or RADIUS operations. Health is key-possession evidence,
not evidence that SCM installed the service or an AD/GPO job ran.

## Package and trust

`New-AuthWireConnectorServicePackage.ps1` runs as an elevated x64 administrator
using an existing LocalMachine code-signing certificate. Inputs are a reviewed,
signed source bundle and a local service configuration assembled from the
verified owned channel-key receipt plus authorized server pairing metadata.
The appliance PKI UUID and Windows bootstrap connector UUID remain distinct.
No private key, gMSA password or keytab is read/exported to Linux.

The builder locks source files against write/rename, verifies fixed reviewed
body hashes and helper publisher signatures, and signs only the reviewed payload
copies. The core rechecks copied script bodies and C# source before signing or
compiling. Canonical hashes normalize checkout CRLF and an Authenticode suffix;
a signature-marker string inside code is not a suffix. Developer maintenance
tool `tools/connector_service_source_hashes.py` checks without writes by default;
`--update` is for source changes reviewed by developers, never a customer bypass.

Each package is bound to one release UUID, connector UUID, host, exact service
SID, public channel-key ID, binding generation, appliance FQDN/TLS pin and HTTPS
base URL. It creates the fixed path:

`%ProgramW6432%\AuthWire-Connector-<connector UUID without dashes>`

The signed x64 executable embeds SHA256 hashes of its fixed worker, helpers and
service.json. Only SYSTEM/Administrators may write package/configuration files;
the service receives read access and execute access only where required. A
separate state directory grants service Modify for bounded, atomic status files.
An admin-only subdirectory contains the verified signed control tools. File
owners, protected ACLs, hashes, reparse paths and runtime SID/service-token
membership are checked. No arbitrary executable/script/path is accepted by the
service binary or from the network.

The builder refuses to overwrite an existing package. Partial preparation needs
review; no second key, automatic ACL repair, automatic publisher trust or silent
package upgrade is performed. Existing dedicated machine key policy and ACL
are checked without modifying them. It is independent of the code-signing key.

## Administrative control

`Install-AuthWireConnectorService.ps1` defaults to Inspect. Its source helpers
and package must have the explicitly selected valid publisher. Install additionally
requires the exact existing gMSA name/SID, local account readiness and owned
bootstrap/key inspection. The bootstrap may retain its original publisher while
the new package uses the separately approved machine publisher. Both are checked;
the original gMSA/GPO ownership markers are not rewritten.

| Mode | Effect |
|---|---|
| Inspect | Validates the local package and reports SCM state; creates nothing |
| Install | Creates only the named own-process service with the existing gMSA and NULL password; does not start it |
| Start | Starts the verified owned service; repeated Running start is a no-op |
| Stop | Stops only that owned service with bounded child cleanup |
| Remove | Stops and removes only its SCM object; retains package, receipt and channel key |

Service identity is `AuthWireConnector-<connector UUID without dashes>`.
Binary path, account, release/connector/SID ownership marker, automatic startup
and recovery settings must match before install/start. Windows' equivalent
`.\name` local-account presentation is normalized, while the host/worker still
require the exact runtime SID. The installer never grants logon rights, creates
accounts, edits SPNs/GPOs, changes trust stores or replaces authentication policies.
Source signing and publisher trust/distribution are separate explicit prerequisites.

The production creation path sets automatic delayed startup and two SCM restart
attempts, each after60seconds, followed by no further restart; the counter resets
after86400seconds. It uses no reboot or external recovery command. Foreign service
state and drift in startup/recovery settings require review rather than repair.
This metadata and actual SCM restart are tested; a real machine reboot is still
a separate customer acceptance gate.

## Worker and recovery

The host starts only system x64 Windows PowerShell5.1 with NoProfile,
NonInteractive and AllSigned. Module lookup is restricted to system modules.
Its reviewed child uses only the dedicated key and the two fixed authenticated
HTTPS health operations. Success polls every30seconds; failures back off30,
60, then120seconds maximum. It performs no AD/GPO job, arbitrary signing request,
remote command or catalog/Kerberos substitution.

The child has an exact parent PID/start-time check, service SID/host/key scope
checks and a separate duplicate-worker mutex. A private Windows job object with
KILL_ON_JOB_CLOSE binds the worker and its compiler children to host lifetime.
Normal stop signals the worker, waits up to20seconds, and always closes the job;
the host requests25seconds from SCM. Parent checking is an additional fallback,
not the sole mechanism for terminating blocked children. There is no breakaway.

The HTTPS client keeps normal chain, name and revocation checks plus the enrolled
leaf pin. Its timeout/cancellation window is configured to5seconds, with a bounded
complete buffered response. DNS/OS certificate-validation behavior can outlast
the configured client timeout; do not present it as a universal five-second
wall-clock guarantee. Kernel job cleanup bounds service stop even if an OS call
blocks. Slow response headers/body rejection is covered by the prior TLS fixture.

Local status is bounded and contains generic health, checked/last-success times,
worker PID/SID, release and backoff counters. It contains no raw server response,
credential or private key. It is a service-writable observation, not trusted
server authorization. Server-side health expires independently after90seconds.
can_apply, directory_sync_ready and kerberos_ready remain false.

## Acceptance boundary

Hosted tests use an isolated temporary local account because GitHub's Windows
runner has no customer AD/gMSA. They run the real signed executable, actual SCM,
non-exportable CNG key and Python HTTPS handler. They cover the public package
builder, changed source refusal, foreign service refusal, native process SID,
duplicate start, outage/backoff/recovery, stop and crash child cleanup, SCM
restart, tampered payload/config ACL rejection and removal without key deletion.
Fixture services/account/LSA right/keys/certificates/hosts entries are cleaned up.
This is not customer gMSA or boot acceptance.

The appliance channel backend was applied as dev.35 on26October2026; operator
reported protected state, RADIUS/broker PIDs and daily timer preserved. No pairing
or customer Windows service was created by that deployment.

Remaining gates: signed Windows delivery; actual DC01 gMSA
bootstrap/key/service/HTTPS acceptance; real boot/policy refresh; staged signed
upgrade/rollback, channel-key/pin and publisher rotation; authenticated bounded
job/result operations; directory/live AD and Kerberos migration; pilot/scale and
legacy-account retirement. A03/A04 remain open. No production commands are
provided here until trusted environment metadata and delivery artifacts are ready.

Primary references:
- https://learn.microsoft.com/en-us/windows/win32/api/winnt/ns-winnt-jobobject_basic_limit_information
- https://learn.microsoft.com/en-us/windows/win32/api/winnt/ns-winnt-jobobject_extended_limit_information
- https://learn.microsoft.com/en-us/dotnet/api/system.net.http.httpclient.timeout
