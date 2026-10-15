# AuthWire current work record

Updated: 15 October 2026, Europe/Istanbul. This record supplements the 9 October
`AuthWire_Durum_ve_Tamamlama_Raporu_2026-10-09.docx` / `.pdf`; those reports are a
dated baseline. Use this record when producing their next requested revision.
The operator requested ongoing tracking and no new report delivery today.

## Completed field results

- **Completed: wired positive EAP-TLS pilot and dynamic policy VLAN assignment.**
  Windows computer 2GL13ZU, Realtek Ethernet, HPE Instant On 1930 VV-SW,
  source 10.35.50.253, port 6. Windows reported Authentication succeeded.
  Changing the AuthWire policy VLAN resulted in an address from the new VLAN;
  the operator also confirmed a VLAN 70 assignment test.
- **Completed: wireless positive EAP-TLS pilot and dynamic policy VLAN assignment.**
  HPE Instant On AP22 OFIS-AP, source 10.35.50.52, SSID VV_802.1X.
  Windows was configured manually with machine EAP-TLS, pinned server name and
  AuthWire Root CA. WPA2-Enterprise connected; initial address 10.10.110.3/24.
  With the SSID default network unchanged, changing only the AuthWire wireless
  policy VLAN gave an address from the new VLAN (operator confirmation 17:13).
- **Existing configuration accepted, new test omitted by operator:** separate
  guest SSID / VLAN 70. The operator already uses this arrangement and explicitly
  declined another guest test. Do not label it as a newly executed test.
- **Completed: normal-mode native RADIUS authorization correction.** PR 27
  backports upstream Python attribute parsing correction without dropping secret
  redaction. Native module update was applied with backup; real normal-service
  Accept and authenticated VLAN attributes were observed. Debug-only success is
  no longer the deployment evidence.
- **Completed: wireless pilot registration and scoped rule.** Existing OFIS-AP
  RADIUS client was changed from wired to wireless, preserving its shared secret.
  Rule `authwire-pilot-wireless` retains the pilot AD security group, EAP-TLS and
  domain computer constraint, and NAS 10.35.50.52. Existing wired rule was retained.
- The operator subsequently chose to share the existing cloud RADIUS profile and
  shared secret between switch and AP. Keep their distinct trusted source IPs and
  wired/wireless classifications; do not combine them into a subnet-wide client.

## Mapping to the baseline report

| ID | Latest change | Work still open |
| --- | --- | --- |
| B01 | Panel session recovery fix deployed; server API and protected-state verification completed. | Operator browser acceptance; complete setup/apply/recovery UX. |
| B02 | Live AD identity/pilot group accepted on wired/wireless; VV06 pilot-group removal and disabled-computer-account rejection/recovery completed. | Deleted account, unavailable AD and capacity tests. |
| B03 | Server name/CA validation completed on wired/wireless; VV06 wired revoked-certificate rejection and signed/current runtime CRL membership verified. | Expired/wrong issuer, CA/issuer rotation and remaining signing maintenance acceptance. |
| B04 | Enrollment task, successful last result, installation record, valid certificate/private key and confirmed receipt observed for the pilot. | Interrupted/duplicate requests and negative enrollment scenarios. |
| B05 | Pilot task and installed client confirmed. Client source hash remained unchanged through server updates. | Fresh SYSVOL package/signature/hash comparison where not yet recorded. |
| B06 | Controlled post-revocation fresh enrollment, new certificate/private key and restored wired authentication/VLAN 110 access completed on VV06. | Post-boot task result, ordinary renewal/scheduler reliability, offline recovery, key lifecycle and expired recovery; endpoint reboot access passed. |
| B07 | Normal production service active; actual switch/AP EAP-TLS/VLAN, VV06 group-out and disabled-account rejection/recovery completed. | Post-boot task execution, remaining lifecycle acceptance and accounting remain open; VV06 reboot wired access passed. |
| B08 | Real permit and dynamic VLAN/DHCP completed on switch/AP; pilot-group and disabled-account rejection/recovery completed on VV06. | Other explicit deny conditions and negative state transitions. |
| B09 | Wired positive/VLAN tests and VV06 missing-cert, wrong-group and disabled-account negatives completed, including recovery for reversible AD changes. | VV06 OS reboot wired access and controlled post-revocation recovery completed. Post-boot enrollment-task execution and remaining lifecycle acceptance stay open. |
| B10 | AP/SSID/source/secret, manual Windows machine EAP-TLS profile, positive connection and dynamic VLAN completed (3 of original 4 rows). | Intentional negative trust/identity tests remain open; reconnect was exercised during VLAN testing. |
| B11 | No accounting expansion in this session. | Accounting, session correlation and retention. |
| B12 | Updates retained configuration, administrators and certificates with backups. | Full restore/rollback and clean appliance import/boot acceptance. |

Do not close all of B03/B06/B09/B10 solely because a positive connection worked.
The operator's completed milestone is positive wired/wireless authentication and
policy VLAN behavior; negative and lifecycle rows remain separately visible.
G01-G07 remain at the baseline state unless a later implementation has evidence.

## Panel stability investigation

- Operator request at 17:38: intermittent F5/repeated credentials/slow responses;
  diagnose, report findings and fix without disturbing tested 802.1X behavior.
- Current production resources: no CPU/RAM/disk pressure, no service crash/restart
  loop. HTTPS public reads measured 2-3 ms; 24 reads at concurrency 8 had zero
  failures, median 11 ms and maximum 23 ms (server-local, not a client LAN benchmark).
