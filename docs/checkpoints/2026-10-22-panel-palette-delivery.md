# AuthWire panel palette — 22 October 2026

## Accepted scope

The operator paused remaining functional work and requested the existing AuthWire
panel use the attached cream/navy/sky-blue/terracotta reference. No new identity,
network, policy, PKI, Windows/GPO or RADIUS functionality is included.

- Navy #1D4D73: principal statistics cards and deep blue accents.
- Sky blue #68A9CF: active navigation/tabs, secondary controls and one statistics card.
- Terracotta #D96B52: primary CTA controls and brand wordmark.
- Cream #F3EAD8: page canvas and sidebar; slightly lighter/darker cream surfaces distinguish forms/cards.
- Charcoal #2C2C2C: normal text/icons. CTA text is #171717 to meet 4.5:1 contrast on terracotta; navy cards use cream text.
- Green/warning/error state indicators retain semantic colors.

## Source and validation

- PR44 reviewed product source b180d5c2cccf2f145f4c49d7ad85ba71c5b6ca88;
  merge f16de7ae5f0deb111184dcbc76f4ae87138fc141.
- Product changes only kaname/static/styles.css and dev.14 metadata in
  kaname/__init__.py, kaname/static/index.html and pyproject.toml. Browser expectation
  updates are development-only. All other installed 137 source files match dev.13.
- Foundation run39754669800: 553 tests / 25 skips, success.
- Browser run39754669357: nine existing UI suites, rendered contrast checks and
  desktop/mobile coverage, success. Screenshots inspected for overview, mobile,
  policy, services, certificates/drawer, LDAP and access records.
- Linux native preparation39754669315, native RADIUS39754669303,
  network probe39754669349, and enrollment/Kerberos/Windows39754669266 succeeded.
- Initial Windows retry job119743546546 failed after a deadline_rearmed timeout;
  same unchanged code passed the requested single rerun, job119745471485. This
  does not resolve the previously tracked intermittent timing issue.
- Deployment guard verified locally: accepted dev.13→dev.14/exact retry, refused
  authorizer/JavaScript/Windows source changes and installed drift; preservation
  refused changes to protected files, PIDs, timers and business state.

## Prepared local-sudo installation — not executed

- Linux segmentiq,10.35.50.246, currently0.14.0-dev.13.
- Read-only preflight: panel679209, RADIUS679309, broker149955 active, all141
  installed source files match accepted dev.13 stage. Passwordless sudo unavailable.
- Candidate stage /home/segmentiq/authwire-stage-dev14-b180d5c2cccf
- All141 candidate files and manifest verified; only four product files differ.
- Manifest SHA256 5dc6f6d432630c92f3c276654163f6ad3ffefcb0270552ab0bd30883f6c7106c
- Deployer /home/segmentiq/authwire-palette-update-20261022.py
- Deployer SHA256 1b21178d80907dede058d45a40f882b9374e8851e34bb93e9b82ff0efeb6a6df
- Deployer is pinned to the reviewed stage/source and installed updater. It takes
  fresh backups, persists original baseline, runs the existing protected-state
  comparisons, preserves RADIUS/broker processes, verifies HTTPS API, and checks
  isolated data restore. The source updater supports rollback on failed update.
- No live sudo installation, service restart, policy write, certificate/CA change,
  Windows/GPO change or live802.1X field test was performed in this turn.
- Pending: operator local sudo deployment output; then actual browser F5 and
  visual acceptance. Record development/technical/staging complete; do not mark
  the live palette installation complete until PALETTE_UPDATE_FINISHED is received.

Remaining functional work stays paused. DHCP/DNS architecture stays out of scope;
NTP work remains paused; current wired allow110/wireless allow140 are not edited.
