# AuthWire local access groups — development acceptance

Local groups are AuthWire-owned access selectors. They do not create AD groups
or change AD memberships. A member is selected from the directory catalog;
the server binds domain, object GUID, SID and account kind. A renamed or
recreated AD account does not inherit access merely because its name matches.

## Storage and atomic changes

Definitions and individual membership rows use the existing runtime_settings
table. No table migration or persistent journal-mode change is required.
Each membership key includes the canonical domain and object GUID and is a
SQLite primary key. A revision-checked BEGIN IMMEDIATE transaction validates
the complete selection, checks existing membership and policy conflicts,
then changes memberships, global revision and audit together. A failed bulk
selection changes nothing. There is no implicit move between groups.

One account belongs to at most one local access group. Remove it explicitly
from its old group before adding it elsewhere. AD's ordinary multiple
security-group memberships remain intact. Group names are unique per domain;
the internal UUID, not a mutable name or invented AD SID, identifies a group.
Bounds: 256 groups, 500 members per group, 10,000 total local memberships.

New members and enabled local-group rules require a complete membership-aware
AD catalog synchronized within 15 minutes. Old members can be removed with
an older snapshot; removal does not grant new rights. The panel warns that a
refresh is required. Selection never accepts a caller-supplied SID binding.

## Policy and live authorization

An optional conditions.local_group_ids array complements existing principal
SIDs. Within one rule the selected AD principals/groups and local groups are
alternatives; access type, NAS, EAP and device constraints still apply.
Old policy payloads retain their shape when the optional field is absent.
An empty group does not turn its rule into an unrestricted wildcard.

Conflict checking includes direct account SIDs, observed nested AD membership,
local members, general rules and overlapping access/NAS scopes. Conflicting
group changes or rule saves/activation are rejected atomically. A group used
by any rule, including a disabled rule, cannot be deleted. Later AD membership
changes can still introduce a conflict; the runtime retains POLICY_CONFLICT
rejection rather than guessing which rule should win.

Only after certificate binding and fresh live AD account checks does the
RADIUS adapter read the current policy/local-membership snapshot together.
Membership must match the authenticated domain/GUID/SID/kind. Deleted,
disabled, rebound or untrusted identities cannot gain local group access.
Missing/malformed local context fails closed. Simulation HTTP input cannot
supply a verified local group claim. A machine certificate does not prove
the logged-in user's identity; real user EAP-TLS remains a separate pilot.

## Panel and permissions

Kullanıcılar ve gruplar includes an AuthWire Grupları section with search,
create/edit/delete and a paged user/computer selection drawer. Selections are
staged until TAMAM; cancellation does not write. The rule picker has an
AuthWire Grubu type. Existing menu headings, design, logo and AD tabs remain.

Reading requires directory.catalog or policies.rules Read. Changes require
policies.rules Write because membership changes network access. AD catalog
Write alone grants no access-policy administration. Sessions, CSRF/Origin,
revision checks and server-side enforcement remain in force. Names are
rendered as text, never HTML. The publisher key, Windows/GPO scripts and
certificates are not changed by this feature.

This is a source/development description. Check CURRENT_STATUS.md for CI,
protected deployment, browser and real endpoint acceptance. Native loopback
TLS tests use disposable certificates and synthetic AD, not customer AD.
Activating the new adapter requires a controlled RADIUS process restart;
its unit, native module and existing RADIUS configuration are preserved.