- Journal contained repeated `SSLV3_ALERT_CERTIFICATE_UNKNOWN` from 10.35.50.54.
  Current HTTPS certificate is self-signed for kaname.vizyonveri.local and
  10.35.50.246, valid through October 2027. This is distinct from RADIUS CA trust;
  neither CA nor RADIUS server certificate should be reset to address it. The
  operator subsequently confirmed 10.35.50.54 is unrelated to panel use; exclude
  these messages from the diagnosis and do not change client certificate trust.
- Frontend defects corrected in PR 28 / source merge
  `11b4950cb475dce20054606a2839499c05cc7566` (0.14.0-dev.3): transient startup
  state/list errors no longer demand another password; fetch has bounded wait;
  login and polling are single flight; generic errors no longer trigger extra
  refresh requests; obsolete session responses cannot close a newer session.
- Completed validation: all nine browser fault-injection scenarios passed,
  existing panel/device/planning browser flows passed, and foundation CI ran
  409 Python tests successfully with 25 environment-dependent skips. Native
  RADIUS protocol and Windows enrollment/renewal fixture gates also passed.
  Main staging passed 112 filesystem-local checks (four skips); source manifest
  `2323abf4fde7a2169313f19ed766ffa425b03a47b2040bccdb33fc1c3af76392`.
- Panel fix status: **0.14.0-dev.3 deployed; final acceptance pending**. The
  operator ran the guarded update at approximately 18:14. Update and trusted HTTPS
  checks passed, and configuration, administrators and Windows client source
  preservation passed. Before update, all 15 authenticated API reads returned
  HTTP 200; endpoint medians were 2.4-8.0 ms, maximum 8.3 ms (server-local).
- Deployment incident: the post-update guard correctly detected RADIUS was no
  longer running. Its unit had `Requires=kaname-lab.service`; stopping the panel
  propagated a clean stop to RADIUS. The panel updater did not account for that
  effective systemd dependency. Panel and native module are healthy/unchanged,
  and RADIUS service restoration was subsequently confirmed by the guarded unit
  repair at 18:31. The initial RADIUS PID was not preserved; a new process was
  started. Authentication configuration and protected state were preserved.
- **Completed: permanent service dependency repair and server verification.**
  PR 29 merged as
  `b7e46991e17d3602d6424c1e59a179fda8b07f14`. Foundation CI ran 421 tests
  successfully (25 environment-dependent skips); native RADIUS proof and real
  disposable systemd lifecycle checks passed. The operator applied the guarded repair at 18:31: unit backup created,
  stop dependency removed, RADIUS started successfully, and UDP
  10.35.50.246:1812 confirmed. All 17 protected-state/file comparisons matched
  backup `upgrade-c2af2627005f44268e12dfebc9b120a8`, including policies, CA,
  certificates, enrollment signer/profiles/bindings, sealed secrets, administrators,
  web/RADIUS keys and certificates, Windows client, native module and remaining
  service commands/hardening. All 15 authenticated API reads returned HTTP 200;
  endpoint medians 2.6-25.1 ms, maximum 60.0 ms (server-local). Final output:
  `REPAIR_FINISHED verified=true radius_active=true protected_state_preserved=true
  panel_api_healthy=true`. Browser behavior after one Ctrl+F5 reload remains
  pending operator feedback; do not claim the intermittent client symptom is
  conclusively resolved until that acceptance.
  Retain `After` and a `Wants` startup
  dependency, remove panel stop propagation, refuse future panel upgrades while
  an active RADIUS service has a stopping dependency, and verify its PID after
  an upgrade. Migration preserves the remaining unit and authentication settings.
  The passing disposable systemd regression fixture reproduced old behavior and checked
  RADIUS PID survival across panel stop/restart. Never retest this by stopping
  the customer's live panel without independent authorization and need.

## VV06 field session — 13–15 October 2026

- Operator will bring a domain-joined Windows computer with no AuthWire client
  certificate installed. Operator identified the new computer as **VV06** at 11:14 on 13 October,
  reporting domain membership and no installed certificate. Read-only baseline confirmed at 11:22: domain vizyonveri.local,
  PartOfDomain=true, one personal machine certificate (Subject/Issuer CN=VV06),
  zero AuthWire machine certificates, AuthWire Root CA not trusted, no AuthWire
  enrollment task, and dot3svc stopped. Certificate purpose of the self-issued
  VV06 certificate was not established. Server-trust and supplicant preparation
  are required before the no-client-certificate rejection test can be accepted. No AD, policy or GPO changes were made in advance.
- **Completed VV06 preparation at 16:52:** operator imported the pinned public
  Root CA into LocalMachine Root after file thumbprint verification.
  RootTrusted=true; Subject CN=KANAME Root 6796fa84; SHA1
  C789A0595ADB95A6BE4534D01B1D205F6C37DE18. dot3svc is Running.
  This trust-only action did not issue an AuthWire client certificate; last
  measured AuthWire machine certificate count was zero. Correct machine EAP-TLS
  wired profile preparation was followed by the actual missing-certificate
  negative test at 19:15; results are recorded below.
- Server connection at session start was unavailable; Desktop Commander
  segmentiq reconnected at approximately 17:08. Production service and CRL
  readiness were subsequently verified; remote connectivity alone was not used
  as evidence of RADIUS health.
- **Blocking readiness issue found at 17:06, resolved at 18:02 on 13 October:** operator read the
  running RADIUS CRL: lastUpdate 12 October 06:02:58 UTC, nextUpdate 13 October
  06:02:58 UTC (09:02:58 Istanbul), already expired. Do not accept a failed
  connection as the missing-client-certificate test while this is unresolved.
  Desktop Commander reconnected; RADIUS was directly confirmed active, PID
  1100697. The subsequent read-only guarded diagnostic compared database and
  runtime CRL dates, numbers and signatures. Existing CA, keys, certificates,
  policies and VLANs have not been changed to address this issue.
