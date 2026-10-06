# AuthWire Design System v1

The panel uses a warm enterprise visual system across its existing screens.
The existing product logo remains unchanged. No external fonts, images, or
component services are required; Inter falls back to Segoe UI and Arial.

## Shared tokens

| Role | Value |
| --- | --- |
| Page background | `#F5EFEB` |
| Sidebar | `#2B2B2B` |
| Copper accent | `#C88565` |
| Accent hover | `#B87354` |
| Accent text / focus | `#9E6045` |
| Surface | `#FFFFFF` |
| Input surface | `#FCFAF9` |
| Body text | `#242424` |
| Secondary text | `#686868` |
| Border | `#E5DDD8` |
| Success text / surface | `#27714A` / `#E7F5EC` |
| Warning text / surface | `#8A5A1D` / `#FFF3DF` |
| Critical text / surface | `#A33C33` / `#FDEAE8` |

Copper primary buttons use dark text for legibility. Status labels use darker
semantic text on soft backgrounds and include a written status. Colors do not
replace the status text.

## Components and layout

- Desktop sidebar: 248 px, 232 px below 1200 px. Brand and footer stay fixed
  within the sidebar; navigation scrolls independently.
- Page title: 28 px. Section title: 20 px. Card title: 16 px. Body: 14 px.
  Labels: 12 px. Table text: 13 px.
- Shared spacing follows a 4 px scale. Cards use 20–24 px padding and 16–20 px
  gaps. Controls use 8 px corners; cards use 10 px; dialogs use 12 px.
- Forms retain labels above controls, visible keyboard focus, existing required
  fields, validation, and permission-controlled actions.
- Tables and existing directory lists use the same muted headings, light hover,
  copper accents, semantic statuses, and compact operation controls.
- The certificate drawer is up to 520 px wide. Narrow layouts overlay it and
  keep forms readable instead of compressing the page beside the drawer.
- Mobile navigation remains accessible through the menu button and closes on
  selection or Escape. Existing tab keyboard navigation and reduced-motion
  behavior remain supported.

## Navigation

The overview is followed by Access, Certificates, RADIUS, Monitoring, and
Administration groups, labelled in Turkish. Navigation only exposes existing
screens that the current session is permitted to read. Empty groups are hidden.
Proposed modules without a backend are not shown as working product features.

## Overview data contract

The overview reads the existing `/api/state` response and existing permissions.
It displays directory users/groups/computers, stored policies, and public CA
metadata. Directory timestamps identify the last catalog read. A stored catalog
is not treated as proof that AD is currently reachable. An expired issuer CA is
explicitly labelled. Missing metrics display a dash rather than an invented zero.

The infrastructure card labels RADIUS as preparation and explicitly says that
the panel does not measure live access status. The certificate lifecycle card
links to the existing bulk profile, deployment, device enrollment and renewal
screen; it does not claim that a deployment has succeeded.

## Scope and rollback

This UI change does not modify Python services, API endpoints, database schema,
certificate issuance, Kerberos, GPO scripts, RADIUS or 802.1X enforcement.
The source baseline is `b8940286ee55001b09c91641ccc60f06ad35d476`.
Reverting the UI change restores the previous interface without reverting the
client and enrollment fixes already in that baseline. The existing Linux update
process should be used for installation; production deployment is a separate
step from source preparation and fixture tests.

## Validation

`tools/ui_smoke.cjs` exercises the existing authenticated browser workflows,
permission-controlled navigation, forms, certificate drawer, catalog details,
and mobile layout. `tools/device_ui_smoke.cjs` exercises bulk enrollment UI.
Both run against disposable fixture servers and do not contact customer AD or
activate network access. Screenshots from these fixtures are review evidence,
not screenshots of a customer deployment.
