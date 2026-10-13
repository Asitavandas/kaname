# AuthWire current work record

Updated: 12 October 2026, Europe/Istanbul. This record supplements the 9 October
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
| B02 | Live AD identity and pilot group were accepted on real wired/wireless sessions. | Intentional wrong-group, disabled/deleted account, unavailable AD and capacity tests. |
| B03 | Real RADIUS server name/CA validation completed on wired and wireless Windows profiles. | Revocation, expired/wrong issuer, CA/issuer and signing maintenance acceptance. |
| B04 | Enrollment task, successful last result, installation record, valid certificate/private key and confirmed receipt observed for the pilot. | Interrupted/duplicate requests and negative enrollment scenarios. |
| B05 | Pilot task and installed client confirmed. Client source hash remained unchanged through server updates. | Fresh SYSVOL package/signature/hash comparison where not yet recorded. |
| B06 | No forced renewal or full OS reboot recovery acceptance executed in this session. | Renewal, offline/reboot recovery, old/new selection and expired recovery. |
| B07 | Normal production service active; actual switch/AP EAP-TLS and VLAN reply path completed. | Deliberate negative authorization acceptance and full boot behavior; accounting remains off. |
| B08 | Real permit and dynamic VLAN/DHCP behavior completed on switch and AP. | Deliberate policy deny and negative state transitions. |
| B09 | Pilot PC/port, Windows trust/profile, positive access and dynamic VLAN completed (3 of original 4 rows). | Combined negative certificate/group and OS reboot row remains open. |
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

## Next agreed field session — 13 October 2026 morning

- Operator will bring a domain-joined Windows computer with no AuthWire client
  certificate installed. Operator identified the new computer as **VV06** at 11:14 on 13 October,
  reporting domain membership and no installed certificate. Read-only baseline confirmed at 11:22: domain vizyonveri.local,
  PartOfDomain=true, one personal machine certificate (Subject/Issuer CN=VV06),
  zero AuthWire machine certificates, AuthWire Root CA not trusted, no AuthWire
  enrollment task, and dot3svc stopped. Certificate purpose of the self-issued
  VV06 certificate was not established. Server-trust and supplicant preparation
  are required before the no-client-certificate rejection test can be accepted. No AD, policy or GPO changes were made in advance.
- Server connection at session start: Desktop Commander segmentiq is offline
  (last seen approximately 16 hours earlier). This does not establish RADIUS
  health; production service/PKI readiness is pending remote reconnection.
- First establish the certificate-free baseline and confirm rejection on the
  existing enterprise 802.1X network. Domain membership alone is not sufficient
  for EAP-TLS. Existing guest access is outside this test and will not be repeated.
- Then exercise controlled enrollment and positive access, followed by the
  outstanding wrong-group, disabled-account and revoked-certificate cases on this
  separate test computer/certificate. Keep working pilot 2GL13ZU unchanged and
  restore temporary account/group changes after each case.
- **User EAP-TLS remains an explicit open item.** User certificate issuance,
  AD binding and live authorization exist in source, but automated user
  distribution/renewal and real wired/wireless user authentication have not been
  accepted. Include them in the next report; do not close them with computer
  pilot evidence. Windows machineOrUser switching also needs separate acceptance.
- Simultaneous machine-and-user authentication (for example TEAP chaining) is not
  implemented and is not silently added to the current EAP-TLS release scope.
- Operator will observe panel behavior and send grouped notes if symptoms recur;
  browser acceptance remains open. No reminder or unattended live test is scheduled.

## Preservation requirements

Keep RADIUS process/unit/native module, policy conditions/VLANs, RADIUS client
secrets, AD connection, existing CA/certificates, Windows client and enrollment
package untouched by panel-only changes. Check actual process and file/state
preservation during deployment. Never record passwords, cookies, shared secrets,
private keys or keytabs in this record or test output.