- CRL diagnostic at 17:13 confirmed current, correctly signed database CRL #18
  (13 October 06:03:23 UTC through 14 October 06:03:23 UTC, two revoked entries)
  versus expired runtime #16 (12 October 06:02:58 UTC through 13 October
  06:02:58 UTC, two entries). Signer enabled and authority currently valid.
  Root cause: the database auto-refresh was not published to the active runtime;
  native X509 cache refresh was not configured. Immediate restart instruction
  given but not yet confirmed; observed PID still 1100697 at 17:31.
- **Completed: permanent CRL correction deployed (0.14.0-dev.4).** signed, pinned, monotonic
  atomic publication as the existing service user; minute timer respecting a
  deliberately stopped RADIUS; native X509 refresh at the supported 300-second
  interval. No CA/endpoint certificate reissue, policy reset or relaxed validation.
  PR 30 merged as `477a57d265a4dbfb9f6fb43f522648fdf277dca9` after all source
  gates passed: 438 foundation tests (25 environment skips), native EAP-TLS CRL
  cache proof (same process, real 300-second interval, native reject before policy),
  non-root systemd timer sandbox and stopped-service boundary, browser and Windows
  enrollment/renewal fixtures. Main staging ran 141 filesystem checks (four skips)
  and produced 98-file manifest
  `359722b02776194d1622d620366c36896108d860e86d68068367fb9f42328718`.
  Operator applied the guarded deployment at 18:02. Source upgrade verified
  HTTPS and preserved the active RADIUS process during the panel upgrade.
  Timer installation then performed the required initial RADIUS restart to
  activate the 300-second native X509 refresh; no periodic restart is configured.
  Database and runtime CRL were identical, signature-valid and current: #18,
  lastUpdate 13 October 06:03:23 UTC, nextUpdate 14 October 06:03:23 UTC,
  two revoked entries. All 17 protected file/state comparisons passed.
  Configuration, policies, CA material, certificates, secrets, administrators,
  primary RADIUS unit/native module and Windows source were preserved.
  Direct read-only follow-up at 18:06 confirmed the minute timer actually
  triggered, its oneshot completed with Result=success, and RADIUS remained
  active with PID 1142921. The successful oneshot being inactive afterward is
  expected. CRL publication/cache readiness blocker is closed; the VV06
  missing-client-certificate field test itself remains open.
- **Completed: VV06 wired missing-client-certificate negative test at 19:15:44
  on 13 October.** WiredService=Running, AuthWireMachineCertificateCount=0.
  Physical Realtek Ethernet MAC 38-CA-84-DB-FF-E6, interface
  415933d5-5010-4a7a-b8bf-0e537e0bc7f2, switch peer 64E881346361.
  Windows reported Connected / Authentication failed; fresh event 15514:
  identity NULL, 0x80420014, "A certificate could not be found that can be used
  with this Extensible Authentication Protocol." Event 15506 then applied a
  600-second suppression period. This establishes supplicant-side failure due
  to unavailable usable client certificate; it is not evidence of a RADIUS
  Access-Reject or an evaluated policy deny. Root trust/domain membership did
  not provide an EAP-TLS client credential. Guest access was not retested.
- Operator requested a brief Linux shutdown at 18:12. Pre-shutdown disk sync
  completed; panel/RADIUS/minute timer were enabled and active. Actual shutdown
  and subsequent boot are not yet confirmed. At 19:19 Desktop Commander was
  offline; this alone did not indicate server/RADIUS failure.
  **Completed: post-boot service/CRL readiness at 19:23.** Operator reported
  kaname-lab.service, authwire-radius.service and authwire-radius-crl-sync.timer
  all active/enabled. Runtime CRL #18 (0x12) lastUpdate 13 October 06:03:23 UTC,
  nextUpdate 14 October 06:03:23 UTC, still current. This verifies readiness
  after the planned shutdown; full boot/lifecycle and endpoint reconnect
  acceptance remain separate from these service-state observations.
- Enrollment scope check at 19:29: VV06 is
  CN=VV06,CN=Computers,DC=vizyonveri,DC=local; direct MemberOf list is empty.
  Existing GPO e5a9ab39-3709-49cb-837a-0208d2eb3b12 is
  AuthWire-Pilot-Trust, AllSettingsEnabled. AuthWire-Pilot-Computers has
  GpoApply; Authenticated Users has GpoRead only. Computer pilot group addition
  is the next scoped action; not yet confirmed. Link location and actual
  enrollment Startup script registration need verification before reboot.
  Do not infer installer deployment from the GPO name or copied SYSVOL files.
- GPMC screenshots at 19:33 confirm AuthWire-Pilot-Trust is linked to the
  vizyonveri.local domain root, Link Enabled=Yes, Enforced=No, WMI filter none.
  Security filtering remains AuthWire-Pilot-Computers only. Computer Startup
  has two entries invoking the same signed Install-AuthWire.ps1 in the existing
  GPO SYSVOL path: bare powershell.exe and the full System32 WindowsPowerShell
  v1.0 path, both with AllSigned. Operator instructed to remove the redundant
  bare-path entry and retain the full-path entry/parameters. Cleanup, VV06 pilot
  membership, new machine-token reboot and automatic enrollment are not yet
  confirmed. Do not mark the GPO distribution/second-device enrollment passed.
