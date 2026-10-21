# Policy enable/disable panel delivery — 21 October 2026

Requested by the operator instead of replacing the planned disabled-policy test with an explicit deny action.

- Reviewed source head: `9629483795df63f139eed25bc3bfb8cc1649aac6` (PR43, merged as `96be7f50c67e030d31f42fcab1cd34ae6b3086af`). Version `0.14.0-dev.13`.
- Exact source-only package:141 files; manifest SHA256 `83a18e516ce8315f06aa0276ebdfe4642de00fce55d00eaf753c16c6e8774295`.
- Prepared ordinary-user stage: `/home/segmentiq/authwire-stage-dev13-9629483795df`.
- Pinned operator launcher: `/home/segmentiq/authwire-policy-toggle-update-20261021.py`; SHA256 `0ef95ca8fa91a62760ee28dd0246bb353d50ef3ea9a690b3378b29fc676983d6`.
- Launcher template: [2026-10-21-policy-toggle-update.py](2026-10-21-policy-toggle-update.py). Pin only STAGE/EXPECTED/RELEASE to the values above; deployed launcher bytes were read back and SHA256 verified. Its private source-stage builder checks the accepted dev12 stage manifest and every source SHA before writing the new stage; no product or policy mutation occurs during staging.

Writer-only controls preserve every policy field except enabled, including allow/deny action, VLAN140, group/NAS/access scopes and constraints. Disabled rules are skipped by the existing evaluator. Another matching enabled rule can still decide the request. Reactivation conflicts and stale revisions are rejected by the existing server; no write replay. Edits preserve disabled status. The panel explains that existing connections are not immediately disconnected.

The update does not toggle any live policy. It preserves Windows/GPO templates, server authorization code, CA/certificates, secrets, policies, service units, native module, RADIUS/broker PIDs and backup/CRL timers; uses before/after private backup, isolated data restore and pinned HTTPS API checks. Only the panel service restarts. The disposable native lab path fix adds its own shim directory to its observer import path, independent of authorizer load order; it does not alter production observer/authentication code.

Live deployment completed with the operator's verified dev13 receipt; operator button and field acceptance remain pending. After installation, inspect both policy rows without clicking, confirm wireless remains allow/VLAN140, and then return to the previously planned VV06 wireless enabled=false→true field test while retaining wired management access. If no other rule matches, expect NO_MATCHING_POLICY while disabled; this is separate from POLICY_DENY. Do not mark all B08/B10 complete from this narrow case. Guest retest is declined; DHCP/DNS placement remains outside scope. NTP work stays paused with its previously recorded health caveat.

## Technical acceptance

🔴✓ All applicable workflow groups succeeded on reviewed head9629483795df63f139eed25bc3bfb8cc1649aac6. Foundation39649300930:553 tests/25skip. Browser39649300900:policy persistence/evaluation, VLAN/selectors, disabled edit, double/failed write, concurrent revision, conflicting activation, RBAC/CSRF and390/1366/1920px; screenshot inspected, actual footerdev13. Native RADIUS39649300968:normal/debug EAP-TLS and authenticated VLAN cases,35 runtime tests. Linux preparation39649301117/native adapter; enrollment39649301061 real Windows client/retry and native Kerberos; bounded probes39649300679. Local policy/admin90tests/1skip and source-preservation/independent-import6tests passed. The first observer-shim CI failure on424e8ee2 was fixed and retested; production authentication code remains exact.

🔴✓ The operator subsequently supplied POLICY_TOGGLE_UPDATE_FINISHED verified=true for dev13. Files/PIDs/timers/business state are preserved, RADIUS326873/broker149955 unchanged; before/after backups,162-file isolated data restore and all authenticated local API reads passed. No live policy action was executed. See [live result](2026-10-21-policy-toggle-live-result.json). Browser visibility and real VV06 disabled→enabled acceptance are still pending. Full appliance boot restore remains untested.
