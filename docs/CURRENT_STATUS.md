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
| B01 | Panel stability investigation in progress: intermittent reload/login complaints. | Stable panel acceptance; complete setup/apply/recovery UX. |
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
  neither CA nor RADIUS server certificate should be reset to address it.
- Frontend issues under investigation: startup catches any data/list failure and
  resets the session view; unbounded fetch; overlapping background polls; generic
  error recovery creates additional requests; login transitions do not invalidate
  obsolete unauthorized responses. Fault-injection coverage is being added.
- Panel fix status: **in progress, not yet deployed or accepted**. Update this
  row with exact source/CI/deployment evidence after completing the fix.

## Preservation requirements

Keep RADIUS process/unit/native module, policy conditions/VLANs, RADIUS client
secrets, AD connection, existing CA/certificates, Windows client and enrollment
package untouched by panel-only changes. Check actual process and file/state
preservation during deployment. Never record passwords, cookies, shared secrets,
private keys or keytabs in this record or test output.