- **Completed: VV06 automatic enrollment/task and machine certificate installation
  observed at 19:45.** LastRunTime 13 October 19:39:42; initial LastTaskResult
  267009 (0x41301, task running), later 0. Certificate count increased from 0
  to 1; Subject CN=AuthWire computer 69b0d5cd-db61-4627-9db7-fcc5230152a3,
  Issuer CN=KANAME Issuer 6796fa84, HasPrivateKey=true, expiry 11 January 2027
  19:43:27 Europe/Istanbul. This is a distinct identity from pilot 2GL13ZU.
  Ethernet disconnected when the final read was captured does not invalidate
  stored task result/certificate evidence. Certificate serial and server receipt
  row were not independently read in this step. Positive switch port 6 access
  and policy VLAN/DHCP on VV06 remain pending; do not close full lifecycle,
  SYSVOL hash/signature inventory or user-authentication acceptance.
- **Completed: VV06 wired positive EAP-TLS field test at 19:48:36.**
  Windows physical Realtek Ethernet reported Connected / Authentication
  succeeded. Fresh event 15502 confirms EAP-TLS and machine credentials.
  Fresh event 15505 confirms host/AuthWire computer
  69b0d5cd-db61-4627-9db7-fcc5230152a3, peer 64E881346361, reason/error 0x0.
  After DHCP renewal, Ethernet had 10.10.110.4/24, gateway 10.10.110.1,
  matching the previously established VLAN 110 subnet. Wi-Fi was disconnected.
  This completes the VV06 certificate-free failure → automatic certificate
  installation → successful wired access sequence. A separate VLAN change on
  VV06 was not performed; dynamic policy VLAN changes remain evidenced by
  the earlier 2GL13ZU wired/wireless pilot tests. Wrong-group, disabled account,
  revoked certificate and lifecycle acceptance remain open.
- **Wrong-group negative phase observed at 19:55:51, reported at 20:01.**
  After the instructed VV06-only pilot group removal and a fresh wired attempt,
  Windows reported Connected / Authentication failed. Fresh event 15514 has
  host/AuthWire computer 69b0d5cd-db61-4627-9db7-fcc5230152a3, switch peer
  64E881346361, reason 0x50005 and error 0x80420105 (server rejected the
  credential). Unlike the earlier missing-certificate failure, a certificate
  identity was selected. This is the expected client-side result of the
  controlled group-out test. Exact backend decision reason was not read;
  do not equate the generic Windows text with certificate revocation or expiry.
  Operator reported no errors/output from DC commands; membership restoration
  and positive recovery must be verified before closing the full wrong-group
  acceptance case. Only VV06 membership was instructed to change.

- **Completed: controlled VV06 wrong-group rejection and recovery at 20:05.**
  After the instructed pilot membership restoration and a fresh physical wired
  reconnect/service reset, Ethernet MAC 38-CA-84-DB-FF-E6 again reported
  Connected / Authentication succeeded. The group-out phase at 19:55:51
  failed and the restored phase succeeded using the same machine certificate.
  This closes the scoped wired field acceptance case; exact backend decision
  reason and an independent AD membership listing were not captured. No policy,
  certificate, VLAN or working 2GL13ZU change was instructed.
  Next controlled case is temporarily disabling only the VV06 AD computer
  account, checking fresh rejection, then re-enabling and verifying recovery.
  The disabled-account case was subsequently completed on 14 October, as
  recorded below.

- **Completed: VV06 disabled AD computer account rejection and recovery on
  14 October.** Operator labeled the first screenshot as account disabled:
  Ethernet MAC 38-CA-84-DB-FF-E6 / GUID 415933d5-5010-4a7a-b8bf-0e537e0bc7f2
  reported Connected / Authentication failed. Fresh event 15514 at 15:56:34
  identifies host/AuthWire computer 69b0d5cd-db61-4627-9db7-fcc5230152a3,
  peer 64E881346361, reason 0x50005, error 0x80420105. The second screenshot,
  after account re-enabling and dot3svc reset, shows the same physical Ethernet
  Connected / Authentication succeeded. This closes the controlled wired
  account-disabled rejection/recovery field case using operator-described AD
  states. Exact backend decision reason and Enabled=false/true AD command
  output were not captured; generic Windows error alone is not a revocation
  or expiry diagnosis. Evidence: image(20261014-130352).png and
  image(20261014-130403).png, inspected directly.
- **Completed: revocation-test preflight at 16:13 on 14 October.**
  Operator screenshots identify the VV06 LocalMachine machine certificate:
  Subject CN=AuthWire computer 69b0d5cd-db61-4627-9db7-fcc5230152a3;
  Windows SerialNumber 0D9C3EE3C0B676CB323C1EC8314B62EE3E20A1D9;
  canonical AuthWire serial d9c3ee3c0b676cb323c1ec8314b62ee3e20a1d9;
  thumbprint 216819A5BF9A13A2A75609EA84FBFA316A39B453;
  HasPrivateKey=true, expiry 11 January 2027 19:43:27 Europe/Istanbul.
  Current physical Ethernet still reports Authentication succeeded.
  Runtime CRL advanced to #20 (0x14), lastUpdate 14 October 06:03:32 UTC,
  nextUpdate 15 October 06:03:32 UTC (09:03:32 Istanbul), currently valid.
  This is next-day runtime publication evidence; no fresh signature/DB-equality
  or process-preservation comparison was captured in these screenshots.
  PKI revoke API expects canonical hex without leading zero; identify the
  exact certificate before the irreversible leaf revocation. Target is only
  VV06, with cessation_of_operation reason for the controlled test. Keep the
  certificate installed until the negative attempt so missing-cert failure
  cannot substitute for revocation rejection. Actual revocation/rejection and
  controlled fresh enrollment are still pending.
- Next: revoked-certificate test on VV06 only, then controlled fresh enrollment.
  First identify the actual current client certificate serial/thumbprint and
  verify current CRL readiness. No certificate has yet been revoked for this
  case; do not mark it completed. Desktop Commander was offline at the 16:06
  follow-up, so no fresh server/CRL inspection could be performed remotely.
  Keep working pilot 2GL13ZU unchanged and preserve policy/client/CA settings.
- **User EAP-TLS remains an explicit open item.** User certificate issuance,
  AD binding and live authorization exist in source, but automated user
  distribution/renewal and real wired/wireless user authentication have not been
  accepted. Include them in the next report; do not close them with computer
  pilot evidence. Windows machineOrUser switching also needs separate acceptance.
- Simultaneous machine-and-user authentication (for example TEAP chaining) is not
  implemented and is not silently added to the current EAP-TLS release scope.
- Operator will observe panel behavior and send grouped notes if symptoms recur;
  browser acceptance remains open. No reminder or unattended live test is scheduled.

## VV06 DNS restored, HTTPS still blocked — 15 October 2026, 14:37

- Attached image(20261015-113624).png was directly inspected. Explicit VV06 DNS
  queries against 10.35.50.70 now succeed: kaname.vizyonveri.local A ->
  10.35.50.246; domain-controller SRV -> dc01.vizyonveri.local:389,
  with additional A -> 10.35.50.70. Scoped explicit DNS-query restoration is
  completed; default-resolver behavior and actual DC discovery are not yet retested.
- Direct-IP TCP test still fails: source 10.10.110.4 -> 10.35.50.246:8765,
  TcpTestSucceeded=False. Ping timeout is ancillary and not service proof.
  Do not mark HTTPS enrollment connectivity or the failed task recovered.
- Direct read-only Linux checks: listener present on 10.35.50.246:8765;
  route to 10.10.110.4 via 10.35.50.254, ens33, source 10.35.50.246.
  This proves a configured return route, not successful end-to-end delivery.
  ufw.service is active; firewalld.service and nftables.service inactive.
  No privileged firewall ruleset has been read; UFW as the blocker is only
  a hypothesis alongside the inter-VLAN firewall policy.
- Next root-only read is operator-run sudo ufw status numbered. Inspect existing
  source/service allowances before any scoped rule change; do not disable UFW,
  broadly open management access or restart RADIUS for this diagnosis.
  Preserve machine cert, client state, task conditions, policy/VLAN and CA.

## VV06 VLAN 110 firewall prerequisite — 15 October 2026, 14:12

- Explicit endpoint queries to internal DNS 10.35.50.70 timed out for both
  kaname.vizyonveri.local A and domain-controller SRV records.
  Direct-IP TCP 10.35.50.246:8765 also failed with source 10.10.110.4.
  Ping timed out as well; ICMP alone is not used as service-health evidence.
- Operator confirmed no firewall access rule exists from 10.10.110.0 network
  to 10.35.50.0 network and will configure access then repeat the same tests.
  Current evidence strongly supports missing inter-VLAN access as the DNS/
  HTTPS bootstrap prerequisite failure. Exact rule effect awaits retest.
- Working machine-certificate EAP-TLS/VLAN authorization does not establish
  endpoint HTTPS enrollment or domain-controller reachability: the RADIUS
  conversation is between switch and server, whereas task requests originate
  from VV06 in its assigned VLAN.
- Recommend scoped destinations/services for this pilot: internal DNS
  10.35.50.70 UDP/TCP 53, AuthWire 10.35.50.246 TCP 8765, and required AD
  connectivity to the actual DC according to the existing domain firewall policy.
  Do not request unrestricted access between both entire networks.
- Firewall/DHCP configuration is performed by the operator. No RADIUS,
  certificate, task, policy/VLAN or server configuration has been changed.
  Post-change DNS/HTTPS/DC discovery and an actual successful existing task
  run remain pending; no second enrollment/reset is needed for this test.

## VV06 VLAN 110 DNS/DC discovery failure — 15 October 2026, 14:05

- Endpoint Ethernet DNS servers are 10.35.50.70 and public resolver 1.1.1.1.
  Test-NetConnection by FQDN warned that kaname.vizyonveri.local name
  resolution failed; nltest forced DC discovery returned 1355 / ERROR_NO_SUCH_DOMAIN.
  No endpoint TCP result was supplied. DNS/DC discovery is currently unhealthy;
  failed discovery alone does not mean VV06 lost domain membership.
- Direct read-only DNS queries from AuthWire Linux to 10.35.50.70 succeeded:
  authoritative NOERROR A kaname.vizyonveri.local -> 10.35.50.246;
  authoritative NOERROR SRV _ldap._tcp.dc._msdcs.vizyonveri.local ->
  dc01.vizyonveri.local, port 389. Thus these records exist and the DNS server
  answers from the Linux management-network vantage. This does not prove
  VLAN 110 DNS reachability or identify a specific firewall rule.
- Session-stage enrollment failure is consistent with endpoint DNS/DC failure,
  but exact original SSPI/HTTPS exception remains unobserved.
- Next: explicit endpoint queries against 10.35.50.70 for both records, plus
  direct-IP TCP 8765 reachability to 10.35.50.246. Check VLAN 110 DNS routing/
  ACL and DHCP resolver configuration against results. Domain clients should
  receive internal AD DNS servers; public recursive forwarding belongs on the
  internal DNS service, not as an alternate domain-client resolver.
- Do not alter EAP-TLS validation, certificates, task, RADIUS policies or broadly
  open VLAN routing. No configuration mutation has been performed.

## VV06 session-stage diagnosis — 15 October 2026, 14:01

- Endpoint status: state=retry_pending, error=ENROLLMENT_OR_INSTALL_FAILED,
  stage=session, no server_error, checked_at=2026-10-15T10:50:08.6893421Z.
  Retry attempts=1, next_attempt=2026-10-15T11:05:08.6366804Z
  (14:05:08 Europe/Istanbul). This is an earliest retry eligibility deadline,
  not a guaranteed task trigger at that time.
- Client source shows session includes machine Kerberos credential acquisition,
  initial SSPI token, pinned/validated HTTPS POST /api/device/session, response
  parsing and mutual-authentication completion. No specific failure within
  these operations is established by the coarse stage. Blank server_error
  does not prove no server contact.
- Read-only Linux verification at 13:58:44 showed panel and RADIUS active/running
  with Result=success and CRL timer active/waiting. A service-journal query for
  13:47-13:52 local returned zero records; it supplies no independent request
  or TLS/Kerberos failure evidence and cannot establish that no request arrived.
- Next endpoint read-only diagnosis: Ethernet IPv4 DNS configuration, current
  FQDN TCP 8765 reachability/source and forced domain-controller discovery on
  VLAN 110. Preserve client state, pinned TLS/mutual Kerberos, task conditions,
  certificate, RADIUS and policy configuration pending evidence.

## VV06 post-boot task failure — 15 October 2026, 13:58

- After the elevated read, operator reported existing enrollment task Ready,
  LastRunTime=15 October 2026 13:48:24 and LastTaskResult=1. This confirms a
  post-boot execution attempt ended with a nonzero result; post-boot task
  success is not accepted. Existing certificate-backed wired authentication
  and VLAN 110 access remain successful, as separately observed.
- Client source inspection confirms status.json records sanitized
  state/error/stage/checked_at/server_error for enrollment failures and
  retry.json records attempts/next_attempt/stage/server_error. Read only these
  whitelisted fields before diagnosing or rerunning. Exit code 1 alone does
  not identify networking, Kerberos, receipt, renewal or signing as the cause.
- Do not clear retry or installation state, replace certificates, weaken
  validation or force-dispatch the task for this initial diagnosis.
  Earlier queued scheduling and this nonzero boot run are distinct observations.

## VV06 Windows reboot acceptance — 15 October 2026, 13:54

- **Completed: restored wired access after the instructed VV06 Windows reboot.**
  Operator supplied physical Realtek Ethernet GUID
  415933d5-5010-4a7a-b8bf-0e537e0bc7f2, MAC 38-CA-84-DB-FF-E6,
  Connected / Authentication succeeded, and IPv4 10.10.110.4/24 Preferred.
  This closes the scoped endpoint reboot/authentication/VLAN-access test.
  Boot timestamp and pre-logon timing were not independently measured.
- Get-ScheduledTaskInfo for AuthWire Certificate Enrollment returned
  PermissionDenied / HRESULT 0x80070005. No LastRunTime or LastTaskResult
  was read. This is a query access failure, not evidence that enrollment
  failed or that the existing scheduled task ran successfully after boot.
- Next: repeat only task-information and administrator-token read in an elevated
  PowerShell on VV06. If denial persists with an elevated token, investigate
  task access read-only; do not weaken the SYSTEM task ACL or change its
  principal, action, triggers, power/network conditions or signing requirements.
- Task execution after reboot, ordinary scheduling reliability, unattended
  renewal, offline recovery and key lifecycle acceptance remain open.
  No server/RADIUS, policy/VLAN, certificate or task change was made for this step.

## VV06 post-revocation recovery accepted — 15 October 2026, 13:47

- **Completed: controlled revocation -> fresh enrollment -> restored wired
  authentication and VLAN 110 access.** Operator supplied current netsh output
  for physical Realtek Ethernet, GUID 415933d5-5010-4a7a-b8bf-0e537e0bc7f2,
  MAC 38-CA-84-DB-FF-E6: Connected / Authentication succeeded.
  The immediately preceding endpoint result showed 10.10.110.4/24,
  gateway 10.10.110.1, with Wi-Fi disconnected.
- Together with the verified distinct new certificate/private key and
  state=installed (13:35 entry), this completes the controlled field recovery
  case. It does not prove the exact EAP-TLS selected serial from a handshake
  trace; the current netsh result reports authentication state only.
- The old server certificate remains revoked. Its guarded local removal was
  instructed but cleanup output was not supplied; do not claim old leaf/key
  lifecycle cleanup independently verified.
- Ordinary scheduler queue cause/reliability, unattended renewal, automatic
  recovery UX and full Windows reboot lifecycle remain separate open items.
  Next scoped acceptance: reboot only VV06 with physical port 6 connected and
  Wi-Fi disconnected, then observe wired authentication/IP and the existing
  SYSTEM task without forced dispatch or task-condition changes.
- Existing working pilot 2GL13ZU and Linux RADIUS, CA, policy/VLAN and secrets
  were not changed for this acceptance step.

## VV06 recovery network observation — 15 October 2026, 13:45

- **Completed: post-recovery IPv4 address observation.** Operator supplied
  Ethernet 10.10.110.4/24, gateway 10.10.110.1, AddressState=Preferred,
  with Wi-Fi disconnected. This matches the established VLAN 110 subnet.
- New certificate installation is already verified separately. This submission
  contains no current netsh authentication state or fresh 15505 success event;
  an IP address alone does not establish successful EAP-TLS or which certificate
  was selected. Keep fresh wired authentication acceptance pending.
- Guarded removal of the old revoked leaf was instructed, but no cleanup output
  was supplied. Do not record removal or private-key cleanup as confirmed.
- Next: read current physical Ethernet authentication state and latest matching
  Wired-AutoConfig success/failure events. Do not reset certificate metadata,
  task settings, RADIUS service, policies, VLANs or CA material for this read.

## VV06 fresh certificate verified — 15 October 2026, 13:35

- **Completed: controlled fresh enrollment after revocation, endpoint evidence.**
  Operator reports TaskState=Ready, LastTaskResult=0; current installed record
  resolves to Subject CN=AuthWire computer
  69b0d5cd-db61-4627-9db7-fcc5230152a3, serial
  6fc12360e627e5b92b0d60ab103def6cb40fe624, thumbprint
  68B32BBD470847950BAE5629B853739F819150B5, HasPrivateKey=true, expiry
  13 January 2027 13:07:32 Europe/Istanbul.
  status.json state=installed, serial matches the new leaf, reported
  last_success=2026-10-15T10:05:31.9905999+00:00.
- These recorded times do not establish that the 13:12:58 RunEx dispatch
  created this leaf: last_success precedes that task start. Preserve the raw
  observations; do not infer an exact issuance/dispatch chronology or permanent
  scheduler fix from them. The distinct new certificate/private-key and
  installed receipt state establish the recovery milestone.
- Next: guarded removal of only the old revoked Windows certificate with
  thumbprint 216819A5BF9A13A2A75609EA84FBFA316A39B453, after checking new
  leaf identity/private-key. Keep the server old serial revoked. No CNG key
  container deletion or CA/trust/policy changes are part of this step.
  Fresh wired port 6 EAP-TLS/DHCP using the new leaf remains pending.

## VV06 controlled dispatch result — 15 October 2026, 13:15

- Operator executed the existing-task RunEx dispatch and reported TaskState=
  Running, LastRunTime=13:12:58, LastTaskResult=267009 (running),
  PendingRequest=false, InstalledRecord=true. This is actual task execution
  and a recreated installed.json, not merely an accepted launch request.
- Inspect the certificate referenced by current installed.json thumbprint and
  current status/finished task result before accepting fresh enrollment or
  removing the old revoked leaf. New serial/thumbprint have not yet been read.
- Persistent scheduled-task settings were not changed by the supplied RunEx
  method. Ordinary condition-based scheduling reliability/precise queue cause
  remains open; do not label one-run dispatch as a permanent scheduler repair.

## VV06 scheduler follow-up — 15 October 2026, 13:07

- Current bootstrap reachability is confirmed: Wi-Fi source 10.35.50.69,
  AuthWire TCP 8765 reachable, network vizyonveri.local is DomainAuthenticated
  with Internet IPv4 connectivity. Task network profile Name/Id are empty;
  RunOnlyIfNetworkAvailable=true, DisallowStartIfOnBatteries=true,
  StopIfGoingOnBatteries=true, RunOnlyIfIdle=false, StartWhenAvailable=true,
  MultipleInstances=IgnoreNew. Win32_Battery Primary BatteryStatus=2.
  Microsoft documents that battery status 2 indicates access to AC power.
- Thus lack of current HTTPS TCP reachability or reported battery discharge
  is not established as the queue cause. Exact Windows scheduler queue cause
  remains unresolved. Avoid changing broad power/network conditions without
  evidence or claiming the installer is permanently fixed.
- Next controlled attempt: invoke the existing enabled SYSTEM task via
  Task Scheduler RunEx with only TASK_RUN_IGNORE_CONSTRAINTS (2), after checking
  its principal/enabled/AllowDemandStart and current state. Preserve persistent
  task settings/action, signed client, config/trust and all server settings.
  No task stop, state reset or additional certificate removal is part of this
  attempt. Report actual post-request task state, not a success-start message.
  This one-run dispatch is not yet performed/verified; new certificate and
  normal periodic scheduling acceptance are still open.

## VV06 queued enrollment — 15 October 2026, 12:55

- Operator read-only diagnostic: Computer=VV06, TaskState=Queued,
  TaskUser=SYSTEM, LastRunTime=12:41:05, LastTaskResult=0,
  ActionCallsClient=true, ValidateOnly=false, PendingRequest=false.
  Current status.json, retry.json and installed.json are all absent.
  Only AuthWire Certificate Enrollment was listed, also Queued.
- This confirms the current task is awaiting scheduler execution and no new
  client-state result has been saved. Earlier current-retry/ValidateOnly
  hypotheses are not supported by this snapshot. Exit 0 is not acceptance
  evidence for fresh issuance. Exact queue constraint is not yet established.
- Check AuthWire TCP reachability from the bootstrap network, task network
  profile/availability, idle/power settings and current network profile before
  changing any scheduler condition. Source installer enables
  RunOnlyIfNetworkAvailable; default Windows battery restrictions may also
  apply. Do not assume either is the cause before collecting actual settings.
- No repeat state reset or old certificate deletion is authorized by this
  diagnostic step; preserve existing Recovery-20261015-124104 backup.

## VV06 recovery attempt — 15 October 2026, 12:46

- Operator screenshots image(20261015-094606).png and
  image(20261015-094614).png were directly inspected. Recovery block printed
  backup C:\ProgramData\AuthWire\Recovery-20261015-124104 and task-start message.
  Task LastRunTime=15 October 12:41:05, LastTaskResult=0.
- **Recovery is not yet verified.** The supplied certificate result contains
  only the original revoked serial 0D9C3EE3C0B676CB323C1EC8314B62EE3E20A1D9,
  thumbprint 216819A5BF9A13A2A75609EA84FBFA316A39B453, private key present,
  expiry 11 January 2027 19:43:27. No new leaf was shown by the fixed-subject
  query. Do not delete the old leaf or mark fresh enrollment successful solely
  from task exit 0 or the task-start message.
- Inspect current task state/action and selected status/retry/installed metadata
  without printing receipt_payload, config contents or pending CSR/key material.
  Source has intentional successful early returns for ValidateOnly, held global
  mutex and future retry deadline; actual cause is not established. An updated
  installed record would also require reading the certificate by its recorded
  thumbprint rather than assuming the original subject filter finds it.
- No second reset, additional key/CSR or certificate deletion has been executed.
  Future mutating recovery commands should be invoked as one script block so
  a guard exception aborts the whole operation in an interactive shell.

## VV06 revocation acceptance — 14 October 2026, 19:06

- **Completed: VV06 wired revoked-certificate rejection.** Operator ran the
  targeted read-only CRL check: crl_number=21, currently_valid=true,
  signature_valid=true, vv06_in_crl=true for canonical serial
  d9c3ee3c0b676cb323c1ec8314b62ee3e20a1d9. The runtime Issuer public key and
  issuer name were used to verify the signature.
- Fresh Windows screenshot image(20261014-160552).png shows event 15514
  at 19:02:55, physical Realtek Ethernet GUID
  415933d5-5010-4a7a-b8bf-0e537e0bc7f2, MAC 38CA84DBFFE6, peer
  64E881346361, host/AuthWire computer 69b0d5cd-db61-4627-9db7-fcc5230152a3,
  reason 0x50005, error 0x40420110, generic account-related failure text.
  Do not relabel that text as independent proof that the AD account is disabled.
  Controlled revocation, exact signed/runtime CRL membership and fresh matching
  endpoint rejection jointly close the field negative case. Actual rejection
  layer (native CRL versus registry callback) was not independently instrumented.
- **Open: controlled fresh enrollment after revocation.** VV06 must use the
  ordinary domain/bootstrap network. Keep the account enabled/in the pilot
  group. Prepare an elevated, VV06-only guarded state reset: refuse running
  enrollment/pending request or mismatched installed serial/thumbprint; verify
  client Authenticode signature; temporarily disable the existing task, back up
  only installed/retry/status metadata under the protected ProgramData AuthWire
  folder, then enable/start the same SYSTEM task for a fresh key/CSR. Preserve
  config/trust, GPO, server settings and the old installed leaf until the new
  certificate/receipt is verified. This is explicit administrative recovery,
  not automatic revival of the revoked certificate or a production recovery UX
  acceptance. No recovery state mutation has been confirmed yet.

## VV06 revocation observation — 14 October 2026, 18:57

- Operator reports VV06 Authentication failed following the instructed
  certificate-revocation sequence. Runtime CRL is #21 (0x15), lastUpdate
  14 October 15:45:14 UTC (18:45:14 Istanbul), nextUpdate 15 October
  15:45:14 UTC (18:45:14 Istanbul), currently valid. This is the expected
  rejection/new-CRL observation; exact target entry/signature and a fresh
  Windows certificate-identity event are not yet captured, so final acceptance
  remains pending those checks.
- Desktop Commander reconnected after the requested server restart.
  Direct read at 18:58 confirms normal RADIUS active, PID 1274, Result=success;
  minute CRL timer active, last trigger 18:58:03, and sync oneshot Result=success
  (inactive after completion is normal). No assistant restart was performed.
- Source inspection for recovery: existing Windows client reports receipt for
  its installed certificate before deciding renewal. A revoked installed leaf
  receipt is rejected and handled as retry_pending; ordinary task reruns do not
  automatically create a fresh CSR in this case. Server issuance accepts a new
  key/CSR after a previously revoked leaf using fresh Kerberos/live AD/profile
  checks. Recovery will require a scoped administrative client-state reset,
  with guarded local backup and a new SYSTEM-task enrollment on an allowed
  bootstrap network. Do not clear config/trust, reuse the old CSR/key, un-revoke
  the old certificate or change working pilot 2GL13ZU.

## Pause checkpoint — 14 October 2026, 16:19 Europe/Istanbul

- Operator requested a Linux shutdown/start before executing the VV06
  certificate-revocation test. No revocation has yet been reported.
- Completed and retained: wired/wireless positive EAP-TLS/VLAN pilots, CRL
  synchronization fix, VV06 missing-certificate negative, GPO task/client
  certificate installation, positive wired/DHCP, pilot-group-out and disabled
  computer-account rejection with successful restoration.
- Exact next revocation target remains canonical serial
  d9c3ee3c0b676cb323c1ec8314b62ee3e20a1d9, VV06 GUID
  69b0d5cd-db61-4627-9db7-fcc5230152a3. Keep this certificate installed for
  the negative test; subsequent recovery uses fresh controlled enrollment.
- Last runtime CRL evidence is #20, valid until 15 October 09:03:32 Istanbul.
  Recheck active services/current CRL after boot before the panel revocation.
- Remote Desktop Commander reconnected for this checkpoint. Direct Linux
  os.sync completed successfully; kaname-lab.service, authwire-radius.service
  and authwire-radius-crl-sync.timer were each active/enabled. No service stop,
  certificate/policy mutation or shutdown was performed by the assistant.
- Work record and source are persisted in Git. This sync is not a newly
  created full data backup. Existing update backup remains the prior backup.

## Preservation requirements

Keep RADIUS process/unit/native module, policy conditions/VLANs, RADIUS client
secrets, AD connection, existing CA/certificates, Windows client and enrollment
package untouched by panel-only changes. Check actual process and file/state
preservation during deployment. Never record passwords, cookies, shared secrets,
private keys or keytabs in this record or test output.
